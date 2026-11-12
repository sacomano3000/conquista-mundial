--!nocheck
-- The mystery shop ("Loja Misteriosa", Data/Shop): a few of the Coleção's items a day, the same window
-- for everyone, sold for Robux by rarity; each slot has a tiny chance, per player, of coming for Coroas
-- with a Common item (rarer still: a Rare one). The owner's numbers are in Data/MyShop.
--   lune run tests/shop.luau
require("./prelude")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local MyShop = require("../src/shared/Data/MyShop")
local Products = require("../src/shared/Data/Products")
local Shop = require("../src/shared/Data/Shop")

local fails, checks = 0, 0
local function expect(c: any, w: string)
	checks += 1
	if c then
		print("  ok   " .. w)
	else
		fails += 1
		print("FAIL " .. w)
	end
end

-- the owner's numbers
expect(Shop.SLOTS == MyShop.loja.ofertas_por_dia and Shop.SLOTS == 6, "6 offers a day")
expect(
	Shop.PRICES.common == 19 and Shop.PRICES.rare == 49 and Shop.PRICES.epic == 99 and Shop.PRICES.legendary == 199,
	"Robux prices by rarity come from Data/MyShop"
)
expect(Shop.STAR_PRICES.common == 6000 and Shop.STAR_PRICES.rare == 25000, "Coroas prices: Common and Rare only")
expect(Shop.STAR_PRICES.epic == nil and Shop.STAR_PRICES.legendary == nil, "no Epic or Legendary is ever sold for Coroas")
expect(math.abs(Shop.P_STARS_COMMON - 0.0002) < 1e-12, "a Coroas offer: 0.02% of the offers")
expect(math.abs(Shop.P_STARS_RARE - 0.000001) < 1e-15, "a Rare for Coroas: 0.0001% of the offers")
for _, r in Cosmetics.RARITIES do
	local p = Products[Shop.product_key(r.id)]
	expect(p ~= nil and p.robux == Shop.PRICES[r.id] and p.grants == "shopbuy:" .. r.id, "a product for " .. r.id)
end

-- days
expect(Shop.day(0) == 0 and Shop.day(86399) == 0 and Shop.day(86400) == 1, "a day is 24 h of UTC")
expect(Shop.next_in(86400 * 5 + 10) == 86390, "the time to the next window")

