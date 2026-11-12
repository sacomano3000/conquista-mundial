--!nocheck
-- The result screen's offers (UI/UIRules.result_offers, shown by UI/GameOver): the next unlock and
-- 2x Stars, said truthfully.
-- Run: .bin/lune run tests/offers.luau
require("./prelude")
local UIRules = require("../src/client/UI/UIRules")
local Arsenal = require("../src/shared/Data/Arsenal")

local fails, total = 0, 0
local function expect(cond: any, what: string)
	total += 1
	if cond then
		print("  ok   " .. what)
	else
		fails += 1
		print("FAIL " .. what)
	end
end

local award = { lines = {}, total = 1440, balance = 4560 }
local function inv(unlocks, stars)
	return { stars = stars or 4560, unlocks = unlocks or {}, loaded = true }
end

local o = UIRules.result_offers(award, inv(), Arsenal)
expect(
	o.goal ~= nil and o.goal.key == "mega" and o.goal.ready == false and o.goal.text == "MEGA NUKE  4,560 / 20,000",
	"a new player: the Mega Nuke, with the Stars they have and its price"
)
expect(o.x2 ~= nil and o.x2.text == "WITH 2X STARS: +2,880", "and what this match would have paid with 2x Stars")

o = UIRules.result_offers({ lines = {}, total = 900, balance = 20000 }, inv(), Arsenal)
expect(o.goal.ready == true and o.goal.text == "UNLOCK MEGA NUKE", "with the Stars for it: UNLOCK")

o = UIRules.result_offers(award, inv({ mega = true, stars2x = true }), Arsenal)
expect(o.goal.key == "scatter" and o.x2 == nil, "the next one after what is owned; no 2x offer to its owner")

-- the balance: the payout's own, or the one handed in (the inventory's after a purchase)
o = UIRules.result_offers(award, inv({}, 99999), Arsenal)
expect(o.goal.text == "MEGA NUKE  4,560 / 20,000", "the payout's balance counts, not a stale inventory")
o = UIRules.result_offers(award, inv({ mega = true }, 560), Arsenal, 560)
expect(o.goal.text == "SCATTERSHOT  560 / 40,000", "after an unlock: the inventory's Stars")

local all = {}
for _, it in Arsenal.ITEMS do
	all[it.key] = true
end
o = UIRules.result_offers(award, inv(all), Arsenal)
expect(o.goal == nil and o.x2 == nil, "everything owned: nothing is offered")

expect(next(UIRules.result_offers(nil, inv(), Arsenal)) == nil, "no payout: no offers")
expect(next(UIRules.result_offers({ lines = {}, total = 0, balance = 5 }, inv(), Arsenal)) == nil, "a payout of nothing: no offers")
expect(
	next(UIRules.result_offers(award, { stars = 0, unlocks = {}, loaded = false }, Arsenal)) == nil,
	"the record not loaded yet: no offers (what is owned is unknown)"
)

-- 2x Stars is Robux only (2026-11-11): told what is on sale, the screen offers it only where it can be bought
do
	local Products = require("../src/shared/Data/Products")
	expect(Arsenal.item("stars2x").stars == nil, "2x Stars has no price in the currency")
	local shipped = Products.unlock_stars2x.id
	expect(type(shipped) == "number" and shipped > 0, "... and, as the game ships (2026-11-11), its product")
	o = UIRules.result_offers(award, inv(), Arsenal, nil, Products)
	expect(o.x2 ~= nil and o.x2.text == "WITH 2X STARS: +2,880", "as the game ships: 2x Stars is offered")
	Products.unlock_stars2x.id = 0
	o = UIRules.result_offers(award, inv(), Arsenal, nil, Products)
	expect(o.x2 == nil, "no product: 2x Stars is not offered (it could not be bought)")
	expect(o.goal ~= nil and o.goal.key == "mega", "... the next unlock still is")
	Products.unlock_stars2x.id = 9002
	o = UIRules.result_offers(award, inv(), Arsenal, nil, Products)
	expect(o.x2 ~= nil and o.x2.text == "WITH 2X STARS: +2,880", "the product made: 2x Stars is offered")
	o = UIRules.result_offers(award, inv({ stars2x = true }), Arsenal, nil, Products)
	expect(o.x2 == nil, "... but not to its owner")
	Products.unlock_stars2x.id = shipped
	expect(UIRules.result_offers(award, inv(), Arsenal, nil, {}).x2 == nil, "a catalog without the product: not offered")
	local src = require("@lune/fs").readFile("src/client/UI/GameOver.luau")
	expect(string.find(src, 'UIRules.result_offers(self._award, inv, UICtx.data("Arsenal"), self._balance, UICtx.data("Products"))', 1, true) ~= nil, "the result screen tells it what is on sale")
end

print(("offers: %d/%d passed"):format(total - fails, total))
if fails > 0 then
	error(("offers: %d failures"):format(fails))
end
