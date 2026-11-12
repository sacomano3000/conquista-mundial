--!nocheck
-- Map/StrikeArt: the Ataque de Dragões over the map is this game's dragon seen from above, turned the
-- way it flies (2026-11-10). The picture's head points left; here: the turn for every direction, its
-- size beside a unit's sprite, and when the missile's sprite is drawn in its place. Also that the
-- picture the Arsenal's card shows and the one that flies are two different drawings.
--   lune run tests/strike_art.luau
local StrikeArt = require("../src/client/Map/StrikeArt")
local ArsenalArt = require("../src/shared/Assets/ArsenalArt")
local OwnArt = require("../src/shared/Assets/OwnArt")
local fs = require("@lune/fs")

local fails, total = 0, 0
local function expect(cond: any, what: string)
	total += 1
	if not cond then
		fails += 1
		print("FAIL " .. what)
	end
end

--- Where the picture's head (pointing left, (-1, 0)) ends up after a GUI Rotation of `deg` degrees:
--- Roblox turns clockwise on a screen whose y grows downwards.
local function head_after(deg: number): (number, number)
	local a = math.rad(deg)
	local x, y = -1, 0
	return x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a)
end

for i = 0, 23 do
	local a = i * math.pi / 12
	local dx, dy = math.cos(a) * 37, math.sin(a) * 37
	local hx, hy = head_after(StrikeArt.heading(dx, dy))
	expect(
		math.abs(hx - dx / 37) < 1e-6 and math.abs(hy - dy / 37) < 1e-6,
		string.format("flying along (%.1f, %.1f) the head points that way (got %.2f, %.2f)", dx, dy, hx, hy)
	)
end
expect(StrikeArt.heading(-5, 0) == 0, "flying left: the picture as it is drawn")
expect(math.abs(math.abs(StrikeArt.heading(5, 0)) - 180) < 1e-6, "flying right: turned around")
expect(math.abs(StrikeArt.heading(0, 5) + 90) < 1e-6, "flying down the screen: a quarter turn to the left")
expect(math.abs(StrikeArt.heading(0, -5) - 90) < 1e-6, "flying up the screen: a quarter turn to the right")
expect(StrikeArt.heading(0, 0) == 0 and StrikeArt.heading(0 / 0, 1) == 0, "no direction: not turned")

-- its size: the wingspan (the picture's height) is SPAN unit sprites, the proportions kept
local A = ArsenalArt.attack and ArsenalArt.attack.airfield
expect(type(A) == "table" and type(A.id) == "string", "the air strike has a picture of its own")
if type(A) == "table" then
	for _, px in { 5, 13, 26, 52, 104 } do
		local w, h = StrikeArt.size(px, A.w, A.h)
		expect(h == math.max(StrikeArt.MIN_PX, math.floor(px * StrikeArt.SPAN + 0.5)), "wingspan for a sprite of " .. px)
		expect(math.abs(w / h - A.w / A.h) < 0.06, string.format("proportions kept at %d px (%d x %d)", px, w, h))
		expect(h > px, "bigger than the missile's sprite it replaces, at " .. px)
	end
	local w0, h0 = StrikeArt.size(1, A.w, A.h)
	expect(h0 == StrikeArt.MIN_PX and w0 >= 1, "never too small to see")
	local w1, h1 = StrikeArt.size(13, 0, 0)
	expect(w1 == h1 and w1 > 0, "a picture with no size: a square, not a division by zero")

	-- the drawing is this game's, under a name that is no Roblox image
	expect(string.sub(A.id, 1, 15) == "rbxasset://own/", "its id is only a name")
	expect(OwnArt.key_for(A.id) == "attack/airfield", "Assets/OwnArt knows it")
	local w, h = OwnArt.size("attack/airfield")
	expect(w == A.w and h == A.h, string.format("ArsenalArt has its size (%d x %d, the drawing is %d x %d)", A.w, A.h, w, h))
	expect(h > w, "seen from above with the wings up and down: taller than wide")
	local px = OwnArt.pixels("attack/airfield")
	expect(px ~= nil and buffer.len(px) == w * h * 4, "its pixels are in the code")
	if px ~= nil and buffer.len(px) == w * h * 4 then
		local opaque, corner = 0, 0
		for i = 0, w * h - 1 do
			if buffer.readu8(px, i * 4 + 3) > 128 then
				opaque += 1
			end
		end
		for _, i in { 0, w - 1, (h - 1) * w, h * w - 1 } do
			corner += buffer.readu8(px, i * 4 + 3)
		end
		expect(opaque > w * h * 0.15 and opaque < w * h * 0.8, "a drawing on a transparent ground")
		expect(corner == 0, "its corners are transparent")
		-- (a red dragon: among the opaque pixels, red leads)
		local r, g, b = 0, 0, 0
		for i = 0, w * h - 1 do
			if buffer.readu8(px, i * 4 + 3) > 128 then
				r += buffer.readu8(px, i * 4)
				g += buffer.readu8(px, i * 4 + 1)
				b += buffer.readu8(px, i * 4 + 2)
			end
		end
		expect(r > g * 1.5 and r > b * 2, "the dragon is red")
	end

	-- the Arsenal's card keeps another drawing (the emblem), and both are in the game
	local card = ArsenalArt.renders.airfield
	expect(card.id ~= A.id and OwnArt.key_for(card.id) == "render/airfield", "the card's picture is another one")
	local cp = OwnArt.pixels("render/airfield")
	local cw, ch = OwnArt.size("render/airfield")
	expect(cw == 256 and ch == 256 and cp ~= nil, "the card's picture is 256 x 256")
	expect(not (cw == w and ch == h), "the two are not the same size")
end

-- when the missile's sprite is drawn in its place
expect(StrikeArt.swapped("rbxasset://own/attack_airfield", "rbxasset://own/attack_airfield") == false, "still the name: nothing to see yet")
expect(StrikeArt.swapped("", "rbxasset://own/attack_airfield") == true, "the drawing is in the label (its Image is empty)")
expect(StrikeArt.swapped("rbxassetid://123", "rbxasset://own/attack_airfield") == true, "the owner's uploaded image")
expect(StrikeArt.swapped(nil, "rbxasset://own/attack_airfield") == false, "no label")

-- Map/UnitLayer draws it (it can't be loaded outside Roblox: its source is read)
do
	local src = fs.readFile("src/client/Map/UnitLayer.luau")
	expect(string.find(src, "ArsenalArt.attack.airfield", 1, true) ~= nil, "UnitLayer takes the air strike's picture")
	expect(string.find(src, "n.kind == Defs.N_AIRSTRIKE and DRAGON ~= nil", 1, true) ~= nil, "... for the air strike only")
	expect(string.find(src, "StrikeArt.heading(dx, dy)", 1, true) ~= nil, "... turned the way it flies")
	expect(string.find(src, "if not as_dragon then", 1, true) ~= nil, "... and keeps the missile's sprite where it can't be shown")
	local demo = fs.readFile("src/client/UI/ArsenalDemo.luau")
	expect(string.find(demo, "AA.attack.airfield", 1, true) ~= nil, "the Arsenal's preview flies the same picture")
end

print(string.format("strike_art: %d checks, %d failed", total, fails))
if fails > 0 then
	error("strike_art failed")
end
