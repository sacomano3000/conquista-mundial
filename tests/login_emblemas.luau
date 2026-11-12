--!nocheck
-- The daily login reward (shared/Data/Login; server/Purchases.login_claim), the wins and kingdoms of a
-- player's life (Purchases' `stats`, the title's card) and the Roblox badges (shared/Data/Badges,
-- shared/Data/MyBadges, server/BadgeAwards). The owner, 2026-11-12.
--   lune run tests/login_emblemas.luau
require("./prelude")
local Missions = require("../src/shared/Data/Missions")
local Login = require("../src/shared/Data/Login")
local Ranked = require("../src/shared/Data/Ranked")
local Badges = require("../src/shared/Data/Badges")
local MyBadges = require("../src/shared/Data/MyBadges")
local Purchases = require("../src/server/Purchases")
local Rewards = require("../src/server/Rewards")
local BadgeAwards = require("../src/server/BadgeAwards")
local Session = require("../src/client/Session")
local fs = require("@lune/fs")

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

print("the seven days")
do
	expect(Login.DAYS == 7, "seven days")
	local want = { 500, 750, 1000, 1500, 2000, 3000 }
	for i, n in want do
		expect(Login.REWARDS[i].stars == n and Login.REWARDS[i].crate == nil, "day " .. i .. " pays " .. n .. " Coroas")
	end
	expect(Login.REWARDS[7].crate == 1 and Login.REWARDS[7].stars == nil, "day 7 is a free crate")
	local st = Login.clean(nil)
	expect(st.day == 0 and st.streak == 0, "a new player: nothing taken")
	local d1 = brt(2026, 11, 12, 9)
	local p = Login.peek(st, d1)
	expect(p.available and p.index == 1 and p.reward.stars == 500, "the first day is day 1")
	local got = Login.claim(st, d1)
	expect(got.index == 1 and st.streak == 1 and st.day == Missions.day(d1), "taking it is remembered")
	expect(Login.claim(st, d1 + 3600) == nil and Login.claim(st, brt(2026, 11, 12, 23, 59)) == nil, "once a day (Brasília's day)")
	local again = Login.peek(st, d1 + 60)
	expect(not again.available and again.index == 1 and again.next == 2, "taken: tomorrow's is day 2")
	-- the days in a row
	for i = 2, 7 do
		local g = Login.claim(st, brt(2026, 11, 11 + i, 0, 1))
		expect(g ~= nil and g.index == i, "the day after: day " .. i)
	end
	expect(st.streak == 7, "the seventh day taken")
	local g8 = Login.claim(st, brt(2026, 11, 19, 12))
	expect(g8.index == 1 and g8.reward.stars == 500, "after the seventh it starts again from day 1")
	-- a day missed
	local g9 = Login.claim(st, brt(2026, 11, 20, 12))
	expect(g9.index == 2, "the next day: day 2")
	local miss = Login.claim(st, brt(2026, 11, 22, 12))
	expect(miss.index == 1 and miss.reward.stars == 500, "a day missed goes back to day 1")
	-- the clock going backwards gives nothing
	expect(Login.claim(st, brt(2026, 11, 21, 12)) == nil, "a day before the last one taken gives nothing")
	-- nonsense
	local bad = Login.clean({ day = "x", streak = 99 })
	expect(bad.day == 0 and bad.streak == 0, "a dirty state with no day: empty")
	local bad2 = Login.clean({ day = 20000, streak = 99 })
	expect(bad2.streak == 7, "a streak is 1..7")
	expect(Login.text(3, Login.REWARDS[3]) == "Recompensa diária, dia 3 de 7: +1000 Coroas. Volte amanhã: +1500 Coroas.", "the notice: " .. Login.text(3, Login.REWARDS[3]))
	expect(string.find(Login.text(6, Login.REWARDS[6]), "Volte amanhã: 1 baú grátis", 1, true) ~= nil, "day 6 promises the crate")
	expect(string.find(Login.text(7, Login.REWARDS[7]), "1 baú grátis", 1, true) ~= nil and string.find(Login.text(7, Login.REWARDS[7]), "recomeça", 1, true) ~= nil, "day 7: the crate, and it starts again")
