-- The ids below are RoWorld's uploads, kept as keys only: this version draws its own art in their place
-- (Assets/OwnArt, tools/arte/make_own_art.py), so these images are not what players see.
-- The Arsenal previews' ground: pieces of this game's world map, drawn like a match
-- (tools/arte/mapas_do_arsenal.py; the cells below are the grid both use).
-- cell: a scene's size in the atlas (tiles = px); scenes[key]: its cells (one per frame, top left)
-- and its border's split of the scene (nil: the player's land only).
return {
	id = "rbxassetid://103272438740711",
	size = Vector2.new(980, 368),
	cell = Vector2.new(192, 88),
	scenes = {
		mega = { frames = { Vector2.new(2, 2) }, split = 0.4, enemy = Color3.fromRGB(220, 68, 60), advance = 0 },
		scatter = { frames = { Vector2.new(198, 2) }, split = 0.38, enemy = Color3.fromRGB(238, 132, 44), advance = 0 },
		reinforce = {
			frames = {
				Vector2.new(394, 2),
				Vector2.new(590, 2),
				Vector2.new(786, 2),
				Vector2.new(2, 94),
				Vector2.new(198, 94),
				Vector2.new(394, 94),
				Vector2.new(590, 94),
				Vector2.new(786, 94),
				Vector2.new(2, 186),
			},
			split = 0.44,
			enemy = Color3.fromRGB(220, 68, 60),
			advance = 22,
		},
		artillery = {
			frames = { Vector2.new(198, 186) },
			split = 0.44,
			enemy = Color3.fromRGB(238, 132, 44),
			advance = 0,
		},
		airfield = { frames = { Vector2.new(394, 186) }, split = 0.4, enemy = Color3.fromRGB(220, 68, 60), advance = 0 },
		railgun = { frames = { Vector2.new(590, 186) }, split = 0.3, enemy = Color3.fromRGB(40, 170, 170), advance = 0 },
		reload2x = {
			frames = { Vector2.new(786, 186) },
			split = 0.68,
			enemy = Color3.fromRGB(220, 68, 60),
			advance = 0,
		},
		stars2x = { frames = { Vector2.new(2, 278) }, split = nil, enemy = nil, advance = 0 },
	},
	player = Color3.fromRGB(150, 92, 226),
}
