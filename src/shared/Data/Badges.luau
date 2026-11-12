--!strict
-- The game's Roblox badges (the owner, 2026-11-12): what each one is for and when a player has earned
-- it, from what the server keeps of them (server/Purchases.inventory). The badges themselves are made
-- by the owner in the Creator Dashboard (GUIA.md, "Emblemas do Roblox"); their ids go in
-- Data/MyBadges. A badge with no id (0) is simply not given yet: nothing else changes.
--
--   Badges.LIST            { { key, name, text (the description for the Dashboard), image } }
--   Badges.earned(inv) ->  { [key] = true } for an inventory (Purchases.inventory's shape)
local IS_ROBLOX = typeof(game) == "Instance"
local function data(name: string): any
	if IS_ROBLOX then
		return require((script :: any).Parent[name]) :: any
	end
	return (require :: any)("./" .. name)
end
local Ranked: any = data("Ranked")
local Login: any = data("Login")

local Badges = {}

Badges.KILLS_1 = 10
Badges.KILLS_2 = 100
Badges.WINS_2 = 10

--- (`image`: the picture's file in assets/emblemas/, 512 x 512)
Badges.LIST = {
	{ key = "first_win", name = "Primeira Vitória", text = "Vença a sua primeira partida pública.", image = "primeira-vitoria.png" },
	{ key = "kills_10", name = "Conquistador", text = "Destrua 10 reinos em partidas públicas.", image = "conquistador.png" },
	{ key = "kills_100", name = "Flagelo dos Reinos", text = "Destrua 100 reinos em partidas públicas.", image = "flagelo-dos-reinos.png" },
	{ key = "wins_10", name = "Veterano de Guerra", text = "Vença 10 partidas públicas.", image = "veterano-de-guerra.png" },
	{ key = "knight", name = "Cavaleiro do Reino", text = "Chegue à patente Cavaleiro na Ranqueada.", image = "cavaleiro-do-reino.png" },
	{ key = "king", name = "Rei de Conquista", text = "Chegue à patente Rei na Ranqueada.", image = "rei-de-conquista.png" },
	{ key = "champion", name = "Campeão da Semana", text = "Termine a semana entre os 3 primeiros do ranking.", image = "campeao-da-semana.png" },
	{ key = "login_7", name = "Sete Dias de Lealdade", text = "Entre no jogo 7 dias seguidos.", image = "sete-dias-de-lealdade.png" },
}

local function num(x: any): number
	local n = tonumber(x) or 0
	return if n ~= n then 0 else n
end

--- The badges an inventory has earned: { [key] = true }.
function Badges.earned(inv: any): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if type(inv) ~= "table" then
		return out
	end
	local stats = if type(inv.stats) == "table" then inv.stats else {}
	local wins, kills = num(stats.wins), num(stats.kills)
	if wins >= 1 then
		out.first_win = true
	end
	if wins >= Badges.WINS_2 then
		out.wins_10 = true
	end
	if kills >= Badges.KILLS_1 then
		out.kills_10 = true
	end
	if kills >= Badges.KILLS_2 then
		out.kills_100 = true
	end
	-- the ranked tiers: the highest one reached this month, or the one the last season closed on
	local r = if type(inv.ranked) == "table" then inv.ranked else {}
	local tier = (Ranked.tier_of(math.max(num(r.points), num(r.peak))))
	if type(inv.ranked_last) == "table" then
		tier = math.max(tier, num(inv.ranked_last.tier))
	end
	if tier >= 2 then
		out.knight = true
	end
	if tier >= #Ranked.TIERS then
		out.king = true
	end
	-- the weekly ranking's insignia (1, 2 or 3: Data/RankPrizes)
	if num(inv.badge) >= 1 then
		out.champion = true
	end
	local login = if type(inv.login) == "table" then inv.login else {}
	if num(login.streak) >= Login.DAYS then
		out.login_7 = true
	end
	return out
end

return Badges
