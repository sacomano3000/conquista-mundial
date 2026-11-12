--!nocheck
-- The place's own settings, read from the two Rojo project files (2026-11-10).
--   * TextChatService.ChatVersion = TextChatService. A place Rojo builds with no TextChatService in it
--     runs Roblox's legacy chat: Studio warns about it on the Chat service, and the legacy chat's window
--     is a ScreenGui in PlayerGui (DisplayOrder 6), so the lobby's painting (the interface's ScreenGui,
--     DisplayOrder 10, the whole screen) was drawn over it. The new chat's window is Roblox's own layer,
--     above every ScreenGui of the game. A script cannot change ChatVersion while the game runs, so it
--     has to be in the place file.
--   lune run tests/projeto.luau
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local fails, total = 0, 0
local function expect(cond: any, what: string)
	total += 1
	if not cond then
		fails += 1
		print("FAIL " .. what)
	end
end

for _, path in { "default.project.json", "release.project.json" } do
	local p = serde.decode("json", fs.readFile(path))
	local tree = p.tree
	expect(type(tree) == "table" and tree["$className"] == "DataModel", path .. " describes a place")
	local chat = tree.TextChatService
	expect(type(chat) == "table", path .. " has TextChatService")
	local props = if type(chat) == "table" then chat["$properties"] else nil
	expect(type(props) == "table" and props.ChatVersion == "TextChatService", path .. " runs the new chat, not the legacy one")
	expect(tree.Chat == nil, path .. " puts nothing in the legacy Chat service")
	-- (what the rest of the game counts on)
	expect(tree.Players["$properties"].CharacterAutoLoads == false, path .. ": no characters")
	expect(tree.StarterGui["$properties"].ResetPlayerGuiOnSpawn == false, path .. ": the interface stays")
end

-- the interface's layer is above where the legacy chat was: the reason it has to be the new chat
do
	local src = fs.readFile("src/client/UI/UIRoot.luau")
	local order = tonumber(string.match(src, "sg%.DisplayOrder = (%d+)"))
	expect(order ~= nil and order > 6, "the interface is drawn above DisplayOrder 6 (the legacy chat's)")
end

print(string.format("projeto: %d checks, %d failed", total, fails))
if fails > 0 then
	error("projeto failed")
end
