--!nocheck
-- The game's own sounds and music (2026-11-11): the owner's choices are the ones in the manifests, every
-- sound has its level, the effects have their own volume apart from the music's, and Settings shows it.
--
--   1. the manifests (Assets/Audio, AudioExtra, AudioUI, Soundtrack) against the owner's list
--   2. AudioDirector itself, run here on stand-ins for Roblox's Sound objects: what volume each effect
--      really plays at, the cut starts, the effects' slider, the music's own trims and slider
--   3. the Settings page: built headless (ui_harness) on a PC and a phone, with the new row
local H = require("./ui_harness")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task_lib = require("@lune/task")
local roblox = require("@lune/roblox")
-- (loaded as outside Roblox, before part 3 gives the Settings page a stand-in `game`)
local Lang = require("../src/shared/Data/Lang")
local UICtx = require("../src/client/UI/UICtx")
local UITheme = require("../src/client/UI/UITheme")
local _W = require("../src/client/UI/Widgets")
local _GlassPanel = require("../src/client/UI/GlassPanel")

local checks, failed = 0, 0
local function check(ok: boolean, what: string)
	checks += 1
	if not ok then
		failed += 1
		print("FAIL: " .. what)
	end
end
local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-6)
end

-- ---------------------------------------------------------------------------------------------
-- 1. The manifests
-- ---------------------------------------------------------------------------------------------

--- What the owner chose (their message of 2026-11-11): sound -> the Creator Store audio's number.
local CHOSEN = {
	ui_click = "15675032796",
	ui_hover = "10066936758",
	ui_tab = "10066968815",
	ui_back = "10066914500",
	ui_open = "9118835414",
	ui_confirm = "10128760939",
	ui_error = "17208214688",
	ui_locked = "9119717950",
	order_ack = "10066968815",
	spawn_confirm = "9114026047",
	spectate_switch = "17208405682",
	queue_start = "17208372272",
	buy_spend = "9113849492",
	star_get = "9113849731",
	star_tick = "9113849011",
	unlock = "9116395085",
	crate_drop = "9125805781",
	crate_land = "9113225986",
	crate_rattle = "9113763590",
	crate_open = "9126263691",
	crate_shimmer = "9125635426",
	card_flip = "9114035710",
	card_whoosh = "9120972321",
	crate_preview_common = "9125647212",
	crate_preview_rare = "9125647212",
	crate_preview_epic = "9125644905",
	crate_preview_legendary = "9116418035",
	reveal_common = "9116395089",
	reveal_rare = "9116385087",
	reveal_epic = "9116384485",
	reveal_legendary = "9116384483",
	countdown_tick = "9114071134",
	countdown_tick_5 = "9119974912",
	countdown_tick_4 = "9119974912",
	countdown_tick_3 = "9119974912",
	countdown_tick_2 = "9119974912",
	countdown_tick_1 = "9119974912",
	countdown_gamestart = "9114822651",
	game_start = "1846284931",
	victory = "1836473422",
	defeat = "1835142330",
	eliminate = "9119748927",
	ally_request = "15675043410",
	alliance = "1840120074",
	betrayal = "1845713466",
	under_attack = "9119072660",
	conquer = "1840120155",
	expand = "9120709477",
	expand_pop = "9116312491",
	build = "9113447116",
	attack_launch = "9119742466",
	nuke_launch = "9114428740",
	nuke_alarm = "9113803790",
	nuke_explosion = "9114362135",
	sam_launch = "9116406610",
	sam_intercept = "9119072660",
	shell_fire = "9120972444",
	shell_hit = "9118608146",
	shell_splash = "9125703162",
	boat_launch = "9117137917",
	warship = "9113804171",
	ship_sink = "9120352848",
}
local MUSIC = {
	title = "99301366639600",
	wait = "132186416717371",
	calm = "139466688846504",
	war = "102727895618704",
	victory = "78703943883933",
	defeat = "102473807772239",
}

