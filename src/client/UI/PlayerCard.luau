--!nocheck
-- The player's card on the title screen (the owner, 2026-11-12): who they are at a glance.
--
--   [flag] Name
--   CAVALEIRO   142 / 300          the ranked tier of the month (Data/Ranked) and the way to the next
--   [=======-------]
--   [trophy] 12 vitórias  [skull] 87 reinos        public matches over the player's life
--   [pet] Mascote: Fênix                             the pet worn (the kingdom's mascot on the map)
--   Login 3/7  ·  amanhã +1.500                      the daily login reward (Data/Login)
--
-- It only shows: nothing in it is pressed. TitleScreen places it (apply_layout) and hides it where
-- there is no room. Methods: refresh(), card_size() -> Vector2.
local UITheme = require("./UITheme")
local UICtx = require("./UICtx")
local W = require("./Widgets")

local PlayerCard = W.class(W.Control)

PlayerCard.WIDTH = 236.0
PlayerCard.WIDTH_COMPACT = 204.0

local function color_of(hex: any): Color3
	local h = tonumber(hex) or 0xECBE5C
	return Color3.fromRGB((h // 65536) % 256, (h // 256) % 256, h % 256)
end

--- A label's text as it is (names and sentences put together here are not for the dictionary).
local function verbatim(l: any, s: string)
	if s == l.text then
		return
	end
	l.text = s
	if l:_min_depends_on_text() then
		l:update_minimum_size()
	end
	l:_redraw()
end

local function picture(px: number, py: number): (any, any)
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.ScaleType = Enum.ScaleType.Fit
	local node = W.wrap(img)
	node:set_min_size(Vector2.new(px, py))
	node.size_flags_vertical = W.SHRINK_CENTER
	node:set_mouse_filter(W.MOUSE_IGNORE)
	return node, img
end

--- "1 vitória" / "12 vitórias": a count with its word, in Portuguese.
function PlayerCard.count(n: number, one: string, many: string): string
	return string.format("%s %s", UICtx.commas(n), if n == 1 then one else many)
end

--- The card's texts for a session (nil: an empty card), apart from the widgets:
--- { name, tier, tier_color, points, frac, wins, kills, pet?, pet_item?, flag_item?, login }.
function PlayerCard.model(ctx: any): any
	local s = ctx.session
	local inv = if s ~= nil and type(s.inventory) == "table" then s.inventory else {}
	local Ranked = UICtx.data("Ranked")
	local Login = UICtx.data("Login")
	local Cosmetics = UICtx.data("Cosmetics")
	local now = os.time()
	if s ~= nil and type(s.server_unix) == "function" then
		local ok, t = pcall(s.server_unix, s)
		if ok and type(t) == "number" then
			now = t
		end
	end
	local view = Ranked.view(inv.ranked, now)
	local tier = Ranked.TIERS[view.tier]
	local frac = 1.0
	if view.next ~= nil then
		frac = math.clamp((view.points - view.at) / math.max(view.next - view.at, 1), 0, 1)
	end
	local stats = if type(inv.stats) == "table" then inv.stats else {}
	local eq = if type(inv.equipped) == "table" then inv.equipped else {}
	local pet = if type(eq.pet) == "string" then Cosmetics.item(eq.pet) else nil
	local flag = if type(eq.flag) == "string" then Cosmetics.item(eq.flag) else nil
	local login = Login.peek(inv.login, now)
	local login_text
	if login.available then
		login_text = string.format("Login diário: dia %d de %d", login.index, Login.DAYS)
	else
		-- (short: the card is narrow. "Login 3/7  ·  amanhã +1.500", "Login 6/7  ·  amanhã baú grátis")
		local nxt = Login.REWARDS[login.next]
		local what = if (tonumber(nxt.crate) or 0) > 0 then "baú grátis" else "+" .. UICtx.commas(tonumber(nxt.stars) or 0)
		login_text = string.format("Login %d/%d  ·  amanhã %s", login.index, Login.DAYS, what)
	end
	return {
		name = if type(ctx.username) == "function" then ctx:username() else "",
		tier = UICtx.data("Lang").upper(tier.name),
		tier_color = color_of(tier.color),
		points = if view.next ~= nil
			then string.format("%s / %s", UICtx.commas(view.points), UICtx.commas(view.next))
			else UICtx.commas(view.points),
		frac = frac,
		wins = PlayerCard.count(math.floor(tonumber(stats.wins) or 0), "vitória", "vitórias"),
		kills = PlayerCard.count(math.floor(tonumber(stats.kills) or 0), "reino", "reinos"),
		pet = if pet ~= nil and pet.kind == "pet" then "Mascote: " .. tostring(pet.name or "") else nil,
		pet_item = if pet ~= nil and pet.kind == "pet" then pet else nil,
		flag_item = if flag ~= nil and flag.kind == "flag" then flag else nil,
		login = login_text,
	}
end

function PlayerCard.new(c: any)
	local self = setmetatable({}, PlayerCard.__mt)
	W.Control._init(self)
	self.ctx = c
	self.name = "PlayerCard"
	self:set_mouse_filter(W.MOUSE_IGNORE)
	local panel = W.Panel.new()
	panel:set_mouse_filter(W.MOUSE_IGNORE)
	panel:add_theme_stylebox_override("panel", UITheme.flat(UITheme.GLASS, 12, UITheme.rgba(1, 1, 1, 0.12), 1, 12.0, 10.0))
	panel:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self:add_child(panel)
	self._panel = panel
	local v = UITheme.vbox(5)
	panel:add_child(v)
	self._v = v
	-- the flag and the name
	local top = UITheme.hbox(8)
	v:add_child(top)
	self._flag, self._flag_img = picture(27, 18)
	self._flag:set_visible(false)
	top:add_child(self._flag)
	self._name = UITheme.label("", 15, 800, UITheme.TEXT)
	self._name.clip_text = true
	self._name.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	self._name.size_flags_horizontal = W.EXPAND_FILL
	self._name.size_flags_vertical = W.SHRINK_CENTER
	top:add_child(self._name)
	-- the tier and the points, then the way to the next tier
	local rank = UITheme.hbox(8)
	v:add_child(rank)
	self._tier = UITheme.label("", 12, 800, UITheme.GOLD, 2)
	self._tier.size_flags_horizontal = W.EXPAND_FILL
	rank:add_child(self._tier)
	self._points = UITheme.label("", 12, 700, UITheme.TEXT_2)
	rank:add_child(self._points)
	local bar = W.Control.new()
	bar:set_mouse_filter(W.MOUSE_IGNORE)
	bar:set_min_size(Vector2.new(0, 5))
	v:add_child(bar)
	local back = W.Panel.new()
	back:set_mouse_filter(W.MOUSE_IGNORE)
	back:add_theme_stylebox_override("panel", UITheme.flat(UITheme.rgba(1, 1, 1, 0.1), 3, UITheme.CLEAR, 0, 0, 0))
	back:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	bar:add_child(back)
	local fill = W.Panel.new()
	fill:set_mouse_filter(W.MOUSE_IGNORE)
	bar:add_child(fill)
	self._fill = fill
	-- victories and kingdoms destroyed
	local stats = UITheme.hbox(6)
	v:add_child(stats)
	local trophy = UITheme.icon_rect("leaderboard", 13.0, UITheme.GOLD)
	trophy.size_flags_vertical = W.SHRINK_CENTER
	stats:add_child(trophy)
	self._wins = UITheme.label("", 12, 600, UITheme.TEXT)
	stats:add_child(self._wins)
	local gap = W.Control.new()
	gap:set_min_size(Vector2.new(6, 0))
	gap:set_mouse_filter(W.MOUSE_IGNORE)
	stats:add_child(gap)
	local skull = UITheme.icon_rect("skull", 13.0, UITheme.RED)
	skull.size_flags_vertical = W.SHRINK_CENTER
	stats:add_child(skull)
	self._kills = UITheme.label("", 12, 600, UITheme.TEXT)
	stats:add_child(self._kills)
	-- the pet worn
	local petrow = UITheme.hbox(6)
	v:add_child(petrow)
	self._pet_row = petrow
	self._pet, self._pet_img = picture(18, 18)
	petrow:add_child(self._pet)
	self._pet_l = UITheme.label("", 12, 600, UITheme.TEXT_2)
	self._pet_l.clip_text = true
	self._pet_l.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	self._pet_l.size_flags_horizontal = W.EXPAND_FILL
	self._pet_l.size_flags_vertical = W.SHRINK_CENTER
	petrow:add_child(self._pet_l)
	-- the daily login reward
	self._login = UITheme.label("", 11, 600, UITheme.GOLD)
	self._login.clip_text = true
	self._login.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	v:add_child(self._login)
	self:refresh()
	return self
end

local function show(img: any, it: any)
	local Cosmetics = UICtx.data("Cosmetics")
	local image, x, y, w, h = Cosmetics.image_of(it)
	img.Image = image
	img.ImageRectOffset = Vector2.new(x, y)
	img.ImageRectSize = Vector2.new(w, h)
end

--- Reads the session again (the inventory changed, the title came back).
function PlayerCard.refresh(self)
	local m = PlayerCard.model(self.ctx)
	self.model_shown = m
	verbatim(self._name, m.name)
	verbatim(self._tier, m.tier)
	self._tier:set_color(m.tier_color)
	verbatim(self._points, m.points)
	self._fill:add_theme_stylebox_override("panel", UITheme.flat(m.tier_color, 3, UITheme.CLEAR, 0, 0, 0))
	self._fill:set_anchors(0, 0, m.frac, 1)
	self._fill:set_offsets(0, 0, 0, 0)
	self._fill:set_visible(m.frac > 0)
	verbatim(self._wins, m.wins)
	verbatim(self._kills, m.kills)
	self._flag:set_visible(m.flag_item ~= nil)
	if m.flag_item ~= nil then
		show(self._flag_img, m.flag_item)
	end
	self._pet_row:set_visible(m.pet_item ~= nil)
	if m.pet_item ~= nil then
		show(self._pet_img, m.pet_item)
		verbatim(self._pet_l, m.pet)
	end
	verbatim(self._login, m.login)
end

--- The card's size: WIDTH (phones: WIDTH_COMPACT) by what its lines need.
function PlayerCard.card_size(self): Vector2
	local w = if self.ctx.compact then PlayerCard.WIDTH_COMPACT else PlayerCard.WIDTH
	local min = self._panel:get_combined_minimum_size()
	return Vector2.new(w, math.max(min.Y, 40.0))
end

return PlayerCard
