--!nocheck
-- The lobby's block that starts a match, in every state (2026-11-12: "improve the lobby's block of
-- solo and online matches, it still looks like RoWorld's"). On a desktop it is a row of four tiles:
-- SOLO and one per kind of public match. This walks the tiles through what the hub can say (no
-- list yet, connecting, offline, a list, in line, on the way, a kind with no match open) and
-- through a window that becomes phone-sized and back, and checks that every text stays inside its
-- tile and nothing is lost on the way.
--   lune run tests/lobby_blocos.luau
local H = require("./ui_harness")
local Signal = require("../src/shared/Core/Signal")
local UICtx = require("../src/client/UI/UICtx")
local UITheme = require("../src/client/UI/UITheme")
local Lang = require("../src/shared/Data/Lang")
Lang.use("pt")

local checks, failed = 0, 0
local function check(ok: boolean, what: string)
	checks += 1
	if not ok then
		failed += 1
		print("FAIL: " .. what)
	end
end

local root, gui = H.root(1280, 720, false)
H.fake_game()
local TitleScreen = require("../src/client/UI/TitleScreen")

local status = "connected"
local s = {
	multiplayer_status = function()
		return status
	end,
	multiplayer_available = function()
		return status == "connected"
	end,
	inventory = { owned = {}, equipped = {}, crates_bought = 0, crates_allowed = false, crates_stars = true, stars = 1200 },
	credits = { crate = 0 },
	inventory_changed = Signal.new(),
	credits_changed = Signal.new(),
}
local ctx = UICtx.new()
ctx.vp = root.vp
ctx.compact = false
ctx.touch = false
ctx.touch_device = false
ctx.session = s
local k = UITheme.scale
ctx.reserved_top_left = Rect.new(0, 0, 280 / k, 58 / k)
function ctx:sfx() end

local t = TitleScreen.new(ctx)
root:add_child(t)
t:set_map_name("Eldoria")
t:apply_layout()
H.step(30)

--- Every text of a tile lies inside the tile, and the tile inside the dock.
local function tiles_ok(what: string)
	local dx, dy, dw, dh = H.rect(t._dock.gui)
	check(math.abs(dx + dw / 2 - H.view.X / 2) < 1.5, what .. ": the dock is centred")
	check(dy + dh <= H.view.Y + 0.5 and dx >= 0, what .. ": the dock is on screen")
	local shown = 0
	for i, c in t._cards do
		if c.btn.visible then
			shown += 1
			local cx, cy, cw, ch = H.rect(c.btn.gui)
			check(cx >= dx - 0.5 and cx + cw <= dx + dw + 0.5 and cy >= dy - 0.5 and cy + ch <= dy + dh + 0.5, string.format("%s: tile %d inside the dock", what, i))
			for name, node in { title = c.title, sub = c.sub, status = c.status, pill = c.pill } do
				if node.visible and (node.text == nil or node.text ~= "") then
					local x, y, w, h = H.rect(node.gui)
					check(
						x >= cx - 0.5 and x + w <= cx + cw + 0.5 and y >= cy - 0.5 and y + h <= cy + ch + 0.5,
						string.format("%s: tile %d's %s inside it (%.0f..%.0f of %.0f..%.0f) %q", what, i, name, x, x + w, cx, cx + cw, tostring(node.text))
					)
				end
			end
			-- the text itself fits its label (nothing cut): measured by the harness's font metrics
			for name, node in { title = c.title, sub = c.sub, status = c.status } do
				if node.visible and node.text ~= "" then
					local need = node:get_combined_minimum_size().X
					local _, _, w = H.rect(node.gui)
					check(node.clip_text == true or need * UITheme.scale <= w + 1.5, string.format("%s: tile %d's %s is not wider than its place %q", what, i, name, tostring(node.text)))
				end
			end
		end
	end
	return shown
end

check(t._tiles == true, "a desktop: the tiles")

