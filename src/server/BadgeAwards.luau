--!strict
-- Gives the game's Roblox badges (shared/Data/Badges says when one is earned; shared/Data/MyBadges has
-- the ids the owner made in the Creator Dashboard). A badge without an id is skipped; a badge given
-- once on this server is not asked for again (Roblox itself ignores a badge the player already has).
--
--   BadgeAwards.configure({ service = BadgeService, ids = { [key] = id }?, log?, warn? })
--   BadgeAwards.sync(player, inv) -> { key }     gives what `inv` (Purchases.inventory) has earned and
--                                                this server has not given yet; yields
--   BadgeAwards.forget(player)                   the player left
local Shared: any = if typeof(game) == "Instance" then game:GetService("ReplicatedStorage"):WaitForChild("Conquista") else nil
local Badges: any = if Shared then require(Shared.Data.Badges) else require("../shared/Data/Badges")
local MyBadges: any = if Shared then require(Shared.Data.MyBadges) else require("../shared/Data/MyBadges")

local BadgeAwards = {}

local deps: { [string]: any } = {}
--- player -> { [key] = true }: given (or found owned) on this server
local given: { [any]: { [string]: boolean } } = {}

function BadgeAwards.configure(d: { [string]: any })
	deps = d
end

function BadgeAwards.reset()
	deps = {}
	table.clear(given)
end

function BadgeAwards.forget(player: any)
	given[player] = nil
end

--- The id of badge `key`, or nil when the owner has not made it yet.
function BadgeAwards.id_of(key: string): number?
	local ids = deps.ids or MyBadges
	local id = tonumber(ids[key])
	return if id ~= nil and id == id and id > 0 and id % 1 == 0 then id else nil
end

function BadgeAwards.sync(player: any, inv: any): { string }
	local out: { string } = {}
	local service = deps.service
	if service == nil or player == nil then
		return out
	end
	local earned = Badges.earned(inv)
	local mine = given[player]
	if mine == nil then
		mine = {}
		given[player] = mine
	end
	for _, b in Badges.LIST do
		local id = BadgeAwards.id_of(b.key)
		if id ~= nil and earned[b.key] and not mine[b.key] then
			-- (marked first: two results arriving together ask Roblox once)
			mine[b.key] = true
			local ok, err = pcall(function()
				if service:UserHasBadgeAsync(player.UserId, id) then
					return
				end
				service:AwardBadge(player.UserId, id)
				table.insert(out, b.key)
			end)
			if not ok then
				mine[b.key] = nil -- (Roblox did not answer: the next result tries again)
				if deps.warn then
					deps.warn("badge " .. b.key .. " not given to " .. tostring(player.UserId) .. ": " .. tostring(err))
				end
			elseif deps.log and out[#out] == b.key then
				deps.log(string.format("%s: badge %s (%d)", tostring(player.UserId), b.key, id))
			end
		end
	end
	return out
end

return BadgeAwards
