--!nonstrict
-- The owner's panel (2026-11-12): one wide window with everything the game's owner sets while the
-- game runs, behind a button of the lobby that only a game admin sees (UICtx.admin: the AF_Admin
-- attribute, which only the server sets; TitleScreen).
--   head     the name, the three pages' chips, close.
--   COROAS   a player (name on this server, "eu", or a numeric id) and an amount: GIVE | TAKE | SEE.
--   CODES    a new code (name or none for a random one, Coroas, validity, uses) and the list of the
--            codes there are, each with ON / OFF and DELETE (the place's own, server/MyCodes, are
--            listed without buttons: they change in Studio).
--   RANKING  a player out of the ranking: by name or id in the field, or with the button on their
--            row of the list (the lists Session.rank already has; the id is shown beside the name).
--   status   under the page: what the server answered, in the owner's language, as it wrote it.
-- A button that can't be undone (DELETE, REMOVE) asks for a second press.
--
-- SECURITY: nothing here is trusted. Every button only sends a request (Session.admin, OP.ADMIN);
-- the server asks who the sender is for each one (ServerMain: admins[player]; server/AdminActions)
-- and refuses anyone else, so a player who forces this window open sees an empty list and gets a
-- refusal for whatever they press.
-- Signals: closed.
local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local UICtx = require("./UICtx")
local HelpOverlay = require("./HelpOverlay")
local Signal = UITheme.core("Signal")

local GOLD = Color3.fromRGB(236, 190, 92)
local FONT = Font.fromId(UITheme.FONT_ID, Enum.FontWeight.Bold)

local AdminPanel = W.class(W.Control)

--- The pages: the key, the chip's text and its icon.
AdminPanel.PAGES = {
	{ key = "coins", title = "STARS", icon = "star" },
	{ key = "codes", title = "CODES", icon = "donate" },
	{ key = "rank", title = "RANKING", icon = "leaderboard" },
}
--- The ranking page's lists (Session.rank.boards) and their chips.
AdminPanel.BOARDS = {
	{ key = "wins", title = "VICTORIES" },
	{ key = "kills", title = "KINGDOMS" },
	{ key = "wins_w", title = "VICTORIES · WEEK" },
	{ key = "kills_w", title = "KINGDOMS · WEEK" },
}
--- The window's width, logical px (never wider than the screen leaves), and the most its lists are tall.
AdminPanel.WIDTH = 880
AdminPanel.LIST_H = 330
AdminPanel.LIST_MIN_H = 84
--- A list row's height (phones: ROW_PHONE).
AdminPanel.ROW = 40
AdminPanel.ROW_PHONE = 34
--- A field's height (phones: FIELD_PHONE).
AdminPanel.FIELD = 42
AdminPanel.FIELD_PHONE = 36
--- Seconds a DELETE / REMOVE button waits for its second press.
AdminPanel.ARM_S = 4
--- Seconds the window waits for the server's answer before it says none came.
AdminPanel.WAIT_S = 12
--- The most rows of a ranking list the page draws.
AdminPanel.RANK_ROWS = 100

--- (tests replace it)
function AdminPanel.now(): number
	return os.clock()
end

--- A label's text exactly as given (the server's answers and the players' names are not for the
--- language layer to read).
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
AdminPanel.set_verbatim = set_verbatim

local function set_variation(b: any, variation: string)
	if b.theme_type_variation ~= variation then
		b.theme_type_variation = variation
		b:_theme_changed()
		b:_restyle_label()
	end
end

-- =============================================================================================
-- Field (one line of typed text)
-- =============================================================================================

--- A text field: a rounded ground with a TextBox on it. `entered` when Enter is pressed in it.
local Field = W.class(W.Control)
AdminPanel.Field = Field
--- Logical px: the text's inset at each side.
Field.PAD = 12.0

