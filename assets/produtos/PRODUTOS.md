# Produtos de Robux: o que preencher em cada um

São **14 produtos**, todos já criados (o passe do mês em 12/11/2026). Para cada um: envie a imagem, copie o nome e a descrição, ponha o preço e salve.
Depois me mande o número (ID) de cada produto, assim: `crate = 1234567890`.

**Situação em 11/11/2026: os 13 foram criados e os IDs já estão no jogo** (tabela "IDs" no fim desta
página; `src/shared/Data/MyProducts.luau`). Esta página fica como referência para quando você quiser
trocar um texto, uma imagem ou um preço.

Onde criar: **create.roblox.com → a sua experiência → Monetização → Produtos de desenvolvedor → Criar**.

- **Imagem:** os arquivos estão nesta pasta (`assets/produtos/`), um por produto, já em 512 × 512. O Roblox mostra o ícone dentro de um círculo; o desenho de cada um cabe inteiro nele (veja `_conferencia.png`). São figuras do próprio jogo.
- **Preço:** os oito do Arsenal são os mesmos do RoWorld. Pode mudar à vontade: o jogo mostra o preço que estiver no painel. Se mudar algum, me diga o novo junto com o ID.
- **Nome e descrição:** são livres. O jogo não lê esses textos; eles aparecem na janela de compra do Roblox.

## Arsenal (8 produtos)

| Linha no jogo | Imagem | Nome | Descrição | Preço |
|---|---|---|---|---|
| `unlock_mega` | `unlock_mega.png` | Magia Suprema | Desbloqueia a Magia Suprema para sempre: uma magia com o dobro do raio de uma Bola de Fogo, lançada dos seus Altares Arcanos. | 39 |
| `unlock_stars2x` | `unlock_stars2x.png` | 2x Coroas | Dobra as Coroas que cada partida paga, para sempre. | 59 |
| `unlock_scatter` | `unlock_scatter.png` | Rajada Arcana | Desbloqueia a Rajada Arcana para sempre: uma Bola de Fogo com 4 a 6 centelhas extras que caem ao redor do alvo. | 67 |
| `unlock_artillery` | `unlock_artillery.png` | Catapulta | Desbloqueia a Catapulta para sempre: uma catapulta que atira sozinha em todo inimigo a até 45 blocos. | 99 |
| `unlock_reload2x` | `unlock_reload2x.png` | Recarga Rápida | Seus Altares Arcanos, Escudos Arcanos, Catapultas, Tocas de Dragões e Balistas Arcanas recarregam na metade do tempo, para sempre. | 129 |
| `unlock_reinforce` | `unlock_reinforce.png` | Reforços | Desbloqueia os Reforços para sempre: convoque de uma vez um quinto do seu limite de tropas, pagando ouro da partida. | 149 |
| `unlock_airfield` | `unlock_airfield.png` | Ataque de Dragões | Desbloqueia o Ataque de Dragões para sempre: construa Tocas de Dragões e peça ataques de fogo que nenhum Escudo Arcano consegue parar. | 349 |
| `unlock_railgun` | `unlock_railgun.png` | Balista Arcana | Desbloqueia a Balista Arcana para sempre: sem limite de alcance, e nada intercepta o seu virote. | 999 |

## Baú da Coleção (1 produto só)

| Linha no jogo | Imagem | Nome | Descrição | Preço |
|---|---|---|---|---|
| `crate` | `crate.png` | Baú da Coleção | Um baú da Coleção. Ele abre na hora, na aba em que foi comprado (Skins, Bandeiras ou Pets), e sorteia um item daquela aba. Se vier um item que você já tem, você recebe Coroas no lugar (Comum 2.500, Raro 6.000, Épico 12.000, Lendário 25.000). Chances: Comum 80%, Raro 15%, Épico 4,5%, Lendário 0,5%. | 9 |

**É um produto só para os três baús.** O jogo sabe em qual aba o jogador apertou o botão e abre o baú daquela aba. Não crie um produto para cada baú.

Se um dia você mudar as chances em `MyShop`, mude também essa descrição.

## Loja Misteriosa (4 produtos, um por raridade)

