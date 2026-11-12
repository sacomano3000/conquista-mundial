--!nocheck
-- The weekly ranking's insignia beside the names (client/UI/Insignia; 2026-11-12), outside Roblox: every
-- screen that shows a player's name is built here and given a player who wears one:
--   * the match's list (Leaderboard.Row), the target's card (TargetCard), the end of a match's
--     winner / leader (GameOver), the starting places' head shots (SpawnOverlay), the lobby's party
--     and its invite list (PartyPanel);
--   * who wears none shows none; an insignia that goes away is taken off;
--   * the pointer on it (a phone: a tap) asks for the card that says where it was won.
--   lune run tests/insignia_nomes.luau
local H = require("./ui_harness")
local UICtx = require("../src/client/UI/UICtx")
local UITheme = require("../src/client/UI/UITheme")
local W = require("../src/client/UI/Widgets")
local Insignia = require("../src/client/UI/Insignia")
local RankPrizes = require("../src/shared/Data/RankPrizes")
local Defs = require("../src/shared/Core/Defs")
local Lang = require("../src/shared/Data/Lang")
Lang.use("pt")

-- (where a press is: Widgets asks Roblox's services, which are not here; the event carries it)
W.input_pos = function(io: any): Vector2
	return Vector2.new(io.Position.X, io.Position.Y)
end
W.screen_to_logical = function(v: Vector2): Vector2
	return v / UITheme.scale
end

local checks, failed = 0, 0
local function check(ok: any, what: string)
	checks += 1
	if not ok then
		failed += 1
		print("FAIL: " .. what)
	end
end

-- (the lobby's party asks Roblox who is on the server: a stand-in, with three players)
local game_ = H.fake_game()
local ME = 77
local function fake_player(uid: number, name: string, badge: any, wins: any, kills: any): any
	local attrs = { RankBadge = badge, RankBadgeWins = wins, RankBadgeKills = kills }
	return {
		UserId = uid,
		Name = name,
		DisplayName = name,
		GetAttribute = function(_p, k: string)
			return attrs[k]
		end,
		IsFriendsWith = function()
			return false
		end,
	}
end
local roster = {
	fake_player(ME, "Eu", 1, 1, 3),
	fake_player(501, "Prata", 2, nil, 2),
	fake_player(502, "Ninguem", nil, nil, nil),
	fake_player(503, "Lixo", 9, "x", 0),
}
local PlayersSvc = game_:GetService("Players")
rawset(PlayersSvc, "LocalPlayer", roster[1])
rawset(PlayersSvc, "GetPlayerByUserId", function(_s, uid: number)
	for _, p in roster do
		if p.UserId == uid then
			return p
		end
	end
	return nil
end)
rawset(PlayersSvc, "GetPlayers", function()
	return roster
end)

local Leaderboard = require("../src/client/UI/Leaderboard")
local TargetCard = require("../src/client/UI/TargetCard")
local GameOver = require("../src/client/UI/GameOver")
local SpawnOverlay = require("../src/client/UI/SpawnOverlay")
local PartyPanel = require("../src/client/UI/PartyPanel")

--- A match's state as the screens read it: four owners, three of them people.
local function state(): any
	local s = {
		phase = Defs.PHASE_SPAWN,
		owners = {
			[1] = { id = 1, name = "Eu", color = Color3.fromRGB(200, 60, 60), kind = Defs.KIND_HUMAN, alive = true, spawned = true, troops = 1200, tiles = 40 },
			[2] = { id = 2, name = "Prata", color = Color3.fromRGB(60, 120, 200), kind = Defs.KIND_HUMAN, alive = true, spawned = false, troops = 900, tiles = 30 },
			[3] = { id = 3, name = "Ninguem", color = Color3.fromRGB(60, 200, 90), kind = Defs.KIND_HUMAN, alive = true, spawned = true, troops = 700, tiles = 20 },
			[4] = { id = 4, name = "Reino de Bot", color = Color3.fromRGB(120, 120, 120), kind = Defs.KIND_BOT or 2, alive = true, spawned = true, troops = 300, tiles = 10 },
		},
		cosmetics = {
			[1] = { face = ME, badge = 1, bw = 1, bk = 3 },
			[2] = { face = 501, badge = 2, bk = 2 },
			[3] = { face = 502 },
		},
	}
	function s:get_owner(id)
		return self.owners[id]
	end
	function s:owner_name(id)
		return self.owners[id] and self.owners[id].name or ""
	end
	function s:tile_owner(t)
		return t
	end
	function s:land_share(_id)
		return 0.25
	end
	function s:has_request()
		return false
	end
	return setmetatable(s, {
		-- (anything else a screen asks the state: nothing there)
		__index = function(_t, _k)
			return function()
				return nil
			end
		end,
	})
end

local function context(view: any): (any, any, any)
	local root = H.root(view[2], view[3], view[4])
	local ctx = UICtx.new()
	ctx.vp = root.vp
	ctx.compact = view[4]
	ctx.touch = view[4]
	ctx.touch_device = view[4]
	ctx.state = state()
	local hints = {}
	function ctx:show_hint(anchor: any, spec: any, force: boolean?)
		if force or not self.touch then
			table.insert(hints, { anchor = anchor, spec = spec, force = force == true })
		end
	end
	function ctx:hide_hint(anchor: any)
		table.insert(hints, { anchor = anchor, hide = true })
	end
	function ctx:sfx() end
	function ctx:me()
		return 1
	end
	function ctx:my()
		return self.state.owners[1]
	end
	function ctx:mode()
		return UICtx.MODE_MULTI
	end
	function ctx:world_call() end
	function ctx:relation(_id)
		return "enemy"
	end
	function ctx:relation_color(_r)
		return UITheme.TEXT
	end
	function ctx:kind_title(_k)
		return "Player"
	end
	function ctx:terrain_title(_t)
		return "Plains"
	end
	function ctx:render_tick()
		return 0
	end
	return ctx, root, hints
end

--- The insignia pictures in sight under `node`: their images, in order.
local function badges(node: any): { string }
	local out = {}
	for _, d in node.gui:GetDescendants() do
		if d.Name == "RankBadge" and d.Visible ~= false then
			local seen = true
			local p = d.Parent
			while p ~= nil and p ~= node.gui do
				if p.Visible == false then
					seen = false
					break
				end
				p = p.Parent
			end
			if seen then
				table.insert(out, d.Image)
			end
		end
	end
	return out
end
local GOLD, SILVER = RankPrizes.badge_image(1), RankPrizes.badge_image(2)

for _, view in { { "pc", 1280, 720, false }, { "celular", 844, 390, true } } do
	local v = " (" .. view[1] .. ")"

	-- ------------------------------------------------------------------------------------------
	-- the match's list
	-- ------------------------------------------------------------------------------------------
	do
		local ctx, root, hints = context(view)
		local row = Leaderboard.Row.new(ctx)
		-- (the list is a column of rows, as wide as its panel)
		local col = UITheme.vbox(2)
		col:set_min_size(Vector2.new(280, 0))
		root:add_child(col)
		col:add_child(row)
		row:set_row(ctx.state.owners[1], 1)
		H.step(2)
		local b = badges(row)
		check(#b == 1 and b[1] == GOLD, "the match's list: the gold insignia beside the name" .. v .. ": " .. #b)
		check(row._ins.wins == 1 and row._ins.kills == 3, "it knows where it was won" .. v)
		do
			local nx, _, nw = H.rect(row.name_l.gui)
			local ix, iy, iw, ih = H.rect(row.badge.gui)
			local rx, ry, rw, rh = H.rect(row.gui)
			check(ix >= nx + nw - 0.5, "right of the name" .. v)
			check(ix >= rx and ix + iw <= rx + rw + 0.5 and iy >= ry - 0.5 and iy + ih <= ry + rh + 0.5, string.format("inside the row%s: %d,%d %dx%d in %d,%d %dx%d", v, ix, iy, iw, ih, rx, ry, rw, rh))
		end
		check(row.badge.gui.Active ~= true, "a press on it still reaches the row" .. v)
		-- the pointer on it
		H.fire(row.badge.gui, "MouseEnter")
		if view[4] then
			check(#hints == 0, "a phone: resting shows nothing" .. v)
			H.fire(row.badge.gui, "InputBegan", { UserInputType = Enum.UserInputType.Touch, UserInputState = Enum.UserInputState.Begin, Position = Vector3.new(4, 4, 0) })
		end
		check(#hints == 1 and hints[1].anchor == row.badge, "the card is asked for, anchored to the insignia" .. v .. ": " .. #hints)
		if hints[1] ~= nil then
			check(
				Lang.t(hints[1].spec.body) == "1º em Vitórias e 3º em Reinos destruídos na semana passada",
				"it says the places" .. v .. ": " .. tostring(Lang.t(hints[1].spec.body))
			)
		end
		-- the row is reused for another owner
		row:set_row(ctx.state.owners[2], 2)
		H.step(2)
		b = badges(row)
		check(#b == 1 and b[1] == SILVER and row._ins.wins == nil and row._ins.kills == 2, "the row reused for the silver player" .. v)
		row:set_row(ctx.state.owners[3], 3)
		H.step(2)
		check(#badges(row) == 0 and row._badge_n == 0, "a player without one: none shown" .. v)
		row:set_row(ctx.state.owners[4], 4)
		H.step(2)
		check(#badges(row) == 0, "a bot: none" .. v)
		-- the week turns during a match that started before: the insignia leaves with the cosmetics
		row:set_row(ctx.state.owners[1], 1)
		ctx.state.cosmetics[1] = { face = ME }
		row:set_row(ctx.state.owners[1], 1)
		H.step(2)
		check(#badges(row) == 0, "the insignia taken away is taken off the row" .. v)
	end

	-- ------------------------------------------------------------------------------------------
	-- the target's card
	-- ------------------------------------------------------------------------------------------
	do
		local ctx, root, hints = context(view)
		local card = TargetCard.new(ctx)
		root:add_child(card)
		card:show_target(2, "attack", { troops = 500 })
		H.step(3)
		local b = badges(card)
		check(#b == 1 and b[1] == SILVER, "the target's card: the owner's silver insignia" .. v .. ": " .. #b)
		do
			local nx, _, nw = H.rect(card._name.gui)
			local ix = H.rect(card._ins.node.gui)
			check(ix >= nx + nw - 0.5, "after the name" .. v)
		end
		H.fire(card._ins.node.gui, "MouseEnter")
		if not view[4] then
			check(#hints == 1 and Lang.t(hints[1].spec.body) == "2º em Reinos destruídos na semana passada", "its card says second in kingdoms" .. v)
		end
		card:show_target(3, "attack", { troops = 500 })
		H.step(3)
		check(#badges(card) == 0, "a target without one: none" .. v)
	end

	-- ------------------------------------------------------------------------------------------
	-- the end of a match: the winner / the leader
	-- ------------------------------------------------------------------------------------------
	do
		local ctx, root = context(view)
		local over = GameOver.new(ctx)
		root:add_child(over)
		over._kind = "defeat"
		over:_set_pill(2)
		H.step(3)
		check(over._winner_ins.place == 2 and over._winner_ins.img.Image == SILVER, "the end of a match: the winner's insignia" .. v)
		check(string.find(over._winner_name.text, "Prata", 1, true) ~= nil, "beside their name" .. v .. ": " .. tostring(over._winner_name.text))
		over:_set_pill(3)
		H.step(3)
		check(over._winner_ins.place == 0 and not over._winner_ins.node.visible, "a winner without one: none" .. v)
	end

	-- ------------------------------------------------------------------------------------------
	-- the starting places
	-- ------------------------------------------------------------------------------------------
	do
		local ctx, root = context(view)
		local so = SpawnOverlay.new(ctx)
		root:add_child(so)
		so:_refresh_players()
		H.step(3)
		if view[4] then
			check(#badges(so) == 0, "phones show a count, no head shots: no insignia to place" .. v)
		else
			local b = badges(so)
			table.sort(b)
			check(#b == 2, "the starting places: two of the three head shots wear one" .. v .. ": " .. #b)
			local want = { GOLD, SILVER }
			table.sort(want)
			check(b[1] == want[1] and b[2] == want[2], "gold and silver" .. v)
		end
	end

	-- ------------------------------------------------------------------------------------------
	-- the lobby's party
	-- ------------------------------------------------------------------------------------------
	do
		local ctx, root, hints = context(view)
		local party = PartyPanel.new(ctx)
		root:add_child(party)
		party:set_state({
			leader = true,
			members = {
				{ uid = ME, name = "Eu", leader = true },
				{ uid = 501, name = "Prata" },
				{ uid = 502, name = "Ninguem" },
				{ uid = 503, name = "Lixo" },
				{ uid = 999, name = "Saiu" },
			},
			invites = {},
		})
		H.step(3)
		local b = badges(party._members)
		check(#b == 2 and b[1] == GOLD and b[2] == SILVER, "the party: its two members with an insignia show it, in order" .. v .. ": " .. #b)
		check(Insignia.of_player(roster[4]) == nil, "an attribute that is no place (9) is no insignia" .. v)
		check(Insignia.of_player(nil) == nil and Insignia.of_player({}) == nil, "no player, or one without attributes: none" .. v)
	end
end

for _, p in H.problems() do
	check(false, "a property Roblox does not have: " .. p)
end
print(string.format("insignia_nomes: %d checks, %d failed", checks, failed))
if failed > 0 then
	error("insignia_nomes: failed")
end
