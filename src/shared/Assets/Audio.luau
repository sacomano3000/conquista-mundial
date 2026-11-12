-- Os sons do Conquista Mundial (escolhidos pelo dono em 2026-11-11; áudios da Creator Store do Roblox).
-- Este arquivo: os sons da partida. Os do baú e da contagem ficam em AudioExtra, os da interface em AudioUI
-- (cada som aparece em um arquivo só).
-- Cada som: id (o número do áudio na Creator Store), length (duração em segundos) e db (ajuste de
-- volume só desse som: negativo abaixa, positivo aumenta; 6 dB é mais ou menos "o dobro / a metade").
-- Um som escrito com sprite / start / stop toca só o trecho entre start e stop (segundos): é como o
-- silêncio do começo do arquivo foi cortado.
-- Para trocar um som: troque o número depois de rbxassetid:// (e, se souber, length). Para deixar um som
-- mais baixo ou mais alto: mude o db dele. Os valores de db vieram de medir cada arquivo (GUIA.md, seção 13).
-- music: os dois temas usados só se a trilha (Assets/Soundtrack) faltar.
return {
	music = {
		menu = { id = "rbxassetid://99301366639600", length = 155 },
		war = { id = "rbxassetid://102727895618704", length = 177.44 },
	},
	sfx = {
		alliance = { sprite = "rbxassetid://1840120074", start = 0.45, stop = 4.101, length = 3.651, db = 0.5 }, -- Bugle Call (A)
		ally_request = { id = "rbxassetid://15675043410", length = 1.472, db = -13 }, -- Roblox_UI_Tonal_Stinger
		attack_launch = { id = "rbxassetid://9119742466", length = 0.685, db = -1 }, -- Sword Draw Clang Unsheathing Two Sabers 1
		betrayal = { id = "rbxassetid://1845713466", length = 3.082, db = -16.5 }, -- Nervous Ghosts F
		boat_launch = { id = "rbxassetid://9117137917", length = 1.006, db = -13 }, -- Oars Fast Rowing In Water Away At Tail 2
		build = { id = "rbxassetid://9113447116", length = 1.555, db = -10.5 }, -- Blacksmith Anvil Hammer Hits 11
		conquer = { sprite = "rbxassetid://1840120155", start = 0.33, stop = 2.9, length = 2.57, db = 4.5 }, -- Bugle Call (C)
		defeat = { sprite = "rbxassetid://1835142330", start = 0.08, stop = 9.387, length = 9.307, db = 4.5 }, -- Accepting Defeat StingC
		expand = { sprite = "rbxassetid://9120709477", start = 0.17, stop = 0.976, length = 0.806, db = -8 }, -- Whoosh Fast Short Dull Several Versions 2
		nuke_alarm = { id = "rbxassetid://9113803790", length = 4.309, db = -4.5 }, -- Church Bells 3
		nuke_explosion = { id = "rbxassetid://9114362135", length = 6.078, db = -10.5 }, -- Explosions 1
		nuke_launch = { sprite = "rbxassetid://9114428740", start = 0.07, stop = 3.989, length = 3.919, db = -7.5 }, -- Fireball Pass By 1
		order_ack = { id = "rbxassetid://10066968815", length = 0.488, db = 4.5 }, -- RBLX UI Select 02
		sam_intercept = { id = "rbxassetid://9119072660", length = 0.74, db = -17.5 }, -- Shield Clang As Hit Metal Sword Hubcap 1
		sam_launch = { id = "rbxassetid://9116406610", length = 1.162, db = -5.5 }, -- Magic Poofs Thumpy Wheezy Exhale 1
		shell_fire = { id = "rbxassetid://9120972444", length = 0.651, db = 2 }, -- Wood Whoosh Slicing Air Quick Swings 1
		shell_hit = { id = "rbxassetid://9118608146", length = 1.118, db = -3.5 }, -- Rock Hits Rock On Rock Various Versions 8
		shell_splash = { id = "rbxassetid://9125703162", length = 0.814, db = 6 }, -- Mud Puddle Splash Shallow Water Impacts Hits
		ship_sink = { sprite = "rbxassetid://9120352848", start = 0.06, stop = 2.357, length = 2.297, db = -7.5 }, -- Underwater Splash 4
		under_attack = { id = "rbxassetid://9119072660", length = 0.74, db = -17.5 }, -- Shield Clang As Hit Metal Sword Hubcap 1
		victory = { sprite = "rbxassetid://1836473422", start = 0.19, stop = 9.979, length = 9.789, db = -11 }, -- Victory Fanfare Sting
		warship = { id = "rbxassetid://9113804171", length = 4.808, db = -1.5 }, -- Church Bell Single Hits Double At Head 4
	},
}
