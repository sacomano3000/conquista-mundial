--!nocheck
-- The global ranking's server side (server/Ranking): what a public match adds, the two lists, a
-- player's own totals, how often the stores are read, what a failing store does.
--   lune run tests/ranking.luau
local F = require("./simsys_fixture")
local Defs, Ev = F.Defs, F.Ev
local Stars = require("../src/shared/Data/Stars")
local Ranking = require("../src/server/Ranking")
-- (this file is about the all-time lists, exactly as they were before the weekly ones came:
-- tests/ranking_semanal.luau has those)
Ranking.WEEKLY_ON = false
local Protocol = require("../src/shared/Net/Protocol")
local fs = require("@lune/fs")

local fails, checks = 0, 0
local function ok(cond: any, what: string)
	checks += 1
	if not cond then
		fails += 1
		print("FAIL " .. what)
	end
end

-- ---------------------------------------------------------------------------------------------
-- A stand-in for Roblox's ordered stores, a clock that only moves when told, and the names.
-- ---------------------------------------------------------------------------------------------
local clock = 1000.0
local waited = {}
local calls = { sorted = 0, get = 0, inc = 0, names = 0 }
local fail = { sorted = nil, get = nil, inc = {}, names = false }
local stores = {}
local order = 0

local function store(board)
	local st = stores[board]
	if st ~= nil then
		return st
	end
	local rows, seq = {}, {}
	st = { rows = rows }
	function st.IncrementAsync(_, key, delta)
		calls.inc += 1
		local e = table.remove(fail.inc, 1)
		if e ~= nil and e ~= false then
			if e == "landed" then
				-- (the request landed and its answer was lost)
				rows[key] = (rows[key] or 0) + delta
				error("HTTP 500 (the answer never came)")
			end
			error(e)
		end
		assert(type(key) == "string" and delta == math.floor(delta) and delta > 0, "a whole, positive addition under a text key")
		if rows[key] == nil then
			order += 1
			seq[key] = order
		end
		rows[key] = (rows[key] or 0) + delta
		return rows[key]
	end
	function st.GetAsync(_, key)
		calls.get += 1
		if fail.get then
			error(fail.get)
		end
		return rows[key]
	end
	function st.GetSortedAsync(_, ascending, size)
		calls.sorted += 1
		if fail.sorted then
			error(fail.sorted)
		end
		assert(ascending == false and size <= 100, "best first, one page of at most 100")
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
	--- another server of the game wrote this
	function st.put(key, value)
		if rows[key] == nil then
			order += 1
			seq[key] = order
		end
		rows[key] = value
	end
	stores[board] = st
	return st
end

local NAMES = {}
local online = {}
local function fresh()
	Ranking.reset()
	table.clear(stores)
	table.clear(waited)
	table.clear(fail.inc)
	table.clear(online)
	fail.sorted, fail.get, fail.names = nil, nil, false
	for k in calls do
		calls[k] = 0
	end
	clock += 10000
end
Ranking.configure({
	store = store,
	names = function(ids)
		calls.names += 1
		if fail.names then
			error("names are down")
		end
		local out = {}
		for _, id in ids do
			out[id] = NAMES[id]
		end
		return out
	end,
	now = function()
		return clock
	end,
	wait = function(s)
		table.insert(waited, s)
		clock += s
	end,
	online = function(uid)
		return online[uid] ~= false
	end,
})

local function result(won, kills, extra)
	local r = { spawned = true, left = false, won = won, minutes = 12, shares = 3, kills = kills, place = 1, field = 20 }
	for k, v in extra or {} do
		r[k] = v
	end
	return r
end
local function player(uid, name)
	return { UserId = uid, DisplayName = name, Name = "user" .. uid }
end

-- =============================================================================================
print("what a result adds")
do
	local d = Ranking.deltas(result(true, 4))
	ok(d.wins == 1 and d.kills == 4, "a win with four nations conquered: 1 and 4")
	d = Ranking.deltas(result(false, 2))
	ok(d.wins == 0 and d.kills == 2, "a lost match keeps its conquests")
	d = Ranking.deltas(result(true, 3, { spawned = false }))
	ok(d.wins == 0 and d.kills == 0, "a player who never spawned adds nothing")
	d = Ranking.deltas(result(true, 3, { left = true }))
	ok(d.wins == 0 and d.kills == 3, "a player who left early has no win, and keeps the conquests")
	d = Ranking.deltas(result(false, 5000))
	ok(d.kills == Ranking.MAX_KILLS and Ranking.MAX_KILLS == Stars.MAX_KILLS, "no more than a match has nations")
	d = Ranking.deltas(result(false, 2.9))
	ok(d.kills == 2, "whole nations only")
	for _, junk in { -3, 0 / 0, math.huge, "many", {}, false } do
		local j = Ranking.deltas(result("yes", junk))
		ok(j.wins == 0 and j.kills == 0, "junk adds nothing (" .. tostring(junk) .. ")")
	end
	d = Ranking.deltas(nil)
	ok(d.wins == 0 and d.kills == 0, "no result: nothing")
