--!nocheck
-- "Fazer o tutorial" (2026-11-12): the settings page has a row that plays the tutorial again
-- (client/UI/PauseMenu, UIRoot.start_tutorial). Checked here, outside Roblox:
--   * the row is on the settings page in the lobby, on a computer and on phones, inside the window
--     and over no other row;
--   * it is not there inside a match, and it is off while a multiplayer match is waited for;
--   * a press closes the settings and starts the tutorial's match, with no question;
--   * the tutorial's Coroas are paid once in a player's life: played again, its last card says the
--     reward was already paid instead of promising it.
--   lune run tests/tutorial_de_novo.luau
local H = require("./ui_harness")
local fs = require("@lune/fs")
local UICtx = require("../src/client/UI/UICtx")
local UITheme = require("../src/client/UI/UITheme")
local W = require("../src/client/UI/Widgets")
for _, m in { "Locker", "MysteryShop", "Arsenal", "CrateOpening" } do
	require("../src/client/UI/" .. m)
end
local TutorialData = require("../src/shared/Data/Tutorial")
local Lang = require("../src/shared/Data/Lang")
Lang.use("pt")

local checks, failed = 0, 0
local function check(ok: any, what: string)
	checks += 1
	if not ok then
		failed += 1
		print("FAIL: " .. what)
	end
end

H.fake_game()
local PauseMenu = require("../src/client/UI/PauseMenu")
local UIRoot = require("../src/client/UI/UIRoot")
local UIMaps = require("../src/client/UI/UIMaps")

local function fake_audio()
	local a = {}
	function a:sfx_volume()
		return 0.7
	end
	function a:set_sfx_volume() end
	function a:music_volume()
		return 0.9
	end
	function a:set_music_volume() end
	function a:is_music_enabled()
		return true
	end
	function a:is_pops_enabled()
		return true
	end
	function a:play_sfx() end
	function a:has_sfx()
		return true
	end
	return a
end

local function press(b: any)
	H.fire(b.gui, "Activated")
	H.step(1)
end

--- where: "title" (the lobby), "queue" (waiting for a multiplayer match), "match" (a solo match)
local function make(view: any, where: string)
	local root = H.root(view[2], view[3], view[4])
	local ctx = UICtx.new()
	ctx.vp = root.vp
	ctx.compact = view[4]
	ctx.touch = view[4]
	ctx.touch_device = view[4]
	ctx.audio = fake_audio()
	local k = UITheme.scale
	ctx.reserved_top_left = Rect.new(0, 0, (if view[4] then 200 else 280) / k, (if view[4] then 44 else 58) / k)
	if where == "match" then
		ctx.session = { mode = UICtx.MODE_SOLO }
		ctx.state_mode = UICtx.MODE_SOLO
	elseif where == "queue" then
		ctx.session = { mode = UICtx.MODE_MULTI }
	end
	local pause = PauseMenu.new(ctx)
	root:add_child(pause)
	local asked = { n = 0 }
	pause.tutorial_requested:Connect(function()
		asked.n += 1
	end)
	pause:open(true, "settings")
	pause:apply_layout()
	H.step(4)
	return pause, asked, ctx
end

local function text_of(b: any): string
	local out = {}
	for _, d in b.gui:GetDescendants() do
		if type(d.Text) == "string" and d.Visible ~= false then
			table.insert(out, d.Text)
		end
	end
	if type(b.gui.Text) == "string" then
		table.insert(out, 1, b.gui.Text)
	end
	return table.concat(out)
end

check(Lang.t("Play the tutorial") == "Fazer o tutorial", "the row's text in Portuguese: Fazer o tutorial")
check(Lang.t(PauseMenu.TUTORIAL_QUEUE_TEXT) ~= PauseMenu.TUTORIAL_QUEUE_TEXT, "the queue's text is translated")

