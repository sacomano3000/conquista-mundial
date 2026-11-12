--!nocheck
-- What is free in this game (server/Purchases.FREE_FOR_ALL, Data/Products): the takeover is always there
-- and the only products on sale are the owner's own (Data/MyProducts: the Arsenal, the crate, the
-- mystery shop; 2026-11-11). Two things are not free: the Arsenal
-- (Purchases.EARN_ARSENAL: its items start locked and are earned) and the Coleção's cosmetics
-- (Purchases.FREE_COSMETICS = false: a brand-new player owns none; they come from crates and from the
-- mystery shop). With those switches turned the other way everything is free, as in the fork this
-- comes from.
require("./prelude")
local Products = require("../src/shared/Data/Products")
local Purchases = require("../src/server/Purchases")
local Arsenal = require("../src/shared/Data/Arsenal")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Subscription = require("../src/shared/Data/Subscription")

local fails = 0
local function expect(c: any, w: string)
	if c then
		print("  ok   " .. w)
	else
		fails += 1
		print("FAIL " .. w)
	end
end

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
Purchases.configure({ datastore = store })

expect(Purchases.FREE_FOR_ALL == true, "everything is free")
-- (what is on sale is what the owner made a product for: Data/MyProducts; the takeover and the starter
-- pack, RoWorld's other two products, are not sold)
local Mine = require("../src/shared/Data/MyProducts")
local others = false
for key, p in Products do
	others = others or (p.id ~= 0 and Mine[key] == nil)
end
expect(not others, "no Robux product exists but the owner's own")
expect(Products.takeover.id == 0 and Products.starter_pack.id == 0, "the takeover and the starter pack are not sold")
expect(Subscription.id() == "", "no subscription is offered")

local P = { UserId = 123456, Name = "Newcomer" }
Purchases.load(P)
local inv = Purchases.inventory(P)
local owned = {}
for _, id in inv.owned do
	owned[id] = true
end

expect(Purchases.EARN_ARSENAL == true, "... except the Arsenal, which is earned")
local none_unlocked = true
for _, it in Arsenal.ITEMS do
	none_unlocked = none_unlocked and not Purchases.has_unlock(P, it.key)
end
expect(none_unlocked, "no Arsenal item is unlocked for a new player")
expect(Purchases.unlock_mask(P) == 0, "the match sees none of them")
expect(inv.starter == false, "no starter pack is offered")
local all = {}
for _, it in Arsenal.ITEMS do
	all[it.key] = true
end
do
	-- with the switch off: the fork's behaviour, every item unlocked
	local Q = { UserId = 654321, Name = "FreeArsenal" }
	Purchases.EARN_ARSENAL = false
	Purchases.load(Q)
	local all_unlocked = true
	for _, it in Arsenal.ITEMS do
		all_unlocked = all_unlocked and Purchases.has_unlock(Q, it.key)
	end
	expect(all_unlocked, "EARN_ARSENAL off: every Arsenal item is unlocked")
	expect(Purchases.unlock_mask(Q) == Arsenal.mask(all), "... and the match sees all of them")
	Purchases.EARN_ARSENAL = true
	Purchases.release(Q)
end

local function owns_all(list: any): boolean
	for _, it in list do
		if not owned[it.id] then
			return false
		end
	end
	return true
end
expect(Purchases.FREE_COSMETICS == false, "... and the Coleção, which is sold")
expect(#Cosmetics.all() > 0 and #inv.owned == #Cosmetics.granted(P.UserId), "a new player owns no cosmetic")
expect(inv.equipped.skin == nil and inv.equipped.flag == nil and inv.equipped.pet == nil, "... and wears none")
expect(not Purchases.equip(P, "skin", Cosmetics.all()[1].id), "a skin not owned can't be put on")
do
	-- with the switch on: the fork's behaviour, every cosmetic owned
	local Q = { UserId = 654322, Name = "FreeCosmetics" }
	Purchases.FREE_COSMETICS = true
	Purchases.load(Q)
	owned = {}
	for _, id in Purchases.inventory(Q).owned do
		owned[id] = true
	end
	expect(owns_all(Cosmetics.all()), "FREE_COSMETICS on: every crate item is owned")
	expect(owns_all(Cosmetics.generals()), "... and every General skin")
	expect(Purchases.equip(Q, "skin", Cosmetics.all()[1].id), "... and any skin can be put on")
	Purchases.FREE_COSMETICS = false
	Purchases.release(Q)
	-- what that free time wrote is not kept: the same player's collection starts empty once cosmetics
	-- are sold (their Coroas and their Arsenal stay)
	rows.u654322.stars = 777
	rows.u654322.unlocks = { [Arsenal.ITEMS[1].key] = true }
	expect(rows.u654322.cosm == 2, "(a record written now is marked)")
	rows.u654322.cosm = nil -- (as a record from before this version)
	Purchases.load(Q)
	local qi = Purchases.inventory(Q)
	expect(#qi.owned == 0 and qi.equipped.skin == nil, "a record from the free time: its collection starts empty")
	expect(qi.stars == 777 and Purchases.has_unlock(Q, Arsenal.ITEMS[1].key), "... its Coroas and its Arsenal stay")
	Purchases.release(Q)
	owned = {}
	for _, id in inv.owned do
		owned[id] = true
	end
end

local someone_elses = false
for _, it in Cosmetics.exclusives() do
	if owned[it.id] and not Cosmetics.may_own(it.id, P.UserId) then
		someone_elses = true
	end
end
expect(not someone_elses, "someone else's exclusive is not theirs")

expect((Purchases.credits(P).takeover or 0) >= 1, "a takeover is ready")
local ok = Purchases.use(P, "takeover")
expect(ok, "... and spent")
Purchases.release(P)
Purchases.load(P)
expect(Purchases.credits(P).takeover == Purchases.FREE_CREDITS, "... and back the next time they join")


if fails > 0 then
	error(fails .. " failures")
end
print("free_for_all: all passed")
