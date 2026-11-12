--!nocheck
-- The game's own world (src/shared/Data/Maps/World, "Eldoria", made by tools/maps/make_fantasy_world.py):
-- an invented map, with invented kingdoms, and nothing of the real one.   lune run tests/eldoria.luau
local MapList = require("../src/shared/Data/MapList")
local WorldMap = require("../src/shared/Core/WorldMap")
local Data = require("../src/shared/Data/Maps/World")
local Earth = require("./fixtures/EarthWorld")

local fails = 0
local function ok(cond: boolean, what: string)
	if not cond then
		fails += 1
		print("FAIL " .. what)
	end
end

-- (2026-11-12: a second, smaller map, Valtara: tests/valtara.luau)
ok(MapList.DEFAULT == "world" and MapList.get("world") ~= nil, "the world is the default map")
ok(MapList.get("world").name == "Eldoria" and Data.name == "Eldoria", "its name is Eldoria")
ok(MapList.get("world").replicated == true, "it is the one map every client has from the start")
ok(MapList.LICENSE == "Original" and MapList.ATTRIBUTION == "" and MapList.CREDITS == "", "an original map, no credits owed")

local map = WorldMap.get("world")
ok(map.W == 2000 and map.H == 1000, "2000 x 1000 tiles")
ok(map.land_count == Data.land_tiles, "the land the manifest says (" .. tostring(map.land_count) .. ")")
local share = map.land_count / map.N
ok(share > 0.25 and share < 0.40, string.format("about a third is land (%.1f%%)", share * 100))
ok(map.contestable_count == map.land_count, "all of its land can be taken (no ice cap)")

-- sea all around: the game's map is flat and the view shows open sea past it, so land on the map's edge
-- would be a coast cut straight (the first Eldoria: a cap along the whole bottom, islands cut at the sides)
do
	local W, H = map.W, map.H
	local on_edge = 0
	for x = 0, W - 1 do
		on_edge += (if map:is_land(x) then 1 else 0) + (if map:is_land((H - 1) * W + x) then 1 else 0)
	end
	for y = 0, H - 1 do
		on_edge += (if map:is_land(y * W) then 1 else 0) + (if map:is_land(y * W + W - 1) then 1 else 0)
	end
	ok(on_edge == 0, "no land on the map's edge (" .. on_edge .. " tiles)")
end

-- several continents and islands: land bodies by size
local sizes: { number } = {}
do
	local W, H, N = map.W, map.H, map.N
	local seen = buffer.create(N)
	local stack = table.create(4096)
	for start = 0, N - 1 do
		if buffer.readu8(seen, start) == 0 and map:is_land(start) then
			buffer.writeu8(seen, start, 1)
			local n, top = 0, 1
			stack[1] = start
			while top > 0 do
				local t = stack[top]
				top -= 1
				n += 1
				local x = t % W
				for _, o in { if x > 0 then t - 1 else -1, if x < W - 1 then t + 1 else -1, t - W, t + W } do
					if o >= 0 and o < N and buffer.readu8(seen, o) == 0 and map:is_land(o) then
						buffer.writeu8(seen, o, 1)
						top += 1
						stack[top] = o
					end
				end
			end
			table.insert(sizes, n)
		end
	end
end
local continents, islands, biggest = 0, 0, 0
for _, n in sizes do
	biggest = math.max(biggest, n)
	if n >= 20000 then
		continents += 1
	elseif n >= 30 then
		islands += 1
	end
end
ok(continents >= 5, "several continents (" .. continents .. ")")
ok(continents <= 12, "not a world of islands only")
ok(islands >= 20, "and islands (" .. islands .. ")")
ok(biggest < map.land_count * 0.45, "no continent is most of the world")

-- the kingdoms: invented names, on land, apart, no real flag
local nations = map:load_nations()
ok(#nations == #Data.nations and #nations >= 60, #nations .. " kingdoms")
local real: { [string]: boolean } = {}
for _, nd in Earth.nations do
	real[string.lower(nd.name)] = true
end
local seen: { [string]: boolean } = {}
local closest = math.huge
for i, nd in nations do
	ok(not real[string.lower(nd.name)], nd.name .. " is not a real place")
	ok(not seen[nd.name], nd.name .. " is named once")
	seen[nd.name] = true
	ok(nd.flag == nil or nd.flag == "", nd.name .. " has no real flag")
	ok(nd.tile >= 0 and map:is_land(nd.tile), nd.name .. " starts on land")
	for j = i + 1, #nations do
		local o = nations[j]
		closest = math.min(closest, math.sqrt((nd.x - o.x) ^ 2 + (nd.y - o.y) ^ 2))
	end
end
ok(closest >= 30, string.format("kingdoms start apart (closest %.0f tiles)", closest))

print(string.format("eldoria: %d kingdoms, %d continents, %d islands, %d failed", #nations, continents, islands, fails))
if fails > 0 then
	error("eldoria tests failed")
end
