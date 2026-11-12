--!nonstrict
-- The RANK window (the lobby's RANK button, beside the balance): the game's rankings, kept by the
-- server (server/Ranking) from public matches only.
--   head    the name, what counts, close.
--   claim   only for who has a weekly prize to claim (Session.inventory.rank_claim): how many Coroas,
--           for which places, and the CLAIM button. It pays the Coroas (the insignia needs no claim:
--           the first three wear it from Monday on). Gone once claimed.
--   scope   WORLD RANK (all time) | WEEKLY RANK (starts empty every Monday; Data/RankPrizes) |
--           CHAMPIONS (last week's first three of each list, with the insignia they wear this week).
--           Phones: short chips in the head, so the list keeps its room.
--   tabs    VICTORIES (public matches won) | KINGDOMS DESTROYED (nations and players conquered in
--           public matches; bots count), for the rank in view.
--   prizes  under the weekly lists: what the week pays (the insignia and Coroas of the first three,
--           the Coroas of the 4th to the 10th), when it ends, and what the player won last week.
--   list    the best hundred, best first: place, head shot, name, number. The first three places in
--           gold, silver and bronze; the player's own row is marked. Whoever wears the insignia this
--           week has it before their name, in every list (UI/Insignia: the pointer on it says why).
--   mine    the player's own number under the list, always in sight, with their place when they are
--           in the list ("100+" when they are not: the stores can't say where anyone else stands).
-- Phones (short and wide): no sub-title, no column names, no notes; the list takes that room.
-- The lists come from Session.rank (asked for when the window opens, and again every ASK_EVERY_S
-- while it stays open; the server reads its stores every couple of minutes, so nothing here is live).
-- A name is drawn as it is: the interface's language layer never reads a player's name.
-- Signals: closed.
local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local UICtx = require("./UICtx")
local HelpOverlay = require("./HelpOverlay")
local Insignia = require("./Insignia")
local Signal = UITheme.core("Signal")
local RankPrizes: any = if typeof(game) == "Instance"
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data.RankPrizes)
	else (require :: any)("../../shared/Data/RankPrizes")

local IS_ROBLOX = typeof(game) == "Instance"

local Ranking = W.class(W.Control)

--- The tabs: the board's key (Session.rank.boards), its name, its icon, the list's number column.
Ranking.TABS = {
	{ key = "wins", title = "VICTORIES", icon = "crown", column = "WINS" },
	{ key = "kills", title = "KINGDOMS DESTROYED", icon = "skull", column = "KINGDOMS" },
}
--- The two ranks: the key, what is added to a tab's key for its board (Session.rank.boards: "wins",
--- "wins_w"...), its name (phones: the short one) and its icon.
Ranking.SCOPES = {
	{ key = "world", suffix = "", title = "WORLD RANK", short = "WORLD", icon = "globe" },
	{ key = "week", suffix = "_w", title = "WEEKLY RANK", short = "WEEKLY", icon = "clock" },
	-- (last week's final lists: only their first RankPrizes.BADGE_PLACES are shown, both at once)
	{ key = "champs", suffix = "_l", title = "CHAMPIONS", short = "CHAMPIONS", icon = "crown" },
}
--- The list's width and the most it may be tall, logical px (phones: the screen decides the height).
Ranking.WIDTH = 460
Ranking.WIDTH_PHONE = 430
Ranking.LIST_H = 396
Ranking.LIST_MIN_H = 96
--- A row's height (phones: ROW_PHONE).
Ranking.ROW = 36
Ranking.ROW_PHONE = 30
--- The lists are asked for again when the window opens with ones older than this, and while it stays
--- open, seconds.
Ranking.STALE_S = 20
Ranking.ASK_EVERY_S = 60
--- With no answer after this long, the window says the lists could not be loaded, seconds.
Ranking.WAIT_S = 10
--- The CLAIM button waits this long for the server's answer before it can be pressed again, seconds.
Ranking.CLAIM_WAIT_S = 12

local GOLD = Color3.fromRGB(236, 190, 92)
local SILVER = Color3.fromRGB(202, 208, 218)
local BRONZE = Color3.fromRGB(208, 142, 92)
local MEDALS = { GOLD, SILVER, BRONZE }

--- The player looking at the lists.
function Ranking.user_id(): number
	if IS_ROBLOX then
		local ok, id = pcall(function()
			return game:GetService("Players").LocalPlayer.UserId
		end)
		if ok and type(id) == "number" then
			return id
		end
	end
	return 0
end

--- The clock the window waits by (tests set their own).
function Ranking.now(): number
	return os.clock()
end

--- A user's head shot (Roblox draws it: no request of ours).
function Ranking.head_shot(uid: number): string
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", uid)
end

--- A label's text exactly as given (Label.set_text would pass it through the language layer: a
--- player called "Play" must not be shown as "Jogar").
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
Ranking.set_verbatim = set_verbatim

--- An insignia's picture (Data/RankPrizes) as a node `px` wide: (node, the ImageLabel).
function Ranking.badge_node(place: number, px: number): (any, any)
	local img = Instance.new("ImageLabel")
	img.Name = "RankBadge"
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.ScaleType = Enum.ScaleType.Fit
	img.Image = RankPrizes.badge_image(place)
	local node = W.wrap(img)
	-- (the picture fades with the window: 1.0 = fully there)
	node:_part(img, "ImageTransparency", 1.0)
	node:set_min_size(Vector2.new(px, px))
	node.size_flags_vertical = W.SHRINK_CENTER
	node:set_mouse_filter(W.MOUSE_IGNORE)
	return node, img
end

--- The board in view: the tab's key with the rank's suffix ("wins", "kills_w"...).
function Ranking.board(self): string
	return Ranking.TABS[self._tab].key .. Ranking.SCOPES[self._scope].suffix
end

--- "#2 in Victories and #5 in Kingdoms destroyed": the places of a week's result (as the code
--- writes it: the label that shows it puts it in the interface's language).
function Ranking.places_text(wins: number?, kills: number?): string
	if wins ~= nil and kills ~= nil then
		return string.format("#%d in Victories and #%d in Kingdoms destroyed", wins, kills)
	elseif wins ~= nil then
		return string.format("#%d in Victories", wins)
	elseif kills ~= nil then
		return string.format("#%d in Kingdoms destroyed", kills)
	end
	return ""
end

function Ranking.new(c: any)
	local self = setmetatable({}, Ranking.__mt)
	W.Control._init(self)
	self.ctx = c
	self.closed = Signal.new()
	self.is_open = false
	self._tab = 1
	--- 1: the world rank, 2: the weekly rank (Ranking.SCOPES)
	self._scope = 1
	--- "wait" (asked, nothing to show yet) | "fail" (no answer, or no server) | nil
	self._state = nil :: string?
	self._asked_at = -math.huge
	self._rows = {}
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
	local trophy = UITheme.icon_rect("leaderboard", 26.0, GOLD)
	trophy.size_flags_vertical = W.SHRINK_CENTER
	self._trophy = trophy
	head:add_child(trophy)
	local tcol = UITheme.vbox(1)
	tcol.size_flags_vertical = W.SHRINK_CENTER
	tcol.size_flags_horizontal = W.EXPAND_FILL
	self._title = UITheme.label("RANKING", 22, 800, GOLD, 4)
	tcol:add_child(self._title)
	self._sub = UITheme.label("The best players of public matches.", 12, 600, UITheme.TEXT_2)
	tcol:add_child(self._sub)
	head:add_child(tcol)
	-- the two ranks. Each has a chip in two places: a row of its own under the head, and (phones) a
	-- short one in the head; only one of the two places is in sight (apply_layout)
	self._scope_chips = {}
	local function scope_chip(i: number, text: string, icon: string?, h: number): any
		local chip = UITheme.button(text, "ChipButton", icon, h)
		chip.toggle_mode = true
		chip:set_font_size(13)
		chip:set_pressed_no_signal(i == self._scope)
		chip.pressed:Connect(function()
			self:_set_scope(i)
		end)
		table.insert(self._scope_chips, { chip = chip, scope = i })
		return chip
	end
	local shead = UITheme.hbox(6)
	shead.size_flags_vertical = W.SHRINK_CENTER
	self._scope_head = shead
	for i, sc in ipairs(Ranking.SCOPES) do
		local chip = scope_chip(i, sc.short, nil, 30.0)
		chip:set_font_size(11)
		shead:add_child(chip)
	end
	shead:set_visible(false)
	head:add_child(shead)
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

	-- the prize to claim (only while there is one: _refresh_claim)
	local claim = W.Panel.new()
	claim:set_mouse_filter(W.MOUSE_PASS)
	claim:add_theme_stylebox_override("panel", UITheme.flat(UITheme.c(GOLD, 0.16), 10, UITheme.c(GOLD, 0.8), 1, 10.0, 6.0))
	local ch = UITheme.hbox(10)
	claim:add_child(ch)
	local ccoin = UITheme.icon_rect("star", 22.0, GOLD)
	ccoin.size_flags_vertical = W.SHRINK_CENTER
	self._claim_coin = ccoin
	ch:add_child(ccoin)
	local ccol = UITheme.vbox(0)
	ccol.size_flags_horizontal = W.EXPAND_FILL
	ccol.size_flags_vertical = W.SHRINK_CENTER
	self._claim_title = UITheme.label("", 14, 800, GOLD)
	self._claim_title.clip_text = true
	self._claim_title.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	ccol:add_child(self._claim_title)
	-- (for which places: two lines when one is not enough)
	self._claim_sub = UITheme.label("", 11, 600, UITheme.TEXT_2)
	self._claim_sub:set_autowrap(true)
	ccol:add_child(self._claim_sub)
	ch:add_child(ccol)
	local cbtn = UITheme.button("CLAIM", "PrimaryButton", nil, 36.0)
	cbtn:set_font_size(13)
	cbtn:set_min_size(Vector2.new(104, 36))
	cbtn.size_flags_vertical = W.SHRINK_CENTER
	cbtn.pressed:Connect(function()
		self:_press_claim()
	end)
	self._claim_b = cbtn
	ch:add_child(cbtn)
	self._claim = claim
	self._claim_m = W.Margin.new()
	self._claim_m:set_mouse_filter(W.MOUSE_IGNORE)
	self._claim_m:add_theme_constant_override("margin_right", 10)
	self._claim_m:add_child(claim)
	self._claim_m:set_visible(false)
	--- os.clock when CLAIM was pressed and the answer is still to come, or nil
	self._claiming = nil :: number?
	v:add_child(self._claim_m)

	local srow = UITheme.hbox(6)
	self._scope_row = srow
	for i, sc in ipairs(Ranking.SCOPES) do
		local chip = scope_chip(i, sc.title, sc.icon, 40.0)
		chip:set_font_size(12)
		chip:add_theme_constant_override("icon_max_width", 16)
		chip.size_flags_horizontal = W.EXPAND_FILL
		srow:add_child(chip)
	end
	v:add_child(srow)

	-- tabs: one per list, each as wide as the other
	local tabs = UITheme.hbox(8)
	self._tab_row = tabs
	self._tabs = {}
	for i, t in ipairs(Ranking.TABS) do
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

	-- the columns' names
	local cols = UITheme.hbox(8)
	self._cols = cols
	self._col_place = UITheme.caption("#", 10, UITheme.TEXT_3)
	UITheme.fix_width(self._col_place, 34, W.ALIGN_CENTER, false)
	cols:add_child(self._col_place)
	self._col_name = UITheme.caption("PLAYER", 10, UITheme.TEXT_3)
	self._col_name.size_flags_horizontal = W.EXPAND_FILL
	cols:add_child(self._col_name)
	self._col_value = UITheme.caption("WINS", 10, UITheme.TEXT_3)
	self._col_value:set_alignment(W.ALIGN_RIGHT)
	cols:add_child(self._col_value)
	self._cols_m = W.Margin.new()
	self._cols_m:set_mouse_filter(W.MOUSE_IGNORE)
	self._cols_m:add_theme_constant_override("margin_left", 8)
	self._cols_m:add_theme_constant_override("margin_right", 14)
	self._cols_m:add_child(cols)
	v:add_child(self._cols_m)

	-- the list (it scrolls), and over it what there is to say when it has no rows
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
	-- (room for the scroll bar, so it never covers the numbers)
	list_m:add_theme_constant_override("margin_right", 10)
	scroll:add_child(list_m)
	self._list = UITheme.vbox(4)
	self._list.size_flags_horizontal = W.EXPAND_FILL
	list_m:add_child(self._list)
	self._empty = UITheme.label("", 13, 600, UITheme.TEXT_2)
	self._empty:set_alignment(W.ALIGN_CENTER)
	self._empty:set_autowrap(true)
	self._empty:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self._empty.vertical_alignment = W.VALIGN_CENTER
	self._empty:set_visible(false)
	host:add_child(self._empty)

	-- the player's own row, always in sight
	local mine = W.Panel.new()
	mine:set_mouse_filter(W.MOUSE_IGNORE)
	mine:add_theme_stylebox_override("panel", UITheme.flat(UITheme.c(GOLD, 0.1), 10, UITheme.c(GOLD, 0.5), 1, 8.0, 6.0))
	self._mine = mine
	local mh = UITheme.hbox(8)
	mine:add_child(mh)
	self._mine_place = UITheme.label("—", 14, 800, GOLD)
	UITheme.fix_width(self._mine_place, 34, W.ALIGN_CENTER, false)
	self._mine_place.size_flags_vertical = W.SHRINK_CENTER
	mh:add_child(self._mine_place)
	local mcol = UITheme.vbox(0)
	mcol.size_flags_horizontal = W.EXPAND_FILL
	mcol.size_flags_vertical = W.SHRINK_CENTER
	local mtitle = UITheme.hbox(6)
	self._mine_title = UITheme.label("YOU", 13, 700, UITheme.TEXT, 1)
	self._mine_title.size_flags_vertical = W.SHRINK_CENTER
	mtitle:add_child(self._mine_title)
	-- the insignia the player wears this week (Data/RankPrizes), when they have one
	self._mine_ins = Insignia.new(c, 16)
	self._mine_badge, self._mine_badge_img = self._mine_ins.node, self._mine_ins.img
	mtitle:add_child(self._mine_badge)
	mcol:add_child(mtitle)
	self._mine_note = UITheme.label("", 11, 500, UITheme.TEXT_2)
	mcol:add_child(self._mine_note)
	mh:add_child(mcol)
	self._mine_value = UITheme.label("0", 16, 800, UITheme.TEXT)
	self._mine_value:set_alignment(W.ALIGN_RIGHT)
	self._mine_value.size_flags_vertical = W.SHRINK_CENTER
	mh:add_child(self._mine_value)
	self._mine_m = W.Margin.new()
	self._mine_m:set_mouse_filter(W.MOUSE_IGNORE)
	self._mine_m:add_theme_constant_override("margin_right", 10)
	self._mine_m:add_child(mine)
	v:add_child(self._mine_m)

	-- what the week pays (the weekly rank only)
	local prizes = W.Panel.new()
	prizes:set_mouse_filter(W.MOUSE_IGNORE)
	prizes:add_theme_stylebox_override("panel", UITheme.flat(UITheme.c(GOLD, 0.06), 10, UITheme.c(GOLD, 0.28), 1, 10.0, 6.0))
	local pv = UITheme.vbox(4)
	prizes:add_child(pv)
	local pcap = UITheme.hbox(8)
	self._prize_cap = pcap
	self._prize_title = UITheme.caption("WEEKLY PRIZES", 10, GOLD)
	self._prize_title.size_flags_horizontal = W.EXPAND_FILL
	pcap:add_child(self._prize_title)
	self._prize_ends = UITheme.label("", 11, 700, UITheme.TEXT_2)
	self._prize_ends:set_alignment(W.ALIGN_RIGHT)
	pcap:add_child(self._prize_ends)
	pv:add_child(pcap)
	local prow = UITheme.hbox(6)
	self._prize_row = prow
	local coin = UITheme.icon_rect("star", 13.0, GOLD)
	coin.size_flags_vertical = W.SHRINK_CENTER
	prow:add_child(coin)
	self._prize_cells = {}
	for place = 1, RankPrizes.BADGE_PLACES do
		local cell = UITheme.hbox(4)
		cell.size_flags_horizontal = W.EXPAND_FILL
		local node, img = Ranking.badge_node(place, 18)
		cell:add_child(node)
		local amount = UITheme.label(UICtx.commas(RankPrizes.coroas(place)), 13, 800, MEDALS[place] or UITheme.TEXT)
		amount.size_flags_vertical = W.SHRINK_CENTER
		cell:add_child(amount)
		table.insert(self._prize_cells, { node = cell, badge = node, image = img, amount = amount, place = place })
		prow:add_child(cell)
	end
	-- the places after the insignias, in one cell: "4th–10th" and the most and the least they pay
	local rest = UITheme.hbox(4)
	local last_place = #RankPrizes.COROAS
	local first_rest = RankPrizes.BADGE_PLACES + 1
	self._prize_rest_l = UITheme.label(string.format("Places %d–%d", first_rest, last_place), 11, 700, UITheme.TEXT_2)
	self._prize_rest_l.size_flags_vertical = W.SHRINK_CENTER
	rest:add_child(self._prize_rest_l)
	self._prize_rest_v = UITheme.label(
		string.format("%s–%s", UICtx.commas(RankPrizes.coroas(first_rest)), UICtx.commas(RankPrizes.coroas(last_place))),
		13,
		800,
		UITheme.TEXT
	)
	self._prize_rest_v.size_flags_vertical = W.SHRINK_CENTER
	rest:add_child(self._prize_rest_v)
	rest:set_visible(last_place >= first_rest)
	self._prize_rest = rest
	prow:add_child(rest)
	-- (phones have no caption row: when the week ends goes at the end of this one)
	self._prize_ends_c = UITheme.label("", 11, 700, UITheme.TEXT_2)
	self._prize_ends_c:set_alignment(W.ALIGN_RIGHT)
	self._prize_ends_c.size_flags_vertical = W.SHRINK_CENTER
	self._prize_ends_c:set_visible(false)
	prow:add_child(self._prize_ends_c)
	pv:add_child(prow)
	self._prize_last = UITheme.label("", 11, 600, UITheme.TEXT_2)
	self._prize_last:set_autowrap(true)
	self._prize_last:set_visible(false)
	pv:add_child(self._prize_last)
	self._prizes = prizes
	self._prizes_m = W.Margin.new()
	self._prizes_m:set_mouse_filter(W.MOUSE_IGNORE)
	self._prizes_m:add_theme_constant_override("margin_right", 10)
	self._prizes_m:add_child(prizes)
	self._prizes_m:set_visible(false)
	v:add_child(self._prizes_m)

	self._note = UITheme.label("Only public matches count. The lists update every few minutes.", 11, 500, UITheme.TEXT_3)
	self._note:set_alignment(W.ALIGN_CENTER)
	self._note:set_autowrap(true)
	v:add_child(self._note)
	return self
end

--- The session's lists (UIRoot.setup, when the session exists).
function Ranking.bind(self, s: any)
	if s == nil or self._bound == s then
		return
	end
	self._bound = s
	if s.rank_changed then
		s.rank_changed:Connect(function()
			self._state = nil
			if self.is_open then
				self:_rebuild()
			end
		end)
	end
	-- the prize to claim comes with the inventory, and leaves with it once claimed
	if s.inventory_changed then
		s.inventory_changed:Connect(function()
			if self.is_open then
				self:_refresh_claim(true)
			end
		end)
	end
	if s.rank_claimed then
		s.rank_claimed:Connect(function(ok: boolean, stars: number)
			self._claiming = nil
			if ok and stars > 0 then
				self.ctx:sfx("confirm")
			end
			if self.is_open then
				self:_refresh_claim(true)
			end
		end)
	end
end

-- ---------------------------------------------------------------------------------------------
-- The prize to claim
-- ---------------------------------------------------------------------------------------------

--- What there is to claim (Session.inventory.rank_claim: { total, weeks = { { wins?, kills?, stars } } }),
--- or nil.
function Ranking.claim_of(self): any
	local s = self.ctx.session
	local inv = if s ~= nil then s.inventory else nil
	local c = if type(inv) == "table" then inv.rank_claim else nil
	if type(c) ~= "table" or type(c.weeks) ~= "table" or #c.weeks == 0 or (tonumber(c.total) or 0) <= 0 then
		return nil
	end
	return c
end

--- The CLAIM panel: there only while the player has a prize to claim. `relayout`: its coming or
--- going changes the list's room.
function Ranking._refresh_claim(self, relayout: boolean?)
	local c = Ranking.claim_of(self)
	local on = c ~= nil
	if c ~= nil then
		self._claim_title:set_text(string.format("Weekly Rank: you won %s Stars!", UICtx.commas(c.total)))
		local last = c.weeks[#c.weeks]
		self._claim_sub:set_text(
			if #c.weeks > 1
				then string.format("Prizes of %d weeks", #c.weeks)
				else Ranking.places_text(last.wins, last.kills) .. " last week"
		)
		local busy = self._claiming ~= nil
		self._claim_b:set_disabled(busy)
		self._claim_b:set_text(if busy then "CLAIMING…" else "CLAIM")
	else
		self._claiming = nil
	end
	if on ~= self._claim_m.visible then
		self._claim_m:set_visible(on)
		if relayout and self.is_open then
			self:apply_layout()
		end
	end
end

--- The CLAIM button: asks the server for the Coroas (Session.rank_claim). The answer comes as
--- rank_claimed, and the inventory that follows no longer has the prize: the panel goes.
function Ranking._press_claim(self)
	if self._claiming ~= nil or Ranking.claim_of(self) == nil then
		return
	end
	local s = self.ctx.session
	if s == nil or type(s.rank_claim) ~= "function" or s:rank_claim() ~= true then
		self._claim_sub:set_text("Couldn't claim now. Try again in a moment.")
		return
	end
	self._claiming = Ranking.now()
	self:_refresh_claim()
end

--- The lists as the session has them, or nil.
function Ranking._data(self): any
	local s = self.ctx.session
	return if s ~= nil and type(s.rank) == "table" then s.rank else nil
end

--- Asks the server for the lists.
function Ranking._ask(self)
	local s = self.ctx.session
	self._asked_at = Ranking.now()
	local sent = s ~= nil and type(s.rank_get) == "function" and s:rank_get() == true
	if self:_data() == nil then
		self._state = if sent then "wait" else "fail"
	end
end

-- ---------------------------------------------------------------------------------------------
-- The list
-- ---------------------------------------------------------------------------------------------

function Ranking._row(self, place: number, r: any, own: boolean, compact: boolean, boards: any): any
	local medal = MEDALS[place]
	local h = if compact then Ranking.ROW_PHONE else Ranking.ROW
	local row = W.Panel.new()
	row:set_mouse_filter(W.MOUSE_IGNORE)
	row:add_theme_stylebox_override(
		"panel",
		UITheme.flat(
			if own then UITheme.c(GOLD, 0.14) elseif medal ~= nil then UITheme.c(medal, 0.07) else UITheme.rgba(1, 1, 1, 0.03),
			9,
			if own then UITheme.c(GOLD, 0.7) elseif medal ~= nil then UITheme.c(medal, 0.3) else UITheme.CLEAR,
			if own or medal ~= nil then 1 else 0,
			8.0,
			if compact then 2.0 else 4.0
		)
	)
	row:set_min_size(Vector2.new(0, h))
	local hb = UITheme.hbox(8)
	row:add_child(hb)
	local pl = UITheme.label(tostring(place), if medal ~= nil then 15 else 13, 800, medal or UITheme.TEXT_2)
	UITheme.fix_width(pl, 34, W.ALIGN_CENTER, false)
	pl.size_flags_vertical = W.SHRINK_CENTER
	hb:add_child(pl)
	local face = Instance.new("ImageLabel")
	face.Name = "Face"
	face.BackgroundColor3 = Color3.fromRGB(52, 48, 54)
	face.BackgroundTransparency = 0
	face.BorderSizePixel = 0
	face.ScaleType = Enum.ScaleType.Crop
	face.Image = Ranking.head_shot(r[1])
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = face
	local fnode = W.wrap(face)
	-- (the picture and the disc under it fade with the window: 1.0 = fully there)
	fnode:_part(face, "ImageTransparency", 1.0)
	fnode:_part(face, "BackgroundTransparency", 1.0)
	local fs = h - (if compact then 8 else 10)
	fnode:set_min_size(Vector2.new(fs, fs))
	fnode.size_flags_vertical = W.SHRINK_CENTER
	fnode:set_mouse_filter(W.MOUSE_IGNORE)
	hb:add_child(fnode)
	-- the insignia they wear this week (last week's first three of either weekly list), before the name
	local ins = nil
	local bp, bw, bk = Insignia.of_lists(boards, r[1])
	if bp ~= nil then
		ins = Insignia.new(self.ctx, if compact then 15 else 17)
		ins:set(bp, bw, bk)
		hb:add_child(ins.node)
	end
	local name = UITheme.label("", if compact then 13 else 14, if own then 800 else 600, UITheme.TEXT)
	name.clip_text = true
	name.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	name.size_flags_horizontal = W.EXPAND_FILL
	name.size_flags_vertical = W.SHRINK_CENTER
	if r[2] ~= "" then
		set_verbatim(name, r[2])
	else
		-- (a name Roblox did not give: an account that no longer exists, or its names were down)
		name:set_text("Player")
		name:set_color(UITheme.TEXT_3)
	end
	hb:add_child(name)
	local value = UITheme.label(UICtx.commas(r[3]), if compact then 14 else 15, 800, medal or UITheme.TEXT)
	value:set_alignment(W.ALIGN_RIGHT)
	value.size_flags_vertical = W.SHRINK_CENTER
	hb:add_child(value)
	return { node = row, uid = r[1], place = place, name = name, value = value, own = own, face = face, place_l = pl, ins = ins }
end

--- A caption between the champions' two lists: the list's icon and name.
function Ranking._section(self, tab: any): any
	local hb = UITheme.hbox(6)
	hb:set_min_size(Vector2.new(0, 20))
	local ic = UITheme.icon_rect(tab.icon, 13.0, GOLD)
	ic.size_flags_vertical = W.SHRINK_CENTER
	hb:add_child(ic)
	local l = UITheme.caption(tab.title, 10, GOLD)
	l.size_flags_vertical = W.SHRINK_CENTER
	hb:add_child(l)
	return hb
end

--- The rows of the tab in view, the player's own row and what the list says when it is empty.
function Ranking._rebuild(self)
	for _, ch in ipairs(self._list:get_children()) do
		self._list:remove_child(ch)
		ch:queue_free()
	end
	table.clear(self._rows)
	local compact = self.ctx.compact == true
	local tab = Ranking.TABS[self._tab]
	local weekly = Ranking.SCOPES[self._scope].key == "week"
	local champs = Ranking.SCOPES[self._scope].key == "champs"
	local board = Ranking.board(self)
	local data = self:_data()
	local me = Ranking.user_id()
	local boards = if data ~= nil then data.boards else nil
	self._col_value:set_text(tab.column)
	self:_refresh_claim()
	local rows = if data ~= nil then data.boards[board] else nil
	if champs then
		-- last week's first three of each list, one list under the other
		for _, t in ipairs(Ranking.TABS) do
			local list = if data ~= nil then data.boards[t.key .. "_l"] else nil
			local n = if type(list) == "table" then math.min(#list, RankPrizes.BADGE_PLACES) else 0
			if n > 0 then
				self._list:add_child(self:_section(t))
			end
			for i = 1, n do
				local r = list[i]
				local row = self:_row(i, r, r[1] == me and me ~= 0, compact, boards)
				row.board = t.key
				table.insert(self._rows, row)
				self._list:add_child(row.node)
			end
		end
		rows = nil
	end
	for i, r in (if type(rows) == "table" then rows else {}) do
		local row = self:_row(i, r, r[1] == me and me ~= 0, compact, boards)
		table.insert(self._rows, row)
		self._list:add_child(row.node)
	end
	-- what an empty list says
	local text = ""
	if #self._rows == 0 then
		if data == nil then
			text = if self._state == "fail"
				then "Couldn't load the ranking. Try again in a moment."
				else "Loading the ranking…"
		elseif data.ok ~= true then
			text = "Couldn't load the ranking. Try again in a moment."
		elseif champs then
			text = "No champions yet. The top 3 of each weekly list appear here on Monday, with their insignia."
		elseif weekly then
			text = if tab.key == "wins"
				then "Nobody has won a public match this week yet. Be the first!"
				else "Nobody has destroyed a kingdom this week yet. Be the first!"
		else
			text = if tab.key == "wins"
				then "Nobody has won a public match yet. Be the first!"
				else "Nobody has destroyed a kingdom in a public match yet. Be the first!"
		end
	end
	self._empty:set_text(text)
	self._empty:set_visible(text ~= "")
	-- the player's own numbers
	local mine = if data ~= nil then data.me[board] else nil
	local value = if type(mine) == "table" then (tonumber(mine[1]) or 0) else 0
	local place = if type(mine) == "table" then tonumber(mine[2]) else nil
	self._mine_value:set_text(UICtx.commas(value))
	local full = type(rows) == "table" and #rows >= 100
	-- (four characters, "100+", in the place's narrow column: smaller letters for them)
	self._mine_place:set_font_size(14)
	-- what the player's number counts, and how to get into the list
	local counts = if tab.key == "wins"
		then (if weekly then "Public matches won this week" else "Public matches won")
		else (if weekly then "Kingdoms destroyed this week" else "Kingdoms destroyed in public matches")
	local how = if tab.key == "wins"
		then (if weekly then "Win a public match this week to enter the list." else "Win a public match to enter the list.")
		else (
			if weekly
				then "Destroy a kingdom in a public match this week to enter the list."
				else "Destroy a kingdom in a public match to enter the list."
		)
	if place ~= nil then
		self._mine_place:set_text(tostring(place))
		self._mine_place:set_color(MEDALS[place] or GOLD)
		self._mine_note:set_text(counts)
	elseif value > 0 and full then
		self._mine_place:set_font_size(12)
		self._mine_place:set_text("100+")
		self._mine_place:set_color(UITheme.TEXT_2)
		self._mine_note:set_text("Outside the top 100")
	else
		self._mine_place:set_text("—")
		self._mine_place:set_color(UITheme.TEXT_3)
		self._mine_note:set_text(if data == nil then "" elseif value > 0 then counts else how)
	end
	self._mine_note:set_visible(not compact and self._mine_note:get_text() ~= "")
	-- the insignia the player wears this week
	local week = if data ~= nil and type(data.week) == "table" then data.week else nil
	local on = if week ~= nil and type(week.badge_on) == "table" then week.badge_on else {}
	self._mine_ins:set(if week ~= nil then week.badge else nil, on.wins, on.kills)
	-- (the champions' board is about last week's lists: no tabs, no columns, no row of the player's)
	self._tab_row:set_visible(not champs)
	self._cols_m:set_visible(not champs and not compact)
	self._mine_m:set_visible(not champs)
	-- the weekly rank: its prizes, when it ends and what last week paid the player
	-- (lists that came with no week: the server has the weekly rank off, Ranking.WEEKLY_ON, or is an
	-- older one during an update: no prize is promised that nobody would pay)
	self._prizes_m:set_visible(weekly and (data == nil or week ~= nil))
	self._sub:set_text(
		if champs
			then "Last week's top 3 of each list, with their insignia."
			elseif weekly then "Starts again every Monday. Only public matches count."
			else "The best players of public matches."
	)
	self._note:set_text(
		if champs
			then "The insignia changes hands every Monday. Stay in the top 3 of the Weekly Rank to keep it."
			elseif weekly then "The top 3 of each list wear the insignia for a week. Winners claim their Stars here from Monday on."
			else "Only public matches count. The lists update every few minutes."
	)
	local last = if week ~= nil then week.last else nil
	if weekly and last ~= nil and not compact then
		self._prize_last:set_text(
			string.format("Last prize: %s · +%s Stars", Ranking.places_text(last.wins, last.kills), UICtx.commas(last.stars))
		)
		self._prize_last:set_visible(true)
	else
		self._prize_last:set_visible(false)
	end
	self:_show_left()
	self._scroll:queue_sort()
end

--- When the week ends, as the clock stands now ("Ends in 3d 4h"; nothing when the server sent no week).
function Ranking._show_left(self)
	local data = self:_data()
	local week = if data ~= nil and type(data.week) == "table" then data.week else nil
	local text, short = "", ""
	if week ~= nil and type(week.ends) == "number" then
		short = RankPrizes.left_text(week.ends - Ranking.now())
		text = string.format("Ends in %s", short)
	end
	if text ~= self._left_text then
		self._left_text = text
		self._prize_ends:set_text(text)
		self._prize_ends_c:set_text(text)
	end
end

--- The world rank (1) or the weekly one (2).
function Ranking._set_scope(self, i: number)
	self._scope = i
	for _, c in ipairs(self._scope_chips) do
		c.chip:set_pressed_no_signal(c.scope == i)
	end
	-- (the prizes come and go with the weekly rank: the list's room changes)
	self:apply_layout();
	(self._scroll.gui :: any).CanvasPosition = Vector2.zero
	self.ctx:sfx("click")
end

function Ranking._set_tab(self, i: number)
	self._tab = i
	for j, ch in ipairs(self._tabs) do
		ch:set_pressed_no_signal(j == i)
	end
	self:_rebuild();
	(self._scroll.gui :: any).CanvasPosition = Vector2.zero
	self.ctx:sfx("click")
end

--- Every frame while open (UIRoot): asks again now and then, and gives up waiting for an answer.
function Ranking.tick(self)
	if not self.is_open then
		return
	end
	local t = Ranking.now()
	if self._scope == 2 then
		self:_show_left()
	end
	-- (no answer to CLAIM: the button can be pressed again; a prize is only ever paid once)
	if self._claiming ~= nil and t - self._claiming > Ranking.CLAIM_WAIT_S then
		self._claiming = nil
		self:_refresh_claim()
	end
	if self._state == "wait" and t - self._asked_at > Ranking.WAIT_S then
		self._state = "fail"
		self:_rebuild()
	elseif t - self._asked_at > Ranking.ASK_EVERY_S then
		self:_ask()
		if self:_data() == nil then
			self:_rebuild() -- ("loading" again, in place of "couldn't load")
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Open / close / layout
-- ---------------------------------------------------------------------------------------------

--- Opens on `tab` ("wins" | "kills"; nil: the one last seen) of rank `scope` ("world" | "week"; nil:
--- the one last seen).
function Ranking.open(self, tab: string?, scope: string?)
	if self.is_open then
		return
	end
	self.is_open = true
	for i, t in ipairs(Ranking.TABS) do
		if t.key == tab then
			self._tab = i
		end
	end
	for i, sc in ipairs(Ranking.SCOPES) do
		if sc.key == scope then
			self._scope = i
		end
	end
	for j, ch in ipairs(self._tabs) do
		ch:set_pressed_no_signal(j == self._tab)
	end
	for _, c in ipairs(self._scope_chips) do
		c.chip:set_pressed_no_signal(c.scope == self._scope)
	end
	self._state = nil
	local data = self:_data()
	if data == nil or data.ok ~= true or Ranking.now() - (tonumber(data.at) or -math.huge) > Ranking.STALE_S then
		self:_ask()
	else
		self._asked_at = Ranking.now()
	end
	self:set_visible(true)
	self:apply_layout();
	(self._scroll.gui :: any).CanvasPosition = Vector2.zero
	self._panel:set_modulate_a(1.0)
	self._dim:set_modulate_a(0.0)
	W.fade(self._dim, 1.0, 0.2)
	UICtx.pop_in(self._panel, 0.0, 0.94, 0.3)
	self.ctx:sfx("open")
end

function Ranking.close(self)
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

function Ranking.apply_layout(self)
	local compact = self.ctx.compact == true
	local area = self.ctx:clear_rect()
	local pad_h = if compact then 12 else 22
	local pad_v = if compact then 8 else 18
	self._panel:set_padding(pad_h, pad_v, pad_h, pad_v)
	self._v:set_separation(if compact then 5 else 10)
	self._title:set_font_size(if compact then 15 else 22)
	self._trophy:set_min_size(if compact then Vector2.new(20, 20) else Vector2.new(26, 26))
	-- (a phone held sideways is short: the list gets the room of everything that can go)
	self._sub:set_visible(not compact)
	self._note:set_visible(not compact)
	self._cols_m:set_visible(not compact)
	self._claim_sub:set_visible(not compact)
	self._claim_title:set_font_size(if compact then 12 else 14)
	self._claim_coin:set_min_size(if compact then Vector2.new(16, 16) else Vector2.new(22, 22))
	self._claim_b:set_min_size(if compact then Vector2.new(92, 28) else Vector2.new(104, 36))
	self._claim_b:set_font_size(if compact then 12 else 13)
	-- (the ranks: a row of their own, or short chips in the head)
	self._scope_row:set_visible(not compact)
	self._scope_head:set_visible(compact)
	self._prize_cap:set_visible(not compact)
	self._prize_ends_c:set_visible(compact)
	self._prize_rest_l:set_font_size(if compact then 10 else 11)
	for _, cell in ipairs(self._prize_cells) do
		cell.amount:set_font_size(if compact then 12 else 13)
		cell.badge:set_min_size(if compact then Vector2.new(16, 16) else Vector2.new(18, 18))
	end
	self._prize_rest_v:set_font_size(if compact then 12 else 13)
	for _, ch in ipairs(self._tabs) do
		ch:set_min_size(Vector2.new(0, if compact then 30 else 38))
		ch:set_font_size(if compact then 12 else 13)
	end
	self._mine_title:set_font_size(if compact then 12 else 13)
	self._mine_value:set_font_size(if compact then 14 else 16)
	local width = math.min(if compact then Ranking.WIDTH_PHONE else Ranking.WIDTH, area.Width - 2 * pad_h - 16)
	self._note:set_min_size(Vector2.new(width, 0))
	self._prize_last:set_min_size(Vector2.new(width - 32, 0))
	-- (the panel's text has what the coin and the button leave of the window's width)
	self._claim_sub:set_min_size(Vector2.new(math.max(80, width - (if compact then 150 else 190)), 0))
	if self.is_open then
		self:_rebuild()
	end
	-- the list takes what the screen has left under the rest of the window
	self._host:set_min_size(Vector2.new(width, 0))
	local chrome = self._panel:get_combined_minimum_size().Y
	local room = area.Height - 8.0 - chrome
	self._host:set_min_size(Vector2.new(width, math.clamp(math.floor(room), Ranking.LIST_MIN_H, Ranking.LIST_H)))
	self:_center()
end

function Ranking._center(self)
	local area = self.ctx:clear_rect()
	local pn = self._panel
	local sz = pn:get_combined_minimum_size()
	local p = area.Min + (Vector2.new(area.Width, area.Height) - sz) * 0.5
	local y = math.max(p.Y, area.Min.Y + 4.0)
	local rp = Vector2.new(math.floor(p.X + 0.5), math.floor(y + 0.5))
	pn:set_offsets(rp.X, rp.Y, rp.X, rp.Y)
	pn:reset_size()
end

return Ranking
