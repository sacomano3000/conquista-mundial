--!strict
-- The owner's chat commands for the currency (Data/Brand.CURRENCY; "Stars" in the code): the game's
-- owner gives it to a player, takes it back, or looks at a balance, typed in the chat:
--
--   /moedas dar <jogador> <quantia>      /moedas dar eu 5000      /moedas dar Fulano 20k
--   /moedas tirar <jogador> <quantia>    /moedas tirar Fulano 500
--   /moedas ver <jogador>                /moedas ver Fulano
--
-- <jogador>: "eu", the name (user name or display name, or its beginning) of someone on this server, or
-- a numeric user id, which also reaches a player who is not on this server.
-- <quantia>: a whole number: 5000, 5.000, 5,000, 5k, 2m.
-- "/coins give | take | see" are the same commands. Anyone who is not a game admin (server/AdminCheck:
-- the owner; everyone in a Studio playtest) is refused.
--
-- No Roblox API here (tests/owner_commands.luau): ServerMain hears the chat and passes the text.
--   OwnerCommands.is_command(text) -> boolean
--   OwnerCommands.amount(word) -> number?
--   OwnerCommands.parse(text) -> { op = "give" | "take" | "see" | "help", who = string?, amount = number? }?
--   OwnerCommands.target(who, sender, players) -> (user_id?, name or the error)
--   OwnerCommands.run(text, sender, deps) -> (reply?, bad)     yields (deps.adjust writes the record)
--     deps = { is_owner = fn(sender) -> boolean, players = fn() -> { player },
--              adjust = fn(user_id, delta) -> (ok, balance or why, changed)   -- Purchases.adjust_stars
--              currency = string }
local OwnerCommands = {}

--- What starts a command (the first is what the guide teaches).
OwnerCommands.ALIASES = { "/moedas", "/coins" }
--- The most one command gives or takes.
OwnerCommands.MAX_AMOUNT = 1000000000

local OPS: { [string]: string } = {
	dar = "give",
	add = "give",
	give = "give",
	["+"] = "give",
	tirar = "take",
	remover = "take",
	remove = "take",
	take = "take",
	["-"] = "take",
	ver = "see",
	saldo = "see",
	see = "see",
}

OwnerCommands.HELP = "Use: /moedas dar <jogador> <quantia>  |  /moedas tirar <jogador> <quantia>  |  /moedas ver <jogador>"

local function words_of(text: string): { string }
	local out = {}
	for w in string.gmatch(text, "%S+") do
		table.insert(out, w)
	end
	return out
end

local function commas(n: number): string
	local s = string.format("%d", math.floor(math.abs(n)))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1.")))
	if string.sub(out, 1, 1) == "." then
		out = string.sub(out, 2)
	end
	return out
end
OwnerCommands.commas = commas

--- Whether `text` is one of these commands ("/moedas", "/moedas ...": not "/moedasx").
function OwnerCommands.is_command(text: any): boolean
	if type(text) ~= "string" then
		return false
	end
	local first = string.lower(string.match(text, "^%s*(%S+)") or "")
	return table.find(OwnerCommands.ALIASES, first) ~= nil
end

--- A whole amount above zero as people write it: "5000", "5.000", "5,000", "5k", "2m". nil: not one
--- ("1.5", "-3", "abc", 0, more than MAX_AMOUNT).
function OwnerCommands.amount(word: any): number?
	if type(word) ~= "string" then
		return nil
	end
	local w = string.lower(word)
	local n: number? = nil
	local digits, suffix = string.match(w, "^(%d+)([km]?)$")
	if digits ~= nil then
		n = tonumber(digits)
		if n ~= nil and suffix == "k" then
			n *= 1000
		elseif n ~= nil and suffix == "m" then
			n *= 1000000
		end
	else
		-- thousands separated by dots or commas, in threes only: "5.000", "1,250,000"
		local head, rest0 = string.match(w, "^(%d%d?%d?)([%.,].*)$")
		local rest = (rest0 or "") :: string
		if head ~= nil and #rest % 4 == 0 then
			local all = head :: string
			local ok = true
			for i = 1, #rest, 4 do
				local group = string.match(string.sub(rest, i, i + 3), "^[%.,](%d%d%d)$")
				if group == nil then
					ok = false
					break
				end
				all ..= group
			end
			if ok then
				n = tonumber(all)
			end
		end
	end
	if n == nil or n ~= n or n < 1 or n > OwnerCommands.MAX_AMOUNT then
		return nil
	end
	return n
end

