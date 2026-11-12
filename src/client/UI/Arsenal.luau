--!nonstrict
-- The Arsenal (2026-10-04: units like Artillery and special nukes, unlocked by grinding Stars or
-- with Robux): a modal for the items of Data/Arsenal. It opens from the
-- title (ArsenalButton), from the command bar's SHOP button, and on its item when a locked unit is
-- pressed in a match.
--
-- One item at a time (2026-10-24: the old menu was so confusing that players opened it and bought
-- nothing; of 4.63M opens in a week,
-- 164K pressed a price). It was a grid of eight cards, each with an unlabeled Stars pill and an
-- unlabeled Robux pill under a small busy scene.
--   list     on the left, the items grouped NUKES / ARMY / BOOSTS: each a row with its render, its name
--            and what it takes: OWNED, its Stars when the player has enough, else its Robux price. A
--            press shows it on the right.
--   item     on the right: what it does in a match, playing big (UI/ArsenalDemo); its name, what kind
--            of thing it is and FOREVER; one plain sentence (Data/Arsenal `plain`) and two facts. Then
--            one big BUY NOW button with the Robux price, and under it the other way: OR UNLOCK WITH
--            ★ 20,000 when the player has the Stars (a press asks once more, the second spends them),
--            else how far along they are with a bar. An item the player has reads OWNED.
--   header   the title, one line of what this is, the Stars balance, close.
-- It opens on the item it was asked for, else the first one the player's Stars can unlock, else the
-- first one they don't have. An unlock (Session.unlocked, however it was bought) flashes its item.
-- It closes from its close button or a press outside the window, never from a press on the window.
-- Signals: closed.
local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local UICtx = require("./UICtx")
local Signal = UITheme.core("Signal")

local IS_ROBLOX = typeof(game) == "Instance"
local function shared(name: string): any
	if IS_ROBLOX then
		return require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data[name]) :: any
	end
	return (require :: any)("../../shared/Data/" .. name)
end
local Catalog = shared("Arsenal")
local Products = shared("Products")
local Prices = require("./Prices")
local ArsenalDemo = require("./ArsenalDemo")
local FrameClock = require("../Map/FrameClock")
local TweenService = if IS_ROBLOX then game:GetService("TweenService") else nil

local Art: any = (function()
	local ok, m = pcall(function()
		if IS_ROBLOX then
			return require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Assets.ArsenalArt)
		end
		return (require :: any)("../../shared/Assets/ArsenalArt")
	end)
	return if ok and type(m) == "table" then m else {}
end)()

local Arsenal = W.class(W.Control)

--- The gold of the window's edge and title (the Coleção's and the Loja Misteriosa's).
local PANEL_GOLD = Color3.fromRGB(236, 190, 92)

