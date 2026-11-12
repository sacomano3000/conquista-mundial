--!nocheck
-- No image of RoWorld's is shown any more (2026-11-12). The 31 that were still used as they were:
--   * the interface's shapes (Assets/UIKit: 15 shadows, the spinner; Assets/UiShapes: the radial
--     menu's 5 pages, the title's and the game-over's gradients, the round glow, the arrow's head):
--     drawn again by tools/arte/formas.py and put in place by UI/ArtSweep through the old ids;
--   * the crate's 3D chest (two meshes and a texture): now blocks (Assets/CrateModel);
--   * the skins' preview atlas: nothing used it, it is gone.
-- Checked here: every image id in src/ has a drawing of this game's, each shape decodes to the size
-- the screens cut it by, the chest is made of plain blocks, and the insignias exist.
--   lune run tests/imagens_proprias.luau
local fs = require("@lune/fs")
local OwnArt = require("../src/shared/Assets/OwnArt")
local UIKit = require("../src/shared/Assets/UIKit")
local UiShapes = require("../src/shared/Assets/UiShapes")
local CrateModel = require("../src/shared/Assets/CrateModel")
local Brand = require("../src/shared/Data/Brand")
local RankPrizes = require("../src/shared/Data/RankPrizes")
local ArtSweep = require("../src/client/UI/ArtSweep")

local checks, fails = 0, 0
local function ok(cond: any, what: string)
	checks += 1
	if not cond then
		fails += 1
		print("FAIL " .. what)
	end
end

