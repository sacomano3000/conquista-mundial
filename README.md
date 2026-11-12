# Conquista Mundial

A conquest game for Roblox on an invented world, Eldoria: claim land, expand, ally and betray, build an
economy, burn your neighbours with spells, hold 80% of the world to win.

This is a modified version of [RoWorld](https://github.com/lukechatton/roworld) by Snick Co., which is
itself a modified version of [OpenFront](https://github.com/openfrontio/OpenFrontIO).
© OpenFront and Contributors. RoWorld's changes © 2026 Snick Co. Not affiliated with or endorsed by
OpenFront or Snick Co.

Based on RoWorld commit `ae7a3505e6f3736aef85fffc1879c0476f819c59` (2026-11-05).
`mudancas-sobre-o-roworld.patch` is the difference from that commit in code and text (images, the generated
art and map data modules, and the removed continent maps are left out of it: compare the folders for those).

Em português: veja `GUIA.md`.

## What's different from RoWorld

- **Name.** The name, the title screen's wordmark and tagline, the source link and who modified the game
  live in one file, `src/shared/Data/Brand.luau`.
- **Its own look.** Graphite and red instead of navy and amber (`tools/tema/recolorir.py` rewrote the
  colour tokens of `src/client/UI/UITheme.luau` and the hand-written colours of the screens); a medieval
  fantasy vocabulary in the Portuguese dictionary (the rules, numbers and code names are RoWorld's).
- **Its own icons and effects.** 120 images take the place of RoWorld's uploads: the interface's and the
  Arsenal's glyphs, the Arsenal's eight item pictures, the map's structure plates and glyphs, unit
  sprites, status icons, the Arsenal previews' effects and ground, the map's effects atlas, the road
  tiles (the rails' place), the chest's lights, the logo and the world's thumbnail. They are kept in the
  code (`src/shared/Assets/OwnArtData.luau`, written by `tools/arte/make_own_art.py` from
  `tools/arte/glifos.py`, `efeitos.py`, `mapas_do_arsenal.py`, `assets/gerados/` and
  `assets/arsenal-icons/`; PNGs in `assets/icones/`) and `src/client/UI/ArtSweep.luau` shows each one, as
  an EditableImage, wherever an ImageLabel is given the RoWorld image it replaces: the screens and the
  sprite sheets' grids are untouched, and the `Assets/*.luau` modules keep RoWorld's ids as keys only.
  `Assets/OwnArtIds.luau` takes the owner's uploaded ids instead. `Brand.OWN_ICONS`; `tests/own_art.luau`.
  Where the engine refuses an EditableImage, RoWorld's image is what shows (the banners, pets and lobby
  painting have none and stay empty). Not replaced: territory skins (code-drawn patterns), the 3D chest
  (meshes), panel shadows and other shapes, sounds.
- **Its own world.** `src/shared/Data/Maps/World.luau` is Eldoria, an invented map of 6 continents, five
  cold islands in the south, about 165 smaller islands and 71 kingdoms, sea all around, made by
  `tools/maps/make_fantasy_world.py` (noise on a sphere, no data downloaded). The real-Earth world and the five continent maps are gone from the game; the real-Earth
  world stays as a test fixture (`tests/fixtures/EarthWorld.luau`) for the rule tests that pin real
  places. `tests/eldoria.luau`. (`tools/maps/make_maps.py` is RoWorld's real-Earth builder: running it
  puts the real map back.)
- **Fewer credits on screen.** The title screen's footer is "© OpenFront and Contributors"; the Help
  window ends with a two-line licence card (copyright notices, AGPL, no warranty) and the source line.
  The map, flag and RoWorld lines are gone, and so is RoWorld's soundtrack with its CC BY 4.0 credit line
  (Roblox does not play another account's audio anyway). A soundtrack that needs a credit puts it in
  `Brand.MUSIC_CREDIT` (shown at the end of the Help window; empty by default).
- **Its own sounds and music** (2026-11-11). Every audio id is one the owner picked from the Roblox Creator
  Store: 62 effects in `Assets/Audio.luau`, `AudioExtra.luau` and `AudioUI.luau` (each sound in one file
  only, so nothing is left as a stand-in) and one track per mood in `Assets/Soundtrack.luau`
  (`Brand.MUSIC = true`). Each entry carries `db`, its own level trim: the files were downloaded, measured
  (the loudest 125 ms, K-weighted) and levelled to three targets (big moments, events, frequent sounds),
  because the raw files spanned about 40 dB. `AudioDirector.play_sfx` adds `stream.db`; `TRIM_DB` and
  `REPLACE` are empty (so `attack_launch` plays its own sound, the order tap during its cooldown).
  Eighteen sounds with silence at the head are `{ sprite, start, stop }` entries (RoWorld's
  `PlaybackRegion` path, unused until now). Soundtrack tracks take `db` too
  (`_crossfade_to(..., db)`, `_gain_volume`).
- **A separate volume for sound effects.** Settings has two sliders, Music and Effects
  (`PauseMenu.VolumeRow`, signal `sfx_volume_changed`, `UICtx.sfx_volume` / `set_sfx_volume`).
  `AudioDirector.set_sfx_volume` scales the "SFX" SoundGroup by the slider's square and saves
  `[audio] sfx_volume` next to `music_volume`. The row's icon (`pops`) is redrawn as a speaker.
  `tests/sons.luau` checks the manifests against the owner's list, runs the real `AudioDirector` on
  stand-in Sounds (the volume each effect plays at, the cut starts, both sliders, the saved values) and
  builds the Settings page headless on a PC and a phone. Nothing was listened to.
- **The Arsenal is priced as RoWorld's** (2026-11-11, the owner's choice). The six units unlock with the
  currency matches pay, at RoWorld's prices, and are also sold for Robux through the owner's own
  developer products, whose ids are in `src/shared/Data/MyProducts.luau` (filled on 2026-11-11; a line at
  `id = 0` is not on sale); RoWorld's product ids only work in RoWorld's own experience and are never
  used. The two boosters (`stars2x`, `reload2x`) have no `stars` price: Robux only, so with their line at
  `id = 0` nobody can get them (their card reads "SOON", their page "Not available yet", and
  `UIRules.result_offers`, now told `Data/Products`, leaves the result screen's 2x offer out). For one day (2026-11-10 to 11) this version
  sold them for 30,000 and 65,000 of the currency; a record that bought one keeps it.
  `tests/arsenal_precos.luau`, `tests/offers.luau`. The takeover is owned by every player; no General
  subscription. (`Purchases.FREE_FOR_ALL`, `Purchases.EARN_ARSENAL`, `Purchases.FREE_COSMETICS = false` in
  `src/server/Purchases.luau`; `tests/free_for_all.luau`.) Saves go to this version's own DataStore,
  `ConquistaMundial_v1`.
- **The Coleção: skins, banners, pets.** Three kinds of cosmetic (`src/shared/Data/Cosmetics.luau`): 36
  territory skins (15 of them in `Data/MySkins.luau`), 80 banners of this version's own (`Assets/Flags.luau`; RoWorld's country flags are
  gone) and 24 pets (`Assets/Pets.luau`), a pet being drawn right of its owner's name on the map
  (`Map/NameLayer.luau`) and in the leaderboard. `UI/Locker.luau` is rewritten: a tab per kind, each with
  its own crate and the odds shown before the purchase. Since 2026-11-12 a crate may roll an item the
  player owns, which pays Coroas instead (`Cosmetics.DUPLICATES`, `Cosmetics.DUPLICATE_STARS`; the owner's
  switch and amounts are `repetidos` and `coroas_repetido` in `Data/MyShop.luau`; with the switch off a
  crate never gives a duplicate and the odds re-normalise when a rarity is exhausted). A crate has two prices, a button
  each: the earned currency for everyone (`Data/MyShop.caixa.coroas`, 25,000, was 10,000 until 2026-11-11; `Purchases.buy_crates`),
  and Robux (product `crate`, 9) shown only where
  `PolicyService` says paid random items are allowed. While `crate` has no id the Robux button shows a
  notice and sells nothing. One crate a purchase (`Locker.CRATE_MAX`, `Purchases.CRATE_MAX` = 1; no
  quantity selector, no crate packs): it opens at once in the tab it was bought in. Crate credits are
  still one counter for the three tabs, so a crate left waiting (a failed opening, or bought before this
  rule) opens in whichever tab is in view; nothing is sold while one waits. The earned currency is never sold. A record written while cosmetics were free starts its collection empty, once
  (`Purchases.RESET_FREE_ERA`). Owner files: `Data/MyShop.luau` (prices, odds), `Data/MySkins.luau`,
  `Data/MyFlags.luau`. Protocol ops 45 / 46. `tests/colecao.luau`.
- **The Loja Misteriosa** replaces RoWorld's flag shop (`UI/FlagShop`, `ShopButton`, `ShopLayout` and the
  `shopflag:` / `shopset:` receipts are removed). `Data/Shop.luau` picks six items a day (UTC), bought
  outright: one developer product per rarity (`shop_<rarity>`, granting `shopbuy:<rarity>`), the server
  remembering which item the player picked before the prompt (`Purchases.shop_pick`); each slot has a small
  per-player chance of being a Common or Rare item for the earned currency (`Purchases.shop_buy`).
  `UI/MysteryShop.luau`; protocol ops 47 to 49; `tests/shop.luau`, `tests/colecao.luau`.
- **The currency is "Coroas", drawn with a crown** (`Brand.CURRENCY`, `Brand.CURRENCY_ICON`). The code
  still calls it `stars`.
- **The Arsenal's pictures are this version's own.** Eight medieval drawings (`assets/arsenal-icons/`,
  embedded by `tools/arte/make_arsenal_icons.py`) replace RoWorld's renders: in the Arsenal's list
  (`src/shared/Assets/ArsenalIcons.luau`, `Brand.OWN_ARSENAL_ICONS`, `tests/arsenal_icons.luau`) and, through
  OwnArt's `render/<key>`, everywhere else a render was shown (previews, the starter offer, the shop slot).
- **A simpler title screen.** `Brand.LOBBY = "simples"`: the wordmark, PLAY SOLO, the multiplayer cards
  and four plain buttons (Arsenal, Locker, Shop, How to play), with the balance in a small chip top right;
  RoWorld's two large animated buttons, the greeting and the glow are off (`"completo"` brings them back).
  `Brand.LOBBY_ART = true` puts a painting (`OwnArt` key `lobby/bg`) behind the title and stops the map
  drifting there (`TitleScreen.PAINTED`, `MapView.still_title`). `src/client/UI/TitleScreen.luau`. With
  `Brand.MUSIC = false` the top bar has no music button and Settings no music row (it is `true` since
  2026-11-11).
- **The Arsenal window has its own layout** (`UI/Arsenal.luau`): a wide window, a shelf of one card per
  item across the top (picture on the item's colours, name, price; it scrolls sideways when the screen
  is narrow), and under it the chosen item, its preview on the left and its words and buttons on the
  right. `UITheme.icon("arsenal")` now finds the Arsenal's mark.
- **A press never reaches what is behind an open window.** `Widgets.add_blocker` puts an invisible
  button under a full-screen window's own parts and `Widgets.guard_presses` makes a kit button drawn
  before an open window ignore its press; `UIRoot` applies both to every modal window.
  `tests/janelas.luau`.
- **A new player is asked before the tutorial starts.** RoWorld started a new player's first match by
  itself as the tutorial; here `UIRoot._tutorial_step` opens `UI/TutorialAsk.luau` ("Do you want the
  tutorial?") first. Yes calls `UIRoot.start_tutorial`; no saves the `[ui]` setting
  `tutorial = "declined"` (`Data/Tutorial.DECLINED`), so `Tutorial.is_new` is false from then on and the
  question is asked once. It waits while another window is open, and closes unanswered if the player is
  taken into a match. `tests/pergunta_tutorial.luau`.
- **"Replay as new player" is removed**: the game menu's button, `UIRoot.replay_as_new_player`,
  `Session.new_player`, `Telemetry.new_player`, the server's `OP.NEW_PLAYER` handler and
  `Purchases.reset_new_player`. Protocol number 18 stays unused.
- **The air strike flies a dragon.** `Assets/ArsenalArt.attack.airfield` (`assets/ataque/airfield.png`,
  seen from above, head to the left; OwnArt key `attack/airfield`, a name-only id) is what the Arsenal's
  preview flies (`UI/ArsenalDemo`) and what `Map/UnitLayer` draws for `N_AIRSTRIKE` in a match, turned
  along its flight (`Map/StrikeArt.luau`: `heading`, `size`); the missile's sprite stays as the
  fallback while the drawing is not in the label. The shop card keeps `renders.airfield`
  (`assets/arsenal-icons/airfield.png`). `tests/strike_art.luau`.
- **Coroas purchases ask first.** `UI/ConfirmBuy.luau` (one window, made by `UIRoot`, drawn above the
  sellers and the crate's opening show) is opened by the Coleção's crate button and the opening show's
  "another" (`Locker._buy_pressed`), a Coroas offer of the Loja Misteriosa (`MysteryShop._pressed`) and the
  Arsenal's Coroas button (`Arsenal._stars_pressed`, which keeps RoWorld's second press only when given no
  window). Cancel, a press outside, or the seller closing buys nothing; Confirm re-runs the seller's
  purchase with `confirmed = true`, so every check runs again. Its buttons ignore presses for `ARM_S`
  (0.35 s) after it opens (a double click), and the sellers' backdrops ignore the press that cancels it
  (`ConfirmBuy.busy`). Robux purchases have Roblox's own prompt. `tests/confirmar_compra.luau`.
- **The floor under a new player's army has a switch.** `Data/Tutorial.ROOKIE_FLOOR_ON` (read by
  `UIAdvisor.check_floor`), `true` as in RoWorld: in a player's first match (`ROOKIE_MATCHES = 1` since
  2026-11-12, RoWorld's was 5; the tutorial's matches are not counted: `Tutorial.rookie(before, tutorials)`,
  `Tutorial.tutorials(ui)`, the saved `[ui] tutorial_n`) 20% of the cap stays home. (It was `false` for a few hours on 2026-11-11; the owner asked for it back.) While a floor,
  this one or the tutorial's, holds everything back, the line under the Attack bar reads
  `FLOOR_REASON` instead of "Sends 0 troops" (`CommandBar.sends_text`). `tests/barra_ataque.luau`.
- **A slot's card counts down.** `BuildButton.refresh` rewrites the hint card while it is the one on
  screen (`_sync_hint`); RoWorld kept a changed reason ("Ready in 0:12") off the slot's redraw and the
  card kept the text it was opened with. `tests/dica_contagem.luau`.
- **A global ranking.** `server/Ranking.luau` keeps two all-time boards in ordered data stores
  (`RankVitorias_v1`: public-match wins; `RankReinos_v1`: nations conquered in public matches, bots
  included, tribes not; `_studio` is appended in Studio, and without API access Studio falls back to an
  in-memory store). `ServerMain`'s `on_result` hook (the one that pays Coroas, so solo matches never
  reach it) calls `Ranking.record`; additions are `IncrementAsync`, retried only on a throttling drop. Each
  server reads a board's top 100 at most every `REFRESH_S` (120 s; a failed read keeps the old list and
  waits `FAIL_S`), and a player's own totals at most every `MINE_S`. The client asks with `OP.RANK_GET`
  (answered at most once every 3 s per player) and gets `OP.RANK`; `Session.clean_rank` bounds what it
  keeps. `UI/Ranking.luau` is the window (two tabs, the player's own row pinned below the list, names set
  verbatim, never through the language layer); `TitleScreen` has the RANK button left of the Coroas chip
  and `UIRoot` treats the window as a lobby modal. `tests/ranking.luau`, `tests/ranking_tela.luau`.