--- The list's groups, in order: a heading and the kinds in it.
Arsenal.GROUPS = {
	{ "NUKES", { nuke = true } },
	{ "ARMY", { call = true, structure = true } },
	{ "BOOSTS", { boost = true } },
}
Arsenal.KIND_TAGS = { structure = "BUILDING", nuke = "NUKE", call = "ORDER", boost = "BOOST" }
--- Under the title.
Arsenal.SUBTITLE = "Unlock once, keep it forever. Earn Stars by playing matches."
--- Logical px: the list's width, a row's height, the item's width and its preview's height (desktop);
--- phones put the preview beside the words.
Arsenal.LIST_W = 236
Arsenal.LIST_W_PHONE = 190
Arsenal.ROW_H = 46
Arsenal.ROW_H_PHONE = 38
Arsenal.DETAIL_W = 470
Arsenal.PREVIEW_H = 228
--- The shelf (2026-11-10: the owner asked for a window that does not look like RoWorld's list beside an
--- item): every item is a card in one row across the top, the chosen one fills the room below it,
--- its preview on the left and its words and buttons on the right. Logical px: a card's least width
--- and its height, the height of the picture in it, the gap between two cards.
Arsenal.CARD_W = 104
Arsenal.CARD_H = 112
Arsenal.CARD_ART_H = 58
Arsenal.CARD_W_PHONE = 84
Arsenal.CARD_H_PHONE = 72
Arsenal.CARD_ART_H_PHONE = 30
Arsenal.CARD_GAP = 8
Arsenal.CARD_GAP_PHONE = 6
--- The window's widest and narrowest inside (desktop; phones), and the item's height range.
Arsenal.WIDE = 960
Arsenal.WIDE_PHONE = 760
Arsenal.ITEM_H = 264
Arsenal.ITEM_H_PHONE = 230
--- "3 / 8 UNLOCKED" beside the balance.
Arsenal.COUNT = "%d / %d UNLOCKED"
--- What stands under the preview on desktop: the name, the tags, the sentence and the buttons (with a
--- Robux button; with the currency's button alone).
Arsenal.UNDER_H = 238
Arsenal.UNDER_H_STARS = 186
--- "PRESS AGAIN" stands this long before the Stars button goes back to its price.
Arsenal.CONFIRM_S = 3.0
--- A purchase whose answer never comes gives up after this long (it is still saved on the server).
Arsenal.WAIT_S = 30.0
--- A note under the buttons stays this long.
Arsenal.NOTE_S = 4.0

local FONT_H = Font.fromId(12187365977, Enum.FontWeight.Heavy)
local FONT_B = Font.fromId(12187365977, Enum.FontWeight.Bold)
local FONT_M = Font.fromId(12187365977, Enum.FontWeight.Medium)
local GOLD = Color3.fromRGB(255, 200, 61)
local GOLD_DARK = Color3.fromRGB(64, 40, 4)
-- BUY NOW: its face's gradient (top, bottom; brighter under the pointer), its lip, the ink of its price
local GREEN_TOP = Color3.fromRGB(86, 216, 130)
local GREEN_BOTTOM = Color3.fromRGB(34, 166, 90)
local GREEN_TOP_HI = Color3.fromRGB(108, 234, 150)
local GREEN_BOTTOM_HI = Color3.fromRGB(46, 186, 106)
local GREEN_LIP = Color3.fromRGB(18, 108, 56)
local GREEN_INK = Color3.fromRGB(12, 82, 42)
local OWNED_GREEN = Color3.fromRGB(110, 230, 155)
local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(185, 183, 186)
local ROW = Color3.fromRGB(33, 31, 34)
local ROW_ON = Color3.fromRGB(52, 50, 53)
local CHIP = Color3.fromRGB(52, 50, 53)
local BAR_OFF = Color3.fromRGB(56, 54, 57)
local BAR_LIP = Color3.fromRGB(38, 36, 39)
--- the dark a preview's ground fades into
local NIGHT = Color3.fromRGB(14, 12, 15)
local ROBUX = "rbxasset://textures/ui/common/robux@3x.png"

local function c3(hex: number): Color3
	return Color3.fromRGB((hex // 65536) % 256, (hex // 256) % 256, hex % 256)
end

-- This version's own picture of an item (Assets/ArsenalIcons), drawn into an EditableImage the first
-- time it is asked for (as Locker draws a skin's preview), or nil: outside Roblox, with
-- Data/Brand.OWN_ARSENAL_ICONS off, for an item with no picture, or when the device has no
-- EditableImage to give (the caller then shows RoWorld's render, Assets/ArsenalArt).
local own_icons: { [string]: any } = {}
local function own_icon(key: string): any
	local cached = own_icons[key]
	if cached ~= nil then
		return cached or nil
	end
	if not IS_ROBLOX then
		return nil
	end
	local made: any = false
	pcall(function()
		if shared("Brand").OWN_ARSENAL_ICONS ~= true then
			return
		end
		local Icons = require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Assets.ArsenalIcons) :: any
		local px = Icons.pixels(key)
		if px == nil then
			return
		end
		local n: number = Icons.SIZE
		local img = game:GetService("AssetService"):CreateEditableImage({ Size = Vector2.new(n, n) })
		if img == nil then
			return
		end
		img:WritePixelsBuffer(Vector2.zero, Vector2.new(n, n), px)
		made = img
	end)
	own_icons[key] = made
	return made or nil
end

--- Shows `key`'s own picture in ImageLabel `label`, when there is one. Returns whether it did.
local function show_own_icon(label: ImageLabel, key: string): boolean
	local img = own_icon(key)
	if img == nil then
		return false
	end
	local ok = pcall(function()
		label.ImageContent = Content.fromObject(img)
	end)
	return ok
end

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local i = Instance.new(class)
	for k, v in props do
		(i :: any)[k] = v
	end
	if parent then
		i.Parent = parent
	end
	return i
end

local function tween(inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?)
	if TweenService ~= nil then
		TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
			:Play()
	end
end

--- 12345 -> "12,345".
function Arsenal.commas(n: number): string
	return UICtx.commas(n)
end

--- 20000 -> "20K", 1500 -> "1,500" (a list row's room).
function Arsenal.short(n: number): string
	if n >= 10000 and n % 1000 == 0 then
		return Arsenal.commas(n / 1000) .. "K"
	end
	return Arsenal.commas(n)
end

--- The item the window opens on: `focus`, else the first the player's Stars can unlock, else the first
--- they don't have, else the first.
function Arsenal.pick(inv: any, focus: string?): string
	if focus ~= nil and Catalog.item(focus) ~= nil then
		return focus
	end
	local unlocks = inv.unlocks or {}
	local stars = inv.stars or 0
	for _, it in Catalog.ITEMS do
		if not unlocks[it.key] and it.stars ~= nil and stars >= it.stars then
			return it.key
		end
	end
	for _, it in Catalog.ITEMS do
		if not unlocks[it.key] then
			return it.key
		end
	end
	return Catalog.ITEMS[1].key
end

function Arsenal.new(c: any)
	local self = setmetatable({}, Arsenal.__mt)
	W.Control._init(self)
	self.ctx = c
	self.closed = Signal.new()
	self.is_open = false
	--- the list's rows: key -> parts
	self._rows = {} :: { [string]: any }
	--- the item shown on the right, and its parts
	self._sel = nil :: string?
	self._detail = nil :: any
	--- { key, how = "stars" | "robux", product?, since }: a purchase on its way
	self._pending = nil :: any
	--- key whose Stars button reads "PRESS AGAIN", and until when
	self._confirm = nil :: string?
	self._confirm_until = 0.0
	self._note = nil :: string?
	self._note_until = 0.0
	-- (Roblox's prices arrive a moment after the first look, and move with its price tests)
	self:_connect(Prices.changed:Connect(function()
		if self.is_open then
			self:_refresh()
		end
	end))
	self._focus = nil :: string?
	self._from = "title"
	--- items whose row was pressed this visit (each reported once)
	self._viewed = {} :: { [string]: boolean }
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self:set_mouse_filter(W.MOUSE_STOP)
	self:set_visible(false)
	self._dim = W.ColorRect.new(UITheme.rgba(0.0275, 0.0196, 0.0314, 0.8))
	self._dim:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self._dim.gui_input:Connect(function(e)
		-- (a press on the window's own ground reaches the dim too: only one outside it closes; one
		-- that cancels the purchase's confirmation, above this window, is not for it)
		if
			e.pressed
			and not (self.confirm ~= nil and self.confirm:busy())
			and not self._panel:has_global_point(e.global_position)
		then
			self:close()
		end
	end)
	self:add_child(self._dim)
	-- (the same window as the Coleção and the Loja Misteriosa: dark glass with a gold edge)
	self._panel = GlassPanel.new(22.0, 18.0, 16, true, 34)
	self._panel:set_tint(UITheme.rgba(0.075, 0.063, 0.071, 0.97))
	self._panel.border_color = UITheme.c(PANEL_GOLD, 0.34)
	self:add_child(self._panel)
	local v = UITheme.vbox(12)
	self._v = v
	self._panel:add_child(v)
	-- head: the title, what this is, the Stars balance, close
	local head = UITheme.hbox(12)
	local icon = UITheme.icon_rect("arsenal", 26.0, PANEL_GOLD)
	icon.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(icon)
	local tv = UITheme.vbox(0)
	tv.size_flags_horizontal = W.EXPAND_FILL
	tv.size_flags_vertical = W.SHRINK_CENTER
	local title = UITheme.label("ARSENAL", 22, 800, PANEL_GOLD, 4)
	self._title = title
	tv:add_child(title)
	self._sub = UITheme.label(Arsenal.SUBTITLE, 12, 500, UITheme.TEXT_2)
	tv:add_child(self._sub)
	head:add_child(tv)
	-- how many of them the player has (desktop: a phone has no room for it beside the subtitle)
	local cnt = W.Panel.new()
	cnt:set_mouse_filter(W.MOUSE_IGNORE)
	cnt:add_theme_stylebox_override("panel", UITheme.flat(UITheme.c(OWNED_GREEN, 0.1), 17, UITheme.c(OWNED_GREEN, 0.35), 1, 12.0, 6.0))
	cnt.size_flags_vertical = W.SHRINK_CENTER
	self._count = UITheme.label(string.format(Arsenal.COUNT, 0, #Catalog.ITEMS), 12, 800, OWNED_GREEN, 1)
	self._count.size_flags_vertical = W.SHRINK_CENTER
	cnt:add_child(self._count)
	self._count_pill = cnt
	head:add_child(cnt)
	local bal = W.Panel.new()
	bal:set_mouse_filter(W.MOUSE_IGNORE)
	bal:add_theme_stylebox_override("panel", UITheme.flat(UITheme.c(PANEL_GOLD, 0.1), 17, UITheme.c(PANEL_GOLD, 0.4), 1, 12.0, 6.0))
	bal.size_flags_vertical = W.SHRINK_CENTER
	local bh = UITheme.hbox(6)
	local star = UITheme.icon_rect("star", 16.0, PANEL_GOLD)
	star.size_flags_vertical = W.SHRINK_CENTER
	bh:add_child(star)
	self._balance = UITheme.label("0", 14, 700, UITheme.TEXT)
	self._balance.size_flags_vertical = W.SHRINK_CENTER
	bh:add_child(self._balance)
	bal:add_child(bh)
	self._balance_pill = bal
	head:add_child(bal)
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
	head:add_child(close)
	v:add_child(head)
	-- a gold line under the head, then the shelf of cards, then the chosen item
	local rule = W.ColorRect.new(UITheme.c(PANEL_GOLD, 0.28))
	rule:set_mouse_filter(W.MOUSE_IGNORE)
	rule:set_min_size(Vector2.new(0, 1))
	rule.size_flags_horizontal = W.FILL
	v:add_child(rule)
	local list_host = W.Control.new()
	list_host:set_mouse_filter(W.MOUSE_PASS)
	self._list_host = list_host
	v:add_child(list_host)
	self._list = new("ScrollingFrame", {
		Name = "ArsenalShelf",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = WHITE,
		ScrollBarImageTransparency = 0.6,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollingDirection = Enum.ScrollingDirection.X,
		ZIndex = 40,
	}, list_host.gui)
	self._list_layout = new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, Arsenal.CARD_GAP),
	}, self._list)
	new(
		"UIPadding",
		{ PaddingRight = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingTop = UDim.new(0, 2) },
		self._list
	)
	local detail_host = W.Control.new()
	detail_host:set_mouse_filter(W.MOUSE_PASS)
	self._detail_host = detail_host
	v:add_child(detail_host)
	if IS_ROBLOX then
		game:GetService("MarketplaceService").PromptProductPurchaseFinished:Connect(function(_u, product_id, purchased)
			self:_on_prompt_done(product_id, purchased)
		end)
	end
	return self
end

--- The session's inventory, unlock answers and unlocks (UIRoot.setup, when the session exists).
function Arsenal.bind(self, s: any)
	if s == nil or self._bound == s then
		return
	end
	self._bound = s
	s.inventory_changed:Connect(function()
		if self.is_open then
			self:_refresh()
		end
	end)
	s.unlock_result:Connect(function(key: string, ok: boolean, reason: string?)
		self:_on_unlock_result(key, ok, reason)
	end)
	s.unlocked:Connect(function(key: string)
		self:_on_unlocked(key)
	end)
end

function Arsenal._inv(self): any
	local s = self.ctx.session
	return if s ~= nil and s.inventory ~= nil then s.inventory else { stars = 0, unlocks = {}, loaded = false }
end

function Arsenal._report(self, kind: string, a: any?, b: any?)
	local s = self.ctx.session
	if s ~= nil and type(s.report) == "function" then
		s:report(kind, a, b)
	end
end

--- The Robux price of `it` (Roblox's own once it answered), or nil while its product doesn't exist.
function Arsenal._robux(_self, it: any): number?
	local p = Products[it.product]
	if p == nil or p.id == 0 then
		return nil
	end
	return Prices.robux(it.product)
end

-- ---------------------------------------------------------------------------------------------
-- The list
-- ---------------------------------------------------------------------------------------------

--- A card's width, height, picture height and the gap (logical px) for this layout: the cards share
--- the shelf's width when all of them fit, and scroll sideways when they don't.
function Arsenal._card_geometry(self): (number, number, number, number)
	local compact = self.ctx.compact
	local gap = if compact then Arsenal.CARD_GAP_PHONE else Arsenal.CARD_GAP
	local least = if compact then Arsenal.CARD_W_PHONE else Arsenal.CARD_W
	local n = #Catalog.ITEMS
	local room = (self._detail_size or Vector2.new(Arsenal.WIDE, 0)).X
	local w = math.max(least, math.floor((room - 4 - gap * (n - 1)) / n))
	return w,
		if compact then Arsenal.CARD_H_PHONE else Arsenal.CARD_H,
		if compact then Arsenal.CARD_ART_H_PHONE else Arsenal.CARD_ART_H,
		gap
end

function Arsenal._build_list(self)
	for _, ch in self._list:GetChildren() do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
	table.clear(self._rows)
	local u = UITheme.scale
	local cw, ch, ah, gap = self:_card_geometry()
	self._list_layout.Padding = UDim.new(0, gap * u)
	local order = 0
	-- (group by group, as the headings of the old list did: spells, the army, the boosts)
	for _, g in Arsenal.GROUPS do
		for _, it in Catalog.ITEMS do
			if g[2][it.kind] then
				order += 1
				local r = self:_row(it, order, cw, ch, ah, u)
				r.x = (order - 1) * (cw + gap) * u
				r.w = cw * u
				self._rows[it.key] = r
			end
		end
	end
end

--- One card of the shelf: the item's picture on its own colours, its name, what it takes.
function Arsenal._row(self, it: any, order: number, cw: number, ch: number, ah: number, u: number): any
	local compact = self.ctx.compact
	local b = new("TextButton", {
		Name = "Row_" .. it.key,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = ROW,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = UDim2.fromOffset(cw * u, ch * u),
		ZIndex = 41,
	}, self._list)
	new("UICorner", { CornerRadius = UDim.new(0, 12 * u) }, b)
	local stroke = new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = GOLD,
		Thickness = 2,
		Transparency = 1,
	}, b)
	-- the picture, on the item's two colours
	local top, bottom = c3(it.color[1]), c3(it.color[2])
	local tile = new("Frame", {
		Name = "Tile",
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(5 * u, 5 * u),
		Size = UDim2.new(1, -10 * u, 0, ah * u),
		ZIndex = 42,
	}, b)
	new("UICorner", { CornerRadius = UDim.new(0, 9 * u) }, tile)
	new("UIGradient", {
		Color = ColorSequence.new(top:Lerp(NIGHT, 0.25), bottom:Lerp(NIGHT, 0.62)),
		Rotation = 90,
	}, tile)
	local shot = if type(Art.renders) == "table" then Art.renders[it.key] else nil
	local side = math.floor(ah * 0.9)
	local render = new("ImageLabel", {
		Name = "Render",
		BackgroundTransparency = 1,
		Image = if shot ~= nil then shot.id else (UITheme.icon(it.icon) or ""),
		ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(side * u, side * u),
		ZIndex = 43,
	}, tile)
	-- (this version's own picture over RoWorld's render, when it can be drawn)
	show_own_icon(render, it.key)
	-- (a long name shrinks to fit rather than being cut: "Reinforcements" on a phone)
	local name_fs = math.floor((if compact then 10 else 12) * u)
	local name_h = if compact then 12 else 16
	local y = 5 + ah + (if compact then 3 else 5)
	local name = new("TextLabel", {
		Name = "Name",
		BackgroundTransparency = 1,
		Text = it.title,
		FontFace = FONT_B,
		TextScaled = true,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(5 * u, y * u),
		Size = UDim2.new(1, -10 * u, 0, name_h * u),
		ZIndex = 42,
	}, b)
	new("UITextSizeConstraint", { MaxTextSize = name_fs, MinTextSize = math.floor(name_fs * 0.7) }, name)
	y += name_h + (if compact then 1 else 3)
	-- what it takes: OWNED, ★ 20K, or the Robux price (under the name)
	local price_h = if compact then 14 else 18
	local right = new("Frame", {
		Name = "Price",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, y * u),
		Size = UDim2.new(1, 0, 0, price_h * u),
		ZIndex = 42,
	}, b)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 3 * u),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, right)
	local pic = new("ImageLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset((if compact then 11 else 13) * u, (if compact then 11 else 13) * u),
		LayoutOrder = 1,
		ZIndex = 43,
	}, right)
	local tx = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT_H,
		TextSize = math.floor((if compact then 10 else 12) * u),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, price_h * u),
		LayoutOrder = 2,
		ZIndex = 43,
	}, right)
	-- the chosen card stands on a gold bar
	local mark = new("Frame", {
		Name = "Mark",
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 4 * u),
		Size = UDim2.new(0.4, 0, 0, 3 * u),
		Visible = false,
		ZIndex = 42,
	}, b)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, mark)
	b.MouseEnter:Connect(function()
		if self._sel ~= it.key then
			b.BackgroundColor3 = ROW:Lerp(ROW_ON, 0.5)
		end
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = if self._sel == it.key then ROW_ON else ROW
	end)
	b.Activated:Connect(function()
		self:_select(it.key, true)
	end)
	return { button = b, stroke = stroke, name = name, icon = pic, text = tx, mark = mark, tile = tile }
