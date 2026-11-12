--!nocheck
-- The owner's panel, on the server (2026-11-12: "crie um botão que só o dono consegue ver, que abre
-- um painel com tudo para configurar"):
--   * server/AdminActions: every request is refused to anyone who is not a game admin, and the
--     refusal carries nothing; the Coroas, the codes and the ranking through the panel's requests;
--   * server/Ranking.remove / find: a player leaves every list, here and in the stores;
--   * the wire and ServerMain: the ops, and the check before anything runs.
--   lune run tests/painel_admin.luau
require("./prelude")
local fs = require("@lune/fs")
local AdminActions = require("../src/server/AdminActions")
local CodeStore = require("../src/server/CodeStore")
local Ranking = require("../src/server/Ranking")
local RankPrizes = require("../src/shared/Data/RankPrizes")
local Protocol = require("../src/shared/Net/Protocol")

local checks, fails = 0, 0
local function ok(cond: any, what: string)
	checks += 1
	if not cond then
		fails += 1
		print("FAIL " .. what)
	end
end
local function has(text: any, part: string): boolean
	return type(text) == "string" and string.find(text, part, 1, true) ~= nil
end

local NOW = 1794268800 -- 2026-11-10 00:00 UTC
local MONDAY = 1794193200 -- Monday 9 November 2026, 00:00 in Brasília
local DAY = 86400

-- ---------------------------------------------------------------------------------------------
-- the code store (one key) and the players' balances
-- ---------------------------------------------------------------------------------------------
local function copy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = copy(x)
	end
	return out
end
local code_rows = {}
local code_store = {}
function code_store:GetAsync(k)
	return copy(code_rows[k])
end
function code_store:UpdateAsync(k, fn)
	local new = fn(copy(code_rows[k]))
	if new ~= nil then
		code_rows[k] = copy(new)
	end
	return new
end
local FIXED = { { code = "FIXO", stars = 250, active = true } }
CodeStore.reset()
CodeStore.configure({
	store = code_store,
	fixed = FIXED,
	clock = function()
		return 1000
	end,
})

local owner = { UserId = 1, Name = "Dono", DisplayName = "O Dono" }
local ana = { UserId = 22, Name = "ana_br", DisplayName = "Ana" }
local zeca = { UserId = 33, Name = "zeca", DisplayName = "Zeca" }
local balance = { [1] = 0, [22] = 100, [33] = 0 }
local adjusted = 0
local removed = {}
local rank_names = { ["campeao"] = 900, ["gemeo"] = 2 }
local deps = {
	is_owner = function(p)
		return p == owner
	end,
	players = function()
		return { owner, ana, zeca }
	end,
	adjust = function(uid, delta)
		adjusted += 1
		local old = balance[uid] or 0
		local new = math.max(0, old + delta)
		balance[uid] = new
		return true, new, new - old
	end,
	currency = "Coroas",
	store = CodeStore,
	now = function()
		return NOW
	end,
	random = function(n)
		return 1
	end,
	fixed = function()
		return FIXED
	end,
	rank_remove = function(uid)
		table.insert(removed, uid)
		return true, if uid == 404 then 0 else 3
	end,
	rank_find = function(name)
		local v = rank_names[string.lower(name)]
		if v == 900 then
			return 900, "Campeao"
		end
		return nil, v or 0
	end,
}

