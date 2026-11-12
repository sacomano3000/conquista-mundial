--!nocheck
-- Assets/ArsenalIcons: this version's own pictures of the Arsenal's items decode to what was drawn.
-- lune run tests/arsenal_icons.luau
local Icons = require("../src/shared/Assets/ArsenalIcons")
local Catalog = require("../src/shared/Data/Arsenal")

local fails = 0
local function ok(cond: boolean, what: string)
	if not cond then
		fails += 1
		print("FAIL " .. what)
	end
end

-- the sum of every byte of each picture, as the tool that made the data computed it
local SUMS = {
	mega = 8580785,
	scatter = 8515947,
	reinforce = 8385565,
	artillery = 8066728,
	airfield = 8186877,
	railgun = 8073141,
	stars2x = 8366861,
	reload2x = 8697817,
}

local n = Icons.SIZE * Icons.SIZE * 4
for _, key in Icons.KEYS do
	local px = Icons.pixels(key)
	ok(px ~= nil, key .. " has a picture")
	if px ~= nil then
		ok(buffer.len(px) == n, key .. " is SIZE x SIZE RGBA")
		local sum = 0
		local clear, solid = 0, 0
		for i = 0, n - 1 do
			sum += buffer.readu8(px, i)
		end
		for i = 3, n - 1, 4 do
			local a = buffer.readu8(px, i)
			if a == 0 then
				clear += 1
			elseif a == 255 then
				solid += 1
			end
		end
		ok(sum == SUMS[key], key .. " decodes to the drawing (sum " .. sum .. ")")
		-- a cut-out: clear around, solid inside, and clear in all four corners
		ok(clear > n / 4 * 0.15, key .. " has a clear background")
		ok(solid > n / 4 * 0.15, key .. " has a solid picture")
		for _, corner in { 0, Icons.SIZE - 1, n / 4 - Icons.SIZE, n / 4 - 1 } do
			ok(buffer.readu8(px, corner * 4 + 3) == 0, key .. " corner " .. corner .. " is clear")
		end
	end
end

-- every item of the Arsenal has one, and nothing else does
local items = 0
for _, it in Catalog.ITEMS do
	items += 1
	ok(Icons.pixels(it.key) ~= nil, "Arsenal item " .. tostring(it.key) .. " has a picture")
end
ok(items == #Icons.KEYS, "one picture per item (" .. items .. " items)")
ok(Icons.pixels("nothing") == nil, "an unknown item has none")

print(string.format("arsenal_icons: %d pictures, %d failed", #Icons.KEYS, fails))
if fails > 0 then
	error("arsenal_icons tests failed")
end
