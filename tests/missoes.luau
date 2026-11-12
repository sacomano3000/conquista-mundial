--!nocheck
-- Missions and the monthly pass (shared/Data/Missions; server/Purchases; server/Rewards): the calendar
-- (days and months turn at midnight in Brasília), the day's missions, what a match's result counts,
-- the Coroas paid at once, the pass (a receipt turns it on for the calendar month; what was already
-- done is paid then; the next month it is off again and the progress starts over), and the season's
-- items (one skin, one flag, one pet a month; kept for good; never in a crate).
require("./prelude")
local Missions = require("../src/shared/Data/Missions")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Products = require("../src/shared/Data/Products")
-- The game ships with the pass's product (2026-11-12: Data/MyProducts, line `pass`). This test tells
-- its own story from "no product yet" to "on sale", so it starts from no product; the id it ships
-- with is checked here (and in tests/my_products).
local SHIPPED_PASS = Products.pass.id
local SHIPPED_PASS_ROBUX = Products.pass.robux
Products.pass.id = 0
local Seasons = require("../src/shared/Assets/Seasons")
local Purchases = require("../src/server/Purchases")
local Rewards = require("../src/server/Rewards")

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

-- unix seconds of a moment given in Brasília time
local function brt(y, mo, d, h, mi)
	return Missions.days_of(y, mo, d) * 86400 + (h or 0) * 3600 + (mi or 0) * 60 + 3 * 3600
end

-- ---------------------------------------------------------------------------------------------
print("the calendar")
do
	local y, m, d = Missions.civil(0)
	expect(y == 1970 and m == 1 and d == 1, "day 0 is 1970-01-01")
	expect(Missions.days_of(2026, 11, 12) == 20769, "2026-11-12 is day 20769")
	y, m, d = Missions.civil(Missions.days_of(2028, 2, 29))
	expect(y == 2028 and m == 2 and d == 29, "a leap day goes there and back")
	for _, ymd in { { 2026, 12, 31 }, { 2027, 1, 1 }, { 2027, 3, 1 }, { 2100, 2, 28 }, { 2100, 3, 1 } } do
		local a, b, c = Missions.civil(Missions.days_of(ymd[1], ymd[2], ymd[3]))
		expect(a == ymd[1] and b == ymd[2] and c == ymd[3], string.format("%d-%02d-%02d goes there and back", ymd[1], ymd[2], ymd[3]))
	end
	local before, after = brt(2026, 11, 12, 23, 59), brt(2026, 11, 13, 0, 0)
	expect(Missions.day(after) == Missions.day(before) + 1, "the day turns at midnight in Brasília")
	expect(Missions.day(brt(2026, 11, 12, 0, 0)) == Missions.day(before), "... and not before it")
	expect(Missions.day_end(before) == after, "the day ends at that midnight")
	local last, first = brt(2026, 11, 30, 23, 59), brt(2026, 12, 1, 0, 0)
	expect(Missions.month(first) == Missions.month(last) + 1, "the month turns at midnight of the 1st in Brasília")
	expect(Missions.month_end(brt(2026, 11, 12, 10)) == first, "November ends when December starts")
	expect(Missions.month_end(brt(2026, 12, 25, 10)) == brt(2027, 1, 1), "December ends when the next year starts")
	expect(Missions.month_end(brt(2028, 2, 10)) == brt(2028, 3, 1), "a leap February ends on March 1st")
	expect(Missions.month_name(Missions.month(last)) == "Novembro de 2026", "the month's name: " .. Missions.month_name(Missions.month(last)))
	-- 02:30 UTC of the 1st is still the last day of the month before in Brasília
	expect(Missions.month(Missions.days_of(2026, 12, 1) * 86400 + 2 * 3600) == Missions.month(last), "02:00 UTC on the 1st is still November there")
	expect(Missions.span(5 * 3600 + 12 * 60) == "5h 12min" and Missions.span(12 * 86400 + 5) == "12 dias" and Missions.span(40) == "1min", "the countdown's words")
end