end

-- =============================================================================================
print("the match's own count: bots count, tribes don't")
do
	local sim = F.new_sim(1)
	local H = F.owner(sim, "Human", Defs.KIND_HUMAN, 0, 10000)
	local B1 = F.owner(sim, "Bot one", Defs.KIND_NATION, 0, 10000)
	local B2 = F.owner(sim, "Bot two", Defs.KIND_NATION, 0, 10000)
	local P2 = F.owner(sim, "Other player", Defs.KIND_HUMAN, 0, 10000)
	local T1 = F.owner(sim, "Tribe", Defs.KIND_TRIBE, 0, 10000)
	F.claim(sim, H, 690, 100, 6)
	F.claim(sim, B1, 716, 100, 5)
	F.claim(sim, B2, 760, 120, 4)
	F.claim(sim, P2, 730, 140, 4)
	F.claim(sim, T1, 690, 130, 3)
	sim.winner = 0
	local tr = Stars.Tracker.new(sim)
	tr:watch(H)
	tr:watch(P2)
	tr:step({})
	tr:step({ { Ev.OWNER_OUT, B2, P2 }, { Ev.OWNER_OUT, B1, H }, { Ev.OWNER_OUT, T1, H }, { Ev.OWNER_OUT, P2, H } })
	local d = Ranking.deltas(tr:result(H))
	ok(d.kills == 2 and d.wins == 0, "a bot nation and a player count, the tribe doesn't; no win while the match goes on")
	sim.phase = Defs.PHASE_OVER
	sim.winner = H
	d = Ranking.deltas(tr:result(H, true))
	ok(d.wins == 1 and d.kills == 2, "the winner of the finished match: one win")
	d = Ranking.deltas(tr:result(P2))
	ok(d.wins == 0 and d.kills == 1, "the player who fell: no win, the bot they conquered counts")
end

-- =============================================================================================
print("a result reaches the two stores")
do
	fresh()
	ok(Ranking.record(11, result(true, 3), "Ana") == true, "a win with three conquests is recorded")
	ok(store("wins").rows["11"] == 1 and store("kills").rows["11"] == 3, "1 in the wins store, 3 in the conquests store, under the user id")
	ok(calls.inc == 2, "two additions")
	Ranking.record(11, result(false, 0), "Ana")
	ok(calls.inc == 2, "a lost match without conquests writes nothing")
	Ranking.record(11, result(false, 2), "Ana")
	ok(calls.inc == 3 and store("wins").rows["11"] == 1 and store("kills").rows["11"] == 5, "conquests alone: one addition, the wins untouched")
	Ranking.record(11, result(true, 0), "Ana")
	ok(store("wins").rows["11"] == 2 and store("kills").rows["11"] == 5, "a win alone")
	for _, bad in { 0, -4, 0 / 0, "x", false } do
		ok(Ranking.record(bad, result(true, 3)) == false, "no user id, nothing recorded")
	end
	ok(calls.inc == 4, "and nothing written for them")
	ok(Ranking.pending() == 0, "nothing left on its way")
end