--- (ink, alpha at the centre, alpha at a corner) of a drawing
local function look(key: string): (number, number, number, number, number)
	local w, h = OwnArt.size(key)
	local px = OwnArt.pixels(key)
	if px == nil then
		return 0, 0, 0, w, h
	end
	local ink = 0
	for i = 0, w * h - 1 do
		if buffer.readu8(px, i * 4 + 3) > 0 then
			ink += 1
		end
	end
	local centre = buffer.readu8(px, ((h // 2) * w + w // 2) * 4 + 3)
	local corner = buffer.readu8(px, 3)
	return ink, centre, corner, w, h
end

-- =============================================================================================
print("every image id in src/ has a drawing of this game's (sounds apart)")
do
	local AUDIO = { ["Audio.luau"] = true, ["AudioExtra.luau"] = true, ["AudioUI.luau"] = true, ["Soundtrack.luau"] = true }
	local SKIP = { ["OwnArtData.luau"] = true, ["OwnArtIds.luau"] = true }
	local images, sounds, left = 0, 0, {}
	local function walk(dir: string)
		for _, name in fs.readDir(dir) do
			local path = dir .. "/" .. name
			if fs.isDir(path) then
				if name ~= "Dev" then
					walk(path)
				end
			elseif string.sub(name, -5) == ".luau" and not SKIP[name] then
				local src = fs.readFile(path)
				for line in string.gmatch(src, "[^\n]+") do
					local code = string.match(line, "^(.-)%-%-") or line
					for id in string.gmatch(code, "rbxassetid://%d+") do
						if AUDIO[name] then
							sounds += 1
						elseif OwnArt.key_for(id) ~= nil then
							images += 1
						else
							table.insert(left, path .. ": " .. id)
						end
					end
				end
			end
		end
	end
	walk("src")
	ok(images >= 140, "the images are found (" .. images .. ")")
	ok(sounds >= 50, "and the sounds, which are not images (" .. sounds .. ")")
	ok(#left == 0, "no image of RoWorld's is left without a drawing: " .. table.concat(left, "; "))
	ok(not fs.isFile("src/shared/Assets/SkinPreviews.luau"), "the unused skins' atlas is gone")
end

-- =============================================================================================
print("the interface's shapes")
do
	ok(Brand.OWN_SHAPES == true and Brand.OWN_ICONS == true, "the game's own shapes and icons are on")
	ok(#UIKit.shadows == 15, "fifteen shadows")
	for i, s in UIKit.shadows do
		local key = OwnArt.key_for(s.id)
		ok(key ~= nil and ArtSweep.is_shape(key), "shadow " .. i .. " has its own drawing")
		if key ~= nil then
			local ink, centre, corner, w, h = look(key)
			ok(w == s.size and h == s.size, string.format("shadow %d is %d px, as the 9-slice cuts it (got %d x %d)", i, s.size, w, h))
			ok(s.slice * 2 < s.size, "shadow " .. i .. ": the corners leave a middle")
			ok(ink > 0 and corner == 0, "shadow " .. i .. " fades to nothing at the corner")
		end
	end
	for _, k in { "spinner_arc", "spinner_ring" } do
		local key = OwnArt.key_for(UIKit[k])
		ok(key == "shape/" .. k, k .. " has its own drawing")
		local ink, centre, _, w, h = look(key or "")
		ok(w == h and w > 0 and ink > 0 and centre == 0, k .. ": a ring, empty in the middle")
	end
	do
		local a = look("shape/spinner_arc")
		local r = look("shape/spinner_ring")
		ok(a < r * 0.45 and a > r * 0.2, "the arc is a piece of the ring (1.9 of 6.28 rad)")
	end
	-- the radial menu: every slice is inside its page, and has ink
	local pages = {}
	for n, id in UiShapes.pages do
		local key = OwnArt.key_for(id)
		ok(key == "shape/radial_" .. n, "the radial menu's page " .. n .. " has its own drawing")
		local w, h = OwnArt.size(key or "")
		pages[n] = { w = w, h = h, px = OwnArt.pixels(key or "") }
		ok(w > 0 and w <= 1024 and h > 0 and h <= 1024, string.format("page %d fits an image (%d x %d)", n, w, h))
	end
	local slices, bad, empty = 0, {}, {}
	for name, s in UiShapes.segments do
		slices += 1
		local pg = pages[s.page]
		if pg == nil or pg.px == nil or s.x + s.w > pg.w or s.y + s.h > pg.h then
			table.insert(bad, name)
		else
			local ink = 0
			for y = s.y, s.y + s.h - 1, 3 do
				for x = s.x, s.x + s.w - 1, 3 do
					if buffer.readu8(pg.px, (y * pg.w + x) * 4 + 3) > 0 then
						ink += 1
					end
				end
			end
			if ink == 0 then
				table.insert(empty, name)
			end
		end
	end
	ok(slices >= 28, "the radial menu's slices are listed (" .. slices .. ")")
	ok(#bad == 0, "every slice is inside its page: " .. table.concat(bad, ", "))
	ok(#empty == 0, "every slice is drawn: " .. table.concat(empty, ", "))
	for k, size in { title_vignette = { 256, 256 }, title_glow = { 256, 128 }, over_dim = { 256, 256 }, disc_glow = { 128, 128 }, arrow_head = { 64, 64 } } do
		local key = OwnArt.key_for(UiShapes[k])
		ok(key == "shape/" .. k, k .. " has its own drawing")
		local ink, _, _, w, h = look(key or "")
		ok(w == size[1] and h == size[2], string.format("%s is %d x %d (got %d x %d)", k, size[1], size[2], w, h))
		ok(ink > 0, k .. " is drawn")
	end
	do
		-- the arrow's head points right (the arrow is rotated from there): more ink on the left half's
		-- outside... simply: its tip is on the right edge's middle, its back spreads wider
		local px = OwnArt.pixels("shape/arrow_head")
		local function column(x: number): number
			local n = 0
			for y = 0, 63 do
				if buffer.readu8(px, (y * 64 + x) * 4 + 3) > 127 then
					n += 1
				end
			end
			return n
		end
		local right, left = 0, 0
		for x = 48, 63 do
			right = math.max(right, column(x))
		end
		for x = 0, 40 do
			left = math.max(left, column(x))
		end
		ok(left > right and left >= 20, string.format("the arrow's head is wide at the back (%d) and narrow at the tip (%d)", left, right))
	end
	ok(ArtSweep.is_shape("shape/arrow_head") and ArtSweep.is_shape("shadow/r008"), "shapes and shadows are the keys OWN_SHAPES turns off")
	ok(not ArtSweep.is_shape("ui/attack") and not ArtSweep.is_shape("badge/1"), "and nothing else")
	ok(ArtSweep.is_own_only("badge/2") and not ArtSweep.is_own_only("shape/over_dim") and not ArtSweep.is_own_only("ui/attack"), "the insignias are drawn even with OWN_ICONS off")
end

-- =============================================================================================
print("the chest is this game's: plain blocks, no mesh, no texture")
do
	local src = fs.readFile("src/shared/Assets/CrateModel.luau")
	ok(string.find(src, "rbxassetid", 1, true) == nil, "the chest's file names no asset")
	ok(#CrateModel.parts >= 12, "it is made of blocks (" .. #CrateModel.parts .. ")")
	local lid, body, names = 0, 0, {}
	local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for i, p in CrateModel.parts do
		ok(p.mesh == nil and p.tex == nil, "block " .. i .. " has no mesh and no texture")
		ok(type(p.name) == "string" and not names[p.name], "block " .. i .. " has a name of its own")
		names[p.name] = true
		ok(type(p.size) == "table" and #p.size == 3 and p.size[1] > 0 and p.size[2] > 0 and p.size[3] > 0, "block " .. i .. " has a size")
		ok(type(p.cf) == "table" and #p.cf >= 3, "block " .. i .. " has a place")
		ok(type(p.color) == "table" and #p.color == 3, "block " .. i .. " has a colour")
		ok(type(p.material) == "string", "block " .. i .. " has a material")
		if p.lid then
			lid += 1
		else
			body += 1
			for a = 1, 3 do
				lo[a] = math.min(lo[a], p.cf[a] - p.size[a] / 2)
				hi[a] = math.max(hi[a], p.cf[a] + p.size[a] / 2)
			end
		end
	end
	ok(lid >= 5 and body >= 3, string.format("a body (%d blocks) and a lid that opens (%d blocks)", body, lid))
	ok(names.Lock and names.Body and names.Lid, "with a body, a lid and a lock")
	-- the opening show's measures still hold: the body stays under the seam, inside the old box
	-- (the lid is a cap: it comes down over the body's top, to the seam)
	ok(hi[2] >= CrateModel.seam[2] and hi[2] < CrateModel.size[2] - 1, "the body's top is under the lid's cap, above the seam")
	ok(hi[1] - lo[1] <= CrateModel.size[1] + 0.3 and hi[3] - lo[3] <= CrateModel.size[3] + 0.3, "the body is as wide as the chest the show was made for")
	ok(CrateModel.hinge[3] > 0 and CrateModel.seam[3] < 0, "the hinge is at the back, the seam at the front")
	ok(type(CrateModel.lid_open) == "number" and CrateModel.lid_open > 90 and CrateModel.lid_open < 170, "the lid opens past upright, not all the way round")
	ok(type(CrateModel.mouth) == "table" and CrateModel.mouth[2] > CrateModel.seam[2], "the prize leaves through the mouth, above the seam")
	ok(names.LidInside and names.Inside, "the open chest is dark inside, the lid's underside too")
	local view = fs.readFile("src/client/UI/ChestView.luau")
	ok(string.find(view, "Color3.fromRGB(p.color[1], p.color[2], p.color[3])", 1, true) ~= nil, "ChestView paints each block its colour")
	for _, f in { "src/client/UI/ChestView.luau", "src/client/UI/CrateOpening.luau", "src/client/UI/CrateButton.luau", "src/client/UI/Locker.luau" } do
		local s = fs.readFile(f)
		ok(string.find(s, "MeshId = \"", 1, true) == nil and string.find(s, "TextureID = \"", 1, true) == nil, f .. " names no mesh and no texture of its own")
	end
end

-- =============================================================================================
print("the weekly ranking's insignias")
do
	for n = 1, RankPrizes.BADGE_PLACES do
		local key = OwnArt.key_for(RankPrizes.badge_image(n))
		ok(key == "badge/" .. n, "insignia " .. n .. " is a drawing of this game's")
		local ink, centre, corner, w, h = look(key or "")
		ok(w == h and w >= 64 and ink > w * h * 0.3 and corner == 0, "insignia " .. n .. " is drawn, with a clear corner")
	end
	local a, b = OwnArt.pixels("badge/1"), OwnArt.pixels("badge/2")
	local differ = false
	for i = 0, buffer.len(a) // 4 - 1 do
		if buffer.readu32(a, i * 4) ~= buffer.readu32(b, i * 4) then
			differ = true
			break
		end
	end
	ok(differ, "gold and silver are not the same picture")
end

print(string.format("imagens_proprias: %d checks, %d failed", checks, fails))
if fails > 0 then
	error("imagens_proprias failed")
end