-- ---------------------------------------------------------------------------------------------
print("the missions")
do
	expect(#Missions.pool() >= Missions.DAILY_COUNT and #Missions.monthly() >= 3, "there are daily and monthly missions")
	local kinds = {}
	for _, def in Missions.monthly() do
		if def.kind ~= nil then
			kinds[def.kind] = (kinds[def.kind] or 0) + 1
		end
		expect(def.goal >= 1 and (def.kind ~= nil or def.stars > 0), "monthly " .. def.id .. ": a goal and a reward")
	end
	expect(kinds.skin == 1 and kinds.flag == 1 and kinds.pet == 1, "the pass gives one skin, one flag and one pet")
	local day0 = Missions.day(brt(2026, 11, 12, 12))
	local varied = false
	for day = day0, day0 + 59 do
		local list = Missions.daily(day)
		local seen, ids = {}, {}
		local ok = #list == Missions.DAILY_COUNT
		for _, def in list do
			if seen[def.counter] or ids[def.id] or def.stars <= 0 then
				ok = false
			end
			seen[def.counter] = true
			ids[def.id] = true
		end
		if not ok then
			expect(false, "day " .. day .. ": " .. Missions.DAILY_COUNT .. " different missions, each counting something else")
		end
		if list[1].id ~= Missions.daily(day0)[1].id then
			varied = true
		end
		expect(Missions.daily(day) == list or Missions.daily(day)[1].id == list[1].id, "day " .. day .. ": the same list every time it is asked")
	end
	expect(varied, "the days do not all have the same missions")
	-- the monthly goals are longer than any daily one of the same kind
	for _, def in Missions.monthly() do
		for _, dd in Missions.pool() do
			if dd.counter == def.counter then
				expect(def.goal > dd.goal * 3, string.format("monthly %s (%d) is much longer than daily %s (%d)", def.id, def.goal, dd.id, dd.goal))
			end
		end
	end
end

-- ---------------------------------------------------------------------------------------------
print("the seasons")
do
	expect(#Seasons.seasons == 12, "twelve seasons, one a month")
	local ids = {}
	for month = 1, 12 do
		local s = Missions.season(2026 * 12 + month - 1)
		expect(s ~= nil and Seasons.seasons[month].month == month, "month " .. month .. " has its season: " .. tostring(s and s.name))
		for _, kind in Cosmetics.KINDS do
			local it = Cosmetics.item(s[kind])
			expect(it ~= nil and it.kind == kind and it.rarity == "season" and it.season == s.key, string.format("%s: its %s is an item of the pass (%s)", s.name, kind, tostring(it and it.name)))
			expect(not ids[s[kind]], s[kind] .. " is of one season only")
			ids[s[kind]] = true
			if kind ~= "skin" then
				local img, _x, _y, w, h = Cosmetics.image_of(it)
				expect(img ~= "" and w > 0 and h > 0, s[kind] .. " has a picture")
			else
				local _b, w, h = Cosmetics.mask(it)
				expect(w == 8 and h == 8 and Cosmetics.color(it, 1) ~= nil, s[kind] .. " has a pattern in its own colours")
			end
			expect(Cosmetics.may_own(s[kind], 42), s[kind] .. " may be owned by anyone it is given to")
		end
	end
	expect(Missions.season(2027 * 12 + 10).key == Missions.season(2026 * 12 + 10).key, "a month has the same season the year after")
	-- never in a crate, the shop, or the Locker's count
	local in_crate = false
	for _, it in Cosmetics.all() do
		if it.season ~= nil or it.rarity == "season" then
			in_crate = true
		end
	end
	expect(not in_crate, "no item of the pass is in the crates' catalog")
	expect(#Cosmetics.seasonals() == 36, "36 items of the pass in all")
	local owned = {}
	for _, it in Cosmetics.seasonals() do
		owned[it.id] = true
	end
	expect(Cosmetics.crate_owned(owned) == 0, "they do not count in the Coleção's N of M")
	expect(Cosmetics.rarity("season").name == "Pass", "they show as the pass's")
	for i = 1, 400 do
		local id = Cosmetics.roll({}, (i * 0.618) % 1, (i * 0.377) % 1)
		if id ~= nil and Cosmetics.item(id).season ~= nil then
			expect(false, "a crate gave an item of the pass: " .. id)
		end
	end
	-- each tab's crate opened until the tab is complete (it is the same draw whether the crate was paid
	-- with Robux or with Coroas: Purchases.open_crate). Since 2026-11-12 a crate may give an item the
	-- player has (it pays Coroas): both ways are run, and in neither does an item of the pass come out
	local shipped_dups = Cosmetics.DUPLICATES
	for _, dups in { true, false } do
		Cosmetics.DUPLICATES = dups
		local way = if dups then "with duplicates" else "never repeating"
		math.randomseed(2026)
		local n_all = 0
		for _, kind in { "skin", "flag", "pet" } do
			local have: { [string]: boolean } = {}
			local crates, got, bad, wrong_tab, dup_n, dup_wrong = 0, 0, 0, 0, 0, 0
			for _ = 1, 300000 do
				local id, dup = Cosmetics.roll(have, math.random(), math.random(), kind)
				if id == nil then
					break
				end
				crates += 1
				local it = Cosmetics.item(id)
				if it.season ~= nil or it.rarity == "season" then
					bad += 1
				end
				if it.kind ~= kind then
					wrong_tab += 1
				end
				if dup ~= (have[id] == true) then
					dup_wrong += 1
				end
				if have[id] then
					dup_n += 1
				else
					have[id] = true
					got += 1
				end
			end
			local in_tab = 0
			for _, it in Cosmetics.all() do
				if it.kind == kind then
					in_tab += 1
				end
			end
			n_all += got
			expect(bad == 0, string.format("%s: the %s crate, opened until the tab is complete (%d crates), never gives an item of the pass", way, kind, crates))
			expect(wrong_tab == 0 and got == in_tab and got > 0, string.format("... and gives every %s of its tab (%d of %d)", kind, got, in_tab))
			expect(dup_wrong == 0 and (dups or dup_n == 0), string.format("... %d duplicates, each one told as a duplicate", dup_n))
			expect(Cosmetics.roll(have, 0.5, 0.5, kind) == nil, "... and then it is not rolled any more, with the pass's items not owned")
		end
		expect(n_all == #Cosmetics.all(), way .. ": the three crates together give the whole catalog and nothing else")
	end
	Cosmetics.DUPLICATES = shipped_dups
	expect(shipped_dups == true, "(as shipped: a crate may give a duplicate)")
	-- a player who owns the pass's items: the crates do not count them as theirs either
	local with_pass: { [string]: boolean } = {}
	for _, it in Cosmetics.seasonals() do
		with_pass[it.id] = true
	end
	local clean_rolls, pass_dups = 0, 0
	for i = 1, 300 do
		local id, dup = Cosmetics.roll(with_pass, (i * 0.618034) % 1, (i * 0.377) % 1)
		if id ~= nil and Cosmetics.item(id).season == nil then
			clean_rolls += 1
		end
		if dup then
			pass_dups += 1
		end
	end
	expect(clean_rolls == 300, "owning the pass's items changes nothing in the crate (300 crates)")
	expect(pass_dups == 0, "... and none of those crates is taken for a duplicate")
	-- the Loja Misteriosa: a year of days, no offer is an item of the pass
	local Shop = require("../src/shared/Data/Shop")
	local offers, bad_offers = 0, 0
	for day = 20760, 20760 + 365 do
		for _, o in Shop.offers(day, 42) do
			offers += 1
			local id = if type(o) == "table" then (o.id or o.item or o.item_id) else o
			local it = Cosmetics.item(id)
			if it == nil or it.season ~= nil or it.rarity == "season" then
				bad_offers += 1
			end
		end
	end
	expect(offers > 365 and bad_offers == 0, string.format("the mystery shop never offers an item of the pass (%d offers in a year)", offers))
end

-- ---------------------------------------------------------------------------------------------
print("what a result counts")
do
	local win = { spawned = true, left = false, won = true, minutes = 12.34, shares = 8, kills = 3, place = 1, field = 20 }
	local d = Missions.deltas(win, true)
	expect(d.played == 1 and d.wins == 1 and d.kills == 3 and d.top3 == 1 and d.minutes == 12.3, "a win: a match, a win, its kingdoms, its minutes, a top 3")
	d = Missions.deltas(win, false)
	expect(d.played == nil and d.kills == 3, "a later life of the same match is not another match")
	d = Missions.deltas({ spawned = true, left = true, won = true, minutes = 1, kills = 0, place = 2, field = 20 }, true)
	expect(d.played == nil and d.wins == nil and d.top3 == nil and d.minutes == 1, "a minute and gone: no match, no win, no top 3")
	d = Missions.deltas({ spawned = true, left = false, won = false, minutes = 9, kills = 1, place = 2, field = 3 }, true)
	expect(d.top3 == nil and d.played == 1, "second of three is not a top 3")
	expect(next(Missions.deltas({ spawned = false, minutes = 50, kills = 9, won = true }, true)) == nil, "a result of someone who never played counts nothing")
	expect(next(Missions.deltas("x", true)) == nil and next(Missions.deltas(nil, true)) == nil, "nonsense counts nothing")
	d = Missions.deltas({ spawned = true, minutes = 1e9, kills = 1e9, place = 1, field = 1e9, won = true }, true)
	expect(d.minutes <= 240 and d.kills <= 200, "a result's numbers are bounded")
end

-- ---------------------------------------------------------------------------------------------
print("a state")
do
	local t = brt(2026, 11, 12, 10)
	local st = Missions.clean({ day = "x", d = { kills = -4, wins = 0 / 0, played = 2.26 }, dp = { "a", 7, b = true, ["bad id"] = true }, pass = "no" })
	expect(st.day == 0 and st.d.kills == nil and st.d.wins == nil and st.d.played == 2.3 and st.dp.a and st.dp.b and st.dp["bad id"] == nil and st.pass == nil, "a stored state is made safe")
	st = Missions.clean(nil)
	local day = Missions.day(t)
	local list = Missions.daily(day)
	Missions.add(st, t, { [list[1].counter] = list[1].goal - 1 })
	local out = Missions.settle(st, t, {})
	expect(out.stars == 0 and #out.done == 0, "a goal not reached pays nothing")
	Missions.add(st, t, { [list[1].counter] = 1 })
	out = Missions.settle(st, t, {})
	expect(out.stars == list[1].stars and #out.done == 1 and st.dp[list[1].id] == true, "the goal reached pays its Coroas")
	expect(st.m.daily == 1, "... and counts as a daily mission done this month")
	out = Missions.settle(st, t, {})
	expect(out.stars == 0, "... once")
	local v = Missions.view(st, t)
	expect(#v.daily == Missions.DAILY_COUNT and v.daily[1].done and v.daily[1].paid and v.daily[1].have == v.daily[1].goal and not v.daily[2].paid, "the view: the first one done")
	expect(v.pass == false and v.day_left == 14 * 3600 and v.season.key == "fenix", "the view: no pass, 14 hours left, November's season")
	-- the next day: the daily part is new, the month's stays
	local t2 = brt(2026, 11, 13, 0, 1)
	v = Missions.view(st, t2)
	expect(not v.daily[1].done and v.daily[1].have == 0, "the next day's missions start from nothing (in the view, the state untouched)")
	expect(st.day == day, "... the view changed nothing")
	Missions.roll(st, t2)
	expect(next(st.d) == nil and next(st.dp) == nil and st.m.daily == 1 and (st.m[list[1].counter] or 0) >= 1, "a new day: the day's counters go, the month's stay")
	-- the next month: everything of the month goes
	st.pass = Missions.month(t2)
	expect(Missions.has_pass(st, t2) and Missions.has_pass(st, brt(2026, 11, 30, 23, 59)), "the pass is on until the month's last minute")
	local t3 = brt(2026, 12, 1, 0, 0)
	expect(not Missions.has_pass(st, t3), "... and off at midnight of the 1st")
	Missions.roll(st, t3)
	expect(next(st.m) == nil and next(st.mp) == nil, "a new month: the monthly progress starts over")
	expect(Missions.view(st, t3).season.key == "urso", "... with December's season")
end

-- ---------------------------------------------------------------------------------------------
print("the server: a match counts, Coroas are paid, the pass")
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
local P = { UserId = 42, Name = "Player" }
local clock = brt(2026, 11, 12, 10)
local pushed = {}
Purchases.reset()
Purchases.configure({
	datastore = store,
	players = {
		GetPlayerByUserId = function(_, id)
			return if id == 42 then P else nil
		end,
	},
	now = function()
		return clock
	end,
	inventory = function(_p, inv)
		table.insert(pushed, inv)
	end,
})
local sent = {}
local rclock = 1000
Rewards.reset()
Rewards.configure({
	add_stars = Purchases.add_stars,
	missions = true,
	send = function(_, payload)
		table.insert(sent, payload)
	end,
	now = function()
		return rclock
	end,
})
Purchases.load(P)
local inv0 = Purchases.inventory(P)
expect(type(inv0.missions) == "table" and inv0.missions.now == clock and inv0.missions.on_sale == false, "the inventory carries the missions, the server's clock, and that no pass is on sale yet")
expect(not Purchases.has_pass(P), "no pass to begin with")
expect(SHIPPED_PASS == 3730557862 and SHIPPED_PASS_ROBUX == 199, "the game ships with the pass on sale: the owner's product, 199 Robux (" .. tostring(SHIPPED_PASS) .. ", " .. tostring(SHIPPED_PASS_ROBUX) .. ")")
do
	Products.pass.id = SHIPPED_PASS
	expect(Purchases.kind_of(SHIPPED_PASS) == "pass" and Purchases.inventory(P).missions.on_sale == true, "... and with it the server sells the pass")
	Products.pass.id = 0
end

local day = Missions.day(clock)
local todays = Missions.daily(day)
-- a result that reaches every goal of today at once
local big = { spawned = true, left = false, won = true, minutes = 30, shares = 8, kills = 9, place = 1, field = 40 }
local base = require("../src/shared/Data/Stars").payout(big, "public", false).total
local due = 0
local d = Missions.deltas(big, true)
for _, def in todays do
	if (d[def.counter] or 0) >= def.goal then
		due += def.stars
	end
end
expect(due > 0, "this result finishes at least one of today's missions (" .. due .. " Coroas)")
local paid = Rewards.pay(P, big, "public")
expect(paid == base + due, string.format("the match pays its Coroas and the missions' (%d + %d = %d)", base, due, paid))
expect(Purchases.stars(P) == base + due, "... into the balance")
local last = sent[#sent]
local line = nil
for _, l in last.lines do
	if l[1] == "missions" then
		line = l[2]
	end
end
expect(line == due and last.total == base + due and last.balance == base + due, "the client's breakdown has a line for the missions")
local inv1 = pushed[#pushed]
expect(inv1.missions.d.kills == 9 and inv1.missions.m.kills == 9 and inv1.missions.m.played == 1, "the inventory that follows carries the progress")
local before = Purchases.stars(P)
Rewards.pay(P, big, "public")
local again = require("../src/shared/Data/Stars").payout(big, "public", false).total
expect(Purchases.stars(P) - before >= again, "a second match pays again")
do
	local v = Missions.view(rows.u42.missions, clock)
	local n = 0
	for _, m in v.daily do
		if m.paid then
			n += 1
		end
	end
	expect(rows.u42.missions.m.daily == n, "the month counts the daily missions done (" .. n .. ")")
end
-- a daily mission is never paid twice in a day
local s0 = Purchases.stars(P)
for _ = 1, 3 do
	Rewards.pay(P, big, "public")
end
local v = Missions.view(rows.u42.missions, clock)
local all_paid = true
for _, m in v.daily do
	all_paid = all_paid and m.paid
end
expect(all_paid, "after a few matches every mission of the day is done")
local s1 = Purchases.stars(P)
Rewards.pay(P, big, "public")
expect(Purchases.stars(P) - s1 == again, "... and then a match pays only itself")
expect(s1 > s0, "(the balance grew meanwhile)")

-- a result that pays no Coroas still counts
do
	local none = { spawned = true, left = true, won = false, minutes = 0.4, shares = 0, kills = 0, place = 30, field = 40 }
	local m0 = rows.u42.missions.m.minutes
	Rewards.pay(P, none, "public")
	expect(rows.u42.missions.m.minutes > m0, "a result counts its minutes whatever it pays")
end

-- the monthly missions: progress without the pass, nothing paid
local function monthly_done(): number
	local n = 0
	for _, m in Missions.view(rows.u42.missions, clock).monthly do
		if m.done then
			n += 1
		end
	end
	return n
end
rows.u42.missions.m = { played = 500, wins = 500, kills = 500, minutes = 5000, top3 = 500, daily = 500 }
Purchases.load(P)
Rewards.pay(P, big, "public")
expect(monthly_done() == #Missions.monthly() and next(rows.u42.missions.mp) == nil, "without the pass the monthly missions are done but not paid")
local season = Missions.season(Missions.month(clock))
local function owns(id: string): boolean
	return rows.u42.owned[id] == true
end
expect(not owns(season.skin) and not owns(season.flag) and not owns(season.pet), "... and none of the season's items is owned")

-- the pass: its receipt
Products.pass.id = 880088
expect(Purchases.kind_of(880088) == "pass", "the pass's product grants the pass")
expect(Purchases.inventory(P).missions.on_sale == true, "with a product id the pass is on sale")
local coins = 0
for _, def in Missions.monthly() do
	coins += def.stars
end
local b0 = Purchases.stars(P)
expect(Purchases.process_receipt({ PlayerId = 42, ProductId = 880088, PurchaseId = "pass-nov", CurrencySpent = 199 }) == "granted", "the pass's receipt is granted")
expect(Purchases.has_pass(P) and rows.u42.missions.pass == Missions.month(clock), "the pass is on for this month")
expect(Purchases.stars(P) - b0 == coins, string.format("the monthly missions already done pay at once (%d Coroas)", coins))
expect(coins == 50000, "the pass pays 50,000 Coroas a month (10,000 + 15,000 + 25,000: Data/MyMissions, 2026-11-12)")
expect(owns(season.skin) and owns(season.flag) and owns(season.pet), "... and the season's skin, flag and pet are given")
expect(rows.u42.equipped.pet == season.pet and rows.u42.equipped.flag == season.flag and rows.u42.equipped.skin == season.skin, "... and put on, the slots being empty")
local inv2 = pushed[#pushed]
expect(table.find(inv2.owned, season.pet) ~= nil and inv2.missions.pass == Missions.month(clock), "the inventory that follows has them and the pass")
expect(Purchases.process_receipt({ PlayerId = 42, ProductId = 880088, PurchaseId = "pass-nov" }) == "granted" and Purchases.stars(P) - b0 == coins, "the same receipt again adds nothing")
local b1 = Purchases.stars(P)
expect(Purchases.process_receipt({ PlayerId = 42, ProductId = 880088, PurchaseId = "pass-nov-2" }) == "granted", "a second pass in the same month is granted")
expect(Purchases.stars(P) - b1 == Products.pass.robux * Purchases.DUPLICATE_STARS_PER_ROBUX, "... as Coroas for its price (there was nothing else to give)")
local b2 = Purchases.stars(P)
Rewards.pay(P, big, "public")
expect(Purchases.stars(P) - b2 == again, "what the pass paid is not paid again")
-- they survive a reload (the record's cleaning keeps them)
Purchases.release(P)
Purchases.load(P)
expect(table.find(Purchases.inventory(P).owned, season.skin) ~= nil and Purchases.has_pass(P), "after leaving and coming back the items and the pass are there")

-- the next month
clock = brt(2026, 12, 1, 0, 5)
expect(not Purchases.has_pass(P), "on the 1st the pass is off")
local b3 = Purchases.stars(P)
Rewards.pay(P, big, "public")
local st = rows.u42.missions
expect(st.month == Missions.month(clock) and st.m.kills == 9 and next(st.mp) == nil, "... and the month's progress starts over")
expect(owns(season.skin) and owns(season.flag) and owns(season.pet), "... but the items stay")
local dec = Missions.season(Missions.month(clock))
expect(dec.key ~= season.key and not owns(dec.pet), "December has another season, not owned yet")
-- bought in the middle of the month with nothing done: on, nothing paid; then a mission done pays
expect(Purchases.process_receipt({ PlayerId = 42, ProductId = 880088, PurchaseId = "pass-dec" }) == "granted" and Purchases.has_pass(P), "December's pass")
local b4 = Purchases.stars(P)
rows.u42.missions.m.kills = 99999
Purchases.load(P)
Rewards.pay(P, big, "public")
local got_item = false
for _, def in Missions.monthly() do
	if def.counter == "kills" and def.kind ~= nil then
		got_item = owns(dec[def.kind])
	end
end
expect(got_item, "with the pass on, a monthly mission that completes gives its item at once")
-- a year later the same season: the item is owned, Coroas instead
clock = brt(2027, 11, 3, 12)
rows.u42.missions = { month = Missions.month(clock), m = { played = 500, wins = 500, kills = 500, minutes = 5000, top3 = 500, daily = 500 }, day = Missions.day(clock), d = {}, dp = {} }
Purchases.load(P)
local b5 = Purchases.stars(P)
expect(Purchases.process_receipt({ PlayerId = 42, ProductId = 880088, PurchaseId = "pass-nov-27" }) == "granted", "November's pass a year later")
expect(Purchases.stars(P) - b5 == coins + 3 * Missions.DUPLICATE_STARS, "the season's items already owned turn into Coroas")
Products.pass.id = 0

-- a solo match (the client's word, bounded by the server's clock): its first result is a match
print("solo")
do
	rows.u43 = nil
	local Q = { UserId = 43, Name = "Solo" }
	Purchases.load(Q)
	clock = brt(2027, 11, 4, 12)
	Rewards.solo_started(Q, "solo1")
	rclock += 20 * 60
	Rewards.solo_result(Q, { spawned = true, left = false, won = false, minutes = 20, shares = 3, kills = 2, place = 5, field = 30 })
	local m = rows.u43.missions
	expect(m.m.played == 1 and m.m.kills == 2 and m.m.minutes == 20, "a solo result counts")
	rclock += 5 * 60
	Rewards.solo_result(Q, { spawned = true, left = false, won = true, minutes = 5, shares = 3, kills = 1, place = 1, field = 30 })
	m = rows.u43.missions
	expect(m.m.played == 1 and m.m.kills == 3 and m.m.wins == 1, "a second life of the same match adds its kingdoms, not another match")
	-- a made-up report: an hour claimed after one real minute
	Rewards.solo_started(Q, "solo2")
	rclock += 60
	Rewards.solo_result(Q, { spawned = true, left = false, won = true, minutes = 240, shares = 30, kills = 200, place = 1, field = 30 })
	m = rows.u43.missions
	expect(m.m.minutes <= 20 + 5 + 1.3 and m.m.kills <= 3 + 30, "a made-up report counts no more time than passed, nor more kingdoms than the field")
	expect(m.m.played == 1, "... and a match of one minute is not a match played")
end

-- without the switch, Rewards calls add_stars as it always did
do
	local calls = {}
	Rewards.reset()
	Rewards.configure({
		missions = false,
		add_stars = function(_p, n, extra)
			table.insert(calls, { n, extra })
			return true, n
		end,
	})
	Rewards.pay(P, big, "public")
	Rewards.pay(P, { spawned = false }, "public")
	-- (2026-11-12: a public result still goes along, for the player's wins and kingdoms and the
	-- ranked points, marked `missions = false` so that no mission counts it)
	expect(#calls == 1 and type(calls[1][2]) == "table" and calls[1][2].missions == false and calls[1][2].public == true, "missions off: the result goes marked as not for the missions, and nothing is written for an empty payout")
end

print(string.format("%d checks, %d failed", checks, fails))
if fails > 0 then
	error("missoes: " .. fails .. " failed")
end
