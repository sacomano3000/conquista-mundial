--!strict
-- Redeem codes the owner creates while the game runs (chat: "/codigo criar NATAL 5000"; server/
-- CodeCommands). They live in one DataStore key, so every server of the game has them and nothing
-- has to be published. The list in the place file (server/MyCodes) keeps working beside them; a name
-- on that list can't be created here.
--
-- No Roblox API (tests/gerar_codigos.luau): ServerMain gives the store.
--   CodeStore.configure(deps)     { store = { GetAsync, UpdateAsync }, clock = fn() -> seconds?, log = fn(text)?,
--                                   fixed = the place's own list (tests; nil: server/MyCodes) }
--   CodeStore.list()              -> ({ entry } sorted by code, read)     `read` false: the store never answered
--   CodeStore.find(text, now)     -> (entry) or (nil, "invalid" | "expired" | "spent" | "store")
--   CodeStore.create(code, stars, expires?, uses?, by?, now?) -> (entry) or (nil, "bad" | "exists" | "full" | "store")
--   CodeStore.switch(code, on)    -> (entry) or (nil, "missing" | "store")
--   CodeStore.remove(code)        -> (entry) or (nil, "missing" | "store")
--   CodeStore.reserve(code, now)  -> (true) or (false, "invalid" | "expired" | "spent" | "store")
--   CodeStore.release(code)       gives back what reserve took (the code did not pay after all)
--
--   entry = { code, stars, expires = Unix s?, active, uses = number?, used = number, made = Unix s?, by = user id? }
--
-- `uses`: how many players in all may redeem the code (nil: no limit). Only a code with a limit
-- counts its redemptions: each one is a write to the shared key (reserve) before the player is paid,
-- so a code for 100 players pays 100 players, whatever server they are on. A code without a limit
-- costs no write here: Purchases marks it in the player's own record, as it does for server/MyCodes.
--
-- Every call here except `configure` and `reset` may yield.
local IS_ROBLOX = typeof(game) == "Instance"
local Codes: any = if IS_ROBLOX then require((script :: any).Parent.Codes) else require("./Codes")

local CodeStore = {}

--- The DataStore (ServerMain adds "_studio" in a Studio playtest, as it does for the players' records).
CodeStore.STORE = "ConquistaMundialCodigos_v1"
--- The one key that holds every code.
CodeStore.KEY = "codes"
--- How old this server's copy may get before it is read again: a code created, switched off or
--- deleted on another server is known here within this.
CodeStore.REFRESH_S = 60
--- A code this server does not know is looked for in the store again, at most once in this long
--- (a code the owner has just announced must work at once; guessing must not cost a read each time).
CodeStore.MISS_REFRESH_S = 15
--- After a read that failed, the store is left alone this long (an outage must not be met with a
--- read for every code typed).
CodeStore.RETRY_S = 5
--- The most codes kept (the key is one value of at most 4 MB; a code is about 100 bytes).
CodeStore.MAX_CODES = 300
--- The most players one limited code can be for.
CodeStore.MAX_USES = 10000000

local deps: { [string]: any } = {}
--- code -> entry, as last read or written
local cached: { [string]: { [string]: any } } = {}
--- when `cached` was read or written (deps.clock seconds); nil: never
local read_at: number? = nil
--- when a code this server does not know last made it read the store
local miss_at: number? = nil
--- when a read last failed
local fail_at: number? = nil

function CodeStore.configure(d: { [string]: any })
	for k, v in d do
		deps[k] = v
	end
end

--- Tests: forget the copy (the store itself is the test's).
function CodeStore.reset()
	table.clear(deps)
	table.clear(cached)
	read_at = nil
	miss_at = nil
	fail_at = nil
end

local function clock(): number
	return if type(deps.clock) == "function" then deps.clock() else os.clock()
end

local function log(text: string)
	if type(deps.log) == "function" then
		pcall(deps.log, "[Codes] " .. text)
	end
end

local function whole(x: any, lo: number, hi: number): number?
	local n = tonumber(x)
	if n == nil or n ~= n or n % 1 ~= 0 or n < lo or n > hi then
		return nil
	end
	return n
end

--- One stored code as an entry, or nil when it is not one (a value someone edited by hand).
local function entry_of(code: any, v: any): { [string]: any }?
	if type(code) ~= "string" or Codes.normalize(code) ~= code or type(v) ~= "table" then
		return nil
	end
	local stars = whole(v.stars, 1, Codes.MAX_STARS)
	if stars == nil then
		return nil
	end
	local uses = if v.uses ~= nil then whole(v.uses, 1, CodeStore.MAX_USES) else nil
	if v.uses ~= nil and uses == nil then
		return nil
	end
	return {
		code = code,
		stars = stars,
		expires = if v.expires ~= nil then whole(v.expires, 0, 2 ^ 40) else nil,
		active = v.active ~= false,
		uses = uses,
		used = whole(v.used, 0, 2 ^ 40) or 0,
		made = whole(v.made, 0, 2 ^ 40),
		by = whole(v.by, 1, 2 ^ 53),
	}
end

--- The stored value as { code -> entry }.
local function clean(v: any): { [string]: { [string]: any } }
	local out = {}
	if type(v) == "table" and type(v.codes) == "table" then
		for code, raw in v.codes do
			local e = entry_of(code, raw)
			if e ~= nil then
				out[e.code] = e
			end
		end
	end
	return out
end

local function count(t: { [string]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function keep(codes: { [string]: { [string]: any } })
	cached = codes
	read_at = clock()
end

--- Reads the store when this server's copy is older than `max_age` seconds. False: the read failed
--- (the copy is what it was).
local function refresh(max_age: number): boolean
	if read_at ~= nil and clock() - read_at < max_age then
		return true
	end
	local store = deps.store
	if store == nil then
		return false
	end
	local t = clock()
	if fail_at ~= nil and t - fail_at < CodeStore.RETRY_S then
		return false
	end
	local ok, v = pcall(function(): any
		return store:GetAsync(CodeStore.KEY)
	end)
	if not ok then
		fail_at = clock()
		log("the codes could not be read: " .. tostring(v))
		return false
	end
	fail_at = nil
	keep(clean(v))
	return true
end

--- One write to the key. `change(codes)` edits the list it is given and returns nil to store it, or
--- the reason nothing is to be stored. -> (true) or (false, that reason or "store").
local function write(change: (codes: { [string]: { [string]: any } }) -> string?): (boolean, string?)
	local store = deps.store
	if store == nil then
		return false, "store"
	end
	local why: string? = nil
	local latest: { [string]: { [string]: any } }? = nil
	local ok, err = pcall(function()
		store:UpdateAsync(CodeStore.KEY, function(old: any): any
			-- (UpdateAsync may call this more than once: every call starts from what is stored)
			local codes = clean(old)
			why = change(codes)
			latest = codes
			if why ~= nil then
				return nil
			end
			return { v = 1, codes = codes }
		end)
	end)
	if not ok then
		log("the codes could not be written: " .. tostring(err))
		return false, "store"
	end
	if latest ~= nil then
		-- (a refused change still read the store: what it saw is the newest copy there is)
		keep(latest)
	end
	if why ~= nil then
		return false, why
	end
	return true, nil
end

--- Every created code, sorted by name. `read` false: the store never answered, the list is empty.
function CodeStore.list(): ({ { [string]: any } }, boolean)
	refresh(CodeStore.REFRESH_S)
	local out = {}
	for _, e in cached do
		table.insert(out, table.clone(e))
	end
	table.sort(out, function(a, b)
		return a.code < b.code
	end)
	return out, read_at ~= nil
end

--- Why `e` pays nothing at `now`, or nil when it pays.
local function bad_at(e: { [string]: any }, now: number): string?
	if not e.active then
		return "invalid"
	end
	if e.expires ~= nil and now > e.expires then
		return "expired"
	end
	if e.uses ~= nil and e.used >= e.uses then
		return "spent"
	end
	return nil
end

--- The created code `text` stands for, when it is good at `now` (Unix seconds).
function CodeStore.find(text: any, now: number): ({ [string]: any }?, string?)
	local code = Codes.normalize(text)
	if code == nil then
		return nil, "invalid"
	end
	refresh(CodeStore.REFRESH_S)
	if cached[code] == nil then
		-- maybe created a moment ago on another server
		local t = clock()
		if (read_at == nil or t - read_at >= CodeStore.MISS_REFRESH_S)
			and (miss_at == nil or t - miss_at >= CodeStore.MISS_REFRESH_S)
		then
			miss_at = t
			refresh(0)
		end
	end
	if read_at == nil then
		return nil, "store"
	end
	local e = cached[code]
	if e == nil then
		return nil, "invalid"
	end
	local bad = bad_at(e, now)
	if bad ~= nil then
		return nil, bad
	end
	return table.clone(e), nil
end

--- A new code. `expires`: the last Unix second it is good (nil: no end). `uses`: how many players
--- in all (nil: no limit). "exists": the name is taken (here, or on the place's own list).
function CodeStore.create(
	code: any,
	stars: any,
	expires: any,
	uses: any,
	by: any,
	now: number?
): ({ [string]: any }?, string?)
	local name = Codes.normalize(code)
	local e = if name ~= nil
		then entry_of(name, { stars = stars, expires = expires, uses = uses, used = 0, made = now, by = by })
		else nil
	if e == nil or (expires ~= nil and e.expires == nil) then
		return nil, "bad"
	end
	if Codes.listed(name, deps.fixed) then
		return nil, "exists"
	end
	local ok, why = write(function(codes): string?
		if codes[e.code] ~= nil then
			return "exists"
		end
		if count(codes) >= CodeStore.MAX_CODES then
			return "full"
		end
		codes[e.code] = e
		return nil
	end)
	if not ok then
		return nil, why
	end
	log(string.format("%s created: %d Stars (by %s)", e.code, e.stars, tostring(by)))
	return table.clone(e), nil
end

--- Switches a code on or off (off: it pays nobody, and can be switched on again).
function CodeStore.switch(code: any, on: boolean): ({ [string]: any }?, string?)
	local name = Codes.normalize(code)
	if name == nil then
		return nil, "missing"
	end
	local ok, why = write(function(codes): string?
		local e = codes[name]
		if e == nil then
			return "missing"
		end
		e.active = on == true
		return nil
	end)
	if not ok then
		return nil, why
	end
	log(string.format("%s switched %s", name, if on then "on" else "off"))
	return table.clone(cached[name]), nil
end

--- Deletes a code. Who has used it keeps what it paid (and its mark: the same name created again
--- pays them nothing).
function CodeStore.remove(code: any): ({ [string]: any }?, string?)
	local name = Codes.normalize(code)
	if name == nil then
		return nil, "missing"
	end
	local gone: { [string]: any }? = nil
	local ok, why = write(function(codes): string?
		gone = codes[name]
		if gone == nil then
			return "missing"
		end
		codes[name] = nil
		return nil
	end)
	if not ok then
		return nil, why
	end
	log(name .. " deleted")
	return gone, nil
end

--- Takes one of a limited code's uses, before the player is paid. A code with no limit takes
--- nothing and writes nothing.
function CodeStore.reserve(code: any, now: number): (boolean, string?)
	local name = Codes.normalize(code)
	if name == nil then
		return false, "invalid"
	end
	local known = cached[name]
	if known ~= nil and known.uses == nil then
		local bad = bad_at(known, now)
		return bad == nil, bad
	end
	return write(function(codes): string?
		local e = codes[name]
		if e == nil then
			return "invalid"
		end
		local bad = bad_at(e, now)
		if bad ~= nil then
			return bad
		end
		if e.uses ~= nil then
			e.used += 1
		end
		return nil
	end)
end

--- Gives back a use `reserve` took. True when it is back (or there was nothing to give back).
function CodeStore.release(code: any): boolean
	local name = Codes.normalize(code)
	if name == nil then
		return true
	end
	local ok, why = write(function(codes): string?
		local e = codes[name]
		if e == nil or e.uses == nil or e.used < 1 then
			return "nothing"
		end
		e.used -= 1
		return nil
	end)
	if not ok and why == "store" then
		log(name .. ": one use was taken and could not be given back")
		return false
	end
	return true
end

return CodeStore
