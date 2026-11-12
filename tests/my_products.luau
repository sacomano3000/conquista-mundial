--!nocheck
-- Data/MyProducts: the owner's own developer products. Each line names a product of Data/Products: an
-- Arsenal item's unlock, the Coleção's crate (and its optional packs), the mystery shop's price of
-- each rarity, or the month's pass (Data/Missions); nothing is on sale until a line has an id.
--   lune run tests/my_products.luau
local Mine = require("../src/shared/Data/MyProducts")
local Products = require("../src/shared/Data/Products")
local Catalog = require("../src/shared/Data/Arsenal")
local MyShop = require("../src/shared/Data/MyShop")

local fails = 0
local function ok(cond: boolean, what: string)
	if not cond then
		fails += 1
		print("FAIL " .. what)
	end
end

local lines = 0
for key, m in Mine do
	lines += 1
	local p = Products[key]
	ok(type(p) == "table", key .. " is a product of Data/Products")
	ok(type(m.id) == "number" and m.id >= 0 and type(m.robux) == "number" and m.robux > 0, key .. " has an id and a price")
	if type(p) == "table" then
		local kind = p.grants or key
		ok(
			string.match(kind, "^unlock:") ~= nil
				or string.match(kind, "^shopbuy:") ~= nil
				or kind == "crate"
				or p.kind == "crate"
				or (key == "pass" and kind == "pass"),
			key .. " unlocks an Arsenal item, is a crate, is a mystery shop price, or is the month's pass"
		)
		ok(p.id == m.id, key .. " is on sale exactly when its line has an id")
		ok(p.staging == 0, key .. " has no product of another experience")
	end
end
ok(lines == 14, "8 Arsenal items, the crate, 4 shop prices, the month's pass (" .. lines .. ")")

-- the game ships with the owner's 13 products (2026-11-11): every line has its own id, a whole
-- number, and none of them is one of RoWorld's (Data/Products names those, for RoWorld's experience).
-- The month's pass (2026-11-12) is the 14th line: its product may not exist yet (id 0: the window's
-- button says EM BREVE); once it has an id, the same rules.
local PASS_READY = Mine.pass ~= nil and Mine.pass.id ~= 0
ok(Mine.pass ~= nil and Products.pass ~= nil and Products.pass.grants == "pass", "the month's pass has its line, and its product gives the pass")
ok(require("../src/shared/Data/Missions").PRODUCT == "pass", "which is the product the missions sell")
do
	local fs = require("@lune/fs")
	-- RoWorld's own product ids (its experience and its test experience), as they were listed in
	-- Data/Products until 2026-11-12: none may be in this game, in the owner's file or anywhere in
	-- Data/Products (which now has no id of its own at all).
	local theirs = {}
	for _, id in {
		3715363250, 3715469100, 3715469104, 3716609998, 3716610004, 3716610015, 3716610019, 3716610030,
		3716610035, 3716610048, 3716610055, 3716610101, 3716610114, 3716610118, 3716621701, 3716621706,
		3716621710, 3716621715, 3716621718, 3716621726, 3716621730, 3716621734, 3718864635, 3718883874,
		3720061533, 3720068382, 3722748745, 3722748768,
	} do
		theirs[id] = true
	end
	local listed = 0
	for id in string.gmatch(fs.readFile("src/shared/Data/Products.luau"), "%f[%w](%d%d%d%d%d%d%d+)%f[%W]") do
		listed += 1
	end
	ok(listed == 0, "Data/Products lists no product id of its own (" .. listed .. "): the ids are the owner's, in Data/MyProducts")
	for key, p in Products do
		if type(p) == "table" and type(p.id) == "number" then
			ok(theirs[p.id] == nil, key .. ": the product the game sells is not one of RoWorld's")
		end
	end
	local seen = {}
	for key, m in Mine do
		if key == "pass" and not PASS_READY then
			ok(m.id == 0 and Products[key].robux == m.robux, "pass: no product yet, its price is the line's")
			continue
		end
		ok(m.id > 0 and m.id % 1 == 0 and m.id < 2 ^ 53, key .. " has a product id (" .. tostring(m.id) .. ")")
		ok(seen[m.id] == nil, key .. " has the same id as " .. tostring(seen[m.id]) .. ": two lines, one product")
		seen[m.id] = key
		ok(theirs[m.id] == nil, key .. " has an id of RoWorld's experience")
		ok(Products[key].robux == m.robux, key .. ": the price shown before Roblox answers is the line's")
	end
end

-- the crate: 9 Robux each, whatever the amount (Data/MyShop.caixa.robux); the shop: one price a rarity
ok(MyShop.caixa.robux == 9, "a crate costs 9 Robux")
ok(Products.crate ~= nil and Products.crate.robux == 9 and Products.crate.count == nil, "crate: one crate for 9 Robux")
ok(Mine.crate ~= nil and Mine.crate.robux == 9, "crate: the same price in MyProducts")
-- one crate a purchase (2026-11-10): no packs, in the owner's file or in the game's
for _, key in { "crate3", "crate5", "crate10" } do
	ok(Products[key] == nil and Mine[key] == nil, key .. ": no pack of crates is sold")
end
for key, p in Products do
	ok(type(p) ~= "table" or p.grants ~= "crate" or key == "crate", key .. ": the only product that gives a crate is `crate`")
	ok(type(p) ~= "table" or p.count == nil or p.count == 1, key .. ": one of it a purchase")
end
ok(Products.crate_first == nil, "no cheaper first crate")
for pt, id in { comum = "common", raro = "rare", epico = "epic", lendario = "legendary" } do
	local p = Products["shop_" .. id]
	ok(
		p ~= nil and p.robux == MyShop.loja.robux[pt] and p.grants == "shopbuy:" .. id and Mine["shop_" .. id].robux == p.robux,
		"shop_" .. id .. ": the price of Data/MyShop.loja.robux." .. pt
	)
end

-- every Arsenal item can be sold; the six units can be earned too, the two boosters are Robux only
-- (2026-11-11, as in RoWorld; tests/arsenal_precos.luau)
local items, earned = 0, 0
for _, it in Catalog.ITEMS or Catalog.items or {} do
	items += 1
	ok(Mine[it.product] ~= nil, tostring(it.key) .. " has a line in MyProducts")
	if it.kind == "boost" then
		ok(it.stars == nil, tostring(it.key) .. " is sold for Robux only")
	else
		earned += 1
		ok(type(it.stars) == "number" and it.stars > 0, tostring(it.key) .. " can be earned by playing")
	end
end
ok(items == 8 and earned == 6, "eight Arsenal items, six of them earned (" .. items .. ", " .. earned .. ")")

-- nothing of RoWorld's is ever used: a product with no line stays off
for key, p in Products do
	if Mine[key] == nil then
		ok(p.id == 0 and (p.staging or 0) == 0, key .. " is not on sale")
	end
end

print(string.format("my_products: %d lines, %d failed", lines, fails))
if fails > 0 then
	error("my_products tests failed")
end
