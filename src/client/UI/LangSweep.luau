--!strict
-- The interface's language (shared/Data/Lang) for the texts that don't go through the kit's Label and
-- Button: the TextLabels and TextButtons a screen makes by hand (the Arsenal's window, the shops, the
-- crate opening, the map's own labels, the corner buttons). Every one under the player's PlayerGui is
-- shown in the interface's language as soon as it exists and whenever its text changes. The kit's own
-- labels arrive already translated, and a text with no entry stays as it is.
--
--   LangSweep.start(player)   once, at the client's start
--   LangSweep.apply(object)   the same for one object now (returns whether its text changed)
local IS_ROBLOX = typeof(game) == "Instance"
local Lang: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data.Lang)
	else (require :: any)("../../shared/Data/Lang")

local LangSweep = {}

--- object -> the text this module gave it (so its own change is not taken for a new text)
local mine: { [any]: string } = setmetatable({}, { __mode = "k" }) :: any
local started = false

--- Shows `obj`'s text in the interface's language. Returns whether it changed.
function LangSweep.apply(obj: any): boolean
	local text = obj.Text
	if type(text) ~= "string" or text == "" or text == mine[obj] then
		return false
	end
	local out = Lang.t(text)
	if out == text then
		return false
	end
	mine[obj] = out
	obj.Text = out
	return true
end

local function watch(obj: Instance)
	if obj:IsA("TextLabel") or obj:IsA("TextButton") then
		LangSweep.apply(obj)
		obj:GetPropertyChangedSignal("Text"):Connect(function()
			LangSweep.apply(obj)
		end)
	elseif obj:IsA("TextBox") then
		-- (what the player types is theirs: only the hint shown while it is empty)
		local hint = (obj :: TextBox).PlaceholderText
		local out = Lang.t(hint)
		if out ~= hint then
			(obj :: TextBox).PlaceholderText = out
		end
	end
end

function LangSweep.start(player: Player)
	if started or not Lang.on() then
		return
	end
	started = true
	local gui = player:WaitForChild("PlayerGui")
	gui.DescendantAdded:Connect(watch)
	for _, obj in gui:GetDescendants() do
		watch(obj)
	end
end

return LangSweep
