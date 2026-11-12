--!nocheck
-- The ranked free-for-all (RANQUEADA, 2026-11-12): shared/Data/Ranked (points, tiers, the monthly
-- season), server/Purchases (the points move in the same write as the Coroas; the season closes and
-- pays once), server/Rewards (what reaches the client) and client/Session (what it keeps of it).
require("./prelude")
local Missions = require("../src/shared/Data/Missions")
local Ranked = require("../src/shared/Data/Ranked")
local Stars = require("../src/shared/Data/Stars")
local Purchases = require("../src/server/Purchases")
local Rewards = require("../src/server/Rewards")
local Session = require("../src/client/Session")

local checks, fails = 0, 0
local function expect(c: any, w: string)
	checks += 1
	if not c then
		fails += 1
		print("FAIL " .. w)
	end
end
local function brt(y, mo, d, h, mi)
	return Missions.days_of(y, mo, d) * 86400 + (h or 0) * 3600 + (mi or 0) * 60 + 3 * 3600
end
local function line_of(lines, key)
	for _, l in lines do
		if l[1] == key then
			return l[2]
		end
	end
	return nil
end

print("the tiers")
do
	local names = {}
	for _, t in Ranked.TIERS do
		table.insert(names, t.name)
	end
	expect(table.concat(names, ",") == "Escudeiro,Cavaleiro,Barão,Duque,Rei", "the five tiers, in order: " .. table.concat(names, ","))
	expect(Ranked.TIERS[1].at == 0 and Ranked.TIERS[1].prize == 0, "the first tier starts at 0 and pays nothing")
	for i = 2, #Ranked.TIERS do
		local a, b = Ranked.TIERS[i - 1], Ranked.TIERS[i]
		expect(b.at > a.at and b.fee > a.fee and b.prize > a.prize, "tier " .. i .. ": more points, a higher entry, a bigger prize")
	end
	expect(Ranked.tier_of(0) == 1 and Ranked.tier_of(99) == 1 and Ranked.tier_of(100) == 2, "tier_of at the first edge")
	expect(Ranked.tier_of(999) == 4 and Ranked.tier_of(1000) == 5 and Ranked.tier_of(999999) == 5, "tier_of at the top")
	expect(Ranked.tier_of(-5) == 1 and Ranked.tier_of(0 / 0) == 1 and Ranked.tier_of("x") == 1, "tier_of with nonsense: the first tier")
end