-- the window: the same for everyone, no item twice, different from day to day, every item real
local D = 20500
local w1, w2 = Shop.window(D), Shop.window(D)
expect(#w1 == Shop.SLOTS, "a full window")
local same, uniq, real = true, true, true
local seen = {}
for i, id in w1 do
	same = same and w2[i] == id
	uniq = uniq and not seen[id]
	seen[id] = true
	local it = Cosmetics.item(id)
	real = real and it ~= nil and not it.exclusive
end
expect(same, "asked twice: the same window")
expect(uniq, "no item twice in a day")
expect(real, "every item is one of the Coleção's")
local changed = 0
for d = D + 1, D + 30 do
	local w = Shop.window(d)
	if table.concat(w, ",") ~= table.concat(Shop.window(d - 1), ",") then
		changed += 1
	end
end
expect(changed == 30, "30 days: 30 different windows")
-- over many days every kind and every rarity shows up, by about the window's weights
local kinds, rar, n = {}, {}, 0
for d = D, D + 1999 do
	for _, id in Shop.window(d) do
		local it = Cosmetics.item(id)
		kinds[it.kind] = (kinds[it.kind] or 0) + 1
		rar[it.rarity] = (rar[it.rarity] or 0) + 1
		n += 1
	end
end
expect((kinds.skin or 0) > 0 and (kinds.flag or 0) > 0 and (kinds.pet or 0) > 0, "skins, flags and pets are all sold")
local wsum = Shop.WINDOW.common + Shop.WINDOW.rare + Shop.WINDOW.epic + Shop.WINDOW.legendary
local near = true
for id, wt in Shop.WINDOW do
	local share = (rar[id] or 0) / n
	print(string.format("       %-9s %.1f%% of the windows (weight %.0f%%)", id, share * 100, wt / wsum * 100))
	near = near and math.abs(share - wt / wsum) < 0.03
end
expect(near, "rarities appear by the window's weights (±3%)")

-- offers: Robux, the price and the product of the item's rarity
local offers = Shop.offers(D, 4242)
local good = #offers == #w1
for i, o in offers do
	local it = Cosmetics.item(o.id)
	good = good
		and o.slot == i
		and it ~= nil
		and o.rarity == it.rarity
		and (
			(o.currency == "robux" and o.id == w1[i] and o.price == Shop.PRICES[it.rarity] and o.product == "shop_" .. it.rarity)
			or (o.currency == "stars" and o.product == nil)
		)
end
expect(good, "each slot: the window's item for Robux, at its rarity's price")
expect(Shop.offer(D, 4242, w1[1]) ~= nil and Shop.offer(D, 4242, w1[1]).id == w1[1], "an item's offer is found by id")
expect(Shop.offer(D, 4242, "nope") == nil and Shop.offer(D, 4242, nil) == nil, "an item not in the window has no offer")
expect(Shop.on_sale(w1[2], D * 86400 + 5) and not Shop.on_sale("nope", D * 86400), "on_sale follows the window")
local again = Shop.offers(D, 4242)
local stable = true
for i, o in offers do
	stable = stable and again[i].id == o.id and again[i].currency == o.currency and again[i].price == o.price
end
expect(stable, "the same player, the same day: the same offers (the server checks a purchase against them)")

-- Coroas offers: about 0.02% of the slots, always a Common item (a Rare one about once in a million)
do
	local slots, stars, star_common, star_rare, bad = 0, 0, 0, 0, 0
	local who, when = nil, nil
	for uid = 1, 250000 do
		for _, o in Shop.offers(D, uid) do
			slots += 1
			if o.currency == "stars" then
				stars += 1
				local it = Cosmetics.item(o.id)
				if it == nil or it.rarity ~= o.rarity or o.price ~= Shop.STAR_PRICES[o.rarity] then
					bad += 1
				elseif o.rarity == "common" then
					star_common += 1
					who, when = uid, o
				elseif o.rarity == "rare" then
					star_rare += 1
				else
					bad += 1
				end
			end
		end
	end
	local want = slots * (Shop.P_STARS_COMMON + Shop.P_STARS_RARE)
	print(string.format("       %d slots: %d for Coroas (expected about %.0f), %d of them Rare", slots, stars, want, star_rare))
	expect(bad == 0, "a Coroas offer is a Common or a Rare item, at its Coroas price")
	expect(math.abs(stars - want) < 5 * math.sqrt(want), "about 0.02% of the offers come for Coroas")
	expect(star_rare <= 12, "a Rare for Coroas is far rarer (0.0001%)")
	expect(star_common >= stars - 12, "the rest are Common")
	expect(who ~= nil, "someone got one")
	if who ~= nil then
		local o = Shop.offer(D, who, when.id)
		expect(o ~= nil and o.currency == "stars" and o.price == 6000, "that player's offer is found by id, for 6000 Coroas")
		local other = Shop.offer(D, who + 1, when.id)
		expect(other == nil or other.currency == "robux", "it is theirs alone: the next player has no such offer")
		local n_dup = 0
		local ids = {}
		for _, x in Shop.offers(D, who) do
			n_dup += if ids[x.id] then 1 else 0
			ids[x.id] = true
		end
		expect(n_dup == 0, "it does not repeat another slot's item")
	end
end

-- RoWorld's flag shop is gone: no flags of its own, no sets
expect(#Shop.flags() == 0 and next(Shop.SETS) == nil and Shop.flag("x") == nil and Shop.key_of("shop_x") == nil, "no flag shop of the old kind")

print(string.format("shop: %d checks, %d failed", checks, fails))
if fails > 0 then
	error("shop tests failed")
end
