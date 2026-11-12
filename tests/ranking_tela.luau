--!nocheck
-- The RANK window (client/UI/Ranking) and what feeds it (client/Session), outside Roblox:
--   * opening it asks the server for the lists; lists that just came are not asked for again;
--   * what it says while it waits, when no answer comes, when there is no server, when a list is empty;
--   * the two tabs, the player's own row and numbers, "100+" outside the hundred;
--   * a player's name is drawn as it is (the language layer does not read it);
--   * a press outside and the close button close it; a press inside doesn't;
--   * Session: OP.RANK_GET goes out, OP.RANK comes in cleaned; junk never reaches the window;
--   * UIRoot stacks it with the lobby's other windows, and a match that starts takes it away.
--   lune run tests/ranking_tela.luau
local H = require("./ui_harness")
local fs = require("@lune/fs")
local Signal = require("../src/shared/Core/Signal")
local UICtx = require("../src/client/UI/UICtx")
local UITheme = require("../src/client/UI/UITheme")
local W = require("../src/client/UI/Widgets")
local RankWindow = require("../src/client/UI/Ranking")
local Session = require("../src/client/Session")
local Protocol = require("../src/shared/Net/Protocol")
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

local clock = 500.0
RankWindow.now = function()
	return clock
end
local ME = 77
RankWindow.user_id = function()
	return ME