end

--- Scrolls the shelf so the chosen card is whole (a phone too narrow for all of them).
function Arsenal._reveal(self, key: string)
	local r = self._rows[key]
	if r == nil or r.x == nil then
		return
	end
	pcall(function()
		local view = self._list.AbsoluteSize.X
		local at = self._list.CanvasPosition.X
		if view <= 0 then
			return
		end
		if r.x < at then
			self._list.CanvasPosition = Vector2.new(math.max(0, r.x - 8), 0)
		elseif r.x + r.w > at + view then
			self._list.CanvasPosition = Vector2.new(r.x + r.w - view + 8, 0)
		end
	end)
end

function Arsenal._refresh_list(self)
	local inv = self:_inv()
	local stars = inv.stars or 0
	for key, r in self._rows do
		local it = Catalog.item(key)
		local on = self._sel == key
		r.button.BackgroundColor3 = if on then ROW_ON else ROW
		r.stroke.Transparency = if on then 0 else 1
		r.mark.Visible = on
		r.name.TextColor3 = if on then GOLD else WHITE
		-- (what the player doesn't have yet is a little darker than what is theirs or chosen)
		r.tile.BackgroundColor3 = if on or inv.unlocks[key] then WHITE else Color3.fromRGB(205, 205, 205)
		if inv.unlocks[key] then
			r.icon.Visible = false
			r.text.Text = "OWNED"
			r.text.TextColor3 = OWNED_GREEN
		elseif it.stars ~= nil and stars >= it.stars then
			r.icon.Visible = true
			r.icon.Image = UITheme.icon("star") or ""
			r.icon.ImageColor3 = GOLD
			r.text.Text = Arsenal.short(it.stars)
			r.text.TextColor3 = GOLD
		else
			local price = self:_robux(it)
			if price == nil and it.stars ~= nil then
				-- no Robux product (this version sells nothing): its price in the currency, dimmed
				-- until the player has that much
				r.icon.Visible = true
				r.icon.Image = UITheme.icon("star") or ""
				r.icon.ImageColor3 = MUTED
				r.text.Text = Arsenal.short(it.stars)
				r.text.TextColor3 = MUTED
			else
				r.icon.Visible = price ~= nil
				r.icon.Image = ROBUX
				r.icon.ImageColor3 = WHITE
				r.text.Text = if price ~= nil then Arsenal.commas(price) else "SOON"
				r.text.TextColor3 = WHITE
			end
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- The item
-- ---------------------------------------------------------------------------------------------

--- The item's area in logical px for this layout: its width, its height, whether the preview sits
--- beside the words (phones) and the preview's size.
function Arsenal._detail_geometry(self): (number, number, boolean, Vector2)
	local size = self._detail_size or Vector2.new(Arsenal.WIDE, Arsenal.ITEM_H)
	-- (the preview stands beside the words on every screen: the shelf took the list's column)
	local side = true
	local pv = if self.ctx.compact
		then Vector2.new(math.floor(math.min(size.X * 0.42, size.Y * 1.25)), size.Y)
		else Vector2.new(math.floor(math.min(size.X * 0.52, size.Y * 1.9)), size.Y)
	return size.X, size.Y, side, pv
end

function Arsenal._build_detail(self)
	if self._detail ~= nil then
		if self._detail.demo ~= nil then
			self._detail.demo:destroy()
		end
		self._detail.root:Destroy()
		self._detail = nil
	end
	local it = Catalog.item(self._sel or "")
	if it == nil then
		return
	end
	local u = UITheme.scale
	local compact = self.ctx.compact
	local dw, dh, side, pv = self:_detail_geometry()
	local root = new("Frame", {
		Name = "ArsenalItem",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(dw * u, dh * u),
		ZIndex = 40,
	}, self._detail_host.gui)
	-- the preview: what it does in a match (ArsenalDemo), its render a sticker in the corner
	local pw, ph = pv.X * u, pv.Y * u
	local ground = new("CanvasGroup", {
		Name = "Preview",
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(pw, ph),
		ZIndex = 41,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(0, 12 * u) }, ground)
	local top, bottom = c3(it.color[1]), c3(it.color[2])
	local grad = new("UIGradient", {
		Color = ColorSequence.new(top:Lerp(NIGHT, 0.42), bottom:Lerp(NIGHT, 0.8)),
		Rotation = 90,
	}, ground)
	local demo = if ArsenalDemo["_build_" .. it.key] ~= nil
		then ArsenalDemo.new(ground, it, Vector2.new(pw, ph), u, 0, root, 12 * u)
		else nil
	if demo ~= nil then
		grad.Enabled = false -- (a gradient on a CanvasGroup tints everything in it)
		if demo:has_map() then
			-- (the map lies under the group: ArsenalDemo._map)
			ground.BackgroundTransparency = 1
		end
	end
	local shot = if type(Art.renders) == "table" then Art.renders[it.key] else nil
	local image = if shot ~= nil then shot.id else (UITheme.icon(it.icon) or "")
	local sh = (if demo ~= nil then 0.36 else 0.8) * ph
	-- (this version's own pictures are square)
	local own = own_icon(it.key) ~= nil
	local sw = if own then sh elseif shot ~= nil then sh * shot.w / shot.h else sh * 0.6
	local max_w = pw * (if demo ~= nil then 0.28 else 0.8)
	if sw > max_w then
		sh *= max_w / sw
		sw = max_w
	end
	local sticker = new("ImageLabel", {
		Name = "Render",
		BackgroundTransparency = 1,
		Image = image,
		AnchorPoint = if demo ~= nil then Vector2.new(0, 0) else Vector2.new(0.5, 0.5),
		Position = if demo ~= nil then UDim2.fromOffset(8 * u, 6 * u) else UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(sw, sh),
		ZIndex = 45,
	}, root)
	if own then
		show_own_icon(sticker, it.key)
	end
	local flash = new("Frame", {
		Name = "Flash",
		BackgroundColor3 = top,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(pw, ph),
		ZIndex = 49,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(0, 12 * u) }, flash)
	-- the words: beside the preview on phones, under it otherwise
	local x0 = if side then pv.X + (if compact then 14 else 20) else 0
	local y0 = if side then 0 else pv.Y + 12
	local tw = if side then dw - x0 else dw
	local col = new("Frame", {
		Name = "Words",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x0 * u, y0 * u),
		Size = UDim2.fromOffset(tw * u, (dh - y0) * u),
		ZIndex = 41,
	}, root)
	local y = 0
	local name_fs = if compact then 18 else 24
	new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Text = string.upper(it.title),
		FontFace = FONT_H,
		TextSize = math.floor(name_fs * u),
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, y * u),
		Size = UDim2.new(1, 0, 0, (name_fs + 4) * u),
		ZIndex = 42,
	}, col)
	y += name_fs + 6
	-- what kind of thing it is, and that it's forever
	local chips = new("Frame", {
		Name = "Chips",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, y * u),
		Size = UDim2.new(1, 0, 0, 20 * u),
		ZIndex = 42,
	}, col)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6 * u),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, chips)
	local function chip(text: string, color: Color3, order: number)
		local l = new("TextLabel", {
			BackgroundColor3 = CHIP,
			Text = text,
			FontFace = FONT_B,
			TextSize = math.floor(10 * u),
			TextColor3 = color,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20 * u),
			LayoutOrder = order,
			ZIndex = 43,
		}, chips)
		new("UICorner", { CornerRadius = UDim.new(0, 6 * u) }, l)
		new("UIPadding", { PaddingLeft = UDim.new(0, 8 * u), PaddingRight = UDim.new(0, 8 * u) }, l)
	end
	-- (phones: the facts only; the list's headings say what kind it is, the subtitle that it's forever)
	if not compact then
		chip(Arsenal.KIND_TAGS[it.kind] or "", WHITE, 1)
		chip("FOREVER", OWNED_GREEN, 2)
	end
	for i, f in it.facts or {} do
		chip(string.upper(f), GOLD, 2 + i)
	end
	y += 28
	-- the one sentence
	local plain_fs = if compact then 12 else 14
	local plain_h = (plain_fs + 4) * 2
	new("TextLabel", {
		Name = "Plain",
		BackgroundTransparency = 1,
		Text = it.plain or it.tagline,
		FontFace = FONT_M,
		TextSize = math.floor(plain_fs * u),
		TextColor3 = Color3.fromRGB(224, 222, 225),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, y * u),
		Size = UDim2.new(1, 0, 0, plain_h * u),
		ZIndex = 42,
	}, col)
	y += plain_h + (if compact then 6 else 12)
	-- how to get it (rebuilt on every refresh: _build_cta)
	local cta = new("Frame", {
		Name = "Get",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, y * u),
		Size = UDim2.new(1, 0, 1, -y * u),
		ZIndex = 42,
	}, col)
	self._detail = {
		key = it.key,
		root = root,
		demo = demo,
		sticker = sticker,
		flash = flash,
		cta = cta,
		width = tw,
		col = col,
		words_h = y,
		room_h = dh - y0,
	}
	self:_build_cta()
