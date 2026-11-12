--!strict
-- Ranked: the RANQUEADA public match (server/Lobbies/LobbyRules.MODE_RANKED) and the rank it gives.
--
-- A ranked match is a free-for-all like the CLÁSSICA one (same maps, same rules, same Coroas), and on
-- top of the Coroas it moves the player's POINTS. Points make the rank (TIERS: Escudeiro, Cavaleiro,
-- Barão, Duque, Rei). They are counted like the Coroas of a match, much smaller, and they can go
-- down: every match costs an entry (the tier's `fee`), so a match that ends badly takes points.
--
--   entry      - the tier's fee                 every match the player spawned in
--   placed     PLACE_MAX x place score x crowd  place score = Stars.place_score (1st: 1, last: 0);
--                                               not for a player who left early
--   victory    WIN x crowd                      the winner
--   conquests  PER_HUMAN a player destroyed, PER_BOT a robot or a kingdom of the map
--
-- `crowd` is how much a place and a victory are worth by the REAL players the match had (the owner,
-- 2026-11-12: "a vitória vale conforme quantos jogadores reais havia"): CROWD_MIN alone against the
-- robots, 1 with CROWD_FULL players or more. 2x Coroas does not touch the points.
-- Points never go below 0. A player's tier is the highest one whose `at` their points reach.
--
-- The season is the calendar month (Brasília: Data/Missions.month, the monthly pass's clock). When
-- the month turns everyone starts again from 0 (the owner: "todo mês, zera tudo"), and a player who
-- played gets the Coroas of the highest tier they reached in it (`prize`), once, the next time they
-- come in.
--
-- A player's state (in their record: server/Purchases, `ranked`):
--   { month = Missions.month, points, games, wins, peak }
--
--   Ranked.clean(v) -> state                  any stored value made safe
--   Ranked.roll(state, t) -> closed?          a new month: the state starts again; -> what the month
--                                             that closed left ({ month, points, tier, stars, games })
--                                             when the player played in it
--   Ranked.score(result, tier) -> { lines = { { key, amount } }, total }
--   Ranked.apply(state, t, result) -> out     rolls, scores and moves the points: { lines, total,
--                                             delta (what really changed), points, tier, before
--                                             (the tier before), month, closed? }
--   Ranked.tier_of(points) -> index, tier
--   Ranked.view(state, t) -> what the screens draw
local IS_ROBLOX = typeof(game) == "Instance"
local function data(name: string): any
	if IS_ROBLOX then
		return require((script :: any).Parent[name]) :: any
	end
	return (require :: any)("./" .. name)
end
local Missions: any = data("Missions")
local Stars: any = data("Stars")

local Ranked = {}

--- The lobby kind (server/Lobbies/LobbyRules.MODE_RANKED).
Ranked.MODE = "ranked"

--- The ranks, lowest first. `at`: the points it starts at; `fee`: what a match costs there; `prize`:
--- the Coroas a season that ends there pays (`color`: the tier's colour on the screens, 0xRRGGBB). To change a number, change it here: nothing else holds it.
Ranked.TIERS = {
	{ key = "escudeiro", name = "Escudeiro", at = 0, fee = 6, prize = 0, color = 0xB9A27A },
	{ key = "cavaleiro", name = "Cavaleiro", at = 100, fee = 10, prize = 1000, color = 0xC9D3DF },
	{ key = "barao", name = "Barão", at = 300, fee = 14, prize = 3000, color = 0x6FC3FF },
	{ key = "duque", name = "Duque", at = 600, fee = 18, prize = 7000, color = 0xC08BFF },
	{ key = "rei", name = "Rei", at = 1000, fee = 22, prize = 15000, color = 0xECBE5C },
}
--- The first place's points (the last place: 0), before `crowd`.
Ranked.PLACE_MAX = 40
--- The winner's points, before `crowd`.
Ranked.WIN = 30
--- A real player destroyed; a robot player or a kingdom of the map destroyed.
Ranked.PER_HUMAN = 6
Ranked.PER_BOT = 1
--- What a place and a victory are worth alone against the robots, and with how many real players
--- they are worth everything.
Ranked.CROWD_MIN = 0.25
Ranked.CROWD_FULL = 8
--- No state holds more than this.
Ranked.MAX_POINTS = 1000000
Ranked.MAX_GAMES = 1000000

Ranked.LINES = { "entry", "placed", "victory", "conquests" }
Ranked.LABELS = {
	entry = "Entry",
	placed = "Place",
	victory = "Victory",
	conquests = "Kingdoms",
}

export type State = { month: number, points: number, games: number, wins: number, peak: number }

local function whole(v: any, lo: number, hi: number): number
	if type(v) ~= "number" or v ~= v then
		return lo
	end
	return math.clamp(math.floor(v), lo, hi)
end

--- Any stored value as a state (a missing or broken one: an empty state of no month).
function Ranked.clean(v: any): State
	local t = if type(v) == "table" then v else {}
	local points = whole(t.points, 0, Ranked.MAX_POINTS)
	return {
		month = whole(t.month, 0, 1000000),
		points = points,
		games = whole(t.games, 0, Ranked.MAX_GAMES),
		wins = whole(t.wins, 0, Ranked.MAX_GAMES),
		peak = math.max(points, whole(t.peak, 0, Ranked.MAX_POINTS)),
	}
end

--- The tier `points` are in: its index in TIERS (1..) and the tier.
function Ranked.tier_of(points: any): (number, any)
	local p = whole(points, 0, Ranked.MAX_POINTS)
	local at = 1
	for i, tier in Ranked.TIERS do
		if p >= tier.at then
			at = i
		end
	end
	return at, Ranked.TIERS[at]
end

--- What a place and a victory are worth with `humans` real players in the match: CROWD_MIN..1.
function Ranked.crowd(humans: any): number
	local h = whole(humans, 1, 1000)
	if Ranked.CROWD_FULL <= 1 then
		return 1
	end
	local k = math.clamp((h - 1) / (Ranked.CROWD_FULL - 1), 0, 1)
	return Ranked.CROWD_MIN + (1 - Ranked.CROWD_MIN) * k
end

local function round(x: number): number
	return math.floor(x + 0.5)
end

--- The points a match's result (Data/Stars' Result, with `kills_h`: the real players among `kills`,
--- and `humans`: the real players the match had) is worth for a player of tier index `tier`.
--- A player who never spawned: nothing, and no entry either.
function Ranked.score(result: any, tier: any): { lines: { { any } }, total: number }
	local lines: { { any } } = {}
	local total = 0
	local r = if type(result) == "table" then result else {}
	if r.spawned ~= true then
		return { lines = lines, total = 0 }
	end
	local t = Ranked.TIERS[whole(tier, 1, #Ranked.TIERS)]
	local function add(key: string, amount: number)
		if amount ~= 0 then
			table.insert(lines, { key, amount })
			total += amount
		end
	end
	add("entry", -t.fee)
	local crowd = Ranked.crowd(r.humans)
	if r.left ~= true then
		local field = whole(r.field, 1, Stars.MAX_FIELD)
		local place = whole(r.place, 1, field)
		add("placed", round(Ranked.PLACE_MAX * Stars.place_score(place, field) * crowd))
		if r.won == true then
			add("victory", round(Ranked.WIN * crowd))
		end
	end
	local kills = whole(r.kills, 0, Stars.MAX_KILLS)
	local kills_h = whole(r.kills_h, 0, kills)
	add("conquests", Ranked.PER_HUMAN * kills_h + Ranked.PER_BOT * (kills - kills_h))
	return { lines = lines, total = total }
end

--- A new month: `state` starts again from nothing. Returns what the month that closed left, when
--- the player played a ranked match in it: { month, points, tier (index), stars (the tier's prize),
--- games, wins }; nil when the month is the same or nothing was played.
function Ranked.roll(state: State, t: number): any
	local month = Missions.month(t)
	if state.month == month then
		return nil
	end
	local closed = nil
	if state.month > 0 and state.month < month and state.games > 0 then
		-- the prize is the one of the highest tier reached in the month ("pela patente alcançada"):
		-- a bad last match does not take it away
		local i, tier = Ranked.tier_of(math.max(state.points, state.peak))
		closed = {
			month = state.month,
			points = state.points,
			tier = i,
			stars = tier.prize,
			games = state.games,
			wins = state.wins,
		}
	end
	state.month = month
	state.points = 0
	state.games = 0
	state.wins = 0
	state.peak = 0
	return closed
end

--- A ranked match's result at unix time `t`: the month rolls first, then the points move (never
--- below 0). -> { lines, total (the match's points), delta (how much the points really moved),
--- points (after), tier, before (tier indexes after and before), month, closed? (Ranked.roll's) }.
--- A result of a player who never spawned changes nothing and counts no game.
function Ranked.apply(state: State, t: number, result: any): any
	local closed = Ranked.roll(state, t)
	local before = Ranked.tier_of(state.points)
	local s = Ranked.score(result, before)
	local old = state.points
	if type(result) == "table" and result.spawned == true then
		state.points = math.clamp(old + s.total, 0, Ranked.MAX_POINTS)
		state.peak = math.max(state.peak, state.points)
		state.games = math.min(state.games + 1, Ranked.MAX_GAMES)
		if result.won == true and result.left ~= true then
			state.wins = math.min(state.wins + 1, Ranked.MAX_GAMES)
		end
	end
	return {
		lines = s.lines,
		total = s.total,
		delta = state.points - old,
		points = state.points,
		tier = (Ranked.tier_of(state.points)),
		before = before,
		month = state.month,
		closed = closed,
	}
end

--- What the screens draw of a state at unix time `t` (a state of another month reads as an empty
--- one): { points, tier (index), name, key, at (the tier's start), next (the next tier's start, nil
--- at the top), next_name, fee, games, wins, month, ends (unix time the season ends) }.
function Ranked.view(state: any, t: number): any
	local st = Ranked.clean(state)
	local month = Missions.month(t)
	if st.month ~= month then
		st = Ranked.clean(nil)
		st.month = month
	end
	local i, tier = Ranked.tier_of(st.points)
	local nxt = Ranked.TIERS[i + 1]
	return {
		points = st.points,
		tier = i,
		name = tier.name,
		key = tier.key,
		at = tier.at,
		next = if nxt ~= nil then nxt.at else nil,
		next_name = if nxt ~= nil then nxt.name else nil,
		fee = tier.fee,
		games = st.games,
		wins = st.wins,
		month = month,
		ends = Missions.month_end(t),
	}
end

local MONTHS_PT = {
	"janeiro", "fevereiro", "março", "abril", "maio", "junho",
	"julho", "agosto", "setembro", "outubro", "novembro", "dezembro",
}

--- A month's name in Portuguese ("novembro").
function Ranked.month_name(month: any): string
	local _, m = Missions.year_month(whole(month, 0, 1000000))
	return MONTHS_PT[m] or "?"
end

--- The notice a player reads when their season closed (Ranked.roll's `closed`), in Portuguese (the
--- server writes it: a sentence with numbers is not in the dictionary).
function Ranked.season_text(closed: any, commas: ((number) -> string)?): string
	local f: any = commas or tostring
	local tier = Ranked.TIERS[whole(closed.tier, 1, #Ranked.TIERS)]
	local text = string.format(
		"Temporada ranqueada de %s encerrada: sua melhor patente foi %s (terminou com %s pontos).",
		Ranked.month_name(closed.month),
		tier.name,
		f(whole(closed.points, 0, Ranked.MAX_POINTS))
	)
	local stars = whole(closed.stars, 0, 100000000)
	if stars > 0 then
		text ..= string.format(" Prêmio: +%s Coroas.", f(stars))
	end
	return text .. " Nova temporada: todos recomeçam do zero."
end

--- "Cavaleiro  ·  142 / 300" (the top tier: "Rei  ·  1.240"), for a line of the lobby.
function Ranked.line(view: any, commas: ((number) -> string)?): string
	local f: any = commas or tostring
	if view.next ~= nil then
		return string.format("%s  ·  %s / %s", view.name, f(view.points), f(view.next))
	end
	return string.format("%s  ·  %s", view.name, f(view.points))
end

return Ranked
