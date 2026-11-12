--!strict
-- Roblox server entry for the multiplayer match (the server half of scripts/net/session.gd plus the
-- server duties of scripts/main.gd). Every Roblox server hosts one shared match (MatchServer); players
-- pick Solo (runs on their client, never touches the server) or Multiplayer on the title screen.
--
-- Networking: ReplicatedStorage.ConquistaNet.ToServer / ToClient RemoteEvents (one per direction, so
-- everything in a direction is strictly ordered: snapshot before deltas, deltas in tick order). The
-- first argument is an op code (Net/Protocol.OP). Deltas / snapshots / intents are buffers.
--
-- Also: per-player settings (SettingsStore), graceful shutdown (BindToClose), and optional stats
-- logging (workspace attribute AF_NET_STATS = true prints a line every 30 s).
--
-- Maps: the terrain of every map but the default lives in script.Parent.MapData (server only);
-- WorldMap gets a provider for it, and ConquistaNet.GetMap (Net/MapFetch) serves it to clients that
-- need a map for solo play or an upcoming multiplayer match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Conquista")
local Protocol = require(Shared.Net.Protocol) :: any
local MapFetch = require(Shared.Net.MapFetch) :: any
local LobbyRules = require(script.Parent.Lobbies.LobbyRules) :: any
local LobbyStore = require(script.Parent.Lobbies.LobbyStore) :: any
local LobbyDirectory = require(script.Parent.Lobbies.LobbyDirectory) :: any
local MatchHost = require(script.Parent.Lobbies.MatchHost) :: any
local Teleports = require(script.Parent.Lobbies.Teleports) :: any
local Party = require(script.Parent.Party) :: any
local SharedClock = require(script.Parent.Lobbies.SharedClock) :: any
local LobbyHttp = require(script.Parent.Lobbies.LobbyHttp) :: any
-- (gitignored: a clone without it keeps the MemoryStore lobby list; tools/publish.sh won't ship without it)
local SecretModule = script.Parent.Lobbies:FindFirstChild("Secret")
local LobbySecret = if SecretModule then require(SecretModule :: ModuleScript) :: any else nil
local BotNames = require(Shared.Data.BotNames) :: any
local BotFaces = require(script.Parent.BotFaces) :: any
local FreshServers = require(script.Parent.FreshServers) :: any
local TutorialData = require(Shared.Data.Tutorial) :: any
local Staging = require(Shared.Data.Staging) :: any
local HttpService = game:GetService("HttpService")
local MapList = require(Shared.Data.MapList) :: any
local MatchServer = require(script.Parent.MatchServer) :: any
local SettingsStore = require(script.Parent.SettingsStore) :: any
local Analytics = require(script.Parent.Analytics) :: any
local ServerPerf = require(script.Parent.ServerPerf) :: any
local AdminCheck = require(script.Parent.AdminCheck) :: any
local DsGate = require(script.Parent.DsGate) :: any
local Handoff = require(script.Parent.Handoff) :: any
local Purchases = require(script.Parent.Purchases) :: any
local OwnerCommands = require(script.Parent.OwnerCommands) :: any
local AdminActions = require(script.Parent.AdminActions) :: any
local Codes = require(script.Parent.Codes) :: any
local CodeStore = require(script.Parent.CodeStore) :: any
local CodeCommands = require(script.Parent.CodeCommands) :: any
local Rewards = require(script.Parent.Rewards) :: any
local General = require(script.Parent.General) :: any
local Ranking = require(script.Parent.Ranking) :: any
local Subscription = require(Shared.Data.Subscription) :: any
local RankPrizes = require(Shared.Data.RankPrizes) :: any
local Ranked = require(Shared.Data.Ranked) :: any
local Login = require(Shared.Data.Login) :: any
local BadgeAwards = require(script.Parent.BadgeAwards) :: any
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local DataStoreService = game:GetService("DataStoreService")

local OP = Protocol.OP

local ServerMain = {}
ServerMain.server = nil :: any
--- Messages a client may send per second before the rest is ignored (intents have their own 30/s).
ServerMain.MAX_MESSAGES_PER_SEC = 90
--- The production experience's universe id (build/publish.json), the only one that uses the lobby
--- service. -1 = none.
ServerMain.PROD_UNIVERSE = -1
--- Team games and parties in production (docs/teams-and-parties.md; always on in Staging and Studio).
ServerMain.TEAM_GAMES_LIVE = true
--- SETTING messages per second per client (clients throttle each section to 2/s).
ServerMain.MAX_SETTINGS_PER_SEC = 8
--- ANALYTICS messages per second per client (a client sends a handful per match).
ServerMain.MAX_ANALYTICS_PER_SEC = 6
ServerMain.MAX_CREDIT_USES_PER_SEC = 2
--- Redeem codes (OP.REDEEM_CODE): tries per player in each window of seconds.
ServerMain.CODE_TRIES = 6
ServerMain.CODE_WINDOW_S = 60
--- The RANK window's lists (OP.RANK_GET) are sent to a player at most this often, seconds.
ServerMain.RANK_GAP_S = 3
--- How long after a player arrives their weekly ranking prizes are looked at (their screen is up by
--- then, so the notice is seen), seconds.
ServerMain.RANK_PRIZE_JOIN_S = 12
--- A player's CLAIM (OP.RANK_CLAIM) reaches the store at most this often, seconds.
ServerMain.RANK_CLAIM_GAP_S = 2
--- The owner's panel (OP.ADMIN): a player's requests are at least this far apart, seconds.
ServerMain.ADMIN_GAP_S = 0.2
--- How often the hub looks whether the week turned (the insignias change hands), seconds.
ServerMain.RANK_WEEK_POLL_S = 30
--- A player may ask to be sent to a fresh server (OP.SOLO_HOP) this often, seconds.
ServerMain.HOP_GAP_S = 15
--- A client sends HELLO once (its scripts started). Further HELLOs from the same player are answered
--- at most this often (LOBBY); the SETTINGS reply has its own, longer limit (SettingsStore.replay).
--- review_code.md R2-2: every HELLO used to echo the whole stored settings blob.
ServerMain.HELLO_MIN_INTERVAL_S = 2.0
--- The match's instrumentation window; each one also goes to the lobby service (ServerPerf; 30 s
--- until 2026-11-01).
ServerMain.STATS_EVERY_S = 60
--- Hubs push the public-lobby list to their players this often (seconds).
ServerMain.LOBBIES_PUSH_S = 2.0

local started = false

--- Reports an error once per distinct message (first line), so a recurring fault can't flood the log.
local reported: { [string]: boolean } = {}
--- The Robux a Loja Misteriosa receipt was for, between Purchases' two words about it (`bought`, then
--- `shop_bought` with the item).
local shop_spent: { [any]: number? } = setmetatable({}, { __mode = "k" }) :: any
local reported_n = 0
local function report_once(where: string, err: any)
	local text = tostring(err)
	local key = where .. ":" .. (string.match(text, "^[^\n]*") or "")
	if reported[key] or reported_n >= 64 then
		return
	end
	reported[key] = true
	reported_n += 1
	warn(string.format("[Server] %s failed: %s", where, text))
end

local function core(name: string): any
	local m = Shared.Core:FindFirstChild(name)
	if m == nil then
		return nil
	end
	return (require :: any)(m)
end