-- 1. no list yet (the hub has not answered): the first tile alone carries the server's word
status = "connecting"
t:set_lobbies(nil, nil)
t:apply_layout()
H.step(20)
check(tiles_ok("connecting") >= 1, "connecting: a tile shows")
check(t._cards[1].title.text == "CLÁSSICA" and t._cards[1].status.text == "Conectando…", "connecting: the tile says so: " .. tostring(t._cards[1].status.text))
check(not t._mp_join.visible, "connecting: no button to press")
local sx, sy, sw, sh = H.rect(t._solo_tile.gui)
check(t._solo_tile.visible and sw > 100 and sh > 100, "connecting: the SOLO tile is there")

-- 2. offline
status = "offline"
t:_refresh_mp()
t:apply_layout()
H.step(20)
tiles_ok("offline")
check(t._cards[1].status.text == "Offline" and t._mp_join_l.text == "TENTAR DE NOVO", "offline: says so, with RETRY: " .. tostring(t._cards[1].status.text) .. " / " .. tostring(t._mp_join_l.text))
do
	local x, _, w = H.rect(t._mp_join_l.gui)
	local px, _, pw = H.rect(t._mp_join.gui)
	check(x >= px - 0.5 and x + w <= px + pw + 0.5, "offline: RETRY fits its button")
end

-- 3. the hub's list: three kinds
status = "connected"
local list = {
	{ id = "a", map = "valtara", map_name = "Valtara", max = 15, players = 4, starts_in = 41, joinable = true },
	{ id = "b", map = "world", map_name = "Eldoria", max = 45, players = 12, starts_in = 63, joinable = true, mode = "ranked" },
	{ id = "c", map = "valtara", map_name = "Valtara", max = 20, players = 6, starts_in = 77, joinable = true, mode = "team", teams = 4 },
}
t:set_lobbies(list, { "ffa", "ranked", "team" })
t:apply_layout()
H.step(20)
check(tiles_ok("three kinds") == 3, "three kinds: three tiles")
-- (2026-11-12: CLÁSSICA, RANQUEADA, EQUIPES; Eldoria has no tile of its own any more)
check(t._cards[2].title.text == "RANQUEADA", "the second tile is the ranked match: " .. tostring(t._cards[2].title.text))
check(t._cards[2].sub.text == "Escudeiro  ·  0 / 100", "... and says the player's rank and points: " .. tostring(t._cards[2].sub.text))
check(t._cards[3].title.text == "EQUIPES", "the third is the team game: " .. tostring(t._cards[3].title.text))
for i = 1, 3 do
	check(t._cards[i].title.text ~= "ELDORIA", "no tile is named after Eldoria (" .. i .. ")")
end
check(t._cards[1].pill_l.text == "ENTRAR" and t._cards[1].pill.visible, "three kinds: JOIN is back on the first tile after RETRY: " .. tostring(t._cards[1].pill_l.text))
check(UITheme.equal(t._cards[1].pill_l.color, UITheme.CYAN), "... in its own colour again, not the offline grey")

-- 4. a kind with no match open
t:set_lobbies({ list[1], list[2] }, { "ffa", "ranked", "team" })
t:apply_layout()
H.step(20)
check(tiles_ok("no team game open") == 3, "no team game open: its tile stays")
check(t._cards[3].status.text == "Abre em breve" and t._cards[3].sub.text == "Jogo de equipes", "... and says it opens soon: " .. tostring(t._cards[3].status.text) .. " / " .. tostring(t._cards[3].sub.text))
t:set_lobbies(list, { "ffa", "ranked", "team" })

