--!strict
-- The owner's panel (client: UI/AdminPanel, behind the lobby's button only a game admin sees): what
-- each of its buttons does on the server. The panel is the chat commands with fields and buttons:
-- the Coroas go through server/OwnerCommands, the codes through server/CodeCommands and
-- server/CodeStore, and a player leaves the ranking through server/Ranking.remove.
--
-- WHO MAY: only a game admin (server/AdminCheck: the game's owner; everyone in a Studio playtest).
-- ServerMain asks `admins[player]` before it calls anything here, and `run` asks deps.is_owner again:
-- the button on a screen means nothing, since a client can draw whatever it likes. A request from
-- anyone else is answered with DENIED and carries nothing (no code, no balance).
--
-- No Roblox API here (tests/painel_admin.luau).
--   AdminActions.word(v, max?) -> string       a typed text made safe: one line, no control bytes
--   AdminActions.codes(deps) -> ({ row }, read) the codes as the panel lists them
--   AdminActions.run(action, args, sender, deps) -> reply        yields (the stores)
--     action: "state" | "coins" | "code_new" | "code_switch" | "code_remove" | "rank_remove"
--     args:   coins        { op = "give" | "take" | "see", who, amount }
--             code_new     { code (empty: a random one), stars, valid ("7d", "31/12/2026"), uses ("100") }
--             code_switch  { code, on }
--             code_remove  { code }
--             rank_remove  { who (a name on this server or in the lists, or a numeric user id) }
--     reply:  { action, ok, text, lines = { string }?, codes = { row }?, codes_read = boolean?, uid = number? }
--             row = { code, info, state, on, fixed }   fixed: from server/MyCodes (the place's own list)
--     deps = { is_owner = fn(sender) -> boolean, players = fn() -> { player },
--              adjust = Purchases.adjust_stars, currency = string,
--              store = server/CodeStore, now = fn() -> Unix s, random = fn(n) -> 1..n, fixed = Codes.all,
--              rank_remove = fn(user id) -> (ok, found), rank_find = fn(name) -> (user id?, name or count) }
local IS_ROBLOX = typeof(game) == "Instance"
local OwnerCommands: any = if IS_ROBLOX
	then require((script :: any).Parent.OwnerCommands)
	else require("./OwnerCommands")
local CodeCommands: any = if IS_ROBLOX then require((script :: any).Parent.CodeCommands) else require("./CodeCommands")

local AdminActions = {}

--- What the panel may ask for.
AdminActions.ACTIONS = { "state", "coins", "code_new", "code_switch", "code_remove", "rank_remove" }
--- The longest text a field sends, bytes.
AdminActions.MAX_TEXT = 48
--- The most codes one answer lists.
AdminActions.MAX_CODES = 300
--- What anyone who is not the owner is told.
AdminActions.DENIED = "Só o dono do jogo pode usar o painel."

--- A typed text made safe to put in a command: a string (or a whole number), one line, no control
--- bytes, single spaces, no space at the ends, at most `max` bytes and still whole UTF-8 ("" otherwise).
function AdminActions.word(v: any, max: number?): string
	if type(v) == "number" and v == v and math.abs(v) < 2 ^ 53 then
		v = string.format("%d", math.floor(v))
	end
	if type(v) ~= "string" then
		return ""
	end
	local limit = max or AdminActions.MAX_TEXT
	-- (far too long: not a field of the panel; nothing is cut out of the middle of a letter)
	if #v > limit * 4 then
		return ""
	end
	local s = string.gsub(v, "[%c\127]", " ")
	s = string.gsub(s, "%s+", " ")
	s = string.gsub(string.gsub(s, "^ ", ""), " $", "")
	if #s > limit or utf8.len(s) == nil then
		return ""
	end
	return s
end

local function no_spaces(s: string): string
	return (string.gsub(s, " ", ""))
end

local function currency_of(deps: { [string]: any }): string
	return if type(deps.currency) == "string" then deps.currency else "Stars"
end

local function now_of(deps: { [string]: any }): number
	return if type(deps.now) == "function" then deps.now() else os.time()
end

--- One code as the panel shows it.
local function row_of(e: { [string]: any }, cur: string, now: number, fixed: boolean): { [string]: any }
	local parts = { string.format("%s %s", OwnerCommands.commas(tonumber(e.stars) or 0), cur) }
	table.insert(parts, if e.expires ~= nil then "até " .. CodeCommands.date(e.expires) else "sem validade")
	if e.uses ~= nil then
		table.insert(
			parts,
			string.format("%s de %s usos", OwnerCommands.commas(e.used or 0), OwnerCommands.commas(e.uses))
		)
	else
		table.insert(parts, "sem limite de usos")
	end
	return {
		code = tostring(e.code),
		info = table.concat(parts, " · "),
		state = CodeCommands.state(e, now),
		on = e.active ~= false,
		fixed = fixed,
	}
end

--- The codes as the panel lists them: the ones made while the game runs (server/CodeStore), then the
--- place's own (server/MyCodes; they can only be changed in Studio). `read` false: the store never
--- answered, so the first part may be missing.
function AdminActions.codes(deps: { [string]: any }): ({ { [string]: any } }, boolean)
	local out: { { [string]: any } } = {}
	local cur, now = currency_of(deps), now_of(deps)
	local read = false
	if deps.store ~= nil then
		local ok, list, got = pcall(deps.store.list)
		if ok and type(list) == "table" then
			read = got ~= false
			for _, e in list do
				if #out < AdminActions.MAX_CODES and type(e) == "table" and e.code ~= nil then
					table.insert(out, row_of(e, cur, now, false))
				end
			end
		end
	end
	if type(deps.fixed) == "function" then
		local ok, list = pcall(deps.fixed)
		if ok and type(list) == "table" then
			for _, e in list do
				if #out < AdminActions.MAX_CODES and type(e) == "table" and e.code ~= nil then
					table.insert(out, row_of(e, cur, now, true))
				end
			end
		end
	end
	return out, read
end

local function with_codes(reply: { [string]: any }, deps: { [string]: any }): { [string]: any }
	local rows, read = AdminActions.codes(deps)
	reply.codes = rows
	reply.codes_read = read
	return reply
end

--- The Coroas: the chat's "/moedas dar | tirar | ver".
local function coins(a: { [string]: any }, sender: any, deps: { [string]: any }): { [string]: any }
	local op = a.op
	local verb = if op == "give" then "dar" elseif op == "take" then "tirar" elseif op == "see" then "ver" else nil
	if verb == nil then
		return { ok = false, text = "Pedido desconhecido." }
	end
	local who = AdminActions.word(a.who)
	if who == "" then
		return { ok = false, text = "Faltou o nome do jogador." }
	end
	local text: string
	if verb == "ver" then
		text = string.format("/moedas ver %s", who)
	else
		local amount = no_spaces(AdminActions.word(a.amount, 16))
		if amount == "" then
			return { ok = false, text = "Faltou a quantia." }
		end
		text = string.format("/moedas %s %s %s", verb, who, amount)
	end
	local reply, bad = OwnerCommands.run(text, sender, {
		is_owner = deps.is_owner,
		players = deps.players,
		adjust = deps.adjust,
		currency = deps.currency,
	})
	return { ok = bad ~= true and reply ~= nil, text = reply or "Pedido desconhecido." }
end

--- A code, as the chat's "/codigo ..." reads the rest of `text`.
local function code_command(text: string, sender: any, deps: { [string]: any }): { [string]: any }
	local reply, bad, lines = CodeCommands.run(text, sender, {
		is_owner = deps.is_owner,
		store = deps.store,
		now = deps.now,
		random = deps.random,
		currency = deps.currency,
		fixed = deps.fixed,
	})
	return with_codes({
		ok = bad ~= true and reply ~= nil,
		text = reply or "Pedido desconhecido.",
		lines = if type(lines) == "table" then lines else nil,
	}, deps)
end

local function code_new(a: { [string]: any }, sender: any, deps: { [string]: any }): { [string]: any }
	local code = no_spaces(AdminActions.word(a.code, 32))
	local stars = no_spaces(AdminActions.word(a.stars, 16))
	local valid = no_spaces(AdminActions.word(a.valid, 16))
	local uses = no_spaces(AdminActions.word(a.uses, 16))
	if stars == "" then
		return with_codes({ ok = false, text = string.format("Faltou quantas %s o código dá.", currency_of(deps)) }, deps)
	end
	-- (the fields take a bare number: "7" days, "100" uses)
	if string.match(valid, "^%d+$") ~= nil then
		valid ..= "d"
	end
	if string.match(uses, "^%d+$") ~= nil then
		uses ..= "x"
	end
	local words = { "/codigo", if code == "" then "gerar" else "criar" }
	if code ~= "" then
		table.insert(words, code)
	end
	table.insert(words, stars)
	if valid ~= "" then
		table.insert(words, valid)
	end
	if uses ~= "" then
		table.insert(words, uses)
	end
	return code_command(table.concat(words, " "), sender, deps)
end

local function code_named(verb: string, a: { [string]: any }, sender: any, deps: { [string]: any }): { [string]: any }
	local code = no_spaces(AdminActions.word(a.code, 32))
	if code == "" then
		return with_codes({ ok = false, text = "Faltou o nome do código." }, deps)
	end
	return code_command(string.format("/codigo %s %s", verb, code), sender, deps)
end

--- A player out of the ranking.
local function rank_remove(a: { [string]: any }, sender: any, deps: { [string]: any }): { [string]: any }
	local who = AdminActions.word(a.who)
	if who == "" then
		return { ok = false, text = "Faltou o nome ou o ID do jogador." }
	end
	if type(deps.rank_remove) ~= "function" then
		return { ok = false, text = "O ranking não está ligado neste servidor." }
	end
	local players = if type(deps.players) == "function" then deps.players() else {}
	local uid, name = OwnerCommands.target(who, sender, players)
	if uid == nil and type(deps.rank_find) == "function" then
		-- (not on this server: someone of the lists, by the name the lists show)
		local id, found = deps.rank_find(who)
		if id ~= nil then
			uid, name = id, tostring(found)
		elseif type(found) == "number" and found > 1 then
			return {
				ok = false,
				text = string.format(
					'Há %d jogadores chamados "%s" no ranking. Use o ID numérico (está ao lado do nome, na lista do painel).',
					found,
					who
				),
			}
		else
			return {
				ok = false,
				text = string.format(
					'"%s" não está neste servidor nem nas listas do ranking. Use o ID numérico da conta.',
					who
				),
			}
		end
	end
	if uid == nil then
		return { ok = false, text = name }
	end
	local ok, found = deps.rank_remove(uid)
	local n = tonumber(found) or 0
	if ok ~= true then
		return {
			ok = false,
			uid = if n > 0 then uid else nil,
			text = "O armazenamento do Roblox falhou no meio: pode ter sobrado alguma lista. Aperte de novo em instantes.",
		}
	end
	if n <= 0 then
		return { ok = true, uid = uid, text = string.format("%s não estava em nenhuma lista do ranking.", name) }
	end
	return {
		ok = true,
		uid = uid,
		text = string.format("%s saiu do ranking. Os outros servidores mostram isso em até 2 minutos.", name),
	}
end

--- Runs one request of the panel for `sender`. Yields. Always answers with a reply table.
function AdminActions.run(action: any, args: any, sender: any, deps: { [string]: any }): { [string]: any }
	local name: string = if type(action) == "string" and #action <= 24 then action else "?"
	-- (first of all, and for every action: who is asking)
	if type(deps.is_owner) ~= "function" or deps.is_owner(sender) ~= true then
		return { action = name, ok = false, denied = true, text = AdminActions.DENIED }
	end
	local a: { [string]: any } = if type(args) == "table" then args else {}
	local reply: { [string]: any }
	if name == "state" then
		reply = with_codes({ ok = true, text = "" }, deps)
	elseif name == "coins" then
		reply = coins(a, sender, deps)
	elseif name == "code_new" then
		reply = code_new(a, sender, deps)
	elseif name == "code_switch" then
		reply = code_named(if a.on == true then "ligar" else "desligar", a, sender, deps)
	elseif name == "code_remove" then
		reply = code_named("apagar", a, sender, deps)
	elseif name == "rank_remove" then
		reply = rank_remove(a, sender, deps)
	else
		reply = { ok = false, text = "Pedido desconhecido." }
	end
	reply.action = name
	return reply
end

return AdminActions
