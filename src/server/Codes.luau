--!strict
-- Redeem codes (server/MyCodes: the owner's list): a player types a code in the Settings window and
-- gets its Coroas ("Stars" in the code), once per player. This module only reads the list and the
-- text typed: no Roblox API (tests/codes.luau); server/Purchases.redeem_code writes the player's
-- record, and ServerMain hears the request (Net OP.REDEEM_CODE, answered with OP.CODE_RESULT).
--
--   Codes.normalize(text)         -> the code as stored ("  bem-vindo " -> "BEM-VINDO"), or nil
--   Codes.find(text, now, list?)  -> ({ code, stars }) or (nil, "invalid" | "expired")
--   Codes.listed(text, list?)     -> whether the list has that code at all (good, expired or switched off)
--   Codes.all(list?)              -> every valid entry { code, stars, expires?, active }, sorted
--   Codes.problems(list?)         -> what is wrong in the list, as lines for the server's log
local IS_ROBLOX = typeof(game) == "Instance"

local Codes = {}

Codes.MIN_LEN = 3
Codes.MAX_LEN = 24
--- The most one code gives.
Codes.MAX_STARS = 100000000
--- The longest text looked at (what a client sends is cut here before anything else).
Codes.MAX_INPUT = 64

local function own_list(): { [any]: any }
	local ok, list = pcall(function(): any
		if IS_ROBLOX then
			local m = (script :: any).Parent:FindFirstChild("MyCodes")
			return if m ~= nil then require(m) :: any else nil
		end
		return (require :: any)("./MyCodes")
	end)
	return if ok and type(list) == "table" then list else {}
end

--- The code a text stands for: upper case, no spaces around or inside; nil when it can't be a code.
function Codes.normalize(text: any): string?
	if type(text) ~= "string" or #text > Codes.MAX_INPUT then
		return nil
	end
	local s = string.upper((string.gsub(text, "%s+", "")))
	if #s < Codes.MIN_LEN or #s > Codes.MAX_LEN or string.match(s, "^[A-Z0-9_%-]+$") == nil then
		return nil
	end
	return s
end

--- The last second (UTC, Unix time) of the day "YYYY-MM-DD", or nil when the text is not a date.
function Codes.day_end(text: any): number?
	if type(text) ~= "string" then
		return nil
	end
	local y, m, d = string.match(text, "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	local yn, mn, dn = tonumber(y), tonumber(m), tonumber(d)
	if yn == nil or mn == nil or dn == nil or mn < 1 or mn > 12 or dn < 1 or dn > 31 then
		return nil
	end
	-- days since 1970-01-01 (the civil calendar; no os.time: the server's time zone must not matter)
	local yy = if mn <= 2 then yn - 1 else yn
	local era = yy // 400
	local yoe = yy - era * 400
	local mp = (mn + 9) % 12
	local doy = (153 * mp + 2) // 5 + dn - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	local days = era * 146097 + doe - 719468
	return days * 86400 + 86399
end

local function entry_of(key: any, v: any): ({ [string]: any }?, string?)
	local code = Codes.normalize(key)
	if code == nil then
		return nil, string.format("code %q: 3 to 24 letters, digits, _ or -", tostring(key))
	end
	if type(v) ~= "table" then
		return nil, code .. ": the line must be { coroas = <number> }"
	end
	local stars = tonumber(v.coroas or v.stars)
	if stars == nil or stars ~= stars or stars < 1 or stars % 1 ~= 0 or stars > Codes.MAX_STARS then
		return nil, code .. ": coroas must be a whole number from 1 to " .. tostring(Codes.MAX_STARS)
	end
	local expires: number? = nil
	local date = v.expira or v.expires
	if date ~= nil then
		expires = Codes.day_end(date)
		if expires == nil then
			return nil, code .. ': expira must be a date like "2027-01-31"'
		end
	end
	local active = v.ativo ~= false and v.active ~= false
	return { code = code, stars = stars, expires = expires, active = active }, nil
end

--- Every valid entry of the list (the owner's, or `list`), sorted by code.
function Codes.all(list: { [any]: any }?): { { [string]: any } }
	local out = {}
	for k, v in list or own_list() do
		local e = entry_of(k, v)
		if e ~= nil then
			table.insert(out, e)
		end
	end
	table.sort(out, function(a, b)
		return a.code < b.code
	end)
	return out
end

--- What is wrong in the list: one line per bad entry (none: the list is fine).
function Codes.problems(list: { [any]: any }?): { string }
	local out = {}
	local seen: { [string]: boolean } = {}
	for k, v in list or own_list() do
		local e, why = entry_of(k, v)
		if e == nil then
			table.insert(out, why or "?")
		elseif seen[e.code] then
			table.insert(out, e.code .. ": written twice (upper and lower case are the same code)")
		else
			seen[e.code] = true
		end
	end
	table.sort(out)
	return out
end

--- Whether the list has the code `text` stands for, in any state. (A code on this list is this
--- list's alone: server/CodeStore neither creates nor pays one of the same name.)
function Codes.listed(text: any, list: { [any]: any }?): boolean
	local code = Codes.normalize(text)
	if code == nil then
		return false
	end
	for k in list or own_list() do
		if Codes.normalize(k) == code then
			return true
		end
	end
	return false
end

--- The code `text` stands for, when it is on the list and good at `now` (Unix seconds).
function Codes.find(text: any, now: number, list: { [any]: any }?): ({ [string]: any }?, string?)
	local code = Codes.normalize(text)
	if code == nil then
		return nil, "invalid"
	end
	for k, v in list or own_list() do
		if Codes.normalize(k) == code then
			local e = entry_of(k, v)
			if e == nil or not e.active then
				return nil, "invalid"
			end
			if e.expires ~= nil and now > e.expires then
				return nil, "expired"
			end
			return e, nil
		end
	end
	return nil, "invalid"
end

return Codes