function ServerMain.start()
	if started then
		return
	end
	started = true
	Players.CharacterAutoLoads = false
	pcall(function()
		StarterGui.ResetPlayerGuiOnSpawn = false
	end)

	-- Server-only map data (src/server/MapData) for WorldMap.get / MapFetch.
	local WorldMapMod = core("WorldMap")
	local map_folder = script.Parent:FindFirstChild("MapData")
	if WorldMapMod ~= nil then
		WorldMapMod.add_provider(function(id: string): any
			local row = MapList.get(id)
			local mod = if row ~= nil and map_folder ~= nil then map_folder:FindFirstChild(row.module) else nil
			return if mod ~= nil then (require :: any)(mod) else nil
		end)
	end

	local folder = Instance.new("Folder")
	folder.Name = "ConquistaNet"
	if WorldMapMod ~= nil then
		MapFetch.serve(folder, function(id: string): any
			return WorldMapMod.load_data(id)
		end)
	end
	local to_server = Instance.new("RemoteEvent")
	to_server.Name = "ToServer"
	to_server.Parent = folder
	local to_client = Instance.new("RemoteEvent")
	to_client.Name = "ToClient"
	to_client.Parent = folder

	local listening: { [Player]: boolean } = {}
	local listening_list: { Player } = {}
	local msg_budget: { [Player]: number } = {}
	local setting_budget: { [Player]: number } = {}
	local analytics_budget: { [Player]: number } = {}
	local credit_budget: { [Player]: number } = {}
	--- redeem-code tries per player in the current window (OP.REDEEM_CODE)
	local code_tries: { [Player]: { since: number, n: number } } = {}
	--- when each player was last sent the ranking (OP.RANK_GET), and who is waiting for it now
	local rank_at: { [Player]: number } = {}
	local rank_busy: { [Player]: boolean } = {}
	--- Looks at what the closed weeks left a player and writes it to their record: the insignia, and
	--- the Coroas they can claim (set where the ranking is configured)
	local rank_prizes: any = nil
	--- players whose prizes are being looked at now, and those whose CLAIM is on its way
	local rank_settling: { [Player]: boolean } = {}
	local rank_claiming: { [Player]: boolean } = {}
	--- The owner's panel (OP.ADMIN): set where the game admins are known, further down
	local admin_op: any = nil
	local rank_claim_at: { [Player]: number } = {}
	--- server/FreshServers on a live hub (nil elsewhere), and when each player last asked to hop
	local fresh: any = nil
	local hop_at: { [Player]: number } = {}
	--- the INVENTORY payload for a player (set below, with the paid-random-items policy)
	local inventory_of: (any) -> any
	--- does this player buy the Coleção's crates with Coroas (set below, with the policy)
	local crates_for_stars: (any) -> boolean
	local hello_at: { [Player]: number } = {}
	local joining_lobby: { [Player]: boolean } = {}
	--- Players who came to watch (a hub's Watch teleport, or Studio's local Watch).
	local spectating: { [Player]: boolean } = {}

	-- Dev diagnostics (workspace attribute AF_DIAG; never set in the shipped place) can add fake
	-- participants (tables) next to real Players.
	local diag: any = nil
	if workspace:GetAttribute("AF_DIAG") == true then
		local m = script.Parent:FindFirstChild("Dev") and script.Parent.Dev:FindFirstChild("SessionDiag")
		if m then
			diag = (require :: any)(m)
		end
	end

	local function send(player: any, op: number, ...: any)
		if typeof(player) == "Instance" then
			if player.Parent == Players then
				to_client:FireClient(player, op, ...)
			end
		elseif diag ~= nil and diag.is_fake(player) then
			diag.deliver(player, op, ...)
		end
	end

	-- Public lobbies: a public server is a HUB (title, solo, the
	-- game-wide lobby list; joining a lobby teleports to its reserved server); a reserved server made
	-- for a lobby is that lobby's MATCH server (one match, bot players fill the empty slots, then
	-- everyone goes back to a hub). Studio has no teleports: a joined lobby runs on the same server.
	local is_match_server = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
	ServerMain.kind = if is_match_server then "match" else "hub"
	-- Team games and parties (docs/teams-and-parties.md): on Staging only at first, then
	-- in production too (since 2026-10-10). TEAM_GAMES_LIVE = false puts
	-- production back to two free-for-all lobbies and no parties.
	local TEAM_GAMES = ServerMain.TEAM_GAMES_LIVE or Staging.here() or RunService:IsStudio()
	ServerMain.team_games = TEAM_GAMES
	-- A live public hub takes part in server/FreshServers: it announces its version, lists itself
	-- while it is the newest, and once it is outdated sends the players who start a solo match to a
	-- fresh server (2026-10-04). Clients read workspace attribute RF_Outdated. Private servers,
	-- match servers and Studio stay out of it.
	if game.PrivateServerId == "" and not RunService:IsStudio() then
		local ok_fresh, err_fresh = pcall(function()
			local MSS = game:GetService("MemoryStoreService")
			local Messaging = game:GetService("MessagingService")
			local list = MSS:GetSortedMap("FreshHubs1")
			fresh = FreshServers.new({
				version = game.PlaceVersion,
				job_id = game.JobId,
				now = os.time,
				players = function(): number
					return #Players:GetPlayers()
				end,
				max_players = Players.MaxPlayers,
				publish = function(version: number)
					Messaging:PublishAsync("PlaceVersion", version)
				end,
				list_put = function(job_id: string, entry: any, ttl_s: number)
					list:SetAsync(job_id, entry, ttl_s)
				end,
				list_get = function(): any
					return list:GetRangeAsync(Enum.SortDirection.Ascending, 200)
				end,
				on_outdated = function(latest: number)
					workspace:SetAttribute("RF_Outdated", true)
				end,
				log = print,
			})
			task.spawn(function()
				pcall(function()
					Messaging:SubscribeAsync("PlaceVersion", function(msg: any)
						fresh:heard(if type(msg) == "table" then msg.Data else nil)
					end)
				end)
				while true do
					fresh:tick()
					task.wait(5)
				end
			end)
			-- a hop whose teleport could not start: the player plays here after all
			game:GetService("TeleportService").TeleportInitFailed:Connect(function(player: Player)
				if hop_at[player] ~= nil then
					send(player, OP.HOP_RESULT, false)
				end
			end)
		end)
		if not ok_fresh then
			warn("[Fresh] off: " .. tostring(err_fresh))
			fresh = nil
		end
	end
	-- Lobby times are written by one server and read by others: every server uses the shared clock
	-- (its own clock corrected against Roblox's backend), never its own os.time().
	SharedClock.start({ log = print })
	local now = SharedClock.now
	local store: any = nil
	local ok_store, st = pcall(LobbyStore.memory, game.JobId, now)
	if ok_store then
		store = st
	else
		warn("[Lobbies] MemoryStore unavailable, using a local store: " .. tostring(st))
		store = LobbyStore.localstore(now)
	end
	-- the lobby service on easy-1 (docs/lobby-service.md) in front of MemoryStore: with hundreds of
	-- servers reading the lobby list every few seconds MemoryStore refused most calls (one partition's
	-- limits, 2026-09-27). MemoryStore stays the fallback while the service is down or switched off.
	-- Studio uses it only when AF_LOBBY_URL points at a test service.
	local lobby_url: string? = nil
	if RunService:IsStudio() then
		local u = workspace:GetAttribute("AF_LOBBY_URL")
		lobby_url = if type(u) == "string" and u ~= "" then u else nil
	elseif LobbyHttp.ENABLED and game.GameId == ServerMain.PROD_UNIVERSE then
		-- (only the production experience: the service is one shared lobby list, and another
		-- experience, like the staging experience, must not show up in it; MemoryStore is its own per experience)
		lobby_url = LobbyHttp.BASE_URL
	end
	if lobby_url ~= nil and LobbySecret ~= nil then
		local client = LobbyHttp.roblox(LobbySecret, now, lobby_url, print)
		if client ~= nil then
			local fallback = store
			-- hubs tell the service who is playing solo / on the title (its live stats page)
			local presence = if ServerMain.kind == "hub"
				then function(): any
					return Analytics.presence(Players:GetPlayers())
				end
				else nil
			store = LobbyStore.failover(LobbyStore.http(client, ServerMain.kind, nil, presence), fallback, {
				healthy = function(): boolean
					return client:healthy()
				end,
				log = print,
			})
			ServerMain.lobby_client = client
			print("[Lobbies] lobby service " .. lobby_url .. " (MemoryStore as fallback)")
		else
			warn("[Lobbies] HTTP requests are off for this place: lobbies stay on MemoryStore")
		end
	end
	ServerMain.lobby_store = store
	-- What this server knew of a player follows them on its teleports (Handoff): the server they arrive
	-- on doesn't read their settings and Purchases record from the DataStores again.
	local handoff_map: any = nil
	pcall(function()
		handoff_map = game:GetService("MemoryStoreService"):GetHashMap(Handoff.MAP)
	end)
	local handoff = Handoff.new({
		map = handoff_map,
		guid = function(): string
			return HttpService:GenerateGUID(false)
		end,
		join_data = function(player: Player): any
			return player:GetJoinData()
		end,
		encode = function(v: any): string
			return HttpService:JSONEncode(v)
		end,
		spawn = task.spawn,
		wait = task.wait,
		now = os.clock,
		log = print,
	})
	ServerMain.handoff = handoff
	local teleports = Teleports.for_place(game.PlaceId, function(players: { Player }, data: any): any
		return handoff:stamp(players, data)
	end)
	local function lobby_maps(): { any }
		local out = {}
		for _, m in MapList.maps do
			table.insert(out, {
				id = m.id,
				name = m.name,
				weight = m.multiplayer_frequency or 1,
				categories = m.categories,
				land = m.land_tiles,
				k_lin = m.k_lin,
			})
		end
		return out
	end
	local directory: any = nil
	local host: any = nil
	--- Studio stand-in for a lobby's reserved server: the lobby this server plays locally.
	local studio_lobby: any = nil
	if is_match_server then
		host = MatchHost.new({
			store = store,
			psid = game.PrivateServerId,
			now = now,
			to_hub = teleports.to_hub,
			log = print,
		})
		ServerMain.host = host
	else
		directory = LobbyDirectory.new({
			store = store,
			teleport = teleports,
			maps = lobby_maps,
			now = now,
			rand = math.random,
			new_id = function(): string
				return HttpService:GenerateGUID(false)
			end,
			log = print,
			team_games = TEAM_GAMES,
			-- (seats never past what a server holds: a seat past it is a "GameFull" teleport. Studio's
			-- Players.MaxPlayers is not the place's, so no cap there.)
			server_size = function(): number?
				return if RunService:IsStudio() then nil else Players.MaxPlayers
			end,
		})
		ServerMain.directory = directory
	end
	-- Parties (server/Party) on a hub; a match server knows who came in which party from the teleport
	-- data (user id → party key; party key → its leader's user id).
	local party: any = nil
	if TEAM_GAMES and not is_match_server then
		party = Party.new({
			send = function(p: Player, state: any)
				send(p, OP.PARTY_STATE, state)
			end,
			now = os.time,
			log = print,
			prefix = string.sub(game.JobId, 1, 8) .. ":",
		})
		ServerMain.party = party
	end
	local party_by_uid: { [string]: string } = {}
	local party_leader: { [string]: number } = {}
	--- The lobby hooks MatchServer uses on a match server (or for a Studio-local lobby).
	local function lobby_hooks(): any
		local function current(): any
			if host ~= nil then
				return host.lobby
			end
			return studio_lobby
		end
		return {
			countdown = function(): number?
				if host ~= nil then
					return host:starts_in()
				end
				local l = studio_lobby
				return if l then math.max(0, l.starts - now()) else nil
			end,
			info = function(): any
				local l = current()
				-- public matches play their map a bit smaller ("world@80"); a team game's teams
				return if l
					then { map_id = LobbyRules.match_map_id(l.map), max = l.max, mode = l.mode, teams = l.teams }
					else nil
			end,
			party_of = function(uid: string): string?
				return party_by_uid[uid]
			end,
			on_start = function(humans: number, voted: boolean?): number
				-- the humans a public match starts with (the headline number; goal: 50):
				-- one "Public Match Humans" event per match on the Creator Dashboard
				local slots = if host ~= nil and host.lobby
					then host.lobby.max
					elseif studio_lobby ~= nil then studio_lobby.max
					else humans
				local reporter = nil
				for _, p in Players:GetPlayers() do
					reporter = p
					break
				end
				if reporter ~= nil then
					Analytics.public_start(reporter, humans, slots, voted == true)
				end
				if host ~= nil then
					local bots = LobbyRules.bot_fill(if host.lobby then host.lobby.max else humans, humans)
					task.spawn(function()
						host:start(humans)
					end)
					return bots
				end
				local l = studio_lobby
				if l ~= nil then
					-- Studio: the local lobby shows as a live match to watch (the hub's own list)
					task.spawn(function()
						pcall(store.update, l.id, function(v: any): any?
							local cur = LobbyRules.decode(v)
							if cur == nil then
								return nil
							end
							cur.status = "started"
							cur.players = humans
							cur.beat = now()
							return cur
						end)
					end)
				end
				return if l then LobbyRules.bot_fill(l.max, humans) else 0
			end,
			bot_names = function(n: number, taken: { [string]: boolean }): { string }
				local rng = Random.new()
				return BotNames.many(n, function()
					return rng:NextNumber()
				end, taken)
			end,
			on_vote_start = function(seconds: number)
				if host ~= nil then
					task.spawn(function()
						host:start_early(seconds)
					end)
				elseif studio_lobby ~= nil then
					studio_lobby.starts = math.min(studio_lobby.starts, now() + math.ceil(seconds))
				end
			end,
			on_closed = function()
				if host ~= nil then
					task.spawn(function()
						host:finish()
					end)
				elseif studio_lobby ~= nil then
					local id = studio_lobby.id
					task.spawn(function()
						pcall(store.remove, id)
					end)
				end
			end,
			on_over = function(peers: { any })
				local list = {}
				for _, p in peers do
					if typeof(p) == "Instance" and p.Parent == Players then
						table.insert(list, p)
					end
				end
				if host ~= nil then
					-- (who was in which party: the hub makes the parties again)
					local back = nil
					if TEAM_GAMES then
						local parties, leaders = {}, {}
						for _, p in list do
							local key = party_by_uid[tostring(p.UserId)]
							if key ~= nil then
								parties[tostring(p.UserId)] = key
								leaders[key] = party_leader[key]
							end
						end
						if next(parties) ~= nil then
							back = { parties = parties, leaders = leaders }
						end
					end
					task.spawn(function()
						host:finish()
						host:return_to_hub(list, back)
					end)
				elseif studio_lobby ~= nil then
					local id = studio_lobby.id
					task.spawn(function()
						pcall(store.remove, id)
					end)
				end
				studio_lobby = nil
			end,
		}
	end

	local server = MatchServer.new({
		lobby = if is_match_server then lobby_hooks() else nil,
		-- the head shots bot players wear beside their names (Roblox user ids; server only)
		bot_faces = BotFaces,
		-- what a player wears in a match (Data/Cosmetics; the match server sends it to everyone)
		cosmetics_of = function(peer: any): any
			if typeof(peer) ~= "Instance" then
				return nil
			end
			local eq = Purchases.equipped(peer)
			-- the weekly ranking's insignia (Data/RankPrizes): beside the name, for everyone
			local badge, on = Purchases.rank_badge(peer)
			if badge ~= nil then
				eq = eq or {}
				eq.badge = badge
				eq.bw = if on ~= nil then on.wins else nil
				eq.bk = if on ~= nil then on.kills else nil
			end
			-- the ranked tier of this month (Data/Ranked), from Cavaleiro up
			local rs = Purchases.ranked_state(peer)
			local tier = Ranked.view(rs, rs.now).tier
			if tier >= 2 then
				eq = eq or {}
				eq.tier = tier
			end
			return eq
		end,
		-- the Arsenal a player has unlocked (Data/Arsenal), and their Stars for a public match
		unlocks_of = function(peer: any): number
			return if typeof(peer) == "Instance" then Purchases.unlock_mask(peer) else 0
		end,
		on_result = function(peer: any, result: any, ranked: boolean?)
			if typeof(peer) == "Instance" then
				-- (a ranked match, shared/Data/Ranked: the same Coroas, and the result moves the
				-- player's points in the same write)
				-- (... and then the Roblox badges it earned, from the record as the match left it)
				task.spawn(function()
					Rewards.pay(peer, result, "public", ranked == true)
					if (peer :: any).Parent ~= nil then
						pcall(BadgeAwards.sync, peer, Purchases.inventory(peer))
					end
				end)
				-- the global ranking: a public match's wins and conquered nations (server/Ranking;
				-- by user id: the player is often on their way out when it lands)
				task.spawn(function()
					local ok, err = pcall(Ranking.record, (peer :: any).UserId, result, (peer :: any).DisplayName)
					if not ok then
						report_once("Ranking.record", err)
					end
				end)
			end
		end,
		make_sim = function(config: { [string]: any }): any
			local Sim = core("Sim")
			local WorldMap = core("WorldMap")
			if Sim == nil or WorldMap == nil then
				error("Core Sim is not available")
			end
			return Sim.new(WorldMap.get(config.map_id), config)
		end,
		send = send,
		peers = function(): { any }
			return listening_list
		end,
		now_ms = function(): number
			return os.clock() * 1000
		end,
		log = print,
	})
	ServerMain.server = server

	-- Quick Play on a hub (docs/lobby-service.md "Quick Play"): a player (a party leader: their party
	-- with them) asks for a public match of a kind; the store seats them in the soonest lobby of that
	-- kind with room, else they wait in line here until a seat is free. PUBLIC_STATE tells the client
	-- ("joining" | "line" | "going" | "idle").
	--- when each player asked (os.clock), for the wait the Public Join event reports
	local public_since: { [Player]: number } = {}
	--- seated and sent: the lobby, their seat, and whether this was already a retry
	local public_sent: { [Player]: { id: string, uid: string, mode: string, at: number, retried: boolean } } = {}
	--- the kinds of public match a player may ask for here (the title's cards)
	local public_kinds = {}
	for _, k in LobbyRules.kinds(TEAM_GAMES) do
		table.insert(public_kinds, k.mode)
	end
	local function public_state(players: { Player }, state: string, mode: string?, extra: any?)
		for _, m in players do
			send(m, OP.PUBLIC_STATE, state, mode, extra)
		end
	end
	--- The players who go with `player` (a party leader: everyone of the party on the title screen),
	--- and the party data for the match server; nil when `player` can't go now.
	local function public_group(player: Player): ({ Player }?, { [string]: any }?)
		if player.Parent ~= Players or Analytics.in_solo(player) then
			return nil, nil
		end
		if party == nil or party:key_of(player) == nil then
			return { player }, nil
		end
		local list, uids = {}, {}
		for _, m in party:members(player) do
			local free = m == player or (m.Parent == Players and not joining_lobby[m] and not Analytics.in_solo(m))
			if free then
				table.insert(list, m)
				table.insert(uids, tostring(m.UserId))
			end
		end
		if #list <= 1 then
			return { player }, nil
		end
		return list, { players = list, key = party:key_of(player), uids = uids, leader = player.UserId }
	end
	local function public_key(player: Player): string
		local k = if party ~= nil then party:key_of(player) else nil
		return if k ~= nil then "p:" .. k else "u:" .. tostring(player.UserId)
	end
	local function public_wait(m: Player): number
		return os.clock() - (public_since[m] or os.clock())
	end
	local function public_seated(players: { Player }, mode: string, l: any, first_try: boolean, retried: boolean?)
		for _, m in players do
			public_sent[m] =
				{ id = l.id, uid = tostring(m.UserId), mode = mode, at = os.clock(), retried = retried == true }
			pcall(Analytics.public_join, m, "Seated", mode, public_wait(m), first_try)
			public_since[m] = nil
		end
		public_state(players, "going", mode, { map = l.map, map_name = l.map_name })
	end
	local function public_failed(players: { Player }, mode: string, result: string, text: string?)
		for _, m in players do
			pcall(Analytics.public_join, m, result, mode, public_wait(m), false)
			public_since[m] = nil
		end
		public_state(players, "idle", mode)
		if text ~= nil then
			for _, m in players do
				send(m, OP.JOIN_RESULT, false, text)
				send(m, OP.NOTICE, text, 1)
			end
		end
	end
	--- Studio (no teleports): this server plays the lobby itself.
	local function public_studio(players: { Player }, group: { [string]: any }?, l: any)
		studio_lobby = l
		server.deps.lobby = lobby_hooks()
		server._finished = false -- (Studio replays lobbies on this one server)
		public_state(players, "idle", LobbyRules.mode_of(l))
		for _, m in players do
			if group ~= nil then
				party_by_uid[tostring(m.UserId)] = group.key
				party_leader[group.key] = group.leader
			end
			local nm = if m.DisplayName ~= "" then m.DisplayName else m.Name
			server:on_client(m, { uid = tostring(m.UserId), name = nm }, OP.JOIN, nm)
		end
	end
	local function public_join(player: Player, mode: string, retried: boolean?)
		if directory == nil or joining_lobby[player] then
			return
		end
		-- seated and on the way (the teleport has 20 s before the client gives up on it): no second seat
		local going = public_sent[player]
		if going ~= nil and os.clock() - going.at < 20 and not retried then
			return
		end
		if party ~= nil and party:key_of(player) ~= nil and not party:is_leader(player) then
			send(player, OP.JOIN_RESULT, false, "Your party leader picks the match.")
			send(player, OP.NOTICE, "Your party leader picks the match.", 1)
			return
		end
		local key = public_key(player)
		if directory:queued(key) ~= nil then
			return -- (in line already)
		end
		local players, group = public_group(player)
		if players == nil then
			return
		end
		for _, m in players do
			joining_lobby[m] = true
			public_since[m] = public_since[m] or os.clock()
		end
		public_state(players, "joining", mode)
		task.spawn(function()
			local ok, reason, l = directory:join_public(players, mode, { party = group })
			for _, m in players do
				joining_lobby[m] = nil
			end
			if ok then
				public_seated(players, mode, l, true, retried)
			elseif reason == "studio" and l ~= nil then
				public_studio(players, group, l)
			elseif reason == LobbyDirectory.NO_ROOM then
				-- every lobby of the kind is full right now: wait in line for the next free seat
				directory:enqueue({
					key = key,
					mode = mode,
					since = now(),
					members = function(): ({ any }?, { [string]: any }?)
						return public_group(player)
					end,
					done = function(seated: boolean, why: string?, lb: any, sent: { Player }?)
						local who = sent or public_group(player) or { player }
						if seated then
							public_seated(who, mode, lb, false, retried)
						elseif why == "studio" and lb ~= nil then
							public_studio(who, nil, lb)
						elseif why == "gone" then
							public_failed(who, mode, "Left Line", nil)
						elseif why == "timeout" then
							public_failed(
								who,
								mode,
								"Timed Out",
								"Every public match is full right now. Try again in a moment, or play solo."
							)
						else
							public_failed(who, mode, "Teleport Failed", why)
						end
					end,
				})
				public_state(players, "line", mode)
			elseif reason == LobbyDirectory.UNREACHABLE then
				public_failed(players, mode, "Unreachable", reason)
			else
				public_failed(players, mode, "Teleport Failed", reason)
			end
		end)
	end
	--- The player (a party leader: the party) leaves the line.
	local function public_cancel(player: Player)
		if directory == nil or (party ~= nil and party:key_of(player) ~= nil and not party:is_leader(player)) then
			return
		end
		local e = directory:queued(public_key(player))
		if e ~= nil and directory:dequeue(e.key) then
			public_failed(public_group(player) or { player }, e.mode, "Left Line", nil)
		end
	end
	ServerMain.public_join = public_join
	-- a public-match teleport that failed after it began: the seat goes back, and once the player is
	-- put in line again on their own
	if directory ~= nil and not RunService:IsStudio() then
		game:GetService("TeleportService").TeleportInitFailed:Connect(function(player: Player, result: any, msg: any)
			if result == Enum.TeleportResult.IsTeleporting then
				-- A second request refused because one is already under way: the player is still on
				-- their way, so the seat stays and nothing failed (2026-10-15: most of the ~5,200 daily
				-- "Teleport Failed" were this; their seat went back and they read "Couldn't reach that
				-- match" while the first teleport carried them in). If that one fails it fires again,
				-- and a seat nobody takes goes back after LobbyRules.ARRIVE_S anyway.
				return
			end
			local sent = public_sent[player]
			public_sent[player] = nil
			if sent == nil or os.clock() - sent.at > 60 then
				return
			end
			task.spawn(function()
				directory:release(sent.id, { sent.uid })
			end)
			pcall(Analytics.public_join, player, "Teleport Failed", sent.mode, 0, false)
			warn(
				string.format(
					"[Lobbies] teleport to %s failed for %s: %s %s",
					sent.id,
					player.Name,
					tostring(result),
					tostring(msg)
				)
			)
			-- (a party member who doesn't lead is brought along by the leader's retry, if free)
			local follower = party ~= nil and party:key_of(player) ~= nil and not party:is_leader(player)
			local again = not sent.retried and not follower and result ~= Enum.TeleportResult.Unauthorized
			if again and player.Parent == Players then
				send(player, OP.NOTICE, "Couldn't reach that match. Finding you another one…", 0)
				public_join(player, sent.mode, true)
			else
				public_state({ player }, "idle", sent.mode)
				send(player, OP.NOTICE, "Couldn't reach that match. Try again in a moment.", 1)
			end
		end)
	end

	to_server.OnServerEvent:Connect(function(player: Player, op: any, ...: any)
		if type(op) ~= "number" then
			return
		end
		local used = msg_budget[player] or 0
		if used >= ServerMain.MAX_MESSAGES_PER_SEC then
			return
		end
		msg_budget[player] = used + 1
		if op == OP.HELLO then
			local t = os.clock()
			local last = hello_at[player]
			if last ~= nil and t - last < ServerMain.HELLO_MIN_INTERVAL_S then
				return -- a repeated HELLO: already answered
			end
			hello_at[player] = t
			if not listening[player] then
				listening[player] = true
				table.insert(listening_list, player)
			end
			send(player, OP.LOBBY, server:lobby_info(player))
			if directory ~= nil then
				send(player, OP.LOBBIES, directory:view(), public_kinds)
			end
			-- the stored settings (size-capped) go out once, not on every HELLO
			SettingsStore.replay(player, function(data: any)
				send(player, OP.SETTINGS, data)
			end)
			send(player, OP.CREDITS, Purchases.credits(player))
			send(player, OP.INVENTORY, inventory_of(player))
			if Subscription.id() ~= "" then
				send(player, OP.GENERAL, General.state(player))
			end
			if party ~= nil then
				send(player, OP.PARTY_STATE, party:state(player))
			end
		elseif op == OP.SETTING then
			local s_used = setting_budget[player] or 0
			if s_used >= ServerMain.MAX_SETTINGS_PER_SEC then
				return
			end
			setting_budget[player] = s_used + 1
			local section, values = ...
			local ok, err = pcall(SettingsStore.set, player, section, values)
			if not ok then
				report_once("SettingsStore.set", err)
			end
		elseif op == OP.JOIN_PUBLIC then
			-- Quick Play: a public match of a kind ("ffa" | "ranked" | "team"), or false to leave the line
			local mode = ...
			if mode == false then
				public_cancel(player)
			elseif LobbyRules.is_mode(mode) and (mode ~= LobbyRules.MODE_TEAM or TEAM_GAMES) then
				-- (the world map has no kind of its own any more: it plays in the free-for-all)
				if mode == LobbyRules.MODE_WORLD and not LobbyRules.WORLD_LOBBY then
					mode = LobbyRules.MODE_FFA
				end
				public_join(player, mode)
			end
		elseif op == OP.JOIN_LOBBY then
			-- (a lobby picked by id) Quick Play into that lobby's kind
			local id = ...
			if directory == nil or type(id) ~= "string" or #id > 64 then
				return
			end
			local mode = LobbyRules.MODE_FFA
			for _, l in directory:lobbies() do
				if l.id == id then
					mode = LobbyRules.mode_of(l)
				end
			end
			public_join(player, mode)
		elseif op == OP.PARTY then
			if party == nil then
				return
			end
			local action, target = ...
			local tuid = tonumber(target)
			if action == "invite" and tuid ~= nil then
				local ok, why = party:invite(player, Players:GetPlayerByUserId(tuid))
				if ok then
					send(player, OP.NOTICE, "Invite sent", 0)
				elseif why ~= nil then
					send(player, OP.NOTICE, why, 1)
				end
			elseif action == "accept" and tuid ~= nil then
				local ok, why = party:accept(player, tuid)
				if not ok and why ~= nil then
					send(player, OP.NOTICE, why, 1)
				end
			elseif action == "decline" and tuid ~= nil then
				party:decline(player, tuid)
			elseif action == "leave" then
				party:leave(player)
			elseif action == "kick" and tuid ~= nil then
				party:kick(player, tuid)
			end
		elseif op == OP.SPECTATE_LOBBY then
			local id = ...
			if directory == nil or type(id) ~= "string" or #id > 64 or joining_lobby[player] then
				return
			end
			joining_lobby[player] = true
			task.spawn(function()
				local ok, err = directory:spectate(player, id)
				joining_lobby[player] = nil
				if ok then
					return -- the teleport is under way
				end
				if err == "studio" then
					-- Studio (no teleports): watch the lobby this server plays itself
					if studio_lobby ~= nil and studio_lobby.id == id and server:stage() ~= "idle" then
						spectating[player] = true
						local nm = if player.DisplayName ~= "" then player.DisplayName else player.Name
						server:on_client(
							player,
							{ uid = tostring(player.UserId), name = nm, spectate = true },
							OP.JOIN,
							nm
						)
						return
					end
					err = "That match has ended."
				end
				send(player, OP.JOIN_RESULT, false, err)
				send(player, OP.NOTICE, err or "Couldn't open that match.", 1)
			end)
		elseif op == OP.ANALYTICS then
			local a_used = analytics_budget[player] or 0
			if a_used >= ServerMain.MAX_ANALYTICS_PER_SEC then
				return
			end
			analytics_budget[player] = a_used + 1
			local ok, err = pcall(Analytics.report, player, ...)
			if not ok then
				report_once("Analytics.report", err)
			end
			-- a solo match starts its clock here (its Stars can't outrun it: server/Rewards)
			local kind, mode = ...
			if kind == "match_start" then
				Rewards.solo_started(player, mode)
			elseif kind == "tutorial" and mode == #TutorialData.FUNNEL then
				-- the tutorial's last step: its Stars, once per player
				task.spawn(Purchases.tutorial_bonus, player, TutorialData.STARS)
			end
		elseif op == OP.SOLO_RESULT then
			local c_used = credit_budget[player] or 0
			if c_used >= ServerMain.MAX_CREDIT_USES_PER_SEC then
				return
			end
			credit_budget[player] = c_used + 1
			local report = ...
			task.spawn(function()
				local ok, err = pcall(Rewards.solo_result, player, report)
				if not ok then
					report_once("Rewards.solo_result", err)
				end
			end)
		elseif op == OP.STARTER_SEEN then
			-- the starter pack's offer is on the player's screen: its 48 hours start (once)
			local c_used = credit_budget[player] or 0
			if c_used >= ServerMain.MAX_CREDIT_USES_PER_SEC then
				return
			end
			credit_budget[player] = c_used + 1
			task.spawn(function()
				if Purchases.starter_seen(player) then
					pcall(Analytics.report, player, "starter", "shown")
				end
			end)
		elseif op == OP.SOLO_HOP then
			-- the player starts a solo match on an outdated hub: to a fresh server, where it starts
			local difficulty, map_id = ...
			local now_s = os.clock()
			if
				fresh == nil
				or type(difficulty) ~= "number"
				or (map_id ~= nil and (type(map_id) ~= "string" or #map_id > 64))
				or now_s - (hop_at[player] or -1e9) < ServerMain.HOP_GAP_S
			then
				send(player, OP.HOP_RESULT, false)
				return
			end
			hop_at[player] = now_s
			task.spawn(function()
				local target = if fresh:is_outdated() then fresh:pick() else nil
				local going = false
				if target ~= nil and player.Parent ~= nil then
					local ok, err = pcall(function()
						local opts = Instance.new("TeleportOptions")
						opts.ServerInstanceId = target
						opts:SetTeleportData(handoff:stamp({ player }, {
							hop = true,
							solo = { d = math.clamp(math.floor(difficulty), 0, 2), m = map_id },
						}))
						game:GetService("TeleportService"):TeleportAsync(game.PlaceId, { player }, opts)
					end)
					going = ok
					if not ok then
						warn("[Fresh] hop failed: " .. tostring(err))
					end
				end
				print(
					string.format("[Fresh] %s: %s", player.Name, if going then "to " .. tostring(target) else "stays")
				)
				pcall(
					Analytics.report,
					player,
					"hop",
					if going then "sent" elseif target == nil then "none" else "failed"
				)
				send(player, OP.HOP_RESULT, going)
			end)
		elseif op == OP.BUY_UNLOCK then
			local c_used = credit_budget[player] or 0
			local key = ...
			if c_used >= ServerMain.MAX_CREDIT_USES_PER_SEC or type(key) ~= "string" or #key > 32 then
				return
			end
			credit_budget[player] = c_used + 1
			task.spawn(function()
				local ok, err = Purchases.buy_unlock(player, key)
				send(player, OP.UNLOCK_RESULT, key, ok, err)
				if ok then
					pcall(Analytics.report, player, "unlocked", key, "stars")
				end
			end)
		elseif op == OP.REDEEM_CODE then
			-- a redeem code from the Settings window (server/MyCodes: the owner's list). A few tries a
			-- minute per player: guessing codes must not be worth trying.
			local text = ...
			if type(text) ~= "string" or #text > 64 then
				return
			end
			local c_used = credit_budget[player] or 0
			if c_used >= ServerMain.MAX_CREDIT_USES_PER_SEC then
				return
			end
			credit_budget[player] = c_used + 1
			local now_c = os.clock()
			local tries = code_tries[player]
			if tries == nil or now_c - tries.since >= ServerMain.CODE_WINDOW_S then
				tries = { since = now_c, n = 0 }
				code_tries[player] = tries
			end
			if tries.n >= ServerMain.CODE_TRIES then
				send(player, OP.CODE_RESULT, false, "slow")
				return
			end
			tries.n += 1
			task.spawn(function()
				local ok, why, stars = Purchases.redeem_code(player, text)
				if not ok and type(why) == "string" and string.sub(why, 1, 5) == "store" then
					why = "store"
				end
				send(player, OP.CODE_RESULT, ok, why, stars)
			end)
		elseif op == OP.RANK_GET then
			-- the RANK window: the two lists and this player's totals (server/Ranking; the lists come
			-- from this server's copy, read from the stores every Ranking.REFRESH_S)
			local t = os.clock()
			if rank_busy[player] or t - (rank_at[player] or -math.huge) < ServerMain.RANK_GAP_S then
				return
			end
			rank_at[player] = t
			rank_busy[player] = true
			task.spawn(function()
				-- (a week that closed while they were here: its prizes, before the lists are sent)
				if rank_prizes ~= nil then
					pcall(rank_prizes, player)
				end
				local ok, payload = pcall(Ranking.get, player)
				rank_busy[player] = nil
				if not ok then
					report_once("Ranking.get", payload)
					payload = Ranking.empty()
				end
				if type(payload.week) == "table" then
					-- the player's own side of the weekly ranking: the insignia worn now and the
					-- last prize paid
					local badge, on = Purchases.rank_badge(player)
					payload.week.badge = badge
					payload.week.badge_on = on
					payload.week.last = Purchases.rank_last(player)
				end
				if player.Parent == Players then
					send(player, OP.RANK, payload)
				end
			end)
		elseif op == OP.ADMIN then
			-- the owner's panel: who is asking is checked there, for every request
			if admin_op ~= nil then
				admin_op(player, ...)
			end
		elseif op == OP.RANK_CLAIM then
			-- the RANK window's CLAIM button: the Coroas the weekly ranking left this player
			-- (Purchases.rank_claim pays each prize once; the answer says how much came)
			if rank_claiming[player] then
				return
			end
			-- (nothing to claim, by the record this server holds: answered without asking the store;
			-- and a store that just failed is not asked again right away)
			local c_now = os.clock()
			if Purchases.rank_claimable(player) == nil then
				send(player, OP.RANK_CLAIMED, true, 0)
				-- (their screen may still show a prize whose time ran out: the inventory says it is gone)
				if Purchases.rank_week(player) then
					send(player, OP.INVENTORY, inventory_of(player))
				end
				return
			elseif c_now - (rank_claim_at[player] or -math.huge) < ServerMain.RANK_CLAIM_GAP_S then
				send(player, OP.RANK_CLAIMED, false, 0)
				return
			end
			rank_claim_at[player] = c_now
			rank_claiming[player] = true
			task.spawn(function()
				local ok, paid, total = pcall(Purchases.rank_claim, player)
				rank_claiming[player] = nil
				if not ok then
					report_once("Purchases.rank_claim", paid)
					paid = nil
				end
				if player.Parent == Players then
					local got = if paid ~= nil then (tonumber(total) or 0) else 0
					send(player, OP.RANK_CLAIMED, paid ~= nil, got)
					if paid == nil then
						send(player, OP.NOTICE, "Não foi possível resgatar agora. Tente de novo em instantes.", 0)
					elseif got > 0 then
						send(player, OP.NOTICE, string.format("Rank Semanal: +%d Coroas resgatadas!", got), 0)
					end
				end
			end)
		elseif op == OP.OPEN_CRATE then
			local c_used = credit_budget[player] or 0
			if c_used >= ServerMain.MAX_CREDIT_USES_PER_SEC then
				return
			end
			credit_budget[player] = c_used + 1
			local crate_kind = ...
			if crate_kind ~= nil and (type(crate_kind) ~= "string" or #crate_kind > 8) then
				return
			end
			task.spawn(function()
				local ok, res, back = Purchases.open_crate(player, crate_kind)
				-- (back: the Coroas a duplicate paid, 0 for a new item)
				send(player, OP.CRATE_RESULT, ok, res, if ok then back or 0 else nil)
				if ok then
					pcall(Analytics.report, player, "crate_opened", res)
				end
			end)
		elseif op == OP.BUY_CRATES then
			-- crates for Coroas: for every player (Robux are the other way, offered only to a player
			-- Roblox lets buy paid random items: PolicyService).
			local c_used = credit_budget[player] or 0
			local n = ...
			if c_used >= ServerMain.MAX_CREDIT_USES_PER_SEC or type(n) ~= "number" then
				return
			end
			credit_budget[player] = c_used + 1
			task.spawn(function()
				local ok, why = Purchases.buy_crates(player, n)
				if not ok and type(why) == "string" and string.sub(why, 1, 5) == "store" then
					why = "store"
				end
				send(player, OP.CRATES_RESULT, ok, why)
				if ok then
					pcall(Analytics.report, player, "credit_bought", "crate_stars", n)
				end
			end)
		elseif op == OP.SHOP_PICK or op == OP.SHOP_BUY then
			local c_used = credit_budget[player] or 0
			local item_id = ...
			if c_used >= ServerMain.MAX_CREDIT_USES_PER_SEC or type(item_id) ~= "string" or #item_id > 40 then
				return
			end
			credit_budget[player] = c_used + 1
			if op == OP.SHOP_PICK then
				local ok, why = Purchases.shop_pick(player, item_id)
				send(player, OP.SHOP_RESULT, "pick", ok, item_id, why)
			else
				task.spawn(function()
					local ok, why = Purchases.shop_buy(player, item_id)
					if not ok and type(why) == "string" and string.sub(why, 1, 5) == "store" then
						why = "store"
					end
					send(player, OP.SHOP_RESULT, "buy", ok, item_id, why)
					if ok then
						pcall(Analytics.report, player, "equipped", "shop_stars")
					end
				end)
			end
		elseif op == OP.EQUIP then
			local c_used = credit_budget[player] or 0
			local slot, id = ...
			if c_used >= ServerMain.MAX_CREDIT_USES_PER_SEC or type(slot) ~= "string" then
				return
			end
			if id ~= false and (type(id) ~= "string" or #id > 40) then
				return
			end
			credit_budget[player] = c_used + 1
			task.spawn(function()
				local ok = Purchases.equip(player, slot, id)
				if ok and id ~= false then
					pcall(Analytics.report, player, "equipped", slot)
				end
			end)
		elseif op == OP.USE_CREDIT then
			local c_used = credit_budget[player] or 0
			local kind, target = ...
			if c_used >= ServerMain.MAX_CREDIT_USES_PER_SEC or type(kind) ~= "string" or #kind > 48 then
				return
			end
			credit_budget[player] = c_used + 1
			if kind == "studio_grant:starter" then
				-- dev diagnostics (Studio + AF_DIAG only): the starter pack's receipt, through its real
				-- checks (refused unless its offer runs)
				if RunService:IsStudio() and diag ~= nil then
					task.spawn(Purchases.grant, player.UserId, "starter", "studio-" .. HttpService:GenerateGUID(false))
				end
				return
			end
			if kind == "studio_grant:takeover" or kind == "studio_grant:crate" then
				-- dev diagnostics (Studio + AF_DIAG only): a test credit without a real product
				if RunService:IsStudio() and diag ~= nil then
					local k = if kind == "studio_grant:crate" then "crate" else "takeover"
					task.spawn(Purchases.grant, player.UserId, k, "studio-" .. HttpService:GenerateGUID(false))
				end
				return
			end
			if string.sub(kind, 1, 13) == "studio_grant:" then
				-- dev diagnostics (Studio + AF_DIAG only): test Stars ("studio_grant:stars", target =
				-- how many) or a test unlock / shop purchase as if bought with Robux
				-- ("studio_grant:unlock:<key>", "studio_grant:shopbuy:<rarity>")
				if RunService:IsStudio() and diag ~= nil then
					local what = string.sub(kind, 14)
					if what == "stars" then
						task.spawn(Purchases.add_stars, player, tonumber(target) or 10000)
					elseif
						string.sub(what, 1, 7) == "unlock:"
						or string.sub(what, 1, 8) == "shopbuy:"
					then
						task.spawn(Purchases.grant, player.UserId, what, "studio-" .. HttpService:GenerateGUID(false))
					end
				end
				return
			end
			task.spawn(function()
				if kind == "takeover" and type(target) == "number" then
					-- a public match this server runs: the takeover happens here. Checked before the
					-- credit is spent, and again after (the match went on meanwhile): a nation that fell
					-- in between gives the credit back.
					if not server:can_take_over(player, target) then
						send(player, OP.CREDIT_RESULT, kind, false, "gone")
						return
					end
					local ok, err = Purchases.use(player, kind)
					if not ok then
						send(player, OP.CREDIT_RESULT, kind, false, err)
						return
					end
					if not server:take_over(player, target) then
						Purchases.grant(player.UserId, kind, "refund-" .. HttpService:GenerateGUID(false))
						send(player, OP.CREDIT_RESULT, kind, false, "gone")
						return
					end
					send(player, OP.CREDIT_RESULT, kind, true)
					pcall(Analytics.report, player, "credit_used", kind)
					return
				end
				-- solo (the player's own match runs on their device): spend; the client takes over
				local ok, err = Purchases.use(player, kind)
				send(player, OP.CREDIT_RESULT, kind, ok, err)
				if ok then
					pcall(Analytics.report, player, "credit_used", kind)
				end
			end)
		elseif op == OP.LEAVE and is_match_server then
			-- leaving a public match's server = back to a hub
			pcall(Analytics.report, player, "left")
			pcall(server.leave, server, player)
			task.spawn(function()
				teleports.to_hub({ player })
			end)
		else
			local name = player.DisplayName
			if name == "" then
				name = player.Name
			end
			local ok, err = xpcall(
				server.on_client,
				debug.traceback,
				server,
				player,
				{ uid = tostring(player.UserId), name = name, spectate = spectating[player] == true },
				op,
				...
			)
			if not ok then
				report_once("on_client op " .. tostring(op), err)
			end
		end
	end)

	-- Deep-link launch data (roblox://experiences/start?placeId=…&launchData=…) for the client's
	-- owner-only test hooks (Main.launch_hooks). Short strings only; the client decides what to honour.
	local function tag_launch(player: Player)
		local ok, jd = pcall(function()
			return player:GetJoinData()
		end)
		local ld = if ok and type(jd) == "table" then jd.LaunchData else nil
		if type(ld) == "string" and #ld > 0 and #ld <= 64 then
			player:SetAttribute("AF_LaunchData", ld)
		end
	end
	--- Humans on this server who came to play (spectators don't count for the lobby / bot fill).
	local function players_present(leaving: Player?): number
		local n = 0
		for _, p in Players:GetPlayers() do
			if p ~= leaving and not spectating[p] then
				n += 1
			end
		end
		return n
	end
	--- Their user ids (the lobby's seat ledger: MatchHost.set_roster).
	local function present_uids(leaving: Player?): { string }
		local out = {}
		for _, p in Players:GetPlayers() do
			if p ~= leaving and not spectating[p] then
				table.insert(out, tostring(p.UserId))
			end
		end
		return out
	end
	--- A hub's Watch teleport carries { spectate = true }: that player only watches this match.
	local function tag_spectator(player: Player)
		if not is_match_server then
			return
		end
		local ok, jd = pcall(function()
			return player:GetJoinData()
		end)
		local td = if ok and type(jd) == "table" then jd.TeleportData else nil
		if type(td) == "table" and td.spectate == true then
			spectating[player] = true
		end
		-- a party's members (LobbyDirectory.join): one team in a team game, and back to one hub
		local pd = if type(td) == "table" then td.party else nil
		if type(pd) == "table" and type(pd.key) == "string" and #pd.key <= 64 then
			party_by_uid[tostring(player.UserId)] = pd.key
			if tonumber(pd.leader) ~= nil then
				party_leader[pd.key] = tonumber(pd.leader) :: number
			end
		end
	end
	--- A hub: the party `player` came back with from a match, or the Roblox party it came in.
	local function join_party_on_arrival(player: Player)
		if party == nil then
			return
		end
		local ok, jd = pcall(function()
			return player:GetJoinData()
		end)
		local td = if ok and type(jd) == "table" then jd.TeleportData else nil
		local parties = if type(td) == "table" then td.parties else nil
		local key = if type(parties) == "table" then parties[tostring(player.UserId)] else nil
		if type(key) == "string" and #key <= 64 then
			local leaders = if type(td.leaders) == "table" then td.leaders else {}
			party:arrived(player, key, tonumber(leaders[key]))
			return
		end
		local pid_ok, pid = pcall(function()
			return (player :: any).PartyId
		end)
		if pid_ok and type(pid) == "string" and pid ~= "" then
			local o_ok, others = pcall(function()
				return game:GetService("SocialService"):GetPlayersByPartyId(pid)
			end)
			if o_ok and type(others) == "table" then
				party:join_roblox_party(player, others)
			end
		end
	end
	-- Game admins (the game's owner, or rank 254+ in the owning group; everyone in a Studio playtest)
	-- are told which "players" are bot players — nobody else ever receives it (bots look like players).
	-- Their Player has the AF_Admin attribute (set here only, so a client can't give it itself).
	local admins: { [Player]: boolean } = {}
	local admin_sent: { [Player]: string } = {}
	-- (AdminCheck: the group's owner once per server, each player's answer shared by every server)
	local admin_cache: any = nil
	pcall(function()
		admin_cache = game:GetService("MemoryStoreService"):GetHashMap("admins_v1")
	end)
	local admin_check = AdminCheck.new({
		studio = RunService:IsStudio(),
		group = game.CreatorType == Enum.CreatorType.Group,
		creator_id = game.CreatorId,
		rank = function(player: Player): number
			return player:GetRankInGroup(game.CreatorId)
		end,
		owner = function(): number?
			local info = game:GetService("GroupService"):GetGroupInfoAsync(game.CreatorId)
			return if type(info) == "table" and type(info.Owner) == "table" then info.Owner.Id else nil
		end,
		cache_get = if admin_cache ~= nil
			then function(key: string): any
				return admin_cache:GetAsync(key)
			end
			else nil,
		cache_set = if admin_cache ~= nil
			then function(key: string, value: any, ttl_s: number)
				admin_cache:SetAsync(key, value, ttl_s)
			end
			else nil,
	})
	local function check_admin(player: Player)
		task.spawn(function()
			for attempt = 1, #AdminCheck.RETRY_S + 1 do
				local ok, yes = pcall(admin_check.is_admin, admin_check, player)
				if player.Parent ~= Players then
					return
				end
				if ok then
					if yes then
						admins[player] = true
						player:SetAttribute("AF_Admin", true)
						print(string.format("[Admin] %s (%d): game admin", player.Name, player.UserId))
					end
					return
				end
				if attempt > #AdminCheck.RETRY_S then
					warn(string.format("[Admin] check for %s failed: %s", player.Name, tostring(yes)))
					return
				end
				task.wait(AdminCheck.RETRY_S[attempt])
			end
		end)
	end
	-- The owner's panel (OP.ADMIN; server/AdminActions; client UI/AdminPanel). The lobby shows its
	-- button to who has AF_Admin, but that is only for show: a client can draw any button it likes.
	-- What counts is `admins[player]`, which only the check above ever sets, asked here for EVERY
	-- request. Anyone else is told no, and learns nothing (no code, no balance, no list).
	local admin_busy: { [Player]: boolean } = {}
	local admin_at: { [Player]: number } = {}
	local admin_refused: { [Player]: boolean } = {}
	local admin_random = Random.new()
	local function is_admin(p: any): boolean
		return admins[p] == true
	end
	admin_op = function(player: Player, action: any, args: any)
		if admins[player] ~= true then
			if not admin_refused[player] then
				admin_refused[player] = true
				warn(
					string.format(
						"[Admin] %s (%d) asked for the owner's panel and is not a game admin: refused",
						player.Name,
						player.UserId
					)
				)
				send(player, OP.ADMIN_RESULT, { action = "?", ok = false, denied = true, text = AdminActions.DENIED })
			end
			return
		end
		if type(action) ~= "string" or #action > 24 or (args ~= nil and type(args) ~= "table") then
			return
		end
		local t = os.clock()
		if admin_busy[player] or t - (admin_at[player] or -math.huge) < ServerMain.ADMIN_GAP_S then
			send(player, OP.ADMIN_RESULT, {
				action = action,
				ok = false,
				busy = true,
				text = "Ainda estou fazendo o pedido anterior. Aguarde um instante.",
			})
			return
		end
		admin_at[player] = t
		admin_busy[player] = true
		task.spawn(function()
			local ok, reply = pcall(AdminActions.run, action, args, player, {
				is_owner = is_admin,
				players = function(): { Player }
					return Players:GetPlayers()
				end,
				adjust = Purchases.adjust_stars,
				currency = (require(Shared.Data.Brand) :: any).CURRENCY,
				store = CodeStore,
				now = os.time,
				random = function(n: number): number
					return admin_random:NextInteger(1, n)
				end,
				fixed = Codes.all,
				rank_remove = Ranking.remove,
				rank_find = Ranking.find,
			})
			admin_busy[player] = nil
			if not ok or type(reply) ~= "table" then
				warn(string.format("[Admin] %s: %s failed: %s", player.Name, action, tostring(reply)))
				reply = { action = action, ok = false, text = "O pedido falhou no servidor. Nada mudou." }
			elseif action ~= "state" then
				print(string.format("[Admin] %s (%d): %s -> %s", player.Name, player.UserId, action, tostring(reply.text)))
			end
			if player.Parent == Players then
				send(player, OP.ADMIN_RESULT, reply)
			end
		end)
	end
	-- The owner's redeem codes (server/MyCodes): say what is wrong in the list, once, in the server's log
	for _, line in Codes.problems() do
		warn("[MyCodes] " .. line)
	end
	-- The owner's currency commands (server/OwnerCommands): "/moedas dar <player> <amount>",
	-- "/moedas tirar ...", "/moedas ver ...", typed in the chat by a game admin. The chat reports a
	-- message in two ways (Player.Chatted, and the TextChatCommand below, which also keeps the
	-- command out of everyone else's chat): whichever arrives, a command runs once.
	local command_last: { [Player]: { text: string, at: number } } = {}
	-- The owner's code commands (server/CodeCommands): "/codigo criar <NAME> <amount>", "/codigo
	-- gerar ...", "/codigo lista", ... The codes they make live in server/CodeStore, for every server.
	local code_random = Random.new()
	local function owner_command(player: Player, text: any)
		if type(text) ~= "string" or #text > 200 then
			return
		end
		local for_codes = CodeCommands.is_command(text)
		if not for_codes and not OwnerCommands.is_command(text) then
			return
		end
		local last = command_last[player]
		local t = os.clock()
		if last ~= nil and last.text == text and t - last.at < 1.0 then
			return
		end
		command_last[player] = { text = text, at = t }
		if for_codes then
			task.spawn(function()
				local ok, reply, bad, lines = pcall(CodeCommands.run, text, player, {
					is_owner = function(p: Player): boolean
						return admins[p] == true
					end,
					store = CodeStore,
					now = os.time,
					random = function(n: number): number
						return code_random:NextInteger(1, n)
					end,
					currency = (require(Shared.Data.Brand) :: any).CURRENCY,
					fixed = Codes.all,
				})
				if not ok then
					warn(string.format("[Owner] %s: %s failed: %s", player.Name, text, tostring(reply)))
					send(player, OP.NOTICE, "O comando falhou. Nada mudou.", 1)
				elseif reply ~= nil then
					print(string.format("[Owner] %s (%d): %s -> %s", player.Name, player.UserId, text, reply))
					if type(lines) == "table" and #lines > 1 then
						-- (the whole answer, for the server's log: F9 > Server > Log)
						for _, line in lines do
							print("[Owner]   " .. tostring(line))
						end
					end
					-- (the third value: the answer also stays in the sender's chat window, where a
					-- code just created can still be read after the notice is gone)
					send(player, OP.NOTICE, reply, if bad then 1 else 0, if type(lines) == "table" then lines else nil)
				end
			end)
			return
		end
		task.spawn(function()
			local ok, reply, bad = pcall(OwnerCommands.run, text, player, {
				is_owner = function(p: Player): boolean
					return admins[p] == true
				end,
				players = function(): { Player }
					return Players:GetPlayers()
				end,
				adjust = Purchases.adjust_stars,
				currency = (require(Shared.Data.Brand) :: any).CURRENCY,
			})
			if not ok then
				warn(string.format("[Owner] %s: %s failed: %s", player.Name, text, tostring(reply)))
				send(player, OP.NOTICE, "O comando falhou. Nada mudou.", 1)
			elseif reply ~= nil then
				print(string.format("[Owner] %s (%d): %s -> %s", player.Name, player.UserId, text, reply))
				send(player, OP.NOTICE, reply, if bad then 1 else 0)
			end
		end)
	end
	local function watch_chat(player: Player)
		player.Chatted:Connect(function(message: string)
			owner_command(player, message)
		end)
	end
	pcall(function()
		local chat = game:GetService("TextChatService")
		local command = Instance.new("TextChatCommand")
		command.Name = "OwnerCurrency"
		command.PrimaryAlias = OwnerCommands.ALIASES[1]
		command.SecondaryAlias = OwnerCommands.ALIASES[2]
		command.Triggered:Connect(function(source: TextSource, message: string)
			local player = Players:GetPlayerByUserId(source.UserId)
			if player ~= nil then
				owner_command(player, message)
			end
		end)
		command.Parent = chat
	end)
	-- (a chat command has two names: one command for each pair of CodeCommands.ALIASES, each made
	-- on its own, so one that Roblox refuses does not take the others with it)
	for i = 1, #CodeCommands.ALIASES, 2 do
		local made, err = pcall(function()
			local chat = game:GetService("TextChatService")
			local code_command = Instance.new("TextChatCommand")
			code_command.Name = "OwnerCodes" .. tostring((i + 1) // 2)
			code_command.PrimaryAlias = CodeCommands.ALIASES[i]
			if CodeCommands.ALIASES[i + 1] ~= nil then
				code_command.SecondaryAlias = CodeCommands.ALIASES[i + 1]
			end
			code_command.Triggered:Connect(function(source: TextSource, message: string)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player ~= nil then
					owner_command(player, message)
				end
			end)
			code_command.Parent = chat
		end)
		if not made then
			warn(string.format("[Owner] the chat command %s could not be made: %s", CodeCommands.ALIASES[i], tostring(err)))
		end
	end
	--- Bot players of the running match (owner ids) to each admin, whenever the match changes.
	local function push_admin_bots()
		local sim = server:sim()
		local ids = {}
		if sim ~= nil and sim.o_bot ~= nil then
			for id = 1, sim.owner_total do
				if sim.o_bot[id] == 1 then
					table.insert(ids, id)
				end
			end
		end
		local key = tostring(sim) .. ":" .. #ids
		for p in admins do
			if listening[p] and admin_sent[p] ~= key then
				admin_sent[p] = key
				send(p, OP.ADMIN_BOTS, ids)
			end
		end
	end
	-- Creator Dashboard analytics: match counts live in the saved settings; on a match server the
	-- killer of an eliminated player is classified here (clients can't tell bot players apart)
	Analytics.configure({
		cosmetic = function(id: string): any
			local C = require(Shared.Data.Cosmetics) :: any
			return C.item(id)
		end,
		--- a shop item's name and price (Robux), for "Shop Item Bought"
		shop_item = function(id: string): (string?, number)
			local it = (require(Shared.Data.Cosmetics) :: any).item(id)
			if it == nil then
				return nil, 0
			end
			local S = require(Shared.Data.Shop) :: any
			local p = (require(Shared.Data.Products) :: any)[S.product_key(it.rarity)]
			return it.name, if p ~= nil then p.robux else 0
		end,
		tutorial_steps = TutorialData.FUNNEL,
		arsenal_title = function(key: string): string?
			local it = (require(Shared.Data.Arsenal) :: any).item(key)
			return if it ~= nil then it.title else nil
		end,
		load_stats = function(player: Player, fn: (any) -> ())
			SettingsStore.when_loaded(player, function(data: any)
				fn(if type(data) == "table" then data[Analytics.STATS] else nil)
			end)
		end,
		save_stats = function(player: Player, stats: any)
			-- (Studio playtests write the real DataStore: they must not count as the owner's matches;
			-- and after a failed load the count starts from nothing: saving it would put a veteran's
			-- matches back to 1)
			if not RunService:IsStudio() and not SettingsStore.load_failed(player) then
				SettingsStore.set(player, Analytics.STATS, stats)
			end
		end,
		classify = function(id: number): string?
			local sim = server:sim()
			if sim == nil or id < 1 or id > (sim.owner_total or 0) then
				return nil
			end
			local Defs = core("Defs")
			local k = sim.o_kind[id]
			if k == Defs.KIND_HUMAN then
				return if sim.o_bot ~= nil and sim.o_bot[id] == 1 then "bot" else "human"
			end
			return if k == Defs.KIND_TRIBE then "tribe" else "nation"
		end,
	})
	-- Paid random items (the cosmetic crates) are not offered where Roblox's policy restricts them
	-- (PolicyService.ArePaidRandomItemsRestricted); unknown until checked = restricted.
	local crates_allowed: { [Player]: boolean } = {}
	--- the policy was asked (an answer or not): RoWorld General's daily perk waits for it
	local policy_known: { [Player]: boolean } = {}
	inventory_of = function(player: Player): any
		local inv = Purchases.inventory(player)
		inv.crates_allowed = crates_allowed[player] == true
		-- (this player's crates cost Coroas: the client shows that price and asks with BUY_CRATES)
		inv.crates_stars = crates_for_stars(player)
		return inv
	end
	--- (Coroas pay a crate for every player: 2026-11-10. Robux are the other way, where
	--- crates_allowed says so.)
	crates_for_stars = function(_player: Player): boolean
		return true
	end
	local function check_policy(player: Player)
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		crates_allowed[player] = ok and type(info) == "table" and info.ArePaidRandomItemsRestricted == false
		policy_known[player] = true
		send(player, OP.INVENTORY, inventory_of(player))
	end
	-- Robux purchases: a receipt is a stored credit before Roblox hears it was granted
	-- (Studio playtests write the real DataStores: their test credits go to a store of their own)
	local store_name = Purchases.STORE .. (if RunService:IsStudio() then "_studio" else "")
	local got_store, purchase_store = pcall(function()
		-- (budget-aware, throttled requests sent again: DsGate)
		return DsGate.wrap(DataStoreService:GetDataStore(store_name))
	end)
	if not got_store then
		if not RunService:IsStudio() then
			error(purchase_store)
		end
		-- an unpublished place open in Studio has no DataStores: the records last for this session
		warn("[Purchases] no DataStore here (an unpublished place): purchases are kept for this session only")
		local rows: { [string]: any } = {}
		purchase_store = {
			GetAsync = function(_: any, k: string): any
				return rows[k]
			end,
			UpdateAsync = function(_: any, k: string, fn: (any) -> any): any
				local v = fn(rows[k])
				if v ~= nil then
					rows[k] = v
				end
				return v
			end,
		}
	end
	-- The codes the owner creates by chat command (server/CodeStore): one key of a store of their
	-- own, read by every server (a Studio playtest has its own, as the purchases do: a code made
	-- while testing is not a code of the published game)
	do
		local got_codes, code_ds = pcall(function()
			return DsGate.wrap(
				DataStoreService:GetDataStore(CodeStore.STORE .. (if RunService:IsStudio() then "_studio" else ""))
			)
		end)
		if not got_codes then
			if not RunService:IsStudio() then
				warn("[Codes] no DataStore for the created codes: " .. tostring(code_ds))
			end
			-- an unpublished place open in Studio has no DataStores: the codes last for this session
			local held: any = nil
			code_ds = {
				GetAsync = function(_: any, _k: string): any
					return held
				end,
				UpdateAsync = function(_: any, _k: string, fn: (any) -> any): any
					local v = fn(held)
					if v ~= nil then
						held = v
					end
					return v
				end,
			}
		end
		CodeStore.configure({ store = code_ds, log = print })
	end
	Purchases.configure({
		datastore = purchase_store,
		code_store = CodeStore,
		players = Players,
		notify = function(player: Player, credits: any)
			send(player, OP.CREDITS, credits)
		end,
		inventory = function(player: Player, _inv: any)
			send(player, OP.INVENTORY, inventory_of(player))
			-- the weekly ranking's insignia, where every client can read it (the chat's tag:
			-- client/ChatBadge)
			pcall(function()
				local badge, on = Purchases.rank_badge(player)
				player:SetAttribute("RankBadge", badge)
				player:SetAttribute("RankBadgeWins", if on ~= nil then on.wins else nil)
				player:SetAttribute("RankBadgeKills", if on ~= nil then on.kills else nil)
			end)
		end,
		shop_bought = function(player: Player, item_id: string?)
			send(player, OP.SHOP_RESULT, "bought", true, item_id)
			local spent = shop_spent[player]
			shop_spent[player] = nil
			if item_id ~= nil then
				pcall(Analytics.report, player, "flag_shop", "bought", item_id, spent)
			end
		end,
		bought = function(player: Player, kind: string, count: number?, spent: number?)
			if kind == "starter" then
				pcall(Analytics.report, player, "starter", "bought")
				return
			end
			if string.sub(kind, 1, 8) == "shopbuy:" then
				-- (the Loja Misteriosa: which item it was comes with shop_bought, below)
				pcall(Analytics.report, player, "credit_bought", kind, count)
				shop_spent[player] = spent
				return
			end
			pcall(Analytics.report, player, "credit_bought", kind, count)
			local key = string.match(kind, "^unlock:(.+)$")
			if key ~= nil then
				pcall(Analytics.report, player, "unlocked", key, "robux")
			end
		end,
		-- an Arsenal unlock (Stars or Robux): the match the player is in lets them use it at once
		-- (also a record that could only be read late: Purchases.load)
		unlocked = function(player: Player, _key: string)
			pcall(server.unlocks_changed, server, player)
		end,
		wait = task.wait,
		log = print,
		warn = warn,
		-- teleported here by a server of ours: the record it held when they left
		arrived = function(player: Player): any
			return handoff:arrived(player)
		end,
		-- (RoWorld offers its starter pack in Studio before the product exists, as a test prompt.
		-- This version has no Robux products at all: the pack is never offered, in Studio either)
		studio = false,
	})
	SettingsStore.connect_handoff(function(player: Player): any
		return handoff:arrived(player)
	end, function(player: Player, settings: any)
		handoff:part(player, "s", settings)
	end)
	-- The global ranking (server/Ranking): two ordered stores, shared by every server of the game
	-- (Studio playtests write stores of their own, as the purchases do: a test must not put the
	-- owner on the real lists)
	do
		local rank_stores: { [string]: any } = {}
		local rank_memory = false
		--- An unpublished place open in Studio has no DataStores: the lists last for this session.
		local function memory_store(): any
			local rows: { [string]: number } = {}
			return {
				IncrementAsync = function(_: any, k: string, d: number): number
					rows[k] = (rows[k] or 0) + d
					return rows[k]
				end,
				GetAsync = function(_: any, k: string): number?
					return rows[k]
				end,
				RemoveAsync = function(_: any, k: string): number?
					local old = rows[k]
					rows[k] = nil
					return old
				end,
				GetSortedAsync = function(_: any, _asc: boolean, size: number): any
					local page = {}
					for k, v in rows do
						table.insert(page, { key = k, value = v })
					end
					table.sort(page, function(a, b)
						return a.value > b.value
					end)
					for i = #page, size + 1, -1 do
						page[i] = nil
					end
					return {
						GetCurrentPage = function(): any
							return page
						end,
					}
				end,
			}
		end
		local UserService = game:GetService("UserService")
		Ranking.configure({
			time = os.time,
			-- (`week`: that week's store of the weekly lists; nil: the all-time store)
			store = function(board: string, week: number?): any
				local base = if week ~= nil
					then string.format("%s_%d", Ranking.WEEK_STORES[board], week)
					else Ranking.STORES[board]
				local st = rank_stores[base]
				if st == nil then
					local name = base .. (if RunService:IsStudio() then "_studio" else "")
					local got, res = pcall(function()
						return DataStoreService:GetOrderedDataStore(name)
					end)
					local function in_memory(): any
						if not rank_memory then
							rank_memory = true
							warn("[Ranking] no DataStore here (Studio without API access, or an unpublished place): the ranking is kept for this session only")
						end
						return memory_store()
					end
					if got and not RunService:IsStudio() then
						st = res
					elseif got then
						-- Studio: the store exists but refuses every request while "Enable Studio
						-- Access to API Services" is off; the first refusal moves this board to memory
						local real: any, mem: any = res, nil
						local function through(method: string)
							return function(_: any, ...: any): any
								if mem == nil then
									local ok, out = pcall(real[method], real, ...)
									if ok then
										return out
									end
									mem = in_memory()
								end
								return mem[method](mem, ...)
							end
						end
						st = {
							IncrementAsync = through("IncrementAsync"),
							GetAsync = through("GetAsync"),
							GetSortedAsync = through("GetSortedAsync"),
							RemoveAsync = through("RemoveAsync"),
						}
					else
						if not RunService:IsStudio() then
							error(res)
						end
						st = in_memory()
					end
					rank_stores[base] = st
				end
				return st
			end,
			-- display names, in one request for a whole list (a user Roblox no longer has is left out)
			names = function(ids: { number }): { [number]: string }
				local out: { [number]: string } = {}
				for _, info in UserService:GetUserInfosByUserIdsAsync(ids) do
					local shown = if type(info.DisplayName) == "string" and info.DisplayName ~= ""
						then info.DisplayName
						else info.Username
					if type(info.Id) == "number" and type(shown) == "string" then
						out[info.Id] = shown
					end
				end
				return out
			end,
			online = function(uid: number): boolean
				return Players:GetPlayerByUserId(uid) ~= nil
			end,
			now = os.clock,
			wait = task.wait,
			log = print,
			warn = warn,
		})
		-- The weekly ranking's prizes (shared/Data/RankPrizes): looked at a moment after a player
		-- arrives, when the week turns and whenever they open the RANK window. Ranking.due says what
		-- the closed weeks left them, Purchases.rank_record writes it to their record once: the
		-- insignia is worn from then on, the Coroas wait for the window's CLAIM button
		-- (OP.RANK_CLAIM).
		local ORDINAL = { "1º", "2º", "3º", "4º", "5º", "6º", "7º", "8º", "9º", "10º" }
		local function prize_text(r: any): string
			local parts = {}
			if r.wins ~= nil then
				table.insert(parts, string.format("%s em Vitórias", ORDINAL[r.wins] or tostring(r.wins)))
			end
			if r.kills ~= nil then
				table.insert(parts, string.format("%s em Reinos destruídos", ORDINAL[r.kills] or tostring(r.kills)))
			end
			local text = string.format(
				"Rank Semanal: você ficou em %s. Abra o RANK e resgate %d Coroas.",
				table.concat(parts, " e "),
				r.stars or 0
			)
			if r.week == Ranking.week() - 1 and RankPrizes.badge(RankPrizes.best(r.wins, r.kills)) ~= nil then
				text ..= " Sua insígnia vale até domingo."
			end
			return text
		end
		rank_prizes = function(player: Player)
			if not Ranking.WEEKLY_ON or rank_settling[player] then
				return
			end
			local loaded, settled = Purchases.rank_week(player)
			if not loaded then
				return
			end
			rank_settling[player] = true
			local ok, err = pcall(function()
				local upto, results = Ranking.due(player.UserId, settled)
				if upto == nil or results == nil or #results == 0 or player.Parent ~= Players then
					return
				end
				local written = Purchases.rank_record(player, upto, results)
				for _, r in (written or {}) do
					send(player, OP.NOTICE, prize_text(r), 0)
				end
			end)
			rank_settling[player] = nil
			if not ok then
				report_once("rank_prizes", err)
			end
		end
	end
	-- The week turns while players are here: last week's insignias come off at once, and
	-- Ranking.SETTLE_DELAY_S later the new ones go on and the winners' RANK button gets its mark.
	-- (The hub only: a match's cosmetics are sent when it starts, and its players pass through the
	-- hub on their way back.)
	if rank_prizes ~= nil and not is_match_server then
		task.spawn(function()
			local seen = Ranking.week()
			local looked = seen
			while true do
				task.wait(ServerMain.RANK_WEEK_POLL_S)
				local ok, err = pcall(function()
					local w = Ranking.week()
					if w ~= seen then
						seen = w
						for _, p in Players:GetPlayers() do
							-- (the inventory carries the insignia: gone now)
							if Purchases.rank_week(p) then
								send(p, OP.INVENTORY, inventory_of(p))
								p:SetAttribute("RankBadge", nil)
								p:SetAttribute("RankBadgeWins", nil)
								p:SetAttribute("RankBadgeKills", nil)
							end
						end
					end
					if w ~= looked and os.time() - RankPrizes.week_start(w) >= Ranking.SETTLE_DELAY_S then
						looked = w
						for _, p in Players:GetPlayers() do
							task.spawn(function()
								pcall(rank_prizes, p)
							end)
							task.wait(0.2)
						end
					end
				end)
				if not ok then
					report_once("rank week", err)
				end
			end
		end)
	end
	--- A player who just arrived: their weekly prizes, once their record is here and their screen is up.
	local function rank_prizes_soon(player: Player)
		task.delay(ServerMain.RANK_PRIZE_JOIN_S, function()
			for _ = 1, 6 do
				if player.Parent ~= Players then
					return
				end
				if Purchases.rank_week(player) then
					break
				end
				task.wait(5)
			end
			if rank_prizes ~= nil then
				pcall(rank_prizes, player)
			end
			-- the ranked matches (shared/Data/Ranked): the month turned since their last one, so
			-- their season closes — the points start again and the rank they ended in is paid
			if player.Parent == Players then
				local ok, closed = pcall(Purchases.ranked_settle, player)
				if not ok then
					report_once("Purchases.ranked_settle", closed)
				elseif closed ~= nil then
					send(player, OP.NOTICE, Ranked.season_text(closed, OwnerCommands.commas), 0)
				end
			end
			-- the daily login reward (shared/Data/Login): the first arrival of the day pays it
			if player.Parent == Players then
				local ok, got = pcall(Purchases.login_claim, player)
				if not ok then
					report_once("Purchases.login_claim", got)
				elseif got ~= nil then
					send(player, OP.NOTICE, Login.text(got.index, got.reward, OwnerCommands.commas), 0)
				end
			end
			-- the Roblox badges earned so far (shared/Data/Badges; none is given without its id)
			if player.Parent == Players then
				pcall(BadgeAwards.sync, player, Purchases.inventory(player))
			end
		end)
	end
	BadgeAwards.configure({ service = game:GetService("BadgeService"), log = print, warn = warn })
	-- Stars for matches (shared/Data/Stars): public matches as this server measured them, solo
	-- matches on the client's report within what the clock allows
	Rewards.configure({
		add_stars = Purchases.add_stars,
		-- (a match's result counts for the player's missions, in the same write: Data/Missions)
		missions = true,
		double = function(player: Player): boolean
			return Purchases.has_unlock(player, "stars2x")
		end,
		general = General.active,
		send = function(player: Player, payload: any)
			send(player, OP.STARS, payload)
			pcall(Analytics.report, player, "stars_paid", payload.total)
		end,
		-- (a ranked match was the first write after the month turned: the season closed there)
		season_closed = function(player: Player, closed: any)
			send(player, OP.NOTICE, Ranked.season_text(closed, OwnerCommands.commas), 0)
		end,
		log = print,
	})
	-- RoWorld General (Data/Subscription; 2026-10-27): Roblox says who is subscribed; server/General
	-- gives the perks
	General.configure({
		status = function(player: Player): boolean?
			local info = (MarketplaceService :: any):GetUserSubscriptionStatusAsync(player, Subscription.id())
			return if type(info) == "table" then info.IsSubscribed == true else nil
		end,
		perks = function(player: Player, day: number, skin: string?): any
			-- (a crate or Stars: the policy decides, so wait for its answer; unknown = no crates)
			local t0 = os.clock()
			while policy_known[player] == nil and player.Parent == Players and os.clock() - t0 < 15 do
				task.wait(0.5)
			end
			return Purchases.general_perks(player, day, skin, crates_allowed[player] == true)
		end,
		send = function(player: Player, state: any)
			send(player, OP.GENERAL, state)
		end,
		subscribed = function(player: Player)
			pcall(Analytics.report, player, "general", "subscribed")
		end,
		now = os.time,
		log = print,
	})
	pcall(function()
		(Players :: any).UserSubscriptionStatusChanged:Connect(function(player: Player, sid: string)
			if sid == Subscription.id() then
				task.spawn(General.changed, player)
			end
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			pcall(General.tick)
		end
	end)
	MarketplaceService.ProcessReceipt = function(info: any): Enum.ProductPurchaseDecision
		local ok, r = pcall(Purchases.process_receipt, info)
		if ok and r == "granted" then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		if not ok then
			report_once("Purchases.process_receipt", r)
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(Purchases.load, player)
		rank_prizes_soon(player)
		task.spawn(check_policy, player)
		task.spawn(General.joined, player)
		Analytics.joined(player)
		tag_launch(player)
		tag_spectator(player)
		task.spawn(join_party_on_arrival, player)
		check_admin(player)
		watch_chat(player)
		SettingsStore.load(player)
		if host ~= nil then
			host:set_present(players_present())
			host:set_roster(present_uids())
		end
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(Purchases.load, p)
		rank_prizes_soon(p)
		task.spawn(check_policy, p)
		task.spawn(General.joined, p)
		Analytics.joined(p)
		tag_launch(p)
		tag_spectator(p)
		check_admin(p)
		watch_chat(p)
		SettingsStore.load(p)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		BadgeAwards.forget(player)
		server:peer_disconnected(player)
		listening[player] = nil
		hop_at[player] = nil
		local i = table.find(listening_list, player)
		if i then
			table.remove(listening_list, i)
		end
		msg_budget[player] = nil
		setting_budget[player] = nil
		analytics_budget[player] = nil
		credit_budget[player] = nil
		code_tries[player] = nil
		command_last[player] = nil
		crates_allowed[player] = nil
		policy_known[player] = nil
		General.release(player)
		Rewards.release(player)
		Ranking.release(player.UserId)
		rank_at[player] = nil
		rank_busy[player] = nil
		rank_settling[player] = nil
		rank_claiming[player] = nil
		rank_claim_at[player] = nil
		if handoff:leaving(player) then
			-- on one of our teleports: their record goes along once this server's writes have landed
			task.spawn(function()
				handoff:part(player, "p", Purchases.settle(player, Handoff.PART_WAIT_S - 5))
				Purchases.release(player)
			end)
		else
			Purchases.release(player)
		end
		pcall(Analytics.left, player)
		hello_at[player] = nil
		joining_lobby[player] = nil
		public_since[player] = nil
		public_sent[player] = nil
		-- in line alone, or leading a party in line: out of it (the party's others go back to idle)
		if directory ~= nil and (party == nil or party:key_of(player) == nil or party:is_leader(player)) then
			local key = public_key(player)
			local e = directory:queued(key)
			if e ~= nil then
				directory:dequeue(key)
				local others = {}
				if party ~= nil and party:key_of(player) ~= nil then
					for _, m in party:members(player) do
						if m ~= player then
							table.insert(others, m)
						end
					end
				end
				public_state(others, "idle", e.mode)
			end
		end
		if host ~= nil then
			host:set_present(players_present(player))
			host:set_roster(present_uids(player))
		end
		spectating[player] = nil
		admins[player] = nil
		admin_busy[player] = nil
		admin_at[player] = nil
		admin_refused[player] = nil
		admin_sent[player] = nil
		if party ~= nil then
			party:removed(player)
		end
	end)
	SettingsStore.start()

	local budget_time = 0.0
	local admin_time = 0.0
	local stats_time = 0.0
	local lobby_push = 0.0
	local studio_beat = 0.0
	local perf = ServerPerf.new()
	local StatsService = game:GetService("Stats")
	--- the counts at the last report (each report has the window's)
	local counted = { hits = 0, misses = 0, none = 0, sent = 0, lost = 0, lost_stars = 0 }
	--- What this server runs, for its ServerPerf report.
	local function perf_context(): { [string]: any }
		local ctx: { [string]: any } = {
			role = ServerMain.kind,
			stage = server:stage(),
			humans = server:participant_count(),
			players = #Players:GetPlayers(),
			mem_mb = StatsService:GetTotalMemoryUsageMb(),
			age_min = time() / 60,
			version = game.PlaceVersion,
			-- players who came with their records (Handoff) and who had to read the DataStores, records
			-- handed on, and Stars that could not be paid
			handoff_hits = handoff.hits - counted.hits,
			handoff_misses = handoff.misses - counted.misses,
			handoff_none = handoff.none - counted.none,
			handoff_sent = handoff.sent - counted.sent,
			stars_lost = Purchases.lost.payouts - counted.lost,
			stars_lost_amount = Purchases.lost.stars - counted.lost_stars,
		}
		counted.hits, counted.misses, counted.none, counted.sent = handoff.hits, handoff.misses, handoff.none, handoff.sent
		counted.lost, counted.lost_stars = Purchases.lost.payouts, Purchases.lost.stars
		local sim = server:sim()
		if sim ~= nil then
			ctx.minute = sim.tick * MatchServer.TICK_SEC / 60
			ctx.attacks = #sim.attacks
		end
		local l = if host ~= nil then host.lobby else nil
		if l ~= nil then
			ctx.map = l.map
			ctx.mode = l.mode or "ffa"
			ctx.max = l.max
		end
		return ctx
	end
	RunService.Heartbeat:Connect(function(dt: number)
		perf:frame(dt)
		admin_time += dt
		if admin_time >= 1.0 then
			admin_time = 0.0
			push_admin_bots()
		end
		budget_time += dt
		if budget_time >= 1.0 then
			budget_time = 0.0
			table.clear(msg_budget)
			table.clear(setting_budget)
			table.clear(analytics_budget)
			table.clear(credit_budget)
		end
		-- MatchServer guards its own tick (a failing Sim ends the match with a notice); this catches
		-- anything else so one fault can't throw on every Heartbeat.
		local ok, err = xpcall(server.process, debug.traceback, server, dt)
		if not ok then
			report_once("MatchServer.process", err)
		end
		-- public lobbies: the hub keeps the game-wide list fresh and shows it; the match server keeps
		-- its lobby record current
		-- (lobby scheduling waits for the shared clock's first measurement, a second or so)
		if directory ~= nil and SharedClock.ready() then
			directory:tick(dt, task.spawn)
			directory:tick_queue(dt, task.spawn)
			lobby_push += dt
			if lobby_push >= ServerMain.LOBBIES_PUSH_S then
				lobby_push = 0.0
				local view = directory:view()
				for _, p in listening_list do
					send(p, OP.LOBBIES, view, public_kinds)
				end
			end
			if studio_lobby ~= nil and server:participant_count() == 0 and server:stage() == "idle" then
				studio_lobby = nil
				server.deps.lobby = nil
			end
			-- Studio: the locally played lobby keeps its live record fresh (as MatchHost does live)
			local stg = server:stage()
			if studio_lobby ~= nil and (stg == "spawn" or stg == "playing") then
				studio_beat += dt
				if studio_beat >= LobbyRules.LIVE_BEAT_S then
					studio_beat = 0.0
					local id = studio_lobby.id
					task.spawn(function()
						pcall(store.update, id, function(v: any): any?
							local cur = LobbyRules.decode(v)
							if cur == nil or cur.status ~= "started" then
								return nil
							end
							cur.beat = now()
							return cur
						end)
					end)
				end
			end
		elseif host ~= nil and SharedClock.ready() then
			host:tick(dt, task.spawn)
		end
		stats_time += dt
		if stats_time >= ServerMain.STATS_EVERY_S then
			local elapsed = stats_time
			stats_time = 0.0
			local st = server:take_stats()
			ServerMain.last_stats = st
			ServerMain.last_stats_window = elapsed
			local ok_r, report = pcall(perf.take, perf, st, perf_context())
			local client = ServerMain.lobby_client
			if ok_r and client ~= nil then
				task.spawn(function()
					pcall(client.post, client, "/v1/perf", { role = ServerMain.kind, perf = report })
				end)
			end
			if workspace:GetAttribute("AF_NET_STATS") == true and st.steps > 0 then
				local n = math.max(1, server:participant_count())
				print(
					string.format(
						"[Net] stage=%s players=%d step avg %.2f ms p99 %.2f max %.2f | encode %.2f ms | %.1f KB/s per client (max delta %d B) | snapshots %d (%d B) | intents %d ok %d dropped",
						server:stage(),
						server:participant_count(),
						st.step_ms_avg,
						st.step_ms_p99,
						st.step_ms_max,
						st.encode_ms_avg,
						st.bytes_sent / 1024 / elapsed / n,
						st.delta_bytes_max,
						st.snapshots_sent,
						st.snapshot_bytes,
						st.intents_ok,
						st.intents_dropped
					)
				)
			end
		end
	end)

	game:BindToClose(function()
		server:shutdown("The game server is restarting. You're back at the title screen.")
		if host ~= nil and not RunService:IsStudio() then
			-- a match server closing: everyone to a hub instead of out of the game
			pcall(teleports.to_hub, Players:GetPlayers())
		end
		-- (a match that ended as the server closes: its wins and conquests are still on their way)
		Ranking.settle(5)
		SettingsStore.flush(true)
	end)

	-- Warm the shared geography before anyone queues, so the first match starts quickly.
	task.defer(function()
		local WorldMap = core("WorldMap")
		if WorldMap then
			pcall(WorldMap.shared)
		end
	end)

	folder.Parent = ReplicatedStorage
	if diag ~= nil then
		diag.start(ServerMain)
	end
end

return ServerMain
