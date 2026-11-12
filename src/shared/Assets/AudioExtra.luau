-- Os sons do Conquista Mundial: baú, cartas, contagem do começo da partida, fila e modo espectador.
-- Cada som: id (o número do áudio na Creator Store), length (duração em segundos) e db (ajuste de
-- volume só desse som: negativo abaixa, positivo aumenta; 6 dB é mais ou menos "o dobro / a metade").
-- Um som escrito com sprite / start / stop toca só o trecho entre start e stop (segundos): é como o
-- silêncio do começo do arquivo foi cortado.
-- Para trocar um som: troque o número depois de rbxassetid:// (e, se souber, length). Para deixar um som
-- mais baixo ou mais alto: mude o db dele. Os valores de db vieram de medir cada arquivo (GUIA.md, seção 13).
return {
	sfx = {
		card_flip = { id = "rbxassetid://9114035710", length = 1.192, db = 3.5 }, -- Deck Of Cards 9
		card_whoosh = { id = "rbxassetid://9120972321", length = 0.561, db = -5 }, -- Wood Whoosh Slicing Air Quick Swings 4
		countdown_gamestart = { sprite = "rbxassetid://9114822651", start = 0.09, stop = 2.56, length = 2.47, db = 20 }, -- Horn Blow Long Bursts 10
		countdown_tick = { id = "rbxassetid://9114071134", length = 0.419, db = 7 }, -- Dial Switch Twisting Sharp Ticking 79
		countdown_tick_1 = { id = "rbxassetid://9119974912", length = 0.83, db = -4.5 }, -- Temple Blocks Impact Hitting Two At Once 3
		countdown_tick_2 = { id = "rbxassetid://9119974912", length = 0.83, db = -4.5 }, -- Temple Blocks Impact Hitting Two At Once 3
		countdown_tick_3 = { id = "rbxassetid://9119974912", length = 0.83, db = -4.5 }, -- Temple Blocks Impact Hitting Two At Once 3
		countdown_tick_4 = { id = "rbxassetid://9119974912", length = 0.83, db = -4.5 }, -- Temple Blocks Impact Hitting Two At Once 3
		countdown_tick_5 = { id = "rbxassetid://9119974912", length = 0.83, db = -4.5 }, -- Temple Blocks Impact Hitting Two At Once 3
		crate_drop = { sprite = "rbxassetid://9125805781", start = 0.06, stop = 1.792, length = 1.732, db = -6.5 }, -- Rising Whoosh Hissing Build Up Ascending Swo
		crate_land = { id = "rbxassetid://9113225986", length = 0.859, db = -17.5 }, -- Axe Impact Giant Thuddy Hits On Wood Floor 5
		crate_open = { sprite = "rbxassetid://9126263691", start = 0.11, stop = 1.931, length = 1.821, db = 7 }, -- Wood Groan Creak Opening Wood Chest Coffin 1
		crate_preview_common = { sprite = "rbxassetid://9125647212", start = 0.31, stop = 2.938, length = 2.628, db = 2 }, -- Magic Whooshes Pass Bys Metallic Shimmering
		crate_preview_epic = { sprite = "rbxassetid://9125644905", start = 0.14, stop = 3.072, length = 2.932, db = -3 }, -- Magic Twirling Small High Pitch Spinning Chi
		crate_preview_legendary = { sprite = "rbxassetid://9116418035", start = 0.41, stop = 3.285, length = 2.875, db = -2.5 }, -- Magic Tone Falling Shimmer Flanged 3
		crate_preview_rare = { sprite = "rbxassetid://9125647212", start = 0.31, stop = 2.938, length = 2.628, db = 2 }, -- Magic Whooshes Pass Bys Metallic Shimmering
		crate_rattle = { id = "rbxassetid://9113763590", length = 0.865, db = -7 }, -- Chain Rattle Glassy Metal Rattle 3
		crate_shimmer = { sprite = "rbxassetid://9125635426", start = 0.11, stop = 3.861, length = 3.751, db = -8 }, -- Magical Exit Sparkling Pass Bys Clinking Chi
		game_start = { sprite = "rbxassetid://1846284931", start = 0.5, stop = 5.799, length = 5.299, db = -4.5 }, -- Timpani Signal 2
		queue_start = { id = "rbxassetid://17208372272", length = 3.035, db = -12.5 }, -- Roblox GUI - Notification Low
		reveal_common = { id = "rbxassetid://9116395089", length = 2.462, db = 10.5 }, -- Magic Glows Soft Clusters Of Chiming Hits 4
		reveal_epic = { sprite = "rbxassetid://9116384485", start = 0.08, stop = 3.179, length = 3.099, db = -12.5 }, -- Magic Burst 1
		reveal_legendary = { sprite = "rbxassetid://9116384483", start = 0.21, stop = 3.797, length = 3.587, db = -8.5 }, -- Magic Burst 3
		reveal_rare = { id = "rbxassetid://9116385087", length = 2.272, db = -10.5 }, -- Magic Burst 5
		spawn_confirm = { id = "rbxassetid://9114026047", length = 0.744, db = 3.5 }, -- Date Stamp Big Office Impact Good Squeak 2
		spectate_switch = { id = "rbxassetid://17208405682", length = 0.564, db = -2.5 }, -- Roblox GUI - Swipe
	},
}