end

--- A full-width button at `y` (logical px), `h` tall; its row lays out the words and icons. Returns its parts.
local function button(
	parent: Instance,
	name: string,
	y: number,
	h: number,
	u: number,
	fill: Color3,
	stroke: Color3?
): any
	local b = new("TextButton", {
		Name = name,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = fill,
		-- (outlined: a faint wash of its colour, so it doesn't read as a hole)
		BackgroundTransparency = if stroke ~= nil then 0.9 else 0,
		BorderSizePixel = 0,
		-- (anchored at its centre: the hover and press scale grow from there)
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, y * u),
		Size = UDim2.new(1, 0, 0, h * u),
		ZIndex = 43,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 12 * u) }, b)
	if stroke ~= nil then
		new("UIStroke", { Color = stroke, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	end
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 44 }, b)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6 * u),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	local s = new("UIScale", {}, b)
	b.MouseEnter:Connect(function()
		tween(s, 0.1, { Scale = 1.02 })
	end)
	b.MouseLeave:Connect(function()
		tween(s, 0.1, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		tween(s, 0.06, { Scale = 0.97 })
	end)
	b.MouseButton1Up:Connect(function()
		tween(s, 0.1, { Scale = 1 })
	end)
	return { button = b, row = row, scale = s }
end

--- BUY NOW (2026-10-24: the Robux buy buttons looked poor and needed a polish; it
--- was a flat green bar, BUY NOW, the Robux glyph and the price run together in the middle): a raised
--- face, a green gradient with a sheen, over a darker lip it sinks onto when pressed; BUY NOW on the
--- left and the price in a pill of its own on the right. `price` nil: SOON, grey; `busy`: "..." alone.
local function buy_button(
	parent: Instance,
	y: number,
	h: number,
	u: number,
	price: number?,
	busy: boolean,
	fs: number
): any
	local on = price ~= nil
	local lip = math.max(3, math.floor(4 * u + 0.5))
	local hh = math.floor(h * u + 0.5)
	local r = UDim.new(0, 12 * u)
	local b = new("TextButton", {
		Name = "Buy",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, y * u),
		Size = UDim2.new(1, 0, 0, hh + lip),
		ZIndex = 43,
	}, parent)
	local under = new("Frame", {
		Name = "Lip",
		BackgroundColor3 = if on then GREEN_LIP else BAR_LIP,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, lip),
		Size = UDim2.new(1, 0, 0, hh),
		ZIndex = 43,
	}, b)
	new("UICorner", { CornerRadius = r }, under)
	local face = new("Frame", {
		Name = "Face",
		BackgroundColor3 = if on then WHITE else BAR_OFF,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, hh),
		ZIndex = 44,
	}, b)
	new("UICorner", { CornerRadius = r }, face)
	local grad = new("UIGradient", {
		Color = ColorSequence.new(GREEN_TOP, GREEN_BOTTOM),
		Rotation = 90,
		Enabled = on,
	}, face)
	new("UIStroke", {
		Color = if on then GREEN_LIP else BAR_LIP,
		Thickness = 1,
		Transparency = 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, face)
	if on then
		-- a sheen over its top
		local sheen = new("Frame", {
			Name = "Sheen",
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(4 * u, 3 * u),
			Size = UDim2.new(1, -8 * u, 0.4, 0),
			ZIndex = 45,
		}, face)
		new("UICorner", { CornerRadius = UDim.new(0, 9 * u) }, sheen)
	end
	local label = new("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Text = if busy then "..." elseif on then "BUY NOW" else "SOON",
		FontFace = FONT_H,
		TextSize = math.floor(fs * u),
		TextColor3 = if on then WHITE else MUTED,
		TextXAlignment = if busy or not on then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(18 * u, 0),
		Size = UDim2.new(1, -36 * u, 1, 0),
		ZIndex = 46,
	}, face)
	if on then
		new("UIStroke", { Color = GREEN_INK, Thickness = 1.5, Transparency = 0.55 }, label)
	end
	if on and not busy then
		local pill = new("Frame", {
			Name = "Price",
			BackgroundColor3 = GREEN_INK,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -7 * u, 0.5, 0),
			Size = UDim2.fromOffset(0, hh - 14 * u),
			AutomaticSize = Enum.AutomaticSize.X,
			ZIndex = 46,
		}, face)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, pill)
		new("UIPadding", { PaddingLeft = UDim.new(0, 10 * u), PaddingRight = UDim.new(0, 12 * u) }, pill)
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 5 * u),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, pill)
		new("ImageLabel", {
			Name = "Robux",
			BackgroundTransparency = 1,
			Image = ROBUX,
			Size = UDim2.fromOffset(math.floor((fs + 1) * u), math.floor((fs + 1) * u)),
			LayoutOrder = 1,
			ZIndex = 47,
		}, pill)
		new("TextLabel", {
			Name = "Amount",
			BackgroundTransparency = 1,
			Text = Arsenal.commas(price :: number),
			FontFace = FONT_H,
			TextSize = math.floor(fs * u),
			TextColor3 = WHITE,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, hh - 14 * u),
			LayoutOrder = 2,
			ZIndex = 47,
		}, pill)
	end
	-- under the pointer it brightens; pressed, it sinks onto its lip
	local function lift(down: boolean)
		tween(face, if down then 0.05 else 0.1, { Position = UDim2.fromOffset(0, if down then lip - 1 else 0) })
	end
	b.MouseEnter:Connect(function()
		if on then
			grad.Color = ColorSequence.new(GREEN_TOP_HI, GREEN_BOTTOM_HI)
		end
	end)
	b.MouseLeave:Connect(function()
		grad.Color = ColorSequence.new(GREEN_TOP, GREEN_BOTTOM)
		lift(false)
	end)
	b.MouseButton1Down:Connect(function()
		if on then
			lift(true)
		end
	end)
	b.MouseButton1Up:Connect(function()
		lift(false)
	end)
	return { button = b, face = face, lip = lip }