--- What a typed text may hold: one line, no control characters, at most `max` characters.
function Field.clean(text: any, max: number): string
	if type(text) ~= "string" then
		return ""
	end
	local s = string.gsub(text, "[%c\127]", "")
	local n = utf8.len(s)
	if n == nil then
		return ""
	end
	if n > max then
		s = string.sub(s, 1, (utf8.offset(s, max + 1) or (#s + 1)) - 1)
	end
	return s
end

function Field.new(hint: string, max_len: number?)
	local self = setmetatable({}, Field.__mt)
	W.Control._init(self)
	self.gui.Name = "AdminField"
	self.entered = Signal.new()
	self.max_len = max_len or 40
	self:set_min_size(Vector2.new(80, AdminPanel.FIELD))
	self:set_mouse_filter(W.MOUSE_STOP)
	local g = self.gui
	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.BorderSizePixel = 0
	bg.BackgroundColor3 = Color3.fromRGB(30, 27, 31)
	bg.Size = UDim2.fromScale(1, 1)
	bg.ZIndex = 4
	bg.Parent = g
	self._corner = Instance.new("UICorner")
	self._corner.Parent = bg
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = bg
	self._stroke = stroke
	self:_part(bg, "BackgroundTransparency", 1.0)
	self:_part(stroke, "Transparency", 0.22)
	local box = Instance.new("TextBox")
	box.Name = "Text"
	box.BackgroundTransparency = 1
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.MultiLine = false
	box.Text = ""
	-- (in the interface's language here, so the sweep of raw texts has nothing left to do)
	box.PlaceholderText = UITheme.tr(hint)
	box.PlaceholderColor3 = UITheme.color3(UITheme.to_rgba(UITheme.TEXT_3))
	box.TextColor3 = UITheme.color3(UITheme.to_rgba(UITheme.TEXT))
	box.FontFace = FONT
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Center
	box.TextTruncate = Enum.TextTruncate.AtEnd
	box.ClipsDescendants = true
	box.ZIndex = 12
	box.Parent = g
	self:_part(box, "TextTransparency", 1.0)
	self._box = box
	self:_connect(box:GetPropertyChangedSignal("Text"):Connect(function()
		local want = Field.clean(box.Text, self.max_len)
		if want ~= box.Text then
			box.Text = want
		end
	end))
	self:_connect(box.Focused:Connect(function()
		self:_part(stroke, "Transparency", 0.6)
	end))
	self:_connect(box.FocusLost:Connect(function(enter: boolean)
		self:_part(stroke, "Transparency", 0.22)
		if enter then
			self.entered:Fire(self:text())
		end
	end))
	self:_draw_field()
	return self
end

--- What is typed, without spaces at the ends.
function Field.text(self): string
	local s = Field.clean(self._box.Text, self.max_len)
	return (string.gsub(string.gsub(s, "^%s+", ""), "%s+$", ""))
end

function Field.set_text(self, s: string)
	self._box.Text = Field.clean(s, self.max_len)
end

function Field.clear(self)
	self._box.Text = ""
end

function Field._on_geometry(self)
	self:_draw_field()
end

function Field._draw(self)
	self:_draw_field()
end

-- (raw instances in px: logical px x UITheme.scale)
function Field._draw_field(self)
	local sc = UITheme.scale
	local function px(v: number): number
		return math.floor(v * sc + 0.5)
	end
	self._corner.CornerRadius = UDim.new(0, px(9))
	self._stroke.Thickness = math.max(1, px(1))
	self._box.Position = UDim2.fromOffset(px(Field.PAD), 0)
	self._box.Size = UDim2.new(1, -px(Field.PAD * 2), 1, 0)
	self._box.TextSize = math.max(px(14), 8)
end

-- =============================================================================================
-- the window
-- =============================================================================================

local function caption(text: string): any
	local l = UITheme.caption(text, 10, UITheme.TEXT_3)
	return l
end

--- A field under its caption.
local function labelled(text: string, field: any, width: number?): any
	local col = UITheme.vbox(3)
	if width ~= nil then
		col:set_min_size(Vector2.new(width, 0))
	else
		col.size_flags_horizontal = W.EXPAND_FILL
	end
	local cap = caption(text)
	col:add_child(cap)
	col:add_child(field)
	return col, cap
end

function AdminPanel.new(c: any)
	local self = setmetatable({}, AdminPanel.__mt)
	W.Control._init(self)
	self.ctx = c
	self.closed = Signal.new()
	self.is_open = false
	self._page = 1
	self._board = 1
	--- the codes as the server last listed them (nil: never answered)
	self._codes = nil :: { any }?
	self._codes_read = true
	--- AdminPanel.now() when a request went out and its answer is still to come
	self._waiting = nil :: number?
	--- the DELETE / REMOVE button waiting for its second press: { button, text, at, variation }
	self._armed = nil :: any
	self._captions = {}
	self._fields = {}
	self._code_rows = {}
	self._rank_rows = {}
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
	local v = UITheme.vbox(12)
	self._v = v
	self._panel:add_child(v)

	-- head
	local head = UITheme.hbox(12)
	local shield = UITheme.icon_rect("settings", 26.0, GOLD)
	shield.size_flags_vertical = W.SHRINK_CENTER
	self._shield = shield
	head:add_child(shield)
	local tcol = UITheme.vbox(1)
	tcol.size_flags_vertical = W.SHRINK_CENTER
	tcol.size_flags_horizontal = W.EXPAND_FILL
	self._title = UITheme.label("OWNER PANEL", 22, 800, GOLD, 3)
	tcol:add_child(self._title)
	self._sub = UITheme.label("Only the game's owner sees this. The server checks every action.", 12, 600, UITheme.TEXT_2)
	tcol:add_child(self._sub)
	head:add_child(tcol)
	local chips = UITheme.hbox(6)
	chips.size_flags_vertical = W.SHRINK_CENTER
	self._chips = {}
	for i, p in ipairs(AdminPanel.PAGES) do
		local chip = UITheme.button(p.title, "ChipButton", p.icon, 36.0)
		chip.toggle_mode = true
		chip:set_font_size(13)
		chip:add_theme_constant_override("icon_max_width", 15)
		chip:set_pressed_no_signal(i == self._page)
		chip.pressed:Connect(function()
			self:_set_page(i)
		end)
		table.insert(self._chips, chip)
		chips:add_child(chip)
	end
	head:add_child(chips)
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

	self._pages = { self:_build_coins(), self:_build_codes(), self:_build_rank() }
	for i, page in ipairs(self._pages) do
		page:set_visible(i == self._page)
		v:add_child(page)
	end

	-- what the server answered
	local status = W.Panel.new()
	status:set_mouse_filter(W.MOUSE_IGNORE)
	status:add_theme_stylebox_override("panel", UITheme.flat(UITheme.rgba(1, 1, 1, 0.04), 9, UITheme.CLEAR, 0, 10.0, 6.0))
	self._status_l = UITheme.label("", 13, 700, UITheme.TEXT_2)
	self._status_l:set_autowrap(true)
	status:add_child(self._status_l)
	self._status = status
	v:add_child(status)
	self:_say("Choose what to do. Nothing changes until you press a button.", nil, true)
	return self
end

-- ---------------------------------------------------------------------------------------------
-- the pages
-- ---------------------------------------------------------------------------------------------

function AdminPanel._field(self, hint: string, max_len: number): any
	local f = Field.new(hint, max_len)
	table.insert(self._fields, f)
	return f
end

function AdminPanel._labelled(self, text: string, field: any, width: number?): any
	local col, cap = labelled(text, field, width)
	table.insert(self._captions, cap)
	return col
end

function AdminPanel._build_coins(self): any
	local page = UITheme.vbox(10)
	local row = UITheme.hbox(10)
	self._coin_who = self:_field('Name, "eu" or numeric ID', 40)
	row:add_child(self:_labelled("PLAYER", self._coin_who))
	self._coin_amount = self:_field("5000 or 20k", 14)
	row:add_child(self:_labelled("AMOUNT", self._coin_amount, 190))
	page:add_child(row)
	local buttons = UITheme.hbox(10)
	local function action(text: string, variation: string, op: string): any
		local b = UITheme.button(text, variation, nil, 42.0)
		b:set_font_size(14)
		b.size_flags_horizontal = W.EXPAND_FILL
		b.pressed:Connect(function()
			self:_send("coins", { op = op, who = self._coin_who:text(), amount = self._coin_amount:text() })
		end)
		buttons:add_child(b)
		return b
	end
	self._coin_give = action("GIVE", "PrimaryButton", "give")
	self._coin_take = action("TAKE", "DangerButton", "take")
	self._coin_see = action("SEE BALANCE", "GlassButton", "see")
	page:add_child(buttons)
	self._coin_note = UITheme.label(
		"By name: only players on this server. By numeric ID: any account, even offline.",
		12,
		500,
		UITheme.TEXT_3
	)
	self._coin_note:set_autowrap(true)
	page:add_child(self._coin_note)
	return page
end

function AdminPanel._build_codes(self): any
	local page = UITheme.vbox(8)
	local row = UITheme.hbox(8)
	self._code_name = self:_field("Empty = random", 24)
	row:add_child(self:_labelled("CODE", self._code_name))
	self._code_stars = self:_field("5000", 14)
	row:add_child(self:_labelled("STARS", self._code_stars, 110))
	self._code_valid = self:_field("7d or 31/12/2026", 12)
	row:add_child(self:_labelled("VALID FOR", self._code_valid, 150))
	self._code_uses = self:_field("No limit", 9)
	row:add_child(self:_labelled("USES", self._code_uses, 100))
	local create = UITheme.button("CREATE", "PrimaryButton", nil, AdminPanel.FIELD)
	create:set_font_size(14)
	create:set_min_size(Vector2.new(110, AdminPanel.FIELD))
	create.size_flags_vertical = W.SHRINK_END
	create.pressed:Connect(function()
		self:_send("code_new", {
			code = self._code_name:text(),
			stars = self._code_stars:text(),
			valid = self._code_valid:text(),
			uses = self._code_uses:text(),
		})
	end)
	self._code_create = create
	row:add_child(create)
	page:add_child(row)
	local host, list, empty = self:_list_host()
	self._code_host, self._code_list, self._code_empty = host, list, empty
	page:add_child(host)
	return page
end

function AdminPanel._build_rank(self): any
	local page = UITheme.vbox(8)
	local row = UITheme.hbox(8)
	self._rank_who = self:_field("Name or numeric ID", 40)
	row:add_child(self:_labelled("PLAYER", self._rank_who))
	local remove = UITheme.button("REMOVE FROM RANKING", "DangerButton", nil, AdminPanel.FIELD)
	remove:set_font_size(13)
	remove:set_min_size(Vector2.new(210, AdminPanel.FIELD))
	remove.size_flags_vertical = W.SHRINK_END
	remove.pressed:Connect(function()
		local who = self._rank_who:text()
		if who == "" then
			self:_say("Type the player's name or numeric ID.", false, true)
			return
		end
		if self:_arm(remove, "REMOVE FROM RANKING") then
			self:_send("rank_remove", { who = who })
		end
	end)
	self._rank_remove = remove
	row:add_child(remove)
	page:add_child(row)
	local boards = UITheme.hbox(6)
	self._board_chips = {}
	for i, b in ipairs(AdminPanel.BOARDS) do
		local chip = UITheme.button(b.title, "ChipButton", nil, 32.0)
		chip.toggle_mode = true
		chip:set_font_size(12)
		chip.size_flags_horizontal = W.EXPAND_FILL
		chip:set_pressed_no_signal(i == self._board)
		chip.pressed:Connect(function()
			self._board = i
			for j, ch in ipairs(self._board_chips) do
				ch:set_pressed_no_signal(j == i)
			end
			self:_rebuild_rank()
			self._rank_scroll.gui.CanvasPosition = Vector2.zero
		end)
		table.insert(self._board_chips, chip)
		boards:add_child(chip)
	end
	self._board_row = boards
	page:add_child(boards)
	local host, list, empty, scroll = self:_list_host()
	self._rank_host, self._rank_list, self._rank_empty, self._rank_scroll = host, list, empty, scroll
	page:add_child(host)
	return page
end

--- A list that scrolls, and over it what there is to say when it has no rows.
function AdminPanel._list_host(_self): (any, any, any, any)
	local host = W.Control.new()
	host:set_mouse_filter(W.MOUSE_PASS)
	local scroll = HelpOverlay.Scroll.new()
	scroll:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	host:add_child(scroll)
	local m = W.Margin.new()
	m:set_mouse_filter(W.MOUSE_IGNORE)
	m.size_flags_horizontal = W.EXPAND_FILL
	-- (room for the scroll bar, so it never covers a button)
	m:add_theme_constant_override("margin_right", 10)
	scroll:add_child(m)
	local list = UITheme.vbox(4)
	list.size_flags_horizontal = W.EXPAND_FILL
	m:add_child(list)
	local empty = UITheme.label("", 13, 600, UITheme.TEXT_2)
	empty:set_alignment(W.ALIGN_CENTER)
	empty:set_autowrap(true)
	empty:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	empty.vertical_alignment = W.VALIGN_CENTER
	empty:set_visible(false)
	host:add_child(empty)
	return host, list, empty, scroll
end

local function row_panel(h: number, compact: boolean): (any, any)
	local row = W.Panel.new()
	row:set_mouse_filter(W.MOUSE_PASS)
	row:add_theme_stylebox_override(
		"panel",
		UITheme.flat(UITheme.rgba(1, 1, 1, 0.035), 9, UITheme.CLEAR, 0, 8.0, if compact then 2.0 else 4.0)
	)
	row:set_min_size(Vector2.new(0, h))
	local hb = UITheme.hbox(8)
	row:add_child(hb)
	return row, hb
end

local function small_button(text: string, variation: string, compact: boolean, width: number): any
	local h = if compact then 26.0 else 30.0
	local b = UITheme.button(text, variation, nil, h)
	b:set_font_size(if compact then 11 else 12)
	b:set_min_size(Vector2.new(width, h))
	b.size_flags_vertical = W.SHRINK_CENTER
	return b
end

local function clear_list(list: any)
	for _, ch in ipairs(list:get_children()) do
		list:remove_child(ch)
		ch:queue_free()
	end
end

--- The codes' list, from what the server last sent.
function AdminPanel._rebuild_codes(self)
	self:_disarm()
	clear_list(self._code_list)
	table.clear(self._code_rows)
	local compact = self.ctx.compact == true
	local h = if compact then AdminPanel.ROW_PHONE else AdminPanel.ROW
	local codes = self._codes
	for _, e in ipairs(codes or {}) do
		local row, hb = row_panel(h, compact)
		local name = UITheme.label("", if compact then 13 else 14, 800, if e.on then GOLD else UITheme.TEXT_3)
		set_verbatim(name, e.code)
		UITheme.fix_width(name, if compact then 118 else 150, W.ALIGN_LEFT, false)
		name.size_flags_vertical = W.SHRINK_CENTER
		hb:add_child(name)
		local info = UITheme.label("", if compact then 11 else 12, 600, UITheme.TEXT_2)
		set_verbatim(info, e.info)
		info.clip_text = true
		info.text_overrun_behavior = W.OVERRUN_ELLIPSIS
		info.size_flags_horizontal = W.EXPAND_FILL
		info.size_flags_vertical = W.SHRINK_CENTER
		hb:add_child(info)
		local live = e.state == "ligado"
		local state = UITheme.label("", 11, 800, if live then UITheme.GREEN else UITheme.RED)
		set_verbatim(state, string.upper(e.state))
		state.size_flags_vertical = W.SHRINK_CENTER
		hb:add_child(state)
		local rec = { node = row, code = e.code, on = e.on, fixed = e.fixed, name = name, info = info, state = state }
		if e.fixed then
			-- the place's own list: changed in Studio, not here
			local fixed = UITheme.label("STUDIO LIST", 11, 700, UITheme.TEXT_3)
			fixed:set_alignment(W.ALIGN_CENTER)
			fixed:set_min_size(Vector2.new(if compact then 164 else 190, 0))
			fixed.size_flags_vertical = W.SHRINK_CENTER
			hb:add_child(fixed)
		else
			local toggle = small_button(if e.on then "TURN OFF" else "TURN ON", "GlassButton", compact, if compact then 84 else 98)
			toggle.pressed:Connect(function()
				self:_send("code_switch", { code = e.code, on = not e.on })
			end)
			hb:add_child(toggle)
			local delete = small_button("DELETE", "DangerButton", compact, if compact then 72 else 84)
			delete.pressed:Connect(function()
				if self:_arm(delete, "DELETE") then
					self:_send("code_remove", { code = e.code })
				end
			end)
			hb:add_child(delete)
			rec.toggle, rec.delete = toggle, delete
		end
		table.insert(self._code_rows, rec)
		self._code_list:add_child(row)
	end
	local text = ""
	if codes == nil then
		text = if self._waiting ~= nil then "Loading the codes…" else "The codes could not be loaded. Close and open the panel again."
	elseif #codes == 0 then
		text = "No codes yet. Fill in the fields above and press CREATE."
	end
	self._code_empty:set_text(text)
	self._code_empty:set_visible(text ~= "")
end

--- The ranking page's list: the board in view, with each player's id and a REMOVE button.
function AdminPanel._rebuild_rank(self)
	self:_disarm()
	clear_list(self._rank_list)
	table.clear(self._rank_rows)
	local compact = self.ctx.compact == true
	local h = if compact then AdminPanel.ROW_PHONE else AdminPanel.ROW
	local s = self.ctx.session
	local data = if s ~= nil then s.rank else nil
	local board = AdminPanel.BOARDS[self._board].key
	local rows = if type(data) == "table" and type(data.boards) == "table" then data.boards[board] else nil
	local n = if type(rows) == "table" then math.min(#rows, AdminPanel.RANK_ROWS) else 0
	for i = 1, n do
		local r = rows[i]
		local uid, pname, value = tonumber(r[1]) or 0, tostring(r[2] or ""), tonumber(r[3]) or 0
		local row, hb = row_panel(h, compact)
		local place = UITheme.label(tostring(i), 13, 800, UITheme.TEXT_2)
		UITheme.fix_width(place, 30, W.ALIGN_CENTER, false)
		place.size_flags_vertical = W.SHRINK_CENTER
		hb:add_child(place)
		local name = UITheme.label("", if compact then 13 else 14, 700, UITheme.TEXT)
		set_verbatim(name, if pname ~= "" then pname else "?")
		name.clip_text = true
		name.text_overrun_behavior = W.OVERRUN_ELLIPSIS
		name.size_flags_horizontal = W.EXPAND_FILL
		name.size_flags_vertical = W.SHRINK_CENTER
		hb:add_child(name)
		local id = UITheme.label("", 11, 600, UITheme.TEXT_3)
		set_verbatim(id, "ID " .. string.format("%d", uid))
		id.size_flags_vertical = W.SHRINK_CENTER
		hb:add_child(id)
		local val = UITheme.label("", if compact then 13 else 14, 800, UITheme.TEXT)
		set_verbatim(val, UICtx.commas(value))
		UITheme.fix_width(val, 64, W.ALIGN_RIGHT, false)
		val.size_flags_vertical = W.SHRINK_CENTER
		hb:add_child(val)
		local remove = small_button("REMOVE", "DangerButton", compact, if compact then 78 else 90)
		remove.pressed:Connect(function()
			if self:_arm(remove, "REMOVE") then
				self:_send("rank_remove", { who = string.format("%d", uid) })
			end
		end)
		hb:add_child(remove)
		table.insert(self._rank_rows, { node = row, uid = uid, name = name, id = id, value = val, remove = remove })
		self._rank_list:add_child(row)
	end
	local text = ""
	if type(data) ~= "table" then
		text = "Loading the ranking…"
	elseif n == 0 then
		text = "Nobody on this list yet."
	end
	self._rank_empty:set_text(text)
	self._rank_empty:set_visible(text ~= "")
end

-- ---------------------------------------------------------------------------------------------
-- asking and answering
-- ---------------------------------------------------------------------------------------------

--- The status line. `good`: true green, false red, nil plain. `translate`: the text is the code's
--- own (English, for the language layer); otherwise it is the server's, drawn as it came.
function AdminPanel._say(self, text: string, good: boolean?, translate: boolean?)
	local l = self._status_l
	l:set_color(if good == true then UITheme.GREEN elseif good == false then UITheme.RED else UITheme.TEXT_2)
	if translate then
		l:set_text(text)
	else
		set_verbatim(l, text)
	end
	self._said = text
	self._said_good = good
	if self.is_open then
		self:_center()
	end
end

--- A button that can't be undone: true on its second press within ARM_S (the first one only asks).
function AdminPanel._arm(self, b: any, text: string): boolean
	local a = self._armed
	if a ~= nil and a.button == b and AdminPanel.now() - a.at <= AdminPanel.ARM_S then
		self:_disarm()
		return true
	end
	self:_disarm()
	self._armed = { button = b, text = text, at = AdminPanel.now() }
	b:set_text("SURE? PRESS AGAIN")
	return false
end

function AdminPanel._disarm(self)
	local a = self._armed
	if a ~= nil then
		self._armed = nil
		if a.button.gui ~= nil and a.button.gui.Parent ~= nil then
			a.button:set_text(a.text)
		end
	end
end

--- Sends one request. One at a time: the buttons wait for the answer.
function AdminPanel._send(self, action: string, args: { [string]: any }?): boolean
	if self._waiting ~= nil then
		return false
	end
	local s = self.ctx.session
	if s == nil or type(s.admin) ~= "function" or not s:admin(action, args) then
		self:_say("There is no server here: the panel works in the published game and in a Studio playtest.", false, true)
		return false
	end
	self._waiting = AdminPanel.now()
	self._sent = action
	if action ~= "state" then
		self:_say("Sending…", nil, true)
	end
	self:_set_busy(true)
	return true
end

function AdminPanel._set_busy(self, on: boolean)
	for _, b in ipairs({ self._coin_give, self._coin_take, self._coin_see, self._code_create, self._rank_remove }) do
		b:set_disabled(on)
	end
	for _, r in ipairs(self._code_rows) do
		if r.toggle ~= nil then
			r.toggle:set_disabled(on)
			r.delete:set_disabled(on)
		end
	end
	for _, r in ipairs(self._rank_rows) do
		r.remove:set_disabled(on)
	end
end

--- The server's answer (Session.admin_result).
function AdminPanel._on_result(self, r: any)
	if type(r) ~= "table" then
		return
	end
	self._waiting = nil
	self:_disarm()
	if r.codes ~= nil then
		self._codes = r.codes
		self._codes_read = r.codes_read ~= false
	end
	if r.text ~= "" then
		self:_say(r.text, r.ok == true)
	elseif r.action == "state" and not self._codes_read then
		self:_say("Roblox's storage did not answer: some codes may be missing from the list.", false, true)
	end
	if r.ok and r.action == "coins" then
		self._coin_amount:clear()
	elseif r.ok and r.action == "code_new" then
		self._code_name:clear()
	elseif r.action == "rank_remove" and r.uid ~= nil then
		-- out of the lists this screen has, at once; and the server is asked for its own again
		local s = self.ctx.session
		local data = if s ~= nil then s.rank else nil
		if type(data) == "table" and type(data.boards) == "table" then
			for _, rows in data.boards do
				if type(rows) == "table" then
					for i = #rows, 1, -1 do
						if type(rows[i]) == "table" and rows[i][1] == r.uid then
							table.remove(rows, i)
						end
					end
				end
			end
		end
		if r.ok then
			self._rank_who:clear()
		end
		if s ~= nil and type(s.rank_get) == "function" then
			s:rank_get()
		end
	end
	if self.is_open then
		self:_rebuild_codes()
		self:_rebuild_rank()
		self:_set_busy(false)
		self:apply_layout()
	end
end

--- The session's answers (UIRoot.setup, when the session exists).
function AdminPanel.bind(self, s: any)
	if s == nil or self._bound == s then
		return
	end
	self._bound = s
	if s.admin_result then
		s.admin_result:Connect(function(r: any)
			self:_on_result(r)
		end)
	end
	if s.rank_changed then
		s.rank_changed:Connect(function()
			if self.is_open then
				self:_rebuild_rank()
				self:_set_busy(self._waiting ~= nil)
			end
		end)
	end
end

function AdminPanel._set_page(self, i: number)
	self._page = i
	self:_disarm()
	for j, chip in ipairs(self._chips) do
		chip:set_pressed_no_signal(j == i)
	end
	for j, page in ipairs(self._pages) do
		page:set_visible(j == i)
	end
	self.ctx:sfx("click")
	if self.is_open then
		self:apply_layout()
	end
end

--- The page in view: "coins" | "codes" | "rank".
function AdminPanel.page(self): string
	return AdminPanel.PAGES[self._page].key
end

function AdminPanel.tick(self)
	if not self.is_open then
		return
	end
	local t = AdminPanel.now()
	local a = self._armed
	if a ~= nil and t - a.at > AdminPanel.ARM_S then
		self:_disarm()
	end
	if self._waiting ~= nil and t - self._waiting > AdminPanel.WAIT_S then
		self._waiting = nil
		self:_set_busy(false)
		self:_say("The server did not answer. Try again in a moment.", false, true)
		self:_rebuild_codes()
	end
end

-- ---------------------------------------------------------------------------------------------
-- open, close, layout
-- ---------------------------------------------------------------------------------------------

--- Opens on `page` ("coins" | "codes" | "rank"; nil: the one last seen).
function AdminPanel.open(self, page: string?)
	if self.is_open then
		return
	end
	self.is_open = true
	for i, p in ipairs(AdminPanel.PAGES) do
		if p.key == page then
			self._page = i
		end
	end
	for j, chip in ipairs(self._chips) do
		chip:set_pressed_no_signal(j == self._page)
	end
	for j, pg in ipairs(self._pages) do
		pg:set_visible(j == self._page)
	end
	self._waiting = nil
	self:_set_busy(false)
	-- the codes there are (and, for the ranking page, the lists, when this screen has none yet)
	self:_send("state")
	local s = self.ctx.session
	if s ~= nil and s.rank == nil and type(s.rank_get) == "function" then
		s:rank_get()
	end
	self:_rebuild_codes()
	self:_rebuild_rank()
	self:_set_busy(self._waiting ~= nil)
	self:set_visible(true)
	self:apply_layout()
	self._panel:set_modulate_a(1.0)
	self._dim:set_modulate_a(0.0)
	W.fade(self._dim, 1.0, 0.2)
	UICtx.pop_in(self._panel, 0.0, 0.94, 0.3)
	self.ctx:sfx("open")
end

function AdminPanel.close(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	self:_disarm()
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

function AdminPanel.apply_layout(self)
	local compact = self.ctx.compact == true
	local area = self.ctx:clear_rect()
	local pad_h = if compact then 12 else 22
	local pad_v = if compact then 8 else 18
	self._panel:set_padding(pad_h, pad_v, pad_h, pad_v)
	self._v:set_separation(if compact then 6 else 12)
	self._title:set_font_size(if compact then 15 else 22)
	self._shield:set_min_size(if compact then Vector2.new(20, 20) else Vector2.new(26, 26))
	-- (a phone held sideways is short: the lists get the room of everything that can go)
	self._sub:set_visible(not compact)
	self._coin_note:set_visible(not compact)
	local fh = if compact then AdminPanel.FIELD_PHONE else AdminPanel.FIELD
	for _, f in ipairs(self._fields) do
		f:set_min_size(Vector2.new(80, fh))
	end
	self._code_create:set_min_size(Vector2.new(if compact then 96 else 110, fh))
	self._rank_remove:set_min_size(Vector2.new(if compact then 190 else 210, fh))
	for _, b in ipairs({ self._coin_give, self._coin_take, self._coin_see }) do
		b:set_min_size(Vector2.new(0, if compact then 36 else 42))
	end
	for _, chip in ipairs(self._chips) do
		chip:set_min_size(Vector2.new(0, if compact then 30 else 36))
		chip:set_font_size(if compact then 12 else 13)
	end
	for _, chip in ipairs(self._board_chips) do
		chip:set_min_size(Vector2.new(0, if compact then 26 else 32))
		chip:set_font_size(if compact then 11 else 12)
	end
	self._status_l:set_font_size(if compact then 12 else 13)
	local width = math.max(280, math.min(AdminPanel.WIDTH, area.Width - 2 * pad_h - 16))
	self._width = width
	self._status_l:set_min_size(Vector2.new(width - 20, 0))
	self._coin_note:set_min_size(Vector2.new(width, 0))
	-- every page as wide as the window; the lists take what the screen has left under the rest
	for _, page in ipairs(self._pages) do
		page:set_min_size(Vector2.new(width, 0))
	end
	for _, host in ipairs({ self._code_host, self._rank_host }) do
		host:set_min_size(Vector2.new(width, 0))
	end
	local chrome = self._panel:get_combined_minimum_size().Y
	local room = area.Height - 8.0 - chrome
	local list_h = math.clamp(math.floor(room), AdminPanel.LIST_MIN_H, AdminPanel.LIST_H)
	for _, host in ipairs({ self._code_host, self._rank_host }) do
		host:set_min_size(Vector2.new(width, list_h))
	end
	self:_center()
end

function AdminPanel._center(self)
	local area = self.ctx:clear_rect()
	local pn = self._panel
	local sz = pn:get_combined_minimum_size()
	local p = area.Min + (Vector2.new(area.Width, area.Height) - sz) * 0.5
	local y = math.max(p.Y, area.Min.Y + 4.0)
	local rp = Vector2.new(math.floor(p.X + 0.5), math.floor(y + 0.5))
	pn:set_offsets(rp.X, rp.Y, rp.X, rp.Y)
	pn:reset_size()
end

return AdminPanel
