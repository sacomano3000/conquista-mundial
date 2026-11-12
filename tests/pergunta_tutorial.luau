--!nocheck
-- "Quer fazer o tutorial?" (2026-11-10): a new player is asked before the tutorial starts
-- (client/UI/TutorialAsk, UIRoot._tutorial_step). Checked here, outside Roblox:
--   * the question opens where the tutorial used to start by itself, and nothing starts before an answer;
--   * it waits while another window is open;
--   * yes starts the tutorial's match; no saves "declined", and the player is not asked again;
--   * a press outside the window answers nothing; the lobby's buttons behind it are refused;
--   * taken into a match meanwhile: it closes with no answer saved;
--   * RoWorld's "Replay as new player" is gone (the menu, the client, the server, the protocol).
--   lune run tests/pergunta_tutorial.luau
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
local function check(ok: boolean, what: string)
	checks += 1
	if not ok then
		failed += 1
		print("FAIL: " .. what)
	end
end

local root, _gui = H.root(1280, 720, false)
-- (the modules above loaded as outside Roblox; the title and UIRoot ask Roblox for services)
H.fake_game()
local UIRoot = require("../src/client/UI/UIRoot")
local UIMaps = require("../src/client/UI/UIMaps")
local TutorialAsk = require("../src/client/UI/TutorialAsk")

--- A stand-in for UIRoot with the real question in it: UIRoot's own functions run on it.
local function make(settings: any, stats: any)
	local t = { mode = UICtx.MODE_TITLE, waiting = false, building = false, calls = {}, saved = {}, begun = 0, gates = 0 }
	local ctx = UICtx.new()
	ctx.vp = root.vp
	ctx.compact = false
	ctx.settings = settings
	ctx.reserved_top_left = Rect.new(0, 0, 280 / UITheme.scale, 58 / UITheme.scale)
	ctx.session = {
		load_settings = function(_s, _name)
			return stats
		end,
	}
	function ctx:sfx() end
	function ctx:mode()
		return t.mode
	end
	function ctx:mp_waiting()
		return t.waiting
	end
	function ctx:set_setting(k, v)
		t.saved[k] = v
		settings[k] = v
	end
	function ctx:session_call(name, args)
		if name == "is_building" then
			return t.building
		end
		table.insert(t.calls, { name, args })
		return nil
	end
	local ask = TutorialAsk.new(ctx)
	root:add_child(ask)
	local ui = setmetatable({
		ctx = ctx,
		_screen = "title",
		tutorial_ask = ask,
		tooltip = { hide_tip = function() end },
		coach = { muted = false, clear = function() end },
		tutorial = {
			active = false,
			begin = function()
				t.begun += 1
			end,
		},
		help = { is_open = false },
		pause = { is_open = false },
		over = { is_open = false },
		map_picker = { is_open = false },
		locker = { is_open = false },
	}, { __index = UIRoot })
	ui._update_input_gate = function()
		t.gates += 1
	end
	ask.answered:Connect(function(yes)
		ui:_on_tutorial_answer(yes)
	end)
	t.ui, t.ask, t.ctx = ui, ask, ctx
	return t
end

local function press(b: any)
	H.fire(b.gui, "Activated")
	H.step(1)
end

local function started(t: any): any
	for _, c in t.calls do
		if c[1] == "start_solo" then
			return c[2]
		end
	end
	return nil
end

-- a new player: the question, not the tutorial
do
	local t = make({}, { matches = 0 })
	local ui = t.ui
	ui:_check_new_player(false)
	check(ui._tutorial_at ~= nil, "a new player on the title is due the question")
	ui:_tutorial_step()
	check(not t.ask.is_open and ui._tutorial_at ~= nil, "not before the moment's wait is over")
	ui._tutorial_at = 0
	t.building = true
	ui:_tutorial_step()
	check(not t.ask.is_open and ui._tutorial_at ~= nil, "not while a match is being built")
	t.building = false
	ui.locker.is_open = true
	ui:_tutorial_step()
	check(not t.ask.is_open and ui._tutorial_at ~= nil, "not over an open window: it waits")
	ui.locker.is_open = false
	-- the question before a purchase is a window too (it was left out of the list before 2026-11-12)
	local had_confirm = ui.confirm_buy
	ui.confirm_buy = { is_open = true }
	ui:_tutorial_step()
	check(not t.ask.is_open and ui._tutorial_at ~= nil, "not over \"confirm the purchase?\": it waits")
	ui.confirm_buy = had_confirm
	ui:_tutorial_step()
	check(t.ask.is_open == true and ui._tutorial_at == nil, "then the question opens")
	check(t.begun == 0 and started(t) == nil, "the tutorial has not started by itself")
	check(t.saved.tutorial == nil, "and nothing is saved before an answer")
	check(t.gates > 0, "the map takes no input under the question")
	H.step(30)
	-- a press outside the window
	H.fire(t.ask._dim.gui, "InputBegan", { UserInputType = "MouseButton1", Position = Vector3.new(5, 5, 0) })
	H.fire(t.ask.gui, "Activated")
	H.step(2)
	check(t.ask.is_open == true and t.saved.tutorial == nil, "a press outside the window answers nothing")
	-- yes
	press(t.ask._yes)
	check(t.ask.is_open == false, "yes closes the question")
	check(t.saved.tutorial == "started" and t.begun == 1, "yes starts the tutorial")
	local a = started(t)
	check(a ~= nil, "... as a solo match")
	if a ~= nil then
		check(a[1] == TutorialData.DIFFICULTY and a[2] == UIMaps.DEFAULT_ID, "... the gentlest, on the default map")
		check(type(a[3]) == "table" and a[3].tribes == TutorialData.TRIBES, "... with the tutorial's tribes")
	end
	check(ui.coach.muted == true, "... the coach's tips wait")
	press(t.ask._yes)
	check(t.begun == 1, "a second press on a closed question does nothing")