- **Daily missions and a monthly pass.** `Data/MyMissions.luau` is the owner's list (pt-BR); the rules are
  `Data/Missions.luau`: the calendar (days and months turn at midnight in Brasília, by the server's clock),
  three daily missions drawn from the pool with the day as seed (the same for everyone, never two on one
  counter), six monthly ones, and a state kept in the player's record (`missions`) that counts matches
  played, wins, kills, minutes, top-3 finishes and daily missions done. `Purchases.add_stars(player, n,
  match)` counts a match's result and pays what became due in the same write; `Rewards` adds it to the
  payout as its own line, outside the 2x multiplier. Daily missions pay the currency to everyone. The
  monthly ones count for everyone but pay only with the pass: a developer product (`Products.pass`, line
  `pass` of `MyProducts`; with id 0 the window says EM BREVE) whose receipt turns the pass on for the calendar
  month and pays at once what was already done. Three monthly missions give the season's skin, flag and
  pet (`Assets/Seasons.luau`, generated by `tools/arte/cosmeticos.py`; twelve seasons, one a month, the
  same each year): kept for good, shown in the Coleção only to their owners, never in a crate or the
  shop; one already owned pays the currency instead. No new message: the state travels with the
  inventory (`inventory.missions`, with the server's clock) and `Session.missions_view` reads it.
  `UI/Missions.luau` is the window (two tabs, the season's panel and the pass's button), opened by the
  title's MISSIONS button. `tests/missoes.luau`, `tests/missoes_janela.luau`. Note for forks: a paid pass
  that pays the soft currency makes that currency indirectly purchasable, which matters where the
  currency buys random crates (see GUIA.md, section 14).
- **The place runs the new chat.** Both project files set `TextChatService.ChatVersion =
  "TextChatService"`. Without it a Rojo-built place runs the legacy chat, whose window is a PlayerGui
  ScreenGui (DisplayOrder 6) and was covered by the lobby's painting (the interface is DisplayOrder 10).
  `tests/projeto.luau`.
- **Numbers follow the language.** `Lang.number` writes 31.250 in Portuguese; `UICtx.commas` uses it.
- **Redeem codes.** Settings has a "Redeem code" row. The owner's list is `src/server/MyCodes.luau`
  (`["CODE"] = { coroas = N, expira = "YYYY-MM-DD"?, ativo = false? }`, server only);
  `src/server/Codes.luau` reads it, `Purchases.redeem_code` pays once per player in the same write that
  records the code, `ServerMain` limits tries (6 a minute). Protocol ops 43 / 44. `tests/codes.luau`.
- **The map zoomed out** (2026-11-11). Past the map's edge the view shows open sea
  (`MapSurface.OUTSIDE`, terrain_pixel's darkest water, used by `MapView`'s backdrop) where RoWorld shows
  grey. Eldoria was then redrawn with sea all around (the map is flat, nothing wraps, so land on its edge
  was a coast cut straight: a cap along the whole bottom edge, islands cut by the sides): no land within
  43 tiles of an edge, every edge tile that darkest water, the cap now five islands (`SOUTH`), 62 of the
  71 kingdoms where they were, 577,814 land tiles (were 650,170). RoWorld's Earth has 43 land tiles on
  each side and Antarctica along its whole bottom edge. `tools/arte/previa_zoom.py` draws
  `assets/previa-zoom-afastado.png`. A structure's icon keeps its glyph at every zoom and stops shrinking at 0.4 of its
  size (`Map/StructureZoom.luau`, a new pure module `StructureLayer.tick` sizes with), where RoWorld
  turned it into a glyphless dot at zoom <= 1.2: on a 2000 x 1000 map with k_lin 1 that was the farthest
  zoom of a 1280 x 720 window. `StructureZoom.DOTS_ZOOM = 1.2` brings the dots back.
  `tests/zoom_mapa.luau`.
- **Codes created in game.** A game admin types `/codigo criar <NAME> <amount> [7d | 31/12/2026] [100x]`,
  `/codigo gerar <amount> ...` (a random name), `/codigo lista | ver | desligar | ligar | apagar` in
  the chat (`src/server/CodeCommands.luau`). The codes live in one key of the data store
  `ConquistaMundialCodigos_v1` (`src/server/CodeStore.luau`; `_studio` in a playtest), so every server
  has them with nothing to publish: a server reads the key at most every 60 s, and once more (at most
  every 15 s) when a player types a code it does not know. `Nx` limits a code to N players in the whole
  game: `Purchases.redeem_code` takes one use in the shared key before it pays and gives it back when
  the player is not paid; a code without a limit costs no shared write. A name on `MyCodes` belongs to
  that list alone. The answer goes back as `OP.NOTICE` with a third value, the lines the client also
  writes into the chat window (`UIRoot.chat_lines`). `tests/gerar_codigos.luau`.
- **Owner commands.** A game admin types `/moedas dar|tirar|ver <player> [amount]` in the chat to give,
  take or read a player's balance (`src/server/OwnerCommands.luau`, `tests/owner_commands.luau`).
- **The owner's panel.** The lobby has an ADMIN button only a game admin sees (the `AF_Admin`
  attribute the server sets), which opens `UI/AdminPanel.luau`: three pages (Coroas, redeem codes,
  ranking) that do what the chat commands do, with fields and buttons. Every press is one
  `OP.ADMIN` request (`action`, `args`); `ServerMain` refuses anyone not in its own `admins` table
  before anything runs, and `src/server/AdminActions.luau` asks again. The answer is `OP.ADMIN_RESULT`
  (a sentence, and the list of codes for the owner alone). `Ranking.remove` takes a player out of the
  all-time lists, this week's and last week's final ones. Deleting a code and removing a player take
  a second press. `tests/painel_admin.luau`, `tests/painel_admin_tela.luau`.
- **The phone lobby's dock** is at most 640 wide (`TitleScreen.DOCK_PHONE_W`; it was 760).
- **The interface is in Portuguese.** The code still writes English; `src/shared/Data/Lang.luau` turns
  every text into the language of `Brand.LANGUAGE` on its way to the screen, from the dictionary
  `src/shared/Data/LangPt.luau` (`tests/lang.luau`). A text with no entry is shown in English.
- **No outside servers.** RoWorld's own lobby service is switched off; matchmaking runs on Roblox's
  MemoryStore, which works in any experience.

The "no outside servers / Brand file / free cosmetics" change is commit `b9b43f7` of the fork
[Milliradiant/roworld](https://github.com/Milliradiant/roworld), applied on top of RoWorld's latest code
(without that fork's garrisons and fog of war). The rules are RoWorld's, unchanged.

`assets/produtos/` holds what the owner types into the Creator Dashboard for each of the 13 developer
products of `Data/MyProducts.luau`: a 512 x 512 icon per product (`tools/arte/produtos.py` draws them from
the Arsenal figures and the glyphs) and `PRODUTOS.md` with a name, a description and the price. One
`crate` product serves the three crates: the tab the purchase was made in decides which one opens.

`assets/pagina/` holds the experience page's material: `icone.png` (512 x 512), `miniatura.png`
(1920 x 1080, with the title; `miniatura-sem-titulo.png` without it) and `DESCRICAO.md` (the description,
pt-BR). The two source paintings (`*-arte.png`) are AI-generated; `tools/arte/pagina.py` crops and scales
them and writes the title in Rubik. The thumbnail is an illustration, not a capture of the game.

**The 13 products exist and are wired (2026-11-11).** `Data/MyProducts.luau` carries the ids of the
owner's developer products, so the game now ships selling: each Arsenal unit for Robux or the currency,
the two boosters for Robux, the crate's Robux button, the mystery shop's offers and the result screen's
2x offer. The ids were checked against Roblox's public product details (all 13 on sale, one universe,
name and price matching their line); no purchase was made, real or in Studio. A line set back to
`id = 0` takes its item off sale. `tests/my_products.luau` checks that every line has its own id and that none is
one of RoWorld's; the tests that describe the no-product behaviour clear the id themselves.

- **Nothing of RoWorld's own accounts is left in the place** (review of 2026-11-12). Removed: the
  developer's account id in `client/Main` (the "autosolo" launch hook is now for the experience's owner,
  `Main.owner_user_id`), the exclusive skin made for one of RoWorld's players (`Cosmetics.exclusive_skins`
  is empty; `Cosmetics.add_exclusive` is the machinery), RoWorld's 28 product ids in `Data/Products` (never
  used: the ids are the owner's, `Data/MyProducts`), and the internal names: the place's folders are
  `Conquista`, `ConquistaServer`, `ConquistaClient` (were `Airfront…`), the GUIs and the stores follow
  (`ConquistaSettings_v1`, `conquista_v1`, `conquista_clock`). The EncodingService probes in
  `Core/MapCodec` and `Net/Protocol` carry new payloads ("mundial" / `bXVuZGlhbA==`, "conquista"). What
  stays: the copyright notice, the comments that say where code came from, and the ids of RoWorld's
  uploaded images, all of them replaced at run time by `Assets/OwnArt` (2026-11-12: the last 31 used as
  they were are gone: `UIKit` and `UiShapes` are redrawn by `tools/arte/formas.py`, `CrateModel` is a
  chest of plain blocks, `SkinPreviews` was unused and is deleted). `tools/revisao/vestigios.py` and
  `tools/revisao/imagens.py` list; `tests/vestigios.luau` and `tests/imagens_proprias.luau` guard.

