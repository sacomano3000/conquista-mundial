--!strict
-- Cosmetics: what a player collects and wears (the "Coleção"). Three kinds, each with its own tab and
-- its own crate:
--
--   skins   a territory pattern: a 1-bit mask tiled over your land (primary vs
--           secondary tiles; mask pixels are 2^scale tiles wide). '#' = the secondary colour: your
--           own colour lightened (tone > 0) or darkened (tone < 0), or a fixed `accent` colour
--           (legendary skins). Data/MySkins adds the owner's own.
--   flags   this game's medieval banners (Assets/Flags: drawn by the game itself, four rarities),
--           shown left of your name on the map and the leaderboard. Data/MyFlags adds the owner's own:
--           drawn with letters (painted by the client: Assets/OwnArt.register) or an uploaded image.
--   pets    a creature's head (Assets/Pets), shown right of your name.
--   exclusive skins (exclusive_skins) are made for particular players: several colours, never in a
--           crate (Cosmetics.all() is the crate catalog; Cosmetics.exclusives() these).
--
-- A crate of a kind rolls a rarity by RARITIES odds (Data/MyShop.caixa.chances), then an item of that
-- kind and rarity (uniformly). odds() gives the player's own odds, shown before every purchase
-- (Roblox's paid random items rules). The same items are sold one by one in the mystery shop (Data/Shop).
--   * With duplicates (Cosmetics.DUPLICATES, Data/MyShop.caixa.repetidos; 2026-11-12): among every
--     item of that rarity; one the player owns already pays Stars instead (duplicate_stars). The odds
--     are the same for everyone, until the player owns the whole kind (no crate is sold then).
--   * Without: only items the player doesn't own; rarities with nothing left drop out and the odds of
--     the rest scale up.
local IS_ROBLOX = typeof(game) == "Instance"
local function asset(name: string): any
	if IS_ROBLOX then
		return require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Assets[name]) :: any
	end
	return (require :: any)("../Assets/" .. name)
end
local function data(name: string): any
	if IS_ROBLOX then
		return require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data[name]) :: any
	end
	return (require :: any)("./" .. name)
end
local Flags: any = asset("Flags")
local Pets: any = asset("Pets")
local OwnArt: any = asset("OwnArt")
local Seasons: any = asset("Seasons")
local MyShop: any = data("MyShop")
local MySkins: any = data("MySkins")
local MyFlags: any = data("MyFlags")

local Cosmetics = {}

--- The kinds, in the Coleção's tab order.
Cosmetics.KINDS = { "skin", "flag", "pet" }

Cosmetics.RARITIES = {
	{ id = "common", name = "Common", odds = 0.80, color = 0x9AA6B2 },
	{ id = "rare", name = "Rare", odds = 0.15, color = 0x3D8BFF },
	{ id = "epic", name = "Epic", odds = 0.045, color = 0xA35BFF },
	{ id = "legendary", name = "Legendary", odds = 0.005, color = 0xFFB22E },
}
--- The owner's names for the rarities (Data/MyShop, MySkins, MyFlags are written in Portuguese).
Cosmetics.RARITY_PT = { comum = "common", raro = "rare", epico = "epic", lendario = "legendary" }
do
	-- the crate's odds are the owner's (Data/MyShop.caixa.chances, in %), made to sum to 1
	local ch = type(MyShop) == "table" and type(MyShop.caixa) == "table" and MyShop.caixa.chances
	if type(ch) == "table" then
		local got, total = {}, 0.0
		for pt, id in Cosmetics.RARITY_PT do
			local v = tonumber(ch[pt])
			if v ~= nil and v == v and v >= 0 then
				got[id] = v
				total += v
			end
		end
		if total > 0 then
			for _, r in Cosmetics.RARITIES do
				r.odds = (got[r.id] or 0) / total
			end
		end
	end
end