-- =============================================================================================
print("who may: nobody but the owner, for every action")
do
	for _, action in AdminActions.ACTIONS do
		local before_codes = copy(code_rows)
		local r = AdminActions.run(action, { op = "give", who = "ana_br", amount = "5000", code = "X", stars = "10" }, ana, deps)
		ok(r.ok == false and r.denied == true and r.text == AdminActions.DENIED, action .. ": refused to a player who is not the owner")
		ok(r.codes == nil and r.lines == nil and r.uid == nil, action .. ": the refusal carries no code, no line, no id")
		ok(next(code_rows) == next(before_codes), action .. ": and nothing was written")
	end
	ok(adjusted == 0 and balance[22] == 100 and #removed == 0, "no balance read or changed, nobody left the ranking")
	local r = AdminActions.run("coins", { op = "give", who = "eu", amount = "999" }, zeca, deps)
	ok(r.denied == true and balance[33] == 0, '"give me" from a player: refused')
	r = AdminActions.run("state", nil, nil, deps)
	ok(r.denied == true and r.codes == nil, "no sender at all: refused")
	r = AdminActions.run("state", nil, owner, { players = deps.players })
	ok(r.denied == true, "no way to tell who the owner is: refused (never open by default)")
	r = AdminActions.run("state", nil, owner, {
		is_owner = function()
			return "yes"
		end,
	})
	ok(r.denied == true, "is_owner must answer true itself")
	r = AdminActions.run({}, nil, ana, deps)
	ok(r.denied == true and r.action == "?", "a request that is not even a word: refused")
end

-- =============================================================================================
print("typed texts")
do
	local W = AdminActions.word
	ok(W("  Ana  Maria \n") == "Ana Maria", "spaces at the ends go, runs of spaces become one")
	ok(W("a\0b\tc\127d") == "a b c d", "control bytes become spaces")
	ok(W(5000) == "5000" and W(12.9) == "12", "a whole number is its digits")
	ok(W(nil) == "" and W({}) == "" and W(true) == "" and W(0 / 0) == "", "anything else is nothing")
	ok(W(string.rep("x", 48)) == string.rep("x", 48) and W(string.rep("x", 49)) == "", "at most 48 bytes")
	ok(W("João") == "João" and W("Jo\195") == "", "letters with accents pass; half a letter does not")
	ok(W("abcdef", 4) == "", "a field's own limit")
end

-- =============================================================================================
print("Coroas")
do
	local r = AdminActions.run("coins", { op = "give", who = "ana_br", amount = "5.000" }, owner, deps)
	ok(r.ok == true and r.action == "coins" and balance[22] == 5100, "give: the balance grows")
	ok(has(r.text, "+5.000 Coroas") and has(r.text, "ana_br"), "... and the answer says how much and to whom: " .. tostring(r.text))
	r = AdminActions.run("coins", { op = "take", who = "Ana", amount = "100" }, owner, deps)
	ok(r.ok == true and balance[22] == 5000, "take, by display name")
	r = AdminActions.run("coins", { op = "see", who = "22" }, owner, deps)
	ok(r.ok == true and has(r.text, "5.000 Coroas") and balance[22] == 5000, "see, by id: nothing changes")
	r = AdminActions.run("coins", { op = "give", who = "eu", amount = "2k" }, owner, deps)
	ok(r.ok == true and balance[1] == 2000, '"eu" is the owner; 2k is 2000')
	r = AdminActions.run("coins", { op = "give", who = "777", amount = 50 }, owner, deps)
	ok(r.ok == true and balance[777] == 50 and has(r.text, "ID 777"), "an id that is not on this server; a number as the amount")
	r = AdminActions.run("coins", { op = "give", who = "", amount = "5" }, owner, deps)
	ok(r.ok == false and has(r.text, "nome"), "no name: said so")
	r = AdminActions.run("coins", { op = "give", who = "ana_br", amount = "" }, owner, deps)
	ok(r.ok == false and has(r.text, "quantia") and balance[22] == 5000, "no amount: said so")
	r = AdminActions.run("coins", { op = "give", who = "ana_br", amount = "muitas" }, owner, deps)
	ok(r.ok == false and has(r.text, "inválida") and balance[22] == 5000, "a bad amount: said so")
	r = AdminActions.run("coins", { op = "give", who = "ninguem", amount = "5" }, owner, deps)
	ok(r.ok == false and has(r.text, "não está neste servidor"), "someone who is not here")
	r = AdminActions.run("coins", { op = "explode", who = "ana_br", amount = "5" }, owner, deps)
	ok(r.ok == false and balance[22] == 5000, "an unknown operation does nothing")
	-- a name that tries to be a command
	r = AdminActions.run("coins", { op = "see", who = "ana_br\n/moedas dar eu 999999" }, owner, deps)
	ok(r.ok == false and balance[1] == 2000, "a second line in the name is not a second command")
	r = AdminActions.run("coins", { op = "give", who = "ana_br", amount = "5 000 000" }, owner, deps)
	ok(balance[22] == 5005000 or r.ok == false, "an amount written with spaces is one number or nothing")
	balance[22] = 5000
end

-- =============================================================================================
print("codes")
do
	local r = AdminActions.run("state", nil, owner, deps)
	ok(r.ok == true and r.action == "state" and r.codes_read == true, "state: answered")
	ok(#r.codes == 1 and r.codes[1].code == "FIXO" and r.codes[1].fixed == true, "the place's own code is listed, marked as fixed")
	ok(has(r.codes[1].info, "250 Coroas") and r.codes[1].state == "ligado" and r.codes[1].on == true, "... with what it gives and how it stands")

	r = AdminActions.run("code_new", { code = "natal", stars = "5000", valid = "7", uses = "100" }, owner, deps)
	ok(r.ok == true and has(r.text, "NATAL"), "a named code: " .. tostring(r.text))
	local e = CodeStore.list()[1]
	ok(e ~= nil and e.code == "NATAL" and e.stars == 5000 and e.uses == 100, "it is in the store, with its Coroas and its limit of uses")
	ok(e.expires == (NOW // DAY + 7) * DAY + 86399, '"7" in the validity field is seven days')
	ok(#r.codes == 2 and r.codes[1].code == "NATAL" and r.codes[1].fixed == false, "the answer carries the new list, the made codes first")
	ok(has(r.codes[1].info, "5.000 Coroas") and has(r.codes[1].info, "0 de 100 usos") and has(r.codes[1].info, "até "), "... described")

	-- the field's hint says "7d or 31/12/2026": both forms, and the chat's "100x", are taken as written
	do
		local r2 = AdminActions.run("code_new", { code = "dica", stars = "10", valid = "7d", uses = "100x" }, owner, deps)
		local e2 = CodeStore.find("DICA", NOW)
		ok(r2.ok == true and e2 ~= nil and e2.expires == (NOW // DAY + 7) * DAY + 86399 and e2.uses == 100, '"7d" and "100x", as the hint and the chat write them: ' .. tostring(r2.text))
		r2 = AdminActions.run("code_new", { code = "dica2", stars = "10", valid = "31/12/2030" }, owner, deps)
		e2 = CodeStore.find("DICA2", NOW)
		ok(r2.ok == true and e2 ~= nil and e2.uses == nil and e2.expires == 1924991999, "a date as the validity (to the end of that day): " .. tostring(r2.text))
		ok(AdminActions.run("code_remove", { code = "DICA" }, owner, deps).ok == true and AdminActions.run("code_remove", { code = "DICA2" }, owner, deps).ok == true, "(both taken out again)")
	end

	r = AdminActions.run("code_new", { code = "", stars = "1k", valid = "31/12/2026", uses = "" }, owner, deps)
	ok(r.ok == true and #r.codes == 3, "no name: a random one")
	local random_code = nil
	for _, row in r.codes do
		if row.code ~= "NATAL" and row.code ~= "FIXO" then
			random_code = row.code
		end
	end
	ok(type(random_code) == "string" and string.match(random_code, "^%w%w%w%w%-%w%w%w%w$") ~= nil, "... like K7QM-X2PD: " .. tostring(random_code))
	ok(has(r.text, random_code), "the answer names it")

	r = AdminActions.run("code_new", { code = "NATAL", stars = "10" }, owner, deps)
	ok(r.ok == false and has(r.text, "Já existe") and #r.codes == 3, "the same name twice: refused, list unchanged")
	r = AdminActions.run("code_new", { code = "VAZIO", stars = "" }, owner, deps)
	ok(r.ok == false and has(r.text, "Coroas") and #r.codes == 3, "no amount: said so")
	r = AdminActions.run("code_new", { code = "RUIM", stars = "10", valid = "ontem" }, owner, deps)
	ok(r.ok == false and #r.codes == 3, "a validity that can't be read: refused")
	r = AdminActions.run("code_new", { code = "FIXO", stars = "10" }, owner, deps)
	ok(r.ok == false and #r.codes == 3, "a name of the place's own list: refused")

	local function row(reply, code)
		for _, x in reply.codes do
			if x.code == code then
				return x
			end
		end
		return {}
	end
	r = AdminActions.run("code_switch", { code = "NATAL", on = false }, owner, deps)
	ok(r.ok == true and row(r, "NATAL").on == false and row(r, "NATAL").state == "DESLIGADO", "switched off")
	ok(CodeStore.find("NATAL", NOW) == nil, "... and it pays nobody")
	ok(row(r, random_code).on == true and row(r, "FIXO").on == true, "... the others stay on")
	r = AdminActions.run("code_switch", { code = "natal", on = true }, owner, deps)
	ok(r.ok == true and row(r, "NATAL").on == true and CodeStore.find("NATAL", NOW) ~= nil, "switched on again (any case)")
	r = AdminActions.run("code_switch", { code = "NAOEXISTE", on = false }, owner, deps)
	ok(r.ok == false and has(r.text, "Não existe"), "a code that does not exist")
	r = AdminActions.run("code_switch", { code = "FIXO", on = false }, owner, deps)
	ok(r.ok == false and has(r.text, "MyCodes"), "the place's own code is changed in Studio: said so")
	r = AdminActions.run("code_remove", { code = "NATAL" }, owner, deps)
	ok(r.ok == true and #r.codes == 2 and CodeStore.find("NATAL", NOW) == nil, "deleted")
	r = AdminActions.run("code_remove", { code = "" }, owner, deps)
	ok(r.ok == false and has(r.text, "nome do código"), "no name: said so")
	r = AdminActions.run("code_remove", { code = "X Y\n/codigo apagar " .. random_code }, owner, deps)
	ok(r.ok == false and #r.codes == 2, "a second line in the name deletes nothing else")
end

-- =============================================================================================
print("the ranking, through the panel")
do
	local r = AdminActions.run("rank_remove", { who = "zeca" }, owner, deps)
	ok(r.ok == true and r.uid == 33 and removed[#removed] == 33 and has(r.text, "saiu do ranking"), "someone on this server, by name")
	r = AdminActions.run("rank_remove", { who = "123456" }, owner, deps)
	ok(r.ok == true and r.uid == 123456 and removed[#removed] == 123456, "anyone, by numeric id")
	r = AdminActions.run("rank_remove", { who = "Campeao" }, owner, deps)
	ok(r.ok == true and r.uid == 900 and removed[#removed] == 900 and has(r.text, "Campeao"), "someone of the lists who is not here, by the name the list shows")
	local n = #removed
	r = AdminActions.run("rank_remove", { who = "Gemeo" }, owner, deps)
	ok(r.ok == false and #removed == n and has(r.text, "ID"), "a name two rows have: the id is asked for, nobody is removed")
	r = AdminActions.run("rank_remove", { who = "fantasma" }, owner, deps)
	ok(r.ok == false and #removed == n, "a name nobody has: nobody is removed")
	r = AdminActions.run("rank_remove", { who = "" }, owner, deps)
	ok(r.ok == false and #removed == n, "no name: nobody is removed")
	r = AdminActions.run("rank_remove", { who = "404" }, owner, deps)
	ok(r.ok == true and has(r.text, "não estava"), "someone who was in no list: said so")
	local d2 = table.clone(deps)
	d2.rank_remove = function()
		return false, 1
	end
	r = AdminActions.run("rank_remove", { who = "zeca" }, owner, d2)
	ok(r.ok == false and has(r.text, "falhou"), "a store that fails: said so")
	d2.rank_remove = nil
	r = AdminActions.run("rank_remove", { who = "zeca" }, owner, d2)
	ok(r.ok == false, "a server without the ranking: said so")
	r = AdminActions.run("launch", {}, owner, deps)
	ok(r.ok == false and r.action == "launch" and r.denied == nil, "an unknown action does nothing")
end

-- =============================================================================================
print("Ranking.remove and Ranking.find")
do
	local wall = MONDAY + 9 * DAY -- Wednesday of the second week (2967)
	local clock = 1000.0
	local stores = {}
	local fail_remove = nil
	local function store(board, week)
		local key = if week ~= nil then board .. "@" .. tostring(week) else board
		local st = stores[key]
		if st ~= nil then
			return st
		end
		local rows = {}
		st = { rows = rows }
		function st.IncrementAsync(_, k, d)
			rows[k] = (rows[k] or 0) + d
			return rows[k]
		end
		function st.GetAsync(_, k)
			return rows[k]
		end
		function st.RemoveAsync(_, k)
			if fail_remove == key then
				error("DataStore unavailable")
			end
			local old = rows[k]
			rows[k] = nil
			return old
		end
		function st.GetSortedAsync(_, _asc, size)
			local page = {}
			for k, v in rows do
				table.insert(page, { key = k, value = v })
			end
			table.sort(page, function(a, b)
				if a.value ~= b.value then
					return a.value > b.value
				end
				return a.key < b.key
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
		stores[key] = st
		return st
	end
	Ranking.reset()
	Ranking.WEEKLY_ON = true
	Ranking.configure({
		store = store,
		names = function(ids)
			local out = {}
			for _, id in ids do
				out[id] = if id == 5 or id == 6 then "Igual" else "P" .. id
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
	local week = RankPrizes.week(wall)
	ok(week == 2967, "the test stands in the second week")
	-- last week's finals: 7 was first in both lists
	for uid, v in { [7] = 9, [8] = 5, [9] = 3, [10] = 1 } do
		store("wins", week - 1).rows[tostring(uid)] = v
		store("kills", week - 1).rows[tostring(uid)] = v * 4
	end
	-- this week and all time
	local won = { spawned = true, won = true, kills = 3 }
	for _ = 1, 4 do
		Ranking.record(7, won, "P7")
	end
	for _ = 1, 2 do
		Ranking.record(8, won, "P8")
	end
	Ranking.record(5, won, "Igual")
	Ranking.record(6, won, "Igual")
	local me = { UserId = 7, Name = "P7" }
	local got = Ranking.get(me)
	ok(got.ok and got.boards.wins[1][1] == 7 and got.boards.wins_w[1][1] == 7 and got.boards.kills[1][1] == 7, "before: 7 leads every list")
	ok(got.me.wins[1] == 4 and got.me.wins[2] == 1, "... and knows its own total and place")
	local champs = Ranking.champions()
	ok(champs ~= nil and champs.wins[1][1] == 7 and Ranking.last_places(7) ~= nil, "... and was last week's champion")

	local id, name = Ranking.find("p8")
	ok(id == 8 and name == "P8", "find: a name of the lists, any case")
	id, name = Ranking.find("Igual")
	ok(id == nil and name == 2, "find: a name two players have gives no id, and says there are two")
	id, name = Ranking.find("ninguem")
	ok(id == nil and name == 0, "find: a name nobody has")
	ok(Ranking.find("") == nil and Ranking.find(nil) == nil and Ranking.find(7) == nil, "find: nothing for no name")

	local all, found = Ranking.remove(7)
	ok(all == true and found == 6, "remove: every store had them (2 all-time, 2 of this week, 2 of last week): " .. tostring(found))
	for _, key in { "wins", "kills", "wins@" .. week, "kills@" .. week, "wins@" .. (week - 1), "kills@" .. (week - 1) } do
		ok(stores[key].rows["7"] == nil, "the store " .. key .. " no longer has them")
		ok(stores[key].rows["8"] ~= nil, "... and still has the others")
	end
	got = Ranking.get(me)
	local still = false
	for _, board in { "wins", "kills", "wins_w", "kills_w" } do
		for _, row in got.boards[board] do
			still = still or row[1] == 7
		end
	end
	ok(not still, "this server's lists lost the row at once (no wait for the next read)")
	ok(got.boards.wins[1][1] == 8 and got.boards.wins_w[1][1] == 8, "the next one leads")
	ok(got.me.wins[1] == 0 and got.me.wins[2] == nil and got.me.kills_w[1] == 0, "their own totals are zero, with no place")
	champs = Ranking.champions()
	ok(champs.wins[1][1] == 8 and champs.kills[1][1] == 8, "last week's champions: the next one moved up")
	ok(Ranking.last_places(7) == nil, "... and they have no place there")
	local upto, results = Ranking.due(7, nil)
	ok(upto == week - 1 and #results == 0, "no prize is owed to them for last week")
	upto, results = Ranking.due(8, nil)
	ok(#results == 1 and results[1].wins == 1, "the next one is owed the first place's")

	-- the lists are read again: still gone
	clock += Ranking.REFRESH_S + 1
	got = Ranking.get(me)
	ok(got.boards.wins[1][1] == 8 and #got.boards.wins == 3, "after the next read of the stores: still out")

	-- they play again: from zero
	Ranking.record(7, won, "P7")
	got = Ranking.get(me)
	ok(got.me.wins[1] == 1 and stores["wins"].rows["7"] == 1, "their next win counts from zero")

	all, found = Ranking.remove(424242)
	ok(all == true and found == 0, "someone who was in no list: nothing found, no error")
	ok(Ranking.remove(nil) == false and Ranking.remove(-1) == false and Ranking.remove("x") == false, "not a user id: refused")

	fail_remove = "kills"
	all, found = Ranking.remove(8)
	ok(all == false and found >= 1, "a store that fails: reported, and the rest was removed")
	ok(stores["wins"].rows["8"] == nil and stores["kills"].rows["8"] ~= nil, "... the one that failed still has them")
	fail_remove = nil
	all, found = Ranking.remove(8)
	ok(all == true and found == 1 and stores["kills"].rows["8"] == nil, "pressing again finishes it")

	-- the first week: there is no week before to look at
	Ranking.reset()
	table.clear(stores)
	wall = MONDAY + 2 * DAY
	Ranking.record(7, won, "P7")
	all, found = Ranking.remove(7)
	ok(all == true and found == 4 and stores["wins@" .. (RankPrizes.FIRST_WEEK - 1)] == nil, "in the first week no store of a week before is touched")

	-- without the weekly lists
	Ranking.reset()
	table.clear(stores)
	Ranking.WEEKLY_ON = false
	Ranking.record(7, won, "P7")
	all, found = Ranking.remove(7)
	ok(all == true and found == 2, "weekly lists off: the two all-time stores")
	Ranking.WEEKLY_ON = true
	Ranking.reset()
end

-- =============================================================================================
print("the wire and the server's door")
do
	local OP = Protocol.OP
	ok(OP.ADMIN == 54 and OP.ADMIN_RESULT == 55, "the two ops")
	local seen = {}
	local twice = false
	for _, n in OP do
		twice = twice or seen[n] == true
		seen[n] = true
	end
	ok(not twice, "no op number is used twice")
	local src = fs.readFile("src/server/ServerMain.luau")
	local a = string.find(src, "admin_op = function(player: Player, action: any, args: any)", 1, true)
	ok(a ~= nil, "ServerMain has the panel's door")
	local body = string.sub(src, a, a + 2600)
	local check = string.find(body, "if admins[player] ~= true then", 1, true)
	local run = string.find(body, "AdminActions.run", 1, true)
	ok(check ~= nil and run ~= nil and check < run, "who is asking is checked before anything runs")
	local ret = string.find(body, "return", check, true)
	ok(ret ~= nil and ret < run, "... and a refusal returns before it")
	ok(has(body, "is_owner = is_admin") and has(src, "return admins[p] == true"), "AdminActions is given the same check")
	ok(has(src, "elseif op == OP.ADMIN then"), "the op reaches the door")
	-- only the server's own check ever makes an admin
	local sets = 0
	for _ in string.gmatch(src, "admins%[[%w_]+%] = true") do
		sets += 1
	end
	ok(sets == 1, "one place only makes a game admin (the AdminCheck answer): " .. sets)
	local sets_attr = 0
	for _ in string.gmatch(src, 'SetAttribute%("AF_Admin"') do
		sets_attr += 1
	end
	ok(sets_attr == 1, "... and one place sets the attribute the button reads")
	ok(has(src, 'RemoveAsync = through("RemoveAsync")') and has(src, "RemoveAsync = function(_: any, k: string)"), "Studio's stand-in stores can remove too")
end

print(string.format("painel_admin: %d checks, %d failed", checks, fails))
if fails > 0 then
	error(fails .. " failures")
end