-- 5. the player pressed JOIN on the free-for-all: asking, in line, on the way
t:set_public({ state = "joining", mode = "ffa" })
t:apply_layout()
H.step(20)
tiles_ok("joining")
check(t._cards[1].status.text == "Procurando um lugar…" or string.find(t._cards[1].status.text, "…", 1, true) ~= nil, "joining: the tile says it is finding a seat: " .. tostring(t._cards[1].status.text))
t:set_public({ state = "line", mode = "ffa" })
t:apply_layout()
H.step(20)
tiles_ok("in line")
check(string.find(t._cards[1].status.text, "Na fila", 1, true) ~= nil, "in line: the tile says so: " .. tostring(t._cards[1].status.text))
check(t._cards[1].thumb_node.visible and t._cards[1].thumb.Image ~= "", "in line: the tile keeps its map picture")
check(t._cards[1].pill_l.text == "CANCELAR", "in line: the button cancels: " .. tostring(t._cards[1].pill_l.text))
t:set_public({ state = "going", mode = "ffa", info = { map = "valtara", map_name = "Valtara" } })
t:apply_layout()
H.step(20)
tiles_ok("going")
check(t._cards[1].title.text == "VALTARA", "on the way: the tile is named after the map: " .. tostring(t._cards[1].title.text))
t:set_public({ state = "idle" })
t:apply_layout()
H.step(20)
check(t._cards[1].title.text == "CLÁSSICA", "back to idle: PUBLIC again")

-- 6. only one kind (a hub with nothing but the free-for-all): SOLO and one tile, no hole
t:set_lobbies({ list[1] }, { "ffa" })
t:apply_layout()
H.step(20)
check(tiles_ok("one kind") == 1, "one kind: one tile beside SOLO")
do
	local dx, _, dw = H.rect(t._dock.gui)
	local ax, _, aw = H.rect(t._solo_tile.gui)
	local bx, _, bw = H.rect(t._cards[1].btn.gui)
	check(ax - dx < 40 and (dx + dw) - (bx + bw) < 40, string.format("one kind: the two tiles fill the row (left gap %.0f, right gap %.0f)", ax - dx, (dx + dw) - (bx + bw)))
end
t:set_lobbies(list, { "ffa", "ranked", "team" })
t:apply_layout()
H.step(20)

-- 7. the solo menu and back: the tiles return whole
t:open_solo_menu()
H.step(20)
check(t._solo_panel.visible == true and t._dock.visible == false, "PLAY: the solo menu takes the dock's place")
t:close_solo_menu(true)
H.step(20)
check(t._dock.visible == true and tiles_ok("after the solo menu") == 3, "closing it: the tiles are back")