--- Duplicates (Data/MyShop.caixa.repetidos; 2026-11-12). true: a crate rolls among EVERY item of its
--- kind, and one the player already owns pays Stars instead (DUPLICATE_STARS, by rarity). false: a crate
--- only ever gives an item the player doesn't own (how it was). Read at each roll: a test may switch it.
Cosmetics.DUPLICATES = false
--- Stars for a duplicate of each rarity (Data/MyShop.caixa.coroas_repetido), never above a crate's
--- price in Stars (a crate that pays for the next one would never end).
Cosmetics.DUPLICATE_STARS = { common = 0, rare = 0, epic = 0, legendary = 0 } :: { [string]: number }
do
	local cx = type(MyShop) == "table" and type(MyShop.caixa) == "table" and MyShop.caixa
	if type(cx) == "table" then
		Cosmetics.DUPLICATES = cx.repetidos == true
		local cap = math.max(0, math.floor(tonumber(cx.coroas) or 0))
		local back = cx.coroas_repetido
		if type(back) == "table" then
			for pt, id in Cosmetics.RARITY_PT do
				local v = tonumber(back[pt])
				if v ~= nil and v == v and v >= 0 then
					Cosmetics.DUPLICATE_STARS[id] = math.min(math.floor(v), cap)
				end
			end
		end
	end
end

--- (mask rows top to bottom; every row the same width)
Cosmetics.skins = {
	-- Common
	{ id = "stripes", name = "Stripes", rarity = "common", scale = 1, tone = -0.22, mask = { "##.." } },
	{ id = "bands", name = "Bands", rarity = "common", scale = 1, tone = -0.22, mask = { "#", "#", ".", "." } },
	{ id = "checker", name = "Checker", rarity = "common", scale = 1, tone = -0.18, mask = { "#.", ".#" } },
	{
		id = "diagonal",
		name = "Diagonal",
		rarity = "common",
		scale = 1,
		tone = -0.24,
		mask = { "#...", ".#..", "..#.", "...#" },
	},
	{
		id = "dots",
		name = "Dots",
		rarity = "common",
		scale = 1,
		tone = 0.32,
		mask = { "....", ".#..", "....", "...." },
	},
	{
		id = "grid",
		name = "Grid",
		rarity = "common",
		scale = 0,
		tone = -0.26,
		mask = { "####", "#...", "#...", "#..." },
	},
	-- Rare
	{
		id = "bricks",
		name = "Bricks",
		rarity = "rare",
		scale = 0,
		tone = -0.3,
		mask = { "########", "#.......", "#.......", "########", "....#...", "....#..." },
	},
	{
		id = "waves",
		name = "Waves",
		rarity = "rare",
		scale = 1,
		tone = -0.24,
		mask = { "#......#", ".#....#.", "..#..#..", "...##..." },
	},
	{
		id = "diamonds",
		name = "Diamonds",
		rarity = "rare",
		scale = 0,
		tone = -0.26,
		mask = { "...##...", "..#..#..", ".#....#.", "#......#", "#......#", ".#....#.", "..#..#..", "...##..." },
	},
	{
		id = "crosshatch",
		name = "Crosshatch",
		rarity = "rare",
		scale = 0,
		tone = -0.24,
		mask = { "#...#", ".#.#.", "..#..", ".#.#.", "#...#" },
	},
	{
		id = "zigzag",
		name = "Zigzag",
		rarity = "rare",
		scale = 1,
		tone = -0.3,
		mask = { "#...#...", ".#.#.#.#", "..#...#." },
	},
	{
		id = "cobble",
		name = "Cobble",
		rarity = "rare",
		scale = 0,
		tone = -0.24,
		mask = { "..####..", ".#....#.", "#......#", "#......#", "####....", "....#..#", ".....##." },
	},
	-- Epic
	{
		id = "stars",
		name = "Starfield",
		rarity = "epic",
		scale = 0,
		tone = 0.42,
		mask = {
			"..........",
			"...#......",
			"..###.....",
			"...#......",
			"..........",
			".......#..",
			"......###.",
			".......#..",
			"..........",
			"..........",
		},
	},
	{
		id = "camo",
		name = "Camouflage",
		rarity = "epic",
		scale = 1,
		tone = -0.3,
		mask = {
			"..###.......##..",
			".#####.....####.",
			".######...#####.",
			"..####.....###..",
			"...##..........#",
			"#.........###.##",
			"##......######..",
			"###....#######..",
			".##.....#####...",
			"..........##....",
			"....##.........#",
			"...#####......##",
			"..#######....###",
			"...#####......#.",
			"....###.........",
			"................",
		},
	},
	{
		id = "circuit",
		name = "Circuit",
		rarity = "epic",
		scale = 0,
		tone = 0.34,
		mask = {
			"#####...",
			"....#...",
			"....#.##",
			"....###.",
			"##......",
			".#......",
			".####..#",
			"....####",
		},
	},
	{
		id = "hex",
		name = "Hive",
		rarity = "epic",
		scale = 0,
		tone = -0.26,
		mask = {
			".####....",
			"#....#...",
			"#....#...",
			".####....",
			"....#####",
			"...#....#",
			"...#....#",
			"....#####",
		},
	},
	{
		id = "tartan",
		name = "Tartan",
		rarity = "epic",
		scale = 0,
		tone = -0.22,
		mask = {
			"##..#...",
			"##..#...",
			"########",
			"##..#...",
			"########",
			"##..#...",
			"##..#...",
			"##..#...",
		},
	},
	-- Legendary: a fixed accent over any colour
	{
		id = "gilded",
		name = "Gilded",
		rarity = "legendary",
		scale = 0,
		accent = 0xE9B949,
		mask = { "...##...", "..#..#..", ".#....#.", "#......#", "#......#", ".#....#.", "..#..#..", "...##..." },
	},
	{
		id = "frost",
		name = "Frost",
		rarity = "legendary",
		scale = 0,
		accent = 0xF2F8FF,
		mask = {
			"...#....",
			".#.#.#..",
			"..###...",
			"#######.",
			"..###...",
			".#.#.#..",
			"...#....",
			"........",
		},
	},
	{
		id = "obsidian",
		name = "Obsidian",
		rarity = "legendary",
		scale = 0,
		accent = 0x15151C,
		mask = { "#...#", ".#.#.", "..#..", ".#.#.", "#...#" },
	},
	{
		id = "ember",
		name = "Ember",
		rarity = "legendary",
		scale = 1,
		accent = 0xFF6A2B,
		mask = { "#......#", ".#....#.", "..#..#..", "...##..." },
	},
}