print("a match's points")
local WIN = { spawned = true, left = false, won = true, minutes = 20, shares = 4, kills = 5, kills_h = 2, place = 1, field = 12, humans = 8 }
local LAST = { spawned = true, left = false, won = false, minutes = 3, shares = 1, kills = 0, kills_h = 0, place = 12, field = 12, humans = 8 }
do
	local s = Ranked.score(WIN, 1)
	expect(line_of(s.lines, "entry") == -Ranked.TIERS[1].fee, "the entry is taken from every match")
	expect(line_of(s.lines, "placed") == Ranked.PLACE_MAX and line_of(s.lines, "victory") == Ranked.WIN, "first of a full match: the whole place and victory points")
	expect(line_of(s.lines, "conquests") == 2 * Ranked.PER_HUMAN + 3 * Ranked.PER_BOT, "a real player is worth far more than a robot: " .. tostring(line_of(s.lines, "conquests")))
	expect(Ranked.PER_HUMAN >= 4 * Ranked.PER_BOT, "... at least four times")
	expect(s.total == -Ranked.TIERS[1].fee + Ranked.PLACE_MAX + Ranked.WIN + 15, "the total is the sum: " .. s.total)
	local l = Ranked.score(LAST, 1)
	expect(l.total < 0 and l.total == -Ranked.TIERS[1].fee, "last place: only the entry, so the points go down: " .. l.total)
	local top = Ranked.score(LAST, 5)
	expect(top.total == -Ranked.TIERS[5].fee and top.total < l.total, "the same bad match costs a Rei more: " .. top.total)
	-- the crowd: a win among robots is worth less than a win among players
	local alone = table.clone(WIN)
	alone.humans = 1
	alone.kills_h = 0
	local a = Ranked.score(alone, 1)
	expect(line_of(a.lines, "victory") < line_of(s.lines, "victory"), "a victory alone with robots is worth less")
	expect(math.abs(line_of(a.lines, "victory") - Ranked.WIN * Ranked.CROWD_MIN) <= 1, "... CROWD_MIN of it: " .. tostring(line_of(a.lines, "victory")))
	expect(a.total > 0, "... but a win still goes up: " .. a.total)
	local last = 0
	for h = 1, 12 do
		local c = Ranked.crowd(h)
		expect(c >= last and c <= 1, "the crowd never falls with more players (" .. h .. ")")
		last = c
	end
	expect(Ranked.crowd(Ranked.CROWD_FULL) == 1 and Ranked.crowd(100) == 1 and Ranked.crowd(nil) == Ranked.CROWD_MIN, "the crowd's ends")
	-- leaving early: the entry is lost, nothing for the place
	local quit = table.clone(WIN)
	quit.left = true
	quit.won = false
	local q = Ranked.score(quit, 1)
	expect(line_of(q.lines, "placed") == nil and line_of(q.lines, "victory") == nil and line_of(q.lines, "entry") ~= nil, "leaving early: no place points, the entry is lost")
	expect(Ranked.score({ spawned = false }, 1).total == 0 and #Ranked.score(nil, 1).lines == 0, "never spawned: nothing moves")
	-- a result made up to cheat is cut to what a match can hold
	local fake = Ranked.score({ spawned = true, won = true, place = 1, field = 2, kills = 1e9, kills_h = 1e9, humans = 1e9 }, 1)
	expect(fake.total <= Ranked.PLACE_MAX + Ranked.WIN + Ranked.PER_HUMAN * Stars.MAX_KILLS, "a made-up result is capped: " .. fake.total)
end

print("the state and the season")
local NOV = brt(2026, 11, 12, 10)
local DEC = brt(2026, 12, 1, 0, 5)
do
	local st = Ranked.clean(nil)
	expect(st.points == 0 and st.games == 0 and st.month == 0, "an empty state")
	local dirty = Ranked.clean({ points = -4, games = "x", wins = 1 / 0, month = 0 / 0, peak = 7.9 })
	expect(dirty.points == 0 and dirty.games == 0 and dirty.month == 0 and dirty.peak == 7, "a dirty state is made safe")
	local out = Ranked.apply(st, NOV, WIN)
	expect(out.delta == out.total and st.points == out.total and st.games == 1 and st.wins == 1, "a win adds its points")
	expect(st.month == Missions.month(NOV) and out.closed == nil, "the state is this month's; nothing closed")
	local before = st.points
	local bad = Ranked.apply(st, NOV + 3600, LAST)
	expect(bad.delta < 0 and st.points == before + bad.delta and st.games == 2 and st.wins == 1, "a bad match takes points away")
	-- never below zero
	local low = Ranked.clean({ month = Missions.month(NOV), points = 2, games = 1 })
	local l = Ranked.apply(low, NOV, LAST)
	expect(low.points == 0 and l.delta == -2 and l.total == -Ranked.TIERS[1].fee, "the points never go below 0 (delta says what really moved)")
	-- promotion and demotion are reported
	local edge = Ranked.clean({ month = Missions.month(NOV), points = 95, games = 3 })
	local up = Ranked.apply(edge, NOV, WIN)
	expect(up.before == 1 and up.tier == 2, "crossing 100: Escudeiro -> Cavaleiro")
	local down = Ranked.clean({ month = Missions.month(NOV), points = 103, games = 3, peak = 103 })
	local d = Ranked.apply(down, NOV, LAST)
	expect(d.before == 2 and d.tier == 1 and down.peak == 103, "a loss may drop a tier; the peak stays")
	-- the month turns
	local v = Ranked.view(down, DEC)
	expect(v.points == 0 and v.tier == 1 and v.name == "Escudeiro" and v.next == 100, "a state of last month reads as Escudeiro, 0")
	expect(v.ends > DEC and v.ends - DEC < 32 * 86400, "the view says when the season ends")
	local closed = Ranked.roll(down, DEC)
	expect(closed ~= nil and closed.tier == 2 and closed.stars == Ranked.TIERS[2].prize and closed.month == Missions.month(NOV), "the season closes on the best tier reached (Cavaleiro), with its prize")
	expect(down.points == 0 and down.games == 0 and down.peak == 0 and down.month == Missions.month(DEC), "... and everything starts from zero")
	expect(Ranked.roll(down, DEC + 60) == nil, "the same month again: nothing closes twice")
	local idle = Ranked.clean({ month = Missions.month(NOV), points = 0, games = 0 })
	expect(Ranked.roll(idle, DEC) == nil, "a player who played no ranked match has no season to close")
	local text = Ranked.season_text(closed)
	expect(string.find(text, "novembro", 1, true) ~= nil and string.find(text, "Cavaleiro", 1, true) ~= nil and string.find(text, "1000", 1, true) ~= nil, "the notice names the month, the tier and the prize: " .. text)
	expect(Ranked.line(Ranked.view({ month = Missions.month(NOV), points = 142 }, NOV)) == "Cavaleiro  ·  142 / 300", "the lobby's line")
	expect(Ranked.line(Ranked.view({ month = Missions.month(NOV), points = 1240 }, NOV)) == "Rei  ·  1240", "the top tier has no next")
end

print("the server: points in the same write as the Coroas")
local rows = {}
local writes = 0
local store = {}
function store:UpdateAsync(k, fn)
	local new = fn(rows[k])
	if new ~= nil then
		rows[k] = new
		writes += 1
	end
	return new
end
function store:GetAsync(k)
	return rows[k]
end
local P = { UserId = 77, Name = "Ana" }
local clock = NOV
local pushed = {}
Purchases.reset()
Purchases.configure({
	datastore = store,
	players = {
		GetPlayerByUserId = function(_, id)
			return if id == 77 then P else nil
		end,
	},
	now = function()
		return clock
	end,
	inventory = function(_p, inv)
		table.insert(pushed, inv)
	end,
})
local sent = {}
local seasons = {}
Rewards.reset()
Rewards.configure({
	add_stars = Purchases.add_stars,
	missions = true,
	send = function(_, payload)
		table.insert(sent, payload)
	end,
	now = function()
		return 1000
	end,
	season_closed = function(_p, closed)
		table.insert(seasons, closed)
	end,
})
Purchases.load(P)
do
	local inv0 = Purchases.inventory(P)
	expect(type(inv0.ranked) == "table" and inv0.ranked.points == 0 and inv0.ranked.now == clock, "the inventory carries the ranked state and the server's clock")
	expect(inv0.ranked_last == nil, "no closed season yet")
	local a = Purchases.ranked_state(P)
	a.points = 999
	expect(Purchases.ranked_state(P).points == 0, "ranked_state hands out a copy")

	-- a classic match: Coroas, no points
	local paid = Rewards.pay(P, WIN, "public")
	expect(paid > 0 and sent[#sent].ranked == nil, "a classic match pays Coroas and sends no ranked part")
	expect(Purchases.inventory(P).ranked.points == 0 and Purchases.inventory(P).ranked.games == 0, "... and moves no points")

	-- a ranked win
	local w0 = writes
	local stars0 = Purchases.inventory(P).stars
	local paid2 = Rewards.pay(P, WIN, "public", true)
	local msg = sent[#sent]
	local expected = Ranked.score(WIN, 1).total
	expect(writes == w0 + 1, "one write for the Coroas and the points together (" .. (writes - w0) .. ")")
	-- (the return counts the Coroas of the missions a match completed, which differ from one match
	-- to the next: the match's own payout is the message's total)
	local base = Stars.payout(WIN, "public", false).total
	expect(paid2 > 0 and msg.total - (line_of(msg.lines, "missions") or 0) == base, "a ranked match pays the same Coroas as a classic one: " .. tostring(msg.total))
	expect(Purchases.inventory(P).stars > stars0, "the Coroas arrived")
	expect(type(msg.ranked) == "table" and msg.ranked.total == expected and msg.ranked.delta == expected and msg.ranked.points == expected, "the client is told the points: " .. tostring(msg.ranked and msg.ranked.total))
	expect(msg.ranked.before == 1 and msg.ranked.tier == Ranked.tier_of(expected), "... and the tier before and after")
	local st = Purchases.inventory(P).ranked
	expect(st.points == expected and st.games == 1 and st.wins == 1 and st.month == Missions.month(NOV), "the record keeps them")
	expect(rows["u77"].ranked.points == expected, "... in the store too")

	-- 2x Coroas doubles the Coroas, never the points
	Rewards.reset()
	Rewards.configure({
		add_stars = Purchases.add_stars,
		missions = true,
		double = function()
			return true
		end,
		send = function(_, payload)
			table.insert(sent, payload)
		end,
		now = function()
			return 1000
		end,
		season_closed = function(_p, closed)
			table.insert(seasons, closed)
		end,
	})
	local before = Purchases.inventory(P).ranked.points
	local paid3 = Rewards.pay(P, WIN, "public", true)
	local tier_now = Ranked.tier_of(before)
	expect(sent[#sent].ranked.total == Ranked.score(WIN, tier_now).total, "with 2x Coroas the points are the same: " .. sent[#sent].ranked.total)
	local dm = sent[#sent]
	expect(paid3 > 0 and line_of(dm.lines, "double") == base and dm.total - (line_of(dm.lines, "missions") or 0) == 2 * base, "... while the Coroas are doubled: " .. tostring(dm.total))

	-- a bad match: nothing to pay in Coroas worth a line, the points still fall
	local b0 = Purchases.inventory(P).ranked.points
	Rewards.pay(P, LAST, "public", true)
	local bad = sent[#sent]
	expect(type(bad.ranked) == "table" and bad.ranked.delta < 0 and Purchases.inventory(P).ranked.points == b0 + bad.ranked.delta, "a bad ranked match takes points away: " .. tostring(bad.ranked and bad.ranked.delta))

	-- never spawned: nothing at all
	local n0, g0 = #sent, Purchases.inventory(P).ranked.games
	Rewards.pay(P, { spawned = false, left = true, won = false, minutes = 0, shares = 0, kills = 0, place = 12, field = 12 }, "public", true)
	expect(Purchases.inventory(P).ranked.games == g0, "a player who never spawned played no ranked match")
	expect(#sent == n0 or sent[#sent].ranked == nil or sent[#sent].ranked.delta == 0, "... and is told of no points")
end

print("the server: the season closes once and pays")
do
	local st = Purchases.inventory(P).ranked
	local stars0 = Purchases.inventory(P).stars
	local peak_tier = Ranked.tier_of(math.max(st.points, st.peak))
	expect(Purchases.ranked_settle(P) == nil, "the same month: nothing to settle")
	clock = DEC
	local closed = Purchases.ranked_settle(P)
	expect(closed ~= nil and closed.month == Missions.month(NOV) and closed.points == st.points and closed.tier == peak_tier, "December: November's season closes")
	local inv = Purchases.inventory(P)
	expect(inv.stars == stars0 + Ranked.TIERS[peak_tier].prize, "the tier's Coroas are paid (" .. (inv.stars - stars0) .. ")")
	expect(inv.ranked.points == 0 and inv.ranked.games == 0 and inv.ranked.month == Missions.month(DEC), "everyone starts again from zero")
	expect(type(inv.ranked_last) == "table" and inv.ranked_last.month == Missions.month(NOV) and inv.ranked_last.games == st.games, "the record remembers the last season")
	expect(Purchases.ranked_settle(P) == nil and Purchases.inventory(P).stars == inv.stars, "settling again pays nothing")
	-- a player who was not settled on arrival: the first ranked match of the new month closes it
	local Q = { UserId = 78, Name = "Bia" }
	rows["u78"] = { ranked = { month = Missions.month(NOV), points = 650, games = 9, wins = 3, peak = 700 }, stars = 10 }
	Purchases.load(Q)
	local n0 = #seasons
	Rewards.pay(Q, LAST, "public", true)
	local invq = Purchases.inventory(Q)
	expect(#seasons == n0 + 1 and seasons[#seasons].tier == 4 and seasons[#seasons].stars == Ranked.TIERS[4].prize, "the first ranked match of the month closes the old season (Duque)")
	expect(invq.stars >= 10 + Ranked.TIERS[4].prize, "... and pays it: " .. invq.stars)
	expect(invq.ranked.games == 1 and invq.ranked.points == 0 and invq.ranked.month == Missions.month(DEC), "... then counts the match in the new one, from zero")
	expect(sent[#sent].ranked.before == 1, "the match was played as an Escudeiro (the new season's entry)")
end

print("the client keeps it safe")
do
	local r = Session.clean_ranked_award({ lines = { { "entry", -6 }, { "placed", 40 }, { 3, 4 }, { "x", 0 / 0 } }, total = 34, delta = 34, points = 134, tier = 2, before = 1 })
	expect(r ~= nil and #r.lines == 2 and r.total == 34 and r.tier == 2 and r.before == 1, "a ranked payout is read")
	expect(Session.clean_ranked_award(nil) == nil and Session.clean_ranked_award("x") == nil, "nothing: nil")
	local w = Session.clean_ranked_award({ lines = "x", total = 1 / 0, delta = "a", points = -3, tier = 99, before = 0 })
	expect(w.total == 100000 and w.delta == 0 and w.points == 0 and w.tier == #Ranked.TIERS and w.before == 1 and #w.lines == 0, "nonsense is clamped")
	expect(Session._season_of(nil) == nil and Session._season_of({ month = 0 }) == nil, "no season: nil")
	local s = Session._season_of({ month = 682, points = 310, tier = 3, stars = 3000, games = 12, wins = 4 })
	expect(s.tier == 3 and s.stars == 3000 and s.games == 12, "a closed season is read")
end

print(string.format("ranqueada: %d checks, %d failed", checks, fails))
if fails > 0 then
	error("ranqueada failed")
end
