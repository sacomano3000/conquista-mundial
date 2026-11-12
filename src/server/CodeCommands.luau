--!strict
-- The owner's chat commands for redeem codes: the game's owner creates a code, switches it off or
-- deletes it while the game runs, with nothing to publish (the codes live in server/CodeStore, one
-- DataStore key every server reads). Typed in the chat:
--
--   /codigo criar <NOME> <coroas> [validade] [usos]     /codigo criar NATAL 5000
--                                                       /codigo criar NATAL 5000 7d 100x
--   /codigo gerar <coroas> [validade] [usos]            /codigo gerar 20k 1x      (a random name)
--   /codigo lista
--   /codigo ver <NOME>
--   /codigo desligar <NOME>      /codigo ligar <NOME>      /codigo apagar <NOME>
--
-- <coroas>: a whole number as /moedas reads it (5000, 5.000, 5k, 2m).
-- [validade]: "7d" (good until the end of the 7th day from today) or a date, "31/12/2026" or
-- "2026-12-31" (good until the end of that day). A day ends at midnight UTC, as in server/MyCodes.
-- [usos]: "100x": the first 100 players in the whole game; "1x": one player only. Without it, every
-- player can use the code, once each.
-- "/code create | random | list | see | off | on | delete" are the same commands. Anyone who is not a
-- game admin (server/AdminCheck: the owner; everyone in a Studio playtest) is refused.
--
-- No Roblox API here (tests/gerar_codigos.luau): ServerMain hears the chat and passes the text.
--   CodeCommands.is_command(text) -> boolean
--   CodeCommands.parse(text, now) -> { op, code?, stars?, expires?, uses?, why? }?
--   CodeCommands.random_code(random) -> "K7QM-X2PD"
--   CodeCommands.date(unix) -> "31/12/2026"
--   CodeCommands.describe(entry, currency, now) -> one line about a code
--   CodeCommands.run(text, sender, deps) -> (reply?, bad, lines?)        yields (the store)
--     reply: one short line for the sender; lines: the same answer in full, for the chat window
--     deps = { is_owner = fn(sender) -> boolean, store = server/CodeStore, now = fn() -> Unix s,
--              random = fn(n) -> 1..n, currency = string, fixed = fn() -> Codes.all() }
local IS_ROBLOX = typeof(game) == "Instance"
local Codes: any = if IS_ROBLOX then require((script :: any).Parent.Codes) else require("./Codes")
local OwnerCommands: any = if IS_ROBLOX
	then require((script :: any).Parent.OwnerCommands)
	else require("./OwnerCommands")

local CodeCommands = {}

--- What starts a command (the first is what the guide teaches). ServerMain makes one chat command
--- for each pair, so none of them is shown to the other players.
CodeCommands.ALIASES = { "/codigo", "/código", "/codigos", "/code" }
--- The letters of a random code: none that is read as another (no 0 O, 1 I L).
CodeCommands.ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
--- The longest "Nd" (ten years).
CodeCommands.MAX_DAYS = 3650
--- How many codes the short answer of "/codigo lista" names.
CodeCommands.LIST_SHORT = 6

local OPS: { [string]: string } = {
	criar = "create",
	cria = "create",
	novo = "create",
	create = "create",
	add = "create",
	gerar = "generate",
	gera = "generate",
	aleatorio = "generate",
	random = "generate",
	generate = "generate",
	lista = "list",
	listar = "list",
	list = "list",
	ver = "see",
	info = "see",
	see = "see",
	desligar = "off",
	desativar = "off",
	off = "off",
	ligar = "on",
	ativar = "on",
	on = "on",
	apagar = "delete",
	excluir = "delete",
	deletar = "delete",
	remover = "delete",
	delete = "delete",
	remove = "delete",
}

