--!strict
-- Nothing of the original game's (RoWorld's) own accounts, products, services or names is left in the
-- code that goes into the place (the review of 2026-11-12; tools/revisao/vestigios.py lists the same
-- things for reading). What stays, on purpose:
--   * the copyright notice the licence requires ("© OpenFront and Contributors", "© 2026 Snick Co."):
--     the title's credits line and the Help's licence card;
--   * comments that say where a piece of code came from (only someone who opens the scripts reads them).
-- Run: lune run tests/vestigios.luau
local fs = require("@lune/fs")

local checks, fails = 0, 0
local function expect(cond: boolean, what: string)
	checks += 1
	if not cond then
		fails += 1
		print("FAIL " .. what)
	end
end

local files: { string } = {}
local function walk(dir: string)
	for _, n in fs.readDir(dir) do
		local p = dir .. "/" .. n
		if fs.isDir(p) then
			walk(p)
		elseif string.sub(n, -5) == ".luau" then
			table.insert(files, p)
		end
	end
end
walk("src")
table.sort(files)
expect(#files > 150, "the game's scripts are read (" .. #files .. ")")

--- A line's code: what comes before a `--` that is not inside a string.
local function code_of(line: string): string
	local quote: string? = nil
	local i = 1
	while i <= #line do
		local c = string.sub(line, i, i)
		if quote ~= nil then
			if c == "\\" then
				i += 1
			elseif c == quote then
				quote = nil
			end
		elseif c == '"' or c == "'" or c == "`" then
			quote = c
		elseif c == "-" and string.sub(line, i + 1, i + 1) == "-" then
			return string.sub(line, 1, i - 1)
		end
		i += 1
	end
	return line
end

-- the copyright notice: the only code that names the original authors
local NOTICE = {
	["src/client/UI/TitleScreen.luau"] = true,
	["src/client/UI/HelpOverlay.luau"] = true,
	["src/shared/Data/LangPt.luau"] = true,
}
-- RoWorld's accounts and products, as they were in the code
local THEIRS = {
	"22641473", -- the developer's account (client/Main: the launch hook)
	"58387889", -- a player's account (Data/Cosmetics: an exclusive skin)
	"137151641329864", -- its place
	"3715363250", "3715469100", "3715469104", "3716609998", "3716610004", "3716610015", "3716610019",
	"3716610030", "3716610035", "3716610048", "3716610055", "3716610101", "3716610114", "3716610118",
	"3716621701", "3716621706", "3716621710", "3716621715", "3716621718", "3716621726", "3716621730",
	"3716621734", "3718864635", "3718883874", "3720061533", "3720068382", "3722748745", "3722748768",
}

local old_names, named, ids, urls = {}, {}, {}, {}
local notices = 0
for _, p in files do
	local src = fs.readFile(p)
	local low = string.lower(src)
	-- the old internal names: nowhere, comments included
	if string.find(low, "airfront", 1, true) ~= nil or string.find(low, "rofront", 1, true) ~= nil then
		table.insert(old_names, p)
	end
	for _, id in THEIRS do
		if string.find(src, id, 1, true) ~= nil then
			table.insert(ids, p .. " " .. id)
		end
	end
	local n = 0
	for line in string.gmatch(src, "[^\n]*") do
		n += 1
		local code = string.lower(code_of(line))
		if string.find(code, "https?://") ~= nil or string.find(code, "snick.co", 1, true) ~= nil then
			table.insert(urls, p .. ":" .. n)
		end
		if string.find(code, "roworld", 1, true) ~= nil or string.find(code, "snick", 1, true) ~= nil or string.find(code, "openfront", 1, true) ~= nil then
			if NOTICE[p] and string.find(code, "© openfront and contributors", 1, true) ~= nil then
				notices += 1
			else
				table.insert(named, p .. ":" .. n)
			end
		end
	end
end
expect(#old_names == 0, "no script has the original's internal names (Airfront, Rofront): " .. table.concat(old_names, ", "))
expect(#ids == 0, "no script has an account, place or product id of the original game: " .. table.concat(ids, ", "))
expect(#urls == 0, "no code has a web address (no service of the original's is called): " .. table.concat(urls, ", "))
expect(#named == 0, "no code names the original game or its studio outside the copyright notice: " .. table.concat(named, ", "))
expect(notices >= 3, "the copyright notice the licence requires is still there (" .. notices .. " lines)")

-- the tools, the lobby service and the tests (none of them goes into the place): the old internal
-- names are gone from there too (2026-11-12). Two files name them on purpose: this test, and the
-- review script that looks for them.
do
	local SKIP_EXT = { png = true, jpg = true, jpeg = true, glb = true, wav = true, ogg = true, mp3 = true, ttf = true, zip = true, rbxl = true, rbxm = true, pyc = true, svg = true }
	local SKIP_DIR = { node_modules = true, __pycache__ = true, dist = true, telas = true }
	local ON_PURPOSE = { ["tests/vestigios.luau"] = true, ["tools/revisao/vestigios.py"] = true }
	local read, left = 0, {}
	local function sweep(dir: string)
		for _, n in fs.readDir(dir) do
			local p = dir .. "/" .. n
			if fs.isDir(p) then
				if not SKIP_DIR[n] then
					sweep(p)
				end
			elseif not SKIP_EXT[string.lower(string.match(n, "%.(%w+)$") or "")] and not ON_PURPOSE[p] then
				read += 1
				local low = string.lower(fs.readFile(p))
				if string.find(low, "airfront", 1, true) ~= nil or string.find(low, "rofront", 1, true) ~= nil then
					table.insert(left, p)
				end
			end
		end
	end
	for _, dir in { "tools", "services", "tests" } do
		if fs.isDir(dir) then
			sweep(dir)
		end
	end
	table.sort(left)
	expect(read > 200, "the tools, the service and the tests are read (" .. read .. " files)")
	expect(#left == 0, "no tool, service file or test has the original's internal names: " .. table.concat(left, ", "))
end

-- the place's folders
for _, name in { "release.project.json", "default.project.json" } do
	local j = fs.readFile(name)
	local low = string.lower(j)
	expect(string.find(low, "airfront", 1, true) == nil and string.find(low, "rofront", 1, true) == nil, name .. ": no folder has the original's internal name")
	expect(
		string.find(j, '"Conquista": {', 1, true) ~= nil
			and string.find(j, '"ConquistaServer": {', 1, true) ~= nil
			and string.find(j, '"ConquistaClient": {', 1, true) ~= nil,
		name .. ": the folders the scripts look for (Conquista, ConquistaServer, ConquistaClient)"
	)
end

-- what was switched off stays off: no lobby service, no subscription, no test experience
local LobbyHttp = require("../src/server/Lobbies/LobbyHttp")
expect(LobbyHttp.BASE_URL == "" and LobbyHttp.FALLBACK_URL == "" and LobbyHttp.ENABLED == false, "the original's lobby service is not called")
local Subscription = require("../src/shared/Data/Subscription")
expect(Subscription.ID == "" and Subscription.STAGING == "", "no subscription of the original's is sold")
expect(require("../src/shared/Data/Staging").UNIVERSE == 0, "no test experience of the original's")
expect(#require("../src/shared/Data/Cosmetics").exclusive_skins == 0, "no skin made for a player of the original's")
-- every product the game can sell is the owner's
local Mine = require("../src/shared/Data/MyProducts")
local mine = {}
for _, m in Mine do
	mine[m.id] = true
end
local foreign = {}
for key, p in require("../src/shared/Data/Products") do
	if type(p) == "table" and type(p.id) == "number" and p.id ~= 0 and not mine[p.id] then
		table.insert(foreign, key)
	end
end
expect(#foreign == 0, "every product on sale is one of the owner's (Data/MyProducts): " .. table.concat(foreign, ", "))

print(string.format("vestigios: %d checks, %d failed", checks, fails))
if fails > 0 then
	error(fails .. " failures")
end
