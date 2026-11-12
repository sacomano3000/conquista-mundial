--!nocheck
-- Data/Lang (the interface's language) and Data/LangPt (the Portuguese dictionary).
-- lune run tests/lang.luau
local Lang = require("../src/shared/Data/Lang")
local Brand = require("../src/shared/Data/Brand")
local PT = require("../src/shared/Data/LangPt")

local fails = 0
local checks = 0
local function eq(got: any, want: any, what: string)
	checks += 1
	if got ~= want then
		fails += 1
		print(string.format("FAIL %s\n   got:  %s\n   want: %s", what, tostring(got), tostring(want)))
	end
end
local function ok(cond: boolean, what: string)
	checks += 1
	if not cond then
		fails += 1
		print("FAIL " .. what)
	end
end

-- outside Roblox nothing is translated until a test asks (the other tests read the English texts)
eq(Lang.on(), false, "off before Lang.use")
eq(Lang.t("Play"), "Play", "untranslated before Lang.use")

Lang.use("pt")
eq(Lang.on(), true, "on after Lang.use('pt')")
local C = Brand.CURRENCY
local CU = Lang.upper(C)
ok(C ~= "Stars" and C ~= "Estrelas", "the currency has its own name")

-- exact texts, capitals, spaces around
eq(Lang.t("Settings"), "Configurações", "exact")
eq(Lang.t("SETTINGS"), "CONFIGURAÇÕES", "capitals, accents included")
eq(Lang.t("  Settings "), "  Configurações ", "the spaces around stay")
eq(Lang.t("0:42"), "0:42", "a clock")
eq(Lang.t("12,500"), "12,500", "a number")
eq(Lang.t("Zanzibar Xq"), "Zanzibar Xq", "a text with no entry stays")
eq(Lang.t(""), "", "empty")
eq(Lang.t(nil), nil, "nil")
eq(Lang.upper("ação é só"), "AÇÃO É SÓ", "upper")

-- string.format texts and glued pieces
eq(Lang.t("Sent 1,200 troops to Peru"), "Enviou 1,200 tropas para Peru", "format")
eq(Lang.t("Alliance formed with Peru"), "Aliança formada com Peru", "glued tail")
eq(Lang.t("Your alliance with Peru has ended"), "Sua aliança com Peru terminou", "glued on both sides")
eq(Lang.t("UNLOCK MEGA NUKE"), "DESBLOQUEAR MAGIA SUPREMA", "a piece inside a piece")
eq(Lang.t("Need 500 more gold"), "Faltam 500 de ouro", "two pieces")
eq(Lang.t("Requires an Airfield"), "Requer: Toca dos Dragões", "article dropped")
eq(Lang.t("Requires a Missile Silo"), "Requer: Altar Arcano", "article dropped (a)")
eq(Lang.t("Your SAM shot down Peru's Atom Bomb"), "Seu Escudo Arcano desfez Bola de Fogo de Peru", "pieces by position")
eq(Lang.t("Only 2 missiles loaded"), "Magias prontas: só 2", "plural letter dropped")
eq(Lang.t("Red team"), "Equipe Red", "team label")
eq(Lang.t("Team 3"), "Equipe 3", "numbered team")

-- the currency's name
eq(Lang.t("2x Stars"), "2x " .. C, "currency")
eq(Lang.t("DOUBLE STARS"), CU .. " EM DOBRO", "currency in capitals")
eq(Lang.t("WITH 2X STARS: +120"), "COM 2X " .. CU .. ": +120", "currency in a format text")
eq(Lang.t("+350 Stars today"), "+350 " .. C .. " hoje", "currency, format")

-- several lines
eq(
	Lang.t("Tutorial complete! +1,000 Stars\nSpend them in the ARSENAL"),
	"Tutorial concluído! +1,000 " .. C .. "\nGaste no ARSENAL",
	"a two-line text with its own entry"
)
eq(Lang.t("Settings\nHelp"), "Configurações\nAjuda", "line by line")

-- texts the code assembles before they are shown
eq(
	Lang.t(string.format("Finish it and earn %s Stars.", Lang.number(1000))),
	"Termine e ganhe 1.000 " .. C .. ".",
	"the tutorial's question: what finishing it pays"
)
eq(
	Lang.t("Surrender and return to the title screen? This campaign will end."),
	"Render-se e voltar à tela inicial? Esta campanha vai terminar.",
	"PauseMenu's surrender, solo"
)

-- the dictionary itself
local SPEC = "%%[%d%.]*[sdifgcqx]"
local function specs(s: string): number
	local n = 0
	local plain = string.gsub(s, "%%%%", "")
	for _ in string.gmatch(plain, SPEC) do
		n += 1
	end
	return n
end
local function braces(s: string): { [string]: number }
	local t = {}
	for k in string.gmatch(s, "{([%w_]+)}") do
		if k ~= "moeda" and k ~= "MOEDA" then
			t[k] = (t[k] or 0) + 1
		end
	end
	return t
end
local entries = 0
local SAMPLES = { "Zed", "7", "Qux", "9", "Vox", "3" }
for src, out in PT do
	entries += 1
	ok(Lang.covers(src), "covers " .. src)
	-- a translation asks for no more pieces than the text has
	local n = specs(src)
	local head = string.sub(src, 1, 1) == " "
	local tail = #src > 1 and string.sub(src, -1) == " "
	local plain_out = string.gsub(out, "%%%%", "")
	ok(specs(out) <= n, "pieces of: " .. src)
	for d in string.gmatch(plain_out, "%%([1-9])") do
		ok(tonumber(d) <= n, "piece %" .. d .. " of: " .. src)
	end
	-- a glued piece keeps its space on the same side
	ok((string.sub(out, 1, 1) == " ") == head, "leading space of: [" .. src .. "]")
	if #src > 1 then
		ok((string.sub(out, -1) == " ") == tail, "trailing space of: [" .. src .. "]")
	end
	-- the {key}s UIRules.format fills in are the same on both sides
	local a, b = braces(src), braces(out)
	for k, v in a do
		ok(b[k] == v, "{" .. k .. "} of: " .. string.sub(src, 1, 60))
	end
	for k in b do
		ok(a[k] ~= nil, "{" .. k .. "} only in the translation of: " .. string.sub(src, 1, 60))
	end
	ok(string.find(out, "[Ee]strela") == nil or string.find(src, "Starfield") ~= nil, "no 'estrela': " .. src)
	ok(string.find(out, "Stars", 1, true) == nil, "no 'Stars' left: " .. src)

	-- a text as the game would write it, and what it becomes
	local i = 0
	local text = string.gsub(string.gsub(src, "%%%%", "\1"), SPEC, function()
		i += 1
		return SAMPLES[(i - 1) % #SAMPLES + 1]
	end)
	text = string.gsub(text, "\1", "%%")
	if head then
		text = "Zed" .. text
	end
	if tail then
		text = text .. "Qux"
	end
	local once = Lang.t(text)
	-- translated twice (a widget's setter, then the sweep or a measure) it must not change again
	eq(Lang.t(once), once, "stable when translated twice: " .. string.sub(src, 1, 70))
	ok(string.find(once, "%%[sd]") == nil, "no %s left in: " .. once)
end
ok(entries > 800, "the dictionary is there (" .. entries .. " entries)")

-- the owner's command replies are written in Portuguese already: they pass through untouched
for _, s in
	{
		"Coroas de Fulano: 12.500",
		"Só o dono do jogo pode usar este comando.",
		"O comando falhou. Nada mudou.",
		"Jogador não encontrado: fulano",
	}
do
	eq(Lang.t(s), s, "Portuguese stays: " .. s)
end

-- back to the code's own English
Lang.use("en")
eq(Lang.on(), false, "off again")
eq(Lang.t("Settings"), "Settings", "English again")

print(string.format("lang: %d checks, %d failed, %d entries", checks, fails, entries))
if fails > 0 then
	error("lang tests failed")
end
