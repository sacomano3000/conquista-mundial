--!nonstrict
-- The MISSIONS window (2026-11-12; the lobby's MISSÕES button): the daily missions, free for everyone,
-- and the monthly pass (shared/Data/Missions; the owner's lists are Data/MyMissions).
--   head     the name, what it is, close.
--   tabs     DAILY (today's missions; Coroas the moment a goal is reached; new ones at midnight in
--            Brasília) | MONTHLY PASS (the month's long missions: their rewards are for whoever bought
--            the pass of this month; the progress counts for everyone).
--   season   only on the pass's tab: the month's season, its three items (skin, flag, pet) and the
--            pass itself: its price and a button that opens Roblox's purchase, "PASS ACTIVE" once it
--            is on, "COMING SOON" while the game has no product for it (Data/MyProducts.pass).
--   list     one row a mission: what to do, how far it is (a bar and "2/3"), what it gives, and its
--            state: a tick when paid, a padlock when it is done but waits for the pass.
--   foot     how long until the day's missions change / the season ends.
-- Nothing here is claimed by hand: the server pays a mission when a match's result reaches its goal
-- (server/Purchases.add_stars), and the pass's receipt pays the monthly ones already done.
-- The numbers come from Session.missions_view (the inventory's copy of the state and the server's
-- clock); the mission's texts are the owner's, in Portuguese, drawn as they are.
-- Signals: closed.
local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local UICtx = require("./UICtx")
local HelpOverlay = require("./HelpOverlay")
local Prices = require("./Prices")
local Signal = UITheme.core("Signal")
local Products = UICtx.data("Products")
local Cosmetics = UICtx.data("Cosmetics")
local MissionData = UICtx.data("Missions")

local IS_ROBLOX = typeof(game) == "Instance"

local Missions = W.class(W.Control)

--- The tabs.
Missions.TABS = {
	{ key = "daily", title = "DAILY", icon = "clock" },
	{ key = "pass", title = "MONTHLY PASS", icon = "star" },
}
--- The list's width and the most it may be tall, logical px (phones: the screen decides the height).
Missions.WIDTH = 520
Missions.WIDTH_PHONE = 560
Missions.LIST_H = 330
Missions.LIST_MIN_H = 84
--- A message of the window's (a purchase that could not start...) stays this long, seconds.
Missions.SAY_S = 5
--- A purchase with no answer is forgotten after this long, seconds.
Missions.PENDING_S = 90
--- The foot's countdown is redrawn this often, seconds.
Missions.TICK_S = 1

local GOLD = Color3.fromRGB(236, 190, 92)
local KIND_NAME = { skin = "SKIN", flag = "FLAG", pet = "PET" }

--- The clock the window waits by (tests set their own).
function Missions.now(): number
	return os.clock()
end

--- A label's text exactly as given (the missions' texts and the season's names are the owner's, in
--- Portuguese already: the language layer must not read them).
local function set_verbatim(l: any, s: string)
	if s == l.text then
		return
	end
	l.text = s
	if l:_min_depends_on_text() then
		l:update_minimum_size()
	end
	l:_redraw()
end

local function color_of(hex: number): Color3
	return Color3.fromRGB((hex // 65536) % 256, (hex // 256) % 256, hex % 256)
end

--- An item's picture in a square of `px` (UIRoot gives `show_item`: the Locker's, which paints a
--- skin's pattern too).
function Missions._thumb(self, px: number): (any, any)
	local img = Instance.new("ImageLabel")
	img.Name = "Item"
	img.BackgroundTransparency = 1
	img.ScaleType = Enum.ScaleType.Fit
	local node = W.wrap(img)
	node:_part(img, "ImageTransparency", 1.0)
	node:set_min_size(Vector2.new(px, px))
	node:set_mouse_filter(W.MOUSE_IGNORE)
	node.size_flags_vertical = W.SHRINK_CENTER
	return node, img
end

function Missions._show(self, img: any, it: any)
	if self.show_item ~= nil then
		self.show_item(img, it)
	elseif it ~= nil and it.kind ~= "skin" then
		local image, x, y, w, h = Cosmetics.image_of(it)
		img.Image = image
		img.ImageRectOffset = Vector2.new(x, y)
		img.ImageRectSize = Vector2.new(w, h)
	end
end

function Missions.new(c: any)
	local self = setmetatable({}, Missions.__mt)
	W.Control._init(self)
	self.ctx = c
	self.closed = Signal.new()
	self.is_open = false
	self._tab = 1
	self._rows = {}
	--- a purchase of the pass under way: { since }
	self._pending = nil :: any
	--- the window's message: { text, color, until }
	self._said = nil :: any
	self._ticked = -math.huge
	self._day = nil :: number?
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self:set_mouse_filter(W.MOUSE_STOP)
	self:set_visible(false)
	self._dim = W.ColorRect.new(UITheme.rgba(0.0275, 0.0196, 0.0314, 0.8))
	self._dim:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self._dim.gui_input:Connect(function(e)
		if e.pressed and not self._panel:has_global_point(e.global_position) then
			self:close()
		end
	end)
	self:add_child(self._dim)
	self._panel = GlassPanel.new(22.0, 18.0, 16, true, 34)
	self._panel:set_tint(UITheme.rgba(0.075, 0.063, 0.071, 0.97))
	self._panel.border_color = UITheme.c(GOLD, 0.34)
	self:add_child(self._panel)
	local v = UITheme.vbox(10)
	self._v = v
	self._panel:add_child(v)

	-- head
	local head = UITheme.hbox(12)
	self._head = head
	local mark = UITheme.icon_rect("target", 26.0, GOLD)
	mark.size_flags_vertical = W.SHRINK_CENTER
	self._mark = mark
	head:add_child(mark)
	local tcol = UITheme.vbox(1)
	tcol.size_flags_vertical = W.SHRINK_CENTER
	tcol.size_flags_horizontal = W.EXPAND_FILL
	self._title = UITheme.label("MISSIONS", 22, 800, GOLD, 4)
	tcol:add_child(self._title)
	self._sub = UITheme.label("Reach a goal and its reward is yours at once.", 12, 600, UITheme.TEXT_2)
	tcol:add_child(self._sub)
	head:add_child(tcol)
	local close = W.Button.new("", "GhostButton")
	close:set_icon("close")
	close.expand_icon = true
	close:set_min_size(Vector2.new(34, 34))
	close:add_theme_constant_override("icon_max_width", 13)
	close:add_theme_stylebox_override("normal", UITheme.empty_box(8, 8))
	close:add_theme_stylebox_override("hover", UITheme.flat(UITheme.FILL, 8, UITheme.CLEAR, 0, 8, 8))
	close.size_flags_vertical = W.SHRINK_CENTER
	close.pressed:Connect(function()
		self:close()
	end)
	self._close_b = close
	head:add_child(close)
	v:add_child(head)

	-- tabs
	local tabs = UITheme.hbox(8)
	self._tab_row = tabs
	self._tabs = {}
	for i, t in ipairs(Missions.TABS) do
		local chip = UITheme.button(t.title, "ChipButton", t.icon, 38.0)
		chip.toggle_mode = true
		chip:set_font_size(13)
		chip.size_flags_horizontal = W.EXPAND_FILL
		chip:set_pressed_no_signal(i == self._tab)
		chip.pressed:Connect(function()
			self:_set_tab(i)
		end)
		table.insert(self._tabs, chip)
		tabs:add_child(chip)
	end
	v:add_child(tabs)

	-- the season and the pass (the pass's tab only)
	-- (a computer: the pass's button under the season's name and items, as wide as the panel; a
	-- phone, short and wide: beside them, in the same row. apply_layout moves it.)
	local season = W.Panel.new()
	season:set_mouse_filter(W.MOUSE_PASS)
	self._season = season
	local sv = UITheme.vbox(8)
	self._season_v = sv
	season:add_child(sv)
	local sh = UITheme.hbox(10)
	self._season_h = sh
	sv:add_child(sh)
	local scol = UITheme.vbox(1)
	scol.size_flags_horizontal = W.EXPAND_FILL
	scol.size_flags_vertical = W.SHRINK_CENTER
	self._season_when = UITheme.caption("", 10, UITheme.TEXT_2)
	self._season_when.clip_text = true
	self._season_when.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	scol:add_child(self._season_when)
	self._season_name = UITheme.label("", 17, 800, GOLD)
	self._season_name.clip_text = true
	self._season_name.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	scol:add_child(self._season_name)
	self._season_note = UITheme.label("Skin, flag and pet of this month only.", 11, 500, UITheme.TEXT_2)
	self._season_note.clip_text = true
	self._season_note.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	scol:add_child(self._season_note)
	sh:add_child(scol)
	self._season_items = {}
	for _, kind in Cosmetics.KINDS do
		local node, img = self:_thumb(40)
		self._season_items[kind] = { node = node, img = img }
		sh:add_child(node)
	end
	local buy = UITheme.button("", "PrimaryButton", "robux", 40.0)
	buy:set_font_size(13)
	buy.size_flags_vertical = W.SHRINK_CENTER
	buy.pressed:Connect(function()
		self:_buy_pressed()
	end)
	self._buy = buy
	self._buy_in = sv
	sv:add_child(buy)
	v:add_child(season)

	-- the list (it scrolls)
	local host = W.Control.new()
	host:set_mouse_filter(W.MOUSE_PASS)
	self._host = host
	v:add_child(host)
	local scroll = HelpOverlay.Scroll.new()
	scroll:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self._scroll = scroll
	host:add_child(scroll)
	local list_m = W.Margin.new()
	list_m:set_mouse_filter(W.MOUSE_IGNORE)
	list_m.size_flags_horizontal = W.EXPAND_FILL
	-- (room for the scroll bar)
	list_m:add_theme_constant_override("margin_right", 10)
	scroll:add_child(list_m)
	self._list = UITheme.vbox(6)
	self._list.size_flags_horizontal = W.EXPAND_FILL
	list_m:add_child(self._list)
	self._empty = UITheme.label("", 13, 600, UITheme.TEXT_2)
	self._empty:set_alignment(W.ALIGN_CENTER)
	self._empty:set_autowrap(true)
	self._empty:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self._empty.vertical_alignment = W.VALIGN_CENTER
	self._empty:set_visible(false)
	host:add_child(self._empty)

	-- foot: the countdown, or the window's message
	self._foot = UITheme.label("", 12, 600, UITheme.TEXT_2)
	self._foot:set_alignment(W.ALIGN_CENTER)
	self._foot:set_autowrap(true)
	v:add_child(self._foot)

	if IS_ROBLOX then
		game:GetService("MarketplaceService").PromptProductPurchaseFinished:Connect(function(_u, product_id, purchased)
			self:_on_prompt_done(product_id, purchased)
		end)
	end
	self:_connect(Prices.changed:Connect(function()
		if self.is_open then
			self:_refresh_pass()
		end
	end))
	return self
end

--- The session's inventory (UIRoot.setup, when the session exists).
function Missions.bind(self, s: any)
	if s == nil or self._bound == s then
		return
	end
	self._bound = s
	if s.inventory_changed then
		s.inventory_changed:Connect(function()
			local view = self:_view()
			if self._pending ~= nil and view ~= nil and view.pass then
				self._pending = nil
				self.ctx:sfx("open")
				self:_say("The pass is yours! Its rewards are being paid.", UITheme.GREEN)
			end
			if self.is_open then
				self:_rebuild()
			end
		end)
	end
end

--- What there is to draw now (Session.missions_view), or nil without a session.
function Missions._view(self): any
	local s = self.ctx.session
	if s == nil or type(s.missions_view) ~= "function" then
		return nil
	end
	return s:missions_view()
end

--- Whether the server's inventory has arrived (before it, the lists are of nobody).
function Missions._loaded(self): boolean
	local s = self.ctx.session
	return s ~= nil and type(s.inventory) == "table" and s.inventory.loaded == true
end

function Missions._say(self, text: string, color: any?)
	self._said = { text = text, color = color or UITheme.TEXT_2, ["until"] = Missions.now() + Missions.SAY_S }
	self:_refresh_foot()
end

-- ---------------------------------------------------------------------------------------------
-- The pass
-- ---------------------------------------------------------------------------------------------

function Missions._buy_pressed(self)
	local view = self:_view()
	if view == nil or view.pass or self._pending ~= nil then
		return
	end
	local p = Products[MissionData.PRODUCT]
	if not view.on_sale or p == nil or p.id == 0 or not IS_ROBLOX then
		self.ctx:sfx("deny", -4.0)
		self:_say("The pass isn't on sale yet.", UITheme.TEXT_2)
		return
	end
	self.ctx:sfx("confirm")
	self._pending = { since = Missions.now(), product = p.id }
	self:_refresh_pass()
	local ok = pcall(function()
		game:GetService("MarketplaceService"):PromptProductPurchase(game:GetService("Players").LocalPlayer, p.id)
	end)
	if not ok then
		self._pending = nil
		self:_say("Purchases aren't available right now.", UITheme.RED)
		self:_refresh_pass()
	end
end

--- Roblox's purchase window closed: bought (the inventory that follows turns the pass on) or not.
function Missions._on_prompt_done(self, product_id: any, purchased: any)
	local p = self._pending
	if p == nil or p.product ~= product_id then
		return
	end
	if purchased ~= true then
		self._pending = nil
	else
		p.since = Missions.now()
		p.paid = true
	end
	if self.is_open then
		self:_refresh_pass()
	end
end

--- The season's panel: its name and items, and the pass's button.
function Missions._refresh_pass(self)
	local view = self:_view()
	local on_tab = Missions.TABS[self._tab].key == "pass"
	self._season:set_visible(on_tab and view ~= nil)
	if view == nil or not on_tab then
		return
	end
	local compact = self.ctx.compact == true
	local season = view.season or {}
	local tone = color_of(tonumber(season.color) or 0xECBE5C)
	self._season:add_theme_stylebox_override("panel", UITheme.flat(UITheme.c(tone, 0.1), 12, UITheme.c(tone, 0.55), 1, if compact then 8.0 else 12.0, if compact then 5.0 else 9.0))
	-- (a phone has the pass's button in this row: only the month, the word would be cut)
	local when = string.upper(MissionData.month_name(view.month))
	set_verbatim(self._season_when, if compact then when else UITheme.tr("SEASON") .. " · " .. when)
	set_verbatim(self._season_name, tostring(season.name or ""))
	self._season_name:set_color(tone)
	for kind, t in self._season_items do
		self:_show(t.img, Cosmetics.item(season[kind]))
	end
	local buy = self._buy
	if view.pass then
		buy:set_icon("check")
		buy:set_text("PASS ACTIVE")
		buy:set_disabled(true)
	elseif not view.on_sale then
		buy:set_icon("lock")
		buy:set_text("COMING SOON")
		buy:set_disabled(true)
	elseif self._pending ~= nil then
		buy:set_icon("robux")
		buy:set_text("WAIT…")
		buy:set_disabled(true)
	else
		buy:set_icon("robux")
		buy:set_text(string.format("%s · BUY THE PASS", UICtx.commas(Prices.robux(MissionData.PRODUCT))))
		buy:set_disabled(false)
	end
end

-- ---------------------------------------------------------------------------------------------
-- The list
-- ---------------------------------------------------------------------------------------------

--- A mission's row. `locked`: done, but its reward waits for the pass.
function Missions._row(self, m: any, pass_tab: boolean, has_pass: boolean, compact: boolean): any
	local locked = pass_tab and m.done and not m.paid and not has_pass
	local tone = if m.paid then UITheme.GREEN elseif m.done then GOLD else nil
	local row = W.Panel.new()
	row:set_mouse_filter(W.MOUSE_IGNORE)
	row:add_theme_stylebox_override(
		"panel",
		UITheme.flat(
			if tone ~= nil then UITheme.c(tone, 0.08) else UITheme.rgba(1, 1, 1, 0.035),
			10,
			if tone ~= nil then UITheme.c(tone, 0.45) else UITheme.CLEAR,
			if tone ~= nil then 1 else 0,
			if compact then 8.0 else 10.0,
			if compact then 4.0 else 7.0
		)
	)
	local hb = UITheme.hbox(10)
	row:add_child(hb)
	-- what to do, and how far it is
	local col = UITheme.vbox(if compact then 2 else 4)
	col.size_flags_horizontal = W.EXPAND_FILL
	col.size_flags_vertical = W.SHRINK_CENTER
	local text = UITheme.label("", if compact then 12 else 14, 700, UITheme.TEXT)
	text.clip_text = true
	text.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	set_verbatim(text, tostring(m.text))
	col:add_child(text)
	local prog = UITheme.hbox(8)
	local bar = W.Control.new()
	bar:set_mouse_filter(W.MOUSE_IGNORE)
	bar:set_min_size(Vector2.new(40, 6))
	bar.size_flags_horizontal = W.EXPAND_FILL
	bar.size_flags_vertical = W.SHRINK_CENTER
	local back = W.Panel.new()
	back:set_mouse_filter(W.MOUSE_IGNORE)
	back:add_theme_stylebox_override("panel", UITheme.flat(UITheme.rgba(1, 1, 1, 0.1), 3, UITheme.CLEAR, 0, 0, 0))
	back:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	bar:add_child(back)
	local frac = if m.goal > 0 then math.clamp(m.have / m.goal, 0, 1) else 0
	local fill = W.Panel.new()
	fill:set_mouse_filter(W.MOUSE_IGNORE)
	fill:add_theme_stylebox_override("panel", UITheme.flat(UITheme.c(tone or GOLD, 0.95), 3, UITheme.CLEAR, 0, 0, 0))
	fill:set_anchors(0, 0, frac, 1)
	fill:set_offsets(0, 0, 0, 0)
	fill:set_visible(frac > 0)
	bar:add_child(fill)
	prog:add_child(bar)
	local count = UITheme.label("", 11, 700, UITheme.TEXT_2)
	set_verbatim(count, string.format("%s/%s", UICtx.commas(m.have), UICtx.commas(m.goal)))
	count.size_flags_vertical = W.SHRINK_CENTER
	prog:add_child(count)
	col:add_child(prog)
	hb:add_child(col)
	-- what it gives
	local it = if m.item ~= nil then Cosmetics.item(m.item) else nil
	local reward = UITheme.hbox(5)
	reward.size_flags_vertical = W.SHRINK_CENTER
	local thumb_img = nil
	if it ~= nil then
		local node, img = self:_thumb(if compact then 26 else 34)
		thumb_img = img
		self:_show(img, it)
		reward:add_child(node)
		local kind = UITheme.label(KIND_NAME[it.kind] or "", 11, 800, UITheme.TEXT)
		kind.size_flags_vertical = W.SHRINK_CENTER
		reward:add_child(kind)
	else
		local coin = UITheme.icon_rect("star", if compact then 14 else 16, GOLD)
		coin.size_flags_vertical = W.SHRINK_CENTER
		reward:add_child(coin)
		local amount = UITheme.label("", if compact then 13 else 15, 800, GOLD)
		set_verbatim(amount, "+" .. UICtx.commas(m.stars))
		amount.size_flags_vertical = W.SHRINK_CENTER
		reward:add_child(amount)
	end
	hb:add_child(reward)
	-- its state
	local state = UITheme.icon_rect(if m.paid then "check" elseif locked then "lock" else "check", 16, if m.paid then UITheme.GREEN else GOLD)
	state.size_flags_vertical = W.SHRINK_CENTER
	state:set_modulate_a(if m.paid or locked then 1.0 else 0.0)
	hb:add_child(state)
	return { node = row, mission = m, text = text, count = count, fill = fill, frac = frac, locked = locked, state = state, item = it, img = thumb_img }
end

--- The rows of the tab in view, the season's panel and the foot.
function Missions._rebuild(self)
	for _, ch in ipairs(self._list:get_children()) do
		self._list:remove_child(ch)
		ch:queue_free()
	end
	table.clear(self._rows)
	local compact = self.ctx.compact == true
	local view = self:_view()
	local pass_tab = Missions.TABS[self._tab].key == "pass"
	self._day = if view ~= nil then view.day else nil
	local text = ""
	if view == nil then
		text = "Couldn't load the missions. Try again in a moment."
	elseif not self:_loaded() then
		text = "Loading the missions…"
	else
		for _, m in (if pass_tab then view.monthly else view.daily) do
			local row = self:_row(m, pass_tab, view.pass == true, compact)
			table.insert(self._rows, row)
			self._list:add_child(row.node)
		end
		if #self._rows == 0 then
			text = "No missions today."
		end
	end
	self._empty:set_text(text)
	self._empty:set_visible(text ~= "")
	self:_refresh_pass()
	self:_refresh_foot()
	self._scroll:queue_sort()
end

--- The foot: the window's message while it lasts, else how long the day / the season still has.
function Missions._refresh_foot(self)
	local said = self._said
	if said ~= nil and Missions.now() < said["until"] then
		self._foot:set_color(said.color)
		self._foot:set_text(said.text)
		return
	end
	self._said = nil
	self._foot:set_color(UITheme.TEXT_2)
	local view = self:_view()
	if view == nil or not self:_loaded() then
		self._foot:set_text("")
		return
	end
	if Missions.TABS[self._tab].key == "pass" then
		local left = MissionData.span(view.month_left)
		if view.pass then
			self._foot:set_text(string.format("Your pass lasts %s more. On the 1st a new season starts.", left))
		else
			self._foot:set_text(string.format("The season ends in %s. Your progress already counts: buy the pass and receive what you have completed.", left))
		end
	else
		self._foot:set_text(string.format("New missions in %s. They are free for everyone.", MissionData.span(view.day_left)))
	end
end

function Missions._set_tab(self, i: number)
	self._tab = i
	for j, ch in ipairs(self._tabs) do
		ch:set_pressed_no_signal(j == i)
	end
	self:apply_layout();
	(self._scroll.gui :: any).CanvasPosition = Vector2.zero
	self.ctx:sfx("click")
end

--- Every frame while open (UIRoot): the countdown, the day that turns, a purchase that never answered.
function Missions.tick(self)
	if not self.is_open then
		return
	end
	local t = Missions.now()
	if t - self._ticked < Missions.TICK_S then
		return
	end
	self._ticked = t
	if self._pending ~= nil and t - self._pending.since > Missions.PENDING_S then
		self._pending = nil
		self:_refresh_pass()
	end
	local view = self:_view()
	if view ~= nil and view.day ~= self._day then
		self:_rebuild() -- (midnight passed with the window open: the new day's missions)
	else
		self:_refresh_foot()
	end
end

-- ---------------------------------------------------------------------------------------------
-- Open / close / layout
-- ---------------------------------------------------------------------------------------------

--- Opens on `tab` ("daily" | "pass"; nil: the one last seen).
function Missions.open(self, tab: string?)
	if self.is_open then
		return
	end
	self.is_open = true
	for i, t in ipairs(Missions.TABS) do
		if t.key == tab then
			self._tab = i
		end
	end
	for j, ch in ipairs(self._tabs) do
		ch:set_pressed_no_signal(j == self._tab)
	end
	self._said = nil
	self._ticked = Missions.now()
	pcall(Prices.fetch_keys, { MissionData.PRODUCT })
	self:set_visible(true)
	self:apply_layout();
	(self._scroll.gui :: any).CanvasPosition = Vector2.zero
	self._panel:set_modulate_a(1.0)
	self._dim:set_modulate_a(0.0)
	W.fade(self._dim, 1.0, 0.2)
	UICtx.pop_in(self._panel, 0.0, 0.94, 0.3)
	self.ctx:sfx("open")
end

function Missions.close(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	self.ctx:sfx("close")
	local t = self:create_tween():set_parallel(true)
	t:tween_property(self._dim, "modulate:a", 0.0, 0.15)
	t:tween_property(self._panel, "modulate:a", 0.0, 0.15)
	t:chain():tween_callback(function()
		if not self.is_open then
			self:set_visible(false)
		end
	end)
	self.closed:Fire()
end

function Missions.apply_layout(self)
	local compact = self.ctx.compact == true
	local area = self.ctx:clear_rect()
	local pad_h = if compact then 12 else 22
	local pad_v = if compact then 8 else 18
	self._panel:set_padding(pad_h, pad_v, pad_h, pad_v)
	self._v:set_separation(if compact then 5 else 10)
	self._title:set_font_size(if compact then 15 else 22)
	self._mark:set_min_size(if compact then Vector2.new(20, 20) else Vector2.new(26, 26))
	-- (a phone held sideways is short: the list gets the room of everything that can go)
	self._sub:set_visible(not compact)
	self._season_note:set_visible(not compact)
	self._season_name:set_font_size(if compact then 13 else 17)
	self._season_h:set_separation(if compact then 6 else 10)
	for _, t in self._season_items do
		t.node:set_min_size(if compact then Vector2.new(26, 26) else Vector2.new(40, 40))
	end
	self._buy:set_min_size(Vector2.new(0, if compact then 30 else 38))
	self._buy:set_font_size(if compact then 11 else 13)
	local buy_in = if compact then self._season_h else self._season_v
	if self._buy_in ~= buy_in then
		self._buy_in:remove_child(self._buy)
		buy_in:add_child(self._buy)
		self._buy_in = buy_in
	end
	self._season_v:set_separation(if compact then 4 else 8)
	self._foot:set_font_size(if compact then 10 else 12)
	for _, ch in ipairs(self._tabs) do
		ch:set_min_size(Vector2.new(0, if compact then 30 else 38))
		ch:set_font_size(if compact then 12 else 13)
	end
	local width = math.min(if compact then Missions.WIDTH_PHONE else Missions.WIDTH, area.Width - 2 * pad_h - 16)
	self._foot:set_min_size(Vector2.new(width, 0))
	if self.is_open then
		self:_rebuild()
	end
	-- the list takes what the screen has left under the rest of the window, and no more than its rows
	self._host:set_min_size(Vector2.new(width, 0))
	local chrome = self._panel:get_combined_minimum_size().Y
	local room = area.Height - 8.0 - chrome
	-- (a pixel or two more than its rows: sizes are rounded to whole pixels on the way to the screen)
	local want = self._list:get_combined_minimum_size().Y + 3
	if want <= 3 then
		want = Missions.LIST_MIN_H
	end
	local most = math.min(Missions.LIST_H, want)
	self._host:set_min_size(Vector2.new(width, math.max(math.min(math.floor(room), most), math.min(Missions.LIST_MIN_H, most))))
	self:_center()
end

function Missions._center(self)
	local area = self.ctx:clear_rect()
	local pn = self._panel
	local sz = pn:get_combined_minimum_size()
	local p = area.Min + (Vector2.new(area.Width, area.Height) - sz) * 0.5
	local y = math.max(p.Y, area.Min.Y + 4.0)
	local rp = Vector2.new(math.floor(p.X + 0.5), math.floor(y + 0.5))
	pn:set_offsets(rp.X, rp.Y, rp.X, rp.Y)
	pn:reset_size()
end

return Missions
