--!nocheck
-- A headless stand-in for Roblox's GUI objects, so the screens (client/UI) can be built, laid out and
-- "drawn" with lune: no Studio needed to find a screen that fails to build, runs off the window, or
-- sets a property that does not exist.
--
-- Every object is backed by a real instance of the same class from lune's own Roblox database: a
-- property read gives Roblox's default, and a property that does not exist (or is given a value of
-- the wrong type) is written down in Harness.bad. Events can be connected and fired; the layout
-- objects a screen leaves to Roblox (UIGridLayout, UIListLayout, UIPadding) are worked out here.
--
--   local H = require("./ui_harness")           -- (sets the globals: Instance, Enum, Font...)
--   local root, gui = H.root(1280, 720)         -- a kit Root (client/UI/Widgets) on a screen that size
--   H.step(n?)                                  -- run the kit's layout / tweens n frames (default 3)
--   H.rect(obj) -> x, y, w, h                   -- where an object ends up on screen (px)
--   H.dump(gui) -> { ... }                      -- everything visible, for tools/arte/telas.py to draw
--   H.fire(obj, "Activated", ...)               -- fire one of an object's events
--   H.bad                                       -- { ["Class.Property"] = why }
local roblox = require("./prelude")
local G = getfenv() :: any

local H = {}
H.bad = {} :: { [string]: string }
--- properties newer than lune's database, or set with objects it can't hold: not mistakes
H.KNOWN = {
	["ImageLabel.ImageContent"] = true,
	["ImageButton.ImageContent"] = true,
	["ScrollingFrame.ScrollBarImageColor3"] = false,
}

local real_new = roblox.Instance.new
local mocks = setmetatable({}, { __mode = "k" })

local function signal()
	local s = { _fns = {} }
	function s:Connect(fn)
		local c = { Connected = true }
		function c:Disconnect()
			c.Connected = false
			local i = table.find(s._fns, fn)
			if i then
				table.remove(s._fns, i)
			end
		end
		table.insert(s._fns, fn)
		return c
	end
	s.connect = s.Connect
	function s:Once(fn)
		local c
		c = s:Connect(function(...)
			c:Disconnect()
			fn(...)
		end)
		return c
	end
	function s:Wait() end
	function s:Fire(...)
		for _, fn in table.clone(s._fns) do
			fn(...)
		end
	end
	return s
end

local MT = {}
local METHODS = {}

local function is_mock(v: any): boolean
	return type(v) == "table" and mocks[v] == true
end

function METHODS.Destroy(self)
	self.Parent = nil
	for _, c in table.clone(self.__children) do
		c:Destroy()
	end
	rawset(self, "__dead", true)
end
function METHODS.ClearAllChildren(self)
	for _, c in table.clone(self.__children) do
		c:Destroy()
	end
end
function METHODS.GetChildren(self)
	return table.clone(self.__children)
end
function METHODS.GetDescendants(self)
	local out = {}
	local function rec(n)
		for _, c in n.__children do
			table.insert(out, c)
			rec(c)
		end
	end
	rec(self)
	return out
end
function METHODS.FindFirstChild(self, name, deep)
	for _, c in self.__children do
		if c.Name == name then
			return c
		end
	end
	if deep then
		for _, c in self.__children do
			local f = c:FindFirstChild(name, true)
			if f then
				return f
			end
		end
	end
	return nil
end
METHODS.WaitForChild = METHODS.FindFirstChild
function METHODS.IsA(self, class)
	if self.__real then
		return self.__real:IsA(class)
	end
	return self.__class == class
end
function METHODS.FindFirstChildOfClass(self, class)
	for _, c in self.__children do
		if c.__class == class then
			return c
		end
	end
	return nil
end
function METHODS.FindFirstChildWhichIsA(self, class)
	for _, c in self.__children do
		if c:IsA(class) then
			return c
		end
	end
	return nil