end

local function words(row: Instance, text: string, size: number, color: Color3, u: number, order: number, h: number)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		FontFace = FONT_H,
		TextSize = math.floor(size * u),
		TextColor3 = color,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, h * u),
		LayoutOrder = order,
		ZIndex = 45,
	}, row)
end

local function pic(row: Instance, image: string, size: number, color: Color3, u: number, order: number)
	return new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = image,
		ImageColor3 = color,
		Size = UDim2.fromOffset(size * u, size * u),
		LayoutOrder = order,
		ZIndex = 45,
	}, row)
end

--- How to get the item shown: OWNED, or BUY NOW with Robux and under it the Stars way.
function Arsenal._build_cta(self)
	local d = self._detail
	if d == nil then
		return
	end
	for _, ch in d.cta:GetChildren() do
		ch:Destroy()
	end
	local it = Catalog.item(d.key)
	local u = UITheme.scale
	local compact = self.ctx.compact
	local inv = self:_inv()
	local stars = inv.stars or 0
	local pending = self._pending
	local busy = pending ~= nil and pending.key == it.key
	local bh = if compact then 38 else 48
	local sh = if compact then 30 else 36
	local y = 0
	if inv.unlocks[it.key] then
		local own = button(d.cta, "Owned", y, bh, u, OWNED_GREEN, OWNED_GREEN)
		pic(own.row, UITheme.icon("check") or "", 18, OWNED_GREEN, u, 1)
		words(own.row, "OWNED", if compact then 15 else 17, OWNED_GREEN, u, 2, bh)
		own.button.Active = false
		y += bh + 8
		self:_line(
			d.cta,
			y,
			if it.kind == "boost" then "It's always on, in every match." else "It's in your build bar in every match.",
			MUTED
		)
		self:_center_words(y + 20)
		return
	end
	-- BUY NOW with Robux, where its product exists (this version has none: the currency earned
	-- by playing is then the only way, and its button is the big one)
	local price = self:_robux(it)
	local sells = price ~= nil
	if sells then
		local buy = buy_button(d.cta, y, bh, u, price, busy and pending.how == "robux", if compact then 15 else 18)
		buy.button.Activated:Connect(function()
			self:_robux_pressed(it)
		end)
		d.buy = buy
		y += bh + buy.lip / u + 8
	else
		sh = bh
	end
	-- the other way: Stars
	if it.stars == nil then
		self:_line(d.cta, y, if sells then "Robux only." else "Not available yet.", MUTED)
		y += 18
	elseif stars >= it.stars then
		local confirm = self._confirm == it.key
		local alt = button(d.cta, "Stars", y, sh, u, GOLD, if confirm then nil else GOLD)
		local col = if confirm then GOLD_DARK else GOLD
		local wfs = if sells then (if compact then 12 else 14) else (if compact then 13 else 15)
		if busy and pending.how == "stars" then
			words(alt.row, "...", wfs, col, u, 1, sh)
		elseif confirm then
			words(alt.row, "PRESS AGAIN TO SPEND", wfs, col, u, 1, sh)
			pic(alt.row, UITheme.icon("star") or "", 15, col, u, 2)
			words(alt.row, Arsenal.commas(it.stars), wfs, col, u, 3, sh)
		else
			words(alt.row, if sells then "OR UNLOCK WITH" else "UNLOCK WITH", wfs, col, u, 1, sh)
			pic(alt.row, UITheme.icon("star") or "", 15, col, u, 2)
			words(alt.row, Arsenal.commas(it.stars), wfs, col, u, 3, sh)
		end
		alt.button.Activated:Connect(function()
			self:_stars_pressed(it)
		end)
		y += sh + 8
	else
		-- how far along: "Or earn it by playing: ★ 12,400 of 20,000", and a bar
		local row = new("Frame", {
			Name = "Earn",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, y * u),
			Size = UDim2.new(1, 0, 0, 16 * u),
			ZIndex = 43,
		}, d.cta)
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4 * u),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, row)
		local fs = if compact then 11 else 12
		new("TextLabel", {
			BackgroundTransparency = 1,
			Text = if sells then "Or earn it by playing:" else "Earn it by playing:",
			FontFace = FONT_M,
			TextSize = math.floor(fs * u),
			TextColor3 = MUTED,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 16 * u),
			LayoutOrder = 1,
			ZIndex = 44,
		}, row)
		pic(row, UITheme.icon("star") or "", 12, GOLD, u, 2)
		new("TextLabel", {
			BackgroundTransparency = 1,
			Text = string.format("%s of %s", Arsenal.commas(stars), Arsenal.commas(it.stars)),
			FontFace = FONT_B,
			TextSize = math.floor(fs * u),
			TextColor3 = GOLD,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 16 * u),
			LayoutOrder = 3,
			ZIndex = 44,
		}, row)
		y += 20
		local bar = new("Frame", {
			Name = "Bar",
			BackgroundColor3 = BAR_OFF,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, y * u),
			Size = UDim2.new(1, 0, 0, 8 * u),
			ZIndex = 43,
		}, d.cta)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, bar)
		local fill = new("Frame", {
			BackgroundColor3 = GOLD,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(math.clamp(stars / it.stars, 0.02, 1), 1),
			ZIndex = 44,
		}, bar)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, fill)
		y += 16
	end
	-- a note about the last press
	if self._note ~= nil and os.clock() < self._note_until then
		self:_line(d.cta, y, self._note, self._note_color or GOLD)
	end
	self:_center_words(y)
