--!nocheck
-- The MISSÕES window (client/UI/Missions) with what feeds it (client/Session), outside Roblox:
--   * Session: the missions arrive with the inventory; the server's clock is followed, not the
--     device's; junk from the server never reaches the window;
--   * before the inventory arrives the window says it is loading; then a row for each mission;
--   * the two tabs; the season's panel only on the pass's one;
--   * the pass's button: its price, "EM BREVE" with no product, "AGUARDE…" while Roblox's purchase
--     window is up, back to the price when the player gives up, "PASSE ATIVO" when the server says so;
--   * a monthly mission completed without the pass waits with a padlock, and is paid with the pass;
--   * midnight passes with the window open: the new day's missions, from zero;
--   * the mission's texts and the season's name are drawn as the owner wrote them;
--   * a press on the close button closes it;
--   * UIRoot stacks it with the lobby's other windows, and a match that starts takes it away.
--   lune run tests/missoes_janela.luau
local H = require("./ui_harness")
local fs = require("@lune/fs")
local UICtx = require("../src/client/UI/UICtx")
local UITheme = require("../src/client/UI/UITheme")
local W = require("../src/client/UI/Widgets")
local Session = require("../src/client/Session")
local Protocol = require("../src/shared/Net/Protocol")
local MissionData = require("../src/shared/Data/Missions")
local Products = require("../src/shared/Data/Products")
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

H.fake_game()
local Window = require("../src/client/UI/Missions")
local OP = Protocol.OP

-- 2026-11-12 18:48 in Brasília (21:48 UTC) on the server; this device's clock is 40 minutes behind
local T = MissionData.days_of(2026, 11, 12) * 86400 + 21 * 3600 + 48 * 60
local SKEW = 40 * 60
local device = T - SKEW
Session.unix = function()
	return device
end
local clock = 100.0
Window.now = function()
	return clock
end

local function press(b: any)
	H.fire(b.gui, "Activated")
	H.step(1)
end
--- The texts drawn under `node`, glued.
local function shown(node: any): string
	local out = {}
	local function add(g: any)
		if type(g.Text) == "string" and g.Visible ~= false then
			table.insert(out, g.Text)
		end
	end
	add(node.gui)
	for _, d in node.gui:GetDescendants() do
		add(d)
	end
	return table.concat(out, "|")
end

local sent = {}
local net = {
	connected = true,
	send = function(op, ...)
		table.insert(sent, table.pack(op, ...))
	end,
	listen = function() end,
}
local s = Session.new({
	now = function()
		return 0
	end,
	net = net,
})

--- What the server sends: the stored state, its clock, whether the pass has a product.
local day, month = MissionData.day(T), MissionData.month(T)
local todays = MissionData.daily(day)
local function state(pass: boolean): any
	local st = MissionData.clean({ day = day, month = month })
	st.d[todays[1].counter] = todays[1].goal
	st.m = { played = 47, kills = 131, minutes = 212, top3 = 9, daily = 14, wins = 20 }
	MissionData.settle(st, T, {})
	if pass then
		st.pass = month
		MissionData.settle(st, T, {})
	end
	return st
end
local function inventory(st: any, on_sale: boolean, now: number?): any
	local m = table.clone(st)
	m.now = now or T
	m.on_sale = on_sale
	return { owned = {}, equipped = {}, stars = 31250, unlocks = {}, missions = m }
end

