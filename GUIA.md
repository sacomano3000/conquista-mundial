# Conquista Mundial: guia rápido

O jogo usa o **sistema do RoWorld** (regras, partidas, lojas, salas), com um **visual próprio**, de fantasia medieval: cores, ícones, efeitos, logo, mapa e nomes novos. Tem também uma **Coleção** de skins, bandeiras e pets, com caixas e uma **Loja Misteriosa** diária (seção 5). As prévias estão em `assets/`: `previa-do-visual.png` (os desenhos) e `previa-lobby-pc.png`, `previa-colecao-*.png`, `previa-loja-*.png`, `previa-arsenal-*.png` (as telas, no PC e no celular).

> **Importante:** eu não consigo abrir o Roblox Studio daqui. Montei o arquivo, conferi o que tem dentro e rodei os testes automáticos, mas a primeira vez que o jogo roda de verdade é quando você apertar Play. A seção 2 diz o que olhar.

## 1. Abrir e jogar

1. Baixe o arquivo **`ConquistaMundial.rbxl`** desta pasta.
2. Dê dois cliques nele. O Roblox Studio abre com o jogo dentro.
3. Aperte **Play** (ou **F5**).
4. Na tela inicial, clique em **JOGAR SOLO**.

O jogo tem um tutorial e um botão de ajuda (**?**). Quem entra pela primeira vez vê, logo depois da tela inicial, a pergunta **QUER FAZER O TUTORIAL?**, com dois botões: **Sim, quero** (começa a partida de tutorial) e **Não, pular** (fica na tela inicial). A pergunta aparece uma vez só por jogador. Quem quiser fazer (ou refazer) o tutorial depois usa o botão **Fazer o tutorial**, em **Configurações** (a engrenagem), no lobby.

**A tela inicial** tem um fundo pintado (um castelo sobre um vale, ao entardecer) no lugar do mapa que ficava se mexendo. Por cima: o logo e o nome, o botão **JOGAR SOLO**, o cartão do multiplayer e quatro botões (**ARSENAL**, **COLEÇÃO**, **LOJA**, **COMO JOGAR**). No celular os quatro viram quadradinhos ao lado do JOGAR SOLO. O saldo de Coroas fica numa plaquinha no canto de cima, à direita; clicar nela abre o Arsenal.

- O botão **LOJA** agora fica dentro da caixa dos botões, embaixo. Era ele que passava por cima do nome CONQUISTA e saía cortado na borda da tela.
- Para voltar ao mapa se mexendo atrás do título, mude `Brand.LOBBY_ART = true` para `false` (seção 9).
- Para voltar à tela inicial antiga do RoWorld, mude `Brand.LOBBY = "simples"` para `"completo"`.

## 2. O que conferir primeiro

Estas coisas eu não tenho como ver daqui. As telas novas foram montadas e medidas por um teste fora do Roblox (seção 11), mas isso não é o mesmo que ver no Studio. Se alguma estiver diferente, me mande um print:

- **A tela inicial:** o fundo pintado cobre a tela inteira e o mapa não aparece atrás? Os quatro botões cabem? Nenhum botão encosta no nome CONQUISTA nem sai da tela, no PC e no celular?
- **A Coleção** (botão COLEÇÃO): três abas (**Skins**, **Bandeiras**, **Pets**), os itens em grade e, à direita, a caixa daquela aba com as **chances** (Comum 80%, Raro 15%, Épico 4,5%, Lendário 0,5%) e, ao lado de cada uma, quanto paga o item repetido (+2.500, +6.000, +12.000, +25.000), e **dois botões de compra lado a lado**: Robux (9) e Coroas (25.000). É **uma caixa por compra**: não existe mais o seletor de quantidade (− 1 +). Em cima, uma plaquinha mostra como o seu nome aparece na partida, com a bandeira e o pet.
- **Abrir uma caixa:** compre uma com o botão de Coroas (25.000; use `/moedas dar eu 50000` no chat para testar). Antes de gastar, o jogo abre a janela **CONFIRMAR COMPRA?**, com o nome do baú, o preço, quanto você tem e com quanto vai ficar. **Cancelar** (ou clicar fora da janela) não compra nada; **Confirmar** compra. A mesma janela aparece no botão de Coroas do Arsenal. O botão de Robux (9) abre a janela de compra do próprio Roblox, porque o produto `crate` já está ligado (seção 6); no Studio essa compra é de teste e não cobra Robux. O baú cai, abre e mostra o item, com os botões **USAR**, **ABRIR PRÓXIMO** e **PRONTO**. O item pode vir repetido: nesse caso a etiqueta do cartão é **REPETIDO** (dourada), a linha embaixo do nome diz **VOCÊ JÁ TINHA · +N COROAS** e o saldo de Coroas sobe.
- **A Loja Misteriosa** (botão LOJA): seis ofertas do dia, um relógio até a troca e o preço em cada cartão. Apertar um preço em Robux abre a janela de compra do Roblox (os quatro produtos da Loja estão ligados, seção 6) e, depois de paga, a oferta vira o item escolhido.
- **O pet na partida:** escolha um pet na Coleção e entre numa partida. Ele aparece à direita do seu nome no mapa e na lista de jogadores.
- **O Arsenal:** a janela mudou de formato. Agora é larga: em cima, uma **prateleira com os oito itens em cartões** (a figura sobre a cor do item, o nome e o preço); o cartão escolhido ganha borda dourada e uma barrinha embaixo. Na parte de baixo, a prévia animada fica à esquerda e o nome, a descrição e o botão de desbloquear ficam à direita. No topo aparece "1 / 8 DESBLOQUEADOS" ao lado do saldo. Compare com `assets/previa-arsenal-pc.png`.
- **O mapa com o zoom afastado:** numa partida, afaste o zoom até o fim. Em volta do mapa deve aparecer **mar** (azul), não faixas cinzas, e **nenhuma terra cortada em linha reta**: o mapa Eldoria foi redesenhado com mar em toda a volta, então não dá para ver onde ele acaba. No sul, onde havia uma faixa de terra de ponta a ponta, agora há cinco ilhas grandes. Compare com `assets/previa-zoom-afastado.png`. Arrastar o mapa até uma borda também mostra só mar.
- **Os ícones das construções com o zoom afastado:** construa uma Cidade e afaste o zoom até o fim. O ícone diminui até uns 12 pixels e **para de diminuir, sempre com o desenho dentro**. Antes, a partir de certo ponto, ele virava uma bolinha colorida sem desenho. No fim de uma partida cheia, com muitas construções, veja se os ícones não ficam amontoados demais no celular; se ficarem, me avise.
- **Os preços do Arsenal:** com os produtos ligados (seção 6), cada cartão mostra **um** preço. Se você tem Coroas para a habilidade, é o preço em Coroas, em dourado (20K, 40K, 40K, 50K, 200K, 500K). Se não tem, é o preço em **Robux**, com o símbolo do Robux (39, 67, 149, 99, 349, 999). Os dois últimos, **2x Coroas** e **Recarga Rápida**, mostram sempre Robux (59 e 129). Na página de uma habilidade aparecem os dois caminhos: o botão verde **COMPRAR** com o preço em Robux e, embaixo, **OU DESBLOQUEIE COM** e o preço em Coroas (ou a barra de quanto falta). A página de um bônus tem só o botão de Robux e a frase **Somente com Robux**. Compare com `assets/previa-arsenal-pc.png`. Um jogador novo, sem Coroas, vê portanto os oito cartões com preço em Robux; o preço em Coroas fica na página do item. Se preferir o preço em Coroas sempre no cartão, me peça.
- **Clique atravessando janela:** abra o Arsenal (e depois a Coleção e a Loja) e clique em vários pontos de dentro da janela, principalmente onde, atrás dela, ficam JOGAR SOLO e os botões da tela inicial. Nada atrás pode reagir e nenhuma partida pode começar. Se ainda acontecer, me diga em qual janela e em que ponto você clicou.
- **A pergunta do tutorial:** aparece cerca de um segundo depois da tela inicial, só para quem nunca jogou. Nada começa sozinho antes da resposta. **Sim, quero** abre o tutorial; **Não, pular** fecha a janela e a pergunta não volta. Com a pergunta aberta, os botões de trás não reagem. Sua conta provavelmente já jogou e por isso não vai ver a pergunta: para ver, use no Studio **Test → Clients and Servers → Start** (os jogadores de teste não têm nada salvo) ou uma conta que nunca entrou no jogo.
- **O dragão do ataque:** no Arsenal, o cartão do **Ataque de Dragões** mostra o dragão de lado (o emblema que você enviou). Na prévia animada desse item e numa partida, quando um Ataque de Dragões é lançado, quem voa é o **dragão visto de cima**, com a cabeça virada para onde ele está indo. Se na partida aparecer um míssil pequeno no lugar do dragão, ou o dragão voar de lado ou de costas, me avise.
- **O botão RANK:** na tela inicial, em cima e à direita, fica à esquerda do saldo de Coroas (no celular é só o troféu, sem a palavra). Ele abre a janela **RANKING** com duas abas, **VITÓRIAS** e **REINOS DESTRUÍDOS**. Clicar fora da janela ou no X fecha. O saldo de Coroas ao lado continua abrindo o Arsenal. No Studio as listas começam vazias ("Ainda não há ninguém nesta lista"): isso é o esperado (seção 3, "O ranking"). Compare com `assets/previa-rank-vitorias-pc.png` e `previa-lobby-pc.png`.
- **O botão ADMIN e o painel do dono:** na tela inicial, em cima e à direita, à esquerda do botão MISSÕES, aparece o botão **ADMIN** (no celular, só a engrenagem). Ele demora um ou dois segundos para aparecer depois que a tela abre. Abre o **PAINEL DO DONO**, com três páginas: **COROAS**, **CÓDIGOS** e **RANKING** (seção 8). No Studio todo mundo que testa vê o botão; para conferir que os outros jogadores não veem, entre no jogo publicado com outra conta.
- **A barra de baixo no celular:** no emulador de celular do Studio (**Test → Device**), a barra da tela inicial tem no máximo 640 de largura e fica no meio, sem encostar nas bordas num celular grande. As prévias estão em `assets/previa-lobby-celular*.png`.
- **O botão que saiu:** nas Configurações e no menu da partida não existe mais "Replay as new player".
- **O chat do Roblox:** o arquivo agora usa o chat novo do Roblox (TextChatService). A janela do chat deve aparecer **por cima** do fundo da tela inicial, e o aviso amarelo "O sistema de bate-papo antigo está sendo descontinuado" no item **Chat** do Explorer não deve mais aparecer. Teste também digitar `/moedas ver eu` no chat.
- **A barra de Ataque (a % de tropas):** numa partida, escolha 75% e mande um ataque. Com a trava do jogador novo ligada (seção 3; no Studio ela vale na primeira partida de cada teste), o ataque deixa 20% do limite de tropas em casa e a linha embaixo da barra passa a dizer **"Poucas tropas. Deixe recuperar"** até o exército crescer, **não "Envia 0 tropas"**. A % escolhida continua marcada. Quando o exército cresce, a linha volta a mostrar o número. A barra tem cinco paradas (10, 25, 35, 50 e 75%); dá para clicar numa delas ou arrastar.
- **A contagem das habilidades:** deixe o mouse parado em cima de um botão que está recarregando (Reforços depois de usar, por exemplo). O cartão que aparece mostra "Pronto em 0:12" e o número deve descer sozinho, sem precisar tirar o mouse e voltar.
- **Textos em português:** o cartão do multiplayer deve dizer "6 Equipes · 0 / 30 jogadores". Se achar qualquer texto em inglês, me mande a frase ou um print.
- **Os números:** os saldos aparecem com ponto (31.250) em todas as telas.
- **O campo de código:** clique na engrenagem (Configurações). Deve haver uma linha "Código de resgate" com o botão **RESGATAR**. Digite `BEMVINDO`: você ganha 5.000 Coroas e aparece um aviso verde. Digite de novo: "Você já usou esse código."
- **Criar um código pelo chat:** no chat, digite `/codigo criar TESTE 1000`. Deve aparecer o aviso "Código TESTE criado: 1.000 Coroas, sem validade, sem limite de usos." e a mesma frase deve ficar escrita no chat, só para você. Depois resgate `TESTE` nas Configurações: entram 1.000 Coroas. Digite `/codigo gerar 500 1x` e veja se o código sorteado aparece no aviso e no chat. `/codigo lista` mostra os dois e `/codigo apagar TESTE` apaga. Confira também se a frase que você digitou **não** aparece no chat como mensagem comum. No Studio isso precisa de **Enable Studio Access to API Services** ligado (seção 8).
- **Os ícones novos aparecem?** Espadas cruzadas no ataque, castelo na cidade, âncora com corda no porto, dragão, catapulta. Se aparecer algum desenho de guerra moderna (avião, foguete, bomba), ou se as bandeiras, os pets e o fundo da tela inicial ficarem vazios, o Studio não deixou o jogo desenhar as imagens: veja a seção 4.
- **As cores estão em grafite e vermelho?** Se sobrar algum painel azul-marinho, me diga em qual tela.
- **O mapa é Eldoria?** Vários continentes e ilhas, com reinos de nomes inventados.
- **Os sons e a música (novos, seção 13):** eu não consigo ouvir nada daqui, então esta é a conferência mais importante desta vez. Abra o jogo e veja: toca música na tela inicial? Ela muda ao entrar numa partida e quando começa uma guerra? Os cliques, o baú, a contagem e os avisos tocam? **Algum som não toca?** (me diga qual: seção 13 mostra como achar o nome). **Algum ainda está alto ou ficou baixo demais?** Cada som tem o seu próprio ajuste e é rápido mexer.
- **O volume dos efeitos:** nas Configurações (engrenagem) há agora duas barras, **Música** e **Efeitos**, cada uma com a sua porcentagem. Arraste **Efeitos**: cada passo dá um clique no volume novo, e a música não muda. Arraste **Música**: os efeitos não mudam. Saia do jogo e entre de novo: as duas porcentagens devem voltar como você deixou (no Studio isso precisa de **Enable Studio Access to API Services**). Compare com `assets/previa-config-pc.png` e `previa-config-celular.png`.
- **O botão de música:** com a música ligada, a fileira de botões do canto de cima, à esquerda, ganhou o botão da nota musical (no PC; a tecla **M** faz o mesmo). Veja se ele não encosta em nada na tela inicial.

Se aparecer erro, abra a janela **Saída** (Output) pelo menu **Janela** do Studio, copie o texto em vermelho e me mande.

## 3. O que este jogo tem de próprio

| O quê | Como ficou |
|---|---|
| **Cores** | Grafite e preto nos painéis, vermelho nos botões principais e no título. |
| **Ícones e efeitos** | 120 imagens novas no lugar das do RoWorld: os ícones da interface e do Arsenal, as oito figuras do Arsenal, as placas e os desenhos das estruturas no mapa, os barcos e projéteis, os ícones de estado, os efeitos (explosões, fogo, fumaça, bandeira da conquista), a estrada, as luzes do baú, o logo e a miniatura do mundo. |
| **Tela inicial** | Fundo pintado, nome, JOGAR SOLO, multiplayer e quatro botões (seção 1). |
| **Coleção** | 36 skins de território, 80 bandeiras próprias e 24 pets (140 itens). Uma caixa para cada tipo, com as chances à mostra; item repetido vira Coroas (seção 5). |
| **Loja Misteriosa** | Seis ofertas por dia, compradas direto, sem sorteio. Ficou no lugar da loja de bandeiras do RoWorld (seção 5). |
| **Arsenal** | Janela com formato próprio: prateleira de cartões em cima, prévia e compra embaixo. |
| **Ranking** | Botão RANK na tela inicial: os 100 jogadores com mais vitórias e os 100 com mais reinos destruídos no multiplayer (logo abaixo, "O ranking"). |
| **Missões e passe do mês** | Botão MISSÕES na tela inicial: três missões por dia, de graça, que pagam Coroas; e o passe do mês, comprado com Robux, com missões longas que pagam Coroas e a skin, a bandeira e o pet da temporada (seção 14). |
| **Códigos de resgate** | Um campo nas Configurações; a lista de códigos é sua (seção 8). |
| **Mapa** | Um mundo inventado, **Eldoria**: 6 continentes, cinco ilhas grandes no sul, mais de 160 ilhas menores, 71 reinos, mar em toda a volta. Os mapas da Terra e dos continentes reais saíram. |
| **Nomes** | Tema de fantasia medieval (tabela abaixo). |
| **Logo** | Escudo vermelho com espadas e coroa, em `assets/icones/logo.png`. Para o ícone do jogo no Roblox há uma versão própria, maior e com o mapa ao fundo: `assets/pagina/icone.png` (seção 10). |
| **Créditos** | Saíram os do RoWorld, dos mapas, das bandeiras e da música. Fica só o aviso que a licença exige (seção 7). |
| **Robux** | Os itens do Arsenal, as caixas, as ofertas da Loja e o passe do mês são vendidos por Robux, pelos 14 produtos criados na sua experiência (seção 6). Os dois bônus do Arsenal (2x Coroas e Recarga Rápida) são vendidos **só** por Robux. |

Nomes de fantasia (você pode mudar qualquer um no dicionário, seção 9):

| Antes | Agora |
|---|---|
| Bomba Atômica, Bomba de Hidrogênio, MIRV | Bola de Fogo, Tempestade de Fogo, Chuva de Meteoros |
| Mega Bomba, Rajada | Magia Suprema, Rajada Arcana |
| Silo de Mísseis, Lançador SAM | Altar Arcano, Escudo Arcano |
| Artilharia, Railgun | Catapulta, Balista Arcana |
| Base Aérea, Ataque Aéreo | Toca dos Dragões, Ataque de Dragões |
| Fábrica, Posto de Defesa, Navio de Guerra | Forja, Forte, Drácar |
| Radiação | Maldição (terra amaldiçoada) |

**O sistema não mudou:** as regras, os números e o comportamento de cada arma são os mesmos. Só o nome e o desenho são outros.

### O ranking

O botão **RANK** abre uma janela com dois ranks, cada um com as mesmas duas listas, e um quadro de campeões:

- **RANK MUNDIAL:** vale desde o primeiro dia do jogo e nunca zera.
- **RANK SEMANAL:** começa do zero toda **segunda-feira à 00:00** (horário de Brasília) e fecha no domingo às 23:59. Paga prêmios (veja "Os prêmios da semana", logo abaixo).
- **CAMPEÕES:** os 3 primeiros de cada lista na semana passada, com a insígnia que eles usam nesta semana.

| Aba | O que soma |
|---|---|
| **VITÓRIAS** | 1 ponto por partida multiplayer vencida. Quem sai antes do fim não ganha a vitória. |
| **REINOS DESTRUÍDOS** | 1 ponto por reino que o jogador eliminou numa partida multiplayer. Reinos de bots contam; tribos não contam. |

- **Só o multiplayer conta.** JOGAR SOLO e o tutorial não somam nada.
- Cada lista mostra os **100 primeiros**: posição, rosto, nome e número. Os três primeiros aparecem em ouro, prata e bronze, e a linha do próprio jogador ganha contorno dourado.
- Embaixo fica a linha fixa **VOCÊ**, com o número do jogador e a posição dele. Quem está fora dos 100 vê o número e "Fora do top 100".
- **A lista não é ao vivo.** Cada servidor relê as listas a cada 2 minutos, e a janela pede de novo a cada minuto enquanto está aberta. Depois de uma partida, o número do próprio jogador (linha VOCÊ) aparece em até um minuto; a posição dele na lista pode levar alguns minutos.
- Os reinos destruídos são somados mesmo que o jogador saia da partida depois; a vitória, não.
- **No Studio** o ranking usa listas separadas, só de teste, para não sujar o ranking de verdade. Sem "Enable Studio Access to API Services" ligado (seção 10), elas ficam só na memória e somem ao fechar o teste.
- **Zerar o ranking inteiro:** em **ServerScriptService → ConquistaServer → Ranking**, troque os nomes em `Ranking.STORES` (`RankVitorias_v1` e `RankReinos_v1`) para `_v2` e publique. As listas antigas ficam guardadas no Roblox, só deixam de ser usadas.
- Não existe ainda um comando para tirar um jogador do ranking (um trapaceiro, por exemplo). Se precisar, me peça.

#### Os prêmios da semana

Quando a semana fecha, os 10 primeiros de **cada uma das duas listas** do Rank Semanal ganham Coroas. Quem está nas duas listas ganha pelas duas.

