--!nocheck
-- A crate's answer on its way from the server to the screen (2026-11-12: a crate may give an item the
-- player has, which pays Coroas instead; Data/MyShop.caixa.repetidos):
--   * client/Session: CRATE_RESULT carries (ok, item, Coroas of a duplicate); the third value reaches
--     the `crate_result` signal as a whole number, 0 for a new item, and junk from the server is 0;
--   * the same message with no third value (an older server) still works: a new item;
--   * a refusal passes its reason and no Coroas;
--   * the shipped numbers of Data/MyShop are the ones the game uses.
-- What the server does with a duplicate is in tests/colecao.luau; the draw itself in tests/cosmetics.luau;
-- the two screens in tests/telas.luau.   lune run tests/caixa_repetido.luau
local H = require("./ui_harness")
local Session = require("../src/client/Session")
local Protocol = require("../src/shared/Net/Protocol")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local MyShop = require("../src/shared/Data/MyShop")

local checks, failed = 0, 0
local function check(ok: boolean, what: string)
	checks += 1
	if not ok then
		failed += 1
		print("FAIL: " .. what)
	end
end

H.fake_game()
local OP = Protocol.OP
local sent = {}
local s = Session.new({
	now = function()
		return 0
	end,
	net = {
		connected = true,
		send = function(op, ...)
			table.insert(sent, table.pack(op, ...))
		end,
		listen = function() end,
	},
})
local got = {}
s.crate_result:Connect(function(ok, res, back)
	table.insert(got, { ok, res, back })
end)

check(OP.CRATE_RESULT == 33 and OP.OPEN_CRATE == 13, "the crate's two messages keep their numbers")
s:_on_net(OP.CRATE_RESULT, true, "pet_lobo", 6000)
check(#got == 1 and got[1][1] == true and got[1][2] == "pet_lobo" and got[1][3] == 6000, "a duplicate: the item and its 6.000 Coroas reach the screen")
s:_on_net(OP.CRATE_RESULT, true, "pet_gato", 0)
check(#got == 2 and got[2][2] == "pet_gato" and got[2][3] == 0, "a new item: no Coroas")
s:_on_net(OP.CRATE_RESULT, true, "pet_gato")
check(#got == 3 and got[3][1] == true and got[3][3] == 0, "no third value at all: a new item")
s:_on_net(OP.CRATE_RESULT, false, "everything owned", nil)
check(#got == 4 and got[4][1] == false and got[4][2] == "everything owned" and got[4][3] == 0, "a refusal: its reason, no Coroas")
for _, junk in { "6000", -5, 0 / 0, {}, true } do
	local n = #got
	s:_on_net(OP.CRATE_RESULT, true, "pet_lobo", junk)
	check(#got == n + 1 and got[#got][3] == 0, "junk as the Coroas (" .. tostring(junk) .. ") is no Coroas")
end
s:_on_net(OP.CRATE_RESULT, true, "pet_lobo", 2500.9)
check(got[#got][3] == 2500, "a fraction is cut to a whole number")

-- asking: the tab's kind goes with the request
check(type(s.open_crate) == "function", "the session can ask to open a crate")
local n0 = #sent
s:open_crate("flag")
check(#sent == n0 + 1 and sent[#sent][1] == OP.OPEN_CRATE and sent[#sent][2] == "flag", "opening a crate asks the server, with the tab's kind")

-- the owner's numbers
local cx = MyShop.caixa
check(cx.repetidos == true, "Data/MyShop: repetidos = true")
check(Cosmetics.DUPLICATES == true, "... and the game follows it")
local pt = { common = "comum", rare = "raro", epic = "epico", legendary = "lendario" }
local same, below = true, true
for id, key in pt do
	same = same and Cosmetics.DUPLICATE_STARS[id] == cx.coroas_repetido[key]
	below = below and cx.coroas_repetido[key] <= cx.coroas
end
check(same, "the four amounts of coroas_repetido are the ones the game pays")
check(below, "none is above a crate's price in Coroas")
local avg = 0
for _, r in Cosmetics.RARITIES do
	avg += r.odds * Cosmetics.DUPLICATE_STARS[r.id]
end
check(math.abs(avg - 3565) < 0.5, string.format("with everything a duplicate, a crate pays back %.0f Coroas on average", avg))
check(avg < cx.coroas * 0.25, "... under a quarter of what a crate costs")

print(string.format("caixa_repetido: %d checks, %d failed", checks, failed))
if failed > 0 then
	error("caixa_repetido: failed")
end
