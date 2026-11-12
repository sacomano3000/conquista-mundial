--!strict
-- AS SUAS SKINS: padrões de território criados por você. Entram na aba Skins da Coleção, na caixa de
-- skins e na Loja Misteriosa, junto com as que já vêm no jogo (Data/Cosmetics).
--
-- Uma skin NÃO é uma imagem: é um desenho pequeno feito de letras, repetido como um azulejo por cima
-- do território do jogador. Por isso não existe pasta de imagens de skin.
--
-- Cada linha da lista:
--   id        um nome só seu, sem espaços nem acentos (não mude depois: é o que fica salvo no jogador)
--   nome      o nome que aparece na Coleção
--   raridade  "comum", "raro", "epico" ou "lendario"
--   escala    0 = cada letra é 1 quadradinho do mapa; 1 = cada letra vale 2x2 (desenho maior)
--   desenho   as linhas do azulejo, de cima para baixo, todas do mesmo tamanho (até 32 letras).
--             "." é a cor do próprio jogador. O resto depende do tipo de skin:
--
--   TIPO 1, dois tons (a skin acompanha a cor do jogador): use "#" para o segundo tom e diga
--       tom = -0.25    (negativo = mais escuro que a cor do jogador; positivo = mais claro; -1 a 1)
--     ou
--       destaque = 0xE9B949   (uma cor fixa no lugar do segundo tom, em hexadecimal RRGGBB)
--
--   TIPO 2, várias cores fixas: dê a lista
--       cores = { 0xB22222, 0xE0B030, 0x1C1C22 }
--     e no desenho use "1" para a primeira cor, "2" para a segunda... ("1" a "9", depois "a" a "z").
--
-- Exemplos (apague o "--" do começo das linhas para ligar). Mais abaixo estão as skins já ligadas.
return {
	-- {
	-- 	id = "minha_cruz",
	-- 	nome = "Cruz do Reino",
	-- 	raridade = "raro",
	-- 	escala = 1,
	-- 	tom = -0.28,
	-- 	desenho = {
	-- 		"..#..",
	-- 		"..#..",
	-- 		"#####",
	-- 		"..#..",
	-- 		"..#..",
	-- 	},
	-- },
	-- {
	-- 	id = "minha_brasa",
	-- 	nome = "Brasa Real",
	-- 	raridade = "epico",
	-- 	escala = 1,
	-- 	cores = { 0xB22222, 0xE0B030 },
	-- 	desenho = {
	-- 		"1..2",
	-- 		".12.",
	-- 		".21.",
	-- 		"2..1",
	-- 	},
	-- },

	-- ===== AS 15 SKINS QUE ENTRARAM EM 12/11/2026 =====
	-- Estão ligadas: aparecem na Coleção, na caixa de skins e na Loja Misteriosa. Pode mudar o nome, a
	-- raridade e o desenho à vontade. NÃO mude o `id` nem apague uma linha depois de publicar: o id é
	-- o que fica salvo em quem já ganhou a skin (apagada, ela some da coleção dessa pessoa).
	{
		id = "pontilhado",
		nome = "Pontilhado",
		raridade = "comum",
		escala = 0,
		tom = 0.32,
		desenho = {
			"#...",
			"....",
			"..#.",
			"....",
		},
	},
	{
		id = "listras_largas",
		nome = "Listras Largas",
		raridade = "comum",
		escala = 1,
		tom = -0.2,
		desenho = {
			"###...",
		},
	},
	{
		id = "degraus",
		nome = "Degraus",
		raridade = "comum",
		escala = 1,
		tom = -0.2,
		desenho = {
			"##..",
			"..##",
		},
	},
	{
		id = "cruzinhas",
		nome = "Cruzinhas",
		raridade = "comum",
		escala = 0,
		tom = 0.3,
		desenho = {
			".#....",
			"###...",
			".#....",
			"....#.",
			"...###",
			"....#.",
		},
	},
	{
		id = "escamas",
		nome = "Escamas",
		raridade = "raro",
		escala = 0,
		tom = -0.26,
		desenho = {
			"#......#",
			"#......#",
			".#....#.",
			"..####..",
			"...##...",
			"...##...",
			"..#..#..",
			"##....##",
		},
	},
	{
		id = "labirinto",
		nome = "Labirinto",
		raridade = "raro",
		escala = 0,
		tom = -0.24,
		desenho = {
			"###.#.#.",
			"....#.#.",
			"###.#.#.",
			"....#.#.",
			"#.#.###.",
			"#.#.....",
			"#.#.###.",
			"#.#.....",
		},
	},
	{
		id = "flechas",
		nome = "Flechas",
		raridade = "raro",
		escala = 1,
		tom = -0.26,
		desenho = {
			"...##...",
			"..####..",
			".##..##.",
			"##....##",
		},
	},
	{
		id = "rosetas",
		nome = "Rosetas",
		raridade = "raro",
		escala = 0,
		tom = 0.3,
		desenho = {
			"...#....",
			"..###...",
			".##.##..",
			"..###...",
			"...#....",
			"........",
			"........",
			"........",
		},
	},
	{
		id = "ameias",
		nome = "Ameias",
		raridade = "raro",
		escala = 1,
		tom = -0.26,
		desenho = {
			"##..##..",
			"########",
			"........",
			"........",
		},
	},
	{
		id = "flor_de_lis",
		nome = "Flor-de-lis",
		raridade = "epico",
		escala = 0,
		tom = 0.42,
		desenho = {
			"............",
			".....#......",
			"....###.....",
			"....###.....",
			"..#.###.#...",
			".###.#.###..",
			".###.#.###..",
			"..#######...",
			"....###.....",
			"...#.#.#....",
			"............",
			"............",
		},
	},
	{
		id = "castelos",
		nome = "Castelos",
		raridade = "epico",
		escala = 0,
		tom = -0.3,
		desenho = {
			"#.#.#.#...",
			"#######...",
			".#####....",
			".##.##....",
			".##.##....",
			".#####....",
			"..........",
			"..........",
		},
	},
	{
		id = "espadas",
		nome = "Espadas",
		raridade = "epico",
		escala = 0,
		tom = -0.3,
		desenho = {
			"...#....",
			"..###...",
			"..###...",
			"..###...",
			"..###...",
			"#######.",
			"...#....",
			"...#....",
			"..###...",
			"........",
			"........",
		},
	},
	{
		id = "vitral",
		nome = "Vitral",
		raridade = "epico",
		escala = 0,
		cores = { 0x1C1C22, 0xE0B030, 0xC0392B },
		desenho = {
			"3......3",
			".1....1.",
			"..1..1..",
			"...22...",
			"...22...",
			"..1..1..",
			".1....1.",
			"3......3",
		},
	},
	{
		id = "esmeralda",
		nome = "Esmeralda",
		raridade = "lendario",
		escala = 0,
		destaque = 0x35D07F,
		desenho = {
			"..####..",
			".#....#.",
			"#..##..#",
			"#.#..#.#",
			"#..##..#",
			".#....#.",
			"..####..",
			"........",
		},
	},
	{
		id = "manto_real",
		nome = "Manto Real",
		raridade = "lendario",
		escala = 0,
		cores = { 0xE9B949, 0x8E3FD0 },
		desenho = {
			"..........",
			".1..11..1.",
			".1..11..1.",
			".11.11.11.",
			".11111111.",
			".12112112.",
			".11111111.",
			"..........",
			"....2.....",
			"..........",
		},
	},
}
