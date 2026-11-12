--!nocheck
-- The Attack bar (client/UI/RatioSlider, the line under it in client/UI/CommandBar) and the floor
-- under a new player's army (Data/Tutorial, client/UI/UIAdvisor), outside Roblox:
--   * the share chosen stays chosen: a send, a release, the pointer moving away do not change it;
--   * an order sends that share of the army as it is now: 100K at 50% sends 50K, then 25K, then 12.5K;
--   * in a player's first matches a floor holds under the army (ROOKIE_FLOOR_ON is on): an order is
--     trimmed to what stands above it, and at the floor the line says why instead of "Sends 0 troops";
--     past those matches, or with the switch off, an order is the share of the army, every time;
--   * in the tutorial, where its own floor holds, the line says why too;
--   * the command bar writes that line.
--   lune run tests/barra_ataque.luau
local H = require("./ui_harness")
local fs = require("@lune/fs")
local UICtx = require("../src/client/UI/UICtx")
local UITheme = require("../src/client/UI/UITheme")
local W = require("../src/client/UI/Widgets")
local Tutorial = require("../src/shared/Data/Tutorial")
local Lang = require("../src/shared/Data/Lang")
Lang.use("pt")

local checks, failed = 0, 0
local function check(ok: boolean, what: string)
	checks += 1
	if not ok then
		failed += 1
		print("FAIL: " .. what)
	end
end

-- Roblox's input service, with events the test can fire (the bar listens there for the release
-- and for the pointer while a stop is held)
local g = H.fake_game()
local UIS = g:GetService("UserInputService")
local function event()
	local e = { fns = {} }
	function e.Connect(self: any, fn: any)
		table.insert(self.fns, fn)
		return { Disconnect = function() end, Connected = true }
	end
	function e.fire(self: any, ...)
		for _, fn in self.fns do
			fn(...)
		end
	end
	return e
end
rawset(UIS, "InputChanged", event())
rawset(UIS, "InputEnded", event())
rawset(UIS, "InputBegan", event())
W.input_pos = function(io: any): Vector2
	return Vector2.new(io.Position.X, io.Position.Y)
end
W.screen_to_logical = function(v: Vector2): Vector2
	return v / UITheme.scale
end
local RatioSlider = require("../src/client/UI/RatioSlider")
local CommandBar = require("../src/client/UI/CommandBar")
local UIAdvisor = require("../src/client/UI/UIAdvisor")

