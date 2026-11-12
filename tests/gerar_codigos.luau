--!nocheck
-- Codes the owner creates by chat command, with nothing to publish (2026-11-11: "temos a opção
-- resgatar código, mas não temos nada para gerar os códigos"):
--   * server/CodeCommands: what "/codigo criar | gerar | lista | ver | desligar | ligar | apagar" mean,
--     who may use them, and what they answer;
--   * server/CodeStore: the codes in one DataStore key, shared by every server; what another server
--     did is seen here; a store outage changes nothing;
--   * server/Purchases.redeem_code: a created code pays once per player; a code with a limit of uses
--     pays that many players and no more; the place's own list (server/MyCodes) keeps working;
--   * the client: the "this code has run out" line, and the answer left in the chat window.
--   lune run tests/gerar_codigos.luau
require("./prelude")
local fs = require("@lune/fs")
local Codes = require("../src/server/Codes")
local CodeStore = require("../src/server/CodeStore")
local CodeCommands = require("../src/server/CodeCommands")
local Purchases = require("../src/server/Purchases")
local Protocol = require("../src/shared/Net/Protocol")
local Session = require("../src/client/Session")
local LangPt = require("../src/shared/Data/LangPt")

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
local DAY = 86400

-- ---------------------------------------------------------------------------------------------
-- A DataStore as Roblox's: values are copies, a write may run its function twice, it can be down
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
local function new_store()
	local st = { rows = {}, down = false, down_writes = false, gets = 0, writes = 0, twice = false }
	function st:GetAsync(k)
		if self.down then
			error("DataStore unavailable")
		end
		self.gets += 1
		return copy(self.rows[k])
	end
	function st:UpdateAsync(k, fn)
		if self.down or self.down_writes then
			error("DataStore request was throttled")
		end
		if self.twice then
			fn(copy(self.rows[k])) -- (a conflict: Roblox calls the function again with the newer value)
		end
		local new = fn(copy(self.rows[k]))
		if new ~= nil then
			self.writes += 1
			self.rows[k] = copy(new)
		end
		return new
	end
	return st
end

-- ---------------------------------------------------------------------------------------------
-- 1. the words of the command
-- ---------------------------------------------------------------------------------------------
do
	local C = CodeCommands
	ok(C.is_command("/codigo criar NATAL 5000") and C.is_command("  /CODIGO lista"), "/codigo is a command")
	ok(C.is_command("/código lista") and C.is_command("/CÓDIGO lista"), "... written with its accent too")
	ok(C.is_command("/codigos") and C.is_command("/code list"), "... and /codigos, /code")
	ok(not C.is_command("/codigox 1") and not C.is_command("oi /codigo") and not C.is_command(nil), "nothing else is")
	ok(not C.is_command("/moedas dar eu 5") and C.parse("oi", NOW) == nil, "/moedas and plain chat are left alone")
	ok(#C.ALIASES == 4, "four names: two chat commands of two names each")

	local c = C.parse("/codigo criar natal 5000", NOW)
	ok(c.op == "create" and c.code == "NATAL" and c.stars == 5000 and c.expires == nil and c.uses == nil, "criar <NOME> <coroas>")
	c = C.parse("/codigo criar Fim-De_Ano 20k 7d 100x", NOW)
	ok(c.op == "create" and c.code == "FIM-DE_ANO" and c.stars == 20000, "a name with - and _, 20k")
	ok(c.expires == NOW + 7 * DAY + 86399 and c.uses == 100, "7d: until the end of the 7th day from today; 100x: a hundred players")
	c = C.parse("/codigo criar NATAL 5.000 1x 0d", NOW + 5000)
	ok(c.stars == 5000 and c.uses == 1 and c.expires == NOW + 86399, "the options in any order; 0d is the end of today")
	c = C.parse("/codigo criar NATAL 5000 25/12/2026", NOW)
	ok(c.expires == Codes.day_end("2026-12-25"), "a date as Brazil writes it")
	c = C.parse("/codigo criar NATAL 5000 5/1/2027", NOW)
	ok(c.expires == Codes.day_end("2027-01-05"), "... with one-digit day and month")
	c = C.parse("/codigo criar NATAL 5000 2026-12-25", NOW)
	ok(c.expires == Codes.day_end("2026-12-25"), "... or as server/MyCodes writes it")
	c = C.parse("/codigo criar NATAL 5000 10/11/2026", NOW + 3600)
	ok(c.op == "create" and c.expires == NOW + 86399, "today's date is still good today")
	c = C.parse("/codigo criar NATAL 5000 09/11/2026", NOW)
	ok(c.op == "help" and has(c.why, "já passou"), "a date that has passed is refused")
	c = C.parse("/codigo criar NATAL 5000 40/13/2026", NOW)
	ok(c.op == "help" and has(c.why, "não é uma data"), "what is not a date is refused")
	c = C.parse("/codigo criar NATAL 5000 7", NOW)
	ok(c.op == "help" and has(c.why, '"7"') and has(c.why, "7d") and has(c.why, "100x"), "a bare number after the amount: asked what it is")
	c = C.parse("/codigo criar NATAL 5000 0x", NOW)
	ok(c.op == "help" and has(c.why, "1x"), "0x is refused")
	c = C.parse("/codigo criar NATAL 5000 9999d", NOW)
	ok(c.op == "help" and has(c.why, "3650d"), "a validity of more than ten years is refused")
	c = C.parse("/codigo criar FELIZ NATAL 5000", NOW)
	ok(c.op == "help" and has(c.why, "NATAL") and has(c.why, "uma palavra só"), "a name of two words: told the name is one word")
	c = C.parse("/codigo criar NATÁL 5000", NOW)
	ok(c.op == "help" and has(c.why, "Nome inválido"), "a name with an accent is refused")
	c = C.parse("/codigo criar AB 5000", NOW)
	ok(c.op == "help" and has(c.why, "Nome inválido"), "a name of two letters is refused")
	c = C.parse("/codigo criar NATAL", NOW)
	ok(c.op == "help" and has(c.why, "/codigo criar NATAL 5000"), "no amount: an example")
	c = C.parse("/codigo criar NATAL 200m", NOW)
	ok(c.op == "help" and has(c.why, "Quantia inválida"), "more than a code may give is refused")
	c = C.parse("/codigo criar NATAL 100m", NOW)
	ok(c.op == "create" and c.stars == Codes.MAX_STARS, "the most a code may give is accepted")
	c = C.parse("/codigo criar NATAL 0", NOW)
	ok(c.op == "help", "zero is refused")

	c = C.parse("/codigo gerar 5000", NOW)
	ok(c.op == "generate" and c.code == nil and c.stars == 5000, "gerar <coroas>")
	c = C.parse("/codigo gerar 5k 1x 30d", NOW)
	ok(c.op == "generate" and c.stars == 5000 and c.uses == 1 and c.expires == NOW + 30 * DAY + 86399, "gerar with options")
	c = C.parse("/codigo gerar", NOW)
	ok(c.op == "help" and has(c.why, "/codigo gerar 5000"), "gerar without an amount: an example")
	c = C.parse("/codigo gerar NATAL 5000", NOW)
	ok(c.op == "help" and has(c.why, "Quantia inválida"), "gerar takes no name")

	ok(C.parse("/codigo lista", NOW).op == "list" and C.parse("/codigos listar", NOW).op == "list", "lista")
	ok(C.parse("/codigo ver", NOW).op == "list", "ver, alone, is the list")
	c = C.parse("/codigo ver natal", NOW)
	ok(c.op == "see" and c.code == "NATAL", "ver <NOME>")
	c = C.parse("/codigo desligar k7qm-x2pd", NOW)
	ok(c.op == "off" and c.code == "K7QM-X2PD", "desligar <NOME>")
	ok(C.parse("/codigo ligar NATAL", NOW).op == "on" and C.parse("/codigo apagar NATAL", NOW).op == "delete", "ligar, apagar")
	ok(C.parse("/codigo desligar", NOW).op == "help" and C.parse("/codigo apagar", NOW).op == "help", "... need a name")
	ok(C.parse("/codigo apagar ç", NOW).op == "help", "... that can be a code's")
	ok(C.parse("/codigo", NOW).op == "help" and C.parse("/codigo dançar", NOW).op == "help", "anything else asks for help")
	ok(C.parse("/code create NATAL 5", NOW).op == "create" and C.parse("/code random 5", NOW).op == "generate", "the English words")
	ok(C.parse("/code off NATAL", NOW).op == "off" and C.parse("/code delete NATAL", NOW).op == "delete", "... off, delete")

	-- dates as they are shown
	ok(C.date(86399) == "01/01/1970" and C.date(0) == "01/01/1970", "the first day")
	ok(C.date(1801439999) == "31/01/2027", "2027-01-31")
	ok(C.date(1709251199) == "29/02/2024", "a leap day")
	ok(C.date(NOW) == "10/11/2026" and C.date(NOW - 1) == "09/11/2026", "a day starts at midnight UTC")
	local bad = 0
	for y = 2024, 2032 do
		for m = 1, 12 do
			for _, d in { 1, 15, 28 } do
				local iso = string.format("%04d-%02d-%02d", y, m, d)
				if C.date(Codes.day_end(iso)) ~= string.format("%02d/%02d/%04d", d, m, y) then
					bad += 1
				end
			end
		end
	end
	ok(bad == 0, "every date shown is the date written (" .. bad .. " wrong)")

	-- a drawn name
	local seq = 0
	local name = C.random_code(function(n)
		seq = seq % n + 1
		return seq
	end)
	ok(name == "ABCD-EFGH", "a drawn name: eight letters in two groups (" .. name .. ")")
	ok(Codes.normalize(name) == name, "... that is a code's name as it is")
	ok(C.random_code(function(n)
		return n
	end) == "9999-9999", "the last letter can be drawn")
	ok(C.random_code(function()
		return 0
	end) == "AAAA-AAAA" and C.random_code(function()
		return 1e9
	end) == "9999-9999", "a draw out of range still gives a name")
	for _, ch in { "0", "O", "1", "I", "L" } do
		ok(string.find(C.ALPHABET, ch, 1, true) == nil, "no '" .. ch .. "' in a drawn name")
	end
	ok(#C.ALPHABET == 31, "31 letters and digits: 31^8 names")
end

-- ---------------------------------------------------------------------------------------------
-- 2. the store of created codes
-- ---------------------------------------------------------------------------------------------
local FIXED = {
	["BEMVINDO"] = { coroas = 5000 },
	["PARADO"] = { coroas = 100, ativo = false },
}
local t = 1000.0 -- this server's clock
local st = new_store()
local logged = {}
local function fresh_server()
	CodeStore.reset()
	CodeStore.configure({
		store = st,
		fixed = FIXED,
		clock = function()
			return t
		end,
		log = function(line)
			table.insert(logged, line)
		end,
	})
end
fresh_server()
do
	local list, read = CodeStore.list()
	ok(#list == 0 and read == true, "a new game has no created codes")
	local e, why = CodeStore.create("natal", 5000, nil, nil, 77, NOW)
	ok(e ~= nil and why == nil and e.code == "NATAL" and e.stars == 5000 and e.active == true, "a code is created")
	ok(e.uses == nil and e.used == 0 and e.expires == nil and e.by == 77 and e.made == NOW, "... with what was asked")
	local row = st.rows[CodeStore.KEY]
	ok(type(row) == "table" and row.v == 1 and type(row.codes.NATAL) == "table" and row.codes.NATAL.stars == 5000, "... and stored in the one key")
	e, why = CodeStore.create("NATAL", 10, nil, nil, 77, NOW)
	ok(e == nil and why == "exists" and st.rows[CodeStore.KEY].codes.NATAL.stars == 5000, "the same name again is refused, the first stays")
	e, why = CodeStore.create("bemvindo", 10, nil, nil, 77, NOW)
	ok(e == nil and why == "exists", "a name on the place's own list is refused")
	e, why = CodeStore.create("parado", 10, nil, nil, 77, NOW)
	ok(e == nil and why == "exists", "... a switched-off one too")
	for _, bad in {
		{ "AB", 5 },
		{ "NATÁL", 5 },
		{ "OK1", 0 },
		{ "OK1", 1.5 },
		{ "OK1", Codes.MAX_STARS + 1 },
		{ "OK1", "muito" },
		{ "OK1", 5, "amanhã" },
		{ "OK1", 5, nil, 0 },
		{ "OK1", 5, nil, 2.5 },
		{ 123, 5 },
	} do
		e, why = CodeStore.create(bad[1], bad[2], bad[3], bad[4], 77, NOW)
		ok(e == nil and why == "bad", "refused: " .. tostring(bad[1]) .. " " .. tostring(bad[2]) .. " " .. tostring(bad[3]) .. " " .. tostring(bad[4]))
	end
	ok(st.rows[CodeStore.KEY].codes.OK1 == nil, "... and none of them was stored")

	CodeStore.create("ZETA", 1, NOW + DAY, 3, 77, NOW)
	CodeStore.create("ALFA", 2, nil, 1, 77, NOW)
	list = CodeStore.list()
	ok(#list == 3 and list[1].code == "ALFA" and list[2].code == "NATAL" and list[3].code == "ZETA", "the list is sorted by name")
	ok(list[3].expires == NOW + DAY and list[3].uses == 3 and list[3].used == 0, "... with each code's terms")
	list[1].stars = 999
	ok(CodeStore.list()[1].stars == 2, "the list handed out is a copy")

	-- finding
	e, why = CodeStore.find(" natal ", NOW)
	ok(e ~= nil and e.code == "NATAL" and e.stars == 5000 and why == nil, "a created code is found, whatever its case")
	e, why = CodeStore.find("NADA", NOW)
	ok(e == nil and why == "invalid", "an unknown one is not")
	e, why = CodeStore.find("x", NOW)
	ok(e == nil and why == "invalid", "what can't be a code is not")
	e, why = CodeStore.find("ZETA", NOW + DAY)
	ok(e ~= nil, "a code is good until its last second")
	e, why = CodeStore.find("ZETA", NOW + DAY + 1)
	ok(e == nil and why == "expired", "... and expired after it")

	-- switching and deleting
	e, why = CodeStore.switch("natal", false)
	ok(e ~= nil and e.active == false and st.rows[CodeStore.KEY].codes.NATAL.active == false, "a code is switched off, in the store")
	e, why = CodeStore.find("NATAL", NOW)
	ok(e == nil and why == "invalid", "switched off, it reads as one that does not exist")
	e = CodeStore.switch("NATAL", true)
	ok(e ~= nil and e.active == true and CodeStore.find("NATAL", NOW) ~= nil, "... and can be switched on again")
	e, why = CodeStore.switch("NADA", false)
	ok(e == nil and why == "missing", "a code that does not exist can't be switched")
	e, why = CodeStore.remove("NADA")
	ok(e == nil and why == "missing", "... nor deleted")
	e, why = CodeStore.remove("zeta")
	ok(e ~= nil and e.code == "ZETA" and st.rows[CodeStore.KEY].codes.ZETA == nil, "a code is deleted")
	ok(#CodeStore.list() == 2 and select(2, CodeStore.find("ZETA", NOW)) == "invalid", "... and is gone")

	-- a limit of uses: counted in the store
	local got
	got, why = CodeStore.reserve("ALFA", NOW)
	ok(got == true and st.rows[CodeStore.KEY].codes.ALFA.used == 1, "a limited code's use is taken in the store")
	e, why = CodeStore.find("ALFA", NOW)
	ok(e == nil and why == "spent", "with every use taken the code has run out")
	got, why = CodeStore.reserve("ALFA", NOW)
	ok(got == false and why == "spent" and st.rows[CodeStore.KEY].codes.ALFA.used == 1, "... and no more can be taken")
	ok(CodeStore.release("ALFA") == true and st.rows[CodeStore.KEY].codes.ALFA.used == 0, "a use is given back")
	ok(CodeStore.release("ALFA") == true and st.rows[CodeStore.KEY].codes.ALFA.used == 0, "... never below zero")
	ok(CodeStore.find("ALFA", NOW) ~= nil, "and the code is good again")
	local writes = st.writes
	got = CodeStore.reserve("NATAL", NOW)
	ok(got == true and st.writes == writes, "a code without a limit: nothing to take, nothing written")
	ok(CodeStore.release("NATAL") == true and st.writes == writes, "... nothing to give back")
	got, why = CodeStore.reserve("NADA", NOW)
	ok(got == false and why == "invalid", "an unknown code has no use to take")
	-- (a write Roblox runs twice counts once)
	st.twice = true
	got = CodeStore.reserve("ALFA", NOW)
	ok(got == true and st.rows[CodeStore.KEY].codes.ALFA.used == 1, "a write Roblox runs twice takes one use, not two")
	CodeStore.release("ALFA")
	ok(st.rows[CodeStore.KEY].codes.ALFA.used == 0, "... and gives one back")
	st.twice = false
	-- (switched off or expired: reserve refuses what find would)
	CodeStore.create("CURTO", 5, NOW + 10, 5, 77, NOW)
	got, why = CodeStore.reserve("CURTO", NOW + 11)
	ok(got == false and why == "expired" and st.rows[CodeStore.KEY].codes.CURTO.used == 0, "an expired code gives no use")
	CodeStore.switch("CURTO", false)
	got, why = CodeStore.reserve("CURTO", NOW)
	ok(got == false and why == "invalid", "nor a switched-off one")
	CodeStore.remove("CURTO")

	-- the store is down: nothing changes, and the copy this server holds still answers
	st.down = true
	e, why = CodeStore.create("NOVO", 5, nil, nil, 77, NOW)
	ok(e == nil and why == "store", "store down: a code is not created")
	e, why = CodeStore.switch("NATAL", false)
	ok(e == nil and why == "store", "... not switched")
	e, why = CodeStore.remove("NATAL")
	ok(e == nil and why == "store", "... not deleted")
	got, why = CodeStore.reserve("ALFA", NOW)
	ok(got == false and why == "store", "... and a limited code gives no use")
	ok(CodeStore.find("NATAL", NOW) ~= nil, "a code this server knows is still found")
	st.down = false
	ok(st.rows[CodeStore.KEY].codes.NOVO == nil and st.rows[CodeStore.KEY].codes.NATAL.active == true, "the store is as it was")
	ok(#logged > 0, "what went wrong is in the server's log")

	-- the limit of codes
	local max = CodeStore.MAX_CODES
	CodeStore.MAX_CODES = 3
	ok(CodeStore.create("TRES", 5, nil, nil, 77, NOW) ~= nil, "a third code fits")
	e, why = CodeStore.create("QUATRO", 5, nil, nil, 77, NOW)
	ok(e == nil and why == "full", "past the limit of codes, no more")
	CodeStore.MAX_CODES = max
	CodeStore.remove("TRES")
	ok(max >= 100, "the real limit is at least a hundred codes")
end

-- another server: what it does is seen here, at the pace set
do
	local function other_server(change)
		local row = copy(st.rows[CodeStore.KEY]) or { v = 1, codes = {} }
		change(row.codes)
		st.rows[CodeStore.KEY] = row
	end
	fresh_server()
	ok(CodeStore.find("NATAL", NOW) ~= nil, "a server that has just opened finds a code made before")
	local gets = st.gets
	ok(CodeStore.find("NATAL", NOW) ~= nil and st.gets == gets, "a code it knows costs no read")
	-- (a code created elsewhere a moment ago: one read finds it, once the copy is MISS_REFRESH_S old)
	other_server(function(codes)
		codes.LONGE = { stars = 70, active = true, used = 0 }
	end)
	local e, why = CodeStore.find("LONGE", NOW)
	ok(e == nil and why == "invalid" and st.gets == gets, "a copy just read is not read again for an unknown code")
	t += CodeStore.MISS_REFRESH_S
	e = CodeStore.find("LONGE", NOW)
	ok(e ~= nil and e.stars == 70 and st.gets == gets + 1, "after MISS_REFRESH_S an unknown code makes one read, and is found")
	-- (guessing: at most one read every MISS_REFRESH_S)
	gets = st.gets
	for i = 1, 50 do
		t += 1.0
		CodeStore.find("CHUTE" .. i, NOW)
	end
	ok(st.gets - gets <= math.ceil(50 / CodeStore.MISS_REFRESH_S) + 1, "50 guesses in 50 s: " .. (st.gets - gets) .. " reads")
	ok(st.gets - gets >= 2, "... but the store is still looked at")
	-- (switched off elsewhere: known here within REFRESH_S)
	t += CodeStore.REFRESH_S
	CodeStore.list()
	other_server(function(codes)
		codes.LONGE.active = false
	end)
	gets = st.gets
	t += CodeStore.REFRESH_S - 1
	ok(CodeStore.find("LONGE", NOW) ~= nil and st.gets == gets, "a code switched off elsewhere: this server's copy holds for REFRESH_S")
	t += 1
	e, why = CodeStore.find("LONGE", NOW)
	ok(e == nil and why == "invalid" and st.gets == gets + 1, "... and then it is off here too")
	ok(CodeStore.MISS_REFRESH_S <= 30 and CodeStore.REFRESH_S <= 120, "a new code works within half a minute, a switched-off one stops within two")
	-- (a limited code is counted in the store, whatever this server remembers)
	other_server(function(codes)
		codes.UNICO = { stars = 5, active = true, uses = 1, used = 0 }
	end)
	t += CodeStore.REFRESH_S
	ok(CodeStore.find("UNICO", NOW) ~= nil, "a limited code made elsewhere is found")
	other_server(function(codes)
		codes.UNICO.used = 1 -- (a player on another server took it)
	end)
	local got
	got, why = CodeStore.reserve("UNICO", NOW)
	ok(got == false and why == "spent" and st.rows[CodeStore.KEY].codes.UNICO.used == 1, "its last use taken on another server: none left here")
	e, why = CodeStore.find("UNICO", NOW)
	ok(e == nil and why == "spent", "... and this server knows it now")
	-- (what someone wrote by hand into the key is not a code)
	other_server(function(codes)
		codes.lower = { stars = 5 }
		codes.SEMVALOR = { active = true }
		codes.NEGATIVO = { stars = -5 }
		codes.TORTO = "texto"
		codes.LIMITE = { stars = 5, uses = "muitos" }
	end)
	t += CodeStore.REFRESH_S
	local names = {}
	for _, x in CodeStore.list() do
		names[x.code] = true
	end
	ok(not names.lower and not names.SEMVALOR and not names.NEGATIVO and not names.TORTO and not names.LIMITE, "junk in the key is not a code")
	ok(names.NATAL and names.ALFA and names.LONGE, "... and the real ones are still there")
	other_server(function(codes)
		for _, k in { "lower", "SEMVALOR", "NEGATIVO", "TORTO", "LIMITE", "LONGE", "UNICO" } do
			codes[k] = nil
		end
	end)
	st.rows.other = "x"
	t += CodeStore.REFRESH_S
	ok(#CodeStore.list() == 2, "two codes left: NATAL and ALFA")

	-- a server that never reached the store
	fresh_server()
	st.down = true
	e, why = CodeStore.find("NATAL", NOW)
	ok(e == nil and why == "store", "the store never read: a code is not called unknown, the store is called down")
	local list, read = CodeStore.list()
	ok(#list == 0 and read == false, "... and the list says it was not read")
	-- (an outage is not met with a read for every code typed)
	local tries = 0
	local real_get = st.GetAsync
	st.GetAsync = function(self, k)
		tries += 1
		return real_get(self, k)
	end
	for i = 1, 40 do
		t += 0.25
		CodeStore.find("CHUTE" .. i, NOW)
	end
	st.GetAsync = real_get
	ok(tries >= 1 and tries <= 3, "store down, 40 codes typed in 10 s: " .. tries .. " reads tried")
	st.down = false
	t += CodeStore.MISS_REFRESH_S
	ok(CodeStore.find("NATAL", NOW) ~= nil, "once the store answers, the code is found")
	-- no store at all
	CodeStore.reset()
	e, why = CodeStore.find("NATAL", NOW)
	ok(e == nil and why == "store", "no store configured: down")
	e, why = CodeStore.create("NOVO", 5, nil, nil, 1, NOW)
	ok(e == nil and why == "store", "... and nothing is created")
	fresh_server()
end

-- ---------------------------------------------------------------------------------------------
-- 3. redeeming a created code
-- ---------------------------------------------------------------------------------------------
do
	local pst = new_store()
	local P = { UserId = 42, Name = "Ana" }
	local Q = { UserId = 43, Name = "Beto" }
	local R = { UserId = 44, Name = "Caio" }
	local now = NOW
	local function configure()
		Purchases.reset()
		Purchases.configure({
			datastore = pst,
			codes = FIXED,
			code_store = CodeStore,
			now = function()
				return now
			end,
			players = {
				GetPlayerByUserId = function(_, id)
					return if id == 42 then P elseif id == 43 then Q elseif id == 44 then R else nil
				end,
			},
		})
		Purchases.load(P)
		Purchases.load(Q)
		Purchases.load(R)
	end
	configure()
	local function stars(p)
		return Purchases.inventory(p).stars
	end
	local function used(code)
		return st.rows[CodeStore.KEY].codes[code].used
	end
	local p0, q0, r0 = stars(P), stars(Q), stars(R)

	local good, why, paid, balance = Purchases.redeem_code(P, " natal ")
	ok(good == true and why == nil and paid == 5000 and balance == p0 + 5000 and stars(P) == p0 + 5000, "a created code pays its Coroas")
	ok(pst.rows.u42.codes.NATAL == true and pst.rows.u42.stars == p0 + 5000, "... the code and the Coroas in one write")
	good, why = Purchases.redeem_code(P, "NATAL")
	ok(good == false and why == "used" and stars(P) == p0 + 5000, "once per player")
	good, why, paid = Purchases.redeem_code(Q, "Natal")
	ok(good == true and paid == 5000 and stars(Q) == q0 + 5000, "another player uses it too")
	ok(used("NATAL") == 0, "a code without a limit is not counted in the shared key")

	-- the place's own list still works, and is that list's alone
	good, why, paid = Purchases.redeem_code(P, "bemvindo")
	ok(good == true and paid == 5000 and stars(P) == p0 + 10000, "a code of the place's own list still pays")
	st.rows[CodeStore.KEY].codes.PARADO = { stars = 999, active = true, used = 0 }
	st.rows[CodeStore.KEY].codes.BEMVINDO = { stars = 999, active = true, used = 0 }
	t += CodeStore.REFRESH_S
	CodeStore.list()
	good, why = Purchases.redeem_code(P, "PARADO")
	ok(good == false and why == "invalid" and stars(P) == p0 + 10000, "a code switched off on the place's list is not paid by a created one of the same name")
	good, why, paid = Purchases.redeem_code(Q, "BEMVINDO")
	ok(good == true and paid == 5000, "... and a live one pays what the place's list says")
	st.rows[CodeStore.KEY].codes.PARADO = nil
	st.rows[CodeStore.KEY].codes.BEMVINDO = nil
	t += CodeStore.REFRESH_S
	CodeStore.list()

	-- a code for one player
	good, why, paid = Purchases.redeem_code(P, "alfa")
	ok(good == true and paid == 2 and used("ALFA") == 1, "a code for one player pays the first")
	good, why = Purchases.redeem_code(Q, "ALFA")
	ok(good == false and why == "spent" and stars(Q) == q0 + 10000 and used("ALFA") == 1, "... and tells the second it has run out")
	good, why = Purchases.redeem_code(P, "ALFA")
	ok(good == false and (why == "spent" or why == "used") and used("ALFA") == 1, "... the first can't use it again")

	-- a code for two players: who has used it takes no second use
	CodeStore.create("DUPLA", 300, nil, 2, 1, NOW)
	good = Purchases.redeem_code(P, "DUPLA")
	ok(good == true and used("DUPLA") == 1, "a code for two: the first")
	local w = st.writes
	good, why = Purchases.redeem_code(P, "DUPLA")
	ok(good == false and why == "used" and used("DUPLA") == 1 and st.writes == w, "the first again: refused before any use is taken")
	-- (this server does not hold the player's record: the use is taken, the record says used, the use goes back)
	Purchases.reset()
	Purchases.configure({ datastore = pst, codes = FIXED, code_store = CodeStore, now = function()
		return now
	end })
	good, why = Purchases.redeem_code(P, "DUPLA")
	ok(good == false and why == "used" and used("DUPLA") == 1, "the record says used: the use taken is given back")
	configure()
	-- (the player's record can't be written: the use goes back)
	pst.down_writes = true
	good, why = Purchases.redeem_code(Q, "DUPLA")
	ok(good == false and has(why, "store unavailable") and used("DUPLA") == 1, "the player's record can't be written: not paid, the use given back")
	pst.down_writes = false
	ok(pst.rows.u43.codes.DUPLA == nil and stars(Q) == q0 + 10000, "... and nothing marked or paid")
	-- (the codes' store is down: nobody is paid)
	st.down = true
	good, why = Purchases.redeem_code(Q, "DUPLA")
	ok(good == false and has(why, "store unavailable") and stars(Q) == q0 + 10000, "the codes' store is down: a limited code pays nobody")
	good, why, paid = Purchases.redeem_code(R, "NATAL")
	ok(good == true and paid == 5000, "... a code without a limit, known here, still pays")
	st.down = false
	good, why, paid = Purchases.redeem_code(Q, "DUPLA")
	ok(good == true and paid == 300 and used("DUPLA") == 2 and stars(Q) == q0 + 10300, "the store back: the second player is paid")
	good, why = Purchases.redeem_code(R, "DUPLA")
	ok(good == false and why == "spent" and stars(R) == r0 + 5000 and used("DUPLA") == 2, "the third is told it has run out")

	-- switched off, expired, deleted
	CodeStore.create("PRAZO", 40, NOW + DAY, nil, 1, NOW)
	now = NOW + DAY + 1
	good, why = Purchases.redeem_code(R, "PRAZO")
	ok(good == false and why == "expired", "a created code past its date has expired")
	now = NOW + DAY
	CodeStore.switch("PRAZO", false)
	good, why = Purchases.redeem_code(R, "PRAZO")
	ok(good == false and why == "invalid", "switched off: it does not exist")
	CodeStore.switch("PRAZO", true)
	good, why, paid = Purchases.redeem_code(R, "PRAZO")
	ok(good == true and paid == 40, "switched on again, on its last day: it pays")
	CodeStore.remove("PRAZO")
	good, why = Purchases.redeem_code(P, "PRAZO")
	ok(good == false and why == "invalid", "deleted: it does not exist")
	ok(stars(R) == r0 + 5040, "who used it keeps what it paid")
	-- (the same name made again: who used the old one is not paid twice)
	CodeStore.create("PRAZO", 40, nil, nil, 1, NOW)
	good, why = Purchases.redeem_code(R, "PRAZO")
	ok(good == false and why == "used", "the same name created again: who used the old one has used it")
	CodeStore.remove("PRAZO")
	CodeStore.remove("DUPLA")
	now = NOW

	-- a server that can't read the codes' store at all says so, not "does not exist"
	fresh_server()
	st.down = true
	good, why = Purchases.redeem_code(R, "ALFA")
	ok(good == false and has(why, "store unavailable"), "the codes' store never read: 'try again', not 'does not exist'")
	good, why, paid = Purchases.redeem_code(R, "BEMVINDO")
	ok(good == true and paid == 5000, "... and the place's own list pays all the same")
	st.down = false
	t += CodeStore.MISS_REFRESH_S

	-- without a store of created codes (the tests of server/Codes): as before
	Purchases.reset()
	Purchases.configure({ datastore = pst, codes = FIXED, now = function()
		return now
	end })
	Purchases.load(P)
	good, why = Purchases.redeem_code(P, "NATAL2")
	ok(good == false and why == "invalid", "no store of created codes: an unknown code is unknown")
end

-- ---------------------------------------------------------------------------------------------
-- 4. the commands, run
-- ---------------------------------------------------------------------------------------------
do
	fresh_server()
	local owner = { UserId = 1001, Name = "Dono" }
	local ana = { UserId = 2002, Name = "ana" }
	local draws = {}
	local deps = {
		is_owner = function(p)
			return p == owner
		end,
		store = CodeStore,
		now = function()
			return NOW
		end,
		random = function(n)
			local v = table.remove(draws, 1)
			return v or 1
		end,
		currency = "Coroas",
		fixed = function()
			return Codes.all(FIXED)
		end,
	}
	local function run(text, who)
		return CodeCommands.run(text, who or owner, deps)
	end
	local function row(code)
		return st.rows[CodeStore.KEY].codes[code]
	end

	local reply, bad, lines = run("oi, tudo bem?")
	ok(reply == nil and bad == false and lines == nil, "plain chat is not answered")
	reply, bad = run("/moedas dar eu 5")
	ok(reply == nil, "nor /moedas")

	-- only the owner
	reply, bad = run("/codigo criar HACK 99999", ana)
	ok(bad == true and has(reply, "Só o dono") and row("HACK") == nil, "a player is refused, and nothing is created")
	reply, bad = run("/codigo lista", ana)
	ok(bad == true and has(reply, "Só o dono") and not has(reply, "NATAL"), "... and is not shown the codes")
	reply, bad = run("/codigo apagar NATAL", ana)
	ok(bad == true and row("NATAL") ~= nil, "... and deletes nothing")
	reply, bad = run("/codigo", ana)
	ok(bad == true and has(reply, "Só o dono"), "... not even the help")

	-- creating
	reply, bad, lines = run("/codigo criar verao 7500")
	ok(bad == false and reply == "Código VERAO criado: 7.500 Coroas, sem validade, sem limite de usos.", "created: " .. tostring(reply))
	ok(type(lines) == "table" and lines[1] == reply, "... the same line for the chat window")
	ok(row("VERAO") ~= nil and row("VERAO").stars == 7500 and row("VERAO").by == 1001 and row("VERAO").made == NOW, "... and stored, with who made it and when")
	reply, bad = run("/codigo criar FESTA 20k 7d 100x")
	ok(bad == false and reply == "Código FESTA criado: 20.000 Coroas, até 17/11/2026, para os 100 primeiros jogadores.", "with a date and a limit: " .. tostring(reply))
	ok(row("FESTA").expires == NOW + 7 * DAY + 86399 and row("FESTA").uses == 100, "... stored with them")
	reply, bad = run("/codigo criar PREMIO 1m 1x")
	ok(bad == false and has(reply, "1.000.000 Coroas") and has(reply, "para 1 jogador só"), "for one player: " .. tostring(reply))
	reply, bad = run("/codigo criar verao 10")
	ok(bad == true and has(reply, "Já existe o código VERAO") and has(reply, "/codigo apagar VERAO") and row("VERAO").stars == 7500, "a name taken: refused, the first stays")
	reply, bad = run("/codigo criar BEMVINDO 10")
	ok(bad == true and has(reply, "MyCodes") and row("BEMVINDO") == nil, "a name of the place's own list: refused")
	reply, bad = run("/codigo criar FELIZ NATAL 5000")
	ok(bad == true and has(reply, "uma palavra só") and row("FELIZ") == nil, "a name of two words: explained, nothing created")
	reply, bad, lines = run("/codigo")
	ok(bad == true and reply == CodeCommands.HELP and type(lines) == "table" and #lines == #CodeCommands.HELP_LINES, "no words: the help, in full for the chat")
	lines[1] = "x"
	ok(CodeCommands.HELP_LINES[1] ~= "x", "... a copy of it")

	-- generating
	draws = { 10, 29, 14, 11, 21, 24, 13, 4 }
	reply, bad = run("/codigo gerar 5000 1x")
	ok(bad == false and reply == "Código K7QM-X2PD criado: 5.000 Coroas, sem validade, para 1 jogador só.", "generated: " .. tostring(reply))
	ok(row("K7QM-X2PD") ~= nil and row("K7QM-X2PD").uses == 1, "... and stored")
	-- (the same draw again, then another: the taken name is drawn again)
	draws = { 10, 29, 14, 11, 21, 24, 13, 4, 2, 2, 2, 2, 3, 3, 3, 3 }
	reply, bad = run("/codigo gerar 100")
	ok(bad == false and has(reply, "Código BBBB-CCCC criado"), "a drawn name that is taken is drawn again: " .. tostring(reply))
	-- (every draw taken: said, nothing else changes)
	run("/codigo criar AAAA-AAAA 1")
	draws = {}
	local n_before = #CodeStore.list()
	reply, bad = run("/codigo gerar 100")
	ok(bad == true and has(reply, "sortear") and #CodeStore.list() == n_before, "no free name drawn in six tries: said, nothing created")
	run("/codigo apagar AAAA-AAAA")
	run("/codigo apagar BBBB-CCCC")

	-- the list
	CodeStore.reserve("FESTA", NOW)
	CodeStore.reserve("FESTA", NOW)
	run("/codigo desligar ALFA")
	reply, bad, lines = run("/codigo lista")
	ok(bad == false and has(reply, "6 códigos: "), "the list, in one line: " .. tostring(reply))
	ok(has(reply, "ALFA 2 (desligado)") and has(reply, "FESTA 20.000 (2/100)") and has(reply, "K7QM-X2PD 5.000 (0/1)") and has(reply, "VERAO 7.500"), "... each code in brief")
	ok(has(reply, "Lista MyCodes: BEMVINDO, PARADO"), "... and the names of the place's own list")
	ok(type(lines) == "table" and #lines == 1 + 6 + 2 and lines[1] == "Códigos criados por comando (6):", "the list in full: a title, six codes, the place's two")
	local function line_of(code)
		for _, l in lines do
			if string.sub(l, 1, #code + 1) == code .. " " then
				return l
			end
		end
		return nil
	end
	ok(line_of("FESTA") == "FESTA · 20.000 Coroas · até 17/11/2026 · 2 de 100 usos · ligado", "a line: " .. tostring(line_of("FESTA")))
	ok(line_of("VERAO") == "VERAO · 7.500 Coroas · sem validade · sem limite de usos · ligado", "a line: " .. tostring(line_of("VERAO")))
	ok(line_of("ALFA") == "ALFA · 2 Coroas · sem validade · 1 de 1 usos · DESLIGADO", "a line: " .. tostring(line_of("ALFA")))
	ok(lines[#lines - 1] == "[MyCodes] BEMVINDO · 5.000 Coroas · sem validade · sem limite de usos · ligado", "the place's line: " .. tostring(lines[#lines - 1]))
	ok(lines[#lines] == "[MyCodes] PARADO · 100 Coroas · sem validade · sem limite de usos · DESLIGADO", "... and its switched-off one")
	-- (more codes than the one line names)
	for i = 1, 3 do
		run("/codigo criar EXTRA" .. i .. " 5")
	end
	reply, bad, lines = run("/codigo lista")
	ok(has(reply, "9 códigos: ") and has(reply, " · e mais 3") and #lines == 1 + 9 + 2, "nine codes: six named, 'and 3 more'; all nine in full")
	for i = 1, 3 do
		run("/codigo apagar EXTRA" .. i)
	end
	-- (states)
	ok(has(CodeCommands.describe({ code = "X", stars = 5, expires = NOW - 1, active = true, used = 0 }, "Coroas", NOW), "EXPIRADO"), "an expired code says so")
	ok(has(CodeCommands.describe({ code = "X", stars = 5, uses = 2, used = 2, active = true }, "Coroas", NOW), "ESGOTADO"), "a spent one too")

	-- one code
	reply, bad = run("/codigo ver festa")
	ok(bad == false and reply == "FESTA · 20.000 Coroas · até 17/11/2026 · 2 de 100 usos · ligado", "ver: " .. tostring(reply))
	reply, bad = run("/codigo ver bemvindo")
	ok(bad == false and has(reply, "[MyCodes] BEMVINDO"), "ver, a code of the place's list")
	reply, bad = run("/codigo ver NADA")
	ok(bad == true and has(reply, "Não existe o código NADA") and has(reply, "/codigo lista"), "ver, an unknown code")

	-- switching and deleting
	reply, bad = run("/codigo desligar verao")
	ok(bad == false and has(reply, "Código VERAO desligado") and has(reply, "/codigo ligar VERAO") and row("VERAO").active == false, "desligar: " .. tostring(reply))
	ok(select(2, CodeStore.find("VERAO", NOW)) == "invalid", "... it pays nobody")
	reply, bad = run("/codigo ligar verao")
	ok(bad == false and reply == "Código VERAO ligado de novo." and row("VERAO").active == true, "ligar: " .. tostring(reply))
	CodeStore.create("VELHO2", 5, NOW - 1, nil, 1, NOW)
	run("/codigo desligar VELHO2")
	reply, bad = run("/codigo ligar VELHO2")
	ok(bad == false and has(reply, "EXPIRADO") and has(reply, "continua sem pagar"), "ligar, an expired code: told it still pays nobody")
	reply, bad = run("/codigo desligar NADA")
	ok(bad == true and has(reply, "Não existe o código NADA"), "desligar, an unknown code")
	reply, bad = run("/codigo desligar BEMVINDO")
	ok(bad == true and has(reply, "MyCodes") and has(reply, "Studio"), "desligar, a code of the place's list: told where to change it")
	reply, bad = run("/codigo apagar velho2")
	ok(bad == false and reply == "Código VELHO2 apagado. Quem já usou fica com as Coroas." and row("VELHO2") == nil, "apagar: " .. tostring(reply))
	reply, bad = run("/codigo apagar velho2")
	ok(bad == true and has(reply, "Não existe o código VELHO2"), "apagar, twice")

	-- the store is down
	st.down = true
	reply, bad = run("/codigo criar FALHA 5")
	ok(bad == true and has(reply, "Nada mudou"), "store down, criar: " .. tostring(reply))
	local write_tries = 0
	local real_update = st.UpdateAsync
	st.UpdateAsync = function(self, k, fn)
		write_tries += 1
		return real_update(self, k, fn)
	end
	reply, bad = run("/codigo gerar 5")
	st.UpdateAsync = real_update
	ok(bad == true and has(reply, "Nada mudou") and write_tries == 1, "store down, gerar: one try, not six (" .. write_tries .. ")")
	reply, bad = run("/codigo desligar VERAO")
	ok(bad == true and has(reply, "Nada mudou"), "store down, desligar")
	reply, bad = run("/codigo apagar VERAO")
	ok(bad == true and has(reply, "Nada mudou"), "store down, apagar")
	st.down = false
	ok(row("FALHA") == nil and row("VERAO") ~= nil and row("VERAO").active == true, "... and nothing changed")
	fresh_server()
	st.down = true
	reply, bad = run("/codigo lista")
	ok(bad == true and has(reply, "Não consegui ler"), "store never read, lista: said, not 'no codes'")
	reply, bad = run("/codigo ver VERAO")
	ok(bad == true and has(reply, "Não consegui ler"), "... ver too")
	st.down = false

	-- a new game: no codes
	local empty = new_store()
	CodeStore.reset()
	CodeStore.configure({ store = empty, fixed = {} })
	deps.fixed = function()
		return {}
	end
	reply, bad, lines = run("/codigo lista")
	ok(bad == false and has(reply, "Nenhum código criado") and has(reply, "/codigo criar NATAL 5000") and #lines == 1, "no codes yet: how to make one")
	-- what the owner is taught works as written
	for _, line in CodeCommands.HELP_LINES do
		for cmd in string.gmatch(line, "/codigo[^—|]+") do
			local text = string.gsub(cmd, "%s+$", "")
			local c = CodeCommands.parse(text, NOW)
			ok(c ~= nil and c.op ~= "help", "the help's own example is a command: " .. text)
		end
	end
	reply, bad = run("/codigo criar NATAL 5000 31/12/2026")
	ok(bad == false and has(reply, "até 31/12/2026") and empty.rows[CodeStore.KEY].codes.NATAL.expires == Codes.day_end("2026-12-31"), "the guide's example: " .. tostring(reply))
	-- every answer fits one notice
	ok(#CodeCommands.HELP <= 200, "the one-line help is short")
end

-- ---------------------------------------------------------------------------------------------
-- 5. the client, and the wiring
-- ---------------------------------------------------------------------------------------------
do
	local OP = Protocol.OP
	local s = Session.new({
		now = function()
			return 0
		end,
		net = { connected = true, send = function() end, listen = function() end },
	})
	local got = {}
	s.notice:Connect(function(text, severity, chat)
		table.insert(got, { text = text, severity = severity, chat = chat })
	end)
	s:_on_net(OP.NOTICE, "Código NATAL criado", 0, { "linha 1", "linha 2" })
	ok(#got == 1 and got[1].text == "Código NATAL criado" and got[1].severity == 0, "a notice with chat lines reaches the interface")
	ok(type(got[1].chat) == "table" and #got[1].chat == 2 and got[1].chat[2] == "linha 2", "... with its lines")
	s:_on_net(OP.NOTICE, "aviso comum", 1)
	ok(#got == 2 and got[2].chat == nil and got[2].severity == 1, "a plain notice has none")
	local many = {}
	for i = 1, 200 do
		many[i] = "l" .. i
	end
	many[3] = 12345
	many[4] = string.rep("a", 5000)
	s:_on_net(OP.NOTICE, "muitas", 0, many)
	local chat = got[3].chat
	ok(#got == 3 and #chat <= Session.NOTICE_CHAT_LINES, "at most NOTICE_CHAT_LINES lines are kept (" .. #chat .. ")")
	local all_text, longest = true, 0
	for _, l in chat do
		all_text = all_text and type(l) == "string"
		longest = math.max(longest, #l)
	end
	ok(all_text and longest <= 300, "... every one a text of at most 300 bytes")
	s:_on_net(OP.NOTICE, "junk", 0, "not a table")
	ok(#got == 4 and got[4].chat == nil, "lines that are not a list are dropped")

	local root = fs.readFile("src/client/UI/UIRoot.luau")
	ok(has(root, 'self:_sig(session, "notice", function(text, severity, chat)') and has(root, "self:_on_notice(text, severity, chat)"), "UIRoot passes the lines on")
	ok(has(root, "UIRoot.chat_lines(chat)") and has(root, ":DisplaySystemMessage(line)"), "... and writes them in the chat window")
	ok(has(root, "seconds = UIRoot.COMMAND_NOTICE_S") and has(root, "UIRoot.COMMAND_NOTICE_S = 14.0"), "... with a notice that stays longer")

	local pause = fs.readFile("src/client/UI/PauseMenu.luau")
	ok(has(pause, 'elseif reason == "spent" then "This code has run out."'), "the Settings line for a code that has run out")
	ok(LangPt["This code has run out."] == "Esse código já esgotou.", "... in Portuguese")

	local main = fs.readFile("src/server/ServerMain.luau")
	ok(has(main, "code_store = CodeStore,"), "ServerMain gives Purchases the store of created codes")
	ok(has(main, "CodeStore.configure({ store = code_ds, log = print })"), "... and gives the store its DataStore")
	ok(has(main, 'CodeStore.STORE .. (if RunService:IsStudio() then "_studio" else "")'), "a Studio playtest has a store of its own")
	ok(has(main, "pcall(CodeCommands.run, text, player, {") and has(main, "store = CodeStore,") and has(main, "fixed = Codes.all,"), "the chat reaches CodeCommands")
	ok(has(main, "return admins[p] == true"), "... for a game admin only")
	ok(has(main, "code_command.PrimaryAlias = CodeCommands.ALIASES[i]") and has(main, "code_command.SecondaryAlias = CodeCommands.ALIASES[i + 1]"), "every name of the command is a chat command (kept out of the others' chat)")
	ok(has(main, "send(player, OP.NOTICE, reply, if bad then 1 else 0, if type(lines) == \"table\" then lines else nil)"), "the answer goes back with its lines")
	local at_redeem = string.find(main, "elseif op == OP.REDEEM_CODE then", 1, true)
	local at_send = string.find(main, "send(player, OP.CODE_RESULT, ok, why, stars)", 1, true)
	ok(at_redeem ~= nil and at_send ~= nil and at_send > at_redeem, "a redeem's reason goes to the client as it is ('spent' too)")
	ok(OP.NOTICE == 23 and OP.REDEEM_CODE == 43 and OP.CODE_RESULT == 44, "no message changed its number")
end

print(string.format("gerar_codigos: %d checks, %d failed", checks, fails))
if fails > 0 then
	error("gerar_codigos tests failed")
end
