--!nocheck
-- The Coleção's sales (server/Purchases, Data/MyShop): a crate for each tab (skins, flags, pets), bought
-- with Robux (9 each, any amount) or, by a player Roblox does not let buy paid random items, with
-- Coroas; the mystery shop's purchases (Robux: the item chosen before the prompt; Coroas: only an
-- offer that came for Coroas for that player); the pet slot.   lune run tests/colecao.luau
require("./prelude")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local MyShop = require("../src/shared/Data/MyShop")
local Products = require("../src/shared/Data/Products")
local Shop = require("../src/shared/Data/Shop")
local Purchases = require("../src/server/Purchases")

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

local rows = {}
local down = false
local store = {}
function store:UpdateAsync(k, fn)
	if down then
		error("DataStore request was throttled")
	end
	local new = fn(rows[k])
	if new ~= nil then
		rows[k] = new
	end
	return new
end
function store:GetAsync(k)
	if down then
		error("DataStore unavailable")
	end
	return rows[k]
end

local players = {}
local shop_told = {}
local forced: { number } = {}
local inv_told = {}
local DAY = 20600
local now = DAY * 86400 + 3600
math.randomseed(11)
Purchases.configure({
	datastore = store,
	players = {
		GetPlayerByUserId = function(_, id)
			return players[id]
		end,
	},
	now = function()
		return now
	end,
	rng = {
		-- (a test may line up the next rolls: `forced`, used first)
		NextNumber = function(_)
			if #forced > 0 then
				return table.remove(forced, 1)
			end
			return math.random()
		end,
	},
	shop_bought = function(p, item_id)
		table.insert(shop_told, { p, item_id })
	end,
	inventory = function(p, i)
		inv_told[p] = i
	end,
})
local function player(id: number, name: string)
	local p = { UserId = id, Name = name }
	players[id] = p
	Purchases.load(p)
	return p
end

expect(Purchases.FREE_COSMETICS == false, "the Coleção is not free")
-- (25.000 since 2026-11-11, was 10.000: a win pays 4.000 and some, 8.000 and some with 2x Coroas)
expect(Purchases.CRATE_STARS == MyShop.caixa.coroas and Purchases.CRATE_STARS == 25000, "a crate for Coroas: 25.000")
expect(Purchases.CRATE_MAX == 1 and MyShop.caixa.maximo_por_vez == nil, "one crate a purchase")

