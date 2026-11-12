--!nocheck
-- The owner's currency commands (server/OwnerCommands) and the balance change behind them
-- (Purchases.adjust_stars): "/moedas dar | tirar | ver <jogador> [quantia]".
require("./prelude")
local OwnerCommands = require("../src/server/OwnerCommands")
local Purchases = require("../src/server/Purchases")
local Arsenal = require("../src/shared/Data/Arsenal")

local fails = 0
local function expect(c: any, w: string)
	if c then
		print("  ok   " .. w)
	else
		fails += 1
		print("FAIL " .. w)
	end
end

-- ------------------------------------------------------------------------------------ the words
expect(OwnerCommands.is_command("/moedas dar eu 5") and OwnerCommands.is_command("  /MOEDAS"), "/moedas is a command")
expect(OwnerCommands.is_command("/coins give me 5"), "... and so is /coins")
expect(not OwnerCommands.is_command("/moedasx 1") and not OwnerCommands.is_command("oi /moedas"), "nothing else is")
expect(not OwnerCommands.is_command(nil) and OwnerCommands.parse("hello") == nil, "other chat is left alone")

local A = OwnerCommands.amount
expect(A("5000") == 5000 and A("5.000") == 5000 and A("5,000") == 5000, "5000, 5.000 and 5,000")
expect(A("20k") == 20000 and A("2M") == 2000000 and A("1.250.000") == 1250000, "20k, 2M, 1.250.000")
expect(A("1.5") == nil and A("1.50") == nil and A("1,5k") == nil, "a decimal is not an amount")
expect(A("0") == nil and A("-3") == nil and A("abc") == nil and A("") == nil and A("12.34.567") == nil, "nor zero, negatives, words")
expect(A("1000000000") == 1000000000 and A("1000000001") == nil and A("5000m") == nil, "at most a billion")

local c = OwnerCommands.parse("/moedas dar Fulano 5000")
expect(c.op == "give" and c.who == "Fulano" and c.amount == 5000, "dar <jogador> <quantia>")
c = OwnerCommands.parse("/moedas tirar Nome Com Espaço 2k")
expect(c.op == "take" and c.who == "Nome Com Espaço" and c.amount == 2000, "a name with spaces: the amount is the last word")
c = OwnerCommands.parse("/moedas ver Fulano")
expect(c.op == "see" and c.who == "Fulano" and c.amount == nil, "ver <jogador>")
expect(OwnerCommands.parse("/moedas").op == "help" and OwnerCommands.parse("/moedas dar Fulano").op == "help", "an incomplete command asks for help")
expect(OwnerCommands.parse("/moedas dar Fulano muito").bad_amount == "muito", "a bad amount is named")
expect(OwnerCommands.parse("/coins give me 7").op == "give" and OwnerCommands.parse("/coins take me 7").op == "take", "the English words")

-- ------------------------------------------------------------------------------------ who
local owner = { UserId = 1001, Name = "Dono", DisplayName = "O Dono" }
local ana = { UserId = 2002, Name = "ana_clara", DisplayName = "Ana" }
local andre = { UserId = 3003, Name = "andre99", DisplayName = "Dré" }
local here = { owner, ana, andre }
local T = OwnerCommands.target
expect(T("eu", owner, here) == 1001 and T("me", ana, here) == 2002, '"eu" is whoever typed it')
expect(T("ANA_CLARA", owner, here) == 2002 and T("dré", owner, here) == 3003, "an exact name, user or display, any case")
expect(T("@andre99", owner, here) == 3003 and T("andr", owner, here) == 3003, "@name, and the start of a name")
local id, why = T("an", owner, here)
expect(id == nil and string.find(why, "mais de um", 1, true) ~= nil, "a start two players share is refused")
id, why = T("zeca", owner, here)
expect(id == nil and string.find(why, "não está", 1, true) ~= nil, "someone who isn't here is refused by name")
expect(T("2002", owner, here) == 2002 and select(2, T("2002", owner, here)) == "ana_clara", "a user id of someone here")
expect(T("987654", owner, here) == 987654, "... or of someone who isn't (their record is reached by id)")

-- ------------------------------------------------------------------------------------ the balance
local rows = {}
local store = {}
local fail_writes = false
function store:UpdateAsync(k, fn)
	if fail_writes then
		error("DataStore down")
	end
	local new = fn(rows[k])
	if new ~= nil then
		rows[k] = new
	end
	return new
end
function store:GetAsync(k)
	return rows[k]
end
local invs = {}
local players = {}
function players:GetPlayerByUserId(uid)
	for _, p in here do
		if p.UserId == uid then
			return p
		end
	end
	return nil
end
Purchases.reset()
Purchases.configure({
	datastore = store,
	players = players,
	inventory = function(p, inv)
		invs[p] = inv
	end,
})
Purchases.load(ana)

expect(Purchases.EARN_ARSENAL == true, "the Arsenal is earned in this version")
local any_free = false
for _, it in Arsenal.ITEMS do
	any_free = any_free or Purchases.has_unlock(ana, it.key)
end
expect(not any_free, "a new player has no Arsenal item")
-- (2026-11-11: the two boosters are Robux only again, as in RoWorld; the six units keep a price)
local priced = true
for _, it in Arsenal.ITEMS do
	if it.kind == "boost" then
		priced = priced and it.stars == nil
	else
		priced = priced and type(it.stars) == "number" and it.stars > 0
	end