local Audio = require("../src/shared/Assets/Audio")
local AudioExtra = require("../src/shared/Assets/AudioExtra")
local AudioUI = require("../src/shared/Assets/AudioUI")
local Soundtrack = require("../src/shared/Assets/Soundtrack")
local Brand = require("../src/shared/Data/Brand")
local Playlist = require("../src/client/Audio/Playlist")
local Signal = require("../src/shared/Core/Signal")

local director_src = fs.readFile("src/client/Audio/AudioDirector.luau")
local names = {}
do
	local block = string.match(director_src, "AudioDirector%.SFX_NAMES = (%b{})")
	for n in string.gmatch(block or "", '"([%w_]+)"') do
		table.insert(names, n)
	end
end
check(#names == 62, "the director knows 62 sounds, got " .. #names)

local n_chosen = 0
for _ in CHOSEN do
	n_chosen += 1
end
check(n_chosen == 62, "the owner's list has 62 sounds, got " .. n_chosen)

local function id_of(e: any): string?
	local raw = e.id or e.sprite
	return if type(raw) == "string" then string.match(raw, "^rbxassetid://(%d+)$") else nil
end

local louder, quieter, cut = 0, 0, 0
for _, name in names do
	local found = {}
	for _, m in { Audio, AudioExtra, AudioUI } do
		if m.sfx[name] ~= nil then
			table.insert(found, m.sfx[name])
		end
	end
	check(#found == 1, name .. " is in exactly one manifest, found in " .. #found)
	local e = found[1]
	if e == nil then
		continue
	end
	check(id_of(e) == CHOSEN[name], string.format("%s is the audio the owner chose (%s), got %s", name, tostring(CHOSEN[name]), tostring(id_of(e))))
	check(type(e.length) == "number" and e.length > 0.05 and e.length < 12, name .. " has its length")
	check(type(e.db) == "number" and e.db >= -20 and e.db <= 20, name .. " has its level, between -20 and +20 dB")
	if type(e.db) == "number" then
		if e.db > 0 then
			louder += 1
		elseif e.db < 0 then
			quieter += 1
		end
	end
	if e.sprite ~= nil then
		cut += 1
		check(e.id == nil, name .. ": a cut sound has `sprite`, not `id`")
		check(
			type(e.start) == "number" and type(e.stop) == "number" and e.start >= 0.05 and e.start < 0.6 and e.stop > e.start,
			name .. ": a cut start between 0.05 and 0.6 s, before its stop"
		)
		check(near(e.length, e.stop - e.start, 0.002), name .. ": its length is the part that plays")
	end
end
for _, m in { Audio, AudioExtra, AudioUI } do
	for name in m.sfx do
		check(table.find(names, name) ~= nil, "manifest entry " .. name .. " is a sound the director plays")
	end
end
check(quieter >= 30, "most sounds were turned down: " .. quieter)
check(cut >= 8, "the sounds with silence at the start are cut: " .. cut)
print(string.format("  %d sounds: %d turned down, %d turned up, %d cut at the start", #names, quieter, louder, cut))

-- the five last seconds of the countdown share one sound (the owner's choice 33)
for sec = 1, 4 do
	check(
		id_of(AudioExtra.sfx["countdown_tick_" .. sec]) == id_of(AudioExtra.sfx.countdown_tick_5),
		"countdown_tick_" .. sec .. " is the same sound as countdown_tick_5"
	)
end

-- the soundtrack: one track per mood, the ones chosen
check(Brand.MUSIC == true, "the music is switched on (Data/Brand.MUSIC)")
check(Brand.MUSIC_CREDIT == "", "and asks for no credit line")
local n_tracks = 0
for _ in Soundtrack.tracks do
	n_tracks += 1
end
check(n_tracks == 6, "six tracks, got " .. n_tracks)
for mood, id in MUSIC do
	local list = Soundtrack.moods[mood]
	check(type(list) == "table" and #list == 1, mood .. " has one track")
	local t = list and Soundtrack.tracks[list[1]]
	check(t ~= nil and t.id == "rbxassetid://" .. id, mood .. " is the track the owner chose")
	check(t ~= nil and type(t.length) == "number" and t.length > 120 and t.length < 260, mood .. " has its length")
	check(t ~= nil and type(t.db) == "number" and t.db >= -8 and t.db <= 8, mood .. " has its level")
end
check(Audio.music.menu.id == "rbxassetid://" .. MUSIC.title, "the fallback menu theme is the title track")
check(Audio.music.war.id == "rbxassetid://" .. MUSIC.war, "the fallback war theme is the war track")
-- a mood of one track plays it again and again
do
	local pl = Playlist.new(Soundtrack, function()
		return 0.5
	end)
	for _, mood in { "title", "wait", "calm", "war" } do
		local a, b, c = pl:next(mood), pl:next(mood), pl:next(mood)
		check(a ~= nil and a == b and b == c and a == Soundtrack.moods[mood][1], mood .. ": its one track repeats")
	end
	check(pl:after("victory") == "title" and pl:after("defeat") == "calm", "victory and defeat play once")
end
-- nothing of RoWorld's audio is left
for _, f in { "Audio", "AudioExtra", "AudioUI", "Soundtrack" } do
	local src = fs.readFile("src/shared/Assets/" .. f .. ".luau")
	check(string.find(src, "Rodrigo Flores", 1, true) == nil, f .. " no longer names RoWorld's composer")
	for id in string.gmatch(src, "rbxassetid://(%d+)") do
		local mine = false
		for _, c in CHOSEN do
			mine = mine or c == id
		end
		for _, c in MUSIC do
			mine = mine or c == id
		end
		check(mine, f .. ": audio " .. id .. " is one the owner chose")
	end
end
check(
	string.find(fs.readFile("src/client/UI/HelpOverlay.luau"), "Music by Rodrigo Flores", 1, true) == nil,
	"How to play no longer credits RoWorld's composer"
)

-- ---------------------------------------------------------------------------------------------
-- 2. The director, on stand-in Sounds
-- ---------------------------------------------------------------------------------------------

local made = {} :: { any }
local heartbeat: ((number) -> ())? = nil
local function fake_signal()
	local s = { fns = {} }
	function s:Connect(fn)
		table.insert(s.fns, fn)
		return { Disconnect = function() end, Connected = true }
	end
	return s
end
local function fake_instance(class: string): any
	local o: any = { ClassName = class, Name = class, Volume = 0.5, IsPlaying = false, IsLoaded = true, TimeLength = 0, TimePosition = 0, plays = 0 }
	o.Ended = fake_signal()
	o.Loaded = fake_signal()
	function o:Play()
		o.IsPlaying = true
		o.plays += 1
		o.played_at = o.TimePosition
	end
	function o:Stop()
		o.IsPlaying = false
	end
	function o:Pause()
		o.IsPlaying = false
	end
	function o:Resume()
		o.IsPlaying = true
	end
	function o:Destroy() end
	table.insert(made, o)
	return o
end
local function module(m: any): any
	return { __module = m }
end
local function folder(children: { [string]: any }): any
	local f = table.clone(children)
	function f:FindFirstChild(name: string)
		return children[name]
	end
	function f:WaitForChild(name: string)
		return children[name]
	end
	return f
end
local shared_folder = folder({
	Core = folder({ Signal = module(Signal) }),
	Data = folder({ Brand = module(Brand) }),
	Assets = folder({
		Audio = module(Audio),
		AudioExtra = module(AudioExtra),
		AudioUI = module(AudioUI),
		Soundtrack = module(Soundtrack),
	}),
})
local services = {
	ReplicatedStorage = folder({ Conquista = shared_folder }),
	RunService = {
		Heartbeat = {
			Connect = function(_s, fn)
				heartbeat = fn
				return { Disconnect = function() end }
			end,
		},
	},
	SoundService = {},
	ContentProvider = { PreloadAsync = function() end },
	LogService = { MessageOut = fake_signal() },
}
local env = {
	game = {
		GetService = function(_g, name: string)
			return services[name]
		end,
	},
	script = { Parent = folder({ Playlist = module(Playlist) }) },
	Instance = { new = fake_instance },
	Enum = roblox.Enum,
	NumberRange = roblox.NumberRange,
	task = task_lib,
	require = function(m: any)
		return m.__module
	end,
}
local AudioDirector = luau.load(director_src, { debugName = "AudioDirector", environment = env })()
check(type(AudioDirector) == "table" and type(AudioDirector.new) == "function", "the director loads")

local function db_gain(db: number): number
	return 10 ^ (db / 20)
end
local function entry(name: string): any
	return AudioUI.sfx[name] or AudioExtra.sfx[name] or Audio.sfx[name]
end

local d = AudioDirector.new("")
check(heartbeat ~= nil, "the director runs every frame")
local n_streams, stand_ins = 0, 0
for k in d._sfx_streams do
	n_streams += 1
	if string.sub(k, -1) == "~" then
		stand_ins += 1
	end
end
check(n_streams == 62 and stand_ins == 0, string.format("62 sounds loaded, none left as a stand-in (%d, %d)", n_streams, stand_ins))
check(next(AudioDirector.REPLACE) == nil, "no sound is replaced by another")
check(next(AudioDirector.TRIM_DB) == nil, "no leftover trim of RoWorld's (the levels are the manifests')")
check(d._sfx_group.Name == "SFX" and d._sfx_group.Volume == 1, "the effects' group starts at full")
check(d:sfx_volume() == 1 and d:music_volume() == 1, "both sliders start at 100%")

--- The voice `name` last played on.
local function voice(name: string): any
	local best = nil
	for _, v in d._pool[name] or {} do
		if best == nil or v.started > best.started then
			best = v
		end
	end
	return best and best.sound
end

-- every sound plays its own audio at its own level
for _, name in names do
	local e = entry(name)
	d:play_sfx(name, 0.0, 0.0)
	local s = voice(name)
	check(s ~= nil and s.plays == 1, name .. " plays")
	for _, o in made do
		o.IsPlaying = false -- (it rang out: at most VOICE_COUNT sound at once)
	end
	if s == nil then
		continue
	end
	check(s.SoundId == "rbxassetid://" .. CHOSEN[name], name .. " plays the chosen audio")
	check(s.SoundGroup == d._sfx_group, name .. " is in the effects' group")
	check(near(s.Volume, math.min(10, db_gain(e.db)), 1e-6), string.format("%s plays at %+.1f dB (volume %.3f)", name, e.db, s.Volume))
	check(s.Volume > 0 and s.Volume <= 10, name .. ": a volume Roblox accepts")
	if e.sprite ~= nil then
		check(
			s.PlaybackRegionsEnabled == true and near(s.PlaybackRegion.Min, e.start, 1e-4) and near(s.PlaybackRegion.Max, e.stop, 1e-4),
			name .. " plays its part only"
		)
		check(near(s.played_at, e.start, 1e-4), name .. " starts where its sound starts")
	else
		check(s.PlaybackRegionsEnabled ~= true and s.played_at == 0, name .. " plays from the beginning")
	end
end
-- the caller's own level still counts, on top of the sound's
do
	local e = entry("shell_hit")
	task_lib.wait(0.12)
	d:play_sfx("shell_hit", -6.0, 0.0)
	check(near(voice("shell_hit").Volume, db_gain(e.db - 6.0)), "a call's -6 dB is added to the sound's level")
	-- the quiet horn at the end of the countdown: as its caller plays it (-2 dB), within Roblox's limit
	local horn = entry("countdown_gamestart")
	task_lib.wait(0.06)
	d:play_sfx("countdown_gamestart", -2.0, 0.0)
	local v = voice("countdown_gamestart").Volume
	check(near(v, db_gain(horn.db - 2.0)) and v <= 10, string.format("the start horn's boost fits (volume %.2f)", v))
end
-- an attack: the chosen sword, then the order tap while it is cooling down
do
	local sword, tap = voice("attack_launch"), voice("order_ack")
	local sp, tp = sword.plays, tap.plays
	task_lib.wait(0.1)
	d:play_sfx("attack_launch", 0.0, 0.0)
	check(sword.plays == sp and tap.plays == tp + 1, "a second attack within the cooldown plays the order tap")
end

-- the effects' slider: its own level, saved under its own key, never the music's
local saved = { audio = { music_enabled = true } }
local session = {
	settings_ready = true,
	settings_loaded = Signal.new(),
	load_settings = function(_s, section: string)
		return table.clone(saved[section] or {})
	end,
	save_settings = function(_s, section: string, t: any)
		saved[section] = table.clone(t)
	end,
}
d:bind_settings(session)
check(d:sfx_volume() == 1 and d._sfx_group.Volume == 1, "no saved level: the effects stay at 100%")
d:set_sfx_volume(0.5, false)
check(d:sfx_volume() == 0.5 and near(d._sfx_group.Volume, 0.25), "50% on the slider is a quarter of the gain (as the music's)")
check(saved.audio.sfx_volume == nil, "a drag in progress saves nothing")
d:set_sfx_volume(0.5, true)
check(saved.audio.sfx_volume == 0.5 and saved.audio.music_enabled == true, "lifting the finger saves [audio] sfx_volume, keeping the rest")
check(saved.audio.music_volume == nil and d:music_volume() == 1, "the music's level is untouched")
d:set_sfx_volume(0, true)
check(d._sfx_group.Volume == 0 and saved.audio.sfx_volume == 0, "0% silences the effects")
d:set_sfx_volume(7, false)
check(d:sfx_volume() == 1 and d._sfx_group.Volume == 1, "a level above 1 is 100%")
d:set_music_volume(0.4, true)
check(saved.audio.music_volume == 0.4 and d._sfx_group.Volume == 1 and d:sfx_volume() == 1, "the music's slider leaves the effects alone")
check(d._music_group.Volume == 1, "and the music's group is not what the effects' slider moves")

-- a saved level comes back in the next session
do
	saved = { audio = { sfx_volume = 0.3, music_volume = 0.8 } }
	local d2 = AudioDirector.new("")
	d2:bind_settings(session)
	check(near(d2:sfx_volume(), 0.3) and near(d2._sfx_group.Volume, 0.09), "a saved 30% is back after a restart")
	check(near(d2:music_volume(), 0.8), "next to the music's saved level")
	-- a level the player moved before the saved one arrived wins
	saved = { audio = { sfx_volume = 0.3 } }
	local late = { settings_ready = false, settings_loaded = Signal.new(), load_settings = session.load_settings, save_settings = session.save_settings }
	local d3 = AudioDirector.new("")
	d3:bind_settings(late)
	d3:set_sfx_volume(0.6, false)
	late.settings_loaded:Fire()
	check(near(d3:sfx_volume(), 0.6), "the player's own move is not overwritten by the saved level")
	saved = { audio = { sfx_volume = "x" } }
	local d4 = AudioDirector.new("")
	d4:bind_settings(session)
	check(d4:sfx_volume() == 1, "a broken saved value is ignored")
end

-- the music: each mood's track at its own level, under the music slider only
do
	saved = { audio = {} }
	local dm = AudioDirector.new("")
	dm:bind_settings(session)
	for _, mood in { "title", "wait", "calm", "war" } do
		dm:set_music_mood(mood)
		for _ = 1, 400 do
			(heartbeat :: any)(0.05)
		end
		local t = Soundtrack.tracks[Soundtrack.moods[mood][1]]
		local cur = dm._current
		check(cur ~= nil and cur.SoundId == t.id and cur.IsPlaying, mood .. ": its track plays")
		check(cur ~= nil and near(cur.Volume, db_gain(-6.0 + t.db), 1e-4), string.format("%s plays at %+.1f dB of the music's level", mood, t.db))
	end
	local t = Soundtrack.tracks[Soundtrack.moods.war[1]]
	dm:set_music_volume(0.5, false)
	check(near(dm._current.Volume, db_gain(-6.0 + t.db) * 0.25, 1e-4), "the music slider at 50% quarters it")
	dm:set_sfx_volume(0.2, false)
	check(near(dm._current.Volume, db_gain(-6.0 + t.db) * 0.25, 1e-4), "the effects' slider does not move the music")
end

-- ---------------------------------------------------------------------------------------------
-- 3. The Settings page
-- ---------------------------------------------------------------------------------------------

H.fake_game()
Lang.use("pt")
local PauseMenu = require("../src/client/UI/PauseMenu")

check(Lang.t("Effects") == "Efeitos", "the row's name is translated")

--- An audio stand-in as UICtx reads it.
local function fake_audio()
	local a = { sfx_level = 0.7, music_level = 0.9, calls = {} }
	function a:sfx_volume()
		return a.sfx_level
	end
	function a:set_sfx_volume(v, save)
		a.sfx_level = v
		table.insert(a.calls, { "sfx", v, save })
	end
	function a:music_volume()
		return a.music_level
	end
	function a:set_music_volume(v, save)
		a.music_level = v
		table.insert(a.calls, { "music", v, save })
	end
	function a:is_music_enabled()
		return true
	end
	function a:is_pops_enabled()
		return true
	end
	function a:play_sfx() end
	function a:has_sfx()
		return true
	end
	return a
end

for _, view in { { "pc", 1280, 720, false }, { "celular", 844, 390, true } } do
	for _, on_title in { true, false } do
		local what = string.format("settings (%s, %s)", view[1], if on_title then "title" else "match")
		local root, gui = H.root(view[2], view[3], view[4])
		local ok, err = xpcall(function()
			local ctx = UICtx.new()
			ctx.vp = root.vp
			ctx.compact = view[4]
			ctx.touch = view[4]
			ctx.touch_device = view[4]
			ctx.audio = fake_audio()
			local k = UITheme.scale
			ctx.reserved_top_left = Rect.new(0, 0, (if view[4] then 200 else 280) / k, (if view[4] then 44 else 58) / k)
			if not on_title then
				ctx.session = { mode = UICtx.MODE_SOLO }
				ctx.state_mode = UICtx.MODE_SOLO
			end
			local pause = PauseMenu.new(ctx)
			root:add_child(pause)
			local got = {}
			pause.sfx_volume_changed:Connect(function(v, final)
				table.insert(got, { v, final })
			end)
			local got_music = 0
			pause.music_volume_changed:Connect(function()
				got_music += 1
			end)
			-- through the menu to the settings and back twice, as a player does (every row moves each time)
			pause:open(true, "menu")
			pause:apply_layout()
			H.step(2)
			pause:show_settings()
			H.step(2)
			pause:_show_page("menu")
			H.step(2)
			check(pause._sfx:get_parent() == nil and pause._music:get_parent() == nil, what .. ": the sliders are not on the menu's page")
			pause:show_settings()
			pause:apply_layout()
			H.step(4)
			check(pause._on_title == on_title, what .. ": the page knows where it is")
			local row = pause._sfx
			check(row ~= nil and row.gui.Name == "SfxVolume", what .. ": the effects row exists")
			check(row.value == 0.7 and row._pct.Text == "70%", what .. ": it opens at the saved level (70%)")
			check(pause._music.value == 0.9, what .. ": beside the music's own (90%)")
			local x, y, w, h = H.rect(row.gui)
			check(w >= 200 and h >= 30, string.format("%s: the row has room (%.0f x %.0f)", what, w, h))
			check(x >= 0 and y >= 0 and x + w <= view[2] and y + h <= view[3], what .. ": the row is on the screen")
			local px, py, pw, ph = H.rect(pause._panel.gui)
			check(px >= -0.5 and py >= -0.5 and px + pw <= view[2] + 0.5 and py + ph <= view[3] + 0.5, string.format("%s: the window fits the screen (%.0f x %.0f at %.0f, %.0f)", what, pw, ph, px, py))
			-- no two rows on top of each other
			local rows = { pause._music, pause._sfx, pause._pops, pause._code }
			if not on_title then
				table.insert(rows, pause._labels)
				table.insert(rows, pause._confirm_sw)
			end
			for i = 1, #rows do
				local ax, ay, aw, ah = H.rect(rows[i].gui)
				check(aw > 0 and ah > 0, string.format("%s: row %d is shown", what, i))
				for j = i + 1, #rows do
					local bx, by, bw, bh = H.rect(rows[j].gui)
					local over = ax < bx + bw - 0.5 and bx < ax + aw - 0.5 and ay < by + bh - 0.5 and by < ay + ah - 0.5
					check(not over, string.format("%s: rows %d and %d do not overlap", what, i, j))
				end
			end
			-- the label fits before the track
			local label = nil
			for _, o in row.gui:GetDescendants() do
				if o:IsA("TextLabel") and o.Text == "Efeitos" then
					label = o
				end
			end
			check(label ~= nil, what .. ": the row says Efeitos")
			if label ~= nil then
				local lx, _, lw = H.rect(label)
				local tx = H.rect(row._track)
				check(lx + lw <= tx + 0.5, string.format("%s: the name ends (%.0f) before the track starts (%.0f)", what, lx + lw, tx))
			end
			-- moving it tells the game, the music's signal stays quiet
			row:_set(0.35, false)
			row:_set(0.35, true)
			check(#got == 2 and got[1][1] == 0.35 and got[1][2] == false and got[2][2] == true, what .. ": a drag, then the lift, are announced")
			check(got_music == 0, what .. ": the music's level is not announced")
			check(row._pct.Text == "35%", what .. ": the row shows 35%")
			-- a picture of it for the owner (tools/arte/telas.py draws assets/previa-config-*.png)
			if not on_title then
				row:set_value(0.7)
				H.step(2)
				H.save(gui, string.format("assets/telas/config-%s.json", view[1]))
			end
		end, function(e)
			return tostring(e) .. "\n" .. debug.traceback()
		end)
		check(ok, what .. " builds: " .. tostring(err))
	end
end
check(#H.problems() == 0, "no property Roblox does not have: " .. table.concat(H.problems(), "; "))

-- the wiring the page's signal needs (UIRoot can't be loaded here: read)
do
	local root_src = fs.readFile("src/client/UI/UIRoot.luau")
	check(
		string.find(root_src, "pause.sfx_volume_changed:Connect(function(v: number, final: boolean)\n\t\tctx:set_sfx_volume(v, final)", 1, true) ~= nil,
		"UIRoot passes the slider on to the audio"
	)
	local ctx = UICtx.new()
	ctx.audio = fake_audio()
	ctx:set_sfx_volume(0.25, true)
	check(ctx:sfx_volume() == 0.25 and ctx.audio.calls[1][1] == "sfx" and ctx.audio.calls[1][3] == true, "UICtx hands it to the director")
	local none = UICtx.new()
	check(none:sfx_volume() == 1, "without audio the level reads 100%")
	none:set_sfx_volume(0.5, true) -- (must not error)
end

print(string.format("sons: %d checks, %d failed", checks, failed))
if failed > 0 then
	error("sons failed")
end