-- ---------------------------------------------------------------------------------------------
-- Session
-- ---------------------------------------------------------------------------------------------
do
	local v = s:missions_view()
	check(type(v) == "table" and #v.daily == MissionData.DAILY_COUNT and v.pass == false and v.on_sale == false, "a new session: today's missions at zero, no pass, nothing on sale")
	local zero = true
	for _, m in v.daily do
		zero = zero and m.have == 0 and not m.done
	end
	check(zero, "nothing counted before the server speaks")
	check(s.inventory.loaded == false, "and the inventory is not loaded")

	local fired = 0
	s.inventory_changed:Connect(function()
		fired += 1
	end)
	s:_on_net(OP.INVENTORY, inventory(state(false), true))
	check(fired == 1 and s.inventory.loaded == true, "the inventory arrives: the signal fires")
	check(s.inventory.missions.skew == SKEW, string.format("the server's clock is %d s ahead of this device's (%s)", SKEW, tostring(s.inventory.missions.skew)))
	check(s:server_unix() == T, "server_unix is the server's time")
	v = s:missions_view()
	check(v.day == day and v.month == month, "the view is of the server's day and month")
	check(v.on_sale == true and v.pass == false, "the pass is on sale, not bought")
	check(v.daily[1].done == true and v.daily[1].paid == true and v.daily[2].done == false, "the first daily mission is done and paid, the second is not")
	check(v.day_left == 5 * 3600 + 12 * 60, string.format("5h 12min to midnight in Brasília (%s s)", tostring(v.day_left)))

	-- a device whose clock is a day wrong still follows the server
	device = T - 86400 - 777
	s:_on_net(OP.INVENTORY, inventory(state(false), true))
	check(s:missions_view().day == day and s:server_unix() == T, "a device a day behind shows the server's day")
	device = T - SKEW
	s:_on_net(OP.INVENTORY, inventory(state(false), true))

	-- junk
	local before = fired
	for _, junk in { 5, "x", true } do
		s:_on_net(OP.INVENTORY, junk)
	end
	check(fired == before, "an inventory that is not a table is ignored")
	for _, junk in { 5, "x", { day = "a", d = 7, m = "q", pass = {}, now = 0 / 0, on_sale = "yes" }, { d = { played = -4, wins = 1 / 0, x = 9 }, now = "soon" } } do
		local inv = inventory(state(false), true)
		inv.missions = junk
		local ok = pcall(function()
			s:_on_net(OP.INVENTORY, inv)
		end)
		local view
		local ok2 = pcall(function()
			view = s:missions_view()
		end)
		local sane = ok and ok2 and type(view) == "table" and #view.daily == MissionData.DAILY_COUNT and view.on_sale == false and view.pass == false
		if sane then
			for _, m in view.daily do
				sane = sane and m.have == m.have and m.have >= 0 and m.have <= m.goal
			end
			for _, m in view.monthly do
				sane = sane and m.have == m.have and m.have >= 0 and m.have <= m.goal
			end
		end
		check(sane, "junk missions from the server: a clean, empty view")
	end
	local n = 0
	for _, e in sent do
		n += 1
	end
	check(n == 0, "the missions ask the server nothing: they come with the inventory")
end

-- ---------------------------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------------------------
local root, _gui = H.root(1280, 720, false)
local ctx = UICtx.new()
ctx.vp = root.vp
ctx.compact = false
ctx.touch = false
ctx.touch_device = false
local sounds = {}
function ctx:sfx(name)
	table.insert(sounds, name)
end

-- a session that has not heard the server yet
local s2 = Session.new({
	now = function()
		return 0
	end,
	net = net,
})
ctx.session = s2
local was_id = Products.pass.id
Products.pass.id = 987654
local m = Window.new(ctx)
root:add_child(m)
m:bind(s2)
H.step(3)
check(m.is_open ~= true and m.visible == false, "made closed")

m:open()
H.step(40)
check(m.is_open == true and m.visible == true, "open")
check(Window.TABS[m._tab].key == "daily", "it opens on the daily missions")
check(#m._rows == 0 and m._empty.visible == true and m._empty.text == "Carregando as missões…", "before the inventory: it says it is loading (" .. tostring(m._empty.text) .. ")")
check(m._foot.text == "", "and the foot says nothing")
check(m._season.visible == false, "no season panel on the daily tab")

s2:_on_net(OP.INVENTORY, inventory(state(false), true))
H.step(10)
check(#m._rows == MissionData.DAILY_COUNT and m._empty.visible == false, "the inventory arrives: a row for each of today's missions")
for i, row in m._rows do
	check(row.text.text == todays[i].text, string.format("row %d shows the owner's text as written (%s)", i, tostring(row.text.text)))
end
check(m._rows[1].mission.paid == true and m._rows[1].state.modulate_a == 1 and m._rows[1].locked == false, "the mission done has its tick")
check(m._rows[2].state.modulate_a == 0, "the one not done has none")
check(m._rows[1].frac == 1 and m._rows[2].frac == 0, "the bars: full, empty")
check(string.find(m._foot.text, "5h 12min", 1, true) ~= nil and string.find(m._foot.text, "de graça", 1, true) ~= nil, "the foot: when the new ones come, and that they are free (" .. m._foot.text .. ")")
check(m._title.text == "MISSÕES" and string.find(shown(m._head), "Cumpriu a meta", 1, true) ~= nil, "the window's title and what it says under it are in Portuguese")

-- the pass's tab
press(m._tabs[2])
H.step(10)
check(Window.TABS[m._tab].key == "pass" and m._season.visible == true, "PASSE DO MÊS: the season's panel shows")
local monthly = MissionData.monthly()
check(#m._rows == #monthly and #monthly >= 3, "a row for each monthly mission")
local season = MissionData.season(month)
check(m._season_name.text == season.name and season.name == "Cinzas da Fênix", "November's season by its name (" .. tostring(m._season_name.text) .. ")")
check(string.find(m._season_when.text, "NOVEMBRO DE 2026", 1, true) ~= nil, "and its month (" .. tostring(m._season_when.text) .. ")")
check(m._buy.disabled == false and string.find(m._buy.text, "COMPRAR O PASSE", 1, true) ~= nil and string.find(m._buy.text, tostring(Products.pass.robux), 1, true) ~= nil, "the button: the price and COMPRAR O PASSE (" .. tostring(m._buy.text) .. ")")
local waiting, open_rows = 0, 0
for _, row in m._rows do
	if row.mission.done then
		waiting += 1
		check(row.locked == true and row.mission.paid == false and row.state.modulate_a == 1, "done without the pass: a padlock, not paid (" .. row.mission.id .. ")")
	else
		open_rows += 1
		check(row.locked == false and row.state.modulate_a == 0, "not done: no mark (" .. row.mission.id .. ")")
	end
end
check(waiting == 3 and open_rows == 3, string.format("three monthly missions wait for the pass, three go on (%d, %d)", waiting, open_rows))
check(string.find(m._foot.text, "18 dias", 1, true) ~= nil and string.find(m._foot.text, "compre o passe", 1, true) ~= nil, "the foot: the season's end and that the progress counts (" .. m._foot.text .. ")")

-- outside Roblox there is no purchase window: the button refuses, with words
press(m._buy)
check(m._pending == nil and m._foot.text == "O passe ainda não está à venda.", "no Roblox here: the press says so (" .. m._foot.text .. ")")
clock += Window.SAY_S + 1
m:tick()
check(string.find(m._foot.text, "18 dias", 1, true) ~= nil, "the message leaves after a while")

-- Roblox's purchase window is up (as _buy_pressed leaves it there)
m._pending = { since = clock, product = Products.pass.id }
m:_refresh_pass()
check(m._buy.disabled == true and m._buy.text == "AGUARDE…", "while Roblox asks: AGUARDE…, and the button is off")
press(m._buy)
check(m._pending ~= nil and m._pending.since == clock, "a second press does nothing")
m:_on_prompt_done(111, true)
check(m._pending ~= nil and m._buy.text == "AGUARDE…", "another product's answer is not this one's")
m:_on_prompt_done(Products.pass.id, false)
check(m._pending == nil and m._buy.disabled == false and string.find(m._buy.text, "COMPRAR O PASSE", 1, true) ~= nil, "the player gave up: the price again")

-- bought, but the server never answers: the button comes back
m._pending = { since = clock, product = Products.pass.id }
m:_on_prompt_done(Products.pass.id, true)
check(m._pending ~= nil and m._pending.paid == true and m._buy.text == "AGUARDE…", "bought: it waits for the server")
clock += Window.PENDING_S - 5
m:tick()
check(m._pending ~= nil, "still waiting before the limit")
clock += 10
m:tick()
check(m._pending == nil and m._buy.disabled == false, "no answer in time: the button comes back")

-- bought, and the server answers with the pass on
m._pending = { since = clock, product = Products.pass.id }
m:_on_prompt_done(Products.pass.id, true)
s2:_on_net(OP.INVENTORY, inventory(state(true), true))
H.step(10)
check(m._pending == nil and m._buy.disabled == true and m._buy.text == "PASSE ATIVO", "the server turns the pass on: PASSE ATIVO (" .. tostring(m._buy.text) .. ")")
check(m._foot.text == "O passe é seu! Os prêmios estão sendo entregues.", "and the window says it (" .. m._foot.text .. ")")
local paid = 0
for _, row in m._rows do
	if row.mission.done then
		paid += 1
		check(row.locked == false and row.mission.paid == true, "with the pass the mission done is paid (" .. row.mission.id .. ")")
	end
end
check(paid == 3, "the three that waited are paid")
press(m._buy)
check(m._pending == nil, "PASSE ATIVO cannot be pressed")
clock += Window.SAY_S + 1
m:tick()
check(string.find(m._foot.text, "18 dias", 1, true) ~= nil and string.find(m._foot.text, "dia 1", 1, true) ~= nil, "the foot: how long the pass lasts (" .. m._foot.text .. ")")

-- no product yet
s2:_on_net(OP.INVENTORY, inventory(state(false), false))
H.step(10)
check(m._buy.disabled == true and m._buy.text == "EM BREVE", "no product for the pass: EM BREVE")
s2:_on_net(OP.INVENTORY, inventory(state(false), true))
Products.pass.id = 0
m:_refresh_pass()
press(m._buy)
check(m._pending == nil, "and with the id at zero nothing is asked of Roblox")
Products.pass.id = 987654
clock += Window.SAY_S + 1

-- midnight passes with the window open
press(m._tabs[1])
H.step(10)
check(Window.TABS[m._tab].key == "daily" and m._season.visible == false and #m._rows == MissionData.DAILY_COUNT, "back on the daily tab")
check(m._rows[1].mission.done == true, "today's first is done")
device += 5 * 3600 + 12 * 60 + 30
clock += Window.TICK_S + 0.1
m:tick()
H.step(10)
local tomorrow = MissionData.daily(day + 1)
local fresh = #m._rows == #tomorrow
for i, row in m._rows do
	fresh = fresh and row.mission.id == tomorrow[i].id and row.mission.have == 0 and not row.mission.done
end
check(fresh, "after midnight: tomorrow's missions, from zero, without closing the window")
check(string.find(m._foot.text, "23h 59min", 1, true) ~= nil, "and a whole day to do them (" .. m._foot.text .. ")")
press(m._tabs[2])
H.step(10)
local kept = 0
for _, row in m._rows do
	if row.mission.done then
		kept += 1
	end
end
check(kept == 3, "the month's progress is not touched by the day")
-- the month turns
device = MissionData.days_of(2026, 12, 1) * 86400 + 3 * 3600 + 60
clock += Window.TICK_S + 0.1
m:tick()
H.step(10)
local zero = true
for _, row in m._rows do
	zero = zero and row.mission.have == 0 and not row.mission.done
end
check(zero, "on the 1st the monthly missions start again")
check(m._season_name.text == MissionData.season(month + 1).name and m._season_name.text == "Noite de Gelo", "and the season is December's (" .. tostring(m._season_name.text) .. ")")
check(string.find(m._buy.text, "COMPRAR O PASSE", 1, true) ~= nil, "whose pass is for sale")
device = T - SKEW

-- closing
local closed = 0
m.closed:Connect(function()
	closed += 1
end)
press(m._close_b)
H.step(30)
H.flush()
check(m.is_open ~= true and closed == 1 and m.visible == false, "the close button closes it")
m:open("pass")
H.step(10)
check(m.is_open == true and Window.TABS[m._tab].key == "pass" and m._season.visible == true, "open(\"pass\") opens on the pass")
m:close()
H.step(30)
H.flush()
m:open()
H.step(10)
check(Window.TABS[m._tab].key == "pass", "opened again: the tab last seen")
m:close()
H.step(30)
H.flush()
Products.pass.id = was_id

-- ---------------------------------------------------------------------------------------------
-- UIRoot and the title screen
-- ---------------------------------------------------------------------------------------------
do
	local src = fs.readFile("src/client/UI/UIRoot.luau")
	local function has(text: string): boolean
		return string.find(src, text, 1, true) ~= nil
	end
	check(has('local MissionsWindow = require("./Missions")'), "UIRoot loads the window")
	check(has("local missions = MissionsWindow.new(ctx)") and has("self.missions_window = missions") and has("root:add_child(missions)"), "makes it, and adds it to the screen")
	check(has("missions.show_item = Locker.show_item"), "it draws the items as the Coleção does")
	local a = string.find(src, "root:add_child(rank)", 1, true)
	local b = string.find(src, "root:add_child(missions)", 1, true)
	local c = string.find(src, "root:add_child(ask)", 1, true)
	check(a ~= nil and b ~= nil and c ~= nil and a < b and b < c, "above the lobby and its windows, under the questions")
	check(has("rank, missions, opening, ask, confirm }"), "it is one of the windows nothing behind takes a press through")
	check(has("title.open_missions:Connect(function()") and has("function UIRoot.open_missions(self, tab: string?)"), "the title's MISSÕES button opens it")
	check(has("self.missions_window:bind(session)"), "it is given the session")
	local at = string.find(src, "function UIRoot._window_open", 1, true)
	local wo = string.sub(src, at, at + 600)
	check(string.find(wo, "self.missions_window,", 1, true) ~= nil, "the tutorial's question waits for it to close")
	check(has("or (self.missions_window ~= nil and self.missions_window.is_open)"), "open, it is a modal for the input gate")
	check(has("and not (self.missions_window ~= nil and self.missions_window.is_open)"), "and nothing opens by itself over it")
	check(has('guard("Missions.tick", self.missions_window.tick, self.missions_window)'), "it ticks while open")
	check(has('if scr ~= "title" and self.missions_window ~= nil and self.missions_window.is_open then'), "a match that starts closes it")
	local ts = fs.readFile("src/client/UI/TitleScreen.luau")
	check(string.find(ts, 'UITheme.button("MISSIONS", "GlassButton", "target", 38.0)', 1, true) ~= nil, "the title has the MISSIONS button")
	check(string.find(ts, "self.open_missions:Fire()", 1, true) ~= nil, "which fires open_missions")
end

for _, p in H.problems() do
	check(false, "a property Roblox does not have: " .. p)
end
print(string.format("missoes_janela: %d checks, %d failed", checks, failed))
if failed > 0 then
	error("missoes_janela: failed")
end