end

print("the server pays it once a day")
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
local P = { UserId = 91, Name = "Lia" }
local clock = brt(2026, 11, 12, 10)
Purchases.reset()
Purchases.configure({
	datastore = store,
	players = {
		GetPlayerByUserId = function(_, id)
			return if id == 91 then P else nil
		end,
	},
	now = function()
		return clock
	end,
})
Rewards.reset()
Rewards.configure({ add_stars = Purchases.add_stars, missions = true, now = function()
	return 1000
end })
Purchases.load(P)
do
	local inv0 = Purchases.inventory(P)
	expect(inv0.login.day == 0 and inv0.stats.wins == 0 and inv0.stats.kills == 0, "a new player's inventory: no login, no wins, no kingdoms")
	local s0, c0 = inv0.stars, Purchases.credits(P).crate or 0
	local got = Purchases.login_claim(P)
	expect(got ~= nil and got.index == 1 and Purchases.inventory(P).stars == s0 + 500, "the first arrival of the day pays day 1")
	local w = writes
	expect(Purchases.login_claim(P) == nil and writes == w and Purchases.inventory(P).stars == s0 + 500, "the second arrival pays nothing and writes nothing")
	local earned0 = rows.u91.stars_earned
	local total = 500
	for i = 2, 6 do
		clock += 86400
		local g = Purchases.login_claim(P)
		total += Login.REWARDS[i].stars
		expect(g ~= nil and g.index == i and Purchases.inventory(P).stars == s0 + total, "day " .. i .. " pays its Coroas")
	end
	expect(total == 8750, "six days: 8.750 Coroas in all")
	expect(rows.u91.stars_earned == earned0, "a gift is not earnings of a match")
	clock += 86400
	local bought = Purchases.inventory(P).crates_bought
	local g7 = Purchases.login_claim(P)
	expect(g7 ~= nil and g7.index == 7 and (Purchases.credits(P).crate or 0) == c0 + 1, "day 7 gives a crate to open")
	expect(Purchases.inventory(P).stars == s0 + total and Purchases.inventory(P).crates_bought == bought, "... with no Coroas, and it is not a crate bought")
	expect(Purchases.inventory(P).login.streak == 7, "the inventory says the streak")
	clock += 3 * 86400
	local back = Purchases.login_claim(P)
	expect(back.index == 1, "three days away: day 1 again")
	-- leaving and coming back keeps it
	Purchases.reset()
	Purchases.configure({ datastore = store, now = function()
		return clock
	end })
	Purchases.load(P)
	expect(Purchases.inventory(P).login.streak == 1 and Purchases.login_claim(P) == nil, "the record keeps the day taken")
end

print("a player's life: wins and kingdoms")
local WIN = { spawned = true, left = false, won = true, minutes = 20, shares = 4, kills = 5, kills_h = 2, place = 1, field = 12, humans = 8 }
do
	Rewards.pay(P, WIN, "public")
	local st = Purchases.inventory(P).stats
	expect(st.wins == 1 and st.kills == 5, "a public win counts: 1 victory, 5 kingdoms")
	Rewards.pay(P, { spawned = true, left = false, won = false, minutes = 9, shares = 2, kills = 3, place = 4, field = 12 }, "public", true)
	st = Purchases.inventory(P).stats
	expect(st.wins == 1 and st.kills == 8, "a ranked match counts its kingdoms too")
	Rewards.pay(P, { spawned = true, left = true, won = true, minutes = 9, shares = 2, kills = 0, place = 1, field = 12 }, "public")
	expect(Purchases.inventory(P).stats.wins == 1, "leaving early is no victory")
	Rewards.solo_started(P, "solo2")
	Rewards.solo_result(P, { spawned = true, left = false, won = true, minutes = 1, shares = 3, kills = 9, place = 1, field = 30 })
	st = Purchases.inventory(P).stats
	expect(st.wins == 1 and st.kills == 8, "solo matches do not count")
	expect(rows.u91.stats.kills == 8, "the store keeps them")
	local c = Session._stats_of({ wins = "7", kills = -3 })
	expect(c.wins == 7 and c.kills == 0 and Session._stats_of(nil).wins == 0, "the client reads them safely")
