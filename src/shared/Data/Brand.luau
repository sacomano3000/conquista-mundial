--!strict
-- The game's name and where its source lives: change them here and every screen follows (the title
-- screen's wordmark, the Help card's credits and Source line, the landscape prompt).
--
-- This game is a modified version of RoWorld (Snick Co.), itself a modified version of OpenFront, under
-- the GNU AGPL v3 and the additional terms in LICENSE: the credits must keep "© OpenFront and
-- Contributors" visible, the name must not be OpenFront's (nor RoWorld's), and players must be able to
-- get this source (SOURCE_REPO).
local Brand = {}

--- The name, as written in sentences.
Brand.NAME = "Conquista Mundial"
--- The title screen's wordmark (capitals). Keep it short: one word of up to 9 letters fills the
--- title screen like the original did; a longer one is drawn smaller to fit.
Brand.WORDMARK = "CONQUISTA"
--- The small line under the wordmark (capitals).
Brand.TAGLINE = "MUNDIAL"
--- The public repository with this game's source (owner/repo on GitHub).
--- (A licença AGPL exige que os jogadores consigam o código que está rodando: a cada versão publicada
--- no Roblox, o repositório precisa receber o mesmo código.)
Brand.SOURCE_REPO = "sacomano3000/conquista-mundial"
--- Who made this version's changes, and when (the AGPL asks a modified version to say so).
--- TROQUE pelo seu nome ou apelido do Roblox.
Brand.MODIFIED_BY = "Equipe Conquista Mundial"
Brand.MODIFIED_YEAR = 2026
--- The logo above the name on the title screen and on the "rotate your phone" card: this game's own
--- emblem (assets/icones/logo.png, drawn by the game itself: Assets/OwnArt). false hides it.
Brand.SHOW_LOGO = true
--- The currency a match pays and the Arsenal takes (RoWorld's "Stars"; the code keeps that name):
--- what players read, plural with a capital. The translation (Data/Lang) writes it everywhere.
--- TROQUE aqui se quiser outro nome para a moeda (por exemplo "Medalhas", "Pontos", "Glória").
Brand.CURRENCY = "Coroas"
--- Its icon: a key of Assets/UiIcons ("crown", "gold", "troops", "target"...), or "star" for
--- RoWorld's own star. Drawn wherever the currency is shown (client/UI/UITheme.icon).
Brand.CURRENCY_ICON = "crown"
--- The Arsenal's pictures: true shows this version's own drawings of the items (Assets/ArsenalIcons,
--- drawn by the game itself, so nothing has to be uploaded); false shows RoWorld's renders.
Brand.OWN_ARSENAL_ICONS = true
--- The interface's language: "pt" translates every text through Data/Lang; "en" leaves RoWorld's English.
Brand.LANGUAGE = "pt"
--- The soundtrack (Assets/Soundtrack): true plays it; false leaves the music off (no music row in
--- Settings, no music button in the top bar). Since 2026-11-11 the tracks are this version's own choice,
--- one per mood, from the Roblox Creator Store (RoWorld's uploads only play in RoWorld's own games).
--- Para trocar uma música: troque o id dela em Assets/Soundtrack.luau.
Brand.MUSIC = true
--- A frase de crédito da música, mostrada no fim de "Como jogar" enquanto a música estiver ligada.
--- Vazio = nenhuma frase (as músicas atuais vêm da Creator Store do Roblox). Se um dia você usar uma
--- música cuja licença exige o nome do autor (por exemplo CC BY), escreva aqui: "Música de Fulano (CC BY 4.0)."
Brand.MUSIC_CREDIT = ""
--- This version's own icons (Assets/OwnArt, drawn by the game itself in place of RoWorld's images).
Brand.OWN_ICONS = true
--- The interface's shapes (panel shadows, the loading ring, the radial menu's slices, glows) drawn by
--- the game itself too, in place of the ones on RoWorld's account (tools/arte/formas.py). They look
--- the same. false: those few go back to RoWorld's images (the icons above stay this game's).
Brand.OWN_SHAPES = true
--- The title screen (the lobby). "simples": the clean one — logo, name, PLAY SOLO, the multiplayer
--- card, three plain buttons (Arsenal, Locker, How to play) and the balance in a small chip top right.
--- "completo": RoWorld's — the two big animated buttons top right, the greeting, the glow.
Brand.LOBBY = "simples"

--- O fundo do lobby: true = a pintura própria do jogo (assets/gerados/fundo_lobby.png), parada, atrás
--- do nome e dos botões; false = o mapa passando devagar ao fundo, como no RoWorld.
Brand.LOBBY_ART = true

return Brand
