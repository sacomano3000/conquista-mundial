--!strict
-- The lobby's picture from the client's first moment (2026-11-12: "the map shows instead of the
-- lobby's image, and then the lobby's image loads").
--
-- Client/Main brings the map up before the interface, and the interface may wait for its fonts on a
-- client that has just arrived (every teleport: into a public match and back from it). In that wait
-- the map stood alone on screen. This cover goes up before the map: the lobby's own picture (UI/ArtSweep
-- puts it there, the same drawing as the title's) over a dark sheet, between the map's layers and the
-- interface. It leaves once the interface has taken the screen.
--
--   BootCover.show(parent)     the cover, under `parent` (the PlayerGui); returns the ScreenGui
--   BootCover.lift(fade?)      takes it away: at once, or fading over `fade` seconds
--   BootCover.up()             whether it is on screen
local BootCover = {}

--- above the map's three layers (Map/MapView: -10 and the two above it), under the interface (10)
BootCover.DISPLAY_ORDER = 9
--- the lobby's picture (UI/TitleScreen.LOBBY_ART; UI/ArtSweep gives it this game's drawing)
BootCover.ART = "rbxasset://own/lobby"
--- the title's own dark sheet, so the cover and the title's first frame look alike
BootCover.INK = Color3.fromRGB(14, 12, 20)
BootCover.SHADE = Color3.new(0.005, 0.008, 0.03)
BootCover.SHADE_ALPHA = 0.72
--- never left on screen: with no word from the interface it goes by itself after this long (s)
BootCover.LIMIT_S = 20

local gui: any = nil
local gen = 0

function BootCover.up(): boolean
	return gui ~= nil
end

function BootCover.show(parent: Instance?): any
	if gui ~= nil then
		return gui
	end
	local sg = Instance.new("ScreenGui")
	sg.Name = "CoberturaInicial"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.ScreenInsets = Enum.ScreenInsets.None
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = BootCover.DISPLAY_ORDER
	local art = Instance.new("ImageLabel")
	art.Name = "LobbyArt"
	art.BackgroundColor3 = BootCover.INK
	art.BackgroundTransparency = 0
	art.BorderSizePixel = 0
	art.Size = UDim2.fromScale(1, 1)
	art.ScaleType = Enum.ScaleType.Crop
	art.Image = BootCover.ART
	art.Parent = sg
	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BackgroundColor3 = BootCover.SHADE
	shade.BackgroundTransparency = 1 - BootCover.SHADE_ALPHA
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.ZIndex = 2
	shade.Parent = sg
	sg.Parent = parent
	gui = sg
	gen += 1
	local mine = gen
	task.delay(BootCover.LIMIT_S, function()
		if gen == mine then
			BootCover.lift(0.3)
		end
	end)
	return sg
end

function BootCover.lift(fade: number?)
	local sg = gui
	if sg == nil then
		return
	end
	gui = nil
	gen += 1
	local t = fade or 0
	local ok = false
	if t > 0 then
		ok = pcall(function()
			local ts = (game :: any):GetService("TweenService")
			local info = TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			ts:Create(sg.LobbyArt, info, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
			ts:Create(sg.Shade, info, { BackgroundTransparency = 1 }):Play()
		end)
	end
	if ok then
		task.delay(t + 0.05, function()
			sg:Destroy()
		end)
	else
		sg:Destroy()
	end
end

return BootCover
