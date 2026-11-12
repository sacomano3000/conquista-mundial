--!nocheck
-- "Confirmar compra?" (2026-11-11): a purchase paid with Coroas asks once more before anything is spent
-- (client/UI/ConfirmBuy; the Coleção's crate, the opening show's "another", an offer of the Loja
-- Misteriosa, an item of the Arsenal). Checked here, outside Roblox:
--   * a press on the price asks the server nothing: the question opens, with what, how much and what is left;
--   * Cancel, a press outside, or the seller closing: nothing bought, and the window under it stays;
--   * Confirm buys once; the second press of a double click does not confirm;
--   * the buttons behind the question are refused;
--   * the purchase is checked again on Confirm (Coroas that went meanwhile buy nothing);
--   * Robux purchases and presses that buy nothing (too few Coroas) open no question;
--   * UIRoot gives the question to the three sellers, above them and above the opening show.
--   lune run tests/confirmar_compra.luau
local H = require("./ui_harness")
local fs = require("@lune/fs")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Signal = require("../src/shared/Core/Signal")
local UICtx = require("../src/client/UI/UICtx")
local UITheme = require("../src/client/UI/UITheme")
local W = require("../src/client/UI/Widgets")
local Locker = require("../src/client/UI/Locker")
local MysteryShop = require("../src/client/UI/MysteryShop")
local CrateOpening = require("../src/client/UI/CrateOpening")
local Arsenal = require("../src/client/UI/Arsenal")
local Catalog = require("../src/shared/Data/Arsenal")
local ConfirmBuy = require("../src/client/UI/ConfirmBuy")
local Shop = require("../src/shared/Data/Shop")
local Lang = require("../src/shared/Data/Lang")
Lang.use("pt")

local checks, failed = 0, 0
local function check(ok: boolean, what: string)
	checks += 1
	if not ok then
		failed += 1
		print("FAIL: " .. what)
	end
end

-- the question's clock is the test's
local clock = 100.0
ConfirmBuy.now = function()
	return clock
end
MysteryShop.now = function()
	return 20000 * 86400 + 43200
end

local function session(stars: number, robux: boolean?): any
	local s = {
		inventory = {
			owned = {},
			equipped = {},
			crates_bought = 0,
			crates_allowed = robux == true,
			crates_stars = robux ~= true,
			stars = stars,
		},
		credits = { crate = 0 },
		inventory_changed = Signal.new(),
		credits_changed = Signal.new(),
		crate_result = Signal.new(),
		crates_result = Signal.new(),
		shop_result = Signal.new(),
		sent = {},
	}
	s.inventory.unlocks = {}
	s.unlocked = Signal.new()
	s.unlock_result = Signal.new()
	for _, name in { "open_crate", "buy_crates", "shop_pick", "shop_buy", "equip", "report", "buy_unlock" } do
		s[name] = function(_self, ...)
			table.insert(s.sent, { name, ... })
			return true
		end
	end
	return s
end

--- How many times `name` was asked of the server.
local function asked(s: any, name: string): number
	local n = 0
	for _, e in s.sent do
		if e[1] == name then
			n += 1
		end
	end
	return n
end

--- The texts drawn under `node`, glued, without spaces (a spaced title is one letter a GuiObject).
local function shown(node: any): string
	local out = {}
	local function add(g: any)
		if type(g.Text) == "string" then
			table.insert(out, g.Text)
		end
	end
	add(node.gui)
	for _, d in node.gui:GetDescendants() do
		add(d)
	end
	return (string.gsub(table.concat(out), "%s", ""))
end

local function press(b: any)
	-- (as Roblox reports a click or a tap that ended on the button)
	H.fire(b.gui, "Activated")
	H.step(1)
end