| Posição | 1º | 2º | 3º | 4º | 5º | 6º | 7º | 8º | 9º | 10º |
|---|---|---|---|---|---|---|---|---|---|---|
| Coroas | 1.000 | 700 | 500 | 300 | 250 | 200 | 150 | 120 | 100 | 80 |

Para comparar: uma partida pública paga 100 Coroas por jogar, 54 por reino destruído e 18 por minuto de uma vitória (algumas centenas no total), e uma caixa custa 25.000. O prêmio é pequeno de propósito. Somando as duas listas, o jogo distribui 6.800 Coroas por semana.

**As Coroas são resgatadas, não chegam sozinhas** (mudou em 12/11/2026):

1. Na segunda-feira, quem ganhou vê uma **marca vermelha com "!"** no canto esquerdo do botão **RANK** do lobby, e um aviso como "Rank Semanal: você ficou em 1º em Vitórias e 2º em Reinos destruídos. Abra o RANK e resgate 1700 Coroas."
2. Dentro da janela do RANK aparece, no topo, uma faixa dourada com o valor e o botão **RESGATAR**. Ela aparece em qualquer uma das três abas de cima.
3. Apertar RESGATAR soma as Coroas ao saldo. A faixa e a marca somem.

- **Só quem ganhou vê o botão.** Para os outros jogadores não existe faixa, botão nem marca.
- **Prazo para resgatar: 2 semanas.** O prêmio de uma semana pode ser resgatado na semana seguinte e na outra. Depois disso ele some sem ser pago. Quem tem prêmio de duas semanas resgata os dois de uma vez, e a faixa diz "Prêmios de 2 semanas".
- **Cada prêmio é pago uma vez só,** mesmo que o jogador aperte duas vezes, troque de servidor ou entre e saia: a ficha dele guarda o que já foi resgatado.
- Os servidores esperam 10 minutos depois da meia-noite de segunda antes de anotar os prêmios, para as últimas partidas de domingo entrarem na conta. Quem já está no lobby nessa hora recebe a marca sem precisar sair e entrar.

**A insígnia** (escudo com coroa: ouro para o 1º, prata para o 2º, bronze para o 3º):

- Os **3 primeiros** de cada lista usam a insígnia durante **toda a semana seguinte**, de segunda a domingo. Ela **não precisa ser resgatada**: aparece sozinha na segunda-feira.
- **Na segunda seguinte ela troca de dono.** Vai para os 3 primeiros da semana que acabou de fechar. Para continuar com ela, o jogador precisa ficar no top 3 de novo, toda semana. Quem caiu do 1º para o 2º lugar passa do ouro para a prata.
- Quem ficou no top 3 das duas listas usa a da melhor posição.
- Ela **não se compra** nem sai de caixa.
- **Onde os outros jogadores veem:** ao lado do nome, em todo lugar onde o nome aparece.

| Lugar | Como aparece |
|---|---|
| Mapa da partida | ao lado do nome do reino |
| Lista de jogadores da partida | à direita do nome |
| Cartão do alvo (ao clicar no território de alguém) | depois do nome |
| Escolha da posição inicial | no canto do rosto do jogador |
| Fim da partida | depois do nome do vencedor ou do líder |
| Grupo do lobby | depois do nome, na lista de membros e na lista de convites |
| Janela do RANK | antes do nome, em todas as listas, e na linha VOCÊ |
| Chat | uma etiqueta colorida **[TOP 1]**, **[TOP 2]** ou **[TOP 3]** antes do nome (o chat do Roblox não aceita imagem) |

- **O que a insígnia quer dizer:** parando o mouse em cima dela (no celular, tocando), aparece um cartão: "1º em Vitórias na semana passada". No mapa, no rosto da posição inicial e no chat não há cartão.
- **Quadro dos campeões:** a janela do RANK tem uma terceira aba em cima, **CAMPEÕES**, com os 3 primeiros de Vitórias e os 3 primeiros de Reinos destruídos da semana passada, cada um com a insígnia.

Outros detalhes:

- A janela mostra, no Rank Semanal, a faixa **PRÊMIOS DA SEMANA** (os valores, quanto tempo falta e, no PC, o último prêmio que o jogador resgatou).
- A primeira semana que conta é a de **9 a 15/11/2026**. Os primeiros prêmios e as primeiras insígnias saem na segunda, 16/11.
- **Empate:** quem tem o mesmo número fica na ordem que o Roblox devolver a lista. O jogo não tem critério de desempate.
- **Mudar os valores, o prazo ou desligar:** **ReplicatedStorage → Conquista → Data → RankPrizes** (`COROAS`, uma linha por posição; `BADGE_PLACES = 3`; `CLAIM_WEEKS = 2`, o prazo para resgatar). Para desligar o Rank Semanal inteiro: **ServerScriptService → ConquistaServer → Ranking**, `Ranking.WEEKLY_ON = false` (os botões RANK SEMANAL e CAMPEÕES continuam na janela, com as listas vazias, e a faixa de prêmios some).
- **No Studio** o Rank Semanal também usa listas de teste separadas.

### A trava de tropas do jogador novo (ligada)

Na **primeira partida** de cada jogador, o jogo segura 20% do limite de tropas em casa, para o jogador novo não gastar o exército inteiro e perder nos primeiros minutos. No RoWorld eram as 5 primeiras partidas; você pediu 1 em 12/11/2026.

- **A partida do tutorial não conta.** Quem faz o tutorial tem a trava na primeira partida depois dele. Quem recusa o tutorial tem a trava na primeira partida que jogar. Jogar o tutorial de novo (botão nas opções) não gasta nem devolve a trava.

- Enquanto a trava vale, um ataque que deixaria o exército abaixo dos 20% é **cortado**: vai só o que está acima da trava, e a linha embaixo da barra de Ataque mostra esse número, que é menor que a % escolhida.
- Quando o exército está na trava, nada é enviado até ele crescer de novo. A linha embaixo da barra diz **"Poucas tropas. Deixe recuperar"** (antes dizia "Envia 0 tropas", que parecia defeito). A % escolhida continua marcada.
- A partir da 2ª partida a trava some: o ataque manda sempre a % escolhida das tropas que o jogador tem.
- **No Studio a trava vale na primeira partida de cada teste**, porque o teste do Studio não guarda quantas partidas você já jogou. Para ver o jogo sem a trava no Studio, jogue uma segunda partida sem parar o teste.
- Para desligar: **ReplicatedStorage → Conquista → Data → Tutorial**, troque `Tutorial.ROOKIE_FLOOR_ON = true` por `false`.
- Para mudar quantas partidas: na mesma página, `Tutorial.ROOKIE_MATCHES` (hoje 1). Para mudar o tamanho: `Tutorial.ROOKIE_FLOOR` (0.2 = 20%).
- O **tutorial** tem a trava dele, que não depende dessa linha (25% do limite fica em casa e a barra para em 50%), porque os passos do tutorial contam com isso.

## 4. Os ícones e o mapa

### Como os ícones aparecem

Uma imagem só pode ser enviada ao Roblox pela conta dona do jogo, e eu não tenho como enviar pela sua. Então os 152 desenhos ficam guardados **dentro do código** e o jogo desenha cada um na hora, sem nada enviado. Para isso o Studio precisa da opção **Allow Mesh / Image APIs** ligada (seção 10), a mesma que o mapa de territórios já usa.

- Se o jogo não conseguir desenhar (opção desligada, ou um aparelho sem memória para isso), ele mostra a imagem antiga do RoWorld no lugar, sem dar erro. As exceções são o logo, que fica escondido, e as bandeiras, os pets e o fundo da tela inicial, que não têm imagem antiga e ficam vazios. **É o único caso em que um desenho antigo ainda pode aparecer.** Para acabar com ele de vez, envie os PNG pela sua conta (item abaixo).
- **Se preferir usar imagens enviadas** (carregam como qualquer imagem do Roblox): veja o passo a passo logo abaixo, em **Enviar os ícones pela sua conta**. É opcional.
- Para voltar aos ícones do RoWorld: em `Brand`, mude `Brand.OWN_ICONS = true` para `false`.

### Enviar os ícones pela sua conta (opcional)

**Você não precisa fazer isto para o jogo funcionar.** O jogo já desenha os 152 desenhos sozinho. Enviar serve para duas coisas: os desenhos passam a carregar como qualquer imagem do Roblox (sem depender da opção **Allow Mesh / Image APIs**), e some o último caso em que uma imagem antiga do RoWorld poderia aparecer (quando o jogo não consegue desenhar num aparelho).

O que é "enviar": cada imagem que um jogo do Roblox mostra precisa estar guardada na conta de alguém no Roblox. Ao enviar um PNG, o Roblox devolve um **número (ID)** dessa imagem. O jogo usa o número, não o arquivo. Só a conta dona do jogo pode enviar imagens para ele, e por isso eu não consigo fazer esta parte daqui.

1. **Baixe a pasta `assets/icones/`** para o seu computador (são 152 arquivos PNG).
2. **Abra o jogo no Studio** (o jogo publicado, não só o arquivo solto).
3. **Abra o Gerenciador de recursos** (em inglês, **Asset Manager**): menu **Exibir** (View) → **Gerenciador de recursos**.
4. **Clique no botão de importar em massa** (a setinha para cima, **Bulk Import**), selecione todos os PNG da pasta e confirme. O Studio envia um por um e mostra uma lista com o resultado.
   - O Roblox passa cada imagem pela **moderação**. Pode levar alguns minutos, e alguma pode ser recusada.
   - Contas novas têm um limite de envios por mês. Se o Studio parar no meio com aviso de limite, continue outro dia: dá para fazer aos poucos.
5. **Copie o ID de cada imagem:** no Gerenciador de recursos, abra a pasta **Imagens**, clique com o botão direito numa imagem e escolha **Copiar ID para a área de transferência** (Copy ID to Clipboard).
6. **Escreva o ID na lista do jogo:** no Explorer, abra **ReplicatedStorage → Conquista → Assets → OwnArtIds**. Cada linha é um desenho. O nome da linha é o nome do arquivo, trocando o primeiro `_` por `/`:

   | Arquivo | Linha em OwnArtIds |
   |---|---|
   | `icons_attack.png` | `["icons/attack"] = "",` |
   | `map_city.png` | `["map/city"] = "",` |
   | `badge_1.png` | `["badge/1"] = "",` |

   Cole o número entre as aspas, com `rbxassetid://` na frente: `["icons/attack"] = "rbxassetid://1234567890",`
7. **Teste** (Play) e **publique**.

- **Linha vazia continua desenhada pelo jogo.** Dá para enviar só alguns e deixar o resto como está.
- **Cuidado:** o que você escreve no Studio some quando você abre um `.rbxl` novo que eu mandar. Me mande a lista dos IDs aqui na conversa (pode ser um print ou o texto do script) e eu gravo no código, para ficar em todas as versões seguintes.
- Os exemplos de nome acima são para mostrar a regra; confira o nome exato de cada linha no próprio script `OwnArtIds`, que lista as 152.
- **Não conferi os nomes dos botões do Studio em português.** Escrevi os nomes em inglês ao lado porque eles mudam de uma versão do Studio para outra. Se não achar algum, me mande um print da tela.
- São 152 imagens e copiar os IDs à mão é demorado. Se você quiser, eu preparo um arquivo `.bat` como o de publicar, que envia tudo com a sua chave de API e já devolve a lista pronta.

### O que mudou nesta rodada

- **As oito figuras do Arsenal** agora são medievais: bola de fogo com runa (Magia Suprema), cinco raios violeta (Rajada Arcana), três elmos (Reforços), catapulta, dragão vermelho (Ataque de Dragões), canhão de bronze com runas (Canhão Arcano), duas coroas (2x Coroas) e ampulheta (Recarga Rápida). Elas aparecem em todas as telas que mostravam as fotos de armas modernas: o Arsenal, as prévias, a oferta inicial e a vitrine.
- **Os efeitos das prévias do Arsenal:** a bomba virou pedra em chamas, o míssil virou raio de fogo, o paraquedas virou um par de asas, o cogumelo atômico virou um pilar de fogo, o traçante virou flecha em chamas, a mira virou um círculo de runa. O chão das prévias mostrava pedaços da Europa; agora mostra pedaços de Eldoria.
- **Os efeitos do mapa** (explosões, bandeira da conquista, fogo, fumaça) foram redesenhados em pixel art, e os trilhos viraram uma **estrada de pedra**.
- **As luzes do baú** (raios, brilho, anel, feixe) também são desenhos novos.
- As pastas com a arte antiga do RoWorld (`assets/arsenal`, `map_sprites`, `ui_icons`, `branding`, `map_fx`, `rails`, `crate`, `globe`, `icons_src`) foram apagadas, junto com os programas que as geravam.

### O que ainda vem do RoWorld

- **Os padrões de território** (as 36 skins: listras, xadrez, tijolos). São desenhos de quadradinhos feitos no código, sem imagem. Você pode criar os seus (seção 5).
- **Nenhuma imagem.** Desde 12/11/2026 as 31 que ainda eram usadas direto foram trocadas:
  - **O baú em 3D** da abertura de caixas era um modelo de outro jogo (duas malhas e uma textura). Agora é um baú **feito de 18 blocos comuns** do Roblox: madeira, duas cintas de ferro, fecho dourado. Não usa malha nem textura de ninguém. **Ele ficou diferente do anterior** (mais quadrado, com a tampa em degraus). A prévia está em `assets/previa-bau.png`.
  - **As 27 formas da interface** (15 sombras de painel, o anel de carregando, as 5 folhas do menu circular, os 3 degradês da tela inicial e do fim de partida, o brilho redondo e a ponta da seta) foram redesenhadas com as mesmas medidas e entram pelo mesmo caminho dos ícones (veja "Como os ícones aparecem"). A ponta da seta mudou de desenho (agora é uma ponta de flecha); as outras ficaram iguais às antigas.
  - **A folha de prévia das skins antigas** não era usada por nenhuma tela e foi apagada.
- **O que continua valendo:** os números das imagens do RoWorld ainda estão escritos no código, porque é por eles que o jogo sabe qual desenho próprio pôr em cada lugar. Se o Roblox não conseguir criar um desenho (falta de memória num celular fraco, ou "Allow Mesh / Image APIs" desligado), aparece a imagem do RoWorld naquele lugar, menos o logo, que nunca aparece. As 5 folhas do menu circular são as maiores (cerca de 3,7 MB de memória cada, criadas só quando o menu abre).
- **Os sons** não entram nessa conta: são 61 arquivos de áudio (seção 13).
- 40 dos ícones pequenos foram desenhados por código, com formas simples. As estruturas, as 8 figuras do Arsenal, 9 dos pets e o fundo da tela inicial são ilustrações feitas para o jogo.

As bandeiras de países reais saíram: as 80 bandeiras da Coleção são estandartes próprios (partidos, cruzes, brasões com dragão, grifo, castelo, coroa).

### Refazer os desenhos

Tudo sai de programas em `tools/arte/`: `efeitos.py` (efeitos, estrada, luzes), `glifos.py` (ícones), `cosmeticos.py` (as bandeiras, os pets e o fundo da tela inicial; os pets e o fundo a partir de `assets/gerados/`), `mapas_do_arsenal.py` (o chão das prévias) e `make_arsenal_icons.py` (as oito figuras, a partir de `assets/arsenal-icons/`). Depois de mudar qualquer um, rode `python3 tools/arte/make_own_art.py` e monte o jogo de novo.

**Trocar uma imagem não é só trocar o PNG.** Os PNGs de `assets/icones/` (por exemplo `render_airfield.png`) são cópias para você ver: o jogo não lê esses arquivos. Cada desenho fica guardado dentro do código, e por isso editar o PNG, na pasta ou no Studio, não muda nada na tela. O caminho é: mandar a imagem nova para mim (fundo transparente ou branco liso) dizendo qual ela substitui, e eu refaço o código e o `.rbxl`.

**O Ataque de Dragões tem duas imagens**, as duas enviadas por você:

| Onde aparece | Arquivo de origem | Cópia em `assets/icones/` |
|---|---|---|
| O cartão do Arsenal (e o canto da prévia, a oferta inicial, a vitrine) | `assets/arsenal-icons/airfield.png` (o dragão de lado) | `render_airfield.png` |
| O dragão que voa: na prévia animada do Arsenal e no ataque durante a partida | `assets/ataque/airfield.png` (o dragão visto de cima) | `attack_airfield.png` |

A imagem do ataque precisa estar **com a cabeça para a esquerda** e de fundo transparente: o jogo gira o desenho na direção do voo contando com isso. Na partida ele aparece com as cores do desenho (não muda de cor conforme o jogador); o rastro e o círculo do alvo continuam na cor de quem atacou. Antes, o ataque na partida era o desenho pequeno de um míssil.

### O mapa com o zoom afastado

Os dois ajustes ficam em **StarterPlayer → StarterPlayerScripts → ConquistaClient → Map**:

- **A cor em volta do mapa:** no script `MapSurface`, a linha `MapSurface.OUTSIDE = ...`. Hoje é o azul do mar aberto do próprio mapa, para o mar continuar sem emenda. Para outra cor, troque a linha por `MapSurface.OUTSIDE = Color3.fromRGB(vermelho, verde, azul)` com números de 0 a 255. O cinza de antes era `Color3.fromRGB(60, 60, 60)`.
- **O tamanho mínimo dos ícones das construções:** no script `StructureZoom`, a linha `StructureZoom.MIN_SCALE = 0.4` (0,4 de 30 pixels, ou seja, 12 pixels). Um número maior deixa os ícones maiores com o zoom afastado, e mais amontoados. Para voltar às bolinhas sem desenho do RoWorld, troque `StructureZoom.DOTS_ZOOM = 0.0` por `1.2`.
- O zoom mais afastado continua mostrando o mapa inteiro com uma margem. A borda do mapa não aparece porque **nenhuma terra de Eldoria chega perto dela**: a mais próxima fica a 43 quadrados, e toda a borda é mar aberto, da mesma cor do mar em volta.

**O que mudou em Eldoria para isso** (o mapa do RoWorld foi a referência: nele as laterais são quase só mar, mas a Antártida ainda termina em linha reta embaixo; aqui nem isso):

- A faixa de terra que ocupava a borda de baixo inteira virou **cinco ilhas frias**, com mar embaixo delas. Os três reinos de lá (Borealia, Kryovar e Nevasca) continuam, um em cada uma das três maiores.
- As ilhas que eram cortadas pelas laterais foram trazidas para dentro e agora aparecem inteiras.
- Os continentes do meio são os mesmos, com as mesmas costas. **62 dos 71 reinos ficaram exatamente no mesmo lugar.** Os outros 9 estavam em terra que saiu e foram postos de novo: Aurelia, Brancavia e Zefira nas ilhas das laterais, Hartwyn na ponta noroeste do continente do oeste, os três do sul nas ilhas novas, Corvanth na ilha de Ardenmor e Mirandel no continente de Kormund.
- O mundo ficou com um pouco menos de terra: 577.814 quadrados no lugar de 650.170 (29% do mapa no lugar de 32,5%).

O mapa novo com os nomes dos reinos está em `assets/mundo/previa-do-mundo.png`.

### Trocar o mapa

O mundo sai de `tools/maps/make_fantasy_world.py`. Rodar com outro número em `--seed` cria outro mundo (sempre com mar em toda a volta), e os nomes dos reinos estão na lista `NAMES` do mesmo arquivo. As cinco ilhas do sul estão na lista `SOUTH` (posição e tamanho de cada uma), e a distância mínima entre a terra e a borda é `EDGE`. Depois de rodar, rode também `python3 tools/arte/make_own_art.py`, que redesenha a miniatura do mapa e os fundos das prévias do Arsenal. `tools/maps/make_maps.py` é o gerador antigo, da Terra real: se rodar, ele põe o mapa real de volta.

## 5. Coleção, caixas e Loja Misteriosa

**A Coleção** guarda três tipos de item, cada um na sua aba:

| Aba | Quantos | Onde aparece |
|---|---|---|
| **Skins** | 36 | O padrão desenhado por cima do território do jogador |
| **Bandeiras** | 80 | À esquerda do nome do jogador, no mapa e na lista de jogadores |
| **Pets** | 24 | À direita do nome do jogador, no mapa e na lista de jogadores |

Todo jogador começa com a Coleção vazia. Quem já tinha um save da versão anterior, em que tudo era de graça, também começa vazio (uma vez só); as Coroas, o Arsenal e os códigos usados continuam.

**As caixas.** Cada aba tem a sua caixa, que sorteia um item daquela aba. O jogador vê as chances antes de comprar: Comum 80%, Raro 15%, Épico 4,5%, Lendário 0,5%. Dentro da raridade sorteada, todos os itens têm a mesma chance.

