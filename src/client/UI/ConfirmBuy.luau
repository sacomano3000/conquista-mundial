--!nonstrict
-- "Confirm the purchase?" (2026-11-11): a purchase paid with Coroas asks once more before anything is
-- spent, so a press by accident buys nothing. A small modal window above the window that sells (the
-- Coleção's crate, its opening show's "another", an offer of the Loja Misteriosa, an item of the
-- Arsenal): what is bought, its price, what the player has and will have left, and two answers.
--   * Cancel, a press outside the window, or the seller closing meanwhile: nothing is bought.
--   * Confirm: the seller's own purchase runs (and checks everything again).
--   * Its buttons take no press for ARM_S after it opens: the second press of a double click on the
--     price button does not answer for the player.
-- Robux purchases do not pass here: Roblox shows its own confirmation.
-- Signals: answered(yes: boolean), closed.

local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local UICtx = require("./UICtx")
local Signal = UITheme.core("Signal")

local ConfirmBuy = W.class(W.Control)

--- The text's width on a computer; a phone's screen takes what it has (apply_layout).
ConfirmBuy.TEXT_W = 320.0
--- After it opens, how long its buttons (and the press outside) do nothing.
ConfirmBuy.ARM_S = 0.35
--- After it closes, how long `busy` still answers true (see there).
ConfirmBuy.LINGER_S = 0.3
--- The clock (the tests set their own).
ConfirmBuy.now = os.clock

