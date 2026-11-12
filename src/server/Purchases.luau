--!strict
-- Robux purchases (developer products, shared/Data/Products). A purchase is a saved credit: Roblox's
-- ProcessReceipt adds it to the player's record in its own DataStore (only the server writes it —
-- the client's SETTING op can't touch it) and only then reports the purchase granted, so Roblox
-- retries until it is stored and a receipt is never granted twice (its PurchaseId is kept). The game
-- spends a credit when the moment comes (Purchases.use); one bought after the moment passed stays
-- for the next time.
--
--   Purchases.configure(deps)     { datastore = DataStore, notify = fn(player, credits), log?, warn?,
--                                   arrived? = fn(player) -> { p = record? }? }
--   Purchases.process_receipt(info) -> "granted" | "not_processed"   (a product's `count` credits)
--   Purchases.load(player)        read the record (join; retried while Roblox refuses it), or take the
--                                 one the last server handed on (deps.arrived: server/Handoff); notify
--   Purchases.credits(player) -> { [kind]: number }
--   Purchases.use(player, kind) -> (ok, err?)   spend one (yields)
--   Purchases.settle(player, max_s) -> record?  leaving for another server: the record once this
--                                 server's writes have landed (yields)
--   Purchases.release(player)     PlayerRemoving
--   Purchases.lost                { payouts, stars } that could not be paid after every retry
--   Purchases.open_crate(player, kind?) -> (ok, item_id | err)   spend a crate credit, roll an item of
--                                 that kind (a duplicate pays Stars: Cosmetics.DUPLICATES)
--   Purchases.buy_crates(player, n) -> (ok, err?)   n crates for Stars (CRATE_STARS each; yields)
--   Purchases.shop_pick(player, item_id) -> (ok, err?)   the mystery shop: the item the Robux prompt is for
--   Purchases.shop_buy(player, item_id) -> (ok, err?)    the mystery shop: an offer that came for Stars
--   Purchases.equip(player, slot, id | false) -> (ok, err?)   "skin" / "flag" / "pet"; only owned items
--   Purchases.inventory(player) -> { owned = { id }, equipped = { skin?, flag? }, crates_bought,
--                                    stars, unlocks = { key } }
--   Purchases.add_stars(player, amount) -> (ok, balance)   a match's Stars (Data/Stars; yields)
--   Purchases.buy_unlock(player, key) -> (ok, err?)        unlock an Arsenal item with Stars (yields)
--   Purchases.has_unlock(player, key) / Purchases.unlock_mask(player)   what the player has unlocked
--   Purchases.starter_state(player) -> false | { state = "ready" } | { state = "active", left = s }
--   Purchases.starter_seen(player)   the starter pack is on their screen: its clock starts (once; yields)
--   Purchases.general_perks(player, day, skin, crates) -> given?   a RoWorld General's day (yields)
--   Purchases.rank_record(player, upto, results) -> written?   the weekly ranking's closed weeks, written
--     to the record: the insignia (worn at once) and the Coroas, which WAIT to be claimed (yields)
--   Purchases.rank_claim(player) -> paid?, total   the RANK window's CLAIM button: pays them, once (yields)
--   Purchases.rank_claimable(player) / rank_badge(player) / rank_last(player) / rank_week(player)
-- The Arsenal (Data/Arsenal): a product whose `grants` is "unlock:<key>" is not a credit — its receipt
-- unlocks that item for good (and pays the item's bonus Stars once). The same unlock bought twice (the
-- shop never offers it) pays Stars instead, DUPLICATE_STARS_PER_ROBUX for each Robux of its price.
-- The starter pack (Data/Starter; 2026-10-15): one product, kind "starter", that unlocks
-- Starter.ITEMS, for a player who has never paid Robux. Its record `starter` = { started, ends, used? }
-- is made the first time the offer is on their screen (starter_seen) and never again: a real deadline.
-- Its receipt is refused (not granted, never stored) unless that offer is running or ended under
-- Starter.GRACE_S ago and wasn't used: a prompt for it opened any other way buys nothing.
-- The record: { credits = { kind = n }, receipts = { id }, owned = { [item] = true },
--   equipped = { skin = id?, flag = id? }, crates_bought = n, stars = n, stars_earned = n,
--   unlocks = { [key] = true }, paid = bool, starter = { started, ends, used? }?, gifts = { [item] = true } }.
-- The Loja Misteriosa (Data/Shop): a product whose `grants` is "shopbuy:<rarity>" adds the item
-- the player chose before the prompt (shop_pick) and puts it on, whenever its receipt comes; without
-- a choice left, an item of that rarity they lack; with none, the currency for the price.
-- Exclusive cosmetics (Cosmetics.exclusive_skins, made for particular players): every read of a
-- record for a player (clean(v, user_id)) owns what Cosmetics.granted(user_id) lists, and the first
-- time (not yet in `gifts`) puts it on; nobody else's record can hold one.
local IS_ROBLOX = typeof(game) == "Instance"
local Products: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data.Products)
	else require("../shared/Data/Products")
local Cosmetics: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data.Cosmetics)
	else require("../shared/Data/Cosmetics")
local RankPrizes: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data.RankPrizes)
	else require("../shared/Data/RankPrizes")
local Arsenal: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data.Arsenal)
	else require("../shared/Data/Arsenal")
local Starter: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data.Starter)
	else require("../shared/Data/Starter")
local Shop: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data.Shop)
	else require("../shared/Data/Shop")
local Subscription: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data.Subscription)
	else require("../shared/Data/Subscription")

local MyShop: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data.MyShop)
	else require("../shared/Data/MyShop")

local Codes: any = if IS_ROBLOX then require((script :: any).Parent.Codes) else require("./Codes")
local Missions: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data.Missions)
	else require("../shared/Data/Missions")
local Ranked: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data.Ranked)
	else require("../shared/Data/Ranked")
local Login: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data.Login)
	else require("../shared/Data/Login")
local Stars: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data.Stars)
	else require("../shared/Data/Stars")

local Purchases = {}

