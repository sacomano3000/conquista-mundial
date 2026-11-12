--!nocheck
-- The owner's panel on the screen (client/UI/AdminPanel) and what feeds it (client/Session):
--   * each button sends one request with what the fields hold; one request at a time;
--   * DELETE and REMOVE ask for a second press, and forget the first after a while;
--   * the server's answer is shown as it came; a refusal shows nothing else;
--   * no server, or no answer: said so;
--   * the lobby's button exists only for the owner; UIRoot opens the panel only for the owner;
--   * Session: OP.ADMIN goes out, OP.ADMIN_RESULT comes in cleaned.
-- The server's side (who may, what each request does) is tests/painel_admin.luau.
--   lune run tests/painel_admin_tela.luau
local H = require("./ui_harness")
local fs = require("@lune/fs")
local Signal = require("../src/shared/Core/Signal")
local UICtx = require("../src/client/UI/UICtx")
local UITheme = require("../src/client/UI/UITheme")
local W = require("../src/client/UI/Widgets")
local AdminPanel = require("../src/client/UI/AdminPanel")
local Session = require("../src/client/Session")
local Protocol = require("../src/shared/Net/Protocol")
local Lang = require("../src/shared/Data/Lang")
local LangPt = require("../src/shared/Data/LangPt")
Lang.use("pt")

local checks, failed = 0, 0
local function check(ok: any, what: string)
	checks += 1
	if not ok then
		failed += 1
		print("FAIL: " .. what)
	end
end

local clock = 500.0
AdminPanel.now = function()
	return clock
end
W.input_pos = function(io: any): Vector2
	return Vector2.new(io.Position.X, io.Position.Y)
end
W.screen_to_logical = function(v: Vector2): Vector2
	return v / UITheme.scale
end

local function press(b: any)
	H.fire(b.gui, "Activated")
	H.step(1)
end
local function press_at(node: any, x: number, y: number)
	H.fire(node.gui, "InputBegan", {
		UserInputType = Enum.UserInputType.MouseButton1,
		UserInputState = Enum.UserInputState.Begin,
		Position = Vector3.new(x, y, 0),
	})
	H.step(1)
end
local function type_in(field: any, text: string)
	field._box.Text = text
	H.step(1)
end

local CODES = {
	{ code = "NATAL", info = "5.000 Coroas · até 31/12/2026 · 12 de 100 usos", state = "ligado", on = true, fixed = false },
	{ code = "VIP", info = "500 Coroas · sem validade · sem limite de usos", state = "DESLIGADO", on = false, fixed = false },
	{ code = "BEMVINDO", info = "1.000 Coroas · sem validade · sem limite de usos", state = "ligado", on = true, fixed = true },
}
local function rank(): any
	local boards = { wins = {}, kills = {}, wins_w = {}, kills_w = {} }
	for i = 1, 5 do
		boards.wins[i] = { 100 + i, "Vencedor" .. i, 50 - i }
		boards.kills[i] = { 200 + i, "Destruidor" .. i, 900 - i }
		boards.wins_w[i] = { 100 + i, "Vencedor" .. i, 9 - i }
	end
	return { ok = true, age = 0, at = 0, boards = boards, me = {} }
end

local VIEWS = {
	{ "pc", 1280, 720, false },
	{ "celular", 844, 390, true },
}

local function make(view: any, server: boolean?)
	local root = H.root(view[2], view[3], view[4])
	local s = {
		rank = rank(),
		rank_changed = Signal.new(),
		admin_result = Signal.new(),
		asked = {},
		rank_asked = 0,
	}
	function s:admin(action, args)
		if server == false then
			return false
		end
		table.insert(s.asked, { action = action, args = args })
		return true
	end
	function s:rank_get()
		s.rank_asked += 1
		return true
	end
	local ctx = UICtx.new()
	ctx.vp = root.vp
	ctx.compact = view[4]
	ctx.touch = view[4]
	ctx.touch_device = view[4]
	ctx.session = s
	function ctx:sfx() end
	local p = AdminPanel.new(ctx)
	root:add_child(p)
	p:bind(s)
	return p, s, ctx