**Item repetido vira Coroas (desde 12/11/2026).** A caixa pode sortear um item que o jogador já tem. Quando isso acontece, ele não ganha o item de novo: recebe Coroas, conforme a raridade.

| Raridade do item repetido | Coroas |
|---|---|
| Comum | 2.500 |
| Raro | 6.000 |
| Épico | 12.000 |
| Lendário | 25.000 |

- **Onde o jogador vê isso:** o cartão da caixa mostra, ao lado de cada chance, quanto paga o repetido daquela raridade (coluna **REPETIDO PAGA**), e o texto diz que item repetido vira Coroas. Na abertura, o item repetido aparece com a etiqueta **REPETIDO** (dourada, no lugar de **NOVO!**) e a linha **VOCÊ JÁ TINHA · +2.500 COROAS**.
- **As chances não mudam mais conforme o que o jogador tem.** São sempre 80 / 15 / 4,5 / 0,5.
- **Quem já tem todos os itens de uma aba não consegue comprar a caixa daquela aba.** Os botões somem e aparece o aviso de que ele já tem tudo. Sem isso a caixa viraria só uma troca de Robux por Coroas.
- **O repetido nunca paga a caixa seguinte.** Com tudo repetido, a média é de 3.565 Coroas por caixa, 14% do preço de 25.000. O jogo também não aceita um valor de repetido maior que o preço da caixa em Coroas.
- **As Coroas do repetido não entram no ranking** nem contam como Coroas ganhas jogando, e não são dobradas pelo 2x Coroas.
- **Para mudar os valores ou desligar:** `MyShop`, linhas `repetidos = true` e `coroas_repetido`. Com `repetidos = false` a caixa volta a nunca repetir, como era antes.

**O que isso muda na conta da coleção.** Antes, cada caixa era um item novo: 84 caixas fechavam a coleção. Agora os primeiros itens vêm rápido e os últimos demoram muito, porque quase tudo o que sai passa a ser repetido. Números do catálogo atual (140 itens), calculados por simulação:

| Aba | Itens | Itens diferentes depois de 25 caixas | depois de 100 | depois de 500 | Caixas para completar (média) |
|---|---|---|---|---|---|
| Skins | 36 | 13 | 22 | 31 | 2.916 |
| Bandeiras | 80 | 20 | 49 | 74 | 2.289 |
| Pets | 24 | 12 | 18 | 23 | 1.075 |

- Um Lendário qualquer sai, em média, a cada 200 caixas. **Um Lendário específico** sai a cada 1.200 caixas em Skins, 1.000 em Bandeiras e 600 em Pets.
- Completar as três abas só com caixas leva em média umas 6.300 caixas (56.500 Robux a 9 cada). Na prática ninguém fecha a coleção pela caixa: os últimos Lendários vêm da Loja Misteriosa, a 199 Robux cada. A coleção inteira pela Loja custa 8.630 Robux.
- Uma caixa de 9 Robux devolve no máximo 3.565 Coroas em média, ou 396 Coroas por Robux. É menos do que o jogo já devolve em outras compras repetidas (500 Coroas por Robux), então a caixa não é um jeito barato de juntar Coroas.

**Uma caixa por compra.** Não dá para comprar várias de uma vez. A caixa comprada abre na hora, na aba em que foi comprada, e não sobra caixa guardada. Antes dava para comprar até 10: a primeira abria e as outras ficavam guardadas, e uma caixa guardada pode ser aberta em qualquer aba. Era assim que uma caixa comprada em Bandeiras acabava aberta em Pets.

- Enquanto houver uma caixa guardada, os botões de compra somem e fica só o **ABRIR BAÚ**. Isso só acontece em dois casos: a abertura falhou (a internet caiu depois do pagamento) ou a conta comprou várias caixas antes desta mudança.
- **Essas caixas guardadas continuam podendo ser abertas em qualquer aba.** Não mexi nisso: elas já foram pagas, e o preço é o mesmo nas três abas. Se você quiser que a caixa fique presa à aba em que foi comprada, me avise.

**Confirmação antes de gastar Coroas.** Toda compra com Coroas pergunta antes: a caixa da Coleção, o botão de comprar outra caixa na tela de abertura, uma oferta por Coroas da Loja Misteriosa e um item do Arsenal. A janela **CONFIRMAR COMPRA?** mostra o que está sendo comprado, o preço, o saldo e quanto sobra, com os botões **Cancelar** e **Confirmar**.

- Clicar fora da janela é o mesmo que cancelar. A janela de trás (Coleção, Loja ou Arsenal) continua aberta.
- Nos primeiros 0,35 segundo a janela não aceita clique. É para o segundo clique de um clique duplo sem querer não confirmar a compra.
- No Arsenal a confirmação era apertar o mesmo botão duas vezes ("aperte de novo para gastar"). Um clique duplo passava direto, então ele agora usa a mesma janela.
- **Compras com Robux não passam por esta janela:** o próprio Roblox já mostra a confirmação dele.
- A prévia está em `assets/previa-confirmar-pc.png` e `previa-confirmar-celular.png`.

A caixa tem **dois preços, com um botão para cada um**, lado a lado:

- **Coroas: 25.000 por caixa**, para todos os jogadores. Coroas só se ganham jogando. Era 10.000; subiu porque uma vitória paga uns 4.000 (uns 8.000 com o 2x Coroas), e a caixa saía a cada duas ou três vitórias. Com 25.000 são umas 6 vitórias por caixa (3 com o 2x). Com o item repetido virando Coroas, não existe mais um total fixo para a Coleção inteira (veja a tabela acima). Para mudar, é a linha `coroas = 25000` em `MyShop`.
- **Robux: 9 por caixa** (o produto `crate` da seção 6). Este botão só aparece **onde o Roblox permite caixa paga**. Onde não permite, ele some e fica só o de Coroas. O jogo pergunta ao Roblox, jogador por jogador. No Brasil a regra vale para menores de 18 anos e para adultos sem idade verificada, então muitos jogadores brasileiros vão ver só o botão de Coroas.
- **O produto `crate` está criado e ligado** (seção 6): o botão de Robux abre a compra do Roblox e, paga a caixa, o baú daquela aba abre na hora. Se um dia a linha `crate` voltar a `id = 0`, o botão de Robux continua aparecendo, mas só mostra o aviso de que a compra ainda não está pronta.
- **Não venda Coroas por Robux.** Se as Coroas puderem ser compradas, a caixa por Coroas passa a contar como caixa paga e deixa de ser permitida para esses jogadores. **O passe do mês encosta nessa regra:** ele é pago com Robux e três das missões dele pagam Coroas. Leia o aviso da seção 14 antes de ligar o passe.

**A Loja Misteriosa** mostra seis itens por dia, os mesmos para todos, e troca à meia-noite do horário universal (21h de Brasília). O jogador compra exatamente o item que vê, sem sorteio, por Robux: 19 (Comum), 49 (Raro), 99 (Épico) ou 199 (Lendário). Cada oferta tem uma chance muito pequena de aparecer por Coroas para um jogador: 0,02% com um item Comum (6.000 Coroas) e 0,0001% com um item Raro (25.000). Um item que o jogador já tem aparece com o botão **USAR**.

**Para mudar preços, chances e quantidades**, abra **ReplicatedStorage → Conquista → Data → MyShop**. O arquivo está comentado em português.

**Para criar os seus itens:**

- **Skins:** **Data → MySkins**. Uma skin não é uma imagem: é um desenho pequeno feito de letras, repetido por cima do território. O arquivo traz exemplos prontos para ligar e, mais abaixo, as 15 skins que entraram em 12/11/2026, já ligadas: ali você muda o nome, a raridade e o desenho de cada uma. Não mude o `id` nem apague uma skin depois de publicar, porque ela some da coleção de quem já ganhou.
- **Bandeiras:** **Data → MyFlags**. Você pode desenhar com letras ou usar uma imagem enviada pela sua conta (proporção 3 por 2).
- **Pets:** os 24 vêm de `tools/arte/cosmeticos.py`. São 9 cabeças desenhadas e 15 pelagens diferentes delas. Criar um pet com cabeça nova pede uma imagem nova e rodar o gerador de novo; me peça que eu faço.

**Os 56 itens que entraram em 12/11/2026.** Nenhum precisou de upload: skins e bandeiras são desenhadas pelo código, e os pets novos são pelagens novas das cabeças que já existiam.

| Aba | Antes | Agora | Comum | Raro | Épico | Lendário |
|---|---|---|---|---|---|---|
| Skins | 21 | 36 | 10 | 11 | 9 | 6 |
| Bandeiras | 48 | 80 | 38 | 24 | 13 | 5 |
| Pets | 15 | 24 | 8 | 8 | 5 | 3 |

- **Skins (15):** Pontilhado, Listras Largas, Degraus, Cruzinhas (Comuns); Escamas, Labirinto, Flechas, Rosetas, Ameias (Raras); Flor-de-lis, Castelos, Espadas, Vitral (Épicas); Esmeralda, Manto Real (Lendárias).
- **Bandeiras (32):** 14 Comuns (losangos, terciados, xadrezes, bordaduras), 10 Raras com figura (âncora, bigorna, torre, balista, dragão, barco, elmo, tesouro, chama, adaga), 6 Épicas (Armada Real, Covil do Dragão, Guardiões da Muralha, Legião de Ferro, Navegantes do Norte, Conselho das Corujas) e 2 Lendárias (Estandarte do Lobo, Estandarte do Falcão).
- **Pets (9):** Gato Branco, Raposa Cinzenta, Coruja Cinzenta (Comuns); Lobo Branco, Falcão Dourado, Corvo Branco (Raros); Unicórnio Sombrio, Grifo Esmeralda (Épicos); Dragão Esmeralda (Lendário).
- **Os itens que já existiam não mudaram** de id, nome nem raridade, então o que os jogadores já têm continua igual. Os itens do passe continuam fora da caixa e da Loja.
- As bandeiras e os pets novos ficam em `tools/arte/cosmeticos.py`, sempre no fim de cada lista (a posição dá o id). Depois de mexer ali, rode `python3 tools/arte/make_own_art.py`.

Os itens novos entram sozinhos na aba, na caixa e na Loja Misteriosa.

## 6. Vender com Robux

Três coisas são vendidas por Robux: os **itens do Arsenal**, as **caixas** da Coleção e as **ofertas da Loja Misteriosa**. A venda só funciona com produtos criados na **sua** experiência, e **os 13 estão criados e ligados** (11/11/2026). Os IDs que você mandou estão em **ReplicatedStorage → Conquista → Data → MyProducts**:

| Linha | O que vende | Preço (Robux) | ID do produto |
|---|---|---|---|
| `unlock_mega` | Magia Suprema | 39 | 3730481743 |
| `unlock_stars2x` | 2x Coroas (só por Robux) | 59 | 3730507253 |
| `unlock_scatter` | Rajada Arcana | 67 | 3730507385 |
| `unlock_artillery` | Catapulta | 99 | 3730507497 |
| `unlock_reload2x` | Recarga Rápida (só por Robux) | 129 | 3730507641 |
| `unlock_reinforce` | Reforços | 149 | 3730507879 |
| `unlock_airfield` | Ataque de Dragões | 349 | 3730508013 |
| `unlock_railgun` | Balista Arcana | 999 | 3730508175 |
| `crate` | 1 caixa da Coleção | 9 | 3730508358 |
| `shop_common` | Loja Misteriosa: um item Comum | 19 | 3730508466 |
| `shop_rare` | Loja Misteriosa: um item Raro | 49 | 3730508616 |
| `shop_epic` | Loja Misteriosa: um item Épico | 99 | 3730508724 |
| `shop_legendary` | Loja Misteriosa: um item Lendário | 199 | 3730508805 |
| `pass` | Passe do mês (seção 14) | 199 | 3730557862 |

**O que eu conferi nos IDs** (em 11/11/2026, nos dados públicos de cada produto no Roblox): os 13 existem, estão à venda, pertencem todos à mesma experiência, e o nome e o preço de cada um batem com a linha em que foi colocado. Nenhum está trocado ou repetido. Dois detalhes de digitação, que não atrapalham a venda: o nome do produto da Rajada Arcana começa com um espaço de tabulação, e as descrições do baú e da Oferta Lendária terminam com um; se quiser, apague no painel.

**O que muda no jogo com os produtos ligados:**

- as seis habilidades do Arsenal podem ser compradas com Robux ou desbloqueadas com Coroas;
- os dois bônus (2x Coroas e Recarga Rápida) passam a poder ser comprados; antes mostravam **EM BREVE**;
- o botão de Robux do baú abre a compra (para os jogadores a quem o Roblox permite caixa paga, seção 5);
- as ofertas da Loja Misteriosa podem ser compradas;
- a tela de fim de partida mostra a oferta "Com 2x Coroas", com o quanto a partida teria pago.

**Como testar sem gastar Robux:** abra o arquivo no Studio, **publique-o na experiência em que você criou os produtos** (File → Publish to Roblox As… → escolha essa experiência; um produto só é vendido dentro da experiência dele) e aperte Play. No Studio a compra é de teste: a janela do Roblox avisa que a conta não será cobrada, e o jogo recebe a compra como se fosse de verdade. Teste um de cada tipo:

1. **Arsenal:** abra um item que você não tem e aperte **COMPRAR**. Depois de confirmar, o cartão deve passar a **ADQUIRIDO**.
2. **Baú:** na Coleção, aperte o botão de Robux (9). O baú daquela aba deve cair e abrir. Repita numa segunda aba e confira que o item é daquela aba.
3. **Loja Misteriosa:** aperte o preço de uma oferta. O item deve ser exatamente o do cartão e já vir equipado.
4. Pare o Play e aperte de novo: o que foi comprado deve continuar lá (precisa da opção **Enable Studio Access to API Services** ligada, seção 10).

Se alguma compra não entregar, copie o que aparecer em vermelho na janela **Output** e me mande. No jogo publicado (fora do Studio) a compra é de verdade e cobra Robux, inclusive de você.

**O 14º produto é o passe do mês** (ID 3730557862, 199 Robux), ligado em 12/11/2026 na linha `pass` do `MyProducts`. Se um dia essa linha ficar com `id = 0`, o botão do passe na janela de Missões mostra **EM BREVE** e ninguém compra; as missões diárias funcionam do mesmo jeito. Detalhes: seção 14.

**Para criar um produto novo, ou refazer tudo em outra experiência** (os IDs só valem na experiência em que foram criados):

1. Publique o jogo (seção 10).
2. Em **create.roblox.com**, abra a experiência → **Monetização → Produtos de desenvolvedor → Criar**. **O que preencher em cada produto (imagem, nome, descrição e preço) está em `assets/produtos/PRODUTOS.md`**, e as 13 imagens estão na mesma pasta.
3. Copie o ID de cada produto.
4. No Studio, abra **ReplicatedStorage → Conquista → Data → MyProducts** e ponha o ID na linha do item.
5. Publique de novo.

- **Para mudar um preço:** mude no painel do Roblox. É o preço do painel que o jogador paga e que o jogo mostra. Depois repita o número em `robux` na linha do `MyProducts`: ele só aparece na tela enquanto o Roblox ainda não respondeu.
- **Para parar de vender um item por Robux:** ponha `id = 0` na linha dele. Uma habilidade continua podendo ser ganha com Coroas; um bônus volta a mostrar **EM BREVE**.
- Os oito preços do Arsenal na tabela são os mesmos do RoWorld.
- A página de uma habilidade mostra os dois caminhos: o botão **COMPRAR** com o preço em Robux e, embaixo, o desbloqueio com Coroas (ou a barra de quanto falta). A página de um bônus mostra só o botão de Robux e a frase **Somente com Robux**.
- Sem o produto do 2x Coroas (`id = 0`), a oferta "Com 2x Coroas" da tela de fim de partida não aparece.
- **Um produto só para os três baús:** a linha `crate` vende o baú das três abas (Skins, Bandeiras, Pets). O jogo sabe em qual aba o jogador apertou o botão e abre o baú daquela aba. Não é preciso um produto para cada baú.
- **Uma caixa por compra:** os pacotes `crate3`, `crate5` e `crate10` não existem mais. Só o produto `crate` vende caixa. Se você já tinha criado algum pacote no Roblox, pode deixá-lo lá: o jogo não o oferece.
- **Loja Misteriosa:** é um produto por raridade, não por item. O jogo guarda qual item o jogador escolheu antes de abrir a compra e entrega esse item quando o Roblox confirma.
- Quem compra um item do Arsenal que já tem recebe Coroas no lugar (500 por Robux).
- **Não testado por mim:** nenhuma compra foi feita, nem de teste. Daqui eu confiro os IDs e o código, mas não abro a janela de compra do Roblox. Faça os quatro testes acima no Studio antes de divulgar o jogo.

## 7. Créditos: o que saiu e o que ficou

Você pediu para tirar todos os créditos. Tirei tudo o que podia sair:

- o texto "versão modificada do RoWorld" e o nome RoWorld em todas as telas;
- os créditos dos mapas (Natural Earth, NOAA) e das bandeiras (Wikimedia);
- o crédito da música do RoWorld, junto com a música dele (veja abaixo);
- o botão "Ajuda e Créditos", que agora é só "Ajuda".

**Uma linha ficou, e essa eu não tirei:** "© OpenFront and Contributors", pequena, no rodapé da tela inicial, e um cartão "LICENÇA" de duas linhas no fim da Ajuda. O código deste jogo vem do OpenFront (pelo RoWorld), e a licença dele (AGPL-3.0, arquivo `LICENSE`) só permite copiar e mudar o jogo se esse aviso continuar visível. Sem ele, o jogo estaria usando o código sem permissão e poderia ser derrubado. O único jeito de não ter nenhum crédito é um jogo escrito do zero, como as duas primeiras versões que fizemos.

A licença pede mais duas coisas, que valem a partir do momento em que o jogo ficar público:

1. **Não chamar o jogo de OpenFront nem de RoWorld**, nem dizer que é oficial.
2. **Deixar o código disponível para os jogadores.** Feito em 12/11/2026: o código está em `github.com/sacomano3000/conquista-mundial` (repositório público) e esse endereço aparece no cartão LICENÇA da Ajuda (`Brand.SOURCE_REPO`). **A cada versão nova publicada no Roblox, o repositório precisa receber o mesmo código**, senão o que está lá deixa de ser o que está rodando.

**Música:** as músicas do RoWorld eram de Rodrigo Flores, com uma licença que exige o nome dele nos créditos, e o Roblox só as toca nos jogos da conta do RoWorld. Elas saíram, e o crédito saiu junto. No lugar entraram as seis músicas que você escolheu na Creator Store do Roblox (seção 13), e a música está ligada (`Brand.MUSIC = true`). Eu não encontrei nelas pedido de crédito ao autor, mas **não conferi a licença de cada uma**: os termos que valem são os da Creator Store do Roblox. Se um dia você usar uma música que exija o nome do autor, escreva a frase em `Brand.MUSIC_CREDIT` e ela aparece no fim da Ajuda.

### Revisão de 12/11/2026: o que ainda ligava o jogo ao RoWorld

Você pediu para eu conferir se sobrou algo do RoWorld. Passei um pente-fino no código que vai para o jogo (`tools/revisao/vestigios.py` lista tudo; `tests/vestigios.luau` trava para não voltar).

**O que eu achei e tirei:**

- **Uma conta do RoWorld com tratamento especial.** O código tinha o número da conta do desenvolvedor do RoWorld: se ela entrasse no seu jogo por um link especial, uma partida solo começava sozinha (um atalho de teste dele). Agora esse atalho vale só para o dono desta experiência, que é você.
- **Uma skin feita para uma jogadora do RoWorld.** A skin "Tie Dye" era dada de graça a uma conta específica, que ganharia a skin também no seu jogo. Saiu. O mecanismo ficou, vazio: se um dia quiser dar uma skin só para alguém, me peça.
- **Os 28 IDs de produtos do RoWorld.** Nunca foram usados (produto de outra experiência não vende na sua), mas estavam escritos em `Products`. Saíram. Os únicos IDs no jogo são os seus 14.
- **Os nomes internos "Airfront" e "Rofront".** Eram os nomes das pastas no Explorer, de algumas telas e de três bancos de dados. Agora é tudo **Conquista** (`ReplicatedStorage → Conquista`, `ConquistaServer`, `ConquistaClient`). Efeito colateral: o que fica guardado junto com as opções (volume, ajustes, dicas e tutorial já vistos) volta ao começo uma vez. Compras, Coroas, itens, missões e ranking não mudam.

