--!strict
-- The mystery shop ("Loja Misteriosa"): every day (00:00 UTC) a few of the Coleção's items (Data/Cosmetics:
-- skins, flags, pets) are on sale one by one, with no draw: what is shown is what is bought.
--
--   the day's window   SLOTS items, the same for everyone, worked out from the date alone (every server
--                      and client agrees): each slot rolls a rarity by WINDOW (Data/MyShop.loja.vitrine)
--                      and then an item of that rarity, no item twice in a day.
--   Robux              an offer costs Robux: one developer product per rarity (Data/Products
--                      "shop_<rarity>", the owner's ids in Data/MyProducts). The server is told which
--                      item the prompt is for (server/Purchases.shop_pick) before the prompt opens.
--   Coroas             each slot, for each player, has a tiny chance of coming for the currency matches
--                      pay instead (Data/MyShop.loja.chance_coroas_comum / _raro, in %): then the slot
--                      holds a Common item (or, rarer still, a Rare one) at a price in Coroas. That roll
--                      comes from the day, the slot and the player's user id: the server works out the
--                      same offers and checks every purchase against them.
--
--   Shop.offers(day, user_id) -> { { slot, id, rarity, currency = "robux" | "stars", price, product? } }
--   Shop.offer(day, user_id, item_id) -> that item's offer today for that player, or nil
--   Shop.day(t) / Shop.next_in(t)
local IS_ROBLOX = typeof(game) == "Instance"
local function data(name: string): any
	if IS_ROBLOX then
		return require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data[name]) :: any
	end
	return (require :: any)("./" .. name)
end
local Cosmetics: any = data("Cosmetics")
local MyShop: any = data("MyShop")

local Shop = {}

Shop.DAY_S = 86400

local cfg: any = if type(MyShop) == "table" and type(MyShop.loja) == "table" then MyShop.loja else {}
local RARITY_PT: { [string]: string } = Cosmetics.RARITY_PT

local function by_rarity(t: any, fallback: { [string]: number }): { [string]: number }
	local out = table.clone(fallback)
	if type(t) == "table" then
		for pt, id in RARITY_PT do
			local v = tonumber(t[pt])
			if v ~= nil and v == v and v >= 0 then
				out[id] = v
			end
		end
	end
	return out
end

