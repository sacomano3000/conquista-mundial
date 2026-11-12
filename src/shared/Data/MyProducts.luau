--!strict
-- VENDA COM ROBUX: os produtos do SEU jogo.
--
-- As seis habilidades do Arsenal (Magia Suprema, Rajada Arcana, Reforços, Catapulta, Ataque de
-- Dragões, Balista Arcana) podem ser compradas de dois jeitos: com a moeda ganha jogando (Coroas) ou
-- com Robux. Os dois bônus permanentes (2x Coroas e Recarga Rápida) são SÓ POR ROBUX, como no
-- RoWorld: enquanto a linha deles estiver com id = 0, aparecem como "EM BREVE" e ninguém consegue ter.
-- A compra com Robux só aparece quando o item tem aqui o id de um "Produto de desenvolvedor"
-- criado na SUA experiência (os ids de outro jogo não funcionam no seu e o dinheiro iria para ele).
-- Os preços em Robux abaixo são os do RoWorld.
--
-- 11/11/2026: os 13 produtos foram criados na experiência do jogo e os ids estão nas linhas abaixo
-- (nome, preço e imagem de cada um: assets/produtos/PRODUTOS.md). Para trocar um preço, mude no painel
-- do Roblox e repita o número em `robux` aqui. Para parar de vender um item por Robux, ponha id = 0.
--
-- Como ligar um produto novo, ou o de outra experiência (os ids só valem na experiência em que
-- foram criados):
--   1. Publique o jogo. Em create.roblox.com abra a experiência > Monetização > Produtos de
--      desenvolvedor > Criar produto de desenvolvedor.
--   2. Crie um produto para cada linha abaixo (o nome é livre, por exemplo "Catapulta") e defina o
--      preço em Robux no painel. É o preço do painel que vale e que o jogo mostra.
--   3. Copie o id do produto (o número) e coloque em `id` na linha dele. `robux` aqui é só o preço
--      mostrado enquanto o Roblox ainda não respondeu: deixe igual ao do painel.
--   4. Publique de novo.
--
-- id = 0: o item não é vendido por Robux. As habilidades continuam podendo ser ganhas jogando; os
-- dois bônus ficam indisponíveis até terem um id.
--
-- CAIXAS DA COLEÇÃO (Data/MyShop): crie o produto `crate` com o preço de UMA caixa (9 Robux). O jogador
-- compra uma caixa por vez. Sem o produto `crate`, a caixa é vendida só por Coroas.
--
-- LOJA MISTERIOSA (Data/MyShop): um produto para cada raridade. Sem o produto de uma raridade, os itens
-- dela aparecem na loja com o preço, mas apertar o botão só mostra o aviso "Essa oferta ainda não pode
-- ser comprada." (as raras ofertas por Coroas funcionam sem produto nenhum).
--
-- PASSE DO MÊS (Data/MyMissions; botão MISSÕES do lobby): a linha `pass`. É um PRODUTO DE DESENVOLVEDOR
-- (não um "Passe de jogo" do Roblox, que é comprado uma vez só e vale para sempre): o jogador compra
-- de novo a cada mês. Enquanto a linha estiver com id = 0, a tela de Missões mostra o passe como
-- "EM BREVE" e ninguém consegue comprar; as missões diárias funcionam do mesmo jeito.
return {
	unlock_mega = { id = 3730481743, robux = 39 }, -- Magia Suprema
	unlock_scatter = { id = 3730507385, robux = 67 }, -- Rajada Arcana
	unlock_stars2x = { id = 3730507253, robux = 59 }, -- 2x Coroas (só por Robux)
	unlock_artillery = { id = 3730507497, robux = 99 }, -- Catapulta
	unlock_reload2x = { id = 3730507641, robux = 129 }, -- Recarga Rápida (só por Robux)
	unlock_reinforce = { id = 3730507879, robux = 149 }, -- Reforços
	unlock_airfield = { id = 3730508013, robux = 349 }, -- Ataque de Dragões
	unlock_railgun = { id = 3730508175, robux = 999 }, -- Balista Arcana (no Roblox o produto se chamava Canhão Arcano: renomeie lá)

	crate = { id = 3730508358, robux = 9 }, -- 1 caixa da Coleção

	shop_common = { id = 3730508466, robux = 19 }, -- Loja Misteriosa: um item Comum
	shop_rare = { id = 3730508616, robux = 49 }, -- Loja Misteriosa: um item Raro
	shop_epic = { id = 3730508724, robux = 99 }, -- Loja Misteriosa: um item Épico
	shop_legendary = { id = 3730508805, robux = 199 }, -- Loja Misteriosa: um item Lendário

	pass = { id = 3730557862, robux = 199 }, -- Passe do mês (Missões)
}