function ConfirmBuy.new(c: any)
	local self = setmetatable({}, ConfirmBuy.__mt)
	W.Control._init(self)
	self.ctx = c
	--- (yes) the question was answered: Confirm, or Cancel / a press outside / the seller closed
	self.answered = Signal.new()
	self.closed = Signal.new()
	self.is_open = false
	self._owner = nil
	self._on_yes = nil
	self._since = 0.0
	self._closed_at = -math.huge
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self:set_mouse_filter(W.MOUSE_STOP)
	self:set_visible(false)
	self._dim = W.ColorRect.new(UITheme.rgba(0.0275, 0.0196, 0.0314, 0.6))
	self._dim:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self._dim.gui_input:Connect(function(e)
		-- (a press on the window's own ground reaches the dim too: only one outside it cancels)
		if e.pressed and not self._panel:has_global_point(e.global_position) then
			self:_answer(false)
		end
	end)
	self:add_child(self._dim)
	self._panel = GlassPanel.new(24.0, 22.0, 18, true, 34)
	self._panel:set_tint(UITheme.rgba(0.0706, 0.0627, 0.0745, 0.97))
	self:add_child(self._panel)
	local v = UITheme.vbox(12)
	self._panel:add_child(v)
	self._title = UITheme.label("CONFIRM PURCHASE?", 20, 800, UITheme.TEXT, 2)
	v:add_child(self._title)
	-- what is bought
	self._what = UITheme.label("", 15, 700, UITheme.TEXT)
	self._what:set_autowrap(true)
	v:add_child(self._what)
	-- its price: the currency's icon and the amount
	local pay = UITheme.hbox(8)
	local coin = UITheme.icon_rect("star", 20, UITheme.GOLD)
	coin.size_flags_vertical = W.SHRINK_CENTER
	pay:add_child(coin)
	self._price = UITheme.label("", 18, 800, UITheme.GOLD)
	self._price.size_flags_horizontal = W.EXPAND_FILL
	pay:add_child(self._price)
	v:add_child(pay)
	-- what the player has, and what is left after it
	self._note = UITheme.label("", 12, 500, UITheme.TEXT_3)
	self._note:set_autowrap(true)
	v:add_child(self._note)
	local row = UITheme.hbox(10)
	self._no = UITheme.button("Cancel", "GlassButton", "", 48.0)
	self._no.size_flags_horizontal = W.EXPAND_FILL
	self._no.pressed:Connect(function()
		self:_answer(false)
	end)
	row:add_child(self._no)
	self._yes = UITheme.button("Confirm", "PrimaryButton", "check", 48.0)
	self._yes.size_flags_horizontal = W.EXPAND_FILL
	self._yes.pressed:Connect(function()
		self:_answer(true)
	end)
	row:add_child(self._yes)
	v:add_child(row)
	return self
end

--- Ask before a purchase. `info`: { owner = the window that sells (it calls cancel(self) when it
--- closes), what = the thing's name, price = Coroas, balance = the player's Coroas }. `on_yes` runs
--- once, on Confirm. A question already on screen is dropped unanswered (as a Cancel).
function ConfirmBuy.ask(self, info: any, on_yes: () -> ())
	if self.is_open then
		self:_answer(false, true)
	end
	local price = math.max(0, math.floor(tonumber(info.price) or 0))
	local balance = math.max(0, math.floor(tonumber(info.balance) or 0))
	self._owner = info.owner
	self._on_yes = on_yes
	self._since = ConfirmBuy.now()
	self._what:set_text(tostring(info.what or ""))
	self._price:set_text(UICtx.commas(price) .. " Stars")
	self._note:set_text(
		string.format(
			"You have %s Stars. You'll have %s left.",
			UICtx.commas(balance),
			UICtx.commas(math.max(0, balance - price))
		)
	)
	self.is_open = true
	self:set_visible(true)
	self._panel:set_modulate_a(1.0)
	self:apply_layout()
	self._dim:set_modulate_a(0.0)
	W.fade(self._dim, 1.0, 0.15)
	UICtx.pop_in(self._panel, 0.0, 0.94, 0.22)
	self.ctx:sfx("open")
end

--- Whether the question is on screen, or left it a moment ago. The windows under it ask before a
--- press outside their own ground closes them: Roblox gives a press to every frame under the pointer,
--- so the press that cancels the question reaches their backdrops too, before or after it reached
--- this one.
function ConfirmBuy.busy(self): boolean
	return self.is_open or ConfirmBuy.now() - self._closed_at < ConfirmBuy.LINGER_S
end

--- Whether an answer is taken yet (ARM_S after it opened).
function ConfirmBuy._armed(self): boolean
	return ConfirmBuy.now() - self._since >= ConfirmBuy.ARM_S
end

function ConfirmBuy._answer(self, yes: boolean, now: boolean?)
	if not self.is_open or (not now and not self:_armed()) then
		return
	end
	local go = self._on_yes
	self._on_yes = nil
	self._owner = nil
	self:_hide()
	self.answered:Fire(yes)
	if yes and go ~= nil then
		go()
	end
end

--- Drops the question, nothing bought. With `owner`: only if the question is that window's (a seller
--- that closes takes its question with it).
function ConfirmBuy.cancel(self, owner: any?)
	if not self.is_open or (owner ~= nil and owner ~= self._owner) then
		return
	end
	self:_answer(false, true)
end

function ConfirmBuy._hide(self)
	self.is_open = false
	self._closed_at = ConfirmBuy.now()
	self.ctx:sfx("close")
	local t = self:create_tween():set_parallel(true)
	t:tween_property(self._dim, "modulate:a", 0.0, 0.12)
	t:tween_property(self._panel, "modulate:a", 0.0, 0.12)
	t:chain():tween_callback(function()
		if not self.is_open then
			self:set_visible(false)
		end
	end)
	self.closed:Fire()
end

function ConfirmBuy.apply_layout(self)
	local ctx = self.ctx
	local area = ctx:clear_rect()
	-- (a phone held upright: the text takes what the screen has)
	local w = math.clamp(area.Width - 80.0, 200.0, ConfirmBuy.TEXT_W)
	for _, l in { self._what, self._note } do
		l:set_min_size(Vector2.new(w, 0))
	end
	local sz = self._panel:get_combined_minimum_size()
	local p = area.Min + (Vector2.new(area.Width, area.Height) - sz) * 0.5
	local y = math.max(p.Y, area.Min.Y + 4.0)
	local rp = Vector2.new(math.floor(p.X + 0.5), math.floor(y + 0.5))
	self._panel:set_offsets(rp.X, rp.Y, rp.X, rp.Y)
	self._panel:reset_size()
end

return ConfirmBuy
