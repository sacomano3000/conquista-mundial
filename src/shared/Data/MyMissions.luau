--!strict
-- MISSÕES E PASSE: as missões do SEU jogo (o botão MISSÕES do lobby; as regras estão em Data/Missions).
--
-- MISSÕES DIÁRIAS (de graça, para todo mundo): a cada dia o jogo sorteia `por_dia` missões da lista
-- `diarias` (as mesmas para todos os jogadores, nunca duas que contam a mesma coisa). Trocam à
-- meia-noite de Brasília. Cumpriu a meta: as Coroas caem na hora, sem botão de resgatar.
--
-- PASSE DO MÊS (comprado com Robux, vale até o último dia do mês): dá direito aos prêmios das missões
-- `mensais`. O progresso delas conta para todo mundo desde o dia 1; quem compra o passe no meio do mês
-- recebe na hora os prêmios das que já cumpriu. No dia 1 tudo recomeça e o passe precisa ser comprado
-- de novo. Os itens ganhos (skin, bandeira e pet da temporada) ficam para sempre.
--
-- O que cada missão pode contar (`contar`):
--   "partidas"   partidas jogadas (solo ou pública) em que o jogador ficou ao menos `minutos_minimos`
--   "vitorias"   partidas vencidas
--   "reinos"     reinos destruídos (os "REINOS DESTRUÍDOS" do Rank: nações e jogadores conquistados)
--   "minutos"    minutos jogados, somados
--   "top3"       partidas terminadas entre os 3 primeiros (com pelo menos 4 reinos no mapa)
--   "diarias"    missões diárias cumpridas (só faz sentido numa missão mensal)
--
-- Em cada linha: `id` (um nome só dela, sem espaços; não mude depois de publicar, senão quem já
-- cumpriu recebe de novo), `texto` (o que aparece na tela; %d vira a meta), `meta`, e o prêmio:
-- `coroas = N`, ou, só nas mensais, `premio = "skin"`, `"bandeira"` ou `"pet"` (o item da temporada
-- do mês; quem já tem esse item recebe `coroas_item_repetido` no lugar).
--
-- As temporadas (nome, skin, bandeira e pet de cada mês) são desenhadas em tools/arte/cosmeticos.py
-- (lista SEASONS) e saem em Assets/Seasons.luau.
--
-- O PREÇO do passe em Robux fica em Data/MyProducts (linha `pass`), junto com o id do produto.
return {
	--- Quantas missões diárias por dia.
	por_dia = 3,
	--- Uma partida só conta como "jogada" se o jogador ficou nela ao menos estes minutos.
	minutos_minimos = 2,
	--- Coroas no lugar de um item da temporada que o jogador já tem (a temporada repete no ano seguinte).
	coroas_item_repetido = 8000,

	diarias = {
		{ id = "jogar2", contar = "partidas", meta = 2, coroas = 400, texto = "Jogue %d partidas" },
		{ id = "jogar3", contar = "partidas", meta = 3, coroas = 600, texto = "Jogue %d partidas" },
		{ id = "reinos3", contar = "reinos", meta = 3, coroas = 500, texto = "Destrua %d reinos" },
		{ id = "reinos6", contar = "reinos", meta = 6, coroas = 900, texto = "Destrua %d reinos" },
		{ id = "vencer1", contar = "vitorias", meta = 1, coroas = 800, texto = "Vença %d partida" },
		{ id = "minutos10", contar = "minutos", meta = 10, coroas = 400, texto = "Jogue por %d minutos" },
		{ id = "minutos20", contar = "minutos", meta = 20, coroas = 700, texto = "Jogue por %d minutos" },
		{ id = "top3", contar = "top3", meta = 1, coroas = 600, texto = "Termine %d partida entre os 3 primeiros" },
	},

	mensais = {
		{ id = "m_jogar", contar = "partidas", meta = 40, coroas = 10000, texto = "Jogue %d partidas" },
		{ id = "m_reinos", contar = "reinos", meta = 100, premio = "skin", texto = "Destrua %d reinos" },
		{ id = "m_minutos", contar = "minutos", meta = 300, coroas = 15000, texto = "Jogue por %d minutos" },
		{ id = "m_top3", contar = "top3", meta = 25, premio = "bandeira", texto = "Termine %d partidas entre os 3 primeiros" },
		{ id = "m_diarias", contar = "diarias", meta = 25, coroas = 25000, texto = "Cumpra %d missões diárias" },
		{ id = "m_vencer", contar = "vitorias", meta = 20, premio = "pet", texto = "Vença %d partidas" },
	},
}
