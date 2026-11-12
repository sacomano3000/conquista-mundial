--!strict
-- Stars for a match (shared/Data/Stars; spent in the Arsenal, shared/Data/Arsenal).
--
-- A public match runs on this server: MatchServer follows it (Stars.Tracker) and its results are paid
-- as they are (Rewards.pay). A solo match runs on the player's own device, so its result is the
-- client's word (OP.SOLO_RESULT): it is typed and bounded (Stars.sanitize), can't be longer than the
-- match really lasted on this server's clock (counted from the client's "match_start" report), and
-- never pays more than Stars.solo_cap of that real time. So a made-up report earns no faster than a
-- good player, and nothing at all without the time passing.
--
--   Rewards.configure(deps)          { add_stars = fn(player, n) -> (ok, balance), double = fn(player)
--                                      -> boolean, general = fn(player) -> boolean, send = fn(player,
--                                      payload), now = fn() -> s, log?, missions = true? }
-- With `missions` on, add_stars is called as add_stars(player, n, { result, first }) and may answer a
-- third value: the Coroas the player's missions paid for that result (Data/Missions; the "missions"
-- line).
-- A RoWorld General (Data/Subscription) gets Subscription.STARS_BONUS of the match's Stars on top
-- (before 2x Stars doubles: the "general" line).
--   Rewards.solo_started(player, mode)   the client's match_start ("solo0" / "solo1" / "solo2")
--   Rewards.solo_result(player, report)  OP.SOLO_RESULT (yields)
--   Rewards.pay(player, result, mode, ranked?)   a result this server measured itself (yields);
--                                        `ranked`: the match was a ranked one (Data/Ranked): add_stars
--                                        moves the player's points in the same write and answers a
--                                        fourth value, which goes to the client as `ranked`
--   Rewards.release(player)              PlayerRemoving
-- The payload sent to the client (OP.STARS): { lines = { { key, amount } }, total, balance, mode,
-- ranked = { lines, total, delta, points, tier, before, month }? }.
local IS_ROBLOX = typeof(game) == "Instance"
local Stars: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data.Stars)
	else require("../shared/Data/Stars")
local Subscription: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data.Subscription)
	else require("../shared/Data/Subscription")

local Rewards = {}

--- Results one solo match may be paid for: its end, and one more for each life a takeover gave it.
Rewards.MAX_SOLO_PAYOUTS = 4
--- Slack on the real time a solo result may claim (the report's trip, the clock's grain), minutes.
Rewards.SLACK_MIN = 0.25

type Solo = { mode: string, paid_at: number, payouts: number }

local deps: { [string]: any } = {}
local solo: { [any]: Solo } = {}

function Rewards.configure(d: { [string]: any })
	for k, v in d do
		deps[k] = v
	end
end

--- Tests: forget everyone.
function Rewards.reset()
	table.clear(solo)
end

local function now(): number
	return if deps.now then deps.now() else os.clock()
end

--- `match`: { result, first } when the missions are on (deps.missions; Data/Missions): add_stars counts
--- the result for them in the same write and answers what they paid, shown as a line of its own
--- ("missions"; never doubled). A match that pays nothing still counts for the missions.
local function deliver(player: any, lines: { { any } }, total: number, mode: string, match: any?): number
	if deps.missions ~= true and match ~= nil then
		-- (no missions here: a ranked result is still counted for the points)
		match = if (match.ranked == true or match.public == true)
				and type(match.result) == "table"
				and match.result.spawned == true
			then { result = match.result, first = match.first, ranked = match.ranked == true, public = match.public == true, missions = false }
			else nil
	end
	if total <= 0 and match == nil then
		return 0
	end
	local ok, balance, bonus, moved = deps.add_stars(player, math.max(total, 0), match)
	if not ok then
		return 0
	end
	if type(bonus) == "number" and bonus > 0 then
		table.insert(lines, { "missions", bonus })
		total = math.max(total, 0) + bonus
	end
	-- the ranked points of the match (never doubled: they are not Coroas)
	local ranked = nil
	if type(moved) == "table" then
		ranked = {
			lines = moved.lines,
			total = moved.total,
			delta = moved.delta,
			points = moved.points,
			tier = moved.tier,
			before = moved.before,
			month = moved.month,
		}
		if deps.season_closed and moved.closed ~= nil then
			pcall(deps.season_closed, player, moved.closed)
		end
	end
	if total <= 0 and ranked == nil then
		return 0
	end
	if deps.send then
		pcall(deps.send, player, { lines = lines, total = math.max(total, 0), balance = balance, mode = mode, ranked = ranked })
	end
	if deps.log then
		deps.log(string.format("[Rewards] %s +%d Stars (%s)", tostring(player.UserId), total, mode))
	end
	return total
end

local function with_double(player: any, lines: { { any } }, total: number): ({ { any } }, number)
	local base = total
	if total > 0 and deps.double and deps.double(player) == true then
		table.insert(lines, { "double", total })
		total *= 2
	end
	if base > 0 and deps.general and deps.general(player) == true then
		local extra = Subscription.bonus(base, Stars.QUANTUM)
		if extra > 0 then
			table.insert(lines, { "general", extra })
			total += extra
		end
	end
	return lines, total
end

--- A result this server measured itself (a public match). Returns the Stars paid.
function Rewards.pay(player: any, result: any, mode: string?, ranked: boolean?): number
	local m = mode or "public"
	local p = Stars.payout(result, m, false)
	local lines, total = with_double(player, p.lines, p.total)
	return deliver(player, lines, total, m, { result = result, first = true, ranked = ranked == true, public = m == "public" })
end

function Rewards.solo_started(player: any, mode: any)
	if type(mode) ~= "string" or Stars.MODE_MULT[mode] == nil or mode == "public" then
		solo[player] = nil
		return
	end
	solo[player] = { mode = mode, paid_at = now(), payouts = 0 }
end

--- The client's result of the solo match it reported starting. Returns the Stars paid.
function Rewards.solo_result(player: any, report: any): number
	local m = solo[player]
	if m == nil or m.payouts >= Rewards.MAX_SOLO_PAYOUTS then
		return 0
	end
	local t = now()
	local real = math.max(0, (t - m.paid_at) / 60)
	local r = Stars.sanitize(report, real + Rewards.SLACK_MIN)
	local first = m.payouts == 0
	m.payouts += 1
	m.paid_at = t
	if r.left then
		solo[player] = nil -- the match is over for this player
	end
	local p = Stars.payout(r, m.mode, false)
	local lines, total = p.lines, p.total
	local cap = Stars.solo_cap(real)
	if total > cap then
		-- more than that much real time can pay: every line shrinks alike
		local k = cap / total
		total = 0
		for _, line in lines do
			line[2] = math.floor(line[2] * k / Stars.QUANTUM) * Stars.QUANTUM
			total += line[2]
		end
	end
	lines, total = with_double(player, lines, total)
	return deliver(player, lines, total, m.mode, { result = r, first = first })
end

function Rewards.release(player: any)
	solo[player] = nil
end

return Rewards