--- A context whose player has `troops` of `cap` (the game's units: the screen shows a tenth).
local function context(troops: number, cap: number): (any, any)
	local ctx = UICtx.new()
	local me = { id = 1, troops = troops, max_troops = cap, spawned = true, alive = true }
	ctx.state = {
		local_owner = 1,
		get_owner = function()
			return me
		end,
	}
	function ctx:sfx() end
	return ctx, me
end
--- The line under the bar, as the player reads it.
local function line(ctx: any): string
	return Lang.t(CommandBar.sends_text(ctx))
end
--- What an order would send now, and the order itself going out (the army pays for it).
local function send(ctx: any, me: any): number
	local share = ctx:order_ratio()
	local n = #ctx.sent_log
	ctx:send({ type = "attack", tile = 1, ratio = share })
	if #ctx.sent_log == n then
		return 0
	end
	local went = me.troops * ctx.sent_log[#ctx.sent_log].intent.ratio
	me.troops -= went
	return went
end

-- 1. the share stays chosen, and each order takes it from the army as it is
do
	local ctx, me = context(1000000, 1400000)
	ctx:set_ratio(0.5)
	check(line(ctx) == "Envia " .. UITheme.fmt_troops(500000) .. " tropas", "100K at 50%: the line says 50K: " .. line(ctx))
	check(send(ctx, me) == 500000, "the first order sends 50K")
	check(ctx.ratio == 0.5, "the share is still 50% after the order")
	check(line(ctx) == "Envia " .. UITheme.fmt_troops(250000) .. " tropas", "then the line says 25K, half of what is left: " .. line(ctx))
	check(send(ctx, me) == 250000, "the second order sends 25K")
	check(ctx.ratio == 0.5 and line(ctx) == "Envia " .. UITheme.fmt_troops(125000) .. " tropas", "then 12.5K: " .. line(ctx))
	-- the army grows back: the line follows it, the share untouched
	me.troops = 800000
	check(line(ctx) == "Envia " .. UITheme.fmt_troops(400000) .. " tropas" and ctx.ratio == 0.5, "the army grows back: the line follows")
end

-- 2. a new player's match, outside the tutorial: the floor under the army is on (the owner's switch)
do
	check(Tutorial.ROOKIE_FLOOR_ON == true, "the game ships with the floor under a new player's army")
	local function match(before: number, tutorials: number?): (any, any, any, () -> ())
		local ctx, me = context(5110000, 7000000)
		-- (the tutorial's matches among those before: the saved [ui] settings)
		ctx.settings.tutorial_n = tutorials
		local played = 0
		function ctx:alive_player()
			return true
		end
		function ctx:alive_seconds()
			return played
		end
		local ui = { ctx = ctx, tutorial = { active = false }, telemetry = { matches_before = function()
			return before
		end } }
		local adv = UIAdvisor.new(ui)
		return ctx, me, adv, function()
			played += 30
		end
	end
	local reason = Lang.t(Tutorial.FLOOR_REASON)
	local floor = Tutorial.ROOKIE_FLOOR * 7000000
	-- a player in the first match outside the tutorial (ROOKIE_MATCHES = 1 since 2026-11-12, the
	-- tutorial's matches not counted): a fifth of the cap stays home
	check(Tutorial.ROOKIE_MATCHES == 1, "a new player's floor holds for one match")
	for _, c in { { 0, 0 }, { 0, 1 }, { 1, 1 }, { 3, 3 } } do
		local before = c[1]
		local what = string.format(" (a player with %d matches, %d of them the tutorial's)", before, c[2])
		local ctx, me, adv, tick = match(before, c[2])
		local held = 0
		ctx.floor_held:Connect(function()
			held += 1
		end)
		ctx:set_ratio(0.75)
		tick()
		adv:check_floor()
		check(ctx.troop_floor == Tutorial.ROOKIE_FLOOR, "the floor arms under a new player's army" .. what)
		-- 75% of 5.11M would leave 1.2775M, under the 1.4M floor: what stands above the floor goes
		check(math.abs(ctx:order_ratio() - (5110000 - floor) / 5110000) < 1e-6, "an order that would cross the floor is trimmed" .. what)
		check(line(ctx) == "Envia " .. UITheme.fmt_troops(5110000 - floor) .. " · reserva " .. UITheme.fmt_troops(floor), "the line says what goes, not 75%, and what stays as the reserve: " .. line(ctx) .. what)
		check(math.abs(send(ctx, me) - (5110000 - floor)) < 1, "and that is what goes" .. what)
		check(held == 1, "the player is told the order was trimmed" .. what)
		check(math.abs(me.troops - floor) < 1, "a fifth of the cap is still home" .. what)
		-- at the floor: nothing goes, and the line says why
		check(ctx:order_ratio() == 0, "at the floor nothing may go" .. what)
		check(line(ctx) == reason and reason == "Poucas tropas. Deixe recuperar", "at the floor the line says why: " .. line(ctx) .. what)
		check(string.find(line(ctx), "Envia 0", 1, true) == nil, "never \"Sends 0 troops\" beside a bar at 75%" .. what)
		local n = #ctx.sent_log
		check(send(ctx, me) == 0 and #ctx.sent_log == n, "an order at the floor sends nothing" .. what)
		check(ctx.ratio == 0.75, "the share on the bar is still 75%" .. what)
		-- the army grows back: the line counts again
		me.troops = 3000000
		check(line(ctx) == "Envia " .. UITheme.fmt_troops(3000000 - floor) .. " · reserva " .. UITheme.fmt_troops(floor), "the army grows back: the line counts again: " .. line(ctx) .. what)
		me.troops = 6000000
		check(line(ctx) == "Envia " .. UITheme.fmt_troops(4500000) .. " tropas", "75% of 6M leaves 1.5M, above the floor: the whole share goes: " .. line(ctx) .. what)
	end
	-- a player past the first matches: no floor, the share of the army as it is, every time
	for _, c in { { 1, 0 }, { 2, 1 }, { 40, 0 }, { 40, 1 } } do
		local before = c[1]
		local what = string.format(" (a player with %d matches, %d of them the tutorial's)", before, c[2])
		local ctx, me, adv, tick = match(before, c[2])
		ctx:set_ratio(0.75)
		for round = 1, 4 do
			tick()
			adv:check_floor()
			check(ctx.troop_floor == nil, "no floor under the army, round " .. round .. what)
			local had = me.troops
			check(line(ctx) == "Envia " .. UITheme.fmt_troops(had * 0.75) .. " tropas", "75% of the army on the line, order " .. round .. what .. ": " .. line(ctx))
			check(math.abs(send(ctx, me) - had * 0.75) < 1, "and 75% goes, order " .. round .. what)
			check(ctx.ratio == 0.75, "the share stays at 75%" .. what)
			check(line(ctx) ~= "Envia 0 tropas" and line(ctx) ~= reason, "after the order the line is not at nothing: " .. line(ctx) .. what)
		end
	end
	-- the switch off: a new player has no floor either
	Tutorial.ROOKIE_FLOOR_ON = false
	do
		local ctx, me, adv, tick = match(0)
		ctx:set_ratio(0.75)
		for round = 1, 3 do
			tick()
			adv:check_floor()
			local had = me.troops
			check(ctx.troop_floor == nil, "switched off: no floor, round " .. round)
			check(line(ctx) == "Envia " .. UITheme.fmt_troops(had * 0.75) .. " tropas", "switched off: 75% on the line, round " .. round .. ": " .. line(ctx))
			check(math.abs(send(ctx, me) - had * 0.75) < 1, "switched off: 75% goes, round " .. round)
		end
	end
	Tutorial.ROOKIE_FLOOR_ON = true
end

-- 2b. the player's own case (2026-11-12: "I have an amount, but I cannot send it": 329K of 763K at
-- 75% read "Sends 176K troops" and nothing said why it was not 247K). The line names the reserve.
do
	local ctx, me = context(3290000, 7630000)
	ctx:set_ratio(0.75)
	check(line(ctx) == "Envia 246K tropas", "no floor: 75% of 329K is 246.75K: " .. line(ctx))
	ctx.troop_floor = Tutorial.ROOKIE_FLOOR
	check(line(ctx) == "Envia 176K · reserva 152K", "with the floor: 176K go, and the line says 152.6K stay: " .. line(ctx))
	-- what goes and what stays are the whole army
	check(math.abs(ctx:troops_for_ratio() + Tutorial.ROOKIE_FLOOR * 7630000 - 3290000) < 1, "what goes and the reserve add up to the army")
	-- a share small enough to leave the reserve alone: the plain line, the whole share
	ctx:set_ratio(0.5)
	check(line(ctx) == "Envia 164K tropas", "50% of 329K leaves more than the reserve: the plain line: " .. line(ctx))
	ctx:set_ratio(0.1)
	check(line(ctx) == "Envia 32.9K tropas", "10%: the plain line: " .. line(ctx))
	-- the longest such line fits the box under the bar (180 px, 11 px text)
	for _, text in { "Envia 888.8K · reserva 888.8K", "Sends 888.8K · keeps 888.8K", "Envia 88.8M · reserva 88.8M" } do
		local w = UITheme.text_width(text, 11, 500)
		check(w <= 180, string.format("%q fits under the bar: %.0f of 180 px", text, w))
	end
	local _ = me
end

-- 3. the tutorial's floor (a quarter of the cap stays home): the line says why, not "Sends 0 troops"
do
	local ctx, me = context(5110000, 7000000)
	ctx.troop_floor = Tutorial.TROOP_FLOOR
	ctx:set_ratio(0.5)
	local held = 0
	ctx.floor_held:Connect(function()
		held += 1
	end)
	check(line(ctx) == "Envia " .. UITheme.fmt_troops(5110000 * 0.5) .. " tropas", "above the floor the line is the share: " .. line(ctx))
	send(ctx, me)
	-- 2.555M left of a 7M cap; the floor is 1.75M: 31.5% may go, not 50%
	check(math.abs(ctx:order_ratio() - (2555000 - 1750000) / 2555000) < 1e-6, "(the next order is trimmed to what stands above the floor)")
	check(line(ctx) == "Envia " .. UITheme.fmt_troops(805000) .. " · reserva " .. UITheme.fmt_troops(Tutorial.TROOP_FLOOR * 7000000), "a trimmed order: the line says what goes and what stays: " .. line(ctx))
	send(ctx, me)
	check(held == 1, "(the player is told the order was trimmed)")
	check(ctx:order_ratio() == 0, "(at the floor nothing may go)")
	check(line(ctx) == "Poucas tropas. Deixe recuperar", "at the floor the line says why: " .. line(ctx))
	check(string.find(line(ctx), "Envia 0", 1, true) == nil, "never \"Sends 0 troops\" beside a bar at 50%")
	check(ctx.ratio == 0.5, "the share on the bar is still 50%")
	local n = #ctx.sent_log
	send(ctx, me)
	check(#ctx.sent_log == n, "and an order sends nothing")
	me.troops = 3000000
	check(line(ctx) == "Envia " .. UITheme.fmt_troops(1250000) .. " · reserva " .. UITheme.fmt_troops(Tutorial.TROOP_FLOOR * 7000000), "the army grows back: the line counts again: " .. line(ctx))
	-- an army that is simply empty, no floor: the plain line
	local c2, m2 = context(0, 7000000)
	check(line(c2) == "Envia 0 tropas", "no army and no floor: the plain line: " .. line(c2))
	-- the reason fits the line's box (180 px, 11 px text; it would end in an ellipsis)
	local w = UITheme.text_width(Tutorial.FLOOR_REASON, 11, 500)
	check(w <= 180, "the reason fits under the bar: " .. w .. " of 180 px")
	local _ = m2
end

-- 4. the bar itself: a stop pressed stays; the release ends the hold; the pointer leaving changes nothing
for _, view in { { "pc", 1280, 720, false }, { "celular", 844, 390, true } } do
	local v = " (" .. view[1] .. ")"
	local root = H.root(view[2], view[3], view[4])
	local ctx, me = context(1000000, 1400000)
	ctx.vp = root.vp
	ctx.touch = view[4]
	local sl = RatioSlider.new(ctx)
	root:add_child(sl)
	H.step(5)
	local x, y, w, h = H.rect(sl.gui)
	local function at(i: number): Vector3
		return Vector3.new(x + (i - 0.5) * w / #UICtx.RATIO_STOPS, y + h / 2, 0)
	end
	local kind = if view[4] then Enum.UserInputType.Touch else Enum.UserInputType.MouseButton1
	local move = if view[4] then Enum.UserInputType.Touch else Enum.UserInputType.MouseMovement
	check(ctx.ratio == UICtx.DEFAULT_RATIO, "(a match starts at the default share)" .. v)
	local io = { UserInputType = kind, UserInputState = Enum.UserInputState.Begin, Position = at(4) }
	H.fire(sl.gui, "InputBegan", io)
	check(ctx.ratio == UICtx.RATIO_STOPS[4] and sl._drag == true, "a press on the fourth stop chooses it" .. v)
	io.UserInputState = Enum.UserInputState.End
	UIS.InputEnded:fire(io, true)
	check(sl._drag == false, "the release ends the hold" .. v)
	UIS.InputChanged:fire({ UserInputType = move, UserInputState = Enum.UserInputState.Change, Position = Vector3.new(5, 100, 0) }, false)
	check(ctx.ratio == UICtx.RATIO_STOPS[4], "the pointer going to the map leaves the share alone" .. v)
	H.step(60)
	check(sl._shown == 4, "the thumb rests on the stop chosen" .. v)
	send(ctx, me)
	send(ctx, me)
	H.step(30)
	check(ctx.ratio == UICtx.RATIO_STOPS[4] and sl._shown == 4, "two orders later the bar is where the player left it" .. v)
	-- a stop held and dragged: the share follows, and stops following at the release
	io = { UserInputType = kind, UserInputState = Enum.UserInputState.Begin, Position = at(2) }
	H.fire(sl.gui, "InputBegan", io)
	io.Position = at(5)
	io.UserInputType = move
	UIS.InputChanged:fire(io, false)
	check(ctx.ratio == UICtx.RATIO_STOPS[5], "dragged to the last stop" .. v)
	io.UserInputType = kind
	UIS.InputEnded:fire(io, true)
	io.Position = at(1)
	io.UserInputType = move
	UIS.InputChanged:fire(io, false)
	check(ctx.ratio == UICtx.RATIO_STOPS[5], "after the release the pointer no longer moves it" .. v)
end

-- 5. the command bar writes that line (and the advisor reads the switch)
do
	local src = fs.readFile("src/client/UI/CommandBar.luau")
	check(string.find(src, "self._ratio_sub:set_text(CommandBar.sends_text(ctx))", 1, true) ~= nil, "the bar's line is sends_text")
	check(select(2, string.gsub(src, "_ratio_sub:set_text", "")) == 1, "and nothing else writes it")
	local adv = fs.readFile("src/client/UI/UIAdvisor.luau")
	check(string.find(adv, "Tut.ROOKIE_FLOOR_ON ~= true", 1, true) ~= nil, "the advisor arms the floor only when the game has it")
	check(Lang.t(Tutorial.FLOOR_REASON) == "Poucas tropas. Deixe recuperar", "the reason is in the game's language")
end

print(string.format("barra_ataque: %d checks, %d failed", checks, failed))
if failed > 0 then
	error("barra_ataque failed")
end