-- =============================================================================================
print("the lists")
do
	fresh()
	NAMES = { [1] = "Ana", [2] = "Bruno", [3] = "Caio", [4] = "Dani" }
	Ranking.record(1, result(true, 2))
	Ranking.record(2, result(true, 9))
	Ranking.record(2, result(true, 1))
	Ranking.record(3, result(false, 4))
	Ranking.record(2, result(true, 0))
	-- (those were other servers' matches: this server knows only what the stores say)
	Ranking.reset()
	local p = Ranking.get(player(3, "Caio"))
	ok(p.ok == true and p.age == 0, "the lists came")
	local w, k = p.boards.wins, p.boards.kills
	ok(#w == 2 and w[1][1] == 2 and w[1][2] == "Bruno" and w[1][3] == 3, "wins: Bruno first with 3")
	ok(w[2][1] == 1 and w[2][2] == "Ana" and w[2][3] == 1, "then Ana with 1; Caio, without a win, is not in it")
	ok(#k == 3 and k[1][1] == 2 and k[1][3] == 10 and k[2][1] == 3 and k[2][3] == 4 and k[3][1] == 1 and k[3][3] == 2, "conquests: 10, 4, 2")
	ok(p.me.wins[1] == 0 and p.me.wins[2] == nil, "Caio's wins: 0, no place")
	ok(p.me.kills[1] == 4 and p.me.kills[2] == 2, "Caio's conquests: 4, second place")
	ok(calls.sorted == 2, "one read of each list")
	ok(calls.names == 1, "one request of names: the second list had nobody this server did not know")
	-- a second look, by someone else, a minute later: the same lists, no new read of them
	clock += 60
	local q = Ranking.get(player(4, "Dani"))
	ok(calls.sorted == 2, "a list is not read again within " .. Ranking.REFRESH_S .. " s")
	ok(q.age == 60 and #q.boards.wins == 2, "it says how old it is")
	ok(q.me.wins[1] == 0 and q.me.kills[1] == 0 and q.me.kills[2] == nil, "a player who never played a public match: zeros")
	-- past the refresh time it is read again, and shows what other servers added meanwhile
	store("wins").put("4", 7)
	clock += Ranking.REFRESH_S
	q = Ranking.get(player(4, "Dani"))
	ok(calls.sorted == 4, "then it is read again")
	ok(q.boards.wins[1][1] == 4 and q.boards.wins[1][3] == 7 and q.me.wins[2] == 1, "and the new leader is there")
	ok(q.boards.wins[1][2] == "Dani", "with their name")
	ok(q.age == 0, "fresh again")
end

-- =============================================================================================
print("a player's own totals are never behind their row")
do
	fresh()
	NAMES = { [1] = "Ana", [2] = "Bruno", [3] = "Caio" }
	store("wins").put("1", 5)
	store("wins").put("2", 3)
	store("wins").put("3", 2)
	local p = Ranking.get(player(3, "Caio"))
	ok(p.me.wins[1] == 2 and p.me.wins[2] == 3, "third with 2")
	-- Caio leaves, wins two matches on another server, comes back before the list is read again
	Ranking.release(3)
	store("wins").put("3", 4)
	clock += 30
	local sorted = calls.sorted
	p = Ranking.get(player(3, "Caio"))
	ok(calls.sorted == sorted, "the list was not read again")
	ok(p.me.wins[1] == 4 and p.me.wins[2] == 2, "his total is the new one, and his row moved up to second")
	ok(p.boards.wins[2][1] == 3 and p.boards.wins[2][3] == 4 and p.boards.wins[3][1] == 2, "the list shows it")
	-- the other way round: a total this server read a moment ago is older than a list just read
	-- (a match that ended elsewhere in between): the list's row is not pulled back
	do
		Ranking.reset()
		clock += 1000
		Ranking.get(player(1, "Ana"))
		clock += Ranking.REFRESH_S - 10
		local q = Ranking.get(player(2, "Bruno"))
		ok(q.me.wins[1] == 3, "(Bruno's total, read now: 3)")
		store("wins").put("2", 6)
		clock += 15
		q = Ranking.get(player(2, "Bruno"))
		ok(q.boards.wins[1][1] == 2 and q.boards.wins[1][3] == 6, "a list newer than the player's total keeps its number: 6, first")
		ok(q.me.wins[1] == 6 and q.me.wins[2] == 1, "and his own row says the same")
		store("wins").put("2", 3)
		Ranking.reset()
		clock += 1000
		Ranking.get(player(3, "Caio"))
	end
	-- a match that ends on this very server: no wait at all
	Ranking.record(2, result(true, 1), "Bruno")
	Ranking.record(2, result(true, 0), "Bruno")
	Ranking.record(2, result(true, 0), "Bruno")
	p = Ranking.get(player(2, "Bruno"))
	ok(p.me.wins[1] == 6 and p.me.wins[2] == 1, "three wins here: Bruno leads with 6")
	ok(p.boards.wins[1][1] == 2 and p.boards.wins[2][1] == 1, "above Ana")
	ok(p.me.kills[1] == 1 and p.me.kills[2] == 1 and p.boards.kills[1][2] == "Bruno", "and his conquest is on the other list, with his name")
	-- someone not in a list of fewer rows than the limit comes in with their first win
	Ranking.record(9, result(true, 0), "Nina")
	p = Ranking.get(player(9, "Nina"))
	ok(p.me.wins[1] == 1 and p.me.wins[2] == 4 and p.boards.wins[4][2] == "Nina", "a first win: last of four, by name")
end

-- =============================================================================================
print("a hundred rows, no more")
do
	fresh()
	NAMES = {}
	for uid = 1, 150 do
		store("wins").put(tostring(uid), 1000 - uid)
		NAMES[uid] = "P" .. uid
	end
	local p = Ranking.get(player(120, "P120"))
	ok(#p.boards.wins == Ranking.TOP and Ranking.TOP == 100, "the list has 100 rows")
	ok(p.boards.wins[1][1] == 1 and p.boards.wins[100][1] == 100, "the best hundred, in order")
	ok(p.me.wins[1] == 880 and p.me.wins[2] == nil, "the 120th has their number and no place")
	local sorted_ok = true
	for i = 2, #p.boards.wins do
		if p.boards.wins[i - 1][3] < p.boards.wins[i][3] then
			sorted_ok = false
		end
	end
	ok(sorted_ok, "never a row above one with more")
	-- the 120th wins enough to pass the 100th
	for _ = 1, 25 do
		Ranking.record(120, result(true, 0), "P120")
	end
	p = Ranking.get(player(120, "P120"))
	ok(#p.boards.wins == 100, "still 100 rows")
	ok(p.me.wins[1] == 905 and p.me.wins[2] == 96, "905 wins: 96th")
	ok(p.boards.wins[95][1] == 95 and p.boards.wins[95][3] == 905, "behind the player who had 905 first (a tie does not pass who was there)")
	ok(p.boards.wins[97][3] == 904 and p.boards.wins[100][1] == 99, "above 904, and the old 100th is out")
	Ranking.record(120, result(true, 0), "P120")
	p = Ranking.get(player(120, "P120"))
	ok(p.me.wins[1] == 906 and p.me.wins[2] == 95, "one more win: 95th")
	ok(p.boards.wins[94][1] == 94 and p.boards.wins[96][1] == 95, "past the one with 905, behind the one who had 906 first")
end

-- =============================================================================================
print("a store that fails")
do
	fresh()
	NAMES = { [1] = "Ana" }
	store("wins").put("1", 5)
	fail.sorted = "502: the store is down"
	local p = Ranking.get(player(1, "Ana"))
	ok(p.ok == false and #p.boards.wins == 0, "no list: it says so")
	ok(p.me.wins[1] == 5, "the player's own total, read by itself, still shows")
	local n = calls.sorted
	clock += 5
	Ranking.get(player(1, "Ana"))
	ok(calls.sorted == n, "a failed read is not tried again at once")
	clock += Ranking.FAIL_S
	fail.sorted = nil
	p = Ranking.get(player(1, "Ana"))
	ok(p.ok == true and p.boards.wins[1][1] == 1 and p.me.wins[2] == 1, "after " .. Ranking.FAIL_S .. " s it is, and the list is there")
	-- with a list in hand, a failing refresh keeps it
	clock += Ranking.REFRESH_S
	fail.sorted = "502"
	p = Ranking.get(player(1, "Ana"))
	ok(p.ok == true and #p.boards.wins == 1 and p.age >= Ranking.REFRESH_S, "a refresh that fails leaves the old list, and its age grows")
	fail.sorted = nil
	-- the totals' read failing: what this server knew stays
	clock += Ranking.MINE_S + Ranking.FAIL_S
	fail.get = "502"
	p = Ranking.get(player(1, "Ana"))
	ok(p.me.wins[1] == 5 and p.me.wins[2] == 1, "the totals' read failing: the row still says 5")
	fail.get = nil
	-- names down: the rows come without names, and get them at the next read
	fresh()
	store("wins").put("1", 5)
	store("wins").put("2", 3)
	fail.names = true
	p = Ranking.get(player(2, "Bruno"))
	ok(p.ok and p.boards.wins[1][2] == "" and p.boards.wins[2][2] == "Bruno", "names down: an empty name, but the player's own")
	fail.names = false
	NAMES = { [1] = "Ana" }
	clock += Ranking.REFRESH_S
	p = Ranking.get(player(2, "Bruno"))
	ok(p.boards.wins[1][2] == "Ana", "the name comes with the next read")
end

-- =============================================================================================
print("an addition is never lost to a busy store, and never counted twice")
do
	fresh()
	fail.inc = { "OrderedDataStore request was throttled. TooManyRequests", "request dropped: the queue was full" }
	ok(Ranking.record(5, result(true, 0), "Eva") == true, "two refusals, then it lands")
	ok(store("wins").rows["5"] == 1, "counted once")
	ok(#waited == 2 and waited[1] == Ranking.RETRY_S[1] and waited[2] == Ranking.RETRY_S[2], "after the waits")
	-- a failure that is not a refusal may have landed: sending it again would count the match twice
	table.clear(waited)
	fail.inc = { "landed" }
	ok(Ranking.record(5, result(true, 0), "Eva") == false, "an answer that never came: reported as lost")
	ok(store("wins").rows["5"] == 2 and #waited == 0, "and not sent again (it had landed)")
	-- refused every time: given up, nothing counted
	fail.inc = { "Throttled", "Throttled", "Throttled", "Throttled", "Throttled" }
	local before = calls.inc
	ok(Ranking.record(5, result(true, 0), "Eva") == false, "refused every time: lost")
	ok(calls.inc - before == #Ranking.RETRY_S + 1 and store("wins").rows["5"] == 2, "after " .. (#Ranking.RETRY_S + 1) .. " tries, nothing added")
	table.clear(fail.inc)
	-- one board failing does not stop the other
	fail.inc = { "502" }
	ok(Ranking.record(6, result(true, 4), "Leo") == false, "the wins' addition failing")
	ok(store("wins").rows["6"] == nil and store("kills").rows["6"] == 4, "the conquests still land")
	ok(Ranking.pending() == 0, "nothing left on its way")
end

-- =============================================================================================
print("nothing is kept for a player who has left")
do
	fresh()
	online[7] = false
	Ranking.record(7, result(true, 2), "Gil")
	local gets = calls.get
	local p = Ranking.get(player(7, "Gil"))
	ok(calls.get == gets + 2, "their totals are read from the stores, not from a leftover")
	ok(p.me.wins[1] == 1 and p.me.kills[1] == 2, "and are right")
	-- the totals of a player who is here are read at most every MINE_S
	gets = calls.get
	clock += 10
	Ranking.get(player(7, "Gil"))
	ok(calls.get == gets, "not read again within " .. Ranking.MINE_S .. " s")
	clock += Ranking.MINE_S
	Ranking.get(player(7, "Gil"))
	ok(calls.get == gets + 2, "then read again")
	Ranking.release(7)
	Ranking.get(player(7, "Gil"))
	ok(calls.get == gets + 4, "and after a release")
end

-- =============================================================================================
print("the wire and the server's wiring")
do
	local OP = Protocol.OP
	ok(OP.RANK_GET == 50 and OP.RANK == 51, "the two ops")
	local seen, dup = {}, false
	for _, v in OP do
		if seen[v] then
			dup = true
		end
		seen[v] = true
	end
	ok(not dup, "no op number is used twice")
	local src = fs.readFile("src/server/ServerMain.luau")
	local a = string.find(src, "on_result = function", 1, true)
	local b = string.find(src, "make_sim = function", 1, true)
	local hook = string.sub(src, a, b)
	ok(string.find(hook, "Ranking.record", 1, true) ~= nil, "a public match's result is recorded")
	local _, n = string.gsub(src, "Ranking%.record,", "")
	ok(n == 1, "and that is the only place: a solo result never is")
	local solo = string.sub(src, string.find(src, "op == OP.SOLO_RESULT", 1, true) or 1)
	solo = string.sub(solo, 1, 1200)
	ok(string.find(solo, "Rewards.solo_result", 1, true) ~= nil and string.find(solo, "Ranking", 1, true) == nil, "the solo result's handler has nothing of the ranking")
	ok(
		string.find(src, "else Ranking.STORES[board]", 1, true) ~= nil
			and string.find(src, 'local name = base .. (if RunService:IsStudio() then "_studio" else "")', 1, true) ~= nil,
		"Studio playtests write stores of their own"
	)
	ok(string.find(src, "GetOrderedDataStore", 1, true) ~= nil, "ordered stores")
	ok(string.find(src, "op == OP.RANK_GET", 1, true) ~= nil and string.find(src, "ServerMain.RANK_GAP_S", 1, true) ~= nil, "the request is answered, and not too often")
	ok(string.find(src, "Ranking.release(player.UserId)", 1, true) ~= nil, "a leaving player is released")
	ok(string.find(src, "Ranking.settle(", 1, true) ~= nil, "a closing server waits for the additions on their way")
	ok(Ranking.STORES.wins ~= Ranking.STORES.kills, "two stores")
end

print(string.format("ranking: %d checks, %d failed", checks, fails))
if fails > 0 then
	error("ranking tests failed")
end
