--!strict
-- The interface's language (2026-11: this version is in Portuguese). RoWorld's code writes English;
-- every text passes through Lang.t on its way to the screen (client/UI/Widgets' Label and Button,
-- UITheme's text measuring, TitleScreen's GradientText, and client/UI/LangSweep for the TextLabels the
-- screens make by hand), and comes out in the language of Data/Brand.LANGUAGE. A text with no entry is
-- shown as it is, in English. tests/lang.luau.
--
-- The dictionary is Data/LangPt: { [English] = Portuguese }.
--   "Play"                 an exact text. A text in capitals with no entry of its own uses the entry of
--                          its ordinary spelling, in capitals ("PLAY" -> "JOGAR").
--   "%s more Stars to go"  a text made with string.format: every %s, %d, %.1f... stands for anything,
--                          and the pieces found are translated too. In the translation %s takes them in
--                          order; %1, %2... take them by position. %% is a percent sign.
--   "UNLOCK "              a piece the code glues to something else (it starts or ends with a space):
--                          the same as "UNLOCK %s".
--   {moeda}, {MOEDA}       in a translation: the currency's name (Data/Brand.CURRENCY), and in capitals.
--
--   Lang.use(language)        "pt", or anything else for the code's own English. On Roblox the game
--                             starts in Data/Brand.LANGUAGE; outside it (the tests, which read
--                             RoWorld's English texts) nothing is translated until a test asks.
--   Lang.t(text) -> text      the text in the interface's language
--   Lang.on() -> boolean      whether anything is translated
--   Lang.upper(text) -> text  capitals, accents included
--   Lang.covers(source) -> boolean   tests: whether a text of the code (as written there) has an entry
local IS_ROBLOX = typeof(game) == "Instance"
local Brand: any = if IS_ROBLOX then require((script :: any).Parent.Brand) else (require :: any)("./Brand")

local Lang = {}

--- How many texts are remembered (the answer for a text never changes).
Lang.CACHE_MAX = 6000
--- A piece found inside a pattern is translated too, this many levels down.
Lang.MAX_DEPTH = 3

local ACCENT_UP: { [string]: string } = {
	["á"] = "Á",
	["à"] = "À",
	["â"] = "Â",
	["ã"] = "Ã",
	["é"] = "É",
	["ê"] = "Ê",
	["í"] = "Í",
	["ó"] = "Ó",
	["ô"] = "Ô",
	["õ"] = "Õ",
	["ú"] = "Ú",
	["ü"] = "Ü",
	["ç"] = "Ç",
}

--- `text` in capitals, the accented letters of Portuguese included (string.upper leaves them small).
function Lang.upper(text: string): string
	local up = string.upper(text)
	return (string.gsub(up, "[\195][\128-\191]", function(ch: string): string
		return ACCENT_UP[ch] or ch
	end))
end

local MAGIC = "[%^%$%(%)%%%.%[%]%*%+%-%?]"
local function escape(s: string): string
	return (string.gsub(s, MAGIC, "%%%0"))
end

--- first / last: the byte a text must start / end with to match (0: anything), checked before the
--- pattern itself (texts with numbers in them change all the time, and most patterns are not theirs)
type Pattern = { pat: string, out: string, weight: number, n: number, first: number, last: number }

--- A string.format text as a pattern: (the Lua pattern, how many pieces it finds, its fixed letters).
local function compile(src: string): (string, number, number)
	local parts = { "^" }
	local n = 0
	local fixed = 0
	local i = 1
	local len = #src
	while i <= len do
		local c = string.sub(src, i, i)
		if c == "%" then
			if string.sub(src, i + 1, i + 1) == "%" then
				table.insert(parts, "%%")
				fixed += 1
				i += 2
			else
				local spec = string.match(src, "^%%[%d%.]*[sdifgcqx]", i)
				if spec ~= nil then
					n += 1
					table.insert(parts, "(.-)")
					i += #spec
				else
					table.insert(parts, "%%")
					fixed += 1
					i += 1
				end
			end
		else
			table.insert(parts, escape(c))
			fixed += 1
			i += 1
		end
	end
	table.insert(parts, "$")
	return table.concat(parts), n, fixed
end

local EXACT: { [string]: string } = {}
local UPPER: { [string]: string } = {}
local PATTERNS: { Pattern } = {}
--- what every entry was made from, as the dictionary has it (Lang.covers)
local SOURCES: { [string]: boolean } = {}
local ON = false
local cache: { [string]: string } = {}
local cache_n = 0

local function is_format(src: string): boolean
	local i = 1
	while true do
		local at = string.find(src, "%", i, true)
		if at == nil then
			return false
		end
		if string.sub(src, at + 1, at + 1) == "%" then
			i = at + 2
		elseif string.match(src, "^%%[%d%.]*[sdifgcqx]", at) ~= nil then
			return true
		else
			i = at + 1
		end
	end
end

local CUR: string = if type(Brand.CURRENCY) == "string" then Brand.CURRENCY else "Stars"
local CUR_UP = Lang.upper(CUR)

local function load(dict: { [string]: string })
	table.clear(EXACT)
	table.clear(UPPER)
	table.clear(PATTERNS)
	table.clear(SOURCES)
	table.clear(cache)
	cache_n = 0
	ON = next(dict) ~= nil
	for src0, raw in dict do
		local src = src0
		SOURCES[src] = true
		local out = (string.gsub((string.gsub(raw, "{moeda}", CUR)), "{MOEDA}", CUR_UP))
		local head = string.sub(src, 1, 1) == " "
		local tail = #src > 1 and string.sub(src, -1) == " "
		if head or tail then
			-- a piece glued to something else: "%s" stands for the rest, on the same side in both
			src = (if head then "%s" else "") .. src .. (if tail then "%s" else "")
			out = (if head then "%s" else "") .. out .. (if tail then "%s" else "")
		end
		if is_format(src) then
			local pat, n, fixed = compile(src)
			if fixed > 0 then
				local first = if string.sub(src, 1, 1) ~= "%" then string.byte(src, 1) else 0
				local last = 0
				if string.match(src, "%%[%d%.]*[sdifgcqx]$") == nil then
					last = string.byte(src, #src)
				end
				table.insert(PATTERNS, { pat = pat, out = out, weight = fixed, n = n, first = first, last = last })
			end
		else
			-- ("%%" in an exact text is a percent sign, as in the code's own string.format)
			local plain = (string.gsub(src, "%%%%", "%%"))
			local core = string.match(plain, "^%s*(.-)%s*$") or plain
			EXACT[core] = (string.gsub(out, "%%%%", "%%"))
		end
	end
	for src, out in EXACT do
		local up = string.upper(src)
		if up ~= src and EXACT[up] == nil and UPPER[up] == nil then
			UPPER[up] = Lang.upper(out)
		end
	end
	-- the most specific pattern first (the one with the most fixed letters)
	table.sort(PATTERNS, function(a: Pattern, b: Pattern): boolean
		if a.weight ~= b.weight then
			return a.weight > b.weight
		end
		return a.pat < b.pat
	end)
end

--- The interface's language from now on: "pt" (Data/LangPt), or anything else for none.
--- What goes between the thousands of a number: "." in Portuguese ("31.250"), "," otherwise.
Lang.SEP = ","

--- A whole number as the interface's language writes it: 31250 -> "31.250" (pt), "31,250".
function Lang.number(n: number): string
	local s = string.format("%d", math.floor(math.abs(n) + 0.5))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1" .. Lang.SEP)))
	if string.sub(out, 1, 1) == Lang.SEP then
		out = string.sub(out, 2)
	end
	return if n < 0 then "-" .. out else out
end

function Lang.use(language: any)
	local dict: any = {}
	Lang.SEP = if language == "pt" then "." else ","
	if language == "pt" then
		dict = if IS_ROBLOX then require((script :: any).Parent.LangPt) else (require :: any)("./LangPt")
	end
	load(dict)
end

local translate: (text: string, depth: number) -> string

local function fill(out: string, caps: { string }, depth: number): string
	local nth = 0
	local res = {}
	local i = 1
	local len = #out
	while i <= len do
		local c = string.sub(out, i, i)
		if c == "%" then
			local nx = string.sub(out, i + 1, i + 1)
			if nx == "%" then
				table.insert(res, "%")
				i += 2
			elseif string.match(nx, "%d") ~= nil and nx ~= "0" then
				table.insert(res, translate(caps[tonumber(nx) :: number] or "", depth + 1))
				i += 2
			else
				local spec = string.match(out, "^%%[%d%.]*[sdifgcqx]", i)
				if spec ~= nil then
					nth += 1
					table.insert(res, translate(caps[nth] or "", depth + 1))
					i += #spec
				else
					table.insert(res, "%")
					i += 1
				end
			end
		else
			table.insert(res, c)
			i += 1
		end
	end
	return table.concat(res)
end

function translate(text: string, depth: number): string
	-- (numbers, clocks, single letters: nothing to translate)
	if string.find(text, "%a%a") == nil then
		return text
	end
	local lead0, core0, trail0 = string.match(text, "^(%s*)(.-)(%s*)$")
	if core0 == nil or core0 == "" then
		return text
	end
	local lead, core, trail = lead0 :: string, core0 :: string, trail0 :: string
	local hit = EXACT[core]
	if hit == nil and string.find(core, "%l") == nil then
		hit = UPPER[core]
	end
	if hit ~= nil then
		return lead .. hit .. trail
	end
	if depth < Lang.MAX_DEPTH then
		local b1, b2 = string.byte(core, 1), string.byte(core, #core)
		for _, p in PATTERNS do
			local caps: { any } = if (p.first == 0 or p.first == b1) and (p.last == 0 or p.last == b2)
				then { string.match(core, p.pat) }
				else {}
			if caps[1] ~= nil then
				if p.n == 0 then
					caps = {}
				end
				return lead .. fill(p.out, caps :: { string }, depth) .. trail
			end
		end
		if string.find(core, "\n", 1, true) ~= nil then
			-- several lines: each on its own
			local lines = string.split(core, "\n")
			local changed = false
			for i, line in lines do
				local t = translate(line, depth + 1)
				if t ~= line then
					lines[i] = t
					changed = true
				end
			end
			if changed then
				return lead .. table.concat(lines, "\n") .. trail
			end
		end
	end
	return text
end

--- Whether anything is translated (Brand.LANGUAGE has a dictionary).
function Lang.on(): boolean
	return ON
end

--- `text` in the interface's language; `text` itself when there is nothing to translate it with.
function Lang.t(text: any): any
	if not ON or type(text) ~= "string" or text == "" then
		return text
	end
	local hit = cache[text]
	if hit ~= nil then
		return hit
	end
	local out = translate(text, 0)
	if cache_n >= Lang.CACHE_MAX then
		table.clear(cache)
		cache_n = 0
	end
	cache[text] = out
	cache_n += 1
	return out
end

--- Tests: whether `source` (a text as the code writes it: a string.format text keeps its %s) has an
--- entry of its own in the dictionary.
function Lang.covers(source: string): boolean
	return SOURCES[source] == true
end

if IS_ROBLOX then
	Lang.use(Brand.LANGUAGE)
end

return Lang