for _, view in { { "pc", 1280, 720, false }, { "celular", 844, 390, true }, { "celular pequeno", 667, 375, true } } do
	local v = " (" .. view[1] .. ")"
	-- ------------------------------------------------------------------------------------------
	-- the lobby
	-- ------------------------------------------------------------------------------------------
	do
		local pause, asked = make(view, "title")
		local b = pause._tutorial
		check(pause:page() == "settings" and pause._on_title == true, "the settings page, in the lobby" .. v)
		check(b:is_visible_in_tree(), "the tutorial's row is there" .. v)
		check(string.find(text_of(b), "Fazer o tutorial", 1, true) ~= nil, "it says Fazer o tutorial" .. v .. ": " .. text_of(b))
		check(b.disabled ~= true, "and can be pressed" .. v)
		local bx, by, bw, bh = H.rect(b.gui)
		local px, py, pw, ph = H.rect(pause._panel.gui)
		check(bw >= 200 and bh >= 36, string.format("the row has room%s: %.0f x %.0f", v, bw, bh))
		check(bx >= px and by >= py and bx + bw <= px + pw + 0.5 and by + bh <= py + ph + 0.5, "it is inside the window" .. v)
		check(px >= -0.5 and py >= -0.5 and px + pw <= view[2] + 0.5 and py + ph <= view[3] + 0.5, string.format("the window fits the screen%s: %.0f x %.0f at %.0f, %.0f", v, pw, ph, px, py))
		for name, other in { music = pause._music, effects = pause._sfx, pops = pause._pops, code = pause._code, tips = pause._tips, done = pause._done } do
			if other:is_visible_in_tree() then
				local ox, oy, ow, oh = H.rect(other.gui)
				local over = bx < ox + ow - 0.5 and ox < bx + bw - 0.5 and by < oy + oh - 0.5 and oy < by + bh - 0.5
				check(not over, "it is not over the " .. name .. " row" .. v)
			end
		end
		H.save(pause.gui, "assets/telas/config-tutorial-" .. (if view[1] == "pc" then "pc" elseif view[1] == "celular" then "celular" else "celular-pequeno") .. ".json")
		-- the game menu's page does not have it
		pause:_show_page("menu")
		H.step(2)
		check(b:get_parent() == nil, "the game menu's own page does not have it" .. v)
		pause:show_settings()
		pause:apply_layout()
		H.step(2)
		check(b:is_visible_in_tree(), "back on the settings page it is there again" .. v)
		-- a press
		press(b)
		check(asked.n == 1, "a press asks for the tutorial, once" .. v)
		check(not pause.is_open, "and closes the settings" .. v)
	end
	-- ------------------------------------------------------------------------------------------
	-- waiting for a multiplayer match
	-- ------------------------------------------------------------------------------------------
	do
		local pause, asked = make(view, "queue")
		local b = pause._tutorial
		check(b:is_visible_in_tree() and b.disabled == true, "in the queue the row is shown, off" .. v)
		check(string.find(text_of(b), "saia da fila", 1, true) ~= nil, "and says why" .. v .. ": " .. text_of(b))
		press(b)
		b.pressed:Fire() -- (even a press that got through)
		check(asked.n == 0 and pause.is_open, "a press does nothing" .. v)
		local px, py, pw, ph = H.rect(pause._panel.gui)
		check(px >= -0.5 and py >= -0.5 and px + pw <= view[2] + 0.5 and py + ph <= view[3] + 0.5, "the window fits the screen with the queue's text" .. v)
		local bx, _, bw = H.rect(b.gui)
		check(bx >= px and bx + bw <= px + pw + 0.5, "the row stays inside the window" .. v)
	end
	-- ------------------------------------------------------------------------------------------
	-- inside a match
	-- ------------------------------------------------------------------------------------------
	do
		local pause, asked = make(view, "match")
		local b = pause._tutorial
		check(not b:is_visible_in_tree(), "inside a match the row is not there" .. v)
		b.pressed:Fire()
		check(asked.n == 0 and pause.is_open, "and nothing can start the tutorial from there" .. v)
		local px, py, pw, ph = H.rect(pause._panel.gui)
		check(px >= -0.5 and py >= -0.5 and px + pw <= view[2] + 0.5 and py + ph <= view[3] + 0.5, "the match's settings still fit the screen" .. v)
	end
end

