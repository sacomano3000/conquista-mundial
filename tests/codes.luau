--!nocheck
-- Redeem codes: server/Codes reads the owner's list (server/MyCodes) and the text a player typed;
-- server/Purchases.redeem_code pays a code once per player.   lune run tests/codes.luau
require("./prelude")
local Codes = require("../src/server/Codes")
local MyCodes = require("../src/server/MyCodes")
local Purchases = require("../src/server/Purchases")
local Protocol = require("../src/shared/Net/Protocol")

local fails, checks = 0, 0
local function ok(cond: any, what: string)
	checks += 1
	if not cond then
		fails += 1
		print("FAIL " .. what)
	end
end

-- 1. what a typed text stands for
ok(Codes.normalize("bemvindo") == "BEMVINDO", "lower case is the same code")
ok(Codes.normalize("  Bem-Vindo_2 ") == "BEM-VINDO_2", "spaces around go; - and _ stay")
ok(Codes.normalize("BEM VINDO") == "BEMVINDO", "a space inside goes")
ok(Codes.normalize("ab") == nil, "two characters are not a code")
ok(Codes.normalize(string.rep("A", 25)) == nil, "25 characters are not a code")
ok(Codes.normalize(string.rep("A", 24)) ~= nil, "24 characters are")
ok(Codes.normalize("OLÁ123") == nil, "an accent is not a code")
ok(Codes.normalize("A;B=C") == nil, "punctuation is not a code")
ok(Codes.normalize(123) == nil and Codes.normalize(nil) == nil, "only text")
ok(Codes.normalize(string.rep(" ", 80) .. "ABC") == nil, "a text longer than the limit is not read")

-- 2. dates
ok(Codes.day_end("1970-01-01") == 86399, "the first day ends at 86399")
ok(Codes.day_end("2027-01-31") == 1801439999, "2027-01-31 ends at 1801439999")
ok(Codes.day_end("2024-02-29") == 1709251199, "a leap day")
ok(Codes.day_end("2027-13-01") == nil and Codes.day_end("31/01/2027") == nil, "not a date")

-- 3. the list
local LIST = {
	["BEMVINDO"] = { coroas = 5000 },
	["velho"] = { coroas = 100, expira = "2026-01-31" },
	["FUTURO"] = { coroas = 250, expira = "2030-12-31" },
	["DESLIGADO"] = { coroas = 100, ativo = false },
	["x"] = { coroas = 100 },
	["SEMVALOR"] = {},
	["NEGATIVO"] = { coroas = -5 },
	["QUEBRADO"] = { coroas = 1.5 },
	["DATA"] = { coroas = 5, expira = "amanhã" },
}
local NOW = 1794268800 -- 2026-11-10
local e, why = Codes.find("bemvindo", NOW, LIST)
ok(e ~= nil and e.code == "BEMVINDO" and e.stars == 5000 and why == nil, "a good code is found, whatever its case")
e, why = Codes.find("VELHO", NOW, LIST)
ok(e == nil and why == "expired", "a code past its last day has expired")
e = Codes.find("VELHO", Codes.day_end("2026-01-31"), LIST)
ok(e ~= nil and e.stars == 100, "and is good until its last day's last second")
e = Codes.find("futuro", NOW, LIST)
ok(e ~= nil and e.stars == 250, "a code with a later date is good")
e, why = Codes.find("DESLIGADO", NOW, LIST)
ok(e == nil and why == "invalid", "a switched-off code reads as one that does not exist")
for _, bad in { "NADA", "SEMVALOR", "NEGATIVO", "QUEBRADO", "DATA", "x", "", "  " } do
	e, why = Codes.find(bad, NOW, LIST)
	ok(e == nil and why == "invalid", "'" .. bad .. "' is not a code")
end
ok(#Codes.all(LIST) == 4, "four entries of the list are valid (" .. #Codes.all(LIST) .. ")")
ok(#Codes.problems(LIST) == 5, "and five are reported (" .. #Codes.problems(LIST) .. ")")
ok(#Codes.problems({ ["ABC"] = { coroas = 1 }, ["abc"] = { coroas = 2 } }) == 1, "the same code twice is reported")

-- 4. the list the game ships with is fine
ok(#Codes.problems(MyCodes) == 0, "server/MyCodes has no bad line: " .. table.concat(Codes.problems(MyCodes), "; "))
ok(#Codes.problems() == 0, "and it is the list read by default")
for _, entry in Codes.all() do
	ok(entry.stars <= 1000000, entry.code .. " gives a sane amount")
end

-- 5. redeeming: once per player, written with the Stars in one write
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
local P = { UserId = 42, Name = "Ana" }
local Q = { UserId = 43, Name = "Beto" }
local now = NOW
local told = 0
Purchases.reset()
Purchases.configure({
	datastore = store,
	codes = LIST,
	now = function()
		return now
	end,
	players = {
		GetPlayerByUserId = function(_, id)
			return if id == 42 then P elseif id == 43 then Q else nil
		end,
	},
	notify = function()
		told += 1
	end,
})
Purchases.load(P)
Purchases.load(Q)
local before = Purchases.inventory(P).stars
told = 0
local good, reason, paid, balance = Purchases.redeem_code(P, " bemvindo ")
ok(good == true and reason == nil and paid == 5000, "a good code pays its Coroas")
ok(balance == before + 5000 and Purchases.inventory(P).stars == before + 5000, "the balance follows")
ok(told >= 1, "and the client is told")
ok(rows.u42 ~= nil and rows.u42.codes.BEMVINDO == true and rows.u42.stars == before + 5000, "one write: the code and the Coroas")
good, reason = Purchases.redeem_code(P, "BEMVINDO")
ok(good == false and reason == "used", "the same player can't use it twice")
ok(Purchases.inventory(P).stars == before + 5000, "and is not paid twice")
good, reason, paid = Purchases.redeem_code(Q, "BemVindo")
ok(good == true and paid == 5000, "another player can use it")
good, reason = Purchases.redeem_code(P, "VELHO")
ok(good == false and reason == "expired", "an expired code pays nothing")
good, reason = Purchases.redeem_code(P, "NADA")
ok(good == false and reason == "invalid", "an unknown code pays nothing")
good, reason = Purchases.redeem_code(P, "DESLIGADO")
ok(good == false and reason == "invalid", "a switched-off code pays nothing")
ok(Purchases.inventory(P).stars == before + 5000, "the balance did not move")
down = true
good, reason = Purchases.redeem_code(P, "FUTURO")
ok(good == false and string.sub(tostring(reason), 1, 17) == "store unavailable", "a store outage: not redeemed")
down = false
ok(rows.u42.codes.FUTURO == nil, "and the code is not marked used")
good, reason, paid = Purchases.redeem_code(P, "FUTURO")
ok(good == true and paid == 250 and Purchases.inventory(P).stars == before + 5250, "it works once the store is back")
-- the record survives a reload with its used codes
Purchases.reset()
Purchases.configure({ datastore = store, codes = LIST })
Purchases.load(P)
good, reason = Purchases.redeem_code(P, "FUTURO")
ok(good == false and reason == "used", "a used code stays used after the player comes back")
ok(Purchases.inventory(P).stars == before + 5250, "with the Coroas it paid")

-- 6. the messages have their numbers
ok(Protocol.OP.REDEEM_CODE == 43 and Protocol.OP.CODE_RESULT == 44, "the two messages")
local seen = {}
for name, n in Protocol.OP do
	ok(seen[n] == nil, "op " .. name .. " shares no number")
	seen[n] = name
end

print(string.format("codes: %d checks, %d failed", checks, fails))
if fails > 0 then
	error("codes tests failed")
end