end
local function last(s: any): any
	return s.asked[#s.asked] or {}
end
local function answer(s: any, r: any)
	s.admin_result:Fire(r)
	H.step(2)
end

-- =============================================================================================
print("the fields")
do
	local F = AdminPanel.Field
	check(F.clean("abc", 10) == "abc" and F.clean("a\nb\tc", 10) == "abc", "one line: no control characters")
	check(F.clean("abcdef", 4) == "abcd", "at most its length")
	check(F.clean("João Çé", 5) == "João " and F.clean("ããããã", 3) == "ããã", "letters with accents count as one each")
	check(F.clean(nil, 4) == "" and F.clean(12, 4) == "" and F.clean("a\255b", 9) == "", "not a text: nothing")
	H.root(1280, 720, false)
	local f = F.new("Name or numeric ID", 12)
	check(f._box.PlaceholderText == "Nome ou ID numérico", "the hint is in Portuguese: " .. tostring(f._box.PlaceholderText))
	f._box.Text = "  Fulano  "
	check(f:text() == "Fulano", "what is typed, without the spaces at the ends")
	f._box.Text = "0123456789ABCDEFG"
	check(f._box.Text == "0123456789AB", "typing past the length is cut as it is typed: " .. tostring(f._box.Text))
	f:set_text("x\ny")
	check(f:text() == "xy", "set_text cleans too")
	f:clear()
	check(f:text() == "", "clear")
	local entered = nil
	f.entered:Connect(function(t)
		entered = t
	end)
	f._box.Text = "abc"
	H.fire(f._box, "FocusLost", true)
	check(entered == "abc", "Enter in the field says what is typed")
	entered = nil
	H.fire(f._box, "FocusLost", false)
	check(entered == nil, "leaving the field without Enter says nothing")
end

-- =============================================================================================
for _, view in VIEWS do
	print("the panel: " .. view[1])
	local p, s = make(view)
	check(p.visible == false and p.is_open == false and #s.asked == 0, "closed at first: nothing is asked of the server")
	p:open()
	H.step(30)
	check(p.is_open and p.visible, "open")
	check(#s.asked == 1 and last(s).action == "state", "opening asks for the codes, once")
	check(p:page() == "coins", "the first page is the Coroas")
	check(p._title.text == "PAINEL DO DONO", "the name, in Portuguese: " .. tostring(p._title.text))
	check(p._chips[1].text == "COROAS" and p._chips[2].text == "CÓDIGOS" and p._chips[3].text == "RANKING", "the three pages: " .. p._chips[1].text .. ", " .. p._chips[2].text .. ", " .. p._chips[3].text)
	check(p._coin_give.disabled == true, "while the first answer is on its way, the buttons wait")
	answer(s, { action = "state", ok = true, text = "", codes = CODES, codes_read = true })
	check(p._coin_give.disabled ~= true and #p._code_rows == 3, "the answer came: the buttons are back, the codes are listed")

	-- Coroas
	type_in(p._coin_who, "Fulano")
	type_in(p._coin_amount, "5.000")
	press(p._coin_give)
	check(#s.asked == 2 and last(s).action == "coins", "GIVE sends one request")
	check(last(s).args.op == "give" and last(s).args.who == "Fulano" and last(s).args.amount == "5.000", "... with the player and the amount as typed")
	check(p._coin_give.disabled == true and p._coin_take.disabled == true and p._coin_see.disabled == true, "the buttons wait for the answer")
	press(p._coin_take)
	check(#s.asked == 2, "a second press while waiting sends nothing")
	answer(s, { action = "coins", ok = true, text = "+5.000 Coroas para Fulano. Saldo: 5.000." })
	check(p._status_l.text == "+5.000 Coroas para Fulano. Saldo: 5.000.", "the answer is shown as the server wrote it")
	check(p._coin_give.disabled ~= true, "the buttons are back")
	check(p._coin_amount:text() == "" and p._coin_who:text() == "Fulano", "the amount is cleared (no second gift by accident); the name stays")
	type_in(p._coin_amount, "100")
	press(p._coin_take)
	check(last(s).args.op == "take" and last(s).args.amount == "100", "TAKE")
	answer(s, { action = "coins", ok = false, text = "Quantia inválida." })
	check(p._status_l.text == "Quantia inválida." and p._coin_amount:text() == "100", "a refusal keeps what was typed")
	press(p._coin_see)
	check(last(s).args.op == "see", "SEE BALANCE")
	answer(s, { action = "coins", ok = true, text = "Fulano tem 4.900 Coroas." })

	-- codes
	press(p._chips[2])
	check(p:page() == "codes" and p._pages[2].visible and not p._pages[1].visible, "the CODES chip shows the codes' page")
	type_in(p._code_name, "natal2")
	type_in(p._code_stars, "5000")
	type_in(p._code_valid, "7d")
	type_in(p._code_uses, "100")
	press(p._code_create)
	local a = last(s)
	check(a.action == "code_new" and a.args.code == "natal2" and a.args.stars == "5000" and a.args.valid == "7d" and a.args.uses == "100", "CREATE sends the four fields")
	local more = table.clone(CODES)
	table.insert(more, 1, { code = "NATAL2", info = "5.000 Coroas · até 19/11/2026 · 0 de 100 usos", state = "ligado", on = true, fixed = false })
	answer(s, { action = "code_new", ok = true, text = "Código NATAL2 criado.", codes = more })
	check(#p._code_rows == 4 and p._code_rows[1].code == "NATAL2", "the new code is in the list")
	check(p._code_rows[1].name.text == "NATAL2" and string.find(p._code_rows[1].info.text, "0 de 100 usos", 1, true) ~= nil, "... with what it gives")
	check(p._code_name:text() == "", "the name's field is cleared")
	local row = p._code_rows[1]
	check(row.toggle.text == "DESLIGAR" and row.delete.text == "APAGAR", "a live code: OFF and DELETE")
	check(p._code_rows[3].toggle.text == "LIGAR", "a code that is off: ON")
	check(p._code_rows[4].fixed == true and p._code_rows[4].toggle == nil and p._code_rows[4].delete == nil, "the place's own code has no buttons")
	press(row.toggle)
	check(last(s).action == "code_switch" and last(s).args.code == "NATAL2" and last(s).args.on == false, "OFF asks to switch it off")
	answer(s, { action = "code_switch", ok = true, text = "Código NATAL2 desligado.", codes = more })
	row = p._code_rows[1]
	local n = #s.asked
	press(row.delete)
	check(#s.asked == n, "DELETE: the first press sends nothing")
	check(row.delete.text == "CERTEZA? APERTE DE NOVO", "... it asks: " .. tostring(row.delete.text))
	clock += AdminPanel.ARM_S + 1
	p:tick()
	check(row.delete.text == "APAGAR", "left alone, it goes back to DELETE")
	press(row.delete)
	check(#s.asked == n and row.delete.text == "CERTEZA? APERTE DE NOVO", "a press after that is a first press again")
	press(p._code_rows[2].delete)
	check(#s.asked == n and row.delete.text == "APAGAR" and p._code_rows[2].delete.text == "CERTEZA? APERTE DE NOVO", "pressing another row's DELETE moves the question there")
	clock += 1
	press(p._code_rows[2].delete)
	check(#s.asked == n + 1 and last(s).action == "code_remove" and last(s).args.code == "NATAL", "the second press deletes that code, and only that one")
	answer(s, { action = "code_remove", ok = true, text = "Código NATAL apagado.", codes = { CODES[2], CODES[3] } })
	check(#p._code_rows == 2 and p._code_rows[1].code == "VIP", "the list follows")

	-- the ranking
	press(p._chips[3])
	check(p:page() == "rank" and #p._rank_rows == 5, "the RANKING chip shows the list")
	check(p._rank_rows[1].name.text == "Vencedor1" and p._rank_rows[1].id.text == "ID 101", "each row: the name and the id")
	n = #s.asked
	press(p._rank_remove)
	check(#s.asked == n and string.find(p._status_l.text, "Escreva o nome", 1, true) ~= nil, "REMOVE with an empty field: asks for the name, sends nothing")
	type_in(p._rank_who, "Vencedor3")
	press(p._rank_remove)
	check(#s.asked == n and p._rank_remove.text == "CERTEZA? APERTE DE NOVO", "REMOVE FROM RANKING asks first")
	press(p._rank_remove)
	check(#s.asked == n + 1 and last(s).action == "rank_remove" and last(s).args.who == "Vencedor3", "the second press sends the name")
	local asked_rank = s.rank_asked
	answer(s, { action = "rank_remove", ok = true, uid = 103, text = "Vencedor3 saiu do ranking." })
	check(#p._rank_rows == 4, "the row leaves the list at once")
	local still = false
	for _, rows in s.rank.boards do
		for _, r in rows do
			still = still or r[1] == 103
		end
	end
	check(not still, "... from every list this screen has")
	check(s.rank_asked == asked_rank + 1, "and the server is asked for its lists again")
	check(p._rank_who:text() == "" and p._rank_remove.text == "TIRAR DO RANKING", "the field is cleared, the button is itself again")
	-- a row's own button: by id
	local r1 = p._rank_rows[1]
	n = #s.asked
	press(r1.remove)
	check(#s.asked == n and r1.remove.text == "CERTEZA? APERTE DE NOVO", "a row's REMOVE asks first")
	press(r1.remove)
	check(#s.asked == n + 1 and last(s).args.who == "101", "the second press sends that player's id")
	answer(s, { action = "rank_remove", ok = false, text = "O armazenamento do Roblox falhou no meio." })
	check(#p._rank_rows == 4 and p._status_l.text == "O armazenamento do Roblox falhou no meio.", "a failure: the list stays, the reason is shown")
	-- the other lists
	press(p._board_chips[2])
	check(#p._rank_rows == 5 and p._rank_rows[1].name.text == "Destruidor1", "the KINGDOMS chip shows the other list")
	press(p._board_chips[4])
	check(#p._rank_rows == 0 and p._rank_empty.visible and p._rank_empty.text == "Ninguém nesta lista ainda.", "an empty list says so")
	-- new lists from the server while open
	s.rank = rank()
	s.rank_changed:Fire()
	H.step(2)
	press(p._board_chips[1])
	check(#p._rank_rows == 5, "lists that come while the panel is open are drawn")

	-- no answer
	press(p._chips[1])
	type_in(p._coin_amount, "5")
	press(p._coin_give)
	check(p._coin_give.disabled == true, "waiting")
	clock += AdminPanel.WAIT_S + 1
	p:tick()
	check(p._coin_give.disabled ~= true and p._status_l.text == "O servidor não respondeu. Tente de novo em instantes.", "no answer: said so, and the buttons are back")

	-- a refusal (someone who is not the owner and forced the window open)
	press(p._coin_give)
	answer(s, { action = "?", ok = false, denied = true, text = "Só o dono do jogo pode usar o painel." })
	check(p._status_l.text == "Só o dono do jogo pode usar o painel.", "a refusal is shown")

	-- closing
	local closed = 0
	p.closed:Connect(function()
		closed += 1
	end)
	press_at(p._dim, 2, 2)
	check(p.is_open == false and closed == 1, "a press outside closes it")
	H.step(30)
	p:open("codes")
	H.step(30)
	check(p.is_open and p:page() == "codes" and last(s).action == "state", "open again, on the page asked for; the codes are asked for again")
	answer(s, { action = "state", ok = true, text = "", codes = CODES })
	local px, py = H.rect(p._panel.gui)
	press_at(p._dim, px + 20, py + 20)
	check(p.is_open, "a press inside does not close it")
	press(p._close_b)
	check(p.is_open == false and closed == 2, "the close button closes it")
end

-- =============================================================================================
print("without a server, and before the codes come")
do
	local p, s = make(VIEWS[1], false)
	p:open("codes")
	H.step(30)
	check(#s.asked == 0 and string.find(p._status_l.text, "Não há servidor aqui", 1, true) ~= nil, "no server: said so")
	check(#p._code_rows == 0 and p._code_empty.visible, "no codes: the list says why")
	type_in(p._code_stars, "10")
	press(p._code_create)
	check(#s.asked == 0 and p._code_create.disabled ~= true, "a button pressed with no server does nothing and does not stay waiting")
	local p2, s2 = make(VIEWS[2])
	p2:open("codes")
	H.step(10)
	check(p2._code_empty.visible and p2._code_empty.text == "Carregando os códigos…", "while the codes are on their way: loading")
	answer(s2, { action = "state", ok = true, text = "", codes = {}, codes_read = true })
	check(p2._code_empty.text == "Nenhum código ainda. Preencha os campos acima e aperte CRIAR.", "no code yet: says how to make one")
	answer(s2, { action = "state", ok = true, text = "", codes = {}, codes_read = false })
	check(string.find(p2._status_l.text, "podem faltar códigos", 1, true) ~= nil, "a store that did not answer: said so")
	-- junk never breaks it
	for _, junk in { 5, "x", true } do
		s2.admin_result:Fire(junk)
	end
	check(p2.is_open, "an answer that is not a table is ignored")
	-- no lists yet: asked for
	local p3, s3 = make(VIEWS[1])
	s3.rank = nil
	p3:open("rank")
	H.step(10)
	check(s3.rank_asked == 1 and p3._rank_empty.text == "Carregando o ranking…", "no lists on this screen yet: asked for, and it says loading")
end

-- =============================================================================================
print("Session: the request and the answer")
do
	local OP = Protocol.OP
	local sent = {}
	local net = {
		connected = true,
		send = function(op, ...)
			table.insert(sent, table.pack(op, ...))
		end,
		listen = function() end,
	}
	local s = Session.new({
		now = function()
			return 0
		end,
		net = net,
	})
	check(s:admin("coins", { op = "see", who = "eu" }) == true, "admin: sent")
	local m = sent[#sent]
	check(m[1] == OP.ADMIN and m[2] == "coins" and m[3].who == "eu" and m.n == 3, "OP.ADMIN, the action and its table")
	check(s:admin("state") == true and type(sent[#sent][3]) == "table", "no arguments: an empty table")
	net.connected = false
	local n = #sent
	check(s:admin("state") == false and #sent == n, "without a server: false, nothing sent")
	net.connected = true
	local got = nil
	local fired = 0
	s.admin_result:Connect(function(r)
		got = r
		fired += 1
	end)
	s:_on_net(OP.ADMIN_RESULT, {
		action = "code_new",
		ok = true,
		text = "Código X criado.",
		uid = 77.9,
		codes = {
			{ code = "X", info = "10 Coroas", state = "ligado", on = true, fixed = false },
			"junk",
			{ code = 5, info = "x" },
			{ code = "", info = "x" },
			{ code = "Y", info = 9, state = nil, on = "yes", fixed = 1 },
			{ code = string.rep("C", 90), info = string.rep("é", 200), state = string.rep("s", 60), on = true },
		},
	})
	check(fired == 1 and got.action == "code_new" and got.ok == true and got.text == "Código X criado.", "OP.ADMIN_RESULT: the answer reaches the panel")
	check(got.uid == 77 and got.denied == false and got.busy == false and got.codes_read == true, "its fields are of the right kind")
	check(#got.codes == 3, "rows that are not codes are dropped: " .. #got.codes)
	check(got.codes[2].code == "Y" and got.codes[2].info == "" and got.codes[2].state == "" and got.codes[2].on == false and got.codes[2].fixed == false, "a row's junk becomes nothing")
	check(#got.codes[3].code == 40 and #got.codes[3].state == 24, "long texts are cut")
	check(#got.codes[3].info <= 160 and utf8.len(got.codes[3].info) ~= nil, "... at the end of a whole letter")
	for _, junk in { 5, "x", false } do
		s:_on_net(OP.ADMIN_RESULT, junk)
	end
	check(fired == 1, "an answer that is not a table never reaches the panel")
	s:_on_net(OP.ADMIN_RESULT, {})
	check(fired == 2 and got.ok == false and got.text == "" and got.codes == nil and got.uid == nil, "an empty answer is a failure with nothing in it")
	local rows = {}
	for i = 1, 400 do
		rows[i] = { code = "C" .. i, info = "", state = "ligado", on = true }
	end
	s:_on_net(OP.ADMIN_RESULT, { ok = true, text = string.rep("a", 900), codes = rows, uid = -3 })
	check(#got.codes == 300 and #got.text == 300 and got.uid == nil, "at most 300 codes and 300 bytes of text; a bad id is dropped")
end

-- =============================================================================================
print("the lobby's button, UIRoot, and the words")
do
	local ts = fs.readFile("src/client/UI/TitleScreen.luau")
	local function tsh(text: string): boolean
		return string.find(ts, text, 1, true) ~= nil
	end
	check(tsh('UITheme.button("ADMIN", "GlassButton", "settings", 38.0)'), "the title has the ADMIN button")
	check(tsh("admin:set_visible(false)"), "hidden when made")
	check(tsh("local on = self.ctx:admin() == true") and tsh("self._admin_b:set_visible(on)"), "shown only for a game admin")
	check(tsh("if self.ctx:admin() then\n\t\t\tself.open_admin:Fire()"), "a press opens the panel only for a game admin")
	local ux = fs.readFile("src/client/UI/UICtx.luau")
	check(string.find(ux, 'lp:GetAttribute("AF_Admin") == true', 1, true) ~= nil, "a game admin: the attribute the server sets")
	local n = 0
	for _, path in fs.readDir("src/client/UI") do
		local src = fs.readFile("src/client/UI/" .. path)
		if string.find(src, 'SetAttribute("AF_Admin"', 1, true) ~= nil then
			n += 1
		end
	end
	for _, path in { "src/client/Session.luau", "src/client/UI/AdminPanel.luau" } do
		if string.find(fs.readFile(path), "SetAttribute", 1, true) ~= nil then
			n += 1
		end
	end
	check(n == 0, "nothing on the client sets that attribute")

	local src = fs.readFile("src/client/UI/UIRoot.luau")
	local function has(text: string): boolean
		return string.find(src, text, 1, true) ~= nil
	end
	check(has('local AdminPanel = require("./AdminPanel")'), "UIRoot loads the panel")
	check(has("local admin_panel = AdminPanel.new(ctx)") and has("self.admin_panel = admin_panel") and has("root:add_child(admin_panel)"), "makes it, and adds it to the screen")
	check(has("title.open_admin:Connect(function()") and has("function UIRoot.open_admin(self, page: string?)"), "the title's button opens it")
	check(has("if p == nil or p.is_open or not self.ctx:admin() then"), "... only for a game admin")
	check(has("self.admin_panel:bind(session)"), "it is given the session")
	check(has("picker, admin_panel, locker"), "nothing behind it takes a press")
	local at = string.find(src, "function UIRoot._window_open", 1, true)
	check(string.find(string.sub(src, at, at + 500), "self.admin_panel,", 1, true) ~= nil, "the tutorial's question waits for it to close")
	check(has("or (self.admin_panel ~= nil and self.admin_panel.is_open)"), "open, it is a modal for the input gate")
	check(has("and not (self.admin_panel ~= nil and self.admin_panel.is_open)"), "and nothing opens by itself over it")
	check(has('guard("AdminPanel.tick", self.admin_panel.tick, self.admin_panel)'), "it ticks while open")
	check(has('if scr ~= "title" and self.admin_panel ~= nil and self.admin_panel.is_open then'), "a match that starts closes it")

	-- every text the panel writes has its Portuguese
	local panel = fs.readFile("src/client/UI/AdminPanel.luau")
	local missing = {}
	local seen = 0
	local function need(text: string)
		seen += 1
		if LangPt[text] == nil then
			table.insert(missing, text)
		end
	end
	for text in string.gmatch(panel, 'self:_say%(%s*"([^"]+)"') do
		need(text)
	end
	for text in string.gmatch(panel, 'self:_field%(\'([^\']+)\'') do
		need(text)
	end
	for text in string.gmatch(panel, 'self:_field%("([^"]+)"') do
		if string.find(text, "%a") ~= nil then
			need(text)
		end
	end
	for text in string.gmatch(panel, 'self:_labelled%("([^"]+)"') do
		need(text)
	end
	for text in string.gmatch(panel, 'title = "([^"]+)"') do
		if text ~= "RANKING" then
			need(text)
		end
	end
	for text in string.gmatch(panel, 'text = if [^\n]- then "([^"]+)" else "([^"]+)"') do
		need(text)
	end
	for _, text in {
		"OWNER PANEL", "GIVE", "TAKE", "SEE BALANCE", "CREATE", "TURN ON", "TURN OFF", "DELETE", "REMOVE", "REMOVE FROM RANKING",
		"SURE? PRESS AGAIN", "STUDIO LIST", "ADMIN", "Loading the ranking…", "Nobody on this list yet.", "Loading the codes…",
		"No codes yet. Fill in the fields above and press CREATE.", "The codes could not be loaded. Close and open the panel again.",
		"Only the game's owner sees this. The server checks every action.",
		"By name: only players on this server. By numeric ID: any account, even offline.",
	} do
		need(text)
		check(string.find(panel, text, 1, true) ~= nil or string.find(ts, text, 1, true) ~= nil, "the code writes: " .. text)
	end
	check(seen >= 40, "the panel's texts were found: " .. seen)
	check(#missing == 0, "every text of the panel has its Portuguese; missing: " .. table.concat(missing, " | "))
end

for _, p in H.problems() do
	check(false, "a property Roblox does not have: " .. p)
end
print(string.format("painel_admin_tela: %d checks, %d failed", checks, failed))
if failed > 0 then
	error("painel_admin_tela: failed")
end
