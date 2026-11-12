--!nocheck
-- The end of a match's summary and the rest of what a match shows of the 2026-11-12 batch, outside
-- Roblox:
--   * UI/GameOver: a ranked match's points ("RANQUEADA +34 · Cavaleiro 134 / 300", promoted, dropped,
--     the lines under it) and the day's missions line;
--   * UI/Leaderboard: the ranked tier beside the name, and no pet there any more;
--   * Map/Mascot.pose: the kingdom's mascot rests, and jumps after a conquest;
--   * Core/GameState.set_cosmetics keeps the tier.
--   lune run tests/resumo_partida.luau
local H = require("./ui_harness")
local UICtx = require("../src/client/UI/UICtx")
local UITheme = require("../src/client/UI/UITheme")
local W = require("../src/client/UI/Widgets")
local Insignia = require("../src/client/UI/Insignia")
local RankPrizes = require("../src/shared/Data/RankPrizes")
local Defs = require("../src/shared/Core/Defs")
local Lang = require("../src/shared/Data/Lang")
Lang.use("pt")

-- (where a press is: Widgets asks Roblox's services, which are not here; the event carries it)
W.input_pos = function(io: any): Vector2
	return Vector2.new(io.Position.X, io.Position.Y)
end
W.screen_to_logical = function(v: Vector2): Vector2
	return v / UITheme.scale
end

local checks, failed = 0, 0
local function check(ok: any, what: string)
	checks += 1
	if not ok then
		failed += 1
		print("FAIL: " .. what)
	end
end

-- (the lobby's party asks Roblox who is on the server: a stand-in, with three players)
local game_ = H.fake_game()
local ME = 77
local function fake_player(uid: number, name: string, badge: any, wins: any, kills: any): any
	local attrs = { RankBadge = badge, RankBadgeWins = wins, RankBadgeKills = kills }
	return {
		UserId = uid,
		Name = name,
		DisplayName = name,
		GetAttribute = function(_p, k: string)
			return attrs[k]
		end,
		IsFriendsWith = function()
			return false
		end,
	}
end
local roster = {
	fake_player(ME, "Eu", 1, 1, 3),
	fake_player(501, "Prata", 2, nil, 2),
	fake_player(502, "Ninguem", nil, nil, nil),
	fake_player(503, "Lixo", 9, "x", 0),
}
local PlayersSvc = game_:GetService("Players")
rawset(PlayersSvc, "LocalPlayer", roster[1])
rawset(PlayersSvc, "GetPlayerByUserId", function(_s, uid: number)
	for _, p in roster do
		if p.UserId == uid then
			return p
		end
	end
	return nil
end)
rawset(PlayersSvc, "GetPlayers", function()
	return roster
end)

local Leaderboard = require("../src/client/UI/Leaderboard")
local TargetCard = require("../src/client/UI/TargetCard")
local GameOver = require("../src/client/UI/GameOver")
local SpawnOverlay = require("../src/client/UI/SpawnOverlay")
local PartyPanel = require("../src/client/UI/PartyPanel")

--- A match's state as the screens read it: four owners, three of them people.
local function state(): any
	local s = {
		phase = Defs.PHASE_SPAWN,
		owners = {
			[1] = { id = 1, name = "Eu", color = Color3.fromRGB(200, 60, 60), kind = Defs.KIND_HUMAN, alive = true, spawned = true, troops = 1200, tiles = 40 },
			[2] = { id = 2, name = "Prata", color = Color3.fromRGB(60, 120, 200), kind = Defs.KIND_HUMAN, alive = true, spawned = false, troops = 900, tiles = 30 },
			[3] = { id = 3, name = "Ninguem", color = Color3.fromRGB(60, 200, 90), kind = Defs.KIND_HUMAN, alive = true, spawned = true, troops = 700, tiles = 20 },
			[4] = { id = 4, name = "Reino de Bot", color = Color3.fromRGB(120, 120, 120), kind = Defs.KIND_BOT or 2, alive = true, spawned = true, troops = 300, tiles = 10 },
		},
		cosmetics = {
			[1] = { face = ME, badge = 1, bw = 1, bk = 3 },
			[2] = { face = 501, badge = 2, bk = 2 },
			[3] = { face = 502 },
		},
	}
	function s:get_owner(id)
		return self.owners[id]
	end
	function s:owner_name(id)
		return self.owners[id] and self.owners[id].name or ""
	end
	function s:tile_owner(t)
		return t
	end
	function s:land_share(_id)
		return 0.25
	end
	function s:has_request()
		return false
	end
	return setmetatable(s, {
		-- (anything else a screen asks the state: nothing there)
		__index = function(_t, _k)
			return function()
				return nil
			end
		end,
	})
end

local function context(view: any): (any, any, any)
	local root = H.root(view[2], view[3], view[4])
	local ctx = UICtx.new()
	ctx.vp = root.vp
	ctx.compact = view[4]
	ctx.touch = view[4]
	ctx.touch_device = view[4]
	ctx.state = state()
	local hints = {}
	function ctx:show_hint(anchor: any, spec: any, force: boolean?)
		if force or not self.touch then
			table.insert(hints, { anchor = anchor, spec = spec, force = force == true })
		end
	end
	function ctx:hide_hint(anchor: any)
		table.insert(hints, { anchor = anchor, hide = true })
	end
	function ctx:sfx() end
	function ctx:me()
		return 1
	end
	function ctx:my()
		return self.state.owners[1]
	end
	function ctx:mode()
		return UICtx.MODE_MULTI
	end
	function ctx:world_call() end
	function ctx:relation(_id)
		return "enemy"
	end
	function ctx:relation_color(_r)
		return UITheme.TEXT
	end
	function ctx:kind_title(_k)
		return "Player"
	end
	function ctx:terrain_title(_t)
		return "Plains"
	end
	function ctx:render_tick()
		return 0
	end
	return ctx, root, hints
end

--- The insignia pictures in sight under `node`: their images, in order.
local function badges(node: any): { string }
	local out = {}
	for _, d in node.gui:GetDescendants() do
		if d.Name == "RankBadge" and d.Visible ~= false then
			local seen = true
			local p = d.Parent
			while p ~= nil and p ~= node.gui do
				if p.Visible == false then
					seen = false
					break
				end
				p = p.Parent
			end
			if seen then
				table.insert(out, d.Image)
			end
		end
	end
	return out
end
local GOLD, SILVER = RankPrizes.badge_image(1), RankPrizes.badge_image(2)

local Ranked = require("../src/shared/Data/Ranked")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local MissionsData = require("../src/shared/Data/Missions")
local GameState = require("../src/shared/Core/GameState")

for _, view in { { "pc", 1280, 720, false }, { "celular", 844, 390, true } } do
	local v = " (" .. view[1] .. ")"
	-- the result screen ----------------------------------------------------------------------
	do
		local ctx, root = context(view)
		local now = os.time()
		local mstate = MissionsData.clean(nil)
		local session = {
			last_award = nil,
			inventory = {},
			missions_view = function(_s)
				return MissionsData.view(mstate, now)
			end,
		}
		ctx.session = session
		local over = GameOver.new(ctx)
		root:add_child(over)
		over.is_open = true
		over:apply_layout()
		check(not over._ranked_l.visible and not over._ranked_d.visible and not over._missions_l.visible, "no payout yet: no summary lines" .. v)
		-- a ranked win that promotes
		over:set_award({
			lines = { { "played", 100 } },
			total = 2330,
			balance = 9000,
			mode = "public",
			ranked = { lines = { { "entry", -6 }, { "placed", 40 }, { "victory", 30 }, { "conquests", 15 } }, total = 79, delta = 79, points = 134, tier = 2, before = 1 },
		})
		H.step(3)
		check(over._ranked_l.visible and over._ranked_l.text == "RANQUEADA  +79  ·  Subiu para Cavaleiro!", "a ranked win that promotes says so" .. v .. ": " .. tostring(over._ranked_l.text))
		check(over._ranked_d.visible and over._ranked_d.text == "Entrada −6  ·  Posição +40  ·  Vitória +30  ·  Reinos +15", "... with how the points were made" .. v .. ": " .. tostring(over._ranked_d.text))
		check(UITheme.equal(over._ranked_l.color, UITheme.GREEN), "points won are green" .. v)
		check(over._stars_btn.visible, "the Coroas pill is there too" .. v)
		-- the missions line
		local mv = MissionsData.view(mstate, now)
		check(over._missions_l.visible and string.find(over._missions_l.text, string.format("Missões de hoje 0 / %d", #mv.daily), 1, true) == 1, "the day's missions line shows" .. v .. ": " .. tostring(over._missions_l.text))
		for _, l in { over._ranked_l, over._ranked_d, over._missions_l } do
			local x, _, w = H.rect(l.gui)
			local rx, _, rw = H.rect(root.gui)
			check(x >= rx - 0.5 and x + w <= rx + rw + 0.5, string.format("the line is on the screen%s (%.0f..%.0f of %.0f..%.0f): %s", v, x, x + w, rx, rx + rw, tostring(l.text)))
		end
		-- a ranked loss, same tier
		over:set_award({
			lines = { { "played", 100 } },
			total = 100,
			balance = 9100,
			ranked = { lines = { { "entry", -10 } }, total = -10, delta = -10, points = 124, tier = 2, before = 2 },
		})
		H.step(3)
		check(over._ranked_l.text == "RANQUEADA  −10  ·  Cavaleiro  124 / 300", "a loss shows the points lost and the standing" .. v .. ": " .. tostring(over._ranked_l.text))
		check(UITheme.equal(over._ranked_l.color, UITheme.RED), "points lost are red" .. v)
		-- a drop
		over:set_award({ lines = {}, total = 0, balance = 9100, ranked = { lines = { { "entry", -10 } }, total = -10, delta = -10, points = 95, tier = 1, before = 2 } })
		H.step(3)
		check(over._ranked_l.text == "RANQUEADA  −10  ·  Caiu para Escudeiro", "a drop says so" .. v .. ": " .. tostring(over._ranked_l.text))
		check(over._ranked_l.visible and not over._stars_btn.visible, "a ranked result with no Coroas still shows its points" .. v)
		-- the top tier has no next
		over:set_award({ lines = {}, total = 5, balance = 1, ranked = { lines = {}, total = 0, delta = 0, points = 1240, tier = 5, before = 5 } })
		H.step(3)
		check(over._ranked_l.text == "RANQUEADA  0  ·  Rei  1.240", "the top tier" .. v .. ": " .. tostring(over._ranked_l.text))
		check(not over._ranked_d.visible, "no lines: no second line" .. v)
		-- a classic match: Coroas and missions, no ranked line
		over:set_award({ lines = { { "played", 100 } }, total = 100, balance = 9200, mode = "public" })
		H.step(3)
		check(not over._ranked_l.visible and not over._ranked_d.visible and over._missions_l.visible, "a classic match: missions, no ranked line" .. v)
		over:set_award(nil)
		H.step(3)
		check(not over._ranked_l.visible and not over._missions_l.visible, "the payout gone: the lines go" .. v)
	end

	-- the match's list: the tier beside the name, no pet ---------------------------------------
	do
		local ctx, root = context(view)
		local pet = Cosmetics.of_kind("pet")[1].id
		ctx.state.cosmetics[1] = { face = ME, tier = 3, pet = pet }
		ctx.state.cosmetics[2] = { face = 501, tier = 1 }
		local row = Leaderboard.Row.new(ctx)
		local col = UITheme.vbox(2)
		col:set_min_size(Vector2.new(280, 0))
		root:add_child(col)
		col:add_child(row)
		row:set_row(ctx.state.owners[1], 1)
		H.step(2)
		check(row.tier_l.visible and row.tier_l.text == "BARÃO", "a Barão's row says so" .. v .. ": " .. tostring(row.tier_l.text))
		check(not row.pet.visible, "the pet is not beside the name any more" .. v)
		local nx, _, nw = H.rect(row.name_l.gui)
		local tx = H.rect(row.tier_l.gui)
		check(tx >= nx + nw - 0.5, "the tier is right of the name" .. v)
		row:set_row(ctx.state.owners[2], 2)
		H.step(2)
		check(not row.tier_l.visible, "an Escudeiro's row shows no tier" .. v)
		row:set_row(ctx.state.owners[4], 4)
		H.step(2)
		check(not row.tier_l.visible, "a robot's row shows no tier" .. v)
	end
end

-- the texts apart from the widgets
do
	check(GameOver.signed(34) == "+34" and GameOver.signed(-10) == "−10" and GameOver.signed(0) == "0" and GameOver.signed(1500) == "+1.500", "signed numbers")
	check(GameOver.missions_line(nil) == "" and GameOver.missions_line({ daily = {} }) == "", "no missions: no line")
	local line = GameOver.missions_line({ daily = {
		{ text = "Destrua 3 reinos", have = 1, goal = 3, done = false },
		{ text = "Jogue 2 partidas", have = 2, goal = 2, done = true },
		{ text = "Vença 1 partida", have = 0, goal = 1, done = false },
	} })
	check(line == "Missões de hoje 1 / 3  ·  Destrua 3 reinos 1 / 3", "the missions line names the nearest one: " .. line)
	local all = GameOver.missions_line({ daily = { { text = "x", have = 1, goal = 1, done = true } } })
	check(all == "Missões de hoje 1 / 1  ·  todas concluídas", "all done: " .. all)
	for i, t in Ranked.TIERS do
		check(type(t.color) == "number" and t.color > 0 and t.color <= 0xFFFFFF, "tier " .. i .. " has a colour")
	end
end

-- the cosmetics of a match keep the ranked tier
do
	local kept = {}
	local fake = { cosmetics = {}, cosmetics_changed = { Fire = function() end } }
	local ok = pcall(GameState.set_cosmetics, fake, { [1] = { tier = 3 }, [2] = { tier = 1 }, [3] = { tier = "x", skin = "a" }, [4] = { tier = 2.5 } }, true)
	if ok then
		kept = fake.cosmetics
		check(kept[1] ~= nil and kept[1].tier == 3, "a tier from Cavaleiro up is kept")
		check(kept[2] == nil, "the first tier alone is nothing to show")
		check(kept[3] ~= nil and kept[3].tier == nil and kept[3].skin == "a", "a tier that is no number is dropped")
		check(kept[4] == nil, "a tier that is no whole number is dropped")
	else
		check(false, "set_cosmetics runs on a plain table")
	end
end

-- the kingdom's mascot (Data/Mascot; Map/NameLayer draws it): resting and celebrating
do
	local Mascot = require("../src/shared/Data/Mascot")
	local size = 30
	local top_rest = 0
	for i = 0, 200 do
		local lift, tilt = Mascot.pose(i * 0.05, nil, size, 1.7)
		top_rest = math.max(top_rest, lift)
		check(lift >= 0 and tilt == 0, "resting: never under the ground, never tilted (" .. i .. ")")
	end
	check(top_rest > 0 and top_rest <= size * 0.06, "resting: it only breathes (" .. top_rest .. ")")
	local top, tilted = 0, 0
	for i = 0, 100 do
		local e = i * Mascot.CHEER_S / 100
		local lift, tilt = Mascot.pose(10 + e, 10, size, 1.7)
		top = math.max(top, lift)
		tilted = math.max(tilted, math.abs(tilt))
		check(lift >= 0 and lift <= size * 0.62 and math.abs(tilt) <= 14.01, "celebrating: a jump within reach (" .. i .. ")")
	end
	check(top > size * 0.3 and tilted > 5, string.format("after a conquest it jumps and wags (%.1f px, %.1f degrees)", top, tilted))
	local after, tilt_after = Mascot.pose(10 + Mascot.CHEER_S + 0.01, 10, size, 1.7)
	check(after <= size * 0.06 and tilt_after == 0, "... and then rests again")
	local early = Mascot.pose(10 + 0.17, 10, size, 1.7)
	local late = Mascot.pose(10 + 0.17 + math.pi / 9 * 5, 10, size, 1.7)
	check(late < early, "each jump is lower than the one before")
	check(Mascot.MIN_PX >= 12 and Mascot.MAX_PX <= 64, "the mascot's size on the screen is bounded")
end

for _, p in H.problems() do
	check(false, "a property Roblox does not have: " .. p)
end
print(string.format("resumo_partida: %d checks, %d failed", checks, failed))
if failed > 0 then
	error("resumo_partida: failed")
end
