--!strict
-- A staging experience (a separate game to test changes in before they go to prod): its universe id,
-- for what differs there (Data/Products' ids).
local Staging = {}

--- The staging experience's universe id. 0 = none.
Staging.UNIVERSE = 0

--- True in the staging experience.
function Staging.here(): boolean
	return Staging.UNIVERSE ~= 0 and typeof(game) == "Instance" and (game :: any).GameId == Staging.UNIVERSE
end

return Staging