**O que eu conferi e já estava limpo:** nenhum texto na tela fala RoWorld; o jogo não chama nenhum site ou servidor do RoWorld (o serviço de salas dele está desligado e sem endereço); não há assinatura, experiência de teste nem teleporte para lugares dele; os comandos de dono valem para o dono desta experiência; o Robux das vendas vai para a sua conta.

**O que ficou, e por quê:**

- **O aviso de direitos autorais** ("© OpenFront and Contributors" no rodapé e "© 2026 Snick Co." no cartão LICENÇA da Ajuda; Snick Co. é o estúdio do RoWorld). A licença exige. É a única menção que o jogador vê.
- **Os comentários do código** (86 linhas citam o RoWorld, para dizer de onde veio cada parte). Jogador não lê comentário: o Roblox não manda o texto dos scripts para quem joga. Só quem abre o arquivo no Studio vê. A licença também pede que o código diga que foi modificado e a partir de quê, então eu não apaguei.
- **Imagens enviadas pela conta do RoWorld.** Nenhuma é mais usada direto (eram 31 até 12/11/2026: veja a seção 4). O código ainda cita 144 números de imagens do RoWorld, e o jogo troca todas pelos desenhos próprios na hora. Se um desenho falhar, aparece a do RoWorld naquele lugar (menos o logo, que nunca aparece). Para não depender disso de jeito nenhum, você pode enviar as suas pela sua conta (os PNG estão em `assets/icones/`); o passo a passo está na seção 4, em "Enviar os ícones pela sua conta". `python3 tools/revisao/imagens.py` lista e confere.
- **Os arquivos da pasta do projeto** (`README.md`, `mudancas-sobre-o-roworld.patch`, `tools/`, `tests/`). Não vão para o jogo. O `.patch` é a lista do que mudou sobre o RoWorld, que a licença pede.

**Não dá para esconder de onde o código veio.** A licença (AGPL-3.0) permite renomear e vender, mas exige manter o aviso e deixar o código disponível. O que a revisão garante é outra coisa: nada no jogo se apresenta como RoWorld, nenhuma conta do RoWorld tem privilégio aqui e nada vai para ele.

## 8. Coroas, códigos de resgate e comandos do dono

Os jogadores ganham Coroas no fim de cada partida e no tutorial (1.000). Os preços do Arsenal são os do RoWorld:

| Item | Preço em Coroas | Preço em Robux |
|---|---|---|
| Magia Suprema | 20.000 | 39 |
| Rajada Arcana | 40.000 | 67 |
| Reforços | 40.000 | 149 |
| Catapulta | 50.000 | 99 |
| Ataque de Dragões | 200.000 | 349 |
| Balista Arcana | 500.000 | 999 |
| 2x Coroas (bônus) | não tem | 59 |
| Recarga Rápida (bônus) | não tem | 129 |

- As seis habilidades podem ser compradas dos dois jeitos. As seis juntas custam 850.000 Coroas.
- Os dois bônus são **só por Robux**. Coroas não compram um bônus, nem com `/moedas`: o servidor recusa e não desconta nada.
- A coluna de Robux já vale: os produtos estão criados e ligados (seção 6).
- Quem comprou um bônus com Coroas entre 10 e 11/11 (quando eles custavam 30.000 e 65.000) continua com ele.

### Códigos de resgate

O jogador abre as **Configurações** (a engrenagem), digita o código na linha **Código de resgate** e aperta **RESGATAR** (ou Enter). Se o código valer, ele ganha as Coroas na hora.

Existem dois jeitos de criar um código. O primeiro é novo e não precisa do Studio.

#### Criar códigos de dentro do jogo (pelo chat)

Entre no jogo publicado com a sua conta e digite no chat:

| Comando | O que faz |
|---|---|
| `/codigo criar NATAL 5000` | Cria o código NATAL, que dá 5.000 Coroas. Todo jogador pode usar, uma vez cada um |
| `/codigo criar NATAL 5000 7d` | O mesmo, valendo até o fim do 7º dia a partir de hoje |
| `/codigo criar NATAL 5000 31/12/2026` | Valendo até o fim desse dia |
| `/codigo criar NATAL 5000 100x` | Só os 100 primeiros jogadores do jogo inteiro conseguem usar |
| `/codigo gerar 5000 1x` | O jogo sorteia o nome (por exemplo `K7QM-X2PD`) e cria um código para **1 jogador só**: bom para sorteio e prêmio |
| `/codigo lista` | Mostra todos os códigos, com quantos usos já foram |
| `/codigo ver NATAL` | Mostra um código |
| `/codigo desligar NATAL` | O código para de pagar. `/codigo ligar NATAL` volta |
| `/codigo apagar NATAL` | Apaga o código de vez |

- **Não precisa publicar nada.** O código fica salvo no banco de dados do jogo e vale em todos os servidores. Um servidor que ainda não conhece o código procura por ele quando um jogador digita, no máximo uma vez a cada 15 segundos. Desligar ou apagar chega aos outros servidores em até 1 minuto.
- A validade (`7d` ou uma data) e o limite (`100x`) são opcionais e podem vir juntos, em qualquer ordem: `/codigo criar NATAL 5000 7d 100x`. Sem eles o código não vence e não tem limite.
- O dia da validade termina à meia-noite do horário universal, que é **21h de Brasília**.
- O limite `100x` é contado no jogo inteiro, não por servidor. Com `1x`, o primeiro que resgatar leva e os outros leem "Esse código já esgotou."
- O nome é **uma palavra só**, de 3 a 24 letras, números, `_` ou `-`, sem acento (`FELIZ-NATAL`, não `FELIZ NATAL`). A quantia aceita `5000`, `5.000`, `5k` ou `2m`, até 100 milhões.
- O sorteado do `/codigo gerar` não usa 0, O, 1, I nem L, para ninguém confundir na hora de digitar.
- Se você apagar um código e criar outro com o mesmo nome, quem usou o antigo não consegue usar o novo.
- Cabem 300 códigos. Apague os velhos de vez em quando.
- **Quem pode usar:** as mesmas pessoas do `/moedas` (veja abaixo). Para qualquer outro jogador o comando responde "Só o dono do jogo pode usar /codigo" e não cria nada.
- **A resposta** aparece como aviso na tela por 14 segundos e também fica escrita no seu chat, para dar tempo de copiar o código sorteado. Se perder, `/codigo lista` mostra de novo, e tudo fica no registro do servidor (F9 → Server → Log).
- **Cuidado com erro de digitação na primeira palavra.** `/codigo`, `/código`, `/codigos` e `/code` são comandos e não aparecem para os outros jogadores. Qualquer outra coisa (`/codgo criar NATAL 5000`) é uma mensagem comum de chat e **todo mundo no servidor lê**. Se acontecer, apague o código e crie outro.
- **No Studio:** os códigos criados num teste do Studio ficam num banco separado e só valem nos testes do Studio, igual às Coroas. Para criar um código do jogo de verdade, entre no jogo publicado. No Studio o comando precisa de **Enable Studio Access to API Services** ligado; sem isso ele responde "Não consegui salvar agora".

#### A lista fixa no Studio

O jeito antigo continua valendo e os dois funcionam juntos. No Studio, abra **ServerScriptService → ConquistaServer → MyCodes**. Cada linha é um código:

```lua
["BEMVINDO"] = { coroas = 5000 },
["LANCAMENTO"] = { coroas = 20000, expira = "2027-01-31" },
["OBRIGADO10K"] = { coroas = 10000, ativo = false },
```

- `coroas`: quanto o código dá.
- `expira` (opcional): o último dia em que ele vale, no formato ano-mês-dia. O dia termina à meia-noite do horário universal (21h de Brasília).
- `ativo = false` (opcional): desliga o código sem apagar a linha.
- O código pode ter de 3 a 24 letras, números, `_` ou `-`. Maiúsculas e minúsculas tanto faz, e espaços são ignorados.
- **Cada jogador usa cada código uma vez só.** Isso fica salvo junto com as Coroas dele.
- Para criar ou desligar um código **desta lista**, mude a lista e publique de novo. Os servidores abertos continuam com a lista antiga até fecharem. Os comandos do chat não mudam esta lista, e um nome que está nela não pode ser criado pelo chat.
- O jogo vem com um código de exemplo, **`BEMVINDO`** (5.000 Coroas). Troque ou apague antes de divulgar.
- A lista fica só no servidor: os jogadores não conseguem ver os códigos pelo jogo.
- Cada jogador pode tentar 6 códigos por minuto. Depois disso aparece "Muitas tentativas". Isso vale para os dois tipos de código.
- Se você escrever uma linha errada (sem `coroas`, data torta), o código dela não vale e aparece um aviso amarelo `[MyCodes]` no Output do Studio dizendo qual é.

### Painel do dono

Na tela inicial, em cima e à direita, o dono do jogo tem o botão **ADMIN** (engrenagem), à esquerda do botão MISSÕES. Ele abre uma janela larga, o **PAINEL DO DONO**, com tudo o que dá para mexer com o jogo no ar. Faz o mesmo que os comandos do chat (que continuam funcionando), só que com campos e botões. Prévias: `assets/previa-painel-dono*.png` e `assets/previa-lobby-dono-*.png`.

| Página | O que tem |
|---|---|
| **COROAS** | Campo **JOGADOR** (nome de quem está no servidor, `eu`, ou o ID numérico da conta) e campo **QUANTIA** (`5000`, `5.000`, `20k`). Botões **DAR**, **TIRAR** e **VER SALDO**. Pelo ID funciona mesmo com o jogador fora do jogo |
| **CÓDIGOS** | Para criar: **CÓDIGO** (vazio = o jogo sorteia um, como `K7QM-X2PD`), **COROAS**, **VALIDADE** (`7d`, só `7`, ou `31/12/2026`; vazio = sem validade) e **USOS** (`100` = só os 100 primeiros; vazio = sem limite). Botão **CRIAR**. Embaixo, a lista de todos os códigos, cada um com **DESLIGAR / LIGAR** e **APAGAR**. Os códigos da lista `MyCodes` aparecem como **LISTA DO STUDIO**, sem botões: esses só mudam no Studio |
| **RANKING** | Para tirar um jogador do ranking: escreva o nome ou o ID e aperte **TIRAR DO RANKING**, ou aperte **TIRAR** na linha dele na lista. A lista mostra o ID ao lado de cada nome, e tem quatro botões para escolher qual ranking ver (Vitórias, Reinos, e os dois da semana) |

- **A faixa de baixo** mostra a resposta do servidor: verde quando deu certo, vermelha quando não.
- **APAGAR e TIRAR pedem um segundo aperto** ("CERTEZA? APERTE DE NOVO"). Se você não apertar de novo em 4 segundos, o botão volta ao normal e nada acontece.
- **Tirar do ranking** apaga os números do jogador nas quatro listas (Vitórias e Reinos, do ranking geral e do semanal) e nas listas finais da semana passada (o quadro CAMPEÕES e os prêmios ainda não entregues). Ele não fica banido: se jogar de novo, recomeça do zero.
  - No servidor em que você está, o jogador some da lista na hora. Nos outros servidores, em até 2 minutos. O quadro CAMPEÕES dos outros servidores só muda quando o servidor fecha e abre de novo; até lá, um desses servidores ainda pode entregar a ele o prêmio da semana passada.
  - Quem estava logo abaixo dele sobe uma posição, inclusive na lista final da semana passada: se ele era o 3º, o 4º passa a ter direito ao prêmio do 3º (se ainda não tinha recebido o dele).
  - Uma insígnia que o jogador **já está usando** nesta semana e Coroas de prêmio **já entregues** não são tiradas. Para tirar Coroas, use a página COROAS.
- **Quem vê o botão:** só o dono do jogo. Se o jogo for de um grupo, quem tem cargo 254 ou mais. No Studio, qualquer um que estiver testando.
- **Dá para um jogador burlar?** Não dá para ele **usar** o painel. Quem decide quem é o dono é o servidor do Roblox, comparando a conta do jogador com a conta dona do jogo, e isso o jogador não consegue falsificar. O botão é só a porta de entrada: cada aperto dentro do painel vira um pedido, e o servidor confere de novo quem está pedindo, em todos eles. Um trapaceiro com programa de exploit consegue, no máximo, fazer a janela aparecer **na tela dele**: ela vem vazia (a lista de códigos só é enviada ao dono) e qualquer botão responde "Só o dono do jogo pode usar o painel". A tentativa fica anotada no log do servidor, com o nome dele.
- O painel só existe na tela inicial. Se uma partida começar com ele aberto, ele fecha.

### Comandos do dono

Digitados no chat do jogo:

| Comando | O que faz |
|---|---|
| `/moedas dar Fulano 5000` | Dá 5.000 Coroas a Fulano |
| `/moedas tirar Fulano 2000` | Tira 2.000 Coroas de Fulano (o saldo não fica abaixo de zero) |
| `/moedas ver Fulano` | Mostra o saldo de Fulano |

- No lugar do nome vale `eu`, o nome de usuário, o apelido, o começo do nome (se só um jogador começar assim) ou o número de ID da conta. Com o ID funciona mesmo se o jogador estiver fora do jogo.
- A quantia pode ser escrita `5000`, `5.000`, `5k` ou `2m`.
- **Quem pode usar:** no Studio, qualquer um que estiver testando. No jogo publicado, só o dono. Se o jogo for de um grupo, quem tem cargo 254 ou mais.
- A resposta aparece como aviso na tela de quem digitou.
- Os comandos de código (`/codigo criar`, `/codigo gerar`, `/codigo lista`...) estão explicados acima, em **Códigos de resgate**.

**Para as Coroas ficarem salvas no Studio**, ligue **File → Game Settings → Security → Enable Studio Access to API Services** (o jogo precisa estar publicado). Sem isso, o saldo vale só enquanto o teste está aberto.

Os saldos ficam num save novo desta versão. Quem tinha tudo liberado no teste anterior começa com o Arsenal bloqueado.

Para mudar um preço em Coroas, abra **ReplicatedStorage → Conquista → Data → Arsenal** e troque o número `stars = ...` do item. No código a moeda ainda se chama `stars`; só o nome na tela mudou. Os dois bônus não têm essa linha, e é isso que os deixa só por Robux. Para um bônus voltar a ser vendido por Coroas, escreva uma linha `stars = 30000,` logo abaixo da linha `kind = "boost",` dele.

## 9. Nomes, moeda, tradução e cores

No Studio, abra **Explorer → ReplicatedStorage → Conquista → Data → Brand** e mude:

| Linha | O que é |
|---|---|
| `Brand.NAME = "Conquista Mundial"` | O nome nas frases |
| `Brand.WORDMARK = "CONQUISTA"` | As letras grandes da tela inicial (até 9 letras fica no tamanho cheio) |
| `Brand.TAGLINE = "MUNDIAL"` | A linha pequena embaixo |
| `Brand.MODIFIED_BY = "..."` | Seu nome ou apelido, que aparece no cartão de licença |
| `Brand.SHOW_LOGO = true` | Mostra o logo na tela inicial |
| `Brand.CURRENCY = "Coroas"` | O nome da moeda em todas as telas |
| `Brand.CURRENCY_ICON = "crown"` | O ícone da moeda (`crown`, `gold`, `skull`, `troops`, `target`...) |
| `Brand.OWN_ICONS = true` | Os desenhos próprios (seção 4) |
| `Brand.LOBBY = "simples"` | A tela inicial: `"simples"` (a nova) ou `"completo"` (a do RoWorld, com os botões grandes animados) |
| `Brand.LOBBY_ART = true` | O fundo pintado da tela inicial. Com `false`, volta o mapa se mexendo atrás do título |
| `Brand.MUSIC = true` | A música ligada (seção 13). Com `false` o jogo fica sem música e sem o botão dela |
| `Brand.MUSIC_CREDIT = ""` | A frase de crédito da música no fim da Ajuda. Vazio = nenhuma (seção 7) |
| `Brand.LANGUAGE = "pt"` | O idioma. Com `"en"` o jogo volta ao inglês |

As pastas **Conquista**, **ConquistaServer** e **ConquistaClient** que aparecem no Explorer são o código do jogo (até 12/11/2026 se chamavam "Airfront", o nome interno do RoWorld). Não mude esses nomes, senão o jogo para de funcionar.

**Tradução e nomes de fantasia:** o código escreve em inglês e cada texto é trocado na hora de mostrar, pelo dicionário **Data → LangPt** (966 frases).

- Para mudar um nome ou corrigir uma frase, ache a linha no `LangPt` e mude só o lado direito. Exemplo: `["Artillery"] = "Catapulta",`.
- Não mexa nos `%s` e `%d`: são os lugares onde entram nomes e números. `{moeda}` vira o nome da moeda.
- Um texto que não estiver no dicionário aparece em inglês. Se encontrar algum, me mande a frase ou um print.

**Cores:** ficam em **StarterPlayerScripts → ConquistaClient → UI → UITheme**, nas linhas `UITheme.GLASS`, `UITheme.AMBER` (a cor principal, hoje vermelha), `UITheme.TEXT` e vizinhas.

## 10. Publicar

1. No Studio: **File → Publish to Roblox As… → Create new experience**.
2. **File → Game Settings → Security**: ligue **Allow Mesh / Image APIs** e **Enable Studio Access to API Services**. A primeira opção só aparece liberada para conta com 13 anos ou mais e identidade verificada, que você disse que tem.
3. Publique de novo e deixe o jogo público (ou só para amigos) no Creator Dashboard.
4. Antes de abrir ao público, veja a seção 7 (licença) e, se for vender, as seções 5 e 6.
5. **A página do jogo:** o ícone (`icone.png`, 512 × 512), a miniatura (`miniatura.png`, 1920 × 1080, com o nome; `miniatura-sem-titulo.png` é a mesma pintura sem o nome) e a descrição pronta para copiar estão em `assets/pagina/` (o texto está em `DESCRICAO.md`). Coloque em **create.roblox.com → Criações → a experiência → Configurar**. A miniatura é uma ilustração, não uma foto do jogo; o Roblox aceita até 10, então vale juntar fotos de uma partida de verdade.

### Se o Studio travar em "Upload em andamento… Aguarde"

Isso aconteceu ao publicar por cima do jogo que já existe (**Publicar no Roblox como… → Substituir**). Não sei a causa: daqui eu não vejo o seu Studio nem a resposta do Roblox. Em ordem, do mais simples ao mais trabalhoso:

1. **Cancelar** e olhar a janela **Saída** (em inglês, Output). Ela abre pelo menu **Janela**, no alto do Studio, e não pelo menu Ver. Se houver uma linha vermelha, é ela que diz o motivo.
2. Usar **Arquivo → Salvar no Roblox como…** em vez de Publicar, escolher o jogo e **Substituir**. Se passar, depois use **Arquivo → Publicar no Roblox**. Há relatos no fórum do Roblox de que esse caminho funciona quando o Publicar como trava.
3. Conferir se o jogo publicado está com a **Colaboração (Team Create)** ligada. Com ela ligada o Roblox não deixa substituir o lugar por um arquivo. Desligue, substitua e ligue de novo se quiser.
4. Publicar **sem o Studio**, com o arquivo `publicar-pelo-roblox.bat` (fica junto do `.rbxl`). Ele envia o `ConquistaMundial.rbxl` da mesma pasta direto para o Roblox e mostra a resposta, inclusive o motivo se for recusado. Precisa de uma chave de API: abra **create.roblox.com/dashboard/credentials** (página Chaves de API) e clique em **Criar chave de API**; dê um nome qualquer; em **Permissões de acesso**, escolha o sistema **assets**, deixe **Restringir por criador** desligado e, em **Selecione operações para adicionar**, marque as de leitura e de escrita (Read e Write); deixe a restrição de endereços IP desligada; clique em **Salvar e gerar chave** e copie a chave. Abra o `.bat` com dois cliques, cole a chave e aperte Enter. **A chave é uma senha: não mande para ninguém, nem para mim, e apague-a no painel depois de usar.** **Funcionou em 11/11/2026 (noite):** você rodou o `.bat`, o Roblox respondeu `"isPublished":true` e o jogo foi publicado como a versão 9 do lugar. Os textos com letras trocadas que aparecem na janela preta (a descrição do jogo) são só a janela do Windows mostrando os acentos errado; nada disso é enviado.

## 11. O que foi verificado

