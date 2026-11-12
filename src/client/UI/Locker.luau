--!nonstrict
-- The Coleção (the "Locker"): what the player owns to wear in a match, in three tabs, and each tab's
-- own crate.
--   head        the title, how the player's name will look in a match (flag on the left of the name,
--               pet on the right), their balance, close.
--   tabs        Skins / Flags / Pets, each with how many of its items the player owns.
--   grid        the tab's items (owned first, rarest first; the rest dimmed, as a preview of what the
--               crate can give); press an owned one to wear it, "None" to wear nothing.
--   crate       the tab's crate, on the right: an item of that tab the player doesn't own yet. Shown
--               before any purchase: the player's own chance of each rarity (Cosmetics.odds; Roblox's
--               rules for random items). One crate a purchase (Locker.CRATE_MAX), paid with
--                 Coroas  for everyone: Session.buy_crates, Data/MyShop.caixa.coroas;
--                 Robux   beside it, only where Roblox lets this player buy paid random items
--                         (Session.inventory.crates_allowed: the server asks PolicyService): one
--                         purchase of Data/Products.crate. While the product has no id the button
--                         says so and sells nothing.
--               A crate bought opens at once, as a crate of the tab it was bought in. One whose
--               opening failed (or bought before 2026-11-10, several at a time) waits as a credit:
--               OPEN CRATE opens it as a crate of the tab in view.
--   reveal      the opening show (CrateOpening): the item in its rarity's colour, Wear / Next / Done.
-- Signals: closed.
local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local ChestView = require("./ChestView")
local UICtx = require("./UICtx")
local Signal = UITheme.core("Signal")

local IS_ROBLOX = typeof(game) == "Instance"
local function shared(name: string): any
	if IS_ROBLOX then
		return require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data[name]) :: any
	end
	return (require :: any)("../../shared/Data/" .. name)
end
local Cosmetics = shared("Cosmetics")
local Products = shared("Products")
local MyShop = shared("MyShop")
local Prices = require("./Prices")

local Locker = W.class(W.Control)

