--!nocheck
-- Cosmetics (Data/Cosmetics): the catalog, the player's odds, crate rolls (never a duplicate, rarity
-- shares follow the published odds), and a territory skin in MapSurface.tile_pixel.
require("./prelude")
-- (the owner's own skins and flags, Data/MySkins and Data/MyFlags: read once, when Cosmetics loads.
-- Three good ones and four bad ones are added first, as the owner would write them)
local MySkins = require("../src/shared/Data/MySkins")
local MyFlags = require("../src/shared/Data/MyFlags")
local MyShop = require("../src/shared/Data/MyShop")
local n_my_skins, n_my_flags = #MySkins, #MyFlags
table.insert(MySkins, { id = "t_cruz", nome = "Cruz", raridade = "raro", escala = 1, tom = -0.3, desenho = { ".#.", "###", ".#." } })
table.insert(MySkins, { id = "t_brasa", nome = "Brasa", raridade = "epico", cores = { 0xB22222, 0xE0B030 }, desenho = { "1..2", ".12." } })
table.insert(MySkins, { id = "t torta", nome = "Id com espaço", desenho = { "#." } })
table.insert(MySkins, { id = "t_torta", nome = "Linhas diferentes", desenho = { "#.", "#" } })
table.insert(MySkins, { id = "stripes", nome = "Id repetido", desenho = { "#." } })
table.insert(MyFlags, { id = "t_leao", nome = "Leão", raridade = "lendario", cores = { a = 0xB22222, o = 0xE0B030 }, desenho = { "aaoaa", "aoooa", "aaoaa" } })
table.insert(MyFlags, { id = "t_foto", nome = "Foto", raridade = "comum", imagem = "123456" })
table.insert(MyFlags, { id = "t_vazia", nome = "Sem desenho" })
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Flags = require("../src/shared/Assets/Flags")
local Pets = require("../src/shared/Assets/Pets")
local OwnArt = require("../src/shared/Assets/OwnArt")
local MapSurface = require("../src/client/Map/MapSurface")

local fails = 0
local function expect(c: any, w: string)
	if c then
		print("  ok   " .. w)
	else
		fails += 1
		print("FAIL " .. w)
	end
end

-- catalog
local ids, skins, flags, pets = {}, 0, 0, 0
local dup = false
local rare_ok = true
for _, it in Cosmetics.all() do
	if ids[it.id] then
		dup = true
	end
	ids[it.id] = true
	if it.kind == "skin" then
		skins += 1
		local w = #it.mask[1]
		for _, row in it.mask do
			if #row ~= w or string.find(row, if it.colors ~= nil then "[^%w.]" else "[^#.]") then
				print("  bad mask row in " .. it.id .. ": " .. row)
				rare_ok = false
			end
		end
		if it.tone == nil and it.accent == nil and it.colors == nil then
			rare_ok = false
		end
	elseif it.kind == "flag" then
		flags += 1
		if not (it.w > 0 and it.h > 0 and Cosmetics.flag_image(it) ~= nil) then
			rare_ok = false
		end
	else
		pets += 1
		local img, x, y, w, h = Cosmetics.image_of(it)
		if not (it.kind == "pet" and img == Pets.image and w == 96 and h == 96 and x >= 0 and y >= 0) then
			rare_ok = false
		end
	end
	local known = false
	for _, r in Cosmetics.RARITIES do
		known = known or r.id == it.rarity
	end
	rare_ok = rare_ok and known
