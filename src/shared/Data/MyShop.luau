--!strict
-- A SUA LOJA: as caixas da Coleção e a Loja Misteriosa. Mude os números aqui e publique de novo.
--
-- CAIXAS (Coleção): cada aba (Skins, Bandeiras, Pets) tem a sua caixa. A caixa sorteia um item daquela
-- aba pelas chances abaixo. É uma caixa por compra: ela abre na hora, na aba em que foi comprada.
-- ITEM REPETIDO (`repetidos` abaixo): com true, a caixa pode sortear um item que o jogador já tem, e
-- nesse caso ele recebe Coroas no lugar (`coroas_repetido`, por raridade). Com false, a caixa nunca
-- repete: sempre vem um item novo, e a coleção inteira custa só o número de itens vezes o preço.
-- Quando o jogador já tem todos os itens de uma aba, a caixa daquela aba não é mais vendida.
-- Há dois botões lado a lado:
--   * Coroas (`coroas` abaixo, por caixa): para todos. Coroas só se ganham jogando.
--   * Robux (o produto `crate` de Data/MyProducts): só aparece onde o Roblox permite caixa paga. Onde
--     NÃO permite (no Brasil: menores de 18 e adultos sem idade verificada), o botão de Robux some e
--     fica só o de Coroas. O jogo pergunta ao Roblox, jogador por jogador (PolicyService).
--   * Enquanto o produto `crate` não tiver id em Data/MyProducts, o botão de Robux aparece mas avisa
--     que a compra ainda não está pronta; a caixa por Coroas funciona normalmente.
-- IMPORTANTE: não venda Coroas por Robux. Se as Coroas puderem ser compradas, a caixa por Coroas passa
-- a contar como caixa paga e deixa de ser permitida para esses jogadores.
--
-- LOJA MISTERIOSA: todo dia (00:00 UTC) aparecem `ofertas_por_dia` itens para comprar direto, sem
-- sorteio, por Robux (um produto por raridade em Data/MyProducts: shop_common, shop_rare, shop_epic,
-- shop_legendary). Cada oferta tem uma chance pequena de vir por Coroas para aquele jogador: quando
-- vem, é um item Comum (ou, muito mais raro, um item Raro).
return {
	caixa = {
		--- preço em Robux mostrado enquanto o Roblox não responde (o que vale é o preço do produto)
		robux = 9,
		--- preço em Coroas de uma caixa (para todos os jogadores)
		coroas = 25000,
		--- a chance de cada raridade, em % (o jogo mostra estes números antes da compra, como o Roblox
		--- exige). Não precisam somar 100: o jogo acerta a proporção. Com `repetidos = false`, se o
		--- jogador já tem todos os itens de uma raridade naquela aba, a chance dela é repartida entre
		--- as outras.
		chances = {
			comum = 80,
			raro = 15,
			epico = 4.5,
			lendario = 0.5,
		},
		--- true: a caixa pode sortear um item que o jogador já tem (ele recebe Coroas no lugar).
		--- false: a caixa nunca repete (como era até 12/11/2026).
		repetidos = true,
		--- Coroas pagas por um item repetido, pela raridade dele. Mantenha bem abaixo do preço da
		--- caixa em Coroas: o jogo não aceita um valor maior que esse preço (senão a caixa se pagaria
		--- sozinha), e quanto mais alto, mais barato fica juntar Coroas comprando caixas com Robux.
		coroas_repetido = {
			comum = 2500,
			raro = 6000,
			epico = 12000,
			lendario = 25000,
		},
	},
	loja = {
		--- quantos itens a loja mostra por dia
		ofertas_por_dia = 6,
		--- que raridades aparecem na loja, em % (não é sorteio de compra: só decide o que entra na vitrine)
		vitrine = {
			comum = 40,
			raro = 35,
			epico = 20,
			lendario = 5,
		},
		--- preço em Robux por raridade (mostrado enquanto o Roblox não responde; vale o do produto)
		robux = {
			comum = 19,
			raro = 49,
			epico = 99,
			lendario = 199,
		},
		--- preço em Coroas quando a oferta vem por Coroas
		coroas = {
			comum = 6000,
			raro = 25000,
		},
		--- a chance, em %, de uma oferta vir por Coroas com um item Comum (0.02 = 0,02%)
		chance_coroas_comum = 0.02,
		--- a chance, em %, de uma oferta vir por Coroas com um item Raro (0.0001 = 0,0001%)
		chance_coroas_raro = 0.0001,
	},
}
