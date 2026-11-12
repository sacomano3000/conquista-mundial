--!nocheck
-- The map zoomed out (2026-11-11, two things its owner saw in Studio):
--   * grey bands around the map once it is smaller than the screen: what is past the map's edge is now
--     open sea (MapSurface.OUTSIDE), the colour Eldoria's own edge water has. Eldoria then had land
--     on three of its edges, cut straight against that sea; it was redrawn with sea all around
--     (tools/maps/make_fantasy_world.py), so no edge of it shows;
--   * the structures' pictures going away at a zoom: an icon keeps its picture at every zoom and stops
--     shrinking where RoWorld turned it into a dot (Map/StructureZoom).
--   lune run tests/zoom_mapa.luau
require("./prelude")
local fs = require("@lune/fs")
local MapCamera = require("../src/client/Map/MapCamera")
local MapSurface = require("../src/client/Map/MapSurface")
local StructureZoom = require("../src/client/Map/StructureZoom")
local WorldMap = require("../src/shared/Core/WorldMap")
local Data = require("../src/shared/Data/Maps/World")

local checks, failed = 0, 0
local function check(ok: any, what: string)
	checks += 1
	if not ok then
		failed += 1
		print("FAIL: " .. what)
	end
end
local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-9)
end
local function has(s: string, part: string): boolean
	return string.find(s, part, 1, true) ~= nil
end

-- ---------------------------------------------------------------------------------------------
-- 1. past the map's edge: sea
-- ---------------------------------------------------------------------------------------------
local function rgb_of(pixel: number): (number, number, number)
	return pixel % 256, (pixel // 256) % 256, (pixel // 65536) % 256
end
local function rgb_of_color(c: any): (number, number, number)
	return math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)
end
do
	local r, g, b = rgb_of_color(MapSurface.OUTSIDE)
	check(r == 61 and g == 123 and b == 171, string.format("around the map: open sea, #3d7bab (%d, %d, %d)", r, g, b))
	local gr, gg, gb = rgb_of_color(MapSurface.BACKGROUND)
	check(not (r == gr and g == gg and b == gb), "... not the grey of impassable terrain")
	-- the colour the map itself gives its open water, from 10 tiles off a coast on
	for _, mag in { 10, 15, 22, 31 } do
		local pr, pg, pb = rgb_of(MapSurface.terrain_pixel(32 + mag))
		check(pr == r and pg == g and pb == b, "the same as the map's water " .. mag .. " tiles from a coast")
	end
	local sr, sg, sb = rgb_of(MapSurface.terrain_pixel(32 + 2))
	check(not (sr == r and sg == g and sb == b), "(water near a coast is lighter)")
	-- the view draws with it
	local src = fs.readFile("src/client/Map/MapView.luau")
	check(has(src, "backdrop.BackgroundColor3 = MapSurface.OUTSIDE"), "the map view's backdrop is that sea")
	check(not has(src, "backdrop.BackgroundColor3 = Color3.fromRGB(0x3c, 0x3c, 0x3c)"), "... the grey is gone from it")

	-- Eldoria's own edges: how much of each runs on into that sea
	local map = WorldMap.get("world")
	local W, H = map.W, map.H
	check(W == Data.width and H == Data.height and W == 2000 and H == 1000, "Eldoria: 2000 x 1000")
	local bytes = map.tile_bytes
	check(typeof(bytes) == "buffer" and buffer.len(bytes) == W * H, "its terrain, a byte a tile")
	local function edge(name: string, n: number, tile_at: (number) -> number): (number, number)
		local same, land = 0, 0
		for i = 0, n - 1 do
			local tb = buffer.readu8(bytes, tile_at(i))
			local pr, pg, pb = rgb_of(MapSurface.terrain_pixel(tb))
			if pr == r and pg == g and pb == b then
				same += 1
			end
			if tb >= 128 then
				land += 1
			end
		end
		return same / n, land / n
	end
	local top, top_land = edge("top", W, function(i)
		return i
	end)
	local bottom, bottom_land = edge("bottom", W, function(i)
		return (H - 1) * W + i
	end)
	local left, left_land = edge("left", H, function(i)
		return i * W
	end)
	local right, right_land = edge("right", H, function(i)
		return i * W + W - 1
	end)
	print(string.format("  Eldoria's edges the colour of the sea around: top %.0f%%, left %.0f%%, right %.0f%%, bottom %.0f%%", top * 100, left * 100, right * 100, bottom * 100))
	print(string.format("  ... and land: top %.0f%%, left %.0f%%, right %.0f%%, bottom %.0f%%", top_land * 100, left_land * 100, right_land * 100, bottom_land * 100))
	-- (the first Eldoria: top 100%, left 52%, right 57%, bottom 0%, land to the very edge all along)
	check(top == 1 and bottom == 1, "the top and the bottom edges are that sea all along: no line there")
	check(left == 1 and right == 1, "and both sides")
	check(top_land + bottom_land + left_land + right_land == 0, "no land on any edge: no coast is cut straight")
	-- ... and none near one either: the water gets to its darkest before the map ends
	local near = math.huge
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			if buffer.readu8(bytes, y * W + x) >= 128 then
				near = math.min(near, x, W - 1 - x, y, H - 1 - y)
			end
		end
	end
	print(string.format("  the land closest to an edge: %d tiles away", near))
	check(near >= 30, "all land is 30 tiles or more from the map's edge")
