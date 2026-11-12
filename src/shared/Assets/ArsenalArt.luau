-- The ids come from RoWorld's uploads; this version's drawings take their place (Assets/OwnArt).
-- The Arsenal's art (Data/Arsenal): white interface masks and the shop cards' renders (its
-- structures' map plates and glyphs are in Assets/MapSprites with every other structure's).
return {
	ui = {
		artillery = "rbxassetid://129962050975056",
		airfield = "rbxassetid://93161184929593",
		railgun = "rbxassetid://80259865103214",
		mega = "rbxassetid://129076365242890",
		scatter = "rbxassetid://73314694929508",
		reinforce = "rbxassetid://80150583838975",
		airstrike = "rbxassetid://97597884564003",
		slug = "rbxassetid://74359376650198",
		star = "rbxassetid://123717027950196",
		lock = "rbxassetid://115477224449087",
		reload = "rbxassetid://98646122722253",
		arsenal = "rbxassetid://100317438832041",
	},
	--- the shop cards' item pictures (Data/Arsenal item key -> image): { id, w, h }. This version draws
	--- its own eight pictures in their place (assets/arsenal-icons, 256 x 256: Assets/OwnArt "render/<key>",
	--- put on screen by UI/ArtSweep), so w and h are the pictures' size.
	renders = {
		airfield = { id = "rbxassetid://110223879206367", w = 256, h = 256 },
		artillery = { id = "rbxassetid://88796850061327", w = 256, h = 256 },
		mega = { id = "rbxassetid://103963261810830", w = 256, h = 256 },
		railgun = { id = "rbxassetid://130681855347677", w = 256, h = 256 },
		reinforce = { id = "rbxassetid://94188923858941", w = 256, h = 256 },
		reload2x = { id = "rbxassetid://119833217146965", w = 256, h = 256 },
		scatter = { id = "rbxassetid://114113709844408", w = 256, h = 256 },
		stars2x = { id = "rbxassetid://114358812407533", w = 256, h = 256 },
	},
	--- what flies in an attack, seen from above with its HEAD TO THE LEFT (assets/ataque/<item>.png;
	--- Assets/OwnArt "attack/<key>"): the Ataque de Dragões' dragon, in the Arsenal's preview
	--- (client/UI/ArsenalDemo) and over the map in a match (client/Map/UnitLayer). The id is only a
	--- name: the image is this game's own. w and h are written by tools/arte/make_own_art.py.
	attack = {
		airfield = { id = "rbxasset://own/attack_airfield", w = 190, h = 288 },
	},
}