-- =============================================================================================
-- UIRoot: the press starts the tutorial's match
-- =============================================================================================
do
	local t = { mode = UICtx.MODE_TITLE, building = false, calls = {}, saved = {}, begun = 0 }
	local ctx = UICtx.new()
	function ctx:mode()
		return t.mode
	end
	function ctx:set_setting(k, val)
		t.saved[k] = val
	end
	function ctx:session_call(name, args)
		if name == "is_building" then
			return t.building
		end
		table.insert(t.calls, { name, args })
		return nil
	end
	local ui = setmetatable({
		ctx = ctx,
		coach = { muted = false, clear = function() end },
		tutorial = {
			begin = function()
				t.begun += 1
			end,
		},
	}, { __index = UIRoot })
	ui:start_tutorial()
	check(t.begun == 1 and #t.calls == 1 and t.calls[1][1] == "start_solo", "start_tutorial begins the steps and starts a solo match")
	local args = t.calls[1][2]
	check(args[1] == TutorialData.DIFFICULTY and args[2] == UIMaps.DEFAULT_ID and args[3].tribes == TutorialData.TRIBES, "the tutorial's own match: gentlest AI, the default map, fewer tribes")
	check(t.saved.tutorial == "started", "and the settings remember it started")
	check(t.saved.tutorial_n == 1, "and count the tutorial's match (it is not one of a new player's first matches)")
	t.mode = UICtx.MODE_SOLO
	ui:start_tutorial()
	check(t.begun == 1, "inside a match nothing starts")
	check(t.saved.tutorial_n == 1, "nor is counted")
	-- played again from the settings page: counted again; a record from before the count had one
	t.mode = UICtx.MODE_TITLE
	ctx.settings.tutorial_n = 1
	ui:start_tutorial()
	check(t.saved.tutorial_n == 2, "the tutorial played again is counted again")
	ctx.settings.tutorial_n = nil
	ctx.settings.tutorial = "done"
	ui:start_tutorial()
	check(t.saved.tutorial_n == 2, "a record from before the count: the tutorial it says was played, and this one")
	ctx.settings.tutorial = nil
	local src = fs.readFile("src/client/UI/UIRoot.luau")
	local a = string.find(src, "pause.tutorial_requested:Connect(function()", 1, true)
	check(a ~= nil and string.find(string.sub(src, a, a + 120), "self:start_tutorial()", 1, true) ~= nil, "UIRoot starts the tutorial when the settings ask for it")
end

-- =============================================================================================
-- the reward is paid once: the last card of a tutorial played again does not promise it
-- =============================================================================================
do
	local p = fs.readFile("src/server/Purchases.luau")
	local a = string.find(p, "function Purchases.tutorial_bonus", 1, true)
	local body = string.sub(p, a, a + 900)
	check(string.find(body, "if rec.tutorial_paid then", 1, true) ~= nil, "the server pays the tutorial's Coroas once")
	check(string.find(p, "tutorial_paid = i ~= nil and i.tutorial_paid == true", 1, true) ~= nil, "and tells the client whether they were paid")
	local s = fs.readFile("src/client/Session.luau")
	check(string.find(s, "tutorial_paid = inv.tutorial_paid == true", 1, true) ~= nil, "the client keeps it")
	local tu = fs.readFile("src/client/UI/Tutorial.luau")
	check(string.find(tu, "self._paid_before = type(inv) == \"table\" and inv.tutorial_paid == true", 1, true) ~= nil, "the tutorial reads it when it begins")
	check(string.find(tu, 'then "Tutorial complete!\\nIts reward was already yours"', 1, true) ~= nil, "and its last card says the reward was already paid")
	check(Lang.t("Tutorial complete!\nIts reward was already yours") == "Tutorial concluído!\nA recompensa dele você já recebeu", "in Portuguese")
	check(string.find(Lang.t(string.format("Tutorial complete! +%s Stars\nSpend them in the ARSENAL", "1.000")), "+1.000 Coroas", 1, true) ~= nil, "the first time it still promises the Coroas")
end

for _, p in H.problems() do
	check(false, "a property Roblox does not have: " .. p)
end
print(string.format("tutorial_de_novo: %d checks, %d failed", checks, failed))
if failed > 0 then
	error("tutorial_de_novo failed")
end