-- 7b. a press on a tile selects it; only the tile's own button starts the match (2026-11-12: "a
-- click outside the JOIN button already starts the match; make it only select")
local asked, left, solo_opened = {}, 0, 0
t.join_public:Connect(function(mode)
	table.insert(asked, mode)
end)
t.leave_line:Connect(function()
	left += 1
end)
do
	local cards = t._cards
	check(t._sel == 1, "at first PUBLIC is the selected tile")
	check(cards[1].btn.theme_type_variation == "PublicButton" and cards[2].btn.theme_type_variation == "GlassButton", "... and the only one with the bright border")
	-- the JOIN bar is a button of its own, exactly over the pill's drawing, inside the tile
	for i, c in cards do
		local jx, jy, jw, jh = H.rect(c.join.gui)
		local px, py, pw, ph = H.rect(c.pill.gui)
		check(c.join.visible and c.join.gui:IsA("GuiButton") and c.join.gui.Active == true, "tile " .. i .. ": JOIN is a button that takes presses")
		check(math.abs(jx - px) < 1 and math.abs(jy - py) < 1 and math.abs(jw - pw) < 1 and math.abs(jh - ph) < 1, string.format("tile %d: the JOIN button lies exactly over its drawing (%.0f,%.0f %.0fx%.0f and %.0f,%.0f %.0fx%.0f)", i, jx, jy, jw, jh, px, py, pw, ph))
		check(jw > 60 and jh > 20, string.format("tile %d: the JOIN button has a size to press (%.0f x %.0f)", i, jw, jh))
		-- it is inside the tile's own button, and comes after the drawing (so it is the one on top)
		local inside_tile, node = false, c.join.gui
		while node ~= nil do
			if node == c.btn.gui then
				inside_tile = true
			end
			node = node.Parent
		end
		check(inside_tile, "tile " .. i .. ": the JOIN button is part of the tile")
		local kids = c.join.gui.Parent:GetChildren()
		local ji, pi = table.find(kids, c.join.gui), table.find(kids, c.pill.gui)
		check(ji ~= nil and pi ~= nil and (c.join.gui.ZIndex > c.pill.gui.ZIndex or (c.join.gui.ZIndex == c.pill.gui.ZIndex and ji > pi)), "tile " .. i .. ": the JOIN button is over the drawing, not under it")
		-- the tile's texts do not take the press from the tile (they are not active)
		check(c.title.gui.Active ~= true and c.status.gui.Active ~= true and c.pill.gui.Active ~= true, "tile " .. i .. ": its texts and the pill's drawing let the press through")
	end
	-- a press on the tile, outside the button: selected, nothing asked
	cards[2].btn.pressed:Fire()
	H.step(5)
	check(#asked == 0 and not t:public_busy(), "a press on the RANQUEADA tile outside JOIN asks for no match")
	check(t._sel == 2, "... it selects the tile")
	check(cards[2].btn.theme_type_variation == "PublicButton" and cards[1].btn.theme_type_variation == "GlassButton" and cards[3].btn.theme_type_variation == "GlassButton", "... which alone has the bright border now")
	check(cards[2].paint_on == true and cards[1].paint_on == false, "... and the bright JOIN button")
	tiles_ok("a tile selected")
	cards[1].btn.pressed:Fire()
	cards[3].btn.pressed:Fire()
	H.step(5)
	check(#asked == 0 and t._sel == 3, "the same on the other tiles: selected, nothing asked")
	-- the SOLO tile: selected by a press on it, and the solo menu stays closed until PLAY
	t._solo_tile.pressed:Fire()
	H.step(5)
	check(t._sel == 0 and t._solo_panel.visible ~= true and t._dock.visible == true, "a press on the SOLO tile selects it and opens nothing")
	check(cards[3].btn.theme_type_variation == "GlassButton" and t._solo_tile_on == true, "... SOLO is the bright one, no match tile is")
	t._solo.pressed:Fire()
	H.step(10)
	check(t._solo_panel.visible == true, "PLAY opens the solo menu")
	t:close_solo_menu(true)
	H.step(10)
	-- the JOIN button: selects its tile and asks for the match
	cards[2].join.pressed:Fire()
	H.step(5)
	check(#asked == 1 and asked[1] == "ranked", "JOIN on the RANQUEADA tile asks for a ranked match: " .. tostring(asked[1]))
	check(t._sel == 2 and t:public_busy(), "... and selects it; the title is busy joining")
	-- while joining, the buttons of the others are off
	check(cards[1].join.disabled == true and cards[3].join.disabled == true, "while joining one, the JOIN of the others is off")
	-- in line: a press on the tile does not leave the line, CANCEL does
	t:set_public({ state = "line", mode = "ranked" })
	H.step(5)
	cards[2].btn.pressed:Fire()
	check(left == 0, "in line: a press on the tile outside the button keeps the place in line")
	check(cards[2].pill_l.text == "CANCELAR", "in line: the button says CANCEL")
	cards[2].join.pressed:Fire()
	check(left == 1, "in line: CANCEL leaves the line")
	t:set_public({ state = "idle" })
	t:apply_layout()
	H.step(10)
	check(#asked == 1, "nothing else was asked on the way")
end

-- 7c. with no list (one server's own match): the first tile's button starts it, the tile selects
do
	local multi = 0
	t.play_multi:Connect(function()
		multi += 1
	end)
	t:set_lobbies(nil, nil)
	t:set_lobby({ stage = "idle" })
	t:apply_layout()
	H.step(10)
	t._cards[2].btn.pressed:Fire() -- (hidden now; whatever was selected, the first tile's press selects it)
	t._cards[1].btn.pressed:Fire()
	check(multi == 0 and t._sel == 1, "one server: a press on the tile selects it and starts nothing")
	check(t._cards[1].join.visible and t._cards[1].join.disabled ~= true, "one server: the START button is there")
	t._cards[1].join.pressed:Fire()
	check(multi == 1, "one server: START starts it")
	status = "connecting"
	t:_refresh_mp()
	H.step(5)
	check(not t._cards[1].join.visible, "connecting: no button, and none to press")
	status = "connected"
	t:set_lobby({})
	t:set_lobbies(list, { "ffa", "ranked", "team" })
	t:apply_layout()
	H.step(20)
	check(tiles_ok("after the single-server states") == 3, "the three tiles are back")
end

-- 8. the window becomes phone-sized and big again: rows, then tiles, nothing lost
local function has_ancestor(node: any, anc: any): boolean
	local p = node
	while p ~= nil do
		if p == anc then
			return true
		end
		p = p:get_parent()
	end
	return false
end
ctx.compact = true
t:apply_layout()
H.step(20)
check(t._tiles == false, "phone-sized: rows")
check(t._solo.text == "JOGAR SOLO", "phone-sized: the PLAY SOLO bar: " .. tostring(t._solo.text))
check(has_ancestor(t._solo, t._dock) and not has_ancestor(t._solo, t._solo_tile), "phone-sized: PLAY SOLO left the tile and is in the dock")
check(not has_ancestor(t._solo_tile, t._dock) or t._solo_tile.visible == false, "phone-sized: the SOLO tile is gone")
for i, c in t._cards do
	check(c.tiled == false and has_ancestor(c.btn, t._dock), "phone-sized: card " .. i .. " is a row in the dock")
	local _, _, cw, ch = H.rect(c.btn.gui)
	check(cw > ch * 1.5, string.format("phone-sized: card %d lies flat (%.0f x %.0f)", i, cw, ch))
end
check(t._cards[1].title.text == "CLÁSSICA", "phone-sized: the same one-word title (CLÁSSICA): " .. tostring(t._cards[1].title.text))
do
	-- (phones: three kinds side by side have no JOIN button to aim at, so the row is the button)
	local before = #asked
	check(t._cards[1].join:get_parent() == nil, "phone-sized: the tiles' JOIN button is gone with the tiles")
	check(t._cards[1].btn.theme_type_variation == "PublicButton" and t._cards[2].btn.theme_type_variation == "GlassButton", "phone-sized: the first row keeps its accent, whatever tile was selected")
	t._cards[3].btn.pressed:Fire()
	check(#asked == before + 1 and asked[#asked] == "team", "phone-sized: a tap on a row joins that match")
	t:set_public({ state = "idle" })
end
ctx.compact = false
t:apply_layout()
H.step(20)
check(t._tiles == true and tiles_ok("big again") == 3, "big again: the tiles")
check(t._solo.text == "JOGAR" and has_ancestor(t._solo, t._solo_tile), "big again: PLAY is inside the SOLO tile")
check(t._cards[1].title.text == "CLÁSSICA", "big again: the one-word title")
do
	local tiles = { t._solo_tile.gui, t._cards[1].btn.gui, t._cards[2].btn.gui, t._cards[3].btn.gui }
	local _, y0, w0, h0 = H.rect(tiles[1])
	for i, g in tiles do
		local _, y, w, h = H.rect(g)
		check(math.abs(y - y0) < 1 and math.abs(h - h0) < 1 and math.abs(w - w0) < 1.5, "big again: tile " .. i .. " matches the first")
	end
end

-- 9. the old single-server lobby (no hub list, one server's stage): the first tile's short lines
t:set_lobbies(nil, nil)
t:set_lobby({ stage = "lobby", countdown_s = 30, queued = 3 })
t:apply_layout()
H.step(20)
tiles_ok("one server, lobby stage")
check(string.find(t._cards[1].status.text, "0:30", 1, true) ~= nil or string.find(t._cards[1].status.text, "0:29", 1, true) ~= nil, "one server: the countdown shows: " .. tostring(t._cards[1].status.text))
t:set_lobby({ stage = "over" })
t:apply_layout()
H.step(20)
tiles_ok("one server, match ending")
t:set_lobby({})
t:apply_layout()
H.step(20)
tiles_ok("one server, idle")

print(string.format("lobby_blocos: %d checks, %d failed", checks, failed))
if failed > 0 then
	error("lobby_blocos failed")
end