CodeCommands.HELP = "Use: /codigo criar <NOME> <coroas>  |  /codigo gerar <coroas>  |  /codigo lista  |  /codigo desligar <NOME>"
CodeCommands.HELP_LINES = {
	"Comandos de código (só o dono):",
	"/codigo criar NATAL 5000 — cria o código NATAL, que dá 5.000 Coroas",
	"/codigo criar NATAL 5000 7d 100x — vale 7 dias, só para os 100 primeiros jogadores",
	"/codigo criar NATAL 5000 31/12/2026 — vale até o fim desse dia",
	"/codigo gerar 5000 1x — cria um código com nome sorteado, para 1 jogador só",
	"/codigo lista — mostra todos os códigos",
	"/codigo ver NATAL — mostra um código",
	"/codigo desligar NATAL  |  /codigo ligar NATAL  |  /codigo apagar NATAL",
}

local STORE_DOWN = "Não consegui salvar agora. Nada mudou. Tente de novo em instantes."

local function words_of(text: string): { string }
	local out = {}
	for w in string.gmatch(text, "%S+") do
		table.insert(out, w)
	end
	return out
end

--- Lower case, capital "Ó" included (string.lower leaves it).
local function lower(s: string): string
	return (string.gsub(string.lower(s), "Ó", "ó"))
end

--- Whether `text` is one of these commands ("/codigo", "/codigo ...": not "/codigox").
function CodeCommands.is_command(text: any): boolean
	if type(text) ~= "string" then
		return false
	end
	local first = lower(string.match(text, "^%s*(%S+)") or "")
	return table.find(CodeCommands.ALIASES, first) ~= nil
end