--- (this version's own store: records written while every Arsenal item was free had them all
--- unlocked, so the earned Arsenal starts from an empty one)
Purchases.STORE = "ConquistaMundial_v1"
--- Receipts remembered per player (a retried ProcessReceipt is always about a recent one).
Purchases.RECEIPTS_KEPT = 100
Purchases.MAX_CREDITS = 1000
Purchases.MAX_STARS = 1000000000
--- (the wins and the kingdoms destroyed of a player's life: `stats`)
Purchases.MAX_STAT = 100000000
--- Stars for each Robux of an unlock bought a second time (what an Arsenal price works out to).
Purchases.DUPLICATE_STARS_PER_ROBUX = 500
--- Everything is free (this fork): every record owns every Arsenal item and every cosmetic its player
--- may own (Cosmetics.may_own: not someone else's exclusive), and always holds FREE_CREDITS of each
--- credit kind that isn't a crate (the takeover), however many are spent.
Purchases.FREE_FOR_ALL = true
Purchases.FREE_CREDITS = 99
--- ... except the cosmetics (the Coleção: skins, flags, pets), which are sold: crates (Purchases.CRATE_STARS,
--- Data/Products.crate) and the mystery shop (Data/Shop). true: every player owns them all, as before.
Purchases.FREE_COSMETICS = false
--- A record written while cosmetics were free owns every one of them. Such a record (no `cosm` mark)
--- starts its collection empty, once; its Coroas, Arsenal and codes stay.
Purchases.RESET_FREE_ERA = true
--- A crate's price in the currency matches pay, for every player (beside the Robux way, which only
--- players Roblox lets buy paid random items see): Data/MyShop.caixa.coroas.
Purchases.CRATE_STARS = math.max(1, math.floor(tonumber(MyShop.caixa and MyShop.caixa.coroas) or 10000))
--- Crates bought with Coroas in one request: one (2026-11-10; it was 1 to 10: the crates beyond the
--- first waited, and a waiting crate opens in any tab of the Coleção, not the one it was bought in).
Purchases.CRATE_MAX = 1
--- ... and except the Arsenal, which is earned: its items start locked and are unlocked with the
--- currency matches pay (Purchases.buy_unlock; the prices are Data/Arsenal's `stars`). Cosmetics and
--- the takeover stay free. false: FREE_FOR_ALL unlocks the Arsenal too, as it did before.
Purchases.EARN_ARSENAL = true

type Record = {
	credits: { [string]: number },
	receipts: { string },
	owned: { [string]: boolean },
	equipped: { skin: string?, flag: string?, pet: string? },
	--- 2 once the record's collection is from the time cosmetics are sold (RESET_FREE_ERA)
	cosm: number?,
	crates_bought: number,
	stars: number,
	stars_earned: number,
	unlocks: { [string]: boolean },
	--- the tutorial's Stars were paid (Data/Tutorial.STARS, once per player)
	tutorial_paid: boolean?,
	-- the weekly ranking (shared/Data/RankPrizes; Purchases.rank_record, rank_claim): the last closed
	-- week whose results were written here, the insignia won ({ week = the week it was won in, place
	-- = 1..3, wins = place?, kills = place? }: worn during week + 1), the Coroas won and not claimed
	-- yet ({ { week, wins = place?, kills = place?, stars } }, oldest first) and the last prize
	-- claimed (the same shape)
	rank_week: number?,
	rank_badge: any?,
	rank_pending: { any }?,
	rank_last: any?,
	--- ever paid Robux (a record from before this field: it has receipts)
	paid: boolean,
	--- the starter pack's offer, once it has been on their screen
	starter: { started: number, ends: number, used: boolean? }?,
	--- exclusive items already given (and put on once): Cosmetics.granted
	gifts: { [string]: boolean },
	--- RoWorld General: the UTC day whose perks were given (Purchases.general_perks)
	general_day: number?,
	--- the redeem codes this player has used (server/Codes; Purchases.redeem_code)
	codes: { [string]: boolean },
	--- the missions and the monthly pass (Data/Missions' State: today's and this month's counters,
	--- what was paid, the month the pass was bought for)
	missions: any,
	--- the ranked matches (Data/Ranked's State: this month's points, games and wins), and what the
	--- last season that closed left ({ month, points, tier, stars, games, wins }; its Coroas were
	--- paid when it was written here)
	ranked: any,
	ranked_last: any?,
	--- public matches over the player's life ({ wins, kills }: the player's card, the badges), and
	--- the daily login reward (Data/Login's State: { day, streak })
	stats: any,
	login: any,
}

--- Reading a player's record when they join: GetAsync attempts and the waits between them. Roblox
--- throttles DataStore reads now and then ("TooManyRequests ... API: GetAsync", 37 in a day on the
--- error report of 2026-10-05). The load used to give up after one attempt, and that player then
--- had none of their unlocks, Stars or cosmetics for the whole session.
Purchases.LOAD_ATTEMPTS = 5
Purchases.LOAD_BACKOFF = { 1, 3, 6, 10 }
--- After those the session goes on without the record, and the read is tried again every
--- LOAD_RETRY_S, LOAD_RETRIES more times, while the player stays.
Purchases.LOAD_RETRY_S = 20
Purchases.LOAD_RETRIES = 30
--- Stars that could not be paid on this server: every write failed, DsGate's retries included.
Purchases.lost = { payouts = 0, stars = 0 }

local deps: { [string]: any } = {}
local cache: { [any]: { [string]: number } } = {}
--- the player's items (the record's owned / equipped / crates_bought), as last read or written
local inv: { [any]: any } = {}
--- player -> the load that is still trying to read their record (a token: a newer load, a write
--- that brought the record, or leaving ends it)
local loading: { [any]: any } = {}
--- player -> their whole record as last read or written (handed to the next server: Purchases.settle)
local records: { [any]: Record } = {}
--- user id -> this server's writes to their record still in flight
local busy: { [number]: number } = {}
--- user id -> a write failed since the record was last read or written: what this server holds may
--- not be what is stored (Purchases.use keeps a spend before it is stored)
local doubt: { [number]: boolean } = {}
--- user id -> rarity -> the mystery shop item whose Robux prompt is open (Purchases.shop_pick)
local picks: { [number]: { [string]: string } } = {}

--- Every write to a record: UpdateAsync on its key, counted while in flight. Errors as UpdateAsync does.
local function update(user_id: number, fn: (any) -> any): any
	busy[user_id] = (busy[user_id] or 0) + 1
	local ok, res = pcall(function()
		return deps.datastore:UpdateAsync("u" .. tostring(user_id), fn)
	end)
	local n = (busy[user_id] or 1) - 1
	busy[user_id] = if n > 0 then n else nil
	if not ok then
		doubt[user_id] = true
		error(res, 0)
	end
	doubt[user_id] = nil
	return res
end

function Purchases.configure(d: { [string]: any })
	for k, v in d do
		deps[k] = v
	end
end

--- Tests: forget everyone.
function Purchases.reset()
	table.clear(cache)
	table.clear(inv)
	table.clear(loading)
	table.clear(records)
	table.clear(busy)
	table.clear(doubt)
	table.clear(picks)
	Purchases.lost.payouts = 0
	Purchases.lost.stars = 0
end

--- The credit kind a product grants (nil: not ours), and how many of it (1: a product's `count`
--- was for RoWorld's crate packs, which this game does not sell: Data/Products).
function Purchases.kind_of(product_id: number): (string?, number)
	for kind, p in Products do
		if p.id ~= 0 and p.id == product_id then
			return p.grants or kind, math.clamp(math.floor(tonumber(p.count) or 1), 1, 10)
		end
	end
	return nil, 0
end

local function key(user_id: number): string
	return "u" .. tostring(user_id)
end

local function clean(v: any, user_id: number?): Record
	local rec: Record = {
		credits = {},
		receipts = {},
		owned = {},
		equipped = {},
		crates_bought = 0,
		stars = 0,
		stars_earned = 0,
		unlocks = {},
		paid = false,
		gifts = {},
		codes = {},
		missions = Missions.clean(nil),
		ranked = Ranked.clean(nil),
		stats = { wins = 0, kills = 0 },
		login = Login.clean(nil),
	}
	if type(v) ~= "table" then
		v = {}
	end
	rec.login = Login.clean(v.login)
	if type(v.stats) == "table" then
		local function life(x: any): number
			local n = tonumber(x) or 0
			return if n ~= n then 0 else math.clamp(math.floor(n), 0, Purchases.MAX_STAT)
		end
		rec.stats = { wins = life(v.stats.wins), kills = life(v.stats.kills) }
	end
	rec.missions = Missions.clean(v.missions)
	rec.ranked = Ranked.clean(v.ranked)
	do
		local l = v.ranked_last
		local function int(x: any, hi: number): number
			local n = tonumber(x) or 0
			return if n ~= n then 0 else math.clamp(math.floor(n), 0, hi)
		end
		if type(l) == "table" and int(l.month, 1000000) > 0 then
			rec.ranked_last = {
				month = int(l.month, 1000000),
				points = int(l.points, Ranked.MAX_POINTS),
				tier = math.clamp(int(l.tier, 100), 1, #Ranked.TIERS),
				stars = int(l.stars, 10000000),
				games = int(l.games, Ranked.MAX_GAMES),
				wins = int(l.wins, Ranked.MAX_GAMES),
			}
		end
	end
	if type(v.codes) == "table" then
		for code, on in v.codes do
			if on == true and type(code) == "string" and #code <= Codes.MAX_LEN then
				rec.codes[code] = true
			end
		end
	end
	local function count(x: any): number
		local n = tonumber(x) or 0
		return if n ~= n then 0 else math.clamp(math.floor(n), 0, Purchases.MAX_STARS)
	end
	rec.stars = count(v.stars)
	rec.stars_earned = count(v.stars_earned)
	rec.tutorial_paid = if v.tutorial_paid == true then true else nil
	do
		local function int(x: any): number?
			local n = tonumber(x)
			return if n ~= nil and n == n and math.abs(n) < 1e9 then math.floor(n) else nil
		end
		rec.rank_week = int(v.rank_week)
		local function place(x: any): number?
			local n = int(x)
			return if n ~= nil and n >= 1 and n <= 100 then n else nil
		end
		local b = v.rank_badge
		if type(b) == "table" and int(b.week) ~= nil and RankPrizes.badge(b.place) ~= nil then
			rec.rank_badge = {
				week = int(b.week),
				place = RankPrizes.badge(b.place),
				wins = RankPrizes.badge(b.wins),
				kills = RankPrizes.badge(b.kills),
			}
		end
		local function prize(l: any): any
			if type(l) ~= "table" or int(l.week) == nil then
				return nil
			end
			return { week = int(l.week), wins = place(l.wins), kills = place(l.kills), stars = math.max(0, int(l.stars) or 0) }
		end
		rec.rank_last = prize(v.rank_last)
		if type(v.rank_pending) == "table" then
			local list = {}
			for i = 1, math.min(#v.rank_pending, 8) do
				local e = prize(v.rank_pending[i])
				if e ~= nil and (e.wins ~= nil or e.kills ~= nil) then
					table.insert(list, e)
				end
			end
			table.sort(list, function(x: any, y: any): boolean
				return x.week < y.week
			end)
			rec.rank_pending = if #list > 0 then list else nil
		end
	end
	local gday = tonumber(v.general_day)
	rec.general_day = if gday ~= nil and gday == gday then math.floor(gday) else nil
	if type(v.unlocks) == "table" then
		for k, on in v.unlocks do
			if on == true and Arsenal.item(k) ~= nil then
				rec.unlocks[k] = true
			end
		end
	end
	-- (a record from when every cosmetic was free: what it "owns" was never earned nor bought)
	local free_era = Purchases.RESET_FREE_ERA and not Purchases.FREE_COSMETICS and v.cosm ~= 2
	rec.cosm = 2
	if type(v.owned) == "table" and not free_era then
		for id, on in v.owned do
			if on == true and Cosmetics.may_own(id, user_id) then
				rec.owned[id] = true
			end
		end
	end
	if Purchases.FREE_FOR_ALL and not Purchases.EARN_ARSENAL then
		for _, it in Arsenal.ITEMS do
			rec.unlocks[it.key] = true
		end
	end
	if Purchases.FREE_FOR_ALL and Purchases.FREE_COSMETICS then
		for _, list in { Cosmetics.all(), Cosmetics.shop_items(), Cosmetics.generals() } do
			for _, it in list do
				if Cosmetics.may_own(it.id, user_id) then
					rec.owned[it.id] = true
				end
			end
		end
	end
	if type(v.gifts) == "table" then
		for id, on in v.gifts do
			if on == true and type(id) == "string" then
				rec.gifts[id] = true
			end
		end
	end
	if type(v.equipped) == "table" then
		for _, slot in Cosmetics.KINDS do
			local id = v.equipped[slot]
			local it = Cosmetics.item(id)
			if it ~= nil and it.kind == slot and rec.owned[id] then
				rec.equipped[slot] = id
			end
		end
	end
	-- (made for this player: always owned; worn the first time, then their own choice)
	for _, id in Cosmetics.granted(user_id) do
		local it = Cosmetics.item(id)
		if it ~= nil then
			rec.owned[id] = true
			if not rec.gifts[id] then
				rec.gifts[id] = true
				rec.equipped[it.kind] = id
			end
		end
	end
	rec.crates_bought = math.max(0, math.floor(tonumber(v.crates_bought) or 0))
	if type(v.credits) == "table" then
		for k, n in v.credits do
			if type(k) == "string" and type(n) == "number" and n == n then
				rec.credits[k] = math.clamp(math.floor(n), 0, Purchases.MAX_CREDITS)
			end
		end
	end
	if Purchases.FREE_FOR_ALL then
		rec.credits.takeover = math.max(rec.credits.takeover or 0, Purchases.FREE_CREDITS)
	end
	if type(v.receipts) == "table" then
		for _, r in v.receipts do
			if type(r) == "string" then
				table.insert(rec.receipts, r)
			end
		end
	end
	-- (a stored `paid` wins)
	rec.paid = if type(v.paid) == "boolean" then v.paid else #rec.receipts > 0
	if type(v.starter) == "table" then
		local started, ends = tonumber(v.starter.started), tonumber(v.starter.ends)
		if started ~= nil and ends ~= nil and started == started and ends == ends then
			rec.starter = { started = started, ends = ends, used = if v.starter.used == true then true else nil }
		end
	end
	return rec
end

local function log(text: string)
	if deps.log then
		deps.log("[Purchases] " .. text)
	end
end

local function player_by_id(user_id: number): any
	local ps = deps.players
	if ps == nil then
		return nil
	end
	local ok, p = pcall(function()
		return ps:GetPlayerByUserId(user_id)
	end)
	return if ok then p else nil
end

local function remember(player: any, rec: Record)
	loading[player] = nil -- (the record is here: a load still retrying has nothing left to do)
	records[player] = rec
	cache[player] = rec.credits
	inv[player] = {
		owned = rec.owned,
		equipped = rec.equipped,
		crates_bought = rec.crates_bought,
		stars = rec.stars,
		stars_earned = rec.stars_earned,
		unlocks = rec.unlocks,
		paid = rec.paid,
		starter = rec.starter,
		missions = rec.missions,
		tutorial_paid = rec.tutorial_paid == true,
		ranked = rec.ranked,
		ranked_last = rec.ranked_last,
		stats = rec.stats,
		login = rec.login,
	}
end

local function now_s(): number
	return if type(deps.now) == "function" then deps.now() else os.time()
end

--- The starter pack's product exists here (Studio: always, its prompt is a test purchase).
local function starter_on_sale(): boolean
	local p = Products[Starter.PRODUCT]
	return p ~= nil and (p.id ~= 0 or deps.studio == true)
end

--- `r` (a record, or a player's inv entry) has every item the pack unlocks.
local function starter_all_owned(r: any): boolean
	for _, k in Starter.ITEMS do
		if not r.unlocks[k] then
			return false
		end
	end
	return true
end

--- `r` may be offered the pack for the first time: never paid Robux, has played (a match or the
--- tutorial paid Stars), and doesn't have all of it already.
local function starter_eligible(r: any): boolean
	return not r.paid and (r.stars_earned or 0) > 0 and not starter_all_owned(r)
end

--- The pack's receipt may be granted on record `rec` at time `t`.
local function starter_redeemable(rec: Record, t: number): boolean
	local s = rec.starter
	return s ~= nil and not s.used and t <= s.ends + Starter.GRACE_S
end

--- Unlocks Arsenal item `it` on `rec` (a Robux receipt, or Stars already taken): its bonus Stars come
--- with it once. Already unlocked: Stars for the price instead.
local function unlock_on(rec: Record, it: any, robux: number?)
	if rec.unlocks[it.key] then
		local back = math.floor((robux or 0) * Purchases.DUPLICATE_STARS_PER_ROBUX)
		rec.stars = math.min(rec.stars + back, Purchases.MAX_STARS)
		return
	end
	rec.unlocks[it.key] = true
	rec.stars = math.min(rec.stars + (it.bonus or 0), Purchases.MAX_STARS)
end

--- Missions (Data/Missions): pays into `rec` what its missions owe at `t`: Coroas, and the season's
--- items (owned for good; put on when that slot wears nothing). Inside a write. Returns what
--- Missions.settle did.
local function settle_missions(rec: Record, t: number): any
	local out = Missions.settle(rec.missions, t, rec.owned)
	if out.stars > 0 then
		rec.stars = math.min(rec.stars + out.stars, Purchases.MAX_STARS)
		rec.stars_earned = math.min(rec.stars_earned + out.stars, Purchases.MAX_STARS)
	end
	for _, id in out.items do
		local it = Cosmetics.item(id)
		if it ~= nil then
			rec.owned[id] = true
			if rec.equipped[it.kind] == nil then
				rec.equipped[it.kind] = id
			end
		end
	end
	return out
end

local function notify(player: any)
	if player ~= nil and deps.notify then
		pcall(deps.notify, player, table.clone(cache[player] or {}))
	end
	if player ~= nil and deps.inventory then
		pcall(deps.inventory, player, Purchases.inventory(player))
	end
end

--- The player's items for the client: owned ids (list), equipped, crates bought.
function Purchases.inventory(player: any): any
	local i = inv[player]
	local owned = {}
	if i ~= nil then
		for id in i.owned do
			table.insert(owned, id)
		end
		table.sort(owned)
	end
	local unlocks = {}
	if i ~= nil then
		for k in i.unlocks do
			table.insert(unlocks, k)
		end
		table.sort(unlocks)
	end
	return {
		owned = owned,
		equipped = if i ~= nil then table.clone(i.equipped) else {},
		crates_bought = if i ~= nil then i.crates_bought else 0,
		stars = if i ~= nil then i.stars else 0,
		unlocks = unlocks,
		starter = Purchases.starter_state(player),
		missions = Purchases.missions_state(player),
		-- the weekly ranking's insignia the player wears this week (1, 2, 3 or nil)
		badge = (Purchases.rank_badge(player)),
		-- ... where it was won ({ wins = place?, kills = place? }, the first three places only)
		badge_on = select(2, Purchases.rank_badge(player)),
		-- the weekly ranking's Coroas won and not claimed yet ({ total, weeks = { { week, wins?,
		-- kills?, stars } } }), or nil: the RANK button's mark and the window's CLAIM button
		rank_claim = Purchases.rank_claimable(player),
		-- the tutorial's Coroas were paid already (tutorial_bonus pays once in a player's life): the
		-- tutorial played again from the settings says so instead of promising them
		tutorial_paid = i ~= nil and i.tutorial_paid == true,
		-- the ranked matches (Data/Ranked): this month's state with this server's clock (`now`: the
		-- client reads the season from it, not from the device's clock), and the last season that
		-- closed ({ month, points, tier, stars, games, wins }), or nil
		ranked = Purchases.ranked_state(player),
		ranked_last = if i ~= nil and i.ranked_last ~= nil then table.clone(i.ranked_last) else nil,
		-- public matches over the player's life ({ wins, kills }: the card on the title screen)
		stats = if i ~= nil and i.stats ~= nil then table.clone(i.stats) else { wins = 0, kills = 0 },
		-- the daily login reward (Data/Login): { day, streak } of the last one taken (the client
		-- reads the server's clock from `ranked.now`)
		login = if i ~= nil and i.login ~= nil then table.clone(i.login) else Login.clean(nil),
	}
end

--- The day's login reward (Data/Login): paid once a day, the first time the player comes in — Coroas,
--- or a free crate on the seventh day in a row (a credit: not a crate bought). A record that took
--- today's already is not written. Yields. -> { index, reward }, or nil.
function Purchases.login_claim(player: any): any
	local i = inv[player]
	if i == nil then
		return nil
	end
	local t = now_s()
	if not Login.peek(i.login, t).available then
		return nil
	end
	local stored: Record? = nil
	local got: any = nil
	local ok, err = pcall(function()
		update(player.UserId, function(old: any): any
			local rec = clean(old, player.UserId)
			stored = rec
			got = Login.claim(rec.login, now_s())
			if got == nil then
				return nil
			end
			local stars = math.max(0, math.floor(tonumber(got.reward.stars) or 0))
			local crates = math.max(0, math.floor(tonumber(got.reward.crate) or 0))
			if stars > 0 then
				-- (a gift, not earnings of a match: stars_earned stays)
				rec.stars = math.min(rec.stars + stars, Purchases.MAX_STARS)
			end
			if crates > 0 then
				rec.credits.crate = math.min((rec.credits.crate or 0) + crates, Purchases.MAX_CREDITS)
			end
			return rec
		end)
	end)
	if not ok or stored == nil then
		log("login reward of " .. tostring(player.UserId) .. " not paid: " .. tostring(err))
		return nil
	end
	remember(player, stored :: Record)
	if got ~= nil then
		log(string.format("%d: login reward, day %d", player.UserId, got.index))
		notify(player)
	end
	return got
end

--- The player's ranked state for the client (Data/Ranked.view reads it there).
function Purchases.ranked_state(player: any): any
	local i = inv[player]
	local st = Ranked.clean(if i ~= nil then i.ranked else nil)
	local out: any = st
	out.now = now_s()
	return out
end

--- A season of the ranked matches closed inside a write: its Coroas go into `rec` (they are not
--- earnings of a match: stars_earned stays) and the record remembers the season.
local function close_season(rec: Record, closed: any)
	if closed == nil then
		return
	end
	local add = math.max(0, math.floor(tonumber(closed.stars) or 0))
	if add > 0 then
		rec.stars = math.min(rec.stars + add, Purchases.MAX_STARS)
	end
	rec.ranked_last = closed
end

--- The month turned since the player's last ranked match: their season closes (Data/Ranked.roll) —
--- the points start again from 0 and the Coroas of the rank they ended in are paid, once. Called when
--- a player comes in; a record whose season is this month's, or that never played, is not written.
--- Yields. -> what the season left ({ month, points, tier, stars, games, wins }), or nil.
function Purchases.ranked_settle(player: any): any
	local i = inv[player]
	if i == nil then
		return nil
	end
	local st = Ranked.clean(i.ranked)
	local t = now_s()
	if st.games <= 0 or st.month <= 0 or st.month >= Missions.month(t) then
		return nil
	end
	local stored: Record? = nil
	local closed: any = nil
	local ok, err = pcall(function()
		update(player.UserId, function(old: any): any
			local rec = clean(old, player.UserId)
			stored = rec
			closed = Ranked.roll(rec.ranked, now_s())
			if closed == nil then
				return nil
			end
			close_season(rec, closed)
			return rec
		end)
	end)
	if not ok or stored == nil then
		log("ranked season of " .. tostring(player.UserId) .. " not closed: " .. tostring(err))
		return nil
	end
	remember(player, stored :: Record)
	if closed ~= nil then
		log(string.format("%d: ranked season %d closed at %d points, +%d Stars", player.UserId, closed.month, closed.points, closed.stars))
		notify(player)
	end
	return closed
end

--- The player's missions for the client (Data/Missions.view reads it there): the stored state, as it
--- is, with this server's clock (`now`, unix seconds: the client counts the day and the month from
--- it, not from the device's clock) and whether the pass can be bought here (`on_sale`).
function Purchases.missions_state(player: any): any
	local i = inv[player]
	local st = Missions.clean(if i ~= nil then i.missions else nil)
	local out: any = st
	out.now = now_s()
	out.on_sale = Products[Missions.PRODUCT] ~= nil and Products[Missions.PRODUCT].id ~= 0
	return out
end

--- Whether the player's monthly pass is on now.
function Purchases.has_pass(player: any): boolean
	local i = inv[player]
	return i ~= nil and Missions.has_pass(Missions.clean(i.missions), now_s())
end

--- The starter pack for this player: false (none: not eligible, bought, ended, or not on sale here),
--- { state = "ready" } (never shown yet: the client shows it and says so, starter_seen), or
--- { state = "active", left = seconds } (its clock is running).
function Purchases.starter_state(player: any): any
	local i = inv[player]
	if i == nil or not starter_on_sale() or starter_all_owned(i) then
		return false
	end
	local s = i.starter
	if s ~= nil then
		local left = s.ends - now_s()
		if s.used or left <= 0 then
			return false
		end
		return { state = "active", left = left }
	end
	return if starter_eligible(i) then { state = "ready" } else false
end

--- The offer is on the player's screen: its clock starts, once (a no-op when it already ran or they
--- can't have it). Yields. True when the clock started now.
function Purchases.starter_seen(player: any): boolean
	if not starter_on_sale() then
		return false
	end
	local started = false
	local stored: Record? = nil
	local ok, err = pcall(function()
		update(player.UserId, function(old: any): any
			started = false
			local rec = clean(old, player.UserId)
			stored = rec
			if rec.starter ~= nil or not starter_eligible(rec) then
				return nil
			end
			local t = now_s()
			rec.starter = { started = t, ends = t + Starter.DURATION_S }
			started = true
			return rec
		end)
	end)
	if not ok or stored == nil then
		log("could not start the starter pack for " .. tostring(player.UserId) .. ": " .. tostring(err))
		return false
	end
	remember(player, stored :: Record)
	notify(player)
	return started
end

--- True when the player has Arsenal item `key` (as last read or written).
function Purchases.has_unlock(player: any, key: string): boolean
	local i = inv[player]
	return i ~= nil and i.unlocks[key] == true
end

--- The player's Arsenal as the Sim's bit mask (Defs.UNLOCK; Sim.set_unlocks).
function Purchases.unlock_mask(player: any): number
	local i = inv[player]
	return if i ~= nil then Arsenal.mask(i.unlocks) else 0
end

function Purchases.stars(player: any): number
	local i = inv[player]
	return if i ~= nil then i.stars else 0
end

--- What the player shows in a match: { skin = id?, flag = id?, pet = id? } (nil when nothing is equipped).
function Purchases.equipped(player: any): any
	local i = inv[player]
	if i == nil or (i.equipped.skin == nil and i.equipped.flag == nil and i.equipped.pet == nil) then
		return nil
	end
	return table.clone(i.equipped)
end

--- Roblox's ProcessReceipt: store the credit, then say granted (never before it is stored).
function Purchases.process_receipt(info: any): string
	local user_id = tonumber(info and info.PlayerId)
	local product = tonumber(info and info.ProductId)
	local receipt = if info and type(info.PurchaseId) == "string" then info.PurchaseId else nil
	local kind, n = nil, 1
	if product then
		kind, n = Purchases.kind_of(product)
	end
	if user_id == nil or kind == nil or receipt == nil then
		log("unknown receipt for product " .. tostring(product))
		return "not_processed"
	end
	return Purchases.grant(user_id, kind, receipt, n, tonumber(info.CurrencySpent))
end

--- Store `n` (default 1) `kind` credits for `user_id` under `receipt` (once per receipt). "granted" once
--- stored. `spent`: the Robux the receipt says were paid (Managed Pricing: not always the set price),
--- passed on to deps.bought.
function Purchases.grant(user_id: number, kind: string, receipt: string, n: number?, spent: number?): string
	local count = math.clamp(math.floor(n or 1), 1, 10)
	local stored: Record? = nil
	local refused = false
	local shop_got: string? = nil
	local ok, err = pcall(function()
		update(user_id, function(old: any): any
			refused = false
			local rec = clean(old, user_id)
			if table.find(rec.receipts, receipt) then
				stored = rec -- granted before (a retry): nothing to add
				return nil
			end
			local unlock_key = string.match(kind, "^unlock:(.+)$")
			local it = if unlock_key ~= nil then Arsenal.item(unlock_key) else nil
			local shop_rarity = string.match(kind, "^shopbuy:(.+)$")
			shop_got = nil
			if shop_rarity ~= nil then
				-- the mystery shop: the item the player chose before the prompt (shop_pick). Without one
				-- (the receipt came to another server, or the item was got meanwhile): an item of that
				-- rarity they lack, from today's window first; with none left, Stars for the price.
				local pick = picks[user_id] and picks[user_id][shop_rarity]
				local function fits(id: any): boolean
					local item = Cosmetics.item(id)
					return item ~= nil and item.rarity == shop_rarity and not item.exclusive and not rec.owned[id]
				end
				local id: string? = if fits(pick) then pick else nil
				if id == nil then
					for _, wid in Shop.window(Shop.day(now_s())) do
						if fits(wid) then
							id = wid
							break
						end
					end
				end
				if id == nil then
					for _, item in Cosmetics.all() do
						if fits(item.id) then
							id = item.id
							break
						end
					end
				end
				if id ~= nil then
					rec.owned[id] = true
					rec.equipped[(Cosmetics.item(id) :: any).kind] = id -- (chosen and paid for: worn at once)
					shop_got = id
				else
					local p = Products[Shop.product_key(shop_rarity)]
					local back = math.floor((if p ~= nil then p.robux else 0) * Purchases.DUPLICATE_STARS_PER_ROBUX)
					rec.stars = math.min(rec.stars + back, Purchases.MAX_STARS)
				end
			elseif kind == "pass" then
				-- the monthly pass (Data/Missions): on for the calendar month of this moment, and the
				-- monthly missions already done are paid now. A second one in the same month (two
				-- devices, a prompt left open) has nothing to add: Coroas for its price instead.
				local t = now_s()
				Missions.roll(rec.missions, t)
				if Missions.has_pass(rec.missions, t) then
					local p = Products[Missions.PRODUCT]
					local back = math.floor((if p ~= nil then p.robux else 0) * Purchases.DUPLICATE_STARS_PER_ROBUX)
					rec.stars = math.min(rec.stars + back, Purchases.MAX_STARS)
				else
					rec.missions.pass = Missions.month(t)
					settle_missions(rec, t)
				end
			elseif kind == "starter" then
				local t = now_s()
				if not starter_redeemable(rec, t) then
					refused = true
					return nil
				end
				for _, k in Starter.ITEMS do
					local item = Arsenal.item(k)
					if item ~= nil then
						local p = Products[item.product]
						unlock_on(rec, item, if p ~= nil then p.robux else 0)
					end
				end
				local s = rec.starter :: any
				s.used = true
				s.bought = t
			elseif it ~= nil then
				local p = Products[it.product]
				unlock_on(rec, it, if p ~= nil then p.robux else 0)
			else
				rec.credits[kind] = math.min((rec.credits[kind] or 0) + count, Purchases.MAX_CREDITS)
				if kind == "crate" then
					rec.crates_bought += count
				end
			end
			table.insert(rec.receipts, receipt)
			while #rec.receipts > Purchases.RECEIPTS_KEPT do
				table.remove(rec.receipts, 1)
			end
			rec.paid = true
			stored = rec
			return rec
		end)
	end)
	if ok and refused then
		log(string.format("refused starter pack %s for %d: no running offer", receipt, user_id))
		return "not_processed"
	end
	if not ok or stored == nil then
		log("could not store receipt " .. receipt .. ": " .. tostring(err))
		return "not_processed"
	end
	local player = player_by_id(user_id)
	if player ~= nil then
		remember(player, stored :: Record)
		notify(player)
		if deps.bought then
			pcall(deps.bought, player, kind, count, spent)
		end
		if string.sub(kind, 1, 8) == "shopbuy:" then
			if picks[user_id] ~= nil then
				picks[user_id][string.sub(kind, 9)] = nil
			end
			if deps.shop_bought then
				pcall(deps.shop_bought, player, shop_got)
			end
		end
		local unlocked = if kind == "starter" then "" else string.match(kind, "^unlock:(.+)$")
		if unlocked ~= nil and deps.unlocked then
			pcall(deps.unlocked, player, unlocked)
		end
	end
	log(string.format("granted %s%s to %d (%s)", kind, if count > 1 then " x" .. count else "", user_id, receipt))
	return "granted"
end

--- Yields: LOAD_ATTEMPTS reads with LOAD_BACKOFF between them, then, with the session already going
--- on an empty record, more every LOAD_RETRY_S (deps.wait; without one, a single attempt).
--- A player teleported here by a server of ours comes with the record that server held when they left
--- (deps.arrived: server/Handoff); then nothing is read.
function Purchases.load(player: any)
	local token = {}
	loading[player] = token
	if deps.arrived then
		local ok, got = pcall(deps.arrived, player)
		if loading[player] ~= token then
			return
		end
		if ok and type(got) == "table" and type(got.p) == "table" then
			remember(player, clean(got.p, player.UserId))
			notify(player)
			return
		end
	end
	local wait = deps.wait
	local tries = 0
	while true do
		tries += 1
		local ok, v = pcall(function()
			return deps.datastore:GetAsync(key(player.UserId))
		end)
		if loading[player] ~= token then
			return -- (they left, a write brought the record, or another load began)
		end
		if ok then
			remember(player, clean(v, player.UserId))
			notify(player)
			if tries > Purchases.LOAD_ATTEMPTS and deps.unlocked then
				-- (it came late: the match they are in learns what they have unlocked)
				pcall(deps.unlocked, player, "")
			end
			return
		end
		local last = not wait or tries >= Purchases.LOAD_ATTEMPTS + Purchases.LOAD_RETRIES
		if tries == Purchases.LOAD_ATTEMPTS or (last and tries < Purchases.LOAD_ATTEMPTS) then
			cache[player] = cache[player] or {}
			log(
				"load failed for "
					.. tostring(player.UserId)
					.. ": "
					.. tostring(v)
					.. (if last then "" else " (trying again while they stay)")
			)
			notify(player)
		end
		if last then
			loading[player] = nil
			return
		end
		wait(if tries < Purchases.LOAD_ATTEMPTS then Purchases.LOAD_BACKOFF[tries] or 10 else Purchases.LOAD_RETRY_S)
	end
end

function Purchases.credits(player: any): { [string]: number }
	return table.clone(cache[player] or {})
end

--- Spend one `kind` credit (atomic on the stored record). Yields.
function Purchases.use(player: any, kind: string): (boolean, string?)
	if Products[kind] == nil then
		return false, "unknown product"
	end
	local spent = false
	local left: { [string]: number }? = nil
	local ok, err = pcall(function()
		update(player.UserId, function(old: any): any
			spent = false
			local rec = clean(old, player.UserId)
			left = rec.credits
			remember(player, rec)
			if (rec.credits[kind] or 0) <= 0 then
				return nil
			end
			rec.credits[kind] -= 1
			spent = true
			left = rec.credits
			return rec
		end)
	end)
	if not ok then
		return false, "store unavailable: " .. tostring(err)
	end
	if left ~= nil then
		cache[player] = left
	end
	notify(player)
	if not spent then
		return false, "no credit"
	end
	return true, nil
end

function Purchases.release(player: any)
	loading[player] = nil
	cache[player] = nil
	inv[player] = nil
	records[player] = nil
	doubt[player.UserId] = nil
	picks[player.UserId] = nil
end

--- A player leaving for another server of ours (server/Handoff): waits, at most `max_s`, for this
--- server's writes to their record to land (a match's Stars are often still being paid), then returns
--- the record as it now stands; nil when it isn't known for sure (never read, still loading, a write
--- that failed or hasn't landed): the next server reads the store. Yields. Call before release.
function Purchases.settle(player: any, max_s: number): any
	local uid = player.UserId
	local waited = 0
	while busy[uid] ~= nil and deps.wait ~= nil and waited < max_s do
		waited += 0.1
		deps.wait(0.1)
	end
	if busy[uid] ~= nil or doubt[uid] or loading[player] ~= nil or inv[player] == nil then
		return nil
	end
	return records[player]
end

--- What a write error was, in a word (for the warning the error report counts).
local function reason(err: any): string
	local text = tostring(err)
	for _, word in { "TooManyRequests", "InternalServerError", "ServiceUnavailable", "Throttled", "queue was full" } do
		if string.find(text, word, 1, true) then
			return word
		end
	end
	return "other"
end

--- Stars that could not be paid after every retry (2026-11-03: the error report showed the store
--- refusing requests, not whether a payout was lost in the end). The server log has who and how many;
--- the warning is worded the same each time so the error report counts them by kind and reason.
local function stars_lost(user_id: number, amount: number, what: string, err: any)
	Purchases.lost.payouts += 1
	Purchases.lost.stars += amount
	log(string.format("could not pay %d %s Stars to %d: %s", amount, what, user_id, tostring(err)))
	if deps.warn then
		deps.warn(string.format("[Purchases] %s Stars lost after every retry (%s)", what, reason(err)))
	end
end

--- Open one crate of `kind` ("skin" / "flag" / "pet": the Coleção's tab; nil = any kind): spend a crate
--- credit and roll an item of that kind (Cosmetics.roll, the published odds), in one write. A new item
--- is added, and equipped when its slot is empty. A duplicate (Cosmetics.DUPLICATES; 2026-11-12) adds
--- nothing but its Stars (Cosmetics.duplicate_stars: paid as they are, no multiplier, not a match's).
--- Yields. (true, item_id, stars) with stars > 0 for a duplicate, else 0; or
--- (false, "no crate" | "everything owned" | "store unavailable: ...").
function Purchases.open_crate(player: any, kind: any): (boolean, string?, number?)
	if kind ~= nil and table.find(Cosmetics.KINDS, kind) == nil then
		return false, "bad kind"
	end
	local rng = deps.rng or Random.new()
	local got: string? = nil
	local back = 0
	local why = "no crate"
	local stored: Record? = nil
	local ok, err = pcall(function()
		update(player.UserId, function(old: any): any
			got = nil
			back = 0
			local rec = clean(old, player.UserId)
			stored = rec
			if (rec.credits.crate or 0) <= 0 then
				why = "no crate"
				return nil
			end
			local id, dup = Cosmetics.roll(rec.owned, rng:NextNumber(), rng:NextNumber(), kind)
			if id == nil then
				why = "everything owned"
				return nil
			end
			rec.credits.crate -= 1
			if dup then
				back = Cosmetics.duplicate_stars(id)
				rec.stars = math.min(rec.stars + back, Purchases.MAX_STARS)
			else
				rec.owned[id] = true
				local it = Cosmetics.item(id)
				if it ~= nil and rec.equipped[it.kind] == nil then
					rec.equipped[it.kind] = id
				end
			end
			got = id
			return rec
		end)
	end)
	if not ok then
		return false, "store unavailable: " .. tostring(err)
	end
	if stored ~= nil then
		remember(player, stored :: Record)
	end
	notify(player)
	if got == nil then
		return false, why
	end
	return true, got, back
end

--- Equip an owned item in its slot ("skin" / "flag"), or clear the slot (id false). Yields.
function Purchases.equip(player: any, slot: string, id: any): (boolean, string?)
	if table.find(Cosmetics.KINDS, slot) == nil then
		return false, "bad slot"
	end
	if id ~= false then
		local it = Cosmetics.item(id)
		if it == nil or it.kind ~= slot then
			return false, "unknown item"
		end
	end
	local done = false
	local stored: Record? = nil
	local ok, err = pcall(function()
		update(player.UserId, function(old: any): any
			done = false
			local rec = clean(old, player.UserId)
			stored = rec
			if id ~= false and not rec.owned[id] then
				return nil
			end
			rec.equipped[slot] = if id == false then nil else id
			done = true
			return rec
		end)
	end)
	if not ok then
		return false, "store unavailable: " .. tostring(err)
	end
	if stored ~= nil then
		remember(player, stored :: Record)
	end
	notify(player)
	return done, if done then nil else "not owned"
end

--- Pays `amount` Stars (a match's payout, Data/Stars). Yields. (ok, the new balance).
--- The Stars for finishing the tutorial (Data/Tutorial), once per player. True when they were paid now.
function Purchases.tutorial_bonus(player: any, amount: number): boolean
	local add = math.floor(tonumber(amount) or 0)
	if add ~= add or add <= 0 then
		return false
	end
	local stored: Record? = nil
	local paid = false
	local ok, err = pcall(function()
		update(player.UserId, function(old: any): any
			local rec = clean(old, player.UserId)
			stored = rec
			if rec.tutorial_paid then
				paid = false
				return nil
			end
			paid = true
			rec.tutorial_paid = true
			rec.stars = math.min(rec.stars + add, Purchases.MAX_STARS)
			rec.stars_earned = math.min(rec.stars_earned + add, Purchases.MAX_STARS)
			return rec
		end)
	end)
	if not ok or stored == nil then
		stars_lost(player.UserId, add, "tutorial", err)
		return false
	end
	remember(player, stored :: Record)
	if paid then
		notify(player)
	end
	return paid
end

-- ---------------------------------------------------------------------------------------------
-- The weekly ranking's prizes (shared/Data/RankPrizes; server/Ranking says who finished where)
-- ---------------------------------------------------------------------------------------------

--- Up to which closed week this player's results were written to their record: (true, week?) once
--- their record is here, (false) before that.
function Purchases.rank_week(player: any): (boolean, number?)
	local rec = records[player]
	if rec == nil then
		return false, nil
	end
	return true, rec.rank_week
end

--- The insignia the player wears now: 1, 2 or 3 (won in the week that closed last), or nil; and
--- where it was won: { wins = place?, kills = place? } (the first three places only).
function Purchases.rank_badge(player: any): (number?, any)
	local rec = records[player]
	local b = if rec ~= nil then rec.rank_badge else nil
	if type(b) ~= "table" or b.week ~= RankPrizes.week(now_s()) - 1 then
		return nil, nil
	end
	local place = RankPrizes.badge(b.place)
	if place == nil then
		return nil, nil
	end
	local wins, kills = RankPrizes.badge(b.wins), RankPrizes.badge(b.kills)
	return place, if wins ~= nil or kills ~= nil then { wins = wins, kills = kills } else nil
end

--- The last weekly prize the player claimed ({ week, wins = place?, kills = place?, stars }), or nil.
function Purchases.rank_last(player: any): any
	local rec = records[player]
	return if rec ~= nil and rec.rank_last ~= nil then table.clone(rec.rank_last) else nil
end

--- The prizes of `rec` that can be claimed in week `week` (RankPrizes.CLAIM_WEEKS), oldest first.
local function claimable(rec: any, week: number): { any }
	local out = {}
	for _, e in (rec.rank_pending or {}) do
		if RankPrizes.claimable(e.week, week) and e.stars > 0 then
			table.insert(out, e)
		end
	end
	return out
end

--- The Coroas the player won in the weekly ranking and did not claim yet: { total, weeks = { { week,
--- wins = place?, kills = place?, stars } } } (oldest first), or nil when there is nothing to claim.
function Purchases.rank_claimable(player: any): any
	local rec = records[player]
	if rec == nil then
		return nil
	end
	local list = claimable(rec, RankPrizes.week(now_s()))
	if #list == 0 then
		return nil
	end
	local total = 0
	local weeks = {}
	for i, e in list do
		total += e.stars
		weeks[i] = table.clone(e)
	end
	return { total = total, weeks = weeks }
end

--- Writes what the closed weeks left the player: `results` ({ { week, wins = place?, kills = place?,
--- stars } }, oldest first: Ranking.due) for the weeks up to `upto`. Nothing is paid here: the Coroas
--- wait in the record until the player claims them (rank_claim). A place among the first
--- RankPrizes.BADGE_PLACES of either list of week `upto` leaves the insignia, worn at once. Each week
--- is written once, whatever server asks. Yields.
--- -> the results written now ({} when they had been), or nil when the store failed (asked again
--- later).
function Purchases.rank_record(player: any, upto: number, results: { any }): { any }?
	local stored: Record? = nil
	local written: { any } = {}
	local ok, err = pcall(function()
		update(player.UserId, function(old: any): any
			local rec = clean(old, player.UserId)
			stored = rec
			written = {}
			local from = rec.rank_week
			if from ~= nil and from >= upto then
				return nil
			end
			-- (what can no longer be claimed leaves the record)
			local keep = claimable(rec, upto + 1)
			for _, r in results do
				local week = math.floor(tonumber(r.week) or -1)
				if week > upto or (from ~= nil and week <= from) then
					continue
				end
				local add = math.max(0, math.floor(tonumber(r.stars) or 0))
				local wins, kills = tonumber(r.wins), tonumber(r.kills)
				if add > 0 and RankPrizes.claimable(week, upto + 1) then
					table.insert(keep, { week = week, wins = wins, kills = kills, stars = add })
				end
				local best = RankPrizes.badge(RankPrizes.best(wins, kills))
				if best ~= nil and (rec.rank_badge == nil or rec.rank_badge.week <= week) then
					rec.rank_badge = { week = week, place = best, wins = RankPrizes.badge(wins), kills = RankPrizes.badge(kills) }
				end
				table.insert(written, r)
			end
			table.sort(keep, function(x: any, y: any): boolean
				return x.week < y.week
			end)
			rec.rank_pending = if #keep > 0 then keep else nil
			rec.rank_week = upto
			return rec
		end)
	end)
	if not ok or stored == nil then
		log("weekly results of " .. tostring(player.UserId) .. " not stored: " .. tostring(err))
		return nil
	end
	remember(player, stored :: Record)
	if #written > 0 then
		log(string.format("%d: weekly ranking, %d week(s) written", player.UserId, #written))
		notify(player)
	end
	return written
end

--- The player pressed CLAIM: pays every prize of theirs that can still be claimed, once (the record
--- forgets them as it pays). Yields.
--- -> (the prizes paid now, oldest first, and their Coroas), ({}, 0) when there was nothing to claim,
--- or nil when the store failed (nothing changed: they can press again).
function Purchases.rank_claim(player: any): ({ any }?, number)
	local stored: Record? = nil
	local paid: { any } = {}
	local total = 0
	local ok, err = pcall(function()
		update(player.UserId, function(old: any): any
			local rec = clean(old, player.UserId)
			stored = rec
			paid = claimable(rec, RankPrizes.week(now_s()))
			total = 0
			if #paid == 0 then
				if rec.rank_pending == nil then
					return nil
				end
				rec.rank_pending = nil -- (only prizes past their time were left)
				return rec
			end
			for _, e in paid do
				total += e.stars
			end
			rec.stars = math.min(rec.stars + total, Purchases.MAX_STARS)
			rec.stars_earned = math.min(rec.stars_earned + total, Purchases.MAX_STARS)
			rec.rank_last = table.clone(paid[#paid])
			rec.rank_pending = nil
			return rec
		end)
	end)
	if not ok or stored == nil then
		log("weekly prizes of " .. tostring(player.UserId) .. " not claimed: " .. tostring(err))
		return nil, 0
	end
	remember(player, stored :: Record)
	if #paid > 0 then
		log(string.format("%d: weekly ranking, %d week(s) claimed, +%d Stars", player.UserId, #paid, total))
	end
	notify(player)
	return paid, total
end

--- RoWorld General (Data/Subscription; 2026-10-27; server/General calls it while Roblox says the
--- player is subscribed): UTC day `day`'s crate credit, or, where crates aren't allowed (`crates`
--- false), Subscription.DAILY_STARS Stars, once a day; and the month's General skin `skin`, kept for
--- good (put on when no skin is worn). Returns what it gave now ({ crate?, stars?, skin? }; {} when
--- the day's were given already), or nil when the store failed (tried again later).
function Purchases.general_perks(player: any, day: number, skin: string?, crates: boolean): any
	local it = if skin ~= nil then Cosmetics.item(skin) else nil
	local stored: Record? = nil
	local given: any = {}
	local ok, err = pcall(function()
		update(player.UserId, function(old: any): any
			local rec = clean(old, player.UserId)
			stored = rec
			given = {}
			local changed = false
			if rec.general_day ~= day then
				rec.general_day = day
				if crates then
					rec.credits.crate = math.min((rec.credits.crate or 0) + 1, Purchases.MAX_CREDITS)
					given.crate = true
				else
					rec.stars = math.min(rec.stars + Subscription.DAILY_STARS, Purchases.MAX_STARS)
					rec.stars_earned = math.min(rec.stars_earned + Subscription.DAILY_STARS, Purchases.MAX_STARS)
					given.stars = Subscription.DAILY_STARS
				end
				changed = true
			end
			if it ~= nil and it.general and not rec.owned[it.id] then
				rec.owned[it.id] = true
				if rec.equipped[it.kind] == nil then
					rec.equipped[it.kind] = it.id
				end
				given.skin = it.id
				changed = true
			end
			return if changed then rec else nil
		end)
	end)
	if not ok or stored == nil then
		log("could not give " .. tostring(player.UserId) .. " their General's day: " .. tostring(err))
		return nil
	end
	remember(player, stored :: Record)
	if next(given) ~= nil then
		notify(player)
	end
	return given
end

--- `match` (optional): { result = the match's result (Data/Stars' Result), first = boolean }: it is
--- counted for the player's missions (Data/Missions) in the same write, and what those missions pay
--- is added too. Then the third value is the Coroas the missions paid, and an `amount` of 0 is fine.
--- `match.missions = false`: the result is not counted for the missions.
--- `match.ranked = true`: the match was a ranked one (Data/Ranked): the result moves the player's
--- points in the same write, and the fourth value is what Ranked.apply answers ({ lines, total,
--- delta, points, tier, before, month, closed? }; a season that closed there is paid there too).
function Purchases.add_stars(player: any, amount: number, match: any?): (boolean, number, number, any)
	local add = math.floor(tonumber(amount) or 0)
	if add ~= add or add < 0 then
		add = 0
	end
	local deltas: any = if type(match) == "table" and match.missions ~= false
		then Missions.deltas(match.result, match.first)
		else nil
	if deltas ~= nil and next(deltas) == nil then
		deltas = nil
	end
	local ranked = type(match) == "table"
		and match.ranked == true
		and type(match.result) == "table"
		and match.result.spawned == true
	-- a public match's result counts for the player's life (`stats`: wins, kingdoms destroyed)
	local life = type(match) == "table"
		and match.public == true
		and type(match.result) == "table"
		and match.result.spawned == true
		and ((tonumber(match.result.kills) or 0) > 0 or match.result.won == true)
	if add <= 0 and deltas == nil and not ranked and not life then
		return false, Purchases.stars(player), 0, nil
	end
	local stored: Record? = nil
	local bonus = 0
	local moved: any = nil
	local ok, err = pcall(function()
		update(player.UserId, function(old: any): any
			local rec = clean(old, player.UserId)
			rec.stars = math.min(rec.stars + add, Purchases.MAX_STARS)
			rec.stars_earned = math.min(rec.stars_earned + add, Purchases.MAX_STARS)
			bonus = 0
			moved = nil
			if deltas ~= nil then
				local t = now_s()
				Missions.add(rec.missions, t, deltas)
				bonus = settle_missions(rec, t).stars
			end
			if ranked then
				moved = Ranked.apply(rec.ranked, now_s(), match.result)
				close_season(rec, moved.closed)
			end
			if life then
				local r = match.result
				local kills = math.clamp(math.floor(tonumber(r.kills) or 0), 0, Stars.MAX_KILLS)
				rec.stats.kills = math.min(rec.stats.kills + kills, Purchases.MAX_STAT)
				if r.won == true and r.left ~= true then
					rec.stats.wins = math.min(rec.stats.wins + 1, Purchases.MAX_STAT)
				end
			end
			stored = rec
			return rec
		end)
	end)
	if not ok or stored == nil then
		if add > 0 then
			stars_lost(player.UserId, add, "match", err)
		end
		return false, Purchases.stars(player), 0, nil
	end
	remember(player, stored :: Record)
	notify(player)
	return true, (stored :: Record).stars, bonus, moved
end

--- The owner's hand on a balance (server/OwnerCommands: "/moedas dar", "/moedas tirar", "/moedas
--- ver"): `delta` Stars added to the record of `user_id` (negative: taken; 0: only read), whether or
--- not that player is on this server. The balance stays within 0..MAX_STARS, so taking more than there
--- is leaves 0. It is not earnings: stars_earned stays as it was. Yields.
--- (true, the balance after, the change that was made) or (false, why).
function Purchases.adjust_stars(user_id: any, delta: any): (boolean, any, number?)
	local uid = tonumber(user_id)
	local d = tonumber(delta)
	if uid == nil or uid ~= uid or uid <= 0 or uid % 1 ~= 0 or uid > 2 ^ 53 then
		return false, "bad player"
	end
	if d == nil or d ~= d or d % 1 ~= 0 or math.abs(d) > Purchases.MAX_STARS then
		return false, "bad amount"
	end
	local stored: Record? = nil
	local before = 0
	local ok, err = pcall(function()
		update(uid, function(old: any): any
			local rec = clean(old, uid)
			before = rec.stars
			rec.stars = math.clamp(rec.stars + d, 0, Purchases.MAX_STARS)
			stored = rec
			-- (nothing to change: nothing is written)
			return if rec.stars ~= before then rec else nil
		end)
	end)
	if not ok or stored == nil then
		return false, "store unavailable: " .. tostring(err)
	end
	local rec = stored :: Record
	local changed = rec.stars - before
	if changed ~= 0 then
		-- on this server: their balance follows at once (elsewhere: with their next write or visit)
		local player = player_by_id(uid)
		if player ~= nil then
			remember(player, rec)
			notify(player)
		end
		log(string.format("owner changed the Stars of %d by %d: %d", uid, changed, rec.stars))
	end
	return true, rec.stars, changed
end

--- A redeem code: one write pays its Stars and marks the code used by this player. Yields.
--- The code is one of the owner's list in the place (server/Codes, server/MyCodes), or one created
--- while the game runs (deps.code_store: server/CodeStore, "/codigo criar ..."); a name on the
--- place's list is that list's alone. A created code with a limit of uses has one of them taken
--- before the player is paid, and given back when the player is not paid after all.
--- (true, nil, stars paid, balance) or
--- (false, "invalid" | "expired" | "used" | "spent" | "store unavailable: ...").
function Purchases.redeem_code(player: any, text: any): (boolean, string?, number?, number?)
	local now = now_s()
	local entry, bad = Codes.find(text, now, deps.codes)
	local shared: any = nil
	if entry == nil and type(deps.code_store) == "table" and not Codes.listed(text, deps.codes) then
		entry, bad = deps.code_store.find(text, now)
		if entry == nil and bad == "store" then
			return false, "store unavailable: codes"
		end
		shared = if entry ~= nil and entry.uses ~= nil then deps.code_store else nil
	end
	if entry == nil then
		return false, bad or "invalid"
	end
	if shared ~= nil then
		-- (someone who has used it must not take a use from someone who has not)
		local held = records[player]
		if held ~= nil and held.codes[entry.code] then
			return false, "used"
		end
		local got, why_not = shared.reserve(entry.code, now)
		if not got then
			return false, if why_not == "store" then "store unavailable: codes" else (why_not or "invalid")
		end
	end
	local why = "store unavailable"
	local done = false
	local stored: Record? = nil
	local ok, err = pcall(function()
		update(player.UserId, function(old: any): any
			done = false
			local rec = clean(old, player.UserId)
			stored = rec
			if rec.codes[entry.code] then
				why = "used"
				return nil
			end
			rec.codes[entry.code] = true
			rec.stars = math.clamp(rec.stars + entry.stars, 0, Purchases.MAX_STARS)
			done = true
			return rec
		end)
	end)
	if shared ~= nil and not (ok and done) then
		shared.release(entry.code)
	end
	if not ok then
		return false, "store unavailable: " .. tostring(err)
	end
	if stored ~= nil then
		remember(player, stored :: Record)
	end
	notify(player)
	if not done then
		return false, why
	end
	log(string.format("%d redeemed the code %s for %d Stars", player.UserId, entry.code, entry.stars))
	return true, nil, entry.stars, (stored :: Record).stars
end

--- Buy `n` crates with Stars (CRATE_STARS each): one write takes the price and adds the crate credits.
--- For every player (2026-11-10: Coroas pay a crate for everyone; Robux are the other way, only where
--- Roblox allows paid random items). Yields. (ok) or (false, "bad count" | "not enough" | "store unavailable: ...").
function Purchases.buy_crates(player: any, n: any): (boolean, string?)
	if type(n) ~= "number" or n ~= n or n < 1 or n > Purchases.CRATE_MAX or n % 1 ~= 0 then
		return false, "bad count"
	end
	local price = n * Purchases.CRATE_STARS
	local why = "store unavailable"
	local done = false
	local stored: Record? = nil
	local ok, err = pcall(function()
		update(player.UserId, function(old: any): any
			done = false
			local rec = clean(old, player.UserId)
			stored = rec
			if rec.stars < price then
				why = "not enough"
				return nil
			end
			rec.stars -= price
			rec.credits.crate = math.min((rec.credits.crate or 0) + n, Purchases.MAX_CREDITS)
			rec.crates_bought += n
			done = true
			return rec
		end)
	end)
	if not ok then
		return false, "store unavailable: " .. tostring(err)
	end
	if stored ~= nil then
		remember(player, stored :: Record)
	end
	notify(player)
	if not done then
		return false, why
	end
	log(string.format("%d bought %d crate(s) for %d Stars", player.UserId, n, price))
	return true, nil
end

--- The mystery shop's offer of `item_id` for this player now: today's, or yesterday's (a shop left open
--- over midnight), of `currency`.
local function shop_offer(player: any, item_id: any, currency: string): any
	local day = Shop.day(now_s())
	for _, d in { day, day - 1 } do
		local o = Shop.offer(d, player.UserId, item_id)
		if o ~= nil and o.currency == currency then
			return o
		end
	end
	return nil
end

--- The player is about to be asked for Robux for mystery shop item `item_id`: remember which item the
--- receipt of that rarity's product is for. (ok) or (false, "not on sale" | "owned" | "no product").
function Purchases.shop_pick(player: any, item_id: any): (boolean, string?)
	local o = shop_offer(player, item_id, "robux")
	if o == nil then
		return false, "not on sale"
	end
	local i = inv[player]
	if i ~= nil and i.owned[item_id] then
		return false, "owned"
	end
	local p = Products[o.product]
	if p == nil or p.id == 0 then
		return false, "no product"
	end
	picks[player.UserId] = picks[player.UserId] or {}
	picks[player.UserId][o.rarity] = item_id
	return true, nil
end

--- Buy mystery shop item `item_id` with Stars: only an offer that came for Stars for this player
--- (Data/Shop.offers). One write takes the price, adds the item and puts it on. Yields.
--- (ok) or (false, "not on sale" | "owned" | "not enough" | "store unavailable: ...").
function Purchases.shop_buy(player: any, item_id: any): (boolean, string?)
	local o = shop_offer(player, item_id, "stars")
	local it = Cosmetics.item(item_id)
	if o == nil or it == nil then
		return false, "not on sale"
	end
	local why = "store unavailable"
	local done = false
	local stored: Record? = nil
	local ok, err = pcall(function()
		update(player.UserId, function(old: any): any
			done = false
			local rec = clean(old, player.UserId)
			stored = rec
			if rec.owned[item_id] then
				why = "owned"
				return nil
			end
			if rec.stars < o.price then
				why = "not enough"
				return nil
			end
			rec.stars -= o.price
			rec.owned[item_id] = true
			rec.equipped[it.kind] = item_id
			done = true
			return rec
		end)
	end)
	if not ok then
		return false, "store unavailable: " .. tostring(err)
	end
	if stored ~= nil then
		remember(player, stored :: Record)
	end
	notify(player)
	if not done then
		return false, why
	end
	log(string.format("%d bought %s in the shop for %d Stars", player.UserId, item_id, o.price))
	return true, nil
end

--- Unlock Arsenal item `key` with Stars: one write takes its price and unlocks it. Yields.
--- (ok) or (false, "unknown item" | "robux only" | "owned" | "not enough" | "store unavailable: ...").
function Purchases.buy_unlock(player: any, item_key: any): (boolean, string?)
	local it = Arsenal.item(item_key)
	if it == nil then
		return false, "unknown item"
	end
	if it.stars == nil then
		return false, "robux only"
	end
	local why = "store unavailable"
	local done = false
	local stored: Record? = nil
	local ok, err = pcall(function()
		update(player.UserId, function(old: any): any
			done = false
			local rec = clean(old, player.UserId)
			stored = rec
			if rec.unlocks[it.key] then
				why = "owned"
				return nil
			end
			if rec.stars < it.stars then
				why = "not enough"
				return nil
			end
			rec.stars -= it.stars
			unlock_on(rec, it, 0)
			done = true
			return rec
		end)
	end)
	if not ok then
		return false, "store unavailable: " .. tostring(err)
	end
	if stored ~= nil then
		remember(player, stored :: Record)
	end
	notify(player)
	if not done then
		return false, why
	end
	if deps.unlocked then
		pcall(deps.unlocked, player, it.key)
	end
	log(string.format("%d unlocked %s for %d Stars", player.UserId, it.key, it.stars))
	return true, nil
end

return Purchases