end
expect(not dup, "item ids are unique")
expect(rare_ok, "masks rectangular, every skin coloured, every flag has an image rect, rarities known")
expect(
	skins == #Cosmetics.skins + n_my_skins + 2 and flags == #Flags.flags + n_my_flags + 2 and pets == #Pets.pets,
	string.format("%d skins, %d flags, %d pets", skins, flags, pets)
)
-- (2026-11-12: 32 banners, 9 pets and 15 skins more; the skins are the owner's file's, Data/MySkins)
expect(#Flags.flags == 80 and #Pets.pets == 24, "80 banners and 24 pets of this game's own")
expect(n_my_skins == 15, "15 skins shipped in Data/MySkins")
expect(Cosmetics.item("flag_br") == nil and Cosmetics.item("flag_us") == nil, "no country flag is left")
expect(#Cosmetics.shop_items() == 0, "... nor the old shop's flags")
for _, kind in Cosmetics.KINDS do
	local per = {}
	for _, it in Cosmetics.of_kind(kind) do
		per[it.rarity] = (per[it.rarity] or 0) + 1
	end
	local every = true
	for _, r in Cosmetics.RARITIES do
		every = every and (per[r.id] or 0) >= 2
	end
	expect(every, kind .. ": at least two items of every rarity")
end

-- the owner's own items
do
	local cruz, brasa = Cosmetics.item("t_cruz"), Cosmetics.item("t_brasa")
	expect(
		cruz ~= nil and cruz.kind == "skin" and cruz.rarity == "rare" and cruz.tone == -0.3 and cruz.scale == 1,
		"MySkins: a two-tone skin, its rarity read from Portuguese"
	)
	expect(
		brasa ~= nil and brasa.rarity == "epic" and #brasa.colors == 2 and brasa.scale == 1,
		"MySkins: a skin of fixed colours"
	)
	local mask, w, h = Cosmetics.mask(brasa)
	expect(w == 4 and h == 2 and buffer.readu8(mask, 0) == 1 and buffer.readu8(mask, 3) == 2, "... its drawing")
	expect(Cosmetics.item("t torta") == nil and Cosmetics.item("t_torta") == nil, "MySkins: bad ids and ragged drawings are left out")
	expect(Cosmetics.item("stripes").name == "Stripes", "MySkins: an id already taken does not replace the game's skin")
	local leao, foto = Cosmetics.item("flag_my_t_leao"), Cosmetics.item("flag_my_t_foto")
	expect(leao ~= nil and leao.kind == "flag" and leao.rarity == "legendary", "MyFlags: a flag drawn in letters")
	local key = OwnArt.key_for(Cosmetics.flag_image(leao))
	expect(key == "myflag/t_leao", "... is an image painted by the game")
	local pw, ph = OwnArt.size(key)
	local px = OwnArt.pixels(key)
	expect(pw == leao.w and ph == leao.h and pw == 110 and ph == 66 and buffer.len(px) == pw * ph * 4, "... 5x3 letters as 110x66 pixels")
	-- (bytes R, G, B, A) the first letter "a" is 0xB22222, the middle "o" 0xE0B030
	local function rgb(x: number, y: number): number
		local o = (y * pw + x) * 4
		return buffer.readu8(px, o) * 65536 + buffer.readu8(px, o + 1) * 256 + buffer.readu8(px, o + 2)
	end
	expect(rgb(0, 0) == 0xB22222 and rgb(pw // 2, ph // 2) == 0xE0B030 and buffer.readu8(px, 3) == 255, "... in its colours")
	expect(
		foto ~= nil and Cosmetics.flag_image(foto) == "rbxassetid://123456" and foto.rarity == "common" and foto.w > 0,
		"MyFlags: a flag from an uploaded image"
	)
	expect(Cosmetics.item("flag_my_t_vazia") == nil, "MyFlags: a flag with nothing to show is left out")
end

local sum = 0
for _, r in Cosmetics.RARITIES do
	sum += r.odds
end
expect(math.abs(sum - 1) < 1e-9, "published odds sum to 100%")
do
	local c = MyShop.caixa.chances
	local by = {}
	for _, r in Cosmetics.RARITIES do
		by[r.id] = r.odds
	end
	local t = c.comum + c.raro + c.epico + c.lendario
	expect(
		math.abs(by.common - c.comum / t) < 1e-9
			and math.abs(by.rare - c.raro / t) < 1e-9
			and math.abs(by.epic - c.epico / t) < 1e-9
			and math.abs(by.legendary - c.lendario / t) < 1e-9,
		"they are the owner's numbers (Data/MyShop.caixa.chances)"
	)
	expect(
		c.comum == 80 and c.raro == 15 and c.epico == 4.5 and c.lendario == 0.5,
		"as shipped: Common 80%, Rare 15%, Epic 4.5%, Legendary 0.5%"
	)
end

-- The catalog grew on 2026-11-12 (84 -> 140 items). What players already own is saved by id: every
-- item of before must still be there, of the same kind and rarity.
do
	local R = { c = "common", r = "rare", e = "epic", l = "legendary" }
	local OLD = {
		flag_c01 = "c", flag_c02 = "c", flag_c03 = "c", flag_c04 = "c", flag_c05 = "c", flag_c06 = "c",
		flag_c07 = "c", flag_c08 = "c", flag_c09 = "c", flag_c10 = "c", flag_c11 = "c", flag_c12 = "c",
		flag_c13 = "c", flag_c14 = "c", flag_c15 = "c", flag_c16 = "c", flag_c17 = "c", flag_c18 = "c",
		flag_c19 = "c", flag_c20 = "c", flag_c21 = "c", flag_c22 = "c", flag_c23 = "c", flag_c24 = "c",
		flag_r01 = "r", flag_r02 = "r", flag_r03 = "r", flag_r04 = "r", flag_r05 = "r", flag_r06 = "r",
		flag_r07 = "r", flag_r08 = "r", flag_r09 = "r", flag_r10 = "r", flag_r11 = "r", flag_r12 = "r",
		flag_r13 = "r", flag_r14 = "r", flag_e01 = "e", flag_e02 = "e", flag_e03 = "e", flag_e04 = "e",
		flag_e05 = "e", flag_e06 = "e", flag_e07 = "e", flag_l01 = "l", flag_l02 = "l", flag_l03 = "l",
		pet_gato = "c", pet_gato_preto = "c", pet_coruja = "c", pet_corvo = "c", pet_raposa = "c",
		pet_lobo = "r", pet_lobo_negro = "r", pet_falcao = "r", pet_coruja_neves = "r",
		pet_raposa_artica = "r", pet_grifo = "e", pet_unicornio = "e", pet_grifo_sombrio = "e",
		pet_dragao = "l", pet_dragao_gelo = "l",
		-- (RoWorld's 21 skins)
		stripes = "c", bands = "c", checker = "c", diagonal = "c", dots = "c", grid = "c",
		bricks = "r", waves = "r", diamonds = "r", crosshatch = "r", zigzag = "r", cobble = "r",
		stars = "e", camo = "e", circuit = "e", hex = "e", tartan = "e",
		gilded = "l", frost = "l", obsidian = "l", ember = "l",
	}
	local n_old, gone = 0, nil
	for id, r in OLD do
		n_old += 1
		local it = Cosmetics.item(id)
		local kind = if string.sub(id, 1, 5) == "flag_" then "flag" elseif string.sub(id, 1, 4) == "pet_" then "pet" else "skin"
		if it == nil or it.rarity ~= R[r] or it.kind ~= kind then
			gone = id
		end
	end
	expect(n_old == 84 and gone == nil, "the 84 items of before 2026-11-12 are all still there, same kind and rarity (" .. tostring(gone) .. ")")
	-- the shipped catalog, without this test's own additions (ids t_...)
	local cnt = { skin = {}, flag = {}, pet = {} }
	local total = 0
	for _, it in Cosmetics.all() do
		if string.find(it.id, "t_", 1, true) ~= 1 and string.find(it.id, "flag_my_t_", 1, true) ~= 1 then
			cnt[it.kind][it.rarity] = (cnt[it.kind][it.rarity] or 0) + 1
			total += 1
		end
	end
	local function is(kind: string, c: number, r: number, e: number, l: number): boolean
		local k = cnt[kind]
		return k.common == c and k.rare == r and k.epic == e and k.legendary == l
	end
	expect(total == 140, "140 items in the crates' catalog (" .. total .. ")")
	expect(is("skin", 10, 11, 9, 6), "36 skins: 10 Common, 11 Rare, 9 Epic, 6 Legendary")
	expect(is("flag", 38, 24, 13, 5), "80 flags: 38 Common, 24 Rare, 13 Epic, 5 Legendary")
	expect(is("pet", 8, 8, 5, 3), "24 pets: 8 Common, 8 Rare, 5 Epic, 3 Legendary")
	-- a few of the new ones, by id
	local NEW = {
		pontilhado = "common", escamas = "rare", vitral = "epic", manto_real = "legendary", esmeralda = "legendary",
		flag_c38 = "common", flag_r24 = "rare", flag_e13 = "epic", flag_l05 = "legendary",
		pet_gato_branco = "common", pet_lobo_branco = "rare", pet_grifo_esmeralda = "epic", pet_dragao_esmeralda = "legendary",
	}
	local missing = nil
	for id, r in NEW do
		local it = Cosmetics.item(id)
		if it == nil or it.rarity ~= r or it.season ~= nil or it.exclusive then
			missing = id
		end
	end
	expect(missing == nil, "the new items are in the catalog with their rarities (" .. tostring(missing) .. ")")
	-- the two sheets the game draws them from fit a Roblox image (1024 a side), and no two items
	-- share a place in them
	local function sheet_ok(list: { any }): boolean
		local seen, ok = {}, true
		for _, f in list do
			local key = f.x .. ":" .. f.y
			ok = ok and seen[key] == nil and f.x >= 0 and f.y >= 0 and f.x + f.w <= 1024 and f.y + f.h <= 1024
			seen[key] = true
		end
		return ok
	end
	expect(sheet_ok(Flags.flags) and sheet_ok(Pets.pets), "every banner and pet has its own place, inside a 1024 x 1024 sheet")
	local Data = require("../src/shared/Assets/OwnArtData")
	local fa, pa = Data.images["flags/atlas"], Data.images["pets/atlas"]
	expect(fa.w <= 1024 and fa.h <= 1024 and pa.w <= 1024 and pa.h <= 1024, string.format("the sheets themselves: %dx%d and %dx%d", fa.w, fa.h, pa.w, pa.h))
	local inside = true
	for _, f in Flags.flags do
		inside = inside and f.x + f.w <= fa.w and f.y + f.h <= fa.h
	end
	for _, f in Pets.pets do
		inside = inside and f.x + f.w <= pa.w and f.y + f.h <= pa.h
	end
	for _, it in Cosmetics.seasonals() do
		if it.kind == "flag" then
			inside = inside and it.x + it.w <= fa.w and it.y + it.h <= fa.h
		elseif it.kind == "pet" then
			inside = inside and it.x + it.w <= pa.w and it.y + it.h <= pa.h
		end
	end
	expect(inside, "... and every banner and pet (the pass's too) lies inside its sheet")
end

-- A crate may give a duplicate (Data/MyShop.caixa.repetidos; 2026-11-12), which pays Coroas. The
-- shipped setting is checked first; then the game's two ways are tested one after the other.
do
	local cx = MyShop.caixa
	expect(cx.repetidos == true and Cosmetics.DUPLICATES == true, "as shipped: a crate may give a duplicate")
	local b = cx.coroas_repetido
	expect(
		b.comum == 2500 and b.raro == 6000 and b.epico == 12000 and b.lendario == 25000,
		"as shipped: a duplicate pays 2,500 / 6,000 / 12,000 / 25,000 Coroas"
	)
	local D = Cosmetics.DUPLICATE_STARS
	expect(
		D.common == 2500 and D.rare == 6000 and D.epic == 12000 and D.legendary == 25000,
		"... and the game reads those four numbers"
	)
	local capped = true
	for _, r in Cosmetics.RARITIES do
		capped = capped and D[r.id] <= cx.coroas
	end
	expect(capped, "no duplicate pays more than a crate costs in Coroas")
end

-- ===== WITH duplicates (the shipped way) =====
do
	Cosmetics.DUPLICATES = true
	math.randomseed(11)
	-- the odds are the published ones whatever the player owns
	local leg = {}
	for _, it in Cosmetics.all() do
		if it.rarity == "legendary" then
			leg[it.id] = true
		end
	end
	local same = true
	for i, e in Cosmetics.odds(leg) do
		same = same and math.abs(e.odds - Cosmetics.RARITIES[i].odds) < 1e-9
		if e.rarity.id == "legendary" then
			same = same and e.left == 0
		end
	end
	expect(same, "duplicates: every legendary owned, the odds stay the published ones (legendary: 0 left)")
	for _, kind in Cosmetics.KINDS do
		local list = Cosmetics.of_kind(kind)
		-- a player who owns half of the kind: rolls give both new items and duplicates, of that kind only
		local own = {}
		for i, it in list do
			if i % 2 == 0 then
				own[it.id] = true
			end
		end
		local n_new, n_dup, wrong_kind, wrong_flag, paid_bad = 0, 0, 0, 0, 0
		local cnt, seen = {}, {}
		local N = 40000
		for _ = 1, N do
			local id, dup = Cosmetics.roll(own, math.random(), math.random(), kind)
			local it = Cosmetics.item(id)
			if it == nil or it.kind ~= kind then
				wrong_kind += 1
			else
				cnt[it.rarity] = (cnt[it.rarity] or 0) + 1
				seen[id] = true
				if dup ~= (own[id] == true) then
					wrong_flag += 1
				end
				if dup then
					n_dup += 1
				else
					n_new += 1
				end
				if Cosmetics.duplicate_stars(id) ~= Cosmetics.DUPLICATE_STARS[it.rarity] then
					paid_bad += 1
				end
			end
		end
		expect(wrong_kind == 0, "duplicates: a " .. kind .. " crate only gives a " .. kind)
		expect(wrong_flag == 0, "... and says 'duplicate' exactly when the player had the item")
		expect(n_new > 0 and n_dup > 0, string.format("... %d new, %d duplicates in %d crates (half owned)", n_new, n_dup, N))
		expect(paid_bad == 0, "... a duplicate's Coroas are its rarity's")
		local near = true
		for _, r in Cosmetics.RARITIES do
			near = near and math.abs((cnt[r.id] or 0) / N - r.odds) <= 0.012
		end
		expect(near, "... rarities come at the published odds, owned or not")
		local every = true
		for _, it in list do
			every = every and seen[it.id] == true
		end
		expect(every, "... and every " .. kind .. " of the catalog can come out")
		-- a player who owns the whole kind: nothing to roll (the crate is not sold)
		local all = {}
		for _, it in list do
			all[it.id] = true
		end
		local id, dup = Cosmetics.roll(all, 0.5, 0.5, kind)
		expect(id == nil and dup == false, "duplicates: every " .. kind .. " owned, no roll")
		-- one item missing: it still comes, sooner or later
		local last = list[#list]
		all[last.id] = nil
		local got_last, tries = false, 0
		while not got_last and tries < 200000 do
			tries += 1
			local rid, rdup = Cosmetics.roll(all, math.random(), math.random(), kind)
			got_last = rid == last.id and rdup == false
		end
		expect(got_last, string.format("... one %s missing (%s): it came after %d crates", kind, last.rarity, tries))
	end
	expect(Cosmetics.duplicate_stars("nope") == 0 and Cosmetics.duplicate_stars(nil) == 0, "an unknown item pays nothing as a duplicate")
	local pass_pays = 0
	for _, it in Cosmetics.seasonals() do
		pass_pays += Cosmetics.duplicate_stars(it.id)
	end
	expect(pass_pays == 0, "a pass item is not a crate item: no duplicate Coroas for it")
end

-- ===== WITHOUT duplicates (Data/MyShop.caixa.repetidos = false: how it was until 2026-11-12) =====
Cosmetics.DUPLICATES = false
-- the player's odds: rarities with nothing left drop out
local owned = {}
for _, it in Cosmetics.all() do
	if it.rarity == "legendary" then
		owned[it.id] = true
	end
end
local o = Cosmetics.odds(owned)
local total = 0
for _, e in o do
	total += e.odds
	if e.rarity.id == "legendary" then
		expect(e.odds == 0 and e.left == 0, "every legendary owned: 0% legendary")
	end
end
expect(math.abs(total - 1) < 1e-9, "the rest scale up to 100% (" .. total .. ")")

-- rolls: never a duplicate until everything is owned; shares follow the odds
math.randomseed(5)
local mine = {}
local n_items = #Cosmetics.all()
local first_dupe = false
for k = 1, n_items do
	local id = Cosmetics.roll(mine, math.random(), math.random())
	if id == nil or mine[id] then
		first_dupe = true
		break
	end
	mine[id] = true
end
expect(not first_dupe, n_items .. " crates: " .. n_items .. " different items")
expect(Cosmetics.roll(mine, 0.5, 0.5) == nil, "everything owned: nothing to roll")
local counts = {}
local N = 40000
for _ = 1, N do
	local id = Cosmetics.roll({}, math.random(), math.random())
	local r = Cosmetics.item(id).rarity
	counts[r] = (counts[r] or 0) + 1
end
local close = true
for _, r in Cosmetics.RARITIES do
	local share = (counts[r.id] or 0) / N
	if math.abs(share - r.odds) > 0.01 then
		close = false
	end
	print(string.format("       %-9s %.1f%% (published %.1f%%)", r.name, share * 100, r.odds * 100))
end
expect(close, "rolled rarity shares match the published odds (±1%)")

-- a crate of one kind (the Coleção's tabs): only that kind, its own odds, never a duplicate
for _, kind in Cosmetics.KINDS do
	local list = Cosmetics.of_kind(kind)
	local got = {}
	local bad = false
	for _ = 1, #list do
		local id = Cosmetics.roll(got, math.random(), math.random(), kind)
		if id == nil or got[id] or Cosmetics.item(id).kind ~= kind then
			bad = true
			break
		end
		got[id] = true
	end
	expect(not bad, string.format("%d %s crates: %d different %ss", #list, kind, #list, kind))
	expect(Cosmetics.roll(got, 0.5, 0.5, kind) == nil, "every " .. kind .. " owned: nothing left in that crate")
	expect(Cosmetics.crate_owned(got, kind) == #list and Cosmetics.crate_owned(got) == #list, "... counted by kind")
	local ko = Cosmetics.odds({}, kind)
	local same = #ko == #Cosmetics.RARITIES
	for i, e in ko do
		same = same and math.abs(e.odds - Cosmetics.RARITIES[i].odds) < 1e-9 and e.left > 0
	end
	expect(same, "the " .. kind .. " crate starts at the published odds")
	local cnt = {}
	for _ = 1, 20000 do
		local r = Cosmetics.item(Cosmetics.roll({}, math.random(), math.random(), kind)).rarity
		cnt[r] = (cnt[r] or 0) + 1
	end
	local near = true
	for _, r in Cosmetics.RARITIES do
		near = near and math.abs((cnt[r.id] or 0) / 20000 - r.odds) <= 0.012
	end
	expect(near, "... and rolls by them")
end
expect(#Cosmetics.of_kind("hat") == 0 and Cosmetics.roll({}, 0.5, 0.5, "hat") == nil, "an unknown kind has no crate")
Cosmetics.DUPLICATES = true
expect(Cosmetics.roll({}, 0.5, 0.5, "hat") == nil, "... with duplicates too")

-- MapSurface: a skinned owner's tiles alternate primary / secondary as its mask says
do
	local W, H = 8, 4
	local own = buffer.create(W * H * 4)
	for i = 0, W * H - 1 do
		buffer.writei32(own, i * 4, 3)
	end
	local surf = setmetatable({
		W = W,
		N = W * H,
		_own = own,
		_flags = buffer.create(W * H),
		defended = buffer.create(W * H),
		pal_fill = buffer.create(64 * 4),
		pal_fill_hi = buffer.create(64 * 4),
		hover = 0,
		_skins = {},
		_state = { cosmetics = { [3] = { skin = "stripes" } }, are_allies = function()
			return false
		end },
	}, MapSurface)
	buffer.writeu32(surf.pal_fill, 3 * 4, 0x96112233)
	surf:_load_skins(nil)
	local sk = surf._skins[3]
	sk.fill2 = 0xBE445566
	-- interior row 1 (row 0 and the edges are border tiles): stripes "##.." at scale 1 = tiles 0-3 on, 4-7 off
	local got = {}
	for x = 1, 6 do
		table.insert(got, if surf:tile_pixel(1 * W + x) == sk.fill2 then "#" else ".")
	end
	expect(table.concat(got) == "###...", "stripes at scale 1 on row 1, x 1..6: " .. table.concat(got))
	surf._state.cosmetics[3] = nil
	surf:_load_skins({ 3 })
	expect(surf._skins[3] == nil and surf:tile_pixel(W + 1) == 0x96112233, "unequipped: the plain fill")
end

-- Exclusive skins (Cosmetics.exclusive_skins; 2026-10-18, a skin made for one player): their owners only,
-- never in a crate, several colours
do
	local DONA = 4242001
	-- (2026-11-12: the game ships none: the original's was made for one of its own players. The
	-- machinery stays, tested with a skin of this test's own.)
	expect(#Cosmetics.exclusives() == 0 and #Cosmetics.exclusive_skins == 0, "the game ships no exclusive skin")
	Cosmetics.add_exclusive({
		id = "so_dela",
		name = "Só Dela",
		owners = { 4242001 },
		scale = 0,
		alpha = 166,
		colors = { 0xD45881, 0xDA846A, 0x7FA88C },
		mask = { "1.23", "21.3", "3.12", "123." },
	})
	local td = Cosmetics.item("so_dela")
	expect(td ~= nil and td.kind == "skin" and td.exclusive == true and td.rarity == "exclusive", "so_dela resolves")
	local in_all = false
	for _, it in Cosmetics.all() do
		in_all = in_all or it.exclusive == true or it.id == "so_dela"
	end
	expect(not in_all, "no exclusive in the crate catalog (Cosmetics.all)")
	expect(Cosmetics.rarity("exclusive").name == "Exclusive", "the Exclusive label")
	local g = Cosmetics.granted(DONA)
	expect(#g == 1 and g[1] == "so_dela", "the owner's user id is granted so_dela")
	expect(#Cosmetics.granted(1) == 0 and #Cosmetics.granted(nil) == 0, "nobody else is granted anything")
	expect(Cosmetics.may_own("so_dela", DONA) and not Cosmetics.may_own("so_dela", 1), "may_own: its owner only")
	expect(Cosmetics.may_own("stripes", 1) and Cosmetics.may_own("stripes", nil), "may_own: crate items for anyone")
	expect(not Cosmetics.may_own("nope", DONA), "may_own: unknown ids for nobody")
	expect(Cosmetics.crate_owned({ so_dela = true, stripes = true }) == 1, "crate_owned leaves exclusives out")
	-- a player owning every crate item still has nothing to roll (the exclusive is not in crates)
	local all = {}
	for _, it in Cosmetics.all() do
		all[it.id] = true
	end
	expect(Cosmetics.roll(all, 0.5, 0.5) == nil, "everything in crates owned: no roll, though so_dela is not")
	local exids = {}
	for _, it in Cosmetics.all() do
		exids[it.id] = true
	end
	local ok = true
	for _, it in Cosmetics.exclusives() do
		if exids[it.id] then
			ok = false
		end
		exids[it.id] = true
		local mask, w, h = Cosmetics.mask(it)
		for _, row in it.mask do
			ok = ok and #row == w
		end
		for i = 0, w * h - 1 do
			local k = buffer.readu8(mask, i)
			ok = ok and (k == 0 or (k <= #it.colors and Cosmetics.color(it, k) ~= nil))
		end
		for _, c in it.colors do
			ok = ok and type(c) == "number" and c >= 0 and c <= 0xFFFFFF
		end
		local a = Cosmetics.skin_alpha(it)
		ok = ok and a > 0 and a <= 255 and w >= 1 and h >= 1 and w <= 64 and h <= 64
	end
	expect(ok, "exclusive masks rectangular, every key has a colour, ids unique across the catalog")

	-- MapSurface: each tile takes its mask key's colour; '.' keeps the owner's fill
	local W, H = 10, 6
	local own = buffer.create(W * H * 4)
	for i = 0, W * H - 1 do
		buffer.writei32(own, i * 4, 3)
	end
	local surf = setmetatable({
		W = W,
		N = W * H,
		_own = own,
		_flags = buffer.create(W * H),
		defended = buffer.create(W * H),
		pal_fill = buffer.create(64 * 4),
		pal_fill_hi = buffer.create(64 * 4),
		hover = 0,
		_skins = {},
		_state = { cosmetics = { [3] = { skin = "so_dela" } }, are_allies = function()
			return false
		end },
	}, MapSurface)
	buffer.writeu32(surf.pal_fill, 3 * 4, 0x96112233)
	surf:_load_skins(nil)
	local sk = surf._skins[3]
	expect(sk ~= nil and sk.fills ~= nil, "so_dela loads with a colour list")
	for k = 1, #td.colors do
		sk.fills[k] = 0xC8000000 + k
	end
	local mask, mw, mh = Cosmetics.mask(td)
	local match = true
	for y = 1, H - 2 do
		for x = 1, W - 2 do
			local k = buffer.readu8(mask, (bit32.rshift(y, td.scale) % mh) * mw + bit32.rshift(x, td.scale) % mw)
			local want = if k == 0 then 0x96112233 else 0xC8000000 + k
			match = match and surf:tile_pixel(y * W + x) == want
		end
	end
	expect(match, "so_dela interior tiles: colors[mask key], the owner's fill for '.'")
end

if fails > 0 then
	error(fails .. " failures")
end
print("cosmetics: all passed")
