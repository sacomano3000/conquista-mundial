--!strict
-- This version's own pictures of the Arsenal's items (the list's tiles and the preview's sticker), in
-- place of RoWorld's renders (Assets/ArsenalArt.renders). They live in the code, not on Roblox: an image
-- can only be uploaded by the account that owns the game, so each picture is kept as a palette and one
-- byte per pixel (Assets/ArsenalIcon_<item>), and client/UI/Arsenal draws it into an EditableImage.
-- The drawings are in assets/arsenal-icons. tests/arsenal_icons.luau.
--
--   ArsenalIcons.SIZE            the pictures are SIZE x SIZE pixels
--   ArsenalIcons.KEYS            the Data/Arsenal items that have one
--   ArsenalIcons.pixels(key)     -> buffer of SIZE * SIZE * 4 bytes (R, G, B, A per pixel, rows from the
--                                top), or nil when the item has no picture
local IS_ROBLOX = typeof(game) == "Instance"

local ArsenalIcons = {}

ArsenalIcons.SIZE = 128
ArsenalIcons.KEYS = { "mega", "scatter", "reinforce", "artillery", "airfield", "railgun", "stars2x", "reload2x" }

local HAS: { [string]: boolean } = {}
for _, k in ArsenalIcons.KEYS do
	HAS[k] = true
end

local B64: { [number]: number } = {}
do
	local letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, #letters do
		B64[string.byte(letters, i)] = i - 1
	end
end

--- The bytes a base64 text stands for.
local function decode(s: string): buffer
	local n = #s
	local pad = if string.sub(s, -2) == "==" then 2 elseif string.sub(s, -1) == "=" then 1 else 0
	local len = (n // 4) * 3 - pad
	local out = buffer.create(len)
	local o = 0
	for i = 1, n, 4 do
		local a, b, c, d = string.byte(s, i, i + 3)
		local v = (B64[a] or 0) * 262144 + (B64[b] or 0) * 4096 + (B64[c] or 0) * 64 + (B64[d] or 0)
		if o < len then
			buffer.writeu8(out, o, v // 65536)
		end
		if o + 1 < len then
			buffer.writeu8(out, o + 1, (v // 256) % 256)
		end
		if o + 2 < len then
			buffer.writeu8(out, o + 2, v % 256)
		end
		o += 3
	end
	return out
end

local function data_of(key: string): any
	if IS_ROBLOX then
		local m = (script :: any).Parent:FindFirstChild("ArsenalIcon_" .. key)
		return if m ~= nil then require(m) :: any else nil
	end
	return (require :: any)("./ArsenalIcon_" .. key)
end

--- The picture of Data/Arsenal item `key` as RGBA bytes, or nil when it has none (or its data is not
--- what it should be).
function ArsenalIcons.pixels(key: string): buffer?
	if not HAS[key] then
		return nil
	end
	local d = data_of(key)
	if type(d) ~= "table" or type(d.data) ~= "string" or type(d.colors) ~= "number" then
		return nil
	end
	local n = ArsenalIcons.SIZE * ArsenalIcons.SIZE
	local raw = decode(d.data)
	local colors: number = d.colors
	if colors < 1 or colors > 256 or buffer.len(raw) ~= colors * 4 + n then
		return nil
	end
	local out = buffer.create(n * 4)
	local at = colors * 4
	for i = 0, n - 1 do
		local c = buffer.readu8(raw, at + i)
		if c >= colors then
			return nil
		end
		-- (the four bytes of a palette entry are R, G, B, A in order: copied as they are)
		buffer.writeu32(out, i * 4, buffer.readu32(raw, c * 4))
	end
	return out
end

return ArsenalIcons
