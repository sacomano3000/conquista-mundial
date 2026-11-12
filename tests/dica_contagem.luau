--!nocheck
-- The card of a command-bar slot (client/UI/BuildButton + Tooltip) while the pointer rests on it:
--   * a countdown in it ("Ready in 0:12") goes down while the card is up (it stood still until the
--     pointer left the slot and came back: the slot kept the new reason to itself);
--   * the card follows the slot when it becomes available, and when its price changes;
--   * a slot whose card is not the one on screen opens nothing and changes nobody else's card;
--   * a card that was closed stays closed;
--   * the card is not built again when nothing in it changed.
--   lune run tests/dica_contagem.luau
local H = require("./ui_harness")
local UICtx = require("../src/client/UI/UICtx")
local UITheme = require("../src/client/UI/UITheme")
local W = require("../src/client/UI/Widgets")
local BuildButton = require("../src/client/UI/BuildButton")
local Tooltip = require("../src/client/UI/Tooltip")
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
local function has(node: any, text: string): boolean
	return string.find(shown(node), (string.gsub(text, "%s", "")), 1, true) ~= nil
end

for _, view in { { "pc", 1280, 720, false }, { "celular", 844, 390, true } } do
	local v = " (" .. view[1] .. ")"
	local root = H.root(view[2], view[3], view[4])
	local ctx = UICtx.new()
	ctx.vp = root.vp
	ctx.compact = view[4]
	ctx.touch = view[4]
	ctx.touch_device = view[4]
	function ctx:sfx() end
	-- what the rules say of each slot (UIRules.availability / owned), set by the test
	local av = {
		reinforce = { ok = false, locked = false, reason = "Ready in 0:12", cost = 5000 },
		airfield = { ok = false, locked = false, reason = "Airfield rearming · ready in 0:30", cost = 90000 },
	}
	ctx.rules = {
		availability = function(_self: any, kind: string)
			return table.clone(av[kind])
		end,
		owned = function()
			return 0
		end,
	}
	local tip = Tooltip.new(ctx)
	ctx.tooltip = tip
	local a = BuildButton.new(ctx, "reinforce", "R")
	local b = BuildButton.new(ctx, "airfield", "T")
	root:add_child(a)
	root:add_child(b)
	root:add_child(tip)
	H.step(4)
	a:refresh()
	b:refresh()
	check(not tip:is_shown(), "a slot that refreshes opens no card of its own" .. v)

	-- the pointer rests on the slot: its card (a phone: the long press, which forces it)
	ctx:show_hint(a, a:hint_spec(), true)
	H.step(4)
	check(tip:is_shown() and tip:anchor_is(a), "the slot's card is up" .. v)
	check(has(tip, "Pronto em 0:12"), "it says the wait: " .. shown(tip) .. v)

	-- time passes: the wait goes down, the pointer still there
	local builds = 0
	local build = Tooltip._build
	Tooltip._build = function(...)
		builds += 1
		return build(...)
	end
	av.reinforce.reason = "Ready in 0:11"
	a:refresh()
	H.step(2)
	check(has(tip, "Pronto em 0:11") and not has(tip, "0:12"), "the card counts down with the slot: " .. shown(tip) .. v)
	check(tip:is_shown() and tip:anchor_is(a), "and stays up, on the same slot" .. v)
	check(builds == 1, "(built once for the new text: " .. builds .. ")" .. v)
	for left = 10, 1, -1 do
		av.reinforce.reason = string.format("Ready in 0:%02d", left)
		a:refresh()
		H.step(1)
		check(has(tip, string.format("Pronto em 0:%02d", left)), "0:" .. left .. " on the card" .. v)
	end
	-- nothing changed: nothing is built again
	builds = 0
	a:refresh()
	a:refresh()
	H.step(2)
	check(builds == 0, "a refresh that changes nothing does not build the card again: " .. builds .. v)
	-- another slot's wait changes: this card keeps its own text
	av.airfield.reason = "Airfield rearming · ready in 0:29"
	b:refresh()
	H.step(2)
	check(builds == 0 and tip:anchor_is(a) and has(tip, "Pronto em 0:01"), "another slot's countdown leaves this card alone" .. v)
	-- the wait is over: the card says what a press does now
	av.reinforce = { ok = true, locked = false, reason = "", cost = 5000 }
	a:refresh()
	H.step(2)
	check(not has(tip, "Pronto em"), "ready: the wait leaves the card: " .. shown(tip) .. v)
	check(has(tip, Lang.t("Click to call them in")), "and it says what a press does" .. v)
	-- the price changed (the slot redraws: the other path through refresh)
	av.reinforce.cost = 7500
	a:refresh()
	H.step(2)
	check(has(tip, UITheme.fmt_cost(7500)), "a new price reaches the card: " .. shown(tip) .. v)

	-- the other slot's card, with its own countdown
	ctx:show_hint(b, b:hint_spec(), true)
	H.step(2)
	check(tip:anchor_is(b) and has(tip, "0:29"), "the other slot's card: " .. shown(tip) .. v)
	av.reinforce.cost = 8000
	a:refresh()
	H.step(2)
	check(tip:anchor_is(b) and has(tip, "0:29") and not has(tip, UITheme.fmt_cost(8000)), "the first slot no longer writes on it" .. v)
	av.airfield.reason = "Airfield rearming · ready in 0:28"
	b:refresh()
	H.step(2)
	check(has(tip, "0:28"), "it counts down too: " .. shown(tip) .. v)

	-- the pointer left: the card closes and a refresh does not bring it back
	ctx:hide_hint(b)
	check(not tip:is_shown(), "the card closes" .. v)
	av.airfield.reason = "Airfield rearming · ready in 0:27"
	b:refresh()
	H.step(2)
	check(not tip:is_shown(), "a closed card stays closed" .. v)
	-- a card of another kind (the map's, which follows the pointer) is not a slot's to rewrite
	tip:show_follow({ title = "Outro" })
	H.step(2)
	av.airfield.reason = "Airfield rearming · ready in 0:26"
	b:refresh()
	H.step(2)
	check(has(tip, "Outro") and not has(tip, "0:26"), "the map's card is not rewritten by a slot" .. v)
	-- without a card at all (the tutorial's stand-ins): refresh does not fail
	ctx.tooltip = nil
	check(pcall(b.refresh, b), "no card in the game: refresh still works" .. v)
	ctx.tooltip = { hide_tip = function() end }
	check(pcall(b.refresh, b), "a stand-in card without the questions: refresh still works" .. v)
	Tooltip._build = build
end

local problems = H.problems()
check(#problems == 0, "no property Roblox lacks was set: " .. table.concat(problems, "; "))
print(string.format("dica_contagem: %d checks, %d failed", checks, failed))
if failed > 0 then
	error("dica_contagem failed")
end