end

-- no
do
	local settings = {}
	local t = make(settings, { matches = 0 })
	local ui = t.ui
	ui:_check_new_player(false)
	ui._tutorial_at = 0
	ui:_tutorial_step()
	check(t.ask.is_open == true, "the question opens for another new player")
	press(t.ask._no)
	check(t.ask.is_open == false, "no closes the question")
	check(t.saved.tutorial == TutorialData.DECLINED and TutorialData.DECLINED == "declined", "no is saved")
	check(t.begun == 0 and started(t) == nil, "no starts nothing")
	check(TutorialData.is_new(settings, { matches = 0 }) == false, "one who said no is not a new player any more")
	ui._tutorial_at = nil
	ui:_check_new_player(false)
	check(ui._tutorial_at == nil, "so they are not asked again")
end

-- not a new player: never asked
do
	for _, case in { { { tutorial = "done" }, { matches = 0 } }, { {}, { matches = 3 } }, { { tips_seen = { expand = true } }, {} } } do
		local t = make(case[1], case[2])
		t.ui:_check_new_player(false)
		check(t.ui._tutorial_at == nil, "a player who has played is not asked")
	end
end

-- on their way into a match before the question opens: it is dropped
do
	local t = make({}, { matches = 0 })
	local ui = t.ui
	ui:_check_new_player(false)
	ui._tutorial_at = 0
	t.waiting = true
	ui:_tutorial_step()
	check(not t.ask.is_open and ui._tutorial_at == nil, "in a queue already: no question")
end

-- taken into a match while the question is open: closed, no answer
do
	local t = make({}, { matches = 0 })
	local ui = t.ui
	ui:_check_new_player(false)
	ui._tutorial_at = 0
	ui:_tutorial_step()
	ui:_tutorial_ask_step()
	check(t.ask.is_open == true, "the question stays open on the title")
	t.mode = "match"
	ui:_tutorial_ask_step()
	check(t.ask.is_open == false, "taken into a match: the question closes")
	check(t.saved.tutorial == nil and t.begun == 0, "... with no answer saved, and no tutorial")
end

