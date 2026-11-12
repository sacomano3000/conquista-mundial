--!strict
-- The weekly ranking's calendar and prizes (server/Ranking counts and pays; UI/Ranking shows them).
--
-- A week runs from Monday 00:00 to Sunday 23:59, Brasília time. When it closes, each of the two weekly
-- lists (victories, kingdoms destroyed) pays its ten best players in Coroas, and the three best of
-- each wear that place's insignia beside their name for the whole of the next week. The insignia
-- cannot be bought or opened from a crate: the ranking is the only way to it.
--
-- The insignia comes by itself on Monday and goes to the next week's best the Monday after. The
-- Coroas wait for the player: the RANK button shows a mark, and the window a CLAIM button, for
-- CLAIM_WEEKS weeks after the week closed (2026-11-12; before that they were paid on arrival).
--
-- TO CHANGE THE PRIZES: edit COROAS below (1st place first). A longer list pays more places.
local RankPrizes = {}

--- Coroas for each place of a weekly list, 1st first. A player in both lists is paid by both.
RankPrizes.COROAS = { 1000, 700, 500, 300, 250, 200, 150, 120, 100, 80 }
--- The places that also earn the insignia.
RankPrizes.BADGE_PLACES = 3
--- How many weeks after a week closed its Coroas can still be claimed (2: the week after, and the
--- one after that). The insignia is worn for one week whatever this says.
RankPrizes.CLAIM_WEEKS = 2
--- A week, seconds, and where it starts: Monday 00:00 in Brasília (UTC-3) is Monday 03:00 UTC, and
--- 1 January 1970 was a Thursday.
RankPrizes.WEEK_S = 7 * 86400
RankPrizes.WEEK_START_S = 4 * 86400 + 3 * 3600
--- The first week the weekly lists existed (the one of Monday 9 November 2026): nothing is read from
--- before it.
RankPrizes.FIRST_WEEK = 2966

--- The insignias' pictures (this game's own drawings: Assets/OwnArt, tools/arte/make_own_art.py) and
--- colours: gold, silver, bronze.
RankPrizes.BADGE_IMAGES = {
	"rbxasset://own/badge/1",
	"rbxasset://own/badge/2",
	"rbxasset://own/badge/3",
}
RankPrizes.BADGE_HEX = { "#ECBE5C", "#CAD0DA", "#D08E5C" }
--- What the chat shows before the name of a player who wears one.
RankPrizes.CHAT_TAGS = { "[TOP 1]", "[TOP 2]", "[TOP 3]" }

--- The week of unix time `t` (a whole number that grows by one every Monday).
function RankPrizes.week(t: number): number
	return math.floor((t - RankPrizes.WEEK_START_S) / RankPrizes.WEEK_S)
end

--- When week `n` starts, unix seconds (it ends when the next one starts).
function RankPrizes.week_start(n: number): number
	return n * RankPrizes.WEEK_S + RankPrizes.WEEK_START_S
end

--- Coroas for `place` of a weekly list (0 outside the prizes).
function RankPrizes.coroas(place: any): number
	local p = tonumber(place)
	if p == nil or p ~= p or p < 1 or p ~= math.floor(p) then
		return 0
	end
	return RankPrizes.COROAS[p] or 0
end

--- The insignia `place` earns: 1, 2 or 3, or nil.
function RankPrizes.badge(place: any): number?
	local p = tonumber(place)
	if p == nil or p ~= p or p < 1 or p > RankPrizes.BADGE_PLACES or p ~= math.floor(p) then
		return nil
	end
	return p
end

--- The picture of insignia `place`, or "" when there is none.
function RankPrizes.badge_image(place: any): string
	local b = RankPrizes.badge(place)
	return if b ~= nil then (RankPrizes.BADGE_IMAGES[b] or "") else ""
end

--- The best of two places (either may be nil).
function RankPrizes.best(a: any, b: any): number?
	local x, y = tonumber(a), tonumber(b)
	if x == nil then
		return y
	elseif y == nil then
		return x
	end
	return math.min(x, y)
end

--- Can a prize of week `week` still be claimed in week `now_week`?
function RankPrizes.claimable(week: any, now_week: number): boolean
	local w = tonumber(week)
	return w ~= nil and w == math.floor(w) and w < now_week and now_week - w <= RankPrizes.CLAIM_WEEKS
end

--- "3d 4h", "5h 12min", "8min": what is left of a week, short.
function RankPrizes.left_text(s: number): string
	local m = math.max(0, math.floor(s / 60))
	local d, h = m // 1440, (m % 1440) // 60
	if d > 0 then
		return string.format("%dd %dh", d, h)
	elseif h > 0 then
		return string.format("%dh %dmin", h, m % 60)
	end
	return string.format("%dmin", math.max(1, m))
end

return RankPrizes
