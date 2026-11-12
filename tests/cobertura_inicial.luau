--!nocheck
-- The lobby's picture covers the screen from the client's first moment (2026-11-12: "the map shows
-- instead of the lobby's image, and then the lobby's image loads"). client/Main brings the map up
-- before the interface, which may wait for its fonts: UI/BootCover goes up before the map and leaves
-- when the interface has the screen.
--   lune run tests/cobertura_inicial.luau
local fs = require("@lune/fs")
local H = require("./ui_harness")
local BootCover = require("../src/client/UI/BootCover")
-- (the title screen's modules load as outside Roblox first, then get a stand-in for `game`)
local _UICtx = require("../src/client/UI/UICtx")
local _UITheme = require("../src/client/UI/UITheme")
H.root(1280, 720, false)
H.fake_game()
local TitleScreen = require("../src/client/UI/TitleScreen")

local checks, failed = 0, 0
local function check(ok: boolean, what: string)
	checks += 1
	if not ok then
		failed += 1
		print("FAIL: " .. what)
	end
end

local pg = H.new("ScreenGui")
check(not BootCover.up(), "no cover before it is asked for")
local sg = BootCover.show(pg)
check(BootCover.up() and sg.Parent == pg, "the cover is on screen once shown")
check(sg.ClassName == "ScreenGui" and sg.IgnoreGuiInset == true and sg.ResetOnSpawn == false, "it fills the screen and outlives a respawn")
-- the map's three layers are MAP_DISPLAY_ORDER and the two above it; the interface is at 10
local map_order = tonumber(string.match(fs.readFile("src/client/Map/MapView.luau"), "MapView%.MAP_DISPLAY_ORDER = (%-?%d+)"))
check(map_order ~= nil and sg.DisplayOrder > map_order + 2, "the cover is above the map's three layers (" .. tostring(map_order) .. " and the two above)")
local ui_src = fs.readFile("src/client/UI/UIRoot.luau")
local ui_order = tonumber(string.match(ui_src, 'sg%.Name = "ConquistaUI".-sg%.DisplayOrder = (%-?%d+)'))
check(ui_order ~= nil and sg.DisplayOrder < ui_order, "... and under the interface (" .. tostring(ui_order) .. ")")
local art = sg:FindFirstChild("LobbyArt")
check(art ~= nil and art.ClassName == "ImageLabel", "it holds the lobby's picture")
check(art.Image == TitleScreen.LOBBY_ART, "... the same picture the title asks for")
check(art.BackgroundTransparency == 0 and art.ImageTransparency == 0, "... opaque: nothing of the map shows through, even before the picture is made")
check(art.Size.X.Scale == 1 and art.Size.Y.Scale == 1 and art.ScaleType == Enum.ScaleType.Crop, "... over the whole screen")
-- (the picture is this game's drawing: UI/ArtSweep knows the name)
local OwnArt = require("../src/shared/Assets/OwnArt")
check(OwnArt.key_for(art.Image) == "lobby/bg", "UI/ArtSweep has a drawing for the cover's picture")
check(BootCover.show(pg) == sg, "asked for twice, it is the same cover")
local n = 0
for _, c in pg:GetChildren() do
	if c.Name == "CoberturaInicial" then
		n += 1
	end
end
check(n == 1, "... and only one is on screen")

BootCover.lift(0)
check(not BootCover.up() and sg.Parent == nil, "lifted, it is gone")
BootCover.lift(0) -- (a second lift does nothing)
check(not BootCover.up(), "lifting twice is harmless")

-- with no word from the interface the cover goes by itself
local sg2 = BootCover.show(pg)
check(BootCover.up() and sg2 ~= sg, "a new cover can be shown")
H.flush()
H.flush()
check(not BootCover.up() and sg2.Parent == nil, "left alone, the cover takes itself away (its time limit)")
-- an old cover's time limit never takes a newer cover
local a = BootCover.show(pg)
BootCover.lift(0)
local b = BootCover.show(pg)
local later = H.later
H.later = {}
later[1][1](table.unpack(later[1], 2)) -- the first cover's limit runs now
check(BootCover.up() and b.Parent == pg and a.Parent == nil, "an older cover's time limit leaves the newer cover alone")
BootCover.lift(0)

-- client/Main: the cover goes up before the map is made, and comes down after the interface is built
local main = fs.readFile("src/client/Main.luau")
local i_show = string.find(main, "BootCover.show", 1, true)
local i_map = string.find(main, "pcall(WorldView.new)", 1, true)
local i_ui = string.find(main, "pcall(UIRoot.new)", 1, true)
local i_lift = string.find(main, "BootCover.lift", 1, true)
check(i_show ~= nil and i_map ~= nil and i_show < i_map, "Main shows the cover before it makes the map")
check(i_lift ~= nil and i_ui ~= nil and i_lift > i_ui, "Main lifts it only after the interface is built")

print(string.format("cobertura_inicial: %d checks, %d failed", checks, failed))
if failed > 0 then
	error("cobertura_inicial failed")
end
