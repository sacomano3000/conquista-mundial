--!nonstrict
-- The weekly ranking's insignia beside a name (Data/RankPrizes; 2026-11-12): the gold, silver or bronze
-- shield of last week's first three, as every screen that shows a name draws it (the RANK window's
-- rows, the match's list, the target's card, the lobby's party, the end of a match).
--
-- The picture alone says the place by its colour. Resting the pointer on it (a tap, on a phone) shows
-- a card with the words: "#1 in Victories last week".
--   local ins = Insignia.new(ctx, 16)      ins.node goes into the row
--   ins:set(place, wins, kills)            place 1..3 (nil / 0: hidden); wins, kills: the place in each
--                                          of last week's lists that earned it (either may be nil)

local W = require("./Widgets")
local RankPrizes: any = if typeof(game) == "Instance"
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data.RankPrizes)
	else (require :: any)("../../shared/Data/RankPrizes")

local Insignia = {}
Insignia.__index = Insignia

--- How long a tap's card stays, seconds.
Insignia.TAP_S = 3.0

local COLORS = { Color3.fromRGB(236, 190, 92), Color3.fromRGB(202, 208, 218), Color3.fromRGB(208, 142, 92) }

--- The colour of insignia `place` (gold, silver, bronze), or nil.
function Insignia.color(place: any): Color3?
	local b = RankPrizes.badge(place)
	return if b ~= nil then COLORS[b] else nil
end

--- What the insignia stands for, in words (as the code writes it: the card that shows it puts it in
--- the interface's language).
function Insignia.text(wins: any, kills: any): string
	local w, k = RankPrizes.badge(wins), RankPrizes.badge(kills)
	if w ~= nil and k ~= nil then
		return string.format("#%d in Victories and #%d in Kingdoms destroyed last week", w, k)
	elseif w ~= nil then
		return string.format("#%d in Victories last week", w)
	elseif k ~= nil then
		return string.format("#%d in Kingdoms destroyed last week", k)
	end
	return "Top 3 of last week's Weekly Rank"
end

--- The card of insignia `place` (UI/Tooltip's spec).
function Insignia.spec(place: any, wins: any, kills: any): any
	return {
		title = "Weekly Rank insignia",
		title_color = Insignia.color(place),
		body = Insignia.text(wins, kills),
		footer = "Worn until Sunday",
	}
end

--- The place of user `uid` among the first three of last week's lists, from the lists themselves
--- (Session.rank.boards: "wins_l", "kills_l"): (best place?, wins place?, kills place?).
function Insignia.of_lists(boards: any, uid: number): (number?, number?, number?)
	local function place(rows: any): number?
		if type(rows) ~= "table" then
			return nil
		end
		for i = 1, math.min(#rows, RankPrizes.BADGE_PLACES) do
			if type(rows[i]) == "table" and rows[i][1] == uid then
				return i
			end
		end
		return nil
	end
	if type(boards) ~= "table" or uid == 0 then
		return nil, nil, nil
	end
	local w, k = place(boards.wins_l), place(boards.kills_l)
	return RankPrizes.best(w, k), w, k
end

--- The insignia a player of this server wears, as the server wrote it on them (ServerMain: the
--- attributes RankBadge, RankBadgeWins, RankBadgeKills): (place?, wins?, kills?).
function Insignia.of_player(player: any): (number?, number?, number?)
	local ok, place, wins, kills = pcall(function()
		return player:GetAttribute("RankBadge"), player:GetAttribute("RankBadgeWins"), player:GetAttribute("RankBadgeKills")
	end)
	if not ok or RankPrizes.badge(place) == nil then
		return nil, nil, nil
	end
	return RankPrizes.badge(place), RankPrizes.badge(wins), RankPrizes.badge(kills)
end

function Insignia.new(ctx: any, px: number)
	local self = setmetatable({}, Insignia)
	self.ctx = ctx
	self.place = 0
	self.wins = nil :: number?
	self.kills = nil :: number?
	local img = Instance.new("ImageLabel")
	img.Name = "RankBadge"
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.ScaleType = Enum.ScaleType.Fit
	self.img = img
	local node = W.wrap(img)
	-- (the picture fades with its window: 1.0 = fully there)
	node:_part(img, "ImageTransparency", 1.0)
	node:set_min_size(Vector2.new(px, px))
	node.size_flags_vertical = W.SHRINK_CENTER
	-- (never in the way of the row or the button under it: it listens, and lets the press through)
	node:set_mouse_filter(W.MOUSE_PASS)
	node:set_visible(false)
	self.node = node
	self._serial = 0
	node.mouse_entered:Connect(function()
		self:_show(false)
	end)
	node.mouse_exited:Connect(function()
		if self.ctx ~= nil then
			self.ctx:hide_hint(node)
		end
	end)
	node.gui_input:Connect(function(e: any)
		if e.kind == "button" and e.pressed and e.touch then
			self:_show(true)
		end
	end)
	return self
end

function Insignia._show(self, tap: boolean)
	local ctx = self.ctx
	if ctx == nil or type(ctx.show_hint) ~= "function" or RankPrizes.badge(self.place) == nil then
		return
	end
	ctx:show_hint(self.node, Insignia.spec(self.place, self.wins, self.kills), tap)
	if tap then
		self._serial += 1
		local serial = self._serial
		task.delay(Insignia.TAP_S, function()
			if self._serial == serial then
				ctx:hide_hint(self.node)
			end
		end)
	end
end

--- Shows insignia `place` (1..3), won with places `wins` / `kills` of last week's lists; anything
--- else hides it. True when it is shown.
function Insignia.set(self, place: any, wins: any, kills: any): boolean
	local b = RankPrizes.badge(place) or 0
	self.wins, self.kills = RankPrizes.badge(wins), RankPrizes.badge(kills)
	if b ~= self.place then
		self.place = b
		self.img.Image = RankPrizes.badge_image(b)
		self.node:set_visible(b ~= 0)
		if b == 0 and self.ctx ~= nil and type(self.ctx.hide_hint) == "function" then
			self.ctx:hide_hint(self.node)
		end
	end
	return b ~= 0
end

return Insignia