--- Skins made for particular players. Never in a crate, never on a bot player, not in the Locker's
--- "N of M": the `owners` (Roblox user ids) own them (Purchases), and it goes on the first time they
--- join with it. Several colours: in `mask`, '.' is the owner's own fill and '1'..'9', 'a'..'z' are
--- colors[1..], drawn at `alpha`.
--- (2026-11-12: empty. The original game had one here, made for one of ITS players, whose account
--- would have owned it in this game too. To give a skin to someone: one entry
--- { id, name, owners = { user id }, scale, alpha, colors, mask }.)
Cosmetics.exclusive_skins = {}

--- How an exclusive item shows in the Locker (not a crate rarity: no odds).
Cosmetics.EXCLUSIVE = { id = "exclusive", name = "Exclusive", odds = 0, color = 0xFF6FD8 }

--- RoWorld General's skins (Data/Subscription; 2026-10-27): a new one each month for subscribers,
--- who keep it. Never in a crate nor on a bot player, not in the Locker's "N of M"; only
--- server/Purchases.general_perks gives one, and anyone given one may own it. Several colours, as an
--- exclusive's.
Cosmetics.general_skins = {
	{
		-- a ribbon: a navy band edged and studded in gold
		id = "gen_chevrons",
		name = "Officer's Braid",
		scale = 1,
		alpha = 200,
		colors = { 0xE2BC58, 0x1C2740 },
		mask = { "11111111", "22222222", "22122212", "22222222", "11111111", "........", "........", "........" },
	},
}
--- How a General skin shows in the Locker.
Cosmetics.GENERAL = { id = "general", name = "General", odds = 0, color = 0xD9B24E }

--- How an item of the monthly pass shows in the Locker (Data/Missions; Assets/Seasons: a skin, a flag
--- and a pet for each month of the year). Never in a crate, the shop or on a bot player, not in the
--- Locker's "N of M": only a pass's monthly mission gives one (server/Purchases), and whoever was given
--- one keeps it.
Cosmetics.SEASON = { id = "season", name = "Pass", odds = 0, color = 0x4FD6C4 }

--- Alpha of the secondary tiles (the primary fill is MapSurface.TERRITORY_ALPHA, 150).
Cosmetics.SECONDARY_ALPHA = 190

type Item = { id: string, kind: string, name: string, rarity: string, [string]: any }

local items: { [string]: Item } = {}
local order: { Item } = {}

local function note(text: string)
	if IS_ROBLOX then
		warn("[Game] " .. text)
	end
end

--- "comum" / "common"... -> the rarity's id ("common" for anything else).
local function rarity_of(v: any): string
	if type(v) == "string" then
		local k = string.lower(v)
		if Cosmetics.RARITY_PT[k] ~= nil then
			return Cosmetics.RARITY_PT[k]
		end
		for _, r in Cosmetics.RARITIES do
			if r.id == k then
				return k
			end
		end
	end
	return "common"