- **Ranked matches, daily login, mascot, player card, Roblox badges** (2026-11-12). A fourth kind of
  match, RANQUEADA, with monthly tiers and prizes (`shared/Data/Ranked`); a seven-day login reward
  (`shared/Data/Login`); the pet a player wears stands on their capital and celebrates a conquest
  (`shared/Data/Mascot`, `client/Map/NameLayer`); a card on the title with the player's tier, wins
  and kingdoms (`client/UI/PlayerCard`); eight Roblox badges, given once the owner makes them and
  fills `shared/Data/MyBadges` (`shared/Data/Badges`, `server/BadgeAwards`; pictures in
  `assets/emblemas/`). GUIA.md, section 15.

## Build it

The game is a [Rojo](https://rojo.space) project.

```
rojo build release.project.json -o ConquistaMundial.rbxl
```

Open `ConquistaMundial.rbxl` in Roblox Studio and press Play to test it solo.

## Put it on Roblox

1. In Studio: **File → Publish to Roblox As… → Create new experience.**
2. **Game Settings → Security:** turn on **Enable Studio Access to API Services** (so saves and lobbies
   also work when testing in Studio) and **Allow Mesh / Image APIs** (the map is drawn with
   EditableImage). Roblox only allows the second one for an account that is 13+ and ID-verified.
3. Publish again after changing settings, then make the experience public (or keep it private and add
   friends) on the Creator Dashboard.

Things that won't carry over from RoWorld:

- **Music and sound effects**: RoWorld's uploads are locked to its own experiences, so none is used. The
  ids in `src/shared/Assets/Soundtrack.luau`, `Audio.luau`, `AudioExtra.luau` and `AudioUI.luau` are
  Creator Store audio the owner chose (they downloaded without a login, which suggests they are public;
  whether each one plays in the experience was not checked in Studio).
- **Images**: the icons, pictures and effects are this version's own and are drawn by the game (see
  above). Neutral shapes (panel shadows, glows, the radial menu's pages, the title's vignette) are
  redrawn too (`tools/arte/formas.py`, switch `Brand.OWN_SHAPES`) and swapped in through RoWorld's ids,
  which remain the lookup keys and the fallback when an EditableImage cannot be made; ten of the
  originals are in `assets/ui_shapes` for comparison (and the skins' patterns in `assets/skins`). RoWorld's other art folders and their generators (`tools/assets/make_*` for icons,
  sprites, renders, effects, rails, branding, flags) were removed from this tree.

`tools/` and `services/` are RoWorld's own development and operations scripts (publishing to their
experience, their lobby server). They are kept as part of the source; this version does not use them. Several of them
read art folders this tree no longer has (`assets/arsenal`, `assets/icons`, `assets/map_sprites`,
`assets/globe`, `assets/audio`) and will not run here as they are.

## Tests

`lune run tests/<name>.luau` with Lune 0.10 or newer. Compare against a clean RoWorld checkout rather than
expecting all green.

`tests/telas.luau` builds the new screens (title, Coleção, crate opening, Loja Misteriosa, Arsenal, ranking,
missions) from
the real UI code on a headless stand-in for Roblox's GUI (`tests/ui_harness.luau`), at 1280×720 and
844×390, checks that nothing leaves the screen or overlaps, and writes each layout to
`assets/telas/*.json`; `python3 tools/arte/telas.py` draws those as `assets/previa-*.png`. They are
layouts computed outside Roblox, not screenshots.

## Licence

GNU Affero General Public License v3 with the additional terms at the end of `LICENSE`. In short, any
public version must:

- keep "© OpenFront and Contributors" visible (the title screen's footer and the Help window's licence
  card do);
- not be called OpenFront or claim to be endorsed by it;
- let players get the source: the Help card's Source line shows `Brand.SOURCE_REPO`, so point that at a
  public repository with the code that is actually running.