-- the window itself, over the lobby, on a computer and on a phone
local TitleScreen = require("../src/client/UI/TitleScreen")
for _, view in { { "pc", 1280, 720, false }, { "celular", 844, 390, true }, { "celular em pé", 390, 844, true } } do
	local r2, _g2 = H.root(view[2], view[3], view[4])
	local ctx = UICtx.new()
	ctx.vp = r2.vp
	ctx.compact = view[4]
	ctx.touch = view[4]
	ctx.touch_device = view[4]
	ctx.session = { inventory = { stars = 0, loaded = true, owned = {}, equipped = {}, unlocks = {} } }
	local k = UITheme.scale
	ctx.reserved_top_left = Rect.new(0, 0, (if view[4] then 200 else 280) / k, (if view[4] then 44 else 58) / k)
	function ctx:sfx() end
	local title = TitleScreen.new(ctx)
	r2:add_child(title)
	title:apply_layout()
	local ask = TutorialAsk.new(ctx)
	r2:add_child(ask)
	W.add_blocker(ask)
	W.guard_presses(r2, function()
		return { ask }
	end)
	local solo = 0
	title.play_solo:Connect(function()
		solo += 1
	end)
	H.step(3)
	check(W.press_blocked(title._solo) == false, view[1] .. ": the lobby's buttons work with no question")
	ask:open()
	H.step(40)
	local name = view[1]
	local x, y, w, h = H.rect(ask._panel.gui)
	check(
		x >= -0.5 and y >= -0.5 and x + w <= H.view.X + 0.5 and y + h <= H.view.Y + 0.5,
		string.format("%s: the window is inside the screen (%.0f, %.0f, %.0f x %.0f in %d x %d)", name, x, y, w, h, H.view.X, H.view.Y)
	)
	for _, b in { ask._yes, ask._no } do
		local bx, by, bw, bh = H.rect(b.gui)
		check(bx >= x - 0.5 and by >= y - 0.5 and bx + bw <= x + w + 0.5 and by + bh <= y + h + 0.5, name .. ": a button is inside the window")
		check(bh >= (if view[4] then 40 else 34), string.format("%s: the button is tall enough to press (%.0f px)", name, bh))
	end
	local nx, _, nw = H.rect(ask._no.gui)
	local yx = H.rect(ask._yes.gui)
	check(nx + nw <= yx + 0.5, name .. ": no is to the left of yes, not over it")
	-- (what the screen shows: the kit's labels and buttons put their text through Data/Lang)
	-- (a text with letter spacing is drawn a letter at a time: the pieces are put together again, and
	-- compared without their spaces)
	local function shown(c: any): string
		local g = c.gui
		local out = {}
		if g ~= nil then
			if type(g.Text) == "string" then
				table.insert(out, g.Text)
			end
			for _, d in g:GetDescendants() do
				if type(d.Text) == "string" then
					table.insert(out, d.Text)
				end
			end
		end
		return (string.gsub(table.concat(out), "%s+", ""))
	end
	check(shown(ask._title) == "QUERFAZEROTUTORIAL?", name .. ": the title is in Portuguese: " .. shown(ask._title))
	check(shown(ask._yes) == "Sim,quero" and shown(ask._no) == "Não,pular", name .. ": the answers are in Portuguese: " .. shown(ask._yes) .. " / " .. shown(ask._no))
	check(string.find(shown(ask._pay), "1.000Coroas", 1, true) ~= nil, name .. ": it says what finishing pays: " .. shown(ask._pay))
	check(string.find(shown(ask._text), "passoapasso", 1, true) ~= nil, name .. ": it says what the tutorial is: " .. shown(ask._text))
	check(string.find(shown(ask._note), "COMOJOGAR", 1, true) ~= nil, name .. ": it names the lobby's button: " .. shown(ask._note))
	local blocker = ask.gui:FindFirstChild("ClickBlocker")
	check(blocker ~= nil and blocker.ZIndex < 0, name .. ": a button under its parts takes the press")
	check(W.press_blocked(title._solo) == true and W.press_blocked(title._q_arsenal) == true, name .. ": the lobby's buttons behind it are refused")
	H.fire(title._solo.gui, "Activated")
	H.fire(title._start.gui, "Activated")
	H.step(1)
	check(solo == 0 and title._solo_open ~= true, name .. ": no match starts behind the question")
	check(W.press_blocked(ask._yes) == false and W.press_blocked(ask._no) == false, name .. ": its own buttons answer")
	local got = nil
	ask.answered:Connect(function(yes)
		got = yes
	end)
	press(ask._no)
	check(got == false and ask.is_open == false, name .. ": no answers no")
	H.step(30)
	H.flush()
	check(W.press_blocked(title._solo) == false, name .. ": the lobby's buttons work again once it closes")
end

-- RoWorld's "Replay as new player" is gone
do
	local Protocol = require("../src/shared/Net/Protocol")
	check(Protocol.OP.NEW_PLAYER == nil, "the protocol has no NEW_PLAYER")
	check(UIRoot.replay_as_new_player == nil, "UIRoot has no replay_as_new_player")
	for _, path in {
		"src/client/UI/PauseMenu.luau",
		"src/client/UI/UIRoot.luau",
		"src/client/Session.luau",
		"src/client/UI/Telemetry.luau",
		"src/client/Dev/SessionDiag.luau",
		"src/server/ServerMain.luau",
		"src/server/Purchases.luau",
		"src/shared/Data/LangPt.luau",
	} do
		local src = fs.readFile(path)
		check(string.find(src, "Replay as new player", 1, true) == nil, path .. " does not speak of the button")
		check(string.find(src, "new_player_requested", 1, true) == nil and string.find(src, "reset_new_player", 1, true) == nil, path .. " has none of its code")
	end
end

for _, p in H.problems() do
	check(false, "property Roblox lacks: " .. tostring(p))
end
print(string.format("pergunta_tutorial: %d checks, %d failed", checks, failed))
if failed > 0 then
	error("pergunta_tutorial failed")
end