- O arquivo `.rbxl` foi montado de novo e conferido: 207 scripts (os quatro novos são das Missões: as regras, a sua lista `MyMissions`, as temporadas e a janela), com a Coleção, a Loja Misteriosa, o Arsenal novo, a tela inicial com o fundo pintado e os seus arquivos (`MyShop`, `MySkins`, `MyFlags`, `MyProducts`, `MyCodes`) dentro. Os três arquivos da loja de bandeiras antiga não estão mais lá.
- **Testes automáticos**, rodados fora do Roblox: rodei **todos de novo depois de redesenhar o mapa Eldoria** (o mapa entra em quase tudo: partidas, robôs, rede, telas). São 105 arquivos de teste. **102 passaram.** Os outros 3 (`gameplayfixer_ui`, `simsys_structures`, `uiscreens_logic`) falham do mesmo jeito no código original do RoWorld, porque dependem de peças do Roblox que não existem fora dele; conferi que as falhas deles são as mesmas, linha por linha, com o mapa antigo e com o novo. Três observações: o `map_surface_repaint` falhou na primeira rodada porque a partida de exemplo dele, no mapa novo, não tinha mais uma queda de reino grande o bastante para o que ele mede; troquei a partida de exemplo (outra semente) e ele passou, 58 de 58. O `net_sim` e o `sim_matches` foram interrompidos por falta de memória enquanto eu rodava outra coisa junto; rodados sozinhos, passaram.
- **Sons, música e volume dos efeitos** (teste novo `sons`, 1.027 conferências; depois dele rodei **todos os testes outra vez**: 107 arquivos, 104 passaram, e os 3 que falham são os mesmos de sempre, citados acima). O teste confere: os 62 sons e as 6 músicas do jogo são exatamente os números que você mandou; nenhum áudio do RoWorld sobrou; cada som toca o áudio certo, no volume do seu ajuste, e os 18 cortados começam no ponto certo; a barra **Efeitos** muda só os efeitos e a barra **Música** só a música; as duas porcentagens são salvas e voltam na sessão seguinte; a página de Configurações é montada pelo código de verdade, em PC e celular, na tela inicial e na partida, com as duas barras dentro da janela, sem nada por cima de nada. O código que toca os sons roda no teste com objetos de som de mentira. **Isso prova as contas, não o som:** nada foi ouvido, e se cada áudio toca no seu jogo só o Studio mostra (seção 13).
- **As telas novas** (teste `telas`, 776 conferências): a tela inicial, a Coleção nas três abas, a abertura de caixa dos três tipos, a Loja Misteriosa, o Arsenal, a pergunta do tutorial e o ranking nas duas abas são montadas pelo código de verdade, em tamanho de PC (1280×720) e de celular (844×390). O teste confere que nada sai da tela, que os botões não ficam um por cima do outro, que o nome CONQUISTA não encosta nos botões nem no saldo, e que os textos saem em português. As prévias em `assets/previa-*.png` são desenhadas a partir dessas medidas.
- **Compras** (testes `colecao`, `shop`, `purchases`): a caixa de cada aba dá um item daquela aba; com tudo daquela aba já obtido, a caixa não é gasta; Coroas a menos não compram nada; a Loja entrega exatamente o item escolhido e o mesmo recibo duas vezes não dá nada a mais; com a linha do produto em `id = 0`, a compra em Robux não abre; dois dias depois a oferta some.
- **Clique atravessando janela** (teste `janelas`, 39 conferências): com o Arsenal, a Coleção ou a Loja abertos por cima da tela inicial, apertar JOGAR SOLO, COMEÇAR ou ARSENAL (os de trás) não faz nada e nenhuma partida começa; ao fechar, eles voltam a funcionar; os botões da própria janela continuam funcionando. A correção tem duas partes: cada janela ganhou um botão invisível do tamanho da tela, por baixo do conteúdo dela, que recebe o clique; e os botões do jogo passaram a ignorar o clique enquanto houver uma janela aberta por cima deles. Vale para Arsenal, Coleção, Loja Misteriosa, abertura de caixa, Como Jogar, escolha de mapa, pausa, fim de partida e as duas janelas de oferta. **Eu não consegui reproduzir o problema original fora do Roblox**, então a confirmação de verdade é a sua, no Studio (seção 2).
- **A pergunta do tutorial** (teste `pergunta_tutorial`, 101 conferências): para um jogador novo a pergunta abre onde antes o tutorial começava sozinho, e nada começa antes da resposta; ela espera se houver outra janela aberta; **Sim, quero** inicia a partida de tutorial (IA mais fácil, mapa padrão); **Não, pular** fica salvo e a pergunta não volta; quem já jogou não é perguntado; se o jogador for levado para uma partida com a pergunta aberta, ela fecha sem salvar resposta; a janela cabe no PC, no celular deitado e no celular em pé, e os botões da tela inicial atrás dela não reagem. O mesmo teste confere que o "Replay as new player" saiu do menu, do cliente, do servidor e do dicionário.
- **O dragão do ataque** (teste `strike_art`, 67 conferências): o giro do desenho foi conferido em 24 direções (a cabeça sempre aponta para onde ele voa), o tamanho acompanha o zoom do mapa, o desenho do ataque e o do cartão do Arsenal são dois desenhos diferentes e os dois estão dentro do jogo. **O que este teste não faz é desenhar o mapa de uma partida:** essa parte do código só roda dentro do Roblox, então o dragão voando na partida eu li e conferi por tipo, mas não vi rodar. Se o Roblox não conseguir mostrar o desenho, o jogo volta a usar o míssil pequeno de antes, em vez de deixar o ataque invisível.
- **O chat** (teste `projeto`, 13 conferências, rodado sozinho depois dos 97): o arquivo montado foi aberto e lido de volta, e nele o chat está marcado como o novo (TextChatService). Antes essa marca não existia, o Roblox tratava o jogo como chat antigo, e a janela do chat antigo fica numa camada abaixo da interface do jogo: por isso o fundo pintado da tela inicial cobria o chat. A janela do chat novo é desenhada pelo próprio Roblox por cima de tudo que é do jogo. **Não vi isso rodando:** a confirmação é abrir o arquivo novo no Studio.
- **As duas formas de pagar a caixa** (testes `telas` e `colecao`): com o Roblox permitindo, aparecem os dois botões, 9 Robux e 25.000 Coroas, lado a lado e dentro do cartão; para o jogador restrito aparece só o de Coroas e a compra por Robux não é pedida; com a linha `crate` em `id = 0`, o botão de Robux só mostra o aviso.
- **O preço novo da caixa, 25.000 Coroas:** depois dessa troca rodei só os testes que leem a caixa e a loja (`colecao`, `confirmar_compra`, `telas`, `janelas`, `shop`, `cosmetics`, `my_products`, `purchases`, `owner_commands`, `offers`); todos passaram. O servidor cobra 25.000, recusa quem tem menos, e a janela de confirmação mostra o preço e o saldo que sobra. As prévias da Coleção foram redesenhadas com o preço novo. Os 105 testes não foram rodados de novo depois dessa troca.
- **Uma caixa por compra** (testes `telas`, `colecao`, `my_products`, `purchases`): o cartão da caixa não tem mais o seletor de quantidade nas três abas, no PC e no celular; o botão de Coroas pede ao servidor uma caixa e ela abre em seguida, na aba em que foi comprada; o servidor recusa um pedido de 2, 3 ou 10 caixas sem tirar Coroas; não existe produto de pacote; com uma caixa guardada, os botões de compra somem e o ABRIR BAÚ aparece.
- **Confirmação da compra** (teste novo `confirmar_compra`, 122 conferências, e a janela medida no teste `telas` em PC e celular): apertar o preço não pede nada ao servidor, só abre a pergunta, com o nome, o preço e o saldo certos; **Cancelar**, um clique fora ou o fechamento da janela de trás não compram nada; **Confirmar** compra uma vez só; um segundo clique 0,1 segundo depois de a pergunta abrir não confirma; os botões de trás não respondem enquanto ela está aberta; se as Coroas acabarem entre o clique e a resposta, nada é comprado; o botão de Robux e o clique sem Coroas suficientes não abrem a pergunta. Vale para a Coleção, a Loja Misteriosa e o Arsenal.
- **O ranking, no servidor** (teste novo `ranking`, 99 conferências, com um banco de dados de mentira no lugar do do Roblox): uma vitória soma 1 e só para quem ficou até o fim; os reinos destruídos somam o número da partida; uma partida sem vitória e sem reino não grava nada; a lista sai em ordem, com no máximo 100 linhas; a mesma lista não é relida antes de 2 minutos; se a leitura falha, a lista anterior continua valendo e a nova tentativa espera 30 segundos; uma soma recusada por excesso de pedidos é tentada de novo e nunca entra duas vezes; quem está fora dos 100 recebe o próprio número sem posição; os testes no Studio gravam em listas separadas.
- **A barra de Ataque** (teste `barra_ataque`, 128 conferências, refeito quando a trava do jogador novo voltou a ficar ligada): a % escolhida não muda depois de um envio, de soltar o botão ou de levar o mouse para o mapa; com 100K e 50% a linha diz 50K, depois 25K, depois 12,5K; nas 5 primeiras partidas a trava segura 20% do limite, o ataque que passaria dela é cortado, e na trava a linha diz "Poucas tropas. Deixe recuperar", nunca "Envia 0 tropas"; a partir da 6ª partida, ou com a trava desligada, vai sempre a % escolhida; no tutorial a linha se comporta do mesmo jeito com a trava dele.
- **A contagem no cartão da habilidade** (teste novo `dica_contagem`, 59 conferências): com o cartão aberto, "Pronto em 0:12" desce segundo a segundo até acabar e então o cartão passa a dizer o que o clique faz; o preço novo também chega ao cartão; o cartão de outro botão não é alterado; um cartão fechado não reabre sozinho.
- **O ranking, na tela** (teste novo `ranking_tela`, 129 conferências, e a janela medida no teste `telas`): as duas abas mostram a lista certa; a linha do jogador é a marcada; "100+" e "Fora do top 100" aparecem para quem está fora; sem resposta do servidor em 10 segundos aparece "Não foi possível carregar o ranking"; o nome de um jogador nunca é traduzido (um jogador chamado "Victory" não vira "Vitória"); o que chega do servidor é limpo antes de ir para a tela (no máximo 100 linhas, nomes cortados em 40 letras, números negativos ou quebrados descartados); com a janela aberta, os botões de trás não reagem; o botão RANK fica dentro da tela e não encosta no saldo de Coroas, no PC e no celular.
- **Os preços do Arsenal** (teste novo `arsenal_precos`, 230 conferências): as seis habilidades custam em Coroas o mesmo que no RoWorld, e os oito preços em Robux de `MyProducts` também são os do RoWorld (os números foram conferidos contra o código original). Os dois bônus não têm preço em Coroas: o servidor recusa a compra com Coroas e não desconta nada, mesmo com 2 milhões no saldo. Com um produto de mentira no lugar do seu, o recibo de Robux libera tanto um bônus quanto uma habilidade, sem tirar Coroas. Na janela, em PC e celular: sem produto, a habilidade mostra só o caminho das Coroas e o bônus mostra "EM BREVE" e "Ainda não disponível"; com produto, a habilidade mostra os dois caminhos e o bônus só o de Robux. A oferta "Com 2x Coroas" do fim da partida só aparece quando o produto existe (teste `offers`).
- **O mapa com o zoom afastado** (testes `zoom_mapa` e `eldoria`): a cor em volta do mapa é a mesma que o próprio mapa usa no mar aberto, e é ela que a tela do mapa usa no fundo. Medido no mapa Eldoria novo: **as quatro bordas são mar aberto em 100% do comprimento, dessa mesma cor, e não há terra em nenhuma delas**; a terra mais próxima de uma borda fica a 43 quadrados. (No Eldoria anterior: em cima 100%, à esquerda 52%, à direita 57%, e a borda de baixo era 100% terra.) Conferido também: 71 reinos, todos em terra, o mais próximo de outro a 89 quadrados; 62 deles no mesmo lugar de antes; 29% do mapa é terra. O tamanho do ícone das construções foi conferido em todos os zooms: o desenho aparece sempre, o ícone nunca fica menor que 12 pixels, nunca muda de tamanho de repente, e acima do ponto em que antes virava bolinha os tamanhos são os mesmos de antes. No zoom mais afastado de cinco tamanhos de tela (janela 1280×720, janela pequena do Studio, Full HD, celular e tablet) o ícone aparece com o desenho.
- **Tradução** (teste `lang`): 986 frases no dicionário. Nenhuma pede mais nomes ou números (`%s`, `%d`) do que o texto original tem, e nenhuma sobra com "Stars" ou um `%s` solto na tela.
- **Códigos criados pelo chat** (teste novo `gerar_codigos`, 244 conferências, com um banco de dados de mentira no lugar do do Roblox): cada comando é lido como o guia ensina, com as datas e as quantias nos formatos aceitos; um jogador comum é recusado e nada é criado; o código criado paga uma vez por jogador; um código `1x` paga o primeiro e diz "esgotou" ao segundo, mesmo com os dois em servidores diferentes; quem já usou não gasta um uso de outro jogador; se o save do jogador falhar, o uso volta para o código; um código criado em outro servidor é achado aqui; desligar, ligar e apagar funcionam; com o banco fora do ar nada muda e a resposta diz para tentar de novo, em vez de "esse código não existe"; os códigos da lista `MyCodes` continuam pagando e um nome dela não pode ser criado pelo chat. Depois de escrever o teste, estraguei o código de propósito de 31 jeitos diferentes, um por vez, e o teste acusou os 31.
- **Códigos de resgate** (a lista `MyCodes`) e **desenhos próprios:** os testes `codes` e `own_art`, como antes.
- **Os 13 produtos de Robux ligados** (11/11/2026). Os IDs foram conferidos nos dados públicos de cada produto no Roblox: os 13 existem, estão à venda, são da mesma experiência, e o nome e o preço de cada um batem com a linha em que foi colocado. O arquivo `.rbxl` foi montado de novo e lido de volta: 203 scripts, e o `MyProducts` de dentro dele tem os 13 IDs. Depois rodei **todos os testes outra vez**: 107 arquivos, 104 passaram, e os 3 que falham são os mesmos de sempre. Sete testes descreviam o jogo sem produto nenhum (`arsenal_precos`, `offers`, `telas`, `confirmar_compra`, `colecao`, `free_for_all`, `my_products`) e foram reescritos: agora conferem o jogo com os produtos ligados e, zerando o ID dentro do próprio teste, o comportamento sem produto. O `my_products` passou a conferir que cada linha tem um ID só dela, que nenhum se repete e que nenhum é um ID do RoWorld; troquei um ID de propósito de três jeitos (repetido, do RoWorld, zero) e ele acusou os três. As prévias do Arsenal (`assets/previa-arsenal-pc.png` e `-celular.png`) foram redesenhadas com os preços em Robux.
- **Missões e passe do mês** (12/11/2026; três testes). `missoes` (319 conferências, com um banco de dados de mentira no lugar do do Roblox): o dia e o mês viram à meia-noite de Brasília, inclusive na virada do ano; as 3 diárias do dia são as mesmas para todos e nunca contam a mesma coisa duas vezes; uma missão paga uma vez só; sem passe a missão mensal completa não paga, e paga na hora da compra; no dia 1 o progresso zera, o passe desliga e os itens ficam; o item repetido vira Coroas; o mesmo recibo duas vezes não entrega duas vezes. `missoes_janela` (89 conferências): a janela segue o relógio do servidor mesmo com o relógio do aparelho errado; dados estragados vindos do servidor não a quebram; o botão passa por preço, **AGUARDE…**, **PASSE ATIVO** e **EM BREVE** nas horas certas; o cadeado some quando o passe liga; com a janela aberta à meia-noite as missões do dia novo aparecem sozinhas. `telas` (agora 1.272 conferências): a janela medida nas duas abas, com e sem passe, no PC e no celular, e o botão MISSÕES na tela inicial. `janelas` (47): um clique não atravessa a janela de Missões. Depois disso rodei **todos os testes**: os 3 que falham são os mesmos de sempre (`gameplayfixer_ui`, `simsys_structures`, `uiscreens_logic`); o resto passou.
- **Não verificado**, porque só dá para ver no Roblox Studio:
  - **as missões e o passe no Roblox:** a janela de verdade, a compra do passe, a entrega dos itens da temporada e a virada do dia e do mês num servidor real (seção 14);
  - **os comandos `/codigo` no chat de verdade.** O que o comando faz foi testado; o que só o Roblox mostra é: se a frase digitada some do chat dos outros jogadores, se a resposta fica escrita no seu chat, e se o `/código` com acento é aceito como comando. Também não vi o banco de dados de verdade do Roblox gravando os códigos;
  - **as telas de verdade.** As prévias não são prints: são desenhos feitos a partir das posições calculadas fora do Roblox, com a mesma fonte. O Roblox pode quebrar uma linha ou arredondar um tamanho de outro jeito. A tela inicial, a Coleção e a Loja no celular são as que têm mais chance de precisar de ajuste;
  - **a abertura da caixa** com o baú em 3D e as animações. O teste só confere que a sequência chega ao fim e mostra o item certo;
  - **o pet e a bandeira ao lado do nome** durante uma partida;
  - **o mapa novo, o mar em volta dele e os ícones pequenos numa partida de verdade.** O mapa, a cor e os tamanhos foram calculados fora do Roblox; a prévia `assets/previa-zoom-afastado.png` é um desenho feito a partir do mapa com as cores do jogo, não um print. Também não joguei uma partida no mapa novo: os robôs jogaram partidas inteiras nele nos testes, mas se as ilhas do sul ficaram boas de jogar só dá para saber jogando;
  - **o dragão voando numa partida** (o desenho aparecer, o tamanho e o giro na direção do voo) e na prévia animada do Arsenal;
  - **a pergunta do tutorial aparecendo de verdade** para uma conta nova, e o tutorial começando ao apertar **Sim, quero**;
  - **o fundo pintado** aparecendo e o mapa escondido atrás dele;
  - **a janela CONFIRMAR COMPRA? aparecendo de verdade** por cima da Coleção, da Loja, do Arsenal e da tela de abertura do baú, e o clique fora dela cancelando sem fechar a janela de trás (fora do Roblox isso foi simulado);
  - **a barra de Ataque e a contagem das habilidades numa partida de verdade.** Os dois consertos foram conferidos com as peças do jogo fora do Roblox, não numa partida;
  - **o ranking de verdade.** Fora do Roblox o banco de dados foi imitado. Só no jogo publicado dá para ver as listas gravando, a ordem que o Roblox devolve, os rostos dos jogadores (quem desenha é o Roblox) e a mesma lista aparecendo em servidores diferentes. O jeito de conferir: publique, vença uma partida multiplayer e abra o RANK alguns minutos depois;
  - **a pergunta ao Roblox** sobre quem pode comprar caixa paga, e qualquer **compra com Robux** (caixa, Loja, Arsenal). Os produtos existem e estão ligados, mas nenhuma compra foi feita, nem de teste: a janela de compra do Roblox abrir, o recibo chegar ao servidor do jogo e o item aparecer são coisas que só o Studio mostra (os quatro testes da seção 6);
  - a compra de ponta a ponta (apertar, o servidor responder, o item aparecer na Coleção);
  - o resgate de código de ponta a ponta, as cores em todas as telas e o equilíbrio das partidas em Eldoria, como antes.

### Item repetido e catálogo maior: o que eu conferi em 12/11/2026

Tudo fora do Roblox, com os testes do projeto. **Nada disto foi aberto no Studio.**

- **O sorteio** (teste `cosmetics`): com metade de uma aba já ganha, 40.000 caixas de cada aba deram itens novos e repetidos, sempre daquela aba, com as raridades nas chances publicadas (margem de 1,2 ponto); o aviso de "repetido" bate exatamente com o que o jogador já tinha; todo item do catálogo pode sair; com a aba completa a caixa não sorteia mais. O modo antigo (`repetidos = false`) continua testado.
- **O servidor** (teste `colecao`, com um banco de dados de mentira): item repetido de cada raridade paga 2.500, 6.000, 12.000 e 25.000 Coroas, gasta a caixa, não acrescenta item e não troca o que o jogador está usando; item novo não paga nada; com o banco fora do ar nada é gasto nem pago; o saldo não passa do teto; com a aba completa a caixa fica guardada. Uma coleção inteira aberta caixa por caixa (4.055 caixas naquele sorteio) devolveu 14% do preço das caixas em Coroas.
- **As telas** (teste `telas`, PC e celular): o cartão da caixa mostra o valor do repetido ao lado de cada chance, dentro do cartão e sem encostar na chance; nenhum texto promete mais "nunca repetido"; a abertura mostra **REPETIDO** e **VOCÊ JÁ TINHA · +6.000 COROAS** para um Raro repetido, e volta para **NOVO!** na caixa seguinte.
- **Os itens do passe** (teste `missoes`): continuam fora da caixa nos dois modos, com as três abas abertas até completar.
- **O catálogo** (teste `cosmetics`): os 84 itens de antes continuam com o mesmo id, tipo e raridade; são 140 no total, com as quantidades da tabela da seção 5; as folhas de bandeiras (960 x 960) e de pets (480 x 768) cabem no limite de 1024 do Roblox.
- **Do servidor até a tela** (teste novo `caixa_repetido`, 19 conferências): o valor do repetido chega à tela como número inteiro; um valor estragado vindo do servidor vira zero; uma recusa não paga nada.
- **A suíte inteira:** 105 testes passam; os 3 que falham são os mesmos de sempre (`gameplayfixer_ui`, `simsys_structures`, `uiscreens_logic`).
- **O que não foi conferido:** a abertura de um item repetido dentro do Roblox (a etiqueta, o som de moedas, o saldo subindo na hora), como as 15 skins novas ficam num território de verdade, e o tempo que o jogo leva para desenhar as folhas maiores ao entrar. As prévias das skins que eu olhei são um desenho feito fora do jogo.

