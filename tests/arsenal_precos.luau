--!nocheck
-- The Arsenal's prices, as RoWorld sells it (2026-11-11, the owner's choice: "as habilidades vão ter
-- preço por Robux e por Coroas, e os bônus somente por Robux"):
--   * the six units (two spells, three structures, the troops' call) cost in Coroas what they cost in
--     RoWorld, and can be bought for Robux too once their product exists (Data/MyProducts);
--   * the two boosters (2x Coroas, Recarga Rápida) have no price in Coroas: Robux only;
--   * the Robux prices suggested in Data/MyProducts are RoWorld's;
--   * the server refuses Coroas for a booster and takes nothing; a Robux receipt unlocks either kind;
--   * the Arsenal's window shows both ways for a unit, one way for a booster, and says "not available
--     yet" for a booster whose product has not been made.
--   lune run tests/arsenal_precos.luau
local H = require("./ui_harness")
local fs = require("@lune/fs")
local Signal = require("../src/shared/Core/Signal")
local UICtx = require("../src/client/UI/UICtx")
local UITheme = require("../src/client/UI/UITheme")
local ArsenalWindow = require("../src/client/UI/Arsenal")
local Catalog = require("../src/shared/Data/Arsenal")
local Products = require("../src/shared/Data/Products")
local Mine = require("../src/shared/Data/MyProducts")
local LangPt = require("../src/shared/Data/LangPt")
local Stars = require("../src/shared/Data/Stars")
local Purchases = require("../src/server/Purchases")
local Lang = require("../src/shared/Data/Lang")
Lang.use("pt")

local checks, failed = 0, 0
local function check(ok: any, what: string)
	checks += 1
	if not ok then
		failed += 1
		print("FAIL: " .. what)
	end
end

-- RoWorld's own numbers (its Data/Arsenal and Data/Products at ae7a350)
local ROWORLD_STARS = { mega = 20000, scatter = 40000, reinforce = 40000, artillery = 50000, airfield = 200000, railgun = 500000 }
local ROWORLD_ROBUX = { mega = 39, scatter = 67, reinforce = 149, artillery = 99, airfield = 349, railgun = 999, stars2x = 59, reload2x = 129 }
local BOOSTERS = { "stars2x", "reload2x" }
local UNITS = { "mega", "scatter", "reinforce", "artillery", "airfield", "railgun" }

-- ---------------------------------------------------------------------------------------------
-- 1. the prices
-- ---------------------------------------------------------------------------------------------
do
	check(#Catalog.ITEMS == 8, "eight items")
	for _, key in UNITS do
		local it = Catalog.item(key)
		check(it ~= nil and it.kind ~= "boost", key .. " is a unit")
		check(it.stars == ROWORLD_STARS[key], key .. " costs RoWorld's price in Coroas: " .. tostring(it.stars))
		check(it.product == "unlock_" .. key and Products[it.product] ~= nil, key .. " has a Robux product too")
		check(Products[it.product].grants == "unlock:" .. key, key .. ": its product unlocks it")
	end
	for _, key in BOOSTERS do
		local it = Catalog.item(key)
		check(it ~= nil and it.kind == "boost", key .. " is a booster")
		check(it.stars == nil, key .. " has no price in Coroas: " .. tostring(it.stars))
		check(it.product == "unlock_" .. key and Products[it.product] ~= nil, key .. " has a Robux product")
		check(Products[it.product].grants == "unlock:" .. key, key .. ": its product unlocks it")
	end
	for key, robux in ROWORLD_ROBUX do
		local m = Mine["unlock_" .. key]
		check(type(m) == "table" and m.robux == robux, key .. ": RoWorld's Robux price in MyProducts: " .. tostring(m and m.robux))
		check(Products["unlock_" .. key].robux == robux, key .. ": ... and in the game")
	end
	-- in the shop: the units cheapest first, the boosters last
	local last, sorted, boosts_last = 0, true, true
	local seen_boost = false
	for _, it in Catalog.ITEMS do
		if it.stars ~= nil then
			sorted = sorted and it.stars >= last
			last = it.stars
			boosts_last = boosts_last and not seen_boost
		else
			seen_boost = true
		end
	end
	check(sorted and boosts_last, "in the shop: cheapest in Coroas first, the Robux-only boosters last")
	-- what the Coroas earned go towards is never a booster
	check(Catalog.next_goal({}).key == "mega", "a new player's Coroas go towards the cheapest unit")
	local owned = {}
	for _, key in UNITS do
		owned[key] = true
	end
	check(Catalog.next_goal(owned) == nil, "with the six units owned, Coroas have no Arsenal item left to buy")
	-- the product keeps what it does: 2x Coroas doubles a payout
	local r = { spawned = true, left = false, minutes = 10, shares = 1, kills = 0, place = 3, field = 10, won = false }
	local one, two = Stars.payout(r, "public", false).total, Stars.payout(r, "public", true).total
	check(one > 0 and two == 2 * one, "2x Coroas still doubles what a match pays (" .. one .. " -> " .. two .. ")")
end

-- ---------------------------------------------------------------------------------------------
-- 2. the server, with the switches the game ships with
-- ---------------------------------------------------------------------------------------------
do
	check(Purchases.EARN_ARSENAL == true, "the Arsenal is earned or bought, not free")
	local rows = {}
	local store = {}
	function store:UpdateAsync(k, fn)
		local new = fn(rows[k])
		if new ~= nil then
			rows[k] = new
		end
		return new
	end
	function store:GetAsync(k)
		return rows[k]
	end
	local P = { UserId = 42, Name = "Ana" }
	local told = {}
	Purchases.reset()
	Purchases.configure({
		datastore = store,
		players = {
			GetPlayerByUserId = function(_, id)
				return if id == 42 then P else nil
			end,
		},
		notify = function() end,
		inventory = function() end,
		unlocked = function(_, key)
			table.insert(told, key)
		end,
		bought = function() end,
	})
	Purchases.load(P)
	for _, it in Catalog.ITEMS do
		check(not Purchases.has_unlock(P, it.key), "a new player does not own " .. it.key)
	end
	-- Coroas never buy a booster, however many
	Purchases.adjust_stars(42, 2000000)
	for _, key in BOOSTERS do
		local got, why = Purchases.buy_unlock(P, key)
		check(got == false and why == "robux only", key .. ": Coroas are refused (" .. tostring(why) .. ")")
		check(not Purchases.has_unlock(P, key) and Purchases.stars(P) == 2000000, key .. ": nothing unlocked, nothing taken")
	end
	-- Coroas buy every unit, at its price
	-- (an item's `bonus` is paid with its unlock, as in RoWorld: 5,000 with the Catapulta and the Toca)
	local balance, spent = 2000000, 0
	for _, key in UNITS do
		local got = Purchases.buy_unlock(P, key)
		balance += (Catalog.item(key).bonus or 0) - ROWORLD_STARS[key]
		spent += ROWORLD_STARS[key]
		check(got == true and Purchases.has_unlock(P, key) and Purchases.stars(P) == balance, key .. ": bought with Coroas, " .. ROWORLD_STARS[key] .. " taken (" .. Purchases.stars(P) .. " left)")
	end
	check(spent == 850000, "the six units cost 850,000 Coroas in all")
	-- Robux: the game ships with the owner's products (2026-11-11: Data/MyProducts has the 13 ids) ...
	local shipped = {}
	for _, it in Catalog.ITEMS do
		local id = Products[it.product].id
		check(type(id) == "number" and id > 0 and id == Mine[it.product].id, it.key .. ": on sale with the id of Data/MyProducts (" .. tostring(id) .. ")")
		check(Purchases.kind_of(id) == "unlock:" .. it.key, it.key .. ": a receipt of that id is its unlock")
		shipped[it.product] = id
	end
	-- ... and a product that has not been made sells nothing
	for _, it in Catalog.ITEMS do
		Products[it.product].id = 0
		check(Purchases.kind_of(shipped[it.product]) == nil, it.key .. ": a line back at id = 0 sells nothing")
	end
	check(Purchases.kind_of(0) == nil, "a purchase of no product is nothing")
	-- ... with a product (any id), its receipt unlocks: a booster
	local ids = {}
	for i, it in Catalog.ITEMS do
		ids[it.key] = 9000 + i
		Products[it.product].id = 9000 + i
	end
	for _, key in BOOSTERS do
		check(Purchases.kind_of(ids[key]) == "unlock:" .. key, key .. ": its product, once made, is an unlock")
		check(Purchases.process_receipt({ PlayerId = 42, ProductId = ids[key], PurchaseId = "b-" .. key }) == "granted", key .. ": the Robux receipt is granted")
		check(Purchases.has_unlock(P, key) and told[#told] == key, key .. ": unlocked with Robux")
		check(rows.u42.unlocks[key] == true, key .. ": and saved")
	end
	check(Purchases.stars(P) >= balance, "a Robux purchase takes no Coroas")
	-- ... and a unit, for a player who has no Coroas for it
	local Q = { UserId = 43, Name = "Beto" }
	Purchases.configure({
		players = {
			GetPlayerByUserId = function(_, id)
				return if id == 42 then P elseif id == 43 then Q else nil
			end,
		},
	})
	Purchases.load(Q)
	local q0 = Purchases.stars(Q)
	check(select(2, Purchases.buy_unlock(Q, "airfield")) == "not enough", "a unit costs more Coroas than a new player has")
	check(Purchases.process_receipt({ PlayerId = 43, ProductId = ids.airfield, PurchaseId = "q1" }) == "granted", "... its Robux receipt is granted")
	check(Purchases.has_unlock(Q, "airfield") and Purchases.stars(Q) >= q0, "a unit is unlocked with Robux too, no Coroas taken")
	-- a unit already owned, bought again with Robux: Coroas for its price
	local before = Purchases.stars(P)
	Purchases.process_receipt({ PlayerId = 42, ProductId = ids.mega, PurchaseId = "dup" })
	check(Purchases.stars(P) == before + 39 * Purchases.DUPLICATE_STARS_PER_ROBUX, "an item bought twice by mistake pays Coroas for its Robux")
	-- (section 3 starts with no product made: every id at 0)
	for _, it in Catalog.ITEMS do
		Products[it.product].id = 0
	end
	-- a record that bought a booster with Coroas while it had a price keeps it
	rows.u77 = { stars = 10, unlocks = { stars2x = true, reload2x = true } }
	local R = { UserId = 77, Name = "Caio" }
	Purchases.load(R)
	check(Purchases.has_unlock(R, "stars2x") and Purchases.has_unlock(R, "reload2x"), "who already owns a booster keeps it")
end

-- ---------------------------------------------------------------------------------------------
-- 3. the window
-- ---------------------------------------------------------------------------------------------
local function texts(inst: any): string
	local out = {}
	for _, d in inst:GetDescendants() do
		if type(d.Text) == "string" and d.Text ~= "" then
			table.insert(out, d.Text)
		end
	end
	return table.concat(out, " | ")
end
local function has(s: string, part: string): boolean
	return string.find(s, part, 1, true) ~= nil
end
local function window(view: any, stars: number)
	local root = H.root(view[2], view[3], view[4])
	local s = {
		inventory = { owned = {}, equipped = {}, stars = stars, unlocks = {} },
		credits = {},
		inventory_changed = Signal.new(),
		credits_changed = Signal.new(),
		unlocked = Signal.new(),
		unlock_result = Signal.new(),
		sent = {},
	}
	for _, name in { "report", "buy_unlock" } do
		s[name] = function(_self, ...)
			table.insert(s.sent, { name, ... })
			return true
		end
	end
	local ctx = UICtx.new()
	ctx.vp = root.vp
	ctx.compact = view[4]
	ctx.touch = view[4]
	ctx.touch_device = view[4]
	ctx.session = s
	local k = UITheme.scale
	ctx.reserved_top_left = Rect.new(0, 0, (if view[4] then 200 else 280) / k, (if view[4] then 44 else 58) / k)
	function ctx:sfx() end
	local a = ArsenalWindow.new(ctx)
	root:add_child(a)
	a:bind(s)
	a:open()
	H.step(40)
	return a, s
end
local function page(a: any, key: string): (string, string, boolean)
	a:_select(key, true)
	H.step(2)
	return texts(a._detail.cta), a._rows[key].text.Text, a._rows[key].icon.Visible
end
local function bought(s: any): number
	local n = 0
	for _, e in s.sent do
		if e[1] == "buy_unlock" then
			n += 1
		end
	end
	return n
end

for _, view in { { "pc", 1280, 720, false }, { "celular", 844, 390, true } } do
	local v = " (" .. view[1] .. ")"
	-- no product made (every line of Data/MyProducts at id = 0): units for Coroas, boosters not yet
	do
		local a, s = window(view, 1000)
		for _, key in UNITS do
			local cta, card = page(a, key)
			check(not has(cta, "BUY NOW") and has(cta, "Earn it by playing:"), key .. ", no product: only the Coroas way: " .. cta .. v)
			check(card == ArsenalWindow.short(ROWORLD_STARS[key]), key .. ", no product: the card shows its Coroas price: " .. card .. v)
		end
		for _, key in BOOSTERS do
			local cta, card, icon = page(a, key)
			check(cta == "Not available yet.", key .. ", no product: the page says it is not available yet: " .. cta .. v)
			check(card == "SOON" and icon == false, key .. ", no product: the card says SOON, no price: " .. card .. v)
			local it = Catalog.item(key)
			a:_stars_pressed(it)
			a:_stars_pressed(it, true)
			check(bought(s) == 0 and a._pending == nil, key .. ": nothing asks the server to sell it for Coroas" .. v)
		end
		-- (a rich player all the same)
		local rich, rs = window(view, 5000000)
		for _, key in BOOSTERS do
			local cta, card = page(rich, key)
			check(cta == "Not available yet." and card == "SOON", key .. ", no product, 5M Coroas: still not for Coroas: " .. cta .. v)
			rich:_stars_pressed(Catalog.item(key), true)
			check(bought(rs) == 0, key .. ": 5M Coroas buy no booster" .. v)
		end
	end
	-- the products made (the game as it ships since 2026-11-11): both ways for a unit, one for a booster
	for _, it in Catalog.ITEMS do
		Products[it.product].id = 7000
	end
	do
		local a, s = window(view, 1000)
		for _, key in UNITS do
			local cta, card, icon = page(a, key)
			check(has(cta, "BUY NOW | " .. ROWORLD_ROBUX[key]) and has(cta, "Or earn it by playing:"), key .. ": Robux and Coroas, both: " .. cta .. v)
			check(card == tostring(ROWORLD_ROBUX[key]) and icon == true, key .. ": short of Coroas, the card shows the Robux price: " .. card .. v)
		end
		for _, key in BOOSTERS do
			local cta, card, icon = page(a, key)
			check(cta == "BUY NOW | " .. ROWORLD_ROBUX[key] .. " | Robux only.", key .. ": Robux, and the line 'Robux only': " .. cta .. v)
			check(not has(cta, "UNLOCK WITH") and not has(cta, "Earn it"), key .. ": no Coroas way" .. v)
			check(card == tostring(ROWORLD_ROBUX[key]) and icon == true, key .. ": the card shows the Robux price: " .. card .. v)
		end
		-- with the Coroas for it: a unit offers both, a booster still Robux alone
		local rich, rs = window(view, 5000000)
		for _, key in UNITS do
			local cta, card = page(rich, key)
			check(has(cta, "BUY NOW | " .. ROWORLD_ROBUX[key]) and has(cta, "OR UNLOCK WITH | " .. ArsenalWindow.commas(ROWORLD_STARS[key])), key .. ", with the Coroas: both buttons: " .. cta .. v)
			check(card == ArsenalWindow.short(ROWORLD_STARS[key]), key .. ", with the Coroas: the card shows the Coroas price: " .. card .. v)
		end
		for _, key in BOOSTERS do
			local cta, card = page(rich, key)
			check(cta == "BUY NOW | " .. ROWORLD_ROBUX[key] .. " | Robux only." and card == tostring(ROWORLD_ROBUX[key]), key .. ", 5M Coroas: Robux alone: " .. cta .. v)
			rich:_stars_pressed(Catalog.item(key), true)
			check(bought(rs) == 0, key .. ": 5M Coroas buy no booster" .. v)
		end
		local _ = s
	end
	for _, it in Catalog.ITEMS do
		Products[it.product].id = 0
	end
end

-- what the window writes is in the game's language
for english, pt in {
	["Not available yet."] = "Ainda não disponível.",
	["Robux only."] = "Somente com Robux.",
	["SOON"] = "EM BREVE",
} do
	check(LangPt[english] == pt, '"' .. english .. '" in Portuguese: ' .. tostring(LangPt[english]))
end
check(type(LangPt["BUY NOW"]) == "string" and type(LangPt["OR UNLOCK WITH"]) == "string", "the two buttons have their Portuguese")
-- the owner's file teaches the same
do
	local src = fs.readFile("src/shared/Data/MyProducts.luau")
	check(
		string.match(src, "unlock_stars2x = { id = %d+, robux = 59 }") ~= nil and string.match(src, "unlock_reload2x = { id = %d+, robux = 129 }") ~= nil,
		"MyProducts lists the two boosters at RoWorld's prices"
	)
	check(has(src, "SÓ POR ROBUX"), "... and says they are Robux only")
end

print(string.format("arsenal_precos: %d checks, %d failed", checks, failed))
if failed > 0 then
	error("arsenal_precos failed")
end