end

--- Desktop: the item's words and buttons (`used` logical px of buttons) stand in the middle of the
--- preview's height rather than hanging from its top with an empty band under them. A note's line
--- keeps its room.
function Arsenal._center_words(self, used: number)
	local d = self._detail
	if d == nil or d.col == nil or self.ctx.compact then
		return
	end
	local spare = d.room_h - d.words_h - used - 24
	local p = d.col.Position
	d.col.Position = UDim2.new(p.X.Scale, p.X.Offset, 0, math.max(0, math.floor(spare * 0.5)) * UITheme.scale)
end

--- A line of small text in the "how to get it" area, at `y` (logical px).
function Arsenal._line(self, parent: Instance, y: number, text: string, color: Color3)
	local u = UITheme.scale
	new("TextLabel", {
		Name = "Line",
		BackgroundTransparency = 1,
		Text = text,
		FontFace = FONT_M,
		TextSize = math.floor((if self.ctx.compact then 11 else 12) * u),
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, y * u),
		Size = UDim2.new(1, 0, 0, 30 * u),
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 44,
	}, parent)
end

--- Show item `key` on the right. `by_player`: a press on its row (reported).
function Arsenal._select(self, key: string, by_player: boolean?)
	if Catalog.item(key) == nil then
		return
	end
	if key ~= self._sel then
		self._sel = key
		self._confirm = nil
		self._note = nil
		self:_build_detail()
		if by_player then
			self.ctx:sfx("tab", -4.0)
			if not self._viewed[key] then
				self._viewed[key] = true
				self:_report("arsenal_view", key)
			end
		end
	end
	self:_refresh_list()
	self:_reveal(key)