end
function METHODS.FindFirstAncestorOfClass(self, class)
	local p = self.__parent
	while p do
		if p.__class == class then
			return p
		end
		p = p.__parent
	end
	return nil
end
function METHODS.IsDescendantOf(self, other)
	local p = self.__parent
	while p do
		if p == other then
			return true
		end
		p = p.__parent
	end
	return false
end
function METHODS.GetPropertyChangedSignal(self, name)
	local k = "~" .. name
	self.__signals[k] = self.__signals[k] or signal()
	return self.__signals[k]
end
function METHODS.GetAttribute(self, k)
	return self.__attrs[k]
end
function METHODS.SetAttribute(self, k, v)
	self.__attrs[k] = v
end
function METHODS.Clone(self)
	local c = H.new(self.__class)
	for k, v in self.__props do
		c[k] = v
	end
	for _, ch in self.__children do
		ch:Clone().Parent = c
	end
	return c
end
for _, name in { "CaptureFocus", "ReleaseFocus", "TweenPosition", "TweenSize", "WritePixelsBuffer", "Play", "Stop", "Cancel", "Pause" } do
	METHODS[name] = function() end
end

local COMPUTED = {}

MT.__index = function(self, k)
	if k == "Parent" then
		return rawget(self, "__parent")
	elseif k == "ClassName" then
		return rawget(self, "__class")
	end
	if type(k) == "string" and string.sub(k, 1, 2) == "__" then
		return nil -- (the harness's own fields: __parent of a root)
	end
	local m = METHODS[k]
	if m ~= nil then
		return m
	end
	local c = COMPUTED[k]
	if c ~= nil then
		return c(self)
	end
	local props = rawget(self, "__props")
	local v = props[k]
	if v ~= nil then
		return v
	end
	local real = rawget(self, "__real")
	if real ~= nil then
		local ok, rv = pcall(function()
			return real[k]
		end)
		if ok and type(rv) ~= "function" then
			return rv
		end
	end
	if props.__set and props.__set[k] then
		return nil -- (a property set to nil)
	end
	-- anything else is taken for an event
	local sigs = rawget(self, "__signals")
	sigs[k] = sigs[k] or signal()
	return sigs[k]
end

MT.__newindex = function(self, k, v)
	if k == "Parent" then
		local old = rawget(self, "__parent")
		if old == v then
			return
		end
		if old ~= nil then
			local i = table.find(old.__children, self)
			if i then
				table.remove(old.__children, i)
			end
		end
		rawset(self, "__parent", v)
		if v ~= nil then
			assert(is_mock(v), "Parent must be an Instance")
			table.insert(v.__children, self)
			local function added(p)
				while p ~= nil do
					local s = p.__signals.DescendantAdded
					if s then
						s:Fire(self)
					end
					p = p.__parent
				end
			end
			local s = v.__signals.ChildAdded
			if s then
				s:Fire(self)
			end
			added(v)
		end
		return
	end
	local props = rawget(self, "__props")
	props.__set = props.__set or {}
	props.__set[k] = true
	local before = props[k]
	props[k] = v
	local real = rawget(self, "__real")
	local key = rawget(self, "__class") .. "." .. tostring(k)
	if H.KNOWN[key] == nil and v ~= nil and not is_mock(v) then
		if real == nil then
			H.bad[key] = "unknown class"
		else
			local ok, err = pcall(function()
				real[k] = v
			end)
			if not ok then
				H.bad[key] = (string.match(tostring(err), "^[^\n]*") or "?") .. " (" .. tostring(v) .. ")"
			end
		end
	end
	if before ~= v then
		local s = rawget(self, "__signals")["~" .. tostring(k)]
		if s then
			s:Fire()
		end
	end
end

MT.__tostring = function(self)
	return rawget(self, "__class") .. "(" .. tostring(self.Name) .. ")"
end

function H.new(class: string, parent: any?)
	local ok, real = pcall(real_new, class)
	local self = {
		__class = class,
		__real = if ok then real else nil,
		__children = {},
		__props = {},
		__signals = {},
		__attrs = {},
	}
	mocks[self] = true
	setmetatable(self, MT)
	if not ok then
		H.bad[class] = "unknown class"
	end
	if parent ~= nil then
		self.Parent = parent
	end
	return self
end

function H.fire(obj: any, event: string, ...)
	local s = obj.__signals[event]
	if s then
		s:Fire(...)
		return true
	end
	return false
end

-- ---------------------------------------------------------------------------------------------
-- Geometry: where Roblox would put an object
-- ---------------------------------------------------------------------------------------------

H.view = Vector2.new(1280, 720)

local function layout_child(parent: any, class: string): any
	for _, c in parent.__children do
		if c.__class == class then
			return c
		end
	end
	return nil
end

local function gui_children(parent: any): { any }
	local out = {}
	for _, c in parent.__children do
		if c:IsA("GuiObject") and c.Visible ~= false then
			table.insert(out, c)
		end
	end
	return out
end

local rect_of

--- The UIScale an object is drawn under: its own times its ancestors' (offsets grow by it).
local function scale_of(obj: any): number
	local k = 1
	local o = obj
	while o ~= nil and o.__children ~= nil do
		local sc = layout_child(o, "UIScale")
		if sc ~= nil then
			k *= sc.Scale
		end
		o = o.__parent
	end
	return k
end
H.scale_of = scale_of

--- The area a parent gives its children: its own rect less its UIPadding.
local function content_rect(parent: any): (number, number, number, number)
	local x, y, w, h = rect_of(parent)
	local pad = layout_child(parent, "UIPadding")
	if pad ~= nil then
		local k = scale_of(parent)
		local l = pad.PaddingLeft.Scale * w + pad.PaddingLeft.Offset * k
		local r = pad.PaddingRight.Scale * w + pad.PaddingRight.Offset * k
		local t = pad.PaddingTop.Scale * h + pad.PaddingTop.Offset * k
		local b = pad.PaddingBottom.Scale * h + pad.PaddingBottom.Offset * k
		x, y, w, h = x + l, y + t, w - l - r, h - t - b
	end
	if parent.__class == "ScrollingFrame" then
		y -= parent.CanvasPosition.Y
		x -= parent.CanvasPosition.X
	end
	return x, y, w, h
end

local own_size

--- A text object's own width and height in px (its letters: UITheme's Rubik metrics).
local function text_extent(obj: any): (number, number)
	local Theme = require("../src/client/UI/UITheme")
	local Lang = require("../src/shared/Data/Lang")
	local text = obj.Text
	if Lang.on() then
		text = Lang.t(text)
	end
	local ts = obj.TextSize * scale_of(obj)
	local ok, weight = pcall(function()
		return obj.FontFace.Weight.Value
	end)
	local widest, lines = 0, 0
	for line in string.gmatch(text .. "\n", "(.-)\n") do
		lines += 1
		local okw, w = pcall(Theme.text_width, line, ts, if ok then weight else 400)
		widest = math.max(widest, if okw then w else #line * ts * 0.55)
	end
	return widest, math.max(1, lines) * ts * 1.185
end

--- What an AutomaticSize object grows to: its text, or its children (laid out by its UIListLayout).
local function auto_extent(obj: any, w: number, h: number): (number, number)
	local c = obj.__class
	local cw, ch = 0, 0
	if c == "TextLabel" or c == "TextButton" or c == "TextBox" then
		cw, ch = text_extent(obj)
	else
		local list = layout_child(obj, "UIListLayout")
		local k = scale_of(obj)
		local n = 0
		for _, kid in gui_children(obj) do
			local kw, kh = own_size(kid, w, h)
			n += 1
			if list ~= nil and list.FillDirection == Enum.FillDirection.Horizontal then
				cw += kw + (if n > 1 then list.Padding.Offset * k else 0)
				ch = math.max(ch, kh)
			elseif list ~= nil then
				ch += kh + (if n > 1 then list.Padding.Offset * k else 0)
				cw = math.max(cw, kw)
			else
				local p, a = kid.Position, kid.AnchorPoint
				cw = math.max(cw, p.X.Offset * k - a.X * kw + kw)
				ch = math.max(ch, p.Y.Offset * k - a.Y * kh + kh)
			end
		end
	end
	local pad = layout_child(obj, "UIPadding")
	if pad ~= nil then
		local k = scale_of(obj)
		cw += (pad.PaddingLeft.Offset + pad.PaddingRight.Offset) * k
		ch += (pad.PaddingTop.Offset + pad.PaddingBottom.Offset) * k
	end
	return cw, ch
end

own_size = function(obj: any, pw: number, ph: number): (number, number)
	local s = obj.Size
	local k = scale_of(obj)
	local w, h = s.X.Scale * pw + s.X.Offset * k, s.Y.Scale * ph + s.Y.Offset * k
	local auto = obj.AutomaticSize
	if auto ~= nil and auto ~= Enum.AutomaticSize.None then
		local cw, ch = auto_extent(obj, w, h)
		if auto == Enum.AutomaticSize.X or auto == Enum.AutomaticSize.XY then
			w = math.max(w, cw)
		end
		if auto == Enum.AutomaticSize.Y or auto == Enum.AutomaticSize.XY then
			h = math.max(h, ch)
		end
	end
	local ar = layout_child(obj, "UIAspectRatioConstraint")
	if ar ~= nil and ar.AspectRatio > 0 then
		if w / math.max(h, 1e-6) > ar.AspectRatio then
			w = h * ar.AspectRatio
		else
			h = w / ar.AspectRatio
		end
	end
	return w, h
end

rect_of = function(obj: any): (number, number, number, number)
	local parent = obj.__parent
	if parent == nil or not obj:IsA("GuiObject") then
		return 0, 0, H.view.X, H.view.Y
	end
	if not parent:IsA("GuiObject") then
		-- a ScreenGui: the whole screen
		local w, h = own_size(obj, H.view.X, H.view.Y)
		local p, a = obj.Position, obj.AnchorPoint
		return p.X.Scale * H.view.X + p.X.Offset - a.X * w, p.Y.Scale * H.view.Y + p.Y.Offset - a.Y * h, w, h
	end
	local px, py, pw, ph = content_rect(parent)
	local pk = scale_of(parent)
	local w, h = own_size(obj, pw, ph)
	local grid = layout_child(parent, "UIGridLayout")
	local list = layout_child(parent, "UIListLayout")
	if grid ~= nil or list ~= nil then
		local kids = gui_children(parent)
		table.sort(kids, function(a, b)
			if a.LayoutOrder ~= b.LayoutOrder then
				return a.LayoutOrder < b.LayoutOrder
			end
			return table.find(parent.__children, a) < table.find(parent.__children, b)
		end)
		local i = table.find(kids, obj)
		if i == nil then
			return px, py, 0, 0
		end
		if grid ~= nil then
			local cw = grid.CellSize.X.Scale * pw + grid.CellSize.X.Offset * pk
			local ch = grid.CellSize.Y.Scale * ph + grid.CellSize.Y.Offset * pk
			local gx = grid.CellPadding.X.Scale * pw + grid.CellPadding.X.Offset * pk
			local gy = grid.CellPadding.Y.Scale * ph + grid.CellPadding.Y.Offset * pk
			local cols = math.max(1, math.floor((pw + gx) / math.max(cw + gx, 1)))
			local col, row = (i - 1) % cols, (i - 1) // cols
			return px + col * (cw + gx), py + row * (ch + gy), cw, ch
		end
		local horizontal = list.FillDirection == Enum.FillDirection.Horizontal
		local gap = list.Padding.Scale * (if horizontal then pw else ph) + list.Padding.Offset * pk
		local total = 0
		local sizes = {}
		for j, k in kids do
			local kw, kh = own_size(k, pw, ph)
			sizes[j] = { kw, kh }
			total += (if horizontal then kw else kh) + (if j > 1 then gap else 0)
		end
		local at = 0
		for j = 1, i - 1 do
			at += (if horizontal then sizes[j][1] else sizes[j][2]) + gap
		end
		local main = if horizontal then pw else ph
		local ha, va = list.HorizontalAlignment, list.VerticalAlignment
		local x, y
		if horizontal then
			local off = if ha == Enum.HorizontalAlignment.Center then (main - total) / 2 elseif ha == Enum.HorizontalAlignment.Right then main - total else 0
			x = px + off + at
			y = py + (if va == Enum.VerticalAlignment.Center then (ph - h) / 2 elseif va == Enum.VerticalAlignment.Bottom then ph - h else 0)
		else
			local off = if va == Enum.VerticalAlignment.Center then (main - total) / 2 elseif va == Enum.VerticalAlignment.Bottom then main - total else 0
			y = py + off + at
			x = px + (if ha == Enum.HorizontalAlignment.Center then (pw - w) / 2 elseif ha == Enum.HorizontalAlignment.Right then pw - w else 0)
		end
		return x, y, w, h
	end
	local p, a = obj.Position, obj.AnchorPoint
	return px + p.X.Scale * pw + p.X.Offset * pk - a.X * w, py + p.Y.Scale * ph + p.Y.Offset * pk - a.Y * h, w, h
end
H.rect = rect_of

COMPUTED.AbsoluteSize = function(self)
	if not self:IsA("GuiObject") then
		return H.view
	end
	local _, _, w, h = rect_of(self)
	return Vector2.new(w, h)
end
COMPUTED.AbsolutePosition = function(self)
	if not self:IsA("GuiObject") then
		return Vector2.zero
	end
	local x, y = rect_of(self)
	return Vector2.new(x, y)
end
COMPUTED.AbsoluteCanvasSize = function(self)
	local _, _, w, h = rect_of(self)
	local bottom = 0
	for _, c in gui_children(self) do
		local _, cy, _, ch = rect_of(c)
		local _, py = content_rect(self)
		bottom = math.max(bottom, cy + ch - py)
	end
	return Vector2.new(w, math.max(h, bottom))
end
COMPUTED.TextBounds = function(self)
	local text = self.__props.Text or ""
	local ts = self.__props.TextSize or 14
	return Vector2.new(utf8.len(text) * ts * 0.56, ts * 1.2)
end
COMPUTED.TextFits = function()
	return true
end

-- ---------------------------------------------------------------------------------------------
-- Globals and the kit
-- ---------------------------------------------------------------------------------------------

for _, n in { "Enum", "Font", "ColorSequence", "ColorSequenceKeypoint", "NumberSequence", "NumberSequenceKeypoint", "Content", "TweenInfo" } do
	if (roblox :: any)[n] ~= nil then
		G[n] = (roblox :: any)[n]
	end
end
G.Instance = { new = H.new }
-- `task`: what is spawned runs at once; what is delayed waits for H.flush()
H.later = {} :: { any }
G.task = {
	spawn = function(fn, ...)
		if type(fn) == "function" then
			fn(...)
		end
	end,
	defer = function(fn, ...)
		table.insert(H.later, { fn, ... })
	end,
	delay = function(_s, fn, ...)
		table.insert(H.later, { fn, ... })
	end,
	-- (a frame goes by; a test that plays something written as a loop of waits sets H.on_wait to
	-- do, between two of them, what a player or the frame would)
	wait = function()
		if H.on_wait ~= nil then
			H.on_wait()
		end
		return 1 / 60
	end,
	cancel = function() end,
}
--- Runs what was deferred or delayed.
function H.flush()
	local list = H.later
	H.later = {}
	for _, e in list do
		if type(e[1]) == "function" then
			e[1](table.unpack(e, 2))
		end
	end
end
if G.Content == nil or G.Content.none == nil then
	G.Content = { none = "none", fromObject = function(o)
		return o
	end, fromUri = function(u)
		return u
	end }
end

local W: any = nil

--- A kit Root on a screen of w x h px (touch: a phone). Returns (root, the ScreenGui).
function H.root(w: number, h: number, touch: boolean?): (any, any)
	W = require("../src/client/UI/Widgets")
	H.view = Vector2.new(w, h)
	W.set_external_driver(true)
	local gui = H.new("ScreenGui")
	gui.Name = "Test"
	local root = W.Root.new(gui, { touch_device = touch == true })
	return root, gui
end

function H.step(n: number?)
	for _ = 1, n or 3 do
		W.step(1 / 60)
	end
end

-- ---------------------------------------------------------------------------------------------
-- Dump: every visible object as a flat list, back to front
-- ---------------------------------------------------------------------------------------------

local function hex(c: any): string
	return string.format("%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

function H.dump(gui: any): { any }
	local out = {}
	local OwnArt = require("../src/shared/Assets/OwnArt")
	local Lang = require("../src/shared/Data/Lang")
	local function rec(obj: any, clip: { number }?, alpha: number)
		if not obj:IsA("GuiObject") then
			for _, c in obj.__children do
				rec(c, clip, alpha)
			end
			return
		end
		if obj.Visible == false then
			return
		end
		local x, y, w, h = rect_of(obj)
		local e: any = {
			class = obj.__class,
			name = obj.Name,
			x = x,
			y = y,
			w = w,
			h = h,
			z = obj.ZIndex,
			bg = hex(obj.BackgroundColor3),
			bga = 1 - obj.BackgroundTransparency,
			rot = obj.Rotation,
		}
		if clip ~= nil then
			e.clip = clip
		end
		local corner = layout_child(obj, "UICorner")
		if corner ~= nil then
			e.radius = corner.CornerRadius.Scale * math.min(w, h) + corner.CornerRadius.Offset * scale_of(obj)
		end
		local stroke = layout_child(obj, "UIStroke")
		if stroke ~= nil and stroke.Enabled ~= false then
			e.stroke = { hex(stroke.Color), 1 - stroke.Transparency, stroke.Thickness * scale_of(obj) }
			-- (on a text object a stroke outlines the letters, unless it asks for the border)
			local c = obj.__class
			if (c == "TextLabel" or c == "TextButton" or c == "TextBox") and stroke.ApplyStrokeMode ~= Enum.ApplyStrokeMode.Border then
				e.text_stroke = true
			end
		end
		local grad = layout_child(obj, "UIGradient")
		if grad ~= nil and grad.Enabled ~= false then
			local keys = {}
			for _, kp in grad.Color.Keypoints do
				table.insert(keys, { kp.Time, hex(kp.Value) })
			end
			local ts = {}
			for _, kp in grad.Transparency.Keypoints do
				table.insert(ts, { kp.Time, 1 - kp.Value })
			end
			e.grad = { rot = grad.Rotation, colors = keys, alphas = ts }
		end
		local class = obj.__class
		if class == "TextLabel" or class == "TextButton" or class == "TextBox" then
			local text = obj.Text
			if class == "TextBox" and text == "" then
				text = obj.PlaceholderText
			end
			e.text = if Lang.on() then Lang.t(text) else text
			e.tc = hex(obj.TextColor3)
			e.ta = 1 - obj.TextTransparency
			e.ts = obj.TextSize * scale_of(obj)
			e.tx = obj.TextXAlignment.Name
			e.ty = obj.TextYAlignment.Name
			e.wrap = obj.TextWrapped
			e.scaled = obj.TextScaled
			local ok, weight = pcall(function()
				return obj.FontFace.Weight.Value
			end)
			e.weight = if ok then weight else 400
		end
		if class == "ImageLabel" or class == "ImageButton" then
			e.image = obj.Image
			if e.image == "" and obj.__props.ImageContent ~= nil and obj.__props.ImageContent ~= "none" then
				e.image = "content"
			end
			e.ic = hex(obj.ImageColor3)
			e.ia = 1 - obj.ImageTransparency
			e.rx, e.ry = obj.ImageRectOffset.X, obj.ImageRectOffset.Y
			e.rw, e.rh = obj.ImageRectSize.X, obj.ImageRectSize.Y
			e.fit = obj.ScaleType.Name
			e.key = if e.image ~= "" then OwnArt.key_for(e.image) else nil
			e.skin = obj:GetAttribute("Skin")
		end
		table.insert(out, e)
		local inner = clip
		if obj.ClipsDescendants or class == "ScrollingFrame" then
			inner = { x, y, x + w, y + h }
			if clip ~= nil then
				inner = { math.max(x, clip[1]), math.max(y, clip[2]), math.min(x + w, clip[3]), math.min(y + h, clip[4]) }
			end
		end
		local kids = {}
		for i, c in obj.__children do
			table.insert(kids, { c, i })
		end
		table.sort(kids, function(a, b)
			local za = if a[1]:IsA("GuiObject") then a[1].ZIndex else 0
			local zb = if b[1]:IsA("GuiObject") then b[1].ZIndex else 0
			if za ~= zb then
				return za < zb
			end
			return a[2] < b[2]
		end)
		for _, k in kids do
			rec(k[1], inner, alpha)
		end
	end
	rec(gui, nil, 1)
	return out
end

--- Writes a dump as JSON for tools/arte/telas.py.
function H.save(gui: any, path: string, extra: any?)
	local serde = require("@lune/serde")
	local fs = require("@lune/fs")
	local data = { view = { H.view.X, H.view.Y }, items = H.dump(gui), extra = extra or {} }
	-- the skins' patterns, for the drawer (a skin is a drawing in the code, not an image)
	local Cosmetics = require("../src/shared/Data/Cosmetics")
	local skins = {}
	for _, list in { Cosmetics.all(), Cosmetics.exclusives(), Cosmetics.generals(), Cosmetics.seasonals() } do
		for _, it in list do
			if it.kind == "skin" then
				skins[it.id] = { mask = it.mask, scale = it.scale, tone = it.tone, accent = it.accent, colors = it.colors }
			end
		end
	end
	data.extra.skins = skins
	fs.writeFile(path, serde.encode("json", data))
end

--- A stand-in for `game`, for the screens that ask Roblox for a service as they load (the title
--- screen: the map list, the party). Not an Instance, so the code that asks `typeof(game)` still knows
--- it is outside Roblox; a service is an empty thing: its methods give nil, its events never fire.
function H.fake_game()
	local nothing: any
	local function service(name: string): any
		local sv = { Name = name }
		return setmetatable(sv, {
			__index = function(_t, key: string): any
				if key == "LocalPlayer" then
					return nil
				end
				-- an event (connected to with :Connect) or a method (called): both are this
				local member = {}
				function member.Connect(_m, _fn)
					return { Disconnect = function() end, Connected = false }
				end
				member.Once = member.Connect
				return setmetatable(member, {
					__call = function()
						return nil
					end,
					-- (read as a value with numbers in it, e.g. GuiService.TopbarInset: all zero)
					__index = function()
						return 0
					end,
				})
			end,
		})
	end
	local services: { [string]: any } = {}
	nothing = {
		GetService = function(_g, name: string): any
			services[name] = services[name] or service(name)
			return services[name]
		end,
		PlaceId = 0,
		JobId = "",
	};
	G.game = nothing
	return nothing
end

--- The properties set that Roblox does not have (a typo, or a wrong type), as lines.
function H.problems(): { string }
	local out = {}
	for k, why in H.bad do
		table.insert(out, k .. ": " .. why)
	end
	table.sort(out)
	return out
end

return H
