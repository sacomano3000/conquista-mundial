-- A trilha sonora do Conquista Mundial (escolhida pelo dono em 2026-11-11): uma música por momento,
-- todas da Creator Store do Roblox (conta DistroKid).
-- tracks: nome -> { id, length (s), title, db }; db é o ajuste de volume só daquela música (as seis foram
-- medidas e niveladas entre si). moods: as músicas de cada momento; com mais de uma, o jogo alterna
-- (title = tela inicial, wait = sala de espera, calm = partida em paz, war = partida em guerra,
-- victory / defeat = fim da partida). Se a licença de uma música pedir o nome do autor, a frase de
-- crédito vai em Data/Brand.luau (MUSIC_CREDIT) e aparece em Como jogar.
return {
	credit = "",
	license = "Roblox Creator Store",
	tracks = {
		royal_courtyard = { id = "rbxassetid://99301366639600", length = 155, title = "Royal Courtyard", db = -0.5 },
		village_of_hope = { id = "rbxassetid://132186416717371", length = 193, title = "Village of Hope", db = 0 },
		whispering_woods = { id = "rbxassetid://139466688846504", length = 218.28, title = "Whispering Woods", db = -3 },
		epic_fortress_defense = { id = "rbxassetid://102727895618704", length = 177.44, title = "Epic Fortress Defense", db = -3.5 },
		triumph_in_the_dust = { id = "rbxassetid://78703943883933", length = 204.76, title = "Triumph in the Dust", db = -4 },
		lacrima = { id = "rbxassetid://102473807772239", length = 199.54, title = "Lacrima", db = 5.5 },
	},
	moods = {
		title = { "royal_courtyard" },
		wait = { "village_of_hope" },
		calm = { "whispering_woods" },
		war = { "epic_fortress_defense" },
		victory = { "triumph_in_the_dust" },
		defeat = { "lacrima" },
	},
}
