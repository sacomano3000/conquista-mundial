--!strict
-- Missions and the monthly PASS (2026-11-12; the lobby's MISSÕES button, client/UI/Missions).
--
--   Daily missions   free, for everyone: DAILY_COUNT of Data/MyMissions.diarias a day (the same ones
--                    for every player, picked by the day's number), each paying Coroas the moment its
--                    goal is reached. A new day starts at midnight in Brasília (TZ_S).
--   The pass         a developer product (Data/Products.pass) bought for ONE calendar month (Brasília
--                    time): it pays the rewards of the monthly missions (Data/MyMissions.mensais):
--                    Coroas, and the season's skin, flag and pet (Assets/Seasons: one season for each
--                    month of the year). Monthly progress counts for everyone from the 1st; whoever
--                    buys the pass later is paid at once for the ones already done. On the 1st the
--                    progress, the list and the pass start again; what was given stays.
--
-- The state kept for a player (server/Purchases, in their record; the client gets a copy with the
-- server's clock, Session.inventory.missions):
--   { day, d = { counter = n }, dp = { id = true },      today's counters and the dailies paid
--     month, m = { counter = n }, mp = { id = true },    this month's, and the monthly ones paid
--     pass = the month the pass was bought for (Missions.month), or nil }
-- A state of another day or month is an empty one (Missions.roll).
--
--   Missions.day(t), month(t), day_end(t), month_end(t)   t = unix seconds
--   Missions.daily(day) -> { Def }      Missions.monthly() -> { Def }
--   Missions.season(month) -> { key, name, color, skin = id, flag = id, pet = id }
--   Missions.deltas(result, first) -> { counter = n }   what a match's result (Data/Stars) adds
--   Missions.add(state, t, deltas)                      counts them (rolls first)
--   Missions.settle(state, t, owned) -> { stars, items = { id }, done = { { id, stars?, item? } } }
--                                                       marks what is due as paid
--   Missions.view(state, t) -> what the window draws
local IS_ROBLOX = typeof(game) == "Instance"
local function data(name: string): any
	if IS_ROBLOX then
		return require((script :: any).Parent[name]) :: any
	end
	return (require :: any)("./" .. name)
end
local function asset(name: string): any
	if IS_ROBLOX then
		return require((script :: any).Parent.Parent.Assets[name]) :: any
	end
	return (require :: any)("../Assets/" .. name)
end
local Mine: any = data("MyMissions")
local Seasons: any = asset("Seasons")

local Missions = {}

--- The clock the days and months turn by: Brasília, UTC-3 all year (no daylight saving since 2019).
Missions.TZ_S = -3 * 3600
--- The developer product's key (Data/Products, Data/MyProducts).
Missions.PRODUCT = "pass"
--- What a mission can count.
Missions.COUNTERS = { "played", "wins", "kills", "minutes", "top3", "daily" }
--- Data/MyMissions' words for them.
Missions.COUNTER_PT = { partidas = "played", vitorias = "wins", reinos = "kills", minutos = "minutes", top3 = "top3", diarias = "daily" }
--- ... and for a monthly mission's item.
Missions.KIND_PT = { skin = "skin", bandeira = "flag", pet = "pet", flag = "flag" }
--- "Top 3" needs a field of at least this many nations and players.
Missions.TOP3_FIELD = 4
--- No counter goes past this.
Missions.MAX_COUNT = 1000000
--- The months' names (the window's title of the season).
Missions.MONTHS = { "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro" }

export type Def = { id: string, counter: string, goal: number, stars: number, kind: string?, text: string }
export type State = {
	day: number,
	d: { [string]: number },
	dp: { [string]: boolean },
	month: number,
	m: { [string]: number },
	mp: { [string]: boolean },
	pass: number?,
}

local function whole(v: any, lo: number, hi: number, default: number): number
	local n = tonumber(v)
	if n == nil or n ~= n then
		return default
	end
	return math.clamp(math.floor(n), lo, hi)
end

-- ---------------------------------------------------------------------------------------------
-- The calendar (whole-number arithmetic: nothing here depends on the machine's time zone)
-- ---------------------------------------------------------------------------------------------

--- Days since 1970-01-01 -> year, month, day.
local function civil(days: number): (number, number, number)
	local z = days + 719468
	local era = (if z >= 0 then z else z - 146096) // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local y = yoe + era * 400
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local d = doy - (153 * mp + 2) // 5 + 1
	local m = if mp < 10 then mp + 3 else mp - 9
	return (if m <= 2 then y + 1 else y), m, d
end

--- year, month, day -> days since 1970-01-01.
local function days_of(y: number, m: number, d: number): number
	local yy = if m <= 2 then y - 1 else y
	local era = (if yy >= 0 then yy else yy - 399) // 400
	local yoe = yy - era * 400
	local doy = (153 * (if m > 2 then m - 3 else m + 9) + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end
Missions.civil = civil
Missions.days_of = days_of

--- The day of unix time `t` (a number that grows by one at every midnight of Brasília).
function Missions.day(t: number): number
	return (math.floor(t) + Missions.TZ_S) // 86400
end

--- The month of unix time `t`: year * 12 + (month - 1).
function Missions.month(t: number): number
	local y, m = civil(Missions.day(t))
	return y * 12 + (m - 1)
end

--- A month's (year, month 1..12).
function Missions.year_month(month: number): (number, number)
	return month // 12, month % 12 + 1
end

--- The unix time at which the day of `t` ends.
function Missions.day_end(t: number): number
	return (Missions.day(t) + 1) * 86400 - Missions.TZ_S
end

--- The unix time at which the month of `t` ends.
function Missions.month_end(t: number): number
	local y, m = Missions.year_month(Missions.month(t) + 1)
	return days_of(y, m, 1) * 86400 - Missions.TZ_S
end

-- ---------------------------------------------------------------------------------------------
-- The missions (Data/MyMissions) and the seasons (Assets/Seasons)
-- ---------------------------------------------------------------------------------------------

local function id_ok(id: any): boolean
	return type(id) == "string" and #id >= 1 and #id <= 24 and string.match(id, "^[%w_]+$") ~= nil
end

local function defs_of(list: any, monthly: boolean): { Def }
	local out: { Def } = {}
	local seen: { [string]: boolean } = {}
	for _, v in (if type(list) == "table" then list else {}) :: { any } do
		if type(v) ~= "table" or not id_ok(v.id) or seen[v.id] then
			continue
		end
		local counter = Missions.COUNTER_PT[v.contar]
		local goal = whole(v.meta, 1, Missions.MAX_COUNT, 0)
		local kind = if monthly then Missions.KIND_PT[v.premio] else nil
		local stars = whole(v.coroas, 0, 10000000, 0)
		if counter == nil or goal < 1 or (kind == nil and stars < 1) or (counter == "daily" and not monthly) then
			continue
		end
		seen[v.id] = true
		local text = if type(v.texto) == "string" and v.texto ~= "" then v.texto else v.id
		local ok, made = pcall(string.format, text, goal)
		table.insert(out, {
			id = v.id,
			counter = counter,
			goal = goal,
			stars = if kind ~= nil then 0 else stars,
			kind = kind,
			text = if ok then made else text,
		})
	end
	return out
end

local POOL: { Def } = defs_of(Mine.diarias, false)
local MONTHLY: { Def } = defs_of(Mine.mensais, true)

--- How many daily missions a day has.
Missions.DAILY_COUNT = whole(Mine.por_dia, 1, 6, 3)
--- A match counts as played after this many minutes in it.
Missions.MIN_MINUTES = math.clamp(tonumber(Mine.minutos_minimos) or 2, 0, 60)
--- Coroas in place of a season's item the player already owns.
Missions.DUPLICATE_STARS = whole(Mine.coroas_item_repetido, 0, 10000000, 8000)

--- Every daily mission there is (the day's ones are picked from these).
function Missions.pool(): { Def }
	return POOL
end

local daily_cache: { [number]: { Def } } = {}

--- The missions of day `day`: the same for everyone, no two counting the same thing while the list
--- has enough different ones.
function Missions.daily(day: number): { Def }
	local got = daily_cache[day]
	if got ~= nil then
		return got
	end
	local order = table.clone(POOL)
	-- (a small generator seeded by the day: the same answer on the server and on every client)
	local x = (day * 2654435761 + 40503) % 2147483648
	local function nextn(n: number): number
		x = (x * 1103515245 + 12345) % 2147483648
		return (x // 65536) % n + 1
	end
	for i = #order, 2, -1 do
		local j = nextn(i)
		order[i], order[j] = order[j], order[i]
	end
	local out: { Def } = {}
	local used: { [string]: boolean } = {}
	for _, def in order do
		if #out < Missions.DAILY_COUNT and not used[def.counter] then
			used[def.counter] = true
			table.insert(out, def)
		end
	end
	for _, def in order do
		if #out < Missions.DAILY_COUNT and not table.find(out, def) then
			table.insert(out, def)
		end
	end
	-- (a short memory: the server meets one new day a day)
	local n = 0
	for _ in daily_cache do
		n += 1
	end
	if n > 8 then
		table.clear(daily_cache)
	end
	daily_cache[day] = out
	return out
end

--- The pass's missions (the same list every month; the season changes what the items are).
function Missions.monthly(): { Def }
	return MONTHLY
end

local by_month: { [number]: any } = {}
for _, s in (Seasons.seasons or {}) :: { any } do
	by_month[s.month] = {
		key = s.key,
		name = s.name,
		color = s.color,
		skin = "skin_passe_" .. s.key,
		flag = "flag_passe_" .. s.key,
		pet = "pet_passe_" .. s.key,
	}
end

--- The season of `month` (Missions.month): its name, colour and the ids of its three items.
function Missions.season(month: number): any
	local _, m = Missions.year_month(month)
	return by_month[m] or by_month[1]
end

--- "Novembro de 2026".
function Missions.month_name(month: number): string
	local y, m = Missions.year_month(month)
	return string.format("%s de %d", Missions.MONTHS[m], y)
end

-- ---------------------------------------------------------------------------------------------
-- A player's state
-- ---------------------------------------------------------------------------------------------

local function counters(v: any): { [string]: number }
	local out: { [string]: number } = {}
	if type(v) == "table" then
		for _, c in Missions.COUNTERS do
			local n = tonumber(v[c])
			if n ~= nil and n == n and n > 0 then
				-- (minutes keep one decimal; the rest are whole)
				out[c] = math.min(math.floor(n * 10 + 0.5) / 10, Missions.MAX_COUNT)
			end
		end
	end
	return out
end

local function id_set(v: any): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local n = 0
	if type(v) == "table" then
		for k, on in v do
			-- (a set { id = true }, or a list of ids)
			local id = if type(k) == "string" and on == true then k elseif type(on) == "string" then on else nil
			if id_ok(id) and n < 64 then
				out[id :: string] = true
				n += 1
			end
		end
	end
	return out
end

--- A state made safe: whatever `v` is (a stored one, the client's copy, nothing).
function Missions.clean(v: any): State
	local t = if type(v) == "table" then v else {}
	local pass = tonumber(t.pass)
	return {
		day = whole(t.day, 0, 10000000, 0),
		d = counters(t.d),
		dp = id_set(t.dp),
		month = whole(t.month, 0, 10000000, 0),
		m = counters(t.m),
		mp = id_set(t.mp),
		pass = if pass ~= nil and pass == pass and pass > 0 then math.floor(pass) else nil,
	}
end

--- Starts the day and the month of `t` in `st` when it is of an earlier one. Returns `st`.
function Missions.roll(st: State, t: number): State
	local day, month = Missions.day(t), Missions.month(t)
	if st.day ~= day then
		st.day = day
		st.d = {}
		st.dp = {}
	end
	if st.month ~= month then
		st.month = month
		st.m = {}
		st.mp = {}
	end
	return st
end

--- Whether the pass is on at `t`.
function Missions.has_pass(st: State, t: number): boolean
	return st.pass ~= nil and st.pass == Missions.month(t)
end

--- What a match's result (Data/Stars' Result) adds to the counters. `first`: the match's first result
--- (a takeover gives a match more lives, and more results: it is still one match).
function Missions.deltas(result: any, first: boolean?): { [string]: number }
	local out: { [string]: number } = {}
	if type(result) ~= "table" or result.spawned ~= true then
		return out
	end
	local minutes = math.clamp(tonumber(result.minutes) or 0, 0, 240)
	local field = tonumber(result.field) or 1
	local place = tonumber(result.place) or field
	if minutes > 0 then
		out.minutes = math.floor(minutes * 10 + 0.5) / 10
	end
	if first ~= false and minutes >= Missions.MIN_MINUTES then
		out.played = 1
	end
	local kills = whole(result.kills, 0, 200, 0)
	if kills > 0 then
		out.kills = kills
	end
	if result.won == true and result.left ~= true then
		out.wins = 1
	end
	if result.left ~= true and field >= Missions.TOP3_FIELD and place <= 3 then
		out.top3 = 1
	end
	return out
end

--- Counts `deltas` in the day and the month of `t`.
function Missions.add(st: State, t: number, deltas: { [string]: number })
	Missions.roll(st, t)
	for c, n in deltas do
		if n > 0 and table.find(Missions.COUNTERS, c) ~= nil then
			st.d[c] = math.min((st.d[c] or 0) + n, Missions.MAX_COUNT)
			st.m[c] = math.min((st.m[c] or 0) + n, Missions.MAX_COUNT)
		end
	end
end

--- Pays what is due and not paid yet: every daily mission of today whose goal is reached, and, with
--- the pass on, every monthly one. Marks them paid in `st` and returns what to give: Coroas, the ids of
--- the season's items (one the player already owns, by `owned`, turns into DUPLICATE_STARS), and the
--- list of what was paid.
function Missions.settle(st: State, t: number, owned: { [string]: any }?): { stars: number, items: { string }, done: { any } }
	Missions.roll(st, t)
	local out = { stars = 0, items = {} :: { string }, done = {} :: { any } }
	for _, def in Missions.daily(st.day) do
		if not st.dp[def.id] and (st.d[def.counter] or 0) >= def.goal then
			st.dp[def.id] = true
			st.m.daily = math.min((st.m.daily or 0) + 1, Missions.MAX_COUNT)
			out.stars += def.stars
			table.insert(out.done, { id = def.id, stars = def.stars })
		end
	end
	if Missions.has_pass(st, t) then
		local season = Missions.season(st.month)
		for _, def in MONTHLY do
			if not st.mp[def.id] and (st.m[def.counter] or 0) >= def.goal then
				st.mp[def.id] = true
				local item: string? = if def.kind ~= nil and season ~= nil then season[def.kind] else nil
				if def.kind == nil then
					out.stars += def.stars
					table.insert(out.done, { id = def.id, stars = def.stars })
				elseif item ~= nil and not (owned ~= nil and owned[item] == true) and not table.find(out.items, item) then
					table.insert(out.items, item)
					table.insert(out.done, { id = def.id, item = item })
				else
					out.stars += Missions.DUPLICATE_STARS
					table.insert(out.done, { id = def.id, stars = Missions.DUPLICATE_STARS })
				end
			end
		end
	end
	return out
end

--- What the window draws at `t`, from a state (not changed): the day's and the month's lists with
--- how far each mission is, whether the pass is on, and how long the day and the month still last.
function Missions.view(v: any, t: number): any
	local st = Missions.roll(Missions.clean(v), t)
	local pass = Missions.has_pass(st, t)
	local season = Missions.season(st.month)
	local daily, monthly = {}, {}
	for _, def in Missions.daily(st.day) do
		local have = math.min(math.floor(st.d[def.counter] or 0), def.goal)
		table.insert(daily, {
			id = def.id,
			text = def.text,
			have = if st.dp[def.id] then def.goal else have,
			goal = def.goal,
			stars = def.stars,
			done = st.dp[def.id] == true or have >= def.goal,
			paid = st.dp[def.id] == true,
		})
	end
	for _, def in MONTHLY do
		local have = math.min(math.floor(st.m[def.counter] or 0), def.goal)
		table.insert(monthly, {
			id = def.id,
			text = def.text,
			have = if st.mp[def.id] then def.goal else have,
			goal = def.goal,
			stars = def.stars,
			kind = def.kind,
			item = if def.kind ~= nil and season ~= nil then season[def.kind] else nil,
			done = st.mp[def.id] == true or have >= def.goal,
			paid = st.mp[def.id] == true,
		})
	end
	return {
		day = st.day,
		month = st.month,
		pass = pass,
		season = season,
		daily = daily,
		monthly = monthly,
		day_left = math.max(0, Missions.day_end(t) - t),
		month_left = math.max(0, Missions.month_end(t) - t),
	}
end

--- "5h 12min", "12 dias", "1 dia", "45min": how long `seconds` is, for the window's countdowns.
function Missions.span(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	if s >= 2 * 86400 then
		return string.format("%d dias", s // 86400)
	elseif s >= 86400 then
		return string.format("1 dia %dh", (s - 86400) // 3600)
	elseif s >= 3600 then
		return string.format("%dh %02dmin", s // 3600, (s % 3600) // 60)
	end
	return string.format("%dmin", math.max(1, (s + 59) // 60))
end

return Missions
