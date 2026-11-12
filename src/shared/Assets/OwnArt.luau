--!strict
--!native
-- This game's own icons, in place of RoWorld's images: the interface's glyphs, the Arsenal's, the map's
-- structure plates and glyphs, the unit sprites, the status icons over the names, the logo and the
-- world's picture. An image can only be uploaded to Roblox by the account that owns the game, so every
-- one of them is kept in the code (Assets/OwnArtData, written by tools/arte/make_own_art.py) and the
-- client draws it into an EditableImage wherever RoWorld's image would be shown (client/UI/ArtSweep).
-- The same drawings are in assets/icones as PNG; Assets/OwnArtIds takes the ids of the ones the owner
-- uploaded. tests/own_art.luau.
--
--   OwnArt.key_for(asset_id)   -> the key of the image that takes the place of RoWorld's `asset_id`
--   OwnArt.size(key)           -> width, height
--   OwnArt.uploaded(key)       -> the owner's own asset id for it, when Assets/OwnArtIds has one
--   OwnArt.pixels(key)         -> buffer of width * height * 4 bytes (R, G, B, A, rows from the top)
--   OwnArt.keys()              -> every key, sorted
--   OwnArt.register(name, key, w, h, paint)   an image painted by code (Data/MyFlags' drawings)
local IS_ROBLOX = typeof(game) == "Instance"

local function load(name: string): any
	if IS_ROBLOX then
		local m = (script :: any).Parent:FindFirstChild(name)
		return if m ~= nil then require(m) :: any else nil
	end
	return (require :: any)("./" .. name)
end

local MapCodec: any = if IS_ROBLOX
	then require((script :: any).Parent.Parent.Core.MapCodec)
	else (require :: any)("../Core/MapCodec")

local Data: any = load("OwnArtData") or { replaces = {}, images = {} }
local Ids: any = {}
do
	local ok, ids = pcall(load, "OwnArtIds")
	if ok and type(ids) == "table" then
		Ids = ids
	end
end

local OwnArt = {}

--- Images painted by code at run time (the owner's own flags drawn with letters: Data/MyFlags):
--- name -> key, key -> { w, h, paint }.
local dyn_ids: { [string]: string } = {}
local dyn: { [string]: { w: number, h: number, paint: () -> buffer } } = {}

--- An image that exists only in the code: wherever `name` (any string that is not a Roblox image,
--- "rbxasset://own/...") is given to an ImageLabel, the client shows `paint()`'s pixels (w * h * 4
--- bytes: R, G, B, A, rows from the top).
function OwnArt.register(name: string, key: string, w: number, h: number, paint: () -> buffer)
	dyn_ids[name] = key
	dyn[key] = { w = w, h = h, paint = paint }
end

function OwnArt.key_for(asset_id: string): string?
	return Data.replaces[asset_id] or dyn_ids[asset_id]
end

function OwnArt.size(key: string): (number, number)
	local e = Data.images[key] or dyn[key]
	if e == nil then
		return 0, 0
	end
	return e.w, e.h
end

function OwnArt.uploaded(key: string): string?
	local id = Ids[key]
	if type(id) == "number" and id > 0 then
		return "rbxassetid://" .. tostring(id)
	end
	if type(id) == "string" and id ~= "" then
		return if string.match(id, "^%d+$") ~= nil then "rbxassetid://" .. id else id
	end
	return nil
end

function OwnArt.keys(): { string }
	local out = {}
	for k in Data.images do
		table.insert(out, k)
	end
	table.sort(out)
	return out
end

--- Every RoWorld asset id that has an image of this game's in its place -> its key.
function OwnArt.replaces(): { [string]: string }
	return Data.replaces
end

function OwnArt.pixels(key: string): buffer?
	local d = dyn[key]
	if d ~= nil then
		return d.paint()
	end
	local e = Data.images[key]
	if e == nil then
		return nil
	end
	local n: number = e.w * e.h
	local raw: buffer = MapCodec.zstd_decompress(MapCodec.b64decode(e.data))
	local out = buffer.create(n * 4)
	local readu8, readu32, writeu32 = buffer.readu8, buffer.readu32, buffer.writeu32
	if e.mode == "a" then
		assert(buffer.len(raw) == n, "OwnArt: " .. key .. ": size")
		for i = 0, n - 1 do
			-- white, with the pixel's alpha (the bytes are R, G, B, A: A is the high byte)
			writeu32(out, i * 4, 0x00FFFFFF + readu8(raw, i) * 0x1000000)
		end
	else
		local colors: number = e.colors
		assert(buffer.len(raw) == colors * 4 + n, "OwnArt: " .. key .. ": size")
		local base = colors * 4
		for i = 0, n - 1 do
			writeu32(out, i * 4, readu32(raw, readu8(raw, base + i) * 4))
		end
	end
	return out
end

return OwnArt
