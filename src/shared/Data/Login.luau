--!strict
-- The daily login reward (the owner, 2026-11-12): seven days in a row, each paying a little more, and
-- a free crate on the seventh; then it starts again from day 1. A day missed goes back to day 1
-- ("perdeu um dia, volta pro dia 1"). Days turn at midnight in Brasília (Data/Missions.day, the
-- missions' clock).
--
-- A player's state (in their record: server/Purchases, `login`):
--   { day = Missions.day of the last reward taken (0: never), streak = which of the seven it was }
--
--   Login.clean(v) -> state
--   Login.peek(state, t) -> { index, available, reward, taken }   what today holds (nothing changes)
--   Login.claim(state, t) -> { index, reward }?                   takes today's (nil: taken already)
--   Login.text(index, reward, commas?) -> the notice, in Portuguese
--
-- Every number of it is REWARDS below.
local IS_ROBLOX = typeof(game) == "Instance"
local function data(name: string): any
	if IS_ROBLOX then
		return require((script :: any).Parent[name]) :: any
	end
	return (require :: any)("./" .. name)
end
local Missions: any = data("Missions")

local Login = {}

--- What each day of the streak gives: Coroas (`stars`) or free crates (`crate`).
Login.REWARDS = {
	{ stars = 500 },
	{ stars = 750 },
	{ stars = 1000 },
	{ stars = 1500 },
	{ stars = 2000 },
	{ stars = 3000 },
	{ crate = 1 },
}
Login.DAYS = #Login.REWARDS

export type State = { day: number, streak: number }

local function whole(x: any, lo: number, hi: number): number
	local n = tonumber(x) or 0
	return if n ~= n then lo else math.clamp(math.floor(n), lo, hi)
end

function Login.clean(v: any): State
	local t = if type(v) == "table" then v else {}
	local day = whole(t.day, 0, 10000000)
	return { day = day, streak = if day > 0 then whole(t.streak, 1, Login.DAYS) else 0 }
end

--- Which day of the seven a reward taken on `today` is, after `state`.
local function index_on(state: State, today: number): number
	if state.day > 0 and today == state.day + 1 then
		return state.streak % Login.DAYS + 1
	end
	return 1
end

--- What today (unix time `t`) holds: { index (1..7: today's day of the streak; taken already: the
--- one taken), available (today's is still to take), reward, next (tomorrow's index when today's
--- is taken; nil otherwise) }.
function Login.peek(state: any, t: number): any
	local st = Login.clean(state)
	local today = Missions.day(t)
	if st.day == today then
		return {
			index = st.streak,
			available = false,
			reward = Login.REWARDS[st.streak],
			next = st.streak % Login.DAYS + 1,
		}
	end
	local i = index_on(st, today)
	return { index = i, available = true, reward = Login.REWARDS[i] }
end

--- Takes today's reward: `state` remembers it. -> { index, reward }, or nil when today's was taken
--- already (or the clock went backwards: a day before the last one taken gives nothing).
function Login.claim(state: State, t: number): any
	local today = Missions.day(t)
	if today <= state.day then
		return nil
	end
	local i = index_on(state, today)
	state.day = today
	state.streak = i
	return { index = i, reward = Login.REWARDS[i] }
end

--- "+1.000 Coroas" / "1 baú grátis": a reward, in Portuguese.
function Login.reward_text(reward: any, commas: ((number) -> string)?): string
	local f: any = commas or tostring
	if type(reward) ~= "table" then
		return ""
	end
	if (tonumber(reward.crate) or 0) > 0 then
		return if reward.crate == 1 then "1 baú grátis" else string.format("%d baús grátis", reward.crate)
	end
	return string.format("+%s Coroas", f(whole(reward.stars, 0, 100000000)))
end

--- The notice a player reads when the day's reward is paid (the server writes it, in Portuguese).
function Login.text(index: any, reward: any, commas: ((number) -> string)?): string
	local i = whole(index, 1, Login.DAYS)
	local text = string.format("Recompensa diária, dia %d de %d: %s.", i, Login.DAYS, Login.reward_text(reward, commas))
	local nxt = Login.REWARDS[i % Login.DAYS + 1]
	if i == Login.DAYS then
		return text .. " Sequência completa! Amanhã ela recomeça do dia 1."
	end
	return text .. string.format(" Volte amanhã: %s.", Login.reward_text(nxt, commas))
end

return Login
