--!nonstrict
-- The Loja Misteriosa (the "Mystery Shop"; Data/Shop, Data/MyShop.loja): a window from the lobby's
-- SHOP button with the day's few offers. The day's items are the same for everyone and change at
-- 00:00 UTC; nothing in it is random for the buyer: the card shows the very item that is bought.
--   head    the name, how long until the offers change, the player's balance, close.
--   cards   one per offer: the item (a skin's pattern, a flag, a pet), its name, rarity and kind, and
--           its button:
--             Robux   the price of that rarity's product (Data/Products.shop_<rarity>; Roblox's own
--                     for this player, UI/Prices). A press tells the server which item the prompt is
--                     for (Session.shop_pick), then opens Roblox's prompt; the server gives the item
--                     when the receipt arrives (server/Purchases).
--             Coroas  a rare offer (Data/MyShop.loja.chance_coroas_*): Session.shop_buy, no prompt.
--             WEAR / WEARING once the item is the player's.
-- Signals: closed.
local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local UICtx = require("./UICtx")
local Prices = require("./Prices")
local Signal = UITheme.core("Signal")

local IS_ROBLOX = typeof(game) == "Instance"
local function shared(name: string): any
	if IS_ROBLOX then
		return require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data[name]) :: any
	end
	return (require :: any)("../../shared/Data/" .. name)
end
local Shop = shared("Shop")
local Cosmetics = shared("Cosmetics")
local Products = shared("Products")

local MysteryShop = W.class(W.Control)

--- A card, logical px (phones: CARD_PHONE), and the room its picture gets.
MysteryShop.CARD = Vector2.new(196, 100)
MysteryShop.CARD_PHONE = Vector2.new(132, 58)
MysteryShop.GAP = 12
--- After a purchase, how long a card waits for the server's word.
MysteryShop.GRANT_WAIT_S = 30

local GOLD = Color3.fromRGB(236, 190, 92)
local KIND_NAME = { skin = "SKIN", flag = "FLAG", pet = "PET" }