end

-- ---------------------------------------------------------------------------------------------
-- 2. the structures' icons
-- ---------------------------------------------------------------------------------------------
local ICON_SIZE, DEVICE_RATIO = 30, 2.0
do
	local src = fs.readFile("src/client/Map/StructureLayer.luau")
	check(has(src, "StructureLayer.ICON_SIZE = 30") and has(src, "StructureLayer.DEVICE_RATIO = 2.0"), "the layer's icon size and device ratio")
	check(has(src, 'require(script.Parent:WaitForChild("StructureZoom"))'), "the layer loads Map/StructureZoom")
	check(has(src, "local icon_scale, dots = StructureZoom.icon(zoom)"), "... and sizes its icons with it")
	check(not has(src, "zoom <= StructureLayer.DOTS_ZOOM"), "... with no rule of its own left")
	check(has(src, "p.glyph.Visible = not dots"), "an icon's picture shows unless it is a dot")
end
do
	check(StructureZoom.DOTS_ZOOM == 0, "no zoom turns icons into dots")
	check(near(StructureZoom.MIN_SCALE, 1.2 / 3.0), "an icon stops shrinking where RoWorld's dots began (0.4)")
	-- every zoom a camera can reach, and beyond: the picture always shows, the plate never under 12 px
	local smallest, biggest_step = math.huge, 0
	local prev: number? = nil
	local z = 0.01
	while z <= 40 do
		local scale, dots = StructureZoom.icon(z)
		check(dots == false, string.format("zoom %.2f: the picture shows", z))
		smallest = math.min(smallest, scale)
		if prev ~= nil then
			biggest_step = math.max(biggest_step, math.abs(scale - prev))
			check(scale >= prev - 1e-12, string.format("zoom %.2f: zooming in never makes an icon smaller", z))
		end
		prev = scale
		z += 0.01
	end
	check(near(smallest, 0.4) and near(smallest * ICON_SIZE, 12), "the smallest plate is 12 px (" .. smallest * ICON_SIZE .. ")")
	check(biggest_step < 0.005, string.format("the size never jumps (biggest step %.4f for 0.01 of zoom)", biggest_step))
	-- where RoWorld drew a dot: now the icon it drew just before
	for _, zoom in { 0.2, 0.7, 1.15, 1.2 } do
		local scale, dots = StructureZoom.icon(zoom)
		check(near(scale, 0.4) and not dots, "zoom " .. zoom .. " (a dot in RoWorld): a 12 px icon with its picture")
	end
	-- above it: RoWorld's sizes, unchanged
	for _, c in { { 1.5, 0.5 }, { 2.4, 0.8 }, { 3.0, 1.0 }, { 5.0, 1.0 }, { 6.99, 1.0 }, { 7.0, 1.0 }, { 10.5, 1.5 }, { 14.0, 2.0 } } do
		local scale, dots = StructureZoom.icon(c[1])
		check(near(scale, c[2]) and not dots, string.format("zoom %.2f: %.2f of the size, as before (%.3f)", c[1], c[2], scale))
	end
	check(select(1, StructureZoom.icon(0 / 0)) == 0.4, "a zoom that is no number: the smallest icon")
	-- the switch back: RoWorld's dots
	StructureZoom.DOTS_ZOOM = 1.2
	local s1, d1 = StructureZoom.icon(1.2)
	local s2, d2 = StructureZoom.icon(1.21)
	check(near(s1, 0.3) and d1 == true and near(s2, 1.21 / 3) and d2 == false, "DOTS_ZOOM = 1.2 brings RoWorld's dots back")
	StructureZoom.DOTS_ZOOM = 0
end
-- on Eldoria, at the farthest zoom of real screens
do
	local map = WorldMap.get("world")
	local k = tonumber(Data.k_lin) or 1
	for _, v in {
		{ "a 1280 x 720 window", 1280, 720, true },
		{ "a Studio window, 1000 x 560", 1000, 560, true },
		{ "full HD, 1920 x 1080", 1920, 1080, false },
		{ "a phone, 844 x 390", 844, 390, true },
		{ "a tablet, 1180 x 820", 1180, 820, true },
	} do
		local cam = MapCamera.new(nil, map)
		cam._vp = Vector2.new(v[2], v[3])
		local far = cam:min_scale()
		local zoom = far / k * DEVICE_RATIO
		local scale, dots = StructureZoom.icon(zoom)
		check(not dots and scale * ICON_SIZE >= 12 - 1e-9, string.format("%s, zoomed all the way out (zoom %.2f): a %.0f px icon with its picture", v[1], zoom, scale * ICON_SIZE))
		-- (what RoWorld's rule did there: this is the report)
		check((zoom <= 1.2) == v[4], string.format("%s: RoWorld's rule drew %s there", v[1], if v[4] then "dots" else "icons"))
		-- the map is then smaller than the screen: what shows around it is the backdrop
		check(far * map.W < v[2] and far * map.H < v[3], v[1] .. ": the whole map fits, with the backdrop around it")
	end
end

print(string.format("zoom_mapa: %d checks, %d failed", checks, failed))
if failed > 0 then
	error("zoom_mapa failed")
end
