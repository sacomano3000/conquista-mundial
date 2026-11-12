--!nocheck
-- Assets/OwnArt: every image of RoWorld's the interface and the map show has a drawing of this game's
-- in its place, and each drawing decodes to its size.   lune run tests/own_art.luau
local OwnArt = require("../src/shared/Assets/OwnArt")
local UiIcons = require("../src/shared/Assets/UiIcons")
local ArsenalArt = require("../src/shared/Assets/ArsenalArt")
local MapSprites = require("../src/shared/Assets/MapSprites")
local CrateArt = require("../src/shared/Assets/CrateArt")
local Branding = require("../src/shared/Assets/Branding")
local MapThumbs = require("../src/shared/Assets/MapThumbs")
local ArsenalFx = require("../src/shared/Assets/ArsenalFx")
local MapFx = require("../src/shared/Assets/MapFx")
local RailArt = require("../src/shared/Assets/RailArt")
local Ids = require("../src/shared/Assets/OwnArtIds")
local Brand = require("../src/shared/Data/Brand")

local fails = 0
local function ok(cond: boolean, what: string)
	if not cond then
		fails += 1
		print("FAIL " .. what)
	end
end

-- 1. nothing of RoWorld's is left without a drawing
local covered = 0
local function has(id: any, what: string)
	covered += 1
	ok(type(id) == "string" and OwnArt.key_for(id) ~= nil, what .. " has its own drawing")
end
for k, id in UiIcons do
	has(id, "UiIcons." .. k)
end
for k, id in ArsenalArt.ui do
	has(id, "ArsenalArt.ui." .. k)
end
for k, id in MapSprites.ui do
	has(id, "MapSprites.ui." .. k)
end
for _, k in { "icons", "shapes", "shapes_one", "units", "units_one", "status" } do
	has(MapSprites[k].id, "MapSprites." .. k)
