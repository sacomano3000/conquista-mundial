--!strict
-- The kingdom's mascot (the owner, 2026-11-12): the pet a player wears (Data/Cosmetics) sits on their
-- capital on the map — it is no longer beside the name — and celebrates when its kingdom conquers
-- another. Looks only: it gives nothing in a match. This is how it moves; client/Map/NameLayer draws it.
local Mascot = {}

--- How long a mascot celebrates a conquest, in seconds, and how big it is on the screen (px).
Mascot.CHEER_S = 2.4
Mascot.MIN_PX = 16
Mascot.MAX_PX = 46

--- A mascot's pose at `now`: (how far it is lifted, in px; its tilt, in degrees). Resting, it
--- breathes a little; for CHEER_S after a conquest (`cheer_at`: when; nil: none) it jumps, lower each
--- time, and wags.
function Mascot.pose(now: number, cheer_at: number?, size: number, seed: number): (number, number)
	local lift = (math.sin(now * 2.2 + seed) * 0.5 + 0.5) * size * 0.05
	local tilt = 0.0
	if cheer_at ~= nil then
		local e = now - cheer_at
		if e >= 0 and e < Mascot.CHEER_S then
			local fade = 1 - e / Mascot.CHEER_S
			lift += math.abs(math.sin(e * 9.0)) * size * 0.55 * fade
			tilt = math.sin(e * 18.0) * 14.0 * fade
		end
	end
	return lift, tilt
end

return Mascot
