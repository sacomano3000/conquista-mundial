--!strict
-- The weekly ranking's insignia in the chat (Data/RankPrizes): a player who finished last week among
-- the first three of a weekly list has "[TOP 1]" (gold), "[TOP 2]" (silver) or "[TOP 3]" (bronze)
-- before their name in every message, for the whole week. The server puts the place on the player
-- (the attribute "RankBadge": ServerMain), so every client can read it.
--
--   ChatBadge.start()                 once, at the client's start
--   ChatBadge.prefix(place, prefix)   the text shown before a message (tests)
local IS_ROBLOX = typeof(game) == "Instance"

local RankPrizes: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Conquista").Data.RankPrizes)
	else (require :: any)("../../shared/Data/RankPrizes")

local ChatBadge = {}

--- The name of the attribute the server sets on a player who wears an insignia (1, 2 or 3).
ChatBadge.ATTRIBUTE = "RankBadge"

local started = false

--- `prefix` (the chat's own "Name:") with the insignia's tag before it; `prefix` as it is for a
--- player who wears none.
function ChatBadge.prefix(place: any, prefix: string): string
	local b = RankPrizes.badge(place)
	if b == nil then
		return prefix
	end
	return string.format('<font color="%s"><b>%s</b></font> %s', RankPrizes.BADGE_HEX[b], RankPrizes.CHAT_TAGS[b], prefix)
end

function ChatBadge.start()
	if started or not IS_ROBLOX then
		return
	end
	started = true
	local chat = (game :: any):GetService("TextChatService")
	local players = (game :: any):GetService("Players")
	chat.OnIncomingMessage = function(message: any): any
		local ok, props = pcall(function(): any
			local src = message.TextSource
			if src == nil then
				return nil
			end
			local player = players:GetPlayerByUserId(src.UserId)
			local place = if player ~= nil then player:GetAttribute(ChatBadge.ATTRIBUTE) else nil
			if RankPrizes.badge(place) == nil then
				return nil
			end
			local p = Instance.new("TextChatMessageProperties")
			p.PrefixText = ChatBadge.prefix(place, message.PrefixText)
			return p
		end)
		return if ok then props else nil
	end
end

return ChatBadge