### Lag: o que eu medi em 12/11/2026

Você pediu para otimizar. Antes de mexer, medi o que dá para medir fora do Roblox:

- **A simulação da partida** (15 minutos de jogo em Eldoria, 80 reinos de robôs): cada passo leva em média 1,6 ms e o pior levou 22 ms, na máquina onde eu trabalho. São dez passos por segundo, então a simulação usa menos de 2% do tempo nessa máquina; mesmo num aparelho várias vezes mais lento sobra folga. Não é ela que trava.
- **Os desenhos próprios** (os 121): montar todos leva 49 ms no total, uma vez só, e cada um só é montado quando aparece. Juntos ocupam uns 24 MB de memória se todos forem usados.
- **O que eu acrescentei ao RoWorld** (Missões, Ranking, Coleção, Loja, fundo do lobby): fechadas, essas telas não fazem nada; abertas, só atualizam um relógio ou o que mudou. A tela inicial se atualiza quatro vezes por segundo. O fundo parado do lobby é mais leve que o mapa animado que o RoWorld mostrava.

**Não achei um ponto de lag para corrigir, e por isso não mexi no motor do mapa.** Mudar o desenho do mapa sem medir dentro do Roblox é chute e pode piorar. O que eu não consigo ver daqui é justamente o que mais pesa: quadros por segundo no seu aparelho, memória no celular e a rede.

Se o jogo travar, me diga **onde** (lobby, começo da partida, fim da partida com o mapa cheio), **em que aparelho**, e mande o número de FPS: no PC, **Shift+F5** mostra o contador. Com isso eu sei onde procurar.

O que mais ajudaria em celular fraco é enviar os desenhos como imagens de verdade pela sua conta (seção 4): o jogo deixa de pintar tudo na hora e de guardar as imagens na memória do script.

### Baú, lobby e mapa Valtara: o que eu conferi em 12/11/2026

**Nada disto foi aberto no Roblox Studio.** Tudo foi conferido fora dele, com as telas montadas por um simulador da interface e desenhadas em imagem (`assets/previa-*.png`).

O que mudou:

- **Baú mostrava o cartão vazio.** Ao fechar o baú, a figura do item era apagada aos poucos e ficava invisível; no baú seguinte ela continuava invisível. Agora a figura volta a ficar visível toda vez que um item é revelado.
- **O mapa aparecia antes da imagem do lobby.** O jogo monta o mapa primeiro e a interface depois. Agora a imagem do lobby sobe antes do mapa (`UI/BootCover`) e sai quando a interface está pronta. Se a interface não responder, a cobertura sai sozinha em 20 segundos.
- **Com o chat do Roblox aberto o painel ia para o lado.** O nome do jogo era largo demais para caber ao lado do chat, e o jogo empurrava nome e painel para a direita. Agora nada vai para o lado: o nome diminui e continua no centro, e o painel fica no centro, abaixo do chat.
- **O bloco de partidas do lobby foi refeito no PC.** Em vez da barra vermelha sobre uma lista, são quatro cartões lado a lado: **SOLO**, **PÚBLICA**, **ELDORIA** e **EQUIPES**, cada um com a figura do mapa, uma linha dizendo o que é, vagas e tempo, e o botão. No celular o bloco continua em linhas, porque quatro cartões em pé não cabem na altura da tela.
- **Mapa novo, menor: Valtara.** 1000×500 (um quarto de Eldoria), 24 reinos, dois continentes separados por mar. Feito por `tools/maps/make_small_map.py`. A PARTIDA PÚBLICA joga em Valtara com até 15 jogadores; Eldoria continua com a partida dela (até 45); o jogo de equipes sorteia entre os dois. No solo, o jogador escolhe em **JOGAR → Mapa**.
- **Tribos neutras conforme o tamanho do mapa.** Eldoria continua com 400; Valtara fica com 148. Sem isso, Valtara teria as mesmas 400 em um terço da terra.

O que os testes conferem:

- `tests/telas`: o cartão do baú mostra o item no primeiro baú e no segundo, depois de fechar; os quatro cartões do lobby ficam lado a lado, do mesmo tamanho, dentro do painel, com figura, título, linha, vagas e botão de cima para baixo; com o chat aberto (483×348 numa janela de 1365×728, as medidas da sua captura) o painel e o nome ficam no centro e fora da área do chat.
- `tests/lobby_blocos`: os cartões em cada situação (conectando, sem servidor, com partidas, na fila, entrando, um tipo sem partida aberta, só um tipo de partida) e a janela diminuindo para tamanho de celular e voltando.
- `tests/cobertura_inicial`: a cobertura fica acima do mapa e abaixo da interface, usa a mesma imagem do lobby e sai.
- `tests/valtara`: tamanho, terra, reinos afastados, borda de mar, os dois continentes, as regras do lobby e o número de tribos.

O que **não** foi conferido:

- **A cobertura do lobby dentro do Roblox.** O teste mostra que ela existe e fica na camada certa. Se o mapa ainda aparecer por um instante ao entrar, me diga em que momento (ao abrir o jogo, ou ao voltar de uma partida).
- **O tamanho real da janela do chat.** Usei as medidas da sua captura. Em outra resolução o Roblox pode dar outro tamanho.
- **Baixar Valtara para uma partida solo.** O mapa fica no servidor e o aparelho o baixa quando a partida começa, pelo mesmo caminho que o RoWorld usava para os mapas dele. Esse caminho não roda fora do Roblox.
- **O equilíbrio de Valtara.** Ninguém jogou nele. O limite de 15 jogadores é calculado pelo tamanho da terra do mapa em `src/server/Lobbies/LobbyRules.luau` (`max_players`). Se for muito ou pouco, me diga.
- **Uma skin com o cartão vazio.** Se o aparelho não conseguir criar a imagem de uma skin, o cartão dela ainda pode ficar vazio. Não mexi nisso porque não consegui reproduzir.

### Cartões do lobby: clicar seleciona, o botão entra (12/11/2026)

**Não foi aberto no Roblox Studio.** Conferido fora dele, em `tests/lobby_blocos`.

- No PC, clicar num cartão **fora do botão** só seleciona o cartão (borda e botão mais claros). Nada começa.
- Só o botão do cartão age: **ENTRAR** entra na partida, **CANCELAR** sai da fila, **JOGAR** abre o menu do solo.
- O cartão SOLO também é selecionável.
- Ao abrir o lobby, o cartão selecionado é o PÚBLICA, que já era o destacado.
- No celular nada mudou: com três tipos de partida lado a lado a linha não tem botão ENTRAR, então tocar na linha continua entrando.

O teste aperta o cartão e o botão separadamente e confere: apertar o cartão não pede partida nem sai da fila; apertar o botão pede a partida certa; o botão fica exatamente sobre o desenho dele, dentro do cartão e por cima.

O que **não** foi conferido: o clique de verdade no Roblox. O botão ENTRAR fica dentro do cartão, que também é um botão. No Roblox o botão de cima recebe o clique. Se os dois receberem, o resultado é o mesmo (seleciona e entra), então não há como entrar clicando fora do botão.

**PÚBLICA e ELDORIA às vezes mostram a mesma partida.** Isso vem do RoWorld e não foi mudado: a PÚBLICA tem a rotação dela (Valtara), mas quando a partida de Eldoria começa antes, quem entra pela PÚBLICA vai para a partida de Eldoria. A regra é `LobbyRules.takes_from` em `src/server/Lobbies/LobbyRules.luau`. **Decisão do dono em 12/11/2026: fica como está.**

### Barra de ataque: a reserva aparece na linha (12/11/2026)

**Não foi aberto no Roblox Studio.** Conferido fora dele, em `tests/barra_ataque`.

Com 329K tropas e a barra em 75%, a linha dizia "Envia 176K tropas" e não explicava por que não eram 246K. A causa é a **reserva do jogador novo**: nas 5 primeiras partidas de cada jogador, uma ordem deixa em casa 20% do limite de tropas (aqui, 20% de 763K = 152K). Essa regra veio do RoWorld e continua ligada.

- Quando a reserva corta a ordem, a linha agora diz **"Envia 176K · reserva 152K"**.
- Quando a ordem cabe inteira, a linha é a de sempre: "Envia 164K tropas".
- Na reserva, nada sai, e a linha continua dizendo "Poucas tropas. Deixe recuperar".
- No celular a linha não aparece (só o número enviado), como antes.

**No Studio a reserva vale em toda partida de teste**, porque lá a contagem de partidas não é salva. No jogo publicado ela some depois da 1ª partida do jogador (eram 5 quando este item foi escrito; mudou em 12/11/2026, veja o item mais abaixo).

Para desligar a reserva fora do tutorial: **ReplicatedStorage → Conquista → Data → Tutorial**, `ROOKIE_FLOOR_ON = false`. Para mudar o tamanho: `ROOKIE_FLOOR` (0.2 = 20%). Para mudar quantas partidas: `ROOKIE_MATCHES`.

### Imagens próprias, botão do tutorial e Rank Semanal (12/11/2026)

**Nada disto foi aberto no Roblox Studio.** Tudo foi conferido fora dele, com os testes abaixo e com prévias desenhadas.

**1. As 31 imagens do RoWorld usadas direto**

- Teste novo `imagens_proprias` (233 conferências): todo número de imagem citado no código tem um desenho próprio; cada sombra tem o tamanho que o painel recorta; cada fatia do menu circular cai dentro da folha dela e tem desenho; o baú é feito só de blocos, sem malha e sem textura; as três insígnias existem.
- `python3 tools/revisao/imagens.py` responde: 144 imagens trocadas por desenho próprio, 61 sons, **0 imagens do RoWorld em uso**.
- Comparei 6 das formas novas com os originais guardados em `assets/ui_shapes/`: 3 idênticas, 3 com diferença de no máximo 1 nível de transparência em 256. As 15 sombras **não** foram comparadas com as antigas (os originais não estão na pasta); foram desenhadas pela mesma fórmula.
- **Não conferido:** o baú de blocos dentro do Roblox (a luz, o material de madeira, a tampa abrindo a 140° na animação), e se algum celular fraco fica sem memória para as folhas do menu circular.
- **Memória:** os desenhos agora são 152 (eram 121). Se todos fossem criados ao mesmo tempo ocupariam uns 47 MB (antes, 24 MB); 20 MB são das formas novas, e 16 MB disso são as 5 folhas do menu circular. Cada desenho só é criado quando aparece na tela. Não medi isso num aparelho de verdade.
- Chaves: `Brand.OWN_SHAPES = false` devolve só as formas e sombras para as imagens do RoWorld; `Brand.OWN_ICONS = false` desliga todos os desenhos próprios, menos as insígnias.

**2. Botão "Fazer o tutorial" em Configurações**

- Fica na página de Configurações **só no lobby**. Dentro de uma partida ele não aparece (começar o tutorial jogaria a partida fora). Na fila de uma partida multiplayer ele aparece apagado, com o texto "Tutorial: saia da fila antes".
- Apertar fecha as Configurações e começa a partida de tutorial, sem perguntar de novo.
- **As 1.000 Coroas do tutorial são pagas uma vez só por jogador** (já era assim). Quem refaz o tutorial vê no fim "Tutorial concluído! A recompensa dele você já recebeu", em vez da promessa de Coroas.
- Teste novo `tutorial_de_novo` (89 conferências), no PC, no celular e no celular pequeno: o botão está dentro da janela, não fica por cima de outra linha, a janela cabe na tela, o aperto pede o tutorial uma vez.
- **Não conferido:** o aperto de verdade no Roblox e o tutorial começando em seguida.

**3. Rank Mundial e Rank Semanal**

- Teste novo `ranking_semanal` (113 conferências), com bancos de dados de mentira: o calendário (segunda 00:00 de Brasília), o resultado indo para a lista geral e para a da semana, a lista da semana vazia na segunda, quem recebe e quanto, o pagamento uma vez só (mesmo em outro servidor), banco falhando sem pagar nada, a insígnia valendo até o último segundo da semana seguinte.
- Teste `ranking_tela` (agora 260 conferências): os dois botões RANK MUNDIAL e RANK SEMANAL, a faixa de prêmios, o tempo que falta, a insígnia na linha VOCÊ, tudo cabendo no PC, no celular (844×390) e no celular pequeno (667×375).
- O teste antigo `ranking` (99) continua passando para as listas gerais.
- **Não conferido, e é o mais importante de testar:** os bancos de dados de verdade do Roblox. A virada de semana, o pagamento e a insígnia só foram exercitados com bancos de mentira. Também não vi a etiqueta **[TOP 1]** no chat do Roblox nem a insígnia ao lado do nome no mapa.
- Limite conhecido: as linhas da lista do ranking não mostram insígnia (só a linha VOCÊ). Na menor medida (16 a 18 px, no mapa) o número I / II / III da insígnia quase não se lê; a cor ainda distingue.

A suíte inteira (118 arquivos de teste) foi rodada depois de tudo: falham os mesmos 3 testes antigos do RoWorld de antes (`gameplayfixer_ui`, `simsys_structures`, `uiscreens_logic`), que não têm relação com esta rodada.

### Prêmio resgatado, insígnia que troca de dono e quadro dos campeões (12/11/2026)

**Nada disto foi aberto no Roblox Studio.** Tudo foi conferido fora dele, com os testes abaixo e com prévias desenhadas.

O que mudou em relação à entrega anterior, no mesmo dia:

| Antes | Agora |
|---|---|
| As Coroas do Rank Semanal chegavam sozinhas ao entrar no jogo | Ficam guardadas até o jogador apertar **RESGATAR** na janela do RANK. Só quem ganhou vê o botão. |
| Nenhum sinal no lobby | Marca vermelha com "!" no canto esquerdo do botão RANK enquanto houver prêmio para resgatar |
| "Quem ficar mais de duas semanas fora perde o prêmio" | As Coroas podem ser resgatadas até 2 semanas depois. A insígnia vale 1 semana e passa para o próximo ganhador na segunda-feira. |
| A insígnia aparecia no mapa, na lista da partida, no chat e na linha VOCÊ | Aparece também no cartão do alvo, na escolha da posição inicial, no fim da partida, no grupo do lobby e em todas as linhas da janela do RANK |
| Nada explicava a insígnia | Parar o mouse nela (ou tocar, no celular) mostra "1º em Vitórias na semana passada" |
| Sem quadro de campeões | Aba **CAMPEÕES** na janela do RANK: top 3 de cada lista na semana passada |

As regras completas estão na seção 3, em "Os prêmios da semana".

O que foi conferido:

- `ranking_semanal` (243 conferências, eram 113), com bancos de dados de mentira: nada é pago sozinho; a insígnia aparece sem resgate; o resgate paga uma vez só (segundo aperto, outro servidor e banco falhando não pagam de novo nem perdem o prêmio); o prêmio continua resgatável na 2ª semana e some na 3ª; na segunda-feira a insígnia sai de todos, vai para o novo top 3, e quem caiu de posição troca de cor; as listas da semana passada chegam a todos os jogadores.
- `ranking_tela` (453, eram 260), no PC, no celular (844×390) e no celular pequeno (667×375): sem prêmio não existe faixa nem a palavra RESGATAR na janela; com prêmio a faixa aparece nas três abas, cabe na tela e a lista continua com espaço; um aperto pede uma vez, o botão fica "RESGATANDO…" e volta se o servidor não responder em 12 segundos; a aba CAMPEÕES mostra 3 + 3 e mais ninguém; a insígnia fica antes do nome; o cartão diz a frase certa.
- `insignia_nomes` (novo, 45): monta a lista da partida, o cartão do alvo, o fim da partida, a escolha da posição inicial e o grupo do lobby com um jogador que usa insígnia, e confere que ela aparece, que quem não tem não mostra, e que ela some quando é retirada.
- `telas` (1.566, eram 1.534): a marca no botão RANK aparece só com prêmio, fica no lado esquerdo, por cima dos botões, dentro da tela, e não atrapalha o aperto.
- Prévias novas em `assets/`: `previa-rank-resgatar-*`, `previa-rank-campeoes-*` e `previa-lobby-premio-*`.
- Os 119 arquivos de teste rodaram. Falham os mesmos 3 de sempre, que já falhavam no RoWorld original (`gameplayfixer_ui`, `simsys_structures`, `uiscreens_logic`). Dois testes de velocidade (`sliced_step`, `sim_matches`) falharam quando rodei duas filas de teste ao mesmo tempo e passaram rodando sozinhos.
- Um conferidor de código (luau-analyze) achou um erro meu no cartão do alvo antes da entrega (um nome de variável que não existia e quebraria o cartão). Corrigido, e o teste novo passou a montar esse cartão.

**Não conferido, e é o que mais importa testar:**

- Os bancos de dados de verdade do Roblox: a virada de segunda-feira, o resgate e a insígnia só rodaram com bancos de mentira.
- A parte do servidor que percebe a virada da semana com jogadores já no lobby (olha a cada 30 segundos). Ela não roda fora do Roblox; só conferi que o código está escrito sem erro.
- O toque na insígnia **no celular**. No PC o cartão depende de um evento do Roblox que funciona em qualquer imagem. No celular, dentro de uma linha que também é botão (a lista de jogadores da partida), não tenho certeza de que o toque chega à insígnia. Se não chegar, o toque só faz o que a linha já fazia.
- A etiqueta [TOP 1] no chat e a insígnia no mapa continuam sem ter sido vistas no Roblox.

Limites conhecidos:

- No mapa, no rosto da escolha de posição e no chat não há cartão explicando a insígnia.
- Na escolha da posição inicial o celular mostra só a contagem de jogadores, sem rostos, então lá não há insígnia.
- Numa partida que atravessa a meia-noite de segunda, as insígnias mostradas são as do começo da partida. Elas se acertam na partida seguinte.

### Reserva de tropas em 1 partida e duas pontas soltas (12/11/2026)

**Nada disto foi aberto no Roblox Studio.**

- **Reserva de tropas do jogador novo:** valia nas 5 primeiras partidas, agora vale em **1**. A partida do tutorial deixou de contar, senão quem faz o tutorial gastaria a única partida dentro dele (onde o tutorial já tem a trava própria) e nunca veria a reserva. As regras estão na seção 3.
  - O jogo passa a guardar, junto com as opções do jogador, quantas vezes ele começou o tutorial. Para quem já tinha feito o tutorial antes desta versão, o jogo conta 1.
  - A dica que aparece quando a reserva corta um ataque dizia "Nas suas primeiras 5 partidas"; agora diz "Na sua primeira partida".
  - Testes: `tutorial` (regra da contagem), `barra_ataque` (190 conferências, eram 128: a reserva vale para quem tem 0 partidas, ou só as do tutorial, e não vale a partir da 2ª), `tutorial_de_novo` (93: o começo do tutorial é contado).
- **Pergunta do tutorial por cima da confirmação de compra:** a pergunta "Quer fazer o tutorial?" espera as janelas do lobby fecharem, mas a janela "confirmar compra" tinha ficado fora da lista. Entrou. Teste `pergunta_tutorial` (102).
- **Nomes antigos nas ferramentas:** 36 arquivos em `tools/`, `services/lobbies/` e `tests/` ainda diziam "Airfront" ou "Rofront". Nenhum deles entra no jogo. Agora dizem Conquista, e os caminhos que apontavam para a pasta do jogo original no computador dos autores viraram `~/games/original`. O teste `vestigios` (17, eram 15) passou a vigiar essas pastas também. Os 45 testes do serviço de lobbies (que o jogo não usa) continuam passando.
  - Ficaram de propósito: as duas frases deste guia e a do `README.md` que contam que os nomes mudaram, e os dois arquivos que procuram por esses nomes (`tests/vestigios.luau` e `tools/revisao/vestigios.py`).