end

--- A drawing's rows: every one a string of the same width (1..max_w), 1..max_h rows.
local function rows_ok(rows: any, max_w: number, max_h: number): boolean
	if type(rows) ~= "table" or #rows < 1 or #rows > max_h then
		return false
	end
	local w = nil
	for _, row in rows do
		if type(row) ~= "string" or #row < 1 or #row > max_w or (w ~= nil and #row ~= w) then
			return false
		end
		w = #row
	end
	return true
end

local function id_ok(id: any): boolean
	return type(id) == "string" and #id >= 1 and #id <= 24 and string.match(id, "^[%w_]+$") ~= nil
end

for _, s in Cosmetics.skins do
	local it: any = table.clone(s)
	it.kind = "skin"
	items[it.id] = it
	table.insert(order, it)
end
-- the owner's own skins (Data/MySkins, fields in Portuguese)
for i, s in (if type(MySkins) == "table" then MySkins else {}) :: { any } do
	if type(s) ~= "table" or not id_ok(s.id) or items[s.id] ~= nil or not rows_ok(s.desenho, 32, 32) then
		note(string.format("MySkins: a skin %s foi ignorada (id repetido ou inválido, ou desenho com linhas de tamanhos diferentes)", tostring(type(s) == "table" and s.id or i)))
		continue
	end
	local it: any = {
		id = s.id,
		kind = "skin",
		custom = true,
		name = if type(s.nome) == "string" and s.nome ~= "" then s.nome else s.id,
		rarity = rarity_of(s.raridade),
		scale = if s.escala == 0 then 0 else 1,
		mask = s.desenho,
	}
	if type(s.cores) == "table" and #s.cores > 0 then
		it.colors = s.cores
	elseif type(s.destaque) == "number" then
		it.accent = s.destaque
	else
		it.tone = math.clamp(tonumber(s.tom) or -0.24, -1, 1)
	end
	items[it.id] = it
	table.insert(order, it)
end

for _, f in (Flags.flags or {}) :: { any } do
	local it: any = table.clone(f)
	it.id = "flag_" .. f.code
	it.kind = "flag"
	it.rarity = rarity_of(f.rarity)
	items[it.id] = it
	table.insert(order, it)