end

--- The list's prices, the balance, and the item's buttons, from the inventory and what's pending.
function Arsenal._refresh(self)
	local inv = self:_inv()
	self._balance:set_text(Arsenal.commas(inv.stars or 0))
	local have = 0
	for _, it in Catalog.ITEMS do
		if inv.unlocks[it.key] then
			have += 1
		end
	end
	self._count:set_text(string.format(UITheme.tr(Arsenal.COUNT), have, #Catalog.ITEMS))
	self:_refresh_list()
	self:_build_cta()
end

--- A note under the item's buttons for a moment (the last press: not enough Stars, PRESS AGAIN...).
function Arsenal._say(self, text: string, color: any?)
	self._note = text
	self._note_color = if typeof(color) == "Color3"
		then color
		elseif color ~= nil then UITheme.color3(UITheme.to_rgba(color))
		else nil
	self._note_until = os.clock() + Arsenal.NOTE_S
	self:_build_cta()
end

function Arsenal._rebuild(self)
	self:_build_list()
	self:_build_detail()
	self:_refresh()
end

-- ---------------------------------------------------------------------------------------------
-- Buying
-- ---------------------------------------------------------------------------------------------

--- The Coroas button of `it`. The player is asked once more before anything is spent: in a window
--- (UI/ConfirmBuy, `self.confirm`: UIRoot sets it; 2026-11-11; `confirmed`: they said yes there), or,
--- with no such window, by a second press on the same button within CONFIRM_S (RoWorld's way: a
--- double click by accident passed it).
function Arsenal._stars_pressed(self, it: any, confirmed: boolean?)
	local inv = self:_inv()
	if self._pending ~= nil or inv.unlocks[it.key] or it.stars == nil then
		return
	end
	if (inv.stars or 0) < it.stars then
		self.ctx:sfx("deny", -4.0)
		local short = Arsenal.commas(it.stars - (inv.stars or 0))
		self:_say(string.format("%s more Stars to go. Play matches to earn them.", short), GOLD)
		return
	end
	if self.confirm ~= nil then
		if not confirmed then
			-- (everything above is checked again when they confirm)
			self._confirm = nil
			self.ctx:sfx("tab")
			self.confirm:ask({
				owner = self,
				what = it.title,
				price = it.stars,
				balance = inv.stars or 0,
			}, function()
				self:_stars_pressed(it, true)
			end)
			return
		end
	elseif self._confirm ~= it.key or os.clock() > self._confirm_until then
		-- the first press asks once more
		self._confirm = it.key
		self._confirm_until = os.clock() + Arsenal.CONFIRM_S
		self.ctx:sfx("tab")
		self:_build_cta()
		return
	end
	self._confirm = nil
	local s = self.ctx.session
	if s == nil or not s:buy_unlock(it.key) then
		self.ctx:sfx("deny")
		self:_say("Couldn't reach the server. Try again in a moment.", UITheme.RED)
		return
	end
	self:_report("arsenal_click", it.key, "stars")
	self.ctx:sfx("buy")
	self._pending = { key = it.key, how = "stars", since = os.clock() }
	self:_refresh()
end

function Arsenal._robux_pressed(self, it: any)
	local inv = self:_inv()
	local p = Products[it.product]
	if self._pending ~= nil or inv.unlocks[it.key] then
		return
	end
	if p == nil or p.id == 0 or not IS_ROBLOX then
		self.ctx:sfx("deny", -4.0)
		self:_say(it.title .. " isn't on sale for Robux yet.", MUTED)
		return
	end
	self._confirm = nil
	self:_report("arsenal_click", it.key, "robux")
	self.ctx:sfx("confirm")
	self._pending = { key = it.key, how = "robux", product = p.id, phase = "prompt", since = os.clock() }
	self:_refresh()
	local ok = pcall(function()
		game:GetService("MarketplaceService"):PromptProductPurchase(game:GetService("Players").LocalPlayer, p.id)
	end)
	if not ok then
		self._pending = nil
		self:_say("Purchases aren't available right now.", UITheme.RED)
		self:_refresh()
	end
end

function Arsenal._on_prompt_done(self, product_id: number, purchased: boolean)
	local p = self._pending
	if p == nil or p.how ~= "robux" or p.phase ~= "prompt" or p.product ~= product_id then
		return
	end
	if not purchased then
		self._pending = nil
		if self.is_open then
			self:_refresh()
		end
		return
	end
	-- bought: the server's receipt unlocks it and the inventory says so (Session.unlocked)
	p.phase = "granting"
	p.since = os.clock()
	if self:_inv().unlocks[p.key] then
		self:_on_unlocked(p.key)
	end
end

function Arsenal._on_unlock_result(self, key: string, ok: boolean, reason: string?)
	local p = self._pending
	if p == nil or p.key ~= key or p.how ~= "stars" then
		return
	end
	if ok then
		return -- (the inventory follows: Session.unlocked flashes the item)
	end
	self._pending = nil
	self.ctx:sfx("deny")
	self:_say(
		if reason == "not enough"
			then "Not enough Stars."
			elseif reason == "owned" then "You already have it."
			else "Couldn't unlock it. Nothing was spent. Try again in a moment.",
		UITheme.RED
	)
	self:_refresh()
end

--- An item was unlocked (however it was bought): it shows, flashing.
function Arsenal._on_unlocked(self, key: string)
	local p = self._pending
	if p ~= nil and p.key == key then
		self._pending = nil
	end
	if not self.is_open then
		return
	end
	local it = Catalog.item(key)
	self.ctx:sfx("unlock")
	self:_select(key, false)
	self:_say(string.upper(it.title) .. " UNLOCKED!", GOLD)
	self:_refresh()
	local d = self._detail
	if d ~= nil and d.key == key then
		d.flash.BackgroundTransparency = 0.15
		tween(d.flash, 0.7, { BackgroundTransparency = 1 })
		d.kick_t = os.clock()
	end
end

--- Every frame while open (UIRoot._process): the item's scene plays; a just-unlocked render rocks.
function Arsenal.frame(self, _delta: number?)
	local d = self._detail
	if d == nil then
		return
	end
	local now = FrameClock.now()
	if d.demo ~= nil then
		d.demo:step(now)
	end
	local rot = 0
	if d.kick_t ~= nil then
		local k = (os.clock() - d.kick_t) / 0.6
		if k >= 1 then
			d.kick_t = nil
		else
			rot = -14 * (1 - k) ^ 2 * math.cos(k * math.pi * 2.5)
		end
	end
	d.sticker.Rotation = rot
end

--- Once a second while open: "PRESS AGAIN" runs out, a purchase that never answers gives up, a note goes.
function Arsenal.tick(self)
	local now = os.clock()
	local again = false
	if self._confirm ~= nil and now > self._confirm_until then
		self._confirm = nil
		again = true
	end
	local p = self._pending
	if p ~= nil and p.phase ~= "prompt" and now - p.since > Arsenal.WAIT_S then
		self._pending = nil
		self:_say("That's taking a while. If you paid, it's saved and will show up shortly.", MUTED)
		again = true
	end
	if self._note ~= nil and now >= self._note_until then
		self._note = nil
		again = true
	end
	if again then
		self:_refresh()
	end
end

-- ---------------------------------------------------------------------------------------------
-- Open / close / layout
-- ---------------------------------------------------------------------------------------------

--- `focus`: an item key to show (a locked unit pressed in a match); `from`: where it was opened from
--- ("title" / "match" / "locked" / "over" / "offer": the result screen's own offers), for the analytics.
function Arsenal.open(self, focus: string?, from: string?)
	self._focus = if focus ~= nil and Catalog.item(focus) ~= nil then focus else nil
	self._from = from or "title"
	self._confirm = nil
	self._note = nil
	if not self.is_open then
		self.is_open = true
		table.clear(self._viewed)
		self:_report("arsenal_shop", self._from)
		self:set_visible(true)
		self._panel:set_modulate_a(1.0)
		self._dim:set_modulate_a(0.0)
		W.fade(self._dim, 1.0, 0.2)
		UICtx.pop_in(self._panel, 0.0, 0.94, 0.3)
		self.ctx:sfx("open")
	end
	Prices.fetch()
	ArsenalDemo.preload()
	self._sel = Arsenal.pick(self:_inv(), self._focus)
	self:apply_layout()
end

function Arsenal.close(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	-- (a purchase waiting for its confirmation goes with the window: nothing is bought)
	if self.confirm ~= nil then
		self.confirm:cancel(self)
	end
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

function Arsenal.apply_layout(self)
	local ctx = self.ctx
	local area = ctx:clear_rect()
	local compact = ctx.compact
	-- (phones: slimmer edges, the preview beside the words)
	self._panel:set_padding(
		if compact then 14 else 22,
		if compact then 10 else 18,
		if compact then 14 else 22,
		if compact then 10 else 18
	)
	self._title:set_font_size(if compact then 15 else 22)
	self._v:set_separation(if compact then 8 else 12)
	self._sub.base_fs = if compact then 10 else 12
	self._sub:set_font_size(math.max(self._sub.base_fs, UITheme.min_font_size))
	self._count_pill:set_visible(not compact)
	local card_h = if compact then Arsenal.CARD_H_PHONE else Arsenal.CARD_H
	-- (the shelf: its cards, the gold bar under the chosen one, a sideways scroll bar's room)
	local shelf_h = card_h + 12
	local gap = if compact then 8 else 12
	local chrome_h = (if compact then 34 + 20 else 40 + 36) + (1 + gap) + (shelf_h + gap) + gap
	local body_h = math.floor(area.Height - chrome_h - 8)
	local dw, dh
	if compact then
		dw = math.clamp(area.Width - 28 - 24, 300, Arsenal.WIDE_PHONE)
		dh = math.clamp(body_h, 150, Arsenal.ITEM_H_PHONE)
	else
		dw = math.clamp(area.Width - 44 - 40, 560, Arsenal.WIDE)
		dh = math.clamp(body_h, 236, Arsenal.ITEM_H)
	end
	self._detail_size = Vector2.new(dw, dh)
	self._list_host:set_min_size(Vector2.new(dw, shelf_h))
	self._detail_host:set_min_size(Vector2.new(dw, dh))
	if self.is_open then
		if self._sel == nil then
			self._sel = Arsenal.pick(self:_inv(), self._focus)
		end
		self:_rebuild()
	end
	local sz = self._panel:get_combined_minimum_size()
	local p = area.Min + (Vector2.new(area.Width, area.Height) - sz) * 0.5
	local y = math.max(p.Y, area.Min.Y + 4.0)
	local rp = Vector2.new(math.floor(p.X + 0.5), math.floor(y + 0.5))
	self._panel:set_offsets(rp.X, rp.Y, rp.X, rp.Y)
	self._panel:reset_size()
end

return Arsenal
