--!nocheck
-- Valtara, the small map (2026-11-12: "one more map, only smaller"; tools/maps/make_small_map.py):
-- its terrain is server-only (src/server/MapData/Valtara, downloaded by a client when a match on it
-- starts), its row is in the registry beside Eldoria's, it is smaller in every way that counts, and
-- the public matches use it: the free-for-all plays Valtara, Eldoria keeps its own match.
--   lune run tests/valtara.luau
require("./prelude")
local MapList = require("../src/shared/Data/MapList")
local WorldMap = require("../src/shared/Core/WorldMap")
local Sim = require("../src/shared/Core/Sim")
local Rules = require("../src/shared/Core/Rules")
local LobbyRules = require("../src/server/Lobbies/LobbyRules")
local Data = require("../src/server/MapData/Valtara")
local Thumbs = require("../src/shared/Assets/MapThumbs")
local OwnArt = require("../src/shared/Assets/OwnArt")

local checks, fails = 0, 0
local function ok(cond: boolean, what: string)
	checks += 1
	if not cond then
		fails += 1
		print("FAIL " .. what)
	end
end

-- the registry: two maps, Eldoria the default
ok(#MapList.maps == 2, "two maps in the registry (" .. #MapList.maps .. ")")
local row = MapList.get("valtara")
local world_row = MapList.get("world")
ok(row ~= nil and row.name == "Valtara" and row.module == "Valtara", "Valtara's row")
ok(row.replicated ~= true, "its terrain is not sent to every client (a match on it downloads it)")
ok(MapList.DEFAULT == "world", "Eldoria is still the map the title and a solo match start with")
ok(row.width == 1000 and row.height == 500, "1000 x 500 tiles")
ok(row.width * row.height == world_row.width * world_row.height / 4, "a quarter of Eldoria's tiles")
ok(row.land_tiles < world_row.land_tiles * 0.4 and row.land_tiles > world_row.land_tiles * 0.25, string.format("about a third of Eldoria's land (%.0f%%)", 100 * row.land_tiles / world_row.land_tiles))
ok(row.nations < world_row.nations / 2 and row.nations >= 20, row.nations .. " kingdoms, fewer than half of Eldoria's")
local featured = false
for _, c in row.categories do
	featured = featured or c == "featured"
	ok(not LobbyRules.WEIRD_CATEGORIES[c], "category " .. c .. " is not one the public matches play less")
end
ok(featured, "it is on the map list's first tab")

-- the map itself
local map = WorldMap.get("valtara")
ok(map.W == 1000 and map.H == 500 and map.name == "Valtara", "the map builds")
ok(map.land_count == Data.land_tiles and map.land_count == row.land_tiles, "the land the registry says (" .. map.land_count .. ")")
ok(map.contestable_count == map.land_count, "all of its land can be taken")
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
-- two lands around the inner sea, and islands
local sizes: { number } = {}
do
	local W, N = map.W, map.N
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
table.sort(sizes, function(a, b)
	return a > b
end)
ok(sizes[1] > 50000 and sizes[2] > 50000, string.format("two great lands (%d and %d tiles)", sizes[1], sizes[2]))
ok(sizes[1] < map.land_count * 0.6, "neither is most of the map")
local islands = 0
for i = 3, #sizes do
	islands += if sizes[i] >= 30 then 1 else 0
end
ok(islands >= 10, "and islands (" .. islands .. ")")
-- the inner sea: the map's middle is open water joined to the ocean
do
	local mid = 255 * map.W + 485
	ok(not map:is_land(mid), "the middle of the map is sea")
	-- (the ocean bit of the tile's byte: tools/maps/make_maps.py OCEAN = 0x20)
	ok(bit32.band(buffer.readu8(map.tile_bytes, mid), 0x20) ~= 0, "... joined to the ocean (not a lake)")
	ok(map:body_of(mid) == map:body_of(0), "... the same water as the map's corner")
end

-- the kingdoms: on land, apart, none of Eldoria's names
local nations = map:load_nations()
ok(#nations == row.nations and #nations == #Data.nations, #nations .. " kingdoms")
local world_names: { [string]: boolean } = {}
for _, nd in WorldMap.get("world"):load_nations() do
	world_names[nd.name] = true
end
local seen: { [string]: boolean } = {}
local closest = math.huge
for i, nd in nations do
	ok(not world_names[nd.name], nd.name .. " is not one of Eldoria's kingdoms")
	ok(not seen[nd.name], nd.name .. " is named once")
	seen[nd.name] = true
	ok(nd.flag == nil or nd.flag == "", nd.name .. " has no real flag")
	ok(nd.tile >= 0 and map:is_land(nd.tile), nd.name .. " starts on land")
	for j = i + 1, #nations do
		local o = nations[j]
		closest = math.min(closest, math.sqrt((nd.x - o.x) ^ 2 + (nd.y - o.y) ^ 2))
	end
end
ok(closest >= 24, string.format("kingdoms start apart (closest %.0f tiles)", closest))

-- fewer tribes on less land: as crowded as Eldoria, not three times as crowded
local world = WorldMap.get("world")
local t_small, t_world = Sim.default_tribes(map), Sim.default_tribes(world)
ok(t_world == Rules.DEFAULT_TRIBES, "Eldoria keeps its " .. t_world .. " tribes")
ok(t_small == math.floor(Rules.DEFAULT_TRIBES * row.land_tiles / Sim.TRIBES_FULL_LAND + 0.5), "Valtara: " .. t_small .. " tribes, in proportion to its land")
local d_small, d_world = map.land_count / t_small, world.land_count / t_world
ok(d_small > d_world * 0.8 and d_small < d_world * 1.25, string.format("about the same land per tribe (%.0f and %.0f tiles)", d_small, d_world))
ok(Sim.default_tribes(WorldMap.get("world@80")) == math.floor(Rules.DEFAULT_TRIBES * 0.64 + 0.5), "Eldoria's public build keeps its count too")
local pub = WorldMap.get(LobbyRules.match_map_id("valtara"))
ok(pub.W == 800 and pub.H == 400, "a public match plays it at 80 %: 800 x 400")
ok(Sim.default_tribes(pub) == math.floor(t_small * 0.64 + 0.5) or math.abs(Sim.default_tribes(pub) - t_small * 0.64) <= 1, "... with tribes in proportion (" .. Sim.default_tribes(pub) .. ")")

-- the public matches (server/Lobbies/LobbyRules, fed as server/ServerMain feeds it)
local maps = {}
for _, m in MapList.maps do
	table.insert(maps, { id = m.id, name = m.name, weight = m.multiplayer_frequency or 1, categories = m.categories, land = m.land_tiles, k_lin = m.k_lin })
end
local ffa = LobbyRules.public_weights(maps)
-- (2026-11-12: Eldoria has no match of its own; CLÁSSICA and RANQUEADA play both maps in turns)
local in_ffa = {}
for _, e in ffa do
	in_ffa[e.id] = e.weight
end
ok(#ffa == 2 and (in_ffa.valtara or 0) > 0 and (in_ffa.world or 0) > 0, "the free-for-alls' rotation plays Valtara and Eldoria")
local seen = {}
for _, r in { 0, 0.3, 0.6, 0.999 } do
	seen[LobbyRules.pick_map(ffa, {}, r)] = true
	ok(LobbyRules.pick_map(ffa, { "valtara" }, r) == "world", "after Valtara: Eldoria")
	ok(LobbyRules.pick_map(ffa, { "world", "valtara", "world" }, r) == "valtara", "after Eldoria: Valtara (two maps take turns)")
end
ok(seen.valtara and seen.world, "with nothing played before, either map may be first")
local team = LobbyRules.team_weights(maps)
local team_ids = {}
for _, e in team do
	team_ids[e.id] = e.weight
end
ok((team_ids.valtara or 0) > 0 and (team_ids.world or 0) > 0, "team games play both maps")
local cap_small = LobbyRules.max_players(row.land_tiles, row.k_lin)
local cap_world = LobbyRules.max_players(world_row.land_tiles, world_row.k_lin)
ok(cap_small == 15, "a public match on Valtara holds " .. cap_small .. " players")
ok(cap_world == 45 and cap_small < cap_world, "Eldoria's holds " .. cap_world)

-- its picture on the map cards: this game's own drawing, made from the map
ok(type(Thumbs.valtara) == "string" and OwnArt.key_for(Thumbs.valtara) == "thumb/valtara", "the cards have a picture for it")
do
	local w, h = OwnArt.size("thumb/valtara")
	ok(w == 256 and h == 128, string.format("... %d x %d, the map's shape", w, h))
	local px = OwnArt.pixels("thumb/valtara")
	ok(px ~= nil and buffer.len(px) == w * h * 4, "... with its pixels")
	-- the middle is sea (blue more than red), the west land is green
	local function at(x, y)
		local i = (y * w + x) * 4
		return buffer.readu8(px, i), buffer.readu8(px, i + 1), buffer.readu8(px, i + 2), buffer.readu8(px, i + 3)
	end
	local r, _g, b, a = at(124, 65)
	ok(a >= 250 and b > r + 30, "... sea in the middle")
	local r2, g2, b2 = at(60, 70)
	ok(g2 > b2 and g2 >= r2, "... land in the west")
end

-- a match on it runs
local sim = Sim.new(map, { seed = 5, difficulty = 1, max_humans = 1, spawn_ticks = 20 })
for _ = 1, 80 do
	sim:step()
end
ok(sim.map.id == "valtara" and sim.tribe_count == t_small, "a Sim on Valtara runs, with its tribes")

print(string.format("valtara: %d checks, %d failed", checks, fails))
if fails > 0 then
	error("valtara tests failed")
end
