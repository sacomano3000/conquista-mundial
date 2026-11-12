--!strict
-- Robux developer products (Creator Dashboard → Monetization → Developer Products). `id` is the
-- product's id; 0 = not created yet (its offer stays hidden). Each purchase is a saved credit of kind
-- `grants` (default: the key), `count` of them (default 1) (server/Purchases.luau): bought credits are
-- never lost if the moment passes. A `grants` of "unlock:<key>" is not a credit: it unlocks that
-- Arsenal item for good (Data/Arsenal).
--
-- Product ids belong to one experience, so every `id` here is 0: this game's ids are the owner's, in
-- Data/MyProducts (read at the end of this file). The original game's own ids were listed here until
-- 2026-11-12; they were never used (a product of another experience cannot be sold in this one) and
-- are gone. `staging` (the same product in a separate test experience, Data/Staging) is unused too.
local PRODUCTS: { [string]: any } = {
	--- Solo / public: take over the AI nation that eliminated you (2026-09-28).
	takeover = { id = 0, robux = 25 },
	--- A cosmetic crate (Data/Cosmetics; 2026-09-29: 49 Robux, the first one 15).
	crate = { id = 0, robux = 49 },
	--- The first crate a player buys (offered only before their first crate).
	crate_first = { id = 0, robux = 15, grants = "crate", first_only = true },
	--- Three crates at once (2026-10-19: 100 Robux instead of 120,
	--- three crates being 3 x 40 at their price): `count` crate credits for one receipt.
	crate3 = { id = 0, robux = 100, grants = "crate", count = 3 },
	--- Ten crates at once (2026-10-27: a buy to come back to above 100 Robux; a paying player spent 89
	--- Robux on average, top experiences about 600): 299, about 30 a crate.
	crate10 = { id = 0, robux = 299, grants = "crate", count = 10 },
	--- The Arsenal (Data/Arsenal; 2026-10-04), at Pixel Conquest's prices.
	unlock_mega = { id = 0, robux = 39, grants = "unlock:mega" },
	unlock_scatter = { id = 0, robux = 67, grants = "unlock:scatter" },
	unlock_reinforce = { id = 0, robux = 149, grants = "unlock:reinforce" },
	unlock_artillery = { id = 0, robux = 99, grants = "unlock:artillery" },
	unlock_airfield = { id = 0, robux = 349, grants = "unlock:airfield" },
	unlock_railgun = { id = 0, robux = 999, grants = "unlock:railgun" },
	unlock_stars2x = { id = 0, robux = 59, grants = "unlock:stars2x" },
	unlock_reload2x = { id = 0, robux = 129, grants = "unlock:reload2x" },
	--- The starter pack (Data/Starter; 2026-10-15: 39 Robux, limited time): Mega Nuke, Scattershot
	--- and 2x Stars, once, for a player who never paid. Its receipt is refused outside its offer.
	starter_pack = { id = 0, robux = 39, grants = "starter" },
	--- The monthly pass (Data/Missions; 2026-11-12): bought once a calendar month, it pays the rewards
	--- of that month's missions. A developer product, not a Roblox Game Pass (which is bought once and
	--- lasts for good). This game's own: no id until Data/MyProducts gives one.
	pass = { id = 0, robux = 199, grants = "pass" },
}

--- The mystery shop (Data/Shop): one product per rarity, granting "shopbuy:<rarity>" — the item the
--- player chose before the prompt (server/Purchases.shop_pick). `shop_rarity` marks them.
local Shop: any = if typeof(game) == "Instance"
	then require((script :: any).Parent.Shop)
	else (require :: any)("./Shop")
for rarity, robux in Shop.PRICES do
	PRODUCTS[Shop.product_key(rarity)] = {
		id = 0,
		robux = robux,
		grants = "shopbuy:" .. rarity,
		shop_rarity = rarity,
	}
end

--- The crate's price (Data/MyShop.caixa.robux). One crate a purchase (2026-11-10): RoWorld's packs of
--- 3 and 10 crates are not sold here (a pack left crates waiting, and a waiting crate opens in any
--- tab of the Coleção, not the one it was bought in).
local MyShop: any = if typeof(game) == "Instance"
	then require((script :: any).Parent.MyShop)
	else (require :: any)("./MyShop")
do
	local each = math.max(1, math.floor(tonumber(MyShop.caixa and MyShop.caixa.robux) or 9))
	PRODUCTS.crate.robux = each
	PRODUCTS.crate3 = nil
	PRODUCTS.crate10 = nil
	-- (no cheaper first crate: every crate costs the same)
	PRODUCTS.crate_first = nil
end

--- the staging experience (Data/Staging): there every product is its `staging` one.
local Staging: any = if typeof(game) == "Instance"
	then require((script :: any).Parent.Staging)
	else (require :: any)("./Staging")

if Staging.here() then
	for _, p in PRODUCTS do
		p.id = p.staging or 0
	end
end

--- This game's own products (Data/MyProducts: the ids of the developer products made in ITS
--- experience): a product is on sale only when Data/MyProducts gives it an id; every other offer
--- stays hidden.
local Mine: any = if typeof(game) == "Instance"
	then require((script :: any).Parent.MyProducts)
	else (require :: any)("./MyProducts")
for key, p in PRODUCTS do
	local m = Mine[key]
	p.staging = 0
	if type(m) == "table" and type(m.id) == "number" and m.id > 0 then
		p.id = m.id
		if type(m.robux) == "number" and m.robux > 0 then
			p.robux = m.robux
		end
	else
		p.id = 0
	end
end

return PRODUCTS
