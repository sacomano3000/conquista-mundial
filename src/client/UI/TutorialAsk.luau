--!nonstrict
-- "Do you want the tutorial?" (2026-11-10): a new player is asked before their first match starts by
-- itself as the tutorial (UIRoot._tutorial_step). A small modal window: what the tutorial is, what
-- finishing it pays (Data/Tutorial.STARS), and two answers. A press outside it does nothing: the
-- window waits for one of the two.
-- Signals: answered(yes: boolean), closed.

local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local UICtx = require("./UICtx")
local Signal = UITheme.core("Signal")
local TutorialData = UICtx.data("Tutorial")

local TutorialAsk = W.class(W.Control)

--- The text's width on a computer; a phone's screen takes what it has (apply_layout).
TutorialAsk.TEXT_W = 380.0

function TutorialAsk.new(c: any)
	local self = setmetatable({}, TutorialAsk.__mt)
	W.Control._init(self)
	self.ctx = c
	--- (yes) one of the two buttons was pressed
	self.answered = Signal.new()
	self.closed = Signal.new()
	self.is_open = false
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self:set_mouse_filter(W.MOUSE_STOP)
	self:set_visible(false)
	self._dim = W.ColorRect.new(UITheme.rgba(0.0275, 0.0196, 0.0314, 0.6))
	self._dim:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self:add_child(self._dim)
	self._panel = GlassPanel.new(24.0, 22.0, 18, true, 34)
	self._panel:set_tint(UITheme.rgba(0.0706, 0.0627, 0.0745, 0.95))
	self:add_child(self._panel)
	local v = UITheme.vbox(12)
	self._panel:add_child(v)
	self._title = UITheme.label("PLAY THE TUTORIAL?", 20, 800, UITheme.TEXT, 2)
	v:add_child(self._title)
	self._text = UITheme.label(
		"A short first match that teaches you to play, step by step. You can skip it at any time.",
		14,
		500,
		UITheme.TEXT
	)
	self._text:set_autowrap(true)
	v:add_child(self._text)
	-- what finishing it pays: the currency's icon and the amount
	local pay = UITheme.hbox(8)
	local coin = UITheme.icon_rect("star", 18, UITheme.GOLD)
	coin.size_flags_vertical = W.SHRINK_CENTER
	pay:add_child(coin)
	self._pay = UITheme.label(
		string.format("Finish it and earn %s Stars.", UICtx.commas(TutorialData.STARS)),
		14,
		700,
		UITheme.GOLD
	)
	self._pay:set_autowrap(true)
	self._pay.size_flags_horizontal = W.EXPAND_FILL
	pay:add_child(self._pay)
	v:add_child(pay)
	self._note =
		UITheme.label("If you skip it, HOW TO PLAY on the main screen explains the game.", 12, 500, UITheme.TEXT_3)
	self._note:set_autowrap(true)
	v:add_child(self._note)
	local row = UITheme.hbox(10)
	self._no = UITheme.button("No, skip it", "GlassButton", "", 48.0)
	self._no.size_flags_horizontal = W.EXPAND_FILL
	self._no.pressed:Connect(function()
		self:_answer(false)
	end)
	row:add_child(self._no)
	self._yes = UITheme.button("Yes, play it", "PrimaryButton", "", 48.0)
	self._yes.size_flags_horizontal = W.EXPAND_FILL
	self._yes.pressed:Connect(function()
		self:_answer(true)
	end)
	row:add_child(self._yes)
	v:add_child(row)
	return self
end

function TutorialAsk._answer(self, yes: boolean)
	if not self.is_open then
		return
	end
	self:close()
	self.answered:Fire(yes)
end

function TutorialAsk.open(self)
	if self.is_open then
		return
	end
	self.is_open = true
	self:set_visible(true)
	self._panel:set_modulate_a(1.0)
	self:apply_layout()
	self._dim:set_modulate_a(0.0)
	W.fade(self._dim, 1.0, 0.2)
	UICtx.pop_in(self._panel, 0.0, 0.94, 0.3)
	self.ctx:sfx("open")
end

--- Closes without an answer (UIRoot: the player is on their way into a match).
function TutorialAsk.close(self)
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

function TutorialAsk.apply_layout(self)
	local ctx = self.ctx
	local area = ctx:clear_rect()
	-- (a phone held upright: the text takes what the screen has)
	local w = math.clamp(area.Width - 80.0, 220.0, TutorialAsk.TEXT_W)
	for _, l in { self._text, self._note } do
		l:set_min_size(Vector2.new(w, 0))
	end
	self._pay:set_min_size(Vector2.new(w - 26.0, 0))
	local sz = self._panel:get_combined_minimum_size()
	local p = area.Min + (Vector2.new(area.Width, area.Height) - sz) * 0.5
	local y = math.max(p.Y, area.Min.Y + 4.0)
	local rp = Vector2.new(math.floor(p.X + 0.5), math.floor(y + 0.5))
	self._panel:set_offsets(rp.X, rp.Y, rp.X, rp.Y)
	self._panel:reset_size()
end

return TutorialAsk