--- A Unix time as the day it falls on (UTC), "31/12/2026".
function CodeCommands.date(unix: number): string
	-- (the civil calendar from a day count; no os.date: the server's time zone must not matter)
	local z = unix // 86400 + 719468
	local era = z // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local d = doy - (153 * mp + 2) // 5 + 1
	local m = if mp < 10 then mp + 3 else mp - 9
	local y = yoe + era * 400 + (if m <= 2 then 1 else 0)
	return string.format("%02d/%02d/%04d", d, m, y)
end

--- The last second of the day `days` days after the one `now` falls on.
local function day_end_after(now: number, days: number): number
	return (now // 86400 + days) * 86400 + 86399
end

--- One of the words after the amount: -> ("expires", Unix s) | ("uses", n) | (nil, what is wrong with it).
local function option(word: string, now: number): (string?, any)
	local w = lower(word)
	local n = string.match(w, "^(%d+)x$") or string.match(w, "^x(%d+)$") or string.match(w, "^(%d+)usos?$")
	if n ~= nil then
		local uses = tonumber(n)
		if uses == nil or uses < 1 or uses > 10000000 then
			return nil, string.format('"%s": o limite de usos vai de 1x a 10000000x.', word)
		end
		return "uses", uses
	end
	n = string.match(w, "^(%d+)d$") or string.match(w, "^(%d+)dias?$")
	if n ~= nil then
		local days = tonumber(n)
		if days == nil or days > CodeCommands.MAX_DAYS then
			return nil, string.format('"%s": a validade em dias vai de 0d (só hoje) a %dd.', word, CodeCommands.MAX_DAYS)
		end
		return "expires", day_end_after(now, days)
	end
	local d, m, y = string.match(w, "^(%d%d?)/(%d%d?)/(%d%d%d%d)$")
	local iso: string? = nil
	if d ~= nil then
		iso = string.format("%04d-%02d-%02d", tonumber(y) or 0, tonumber(m) or 0, tonumber(d) or 0)
	elseif string.match(w, "^%d%d%d%d%-%d%d%-%d%d$") ~= nil then
		iso = w
	end
	if iso ~= nil then
		local ends = Codes.day_end(iso)
		if ends == nil then
			return nil, string.format('"%s" não é uma data. Escreva assim: 31/12/2026.', word)
		end
		if ends < now then
			return nil, string.format('"%s" já passou. Escolha uma data de hoje em diante.', word)
		end
		return "expires", ends
	end
	return nil,
		string.format('Não entendi "%s". Validade: 7d ou 31/12/2026. Limite de usos: 100x. O nome do código é uma palavra só.', word)
end

--- The command in `text`, or nil when the text is not one of these commands. A command that can't be
--- understood is { op = "help", why = what to tell the sender (nil: the list of commands) }.
function CodeCommands.parse(text: any, now: number): { [string]: any }?
	if not CodeCommands.is_command(text) then
		return nil
	end
	local w = words_of(text)
	local op = OPS[lower(w[2] or "")]
	if op == nil then
		return { op = "help" }
	end
	if op == "list" then
		return { op = op }
	end
	if op == "see" or op == "off" or op == "on" or op == "delete" then
		if #w < 3 then
			return { op = if op == "see" then "list" else "help" }
		end
		local code = Codes.normalize(table.concat(w, "", 3))
		if code == nil then
			return { op = "help", why = string.format('"%s" não é nome de código.', table.concat(w, " ", 3)) }
		end
		return { op = op, code = code }
	end
	-- create <NAME> <amount> [options]     generate <amount> [options]
	local at = 3
	local code: string? = nil
	if op == "create" then
		if #w < 4 then
			return { op = "help", why = "Faltou o nome ou a quantia. Exemplo: /codigo criar NATAL 5000" }
		end
		code = Codes.normalize(w[3])
		if code == nil then
			return {
				op = "help",
				why = string.format(
					'Nome inválido: "%s". Use de %d a %d letras, números, _ ou -, sem acento.',
					w[3],
					Codes.MIN_LEN,
					Codes.MAX_LEN
				),
			}
		end
		at = 4
	elseif #w < 3 then
		return { op = "help", why = "Faltou a quantia. Exemplo: /codigo gerar 5000" }
	end
	local stars = OwnerCommands.amount(w[at])
	if stars == nil or stars > Codes.MAX_STARS then
		return {
			op = "help",
			why = string.format(
				'Quantia inválida: "%s". Use um número inteiro até %s, como 5000 ou 20k.%s',
				w[at],
				OwnerCommands.commas(Codes.MAX_STARS),
				if op == "create" then " O nome do código é uma palavra só." else ""
			),
		}
	end
	local cmd: { [string]: any } = { op = op, code = code, stars = stars }
	for i = at + 1, #w do
		local kind, value = option(w[i], now)
		if kind == nil then
			return { op = "help", why = value }
		end
		cmd[kind] = value
	end
	return cmd
end

--- A random code, "K7QM-X2PD". `random(n)` -> a whole number from 1 to n.
function CodeCommands.random_code(random: (n: number) -> number): string
	local a = CodeCommands.ALPHABET
	local out = {}
	for i = 1, 8 do
		local k = math.clamp(math.floor(tonumber(random(#a)) or 1), 1, #a)
		out[i] = string.sub(a, k, k)
	end
	return table.concat(out, "", 1, 4) .. "-" .. table.concat(out, "", 5, 8)
end

--- How a code stands at `now`: "ligado" | "DESLIGADO" | "EXPIRADO" | "ESGOTADO".
local function state_of(e: { [string]: any }, now: number): string
	if e.active == false then
		return "DESLIGADO"
	end
	if e.expires ~= nil and now > e.expires then
		return "EXPIRADO"
	end
	if e.uses ~= nil and (e.used or 0) >= e.uses then
		return "ESGOTADO"
	end
	return "ligado"
end

CodeCommands.state = state_of

local function terms(e: { [string]: any }): (string, string)
	local expiry = if e.expires ~= nil then "até " .. CodeCommands.date(e.expires) else "sem validade"
	local uses = if e.uses == nil
		then "sem limite de usos"
		elseif e.uses == 1 then "para 1 jogador só"
		else string.format("para os %s primeiros jogadores", OwnerCommands.commas(e.uses))
	return expiry, uses
end

--- One line about a code: "NATAL · 5.000 Coroas · até 31/12/2026 · 12 de 100 usos · ligado".
function CodeCommands.describe(e: { [string]: any }, currency: string, now: number): string
	local parts = { e.code, string.format("%s %s", OwnerCommands.commas(e.stars), currency) }
	table.insert(parts, if e.expires ~= nil then "até " .. CodeCommands.date(e.expires) else "sem validade")
	if e.uses ~= nil then
		table.insert(parts, string.format("%s de %s usos", OwnerCommands.commas(e.used or 0), OwnerCommands.commas(e.uses)))
	else
		table.insert(parts, "sem limite de usos")
	end
	table.insert(parts, state_of(e, now))
	return table.concat(parts, " · ")
end

--- The short form of a code in the list's one line: "NATAL 5.000", "K7QM-X2PD 1.000 (0/1)", "VIP 500 (desligado)".
local function brief(e: { [string]: any }, now: number): string
	local s = string.format("%s %s", e.code, OwnerCommands.commas(e.stars))
	local st = state_of(e, now)
	if st ~= "ligado" then
		return s .. " (" .. string.lower(st) .. ")"
	end
	if e.uses ~= nil then
		return s .. string.format(" (%d/%d)", e.used or 0, e.uses)
	end
	return s
end

local function fixed_of(deps: { [string]: any }): { { [string]: any } }
	if type(deps.fixed) ~= "function" then
		return {}
	end
	local ok, list = pcall(deps.fixed)
	return if ok and type(list) == "table" then list else {}
end

local function in_fixed(deps: { [string]: any }, code: string): boolean
	for _, e in fixed_of(deps) do
		if e.code == code then
			return true
		end
	end
	return false
end

local function missing(deps: { [string]: any }, code: string): string
	if in_fixed(deps, code) then
		return code .. " é da lista MyCodes: para mudar, edite a lista no Studio e publique."
	end
	return string.format("Não existe o código %s. Veja os que existem: /codigo lista", code)
end

--- Runs the command in `text` for `sender`. (nil): the text is not a command of these.
--- (reply, bad, lines): what to tell the sender in one line, whether it is a refusal or a failure,
--- and the whole answer line by line (nil: the one line says it all).
function CodeCommands.run(text: any, sender: any, deps: { [string]: any }): (string?, boolean, { string }?)
	if not CodeCommands.is_command(text) then
		return nil, false, nil
	end
	if deps.is_owner(sender) ~= true then
		return "Só o dono do jogo pode usar /codigo.", true, nil
	end
	local now: number = if type(deps.now) == "function" then deps.now() else os.time()
	local cmd = CodeCommands.parse(text, now) :: { [string]: any }
	local cur: string = if type(deps.currency) == "string" then deps.currency else "Stars"
	local store = deps.store
	if cmd.op == "help" then
		if cmd.why ~= nil then
			return cmd.why, true, nil
		end
		return CodeCommands.HELP, true, table.clone(CodeCommands.HELP_LINES)
	end

	if cmd.op == "create" or cmd.op == "generate" then
		local e: { [string]: any }? = nil
		local why: string? = nil
		if cmd.op == "create" then
			if in_fixed(deps, cmd.code) then
				return cmd.code .. " já está na lista MyCodes do Studio. Escolha outro nome.", true, nil
			end
			e, why = store.create(cmd.code, cmd.stars, cmd.expires, cmd.uses, sender.UserId, now)
		else
			-- (a drawn name that is taken is drawn again)
			for _ = 1, 6 do
				local name = CodeCommands.random_code(deps.random)
				e, why = store.create(name, cmd.stars, cmd.expires, cmd.uses, sender.UserId, now)
				if e ~= nil or why ~= "exists" then
					break
				end
			end
		end
		if e == nil then
			if why == "exists" then
				if cmd.op == "generate" then
					return "Não consegui sortear um nome livre. Tente de novo.", true, nil
				end
				return string.format("Já existe o código %s. Escolha outro nome, ou apague o antigo: /codigo apagar %s", cmd.code, cmd.code),
					true,
					nil
			elseif why == "full" then
				return string.format("Chegou ao limite de %d códigos. Apague algum: /codigo apagar <NOME>", store.MAX_CODES or 0),
					true,
					nil
			elseif why == "bad" then
				return "Esse código não pôde ser criado: confira o nome e a quantia.", true, nil
			end
			return STORE_DOWN, true, nil
		end
		local expiry, uses = terms(e)
		local reply = string.format("Código %s criado: %s %s, %s, %s.", e.code, OwnerCommands.commas(e.stars), cur, expiry, uses)
		return reply, false, { reply }
	end

	if cmd.op == "list" then
		local list, read = store.list()
		local fixed = fixed_of(deps)
		if not read then
			return "Não consegui ler os códigos agora. Tente de novo em instantes.", true, nil
		end
		local lines = {}
		local short = {}
		for i, e in list do
			table.insert(lines, CodeCommands.describe(e, cur, now))
			if i <= CodeCommands.LIST_SHORT then
				table.insert(short, brief(e, now))
			end
		end
		local reply: string
		if #list == 0 then
			reply = "Nenhum código criado por comando ainda. Crie um: /codigo criar NATAL 5000"
			table.insert(lines, reply)
		else
			reply = string.format("%d %s: %s", #list, if #list == 1 then "código" else "códigos", table.concat(short, " · "))
			if #list > #short then
				reply ..= string.format(" · e mais %d", #list - #short)
			end
			table.insert(lines, 1, string.format("Códigos criados por comando (%d):", #list))
		end
		if #fixed > 0 then
			local names = {}
			for _, e in fixed do
				table.insert(lines, "[MyCodes] " .. CodeCommands.describe(e, cur, now))
				table.insert(names, e.code)
			end
			reply ..= string.format("  |  Lista MyCodes: %s", table.concat(names, ", ", 1, math.min(#names, 4)))
			if #names > 4 then
				reply ..= string.format(" e mais %d", #names - 4)
			end
		end
		return reply, false, lines
	end

	if cmd.op == "see" then
		local list, read = store.list()
		if not read then
			return "Não consegui ler os códigos agora. Tente de novo em instantes.", true, nil
		end
		for _, e in list do
			if e.code == cmd.code then
				local line = CodeCommands.describe(e, cur, now)
				return line, false, { line }
			end
		end
		for _, e in fixed_of(deps) do
			if e.code == cmd.code then
				local line = "[MyCodes] " .. CodeCommands.describe(e, cur, now)
				return line, false, { line }
			end
		end
		return missing(deps, cmd.code), true, nil
	end

	if cmd.op == "off" or cmd.op == "on" then
		local e, why = store.switch(cmd.code, cmd.op == "on")
		if e == nil then
			return if why == "missing" then missing(deps, cmd.code) else STORE_DOWN, true, nil
		end
		local reply = if cmd.op == "on"
			then string.format("Código %s ligado de novo.", e.code)
			else string.format("Código %s desligado: não paga mais ninguém. Para voltar: /codigo ligar %s", e.code, e.code)
		if cmd.op == "on" and state_of(e, now) ~= "ligado" then
			reply = string.format("Código %s ligado, mas está %s: continua sem pagar.", e.code, state_of(e, now))
		end
		return reply, false, { reply }
	end

	-- delete
	local e, why = store.remove(cmd.code)
	if e == nil then
		return if why == "missing" then missing(deps, cmd.code) else STORE_DOWN, true, nil
	end
	local reply = string.format("Código %s apagado. Quem já usou fica com as %s.", e.code, cur)
	return reply, false, { reply }
end

return CodeCommands