- **Todos os testes de novo:** os 119 arquivos rodaram depois destas mudanças. Falham os mesmos 3 de sempre (`gameplayfixer_ui`, `simsys_structures`, `uiscreens_logic`). Cinco testes pesados (`sliced_step`, `sim_matches`, `net_profile`, `net_protocol`, `net_sim`) foram interrompidos quando rodei duas filas ao mesmo tempo nesta máquina e passaram rodando sozinhos.

### Painel do dono e barra do celular (12/11/2026)

**Nada disto foi aberto no Roblox Studio.** As telas foram montadas e medidas fora do Roblox; as prévias são desenhos aproximados, não prints.

- **Painel do dono** (seção 8): botão ADMIN na tela inicial, só para o dono, e a janela com as páginas COROAS, CÓDIGOS e RANKING. No lugar do "comando para tirar um jogador do ranking" e da "janela para criar códigos" que eu tinha oferecido, como você pediu.
  - **No servidor:** `AdminActions` (arquivo novo) recebe cada pedido do painel e confere quem pediu antes de qualquer coisa; `ServerMain` confere antes dele. As Coroas e os códigos passam pelos mesmos comandos do chat. `Ranking.remove` é novo (antes não havia como tirar ninguém).
  - Teste `painel_admin` (128 conferências): cada uma das 6 ações é recusada para quem não é o dono, e a recusa não leva nenhum código, saldo ou ID; dar, tirar e ver Coroas; criar, sortear, ligar, desligar e apagar código; a validade escrita `7`, `7d` ou como data; um nome com quebra de linha não vira um segundo comando; tirar do ranking por nome, por ID e pelo nome que a lista mostra; dois jogadores com o mesmo nome pedem o ID; o jogador some das 6 listas guardadas e das listas do servidor na hora, não volta na leitura seguinte e recomeça do zero; falha do armazenamento é avisada e apertar de novo termina.
  - Teste `painel_admin_tela` (183): cada botão manda um pedido só, com o que está nos campos; os botões esperam a resposta; APAGAR e TIRAR só agem no segundo aperto e esquecem o primeiro depois de 4 segundos; a resposta aparece como o servidor escreveu; sem servidor e sem resposta, a tela avisa; todos os textos do painel estão em português.
  - Para ver se os testes pegam erro de verdade, tirei de propósito a conferência do dono no servidor (16 conferências falharam) e a pergunta "CERTEZA?" (15 falharam), e desfiz.
- **Barra de baixo no celular:** o limite de largura caiu de 760 para **640**. O teste `telas` monta a tela inicial em mais três tamanhos de celular (667×375, 740×360 e 932×430), além do de 844×390: a barra cabe na tela, tem no máximo 640, os três cartões não se sobrepõem, os textos cabem nos cartões e os botões da barra têm pelo menos 40 de lado. Num celular pequeno (667 de largura) muda muito pouco, porque a barra já quase não passava de 640; a diferença aparece nos celulares maiores.
- **Teste `telas`:** 2.162 conferências (eram 1.566), com as telas novas: o lobby do dono, as três páginas do painel no PC e no celular, e os celulares pequeno, estreito e grande.
- **O que só dá para saber no Studio ou no jogo publicado:**
  - se o botão ADMIN aparece para você e **não** aparece para outra conta (no Studio todo mundo é dono);
  - se o teclado do celular não cobre os campos do painel (os campos ficam no alto da janela por causa disso, mas não vi);
  - tirar do ranking com o armazenamento de verdade do Roblox (no teste é um armazenamento de mentira).
- **Subir os ícones pela sua conta:** escrevi o passo a passo na seção 4. Não enviei nada.
- **Todos os testes de novo:** os 120 arquivos rodaram depois destas mudanças, numa fila só. Falham os mesmos 3 de sempre (`gameplayfixer_ui`, `simsys_structures`, `uiscreens_logic`). Um quarto, `confirmar_compra`, falhou na primeira passada: ele procura no código a lista das janelas que seguram os cliques, e eu tinha quebrado essa lista em duas linhas de um jeito que ele não reconhecia. Arrumei a linha e ele passou (122 conferências), junto com os outros 11 testes que leem o mesmo arquivo.

## 12. Onde está cada coisa

| Pasta ou arquivo | O que é |
|---|---|
| `ConquistaMundial.rbxl` | O jogo, pronto para abrir no Studio |
| `assets/previa-lobby-*.png`, `previa-colecao-*.png`, `previa-bau-*.png`, `previa-loja-*.png`, `previa-arsenal-*.png`, `previa-tutorial-*.png`, `previa-confirmar-*.png`, `previa-rank-vitorias-*.png`, `previa-rank-reinos-*.png`, `previa-rank-semanal-*.png`, `previa-config-tutorial-*.png`, `previa-missoes-*.png`, `previa-bau.png`, `previa-insignias.png` | Prévias das telas, no PC e no celular (desenhos, não prints) |
| `assets/previa-do-visual.png` | Prévia dos desenhos: figuras do Arsenal, efeitos, ícones, logo e mapa |
| `assets/icones/` | Os 152 desenhos próprios, em PNG (cópias: o jogo não lê esta pasta) |
| `assets/gerados/` | As ilustrações de origem: estruturas, pets e o fundo da tela inicial |
| `assets/mundo/previa-do-mundo.png` | O mapa de Eldoria com os nomes dos reinos |
| `assets/arsenal-icons/` | As oito figuras do Arsenal (medievais) |
| `assets/ataque/airfield.png` | O dragão visto de cima, que voa no Ataque de Dragões (cabeça para a esquerda) |
| `src/shared/Data/MyShop.luau` | Preços, chances e quantidades das caixas e da Loja (seção 5) |
| `src/shared/Data/MySkins.luau`, `MyFlags.luau` | As suas skins e bandeiras (seção 5) |
| `src/shared/Data/MyProducts.luau` | Os IDs dos seus produtos de Robux (seção 6) |
| `assets/produtos/` | As 14 imagens dos produtos de Robux e `PRODUTOS.md`, com o nome, a descrição e o preço de cada um (seção 6) |
| `assets/pagina/` | O ícone, a miniatura e a descrição da página do jogo no Roblox (seção 10) |
| `src/shared/Assets/Audio.luau`, `AudioExtra.luau`, `AudioUI.luau`, `Soundtrack.luau` | Os sons e as músicas: o número de cada áudio e o ajuste de volume (seção 13) |
| `assets/previa-config-*.png` | Prévia das Configurações com as barras Música e Efeitos |
| `src/server/MyCodes.luau` | A sua lista de códigos de resgate (seção 8) |
| `src/client/UI/AdminPanel.luau`, `src/server/AdminActions.luau` | O painel do dono: a janela e o que cada botão faz no servidor (seção 8) |
| `assets/previa-painel-dono*.png`, `assets/previa-lobby-dono-*.png` | Prévias do painel do dono (Coroas, Códigos, Ranking) e do botão ADMIN, no PC e no celular |
| `src/shared/Assets/OwnArtIds.luau` | Onde entram os IDs dos ícones, se você enviar pela sua conta (seção 4) |
| `src/shared/Data/MyMissions.luau` | As suas missões diárias e mensais: metas, prêmios e textos (seção 14) |
| `assets/previa-missoes-*.png` | Prévias da janela de Missões: diárias, passe à venda e passe ativo, no PC e no celular |
| `assets/gerados/pet_fenix.png` e os outros cinco pets novos | As ilustrações dos pets de temporada (seção 14) |
| `src/` | O código (o mesmo que está dentro do `.rbxl`) |
| `tools/arte/`, `tools/tema/`, `tools/maps/make_fantasy_world.py` | Os programas que geram os desenhos, as prévias, as cores e o mundo |
| `mudancas-sobre-o-roworld.patch` | Lista exata de tudo que mudou em relação ao código do RoWorld |
| `LICENSE` | A licença AGPL-3.0 |
| `README.md` | Explicação técnica, em inglês |
| `assets/skins/`, `assets/ui_shapes/`, `assets/telas/` | Originais dos padrões e de 10 formas do RoWorld (só para comparar: o jogo usa as redesenhadas por `tools/arte/formas.py`), e as medidas das telas usadas nas prévias |
| `tools/arte/formas.py`, `insignias.py`, `bau.py` | Desenham as formas da interface, as três insígnias do Rank Semanal e a prévia do baú |
| `tests/`, `services/`, resto de `tools/` | Testes e ferramentas do RoWorld. Pode ignorar |

## 13. Sons e música

Os sons e as músicas agora são os que você escolheu (lista de 11/11/2026), todos da Creator Store do Roblox. Nenhum áudio do RoWorld ficou no jogo.

**Importante:** eu não ouço áudio. Baixei cada arquivo e **medi** o volume e a duração, mas quem sabe se ficou bom é você, ouvindo no Studio.

### O volume de cada som

Você avisou que muitos estavam altos demais. Medindo, a diferença entre o som mais alto e o mais baixo da sua lista era enorme (uns 40 dB: o mais alto soava dezenas de vezes mais forte que o mais baixo). Então cada som ganhou um **ajuste próprio**, calculado para que todos toquem perto de três níveis:

- **momentos grandes** (vitória, derrota, Magia Suprema explodindo, começo da partida, carta épica e lendária): o nível mais alto;
- **avisos e acontecimentos** (ataque recebido, aliança, traição, baú, moedas, sinos): 4 dB abaixo;
- **sons que se repetem muito** (cliques, janelas, expansão, construção, catapulta, barcos): 9 dB abaixo dos grandes.

Resultado: **39 sons foram abaixados e 23 foram aumentados** (os que estavam gravados baixo e sumiriam atrás dos outros). Os que mais baixaram: ataque recebido e defesa mágica (−17,5), baú caindo no chão (−17,5), traição (−16,5), erro (−15), pedido de aliança e barco (−13), fila e carta épica (−12,5), vitória (−11).

Dezoito sons tinham silêncio no começo do arquivo (até meio segundo). O jogo agora começa a tocar esses a partir de onde o som realmente começa, para não atrasar (coluna "Corte no início").

| Nº | Quando toca | Nome no código | Áudio escolhido | Ajuste (dB) | Corte no início |
|---|---|---|---|---|---|
| 1 | Clique em botão | `ui_click` | Roblox_UI_Small_Click | +5 |  |
| 2 | Passar o mouse sobre um botão | `ui_hover` | RBLX UI Hover 02 | +12 |  |
| 3 | Trocar de aba | `ui_tab` | RBLX UI Select 02 | +4,5 |  |
| 4 | Voltar / fechar janela | `ui_back` | RBLX UI Back | +5 |  |
| 5 | Abrir janela | `ui_open` | Scrapbook Open And Turn Pages 2 | -3,5 |  |
| 6 | Confirmar | `ui_confirm` | RBLX UI Select 01 | +5,5 |  |
| 7 | Erro / ação recusada | `ui_error` | Roblox GUI - Call Decline | -15 |  |
| 8 | Item bloqueado | `ui_locked` | Switch Clicks Metallic Dull Pops 7 | +1 |  |
| 9 | Ordem aceita na partida | `order_ack` | RBLX UI Select 02 | +4,5 |  |
| 10 | Escolheu onde começar | `spawn_confirm` | Date Stamp Big Office Impact Good Squeak 2 | +3,5 |  |
| 11 | Trocar de jogador ao assistir | `spectate_switch` | Roblox GUI - Swipe | -2,5 |  |
| 12 | Entrou na fila / partida encontrada | `queue_start` | Roblox GUI - Notification Low | -12,5 |  |
| 13 | Gastar Coroas (compra) | `buy_spend` | Coins Or Keys Jingle 6 | +6 |  |
| 14 | Ganhar Coroas | `star_get` | Coin Throws 2 | -6 |  |
| 15 | Contagem das Coroas subindo (toca muitas vezes) | `star_tick` | Coins Drop Wood Table Hits Brass Gear 6 | -7,5 |  |
| 16 | Item desbloqueado | `unlock` | Magic Glows Soft Clusters Of Chiming Hits 5 | +10,5 |  |
| 17 | Baú caindo | `crate_drop` | Rising Whoosh Hissing Build Up Ascending Swo | -6,5 | 0,06 s |
| 18 | Baú bate no chão | `crate_land` | Axe Impact Giant Thuddy Hits On Wood Floor 5 | -17,5 |  |
| 19 | Baú chacoalha | `crate_rattle` | Chain Rattle Glassy Metal Rattle 3 | -7 |  |
| 20 | Baú abre | `crate_open` | Wood Groan Creak Opening Wood Chest Coffin 1 | +7 | 0,11 s |
| 21 | Brilho saindo do baú | `crate_shimmer` | Magical Exit Sparkling Pass Bys Clinking Chi | -8 | 0,11 s |
| 22 | Carta vira | `card_flip` | Deck Of Cards 9 | +3,5 |  |
| 23 | Carta passa voando | `card_whoosh` | Wood Whoosh Slicing Air Quick Swings 4 | -5 |  |
| 24 | Aviso da raridade: Comum | `crate_preview_common` | Magic Whooshes Pass Bys Metallic Shimmering | +2 | 0,31 s |
| 25 | Aviso da raridade: Raro | `crate_preview_rare` | Magic Whooshes Pass Bys Metallic Shimmering | +2 | 0,31 s |
| 26 | Aviso da raridade: Épico | `crate_preview_epic` | Magic Twirling Small High Pitch Spinning Chi | -3 | 0,14 s |
| 27 | Aviso da raridade: Lendário | `crate_preview_legendary` | Magic Tone Falling Shimmer Flanged 3 | -2,5 | 0,41 s |
| 28 | Item revelado: Comum | `reveal_common` | Magic Glows Soft Clusters Of Chiming Hits 4 | +10,5 |  |
| 29 | Item revelado: Raro | `reveal_rare` | Magic Burst 5 | -10,5 |  |
| 30 | Item revelado: Épico | `reveal_epic` | Magic Burst 1 | -12,5 | 0,08 s |
| 31 | Item revelado: Lendário | `reveal_legendary` | Magic Burst 3 | -8,5 | 0,21 s |
| 32 | Tique da contagem (curto) | `countdown_tick` | Dial Switch Twisting Sharp Ticking 79 | +7 |  |
| 33 | Contagem: 5 | `countdown_tick_5` … `_1` | Temple Blocks Impact Hitting Two At Once 3 | -4,5 |  |
| 34 | Fim da contagem: a partida começa | `countdown_gamestart` | Horn Blow Long Bursts 10 | +20 | 0,09 s |
| 35 | Início da partida | `game_start` | Timpani Signal 2 | -4,5 | 0,50 s |
| 36 | Vitória | `victory` | Victory Fanfare Sting | -11 | 0,19 s |
| 37 | Derrota | `defeat` | Accepting Defeat StingC | +4,5 | 0,08 s |
| 38 | Um jogador foi eliminado | `eliminate` | Sword Stab 1 | -2 |  |
| 39 | Chegou um pedido de aliança | `ally_request` | Roblox_UI_Tonal_Stinger | -13 |  |
| 40 | Aliança formada | `alliance` | Bugle Call (A) | +0,5 | 0,45 s |
| 41 | Traição | `betrayal` | Nervous Ghosts F | -16,5 |  |
| 42 | Você está sendo atacado | `under_attack` | Shield Clang As Hit Metal Sword Hubcap 1 | -17,5 |  |
| 43 | Reino conquistado | `conquer` | Bugle Call (C) | +4,5 | 0,33 s |
| 44 | Expandir território | `expand` | Whoosh Fast Short Dull Several Versions 2 | -8 | 0,17 s |
| 45 | Borda crescendo (estalo, toca muitas vezes) | `expand_pop` | Lip Pops Dry Plosive Short Snaps 2 | +5,5 |  |
| 46 | Construção feita | `build` | Blacksmith Anvil Hammer Hits 11 | -10,5 |  |
| 47 | Ataque lançado | `attack_launch` | Sword Draw Clang Unsheathing Two Sabers 1 | -1 |  |
| 48 | Magia Suprema lançada | `nuke_launch` | Fireball Pass By 1 | -7,5 | 0,07 s |
| 49 | Alarme: Magia Suprema a caminho | `nuke_alarm` | Church Bells 3 | -4,5 |  |
| 50 | Explosão da Magia Suprema | `nuke_explosion` | Explosions 1 | -10,5 |  |
| 51 | Escudo Arcano dispara | `sam_launch` | Magic Poofs Thumpy Wheezy Exhale 1 | -5,5 |  |
| 52 | Escudo Arcano intercepta | `sam_intercept` | Shield Clang As Hit Metal Sword Hubcap 1 | -17,5 |  |
| 53 | Disparo (catapulta / navio) | `shell_fire` | Wood Whoosh Slicing Air Quick Swings 1 | +2 |  |
| 54 | Disparo acerta a terra | `shell_hit` | Rock Hits Rock On Rock Various Versions 8 | -3,5 |  |
| 55 | Disparo cai na água | `shell_splash` | Mud Puddle Splash Shallow Water Impacts Hits | +6 |  |
| 56 | Barco de tropas sai | `boat_launch` | Oars Fast Rowing In Water Away At Tail 2 | -13 |  |
| 57 | Navio de guerra lançado | `warship` | Church Bell Single Hits Double At Head 4 | -1,5 |  |
| 58 | Navio afunda | `ship_sink` | Underwater Splash 4 | -7,5 | 0,06 s |

Os números 24 e 25 usam o mesmo áudio, e o 42 e o 52 também: foi a sua escolha.

**Dois avisos sobre a sua lista:**

- **Nº 34 (a trombeta do começo, letra C):** esse arquivo foi gravado muito baixo, cerca de 30 dB abaixo das outras duas opções da linha 34. Dei o aumento máximo que o Roblox permite (+20 dB) e mesmo assim ele deve tocar mais fraco que os outros sons grandes. Se achar fraco, a letra **A** da linha 34 (Horn Blow 17) é uma trombeta parecida, gravada em volume normal: é só me dizer "34 = A".
- **Nº 47 (lançar um ataque):** no RoWorld esse som estava trocado por um toque curto, porque atacar é o que mais se faz na partida. Como você escolheu um som para ele (a espada saindo da bainha), tirei a troca: a espada toca no ataque, no máximo uma vez a cada 1,2 segundo, e nos ataques seguidos dentro desse tempo toca o toque curto (nº 9). Se cansar, me avise que eu volto ao toque curto.

### Como mexer

Os sons ficam em três arquivos dentro de **ReplicatedStorage → Conquista → Assets**: `Audio` (partida), `AudioExtra` (baú, cartas, contagem) e `AudioUI` (interface, Coroas). Cada linha é um som:

```
under_attack = { id = "rbxassetid://9119072660", length = 0.741, db = -17.5 }, -- Shield Clang As Hit Metal Sword Hubcap 1
```

- **Deixar um som mais baixo ou mais alto:** mude o número de `db`. Negativo abaixa, positivo aumenta. Uma mudança de 3 já se nota; 6 é mais ou menos "metade" ou "o dobro".
- **Trocar um som:** troque o número depois de `rbxassetid://` pelo número do áudio novo (o número que aparece no endereço da página dele na Creator Store). O `db` foi medido para o áudio antigo: me mande o número novo que eu meço e ajusto, ou acerte de ouvido.
- **Abaixar ou aumentar todos os efeitos de uma vez:** em **StarterPlayerScripts → Client → Audio → AudioDirector**, a linha `self.sfx_volume_db = 0.0`. Com `-3.0` tudo fica um pouco mais baixo.
- **Abaixar ou aumentar toda a música:** no mesmo arquivo, `self.music_volume_db = -6.0`.

Depois de mudar no Studio, publique de novo. Se preferir, me diga "o som tal está alto" e eu mudo.

### A música

| Momento | Nome no código | Música | Duração | Ajuste (dB) |
|---|---|---|---|---|
| Tela inicial | `title` | Royal Courtyard | 2:35 | -0,5 |
| Sala de espera | `wait` | Village of Hope | 3:13 | 0 |
| Partida em paz | `calm` | Whispering Woods | 3:38 | -3 |
| Partida em guerra | `war` | Epic Fortress Defense | 2:57 | -3,5 |
| Vitória | `victory` | Triumph in the Dust | 3:25 | -4 |
| Derrota | `defeat` | Lacrima | 3:20 | +5,5 |

É uma música por momento, em **Assets → Soundtrack**. Como cada momento tem uma só, ela recomeça quando acaba (com uma passagem suave de 2 segundos). As músicas de vitória e de derrota tocam uma vez e depois voltam a da tela inicial ou a de partida. Para ter mais de uma música num momento, acrescente outra linha em `tracks` e ponha o nome dela na lista do momento em `moods`: o jogo alterna sozinho.