-- crates by kind
do
	local A = player(1001, "Ana")
	expect(#Purchases.inventory(A).owned == 0, "a new player's collection is empty")
	Products.crate.id = 9001
	-- 4 crates = 4 receipts of the 9 Robux product
	for i = 1, 4 do
		Purchases.process_receipt({ PlayerId = 1001, ProductId = 9001, PurchaseId = "a" .. i })
	end
	expect(rows.u1001.credits.crate == 4 and rows.u1001.crates_bought == 4, "4 receipts of 9 Robux: 4 crates")
	local ok1, pet = Purchases.open_crate(A, "pet")
	local ok2, flag = Purchases.open_crate(A, "flag")
	local ok3, skin = Purchases.open_crate(A, "skin")
	expect(ok1 and Cosmetics.item(pet).kind == "pet", "the pets' crate gives a pet (" .. tostring(pet) .. ")")
	expect(ok2 and Cosmetics.item(flag).kind == "flag", "the flags' crate gives a flag (" .. tostring(flag) .. ")")
	expect(ok3 and Cosmetics.item(skin).kind == "skin", "the skins' crate gives a skin (" .. tostring(skin) .. ")")
	local eq = Purchases.equipped(A)
	expect(eq.pet == pet and eq.flag == flag and eq.skin == skin, "each is put on (its slot was empty): a match shows all three")
	local bad, why = Purchases.open_crate(A, "hat")
	expect(not bad and why == "bad kind" and rows.u1001.credits.crate == 1, "an unknown kind opens nothing")
	-- every pet owned: the pets' crate keeps the credit, the others still open
	for _, it in Cosmetics.of_kind("pet") do
		rows.u1001.owned[it.id] = true
	end
	local okp, whyp = Purchases.open_crate(A, "pet")
	expect(not okp and whyp == "everything owned" and rows.u1001.credits.crate == 1, "every pet owned: the crate is kept")
	local oks, skin2 = Purchases.open_crate(A, "skin")
	-- (the same skin again would be a duplicate: tested further down)
	expect(oks and Cosmetics.item(skin2).kind == "skin", "... and opens as a skins' crate instead")
	-- the pet slot
	expect(Purchases.equip(A, "pet", false) and rows.u1001.equipped.pet == nil, "the pet can be taken off")
	expect(Purchases.equip(A, "pet", "pet_gato") and rows.u1001.equipped.pet == "pet_gato", "... and an owned pet put on")
	expect(not Purchases.equip(A, "pet", flag), "a flag does not go in the pet slot")
	expect(not Purchases.equip(A, "hat", "pet_gato"), "there is no fourth slot")
	Purchases.release(A)
	Purchases.load(A)
	expect(Purchases.equipped(A).pet == "pet_gato", "the pet is still on after they come back")
	-- no packs (2026-11-10): one crate a purchase, with Robux too
	expect(Products.crate3 == nil and Products.crate5 == nil and Products.crate10 == nil, "no pack of crates is sold")
end

-- crates for Coroas (every player may; the only way for one who may not buy paid random items)
do
	local B = player(1002, "Bia")
	rows.u1002 = { cosm = 2, stars = 54000 }
	Purchases.release(B)
	Purchases.load(B)
	-- one crate a purchase (2026-11-10): asking for more buys nothing
	for _, n in { 2, 3, 10 } do
		local okm, whym = Purchases.buy_crates(B, n)
		expect(not okm and whym == "bad count" and rows.u1002.stars == 54000 and (rows.u1002.credits or {}).crate == nil, n .. " crates at once: refused, nothing taken")
	end
	expect(Purchases.buy_crates(B, 1), "a crate for 25.000 Coroas")
	expect(rows.u1002.stars == 29000 and rows.u1002.credits.crate == 1 and rows.u1002.crates_bought == 1, "... paid and counted")
	expect(Purchases.buy_crates(B, 1), "and another, in another purchase")
	expect(rows.u1002.stars == 4000 and rows.u1002.credits.crate == 2 and rows.u1002.crates_bought == 2, "... paid and counted too")
	expect(rows.u1002.paid == nil or rows.u1002.paid == 0 or rows.u1002.paid == false, "... and it is not a Robux purchase")
	local ok, why = Purchases.buy_crates(B, 1)
	expect(not ok and why == "not enough" and rows.u1002.stars == 4000, "a crate costs 25.000: 4.000 Coroas are not enough")
	for _, n in { 0, -1, 1.5, 11, 0 / 0, "2", "1" } do
		local okn, whyn = Purchases.buy_crates(B, n)
		expect(not okn and whyn == "bad count", "a bad amount (" .. tostring(n) .. ") buys nothing")
	end
	expect(rows.u1002.stars == 4000, "nothing else was taken")
	down = true
	rows.u1002.stars = 99999
	local okd, whyd = Purchases.buy_crates(B, 1)
	down = false
	expect(not okd and string.find(whyd, "store", 1, true) ~= nil and rows.u1002.credits.crate == 2, "store down: nothing bought")
	local oko, got = Purchases.open_crate(B, "flag")
	expect(oko and Cosmetics.item(got).kind == "flag", "a crate bought with Coroas opens like any other")
end

-- a duplicate pays Coroas (Data/MyShop.caixa.repetidos; 2026-11-12)
do
	expect(Cosmetics.DUPLICATES == true, "as shipped, a crate may give an item the player has")
	local D = player(1010, "Duda")
	local skins = Cosmetics.of_kind("skin")
	local by = {}
	for _, it in skins do
		by[it.rarity] = by[it.rarity] or {}
		table.insert(by[it.rarity], it)
	end
	-- Duda has the first Common and the first Legendary skin, wears the Common, and has 7 crates
	local c1, c2, l1 = by.common[1], by.common[2], by.legendary[1]
	rows.u1010 = { cosm = 2, stars = 1000, owned = { [c1.id] = true, [l1.id] = true }, equipped = { skin = c1.id }, credits = { crate = 7 } }
	Purchases.release(D)
	Purchases.load(D)
	local earned0 = rows.u1010.stars_earned or 0
	local function owned_n(): number
		local n = 0
		for _ in rows.u1010.owned do
			n += 1
		end
		return n
	end
	-- the first Common again (r1 in the Commons' share, r2 = 0: the first of them)
	forced = { 0.10, 0.0 }
	local ok, id, back = Purchases.open_crate(D, "skin")
	expect(ok and id == c1.id and back == 2500, "a Common the player has: told it is that item, and 2,500 Coroas")
	expect(rows.u1010.stars == 3500 and owned_n() == 2 and rows.u1010.credits.crate == 6, "... the Coroas are paid, nothing is added, the crate is spent")
	expect(rows.u1010.equipped.skin == c1.id, "... and what they wear is left alone")
	expect((rows.u1010.stars_earned or 0) == earned0, "... it does not count as Coroas earned by playing (the ranking)")
	expect(inv_told[D] ~= nil and inv_told[D].stars == 3500, "... the client is told the new balance")
	-- the second Common: new
	forced = { 0.10, 1.5 / #by.common }
	ok, id, back = Purchases.open_crate(D, "skin")
	expect(ok and id == c2.id and back == 0, "a Common the player doesn't have: the item, no Coroas")
	expect(rows.u1010.stars == 3500 and rows.u1010.owned[c2.id] == true and owned_n() == 3 and rows.u1010.credits.crate == 5, "... it is added, the balance stays")
	-- the Legendary again
	forced = { 0.9999, 0.0 }
	ok, id, back = Purchases.open_crate(D, "skin")
	expect(ok and id == l1.id and back == 25000, "a Legendary the player has: 25,000 Coroas")
	expect(rows.u1010.stars == 28500 and owned_n() == 3 and rows.u1010.credits.crate == 4, "... paid, nothing added")
	-- one of each of the other two rarities
	for _, case in { { "rare", 0.85, 6000 }, { "epic", 0.97, 12000 } } do
		local it = by[case[1]][1]
		rows.u1010.owned[it.id] = true
		Purchases.release(D)
		Purchases.load(D)
		local before = rows.u1010.stars
		forced = { case[2], 0.0 }
		ok, id, back = Purchases.open_crate(D, "skin")
		expect(ok and id == it.id and back == case[3] and rows.u1010.stars == before + case[3], string.format("a %s the player has: %d Coroas", case[1], case[3]))
	end
	expect(rows.u1010.credits.crate == 2, "five crates opened, two left")
	-- the store is down: nothing is spent and nothing is paid
	local before = rows.u1010.stars
	down = true
	forced = { 0.10, 0.0 }
	local okd, whyd = Purchases.open_crate(D, "skin")
	down = false
	forced = {}
	expect(not okd and string.find(whyd, "store", 1, true) ~= nil and rows.u1010.stars == before and rows.u1010.credits.crate == 2, "store down: no crate spent, no Coroas paid")
	-- the balance never passes its ceiling
	rows.u1010.stars = Purchases.MAX_STARS - 10
	Purchases.release(D)
	Purchases.load(D)
	forced = { 0.10, 0.0 }
	ok, id, back = Purchases.open_crate(D, "skin")
	expect(ok and back == 2500 and rows.u1010.stars == Purchases.MAX_STARS, "a full purse stays at its ceiling")
	-- every skin owned: the crate is kept, nothing is paid (the skins' crate is no longer sold)
	for _, it in skins do
		rows.u1010.owned[it.id] = true
	end
	rows.u1010.stars = 500
	Purchases.release(D)
	Purchases.load(D)
	local oka, whya = Purchases.open_crate(D, "skin")
	expect(not oka and whya == "everything owned" and rows.u1010.credits.crate == 1 and rows.u1010.stars == 500, "every skin owned: the crate is kept, no Coroas")

	-- A whole collection, crate by crate, paid with Coroas only: what comes back from duplicates
	-- never pays for the crates (the average duplicate is far below a crate's price)
	local E = player(1011, "Edu")
	rows.u1011 = { cosm = 2, stars = 0, owned = {}, credits = { crate = 0 } }
	Purchases.release(E)
	Purchases.load(E)
	local total_crates, total_back, total_new = 0, 0, 0
	local wrong = 0
	for _, kind in Cosmetics.KINDS do
		local n_kind = #Cosmetics.of_kind(kind)
		local guard = 0
		while guard < 200000 do
			guard += 1
			rows.u1011.credits = rows.u1011.credits or {}
			rows.u1011.credits.crate = 1
			local had = {}
			for k in rows.u1011.owned or {} do
				had[k] = true
			end
			local stars0 = rows.u1011.stars or 0
			local okc, got, paid = Purchases.open_crate(E, kind)
			if not okc then
				if got ~= "everything owned" then
					wrong += 1
				end
				break
			end
			total_crates += 1
			total_back += paid
			local it = Cosmetics.item(got)
			if it == nil or it.kind ~= kind or it.season ~= nil then
				wrong += 1
			elseif had[got] then
				-- a duplicate: its rarity's Coroas, exactly, and nothing added
				if paid ~= Cosmetics.DUPLICATE_STARS[it.rarity] or rows.u1011.stars ~= stars0 + paid then
					wrong += 1
				end
			else
				total_new += 1
				if paid ~= 0 or rows.u1011.stars ~= stars0 or rows.u1011.owned[got] ~= true then
					wrong += 1
				end
			end
		end
		local have = 0
		for k in rows.u1011.owned do
			if Cosmetics.item(k).kind == kind then
				have += 1
			end
		end
		expect(have == n_kind, string.format("a whole collection of %ss by crates: all %d got", kind, n_kind))
	end
	expect(wrong == 0, "... every crate gave an item of its tab; new ones paid nothing, duplicates paid their rarity's Coroas")
	expect(total_new == #Cosmetics.all(), string.format("... %d crates for the %d items (never repeating it would take %d)", total_crates, total_new, total_new))
	local share = total_back / (total_crates * Purchases.CRATE_STARS)
	expect(share < 0.25, string.format("... duplicates paid back %.0f%% of the crates' price in Coroas: crates never pay for themselves", share * 100))
	print(string.format("       %d crates, %d Coroas back from duplicates (%.0f per crate)", total_crates, total_back, total_back / total_crates))
end

-- the mystery shop
do
	local C = player(1003, "Caio")
	local offers = Shop.offers(DAY, 1003)
	local robux = nil
	for _, o in offers do
		if o.currency == "robux" then
			robux = o
			break
		end
	end
	expect(robux ~= nil, "today's shop has a Robux offer")
	-- its rarity's product is made (Data/MyProducts) ...
	local shipped = Products[robux.product].id
	expect(type(shipped) == "number" and shipped > 0, "the offer's product has the owner's id (" .. tostring(robux.product) .. ")")
	-- ... and without it there is nothing to prompt
	Products[robux.product].id = 0
	local okn, whyn = Purchases.shop_pick(C, robux.id)
	expect(not okn and whyn == "no product", "no product created for that rarity: no prompt")
	for i, r in Cosmetics.RARITIES do
		Products["shop_" .. r.id].id = 9100 + i
	end
	local pid = Products[robux.product].id
	expect(not Purchases.shop_pick(C, "pet_nope") and not Purchases.shop_pick(C, 5), "an item not on sale is not picked")
	local outside = nil
	for _, it in Cosmetics.all() do
		if Shop.offer(DAY, 1003, it.id) == nil and Shop.offer(DAY - 1, 1003, it.id) == nil and it.rarity == robux.rarity then
			outside = it.id
			break
		end
	end
	local oko, whyo = Purchases.shop_pick(C, outside)
	expect(outside ~= nil and not oko and whyo == "not on sale", "nor an item that is not in today's window")
	expect(Purchases.shop_pick(C, robux.id), "the item on sale is picked")
	expect(Purchases.process_receipt({ PlayerId = 1003, ProductId = pid, PurchaseId = "s1" }) == "granted", "the receipt")
	expect(rows.u1003.owned[robux.id] == true, "... gives exactly that item (" .. robux.id .. ")")
	expect(rows.u1003.equipped[Cosmetics.item(robux.id).kind] == robux.id, "... and puts it on")
	expect(#shop_told == 1 and shop_told[1][1] == C and shop_told[1][2] == robux.id, "the player is told what they got")
	expect(Purchases.process_receipt({ PlayerId = 1003, ProductId = pid, PurchaseId = "s1" }) == "granted", "the same receipt again")
	local n_owned = 0
	for _ in rows.u1003.owned do
		n_owned += 1
	end
	expect(n_owned == 1, "... gives nothing more")
	local okw, whyw = Purchases.shop_pick(C, robux.id)
	expect(not okw and whyw == "owned", "an item already owned is not sold again")
	-- a receipt with no pick (it came to another server): an item of that rarity all the same
	expect(Purchases.process_receipt({ PlayerId = 1003, ProductId = pid, PurchaseId = "s2" }) == "granted", "a receipt with no item chosen")
	local extra = nil
	for id in rows.u1003.owned do
		if id ~= robux.id then
			extra = id
		end
	end
	expect(extra ~= nil and Cosmetics.item(extra).rarity == robux.rarity, "... still gives an item of that rarity (" .. tostring(extra) .. ")")
	-- every item of that rarity owned: Coroas back instead
	for _, it in Cosmetics.all() do
		if it.rarity == robux.rarity then
			rows.u1003.owned[it.id] = true
		end
	end
	local before = rows.u1003.stars or 0
	expect(Purchases.process_receipt({ PlayerId = 1003, ProductId = pid, PurchaseId = "s3" }) == "granted", "nothing of that rarity left")
	expect((rows.u1003.stars or 0) > before, "... the Robux come back as Coroas")

	-- Coroas: only an offer that came for Coroas for that player
	local okr, whyr = Purchases.shop_buy(C, robux.id)
	expect(not okr and whyr == "not on sale", "a Robux offer can't be bought with Coroas")
	local lucky, offer = nil, nil
	for uid = 2000, 400000 do
		for _, o in Shop.offers(DAY, uid) do
			if o.currency == "stars" then
				lucky, offer = uid, o
			end
		end
		if lucky ~= nil then
			break
		end
	end
	expect(lucky ~= nil and offer.rarity == "common", "(a player whose shop has a Common for Coroas today: " .. tostring(lucky) .. ")")
	if lucky ~= nil then
		local L = player(lucky, "Sortudo")
		rows["u" .. lucky] = { cosm = 2, stars = offer.price - 1 }
		Purchases.release(L)
		Purchases.load(L)
		local ok1, why1 = Purchases.shop_buy(L, offer.id)
		expect(not ok1 and why1 == "not enough", "one Coroa short: no sale")
		expect(not Purchases.shop_pick(L, offer.id), "it is not a Robux offer")
		rows["u" .. lucky].stars = offer.price + 50
		Purchases.release(L)
		Purchases.load(L)
		expect(Purchases.shop_buy(L, offer.id), "bought with Coroas")
		local rec = rows["u" .. lucky]
		expect(rec.stars == 50 and rec.owned[offer.id] == true, "... paid, owned")
		expect(rec.equipped[Cosmetics.item(offer.id).kind] == offer.id, "... and put on")
		local ok2, why2 = Purchases.shop_buy(L, offer.id)
		expect(not ok2 and why2 == "owned" and rec.stars == 50, "not twice")
		-- the same item is not for Coroas for someone else
		local okc, whyc = Purchases.shop_buy(C, offer.id)
		expect(not okc and whyc == "not on sale", "another player can't buy that offer")
		-- nor tomorrow's tomorrow
		now += 2 * 86400
		rec.owned[offer.id] = nil
		local ok3, why3 = Purchases.shop_buy(L, offer.id)
		expect(not ok3 and why3 == "not on sale", "two days later the offer is gone")
		now -= 2 * 86400
	end
end

print(string.format("colecao: %d checks, %d failed", checks, fails))
if fails > 0 then
	error("colecao tests failed")
end
