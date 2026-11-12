--!nocheck
-- The game's own screens, built outside Roblox (tests/ui_harness.luau) on a desktop and on a phone:
-- every one must build, set no property Roblox lacks, and keep its window inside the screen. Each is
-- also saved to assets/telas/<name>.json, which tools/arte/telas.py draws (assets/previa-<name>.png).
--   lune run tests/telas.luau
local H = require("./ui_harness")
local fs = require("@lune/fs")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Signal = require("../src/shared/Core/Signal")
local UICtx = require("../src/client/UI/UICtx")
local UITheme = require("../src/client/UI/UITheme")

-- (the texts as the player reads them: Data/LangPt)
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

if not fs.isDir("assets/telas") then
	fs.writeDir("assets/telas")
end

local VIEWS = {
	{ "pc", 1280, 720, false },
	{ "celular", 844, 390, true },
}

--- A player's session as the screens read it: `owned` ids, what they wear, Coroas, waiting crates.
local function session(opts: any): any
	local s = {
		inventory = {
			owned = {},
			equipped = opts.equipped or {},
			crates_bought = 0,
			crates_allowed = opts.robux == true,
			crates_stars = opts.robux ~= true,
			stars = opts.stars or 0,
			-- (the player's card on the title: UI/PlayerCard)
			ranked = opts.ranked,
			stats = opts.stats,
			login = opts.login,
		},
		credits = { crate = opts.crates or 0 },
		inventory_changed = Signal.new(),
		credits_changed = Signal.new(),
		crate_result = Signal.new(),
		crates_result = Signal.new(),
		shop_result = Signal.new(),
		sent = {},
	}
	for _, id in opts.owned or {} do
		s.inventory.owned[id] = true
	end
	for _, name in { "open_crate", "buy_crates", "shop_pick", "shop_buy", "equip", "report" } do
		s[name] = function(_self, ...)
			table.insert(s.sent, { name, ... })
			return true
		end
	end
	return s
end

--- The interface's context as UIRoot makes it: the screen's size, phone or not, and the corner Roblox
--- keeps for its own top bar (the menu and chat buttons, top left).
local function ctx_for(root: any, view: any, s: any): any
	local ctx = UICtx.new()
	ctx.vp = root.vp
	ctx.compact = view[4]
	ctx.touch = view[4]
	ctx.touch_device = view[4]
	ctx.session = s
	local k = UITheme.scale
	ctx.reserved_top_left = Rect.new(0, 0, (if view[4] then 200 else 280) / k, (if view[4] then 44 else 58) / k)
	function ctx:sfx() end
	return ctx
end

--- `obj` (a GuiObject) lies inside the screen.
local function inside(obj: any, what: string)
	local x, y, w, h = H.rect(obj)
	check(
		x >= -0.5 and y >= -0.5 and x + w <= H.view.X + 0.5 and y + h <= H.view.Y + 0.5,
		string.format("%s inside the screen (%.0f, %.0f, %.0f x %.0f in %d x %d)", what, x, y, w, h, H.view.X, H.view.Y)
	)
end

--- No two of `list` (GuiObjects) overlap.
local function apart(list: { any }, what: string)
	for i = 1, #list do
		local ax, ay, aw, ah = H.rect(list[i])
		for j = i + 1, #list do
			local bx, by, bw, bh = H.rect(list[j])
			local over = ax < bx + bw - 0.5 and bx < ax + aw - 0.5 and ay < by + bh - 0.5 and by < ay + ah - 0.5
			check(not over, string.format("%s: pieces %d and %d do not overlap", what, i, j))
		end
	end
end

local function run(name: string, view: any, fn: (any, any) -> ())
	local root, gui = H.root(view[2], view[3], view[4])
	local ok, err = xpcall(function()
		fn(root, gui)
	end, function(e)
		return tostring(e) .. "\n" .. debug.traceback()
	end)
	check(ok, name .. " (" .. view[1] .. ") builds: " .. tostring(err))
	H.save(gui, string.format("assets/telas/%s-%s.json", name, view[1]))
end

local SOME = { "stripes", "bricks", "flag_c01", "flag_c07", "flag_r03", "flag_e02", "pet_gato", "pet_coruja", "pet_dragao" }

-- ---------------------------------------------------------------------------------------------
-- The Coleção
-- ---------------------------------------------------------------------------------------------
local Locker = require("../src/client/UI/Locker")
for _, view in VIEWS do
	for tab, kind in Cosmetics.KINDS do
		run("colecao-" .. kind, view, function(root, gui)
			local s = session({
				owned = SOME,
				equipped = { skin = "bricks", flag = "flag_r03", pet = "pet_dragao" },
				stars = if kind == "pet" then 131250 else 31250,
				crates = 0,
				-- (the skins' tab as a player Roblox lets buy a paid crate sees it: Robux and Coroas
				-- side by side; the other two as a player it restricts: Coroas alone)
				robux = kind == "skin",
			})
			local l = Locker.new(ctx_for(root, view, s))
			root:add_child(l)
			l:bind(s)
			l:open()
			l:_set_tab(tab)
			l:apply_layout()
			H.step(40)
			inside(l._panel.gui, "the Coleção's window, tab " .. kind)
			inside(l._crate.gui, "the crate's card, tab " .. kind)
			inside(l._buy.gui, "the crate's price button, tab " .. kind)
			apart({ l._host.gui, l._crate.gui }, "the grid and the crate, tab " .. kind)
			apart({ l._head.gui, l._tab_row.gui, l._body.gui }, "head, tabs and body, tab " .. kind)
			check(#l._cards == #Cosmetics.of_kind(kind) + 1, "one card for each item of the tab, and None")
			-- the odds on show are the player's own for this tab, and add up to 100 %
			local sum = 0
			for _, e in Cosmetics.odds(s.inventory.owned, kind) do
				sum += e.odds
			end
			check(math.abs(sum - 1) < 1e-9, "the odds shown add up to 100 %")
			if kind == "skin" then
				-- both ways to pay: 9 Robux or 25.000 Coroas
				check(l._buy_r.visible == true and l._buy.visible == true, "Robux and Coroas buttons both on show")
				inside(l._buy_r.gui, "the crate's Robux button")
				apart({ l._buy_r.gui, l._buy.gui }, "the Robux and the Coroas buttons")
				check(tostring(l._buy_r.text) == "9", "one crate: 9 Robux (" .. tostring(l._buy_r.text) .. ")")
				check(tostring(l._buy.text) == "25.000", "one crate: 25.000 Coroas (" .. tostring(l._buy.text) .. ")")
				check(l._buy.disabled ~= true and l._buy_r.disabled ~= true, "both can be pressed")
				local cx, cy, cw, chh = H.rect(l._crate.gui)
				local bx, by, bw, bh = H.rect(l._buy_r.gui)
				local sx, sy, sw, sh = H.rect(l._buy.gui)
				check(bx >= cx - 0.5 and sx + sw <= cx + cw + 0.5 and by + bh <= cy + chh + 0.5 and sy + sh <= cy + chh + 0.5, "both buttons stand inside the crate's card")
				check(math.abs(by - sy) <= 0.5 and math.abs(bh - sh) <= 0.5 and bw >= 50, "side by side, the same height")
				-- (a crate product with no id: the button says so and asks nothing)
				local said = nil
				l._toast = function(_l, text)
					said = text
				end
				local CrateProduct = require("../src/shared/Data/Products").crate
				local shipped = CrateProduct.id
				check(type(shipped) == "number" and shipped > 0 and l:_has_product(), "the crate's Robux product is made (Data/MyProducts)")
				CrateProduct.id = 0
				local n0 = #s.sent
				l:_buy_pressed("robux")
				check(#s.sent == n0 and type(said) == "string" and l._pending == nil, "Robux with no product: a notice, nothing asked")
				-- (with it, as the game ships: no notice, no question of ours, no Coroas purchase; the
				-- prompt itself is Roblox's and cannot open outside it)
				CrateProduct.id = shipped
				said = nil
				l:_buy_pressed("robux")
				local asked_crates = 0
				for _, e in s.sent do
					if e[1] == "buy_crates" then
						asked_crates += 1
					end
				end
				check(said == nil and asked_crates == 0 and l._pending == nil, "Robux with the product: no notice, and no Coroas spent")
			else
				check(l._buy_r.visible ~= true and l._buy.visible == true, "a player Roblox restricts sees the Coroas button alone, tab " .. kind)
				local n0 = #s.sent
				l:_buy_pressed("robux")
				check(#s.sent == n0 and l._pending == nil, "and a Robux purchase cannot be asked for, tab " .. kind)
			end
			-- a duplicate pays Coroas (2026-11-12): the card says so, with the amount beside each chance
			do
				local want = { common = "+2.500", rare = "+6.000", epic = "+12.000", legendary = "+25.000" }
				local chance = { common = "80%", rare = "15%", epic = "4,5%", legendary = "0,5%" }
				local right, shown, odds_ok = true, true, true
				for id, text in want do
					local d = l._dups[id]
					right = right and d ~= nil and tostring(d.text) == text
					shown = shown and d ~= nil and d.visible ~= false
					odds_ok = odds_ok and tostring(l._odds[id].text) == chance[id]
				end
				check(right, "what a duplicate of each rarity pays is written in the crate's card, tab " .. kind)
				check(odds_ok, "the four chances are the published ones, whatever the player owns, tab " .. kind)
				if shown then
					for id in want do
						inside(l._dups[id].gui, "the duplicate's Coroas (" .. id .. "), tab " .. kind)
						apart({ l._odds[id].gui, l._dups[id].gui }, "the chance and the duplicate's Coroas (" .. id .. "), tab " .. kind)
					end
				end
				check(shown, "... and on show, tab " .. kind)
				local note = tostring(l._note.text)
				check(string.find(note, "repetido vira Coroas", 1, true) ~= nil and string.find(note, "Nunca", 1, true) == nil, "the note under the button says a duplicate becomes Coroas, tab " .. kind .. " (" .. note .. ")")
				local never = nil
				for _, d in l._crate.gui:GetDescendants() do
					if type(d.Text) == "string" and string.find(Lang.upper(Lang.t(d.Text)), "NUNCA", 1, true) ~= nil then
						never = d.Text
					end
				end
				check(never == nil, "nothing in the crate's card promises 'never a duplicate', tab " .. kind .. " (" .. tostring(never) .. ")")
				local sub_t = tostring(l._crate_sub.text)
				check(string.find(sub_t, "repetid", 1, true) ~= nil and string.find(sub_t, "ainda não tem", 1, true) == nil, "the crate no longer promises an item the player doesn't have, tab " .. kind .. " (" .. sub_t .. ")")
			end
			-- one crate a purchase (2026-11-10: the "how many" row is gone)
			check(l._qty_row == nil and l._plus == nil and l._minus == nil and l._qty_l == nil, "no row to pick how many crates, tab " .. kind)
			check(Locker.CRATE_MAX == 1 and l:_max_qty() == 1, "one crate at a time, tab " .. kind)
			check(tostring(l._buy.text) == "25.000", "the Coroas button shows one crate's price, tab " .. kind .. " (" .. tostring(l._buy.text) .. ")")
			for _, d in l._crate.gui:GetDescendants() do
				if type(d.Text) == "string" then
					check(d.Text ~= "+" and d.Text ~= "–" and d.Text ~= "Quantos", "nothing of the old row is drawn in the crate's card, tab " .. kind)
				end
			end
			if kind == "pet" then
				l:_buy_pressed("stars")
				check(s.sent[#s.sent][1] == "buy_crates" and s.sent[#s.sent][2] == 1, "buying asks the server for one crate")
				local asked = #s.sent
				l:_buy_pressed("stars")
				check(#s.sent == asked, "a second press while it is being bought asks nothing")
				s.credits.crate = 1
				s.crates_result:Fire(true)
				check(s.sent[#s.sent][1] == "open_crate" and s.sent[#s.sent][2] == "pet", "then it opens at once, as a pet crate")
				-- (the server's roll came: the crate is spent, none waits)
				s.credits.crate = 0
				-- (the answer goes to the crate's show with what a duplicate paid: here a Raro, 6.000)
				local told = nil
				l.opening = {
					play = function() end,
					resolve = function(_o, id, back)
						told = { id, back }
					end,
					fail = function() end,
				}
				l._pending = { phase = "opening", since = os.clock(), kind = "pet" }
				s.crate_result:Fire(true, "pet_lobo", 6000)
				check(told ~= nil and told[1] == "pet_lobo" and told[2] == 6000, "the server's answer reaches the crate's show: the item and the duplicate's Coroas")
				l.opening = nil
				l:_refresh_crate()
				H.step(4)
				check(l._pending == nil and l._open_b.visible ~= true, "no crate is left waiting: no OPEN button")
				-- a crate that waits from before (bought several at a time): it can still be opened
				s.credits.crate = 2
				l:_refresh_crate()
				H.step(4)
				check(l._open_b.visible == true, "crates that waited from before still show OPEN")
				inside(l._open_b.gui, "the OPEN button of crates that waited")
				inside(l._crate.gui, "the crate's card, with crates that waited")
				check(l._buy.visible ~= true and l._buy_r.visible ~= true and l:_max_qty() == 0, "... and nothing is sold until they are opened")
				local held = #s.sent
				l:_buy_pressed("stars")
				check(#s.sent == held and l._pending == nil, "... a buy asked for anyway asks the server nothing")
				s.credits.crate = 0
				l:_refresh_crate()
				H.step(4)
			end
		end)
	end
end

-- ---------------------------------------------------------------------------------------------
-- "Confirmar compra?": asked before Coroas are spent (over the Coleção; tests/confirmar_compra.luau)
-- ---------------------------------------------------------------------------------------------
local ConfirmBuy = require("../src/client/UI/ConfirmBuy")
for _, view in VIEWS do
	run("confirmar", view, function(root, gui)
		local s = session({ owned = SOME, equipped = { skin = "bricks", flag = "flag_r03", pet = "pet_dragao" }, stars = 31250 })
		local ctx = ctx_for(root, view, s)
		local l = Locker.new(ctx)
		root:add_child(l)
		local c = ConfirmBuy.new(ctx)
		root:add_child(c)
		l:set_confirm(c)
		l:bind(s)
		l:open()
		l:_set_tab(2)
		l:apply_layout()
		H.step(40)
		local n0 = #s.sent
		l:_buy_pressed("stars")
		H.step(40)
		check(c.is_open == true and c.visible == true, "the price's button opens the question")
		for i = n0 + 1, #s.sent do
			check(s.sent[i][1] ~= "buy_crates", "nothing is bought before the answer")
		end
		inside(c._panel.gui, "the question's window")
		local px, py, pw, ph = H.rect(c._panel.gui)
		for _, part in { c._title, c._what, c._price, c._note, c._no, c._yes } do
			local x, y, w, h = H.rect(part.gui)
			check(x >= px - 0.5 and y >= py - 0.5 and x + w <= px + pw + 0.5 and y + h <= py + ph + 0.5, "a piece of the question inside its window")
		end
		apart({ c._no.gui, c._yes.gui }, "Cancelar and Confirmar")
		apart({ c._what.gui, c._price.gui, c._note.gui, c._no.gui }, "the question's lines")
		check(c._no.text == "Cancelar" and c._yes.text == "Confirmar", "the answers in Portuguese")
		-- (the question stands apart from the button that opened it: a double click does not land on Confirmar)
		local bx, by, bw, bh = H.rect(l._buy.gui)
		local yx, yy, yw, yh = H.rect(c._yes.gui)
		local over = bx < yx + yw and yx < bx + bw and by < yy + yh and yy < by + bh
		check(not over or ConfirmBuy.ARM_S >= 0.3, "Confirmar is not under the pointer that pressed the price, or takes no press at first")
	end)
end

-- ---------------------------------------------------------------------------------------------
-- The Loja Misteriosa
-- ---------------------------------------------------------------------------------------------
local MysteryShop = require("../src/client/UI/MysteryShop")
local Shop = require("../src/shared/Data/Shop")
local Products = require("../src/shared/Data/Products")
MysteryShop.now = function()
	return 20000 * 86400 + 43200 + 5 * 3600 + 7 * 60 + 9
end
for _, view in VIEWS do
	run("loja", view, function(root, gui)
		local offers = Shop.offers(Shop.day(MysteryShop.now()), 0)
		check(#offers == Shop.SLOTS, "the day's offers: " .. #offers)
		local s = session({ owned = { offers[2].id }, equipped = {}, stars = 31250 })
		local m = MysteryShop.new(ctx_for(root, view, s))
		m.show_item = Locker.show_item
		root:add_child(m)
		m:bind(s)
		m:open()
		H.step(40)
		inside(m._panel.gui, "the shop's window")
		local nodes = {}
		for _, c in m._cards do
			inside(c.node.gui, "an offer's card")
			inside(c.button.gui, "an offer's button")
			table.insert(nodes, c.node.gui)
		end
		apart(nodes, "the offers' cards")
		check(#m._cards == #offers, "one card for each offer")
		check(m._cards[2].button.text == "USAR", "an owned offer's button wears it: " .. tostring(m._cards[2].button.text))
		check(m._clock.text == "6:52:51", "the clock to the next offers: " .. tostring(m._clock.text))
		-- a Robux offer: nothing to prompt when its rarity's product has no id
		local toasts = {}
		m._toast = function(_m, text)
			table.insert(toasts, text)
		end
		local key = offers[1].product
		local old = Products[key].id
		check(type(old) == "number" and old > 0, "the offer's product is made (Data/MyProducts): " .. tostring(key))
		Products[key].id = 0
		m:_pressed(offers[1])
		check(s.sent[#s.sent][1] == "report" and m._pending == nil and #toasts == 1, "no product: nothing is asked, the player is told")
		-- with the product: the server is told the item first, then the prompt
		Products[key].id = 777
		m:_pressed(offers[1])
		check(s.sent[#s.sent][1] == "shop_pick" and s.sent[#s.sent][2] == offers[1].id, "a Robux offer tells the server its item")
		check(m._pending ~= nil and m._pending.phase == "pick", "and waits for its word")
		s.shop_result:Fire("pick", false, offers[1].id, "not on sale")
		check(m._pending == nil and #toasts == 2, "refused: the wait ends, the player is told")
		Products[key].id = old
		-- an owned one is worn
		m:_pressed(offers[2])
		check(s.sent[#s.sent][1] == "equip", "pressing an owned offer wears it")
	end)
end

-- ---------------------------------------------------------------------------------------------
-- The Arsenal
-- ---------------------------------------------------------------------------------------------
local Arsenal = require("../src/client/UI/Arsenal")
for _, view in VIEWS do
	run("arsenal", view, function(root, gui)
		local s = session({ stars = 31250 })
		s.inventory.unlocks = { artillery = true }
		s.unlocked = Signal.new()
		s.unlock_result = Signal.new()
		local a = Arsenal.new(ctx_for(root, view, s))
		root:add_child(a)
		a:bind(s)
		a:open()
		H.step(40)
		inside(a._panel.gui, "the Arsenal's window")
		inside(a._list_host.gui, "the Arsenal's list")
		inside(a._detail_host.gui, "the Arsenal's item")
		apart({ a._list_host.gui, a._detail_host.gui }, "the Arsenal's list and item")
		-- every item's page builds, and its button stays inside the window
		local px, py, pw, ph = H.rect(a._panel.gui)
		for _, it in require("../src/shared/Data/Arsenal").ITEMS do
			a:_select(it.key, true)
			H.step(2)
			local d = a._detail
			check(d ~= nil and d.key == it.key, "the Arsenal shows " .. it.key)
			for _, ch in d.cta:GetChildren() do
				if ch:IsA("GuiObject") then
					local x, y, w, h = H.rect(ch)
					check(
						x >= px - 0.5 and y >= py - 0.5 and x + w <= px + pw + 0.5 and y + h <= py + ph + 0.5,
						string.format("%s: its %s inside the window (%.0f..%.0f in %.0f..%.0f)", it.key, ch.Name, y, y + h, py, py + ph)
					)
				end
			end
		end
		a:_select("mega", true)
		H.step(2)
	end)
end

-- ---------------------------------------------------------------------------------------------
-- Opening a crate: the show plays to its end for each kind, and says what came in pt
-- ---------------------------------------------------------------------------------------------
local CrateOpening = require("../src/client/UI/CrateOpening")
for _, view in VIEWS do
	for _, kind in { "skin", "flag", "pet" } do
		run("bau-" .. kind, view, function(root, gui)
			local s = session({ stars = 31250 })
			local o = CrateOpening.new(ctx_for(root, view, s))
			root:add_child(o)
			o:apply_layout()
			local it = Cosmetics.of_kind(kind)[3]
			o.show_item = Locker.show_item
			o.info_of = function()
				return {
					crates = 1,
					price = 25000,
					stars = true,
					kind = kind,
					can_more = true,
					wearing = function()
						return nil
					end,
				}
			end
			-- (the show is a loop of waits: between two of them a frame is drawn, the server answers
			-- and the player taps)
			local n = 0
			H.on_wait = function()
				n += 1
				o:_step(1 / 60)
				if n == 30 then
					o:resolve(it.id)
				end
				if n % 20 == 0 and n < 2000 then
					o:_tap()
				end
				if n > 6000 then
					error("the crate's show never ends")
				end
			end
			o:play(o.info_of())
			H.flush()
			H.on_wait = nil
			H.step(4)
			check(o._item == it.id, kind .. ": the crate shows what came")
			local seen = {}
			for _, d in gui:GetDescendants() do
				if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
					seen[Lang.t(d.Text)] = true
				end
			end
			check(seen[Lang.t(it.name)] == true, kind .. ": the item's name is on the screen")
			local want = ({ skin = "BAÚ DE SKINS", flag = "BAÚ DE BANDEIRAS", pet = "BAÚ DE PETS" })[kind]
			check(seen[want] == true, kind .. ": the crate's title reads " .. want)
			check(seen["NOVO!"] == true and seen["REPETIDO"] == nil and o._new.Visible == true, kind .. ": a new item is tagged NOVO!")
			local never = nil
			for text in seen do
				if string.find(Lang.upper(text), "NUNCA", 1, true) ~= nil then
					never = text
				end
			end
			check(never == nil, kind .. ": nothing in the crate's show promises 'never a duplicate' (" .. tostring(never) .. ")")
			local sub_want = ({ skin = "UMA SKIN · REPETIDA VIRA COROAS", flag = "UMA BANDEIRA · REPETIDA VIRA COROAS", pet = "UM PET · REPETIDO VIRA COROAS" })[kind]
			check(seen[sub_want] == true, kind .. ": the line under the title reads " .. sub_want)
		end)
	end
	-- the same show for an item the player already had (2026-11-12): REPETIDO, and the Coroas it paid
	run("bau-repetido", view, function(root, gui)
		local s = session({ stars = 31250 })
		local o = CrateOpening.new(ctx_for(root, view, s))
		root:add_child(o)
		o:apply_layout()
		local it = Cosmetics.item("pet_lobo")
		local paid = Cosmetics.duplicate_stars(it.id)
		o.show_item = Locker.show_item
		o.info_of = function()
			return {
				crates = 0,
				price = 25000,
				stars = true,
				kind = "pet",
				can_more = true,
				wearing = function()
					return nil
				end,
			}
		end
		local n = 0
		H.on_wait = function()
			n += 1
			o:_step(1 / 60)
			if n == 30 then
				o:resolve(it.id, paid)
			end
			if n % 20 == 0 and n < 2000 then
				o:_tap()
			end
			if n > 6000 then
				error("the crate's show never ends")
			end
		end
		o:play(o.info_of())
		H.flush()
		H.on_wait = nil
		H.step(4)
		local seen = {}
		for _, d in gui:GetDescendants() do
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
				seen[Lang.t(d.Text)] = true
			end
		end
		check(paid == 6000 and it.rarity == "rare", "a Raro pet as a duplicate pays 6.000 Coroas")
		check(o._item == it.id and seen[Lang.t(it.name)] == true, "a duplicate: the item that came is still shown by name")
		check(seen["REPETIDO"] == true and seen["NOVO!"] == nil, "a duplicate is tagged REPETIDO, not NOVO!")
		check(seen["VOCÊ JÁ TINHA · +6.000 COROAS"] == true, "... and the Coroas it paid are written under the name")
		local px, py, pw, ph = H.rect(gui)
		local kx, ky, kw, kh = H.rect(o._kind)
		check(kx >= px - 0.5 and kx + kw <= px + pw + 0.5 and ky >= py - 0.5 and ky + kh <= py + ph + 0.5, string.format("... inside the screen (%.0f..%.0f of %.0f)", kx, kx + kw, pw))
		-- the show is closed, and its pictures fade out (outside Roblox no tween runs: the fade's end
		-- is set by hand). The next crate must show its item again: it used to stay invisible
		-- (2026-11-12: "the card comes empty")
		o:close()
		H.step(2)
		o._preview.ImageTransparency = 1
		-- the next crate opened is a new item again: the tag goes back
		n = 0
		H.on_wait = function()
			n += 1
			o:_step(1 / 60)
			if n == 30 then
				o:resolve("pet_gato", 0)
			end
			if n % 20 == 0 and n < 2000 then
				o:_tap()
			end
			if n > 6000 then
				error("the crate's show never ends")
			end
		end
		o:play(o.info_of())
		H.flush()
		H.on_wait = nil
		H.step(4)
		local seen2 = {}
		for _, d in gui:GetDescendants() do
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and d.Visible ~= false then
				seen2[Lang.t(d.Text)] = true
			end
		end
		check(seen2["NOVO!"] == true and seen2["REPETIDO"] == nil and (o._dup or 0) == 0, "the next crate, a new item: NOVO! again, no Coroas line")
		check(seen2["PET · ACOMPANHA O SEU NOME"] == true, "... and the usual line under the name is back")
		check(o._preview.ImageTransparency == 0 and o._preview.Visible ~= false, "a crate opened after another was closed shows its item's picture (not left faded out)")
		check(o._preview.Image ~= "" and o._preview.ImageRectSize.X > 0, "... and the picture is the item's place in the pets' sheet")
		-- (the picture saved is the duplicate's)
		n = 0
		H.on_wait = function()
			n += 1
			o:_step(1 / 60)
			if n == 30 then
				o:resolve(it.id, paid)
			end
			if n % 20 == 0 and n < 2000 then
				o:_tap()
			end
		end
		o:play(o.info_of())
		H.flush()
		H.on_wait = nil
		H.step(4)
	end)
end

-- ---------------------------------------------------------------------------------------------
-- The RANK window: the two global lists (client/UI/Ranking)
-- ---------------------------------------------------------------------------------------------
local RankWindow = require("../src/client/UI/Ranking")
local RANK_ME = 4410077
RankWindow.user_id = function()
	return RANK_ME
end
local RANK_NAMES = {
	"ReiDoNorte", "Valquiria_BR", "DragaoDeEldoria", "xXCavaleiroXx", "Lia Tempestade", "Conde Vasco", "MestreDasTorres",
	"Imperatriz Nara", "Thorin77", "LoboDaEstepe", "Rainha Ísis", "BarãoVermelho", "o_ultimo_reino", "Sir Galvão",
	"Duquesa Mel", "Guardião42", "Fênix Dourada", "PedroConquista", "Ana das Colinas", "ZéDoCastelo",
}
local function rank_fixture(): any
	local wins, kills = {}, {}
	for i = 1, 100 do
		local name = RANK_NAMES[(i - 1) % #RANK_NAMES + 1] .. (if i > #RANK_NAMES then tostring(i) else "")
		wins[i] = { 9000 + i, name, math.floor(1240 / (1 + (i - 1) * 0.22)) + (100 - i) }
		kills[i] = { 9000 + ((i * 37) % 100) + 1, RANK_NAMES[(i * 7) % #RANK_NAMES + 1] .. (if i > 9 then tostring(i) else ""), math.floor(9800 / (1 + (i - 1) * 0.18)) + (100 - i) * 3 }
	end
	-- the player: fourth in wins, outside the hundred in kingdoms
	wins[4] = { RANK_ME, "Você Mesmo", wins[4][3] }
	-- (a row Roblox gave no name for)
	wins[6][2] = ""
	return {
		ok = true,
		age = 40,
		at = os.clock(),
		boards = { wins = wins, kills = kills },
		me = { wins = { wins[4][3], 4 }, kills = { 212 } },
	}
end
for _, view in VIEWS do
	for i, tab in RankWindow.TABS do
		run("rank-" .. (if tab.key == "wins" then "vitorias" else "reinos"), view, function(root, gui)
			local s = session({ stars = 31250 })
			s.rank = rank_fixture()
			s.rank_changed = Signal.new()
			s.rank_get = function(_s)
				table.insert(s.sent, { "rank_get" })
				return true
			end
			local r = RankWindow.new(ctx_for(root, view, s))
			root:add_child(r)
			r:bind(s)
			r:open(tab.key)
			H.step(40)
			local what = "the ranking (" .. tab.key .. ", " .. view[1] .. ")"
			inside(r._panel.gui, what .. ": its window")
			check(r._tab == i and #r._rows == 100, what .. ": a hundred rows of its list")
			check(#s.sent == 0, what .. ": lists that just came are not asked for again")
			-- everything of the window is inside it, and its parts are apart
			local px, py, pw, ph = H.rect(r._panel.gui)
			local parts = { r._head, r._tab_row, r._host, r._mine }
			if not view[4] then
				table.insert(parts, r._cols)
				table.insert(parts, r._note)
			end
			local guis = {}
			for j, n in parts do
				local x, y, w, h = H.rect(n.gui)
				check(
					x >= px - 0.5 and y >= py - 0.5 and x + w <= px + pw + 0.5 and y + h <= py + ph + 0.5,
					string.format("%s: part %d inside the window (%.0f, %.0f, %.0f x %.0f)", what, j, x, y, w, h)
				)
				table.insert(guis, n.gui)
			end
			apart(guis, what .. ": the window's parts")
			apart({ r._tabs[1].gui, r._tabs[2].gui }, what .. ": the two tabs")
			-- (a phone is short: the sub-title, the columns' names and the notes give their room to the list)
			check(r._cols_m.visible == not view[4] and r._note.visible == not view[4] and r._sub.visible == not view[4], what .. ": the column names and the notes only where there is room")
			inside(r._close_b.gui, what .. ": its close button")
			-- the list shows whole rows from its top, and has room for at least five
			local hx, hy, hw, hh = H.rect(r._host.gui)
			local x1, y1, w1, h1 = H.rect(r._rows[1].node.gui)
			check(math.abs(y1 - hy) <= 2.5 and x1 >= hx - 0.5 and x1 + w1 <= hx + hw + 0.5, string.format("%s: the first row at the list's top (%.1f / %.1f)", what, y1, hy))
			local _, y2, _, _ = H.rect(r._rows[2].node.gui)
			check(y2 >= y1 + h1, what .. ": the rows are one under the other")
			check(hh >= 5 * (y2 - y1) - 1, string.format("%s: at least five rows in sight (%.0f px, %.0f a row)", what, hh, y2 - y1))
			local _, yl, _, hl = H.rect(r._rows[100].node.gui)
			check(yl + hl > hy + hh, what .. ": the hundredth row is below: the list scrolls")
			local canvas = r._scroll.gui.CanvasSize.Y.Offset
			check(canvas >= (yl + hl - y1) - 1, string.format("%s: the scroll reaches the last row (%d px for %.0f)", what, canvas, yl + hl - y1))
			-- a row: place, face, name, number, in that order and inside it
			local row = r._rows[1]
			local rx, ry, rw, rh = H.rect(row.node.gui)
			local last = rx
			for j, g in { row.place_l.gui, row.face, row.name.gui, row.value.gui } do
				local x, y, w, h = H.rect(g)
				check(x >= last - 0.5 and x + w <= rx + rw + 0.5 and y >= ry - 0.5 and y + h <= ry + rh + 0.5, string.format("%s: the row's piece %d in its place", what, j))
				last = x + w
			end
			local fx, fy, fw, fh = H.rect(row.face)
			check(math.abs(fw - fh) < 1.1 and fw >= 16, string.format("%s: the face is a square of a size to be seen (%.0f x %.0f)", what, fw, fh))
			check(row.face.Image == "rbxthumb://type=AvatarHeadShot&id=" .. row.uid .. "&w=48&h=48", what .. ": the face is that user's head shot")
			check(row.face.ImageTransparency < 0.01 and row.face.Visible ~= false, what .. ": and it is drawn (not transparent): " .. tostring(row.face.ImageTransparency))
		end)
	end
end

-- ---------------------------------------------------------------------------------------------
-- The lobby
-- ---------------------------------------------------------------------------------------------
-- (the title screen asks Roblox for services as it loads: a stand-in, set only now, so the modules
-- above, which ask whether `game` exists, loaded as outside Roblox)
H.fake_game()
local TitleScreen = require("../src/client/UI/TitleScreen")
for _, view in VIEWS do
	run("lobby", view, function(root, gui)
		-- a player with some history: a Cavaleiro with a pet, a flag, wins and the third login day
		local MissionsData = require("../src/shared/Data/Missions")
		local now = os.time()
		local ctx = ctx_for(root, view, session({
			stars = 31250,
			equipped = { pet = Cosmetics.of_kind("pet")[1].id, flag = Cosmetics.of_kind("flag")[1].id },
			ranked = { month = MissionsData.month(now), points = 142, games = 9, wins = 3, peak = 150 },
			stats = { wins = 12, kills = 87 },
			login = { day = MissionsData.day(now), streak = 3 },
		}))
		local t = TitleScreen.new(ctx)
		root:add_child(t)
		t:set_map_name("Eldoria")
		t:apply_layout()
		-- the hub's public matches, as a player sees them: the free-for-all (on Valtara, the small
		-- map), Eldoria's own, and a team game
		t:set_lobbies({
			{ id = "a", map = "valtara", map_name = "Valtara", max = 15, players = 4, starts_in = 41, joinable = true },
			{ id = "b", map = "world", map_name = "Eldoria", max = 45, players = 12, starts_in = 63, joinable = true, mode = "ranked" },
			{ id = "c", map = "valtara", map_name = "Valtara", max = 20, players = 6, starts_in = 77, joinable = true, mode = "team", teams = 4 },
		}, { "ffa", "ranked", "team" })
		t:apply_layout()
		H.step(40)
		check(t._art ~= nil, "the lobby has its own picture behind everything")
		-- the player's card (UI/PlayerCard): on the screen, clear of the dock, the wordmark and the
		-- top row's buttons, saying who the player is
		do
			local card = t._card
			check(card.visible, "the player's card shows")
			inside(card.gui, "the player's card")
			local cx, cy, cw, ch = H.rect(card.gui)
			for what, other in { dock = t._dock, wordmark = t._word, ["RANK button"] = t._rank_b, ["MISSIONS button"] = t._missions_b } do
				local ox, oy, ow, oh = H.rect(other.gui)
				local apart = cx + cw <= ox + 0.5 or ox + ow <= cx + 0.5 or cy + ch <= oy + 0.5 or oy + oh <= cy + 0.5
				check(apart, string.format("the player's card is clear of the %s (card %.0f,%.0f %.0fx%.0f; it %.0f,%.0f %.0fx%.0f)", what, cx, cy, cw, ch, ox, oy, ow, oh))
			end
			local m = card.model_shown
			check(m.tier == "CAVALEIRO" and m.points == "142 / 300", "the card says the ranked tier and the way to the next: " .. m.tier .. " " .. m.points)
			check(math.abs(m.frac - 0.21) < 0.001, "... with the bar at 42 of 200 points: " .. tostring(m.frac))
			check(m.wins == "12 vitórias" and m.kills == "87 reinos", "the card counts victories and kingdoms: " .. m.wins .. ", " .. m.kills)
			check(type(m.pet) == "string" and string.sub(m.pet, 1, 9) == "Mascote: " and card._pet_row.visible, "the card names the mascot: " .. tostring(m.pet))
			check(card._flag.visible and card._flag_img.Image ~= "", "the card shows the flag")
			check(m.login == "Login 3/7  ·  amanhã +1.500", "the card says the login day and tomorrow's reward: " .. m.login)
			-- the longest login line there is fits the card's width (a label that cuts its text has
			-- no minimum width: measured with one that does not)
			do
				local inner = card:card_size().X - 24
				for _, text in { m.login, "Login 6/7  ·  amanhã baú grátis", "Login diário: dia 7 de 7" } do
					local probe = UITheme.label("", 11, 600)
					probe.text = text
					probe:update_minimum_size()
					local need = probe:get_combined_minimum_size().X
					check(need <= inner, string.format("the login line %q fits the card (%.0f of %.0f)", text, need, inner))
				end
			end
			check(card._name.text ~= "" and card._tier.text == "CAVALEIRO", "the card's labels carry them: " .. tostring(card._name.text))
			-- every line of it is inside the card
			for what, l in { name = card._name, tier = card._tier, points = card._points, wins = card._wins, kills = card._kills, login = card._login, mascot = card._pet_l } do
				local lx, ly, lw, lh = H.rect(l.gui)
				check(lx >= cx - 0.5 and ly >= cy - 0.5 and lx + lw <= cx + cw + 0.5 and ly + lh <= cy + ch + 0.5, string.format("the card's %s line is inside it (%.0f,%.0f %.0fx%.0f in %.0f,%.0f %.0fx%.0f)", what, lx, ly, lw, lh, cx, cy, cw, ch))
			end
		end
		-- the block that starts a match (2026-11-12: it was RoWorld's bar over a list). Desktop: a
		-- row of tiles, SOLO and one per kind of public match; phones: their compact rows
		do
			local cards = t._cards
			check(cards[1].btn.visible and cards[2].btn.visible and cards[3].btn.visible, "the three kinds of public match show")
			check(cards[2].title.text == "RANQUEADA", "the second kind is the ranked match (Eldoria has no card of its own): " .. tostring(cards[2].title.text))
			for i, c in cards do
				inside(c.btn.gui, "the match card " .. i)
			end
			if view[4] then
				check(t._tiles == false and cards[1].tiled == false, "phones: the cards are rows")
				check(t._solo.text == "JOGAR SOLO", "phones: the PLAY SOLO bar")
			else
				check(t._tiles == true, "desktop: the tiles")
				local tiles = { t._solo_tile.gui, cards[1].btn.gui, cards[2].btn.gui, cards[3].btn.gui }
				apart(tiles, "the four tiles")
				local x0, y0, w0, h0 = H.rect(tiles[1])
				local dx, _, dw = H.rect(t._dock.gui)
				for i, g in tiles do
					local x, y, w, h = H.rect(g)
					check(math.abs(y - y0) < 1 and math.abs(h - h0) < 1, string.format("tile %d is level with the first and as tall (%.0f, %.0f)", i, y, h))
					check(math.abs(w - w0) < 1.5, string.format("tile %d is as wide as the first (%.0f and %.0f)", i, w, w0))
					check(x >= dx and x + w <= dx + dw, "tile " .. i .. " is inside the dock")
					check(h > w * 0.8, string.format("tile %d stands (%.0f x %.0f): not a row of a list", i, w, h))
				end
				check(H.rect(tiles[4]) > H.rect(tiles[3]) and H.rect(tiles[3]) > H.rect(tiles[2]) and H.rect(tiles[2]) > x0, "side by side: SOLO, public, Eldoria, teams")
				-- each tile's pieces, top to bottom: picture, title, second line, status, button
				for i, c in cards do
					local _, py, _, ph = H.rect(c.thumb_node.gui)
					local _, ty, _, th = H.rect(c.title.gui)
					local _, sy, _, sh = H.rect(c.sub.gui)
					local _, ry, _, rh = H.rect(c.status.gui)
					local bx, by, bw, bh = H.rect(c.pill.gui)
					check(py + ph <= ty + 0.5 and ty + th <= sy + 0.5 and sy + sh <= ry + 0.5 and ry + rh <= by + 0.5, "tile " .. i .. ": picture, title, line, status and button from top to bottom")
					local cx, cy, cw, chh = H.rect(c.btn.gui)
					check(bx >= cx and bx + bw <= cx + cw + 0.5 and by + bh <= cy + chh + 0.5, "tile " .. i .. ": the button is inside it")
					check(bw > cw * 0.7, string.format("tile %d: the button spans the tile (%.0f of %.0f)", i, bw, cw))
					check(c.thumb_node.visible and c.thumb.Image ~= "", "tile " .. i .. " shows its map's picture")
					check(c.sub.text ~= "", "tile " .. i .. " has its second line: " .. tostring(c.sub.text))
				end
				check(cards[1].title.text == "CLÁSSICA" and cards[2].title.text == "RANQUEADA" and cards[3].title.text == "EQUIPES", "the tiles' one-word titles: " .. tostring(cards[1].title.text) .. ", " .. tostring(cards[2].title.text) .. ", " .. tostring(cards[3].title.text))
				check(cards[1].sub.text == "Próxima: Valtara", "the free-for-all names its next map: " .. tostring(cards[1].sub.text))
				check(cards[1].status.text == "4/15  ·  0:41", "... and its seats and time: " .. tostring(cards[1].status.text))
				check(string.find(cards[3].sub.text, "Valtara", 1, true) ~= nil, "the team game names its map: " .. tostring(cards[3].sub.text))
				-- the map pictures: the free-for-all's and the team game's are Valtara's, Eldoria's its own
				local Thumbs = require("../src/shared/Assets/MapThumbs")
				check(cards[1].thumb.Image == Thumbs.valtara and cards[3].thumb.Image == Thumbs.valtara, "Valtara's picture on the tiles that play it")
				check(cards[2].thumb.Image == Thumbs.world and t._solo_tile_thumb.Image == Thumbs.world, "Eldoria's on its own tile and on SOLO's")
				-- the SOLO tile: the PLAY button inside it, level with the others' buttons
				local sx, sy, sw, sh = H.rect(t._solo.gui)
				local _, by, _, bh = H.rect(cards[1].pill.gui)
				check(sx >= x0 and sx + sw <= x0 + w0 + 0.5 and sy + sh <= y0 + h0 + 0.5, "the PLAY button is inside the SOLO tile")
				check(math.abs(sy - by) < 1.5 and math.abs(sh - bh) < 1.5, string.format("... level with the JOIN bars and as tall (%.0f/%.0f, %.0f/%.0f)", sy, by, sh, bh))
				check(t._solo.text == "JOGAR" and t._solo_tile_sub.text == "Mapa:  Eldoria", "it says PLAY, and the tile names the solo map")
				local opened = false
				t._solo.pressed:Fire()
				opened = t._solo_panel.visible == true
				check(opened, "PLAY opens the solo menu (map, difficulty, START)")
				t:close_solo_menu(true)
				H.step(20)
				-- another map picked for solo: the tile follows
				t:set_map_name("Valtara")
				check(t._solo_tile_sub.text == "Mapa:  Valtara" and t._solo_tile_thumb.Image == Thumbs.valtara, "the SOLO tile follows the map picked")
				t:set_map_name("Eldoria")
			end
		end
		local ax, ay, aw, ah = H.rect(t._art.gui)
		check(ax <= 0.5 and ay <= 0.5 and aw >= H.view.X - 1 and ah >= H.view.Y - 1, "the picture fills the screen")
		inside(t._dock.gui, "the lobby's dock")
		inside(t._word.gui, "the game's name")
		inside(t._coins.gui, "the balance")
		local quick = { t._q_arsenal.gui, t._q_locker.gui, t._q_shop.gui, t._help.gui }
		for i, q in quick do
			inside(q, "the dock's button " .. i)
		end
		apart(quick, "the dock's four buttons")
		apart({ t._word.gui, t._dock.gui }, "the name and the dock")
		apart({ t._word.gui, t._coins.gui }, "the name and the balance")
		apart({ t._word.gui, t._q_shop.gui }, "the name and the shop's button")
		-- the RANK button: beside the balance, to its left, as tall as it
		inside(t._rank_b.gui, "the RANK button")
		apart({ t._rank_b.gui, t._coins.gui }, "the RANK button and the balance")
		apart({ t._rank_b.gui, t._word.gui }, "the RANK button and the name")
		do
			local cx, cy, _, ch = H.rect(t._coins.gui)
			local bx, by, bw, bh = H.rect(t._rank_b.gui)
			check(bx + bw <= cx and cx - (bx + bw) <= 12, string.format("the RANK button is just left of the balance (%.0f px between)", cx - (bx + bw)))
			check(math.abs(by - cy) < 1 and math.abs(bh - ch) < 1, "level with it, and as tall")
			check(bw >= 30 and bh >= 30, string.format("big enough to press (%.0f x %.0f)", bw, bh))
			check((t._rank_b.text == "") == (view[4] == true), "phones: the trophy alone; desktop: the word RANK: " .. tostring(t._rank_b.text))
			local opened = 0
			t.open_rank:Connect(function()
				opened += 1
			end)
			t._rank_b.pressed:Fire()
			check(opened == 1, "the RANK button opens the ranking")
		end
		-- the MISSIONS button: left of the RANK one, level with it and as tall
		inside(t._missions_b.gui, "the MISSIONS button")
		apart({ t._missions_b.gui, t._rank_b.gui, t._coins.gui }, "the MISSIONS button, the RANK one and the balance")
		apart({ t._missions_b.gui, t._word.gui }, "the MISSIONS button and the name")
		do
			local rx, ry, _, rh = H.rect(t._rank_b.gui)
			local bx, by, bw, bh = H.rect(t._missions_b.gui)
			check(bx + bw <= rx and rx - (bx + bw) <= 12, string.format("the MISSIONS button is just left of the RANK one (%.0f px between)", rx - (bx + bw)))
			check(math.abs(by - ry) < 1 and math.abs(bh - rh) < 1, "level with it, and as tall")
			check(bw >= 30 and bh >= 30, string.format("big enough to press (%.0f x %.0f)", bw, bh))
			check((t._missions_b.text == "") == (view[4] == true), "phones: the target alone; desktop: the word: " .. tostring(t._missions_b.text))
			-- (Roblox's own buttons keep the top left corner: nothing of ours goes under them)
			local k = UITheme.scale
			check(bx >= (if view[4] then 200 else 280) / k or by >= (if view[4] then 44 else 58) / k, string.format("clear of Roblox's corner (x %.0f, y %.0f)", bx, by))
			local opened = 0
			t.open_missions:Connect(function()
				opened += 1
			end)
			t._missions_b.pressed:Fire()
			check(opened == 1, "the MISSIONS button opens the missions")
		end
		local pressed = 0
		t.open_shop:Connect(function()
			pressed += 1
		end)
		t._q_shop.pressed:Fire()
		check(pressed == 1, "the SHOP button opens the shop")
		-- the owner's button: a player who is not the owner has none
		check(t._admin_b.visible == false, "a player who is not the owner sees no ADMIN button")
		do
			local opened = 0
			t.open_admin:Connect(function()
				opened += 1
			end)
			t._admin_b.pressed:Fire()
			check(opened == 0, "... and the button, pressed by force, opens nothing")
		end
		-- phones: the dock is no wider than DOCK_PHONE_W (2026-11-12: 640, was 760)
		if view[4] then
			local _, _, dw = H.rect(t._dock.gui)
			check(TitleScreen.DOCK_PHONE_W == 640, "the phone dock's limit is 640")
			check(dw <= 640 * UITheme.scale + 1.5, string.format("the phone's dock is at most 640 wide (%.0f)", dw / UITheme.scale))
			check(dw < H.view.X - 80, string.format("... and no longer runs from edge to edge (%.0f of %d)", dw, H.view.X))
		end
	end)
end

-- ---------------------------------------------------------------------------------------------
-- The lobby on other phones (2026-11-12: "faça para que fique bem para celular"): a small one and
-- a large one. The dock keeps inside the screen, at most 640 wide; every card's words fit in it;
-- every button is big enough for a thumb.
-- ---------------------------------------------------------------------------------------------
for _, view in { { "celular-pequeno", 667, 375, true }, { "celular-estreito", 740, 360, true }, { "celular-grande", 932, 430, true } } do
	run("lobby", view, function(root, gui)
		local ctx = ctx_for(root, view, session({ stars = 31250 }))
		local t = TitleScreen.new(ctx)
		root:add_child(t)
		t:set_map_name("Eldoria")
		t:apply_layout()
		t:set_lobbies({
			{ id = "a", map = "valtara", map_name = "Valtara", max = 15, players = 4, starts_in = 41, joinable = true },
			{ id = "b", map = "world", map_name = "Eldoria", max = 45, players = 12, starts_in = 63, joinable = true, mode = "ranked" },
			{ id = "c", map = "valtara", map_name = "Valtara", max = 20, players = 16, starts_in = 77, joinable = true, mode = "team", teams = 4 },
		}, { "ffa", "ranked", "team" })
		t:apply_layout()
		H.step(40)
		local k = UITheme.scale
		local dx, dy, dw, dh = H.rect(t._dock.gui)
		inside(t._dock.gui, "the dock")
		check(dw <= 640 * k + 1.5, string.format("%s: the dock is at most 640 wide (%.0f)", view[1], dw / k))
		check(dh <= H.view.Y * 0.4, string.format("%s: the dock takes at most two fifths of the height (%.0f of %d)", view[1], dh, H.view.Y))
		local cards = { t._cards[1].btn.gui, t._cards[2].btn.gui, t._cards[3].btn.gui }
		apart(cards, view[1] .. ": the three match cards")
		for i, c in t._cards do
			local cx, cy, cw, ch = H.rect(c.btn.gui)
			check(cx >= dx - 0.5 and cx + cw <= dx + dw + 0.5, view[1] .. ": card " .. i .. " is inside the dock")
			check(ch >= 40 * k, string.format("%s: card %d is tall enough for a thumb (%.0f)", view[1], i, ch / k))
			for _, piece in { c.title, c.status } do
				if piece.visible then
					local px, _, pw = H.rect(piece.gui)
					check(
						px >= cx - 0.5 and px + pw <= cx + cw + 0.5,
						string.format('%s: card %d: "%s" fits in the card (%.0f + %.0f in %.0f + %.0f)', view[1], i, tostring(piece.text), px, pw, cx, cw)
					)
				end
			end
		end
		local row = { t._solo.gui, t._q_arsenal.gui, t._q_locker.gui, t._q_shop.gui, t._help.gui }
		apart(row, view[1] .. ": PLAY SOLO and the four buttons")
		for i, g in row do
			local x, y, w, h = H.rect(g)
			check(x >= dx - 0.5 and x + w <= dx + dw + 0.5 and y + h <= dy + dh + 0.5, view[1] .. ": button " .. i .. " of the lower row is inside the dock")
			check(w >= 40 * k and h >= 40 * k, string.format("%s: button %d is big enough for a thumb (%.0f x %.0f)", view[1], i, w / k, h / k))
		end
		apart({ t._word.gui, t._dock.gui }, view[1] .. ": the name and the dock")
		for _, b in { t._coins, t._rank_b, t._missions_b } do
			inside(b.gui, view[1] .. ": a button of the top right")
		end
		apart({ t._missions_b.gui, t._rank_b.gui, t._coins.gui, t._word.gui }, view[1] .. ": the top right's buttons and the name")
	end)
end

-- ---------------------------------------------------------------------------------------------
-- The owner's lobby: the ADMIN button, left of the MISSIONS one (only a game admin has it)
-- ---------------------------------------------------------------------------------------------
for _, view in VIEWS do
	run("lobby-dono", view, function(root, gui)
		local ctx = ctx_for(root, view, session({ stars = 31250 }))
		local is_admin = false
		function ctx:admin()
			return is_admin
		end
		local t = TitleScreen.new(ctx)
		root:add_child(t)
		t:set_map_name("Eldoria")
		t:apply_layout()
		H.step(40)
		check(t._admin_b.visible == false, "before the server says who the owner is: no button")
		-- the server's word comes a moment after the lobby (the attribute on the owner's Player)
		is_admin = true
		t:_refresh_coins()
		t:apply_layout()
		H.step(10)
		check(t._admin_b.visible == true, "the owner sees the ADMIN button")
		inside(t._admin_b.gui, "the ADMIN button")
		apart({ t._admin_b.gui, t._missions_b.gui, t._rank_b.gui, t._coins.gui }, "the ADMIN button, the MISSIONS one, the RANK one and the balance")
		apart({ t._admin_b.gui, t._word.gui }, "the ADMIN button and the name")
		local mx, my, _, mh = H.rect(t._missions_b.gui)
		local bx, by, bw, bh = H.rect(t._admin_b.gui)
		check(bx + bw <= mx and mx - (bx + bw) <= 12, string.format("just left of the MISSIONS button (%.0f px between)", mx - (bx + bw)))
		check(math.abs(by - my) < 1 and math.abs(bh - mh) < 1, "level with it, and as tall")
		check(bw >= 30 and bh >= 30, string.format("big enough to press (%.0f x %.0f)", bw, bh))
		check((t._admin_b.text == "") == (view[4] == true), "phones: the gear alone; desktop: the word: " .. tostring(t._admin_b.text))
		local k = UITheme.scale
		check(bx >= (if view[4] then 200 else 280) / k or by >= (if view[4] then 44 else 58) / k, string.format("clear of Roblox's corner (x %.0f, y %.0f)", bx, by))
		local opened = 0
		t.open_admin:Connect(function()
			opened += 1
		end)
		t._admin_b.pressed:Fire()
		check(opened == 1, "the ADMIN button opens the owner's panel")
		-- the owner's word taken back (it never is, in the game): the button goes, and opens nothing
		is_admin = false
		t._admin_b.pressed:Fire()
		check(opened == 1, "a press that is no longer the owner's opens nothing")
		t:_refresh_coins()
		check(t._admin_b.visible == false, "... and the button goes")
		is_admin = true
		t:_refresh_coins()
	end)
end

-- ---------------------------------------------------------------------------------------------
-- The owner's panel (UI/AdminPanel): its three pages
-- ---------------------------------------------------------------------------------------------
local AdminPanel = require("../src/client/UI/AdminPanel")
local ADMIN_CODES = {
	{ code = "NATAL", info = "5.000 Coroas · até 31/12/2026 · 12 de 100 usos", state = "ligado", on = true, fixed = false },
	{ code = "K7QM-X2PD", info = "1.000 Coroas · sem validade · 0 de 1 usos", state = "ligado", on = true, fixed = false },
	{ code = "INAUGURACAO", info = "20.000 Coroas · até 20/11/2026 · sem limite de usos", state = "DESLIGADO", on = false, fixed = false },
	{ code = "VELHO", info = "500 Coroas · até 01/11/2026 · sem limite de usos", state = "EXPIRADO", on = true, fixed = false },
	{ code = "BEMVINDO", info = "1.000 Coroas · sem validade · sem limite de usos", state = "ligado", on = true, fixed = true },
}
local function admin_rank(): any
	local boards = { wins = {}, kills = {}, wins_w = {}, kills_w = {}, wins_l = {}, kills_l = {} }
	for i = 1, 14 do
		boards.wins[i] = { 4000000 + i * 137, if i == 2 then "Nome Bem Comprido De Jogador" else "Jogador" .. i, 320 - i * 7 }
		boards.kills[i] = { 5000000 + i * 91, "Guerreiro" .. i, 4100 - i * 55 }
	end
	return { ok = true, age = 0, at = 0, boards = boards, me = {} }
end
for _, page in { { "coins", "painel-dono" }, { "codes", "painel-dono-codigos" }, { "rank", "painel-dono-ranking" } } do
	for _, view in VIEWS do
		run(page[2], view, function(root, gui)
			local s = session({ stars = 31250 })
			s.rank = admin_rank()
			s.rank_changed = Signal.new()
			s.admin_result = Signal.new()
			s.asked = {}
			function s:admin(action, args)
				table.insert(s.asked, { action, args })
				return true
			end
			function s:rank_get()
				return true
			end
			local ctx = ctx_for(root, view, s)
			local p = AdminPanel.new(ctx)
			root:add_child(p)
			p:bind(s)
			p:open(page[1])
			check(#s.asked == 1 and s.asked[1][1] == "state", "opening asks the server for the codes")
			s.admin_result:Fire({ action = "state", ok = true, text = "", codes = ADMIN_CODES, codes_read = true })
			if page[1] == "coins" then
				s.admin_result:Fire({ action = "coins", ok = true, text = "+5.000 Coroas para CaruzoOFC. Saldo: 36.250." })
			elseif page[1] == "codes" then
				s.admin_result:Fire({ action = "code_new", ok = true, text = "Código NATAL criado: 5.000 Coroas, até 31/12/2026, para os 100 primeiros jogadores.", codes = ADMIN_CODES })
			else
				s.admin_result:Fire({ action = "rank_remove", ok = false, text = 'Há 2 jogadores chamados "Igual" no ranking. Use o ID numérico (está ao lado do nome, na lista do painel).' })
			end
			H.step(40)
			check(p:page() == page[1], "the page asked for is in view")
			inside(p._panel.gui, "the owner's panel")
			local px, py, pw, ph = H.rect(p._panel.gui)
			local k = UITheme.scale
			check(pw >= math.min(700 * k, H.view.X - 60), string.format("wide: %.0f of %d", pw, H.view.X))
			local function within(obj: any, what: string)
				local x, y, w, h = H.rect(obj)
				check(
					x >= px - 0.5 and y >= py - 0.5 and x + w <= px + pw + 0.5 and y + h <= py + ph + 0.5,
					string.format("%s inside the panel (%.0f, %.0f, %.0f x %.0f in %.0f, %.0f, %.0f x %.0f)", what, x, y, w, h, px, py, pw, ph)
				)
			end
			local chips = {}
			for i, chip in p._chips do
				within(chip.gui, "page chip " .. i)
				table.insert(chips, chip.gui)
			end
			table.insert(chips, p._close_b.gui)
			table.insert(chips, p._title.gui)
			apart(chips, "the name, the page chips and the close button")
			within(p._close_b.gui, "the close button")
			within(p._status.gui, "the server's answer")
			local _, sy = H.rect(p._status.gui)
			if page[1] == "coins" then
				local row = { p._coin_who.gui, p._coin_amount.gui }
				apart(row, "the two fields")
				local buttons = { p._coin_give.gui, p._coin_take.gui, p._coin_see.gui }
				apart(buttons, "GIVE, TAKE and SEE")
				for i, g in { p._coin_who.gui, p._coin_amount.gui, p._coin_give.gui, p._coin_take.gui, p._coin_see.gui } do
					within(g, "piece " .. i .. " of the Coroas page")
					local _, y, w, h = H.rect(g)
					check(h >= 34 * k and w >= 80 * k, string.format("piece %d is big enough to press (%.0f x %.0f)", i, w / k, h / k))
					check(y + h <= sy + 0.5, "piece " .. i .. " is above the answer")
				end
				check(p._coin_give.text == "DAR" and p._coin_take.text == "TIRAR" and p._coin_see.text == "VER SALDO", "the three buttons, in Portuguese")
				check(p._status_l.text == "+5.000 Coroas para CaruzoOFC. Saldo: 36.250.", "the server's answer is shown as it came")
			elseif page[1] == "codes" then
				local form = { p._code_name.gui, p._code_stars.gui, p._code_valid.gui, p._code_uses.gui, p._code_create.gui }
				apart(form, "the new code's four fields and CREATE")
				for i, g in form do
					within(g, "piece " .. i .. " of the new code's row")
					local _, _, w, h = H.rect(g)
					check(h >= 34 * k and w >= 70 * k, string.format("piece %d is big enough (%.0f x %.0f)", i, w / k, h / k))
				end
				check(#p._code_rows == #ADMIN_CODES, "one row per code: " .. #p._code_rows)
				within(p._code_host.gui, "the codes' list")
				local hx, hy, hw, hh = H.rect(p._code_host.gui)
				check(hh >= 80 * k, string.format("the list has room (%.0f)", hh / k))
				check(hy + hh <= sy + 0.5, "the list is above the answer")
				for i, r in p._code_rows do
					local rx, ry, rw, rh = H.rect(r.node.gui)
					check(rx >= hx - 0.5 and rx + rw <= hx + hw + 0.5, "code row " .. i .. " is as wide as the list at most")
					if r.fixed then
						check(r.toggle == nil and r.delete == nil, "the place's own code has no buttons")
					else
						apart({ r.name.gui, r.info.gui, r.state.gui, r.toggle.gui, r.delete.gui }, "code row " .. i .. ": name, description, state, ON/OFF, DELETE")
						for _, b in { r.toggle, r.delete } do
							local bx, by, bw, bh = H.rect(b.gui)
							check(bx >= rx - 0.5 and bx + bw <= rx + rw + 0.5 and by >= ry - 0.5 and by + bh <= ry + rh + 0.5, "code row " .. i .. ": a button inside the row")
							check(bw >= 60 * k and bh >= 24 * k, string.format("code row %d: a button big enough (%.0f x %.0f)", i, bw / k, bh / k))
						end
						check(r.toggle.text == (if r.on then "DESLIGAR" else "LIGAR"), "code row " .. i .. ": the switch says what it will do")
					end
				end
			else
				apart({ p._rank_who.gui, p._rank_remove.gui }, "the field and REMOVE FROM RANKING")
				within(p._rank_who.gui, "the player's field")
				within(p._rank_remove.gui, "REMOVE FROM RANKING")
				local chips2 = {}
				for i, chip in p._board_chips do
					within(chip.gui, "list chip " .. i)
					table.insert(chips2, chip.gui)
				end
				apart(chips2, "the four lists' chips")
				check(#p._rank_rows == 14, "one row per player of the list: " .. #p._rank_rows)
				within(p._rank_host.gui, "the ranking's list")
				local hx, hy, hw, hh = H.rect(p._rank_host.gui)
				check(hh >= 80 * k and hy + hh <= sy + 0.5, string.format("the list has room, above the answer (%.0f)", hh / k))
				for i = 1, 2 do
					local r = p._rank_rows[i]
					local rx, ry, rw, rh = H.rect(r.node.gui)
					apart({ r.name.gui, r.id.gui, r.value.gui, r.remove.gui }, "ranking row " .. i .. ": name, id, number, REMOVE")
					local bx, by, bw, bh = H.rect(r.remove.gui)
					check(bx >= rx - 0.5 and bx + bw <= rx + rw + 0.5 and by >= ry - 0.5 and by + bh <= ry + rh + 0.5, "ranking row " .. i .. ": the button inside the row")
				end
				check(p._rank_rows[1].id.text == "ID 4000137", "the id beside the name: " .. tostring(p._rank_rows[1].id.text))
			end
		end)
	end
end

-- ---------------------------------------------------------------------------------------------
-- The lobby of a player with a weekly prize to claim: the mark on the RANK button's left side
-- ---------------------------------------------------------------------------------------------
for _, view in VIEWS do
	run("lobby-premio", view, function(root, gui)
		local s = session({ stars = 31250 })
		local ctx = ctx_for(root, view, s)
		local t = TitleScreen.new(ctx)
		root:add_child(t)
		t:set_map_name("Eldoria")
		t:apply_layout()
		t:set_lobbies({
			{ id = "a", map = "valtara", map_name = "Valtara", max = 15, players = 4, starts_in = 41, joinable = true },
			{ id = "b", map = "world", map_name = "Eldoria", max = 45, players = 12, starts_in = 63, joinable = true, mode = "ranked" },
		}, { "ffa", "ranked" })
		t:apply_layout()
		H.step(40)
		local m = t._rank_mark
		check(m ~= nil and not m:is_visible_in_tree(), "nothing to claim: the RANK button has no mark")
		check(t:rank_claim_total() == 0, "and the total is 0")
		-- the prize arrives with the inventory
		s.inventory.rank_claim = { total = 1700, weeks = { { wins = 1, kills = 2, stars = 1700 } } }
		H.step(40)
		check(t:rank_claim_total() == 1700, "a prize to claim: its Coroas")
		check(m:is_visible_in_tree(), "the RANK button gets its mark")
		local rx, ry, rw, rh = H.rect(t._rank_b.gui)
		local mx, my, mw, mh = H.rect(m.gui)
		inside(m.gui, "the RANK button's mark")
		check(mw >= 12 and mh >= 12 and math.abs(mw - mh) < 1, string.format("it is a round mark one can see (%.0f x %.0f)", mw, mh))
		local cx, cy = mx + mw * 0.5, my + mh * 0.5
		check(cx <= rx + rw * 0.25, string.format("on the button's LEFT side (mark at %.0f, button %.0f to %.0f)", cx, rx, rx + rw))
		check(mx < rx + 1 and mx + mw > rx, "over the button's left edge")
		check(cy >= ry - mh and cy <= ry + rh * 0.5, "at its top corner")
		-- (it is the last thing drawn there: the buttons are under it)
		local kids = t.gui:GetChildren()
		local im, ir, ii = table.find(kids, m.gui), table.find(kids, t._rank_b.gui), table.find(kids, t._missions_b.gui)
		check(im ~= nil and ir ~= nil and ii ~= nil and im > ir and im > ii, "drawn over the RANK and the MISSIONS buttons")
		check(m.gui.Active ~= true, "a press goes through it to the button")
		local text = ""
		for _, d in m.gui:GetDescendants() do
			if type(d.Text) == "string" then
				text ..= d.Text
			end
		end
		check(text == "!", "it says \"!\": " .. text)
		-- the button under it still opens the ranking
		local opened = 0
		t.open_rank:Connect(function()
			opened += 1
		end)
		t._rank_b.pressed:Fire()
		check(opened == 1, "the RANK button opens the ranking as before")
		-- claimed: the mark goes
		s.inventory.rank_claim = nil
		H.step(40)
		check(not m:is_visible_in_tree(), "claimed: the mark is gone")
		-- (the picture saved is the lobby with the mark)
		s.inventory.rank_claim = { total = 1700, weeks = { { wins = 1, kills = 2, stars = 1700 } } }
		H.step(40)
		check(m:is_visible_in_tree(), "another week's prize: the mark is back")
	end)
end

-- ---------------------------------------------------------------------------------------------
-- The MISSIONS window: the daily missions and the monthly pass (client/UI/Missions)
-- ---------------------------------------------------------------------------------------------
local MissionsWindow = require("../src/client/UI/Missions")
local MissionData = require("../src/shared/Data/Missions")
local ProductsData = require("../src/shared/Data/Products")
-- (a fixed moment: 12 November 2026, 18:48 in Brasília)
local MISSIONS_T = MissionData.days_of(2026, 11, 12) * 86400 + 18 * 3600 + 48 * 60 + 3 * 3600
MissionsWindow.show_item = Locker.show_item
--- `how`: "diarias" (two of today's three done) | "passe" (no pass; some monthly ones done and
--- waiting) | "passe-ativo" (the pass on: those paid).
local function missions_session(how: string): any
	local s = session({ stars = 31250 })
	s.inventory.loaded = true
	local day, month = MissionData.day(MISSIONS_T), MissionData.month(MISSIONS_T)
	local st = MissionData.clean({ day = day, month = month })
	local todays = MissionData.daily(day)
	st.d[todays[1].counter] = todays[1].goal
	st.d[todays[2].counter] = todays[2].goal
	st.d[todays[3].counter] = math.max(0, todays[3].goal - 1)
	st.m = { played = 47, kills = 131, minutes = 212, top3 = 9, daily = 14, wins = 20 }
	MissionData.settle(st, MISSIONS_T, {})
	if how == "passe-ativo" then
		st.pass = month
		MissionData.settle(st, MISSIONS_T, {})
	end
	s.missions_view = function(_s)
		local v = MissionData.view(st, MISSIONS_T)
		v.on_sale = true
		return v
	end
	return s
end
for _, view in VIEWS do
	for _, how in { "diarias", "passe", "passe-ativo" } do
		run("missoes-" .. how, view, function(root, gui)
			local was = ProductsData.pass.id
			ProductsData.pass.id = 1
			local s = missions_session(how)
			local m = MissionsWindow.new(ctx_for(root, view, s))
			root:add_child(m)
			m:bind(s)
			m:open(if how == "diarias" then "daily" else "pass")
			H.step(40)
			ProductsData.pass.id = was
			local what = "the missions (" .. how .. ", " .. view[1] .. ")"
			local v = s:missions_view()
			inside(m._panel.gui, what .. ": its window")
			local want = if how == "diarias" then #v.daily else #v.monthly
			check(#m._rows == want and want >= 3, string.format("%s: a row for each mission (%d)", what, #m._rows))
			-- everything of the window is inside it, and its parts are apart
			local px, py, pw, ph = H.rect(m._panel.gui)
			local parts = { m._head, m._tab_row, m._host, m._foot }
			if how ~= "diarias" then
				table.insert(parts, m._season)
			end
			local guis = {}
			for j, n in parts do
				local x, y, w, h = H.rect(n.gui)
				check(
					x >= px - 0.5 and y >= py - 0.5 and x + w <= px + pw + 0.5 and y + h <= py + ph + 0.5,
					string.format("%s: part %d inside the window (%.0f, %.0f, %.0f x %.0f)", what, j, x, y, w, h)
				)
				table.insert(guis, n.gui)
			end
			apart(guis, what .. ": the window's parts")
			apart({ m._tabs[1].gui, m._tabs[2].gui }, what .. ": the two tabs")
			inside(m._close_b.gui, what .. ": its close button")
			check(m._season.visible == (how ~= "diarias"), what .. ": the season's panel only on the pass's tab")
			-- the rows: one under the other, the first at the list's top, each piece inside its row
			local hx, hy, hw, hh = H.rect(m._host.gui)
			local x1, y1, w1, h1 = H.rect(m._rows[1].node.gui)
			check(math.abs(y1 - hy) <= 2.5 and x1 >= hx - 0.5 and x1 + w1 <= hx + hw + 0.5, string.format("%s: the first row at the list's top (%.1f / %.1f)", what, y1, hy))
			local _, y2, _, _ = H.rect(m._rows[2].node.gui)
			check(y2 >= y1 + h1, what .. ": the rows are one under the other")
			check(hh >= 2 * (y2 - y1) - 1, string.format("%s: at least two rows in sight (%.0f px, %.0f a row)", what, hh, y2 - y1))
			local _, yl, _, hl = H.rect(m._rows[#m._rows].node.gui)
			local canvas = m._scroll.gui.CanvasSize.Y.Offset
			check(yl + hl <= hy + hh + 0.5 or canvas >= (yl + hl - y1) - 1, string.format("%s: the last row is in sight or the scroll reaches it (%d px for %.0f)", what, canvas, yl + hl - y1))
			if not view[4] then
				check(yl + hl <= hy + hh + 0.5, what .. ": on a computer every row is in sight, no scrolling")
			end
			for i, row in m._rows do
				local rx, ry, rw, rh = H.rect(row.node.gui)
				for j, g in { row.text.gui, row.count.gui, row.state.gui } do
					local x, y, w, h = H.rect(g)
					check(x >= rx - 0.5 and x + w <= rx + rw + 0.5 and y >= ry - 0.5 and y + h <= ry + rh + 0.5, string.format("%s: row %d's piece %d inside it", what, i, j))
				end
				local tx, _, tw, _ = H.rect(row.text.gui)
				local sx = H.rect(row.state.gui)
				check(tx + tw <= sx + 0.5, string.format("%s: row %d's text ends before its state", what, i))
				local mi = row.mission
				check(row.text.text == mi.text, string.format("%s: row %d says what to do: %s", what, i, tostring(row.text.text)))
				check(math.abs(row.frac - mi.have / mi.goal) < 1e-6, string.format("%s: row %d's bar is at %d of %d", what, i, mi.have, mi.goal))
				check(row.locked == (how == "passe" and mi.done), string.format("%s: row %d waits for the pass only when done without it", what, i))
				check((row.item ~= nil) == (mi.item ~= nil), string.format("%s: row %d shows its item", what, i))
			end
			if how == "diarias" then
				check(v.daily[1].paid and v.daily[2].paid and not v.daily[3].paid, what .. ": two of the three are done")
				check(string.find(m._foot.text, "5h 12min", 1, true) ~= nil, what .. ": the foot counts down to midnight: " .. tostring(m._foot.text))
			else
				local done = 0
				local items = 0
				for _, row in m._rows do
					done += if row.mission.done then 1 else 0
					items += if row.item ~= nil then 1 else 0
				end
				check(done >= 2 and done < #m._rows, what .. ": some monthly missions done, some not (" .. done .. ")")
				check(items == 3, what .. ": three rows give the season's items")
				check(m._season_name.text == "Cinzas da Fênix", what .. ": November's season: " .. tostring(m._season_name.text))
				check(string.find(m._season_when.text, "NOVEMBRO DE 2026", 1, true) ~= nil, what .. ": and its month: " .. tostring(m._season_when.text))
				check(string.find(m._foot.text, "18 dias", 1, true) ~= nil, what .. ": the foot counts the days left: " .. tostring(m._foot.text))
				local bx, by, bw, bh = H.rect(m._buy.gui)
				local sx, sy, sw, sh = H.rect(m._season.gui)
				check(bx >= sx and bx + bw <= sx + sw + 0.5 and by >= sy and by + bh <= sy + sh + 0.5, what .. ": the pass's button inside the season's panel")
				check(bw >= 60 and bh >= 28, string.format("%s: the pass's button is big enough (%.0f x %.0f)", what, bw, bh))
				local thumbs = {}
				for _, kind in Cosmetics.KINDS do
					table.insert(thumbs, m._season_items[kind].node.gui)
				end
				table.insert(thumbs, m._buy.gui)
				table.insert(thumbs, m._season_name.gui)
				apart(thumbs, what .. ": the season's name, its three items and the button")
				if how == "passe" then
					check(m._buy.disabled ~= true and string.find(m._buy.text, tostring(ProductsData.pass.robux), 1, true) ~= nil, what .. ": the button sells the pass at its price: " .. tostring(m._buy.text))
					check(v.pass == false, what .. ": no pass")
				else
					check(m._buy.disabled == true and m._buy.text == "PASSE ATIVO", what .. ": the button says the pass is on: " .. tostring(m._buy.text))
					for i, row in m._rows do
						check(row.mission.paid == row.mission.done, string.format("%s: row %d is paid when done", what, i))
					end
				end
			end
			-- without a product the pass is not sold
			if how == "passe" and not view[4] then
				local was_view = s.missions_view
				s.missions_view = function(_s)
					local vv = was_view(_s)
					vv.on_sale = false
					return vv
				end
				m:_rebuild()
				check(m._buy.disabled == true and m._buy.text == "EM BREVE", what .. ": with no product the button says coming soon")
				s.missions_view = was_view
				m:_rebuild()
				H.step(10)
			end
		end)
	end
end

-- ---------------------------------------------------------------------------------------------
-- The lobby with Roblox's chat open (2026-11-12: "when I open Roblox's chat the panel goes to the
-- side and is not in the centre"). The chat window takes the top left of the screen (the player's
-- screenshot: 483 x 348 px of a 1365 x 728 window); the name and the dock stay in the middle.
-- ---------------------------------------------------------------------------------------------
do
	local view = { "pc", 1365, 728, false }
	run("lobby-chat", view, function(root, gui)
		local ctx = ctx_for(root, view, session({ stars = 44690 }))
		local k = UITheme.scale
		ctx.reserved_top_left = Rect.new(0, 0, 483 / k, 348 / k)
		local t = TitleScreen.new(ctx)
		root:add_child(t)
		t:set_map_name("Eldoria")
		t:apply_layout()
		t:set_lobbies({
			{ id = "a", map = "valtara", map_name = "Valtara", max = 15, players = 0, starts_in = 26, joinable = true },
			{ id = "b", map = "world", map_name = "Eldoria", max = 45, players = 0, starts_in = 48, joinable = true, mode = "ranked" },
			{ id = "c", map = "world", map_name = "Eldoria", max = 30, players = 0, starts_in = 26, joinable = true, mode = "team", teams = 6 },
		}, { "ffa", "ranked", "team" })
		t:apply_layout()
		H.step(40)
		local mid = H.view.X / 2
		local dx, dy, dw, dh = H.rect(t._dock.gui)
		check(math.abs(dx + dw / 2 - mid) < 1.5, string.format("chat open: the dock is in the middle of the screen (its centre %.0f, the screen's %.0f)", dx + dw / 2, mid))
		local wx, wy, ww, wh = H.rect(t._word.gui)
		check(math.abs(wx + ww / 2 - mid) < 3, string.format("chat open: the game's name is in the middle (its centre %.0f)", wx + ww / 2))
		inside(t._dock.gui, "chat open: the dock")
		inside(t._word.gui, "chat open: the name")
		-- the dock is below the chat window; the name made itself small enough to stand beside it
		check(dy >= 348 or dx >= 483, string.format("chat open: the dock is clear of the chat window (dock at %.0f, %.0f)", dx, dy))
		check(wx >= 483 or wy >= 348, string.format("chat open: the name is clear of the chat window (name from x %.0f, %.0f wide)", wx, ww))
		apart({ t._word.gui, t._dock.gui }, "chat open: the name and the dock")
		apart({ t._word.gui, t._coins.gui }, "chat open: the name and the balance")
		-- the same window with the chat closed: nothing moves sideways, the name is only bigger
		ctx.reserved_top_left = Rect.new(0, 0, 280 / k, 58 / k)
		t:apply_layout()
		H.step(20)
		local dx2, _, dw2 = H.rect(t._dock.gui)
		local wx2, _, ww2 = H.rect(t._word.gui)
		check(math.abs(dx2 - dx) < 1 and math.abs(dw2 - dw) < 1, "chat closed again: the dock is where it was")
		check(math.abs(wx2 + ww2 / 2 - mid) < 3 and ww2 > ww, string.format("... the name is in the middle too, and bigger (%.0f px wide, %.0f with the chat)", ww2, ww))
		-- a chat window too wide for any name beside it: the name stops shrinking and stays centred
		ctx.reserved_top_left = Rect.new(0, 0, 640 / k, 348 / k)
		t:apply_layout()
		H.step(20)
		local wx3, _, ww3 = H.rect(t._word.gui)
		local dx3, _, dw3 = H.rect(t._dock.gui)
		check(math.abs(wx3 + ww3 / 2 - mid) < 3 and math.abs(dx3 + dw3 / 2 - mid) < 1.5, "a chat window half the screen wide: name and dock still in the middle")
		check(ww3 > 120, string.format("... and the name is still readable (%.0f px wide)", ww3))
		ctx.reserved_top_left = Rect.new(0, 0, 483 / k, 348 / k)
		t:apply_layout()
		H.step(20)
	end)
end

-- ---------------------------------------------------------------------------------------------
-- "Quer fazer o tutorial?": the question a new player is asked, over the lobby
-- ---------------------------------------------------------------------------------------------
local TutorialAsk = require("../src/client/UI/TutorialAsk")
for _, view in VIEWS do
	run("tutorial", view, function(root, gui)
		local ctx = ctx_for(root, view, session({ stars = 0 }))
		local t = TitleScreen.new(ctx)
		root:add_child(t)
		t:apply_layout()
		local ask = TutorialAsk.new(ctx)
		root:add_child(ask)
		ask:open()
		H.step(40)
		inside(ask._panel.gui, "the tutorial's question")
		inside(ask._yes.gui, "its yes")
		inside(ask._no.gui, "its no")
		apart({ ask._yes.gui, ask._no.gui }, "the two answers")
		apart({ ask._title.gui, ask._text.gui, ask._pay.gui, ask._note.gui, ask._yes.gui }, "the question's lines")
		local px, py, pw, ph = H.rect(ask._panel.gui)
		for i, l in { ask._title, ask._text, ask._pay, ask._note } do
			local x, y, w, h = H.rect(l.gui)
			check(
				x >= px - 0.5 and y >= py - 0.5 and x + w <= px + pw + 0.5 and y + h <= py + ph + 0.5,
				string.format("the question's line %d is inside its window (%s)", i, view[1])
			)
		end
	end)
end

for _, p in H.problems() do
	check(false, "a property Roblox does not have: " .. p)
end
print(string.format("telas: %d checks, %d failed", checks, failed))
if failed > 0 then
	error("telas: failed")
end