--- name, the slot (Cosmetics.KINDS), the crate's title, what it gives, "you own them all", and what
--- it gives when a crate may roll a duplicate (Cosmetics.DUPLICATES; 2026-11-12)
Locker.TABS = {
	{ "Skins", "skin", "SKIN CRATE", "A territory skin you don't own yet", "You own every skin.", "A territory skin. A duplicate pays Stars instead." },
	{ "Flags", "flag", "FLAG CRATE", "A flag you don't own yet", "You own every flag.", "A flag. A duplicate pays Stars instead." },
	{ "Pets", "pet", "PET CRATE", "A pet you don't own yet", "You own every pet.", "A pet. A duplicate pays Stars instead." },
}
Locker.CARD = { skin = Vector2.new(112, 132), flag = Vector2.new(122, 118), pet = Vector2.new(112, 132) }
Locker.GRID_SIZE = Vector2.new(640, 440)
Locker.CRATE_W = 268
--- the colour skins are previewed in (the player's own varies by match)
Locker.PREVIEW_COLOR = Color3.fromRGB(64, 132, 230)
Locker.PREVIEW_TILES = 24
Locker.CREDIT_WAIT_S = 30
--- a crate's price in Coroas (Data/MyShop.caixa)
Locker.CRATE_STARS = math.max(1, math.floor(tonumber(MyShop.caixa and MyShop.caixa.coroas) or 10000))
--- One crate a purchase (2026-11-10: there was a "how many" row, 1 to 10. The first crate opened in
--- the tab it was bought in and the others waited, and a waiting crate opens in whichever tab is in
--- view: crates bought in Bandeiras were opened in Pets. Bought one at a time, a crate opens at once,
--- in its own tab, and none is left waiting.)
Locker.CRATE_MAX = 1

local FONT = Font.fromId(12187365977, Enum.FontWeight.Bold)
local FONT_M = Font.fromId(12187365977, Enum.FontWeight.Medium)
local GOLD = Color3.fromRGB(236, 190, 92)

local function c3(hex: number): Color3
	return Color3.fromRGB((hex // 65536) % 256, (hex // 256) % 256, hex % 256)
end

--- 80 -> "80%", 4.5 -> "4.5%" ("4,5%" in Portuguese), 0.04 -> "0.04%"
local function pct(share: number): string
	local v = share * 100
	local text = if v >= 10 or v == math.floor(v) then string.format("%.0f", v) else string.format("%.2f", v)
	if string.find(text, ".", 1, true) ~= nil then
		text = string.gsub(string.gsub(text, "0+$", ""), "%.$", "")
	end
	if UITheme.tr("Common") ~= "Common" then
		text = string.gsub(text, "%.", ",")
	end
	return text .. "%"
end
Locker.pct = pct

-- A skin's preview: its pattern in PREVIEW_COLOR over sand, the way the map draws it
-- (MapSurface: fill alpha 150, secondary Cosmetics.SECONDARY_ALPHA, a darker edge). Cached per skin.
local previews: { [string]: any } = {}
local function skin_preview(skin: any): any
	local cached = previews[skin.id]
	if cached ~= nil then
		return cached or nil
	end
	if not IS_ROBLOX then
		return nil
	end
	-- (a skin with several colours shows twice the tiles: its pattern is larger)
	local n = if skin.colors ~= nil then Locker.PREVIEW_TILES * 2 else Locker.PREVIEW_TILES
	local ok, img = pcall(function()
		return game:GetService("AssetService"):CreateEditableImage({ Size = Vector2.new(n, n) })
	end)
	if not ok or img == nil then
		previews[skin.id] = false
		return nil
	end
	local mask, mw, mh = Cosmetics.mask(skin)
	local c = Locker.PREVIEW_COLOR
	local r, g, b = c.R, c.G, c.B
	local sr, sg, sb = Cosmetics.secondary(skin, r, g, b)
	local tr, tg, tb = 221 / 255, 205 / 255, 160 / 255
	local a1, a2 = 150 / 255, Cosmetics.SECONDARY_ALPHA / 255
	local buf = buffer.create(n * n * 4)
	for y = 0, n - 1 do
		for x = 0, n - 1 do
			local cr, cg, cb, a
			if x == 0 or y == 0 or x == n - 1 or y == n - 1 then
				cr, cg, cb, a = r * 0.875, g * 0.875, b * 0.875, 1
			else
				local mx = bit32.rshift(x, skin.scale or 0) % mw
				local my = bit32.rshift(y, skin.scale or 0) % mh
				local k = buffer.readu8(mask, my * mw + mx)
				local kr, kg, kb
				if skin.colors ~= nil and k ~= 0 then
					kr, kg, kb = Cosmetics.color(skin, k)
				end
				if kr ~= nil then
					cr, cg, cb, a = kr, kg :: number, kb :: number, Cosmetics.skin_alpha(skin) / 255
				elseif k ~= 0 and skin.colors == nil then
					cr, cg, cb, a = sr, sg, sb, a2
				else
					cr, cg, cb, a = r, g, b, a1
				end
			end
			local k = (y * n + x) * 4
			buffer.writeu8(buf, k, math.floor((tr * (1 - a) + cr * a) * 255 + 0.5))
			buffer.writeu8(buf, k + 1, math.floor((tg * (1 - a) + cg * a) * 255 + 0.5))
			buffer.writeu8(buf, k + 2, math.floor((tb * (1 - a) + cb * a) * 255 + 0.5))
			buffer.writeu8(buf, k + 3, 255)
		end
	end
	local wrote = pcall(function()
		img:WritePixelsBuffer(Vector2.zero, Vector2.new(n, n), buf)
	end)
	previews[skin.id] = if wrote then img else false
	return if wrote then img else nil
end

--- Show item `it` in ImageLabel `img`: a skin's pattern (painted here: a skin is a drawing in the
--- code, not an image), a flag or a pet from its sheet.
local function show_item(img: ImageLabel, it: any)
	img.ImageRectOffset = Vector2.zero
	img.ImageRectSize = Vector2.zero
	img.ImageContent = Content.none
	img.Image = ""
	img:SetAttribute("Skin", nil)
	if it == nil then
		return
	end
	if it.kind == "skin" then
		img.ResampleMode = Enum.ResamplerMode.Pixelated
		img:SetAttribute("Skin", it.id)
		local ed = skin_preview(it)
		if ed ~= nil then
			img.ImageContent = Content.fromObject(ed)
		end
		return
	end
	local image, x, y, w, h = Cosmetics.image_of(it)
	img.ResampleMode = Enum.ResamplerMode.Default
	img.Image = image
	img.ImageRectOffset = Vector2.new(x, y)
	img.ImageRectSize = Vector2.new(w, h)
end
Locker.show_item = show_item

function Locker.new(c: any)
	local self = setmetatable({}, Locker.__mt)
	W.Control._init(self)
	self.ctx = c
	self.closed = Signal.new()
	self.is_open = false
	-- (Roblox's price of the crate arrives a moment after the first look: UI/Prices)
	self:_connect(Prices.changed:Connect(function()
		if self.is_open then
			self:_refresh_crate()
		end
	end))
	self._tab = 1
	self._pending = nil
	self._cards = {}
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self:set_mouse_filter(W.MOUSE_STOP)
	self:set_visible(false)
	self._dim = W.ColorRect.new(UITheme.rgba(0.0275, 0.0196, 0.0314, 0.8))
	self._dim:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self._dim.gui_input:Connect(function(e)
		-- (a press on the window's own ground reaches the dim too: only one outside it closes)
		if
			e.pressed
			and not (self.opening ~= nil and self.opening.is_open)
			and not (self.confirm ~= nil and self.confirm:busy())
			and not self._panel:has_global_point(e.global_position)
		then
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

	-- head: title + count | the name as a match shows it | balance | close
	local head = UITheme.hbox(14)
	self._head = head
	local tcol = UITheme.vbox(1)
	tcol.size_flags_vertical = W.SHRINK_CENTER
	self._title = UITheme.label("LOCKER", 22, 800, GOLD, 4)
	tcol:add_child(self._title)
	self._count = UITheme.label("", 12, 600, UITheme.TEXT_2)
	tcol:add_child(self._count)
	head:add_child(tcol)
	local gap = W.Control.new()
	gap.size_flags_horizontal = W.EXPAND_FILL
	gap:set_mouse_filter(W.MOUSE_IGNORE)
	head:add_child(gap)
	self:_build_plate(head)
	local gap2 = W.Control.new()
	gap2.size_flags_horizontal = W.EXPAND_FILL
	gap2:set_mouse_filter(W.MOUSE_IGNORE)
	head:add_child(gap2)
	local purse = W.Panel.new()
	purse:set_mouse_filter(W.MOUSE_IGNORE)
	purse:add_theme_stylebox_override("panel", UITheme.flat(UITheme.c(GOLD, 0.1), 17, UITheme.c(GOLD, 0.4), 1, 12.0, 6.0))
	purse.size_flags_vertical = W.SHRINK_CENTER
	local ph = UITheme.hbox(6)
	local coin = UITheme.icon_rect("star", 16.0, GOLD)
	coin.size_flags_vertical = W.SHRINK_CENTER
	ph:add_child(coin)
	self._purse = UITheme.label("0", 14, 700, UITheme.TEXT)
	self._purse.size_flags_vertical = W.SHRINK_CENTER
	ph:add_child(self._purse)
	purse:add_child(ph)
	self._purse_box = purse
	head:add_child(purse)
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

	-- tabs: one per collection, each as wide as the others
	local tabs = UITheme.hbox(8)
	self._tab_row = tabs
	self._tabs = {}
	for i, _t in ipairs(Locker.TABS) do
		local chip = UITheme.button("", "ChipButton", "", 38.0)
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

	-- body: the grid | the tab's crate
	local body = UITheme.hbox(16)
	self._body = body
	v:add_child(body)
	local host = W.Control.new()
	host:set_min_size(Locker.GRID_SIZE)
	host:set_mouse_filter(W.MOUSE_PASS)
	self._host = host
	body:add_child(host)
	local sf = Instance.new("ScrollingFrame")
	sf.Name = "LockerGrid"
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.Size = UDim2.fromScale(1, 1)
	sf.ScrollBarThickness = 6
	sf.ScrollBarImageColor3 = GOLD
	sf.ScrollBarImageTransparency = 0.5
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.CanvasSize = UDim2.new(0, 0, 0, 0)
	sf.ScrollingDirection = Enum.ScrollingDirection.Y
	sf.ZIndex = 40
	sf.Parent = host.gui
	host:_part(sf, "ScrollBarImageTransparency", 0.5)
	self._sf = sf
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = sf
	self._grid = grid
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 3)
	pad.PaddingLeft = UDim.new(0, 3)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 3)
	pad.Parent = sf
	self:_build_crate(body)
	-- Roblox: the purchase prompt (the session's signals: bind, once UIRoot has one)
	if IS_ROBLOX then
		game:GetService("MarketplaceService").PromptProductPurchaseFinished:Connect(function(_u, product_id, purchased)
			self:_on_prompt_done(product_id, purchased)
		end)
	end
	return self
end

--- The session's inventory, credits and crate answers (UIRoot.setup, when the session exists).
function Locker.bind(self, s: any)
	if s == nil or self._bound == s then
		return
	end
	self._bound = s
	if s.inventory_changed then
		s.inventory_changed:Connect(function()
			self:_on_inventory()
		end)
	end
	if s.credits_changed then
		s.credits_changed:Connect(function()
			self:_on_credits()
		end)
	end
	if s.crate_result then
		s.crate_result:Connect(function(ok, res, back)
			self:_on_result(ok, res, back)
		end)
	end
	if s.crates_result then
		s.crates_result:Connect(function(ok, reason)
			self:_on_bought_with_stars(ok, reason)
		end)
	end
end

-- ---------------------------------------------------------------------------------------------
-- The name as a match shows it: [flag] name [pet]
-- ---------------------------------------------------------------------------------------------

local function plate_image(w: number, h: number): (any, ImageLabel)
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.ScaleType = Enum.ScaleType.Fit
	local node = W.wrap(img)
	node:_part(img, "ImageTransparency", 1.0)
	node:set_min_size(Vector2.new(w, h))
	node:set_mouse_filter(W.MOUSE_IGNORE)
	node.size_flags_vertical = W.SHRINK_CENTER
	return node, img
end

function Locker._build_plate(self, parent: any)
	local plate = W.Panel.new()
	plate:set_mouse_filter(W.MOUSE_IGNORE)
	plate:add_theme_stylebox_override("panel", UITheme.flat(UITheme.rgba(0, 0, 0, 0.32), 10, UITheme.LINE, 1, 14.0, 6.0))
	plate.size_flags_vertical = W.SHRINK_CENTER
	self._plate = plate
	local col = UITheme.vbox(2)
	plate:add_child(col)
	self._plate_cap = UITheme.caption("In a match", 10, UITheme.TEXT_3)
	self._plate_cap:set_alignment(W.ALIGN_CENTER)
	col:add_child(self._plate_cap)
	local row = UITheme.hbox(8)
	row:set_alignment(W.ALIGN_CENTER)
	col:add_child(row)
	self._plate_flag, self._plate_flag_img = plate_image(33, 22)
	row:add_child(self._plate_flag)
	local name = "You"
	if IS_ROBLOX then
		pcall(function()
			name = game:GetService("Players").LocalPlayer.DisplayName
		end)
	end
	self._plate_name = UITheme.label(name, 15, 700, UITheme.TEXT)
	self._plate_name.size_flags_vertical = W.SHRINK_CENTER
	row:add_child(self._plate_name)
	self._plate_pet, self._plate_pet_img = plate_image(26, 26)
	row:add_child(self._plate_pet)
	parent:add_child(plate)
end

function Locker._refresh_plate(self)
	local flag = Cosmetics.item(self:_equipped("flag"))
	local pet = Cosmetics.item(self:_equipped("pet"))
	self._plate_flag:set_visible(flag ~= nil)
	self._plate_pet:set_visible(pet ~= nil)
	show_item(self._plate_flag_img, flag)
	show_item(self._plate_pet_img, pet)
end

-- ---------------------------------------------------------------------------------------------
-- The crate
-- ---------------------------------------------------------------------------------------------

function Locker._build_crate(self, parent: any)
	local card = W.Panel.new()
	card:set_mouse_filter(W.MOUSE_PASS)
	card:add_theme_stylebox_override("panel", UITheme.flat(UITheme.c(GOLD, 0.06), 14, UITheme.c(GOLD, 0.42), 1, 16.0, 14.0))
	self._crate = card
	parent:add_child(card)
	local v = UITheme.vbox(8)
	self._crate_v = v
	card:add_child(v)
	-- the 3D chest (ChestView: the opening's chest), bobbing while the window is open
	local vpf = Instance.new("ViewportFrame")
	vpf.BackgroundTransparency = 1
	self._chest_view = ChestView.build(vpf)
	self._chest_P = ChestView.rest()
	self._chest_t = 0.0
	ChestView.pose(self._chest_view, self._chest_P)
	self._art = W.wrap(vpf)
	self._art:_part(vpf, "ImageTransparency", 1.0)
	self._art:set_min_size(Vector2.new(Locker.CRATE_W - 32, 118))
	self._art:set_mouse_filter(W.MOUSE_IGNORE)
	self._art.size_flags_horizontal = W.SHRINK_CENTER
	v:add_child(self._art)
	self._crate_title = UITheme.label("SKIN CRATE", 16, 800, UITheme.TEXT, 2)
	self._crate_title:set_alignment(W.ALIGN_CENTER)
	v:add_child(self._crate_title)
	self._crate_sub = UITheme.label("", 12, 500, UITheme.TEXT_2)
	self._crate_sub:set_alignment(W.ALIGN_CENTER)
	self._crate_sub:set_autowrap(true)
	self._crate_sub:set_min_size(Vector2.new(Locker.CRATE_W - 32, 0))
	v:add_child(self._crate_sub)
	-- the odds (the player's own, for this tab; shown before any purchase)
	local odds_panel = W.Panel.new()
	odds_panel:set_mouse_filter(W.MOUSE_IGNORE)
	odds_panel:add_theme_stylebox_override("panel", UITheme.flat(UITheme.rgba(0, 0, 0, 0.28), 10, UITheme.LINE, 1, 12.0, 8.0))
	self._odds_box = odds_panel
	local odds = UITheme.vbox(3)
	self._odds_v = odds
	odds_panel:add_child(odds)
	-- (the captions' row: the odds, and over the last column what a duplicate of that rarity pays)
	local cap_row = UITheme.hbox(8)
	local cap_odds = UITheme.caption("Chances", 10, UITheme.TEXT_3)
	cap_odds.size_flags_horizontal = W.EXPAND_FILL
	cap_row:add_child(cap_odds)
	self._dup_cap = UITheme.caption("Duplicate pays", 10, UITheme.TEXT_3)
	cap_row:add_child(self._dup_cap)
	self._odds_cap = cap_row
	odds:add_child(cap_row)
	self._odds = {}
	self._dups = {}
	self._odds_labels = {}
	for _, r in Cosmetics.RARITIES do
		local row = UITheme.hbox(8)
		local sw = UITheme.swatch(c3(r.color), 10.0, 3)
		sw.size_flags_vertical = W.SHRINK_CENTER
		row:add_child(sw)
		local name = UITheme.label(r.name, 12, 600, UITheme.TEXT)
		name.size_flags_horizontal = W.EXPAND_FILL
		row:add_child(name)
		local share = UITheme.label("", 12, 700, UITheme.TEXT)
		row:add_child(share)
		self._odds[r.id] = share
		-- the Coroas a duplicate of this rarity pays (Cosmetics.DUPLICATE_STARS), in the currency's gold
		local back = UITheme.label("", 12, 700, UITheme.GOLD)
		back:set_alignment(W.ALIGN_RIGHT)
		row:add_child(back)
		self._dups[r.id] = back
		table.insert(self._odds_labels, name)
		table.insert(self._odds_labels, share)
		table.insert(self._odds_labels, back)
		odds:add_child(row)
	end
	v:add_child(odds_panel)
	-- the two ways to pay, side by side (2026-11-10): Robux where Roblox lets this player buy a paid
	-- crate, and Coroas for everyone
	local brow = UITheme.hbox(8)
	self._buy_row = brow
	self._buy_r = UITheme.button("9", "PrimaryButton", "robux", 46.0)
	self._buy_r:set_min_size(Vector2.new(0, 46))
	self._buy_r.pressed:Connect(function()
		self:_buy_pressed("robux")
	end)
	brow:add_child(self._buy_r)
	self._buy = UITheme.button("10,000", "GoldButton", "star", 46.0)
	self._buy.size_flags_horizontal = W.EXPAND_FILL
	self._buy:set_min_size(Vector2.new(0, 46))
	self._buy.pressed:Connect(function()
		self:_buy_pressed("stars")
	end)
	brow:add_child(self._buy)
	-- (two buttons in the room of one: the theme's side margins, 22 px, come down so "100.000" fits)
	for _, b in { self._buy_r, self._buy } do
		local th = UITheme.theme()[if b == self._buy_r then "PrimaryButton" else "GoldButton"]
		for name, style in th.styles do
			local tight = UITheme.dup(style)
			if tight.margin ~= nil then
				tight.margin[1] = 8.0
				tight.margin[3] = 8.0
			else
				tight.mh = 8.0
			end
			b:add_theme_stylebox_override(name, tight)
		end
		b:add_theme_constant_override("icon_max_width", 16)
	end
	brow:set_min_size(Vector2.new(Locker.CRATE_W - 32, 46))
	v:add_child(brow)
	-- a crate already bought waits here
	self._open_b = UITheme.button("OPEN CRATE", "GlassButton", "crate", 40.0)
	self._open_b:set_min_size(Vector2.new(Locker.CRATE_W - 32, 40))
	self._open_b:set_font_size(13)
	self._open_b:set_visible(false)
	self._open_b.pressed:Connect(function()
		self:_open_pressed()
	end)
	v:add_child(self._open_b)
	self._note = UITheme.label("", 11, 500, UITheme.TEXT_3)
	self._note:set_alignment(W.ALIGN_CENTER)
	self._note:set_autowrap(true)
	self._note:set_min_size(Vector2.new(Locker.CRATE_W - 32, 0))
	v:add_child(self._note)
end

function Locker._inv(self): any
	local s = self.ctx.session
	return if s ~= nil and s.inventory ~= nil
		then s.inventory
		else { owned = {}, equipped = {}, crates_bought = 0, crates_allowed = false, crates_stars = true, stars = 0 }
end

function Locker._crates(self): number
	local s = self.ctx.session
	local c = if s ~= nil then s.credits else nil
	return if type(c) == "table" then (tonumber(c.crate) or 0) else 0
end

function Locker._kind(self): string
	return Locker.TABS[self._tab][2]
end

--- May this player pay a crate with Robux? Only where Roblox does not restrict paid random items for
--- them (the server's word, from PolicyService: Session.inventory.crates_allowed; unknown = no).
--- Coroas pay a crate for everyone.
function Locker._can_robux(self): boolean
	return self:_inv().crates_allowed == true
end

--- Is there a Robux product to prompt (Data/MyProducts `crate` with its id)?
function Locker._has_product(_self): boolean
	return Products.crate ~= nil and Products.crate.id ~= 0
end

--- The way the next crate is paid when nobody says: the way of the last purchase; before any, Coroas,
--- or Robux for a player who may use them and hasn't the Coroas for one crate.
function Locker._how_now(self): string
	local robux = self:_can_robux() and self:_has_product()
	if self._how == "robux" and robux then
		return "robux"
	elseif self._how == "stars" then
		return "stars"
	end
	if robux and (tonumber(self:_inv().stars) or 0) < Locker.CRATE_STARS then
		return "robux"
	end
	return "stars"
end

--- Items of the tab in view the player has yet to get.
function Locker._left(self): number
	local kind = self:_kind()
	return #Cosmetics.of_kind(kind) - Cosmetics.crate_owned(self:_inv().owned, kind)
end

--- Whether a crate can be bought now (1) or not (0): the tab still has an item to give, and no crate
--- waits (one at a time: a waiting crate is opened first, so crates never pile up).
function Locker._max_qty(self): number
	if self:_left() <= 0 or self:_crates() > 0 then
		return 0
	end
	return Locker.CRATE_MAX
end

--- What a crate costs paid `how` ("stars" | "robux"; nil: Locker._how_now): (the amount, how).
function Locker._total(self, how: string?): (number, string)
	if (how or self:_how_now()) ~= "robux" then
		return Locker.CRATE_STARS, "stars"
	end
	return Prices.robux("crate"), "robux"
end

function Locker._set_tab(self, i: number)
	self._tab = i
	for j, ch in ipairs(self._tabs) do
		ch:set_pressed_no_signal(j == i)
	end
	self:_refresh_crate()
	self:_rebuild()
	self._sf.CanvasPosition = Vector2.zero
end

function Locker._refresh_crate(self)
	local inv = self:_inv()
	local tab = Locker.TABS[self._tab]
	local kind = tab[2]
	local total = #Cosmetics.all()
	local owned = Cosmetics.crate_owned(inv.owned)
	self._count:set_text(string.format("%d of %d unlocked", owned, total))
	self._purse:set_text(UICtx.commas(math.floor(tonumber(inv.stars) or 0)))
	for i, t in ipairs(Locker.TABS) do
		local n = #Cosmetics.of_kind(t[2])
		self._tabs[i]:set_text(string.format("%s  %d/%d", UITheme.tr(t[1]), Cosmetics.crate_owned(inv.owned, t[2]), n))
	end
	self:_refresh_plate()
	local dups = Cosmetics.DUPLICATES == true
	self._crate_title:set_text(tab[3])
	self._crate_sub:set_text(if dups then tab[6] else tab[4])
	-- the player's own odds in this tab. Without duplicates a rarity with nothing left gives its share
	-- to the others; with them every rarity keeps its share, and the row says what a duplicate pays
	self._dup_cap:set_visible(dups)
	local dup_w = 0
	for _, e in Cosmetics.odds(inv.owned, kind) do
		local l = self._odds[e.rarity.id]
		if l then
			l:set_text(if dups or e.left > 0 then pct(e.odds) else "all owned")
		end
		local d = self._dups[e.rarity.id]
		if d then
			d:set_visible(dups)
			d:set_text(if dups then "+" .. UICtx.commas(Cosmetics.DUPLICATE_STARS[e.rarity.id] or 0) else "")
			dup_w = math.max(dup_w, d:get_combined_minimum_size().X)
		end
	end
	-- (one width for the column, so the odds line up above each other)
	for _, d in self._dups do
		d:set_min_size(Vector2.new(dup_w, 0))
	end
	local left = self:_left()
	local waiting = self:_crates()
	local busy = self._pending ~= nil
	local can_buy = left > 0 and self:_max_qty() > 0
	local robux = self:_can_robux()
	local price = self:_total("stars")
	local short = price - (tonumber(inv.stars) or 0)
	self._odds_box:set_visible(left > 0)
	self._buy_row:set_visible(can_buy)
	self._buy:set_visible(can_buy)
	self._buy:set_disabled(busy or short > 0)
	self._buy_r:set_visible(can_buy and robux)
	self._buy_r:set_disabled(busy)
	-- (a crate's price on each button: Coroas, and Robux beside it where Roblox allows)
	self._buy:set_text(UICtx.commas(price))
	if robux then
		self._buy_r:set_text(UICtx.commas((self:_total("robux"))))
	end
	self._open_b:set_visible(waiting > 0)
	self._open_b:set_disabled(busy or left <= 0)
	self._open_b:set_text(if waiting > 1 then string.format("OPEN CRATE (%d)", waiting) else "OPEN CRATE")
	local note
	if left <= 0 then
		note = if waiting > 0 then tab[5] .. " " .. UITheme.tr("Open your crate in another tab.") else tab[5]
	elseif busy then
		note = if self._pending.phase == "opening" then "OPENING…" else "BUYING…"
	elseif short > 0 then
		note = string.format("%s more Stars to go. Play matches to earn them.", UICtx.commas(short))
	elseif not robux then
		note = if dups
			then "Paid with Stars, earned by playing  ·  A duplicate pays Stars"
			else "Paid with Stars, earned by playing  ·  Never a duplicate"
	else
		note = if dups
			then "Robux or Stars: your choice  ·  A duplicate pays Stars"
			else "Robux or Stars: your choice  ·  Never a duplicate"
	end
	self._note:set_text(note)
	-- a button came or went (a crate arrived, the last item was got): the window is fitted again
	if self.is_open and not self._fitting and self._fit_for ~= nil and self._fit_for ~= self:_fit_key() then
		self._fitting = true
		if self:_fit() then
			self:_rebuild()
		end
		self._fitting = false
	end
end

-- ---------------------------------------------------------------------------------------------
-- Buying and opening
-- ---------------------------------------------------------------------------------------------

--- A short notice (UIRoot sets this to its toasts).
function Locker._toast(_self, _text: string) end

function Locker._report(self, kind: string)
	local s = self.ctx.session
	if s ~= nil and type(s.report) == "function" then
		s:report(kind)
	end
end

--- Ask Roblox for one purchase of the row.
function Locker._prompt(self, product_id: number)
	local ok = pcall(function()
		game:GetService("MarketplaceService"):PromptProductPurchase(game:GetService("Players").LocalPlayer, product_id)
	end)
	if not ok then
		self:_cancel("Purchases aren't available right now.")
	end
end

--- The window that asks before Coroas are spent (UI/ConfirmBuy; UIRoot makes it, above this window
--- and the opening show). Without one a press buys at once.
function Locker.set_confirm(self, c: any)
	self.confirm = c
end

--- A buy button (or the opening show's "another"): one crate, paid `how` ("stars" | "robux"; nil: as
--- the last one was, Locker._how_now). Paid with Coroas, the player is asked once more first
--- (2026-11-11: a press by accident bought a crate); `confirmed`: they said yes. Robux have Roblox's
--- own confirmation.
function Locker._buy_pressed(self, how: string?, confirmed: boolean?)
	if self._pending ~= nil then
		return
	end
	local way = how or self:_how_now()
	if way == "robux" then
		if not self:_can_robux() then
			return
		end
		if not self:_has_product() then
			-- (the owner has yet to create the crate's product: Data/MyProducts)
			self.ctx:sfx("deny", -6.0)
			self:_toast("Robux purchases aren't ready yet. Use Stars for now.")
			return
		end
	end
	if self:_max_qty() <= 0 then
		return
	end
	if not confirmed then
		self:_report("crate_click")
	end
	local s = self.ctx.session
	self._how = way
	if way ~= "robux" then
		local have = tonumber(self:_inv().stars) or 0
		if have < Locker.CRATE_STARS then
			self.ctx:sfx("deny", -6.0)
			return
		end
		if not confirmed and self.confirm ~= nil then
			-- (everything above is checked again when they confirm)
			self.ctx:sfx("click")
			self.confirm:ask({
				owner = self,
				what = Locker.TABS[self._tab][3],
				price = Locker.CRATE_STARS,
				balance = have,
			}, function()
				self:_buy_pressed("stars", true)
			end)
			return
		end
		if s == nil or type(s.buy_crates) ~= "function" or not s:buy_crates(1) then
			self:_toast("Couldn't reach the server. Try again in a moment.")
			return
		end
		self._pending = { phase = "stars", since = os.clock(), kind = self:_kind() }
		self:_refresh_crate()
		return
	end
	if not IS_ROBLOX then
		return
	end
	local prod = Products.crate
	if prod == nil or prod.id == 0 then
		return
	end
	-- one prompt: the crate opens once it is paid
	self._pending = {
		phase = "prompt",
		product = prod.id,
		since = os.clock(),
		kind = self:_kind(),
	}
	self:_refresh_crate()
	self:_prompt(prod.id)
end

--- The open button: a crate that waits, as a crate of the tab in view.
function Locker._open_pressed(self)
	if self._pending ~= nil or self:_crates() <= 0 or self:_left() <= 0 then
		return
	end
	self:_open(self:_kind())
end

function Locker._open(self, kind: string?)
	local k = kind or self:_kind()
	self._pending = { phase = "opening", since = os.clock(), kind = k }
	self:_refresh_crate()
	-- the show starts at once: the server's roll lands while the chest drops / shakes
	if self.opening ~= nil then
		self.opening:play(self:_offer())
	end
	local s = self.ctx.session
	if s == nil or not s:open_crate(k) then
		if self.opening ~= nil then
			self.opening:fail("Couldn't reach the server. Try again in a moment.")
		end
		self:_cancel("Couldn't reach the server. Try again in a moment.")
	end
end

--- What the opening show offers next: waiting crates, the next one's price and currency, whether more
--- can come, and what the player wears.
function Locker._offer(self): any
	local price, currency = self:_total()
	return {
		crates = self:_crates(),
		price = price,
		stars = currency == "stars",
		kind = self:_kind(),
		can_more = self:_left() > 0 and (self:_crates() > 0 or currency ~= "stars" or (tonumber(self:_inv().stars) or 0) >= price),
		wearing = function(slot: string): string?
			return self:_equipped(slot)
		end,
	}
end

--- The opening show (UIRoot makes it, above this window).
function Locker.set_opening(self, o: any)
	self.opening = o
	o.preview_of = skin_preview
	o.show_item = show_item
	o.info_of = function()
		return self:_offer()
	end
	o.wear:Connect(function(id: string)
		local it = Cosmetics.item(id)
		local se = self.ctx.session
		if it ~= nil and se ~= nil then
			self.ctx:sfx("click")
			se:equip(it.kind, it.id)
		end
	end)
	o.again:Connect(function()
		if self._pending ~= nil then
			return
		end
		if self:_crates() > 0 and self:_left() > 0 then
			self:_open(self:_kind())
		else
			self:_buy_pressed()
		end
	end)
	o.closed:Connect(function(fail_text: string?)
		if fail_text then
			self:_toast(fail_text)
		end
		if self.is_open then
			self:_refresh_crate()
			self:_rebuild()
		end
	end)
end

function Locker._cancel(self, message: string?)
	self._pending = nil
	if message then
		self:_toast(message)
	end
	self:_refresh_crate()
end

function Locker._on_prompt_done(self, product_id: number, purchased: boolean)
	local p = self._pending
	if p == nil or p.phase ~= "prompt" or product_id ~= p.product then
		return
	end
	if not purchased then
		self:_cancel(nil)
		return
	end
	-- bought: the server stores the crate and says so (credits); then it opens
	p.phase = "credit"
	p.since = os.clock()
	if self:_crates() > 0 then
		self:_open(p.kind)
	end
end

--- The server's answer to crates asked for with Coroas.
function Locker._on_bought_with_stars(self, ok: boolean, reason: string?)
	local p = self._pending
	if p == nil or p.phase ~= "stars" then
		return
	end
	if not ok then
		self:_cancel(
			if reason == "not enough"
				then "Not enough Stars."
				else "Couldn't buy the crate right now. Nothing was taken."
		)
		return
	end
	p.phase = "credit"
	p.since = os.clock()
	if self:_crates() > 0 then
		self:_open(p.kind)
	end
end

function Locker._on_credits(self)
	local p = self._pending
	if p ~= nil and p.phase == "credit" and self:_crates() > 0 then
		self:_open(p.kind)
	end
	if self.is_open then
		self:_refresh_crate()
	end
end

function Locker._on_inventory(self)
	if self.is_open then
		self:_refresh_crate()
		self:_rebuild()
	end
	if self.opening ~= nil and self.opening.is_open then
		self.opening:refresh_buttons()
	end
end

function Locker._on_result(self, ok: boolean, res: string, back: number?)
	local p = self._pending
	if p == nil or p.phase ~= "opening" then
		return
	end
	self._pending = nil
	self:_refresh_crate()
	local o = self.opening
	if ok then
		if o ~= nil then
			-- (back: the Coroas a duplicate paid instead of the item; 0 for a new one)
			o:resolve(res, back)
		end
	elseif o ~= nil then
		o:fail(
			if res == "everything owned"
				then "You own everything in this tab already. Your crate is saved."
				else "Couldn't open the crate right now. It's saved: try again."
		)
	end
end

--- Once a second while open: a purchase that never came back gives up (a crate bought stays saved).
function Locker.tick(self)
	local p = self._pending
	if p ~= nil then
		local limit = if p.phase == "prompt" then 180 else Locker.CREDIT_WAIT_S
		if os.clock() - p.since > limit then
			self:_cancel(if p.phase == "prompt" then nil else "Your crate is saved: open it in a moment.")
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- The grid
-- ---------------------------------------------------------------------------------------------

function Locker._equipped(self, slot: string): string?
	local inv = self:_inv()
	return inv.equipped and inv.equipped[slot] or nil
end

function Locker._card(self, it: any, order: number, slot: string): TextButton
	local s = UITheme.scale
	local inv = self:_inv()
	local owned = it == nil or inv.owned[it.id] == true
	local equipped = if it == nil then self:_equipped(slot) == nil else self:_equipped(slot) == it.id
	local rar = if it ~= nil then Cosmetics.rarity(it.rarity) else nil
	local tone = if rar ~= nil then c3(rar.color) else Color3.fromRGB(150, 146, 150)
	local host = self._host
	local b = Instance.new("TextButton")
	b.Name = if it then it.id else "none"
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundColor3 = Color3.fromRGB(20, 17, 21)
	b.BackgroundTransparency = 0.15
	b.LayoutOrder = order
	b.ZIndex = 41
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, math.floor(9 * s))
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = if equipped then GOLD elseif owned then tone else Color3.new(1, 1, 1)
	stroke.Transparency = if equipped then 0 elseif owned then 0.45 else 0.9
	stroke.Thickness = if equipped then 2 else 1
	stroke.Parent = b
	-- the rarity's ribbon along the foot
	local ribbon = Instance.new("Frame")
	ribbon.Name = "Rarity"
	ribbon.BorderSizePixel = 0
	ribbon.BackgroundColor3 = tone
	ribbon.AnchorPoint = Vector2.new(0.5, 1)
	ribbon.Position = UDim2.new(0.5, 0, 1, -math.floor(5 * s))
	ribbon.Size = UDim2.new(1, -math.floor(18 * s), 0, math.max(2, math.floor(3 * s)))
	ribbon.ZIndex = 42
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0.5, 0)
	rc.Parent = ribbon
	ribbon.Parent = b
	local img = Instance.new("ImageLabel")
	img.Name = "Preview"
	img.BackgroundTransparency = 1
	img.ScaleType = Enum.ScaleType.Fit
	img.Position = UDim2.fromOffset(math.floor(12 * s), math.floor(10 * s))
	img.Size = UDim2.new(1, -math.floor(24 * s), 1, -math.floor(54 * s))
	img.ZIndex = 42
	img.Parent = b
	show_item(img, it)
	if it == nil then
		-- "None": a cross where the others show their art
		img.Image = UITheme.icon("close") or ""
		img.ImageColor3 = Color3.fromRGB(150, 146, 150)
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.new(0.5, 0, 0.5, -math.floor(17 * s))
		img.Size = UDim2.fromOffset(math.floor(26 * s), math.floor(26 * s))
	end
	local name = Instance.new("TextLabel")
	name.Name = "ItemName"
	name.BackgroundTransparency = 1
	name.FontFace = FONT
	name.TextSize = math.floor(12 * s)
	name.TextColor3 = Color3.new(1, 1, 1)
	-- (a long name shrinks to fit its card instead of being cut)
	name.TextScaled = true
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = math.max(7, math.floor(12 * s))
	fit.MinTextSize = 6
	fit.Parent = name
	name.Text = if it then it.name else "None"
	name.Position = UDim2.new(0, math.floor(6 * s), 1, -math.floor(41 * s))
	name.Size = UDim2.new(1, -math.floor(12 * s), 0, math.floor(16 * s))
	name.ZIndex = 42
	name.Parent = b
	local sub = Instance.new("TextLabel")
	sub.Name = "State"
	sub.BackgroundTransparency = 1
	sub.FontFace = FONT_M
	sub.TextSize = math.floor(10 * s)
	sub.TextColor3 = if equipped then GOLD else tone
	sub.Text = if equipped then "WEARING" elseif rar then string.upper(rar.name) else ""
	sub.Position = UDim2.new(0, math.floor(6 * s), 1, -math.floor(25 * s))
	sub.Size = UDim2.new(1, -math.floor(12 * s), 0, math.floor(12 * s))
	sub.ZIndex = 42
	sub.Parent = b
	host:_part(b, "BackgroundTransparency", 0.85)
	host:_part(stroke, "Transparency", 1 - stroke.Transparency)
	host:_part(ribbon, "BackgroundTransparency", if owned then 1.0 else 0.4)
	host:_part(img, "ImageTransparency", if owned then 1.0 else 0.32)
	host:_part(name, "TextTransparency", if owned then 1.0 else 0.5)
	host:_part(sub, "TextTransparency", if owned then 1.0 else 0.6)
	if not owned then
		-- yet to get: a lock in the corner
		local lock = Instance.new("ImageLabel")
		lock.Name = "Lock"
		lock.BackgroundTransparency = 1
		lock.Image = UITheme.icon("lock") or ""
		lock.ImageColor3 = Color3.new(1, 1, 1)
		lock.AnchorPoint = Vector2.new(1, 0)
		lock.Position = UDim2.new(1, -math.floor(7 * s), 0, math.floor(7 * s))
		lock.Size = UDim2.fromOffset(math.floor(14 * s), math.floor(14 * s))
		lock.ZIndex = 43
		lock.Parent = b
		host:_part(lock, "ImageTransparency", 0.55)
	end
	b.MouseEnter:Connect(function()
		host:_part(b, "BackgroundTransparency", 0.7)
	end)
	b.MouseLeave:Connect(function()
		host:_part(b, "BackgroundTransparency", 0.85)
	end)
	b.Activated:Connect(function()
		if not owned then
			self.ctx:sfx("deny", -6.0)
			self:_toast("It comes in this tab's crate, or in the Mystery Shop.")
			return
		end
		local se = self.ctx.session
		if se ~= nil then
			self.ctx:sfx("click")
			se:equip(slot, if it then it.id else false)
		end
	end)
	b.Parent = self._sf
	return b
end

function Locker._rebuild(self)
	for _, b in self._cards do
		self._host:_drop_part(b)
		for _, d in b:GetDescendants() do
			self._host:_drop_part(d)
		end
		b:Destroy()
	end
	table.clear(self._cards)
	local s = UITheme.scale
	local slot = self:_kind()
	local cell = Locker.CARD[slot]
	if self.ctx.compact then
		cell *= 0.8
	end
	-- as many columns as fit, each stretched so the row fills the grid's width
	local gap = math.floor(8 * s)
	local avail = math.floor((self._grid_w or Locker.GRID_SIZE.X) * s) - 13 - 8
	local cols = math.max(2, math.floor((avail + gap) / (math.floor(cell.X * s) + gap)))
	local cw = math.floor((avail - (cols - 1) * gap) / cols)
	self._grid.CellSize = UDim2.fromOffset(cw, math.floor(cell.Y * s * cw / math.max(1, cell.X * s)))
	self._grid.CellPadding = UDim2.fromOffset(gap, gap)
	local inv = self:_inv()
	-- None first, then owned (rarest first), then the rest
	local list = {}
	for _, it in Cosmetics.of_kind(slot) do
		table.insert(list, it)
	end
	-- (an exclusive, a General skin or an item of the monthly pass only for whoever owns it: nobody
	-- else can get one here)
	for _, more in { Cosmetics.exclusives(), Cosmetics.generals(), Cosmetics.shop_items(), Cosmetics.seasonals() } do
		for _, it in more do
			if it.kind == slot and inv.owned[it.id] == true then
				table.insert(list, it)
			end
		end
	end
	local rank = { exclusive = 0, general = 0, season = 0, legendary = 1, epic = 2, rare = 3, common = 4 }
	table.sort(list, function(a, b)
		local oa, ob = inv.owned[a.id] == true, inv.owned[b.id] == true
		if oa ~= ob then
			return oa
		end
		local ra, rb = rank[a.rarity] or 9, rank[b.rarity] or 9
		if ra ~= rb then
			return ra < rb
		end
		return a.name < b.name
	end)
	table.insert(self._cards, self:_card(nil, 0, slot))
	for i, it in list do
		table.insert(self._cards, self:_card(it, i, slot))
	end
end

-- ---------------------------------------------------------------------------------------------
-- Open / close / layout
-- ---------------------------------------------------------------------------------------------

function Locker.open(self)
	if self.is_open then
		return
	end
	self.is_open = true
	self:_report("crate_shop")
	Prices.fetch()
	self:_refresh_crate()
	self:_rebuild()
	self:set_visible(true)
	self:apply_layout()
	self._panel:set_modulate_a(1.0)
	self._dim:set_modulate_a(0.0)
	W.fade(self._dim, 1.0, 0.2)
	UICtx.pop_in(self._panel, 0.0, 0.94, 0.3)
	self.ctx:sfx("open")
	if self._chest_conn == nil and IS_ROBLOX then
		self._chest_conn = game:GetService("RunService").RenderStepped:Connect(function(dt)
			self._chest_t += dt
			ChestView.idle(self._chest_P, self._chest_t, 2.4)
			ChestView.pose(self._chest_view, self._chest_P)
		end)
	end
end

function Locker.close(self)
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
			if self._chest_conn then
				self._chest_conn:Disconnect()
				self._chest_conn = nil
			end
		end
	end)
	self.closed:Fire()
end

function Locker.apply_layout(self)
	local ctx = self.ctx
	local compact = ctx.compact
	-- phones (landscape: wide, short): the same two columns with a slim crate (no chest, no line
	-- under its title, smaller type) so the grid keeps the height
	local cw = if compact then 204 else Locker.CRATE_W
	self._art:set_visible(not compact)
	self._crate_sub:set_visible(not compact)
	self._odds_cap:set_visible(not compact)
	self._plate_cap:set_visible(not compact)
	self._count:set_visible(not compact)
	self._panel:set_padding(if compact then 12 else 22, if compact then 8 else 18, if compact then 12 else 22, if compact then 8 else 18)
	self._v:set_separation(if compact then 6 else 12)
	self._body:set_separation(if compact then 10 else 16)
	self._title:set_font_size(if compact then 15 else 22)
	self._crate_title:set_font_size(if compact then 13 else 16)
	self._crate_sub:set_min_size(Vector2.new(cw - 32, 0))
	self._note:set_min_size(Vector2.new(cw - 32, 0))
	-- (the Robux price is two digits, the Coroas one up to "100.000": two fifths and three fifths of
	-- the row; the Coroas button alone takes all of it)
	local bh = if compact then 38 else 46
	self._buy_row:set_separation(if compact then 6 else 8)
	self._buy_r:set_min_size(Vector2.new(math.floor((cw - 32 - 8) * (if compact then 0.34 else 0.4)), bh))
	self._buy:set_min_size(Vector2.new(0, bh))
	for _, b in { self._buy, self._buy_r } do
		b:set_font_size(if compact then 13 else 16)
		b:add_theme_constant_override("icon_max_width", if compact then 13 else 16)
	end
	self._buy_row:set_min_size(Vector2.new(cw - 32, if compact then 38 else 46))
	self._open_b:set_min_size(Vector2.new(cw - 32, if compact then 32 else 40))
	self._crate_v:set_separation(if compact then 4 else 8)
	for _, ch in ipairs(self._tabs) do
		ch:set_min_size(Vector2.new(0, if compact then 30 else 38))
		ch:set_font_size(if compact then 12 else 13)
	end
	self._crate_w = cw
	if self.is_open then
		self._fitting = true
		self:_refresh_crate()
		self._fitting = false
	end
	self:_fit()
	if self.is_open then
		self:_rebuild()
	end
end

--- Make the window fit the screen: the grid takes the room that is left; when the crate's column
--- alone is taller than the screen (a short phone, with a crate waiting to be opened), it gives up
--- its note, then its title, then the rarities' rows get tighter.
function Locker._fit(self)
	local ctx = self.ctx
	local area = ctx:clear_rect()
	local compact = ctx.compact
	local cw = self._crate_w or Locker.CRATE_W
	self._plate:set_visible(true)
	self._note:set_visible(true)
	self._crate_title:set_visible(true)
	self._odds_v:set_separation(if compact then 0 else 3)
	for _, l in self._odds_labels do
		l:set_font_size(if compact then 11 else 12)
	end
	local gw = math.clamp(area.Width - cw - (if compact then 60 else 120), 260, Locker.GRID_SIZE.X)
	local gh = math.clamp(area.Height - (if compact then 110 else 220), 110, Locker.GRID_SIZE.Y)
	self._host:set_min_size(Vector2.new(gw, gh))
	local function over_y(): number
		return self._panel:get_combined_minimum_size().Y - (area.Height - 4)
	end
	local function over_x(): number
		return self._panel:get_combined_minimum_size().X - (area.Width - 4)
	end
	-- too wide (a narrow phone): the name's preview goes, then the grid gives up width
	if over_x() > 0 then
		self._plate:set_visible(false)
	end
	if over_x() > 0 then
		gw = math.max(200, gw - over_x())
		self._host:set_min_size(Vector2.new(gw, gh))
	end
	-- too tall: the grid first
	if over_y() > 0 then
		gh = math.max(100, gh - over_y())
		self._host:set_min_size(Vector2.new(gw, gh))
	end
	if over_y() > 0 then
		self._note:set_visible(false)
	end
	if over_y() > 0 then
		self._crate_title:set_visible(false)
	end
	if over_y() > 0 then
		for _, l in self._odds_labels do
			l:set_font_size(10)
		end
	end
	local changed = self._grid_w ~= gw
	self._grid_w = gw
	-- (what the fit was made for: _refresh_crate asks again when it changes)
	self._fit_for = self:_fit_key()
	self:_center()
	return changed
end

--- What the crate's column shows that changes its height.
function Locker._fit_key(self): string
	return string.format("%s%s%s%s", tostring(self._open_b.visible), tostring(self._buy.visible) .. tostring(self._buy_r.visible), tostring(self._odds_box.visible), tostring(self._buy_row.visible))
end

function Locker._center(self)
	local ctx = self.ctx
	local area = ctx:clear_rect()
	for _, pn in { self._panel } do
		local sz = pn:get_combined_minimum_size()
		local p = area.Min + (Vector2.new(area.Width, area.Height) - sz) * 0.5
		local y = math.max(p.Y, area.Min.Y + 4.0)
		local rp = Vector2.new(math.floor(p.X + 0.5), math.floor(y + 0.5))
		pn:set_offsets(rp.X, rp.Y, rp.X, rp.Y)
		pn:reset_size()
	end
end

return Locker