end
expect(priced, "every unit of the Arsenal has a price in the currency; the two boosters have none")

local ok, bal, ch = Purchases.adjust_stars(2002, 5000)
expect(ok and bal == 5000 and ch == 5000 and Purchases.stars(ana) == 5000, "+5000: stored, and this server's copy follows")
expect(invs[ana] ~= nil and invs[ana].stars == 5000, "... and their client is told")
expect(rows.u2002.stars == 5000 and rows.u2002.stars_earned == 0, "a gift is not earnings")
ok, bal, ch = Purchases.adjust_stars(2002, -1200)
expect(ok and bal == 3800 and ch == -1200 and Purchases.stars(ana) == 3800, "-1200")
ok, bal, ch = Purchases.adjust_stars(2002, -999999)
expect(ok and bal == 0 and ch == -3800 and rows.u2002.stars == 0, "taking more than there is leaves zero")
ok, bal, ch = Purchases.adjust_stars(2002, 0)
expect(ok and bal == 0 and ch == 0, "0 only reads")
ok, bal, ch = Purchases.adjust_stars(987654, 250)
expect(ok and bal == 250 and rows.u987654.stars == 250, "a player who is not on this server, by id")
ok, bal, ch = Purchases.adjust_stars(2002, Purchases.MAX_STARS)
expect(ok and bal == Purchases.MAX_STARS, "up to the cap")
ok, bal, ch = Purchases.adjust_stars(2002, 10)
expect(ok and bal == Purchases.MAX_STARS and ch == 0, "... and no further")
Purchases.adjust_stars(2002, -Purchases.MAX_STARS)
expect(not Purchases.adjust_stars(2002, 1.5) and not Purchases.adjust_stars(2002, 0 / 0), "a fraction or NaN is refused")
expect(not Purchases.adjust_stars(-4, 10) and not Purchases.adjust_stars("x", 10) and not Purchases.adjust_stars(2002, 2e9), "so is a bad id or a huge amount")
fail_writes = true
local ok2, why2 = Purchases.adjust_stars(2002, 10)
expect(not ok2 and string.find(why2, "store unavailable", 1, true) ~= nil and Purchases.stars(ana) == 0, "a failed write changes nothing")
fail_writes = false

-- a gift buys an unlock like earned currency does
Purchases.adjust_stars(2002, 20000)
local bought = Purchases.buy_unlock(ana, "mega")
expect(bought and Purchases.has_unlock(ana, "mega") and Purchases.stars(ana) == 0, "given currency unlocks the Mega Nuke")
Purchases.adjust_stars(2002, 30000)
local got_boost, why_boost = Purchases.buy_unlock(ana, "stars2x")
expect(not got_boost and why_boost == "robux only" and Purchases.stars(ana) == 30000, "... but not a booster: Robux only, nothing taken")
Purchases.adjust_stars(2002, -30000)

-- ------------------------------------------------------------------------------------ the command
local deps = {
	is_owner = function(p)
		return p == owner
	end,
	players = function()
		return here
	end,
	adjust = Purchases.adjust_stars,
	currency = "Coroas",
}
local reply, bad = OwnerCommands.run("bom dia", owner, deps)
expect(reply == nil and bad == false, "ordinary chat: no reply")
reply, bad = OwnerCommands.run("/moedas dar eu 999", ana, deps)
expect(bad and string.find(reply, "dono", 1, true) ~= nil and Purchases.stars(ana) == 0, "a player who is not the owner is refused")
reply, bad = OwnerCommands.run("/moedas dar Ana 12.500", owner, deps)
expect(not bad and reply == "+12.500 Coroas para ana_clara. Saldo: 12.500." and Purchases.stars(ana) == 12500, "dar")
reply, bad = OwnerCommands.run("/moedas tirar ana 500", owner, deps)
expect(not bad and reply == "-500 Coroas de ana_clara. Saldo: 12.000.", "tirar")
reply, bad = OwnerCommands.run("/moedas ver ana", owner, deps)
expect(not bad and reply == "ana_clara tem 12.000 Coroas." and Purchases.stars(ana) == 12000, "ver changes nothing")
reply, bad = OwnerCommands.run("/moedas tirar ana 1m", owner, deps)
expect(not bad and string.find(reply, "só tinha 12.000", 1, true) ~= nil and Purchases.stars(ana) == 0, "tirar more than there is")
reply, bad = OwnerCommands.run("/moedas dar eu 50", owner, deps)
expect(not bad and rows.u1001.stars == 50, "the owner gives to themselves")
reply, bad = OwnerCommands.run("/moedas dar zeca 50", owner, deps)
expect(bad and string.find(reply, "zeca", 1, true) ~= nil, "an unknown name: an error, nothing written")
reply, bad = OwnerCommands.run("/moedas dar ana muitas", owner, deps)
expect(bad and string.find(reply, "muitas", 1, true) ~= nil and Purchases.stars(ana) == 0, "a bad amount: an error")
reply, bad = OwnerCommands.run("/moedas", owner, deps)
expect(bad and reply == OwnerCommands.HELP, "no words: the help line")
fail_writes = true
reply, bad = OwnerCommands.run("/moedas dar ana 10", owner, deps)
expect(bad and string.find(reply, "Nada mudou", 1, true) ~= nil, "a failed write is reported")
fail_writes = false

if fails > 0 then
	error(fails .. " failures")
end
print("owner_commands: all passed")