end
has(CrateArt.icon, "CrateArt.icon")
has(Branding.app_icon, "Branding.app_icon")
has(Branding.logo_mark, "Branding.logo_mark")
has(MapThumbs.world, "MapThumbs.world")
-- (2026-11: the effects, the road, the chest's lights, the Arsenal's pictures and its previews' ground)
for k, id in CrateArt do
	has(id, "CrateArt." .. k)
end
for k, e in ArsenalFx do
	has(e.id, "ArsenalFx." .. k)
end
has(MapFx.id, "MapFx")
for k, id in RailArt do
	has(id, "RailArt." .. k)
end
for k, r in ArsenalArt.renders do
	has(r.id, "ArsenalArt.renders." .. k)
	ok(OwnArt.key_for(r.id) == "render/" .. k, "the picture of " .. k .. " is this game's")
end
ok(OwnArt.key_for("rbxassetid://1") == nil, "an image that is not RoWorld's is left alone")

-- 2. the sheets keep RoWorld's grids (the map cuts them by cell)
local function size_is(id: string, w: number, h: number, what: string)
	local key = OwnArt.key_for(id)
	local gw, gh = OwnArt.size(key or "")
	ok(gw == w and gh == h, string.format("%s is %d x %d (got %d x %d)", what, w, h, gw, gh))
end
local S = MapSprites
size_is(S.icons.id, S.icons.cell * S.icons.cols, S.icons.cell, "the structures' glyphs")
size_is(S.shapes.id, S.shapes.cell * S.shapes.cols, S.shapes.cell * 2, "the structures' plates")
size_is(S.shapes_one.id, S.shapes_one.cell * S.shapes_one.cols, S.shapes_one.cell, "the one-image plates")
size_is(S.units.id, S.units.cell * S.units.cols, S.units.cell * 2, "the units")
size_is(S.units_one.id, S.units_one.cell * S.units_one.cols, S.units_one.cell, "the one-image units")
size_is(S.status.id, S.status.cell * S.status.cols, S.status.cell * 4, "the status icons")
size_is(UiIcons.attack, 128, 128, "an interface icon")
-- the effects keep the sizes and grids the screens cut them by
for k, e in ArsenalFx do
	if e.cell ~= nil then
		size_is(e.id, e.cell * e.cols, e.cell * math.ceil(e.frames / e.cols), "the Arsenal's flipbook " .. k)
	else
		size_is(e.id, e.w, e.h, "the Arsenal's effect " .. k)
	end
end
do
	local mw, mh = 0, 0
	for k, row in MapFx do
		if type(row) == "table" then
			mw = math.max(mw, row.x + row.w * row.frames)
			mh = math.max(mh, row.y + row.h)
		end
	end
	size_is(MapFx.id, mw, mh, "the map's effects")
	-- every frame of every row has something drawn (the first frame of the flag's cloth is empty)
	local key = OwnArt.key_for(MapFx.id)
	local px = OwnArt.pixels(key or "")
	local w = OwnArt.size(key or "")
	for k, row in MapFx do
		if type(row) == "table" and px ~= nil then
			for f = 0, row.frames - 1 do
				local ink = 0
				for y = row.y, row.y + row.h - 1 do
					for x = row.x + f * row.w, row.x + (f + 1) * row.w - 1 do
						if buffer.readu8(px, (y * w + x) * 4 + 3) > 0 then
							ink += 1
						end
					end
				end
				ok(ink > 0 or (k == "banner" and f == 0), string.format("MapFx.%s frame %d is drawn", k, f))
			end
		end
	end
end
for k, id in RailArt do
	size_is(id, 24, 24, "the road tile " .. k)
end
for k, r in ArsenalArt.renders do
	size_is(r.id, r.w, r.h, "the Arsenal's picture " .. k)
end
do
	-- (Assets/ArsenalMaps uses Vector2: read as text here)
	local src = require("@lune/fs").readFile("src/shared/Assets/ArsenalMaps.luau")
	local id = string.match(src, 'id = "(rbxassetid://%d+)"')
	local sw, sh = string.match(src, "size = Vector2%.new%((%d+), (%d+)%)")
	has(id, "ArsenalMaps")
	size_is(id, tonumber(sw), tonumber(sh), "the Arsenal previews' ground")
end
size_is(Branding.logo_mark, 512, 512, "the logo")

-- 3. every drawing decodes; the interface's are white masks with something drawn
local keys = OwnArt.keys()
for _, key in keys do
	local w, h = OwnArt.size(key)
	local px = OwnArt.pixels(key)
	ok(px ~= nil and buffer.len(px) == w * h * 4, key .. " decodes to its size")
	ok(w <= 1024 and h <= 1024, key .. " fits an EditableImage")
	if px ~= nil then
		local ink, white = 0, true
		for i = 0, w * h - 1 do
			local a = buffer.readu8(px, i * 4 + 3)
			if a > 0 then
				ink += 1
				if buffer.readu32(px, i * 4) % 0x1000000 ~= 0xFFFFFF then
					white = false
				end
			end
		end
		ok(ink > 0, key .. " has something drawn")
		local kind = string.match(key, "^(%w+)/")
		if kind == "icons" or kind == "arsenal" or kind == "map" or kind == "crate" then
			ok(white, key .. " is a white mask")
			ok(ink > w * h * 0.03 and ink < w * h * 0.9, key .. " is a glyph, not a blot")
		end
	end
end
ok(OwnArt.pixels("nothing") == nil, "an unknown key has no drawing")
for _, target in OwnArt.replaces() do
	ok(OwnArt.size(target) > 0, "replacement " .. target .. " exists")
end

-- 4. the owner's uploads: optional, none by default
for key, id in Ids do
	ok(OwnArt.size(key) > 0, "OwnArtIds." .. key .. " names a drawing")
	ok(id == "" or OwnArt.uploaded(key) ~= nil, "OwnArtIds." .. key .. " is an id or empty")
end
ok(OwnArt.uploaded("icons/attack") == nil or Ids["icons/attack"] ~= "", "no upload unless the owner gave one")
ok(Brand.OWN_ICONS == true, "the game's own icons are on")

print(string.format("own_art: %d drawings for %d images, %d failed", #keys, covered, fails))
if fails > 0 then
	error("own_art tests failed")
end