end
-- (where a press is: Widgets asks Roblox's services, which are not here; the event carries it)
W.input_pos = function(io: any): Vector2
	return Vector2.new(io.Position.X, io.Position.Y)
end
W.screen_to_logical = function(v: Vector2): Vector2
	return v / UITheme.scale
end

local function press(b: any)
	H.fire(b.gui, "Activated")
	H.step(1)
end
local function press_at(node: any, x: number, y: number)
	H.fire(node.gui, "InputBegan", {
		UserInputType = Enum.UserInputType.MouseButton1,
		UserInputState = Enum.UserInputState.Begin,
		Position = Vector3.new(x, y, 0),
	})
	H.step(1)
end
--- The texts drawn under `node`, glued, without spaces.
local function shown(node: any): string
	local out = {}
	local function add(g: any)
		if type(g.Text) == "string" and g.Visible ~= false then
			table.insert(out, g.Text)
		end
	end
	add(node.gui)
	for _, d in node.gui:GetDescendants() do
		add(d)
	end
	return (string.gsub(table.concat(out), "%s", ""))
end

local function lists(n_wins: number, n_kills: number, me_wins: any, me_kills: any): any
	local wins, kills = {}, {}
	for i = 1, n_wins do
		wins[i] = { 1000 + i, "Vencedor" .. i, 900 - i * 3 }
	end
	for i = 1, n_kills do
		kills[i] = { 2000 + i, "Destruidor" .. i, 5000 - i * 11 }
	end
	return { ok = true, age = 0, at = clock, boards = { wins = wins, kills = kills }, me = { wins = me_wins or { 0 }, kills = me_kills or { 0 } } }
end

local VIEWS = {
	{ "pc", 1280, 720, false },
	{ "celular", 844, 390, true },
}

local function make(view: any, rank: any, server: boolean?)
	local root, gui = H.root(view[2], view[3], view[4])
	local s = {
		rank = rank,
		rank_changed = Signal.new(),
		asked = 0,
		-- (the weekly prize to claim comes with the inventory)
		inventory = {},
		inventory_changed = Signal.new(),
		rank_claimed = Signal.new(),
		claims = 0,
	}
	s.rank_get = function(_s)
		s.asked += 1
		return server ~= false
	end
	s.rank_claim = function(_s)
		s.claims += 1
		return server ~= false
	end
	local ctx = UICtx.new()
	ctx.vp = root.vp
	ctx.compact = view[4]
	ctx.touch = view[4]
	ctx.touch_device = view[4]
	ctx.session = s
	-- (the cards the insignias ask for: who asked, what it says, whether a tap forced it)
	s.hints = {}
	function ctx:show_hint(anchor: any, spec: any, force: boolean?)
		if force or not self.touch then
			table.insert(s.hints, { anchor = anchor, spec = spec, force = force == true })
		end
	end
	function ctx:hide_hint(anchor: any)
		table.insert(s.hints, { anchor = anchor, hide = true })
	end
	local k = UITheme.scale
	ctx.reserved_top_left = Rect.new(0, 0, (if view[4] then 200 else 280) / k, (if view[4] then 44 else 58) / k)
	function ctx:sfx() end
	local r = RankWindow.new(ctx)
	root:add_child(r)
	W.add_blocker(r)
	W.guard_presses(root, function()
		return { r }
	end)
	r:bind(s)
	return r, s, root
end

for _, view in VIEWS do
	local v = " (" .. view[1] .. ")"
	-- -----------------------------------------------------------------------------------------
	-- waiting, an answer, no answer
	-- -----------------------------------------------------------------------------------------
	do
		clock += 1000
		local r, s = make(view, nil)
		check(not r.visible and s.asked == 0, "closed, it asks nothing" .. v)
		r:open()
		H.step(30)
		check(r.is_open and r.visible and s.asked == 1, "opening it asks the server for the lists, once" .. v)
		check(r._empty.visible and string.find(shown(r._host), "Carregandooranking", 1, true) ~= nil, "while it waits: loading" .. v .. ": " .. shown(r._host))
		check(#r._rows == 0, "no rows yet" .. v)
		check(r._mine_value.text == "0" and r._mine_place.text == "—", "the player's own row: nothing yet" .. v)
		-- the answer
		s.rank = lists(100, 3, { 870, 10 }, { 0 })
		s.rank.boards.wins[10] = { ME, "Victory", 870 }
		s.rank.boards.wins[11][2] = ""
		s.rank_changed:Fire()
		H.step(5)
		check(#r._rows == 100 and not r._empty.visible, "the answer: a hundred rows, nothing said over them" .. v)
		check(r._rows[1].name.text == "Vencedor1" and r._rows[1].value.text == "897", "the first row: name and number" .. v)
		check(r._rows[1].place_l.text == "1" and r._rows[100].place_l.text == "100", "places 1 to 100" .. v)
		-- a name is never translated ("Victory" is "Vitória" in the game's texts)
		check(Lang.t("Victory") == "Vitória", "(the language layer does translate that word)")
		check(r._rows[10].name.text == "Victory", "a player called Victory is shown as Victory" .. v)
		check(string.find(shown(r._rows[10].node), "Victory", 1, true) ~= nil and string.find(shown(r._rows[10].node), "Vitória", 1, true) == nil, "on the screen too" .. v .. ": " .. shown(r._rows[10].node))
		check(r._rows[11].name.text == "Jogador", "a row without a name says Jogador" .. v)
		-- the player's own row, and only it, is marked
		local own = 0
		for _, row in r._rows do
			if row.own then
				own += 1
			end
		end
		check(own == 1 and r._rows[10].own, "the player's own row is the marked one" .. v)
		check(r._mine_place.text == "10" and r._mine_value.text == "870", "the player's row under the list: 10th with 870" .. v)
		check(r._col_value.text == "VITÓRIAS", "the number's column: VITÓRIAS" .. v .. ": " .. tostring(r._col_value.text))
		-- the other tab
		press(r._tabs[2])
		check(r._tab == 2 and #r._rows == 3 and r._rows[1].name.text == "Destruidor1", "the second tab shows the other list" .. v)
		check(r._col_value.text == "REINOS", "its column: REINOS" .. v)
		check(r._mine_place.text == "—" and r._mine_value.text == "0", "not in it, with nothing: a dash and 0" .. v)
		if not view[4] then
			check(string.find(shown(r._mine), "Destruaumreino", 1, true) ~= nil, "and how to get in" .. v .. ": " .. shown(r._mine))
		end
		check(r._tabs[2].button_pressed == true and r._tabs[1].button_pressed == false, "the tab pressed is the lit one" .. v)
		check(s.asked == 1, "changing tab asks the server nothing" .. v)
		press(r._tabs[1])
		check(r._tab == 1 and #r._rows == 100, "back to the first" .. v)
		-- closing: the button, then a press outside; a press inside leaves it open
		press(r._close_b)
		check(not r.is_open, "the close button closes it" .. v)
		H.step(30)
		check(not r.visible, "and it leaves the screen" .. v)
		clock += 5
		r:open()
		H.step(30)
		check(r.is_open and s.asked == 1, "opened again a moment later: the same lists, nothing asked" .. v)
		local px, py, pw, ph = H.rect(r._panel.gui)
		press_at(r._dim, px + pw / 2, py + ph / 2)
		check(r.is_open, "a press inside the window leaves it open" .. v)
		press_at(r._dim, 6, H.view.Y - 6)
		check(not r.is_open, "a press outside closes it" .. v)
		-- old lists are asked for again on opening
		clock += RankWindow.STALE_S + 1
		r:open()
		H.step(5)
		check(s.asked == 2 and #r._rows == 100, "lists older than " .. RankWindow.STALE_S .. " s: shown, and asked for again" .. v)
		-- and now and then while it stays open
		clock += RankWindow.ASK_EVERY_S - 5
		r:tick()
		check(s.asked == 2, "not asked again before " .. RankWindow.ASK_EVERY_S .. " s" .. v)
		clock += 10
		r:tick()
		check(s.asked == 3, "then asked again" .. v)
		r:tick()
		check(s.asked == 3, "once" .. v)
		check(#r._rows == 100 and not r._empty.visible, "the rows stay while the new ones come" .. v)
		r:close()
		clock += 500
		r:tick()
		check(s.asked == 3, "closed, it asks nothing" .. v)
	end
	-- -----------------------------------------------------------------------------------------
	-- no answer, no server, a failed store, empty lists
	-- -----------------------------------------------------------------------------------------
	do
		clock += 1000
		local r, s = make(view, nil)
		r:open()
		H.step(5)
		clock += RankWindow.WAIT_S - 1
		r:tick()
		check(string.find(shown(r._host), "Carregando", 1, true) ~= nil, "still waiting before " .. RankWindow.WAIT_S .. " s" .. v)
		clock += 2
		r:tick()
		H.step(2)
		check(string.find(shown(r._host), "Nãofoipossívelcarregaroranking", 1, true) ~= nil, "no answer: it says the ranking could not be loaded" .. v .. ": " .. shown(r._host))
		-- it tries again by itself, and the late answer is shown
		clock += RankWindow.ASK_EVERY_S + 1
		r:tick()
		H.step(2)
		check(s.asked == 2 and string.find(shown(r._host), "Carregando", 1, true) ~= nil, "it asks again later, and says it is loading" .. v)
		s.rank = lists(2, 0, { 0 }, { 0 })
		s.rank_changed:Fire()
		H.step(2)
		check(#r._rows == 2 and not r._empty.visible, "an answer that comes late is shown" .. v)
		press(r._tabs[2])
		check(#r._rows == 0 and string.find(shown(r._host), "Ninguémdestruiuumreino", 1, true) ~= nil, "an empty list invites the first" .. v .. ": " .. shown(r._host))
	end
	do
		clock += 1000
		local r, s = make(view, nil, false)
		r:open()
		H.step(5)
		check(s.asked == 1 and string.find(shown(r._host), "Nãofoipossívelcarregar", 1, true) ~= nil, "no server to ask: it says so at once" .. v)
	end
	do
		clock += 1000
		local bad = lists(0, 0, { 12 }, { 30 })
		bad.ok = false
		local r, s = make(view, bad)
		r:open()
		H.step(5)
		check(s.asked == 1, "lists the server could not read are asked for again" .. v)
		check(string.find(shown(r._host), "Nãofoipossívelcarregar", 1, true) ~= nil, "the server's stores failing: it says so" .. v)
		check(r._mine_value.text == "12", "the player's own number still shows" .. v)
	end
	-- -----------------------------------------------------------------------------------------
	-- outside the hundred; inside a short list
	-- -----------------------------------------------------------------------------------------
	do
		clock += 1000
		local r = make(view, lists(100, 100, { 40 }, { 0 }))
		r:open()
		H.step(5)
		check(r._mine_place.text == "100+" and r._mine_value.text == "40", "wins but not among the hundred: 100+" .. v)
		if not view[4] then
			check(string.find(shown(r._mine), "Foradotop100", 1, true) ~= nil, "and it says outside the top 100" .. v)
		end
		local mx, my, mw, mh = H.rect(r._mine.gui)
		local lx, ly, lw, lh = H.rect(r._mine_place.gui)
		check(lx >= mx - 0.5 and lx + lw <= mx + mw + 0.5, "100+ inside the player's row" .. v)
		local tx = H.rect(r._mine_title.gui)
		check(lx + lw <= tx + 0.5, string.format("and not over the word beside it (%.0f / %.0f)", lx + lw, tx) .. v)
		press(r._tabs[2])
		check(r._mine_place.text == "—", "nothing on the other board: a dash, not 100+" .. v)
		local own = 0
		for _, row in r._rows do
			if row.own then
				own += 1
			end
		end
		check(own == 0, "no row is marked when the player is not in the list" .. v)
	end
	do
		clock += 1000
		local data = lists(3, 0, { 890, 2 }, { 0 })
		data.boards.wins[2] = { ME, "Eu", 890 }
		local r = make(view, data)
		r:open("wins")
		H.step(5)
		check(r._mine_place.text == "2" and r._rows[2].own, "second of three: place 2, row marked" .. v)
		r:close()
		r:open("kills")
		H.step(5)
		check(r._tab == 2, "it can open on the second tab" .. v)
		r:close()
		r:open()
		check(r._tab == 2, "and opens next on the tab last seen" .. v)
	end
end

-- ---------------------------------------------------------------------------------------------
-- Session: the request, and the answer made safe
-- ---------------------------------------------------------------------------------------------
do
	local OP = Protocol.OP
	local sent = {}
	local net = {
		connected = true,
		send = function(op, ...)
			table.insert(sent, table.pack(op, ...))
		end,
		listen = function() end,
	}
	local s = Session.new({
		now = function()
			return 0
		end,
		net = net,
	})
	check(s.rank == nil, "a new session has no lists")
	check(s:rank_get() == true and #sent >= 1 and sent[#sent][1] == OP.RANK_GET and sent[#sent].n == 1, "rank_get sends OP.RANK_GET, alone")
	net.connected = false
	local n = #sent
	check(s:rank_get() == false and #sent == n, "without a server: false, nothing sent")
	net.connected = true
	local fired = 0
	s.rank_changed:Connect(function()
		fired += 1
	end)
	local rows = {}
	for i = 1, 130 do
		rows[i] = { i, "N" .. i, 500 - i }
	end
	rows[3] = "junk"
	rows[4] = { "x", "name", 5 }
	rows[5] = { 5, 12345, 400.9 }
	rows[6] = { 6, string.rep("a", 90), -4 }
	rows[7] = { 7, "nan", 0 / 0 }
	s:_on_net(OP.RANK, {
		ok = true,
		age = 33,
		boards = { wins = rows, kills = "none" },
		me = { wins = { 77.9, 2 }, kills = { "x", 500 } },
	})
	check(fired == 1 and type(s.rank) == "table", "OP.RANK: the lists are kept, the signal fires")
	local w = s.rank.boards.wins
	check(#w == 100, "no more than a hundred rows: " .. #w)
	check(w[1][1] == 1 and w[2][1] == 2 and w[3][1] == 5, "rows that are not rows are dropped (a text, a user id that is not a number)")
	check(w[3][2] == "" and w[3][3] == 400, "a name that is not text is empty; the number is whole")
	check(#w[4][2] == 40 and w[4][3] == 0, "a long name is cut to 40; a negative number is 0")
	check(w[5][1] == 8, "a row with a number that is not one is dropped")
	check(#s.rank.boards.kills == 0, "a list that is not a list is empty")
	check(s.rank.me.wins[1] == 77 and s.rank.me.wins[2] == 2, "the player's own: whole number, place")
	check(s.rank.me.kills[1] == 0 and s.rank.me.kills[2] == nil, "junk of the player's own: 0, and no place outside the list")
	check(s.rank.ok == true and s.rank.age == 33 and type(s.rank.at) == "number", "ok, age, and when it came")
	for _, junk in { 5, "x", false } do
		s:_on_net(OP.RANK, junk)
	end
	check(fired == 1, "a payload that is not a table changes nothing")
	s:_on_net(OP.RANK, {})
	check(fired == 2 and s.rank.ok == false and #s.rank.boards.wins == 0 and s.rank.me.wins[1] == 0, "an empty table: not ok, empty lists, zeros")
	-- the window draws what the session cleaned, whatever came
	local r = RankWindow.new((function()
		local root = H.root(1280, 720, false)
		local ctx = UICtx.new()
		ctx.vp = root.vp
		ctx.compact = false
		ctx.session = s
		ctx.reserved_top_left = Rect.new(0, 0, 280, 58)
		function ctx:sfx() end
		return ctx
	end)())
	local okb, err = pcall(function()
		r:bind(s)
		r:open()
		s:_on_net(OP.RANK, { ok = true, boards = { wins = rows }, me = {} })
		r:_set_tab(2)
		r:_set_tab(1)
	end)
	check(okb and #r._rows == 100, "the window builds from it: " .. tostring(err))
end

-- ---------------------------------------------------------------------------------------------
-- UIRoot and the title screen
-- ---------------------------------------------------------------------------------------------
do
	local src = fs.readFile("src/client/UI/UIRoot.luau")
	local function has(text: string): boolean
		return string.find(src, text, 1, true) ~= nil
	end
	check(has('local RankWindow = require("./Ranking")'), "UIRoot loads the window")
	check(has("local rank = RankWindow.new(ctx)") and has("self.rank_window = rank") and has("root:add_child(rank)"), "makes it, and adds it to the screen")
	local a = string.find(src, "root:add_child(flag_shop)", 1, true)
	local b = string.find(src, "root:add_child(rank)", 1, true)
	local c = string.find(src, "root:add_child(ask)", 1, true)
	check(a ~= nil and b ~= nil and c ~= nil and a < b and b < c, "above the lobby and its windows, under the questions")
	check(has("general, flag_shop, rank, missions, opening, ask, confirm }"), "it is one of the windows nothing behind takes a press through")
	check(has("title.open_rank:Connect(function()") and has("function UIRoot.open_rank(self)"), "the title's RANK button opens it")
	check(has("self.rank_window:bind(session)"), "it is given the session")
	local wo = string.sub(src, string.find(src, "function UIRoot._window_open", 1, true), string.find(src, "function UIRoot._window_open", 1, true) + 500)
	check(string.find(wo, "self.rank_window,", 1, true) ~= nil, "the tutorial's question waits for it to close")
	check(has("or (self.rank_window ~= nil and self.rank_window.is_open)"), "open, it is a modal for the input gate")
	check(has("and not (self.rank_window ~= nil and self.rank_window.is_open)"), "and nothing opens by itself over it")
	check(has('guard("Ranking.tick", self.rank_window.tick, self.rank_window)'), "it ticks while open")
	check(has('if scr ~= "title" and self.rank_window ~= nil and self.rank_window.is_open then'), "a match that starts closes it")
	local ts = fs.readFile("src/client/UI/TitleScreen.luau")
	check(string.find(ts, 'UITheme.button("RANK", "GlassButton", "leaderboard", 38.0)', 1, true) ~= nil, "the title has the RANK button, with the trophy")
	check(string.find(ts, "self.open_rank:Fire()", 1, true) ~= nil, "which fires open_rank")
end

-- =============================================================================================
-- The two ranks: WORLD and WEEKLY, the weekly prizes, when the week ends, the insignia
-- =============================================================================================
local RankPrizes = require("../src/shared/Data/RankPrizes")
local function with_week(rank: any, n_wins: number, n_kills: number, week: any): any
	local wins, kills = {}, {}
	for i = 1, n_wins do
		wins[i] = { 3000 + i, "Semanal" .. i, 40 - i }
	end
	for i = 1, n_kills do
		kills[i] = { 4000 + i, "Algoz" .. i, 300 - i * 7 }
	end
	rank.boards.wins_w, rank.boards.kills_w = wins, kills
	rank.me.wins_w, rank.me.kills_w = { 0 }, { 0 }
	rank.week = week
	return rank
end
for _, view in { { "pc", 1280, 720, false }, { "celular", 844, 390, true }, { "celular pequeno", 667, 375, true } } do
	local v = " (" .. view[1] .. ")"
	local compact = view[4]
	do
		clock += 1000
		local rank = with_week(lists(100, 3, { 870, 10 }, { 0 }), 12, 2, {
			ends = clock + 3 * 86400 + 4 * 3600 + 30,
			badge = 2,
			last = { wins = 2, kills = 5, stars = 950 },
		})
		rank.boards.wins_w[4] = { ME, "Eu", 36 }
		rank.me.wins_w = { 36, 4 }
		local r, s = make(view, rank)
		r:open()
		H.step(30)
		-- the two ranks are in sight in one place only
		check(r._scope_row.visible == not compact and r._scope_head.visible == compact, "the two ranks: a row of their own, or short chips in the head" .. v)
		local where = if compact then r._scope_head else r._scope_row
		local text = shown(where)
		check(
			text == (if compact then "MUNDIALSEMANALCAMPEÕES" else "RANKMUNDIALRANKSEMANALCAMPEÕES"),
			"they are named RANK MUNDIAL, RANK SEMANAL and CAMPEÕES" .. v .. ": " .. text
		)
		check(r._scope == 1 and #r._rows == 100 and r._rows[1].name.text == "Vencedor1", "it opens on the world rank" .. v)
		check(not r._prizes_m.visible, "the world rank shows no prizes" .. v)
		check(shown(r._tab_row) == "VITÓRIASREINOSDESTRUÍDOS", "the world rank has the two categories" .. v .. ": " .. shown(r._tab_row))
		-- the weekly rank
		local chips = {}
		for _, c in r._scope_chips do
			if c.chip:is_visible_in_tree() then
				chips[c.scope] = c.chip
			end
		end
		check(chips[1] ~= nil and chips[2] ~= nil, "one chip for each rank can be pressed" .. v)
		local asked = s.asked
		press(chips[2])
		check(r._scope == 2 and #r._rows == 12 and r._rows[1].name.text == "Semanal1", "RANK SEMANAL shows the week's list" .. v)
		check(chips[2].button_pressed == true and chips[1].button_pressed == false, "the rank pressed is the lit one" .. v)
		check(shown(r._tab_row) == "VITÓRIASREINOSDESTRUÍDOS", "the weekly rank has the same two categories" .. v)
		check(r._rows[4].own and r._mine_place.text == "4" and r._mine_value.text == "36", "the player's own weekly row: 4th with 36" .. v)
		check(s.asked == asked, "changing rank asks the server nothing" .. v)
		-- the prizes
		check(r._prizes_m.visible, "the weekly rank shows what the week pays" .. v)
		local prizes = shown(r._prizes)
		for place = 1, 3 do
			local amount = (string.gsub(UICtx.commas(RankPrizes.coroas(place)), "%s", ""))
			check(string.find(prizes, amount, 1, true) ~= nil, "place " .. place .. "'s Coroas are shown" .. v .. ": " .. prizes)
			local cell = r._prize_cells[place]
			check(cell.image.Image == RankPrizes.badge_image(place) and cell.badge:is_visible_in_tree(), "with its insignia" .. v)
		end
		check(string.find(prizes, "4º–10º", 1, true) ~= nil, "and the places 4 to 10" .. v .. ": " .. prizes)
		local rest = string.format("%s–%s", UICtx.commas(RankPrizes.coroas(4)), UICtx.commas(RankPrizes.coroas(10)))
		check(string.find(prizes, rest, 1, true) ~= nil, "with the most and the least they pay" .. v .. ": " .. prizes)
		check(string.find(prizes, "Terminaem3d4h", 1, true) ~= nil, "and when the week ends" .. v .. ": " .. prizes)
		if not compact then
			check(string.find(prizes, "PRÊMIOSDASEMANA", 1, true) ~= nil, "under the title PRÊMIOS DA SEMANA" .. v)
			check(
				string.find(prizes, "Últimoprêmio:2ºemVitóriase5ºemReinosdestruídos·+950Coroas", 1, true) ~= nil,
				"and the last prize the player claimed" .. v .. ": " .. prizes
			)
			check(string.find(shown(r._panel), "insígnia", 1, true) ~= nil, "the note explains the insignia" .. v)
			check(string.find(shown(r._panel), "resgataasCoroasaqui", 1, true) ~= nil, "and that the Coroas are claimed here" .. v)
			check(string.find(shown(r._panel), "quandovocêentranojogo", 1, true) == nil, "nothing says any more that they arrive by themselves" .. v)
		end
		-- the clock moves: the time left follows
		clock += 4 * 3600
		r:tick()
		H.step(2)
		check(string.find(shown(r._prizes), "Terminaem3d0h", 1, true) ~= nil, "four hours later: 3d 0h" .. v .. ": " .. shown(r._prizes))
		-- the insignia the player wears
		check(r._mine_badge:is_visible_in_tree() and r._mine_badge_img.Image == RankPrizes.badge_image(2), "the player's own row shows the insignia they wear" .. v)
		-- the other category of the week
		press(r._tabs[2])
		check(#r._rows == 2 and r._rows[1].name.text == "Algoz1" and r._mine_place.text == "—", "the week's kingdoms list" .. v)
		press(r._tabs[1])
		-- everything fits
		local px, py, pw, ph = H.rect(r._panel.gui)
		check(px >= 0 and py >= 0 and px + pw <= view[2] + 0.5 and py + ph <= view[3] + 0.5, string.format("the window fits the screen%s: %d,%d %dx%d", v, px, py, pw, ph))
		local _, hy, _, hh = H.rect(r._host.gui)
		check(hh >= RankWindow.LIST_MIN_H * UITheme.scale - 0.5, string.format("the list keeps room for rows%s: %d px", v, hh))
		local zx, zy, zw, zh = H.rect(r._prizes.gui)
		check(zx >= px and zx + zw <= px + pw + 0.5 and zy + zh <= py + ph + 0.5 and zy >= hy + hh - 0.5, "the prizes are inside the window, under the list" .. v)
		for place = 1, 3 do
			local ax, _, aw = H.rect(r._prize_cells[place].amount.gui)
			check(ax >= zx and ax + aw <= zx + zw + 0.5, "prize " .. place .. " is inside the strip" .. v)
		end
		local ex, _, ew = H.rect((if compact then r._prize_ends_c else r._prize_ends).gui)
		check(ex >= zx and ex + ew <= zx + zw + 0.5, "the time left is inside the strip" .. v)
		local cx, _, cw = H.rect(r._close_b.gui)
		check(cx + cw <= px + pw + 0.5, "the close button is inside the window" .. v)
		if compact then
			local sx, _, sw = H.rect(r._scope_head.gui)
			local tx, _, tw = H.rect(r._title.gui)
			check(sx >= tx + tw - 0.5 and sx + sw <= cx + 0.5, "the head's chips sit between the title and the close button" .. v)
		end
		H.save(r.gui, "assets/telas/rank-semanal-" .. (if view[1] == "pc" then "pc" elseif view[1] == "celular" then "celular" else "celular-pequeno") .. ".json")
		-- back to the world rank: the prizes go
		press(chips[1])
		check(r._scope == 1 and not r._prizes_m.visible and #r._rows == 100, "back to RANK MUNDIAL" .. v)
		press(r._close_b)
		H.step(30)
		-- it opens again where it was left, or where it is told
		clock += 5
		r:open(nil, "week")
		H.step(5)
		check(r._scope == 2 and r._prizes_m.visible, "open(nil, \"week\") opens on the weekly rank" .. v)
		press(r._close_b)
		H.step(30)
	end
	do
		-- an empty week, no insignia, nothing won last week
		clock += 1000
		local rank = with_week(lists(5, 3), 0, 0, { ends = clock + 20 * 60 })
		local r = make(view, rank)
		r:open(nil, "week")
		H.step(30)
		check(#r._rows == 0 and string.find(shown(r._host), "nestasemanaainda", 1, true) ~= nil, "an empty week says so" .. v .. ": " .. shown(r._host))
		check(not r._mine_badge:is_visible_in_tree(), "no insignia, none shown" .. v)
		check(not r._prize_last:is_visible_in_tree(), "nothing won last week, nothing said" .. v)
		check(string.find(shown(r._prizes), "Terminaem20min", 1, true) ~= nil, "twenty minutes left" .. v .. ": " .. shown(r._prizes))
		press(r._tabs[2])
		check(string.find(shown(r._host), "destruiuumreinonestasemana", 1, true) ~= nil, "the other category's empty text" .. v)
	end
	do
		-- a server that sent no weekly part (an older server during an update)
		clock += 1000
		local r = make(view, lists(5, 3))
		r:open(nil, "week")
		H.step(30)
		check(#r._rows == 0, "no weekly lists from the server: an empty list" .. v)
		check(not r._prizes_m.visible, "and no prize is promised that nobody would pay" .. v)
		local px, py, pw, ph = H.rect(r._panel.gui)
		check(px >= 0 and py >= 0 and px + pw <= view[2] + 0.5 and py + ph <= view[3] + 0.5, "the window still fits" .. v)
	end
end


-- =============================================================================================
-- The prize to claim, the champions' board and the insignia beside the names (2026-11-12)
-- =============================================================================================
local Insignia = require("../src/client/UI/Insignia")
do
	-- the card's words
	check(Lang.t(Insignia.text(1, nil)) == "1º em Vitórias na semana passada", "the card: 1st in victories: " .. tostring(Lang.t(Insignia.text(1, nil))))
	check(Lang.t(Insignia.text(nil, 3)) == "3º em Reinos destruídos na semana passada", "the card: 3rd in kingdoms")
	check(
		Lang.t(Insignia.text(2, 1)) == "2º em Vitórias e 1º em Reinos destruídos na semana passada",
		"the card: both lists: " .. tostring(Lang.t(Insignia.text(2, 1)))
	)
	check(Lang.t(Insignia.text(nil, nil)) == "Top 3 do Rank Semanal da semana passada", "the card: a place the server did not say")
	check(Lang.t(Insignia.text(7, nil)) == "Top 3 do Rank Semanal da semana passada", "a place past the third is no insignia's place")
	local spec = Insignia.spec(1, 1, nil)
	check(Lang.t(spec.title) == "Insígnia do Rank Semanal" and Lang.t(spec.footer) == "Vale até domingo", "the card's title and until when it is worn")
	check(Insignia.color(1) ~= nil and Insignia.color(3) ~= nil and Insignia.color(4) == nil, "gold, silver and bronze only")
	-- who wears it, from last week's lists
	local boards = { wins_l = { { 11, "A", 9 }, { 12, "B", 8 }, { 13, "C", 7 }, { 14, "D", 6 } }, kills_l = { { 13, "C", 90 }, { 15, "E", 80 } } }
	local function of(uid: number): string
		local p, w, k = Insignia.of_lists(boards, uid)
		return tostring(p) .. "/" .. tostring(w) .. "/" .. tostring(k)
	end
	check(of(11) == "1/1/nil", "first in victories: gold: " .. of(11))
	check(of(13) == "1/3/1", "third in victories and first in kingdoms: the better of the two, gold: " .. of(13))
	check(of(15) == "2/nil/2", "second in kingdoms: silver: " .. of(15))
	check(of(14) == "nil/nil/nil", "the fourth wears none: " .. of(14))
	check(of(0) == "nil/nil/nil" and select(1, Insignia.of_lists(nil, 11)) == nil, "no user, no lists: none")
end
for _, view in { { "pc", 1280, 720, false }, { "celular", 844, 390, true }, { "celular pequeno", 667, 375, true } } do
	local v = " (" .. view[1] .. ")"
	local compact = view[4]
	local file = if view[1] == "pc" then "pc" elseif view[1] == "celular" then "celular" else "celular-pequeno"
	clock += 1000
	local rank = with_week(lists(100, 3, { 870, 10 }, { 0 }), 12, 2, {
		ends = clock + 6 * 86400,
		badge = 1,
		badge_on = { wins = 1, kills = 3 },
	})
	-- last week's final lists: the player won the victories and was third in kingdoms
	rank.boards.wins_l = { { ME, "Eu", 31 }, { 3001, "Semanal1", 28 }, { 1002, "Vencedor2", 25 }, { 9004, "Quarto", 20 } }
	rank.boards.kills_l = { { 4001, "Algoz1", 410 }, { 9002, "Vice", 388 }, { ME, "Eu", 350 } }
	rank.boards.wins_w[4] = { ME, "Eu", 36 }
	rank.me.wins_w = { 36, 4 }
	local r, s = make(view, rank)

	-- nobody without a prize sees the button
	r:open()
	H.step(30)
	check(not r._claim_m:is_visible_in_tree(), "no prize to claim: no CLAIM button" .. v)
	check(string.find(shown(r._panel), "RESGATAR", 1, true) == nil, "the word is nowhere in the window" .. v)
	local _, _, _, list_h0 = H.rect(r._host.gui)

	-- the prize arrives with the inventory: the panel shows, in every rank
	s.inventory.rank_claim = { total = 1500, weeks = { { wins = 1, kills = 3, stars = 1500 } } }
	s.inventory_changed:Fire(s.inventory)
	H.step(3)
	check(r._claim_m:is_visible_in_tree(), "a prize to claim: the CLAIM panel shows" .. v)
	local ctext = shown(r._claim)
	check(string.find(ctext, "RankSemanal:vocêganhou1.500Coroas!", 1, true) ~= nil, "it says how many Coroas" .. v .. ": " .. ctext)
	check(string.find(ctext, "RESGATAR", 1, true) ~= nil, "with the RESGATAR button" .. v .. ": " .. ctext)
	if not compact then
		check(string.find(ctext, "1ºemVitóriase3ºemReinosdestruídosnasemanapassada", 1, true) ~= nil, "and for which places" .. v .. ": " .. ctext)
	end
	do
		local px, py, pw, ph = H.rect(r._panel.gui)
		check(px >= 0 and py >= 0 and px + pw <= view[2] + 0.5 and py + ph <= view[3] + 0.5, string.format("with it the window still fits%s: %d,%d %dx%d", v, px, py, pw, ph))
		local zx, zy, zw, zh = H.rect(r._claim.gui)
		check(zx >= px and zx + zw <= px + pw + 0.5 and zy >= py and zy + zh <= py + ph + 0.5, "the panel is inside the window" .. v)
		local bx, by, bw, bh = H.rect(r._claim_b.gui)
		check(bx >= zx and bx + bw <= zx + zw + 0.5 and by >= zy - 0.5 and by + bh <= zy + zh + 0.5, "and the button inside the panel" .. v)
		check(bh >= 26 * UITheme.scale, string.format("the button is tall enough for a finger%s: %d px", v, bh))
		local _, hy, _, hh = H.rect(r._host.gui)
		check(hh >= RankWindow.LIST_MIN_H * UITheme.scale - 0.5, string.format("the list keeps room for rows%s: %d px", v, hh))
		check(zy + zh <= hy + 0.5, "the panel is above the list" .. v)
		local tx, _, tw = H.rect(r._claim_title.gui)
		check(tx + tw <= bx + 0.5, "the text stops before the button" .. v)
		-- (nothing is cut: the title has the room its words need at its size)
		local need = r._claim_title.gui.TextBounds.X
		check(need <= tw + 1.5, string.format("the title's words fit its room%s: %d in %d", v, need, tw))
		if not compact then
			local sx, _, sw = H.rect(r._claim_sub.gui)
			check(sx + sw <= bx + 0.5, "the places' line stops before the button too" .. v)
		end
	end
	H.save(r.gui, "assets/telas/rank-resgatar-" .. file .. ".json")
	local chips = {}
	for _, c in r._scope_chips do
		if c.chip:is_visible_in_tree() then
			chips[c.scope] = c.chip
		end
	end
	check(chips[1] ~= nil and chips[2] ~= nil and chips[3] ~= nil, "three chips: world, weekly, champions" .. v)
	press(chips[2])
	check(r._claim_m:is_visible_in_tree(), "the panel stays in the weekly rank" .. v)
	do
		local px, py, pw, ph = H.rect(r._panel.gui)
		check(px >= 0 and py >= 0 and px + pw <= view[2] + 0.5 and py + ph <= view[3] + 0.5, string.format("the weekly rank with the panel fits%s: %d,%d %dx%d", v, px, py, pw, ph))
		local _, _, _, hh = H.rect(r._host.gui)
		check(hh >= RankWindow.LIST_MIN_H * UITheme.scale - 0.5, string.format("and its list keeps room for rows%s: %d px", v, hh))
	end

	-- the insignia beside the names: in the weekly list
	check(r._rows[4].own and r._rows[4].ins ~= nil and r._rows[4].ins.place == 1, "the player's row in the week's list wears their gold" .. v)
	check(r._rows[1].ins ~= nil and r._rows[1].ins.place == 2, "Semanal1, second last week, wears silver in this week's list" .. v)
	check(r._rows[2].ins == nil and r._rows[5].ins == nil, "who was not in last week's top 3 wears none" .. v)
	check(r._rows[1].ins.img.Image == RankPrizes.badge_image(2) and r._rows[1].ins.node:is_visible_in_tree(), "the silver picture is drawn" .. v)
	do
		local ix, iy, iw, ih = H.rect(r._rows[1].ins.node.gui)
		local nx = H.rect(r._rows[1].name.gui)
		local rx, ry, rw, rh = H.rect(r._rows[1].node.gui)
		check(iw >= 14 * UITheme.scale and ih >= 14 * UITheme.scale, string.format("it is big enough to tell the colours apart%s: %dx%d", v, iw, ih))
		check(ix + iw <= nx + 0.5 and ix >= rx and iy >= ry - 0.5 and iy + ih <= ry + rh + 0.5, "it stands right before the name, inside the row" .. v)
	end
	check(r._mine_badge:is_visible_in_tree() and r._mine_ins.place == 1 and r._mine_ins.wins == 1 and r._mine_ins.kills == 3, "the player's own row wears it too, and knows where it was won" .. v)
	-- the pointer on it: the card says why (a phone: a tap)
	table.clear(s.hints)
	local ins = r._rows[1].ins
	H.fire(ins.node.gui, "MouseEnter")
	if compact then
		check(#s.hints == 0, "a phone has no pointer: resting shows nothing" .. v)
		H.fire(ins.node.gui, "InputBegan", {
			UserInputType = Enum.UserInputType.Touch,
			UserInputState = Enum.UserInputState.Begin,
			Position = Vector3.new(10, 10, 0),
		})
		check(#s.hints == 1 and s.hints[1].force == true, "a tap shows the card" .. v .. ": " .. #s.hints)
	else
		check(#s.hints == 1 and s.hints[1].force == false, "the pointer on the insignia shows a card" .. v .. ": " .. #s.hints)
	end
	local hint = s.hints[1]
	if hint ~= nil then
		check(hint.anchor == ins.node, "anchored to the insignia" .. v)
		check(Lang.t(hint.spec.body) == "2º em Vitórias na semana passada", "it says \"2º em Vitórias na semana passada\"" .. v .. ": " .. tostring(Lang.t(hint.spec.body)))
	end
	H.fire(ins.node.gui, "MouseLeave")
	check(s.hints[#s.hints].hide == true and s.hints[#s.hints].anchor == ins.node, "the pointer leaves: the card goes" .. v)
	-- ... and in the world list
	press(chips[1])
	check(r._rows[2].ins ~= nil and r._rows[2].ins.place == 3 and r._rows[1].ins == nil, "Vencedor2, third last week, wears bronze in the world list" .. v)

	-- the champions' board
	local asked = s.asked
	press(chips[3])
	check(r._scope == 3 and chips[3].button_pressed == true, "CAMPEÕES opens the champions' board" .. v)
	check(s.asked == asked, "it asks the server nothing: the lists came with the others" .. v)
	check(#r._rows == 6, "the top 3 of each list, and nobody else" .. v .. ": " .. #r._rows)
	local names = {}
	for i, row in r._rows do
		names[i] = row.name.text .. ":" .. row.place .. ":" .. tostring(row.board) .. ":" .. tostring(row.ins ~= nil and row.ins.place)
	end
	local got = table.concat(names, " ")
	check(
		got == "Eu:1:wins:1 Semanal1:2:wins:2 Vencedor2:3:wins:3 Algoz1:1:kills:1 Vice:2:kills:2 Eu:3:kills:1",
		"victories first, then kingdoms, each with the insignia they wear" .. v .. ": " .. got
	)
	local board = shown(r._host)
	check(string.find(board, "VITÓRIAS", 1, true) ~= nil and string.find(board, "REINOSDESTRUÍDOS", 1, true) ~= nil, "each list under its name" .. v .. ": " .. board)
	check(string.find(board, "Quarto", 1, true) == nil, "the fourth is not a champion" .. v)
	check(not r._tab_row:is_visible_in_tree() and not r._mine_m:is_visible_in_tree() and not r._prizes_m:is_visible_in_tree(), "no tabs, no row of the player's, no prizes: the board alone" .. v)
	check(r._claim_m:is_visible_in_tree(), "the CLAIM panel is there too" .. v)
	if not compact then
		check(string.find(shown(r._panel), "trocadedonotodasegunda-feira", 1, true) ~= nil, "the note says the insignia changes hands on Monday" .. v)
	end
	do
		local px, py, pw, ph = H.rect(r._panel.gui)
		check(px >= 0 and py >= 0 and px + pw <= view[2] + 0.5 and py + ph <= view[3] + 0.5, string.format("the board fits the screen%s: %d,%d %dx%d", v, px, py, pw, ph))
		local hx, hy, hw, hh = H.rect(r._host.gui)
		for i, row in r._rows do
			local rx, _, rw = H.rect(row.node.gui)
			check(rx >= hx - 0.5 and rx + rw <= hx + hw + 0.5, "champion " .. i .. " is inside the list" .. v)
		end
	end
	H.save(r.gui, "assets/telas/rank-campeoes-" .. file .. ".json")

	-- RESGATAR: one request, the button waits, the answer and the inventory take the panel away
	press(r._claim_b)
	check(s.claims == 1, "RESGATAR asks the server once" .. v)
	check(r._claim_b.disabled == true and string.find(shown(r._claim), "RESGATANDO", 1, true) ~= nil, "while it waits the button says so and is off" .. v .. ": " .. shown(r._claim))
	press(r._claim_b)
	check(s.claims == 1, "a second press while waiting asks nothing" .. v)
	s.inventory.rank_claim = nil
	s.inventory.stars = 1500
	s.rank_claimed:Fire(true, 1500)
	s.inventory_changed:Fire(s.inventory)
	H.step(3)
	check(not r._claim_m:is_visible_in_tree(), "claimed: the panel is gone" .. v)
	check(string.find(shown(r._panel), "RESGATAR", 1, true) == nil, "and so is the button" .. v)
	check(#r._rows == 6 and r._rows[1].ins ~= nil, "the insignias stay: they never needed the claim" .. v)
	do
		local px, py, pw, ph = H.rect(r._panel.gui)
		check(px >= 0 and py >= 0 and px + pw <= view[2] + 0.5 and py + ph <= view[3] + 0.5, "the window is laid out again without it" .. v)
	end
	press(chips[1])
	local _, _, _, list_h1 = H.rect(r._host.gui)
	check(math.abs(list_h1 - list_h0) < 1, string.format("the list has its room back%s: %d -> %d", v, list_h0, list_h1))

	-- no answer: the button comes back; the store failed: the same
	s.inventory.rank_claim = { total = 300, weeks = { { wins = 4, stars = 300 }, { kills = 9, stars = 100 } } }
	s.inventory.rank_claim.total = 400
	s.inventory_changed:Fire(s.inventory)
	H.step(3)
	check(string.find(shown(r._claim), "vocêganhou400Coroas!", 1, true) ~= nil, "two weeks to claim: their sum" .. v .. ": " .. shown(r._claim))
	if not compact then
		check(string.find(shown(r._claim), "Prêmiosde2semanas", 1, true) ~= nil, "and that they are two weeks' prizes" .. v .. ": " .. shown(r._claim))
	end
	press(r._claim_b)
	check(s.claims == 2 and r._claim_b.disabled == true, "pressed again for the new prize" .. v)
	clock += RankWindow.CLAIM_WAIT_S + 1
	r:tick()
	H.step(2)
	check(r._claim_b.disabled == false and string.find(shown(r._claim), "RESGATAR", 1, true) ~= nil, "no answer: the button can be pressed again" .. v)
	press(r._claim_b)
	s.rank_claimed:Fire(false, 0)
	H.step(2)
	check(s.claims == 3 and r._claim_b.disabled == false and r._claim_m:is_visible_in_tree(), "the server could not pay: the panel stays, the button is back" .. v)
	press(r._close_b)
	H.step(30)
end
do
	-- no server to ask
	local view = { "pc", 1280, 720, false }
	clock += 1000
	local rank = with_week(lists(5, 3), 3, 0, { ends = clock + 86400 })
	local r, s = make(view, rank, false)
	s.inventory.rank_claim = { total = 80, weeks = { { wins = 10, stars = 80 } } }
	r:open()
	H.step(30)
	check(r._claim_m:is_visible_in_tree() and string.find(shown(r._claim), "10ºemVitóriasnasemanapassada", 1, true) ~= nil, "a tenth place has its prize to claim: " .. shown(r._claim))
	press(r._claim_b)
	check(s.claims == 1 and r._claim_b.disabled == false, "no server: the button stays on")
	check(string.find(shown(r._claim), "Nãofoipossívelresgataragora", 1, true) ~= nil, "and the panel says it could not claim: " .. shown(r._claim))
	-- an empty champions' board
	for _, c in r._scope_chips do
		if c.scope == 3 and c.chip:is_visible_in_tree() then
			press(c.chip)
		end
	end
	check(r._scope == 3 and #r._rows == 0, "no lists of last week: no champions")
	check(string.find(shown(r._host), "Aindanãohácampeões", 1, true) ~= nil, "and the board says when they appear: " .. shown(r._host))
end

for _, p in H.problems() do
	check(false, "a property Roblox does not have: " .. p)
end
print(string.format("ranking_tela: %d checks, %d failed", checks, failed))
if failed > 0 then
	error("ranking_tela: failed")
end
