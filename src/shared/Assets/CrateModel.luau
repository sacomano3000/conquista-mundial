-- The cosmetic crate's 3D chest (UI/ChestView, CrateOpening): this game's own treasure chest, built
-- from plain blocks at run time inside a ViewportFrame. Wood, iron bands, a gold lock: no mesh, no
-- texture, nothing uploaded by anyone (2026-11-12; before it this was BedWars' block chest, two meshes
-- and a texture on another account).
--   pivot at the bottom centre, front = -Z, lid closed; `hinge` = the lid's hinge point (the lid opens
--   with a positive rotation about X there); sizes in studs. The lid is the top of the chest: it flips
--   far back so it stays low.
--   parts: { name, lid (moves with the lid), size, cf (x, y, z of its centre, then the rotation),
--   color = { r, g, b }, material }. A part with `mesh` / `tex` / `scale` is drawn as that mesh instead
--   (ChestView still knows how).
-- The outer measures, the hinge, the mouth and the seam are the ones the opening show was made for.
-- tools/arte/bau.py draws it (assets/previa-bau.png) from this file.
local WOOD = { 134, 88, 50 }
local WOOD_LID = { 150, 100, 58 }
local WOOD_DARK = { 86, 54, 32 }
local IRON = { 74, 74, 84 }
local GOLD = { 236, 190, 92 }
local INSIDE = { 34, 24, 20 }
local I = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }

local function block(name: string, lid: boolean, size: { number }, at: { number }, color: { number }, material: string): any
	return {
		name = name,
		lid = lid,
		size = size,
		cf = { at[1], at[2], at[3], table.unpack(I) },
		color = color,
		material = material,
	}
end

return {
	size = { 5, 4.6666, 5 },
	hinge = { 0, 1.6667, 2.5 },
	-- the open chest's mouth (the card comes out here) and the lid's front seam (light leaks there)
	mouth = { 0, 2.1, 0 },
	seam = { 0, 1.6667, -2.5 },
	lid_open = 140,
	parts = {
		-- the box
		block("Body", false, { 4.6666, 2.3333, 4.6666 }, { 0, 1.1667, 0 }, WOOD, "WoodPlanks"),
		block("Foot", false, { 4.9, 0.5, 4.9 }, { 0, 0.25, 0 }, WOOD_DARK, "Wood"),
		block("BandLeft", false, { 0.6, 2.36, 4.8 }, { -1.45, 1.18, 0 }, IRON, "Metal"),
		block("BandRight", false, { 0.6, 2.36, 4.8 }, { 1.45, 1.18, 0 }, IRON, "Metal"),
		block("Inside", false, { 4.1, 0.1, 4.1 }, { 0, 2.34, 0 }, INSIDE, "SmoothPlastic"),
		-- the lid: a cap over the box, stepped at the top so it reads as a rounded lid
		block("Lid", true, { 5, 2, 5 }, { 0, 2.6667, 0 }, WOOD_LID, "WoodPlanks"),
		block("LidInside", true, { 4.4, 0.06, 4.4 }, { 0, 1.65, 0 }, INSIDE, "SmoothPlastic"),
		block("LidRim", true, { 5.12, 0.36, 5.12 }, { 0, 1.8467, 0 }, WOOD_DARK, "Wood"),
		block("LidStep", true, { 5, 0.6, 4.3 }, { 0, 3.9667, 0 }, WOOD_LID, "WoodPlanks"),
		block("LidTop", true, { 5, 0.4, 3.3 }, { 0, 4.4667, 0 }, WOOD_LID, "WoodPlanks"),
		block("LidBandLeft", true, { 0.6, 2.04, 5.2 }, { -1.45, 2.6867, 0 }, IRON, "Metal"),
		block("LidBandRight", true, { 0.6, 2.04, 5.2 }, { 1.45, 2.6867, 0 }, IRON, "Metal"),
		block("LidStepBandLeft", true, { 0.6, 0.64, 4.44 }, { -1.45, 3.9867, 0 }, IRON, "Metal"),
		block("LidStepBandRight", true, { 0.6, 0.64, 4.44 }, { 1.45, 3.9867, 0 }, IRON, "Metal"),
		block("LidTopBandLeft", true, { 0.6, 0.44, 3.44 }, { -1.45, 4.4767, 0 }, IRON, "Metal"),
		block("LidTopBandRight", true, { 0.6, 0.44, 3.44 }, { 1.45, 4.4767, 0 }, IRON, "Metal"),
		-- the lock, on the lid's front
		block("Lock", true, { 1.1, 1.2, 0.3 }, { 0, 2.3, -2.6 }, GOLD, "Metal"),
		block("Keyhole", true, { 0.3, 0.46, 0.34 }, { 0, 2.2, -2.6 }, INSIDE, "SmoothPlastic"),
	},
}