--- Items in the day's window.
Shop.SLOTS = math.clamp(math.floor(tonumber(cfg.ofertas_por_dia) or 6), 1, 12)
--- Which rarities the window shows (weights).
Shop.WINDOW = by_rarity(cfg.vitrine, { common = 40, rare = 35, epic = 20, legendary = 5 })
--- Robux by rarity (the price shown until Roblox answers: UI/Prices; the product's price is what counts).
Shop.PRICES = by_rarity(cfg.robux, { common = 19, rare = 49, epic = 99, legendary = 199 })
--- Coroas by rarity, for an offer that came for Coroas (only Common and Rare ever do).
Shop.STAR_PRICES = by_rarity(cfg.coroas, { common = 6000, rare = 25000 })
--- The chance (0..1) of a slot coming for Coroas with a Common item / with a Rare item. The owner
--- writes them in % (0.02 = 0.02%).
Shop.P_STARS_COMMON = math.clamp((tonumber(cfg.chance_coroas_comum) or 0.02) / 100, 0, 1)
Shop.P_STARS_RARE = math.clamp((tonumber(cfg.chance_coroas_raro) or 0.0001) / 100, 0, 1)

--- RoWorld's flag shop (flags of its own, limited sets): none here. Kept empty for the code that asks.
Shop.SETS = {}
Shop.ITEM_PREFIX = "shop_"
function Shop.flags(): { any }
	return {}
end
function Shop.flag(_key: any): any
	return nil
end
function Shop.key_of(_id: any): string?
	return nil
end
function Shop.item_id(key: string): string
	return Shop.ITEM_PREFIX .. key
end

--- The developer product key of a rarity's price (Data/Products).
function Shop.product_key(rarity: string): string
	return "shop_" .. rarity
end

--- The UTC day number of Unix time `t`.
function Shop.day(t: number): number
	return math.floor(t / Shop.DAY_S)
end

--- Seconds from `t` until the shop turns over.
function Shop.next_in(t: number): number
	return (Shop.day(t) + 1) * Shop.DAY_S - t
end

-- xorshift32 (bit32: the same numbers in every Luau, so every server and client agrees)
local function rng(seed: number): () -> number
	local s = bit32.band(seed, 0xFFFFFFFF)
	if s == 0 then
		s = 0x9E3779B9
	end
	local function step(): number
		s = bit32.bxor(s, bit32.lshift(s, 13))
		s = bit32.bxor(s, bit32.rshift(s, 17))
		s = bit32.bxor(s, bit32.lshift(s, 5))
		return s
	end
	for _ = 1, 4 do
		step() -- (mix the seed)
	end
	return step
end

--- A fraction in [0, 1) from a generator.
local function unit(next: () -> number): number
	return next() / 4294967296
end

--- (x * m) mod 2^32 without leaving the integers a double holds exactly
local function mul32(x: number, m: number): number
	local lo, hi = x % 65536, x // 65536
	return ((hi * m) % 65536 * 65536 + lo * m) % 4294967296
end

--- Two numbers (each under 2^32) into one seed.
local function mix(a: number, b: number): number
	local x = bit32.bxor(bit32.band(a, 0xFFFFFFFF), bit32.lrotate(bit32.band(b, 0xFFFFFFFF), 16))
	x = mul32(bit32.bxor(x, bit32.rshift(x, 15)), 0x2C1B3C6D)
	x = mul32(bit32.bxor(x, bit32.rshift(x, 12)), 0x297A2D39)
	return bit32.bxor(x, bit32.rshift(x, 15))
end

--- The catalog by rarity (ids, in catalog order).
local pools: { [string]: { string } }? = nil
local function pool_of(rarity: string): { string }
	if pools == nil then
		local p: { [string]: { string } } = {}
		for _, it in Cosmetics.all() do
			p[it.rarity] = p[it.rarity] or {}
			table.insert(p[it.rarity], it.id)
		end
		pools = p
	end
	return (pools :: any)[rarity] or {}
end

local ORDER = { "common", "rare", "epic", "legendary" }

--- The day's window, the same for everyone: SLOTS item ids (fewer when the catalog is smaller).
local window_day, window_ids = -1, {} :: { string }
function Shop.window(day: number): { string }
	if day == window_day then
		return window_ids
	end
	local next = rng(mix(day, 0x51ED))
	local taken: { [string]: boolean } = {}
	local out: { string } = {}
	local total = 0.0
	for _, r in ORDER do
		if #pool_of(r) > 0 then
			total += Shop.WINDOW[r] or 0
		end
	end
	for _ = 1, Shop.SLOTS do
		-- a rarity by weight (among those that have items), then an item of it not shown yet today;
		-- a rarity used up falls to the next one with items left
		local x = unit(next) * total
		local start = 1
		for i, r in ORDER do
			if #pool_of(r) > 0 then
				start = i
				x -= Shop.WINDOW[r] or 0
				if x < 0 then
					break
				end
			end
		end
		local u = unit(next)
		local picked: string? = nil
		for k = 0, #ORDER - 1 do
			local pool = pool_of(ORDER[(start - 1 + k) % #ORDER + 1])
			local free = {}
			for _, id in pool do
				if not taken[id] then
					table.insert(free, id)
				end
			end
			if #free > 0 then
				picked = free[math.clamp(math.floor(u * #free) + 1, 1, #free)]
				break
			end
		end
		if picked == nil then
			break
		end
		taken[picked] = true
		table.insert(out, picked)
	end
	window_day, window_ids = day, out
	return out
end

--- The offers of `day` for player `user_id`: the day's window, with each slot's own roll for Coroas.
function Shop.offers(day: number, user_id: number): { any }
	local out = {}
	local ids = Shop.window(day)
	local shown: { [string]: boolean } = {}
	for _, id in ids do
		shown[id] = true
	end
	for slot, id in ids do
		local next = rng(mix(mix(day, slot), math.abs(math.floor(user_id)) % 4294967296))
		local u = unit(next)
		local star_rarity: string? = nil
		if u < Shop.P_STARS_RARE then
			star_rarity = "rare"
		elseif u < Shop.P_STARS_RARE + Shop.P_STARS_COMMON then
			star_rarity = "common"
		end
		local offer: any = nil
		if star_rarity ~= nil then
			-- the slot holds an item of that rarity instead (one not in today's window already)
			local free = {}
			for _, pid in pool_of(star_rarity) do
				if not shown[pid] then
					table.insert(free, pid)
				end
			end
			if #free > 0 then
				local pid = free[math.clamp(math.floor(unit(next) * #free) + 1, 1, #free)]
				shown[pid] = true
				offer = {
					slot = slot,
					id = pid,
					rarity = star_rarity,
					currency = "stars",
					price = Shop.STAR_PRICES[star_rarity] or 0,
				}
			end
		end
		if offer == nil then
			local it = Cosmetics.item(id)
			local rarity = if it ~= nil then it.rarity else "common"
			offer = {
				slot = slot,
				id = id,
				rarity = rarity,
				currency = "robux",
				price = Shop.PRICES[rarity] or 0,
				product = Shop.product_key(rarity),
			}
		end
		table.insert(out, offer)
	end
	return out
end

--- Item `item_id`'s offer on `day` for player `user_id` (nil: not on sale for them that day).
function Shop.offer(day: number, user_id: number, item_id: any): any
	if type(item_id) ~= "string" then
		return nil
	end
	for _, o in Shop.offers(day, user_id) do
		if o.id == item_id then
			return o
		end
	end
	return nil
end

--- Is item `id` in the window at `t` (for anyone: the Robux offers)?
function Shop.on_sale(id: string, t: number): boolean
	return table.find(Shop.window(Shop.day(t)), id) ~= nil
end

return Shop
