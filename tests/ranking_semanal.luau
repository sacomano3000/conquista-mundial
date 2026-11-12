--!nocheck
-- The weekly ranking (shared/Data/RankPrizes, server/Ranking, server/Purchases): the calendar, what
-- a result adds, the week turning, who a closed week pays and how much, the insignia and where it
-- travels (the inventory, the match's cosmetics, the chat's tag).
--   lune run tests/ranking_semanal.luau
local fs = require("@lune/fs")
local RankPrizes = require("../src/shared/Data/RankPrizes")
local Ranking = require("../src/server/Ranking")
local Purchases = require("../src/server/Purchases")
local Session = require("../src/client/Session")
local GameState = require("../src/shared/Core/GameState")
local ChatBadge = require("../src/client/UI/ChatBadge")
local Protocol = require("../src/shared/Net/Protocol")

local fails, checks = 0, 0
local function ok(cond: any, what: string)
	checks += 1
	if not cond then
		fails += 1
		print("FAIL " .. what)
	end
end

-- Monday 9 November 2026, 00:00 in Brasília (03:00 UTC)
local MONDAY = 1794193200
local DAY = 86400

-- =============================================================================================
print("the calendar and the prizes")
do
	ok(RankPrizes.week(MONDAY) == 2966 and RankPrizes.FIRST_WEEK == 2966, "the first week is the one of Monday 9 November 2026")
	ok(RankPrizes.week(MONDAY - 1) == 2965, "one second before Monday's midnight is still the week before")
	ok(RankPrizes.week(MONDAY + 7 * DAY - 1) == 2966, "Sunday 23:59:59 is the same week")
	ok(RankPrizes.week(MONDAY + 7 * DAY) == 2967, "the next Monday is the next week")
	ok(RankPrizes.week_start(2966) == MONDAY, "a week starts on its Monday")
	ok(#RankPrizes.COROAS == 10, "ten places are paid")
	local falling = true
	for i = 2, #RankPrizes.COROAS do
		falling = falling and RankPrizes.COROAS[i] < RankPrizes.COROAS[i - 1] and RankPrizes.COROAS[i] > 0
	end
	ok(falling, "whoever is ahead earns more, and the 10th still earns something")
	ok(RankPrizes.COROAS[1] <= 1000, "modest: the first place of a list earns at most 1000")
	ok(RankPrizes.coroas(1) == RankPrizes.COROAS[1] and RankPrizes.coroas(10) == RankPrizes.COROAS[10], "a place's Coroas")
	ok(RankPrizes.coroas(11) == 0 and RankPrizes.coroas(0) == 0 and RankPrizes.coroas(nil) == 0 and RankPrizes.coroas(2.5) == 0, "nothing outside the ten")
	ok(RankPrizes.badge(1) == 1 and RankPrizes.badge(2) == 2 and RankPrizes.badge(3) == 3, "the first three earn the insignia")
	ok(RankPrizes.badge(4) == nil and RankPrizes.badge(0) == nil and RankPrizes.badge("x") == nil and RankPrizes.badge(1.5) == nil, "nobody else does")
	ok(RankPrizes.badge_image(2) == "rbxasset://own/badge/2" and RankPrizes.badge_image(4) == "", "the insignia's picture")
	ok(RankPrizes.best(3, 1) == 1 and RankPrizes.best(nil, 2) == 2 and RankPrizes.best(4, nil) == 4 and RankPrizes.best(nil, nil) == nil, "the best of two places")
	ok(RankPrizes.left_text(3 * DAY + 4 * 3600 + 59) == "3d 4h", "days and hours left")
	ok(RankPrizes.left_text(5 * 3600 + 12 * 60) == "5h 12min", "hours and minutes left")
	ok(RankPrizes.left_text(8 * 60) == "8min" and RankPrizes.left_text(5) == "1min" and RankPrizes.left_text(-9) == "1min", "minutes left, never less than one")
	local art = fs.readFile("src/shared/Assets/OwnArtData.luau")
	for n = 1, 3 do
		ok(string.find(art, '["rbxasset://own/badge/' .. n .. '"] = "badge/' .. n .. '"', 1, true) ~= nil, "insignia " .. n .. " is drawn by the game")
	end
end

-- ---------------------------------------------------------------------------------------------
-- Ordered stores by (board, week), a wall clock and a waiting clock that only move when told.
-- ---------------------------------------------------------------------------------------------
local wall = MONDAY + 2 * DAY -- Wednesday of week 2966
local clock = 1000.0
local calls = { sorted = 0, get = 0, inc = 0 }
local fail_sorted = nil
local stores = {}
local order = 0
local function store(board, week)
	local key = if week ~= nil then board .. "@" .. tostring(week) else board
	local st = stores[key]
	if st ~= nil then
		return st
	end
	local rows, seq = {}, {}
	st = { rows = rows }
	function st.IncrementAsync(_, k, delta)
		calls.inc += 1
		if rows[k] == nil then
			order += 1
			seq[k] = order
		end
		rows[k] = (rows[k] or 0) + delta
		return rows[k]
	end
	function st.GetAsync(_, k)
		calls.get += 1
		return rows[k]
	end
	function st.GetSortedAsync(_, ascending, size)
		calls.sorted += 1
		if fail_sorted then
			error(fail_sorted)
		end
		assert(ascending == false and size <= 100)
		local page = {}
		for k, v in rows do
			table.insert(page, { key = k, value = v })
		end
		table.sort(page, function(a, b)
			if a.value ~= b.value then
				return a.value > b.value
			end
			return (seq[a.key] or 0) < (seq[b.key] or 0)
		end)
		for i = #page, size + 1, -1 do
			page[i] = nil
		end
		return {
			GetCurrentPage = function()
				return page
			end,
		}
	end
	function st.put(k, v)
		if rows[k] == nil then
			order += 1
			seq[k] = order
		end
		rows[k] = v
	end
	stores[key] = st
	return st
end
local function fresh(at)
	Ranking.reset()
	table.clear(stores)
	fail_sorted = nil
	for k in calls do
		calls[k] = 0
	end
	wall = at or (MONDAY + 2 * DAY)
	clock += 10000
end
Ranking.WEEKLY_ON = true
Ranking.configure({
	store = store,
	names = function(ids)
		local out = {}
		for _, id in ids do
			out[id] = "P" .. id
		end
		return out
	end,
	now = function()
		return clock
	end,
	time = function()
		return wall
	end,
	wait = function(s)
		clock += s
	end,
	online = function()
		return true
	end,
})
local function result(won, kills)
	return { spawned = true, left = false, won = won, minutes = 12, shares = 3, kills = kills, place = 1, field = 20 }
end
local function player(uid)
	return { UserId = uid, DisplayName = "P" .. uid, Name = "p" .. uid }
end

-- =============================================================================================
print("a result goes to the all-time list and to the week's")
do
	fresh()
	ok(Ranking.week() == 2966, "the week now")
	ok(Ranking.record(7, result(true, 3), "P7") == true, "the result landed")
	ok(store("wins").rows["7"] == 1 and store("kills").rows["7"] == 3, "the all-time stores have it")
	ok(store("wins", 2966).rows["7"] == 1 and store("kills", 2966).rows["7"] == 3, "and so do this week's")
	ok(calls.inc == 4, "four additions: two boards, each in two stores")
	Ranking.record(8, result(false, 5), "P8")
	ok(store("wins", 2966).rows["8"] == nil and store("kills", 2966).rows["8"] == 5, "no win, no weekly win")
	local p = Ranking.get(player(7))
	ok(p.ok == true, "the lists came")
	ok(#p.boards.wins == 1 and #p.boards.wins_w == 1 and p.boards.wins_w[1][1] == 7 and p.boards.wins_w[1][3] == 1, "the weekly victories list")
	ok(#p.boards.kills_w == 2 and p.boards.kills_w[1][1] == 8 and p.boards.kills_w[1][3] == 5 and p.boards.kills_w[2][1] == 7, "the weekly kingdoms list, best first")
	ok(p.me.wins_w[1] == 1 and p.me.wins_w[2] == 1 and p.me.kills_w[1] == 3 and p.me.kills_w[2] == 2, "the player's own weekly numbers and places")
	ok(type(p.week) == "table" and p.week.n == 2966, "the payload says which week it is")
	ok(p.week.left == 5 * DAY, "and how long is left of it (Wednesday 00:00: five days)")
	local e = Ranking.empty()
	ok(e.ok == false and type(e.boards.wins_w) == "table" and e.me.kills_w[1] == 0, "the payload of a ranking that failed has the weekly boards too")
end

-- =============================================================================================
print("Monday: the weekly lists start empty, the all-time ones go on")
do
	fresh()
	Ranking.record(7, result(true, 3), "P7")
	Ranking.get(player(7))
	wall = MONDAY + 7 * DAY + 60 -- Monday 00:01 of week 2967
	clock += 5
	local p = Ranking.get(player(7))
	ok(p.week.n == 2967, "a new week")
	ok(#p.boards.wins_w == 0 and #p.boards.kills_w == 0, "the weekly lists are empty")
	ok(p.me.wins_w[1] == 0 and p.me.wins_w[2] == nil and p.me.kills_w[1] == 0, "and so are the player's weekly numbers")
	ok(#p.boards.wins == 1 and p.me.wins[1] == 1 and p.me.kills[1] == 3, "the world rank keeps everything")
	ok(store("wins", 2966).rows["7"] == 1, "last week's store still has last week's numbers")
	Ranking.record(7, result(true, 1), "P7")
	ok(store("wins", 2967).rows["7"] == 1 and store("wins", 2966).rows["7"] == 1, "a new result goes to the new week only")
	ok(store("wins").rows["7"] == 2, "and to the all-time list")
	clock += 1
	p = Ranking.get(player(7))
	ok(#p.boards.wins_w == 1 and p.boards.wins_w[1][3] == 1 and p.me.wins_w[1] == 1, "the new week's list has the new result")
end

-- =============================================================================================
print("a closed week: who finished where, and what that pays")
local function fill_week(week)
	-- twelve players in the victories list (uid 101 best ... 112 last), three in the kingdoms one
	for i = 1, 12 do
		store("wins", week).put(tostring(100 + i), 30 - i)
	end
	store("kills", week).put("105", 40)
	store("kills", week).put("101", 20)
	store("kills", week).put("200", 10)
end
do
	fresh()
	fill_week(2966)
	-- still inside week 2966: nothing is closed yet
	local upto, res = Ranking.due(101, nil)
	ok(upto == 2965 and #res == 0, "while the week runs, it owes nothing")
	ok(calls.sorted == 0, "and nothing before the first week is read")
	-- Monday 00:05 of the next week: too soon
	wall = MONDAY + 7 * DAY + 300
	upto, res = Ranking.due(101, nil)
	ok(upto == nil and res == nil, "five minutes after the week closed: not yet")
	-- Monday 00:10
	wall = MONDAY + 7 * DAY + Ranking.SETTLE_DELAY_S
	upto, res = Ranking.due(101, nil)
	ok(upto == 2966 and #res == 1, "ten minutes after: the closed week is looked at")
	local r = res[1]
	ok(r.week == 2966 and r.wins == 1 and r.kills == 2, "first in victories, second in kingdoms")
	ok(r.stars == RankPrizes.coroas(1) + RankPrizes.coroas(2), "each list pays its place")
	ok(calls.sorted == 2, "two reads: one for each list")
	local _, r5 = Ranking.due(105, nil)
	ok(r5[1].wins == 5 and r5[1].kills == 1 and r5[1].stars == RankPrizes.coroas(5) + RankPrizes.coroas(1), "another player, other places")
	local _, r10 = Ranking.due(110, nil)
	ok(r10[1].wins == 10 and r10[1].kills == nil and r10[1].stars == RankPrizes.coroas(10), "the tenth is still paid")
	local u11, r11 = Ranking.due(111, nil)
	ok(u11 == 2966 and #r11 == 0, "the eleventh is not")
	local u0, r0 = Ranking.due(999, nil)
	ok(u0 == 2966 and #r0 == 0, "nor is someone who was not in the lists")
	ok(calls.sorted == 2, "a closed week is read once per server")
	local _, again = Ranking.due(101, 2966)
	ok(#again == 0, "a player settled up to that week is owed nothing more")
	-- a late addition to the closed week changes nothing here (the list was final when read)
	local f = Ranking.final(2966)
	ok(#f.wins == 10 and f.wins[1][1] == 101 and f.wins[10][1] == 110, "the final list: ten rows, best first")
end
do
	-- a store that fails: nothing is said, and it is asked again
	fresh(MONDAY + 7 * DAY + 3600)
	fill_week(2966)
	fail_sorted = "the store is down"
	local upto, res = Ranking.due(101, nil)
	ok(upto == nil and res == nil, "a failing store: nothing is paid and nothing is marked")
	fail_sorted = nil
	local reads = calls.sorted
	upto, res = Ranking.due(101, nil)
	ok(upto == nil and calls.sorted == reads, "a store that just failed is left alone for a moment (every RANK window asks)")
	clock += Ranking.FAIL_S + 1
	upto, res = Ranking.due(101, nil)
	ok(upto == 2966 and #res == 1, "the next try works")
end
do
	-- a player who stayed away: the last BACK_WEEKS closed weeks are still paid
	fresh(MONDAY + 3 * 7 * DAY + 3600) -- week 2969
	fill_week(2966)
	fill_week(2967)
	fill_week(2968)
	local upto, res = Ranking.due(101, nil)
	ok(upto == 2968 and #res == Ranking.BACK_WEEKS and res[1].week == 2967 and res[2].week == 2968, "two weeks back, oldest first; the third is gone")
	local _, res2 = Ranking.due(101, 2967)
	ok(#res2 == 1 and res2[1].week == 2968, "only the weeks after the one already settled")
end
do
	fresh(MONDAY + 7 * DAY + 3600)
	fill_week(2966)
	Ranking.WEEKLY_ON = false
	local upto, res = Ranking.due(101, nil)
	ok(upto == nil and res == nil, "WEEKLY_ON = false: no prizes")
	Ranking.record(7, result(true, 2), "P7")
	ok(store("wins", 2967).rows["7"] == nil and store("wins").rows["7"] == 1, "and no weekly store is written")
	local p = Ranking.get(player(7))
	ok(p.boards.wins_w == nil and p.week == nil, "and the payload has no weekly part")
	Ranking.WEEKLY_ON = true
end

-- =============================================================================================
print("the prizes land in the player's record once, with the insignia")
local rows = {}
local ds = {}
local ds_fail = false
function ds:UpdateAsync(k, fn)
	if ds_fail then
		error("the store is down")
	end
	local new = fn(rows[k])
	if new ~= nil then
		rows[k] = new
	end
	return new
end
function ds:GetAsync(k)
	return rows[k]
end
local pushed = {}
local P = { UserId = 101, Name = "p101" }
local function server()
	Purchases.reset()
	Purchases.configure({
		datastore = ds,
		players = {
			GetPlayerByUserId = function(_, id)
				return if id == 101 then P else nil
			end,
		},
		now = function()
			return wall
		end,
		inventory = function(_p, inv)
			table.insert(pushed, inv)
		end,
	})
	Purchases.load(P)
end
do
	fresh(MONDAY + 7 * DAY + 3600) -- Monday 01:00 of week 2967
	fill_week(2966)
	server()
	local loaded, settled = Purchases.rank_week(P)
	ok(loaded == true and settled == nil, "a record nothing was written to yet")
	ok(Purchases.rank_week({ UserId = 5 }) == false, "a player whose record is not here yet: not now")
	ok(Purchases.rank_badge(P) == nil and Purchases.rank_last(P) == nil and Purchases.rank_claimable(P) == nil, "no insignia, no prize, nothing to claim yet")
	local before = Purchases.stars(P)
	local upto, res = Ranking.due(101, settled)
	table.clear(pushed)
	-- the server writes the week's result by itself: the insignia at once, the Coroas to be claimed
	local written = Purchases.rank_record(P, upto, res)
	local prize = RankPrizes.coroas(1) + RankPrizes.coroas(2)
	ok(written ~= nil and #written == 1, "one week written")
	ok(Purchases.stars(P) == before, "NOTHING is paid by itself: the balance is as it was")
	local place, on = Purchases.rank_badge(P)
	ok(place == 1 and on ~= nil and on.wins == 1 and on.kills == 2, "the insignia needs no claim: worn at once, and it knows where it was won")
	local c = Purchases.rank_claimable(P)
	ok(c ~= nil and c.total == prize and #c.weeks == 1 and c.weeks[1].week == 2966 and c.weeks[1].wins == 1 and c.weeks[1].kills == 2, "the Coroas of both lists wait to be claimed")
	local inv = pushed[#pushed]
	ok(inv ~= nil and inv.stars == before and inv.badge == 1, "the client is told: same balance, the insignia")
	ok(inv.badge_on ~= nil and inv.badge_on.wins == 1 and inv.badge_on.kills == 2, "where the insignia was won")
	ok(inv.rank_claim ~= nil and inv.rank_claim.total == prize, "and that there is a prize to claim (the RANK button's mark, the RESGATAR button)")
	ok(Purchases.rank_last(P) == nil, "nothing was claimed yet")
	local _, s2 = Purchases.rank_week(P)
	ok(s2 == 2966, "the record says up to which week it was written")
	-- again, same server
	local _, res2 = Ranking.due(101, s2)
	ok(#res2 == 0, "nothing more is to be written")
	local again = Purchases.rank_record(P, upto, res)
	ok(again ~= nil and #again == 0 and Purchases.rank_claimable(P).total == prize, "the same week written again adds nothing")
	-- another server of the game
	server()
	local third = Purchases.rank_record(P, upto, res)
	ok(#third == 0 and Purchases.rank_claimable(P).total == prize, "another server cannot write it twice")
	ok(Purchases.rank_badge(P) == 1, "the insignia is there on the other server too")
	-- a failing store changes nothing
	ds_fail = true
	local paid, total = Purchases.rank_claim(P)
	ds_fail = false
	ok(paid == nil and total == 0 and Purchases.stars(P) == before and Purchases.rank_claimable(P) ~= nil, "a store that fails pays nothing, and the prize is still there to claim")
	-- RESGATAR
	table.clear(pushed)
	paid, total = Purchases.rank_claim(P)
	ok(paid ~= nil and #paid == 1 and total == prize, "the claim pays the week's prize")
	ok(Purchases.stars(P) == before + prize, "the Coroas of both lists arrived")
	ok(#pushed >= 1 and pushed[#pushed].stars == before + prize and pushed[#pushed].rank_claim == nil, "the client is told the new balance, and that nothing is left to claim")
	ok(pushed[#pushed].badge == 1, "the insignia stays")
	ok(Purchases.rank_claimable(P) == nil, "nothing is left to claim")
	local last = Purchases.rank_last(P)
	ok(last.week == 2966 and last.wins == 1 and last.kills == 2 and last.stars == prize, "the last prize claimed is remembered")
	-- pressed again, and on another server
	paid, total = Purchases.rank_claim(P)
	ok(paid ~= nil and #paid == 0 and total == 0 and Purchases.stars(P) == before + prize, "a second press pays nothing")
	server()
	paid, total = Purchases.rank_claim(P)
	ok(#paid == 0 and total == 0 and Purchases.stars(P) == before + prize, "nor does another server")
	ok(Purchases.rank_record(P, upto, res) ~= nil and Purchases.rank_claimable(P) == nil, "and the week cannot be written a second time to be claimed again")
end
do
	-- the insignia lasts the week after the one it was won in
	wall = MONDAY + 2 * 7 * DAY - 1 -- Sunday 23:59:59 of week 2967
	ok(Purchases.rank_badge(P) == 1, "until the last second of the next week")
	ok(Purchases.inventory(P).badge == 1, "the inventory says so")
	wall = MONDAY + 2 * 7 * DAY + 1 -- week 2968
	ok(Purchases.rank_badge(P) == nil, "and is gone on Monday, before anything is written")
	ok(Purchases.inventory(P).badge == nil and Purchases.inventory(P).badge_on == nil, "the inventory too")
	ok(Purchases.rank_last(P) ~= nil, "what was claimed is still remembered")
end
do
	-- Monday: the insignia goes to the next winner; who stays in the top 3 keeps one
	-- week 2967: 102 wins the victories, 101 is second, 105 is out of the top 3
	rows = {}
	fresh(MONDAY + 7 * DAY + 3600)
	fill_week(2966)
	Purchases.reset()
	Purchases.configure({ datastore = ds, now = function()
		return wall
	end })
	local A, B, C = { UserId = 101, Name = "p101" }, { UserId = 102, Name = "p102" }, { UserId = 105, Name = "p105" }
	for _, pl in { A, B, C } do
		Purchases.load(pl)
		local upto, res = Ranking.due(pl.UserId, nil)
		Purchases.rank_record(pl, upto, res)
	end
	ok(Purchases.rank_badge(A) == 1 and Purchases.rank_badge(B) == 2 and Purchases.rank_badge(C) == 1, "week 2967: 101 gold (victories), 102 silver, 105 gold (kingdoms)")
	store("wins", 2967).put("102", 50)
	store("wins", 2967).put("101", 40)
	store("wins", 2967).put("120", 30)
	store("wins", 2967).put("105", 5)
	wall = MONDAY + 2 * 7 * DAY + 5 -- Monday 00:00:05 of week 2968: the lists are not read yet
	ok(Purchases.rank_badge(A) == nil and Purchases.rank_badge(B) == nil and Purchases.rank_badge(C) == nil, "Monday 00:00: last week's insignias come off, everyone's")
	wall = MONDAY + 2 * 7 * DAY + 3600
	for _, pl in { A, B, C } do
		local _, at = Purchases.rank_week(pl)
		local upto, res = Ranking.due(pl.UserId, at)
		Purchases.rank_record(pl, upto, res)
	end
	local pb, onb = Purchases.rank_badge(B)
	ok(pb == 1 and onb.wins == 1 and onb.kills == nil, "the new winner wears gold now")
	local pa, ona = Purchases.rank_badge(A)
	ok(pa == 2 and ona.wins == 2, "last week's winner stayed in the top 3: they wear the place they got this time, silver")
	ok(Purchases.rank_badge(C) == nil, "who fell out of the top 3 lost the insignia")
	ok(Purchases.rank_claimable(C).total == RankPrizes.coroas(5) + RankPrizes.coroas(1) + RankPrizes.coroas(4), "but their Coroas are all still there: last week's and this one's")
	-- the Coroas can be claimed up to CLAIM_WEEKS weeks later
	ok(RankPrizes.CLAIM_WEEKS == 2, "two weeks to claim")
	ok(RankPrizes.claimable(2966, 2967) and RankPrizes.claimable(2966, 2968), "a week's prize: claimable the next week and the one after")
	ok(not RankPrizes.claimable(2966, 2969) and not RankPrizes.claimable(2966, 2966) and not RankPrizes.claimable(2967, 2966), "not three weeks later, and not before the week closes")
	local ca = Purchases.rank_claimable(A)
	ok(#ca.weeks == 2 and ca.weeks[1].week == 2966 and ca.weeks[2].week == 2967, "101 has two weeks to claim, oldest first")
	ok(ca.total == RankPrizes.coroas(1) + RankPrizes.coroas(2) + RankPrizes.coroas(2), "their sum")
	wall = MONDAY + 3 * 7 * DAY + 3600 -- week 2969: week 2966's prize is past its time
	ca = Purchases.rank_claimable(A)
	ok(#ca.weeks == 1 and ca.weeks[1].week == 2967 and ca.total == RankPrizes.coroas(2), "a week later the older prize is gone, the newer one is still there")
	local before = Purchases.stars(A)
	local paid, total = Purchases.rank_claim(A)
	ok(#paid == 1 and total == RankPrizes.coroas(2) and Purchases.stars(A) == before + total, "the claim pays what can still be claimed, and only that")
	ok(Purchases.rank_claimable(A) == nil, "and nothing is left")
	wall = MONDAY + 4 * 7 * DAY + 3600 -- week 2970: 102 never claimed
	ok(Purchases.rank_claimable(B) == nil, "who never came for it: after two weeks there is no button any more")
	local b0 = Purchases.stars(B)
	paid, total = Purchases.rank_claim(B)
	ok(paid ~= nil and #paid == 0 and total == 0 and Purchases.stars(B) == b0, "and a claim sent anyway pays nothing")
end
do
	-- places 4 to 10: Coroas, no insignia; the first three of either list: the insignia of the best
	rows = {}
	P = { UserId = 110, Name = "p110" }
	fresh(MONDAY + 7 * DAY + 3600)
	fill_week(2966)
	Purchases.reset()
	Purchases.configure({ datastore = ds, now = function()
		return wall
	end })
	Purchases.load(P)
	local upto, res = Ranking.due(110, nil)
	local written = Purchases.rank_record(P, upto, res)
	ok(#written == 1 and Purchases.rank_claimable(P).total == RankPrizes.coroas(10), "the tenth has the tenth's Coroas to claim")
	ok(Purchases.rank_badge(P) == nil, "and no insignia")
	local _, total = Purchases.rank_claim(P)
	ok(total == RankPrizes.coroas(10) and Purchases.stars(P) == RankPrizes.coroas(10), "claimed")
	local Q = { UserId = 103, Name = "p103" }
	Purchases.load(Q)
	local u3, r3 = Ranking.due(103, nil)
	Purchases.rank_record(Q, u3, r3)
	ok(Purchases.rank_badge(Q) == 3 and Purchases.rank_claimable(Q).total == RankPrizes.coroas(3), "the third gets the third's insignia, and Coroas to claim")
	local R = { UserId = 200, Name = "p200" }
	Purchases.load(R)
	local u2, r2 = Ranking.due(200, nil)
	Purchases.rank_record(R, u2, r2)
	local pr, onr = Purchases.rank_badge(R)
	ok(pr == 3 and onr.kills == 3 and onr.wins == nil, "third in kingdoms alone earns it too")
	-- the eleventh: nothing to see
	local E = { UserId = 111, Name = "p111" }
	Purchases.load(E)
	local ue, re = Ranking.due(111, nil)
	local we = Purchases.rank_record(E, ue, re)
	ok(we ~= nil and #we == 0 and Purchases.rank_claimable(E) == nil and Purchases.inventory(E).rank_claim == nil, "who won nothing has nothing to claim: no button for them")
	-- junk in a stored record never becomes an insignia or a prize
	rows["u300"] = {
		rank_week = "x",
		rank_badge = { week = 2966, place = 7 },
		rank_last = { week = 2966, wins = -3, stars = "many" },
		rank_pending = { "x", { week = 2966, stars = 500 }, { week = "y", wins = 1, stars = 9 }, { week = 2966, wins = 2, stars = -4 } },
	}
	local J = { UserId = 300, Name = "p300" }
	Purchases.load(J)
	local loaded, settled = Purchases.rank_week(J)
	ok(loaded and settled == nil and Purchases.rank_badge(J) == nil, "a stored record with junk in it: no insignia, nothing written")
	local jl = Purchases.rank_last(J)
	ok(jl ~= nil and jl.wins == nil and jl.stars == 0, "its last prize is made safe")
	ok(Purchases.rank_claimable(J) == nil, "and its junk prizes are nothing to claim")
	local j0 = Purchases.stars(J)
	Purchases.rank_claim(J)
	ok(Purchases.stars(J) == j0, "claiming them pays nothing")
end

-- =============================================================================================
print("last week's champions: the lists every window gets")
do
	fresh(MONDAY + 2 * DAY)
	fill_week(2966)
	ok(Ranking.champions() == nil, "the first week still runs: no champions")
	local p0 = Ranking.get(player(101))
	ok(p0.boards.wins_l ~= nil and #p0.boards.wins_l == 0 and #p0.boards.kills_l == 0, "the payload has the two lists, empty")
	fresh(MONDAY + 7 * DAY + 300)
	fill_week(2966)
	ok(Ranking.champions() == nil and calls.sorted == 0, "five minutes into the new week: not yet, and nothing is read")
	fresh(MONDAY + 7 * DAY + 3600)
	fill_week(2966)
	local f = Ranking.champions()
	ok(f ~= nil and f.wins[1][1] == 101 and f.kills[1][1] == 105, "an hour in: last week's final lists")
	local lp = Ranking.last_places(101)
	ok(lp ~= nil and lp.wins == 1 and lp.kills == 2, "101: first in victories, second in kingdoms")
	local l3 = Ranking.last_places(103)
	ok(l3 ~= nil and l3.wins == 3 and l3.kills == nil, "103: third in victories")
	local l4 = Ranking.last_places(104)
	ok(l4 ~= nil and l4.wins == 4, "104: fourth (a prized place, no insignia)")
	ok(Ranking.last_places(111) == nil and Ranking.last_places(999) == nil, "the eleventh and a stranger: no prized place")
	local reads = calls.sorted
	local p = Ranking.get(player(101))
	local wl, kl = p.boards.wins_l, p.boards.kills_l
	ok(#wl == 10 and wl[1][1] == 101 and wl[1][2] == "P101" and wl[1][3] == 29, "the payload: last week's victories, with names and numbers: " .. tostring(wl[1] and wl[1][2]))
	ok(#kl == 3 and kl[1][1] == 105 and kl[3][1] == 200, "and last week's kingdoms")
	ok(p.me.wins_l ~= nil and p.me.wins_l[2] == 1 and p.me.kills_l[2] == 2, "and the player's own places in them")
	local again = Ranking.get(player(102))
	ok(#again.boards.wins_l == 10, "another player gets them too")
	local final_reads = 0
	for key in stores do
		if string.find(key, "@2966", 1, true) then
			final_reads += 1
		end
	end
	ok(final_reads == 2, "last week's two stores are the ones read")
	local e = Ranking.empty()
	ok(e.boards.wins_l ~= nil and #e.boards.wins_l == 0, "the empty payload has them too")
end

-- =============================================================================================
print("what reaches the client")
do
	local p = Session.clean_rank({
		ok = true,
		age = 3,
		boards = { wins = { { 1, "A", 9 } }, kills = {}, wins_w = { { 2, "B", 4 }, { 3, "C", 1 } }, kills_w = { { "x" } } },
		me = { wins = { 9, 1 }, kills = { 0 }, wins_w = { 1, 2 }, kills_w = { 0, 5 } },
		week = { n = 2966, left = 3600, badge = 2, last = { week = 2965, wins = 4, stars = 300 } },
	}, 100)
	ok(#p.boards.wins_w == 2 and p.boards.wins_w[1][2] == "B" and #p.boards.kills_w == 0, "the weekly lists, cleaned")
	ok(p.me.wins_w[1] == 1 and p.me.wins_w[2] == 2 and p.me.kills_w[2] == nil, "the player's weekly numbers; a place outside the list is dropped")
	ok(p.week.ends == 3700 and p.week.badge == 2, "when the week ends by this device's clock, and the insignia")
	ok(p.week.last.wins == 4 and p.week.last.kills == nil and p.week.last.stars == 300, "last week's prize")
	local q = Session.clean_rank({ ok = true, boards = {}, me = {}, week = { left = "soon", badge = 9, last = { stars = 5 } } }, 100)
	ok(q.week.ends == 100 and q.week.badge == nil and q.week.last == nil, "junk in the week's part never reaches the window")
	local old = Session.clean_rank({ ok = true, boards = { wins = {}, kills = {} }, me = {} }, 100)
	ok(old.week == nil and #old.boards.wins_w == 0 and old.me.kills_w[1] == 0, "a server without weekly lists: empty ones, and no week")
	ok(#old.boards.wins_l == 0 and #old.boards.kills_l == 0, "and no champions")
	-- last week's lists, and where the insignia was won
	local l = Session.clean_rank({
		ok = true,
		boards = { wins = {}, kills = {}, wins_l = { { 7, "Zé", 12 }, { "x", "y" }, { 8, "Lia", 9 } }, kills_l = { { 8, "Lia", 40 } } },
		me = {},
		week = { left = 60, badge = 1, badge_on = { wins = 2, kills = 1 } },
	}, 100)
	ok(#l.boards.wins_l == 2 and l.boards.wins_l[2][2] == "Lia" and #l.boards.kills_l == 1, "last week's lists, cleaned")
	ok(l.week.badge == 1 and l.week.badge_on.wins == 2 and l.week.badge_on.kills == 1, "the insignia and where it was won")
	local nb = Session.clean_rank({ ok = true, boards = {}, me = {}, week = { left = 60, badge_on = { wins = 1 } } }, 100)
	ok(nb.week.badge == nil and nb.week.badge_on == nil, "no insignia: nothing about where")
	local jb = Session.clean_rank({ ok = true, boards = {}, me = {}, week = { left = 60, badge = 2, badge_on = { wins = 9, kills = "x" } } }, 100)
	ok(jb.week.badge == 2 and jb.week.badge_on.wins == nil and jb.week.badge_on.kills == nil, "junk places are dropped")
	-- the prize to claim (it comes with the inventory)
	local c = Session.clean_claim({ total = 99999, weeks = { { week = 2966, wins = 1, kills = 12, stars = 1000.7 }, { week = 2967, kills = 3, stars = 500 } } })
	ok(c ~= nil and #c.weeks == 2 and c.total == 1500, "the claim: the weeks, and a total counted here, not taken on trust")
	ok(c.weeks[1].wins == 1 and c.weeks[1].kills == 12 and c.weeks[1].stars == 1000 and c.weeks[2].kills == 3, "each week's places and Coroas")
	ok(Session.clean_claim(nil) == nil and Session.clean_claim({}) == nil and Session.clean_claim({ weeks = {} }) == nil, "nothing to claim: nil (no button, no mark)")
	ok(Session.clean_claim({ weeks = { "x", { stars = 50 }, { wins = 1, stars = 0 }, { wins = 1, stars = -5 }, { wins = 0, stars = 9 } } }) == nil, "junk is not a prize")
	local many = {}
	for i = 1, 9 do
		many[i] = { wins = i, stars = 10 }
	end
	ok(#Session.clean_claim({ weeks = many }).weeks == 4, "never more than four weeks")
end
do
	local st = GameState.new()
	st:set_cosmetics({ [3] = { badge = 2 }, [4] = { skin = "stripes", badge = 7 }, [5] = { badge = "1" } }, true)
	ok(st.cosmetics[3] ~= nil and st.cosmetics[3].badge == 2, "an insignia alone travels with the match's cosmetics")
	ok(st.cosmetics[4].badge == nil and st.cosmetics[4].skin == "stripes", "a place that is not 1, 2 or 3 is dropped")
	ok(st.cosmetics[5] == nil, "and so is one that is not a number")
	st:set_cosmetics({ [3] = { badge = 1 } }, true)
	ok(st.cosmetics[3].badge == 1 and st.cosmetics[4] == nil, "a new insignia replaces the old")
	-- where it was won goes along (the card's words)
	local ch = st:set_cosmetics({ [3] = { badge = 1, bw = 1, bk = 3 }, [6] = { bw = 1 }, [7] = { badge = 2, bw = 9, bk = "x" } }, true)
	ok(st.cosmetics[3].bw == 1 and st.cosmetics[3].bk == 3, "the places that earned it travel with it")
	ok(st.cosmetics[6] == nil, "places without an insignia are nothing")
	ok(st.cosmetics[7].badge == 2 and st.cosmetics[7].bw == nil and st.cosmetics[7].bk == nil, "junk places are dropped")
	ok(type(ch) ~= "table" or table.find(ch, 3) ~= nil, "a change of place alone counts as a change")
end
do
	ok(ChatBadge.prefix(nil, "Ana:") == "Ana:" and ChatBadge.prefix(4, "Ana:") == "Ana:", "the chat: a player without the insignia is shown as before")
	local t = ChatBadge.prefix(1, "Ana:")
	ok(string.find(t, "[TOP 1]", 1, true) ~= nil and string.find(t, RankPrizes.BADGE_HEX[1], 1, true) ~= nil and string.sub(t, -4) == "Ana:", "first place: a gold tag before the name")
	ok(string.find(ChatBadge.prefix(3, "Bia:"), "[TOP 3]", 1, true) ~= nil, "third place: its own tag")
end
do
	local main = fs.readFile("src/server/ServerMain.luau")
	ok(string.find(main, 'player:SetAttribute("RankBadge", badge)', 1, true) ~= nil, "the server puts the insignia on the player for every client")
	ok(string.find(main, 'player:SetAttribute("RankBadgeWins"', 1, true) ~= nil and string.find(main, 'player:SetAttribute("RankBadgeKills"', 1, true) ~= nil, "and where it was won")
	ok(string.find(main, "eq.bw = ", 1, true) ~= nil and string.find(main, "eq.bk = ", 1, true) ~= nil, "a match's cosmetics carry that too")
	-- nothing is paid by itself any more
	ok(string.find(main, "rank_settle", 1, true) == nil, "the server no longer pays the prize by itself")
	ok(string.find(main, "Purchases.rank_record(player, upto, results)", 1, true) ~= nil, "it writes the result: the insignia, and the Coroas to claim")
	ok(string.find(main, "elseif op == OP.RANK_CLAIM then", 1, true) ~= nil and string.find(main, "pcall(Purchases.rank_claim, player)", 1, true) ~= nil, "the claim is its own request")
	ok(string.find(main, "if rank_claiming[player] then", 1, true) ~= nil, "one claim of a player at a time")
	ok(string.find(main, "if Purchases.rank_claimable(player) == nil then", 1, true) ~= nil, "with nothing to claim the store is not even asked")
	ok(string.find(main, "ServerMain.RANK_CLAIM_GAP_S", 1, true) ~= nil, "and it is asked only so often")
	ok(string.find(main, "send(player, OP.RANK_CLAIMED, paid ~= nil, got)", 1, true) ~= nil, "and it is answered")
	ok(Protocol.OP.RANK_CLAIM == 52 and Protocol.OP.RANK_CLAIMED == 53, "the two ops' numbers")
	ok(string.find(main, "ServerMain.RANK_WEEK_POLL_S", 1, true) ~= nil and string.find(main, "if w ~= seen then", 1, true) ~= nil, "the hub notices the week turning while players are there")
	local used = {}
	for name, n in Protocol.OP do
		ok(used[n] == nil, "op number " .. tostring(n) .. " is used once (" .. name .. ")")
		used[n] = true
	end
	ok(ChatBadge.ATTRIBUTE == "RankBadge", "the chat reads that attribute")
	ok(string.find(main, "eq.badge = badge", 1, true) ~= nil, "a match's cosmetics carry it")
	ok(string.find(main, "rank_prizes_soon(player)", 1, true) ~= nil and string.find(main, "pcall(rank_prizes, player)", 1, true) ~= nil, "prizes are looked at on arrival and when the RANK window opens")
	local ms = fs.readFile("src/server/MatchServer.luau")
	ok(string.find(ms, "badge = badge,", 1, true) ~= nil and string.find(ms, "bw = if badge ~= nil then c.bw else nil", 1, true) ~= nil, "the match server sends it to everyone")
	local lb = fs.readFile("src/client/UI/Leaderboard.luau")
	ok(string.find(lb, "self._ins:set(bn,", 1, true) ~= nil, "the match's list draws it beside the name")
	-- every screen with a name draws it through UI/Insignia (the card with the words comes with it)
	for file, what in {
		Leaderboard = "Insignia.new(c, 16)",
		TargetCard = "self._ins:set(",
		GameOver = "self._winner_ins:set(",
		PartyPanel = "Insignia.of_player(p)",
		Ranking = "Insignia.of_lists(boards, r[1])",
	} do
		local src = fs.readFile("src/client/UI/" .. file .. ".luau")
		ok(string.find(src, 'require("./Insignia")', 1, true) ~= nil and string.find(src, what, 1, true) ~= nil, file .. " shows the insignia beside the name")
	end
	ok(string.find(fs.readFile("src/client/UI/SpawnOverlay.luau"), "badge_image(cosmetics[h.id].badge)", 1, true) ~= nil, "the starting places' head shots show it")
	local ts = fs.readFile("src/client/UI/TitleScreen.luau")
	ok(string.find(ts, 'mark.name = "RankMark"', 1, true) ~= nil and string.find(ts, "self._rank_mark:set_visible(on)", 1, true) ~= nil, "the RANK button has its mark")
	local nl = fs.readFile("src/client/Map/NameLayer.luau")
	ok(string.find(nl, "RankPrizes.badge_image(rn)", 1, true) ~= nil, "the map's name draws it too")
	local cm = fs.readFile("src/client/Main.luau")
	ok(string.find(cm, 'optional(client, { "UI", "ChatBadge" })', 1, true) ~= nil, "the chat's tag starts with the client")
	-- the insignia cannot be bought or opened: no item, product or crate knows it
	for _, f in { "Cosmetics", "MyShop", "MyProducts", "Products" } do
		local src = fs.readFile("src/shared/Data/" .. f .. ".luau")
		ok(string.find(src, "badge", 1, true) == nil, f .. " has no insignia for sale")
	end
end

print(string.format("ranking_semanal: %d checks, %d failed", checks, fails))
if fails > 0 then
	error("ranking_semanal tests failed")
end
