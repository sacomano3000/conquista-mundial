--!strict
-- The global ranking (the lobby's RANK button; UI/Ranking): two boards, every server of the game
-- reading and writing the same two ordered stores.
--
--   wins    public matches won
--   kills   nations and players conquered in public matches (the match's own count, the one its
--           "Nations conquered" line pays: bots count, tribes don't)
--
-- Only a result this server measured itself is counted (MatchServer's on_result, a public match). A
-- solo match runs on the player's device and its result is the client's word: it never gets here.
--
--   Ranking.configure(deps)          { store = fn(board) -> ordered store (IncrementAsync, GetAsync,
--                                      GetSortedAsync, RemoveAsync), names = fn({ user id }) -> { [user id] =
--                                      name } (yields; may fail), now = fn() -> s, wait = fn(s)?,
--                                      online = fn(user id) -> boolean?, log?, warn? }
--   Ranking.record(user_id, result, name?)   a public match's result (shared/Data/Stars.Result);
--                                            yields; -> true when everything it had to add landed
--   Ranking.get(player) -> payload           what OP.RANK carries (yields the first time, and when
--                                            a list is older than REFRESH_S)
--   Ranking.release(user_id)                 PlayerRemoving
--   Ranking.settle(max_s)                    waits for the additions still on their way (BindToClose)
--
-- The payload: { ok = boolean, age = s, boards = { wins = { { uid, name, value } ... }, kills = ... },
--                me = { wins = { value, place? }, kills = { value, place? } } }
-- `place` only when the player is in the list (the stores can't say where anyone else stands).
--
-- A list is read at most once every REFRESH_S on each server (GetSortedAsync is the scarcest of the
-- store's requests), so a list can be that old; the player's own totals are read fresh and put into
-- the list this server holds, so nobody sees their own row behind their own numbers.
--
-- THE WEEKLY LISTS (2026-11-12; shared/Data/RankPrizes has the calendar and the prizes). Each board
-- has a twin that starts empty every Monday 00:00, Brasília time: "wins_w" and "kills_w" here and in
-- the payload, kept in ordered stores of their own with the week's number in the name. A result is
-- added to the all-time board and to the week's.
--
--   Ranking.week() -> n                      the week now
--   Ranking.final(week) -> { wins = { { uid, value } ... }, kills = ... }?   a closed week's best
--                                            (RankPrizes.COROAS places), read once per server; nil
--                                            when the store failed
--   Ranking.due(user_id, settled?) -> upto?, results?   what the closed weeks after `settled` owe
--                                            this player: { { week, wins = place?, kills = place?,
--                                            stars } } (only weeks with a prize). nil: not now (the
--                                            week closed a moment ago, or the store failed)
--
-- The payload gains boards.wins_w / kills_w, me.wins_w / kills_w and week = { n, left = seconds }.
-- Ranking.WEEKLY_ON = false: no weekly stores are read or written, and the payload has none of it.
local RankPrizes: any = if typeof(game) == "Instance"
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data.RankPrizes)
	else (require :: any)("../shared/Data/RankPrizes")

local Ranking = {}

Ranking.BOARDS = { "wins", "kills" }
--- The weekly lists: on or off, each board's weekly twin, and the stores' names (the week's number
--- is added: "RankSemVitorias_v1_2966"; a "_studio" twin for Studio playtests: ServerMain).
Ranking.WEEKLY_ON = true
Ranking.WEEKLY = { wins = "wins_w", kills = "kills_w" }
--- Last week's final lists, as the RANK window gets them (its "champions": the prized places)
Ranking.LAST = { wins = "wins_l", kills = "kills_l" }
Ranking.WEEK_STORES = { wins = "RankSemVitorias_v1", kills = "RankSemReinos_v1" }
--- A closed week is paid only this long after it closed (a match that ended on the stroke of
--- midnight may still be on its way to the store), seconds.
Ranking.SETTLE_DELAY_S = 600
--- How many closed weeks back a player's prizes are still looked for (as long as they can be
--- claimed: Data/RankPrizes.CLAIM_WEEKS).
Ranking.BACK_WEEKS = RankPrizes.CLAIM_WEEKS
--- The ordered stores' names (a "_studio" twin for Studio playtests: ServerMain).
Ranking.STORES = { wins = "RankVitorias_v1", kills = "RankReinos_v1" }
--- Rows of a list (one page of an ordered store: at most 100).
Ranking.TOP = 100
--- How long a list read from the store is shown before it is read again, seconds.
Ranking.REFRESH_S = 120
--- After a read that failed: not again before this, seconds.
Ranking.FAIL_S = 30
--- A player's own totals are read again at most this often, seconds.
Ranking.MINE_S = 60
--- The waits before each new try of an addition (a match's result must not be lost to a busy store).
Ranking.RETRY_S = { 2, 5, 10 }
--- The most one result may add (Stars.MAX_KILLS: a match has no more nations than that).
Ranking.MAX_KILLS = 200
--- Names remembered by this server (every list's rows; cleared when it grows past this).
Ranking.MAX_NAMES = 2000

type Row = { any } -- { uid: number, name: string, value: number }
type List = { rows: { Row }, at: number, tried: number, ok: boolean, busy: boolean }
type Mine = { [string]: number } -- one total per board ("wins", "kills", "wins_w", "kills_w"), and `at`

local deps: { [string]: any } = {}
local lists: { [string]: List } = {}
local mine: { [number]: Mine } = {}
local names: { [number]: string } = {}
local name_count = 0
local pending = 0
--- the week the weekly lists and totals in memory belong to
local cur_week: number? = nil
--- week -> its final lists (Ranking.final), and the weeks being read
local finals: { [number]: any } = {}
local final_busy: { [number]: boolean } = {}
--- week -> when its final lists were last asked for and the store failed
local final_failed: { [number]: number } = {}

function Ranking.configure(d: { [string]: any })
	for k, v in d do
		deps[k] = v
	end
end

--- Tests: forget everything.
function Ranking.reset()
	table.clear(lists)
	table.clear(mine)
	table.clear(names)
	name_count = 0
	pending = 0
	cur_week = nil
	table.clear(finals)
	table.clear(final_busy)
	table.clear(final_failed)
end

local function now(): number
	return if deps.now then deps.now() else os.clock()
end

local function note(text: string)
	if deps.warn then
		deps.warn("[Ranking] " .. text)
	end
end

--- The calendar's clock: unix seconds (`now` only measures waits).
local function time_s(): number
	return if deps.time then deps.time() else os.time()
end

--- The week now.
function Ranking.week(): number
	return RankPrizes.week(time_s())
end

--- Every board in use: the all-time ones, then their weekly twins.
local function boards(): { string }
	local out = table.clone(Ranking.BOARDS)
	if Ranking.WEEKLY_ON then
		for _, b in Ranking.BOARDS do
			table.insert(out, Ranking.WEEKLY[b])
		end
	end
	return out
end

--- board -> the all-time board it is the weekly twin of
local function weekly_base(board: string): string?
	for base, w in Ranking.WEEKLY do
		if w == board then
			return base
		end
	end
	return nil
end

--- A new week: the weekly lists and totals this server holds belong to the one before.
local function roll()
	if not Ranking.WEEKLY_ON then
		return
	end
	local w = Ranking.week()
	if w == cur_week then
		return
	end
	local first = cur_week == nil
	cur_week = w
	if first then
		return
	end
	for _, b in Ranking.BOARDS do
		lists[Ranking.WEEKLY[b]] = nil
	end
	for _, m in mine do
		for _, b in Ranking.BOARDS do
			m[Ranking.WEEKLY[b]] = 0
		end
		m.at = -math.huge
	end
end

--- A board's store (a weekly board: this week's).
local function store_of(board: string): any
	local base = weekly_base(board)
	if base ~= nil then
		return deps.store(base, cur_week or Ranking.week())
	end
	return deps.store(board)
end

local function list_of(board: string): List
	local l = lists[board]
	if l == nil then
		l = { rows = {}, at = -math.huge, tried = -math.huge, ok = false, busy = false }
		lists[board] = l
	end
	return l
end

local function remember(uid: number, name: any)
	if type(name) ~= "string" or name == "" then
		return
	end
	if names[uid] == nil then
		if name_count >= Ranking.MAX_NAMES then
			table.clear(names)
			name_count = 0
		end
		name_count += 1
	end
	names[uid] = name
end

--- A whole number a store may hold, or nil.
local function whole(v: any): number?
	local n = tonumber(v)
	if n == nil or n ~= n or n < 0 or n == math.huge then
		return nil
	end
	return math.floor(n)
end

--- Puts `uid`'s total into the list this server holds, when it is newer than the list's: its row
--- moves up, or comes in if it now belongs among the rows. A list never read is left alone.
local function merge(board: string, uid: number, value: number)
	local l = lists[board]
	if l == nil or not l.ok or value <= 0 then
		return
	end
	local rows = l.rows
	local at: number? = nil
	for i, r in rows do
		if r[1] == uid then
			at = i
			break
		end
	end
	if at ~= nil then
		if value <= rows[at][3] then
			return
		end
		rows[at][3] = value
	else
		local last = rows[#rows]
		if #rows >= Ranking.TOP and (last == nil or value <= last[3]) then
			return
		end
		local row: Row = { uid :: any, names[uid] or "", value }
		table.insert(rows, row)
		at = #rows
	end
	-- up past every row with less (ties keep the order the store gave)
	local i = at :: number
	while i > 1 and rows[i - 1][3] < rows[i][3] do
		rows[i - 1], rows[i] = rows[i], rows[i - 1]
		i -= 1
	end
	while #rows > Ranking.TOP do
		table.remove(rows)
	end
end

--- Reads a board's list from its store. Yields. False when the store or its answer failed (the list
--- this server has stays as it is).
local function fetch(board: string): boolean
	local l = list_of(board)
	l.busy = true
	l.tried = now()
	local rows: { Row } = {}
	local ok, err = pcall(function()
		local store = store_of(board)
		local pages = store:GetSortedAsync(false, Ranking.TOP)
		for _, e in pages:GetCurrentPage() do
			local uid = tonumber(e.key)
			local value = whole(e.value)
			if uid ~= nil and value ~= nil and value > 0 and #rows < Ranking.TOP then
				local row: Row = { uid :: any, "", value }
				table.insert(rows, row)
			end
		end
	end)
	if not ok then
		l.busy = false
		note(string.format("could not read the %s list (%s)", board, tostring(err)))
		return false
	end
	-- names: the ones this server does not know yet, in one request
	local unknown: { number } = {}
	for _, r in rows do
		if names[r[1]] == nil then
			table.insert(unknown, r[1])
		end
	end
	if #unknown > 0 and deps.names ~= nil then
		local got, res = pcall(deps.names, unknown)
		if got and type(res) == "table" then
			for uid, name in res do
				if type(uid) == "number" then
					remember(uid, name)
				end
			end
		elseif not got then
			note(string.format("could not read %d names (%s)", #unknown, tostring(res)))
		end
	end
	for _, r in rows do
		r[2] = names[r[1]] or ""
	end
	l.rows = rows
	l.at = now()
	l.ok = true
	l.busy = false
	if lists[board] ~= l then
		-- (the week turned while this read was on its way: these rows are last week's)
		return false
	end
	-- what this server knows better than the store's list did a moment ago
	for uid, m in mine do
		merge(board, uid, (m :: any)[board] or 0)
	end
	return true
end

--- The list, read again when it is due. Yields.
local function fresh(board: string): List
	local l = list_of(board)
	if l.busy then
		-- someone else is reading it: wait for that read rather than start another
		local t0 = now()
		while l.busy and deps.wait ~= nil and now() - t0 < 10 do
			deps.wait(0.1)
		end
		return l
	end
	local t = now()
	local stale = not l.ok or t - l.at >= Ranking.REFRESH_S
	-- (after a read that failed, `tried` is later than `at`: the next one waits FAIL_S)
	if stale and (l.tried <= l.at or t - l.tried >= Ranking.FAIL_S) then
		fetch(board)
	end
	return l
end

--- A player's own totals, read from the stores when this server does not have them (or they are
--- old). Yields. nil when a read failed and nothing is known.
local function totals(uid: number): Mine?
	local m = mine[uid]
	local t = now()
	if m ~= nil and t - m.at < Ranking.MINE_S then
		return m
	end
	local got: { [string]: number } = {}
	local week = cur_week
	local ok, err = pcall(function()
		for _, board in boards() do
			got[board] = whole(store_of(board):GetAsync(tostring(uid))) or 0
		end
	end)
	if not ok then
		note(string.format("could not read the totals of %d (%s)", uid, tostring(err)))
		return m
	end
	-- (an addition may have landed while the reads were on their way: never go back)
	local cur = mine[uid]
	local out: Mine = { at = now() }
	for _, board in boards() do
		-- (a weekly total read before the week turned belongs to the week that closed)
		local v = if weekly_base(board) ~= nil and week ~= cur_week then 0 else got[board]
		out[board] = math.max(v, if cur ~= nil then (cur[board] or 0) else 0)
	end
	mine[uid] = out
	return out
end

--- Is this error the store refusing a request for its limits (the request did nothing)?
local function throttled(err: any): boolean
	local s = tostring(err)
	return string.find(s, "Throttled", 1, true) ~= nil
		or string.find(s, "TooManyRequests", 1, true) ~= nil
		or string.find(s, "queue was full", 1, true) ~= nil
		or string.find(s, "request dropped", 1, true) ~= nil
		or string.find(s, "throttl", 1, true) ~= nil
end

--- Adds `delta` to `uid`'s total on a board. Yields. -> the new total, or nil when it was lost.
local function add(board: string, uid: number, delta: number): number?
	local attempt = 1
	while true do
		local ok, res = pcall(function()
			return store_of(board):IncrementAsync(tostring(uid), delta)
		end)
		if ok then
			return whole(res)
		end
		local pause = Ranking.RETRY_S[attempt]
		-- (only a request the store says it dropped is sent again: any other failure may have
		-- landed, and a second one would count the match twice)
		if pause == nil or deps.wait == nil or not throttled(res) then
			note(string.format("%d %s of %d lost (%s)", delta, board, uid, tostring(res)))
			return nil
		end
		attempt += 1
		deps.wait(pause)
	end
end

--- What a result adds to each board: { wins = 0 | 1, kills = n }. Nothing for a player who never
--- spawned; a player who left early keeps the nations they conquered and has no win.
function Ranking.deltas(result: any): { [string]: number }
	if type(result) ~= "table" or result.spawned ~= true then
		return { wins = 0, kills = 0 }
	end
	local k = whole(result.kills) or 0
	return {
		wins = if result.won == true and result.left ~= true then 1 else 0,
		kills = math.min(k, Ranking.MAX_KILLS),
	}
end

--- A public match's result for `user_id` (the player may be gone by the time it lands). Yields.
function Ranking.record(user_id: any, result: any, name: any?): boolean
	local uid = whole(user_id)
	if uid == nil or uid <= 0 or deps.store == nil then
		return false
	end
	remember(uid, name)
	local d = Ranking.deltas(result)
	local all = true
	pending += 1
	roll()
	for _, board in boards() do
		local delta = d[weekly_base(board) or board]
		if delta > 0 then
			local week = cur_week
			local total = add(board, uid, delta)
			if total == nil then
				all = false
			elseif weekly_base(board) == nil or week == cur_week then
				local m = mine[uid]
				if m == nil and (deps.online == nil or deps.online(uid)) then
					-- (the other board's total is not known: read when the player asks. Nothing is
					-- kept for a player who has left: release would never be told again)
					m = { at = -math.huge }
					for _, b in boards() do
						m[b] = 0
					end
					mine[uid] = m
				end
				if m ~= nil then
					(m :: any)[board] = math.max((m :: any)[board] or 0, total)
				end
				merge(board, uid, total)
			end
		end
	end
	pending -= 1
	if deps.log and (d.wins > 0 or d.kills > 0) then
		deps.log(string.format("[Ranking] %d: +%d wins, +%d kills%s", uid, d.wins, d.kills, if all then "" else " (lost in part)"))
	end
	return all
end

--- What the RANK window shows `player` ({ UserId, DisplayName? | Name? }). Yields.
function Ranking.get(player: any): { [string]: any }
	local uid = whole(if type(player) == "table" or typeof(player) == "Instance" then player.UserId else nil) or 0
	if deps.store == nil then
		return Ranking.empty()
	end
	roll()
	if uid > 0 then
		local ok, shown = pcall(function()
			return player.DisplayName or player.Name
		end)
		if ok then
			remember(uid, shown)
		end
	end
	local m = if uid > 0 then totals(uid) else nil
	local out = { ok = true, age = 0, boards = {} :: { [string]: any }, me = {} :: { [string]: any } }
	if Ranking.WEEKLY_ON then
		local w = cur_week or Ranking.week();
		(out :: any).week = { n = w, left = math.max(0, RankPrizes.week_start(w + 1) - time_s()) }
	end
	for _, board in boards() do
		local l = fresh(board)
		if m ~= nil then
			merge(board, uid, (m :: any)[board] or 0)
		end
		if not l.ok then
			out.ok = false
		else
			out.age = math.max(out.age, math.max(0, math.floor(now() - l.at)))
		end
		local rows = table.create(#l.rows)
		local place: number? = nil
		local value = if m ~= nil then ((m :: any)[board] or 0) else 0
		for i, r in l.rows do
			-- (a name learnt since the list was read: a player of this server)
			local name = if r[2] ~= "" then r[2] else (names[r[1]] or "")
			rows[i] = { r[1], name, r[3] }
			if r[1] == uid then
				place = i
				value = math.max(value, r[3])
			end
		end
		out.boards[board] = rows
		out.me[board] = { value, place }
	end
	-- last week's prized places (the window's "champions", and who wears an insignia in its rows)
	if Ranking.WEEKLY_ON then
		local f = Ranking.champions()
		for _, board in Ranking.BOARDS do
			local rows = {}
			local mine_row: { any } = { 0 }
			for i, r in (if f ~= nil then f[board] else {}) do
				rows[i] = { r[1], names[r[1]] or "", r[2] }
				if r[1] == uid then
					mine_row = { r[2], i }
				end
			end
			out.boards[Ranking.LAST[board]] = rows
			out.me[Ranking.LAST[board]] = mine_row
		end
	end
	return out
end

--- Last week's final lists ({ wins = { { uid, value } ... }, kills = ... }: Ranking.final), once they
--- can be trusted (SETTLE_DELAY_S into the new week), with their names learnt. Yields the first
--- time. nil: not yet, no such week, or the store failed.
function Ranking.champions(): any
	if not Ranking.WEEKLY_ON then
		return nil
	end
	local t = time_s()
	local cur = RankPrizes.week(t)
	if cur - 1 < RankPrizes.FIRST_WEEK or t - RankPrizes.week_start(cur) < Ranking.SETTLE_DELAY_S then
		return nil
	end
	local f = Ranking.final(cur - 1)
	if f == nil then
		return nil
	end
	if not f.named then
		f.named = true
		local unknown: { number } = {}
		for _, board in Ranking.BOARDS do
			for _, r in f[board] do
				if names[r[1]] == nil and not table.find(unknown, r[1]) then
					table.insert(unknown, r[1])
				end
			end
		end
		if #unknown > 0 and deps.names ~= nil then
			local got, res = pcall(deps.names, unknown)
			if got and type(res) == "table" then
				for id, name in res do
					if type(id) == "number" then
						remember(id, name)
					end
				end
			else
				f.named = false -- (asked again with the next window)
			end
		end
	end
	return f
end

--- The places `user_id` finished last week in: { wins = place?, kills = place? } (the prized places
--- only), or nil when they are in neither list or nothing can be said now. Yields the first time.
function Ranking.last_places(user_id: any): any
	local uid = whole(user_id)
	local f = if uid ~= nil then Ranking.champions() else nil
	if f == nil then
		return nil
	end
	local out: { [string]: number } = {}
	for _, board in Ranking.BOARDS do
		for place, r in f[board] do
			if r[1] == uid then
				out[board] = place
				break
			end
		end
	end
	return if next(out) ~= nil then out else nil
end

--- The payload of a ranking that could not be read.
function Ranking.empty(): { [string]: any }
	local out = { ok = false, age = 0, boards = {} :: { [string]: any }, me = {} :: { [string]: any } }
	for _, board in boards() do
		out.boards[board] = {}
		out.me[board] = { 0 }
	end
	if Ranking.WEEKLY_ON then
		for _, board in Ranking.BOARDS do
			out.boards[Ranking.LAST[board]] = {}
			out.me[Ranking.LAST[board]] = { 0 }
		end
	end
	return out
end

-- ---------------------------------------------------------------------------------------------
-- A closed week: who finished where, and what that pays
-- ---------------------------------------------------------------------------------------------

--- Week `week`'s best players of each board, as the stores have them: { wins = { { uid, value } ... },
--- kills = ... }, at most #RankPrizes.COROAS rows each. Read once per server (a closed week does not
--- change). Yields. nil when a store failed.
function Ranking.final(week: number): any
	local f = finals[week]
	if f ~= nil then
		return f
	end
	if deps.store == nil then
		return nil
	end
	if final_busy[week] then
		local t0 = now()
		while final_busy[week] and deps.wait ~= nil and now() - t0 < 10 do
			deps.wait(0.1)
		end
		return finals[week]
	end
	-- (a store that just failed is left alone for a while: every player's RANK window asks)
	local failed = final_failed[week]
	if failed ~= nil and now() - failed < Ranking.FAIL_S then
		return nil
	end
	final_busy[week] = true
	local top = math.clamp(#RankPrizes.COROAS, 1, 100)
	local out: { [string]: any } = {}
	local ok, err = pcall(function()
		for _, board in Ranking.BOARDS do
			local rows = {}
			local pages = deps.store(board, week):GetSortedAsync(false, top)
			for _, e in pages:GetCurrentPage() do
				local uid = tonumber(e.key)
				local value = whole(e.value)
				if uid ~= nil and value ~= nil and value > 0 and #rows < top then
					table.insert(rows, { uid, value })
				end
			end
			out[board] = rows
		end
	end)
	final_busy[week] = nil
	if not ok then
		final_failed[week] = now()
		note(string.format("could not read week %d's final lists (%s)", week, tostring(err)))
		return nil
	end
	final_failed[week] = nil
	finals[week] = out
	for w in finals do
		if w < week - Ranking.BACK_WEEKS - 1 then
			finals[w] = nil
		end
	end
	return out
end

--- What the closed weeks owe `user_id`, whose prizes are settled up to week `settled` (nil: never).
--- -> upto (the last closed week), results ({ { week, wins = place?, kills = place?, stars } },
--- oldest first, only the weeks with a prize). Yields the first time a week is looked at.
--- nil: nothing can be said now (the week closed less than SETTLE_DELAY_S ago, or a store failed).
function Ranking.due(user_id: any, settled: number?): (number?, { any }?)
	local uid = whole(user_id)
	if uid == nil or uid <= 0 or not Ranking.WEEKLY_ON then
		return nil, nil
	end
	local t = time_s()
	local cur = RankPrizes.week(t)
	if t - RankPrizes.week_start(cur) < Ranking.SETTLE_DELAY_S then
		return nil, nil
	end
	local upto = cur - 1
	local first = math.max(upto - Ranking.BACK_WEEKS + 1, RankPrizes.FIRST_WEEK)
	if settled ~= nil then
		first = math.max(first, settled + 1)
	end
	local results = {}
	for w = first, upto do
		local f = Ranking.final(w)
		if f == nil then
			return nil, nil
		end
		local r: { [string]: any } = { week = w, stars = 0 }
		for _, board in Ranking.BOARDS do
			for place, row in f[board] do
				if row[1] == uid then
					r[board] = place
					r.stars += RankPrizes.coroas(place)
					break
				end
			end
		end
		if r.wins ~= nil or r.kills ~= nil then
			table.insert(results, r)
		end
	end
	return upto, results
end

--- The names this server knows a player of the lists by: (user id, name) of the only row whose name
--- is `text` (any case), or (nil, how many rows have that name: 0, or 2+ when the name is not enough
--- and the numeric id is needed). Reads nothing: only the lists already in memory.
function Ranking.find(text: any): (number?, any)
	if type(text) ~= "string" or text == "" then
		return nil, 0
	end
	local q = string.lower(text)
	local seen: { [number]: string } = {}
	local n = 0
	local function look(uid: any, name: any)
		if type(uid) == "number" and type(name) == "string" and name ~= "" and seen[uid] == nil and string.lower(name) == q then
			seen[uid] = name
			n += 1
		end
	end
	for _, l in lists do
		for _, r in l.rows do
			look(r[1], r[2])
		end
	end
	for _, f in finals do
		for _, board in Ranking.BOARDS do
			for _, r in (f[board] or {}) :: { any } do
				look(r[1], names[r[1]])
			end
		end
	end
	if n == 1 then
		local uid, name = next(seen)
		return uid, name
	end
	return nil, n
end

--- The owner's panel (server/AdminPanel): takes `user_id` out of the ranking: the all-time lists,
--- this week's, and last week's final ones (the "champions", and the prizes not yet handed out).
--- Their totals start again from zero with their next public match. Yields.
--- -> (ok, found): ok = false when a store refused (what could be removed was); found: how many of
--- the stores had a number for them (0: they were in no list).
--- This server's lists lose the row at once; the other servers show it until they read the stores
--- again (REFRESH_S; last week's final lists: until that server closes).
function Ranking.remove(user_id: any): (boolean, number)
	local uid = whole(user_id)
	if uid == nil or uid <= 0 or deps.store == nil then
		return false, 0
	end
	roll()
	local key = tostring(uid)
	local all, found = true, 0
	local function take(what: string, get: () -> any)
		local ok, res = pcall(function()
			return get():RemoveAsync(key)
		end)
		if not ok then
			all = false
			note(string.format("could not remove %d from %s (%s)", uid, what, tostring(res)))
		elseif whole(res) ~= nil and (whole(res) :: number) > 0 then
			found += 1
		end
	end
	for _, board in boards() do
		take(board, function()
			return store_of(board)
		end)
		local l = lists[board]
		if l ~= nil then
			for i = #l.rows, 1, -1 do
				if l.rows[i][1] == uid then
					table.remove(l.rows, i)
				end
			end
		end
	end
	-- (what this server remembers of their totals would put the row back: merge)
	mine[uid] = nil
	if Ranking.WEEKLY_ON then
		local last = (cur_week or Ranking.week()) - 1
		if last >= RankPrizes.FIRST_WEEK then
			for _, board in Ranking.BOARDS do
				take(string.format("%s of week %d", board, last), function()
					return deps.store(board, last)
				end)
			end
			local f = finals[last]
			if f ~= nil then
				for _, board in Ranking.BOARDS do
					local rows = f[board]
					for i = #rows, 1, -1 do
						if rows[i][1] == uid then
							table.remove(rows, i)
						end
					end
				end
			end
		end
	end
	if deps.log then
		deps.log(string.format("[Ranking] %d removed by the owner (%d stores had them%s)", uid, found, if all then "" else "; a store failed"))
	end
	return all, found
end

function Ranking.release(user_id: any)
	local uid = whole(user_id)
	if uid ~= nil then
		mine[uid] = nil
	end
end

--- Additions still on their way.
function Ranking.pending(): number
	return pending
end

--- Waits, at most `max_s`, for the additions on their way to land (a closing server).
function Ranking.settle(max_s: number)
	local t0 = now()
	while pending > 0 and deps.wait ~= nil and now() - t0 < max_s do
		deps.wait(0.1)
	end
end

return Ranking
