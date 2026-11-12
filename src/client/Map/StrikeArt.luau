--!strict
-- The air strike's own picture over the map (2026-11-10): the Ataque de Dragões is drawn as a dragon
-- seen from above (Assets/ArsenalArt.attack.airfield, assets/ataque/airfield.png), turned the way it
-- flies, where RoWorld drew the missile's sprite. Map/UnitLayer draws it; this is the arithmetic.
--
-- The picture has its HEAD TO THE LEFT and its wings up and down: its height is the wingspan.
--
-- Pure Luau (no Roblox types): tests/strike_art.luau.
local StrikeArt = {}

--- The wingspan, in unit sprites (a unit's sprite is UnitLayer.UNIT_SIZE tiles wide).
StrikeArt.SPAN = 2.4
--- The wingspan is never under this many pixels (a map zoomed far out).
StrikeArt.MIN_PX = 14

--- The GUI Rotation (degrees, clockwise on screen) that makes a picture whose head points left fly
--- along (dx, dy) on screen (y grows downwards). No direction: not turned.
function StrikeArt.heading(dx: number, dy: number): number
	if (dx == 0 and dy == 0) or dx ~= dx or dy ~= dy then
		return 0
	end
	return math.deg(math.atan2(-dy, -dx))
end

--- The picture's size on screen (width, height) for a unit sprite of `px` pixels and a picture of
--- `w` x `h` pixels: the wingspan is SPAN sprites, the proportions kept.
function StrikeArt.size(px: number, w: number, h: number): (number, number)
	local span = math.max(StrikeArt.MIN_PX, math.floor(px * StrikeArt.SPAN + 0.5))
	if w <= 0 or h <= 0 then
		return span, span
	end
	return math.max(1, math.floor(span * w / h + 0.5)), span
end

--- Whether a label given the picture's name (`id`, "rbxasset://own/...", which is no Roblox image)
--- now shows this game's drawing: client/UI/ArtSweep puts the drawing in the label, and its Image is
--- then something else (the owner's uploaded id, or empty). While it is still the name there is
--- nothing to see, and the missile's sprite is drawn as before.
function StrikeArt.swapped(image: any, id: string): boolean
	return type(image) == "string" and image ~= id
end

return StrikeArt
