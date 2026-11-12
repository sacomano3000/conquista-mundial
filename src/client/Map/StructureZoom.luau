--!strict
-- How big a structure's icon is drawn at a zoom, and whether its picture is shown (2026-11-11).
-- Map/StructureLayer draws with it; this is the arithmetic.
--
-- `zoom` is the camera zoom in device px per full-size tile (StructureLayer.tick: cam.scale / k_lin *
-- DEVICE_RATIO). The answer is a share of StructureLayer.ICON_SIZE.
--
-- RoWorld's rule: far out (zoom <= 1.2) every structure became a small dot, 0.3 of the size, with no
-- picture in it. On Eldoria (2000 x 1000 tiles, k_lin 1) that is reached at the farthest zoom of a
-- 1280 x 720 window (zoom 1.15) and well before it on a phone (0.70), and its owner read it as the
-- structures' pictures going away. Here an icon keeps its picture at every zoom and stops shrinking
-- at MIN_SCALE, the size it had where RoWorld's dots began (1.2 / 3.0 = 0.4, a 12 px plate), so
-- nothing jumps. DOTS_ZOOM = 1.2 brings RoWorld's dots back.
--
-- Pure Luau (no Roblox types): tests/zoom_mapa.luau.
local StructureZoom = {}

--- At or under this zoom an icon is a dot without its picture. 0: never (RoWorld: 1.2).
StructureZoom.DOTS_ZOOM = 0.0
--- A dot's size.
StructureZoom.DOT_SCALE = 0.3
--- Under GROW_ZOOM an icon is zoom / SCALE_FACTOR_OUT of its size, 1 at most ...
StructureZoom.SCALE_FACTOR_OUT = 3.0
--- ... and never under this.
StructureZoom.MIN_SCALE = 0.4
--- From this zoom on an icon grows with the map.
StructureZoom.GROW_ZOOM = 7.0

--- (size as a share of the icon's full size, whether it is a dot without its picture) at `zoom`.
function StructureZoom.icon(zoom: number): (number, boolean)
	if zoom ~= zoom then
		return StructureZoom.MIN_SCALE, false
	end
	if StructureZoom.DOTS_ZOOM > 0 and zoom <= StructureZoom.DOTS_ZOOM then
		return StructureZoom.DOT_SCALE, true
	end
	if zoom >= StructureZoom.GROW_ZOOM then
		return zoom / StructureZoom.GROW_ZOOM, false
	end
	return math.max(StructureZoom.MIN_SCALE, math.min(1.0, zoom / StructureZoom.SCALE_FACTOR_OUT)), false
end

return StructureZoom