end
-- the owner's own flags (Data/MyFlags): an uploaded image, or a drawing in letters that the client
-- paints (OwnArt.register: an image that exists only in the code, like the game's own banners)
Cosmetics.MYFLAG_W = 114
for i, f in (if type(MyFlags) == "table" then MyFlags else {}) :: { any } do
	local id = if type(f) == "table" and id_ok(f.id) then "flag_my_" .. f.id else nil
	if id == nil or items[id] ~= nil then
		note(string.format("MyFlags: a bandeira %s foi ignorada (id repetido ou inválido)", tostring(type(f) == "table" and f.id or i)))
		continue
	end
	local it: any = {
		id = id,
		kind = "flag",
		custom = true,
		code = "my_" .. f.id,
		name = if type(f.nome) == "string" and f.nome ~= "" then f.nome else f.id,
		rarity = rarity_of(f.raridade),
		x = 0,
		y = 0,
	}
	if type(f.imagem) == "string" and f.imagem ~= "" then
		it.image = if string.match(f.imagem, "^%d+$") ~= nil then "rbxassetid://" .. f.imagem else f.imagem
		it.w = math.clamp(math.floor(tonumber(f.largura) or 228), 1, 1024)
		it.h = math.clamp(math.floor(tonumber(f.altura) or 152), 1, 1024)
	elseif rows_ok(f.desenho, 38, 25) and type(f.cores) == "table" then
		local rows: { string } = f.desenho
		local gw, gh = #rows[1], #rows
		-- (each letter a square of k pixels, so the edges stay sharp when the flag is drawn bigger)
		local k = math.max(1, Cosmetics.MYFLAG_W // gw)
		local colors: { [string]: number } = {}
		for ch, c in f.cores do
			if type(ch) == "string" and #ch == 1 and type(c) == "number" then
				colors[ch] = c
			end
		end
		it.w, it.h = gw * k, gh * k
		it.image = "rbxasset://own/myflag/" .. f.id
		OwnArt.register(it.image, "myflag/" .. f.id, it.w, it.h, function(): buffer
			local out = buffer.create(it.w * it.h * 4)
			for gy = 1, gh do
				local row = rows[gy]
				for gx = 1, gw do
					local c = colors[string.sub(row, gx, gx)]
					if c ~= nil then
						-- (the bytes are R, G, B, A)
						local px = 0xFF000000 + (c % 256) * 0x10000 + ((c // 256) % 256) * 0x100 + ((c // 65536) % 256)
						for y = (gy - 1) * k, gy * k - 1 do
							for x = (gx - 1) * k, gx * k - 1 do
								buffer.writeu32(out, (y * it.w + x) * 4, px)
							end
						end
					end
				end
			end
			return out
		end)
	else
		note(string.format("MyFlags: a bandeira %s foi ignorada (precisa de `imagem`, ou de `cores` e `desenho` com linhas do mesmo tamanho)", tostring(f.id)))
		continue
	end
	items[id] = it
	table.insert(order, it)
end

for _, p in (Pets.pets or {}) :: { any } do
	local it: any = table.clone(p)
	it.id = "pet_" .. p.id
	it.kind = "pet"
	it.rarity = rarity_of(p.rarity)
	it.image = Pets.image
	items[it.id] = it
	table.insert(order, it)
end

-- (exclusives resolve by id like any item, but stay out of `order`: the crates, their odds, bot players)
local exclusives: { Item } = {}
local granted: { [number]: { string } } = {}
--- One more exclusive skin (an entry of Cosmetics.exclusive_skins; the tests add their own).
function Cosmetics.add_exclusive(s: any)
	local it: any = table.clone(s)
	it.kind = "skin"
	it.rarity = "exclusive"
	it.exclusive = true
	items[it.id] = it
	table.insert(exclusives, it)
	for _, uid in ((s :: any).owners or {}) :: { number } do
		granted[uid] = granted[uid] or {}
		table.insert(granted[uid], it.id)
	end
end
for _, s in Cosmetics.exclusive_skins do
	Cosmetics.add_exclusive(s)
end

-- (General skins resolve by id too, and stay out of `order` like the exclusives)
local generals: { Item } = {}
for _, g in Cosmetics.general_skins do
	local it: any = table.clone(g)
	it.kind = "skin"
	it.rarity = "general"
	it.general = true
	items[it.id] = it
	table.insert(generals, it)
end

-- (the pass's items, three a season: by id like any item, out of `order` like the exclusives)
local seasonals: { Item } = {}
for _, s in (Seasons.seasons or {}) :: { any } do
	local function add(it: any)
		it.rarity = "season"
		it.season = s.key
		it.season_name = s.name
		items[it.id] = it
		table.insert(seasonals, it)
	end
	local skin: any = table.clone(s.skin)
	skin.id = "skin_passe_" .. s.key
	skin.kind = "skin"
	add(skin)
	local flag: any = table.clone(s.flag)
	flag.id = "flag_passe_" .. s.key
	flag.kind = "flag"
	flag.code = "passe_" .. s.key
	flag.image = Seasons.flags
	add(flag)
	local pet: any = table.clone(s.pet)
	pet.id = "pet_passe_" .. s.key
	pet.kind = "pet"
	pet.image = Seasons.pets
	add(pet)
end

-- (RoWorld's flag shop sold flags of its own, one product each: none here. The mystery shop,
-- Data/Shop, sells the crate catalog's items.)
local shop_items: { Item } = {}

function Cosmetics.item(id: any): Item?
	return if type(id) == "string" then items[id] else nil
end

--- Every crate item (skins, then flags, then pets). Exclusives are not in it (Cosmetics.exclusives).
function Cosmetics.all(): { Item }
	return order
end

--- The crate items of one kind ("skin" / "flag" / "pet"), in catalog order.
local by_kind: { [string]: { Item } } = {}
function Cosmetics.of_kind(kind: string): { Item }
	local list = by_kind[kind]
	if list == nil then
		list = {}
		for _, it in order do
			if it.kind == kind then
				table.insert(list, it)
			end
		end
		by_kind[kind] = list
	end
	return list
end

--- The items made for particular players (Cosmetics.exclusive_skins).
function Cosmetics.exclusives(): { Item }
	return exclusives
end

--- RoWorld General's skins (Cosmetics.general_skins), as items.
function Cosmetics.generals(): { Item }
	return generals
end

--- The monthly pass's items (Assets/Seasons), every season's.
function Cosmetics.seasonals(): { Item }
	return seasonals
end

--- RoWorld's flag shop's flags: none in this game (kept for the screens that list them).
function Cosmetics.shop_items(): { Item }
	return shop_items
end

--- The exclusive item ids made for Roblox user `user_id` (empty for everyone else).
function Cosmetics.granted(user_id: any): { string }
	return if type(user_id) == "number" then (granted[user_id] or {}) else {}
end

--- May user `user_id` own item `id`? Any crate item; an exclusive only for its owners.
function Cosmetics.may_own(id: any, user_id: any): boolean
	local it = Cosmetics.item(id)
	if it == nil then
		return false
	end
	if not it.exclusive then
		return true
	end
	for _, g in Cosmetics.granted(user_id) do
		if g == id then
			return true
		end
	end
	return false
end

--- How many crate items (of `kind`, when given) a set of owned ids holds (the Coleção's "N of M";
--- exclusives don't count).
function Cosmetics.crate_owned(owned: { [string]: any }, kind: string?): number
	local n = 0
	for id in owned do
		local it = items[id]
		if it ~= nil and not it.exclusive and not it.shop and not it.general and not it.season and (kind == nil or it.kind == kind) then
			n += 1
		end
	end
	return n
end

function Cosmetics.rarity(id: string): any
	if id == "exclusive" then
		return Cosmetics.EXCLUSIVE
	elseif id == "general" then
		return Cosmetics.GENERAL
	elseif id == "season" then
		return Cosmetics.SEASON
	end
	for _, r in Cosmetics.RARITIES do
		if r.id == id then
			return r
		end
	end
	return Cosmetics.RARITIES[1]
end

--- The image of a flag item (its x, y, w, h: the rect in it): the banners' atlas, or the owner's own.
function Cosmetics.flag_image(it: any): string
	if it and type(it.image) == "string" then
		return it.image
	end
	local a = Flags.atlases or {}
	return if it and it.atlas then (a[it.atlas] or "") else ""
end

--- A flag item at its largest: (image, x, y, w, h).
function Cosmetics.flag_big(it: any): (string, number, number, number, number)
	return Cosmetics.flag_image(it), it and it.x or 0, it and it.y or 0, it and it.w or 0, it and it.h or 0
end

--- The image of a pet item (its x, y, w, h: the rect in it).
function Cosmetics.pet_image(it: any): string
	return if it and type(it.image) == "string" then it.image else ""
end

--- Any flag or pet item as (image, x, y, w, h); a skin has no image (its pattern is painted).
function Cosmetics.image_of(it: any): (string, number, number, number, number)
	if it == nil or it.kind == "skin" then
		return "", 0, 0, 0, 0
	end
	local img = if it.kind == "pet" then Cosmetics.pet_image(it) else Cosmetics.flag_image(it)
	return img, it.x or 0, it.y or 0, it.w or 0, it.h or 0
end

--- A player's Roblox head shot: the `face` of a match's cosmetics map is their user id (since
--- 2026-10-04 a little Roblox head picture shows next to each username).
function Cosmetics.face_image(user_id: number): string
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", user_id)
end

--- The player's own odds per rarity for a crate of `kind` (nil: one crate of everything): RARITIES'
--- odds over the rarities a crate can roll: with duplicates every rarity that has an item of that
--- kind, without them the ones that still have an item the player doesn't own (owned: set of item
--- ids). { {rarity, odds, left} } in RARITIES order (left: items of it not owned yet); odds sum to 1.
function Cosmetics.odds(owned: { [string]: any }, kind: string?): { { rarity: any, odds: number, left: number } }
	local out = {}
	local total = 0.0
	local dups = Cosmetics.DUPLICATES
	local list: { any } = if kind ~= nil then Cosmetics.of_kind(kind) else order
	for _, r in Cosmetics.RARITIES do
		local left, all = 0, 0
		for _, it in list do
			if it.rarity == r.id then
				all += 1
				if not owned[it.id] then
					left += 1
				end
			end
		end
		-- (with duplicates a rarity is rolled whether or not the player has all of it; without them
		-- a rarity with nothing left gives its share to the others)
		local on = if dups then all > 0 else left > 0
		table.insert(out, { rarity = r, odds = if on then r.odds else 0.0, left = left })
		if on then
			total += r.odds
		end
	end
	for _, e in out do
		e.odds = if total > 0 then e.odds / total else 0.0
	end
	return out
end

--- Roll a crate of `kind` (nil: of everything). r1, r2 in [0, 1). Returns the item and whether the
--- player already owns it (a duplicate: only with Cosmetics.DUPLICATES; it pays
--- Cosmetics.duplicate_stars). nil when they own everything of it: a crate is never rolled then,
--- with or without duplicates (there is nothing left to win).
function Cosmetics.roll(owned: { [string]: any }, r1: number, r2: number, kind: string?): (string?, boolean)
	local dups = Cosmetics.DUPLICATES
	local list: { any } = if kind ~= nil then Cosmetics.of_kind(kind) else order
	if dups then
		local left = false
		for _, it in list do
			if not owned[it.id] then
				left = true
				break
			end
		end
		if not left then
			return nil, false
		end
	end
	local odds = Cosmetics.odds(owned, kind)
	local x = r1
	local pick = nil
	for _, e in odds do
		if e.odds > 0 then
			pick = e
			if x < e.odds then
				break
			end
			x -= e.odds
		end
	end
	if pick == nil then
		return nil, false
	end
	local pool = {}
	for _, it in list do
		if it.rarity == pick.rarity.id and (dups or not owned[it.id]) then
			table.insert(pool, it.id)
		end
	end
	local id = pool[math.clamp(math.floor(r2 * #pool) + 1, 1, #pool)]
	return id, id ~= nil and owned[id] ~= nil and owned[id] ~= false
end

--- Stars a duplicate of item `id` pays (its rarity's: Cosmetics.DUPLICATE_STARS); 0 for anything that
--- is not a crate item.
function Cosmetics.duplicate_stars(id: any): number
	local it = Cosmetics.item(id)
	if it == nil or it.exclusive or it.shop or it.general or it.season then
		return 0
	end
	return Cosmetics.DUPLICATE_STARS[it.rarity] or 0
end

--- The colour number of mask character `ch`: 0 for the owner's own fill ('.' or anything unknown), 1 for
--- '#' (a two-tone skin's secondary), '1'..'9' -> 1..9 and 'a'..'z' -> 10..35 (a skin's `colors`).
local function mask_key(ch: string): number
	if ch == "#" then
		return 1
	end
	local b = string.byte(ch)
	if b >= 49 and b <= 57 then -- '1'..'9'
		return b - 48
	elseif b >= 97 and b <= 122 then -- 'a'..'z'
		return b - 87
	end
	return 0
end

--- A skin's mask as a buffer of w * h bytes for MapSurface: 0 = the owner's fill, 1 = a two-tone skin's
--- secondary, or k = colors[k] of a skin with `colors`.
function Cosmetics.mask(skin: any): (buffer, number, number)
	local rows = skin.mask
	local h = #rows
	local w = 0
	for _, row in rows do
		w = math.max(w, #row)
	end
	local b = buffer.create(w * h)
	for y, row in rows do
		for x = 1, #row do
			buffer.writeu8(b, (y - 1) * w + (x - 1), mask_key(string.sub(row, x, x)))
		end
	end
	return b, w, h
end

--- colors[k] of a skin with several colours as (r, g, b) floats (nil past its list, or a two-tone skin).
function Cosmetics.color(skin: any, k: number): (number?, number?, number?)
	local list = skin.colors
	local c = if type(list) == "table" then list[k] else nil
	if type(c) ~= "number" then
		return nil, nil, nil
	end
	return ((c // 65536) % 256) / 255, ((c // 256) % 256) / 255, (c % 256) / 255
end

--- The alpha (0..255) a skin's own colours are drawn at.
function Cosmetics.skin_alpha(skin: any): number
	return if type(skin.alpha) == "number" then skin.alpha else Cosmetics.SECONDARY_ALPHA
end

--- The secondary colour (r, g, b floats) of `skin` over a territory of colour (r, g, b).
function Cosmetics.secondary(skin: any, r: number, g: number, b: number): (number, number, number)
	local a = skin.accent
	if type(a) == "number" then
		return ((a // 65536) % 256) / 255, ((a // 256) % 256) / 255, (a % 256) / 255
	end
	local t = tonumber(skin.tone) or -0.2
	if t >= 0 then
		return r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t
	end
	return r * (1 + t), g * (1 + t), b * (1 + t)
end

return Cosmetics