| Linha no jogo | Imagem | Nome | Descrição | Preço |
|---|---|---|---|---|
| `shop_common` | `shop_common.png` | Oferta Comum | Compra o item Comum que você escolheu na Loja Misteriosa (skin, bandeira ou pet). Você recebe exatamente o item mostrado na oferta. | 19 |
| `shop_rare` | `shop_rare.png` | Oferta Rara | Compra o item Raro que você escolheu na Loja Misteriosa (skin, bandeira ou pet). Você recebe exatamente o item mostrado na oferta. | 49 |
| `shop_epic` | `shop_epic.png` | Oferta Épica | Compra o item Épico que você escolheu na Loja Misteriosa (skin, bandeira ou pet). Você recebe exatamente o item mostrado na oferta. | 99 |
| `shop_legendary` | `shop_legendary.png` | Oferta Lendária | Compra o item Lendário que você escolheu na Loja Misteriosa (skin, bandeira ou pet). Você recebe exatamente o item mostrado na oferta. | 199 |

Aqui também é um produto por raridade, não por item: o jogo guarda qual item o jogador escolheu e entrega esse.

## Passe do mês (1 produto)

| Linha no jogo | Imagem | Nome | Descrição | Preço |
|---|---|---|---|---|
| `pass` | `pass.png` | Passe do Mês | Libera os prêmios das missões mensais até o fim deste mês: Coroas e a skin, a bandeira e o pet exclusivos da temporada, que não saem em baú nem na Loja. O progresso que você já fez no mês conta. No dia 1 começa uma temporada nova. | 199 |

- **É um produto de desenvolvedor, não um "Passe de jogo".** O jogador compra de novo a cada mês; um Passe de jogo do Roblox é comprado uma vez só.
- **É um produto só para todos os meses.** O jogo sabe em que mês a compra foi feita. Por isso a imagem não mostra nenhuma temporada.
- O preço (199 Robux) foi escolha sua; a conta está no `GUIA.md`, seção 14. Para mudar: no painel, e repita o número na linha `pass` do `MyProducts`.
- Criado em 12/11/2026, ID 3730557862. Se a linha `pass` ficar com `id = 0`, o botão do passe mostra **EM BREVE**.
- Antes de ligar, leia o aviso sobre o passe pagar Coroas, no `GUIA.md`, seção 14.

## IDs (criados em 11/11/2026)

| Linha no jogo | ID do produto | Preço no painel |
|---|---|---|
| `unlock_mega` | 3730481743 | 39 |
| `unlock_stars2x` | 3730507253 | 59 |
| `unlock_scatter` | 3730507385 | 67 |
| `unlock_artillery` | 3730507497 | 99 |
| `unlock_reload2x` | 3730507641 | 129 |
| `unlock_reinforce` | 3730507879 | 149 |
| `unlock_airfield` | 3730508013 | 349 |
| `unlock_railgun` | 3730508175 | 999 |
| `crate` | 3730508358 | 9 |
| `shop_common` | 3730508466 | 19 |
| `shop_rare` | 3730508616 | 49 |
| `shop_epic` | 3730508724 | 99 |
| `shop_legendary` | 3730508805 | 199 |
| `pass` | 3730557862 | 199 |

Conferido nos dados públicos de cada produto no Roblox (os 13 primeiros em 11/11/2026, o passe em 12/11/2026): os 14 existem, estão à venda, são
da mesma experiência, e o nome e o preço de cada um batem com a linha. Dois detalhes de digitação, sem
efeito na venda: o nome do produto da Rajada Arcana começa com um espaço de tabulação, e as descrições do
baú e da Oferta Lendária terminam com um. Dá para apagar no painel.

## O que eu não conferi

- Não vejo o seu painel. Se o formulário pedir algum campo que não está aqui (por exemplo uma categoria), me diga o que aparece.
- A imagem passa pela moderação do Roblox antes de aparecer para os outros. Não sei quanto tempo leva nem posso garantir que todas sejam aprovadas. Também não testei se o produto já pode ser comprado enquanto a imagem está em análise.
- Para refazer as imagens: `python3 tools/arte/produtos.py`.