--- The command in `text`, or nil when the text is not one of these commands. A command that can't be
--- understood is { op = "help" }.
function OwnerCommands.parse(text: any): { [string]: any }?
	if not OwnerCommands.is_command(text) then
		return nil
	end
	local w = words_of(text)
	local op = OPS[string.lower(w[2] or "")]
	if op == nil then
		return { op = "help" }
	end
	if op == "see" then
		if #w < 3 then
			return { op = "help" }
		end
		return { op = op, who = table.concat(w, " ", 3) }
	end
	if #w < 4 then
		return { op = "help" }
	end
	-- (a display name may have spaces: the amount is the last word)
	local amount = OwnerCommands.amount(w[#w])
	if amount == nil then
		return { op = "help", bad_amount = w[#w] }
	end
	return { op = op, who = table.concat(w, " ", 3, #w - 1), amount = amount }
end

local function name_of(p: any): string
	local n = p.Name
	return if type(n) == "string" then n else tostring(p.UserId)
end

--- Who `who` is: (user id, their name), or (nil, why not). "eu" / "me" is the sender; then someone
--- on this server by exact user name or display name, a numeric user id (on this server or not), or
--- the only one whose name starts with it.
function OwnerCommands.target(who: any, sender: any, players: { any }): (number?, string)
	if type(who) ~= "string" or who == "" then
		return nil, "Faltou o nome do jogador."
	end
	local q = string.lower(who)
	if string.sub(q, 1, 1) == "@" then
		q = string.sub(q, 2)
	end
	if q == "eu" or q == "me" then
		return sender.UserId, name_of(sender)
	end
	for _, p in players do
		if string.lower(name_of(p)) == q or (type(p.DisplayName) == "string" and string.lower(p.DisplayName) == q) then
			return p.UserId, name_of(p)
		end
	end
	if string.match(q, "^%d+$") ~= nil then
		local id = tonumber(q)
		if id ~= nil and id >= 1 and id <= 2 ^ 53 then
			for _, p in players do
				if p.UserId == id then
					return id, name_of(p)
				end
			end
			return id, "ID " .. q
		end
	end
	local found: { any } = {}
	for _, p in players do
		local dn = if type(p.DisplayName) == "string" then string.lower(p.DisplayName) else ""
		if string.sub(string.lower(name_of(p)), 1, #q) == q or string.sub(dn, 1, #q) == q then
			table.insert(found, p)
		end
	end
	if #found == 1 then
		return found[1].UserId, name_of(found[1])
	end
	if #found > 1 then
		local names = {}
		for i = 1, math.min(#found, 4) do
			names[i] = name_of(found[i])
		end
		return nil,
			string.format('"%s" serve para mais de um jogador (%s). Escreva o nome inteiro.', who, table.concat(names, ", "))
	end
	return nil,
		string.format('"%s" não está neste servidor. Use o nome de quem está aqui, ou o ID numérico da conta.', who)
end

--- Runs the command in `text` for `sender`. (nil): the text is not a command of these.
--- (reply, bad): what to tell the sender, and whether it is a refusal or a failure.
function OwnerCommands.run(text: any, sender: any, deps: { [string]: any }): (string?, boolean)
	local cmd = OwnerCommands.parse(text)
	if cmd == nil then
		return nil, false
	end
	if deps.is_owner(sender) ~= true then
		return "Só o dono do jogo pode usar /moedas.", true
	end
	local cur: string = if type(deps.currency) == "string" then deps.currency else "Stars"
	if cmd.op == "help" then
		if cmd.bad_amount ~= nil then
			return string.format('Quantia inválida: "%s". Use um número inteiro, como 5000 ou 20k.', cmd.bad_amount), true
		end
		return OwnerCommands.HELP, true
	end
	local uid, name = OwnerCommands.target(cmd.who, sender, deps.players())
	if uid == nil then
		return name, true
	end
	local delta = if cmd.op == "give" then cmd.amount elseif cmd.op == "take" then -cmd.amount else 0
	local ok, balance, changed = deps.adjust(uid, delta)
	if not ok or type(balance) ~= "number" then
		return "Não consegui acessar o registro desse jogador agora. Nada mudou. Tente de novo em instantes.", true
	end
	local moved = math.abs(tonumber(changed) or 0)
	if cmd.op == "see" then
		return string.format("%s tem %s %s.", name, commas(balance), cur), false
	elseif cmd.op == "give" then
		if moved < cmd.amount then
			return string.format("%s chegou ao limite: entraram só %s %s. Saldo: %s.", name, commas(moved), cur, commas(balance)),
				false
		end
		return string.format("+%s %s para %s. Saldo: %s.", commas(moved), cur, name, commas(balance)), false
	end
	if moved < cmd.amount then
		return string.format("%s só tinha %s %s: tirei tudo. Saldo: %s.", name, commas(moved), cur, commas(balance)), false
	end
	return string.format("-%s %s de %s. Saldo: %s.", commas(moved), cur, name, commas(balance)), false
end

return OwnerCommands