As seis também foram medidas e niveladas entre si (a de derrota estava bem mais baixa que as outras, as de guerra e vitória mais altas).

### O volume para o jogador

Nas Configurações há duas barras separadas: **Música** e **Efeitos** (0 a 100%). Cada uma mexe só no seu grupo e as duas ficam salvas na conta do jogador. A chave **Som de fronteira** continua existindo: ela desliga só o estalo da fronteira crescendo.

### O que não foi conferido

- **Nada foi ouvido.** Os volumes são contas sobre medidas; o gosto é seu.
- **Se cada áudio toca no seu jogo.** Consegui baixar os 61 arquivos sem login, o que indica que são públicos, mas só o Studio mostra se o Roblox toca cada um no seu jogo. Se algum não tocar, a janela **Output** mostra "Failed to load sound" e, logo depois, uma linha `[Audio]` com o nome do som.
- **O corte do silêncio inicial** usa um recurso do Roblox (tocar só um trecho do áudio) que o código do RoWorld já tinha, mas que nenhum som usava. Conferi a conta fora do Roblox, não o som. Se algum dos 18 sons cortados não tocar ou começar estranho, me avise: tirar o corte é trocar uma linha.

## 14. Missões e passe do mês

O botão **MISSÕES** fica no alto da tela inicial, à esquerda do RANK (no celular é só o ícone do alvo). A janela tem duas abas. As prévias estão em `assets/previa-missoes-diarias-pc.png`, `previa-missoes-passe-pc.png`, `previa-missoes-passe-ativo-pc.png` e as três de celular.

### Missões diárias (de graça)

- Todo dia o jogo escolhe **3 missões** de uma lista de 8. São as mesmas para todos os jogadores, e nunca duas que contam a mesma coisa.
- Elas trocam à **meia-noite de Brasília**. O pé da janela mostra quanto falta.
- Cada uma paga de **400 a 900 Coroas**. Não há botão de resgatar: quando a partida que completa a meta termina, as Coroas entram junto com as da partida, numa linha própria, **Missões cumpridas**. Essa linha não é dobrada pelo 2x Coroas.
- Contam as partidas **solo e as públicas**.

### Passe do mês (Robux)

- A temporada é o **mês do calendário**, no horário de Brasília. Cada mês tem um nome e três itens só dele: uma skin, uma bandeira e um pet.
- O passe é comprado com Robux e vale **até o último dia do mês**. No dia 1 o progresso mensal volta a zero, o passe desliga e é preciso comprar de novo. O que o jogador já recebeu fica com ele para sempre.
- São **6 missões mensais**, longas. Três pagam Coroas (10.000, 15.000 e 25.000, **50.000 no mês**) e três entregam a skin, a bandeira e o pet da temporada.
- **O progresso conta para todo mundo desde o dia 1**, com ou sem passe. Quem completa uma missão mensal sem o passe vê um cadeado na linha. Quem compra o passe no meio do mês recebe na hora tudo o que já tinha completado.
- Um item da temporada entra na Coleção do jogador e já vem equipado se ele não estiver usando nada daquele tipo. Na Coleção, esses itens aparecem só para quem os tem. Eles não saem em caixa nem na Loja Misteriosa.
- As temporadas se repetem todo ano. Quem já tem o item daquele mês recebe **8.000 Coroas** no lugar.
- Se o jogador comprar o passe duas vezes no mesmo mês (não deveria conseguir: o botão vira **PASSE ATIVO**), a segunda compra vira Coroas, 500 por Robux, como no Arsenal.

| Mês | Temporada | Pet |
|---|---|---|
| Janeiro | Sol Dourado | Leão |
| Fevereiro | Mares Bravios | Serpente |
| Março | Floresta Antiga | Cervo |
| Abril | Tempestade | um dos 9 pets antigos, com as cores da temporada |
| Maio | Reino das Rosas | idem |
| Junho | Noites de Fogueira | idem |
| Julho | Reino das Sombras | Morcego |
| Agosto | Areias do Deserto | idem a abril |
| Setembro | Cavernas de Cristal | idem |
| Outubro | Noite das Bruxas | idem |
| Novembro | Cinzas da Fênix | Fênix |
| Dezembro | Noite de Gelo | Urso |

Seis meses têm um pet com ilustração nova (fênix, urso, leão, serpente, cervo, morcego). Nos outros seis o pet é uma das figuras que o jogo já tinha, repintada nas cores da temporada. Se quiser ilustração nova para esses também, me peça.

### O produto do passe

O passe é um **produto de desenvolvedor**, como os outros 13, e **não** um "Passe de jogo" do Roblox. Passe de jogo é comprado uma vez e vale para sempre; o seu precisa ser comprado de novo a cada mês.

- Você criou o produto em 12/11/2026: **Passe do Mês**, ID **3730557862**, **199 Robux**. Conferi nos dados públicos do Roblox: existe, está à venda, é da sua experiência, e o nome, a descrição e o preço batem.
- O ID está em **ReplicatedStorage → Conquista → Data → MyProducts**, na linha `pass`. Com ele, o botão mostra o preço e **COMPRAR O PASSE**; com `id = 0`, mostra **EM BREVE**.
- É um produto só para todos os meses. O jogo sabe em que mês a compra foi feita.
- Para mudar o preço: mude no painel do Roblox e repita o número em `robux` na linha `pass`. O que cobra é o painel; o número do jogo é só o que o botão mostra antes de o Roblox responder.
- A imagem e a descrição estão em `assets/produtos/` (`pass.png`, `PRODUTOS.md`).

**Eu não testei a compra.** Só dá para testar dentro do Roblox. No Studio (Play), a compra é de mentira e não cobra; no jogo publicado cobra Robux de verdade, inclusive de você.

### Por que 199 Robux e 50.000 Coroas

Você escolheu 199 Robux e pediu mais Coroas. A conta, pelos preços que o jogo já tem:

- Os itens do passe têm raridade própria (**Passe**), acima de Lendário na Coleção. Um Lendário na Loja Misteriosa custa 199 Robux; três custariam 597.
- O passe custa o preço de **um** Lendário e entrega três itens, mas só para quem cumprir as missões (20 vitórias, 25 partidas entre os 3 primeiros, 100 reinos destruídos), e a compra se repete todo mês.
- As Coroas subiram de 26.000 para **50.000** no mês (10.000 por 40 partidas, 15.000 por 300 minutos, 25.000 por 25 missões diárias). Dá duas caixas da Coleção (25.000 cada) ou a Catapulta (50.000).
- Para mudar as Coroas: **ReplicatedStorage → Conquista → Data → MyMissions**, o número `coroas` de cada linha em `mensais`.
- Uma segunda compra no mesmo mês vira Coroas a 500 por Robux: 99.500 com o preço de 199.

**Os itens do passe só saem pelo passe.** Não estão em nenhum baú (comprado com Robux ou com Coroas) nem na Loja Misteriosa. O teste abre cada baú até esvaziar e confere um ano de ofertas da Loja: nenhum item do passe aparece.

### Aviso sobre o passe pagar Coroas

Três missões do passe pagam Coroas (50.000 no mês, o preço de duas caixas). O passe é pago com Robux. Então, por esse caminho, **Robux viram Coroas**, e Coroas compram a caixa da Coleção, que é sorteio. A regra do Roblox proíbe vender item sorteado para alguns jogadores (no Brasil, menores de 18 e adultos sem idade verificada), e o jogo hoje deixa esses jogadores comprarem a caixa com Coroas justamente porque Coroas só se ganhavam jogando.

**Eu não sei dizer se o Roblox considera isso uma caixa paga.** Não achei um texto oficial que trate desse caso, e não quero te dar uma garantia que não tenho. Você escolheu o passe com Coroas e itens, e está feito assim. Se preferir não correr esse risco, há duas saídas simples, e eu faço qualquer uma se você pedir:

- trocar os três prêmios em Coroas do passe por outra coisa que não compre caixa; ou
- deixar o passe só com os três itens da temporada.

As missões diárias não entram nisso: são de graça.

### Mudar as missões

Abra **ReplicatedStorage → Conquista → Data → MyMissions**. O arquivo está comentado em português. Cada linha tem:

- `id`: um nome só dela. **Não mude depois de publicar**, senão quem já cumpriu recebe de novo.
- `contar`: o que a missão conta. `"partidas"` (jogadas por pelo menos 2 minutos), `"vitorias"`, `"reinos"` (reinos destruídos, o mesmo número do Rank), `"minutos"` (jogados, somados), `"top3"` (terminar entre os 3 primeiros, numa partida com pelo menos 4 reinos) ou `"diarias"` (missões diárias cumpridas; para missão mensal).
- `meta`: o número a alcançar.
- `coroas = N`, ou, só nas mensais, `premio = "skin"`, `"bandeira"` ou `"pet"`.
- `texto`: o que aparece na tela. O `%d` vira a meta.

No começo do arquivo ficam `por_dia` (quantas diárias por dia), `minutos_minimos` e `coroas_item_repetido`.

**Não existe contador de construções destruídas.** O seu exemplo "destrua 3 castelos" virou **Destrua 3 reinos**, que o jogo já contava. Se quiser uma missão de construções, é um contador novo no servidor; me peça.

### O que não foi conferido

- **Nada disto foi visto no Roblox.** As regras, o servidor e a janela foram testados fora dele (seção 11).
- **A compra do passe.** O produto não existe ainda, e mesmo com ele eu não abro a janela de compra do Roblox. Depois de criar, teste no Studio: aperte **COMPRAR O PASSE**, confirme, e o botão deve virar **PASSE ATIVO**; as missões mensais já completas devem pagar na hora.
- **A virada do dia e do mês num servidor de verdade.** Fora do Roblox o relógio foi adiantado à mão.
- **As partidas solo contam pelo que o próprio aparelho do jogador informa.** O servidor limita os minutos ao tempo que realmente passou, mas alguém que altere o jogo no próprio aparelho pode inventar vitórias solo, como já podia para ganhar Coroas. Se isso incomodar, dá para fazer as missões contarem só partidas públicas.

## 15. Ranqueada, login diário, mascote, cartão do jogador e emblemas

Tudo desta seção entrou em 12/11/2026. Cada número fica em **um** arquivo, dito em cada parte.

### Ranqueada

No lobby há quatro blocos: **SOLO**, **CLÁSSICA**, **RANQUEADA** e **EQUIPES**. A Clássica e a Ranqueada são a mesma partida pública de todos contra todos e alternam os dois mapas (Eldoria e Valtara); só a Ranqueada mexe nos pontos. As Coroas são pagas igual nas duas.

**Patentes** (`src/shared/Data/Ranked.luau`, tabela `TIERS`):

| Patente | A partir de | Entrada por partida | Prêmio no fim do mês |
|---|---|---|---|
| Escudeiro | 0 pontos | 6 | nada |
| Cavaleiro | 100 | 10 | 1.000 Coroas |
| Barão | 300 | 14 | 3.000 Coroas |
| Duque | 600 | 18 | 7.000 Coroas |
| Rei | 1.000 | 22 | 15.000 Coroas |

**Pontos de uma partida** (mesmo arquivo, `PLACE_MAX`, `WIN`, `PER_HUMAN`, `PER_BOT`):

- **Entrada:** toda partida em que o jogador nasceu no mapa custa a entrada da patente dele. É isso que faz perder pontos numa derrota.
- **Posição:** até 40 pontos, conforme a colocação final (a mesma conta que paga as Coroas). Quem sai antes do fim não recebe esta parte.
- **Vitória:** 30 pontos.
- **Reinos destruídos:** 6 por jogador de verdade, 1 por robô ou reino do mapa.
- **Sala vazia vale menos:** posição e vitória são multiplicadas por 0,25 quando o jogador está sozinho com robôs, subindo até 1 com 8 jogadores de verdade.
- Os pontos nunca ficam abaixo de zero, e o 2x Coroas não mexe neles.

**Temporada:** o mês do calendário, pelo horário de Brasília. Na virada todos voltam a zero e cada um recebe o prêmio da **melhor patente que alcançou no mês**, mesmo que tenha caído depois. O aviso aparece na primeira entrada do mês novo.

**Robôs:** na Ranqueada 4 robôs jogam com a estratégia avançada, contra 2 nas outras partidas (`RANKED_SMART_BOTS` em `src/server/MatchServer.luau`).

**Onde aparece:** no bloco RANQUEADA do lobby ("Cavaleiro · 142 / 300"), no cartão do jogador, na tela de fim de partida ("RANQUEADA +34 · Cavaleiro 176 / 300", com a conta embaixo) e, de Cavaleiro para cima, ao lado do nome na lista da partida, na cor da patente.

### Login diário

A primeira entrada de cada dia (horário de Brasília) paga sozinha, com um aviso na tela. Não há botão para apertar.

| Dia | Recompensa |
|---|---|
| 1 | 500 Coroas |
| 2 | 750 Coroas |
| 3 | 1.000 Coroas |
| 4 | 1.500 Coroas |
| 5 | 2.000 Coroas |
| 6 | 3.000 Coroas |
| 7 | 1 baú grátis |

Depois do dia 7 volta ao dia 1. Um dia sem entrar também volta ao dia 1. A tabela é `REWARDS` em `src/shared/Data/Login.luau`: troque os números, ou ponha `{ crate = 1 }` no lugar de `{ stars = N }`.

### Mascote

O pet equipado deixou de ficar ao lado do nome: agora fica em cima da capital do reino, no mapa, respirando de leve. Quando o reino dele destrói outro, pula e balança por 2,4 segundos. É só visual, não muda nada na partida. O movimento está em `src/shared/Data/Mascot.luau` (`CHEER_S`, `MIN_PX`, `MAX_PX`). Para o pet voltar também para a lista da partida: `Leaderboard.PET_IN_ROWS = true` em `src/client/UI/Leaderboard.luau`.

### Cartão do jogador

No lobby, embaixo à esquerda no PC e em cima à esquerda no celular: bandeira e nome, patente com a barra até a próxima, vitórias e reinos destruídos da vida toda (só partidas públicas contam, a partir desta versão), o mascote e o dia do login. Nada nele é clicável. Some sozinho quando não cabe (tela estreita, painel do grupo aberto, sala de espera). Arquivo: `src/client/UI/PlayerCard.luau`.

### Emblemas do Roblox

O jogo sabe dar 8 emblemas. Um emblema só é dado depois de criado no Roblox e com o número dele em `src/shared/Data/MyBadges.luau`; sem número, nada acontece e nada quebra.

**Situação em 12/11/2026:** 5 criados e já com o número no arquivo (Primeira Vitória, Conquistador, Veterano de Guerra, Cavaleiro do Reino, Sete Dias de Lealdade). Faltam 3: Flagelo dos Reinos, Rei de Conquista e Campeão da Semana. Os 5 foram criados entre 08:20 e 08:22 de Brasília; para os outros 3 saírem de graça, crie depois das 08:30 de 13/11.

| Linha em `MyBadges.luau` | Nome | Descrição para colar | Imagem em `assets/emblemas/` |
|---|---|---|---|
| `first_win` | Primeira Vitória | Vença a sua primeira partida pública. | `primeira-vitoria.png` |
| `kills_10` | Conquistador | Destrua 10 reinos em partidas públicas. | `conquistador.png` |
| `kills_100` | Flagelo dos Reinos | Destrua 100 reinos em partidas públicas. | `flagelo-dos-reinos.png` |
| `wins_10` | Veterano de Guerra | Vença 10 partidas públicas. | `veterano-de-guerra.png` |
| `knight` | Cavaleiro do Reino | Chegue à patente Cavaleiro na Ranqueada. | `cavaleiro-do-reino.png` |
| `king` | Rei de Conquista | Chegue à patente Rei na Ranqueada. | `rei-de-conquista.png` |
| `champion` | Campeão da Semana | Termine a semana entre os 3 primeiros do ranking. | `campeao-da-semana.png` |
| `login_7` | Sete Dias de Lealdade | Entre no jogo 7 dias seguidos. | `sete-dias-de-lealdade.png` |

Como criar cada um:

1. Abra o Painel do Criador (create.roblox.com), ache o jogo, e no menu dele vá em **Engajamento → Emblemas** (ou, na miniatura do jogo, **⋯ → Criar emblema**).
2. Envie a imagem da tabela, cole o nome e a descrição, deixe o emblema ativado e crie.
3. Na lista de emblemas, passe o mouse sobre ele, **⋯ → Copiar ID do recurso**.
4. Abra `src/shared/Data/MyBadges.luau` e troque o `0` da linha dele pelo número.
5. Publique o jogo de novo.

O Roblox deixa criar 5 emblemas de graça por dia em cada jogo; o sexto em diante, no mesmo dia, custa 100 Robux cada. Para não pagar: crie 5 hoje e 3 amanhã. O Roblox recorta a imagem em círculo; `assets/emblemas/_previa-circular.png` mostra as oito já recortadas.

O emblema é dado quando o jogador entra e depois de cada partida pública, então quem já tinha os números antes de você colar o id recebe na entrada seguinte. As vitórias e os reinos só começaram a ser contados nesta versão: partidas antigas não entram.

### O que não foi conferido

- **Nada disto foi visto no Roblox.** Pontos, temporada, login, contagem e a regra de cada emblema foram testados fora dele (`tests/ranqueada.luau`, `tests/login_emblemas.luau`, `tests/resumo_partida.luau`, `tests/telas.luau`).
- **A entrega do emblema pelo Roblox.** Testei com um serviço de emblemas de mentira. O de verdade só dá para testar depois que você criar os emblemas.
- **O mascote no mapa.** Só o movimento (altura do pulo, inclinação, duração) foi testado; o desenho dele em cima da capital eu não vi rodando. É a primeira coisa para olhar no Studio: equipe um pet, entre numa partida e destrua um reino.
- **A virada do mês e do dia num servidor de verdade.** Fora do Roblox o relógio foi adiantado à mão.

## 16. Nomes e ícones mais medievais (12/11/2026)

O que ainda lembrava arma moderna foi trocado. Só mudaram nomes, textos e desenhos: as regras, os preços e os números dos produtos são os mesmos.

| Antes | Agora | O que mudou no desenho |
|---|---|---|
| Canhão Arcano | **Balista Arcana** | Figura do Arsenal e ícone do mapa: uma balista de madeira com virote de cristal |
| Bala | **Virote** | Ícone: uma flecha grossa com penas |
| Galeão | **Drácar** | Ícone e navio no mapa: barco de uma vela só, com proa de dragão e escudos |
| Bola de Fogo (ícone de cometa com anel) | Bola de Fogo | Ícone: uma bola em chamas |
| Reforços (ícone de muralha com cruz) | Reforços | Ícone: uma trompa de guerra |
| Toca dos Dragões / Ataque de Dragões | os mesmos nomes | **Todo dragão é o mesmo: visto de cima, de asas abertas, voando.** A figura do Arsenal, o ícone no mapa e o botão do ataque usam o dragão que já voava nos ataques |

Textos: "caminhões" virou "carroças", "bateria" virou "catapulta", "rearma" virou "prontos de novo", e os textos do antigo canhão falam de balista e virote.

Três estandartes da Coleção acompanharam: "Canhão de Ouro" virou **Balista de Ouro**, "Nau de Prata" virou **Drácar de Prata**, e os dois estandartes de dragão mostram o dragão visto de cima. Quem já tinha esses itens continua com eles.

**A Catapulta ficou como estava.** "Trabuco", no Brasil, também é gíria para arma de fogo, então não troquei o nome.

**Os pets de dragão não mudaram.** São retratos de mascote, não o dragão do ataque. Se quiser esses também vistos de cima, é só pedir.

**O que você precisa fazer no Roblox:** o produto `unlock_railgun` (id 3730508175) ainda se chama "Canhão Arcano" no Painel do Criador. Troque o nome para "Balista Arcana", a descrição pela de `assets/produtos/PRODUTOS.md` e a imagem por `assets/produtos/unlock_railgun.png`. O produto do Ataque de Dragões (`unlock_airfield`) ganhou imagem nova também. O id não muda e nada quebra se você não trocar: só fica o nome antigo na janela de compra do Roblox.

**Onde ficam os desenhos:** as silhuetas em `assets/gerados/g_*.png`, as figuras do Arsenal em `assets/arsenal-icons/`, e as versões de antes em `assets/gerados/antigos/` e `assets/arsenal-icons/antigos/`. Depois de trocar um desenho: `python3 tools/arte/make_arsenal_icons.py` e `python3 tools/arte/make_own_art.py`.

**Não conferido:** nada disto foi visto no Roblox. Olhei os desenhos e as prévias das telas fora dele.
