--!nocheck
-- A press never reaches what is behind an open window (2026-11-10: with the Arsenal open, a press
-- inside it started a match: it went to the title's button underneath). Widgets.add_blocker puts an
-- invisible button under the window's parts, Widgets.guard_presses makes a kit button behind an open
-- window refuse its press. Checked on the real screens: the lobby with the Arsenal, the Coleção and
-- the Loja Misteriosa over it.
--   lune run tests/janelas.luau
local H = require("./ui_harness")
local Signal = require("../src/shared/Core/Signal")
local UICtx = require("../src/client/UI/UICtx")
local UITheme = require("../src/client/UI/UITheme")
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
local W = require("../src/client/UI/Widgets")

local s = {
	inventory = {
		owned = {},
		equipped = {},
		stars = 31250,
		unlocks = {},
		crates_bought = 0,
		crates_allowed = true,
		crates_stars = false,
		loaded = true,
	},
	inventory_changed = Signal.new(),
	credits_changed = Signal.new(),
	crate_result = Signal.new(),
	crates_result = Signal.new(),
	shop_result = Signal.new(),
	unlock_result = Signal.new(),
	unlocked = Signal.new(),
	shop_day = 20000,
}
function s.report() end
function s.equip() end
function s.open_crate() end
function s.buy_crates() end
function s.shop_buy() end
function s.shop_pick() end
function s.unlock() end
-- (the missions' window reads its lists here: Session.missions_view)
function s.missions_view()
	local MissionData = require("../src/shared/Data/Missions")
	local t = MissionData.days_of(2026, 11, 12) * 86400 + 21 * 3600
	local v = MissionData.view(MissionData.clean({ day = MissionData.day(t), month = MissionData.month(t) }), t)
	v.on_sale = false
	return v
end

local ctx = UICtx.new()
ctx.vp = root.vp
ctx.compact = false
ctx.touch = false
ctx.touch_device = false
ctx.session = s
ctx.reserved_top_left = Rect.new(0, 0, 280 / UITheme.scale, 58 / UITheme.scale)
function ctx:sfx() end

H.fake_game()
local TitleScreen = require("../src/client/UI/TitleScreen")
local Arsenal = require("../src/client/UI/Arsenal")
local Locker = require("../src/client/UI/Locker")
local MysteryShop = require("../src/client/UI/MysteryShop")
local MissionsWindow = require("../src/client/UI/Missions")

local title = TitleScreen.new(ctx)
root:add_child(title)
title:apply_layout()
local locker = Locker.new(ctx)
root:add_child(locker)
local arsenal = Arsenal.new(ctx)
root:add_child(arsenal)
local shop = MysteryShop.new(ctx)
root:add_child(shop)
local missions = MissionsWindow.new(ctx)
root:add_child(missions)
local windows = { locker, arsenal, shop, missions }
for _, w in windows do
	W.add_blocker(w)
end
W.guard_presses(root, function()
	return windows
end)
for _, w in windows do
	if w.bind then
		w:bind(s)
	end
end
H.step(3)

-- what the lobby's buttons would do
local started, solo_menus, opened = 0, 0, 0
title.play_solo:Connect(function()
	started += 1
end)
title.open_arsenal:Connect(function()
	opened += 1
end)
local function press(b: any)
	-- (as Roblox reports a click or a tap that ended on the button)
	H.fire(b.gui, "Activated")
	H.step(1)
end

-- (every button asked about stands in the tree, under the title)
for _, b in { title._solo, title._start, title._q_arsenal } do
	local top = b
	while top ~= nil and top.parent ~= root do
		top = top.parent
	end
	check(top == title, "the lobby's button is the title's")
end

-- nothing open: the lobby's buttons work
press(title._solo)
check(title._solo_open == true, "JOGAR SOLO opens its menu when no window is open")
press(title._start)
check(started == 1, "COMEÇAR starts a match when no window is open")
press(title._q_arsenal)
check(opened == 1, "ARSENAL opens when no window is open")
if title._solo_open then
	solo_menus += 1
end

for _, case in { { "o Arsenal", arsenal }, { "a Coleção", locker }, { "a Loja Misteriosa", shop }, { "as Missões", missions } } do
	local name, w = case[1], case[2]
	local blocker = w.gui:FindFirstChild("ClickBlocker")
	check(blocker ~= nil and blocker.__class == "TextButton", name .. ": has a button under its parts that takes the press")
	check(blocker ~= nil and blocker.ZIndex < 0 and blocker.Size.X.Scale == 1 and blocker.Size.Y.Scale == 1, name .. ": that button fills the window, under everything")
	w:open()
	H.step(3)
	check(w.is_open == true, name .. ": open")
	local before, opened_before = started, opened
	press(title._start)
	check(started == before, name .. " open: COMEÇAR behind it does not start a match")
	title:close_solo_menu(true)
	press(title._solo)
	check(title._solo_open ~= true, name .. " open: JOGAR SOLO behind it does nothing")
	press(title._q_arsenal)
	check(opened == opened_before, name .. " open: the lobby's ARSENAL button behind it does nothing")
	w:close()
	H.step(30)
	H.flush()
	check(w.is_open ~= true, name .. ": closed")
	title:open_solo_menu()
	press(title._start)
	check(started == before + 1, name .. " closed: COMEÇAR works again")
end

-- a press that begins under an open window and closes it (the dim around the window) does not land on
-- the button behind when it is released
do
	arsenal:open()
	H.step(3)
	local before = started
	local heard = H.fire(title._start.gui, "InputBegan", { UserInputType = Enum.UserInputType.MouseButton1, UserInputState = Enum.UserInputState.Begin, Position = Vector3.new(0, 0, 0) })
	check(heard == true and title._start._refused_at ~= nil, "the button behind heard the press begin, and refused it")
	arsenal:close()
	H.fire(title._start.gui, "Activated")
	check(started == before, "a press begun under the Arsenal does not start a match when it ends after the Arsenal closed")
	H.step(30)
	H.flush()
	press(title._start)
	check(started == before + 1, "the next press, begun with nothing open, does")
end

-- a window's own buttons still work while it is open, and so does a window above another
arsenal:open()
H.step(3)
local row = arsenal._rows["mega"] or select(2, next(arsenal._rows))
local other
for key, r in arsenal._rows do
	if key ~= arsenal._sel then
		other = { key, r }
		break
	end
end
check(row ~= nil and other ~= nil, "the Arsenal has its cards")
if other ~= nil then
	H.fire(other[2].button, "Activated")
	check(arsenal._sel == other[1], "the Arsenal's own cards answer a press while it is open")
end
-- (the shop is drawn after the Arsenal: with both open, the shop's buttons are not behind anything)
check(W.press_blocked ~= nil, "the guard is installed")
local probe = W.Button.new("x")
shop:add_child(probe)
check(W.press_blocked(probe) == false, "a button of a window drawn above the open one is not blocked")
local probe2 = W.Button.new("y")
locker:add_child(probe2)
check(W.press_blocked(probe2) == true, "a button of a window drawn under the open one is blocked")
arsenal:close()
H.step(30)
H.flush()
check(W.press_blocked(probe2) == false, "and free again once it closes")

for _, p in H.problems() do
	check(false, "property Roblox lacks: " .. tostring(p))
end
print(string.format("janelas: %d checks, %d failed", checks, failed))
if failed > 0 then
	error("janelas failed")
end