-- (where a press is: Widgets asks Roblox's services, which are not here; the event carries it)
W.input_pos = function(io: any): Vector2
	return Vector2.new(io.Position.X, io.Position.Y)
end
W.screen_to_logical = function(v: Vector2): Vector2
	return v / UITheme.scale
end

--- A press at (x, y), in screen px, as Roblox gives it to a frame under the pointer.
local function press_at(node: any, x: number, y: number)
	H.fire(node.gui, "InputBegan", {
		UserInputType = Enum.UserInputType.MouseButton1,
		UserInputState = Enum.UserInputState.Begin,
		Position = Vector3.new(x, y, 0),
	})
	H.step(1)
end

--- The interface as UIRoot stacks it: the two sellers, the opening show, the question on top.
local function make(view: any, stars: number, robux: boolean?)
	local root, gui = H.root(view[2], view[3], view[4])
	local s = session(stars, robux)
	local ctx = UICtx.new()
	ctx.vp = root.vp
	ctx.compact = view[4]
	ctx.touch = view[4]
	ctx.touch_device = view[4]
	ctx.session = s
	local k = UITheme.scale
	ctx.reserved_top_left = Rect.new(0, 0, (if view[4] then 200 else 280) / k, (if view[4] then 44 else 58) / k)
	function ctx:sfx() end
	local t = { root = root, gui = gui, s = s, toasts = {} }
	t.locker = Locker.new(ctx)
	t.locker._toast = function(_l, text)
		table.insert(t.toasts, text)
	end
	root:add_child(t.locker)
	t.shop = MysteryShop.new(ctx)
	t.shop.show_item = Locker.show_item
	t.shop._toast = function(_m, text)
		table.insert(t.toasts, text)
	end
	root:add_child(t.shop)
	t.opening = CrateOpening.new(ctx)
	-- (the show itself is a loop of waits, drawn by tests/telas: here only what is asked of it)
	t.plays = 0
	t.opening.play = function()
		t.plays += 1
	end
	t.locker:set_opening(t.opening)
	root:add_child(t.opening)
	t.arsenal = Arsenal.new(ctx)
	root:add_child(t.arsenal)
	t.confirm = ConfirmBuy.new(ctx)
	t.locker:set_confirm(t.confirm)
	t.shop.confirm = t.confirm
	t.arsenal.confirm = t.confirm
	root:add_child(t.confirm)
	local windows = { t.locker, t.shop, t.opening, t.arsenal, t.confirm }
	for _, w in windows do
		W.add_blocker(w)
	end
	W.guard_presses(root, function()
		return windows
	end)
	t.locker:bind(s)
	t.shop:bind(s)
	t.arsenal:bind(s)
	t.answers = {}
	t.confirm.answered:Connect(function(yes)
		table.insert(t.answers, yes)
	end)
	return t
end

local function inside(obj: any, what: string)
	local x, y, w, h = H.rect(obj)
	check(
		x >= -0.5 and y >= -0.5 and x + w <= H.view.X + 0.5 and y + h <= H.view.Y + 0.5,
		string.format("%s inside the screen (%.0f, %.0f, %.0f x %.0f in %d x %d)", what, x, y, w, h, H.view.X, H.view.Y)
	)
end

local VIEWS = {
	{ "pc", 1280, 720, false },
	{ "celular", 844, 390, true },
}

-- ---------------------------------------------------------------------------------------------
-- The Coleção's crate
-- ---------------------------------------------------------------------------------------------
for _, view in VIEWS do
	local on = " (" .. view[1] .. ")"
	local t = make(view, 31250)
	local l, c, s = t.locker, t.confirm, t.s
	l:open()
	l:_set_tab(2)
	l:apply_layout()
	H.step(40)
	check(c.is_open == false and c.visible ~= true, "no question before a press" .. on)

	-- the price is pressed: a question, nothing asked of the server
	press(l._buy)
	check(c.is_open == true and c.visible == true, "pressing the price opens the question" .. on)
	check(asked(s, "buy_crates") == 0 and l._pending == nil, "... and buys nothing yet" .. on)
	H.step(30)
	local text = shown(c)
	check(string.find(text, "CONFIRMARCOMPRA?", 1, true) ~= nil, "it asks CONFIRMAR COMPRA?" .. on .. ": " .. text)
	check(string.find(text, "BAÚDEBANDEIRAS", 1, true) ~= nil, "it names the crate of the tab" .. on)
	check(string.find(text, "25.000Coroas", 1, true) ~= nil, "it shows the price, 25.000 Coroas" .. on)
	check(string.find(text, "Vocêtem31.250Coroas.Vaificarcom6.250.", 1, true) ~= nil, "it shows what the player has and what is left" .. on)
	check(c._no.text == "Cancelar" and c._yes.text == "Confirmar", "its answers: Cancelar, Confirmar" .. on)
	-- where it stands
	inside(c._panel.gui, "the question's window" .. on)
	local px, py, pw, ph = H.rect(c._panel.gui)
	for _, b in { c._no, c._yes } do
		local x, y, w, h = H.rect(b.gui)
		check(x >= px - 0.5 and y >= py - 0.5 and x + w <= px + pw + 0.5 and y + h <= py + ph + 0.5, "a button inside the question's window" .. on)
		check(h >= 34 and w >= 80, string.format("a button large enough to press (%.0f x %.0f)%s", w, h, on))
	end
	local nx, _, nw = H.rect(c._no.gui)
	local yx = H.rect(c._yes.gui)
	check(nx + nw <= yx + 0.5, "Cancelar on the left of Confirmar, apart" .. on)
	-- (the question is drawn above the Coleção and above the opening show)
	local kids = t.root.children
	check(table.find(kids, c) > table.find(kids, l) and table.find(kids, c) > table.find(kids, t.opening), "the question is drawn above the sellers and the opening show" .. on)

	-- the buttons behind the question are refused
	clock += 1
	local tab_before = l._tab
	press(l._buy)
	press(l._tabs[3])
	check(c.is_open == true and asked(s, "buy_crates") == 0 and l._tab == tab_before, "the Coleção's buttons behind the question do nothing" .. on)
	press(l._close_b)
	check(l.is_open == true, "... its close button too" .. on)

	-- Cancel
	press(c._no)
	check(c.is_open == false, "Cancelar closes the question" .. on)
	check(asked(s, "buy_crates") == 0 and l._pending == nil and l.is_open == true, "... nothing bought, the Coleção still open" .. on)
	check(#t.answers == 1 and t.answers[1] == false, "... answered no" .. on)

	-- a press outside the question (Roblox gives it to the Coleção's backdrop too, in either order)
	clock += 1
	press(l._buy)
	check(c.is_open == true, "the price again: the question again" .. on)
	clock += 1
	press_at(c._panel, px + pw * 0.5, py + 10)
	press_at(c._dim, px + pw * 0.5, py + 10)
	check(c.is_open == true, "a press on the question's own ground cancels nothing" .. on)
	press_at(l._dim, 3, 3)
	check(l.is_open == true and c.is_open == true, "a press outside reaching the Coleção first does not close the Coleção" .. on)
	press_at(c._dim, 3, 3)
	check(c.is_open == false and asked(s, "buy_crates") == 0, "a press outside the question cancels it: nothing bought" .. on)
	press_at(l._dim, 3, 3)
	check(l.is_open == true, "... and the same press does not close the Coleção under it" .. on)
	clock += 1
	H.step(20)

	-- Confirm: one crate, once
	press(l._buy)
	clock += 1
	press(c._yes)
	check(c.is_open == false and asked(s, "buy_crates") == 1, "Confirmar buys: the server is asked once" .. on)
	check(s.sent[#s.sent][1] == "buy_crates" and s.sent[#s.sent][2] == 1, "... for one crate" .. on)
	check(l._pending ~= nil and l._pending.phase == "stars" and l._pending.kind == "flag", "... of the tab it was bought in" .. on)
	press(c._yes)
	check(asked(s, "buy_crates") == 1, "a press on the answered question buys nothing more" .. on)
	s.credits.crate = 1
	s.crates_result:Fire(true)
	check(s.sent[#s.sent][1] == "open_crate" and s.sent[#s.sent][2] == "flag", "then the crate opens" .. on)
	check(t.plays == 1, "... with its show" .. on)

	-- (another interface from here on: Widgets' press guard is the last one made)
	-- a double click: the second press lands before the question takes answers
	local t2 = make(view, 31250)
	t2.locker:open()
	t2.locker:_set_tab(2)
	t2.locker:apply_layout()
	H.step(10)
	press(t2.locker._buy)
	clock += 0.1
	press(t2.confirm._yes)
	check(t2.confirm.is_open == true and asked(t2.s, "buy_crates") == 0, "a press 0.1 s after it opened confirms nothing (a double click)" .. on)
	press_at(t2.confirm._dim, 5, 5)
	check(t2.confirm.is_open == true, "... nor does it cancel" .. on)
	clock += ConfirmBuy.ARM_S
	press(t2.confirm._yes)
	check(t2.confirm.is_open == false and asked(t2.s, "buy_crates") == 1, "... a moment later it does" .. on)
end

-- ---------------------------------------------------------------------------------------------
-- What must not open a question, and what happens under an open one
-- ---------------------------------------------------------------------------------------------
do
	local view = VIEWS[1]
	-- too few Coroas: nothing to confirm
	local t = make(view, 4000)
	t.locker:open()
	t.locker:apply_layout()
	H.step(10)
	t.locker:_buy_pressed("stars")
	check(t.confirm.is_open == false and asked(t.s, "buy_crates") == 0, "too few Coroas: no question, nothing bought")

	-- Robux: Roblox asks, this window does not
	t = make(view, 31250, true)
	t.locker:open()
	t.locker:apply_layout()
	H.step(10)
	local CrateProduct = require("../src/shared/Data/Products").crate
	local shipped = CrateProduct.id
	t.locker:_buy_pressed("robux")
	check(shipped > 0 and t.confirm.is_open == false and #t.toasts == 0 and asked(t.s, "buy_crates") == 0, "the Robux button opens no question of ours (Roblox asks), and spends no Coroas")
	CrateProduct.id = 0
	t.locker:_buy_pressed("robux")
	CrateProduct.id = shipped
	check(t.confirm.is_open == false and #t.toasts == 1, "... nor with no product made: a notice")

	-- the Coleção closes under the question: the purchase goes with it
	t = make(view, 31250)
	t.locker:open()
	t.locker:apply_layout()
	H.step(10)
	press(t.locker._buy)
	check(t.confirm.is_open == true, "a question to close")
	t.locker:close()
	H.step(2)
	check(t.confirm.is_open == false and asked(t.s, "buy_crates") == 0, "the Coleção closing takes the question with it: nothing bought")
	clock += 1
	press(t.confirm._yes)
	check(asked(t.s, "buy_crates") == 0, "... and Confirmar on the closed question buys nothing")
	-- (another seller's closing leaves a question that is not its own)
	t.locker:open()
	H.step(10)
	clock += 1
	press(t.locker._buy)
	t.shop:close()
	t.confirm:cancel(t.shop)
	check(t.confirm.is_open == true, "the shop's closing leaves the Coleção's question")
	t.confirm:cancel()

	-- Coroas gone between the press and the answer: checked again, nothing bought
	t = make(view, 31250)
	t.locker:open()
	t.locker:apply_layout()
	H.step(10)
	press(t.locker._buy)
	t.s.inventory.stars = 500
	clock += 1
	press(t.confirm._yes)
	check(t.confirm.is_open == false and asked(t.s, "buy_crates") == 0, "Coroas that went meanwhile: Confirmar buys nothing")

	-- the opening show's "another": a purchase too, so it asks too, above the show
	t = make(view, 31250)
	t.locker:open()
	t.locker:_set_tab(3)
	t.locker:apply_layout()
	H.step(10)
	t.opening.again:Fire()
	check(t.confirm.is_open == true and asked(t.s, "buy_crates") == 0, "the opening show's \"another\" asks before buying")
	check(string.find(shown(t.confirm), "BAÚDEPETS", 1, true) ~= nil, "... naming the crate of that tab")
	clock += 1
	press(t.confirm._yes)
	check(asked(t.s, "buy_crates") == 1 and t.locker._pending.kind == "pet", "... and Confirmar buys one pet crate")
	-- (with a crate waiting, "another" opens it: nothing is bought, nothing to confirm)
	t = make(view, 31250)
	t.locker:open()
	t.locker:apply_layout()
	H.step(10)
	t.s.credits.crate = 1
	t.opening.again:Fire()
	check(t.confirm.is_open == false and asked(t.s, "open_crate") == 1 and asked(t.s, "buy_crates") == 0, "a waiting crate opens with no question: nothing is spent")

	-- without the question (a Locker on its own, as some tests build it) a press buys, as before
	local root = H.root(1280, 720, false)
	local s = session(31250)
	local ctx = UICtx.new()
	ctx.vp = root.vp
	ctx.session = s
	ctx.reserved_top_left = Rect.new(0, 0, 280 / UITheme.scale, 58 / UITheme.scale)
	function ctx:sfx() end
	local alone = Locker.new(ctx)
	root:add_child(alone)
	alone:bind(s)
	alone:open()
	H.step(5)
	alone:_buy_pressed("stars")
	check(asked(s, "buy_crates") == 1, "a Locker given no question buys at once")
end

-- ---------------------------------------------------------------------------------------------
-- The Loja Misteriosa
-- ---------------------------------------------------------------------------------------------
do
	local offers = Shop.offers(Shop.day(MysteryShop.now()), 0)
	-- (an offer for Coroas is rare, Data/MyShop.loja.chance_coroas_comum: the day's first offer is
	-- made one here, as Shop.offers gives it)
	local robux = offers[1]
	local coroas = table.clone(offers[2])
	coroas.currency = "stars"
	coroas.price = Shop.STAR_PRICES.common
	coroas.product = nil
	check(robux ~= nil and robux.currency == "robux" and coroas.price == 6000, "an offer for Robux and one for Coroas (6.000)")
	if coroas ~= nil and robux ~= nil then
		local t = make(VIEWS[1], coroas.price + 250)
		local m, c, s = t.shop, t.confirm, t.s
		m:open()
		H.step(20)
		m:_pressed(coroas)
		check(c.is_open == true and asked(s, "shop_buy") == 0 and m._pending == nil, "an offer for Coroas: a question first, nothing bought")
		H.step(20)
		local text = shown(c)
		local name = Lang.t(Cosmetics.item(coroas.id).name)
		check(string.find(text, (string.gsub(name, "%s", "")), 1, true) ~= nil, "it names the item (" .. name .. "): " .. text)
		check(string.find(text, (string.gsub(UICtx.commas(coroas.price) .. " Coroas", "%s", "")), 1, true) ~= nil, "it shows the offer's price")
		check(string.find(text, "Vaificarcom250.", 1, true) ~= nil, "it shows what is left")
		inside(c._panel.gui, "the question's window over the shop")
		-- a press outside: the question goes, the shop stays
		clock += 1
		press_at(m._dim, 3, 3)
		press_at(c._dim, 3, 3)
		press_at(m._dim, 3, 3)
		check(c.is_open == false and m.is_open == true and asked(s, "shop_buy") == 0, "a press outside cancels the question, not the shop; nothing bought")
		clock += 1
		-- Cancel
		m:_pressed(coroas)
		clock += 1
		press(c._no)
		check(c.is_open == false and asked(s, "shop_buy") == 0 and m._pending == nil, "Cancelar: nothing bought")
		-- Confirm
		m:_pressed(coroas)
		clock += 1
		press(c._yes)
		check(asked(s, "shop_buy") == 1 and s.sent[#s.sent][2] == coroas.id, "Confirmar buys that item, once")
		check(m._pending ~= nil and m._pending.id == coroas.id and m._pending.phase == "buy", "... and the shop waits for the server")
		-- an owned offer is worn, a Robux one is Roblox's to confirm: no question
		m._pending = nil
		s.inventory.owned[coroas.id] = true
		m:_pressed(coroas)
		check(c.is_open == false and s.sent[#s.sent][1] == "equip", "an owned offer is worn: no question")
		m:_pressed(robux)
		check(c.is_open == false, "a Robux offer opens no question of ours")
		-- too few Coroas
		local t3 = make(VIEWS[1], coroas.price - 1)
		t3.shop:open()
		H.step(5)
		t3.shop:_pressed(coroas)
		check(t3.confirm.is_open == false and asked(t3.s, "shop_buy") == 0 and #t3.toasts == 1, "too few Coroas: a notice, no question")
		-- the shop closes under the question
		local t4 = make(VIEWS[1], coroas.price)
		t4.shop:open()
		H.step(5)
		t4.shop:_pressed(coroas)
		t4.shop:close()
		check(t4.confirm.is_open == false and asked(t4.s, "shop_buy") == 0, "the shop closing takes the question with it")
	end
end

-- ---------------------------------------------------------------------------------------------
-- The Arsenal: its Coroas button asks in the same window (before: a second press on the button)
-- ---------------------------------------------------------------------------------------------
do
	local mega = Catalog.item("mega")
	check(mega ~= nil and mega.stars == 20000, "the Arsenal's first item costs 20.000 Coroas")
	local t = make(VIEWS[1], 31250)
	local a, c, s = t.arsenal, t.confirm, t.s
	a:open("mega")
	H.step(20)
	a:_stars_pressed(mega)
	check(c.is_open == true and asked(s, "buy_unlock") == 0 and a._pending == nil, "the Arsenal's Coroas button: a question first, nothing bought")
	check(a._confirm == nil, "... and the button does not wait for a second press any more")
	H.step(20)
	local text = shown(c)
	check(string.find(text, (string.gsub(Lang.t(mega.title), "%s", "")), 1, true) ~= nil, "it names the item (" .. Lang.t(mega.title) .. "): " .. text)
	check(string.find(text, "20.000Coroas", 1, true) ~= nil, "it shows the item's price")
	check(string.find(text, "Vocêtem31.250Coroas.Vaificarcom11.250.", 1, true) ~= nil, "it shows what is left")
	inside(c._panel.gui, "the question's window over the Arsenal")
	-- a second press on the Arsenal's button (a double click) confirms nothing: it asks again
	clock += 0.1
	a:_stars_pressed(mega)
	check(asked(s, "buy_unlock") == 0 and c.is_open == true, "a second press on the Arsenal's button buys nothing")
	-- a press outside: the question goes, the Arsenal stays
	clock += 1
	press_at(a._dim, 3, 3)
	press_at(c._dim, 3, 3)
	press_at(a._dim, 3, 3)
	check(c.is_open == false and a.is_open == true and asked(s, "buy_unlock") == 0, "a press outside cancels the question, not the Arsenal; nothing bought")
	clock += 1
	-- Cancel
	a:_stars_pressed(mega)
	clock += 1
	press(c._no)
	check(c.is_open == false and asked(s, "buy_unlock") == 0 and a._pending == nil, "Cancelar: nothing unlocked")
	-- Confirm
	a:_stars_pressed(mega)
	clock += 1
	press(c._yes)
	local which = nil
	for _, e in s.sent do
		if e[1] == "buy_unlock" then
			which = e[2]
		end
	end
	check(asked(s, "buy_unlock") == 1 and which == "mega", "Confirmar unlocks that item, once")
	check(a._pending ~= nil and a._pending.key == "mega" and a._pending.how == "stars", "... and the Arsenal waits for the server")
	-- too few Coroas: told so, no question
	local t2 = make(VIEWS[1], 5000)
	t2.arsenal:open("mega")
	H.step(5)
	t2.arsenal:_stars_pressed(mega)
	check(t2.confirm.is_open == false and asked(t2.s, "buy_unlock") == 0, "too few Coroas in the Arsenal: no question, nothing bought")
	-- the Arsenal closes under the question
	local t3 = make(VIEWS[1], 31250)
	t3.arsenal:open("mega")
	H.step(5)
	t3.arsenal:_stars_pressed(mega)
	check(t3.confirm.is_open == true, "a question over the Arsenal")
	t3.arsenal:close()
	check(t3.confirm.is_open == false and asked(t3.s, "buy_unlock") == 0, "the Arsenal closing takes the question with it")
	-- Coroas gone between the press and the answer
	local t4 = make(VIEWS[1], 31250)
	t4.arsenal:open("mega")
	H.step(5)
	t4.arsenal:_stars_pressed(mega)
	t4.s.inventory.stars = 100
	clock += 1
	press(t4.confirm._yes)
	check(asked(t4.s, "buy_unlock") == 0, "Coroas that went meanwhile: Confirmar unlocks nothing")
	-- an Arsenal given no question keeps RoWorld's two presses
	local t5 = make(VIEWS[1], 31250)
	t5.arsenal.confirm = nil
	t5.arsenal:open("mega")
	H.step(5)
	t5.arsenal:_stars_pressed(mega)
	check(asked(t5.s, "buy_unlock") == 0 and t5.arsenal._confirm == "mega", "with no question: the first press asks on the button")
	t5.arsenal:_stars_pressed(mega)
	check(asked(t5.s, "buy_unlock") == 1, "... and the second buys")
end

-- ---------------------------------------------------------------------------------------------
-- UIRoot makes the question, gives it to the sellers and stacks it on top
-- ---------------------------------------------------------------------------------------------
do
	local src = fs.readFile("src/client/UI/UIRoot.luau")
	local function at(text: string): number
		return (string.find(src, text, 1, true)) or 0
	end
	check(at('require("./ConfirmBuy")') > 0, "UIRoot loads the question")
	check(at("locker:set_confirm(confirm)") > 0, "UIRoot gives it to the Coleção")
	check(at("flag_shop.confirm = confirm") > 0, "UIRoot gives it to the Loja Misteriosa")
	check(at("arsenal.confirm = confirm") > 0, "UIRoot gives it to the Arsenal")
	check(at("root:add_child(confirm)") > at("root:add_child(arsenal)") and at("root:add_child(arsenal)") > 0, "UIRoot stacks it above the Arsenal")
	check(at("root:add_child(confirm)") > at("root:add_child(opening)") and at("root:add_child(opening)") > at("root:add_child(locker)") and at("root:add_child(locker)") > 0, "UIRoot stacks it above the opening show, the show above the Coleção")
	check(at("root:add_child(confirm)") > at("root:add_child(flag_shop)") and at("root:add_child(flag_shop)") > 0, "... and above the Loja Misteriosa")
	check(string.find(src, "local windows = {[^}]*opening, ask, confirm }") ~= nil, "UIRoot counts it among the windows that take the presses")
	check(at("self.confirm_buy:apply_layout()") > 0, "UIRoot lays it out again when the screen changes")
end

for _, p in H.problems() do
	check(false, "a property Roblox lacks: " .. p)
end

print(string.format("confirmar_compra: %d checks, %d failed", checks, failed))
if failed > 0 then
	error("confirmar_compra: failed")
end
