-- Os sons do Conquista Mundial: interface (cliques, janelas, abas), Coroas, eliminação e o estalo da
-- fronteira (expand_pop).
-- Cada som: id (o número do áudio na Creator Store), length (duração em segundos) e db (ajuste de
-- volume só desse som: negativo abaixa, positivo aumenta; 6 dB é mais ou menos "o dobro / a metade").
-- Um som escrito com sprite / start / stop toca só o trecho entre start e stop (segundos): é como o
-- silêncio do começo do arquivo foi cortado.
-- Para trocar um som: troque o número depois de rbxassetid:// (e, se souber, length). Para deixar um som
-- mais baixo ou mais alto: mude o db dele. Os valores de db vieram de medir cada arquivo (GUIA.md, seção 13).
return {
	sfx = {
		buy_spend = { id = "rbxassetid://9113849492", length = 1.245, db = 6 }, -- Coins Or Keys Jingle 6
		eliminate = { id = "rbxassetid://9119748927", length = 0.963, db = -2 }, -- Sword Stab 1
		expand_pop = { id = "rbxassetid://9116312491", length = 0.446, db = 5.5 }, -- Lip Pops Dry Plosive Short Snaps 2
		star_get = { id = "rbxassetid://9113849731", length = 1.698, db = -6 }, -- Coin Throws 2
		star_tick = { id = "rbxassetid://9113849011", length = 1.39, db = -7.5 }, -- Coins Drop Wood Table Hits Brass Gear 6
		ui_back = { id = "rbxassetid://10066914500", length = 0.56, db = 5 }, -- RBLX UI Back
		ui_click = { id = "rbxassetid://15675032796", length = 0.133, db = 5 }, -- Roblox_UI_Small_Click
		ui_confirm = { id = "rbxassetid://10128760939", length = 0.577, db = 5.5 }, -- RBLX UI Select 01
		ui_error = { id = "rbxassetid://17208214688", length = 0.868, db = -15 }, -- Roblox GUI - Call Decline
		ui_hover = { id = "rbxassetid://10066936758", length = 0.095, db = 12 }, -- RBLX UI Hover 02
		ui_locked = { id = "rbxassetid://9119717950", length = 0.292, db = 1 }, -- Switch Clicks Metallic Dull Pops 7
		ui_open = { id = "rbxassetid://9118835414", length = 1.486, db = -3.5 }, -- Scrapbook Open And Turn Pages 2
		ui_tab = { id = "rbxassetid://10066968815", length = 0.488, db = 4.5 }, -- RBLX UI Select 02
		unlock = { id = "rbxassetid://9116395085", length = 4.465, db = 10.5 }, -- Magic Glows Soft Clusters Of Chiming Hits 5
	},
}