local function c3(hex: number): Color3
	return Color3.fromRGB((hex // 65536) % 256, (hex // 256) % 256, hex % 256)
end

--- "5:12:09"
function MysteryShop.clock(s: number): string
	s = math.max(0, math.floor(s))
	return string.format("%d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60)
end

--- Unix time as the server has it (every client agrees on the day).
function MysteryShop.now(): number
	if IS_ROBLOX then
		local ok, t = pcall(function()
			return workspace:GetServerTimeNow()
		end)
		if ok and type(t) == "number" then
			return t
		end
	end
	return os.time()
end

--- The player the offers are for.
function MysteryShop.user_id(): number
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

function MysteryShop.new(c: any)
	local self = setmetatable({}, MysteryShop.__mt)
	W.Control._init(self)
	self.ctx = c
	self.closed = Signal.new()
	self.is_open = false
	self._pending = nil
	self._day = -1
	self._cards = {}
	--- how to draw an item (the Locker's: UIRoot hands it over, so the skins' patterns are shared)
	self.show_item = nil :: any
	self:_connect(Prices.changed:Connect(function()
		if self.is_open then
			self:_refresh()
		end
	end))
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self:set_mouse_filter(W.MOUSE_STOP)
	self:set_visible(false)
	self._dim = W.ColorRect.new(UITheme.rgba(0.0275, 0.0196, 0.0314, 0.8))
	self._dim:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self._dim.gui_input:Connect(function(e)
		-- (a press that cancels the purchase's confirmation, above this window, is not for it)
		if
			e.pressed
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

	local head = UITheme.hbox(14)
	self._head = head
	local tcol = UITheme.vbox(1)
	tcol.size_flags_vertical = W.SHRINK_CENTER
	tcol.size_flags_horizontal = W.EXPAND_FILL
	self._title = UITheme.label("MYSTERY SHOP", 22, 800, GOLD, 4)
	tcol:add_child(self._title)
	self._sub = UITheme.label("", 12, 600, UITheme.TEXT_2)
	tcol:add_child(self._sub)
	head:add_child(tcol)
	-- the clock to the next offers
	local timer = W.Panel.new()
	timer:set_mouse_filter(W.MOUSE_IGNORE)
	timer:add_theme_stylebox_override("panel", UITheme.flat(UITheme.rgba(0, 0, 0, 0.32), 17, UITheme.LINE, 1, 12.0, 6.0))
	timer.size_flags_vertical = W.SHRINK_CENTER
	local th = UITheme.hbox(6)
	local ticon = UITheme.icon_rect("clock", 14.0, UITheme.TEXT_2)
	ticon.size_flags_vertical = W.SHRINK_CENTER
	th:add_child(ticon)
	self._clock = UITheme.label("0:00:00", 13, 700, UITheme.TEXT)
	self._clock.size_flags_vertical = W.SHRINK_CENTER
	UITheme.fix_width(self._clock, 62, W.ALIGN_CENTER, true)
	th:add_child(self._clock)
	timer:add_child(th)
	self._timer = timer
	head:add_child(timer)
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
	head:add_child(close)
	v:add_child(head)

	self._rows = UITheme.vbox(MysteryShop.GAP)
	v:add_child(self._rows)

	self._note = UITheme.label("You buy exactly what you see: no luck involved. Offers for Stars are very rare.", 11, 500, UITheme.TEXT_3)
	self._note:set_alignment(W.ALIGN_CENTER)
	self._note:set_autowrap(true)
	v:add_child(self._note)

	if IS_ROBLOX then
		game:GetService("MarketplaceService").PromptProductPurchaseFinished:Connect(function(_u, product_id, purchased)
			self:_on_prompt_done(product_id, purchased)
		end)
	end
	self:set_process(true)
	return self
end

--- The session's inventory and the shop's answers (UIRoot.setup, when the session exists).
function MysteryShop.bind(self, s: any)
	if s == nil or self._bound == s then
		return
	end
	self._bound = s
	if s.inventory_changed then
		s.inventory_changed:Connect(function()
			self:_on_inventory()
		end)
	end
	if s.shop_result then
		s.shop_result:Connect(function(what, ok, item_id, reason)
			self:_on_result(what, ok, item_id, reason)
		end)
	end
end

--- A short notice (UIRoot sets this to its toasts).
function MysteryShop._toast(_self, _text: string) end

function MysteryShop._report(self, a: string, b: any?)
	local s = self.ctx.session
	if s ~= nil and type(s.report) == "function" then
		-- (the analytics' "Mystery Shop" events: Opened once a visit, Clicked on a price)
		s:report("flag_shop", a, b)
	end
end

function MysteryShop._inv(self): any
	local s = self.ctx.session
	return if s ~= nil and s.inventory ~= nil then s.inventory else { owned = {}, equipped = {}, stars = 0 }
end

--- Today's offers for this player.
function MysteryShop.offers(self): { any }
	return Shop.offers(Shop.day(MysteryShop.now()), MysteryShop.user_id())
end

--- Can a Robux offer be bought here (its product exists)?
local function product_of(o: any): any
	local p = if o.product ~= nil then Products[o.product] else nil
	return if p ~= nil and p.id ~= 0 then p else nil
end

-- ---------------------------------------------------------------------------------------------
-- Cards
-- ---------------------------------------------------------------------------------------------

function MysteryShop._card(self, o: any, size: Vector2, compact: boolean): any
	local it = Cosmetics.item(o.id)
	local rar = Cosmetics.rarity(o.rarity)
	local tone = if rar ~= nil then c3(rar.color) else Color3.fromRGB(150, 146, 150)
	local stars = o.currency == "stars"
	local card = W.Panel.new()
	card:set_mouse_filter(W.MOUSE_PASS)
	card:add_theme_stylebox_override(
		"panel",
		UITheme.flat(
			if stars then UITheme.c(GOLD, 0.1) else UITheme.c(tone, 0.07),
			12,
			if stars then UITheme.c(GOLD, 0.85) else UITheme.c(tone, 0.55),
			if stars then 2 else 1,
			if compact then 8.0 else 12.0,
			if compact then 8.0 else 12.0
		)
	)
	local v = UITheme.vbox(if compact then 3 else 6)
	card:add_child(v)
	local pad = if compact then 16 else 24
	-- the rare kind of offer says so
	local badge = UITheme.caption(if stars then "RARE OFFER" else "", 10, GOLD)
	badge:set_alignment(W.ALIGN_CENTER)
	badge:set_visible(stars or not compact)
	v:add_child(badge)
	local img = Instance.new("ImageLabel")
	img.Name = "Offer"
	img.BackgroundTransparency = 1
	img.ScaleType = Enum.ScaleType.Fit
	local node = W.wrap(img)
	node:_part(img, "ImageTransparency", 1.0)
	node:set_min_size(Vector2.new(size.X - pad, size.Y))
	node:set_mouse_filter(W.MOUSE_IGNORE)
	if self.show_item ~= nil then
		self.show_item(img, it)
	elseif it ~= nil and it.kind ~= "skin" then
		local image, x, y, w, h = Cosmetics.image_of(it)
		img.Image = image
		img.ImageRectOffset = Vector2.new(x, y)
		img.ImageRectSize = Vector2.new(w, h)
	end
	v:add_child(node)
	-- (a long name gets smaller letters rather than being cut)
	local text = UITheme.tr(if it ~= nil then it.name else "?")
	local px = if compact then 12 else 14
	while px > 9 and UITheme.text_width(text, px, 700) > size.X - pad do
		px -= 1
	end
	local name = UITheme.label(text, px, 700, UITheme.TEXT)
	name:set_alignment(W.ALIGN_CENTER)
	name:set_min_size(Vector2.new(size.X - pad, 0))
	name.clip_text = true
	v:add_child(name)
	local kind = string.format(
		"%s · %s",
		string.upper(UITheme.tr(if rar ~= nil then rar.name else "")),
		UITheme.tr(KIND_NAME[if it ~= nil then it.kind else "skin"] or "")
	)
	local sub = UITheme.label(kind, if compact then 9 else 10, 700, tone, 1)
	sub:set_alignment(W.ALIGN_CENTER)
	v:add_child(sub)
	local b = UITheme.button("", if stars then "PrimaryButton" else "GlassButton", "", if compact then 34.0 else 40.0)
	b:set_min_size(Vector2.new(size.X - pad, if compact then 34 else 40))
	b:set_font_size(if compact then 13 else 15)
	b.pressed:Connect(function()
		self:_pressed(o)
	end)
	v:add_child(b)
	return { node = card, button = b, offer = o, item = it }
end

--- Each card's button: the price, or WEAR / WEARING, or a wait.
function MysteryShop._refresh(self)
	local inv = self:_inv()
	self._purse:set_text(UICtx.commas(math.floor(tonumber(inv.stars) or 0)))
	local p = self._pending
	for _, c in self._cards do
		local o, it, b = c.offer, c.item, c.button
		local owned = inv.owned[o.id] == true
		local worn = it ~= nil and inv.equipped ~= nil and inv.equipped[it.kind] == o.id
		if owned then
			b:set_icon("")
			b:set_text(if worn then "WEARING" else "WEAR")
			b:set_disabled(worn)
		elseif p ~= nil and p.id == o.id then
			b:set_icon("")
			b:set_text("BUYING…")
			b:set_disabled(true)
		elseif o.currency == "stars" then
			b:set_icon("star")
			b:set_text(UICtx.commas(o.price))
			b:set_disabled(p ~= nil)
		else
			b:set_icon("robux")
			b:set_text(UICtx.commas(Prices.robux(o.product)))
			b:set_disabled(p ~= nil)
		end
	end
end

function MysteryShop._rebuild(self)
	for _, ch in ipairs(self._rows:get_children()) do
		self._rows:remove_child(ch)
		ch:queue_free()
	end
	table.clear(self._cards)
	local ctx = self.ctx
	local compact = ctx.compact == true
	local offers = self:offers()
	self._day = Shop.day(MysteryShop.now())
	local n = #offers
	self._sub:set_text(string.format("%d offers picked for today. Tomorrow they change.", n))
	-- desktop: two rows; phones (wide and short): one row, two past six offers
	local rows = if n <= 3 then 1 elseif compact and n <= 6 then 1 else 2
	local cols = math.max(1, math.ceil(n / rows))
	local area = ctx:clear_rect()
	local gap = if compact then 8 else MysteryShop.GAP
	local base = if compact then MysteryShop.CARD_PHONE else MysteryShop.CARD
	local room = area.Width - (if compact then 32 else 120) - (cols - 1) * gap
	local cw = math.clamp(math.floor(room / cols), 96, base.X)
	local size = Vector2.new(cw, base.Y)
	self._rows:set_separation(gap)
	local i = 0
	for _ = 1, rows do
		local line = UITheme.hbox(gap)
		line:set_alignment(W.ALIGN_CENTER)
		for _ = 1, cols do
			i += 1
			local o = offers[i]
			if o == nil then
				break
			end
			local c = self:_card(o, size, compact)
			table.insert(self._cards, c)
			line:add_child(c.node)
		end
		self._rows:add_child(line)
	end
	self._note:set_min_size(Vector2.new(math.min(cols * cw + (cols - 1) * gap, 560), 0))
	self:_refresh()
end

-- ---------------------------------------------------------------------------------------------
-- Buying
-- ---------------------------------------------------------------------------------------------

function MysteryShop._cancel(self, message: string?)
	self._pending = nil
	if message then
		self:_toast(message)
	end
	self:_refresh()
end

--- An offer's button. An offer paid with Coroas asks once more first (UI/ConfirmBuy, `self.confirm`:
--- UIRoot sets it; 2026-11-11); `confirmed`: the player said yes. Robux have Roblox's own confirmation.
function MysteryShop._pressed(self, o: any, confirmed: boolean?)
	if self._pending ~= nil then
		return
	end
	local inv = self:_inv()
	local s = self.ctx.session
	local it = Cosmetics.item(o.id)
	if inv.owned[o.id] == true then
		-- the player's already: wear it
		if s ~= nil and it ~= nil then
			self.ctx:sfx("click")
			s:equip(it.kind, o.id)
		end
		return
	end
	if not confirmed then
		self:_report("clicked", o.id)
	end
	if o.currency == "stars" then
		local have = tonumber(inv.stars) or 0
		if have < o.price then
			self.ctx:sfx("deny", -6.0)
			self:_toast("Not enough Stars.")
			return
		end
		if not confirmed and self.confirm ~= nil then
			-- (everything above is checked again when they confirm)
			self.ctx:sfx("click")
			self.confirm:ask({
				owner = self,
				what = UITheme.tr(if it ~= nil then it.name else "?"),
				price = o.price,
				balance = have,
			}, function()
				self:_pressed(o, true)
			end)
			return
		end
		if s == nil or type(s.shop_buy) ~= "function" or not s:shop_buy(o.id) then
			self:_toast("Couldn't reach the server. Try again in a moment.")
			return
		end
		self._pending = { id = o.id, phase = "buy", since = os.clock() }
		self:_refresh()
		return
	end
	local prod = product_of(o)
	if prod == nil then
		self.ctx:sfx("deny", -6.0)
		self:_toast("This offer can't be bought yet.")
		return
	end
	-- the server learns which item the prompt is for first (one product sells every item of a rarity)
	if s == nil or type(s.shop_pick) ~= "function" or not s:shop_pick(o.id) then
		self:_toast("Couldn't reach the server. Try again in a moment.")
		return
	end
	self._pending = { id = o.id, phase = "pick", product = prod.id, since = os.clock() }
	self:_refresh()
end

local REASONS = {
	["not on sale"] = "This offer has ended.",
	["owned"] = "You already own it.",
	["not enough"] = "Not enough Stars.",
	["no product"] = "This offer can't be bought yet.",
}

--- The server's word: "pick" (the prompt may open), "buy" (a Coroas purchase), "bought" (a Robux
--- purchase arrived).
function MysteryShop._on_result(self, what: string, ok: boolean, item_id: string?, reason: string?)
	local p = self._pending
	if what == "bought" then
		if ok then
			self.ctx:sfx("open")
			self:_toast("It's yours! Find it in your Locker.")
		end
		if p ~= nil and (item_id == nil or p.id == item_id) then
			self._pending = nil
		end
		self:_refresh()
		return
	end
	if p == nil or (item_id ~= nil and p.id ~= item_id) then
		return
	end
	if what == "pick" and p.phase == "pick" then
		if not ok then
			self:_cancel(REASONS[reason or ""] or "Couldn't buy it right now. Nothing was taken.")
			return
		end
		p.phase = "prompt"
		p.since = os.clock()
		local prompted = IS_ROBLOX
			and pcall(function()
				game:GetService("MarketplaceService"):PromptProductPurchase(game:GetService("Players").LocalPlayer, p.product)
			end)
		if not prompted then
			self:_cancel("Purchases aren't available right now.")
		end
	elseif what == "buy" and p.phase == "buy" then
		if ok then
			self._pending = nil
			self.ctx:sfx("open")
			self:_toast("It's yours! Find it in your Locker.")
			self:_refresh()
		else
			self:_cancel(REASONS[reason or ""] or "Couldn't buy it right now. Nothing was taken.")
		end
	end
end

function MysteryShop._on_prompt_done(self, product_id: number, purchased: boolean)
	local p = self._pending
	if p == nil or p.phase ~= "prompt" or product_id ~= p.product then
		return
	end
	if not purchased then
		self:_cancel(nil)
		return
	end
	-- bought: the server stores the item and says so ("bought", or the inventory shows it)
	p.phase = "grant"
	p.since = os.clock()
end

function MysteryShop._on_inventory(self)
	local p = self._pending
	if p ~= nil and self:_inv().owned[p.id] == true then
		self._pending = nil
	end
	if self.is_open then
		self:_refresh()
	end
end

--- Once a second: a purchase that never came back gives up; a new day brings new offers.
function MysteryShop.tick(self)
	local p = self._pending
	if p ~= nil then
		local limit = if p.phase == "prompt" then 180 else MysteryShop.GRANT_WAIT_S
		if os.clock() - p.since > limit then
			self:_cancel(
				if p.phase == "grant"
					then "Your purchase is on its way: it will show up in a moment."
					elseif p.phase == "prompt" then nil
					else "Couldn't reach the server. Try again in a moment."
			)
		end
	end
	if self.is_open and Shop.day(MysteryShop.now()) ~= self._day then
		self:_rebuild()
		self:_center()
	end
end

function MysteryShop._process(self, _dt: number)
	if not self.is_open then
		return
	end
	local left = math.floor(Shop.next_in(MysteryShop.now()))
	if left ~= self._clock_shown then
		self._clock_shown = left
		self._clock:set_text(MysteryShop.clock(left))
	end
end

-- ---------------------------------------------------------------------------------------------
-- Open / close / layout
-- ---------------------------------------------------------------------------------------------

function MysteryShop.open(self)
	if self.is_open then
		return
	end
	self.is_open = true
	self:_report("opened")
	local keys = {}
	for _, r in Cosmetics.RARITIES do
		table.insert(keys, Shop.product_key(r.id))
	end
	Prices.fetch_keys(keys)
	self:set_visible(true)
	self:apply_layout()
	self._panel:set_modulate_a(1.0)
	self._dim:set_modulate_a(0.0)
	W.fade(self._dim, 1.0, 0.2)
	UICtx.pop_in(self._panel, 0.0, 0.94, 0.3)
	self.ctx:sfx("open")
	self:_process(0)
end

function MysteryShop.close(self)
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

function MysteryShop.apply_layout(self)
	local compact = self.ctx.compact == true
	self._panel:set_padding(if compact then 12 else 22, if compact then 8 else 18, if compact then 12 else 22, if compact then 8 else 18)
	self._v:set_separation(if compact then 6 else 12)
	self._title:set_font_size(if compact then 15 else 22)
	self._sub:set_visible(not compact)
	self._note:set_font_size(if compact then 10 else 11)
	if self.is_open then
		self:_rebuild()
	end
	self:_center()
end

function MysteryShop._center(self)
	local area = self.ctx:clear_rect()
	local pn = self._panel
	local sz = pn:get_combined_minimum_size()
	local p = area.Min + (Vector2.new(area.Width, area.Height) - sz) * 0.5
	local y = math.max(p.Y, area.Min.Y + 4.0)
	local rp = Vector2.new(math.floor(p.X + 0.5), math.floor(y + 0.5))
	pn:set_offsets(rp.X, rp.Y, rp.X, rp.Y)
	pn:reset_size()
end

return MysteryShop