end

print("the badges")
do
	local keys = {}
	for _, b in Badges.LIST do
		expect(type(b.key) == "string" and keys[b.key] == nil, "badge " .. tostring(b.key) .. " once")
		keys[b.key] = true
		expect(type(b.name) == "string" and #b.name >= 3 and #b.name <= 50, b.key .. ": a name Roblox takes")
		expect(type(b.text) == "string" and #b.text >= 10 and #b.text <= 1000, b.key .. ": a description")
		expect(MyBadges[b.key] ~= nil and type(MyBadges[b.key]) == "number", b.key .. ": a line in MyBadges")
		-- (an id is a whole number a Luau number holds exactly: 0, or the badge's asset id)
		expect(MyBadges[b.key] >= 0 and MyBadges[b.key] % 1 == 0 and MyBadges[b.key] < 2 ^ 53, b.key .. ": its id is a whole number")
		expect(fs.isFile("assets/emblemas/" .. b.image), b.key .. ": its picture is in assets/emblemas/ (" .. b.image .. ")")
	end
	for k in MyBadges do
		expect(keys[k] == true, "MyBadges." .. tostring(k) .. " is a badge of the list")
	end
	expect(#Badges.LIST == 8, "eight badges")
	local none = Badges.earned({ stats = { wins = 0, kills = 9 }, ranked = { points = 99 }, login = { day = 1, streak = 6 } })
	expect(next(none) == nil and next(Badges.earned(nil)) == nil, "nothing earned yet: none")
	local e = Badges.earned({ stats = { wins = 1, kills = 10 } })
	expect(e.first_win and e.kills_10 and not e.wins_10 and not e.kills_100, "the first victory and 10 kingdoms")
	e = Badges.earned({ stats = { wins = 10, kills = 100 } })
	expect(e.first_win and e.wins_10 and e.kills_10 and e.kills_100, "10 victories and 100 kingdoms")
	expect(Badges.earned({ ranked = { points = 100 } }).knight and not Badges.earned({ ranked = { points = 100 } }).king, "Cavaleiro at 100 points")
	expect(Badges.earned({ ranked = { points = 20, peak = 120 } }).knight, "... kept by the month's peak")
	expect(Badges.earned({ ranked = { points = 0 }, ranked_last = { tier = 5 } }).king, "Rei, by the season that closed")
	expect(Badges.earned({ ranked = { points = Ranked.TIERS[5].at } }).king, "Rei at its points")
	expect(Badges.earned({ badge = 2 }).champion and not Badges.earned({ badge = nil }).champion, "the weekly insignia is the champion's badge")
	expect(Badges.earned({ login = { day = 5, streak = 7 } }).login_7, "seven days in a row")
	-- the inventory the server really keeps says them (the player above: 1 victory, 8 kingdoms, a
	-- ranked match played)
	local real = Badges.earned(Purchases.inventory(P))
	expect(real.first_win == true and not real.kills_10 and not real.wins_10 and not real.login_7, "the server's inventory: the first victory, nothing else yet")
	Rewards.pay(P, { spawned = true, left = false, won = false, minutes = 9, shares = 2, kills = 2, place = 3, field = 12 }, "public")
	expect(Badges.earned(Purchases.inventory(P)).kills_10 == true, "... and at the tenth kingdom, the Conquistador")
	for _ = 1, 8 do
		Rewards.pay(P, { spawned = true, left = false, won = true, minutes = 30, shares = 60, kills = 11, kills_h = 7, place = 1, field = 12, humans = 8 }, "public", true)
	end
	local inv = Purchases.inventory(P)
	real = Badges.earned(inv)
	expect(inv.ranked.points >= 100 and real.knight == true, "eight ranked wins: a Cavaleiro (" .. tostring(inv.ranked.points) .. " points), with its badge")
	expect(not real.kills_100 and inv.stats.kills == 98, "98 kingdoms are not yet 100: " .. tostring(inv.stats.kills) .. " wins " .. tostring(inv.stats.wins))
end

print("giving them")
do
	local asked, awarded = {}, {}
	local owned = {}
	local fail = false
	local service = {}
	function service:UserHasBadgeAsync(uid, id)
		table.insert(asked, id)
		if fail then
			error("HTTP 500")
		end
		return owned[id] == true
	end
	function service:AwardBadge(uid, id)
		table.insert(awarded, { uid, id })
		owned[id] = true
		return true
	end
	local inv = { stats = { wins = 1, kills = 10 } }
	-- no ids: nothing is asked of Roblox
	BadgeAwards.reset()
	BadgeAwards.configure({ service = service, ids = {} })
	expect(#BadgeAwards.sync(P, inv) == 0 and #asked == 0, "no ids: nothing is given and Roblox is not asked")
	-- the badges the owner made on 2026-11-12 (read from badges.roblox.com for the game's universe),
	-- and the three still to make
	BadgeAwards.reset()
	BadgeAwards.configure({ service = service })
	local MADE = { first_win = 2521930147405894, kills_10 = 85899100414808, wins_10 = 1576615438298338, knight = 4429522879154910, login_7 = 1008929451862054 }
	for _, b in Badges.LIST do
		expect(MyBadges[b.key] == (MADE[b.key] or 0), "MyBadges." .. b.key .. " is the id of the badge made (0: not made yet): " .. string.format("%.0f", MyBadges[b.key]))
		expect(BadgeAwards.id_of(b.key) == (if MADE[b.key] then MADE[b.key] else nil), "... and that is the id the server gives: " .. tostring(BadgeAwards.id_of(b.key)))
	end
	-- as the game ships: a player with a first victory and 10 kingdoms gets those two, by their ids
	do
		local got = BadgeAwards.sync(P, inv)
		table.sort(got)
		expect(#got == 2 and got[1] == "first_win" and got[2] == "kills_10", "the shipped ids: the two badges earned are given (" .. table.concat(got, ", ") .. ")")
		expect(#awarded == 2 and awarded[1][2] == MADE.first_win and awarded[2][2] == MADE.kills_10, "... with the ids of the badges made")
		-- one not made yet (100 kingdoms) is not asked of Roblox
		local n = #asked
		expect(#BadgeAwards.sync(P, { stats = { wins = 1, kills = 100 } }) == 0 and #asked == n, "a badge with no id yet is not asked of Roblox")
		asked, awarded, owned = {}, {}, {}
	end
	-- with ids
	BadgeAwards.reset()
	BadgeAwards.configure({ service = service, ids = { first_win = 111, kills_10 = 0, wins_10 = 333 } })
	local out = BadgeAwards.sync(P, inv)
	expect(#out == 1 and out[1] == "first_win" and #awarded == 1 and awarded[1][1] == 91 and awarded[1][2] == 111, "the first victory's badge is given")
	expect(#BadgeAwards.sync(P, inv) == 0 and #awarded == 1 and #asked == 1, "... once: the next result asks nothing")
	inv.stats.wins = 10
	out = BadgeAwards.sync(P, inv)
	expect(#out == 1 and out[1] == "wins_10" and awarded[2][2] == 333, "10 victories: its badge")
	-- a badge the player already has is not given again
	BadgeAwards.forget(P)
	local n = #awarded
	expect(#BadgeAwards.sync(P, inv) == 0 and #awarded == n, "back on another visit: Roblox says they have them, nothing is given")
	-- Roblox not answering: tried again later
	BadgeAwards.forget(P)
	owned = {}
	fail = true
	local warned = 0
	BadgeAwards.configure({ service = service, ids = { first_win = 111 }, warn = function()
		warned += 1
	end })
	expect(#BadgeAwards.sync(P, inv) == 0 and warned == 1, "Roblox failing: a warning, nothing given")
	fail = false
	expect(#BadgeAwards.sync(P, inv) == 1, "... and the next result tries again")
	BadgeAwards.reset()
	expect(#BadgeAwards.sync(P, inv) == 0, "no service (outside Roblox): nothing happens")
end

print(string.format("login_emblemas: %d checks, %d failed", checks, fails))
if fails > 0 then
	error("login_emblemas failed")
end
