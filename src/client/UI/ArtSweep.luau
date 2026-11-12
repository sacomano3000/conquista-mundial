--!strict
-- This game's own icons on screen (shared/Assets/OwnArt): every ImageLabel and ImageButton under the
-- player's PlayerGui that is given one of RoWorld's images shows this game's drawing instead, as soon as
-- it exists and whenever its image changes. The screens keep asking for the same images (UITheme.icon,
-- Assets/MapSprites...) and the sprite sheets keep their grids, so no screen had to change.
--
-- A drawing is an EditableImage made once from the pixels in the code (or the owner's uploaded image,
-- Assets/OwnArtIds). Where the engine refuses to make one, RoWorld's image stays, except the logo,
-- which is hidden. Data/Brand.OWN_ICONS = false turns all of this off; Data/Brand.OWN_SHAPES = false
-- leaves only the interface's shapes (shadows, slices, glows) as RoWorld's.
--
--   ArtSweep.start(player)   once, at the client's start
--   ArtSweep.apply(object)   the same for one object now (returns whether it changed)
local IS_ROBLOX = typeof(game) == "Instance"

local ArtSweep = {}

local OwnArt: any = nil
local started = false
--- Data/Brand.OWN_SHAPES = false: the interface's shapes ("shape/...", "shadow/...") are left alone
local shapes_on = true
--- Data/Brand.OWN_ICONS = false: only the images that exist nowhere else are drawn (ArtSweep.is_own_only)
local icons_on = true
--- key -> Content, the uploaded id (string), or false when it could not be made
local made: { [string]: any } = {}
--- the EditableImages, kept alive
local keep: { any } = {}

local function content_for(key: string): any
	local c = made[key]
	if c ~= nil then
		return c
	end
	c = false
	local up = OwnArt.uploaded(key)
	if up ~= nil then
		c = up
	else
		local ok, err = pcall(function(): any
			local w, h = OwnArt.size(key)
			local px = OwnArt.pixels(key)
			local img = (game :: any):GetService("AssetService"):CreateEditableImage({ Size = Vector2.new(w, h) })
			if px == nil or img == nil then
				return nil
			end
			img:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), px)
			table.insert(keep, img)
			c = (Content :: any).fromObject(img)
			return nil
		end)
		if not ok then
			warn("[Game] own icon " .. key .. ": " .. tostring(err))
		end
	end
	made[key] = c
	return c
end

--- Is `key` one of the interface's shapes (tools/arte/formas.py)?
function ArtSweep.is_shape(key: string): boolean
	return string.sub(key, 1, 6) == "shape/" or string.sub(key, 1, 7) == "shadow/"
end

--- Is `key` an image that only this game has (the weekly ranking's insignias, Data/RankPrizes)? Their
--- "id" is not an asset of Roblox's, so they are drawn even with Brand.OWN_ICONS off.
function ArtSweep.is_own_only(key: string): boolean
	return string.sub(key, 1, 6) == "badge/"
end

function ArtSweep.apply(obj: any): boolean
	local id = obj.Image
	if type(id) ~= "string" or id == "" then
		return false
	end
	local key = OwnArt.key_for(id)
	if key == nil or (not shapes_on and ArtSweep.is_shape(key)) then
		return false
	end
	if not icons_on and not ArtSweep.is_own_only(key) then
		return false
	end
	local c = content_for(key)
	if c == false then
		if key == "logo" then
			obj.ImageTransparency = 1 -- never RoWorld's logo
		end
		return false
	end
	if type(c) == "string" then
		if c == id then
			return false
		end
		obj.Image = c
	else
		obj.ImageContent = c
	end
	return true
end

local function watch(obj: Instance)
	if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
		ArtSweep.apply(obj)
		obj:GetPropertyChangedSignal("Image"):Connect(function()
			ArtSweep.apply(obj)
		end)
	end
end

function ArtSweep.start(player: Player)
	if started or not IS_ROBLOX then
		return
	end
	local shared = (game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista")
	local brand = require(shared.Data.Brand) :: any
	icons_on = brand.OWN_ICONS ~= false
	shapes_on = icons_on and brand.OWN_SHAPES ~= false
	OwnArt = require(shared.Assets.OwnArt) :: any
	started = true
	local gui = player:WaitForChild("PlayerGui")
	gui.DescendantAdded:Connect(watch)
	for _, obj in gui:GetDescendants() do
		watch(obj)
	end
end

return ArtSweep
