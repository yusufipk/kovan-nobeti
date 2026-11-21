extends Node
# Root of the game: builds every system, owns the state (menu, run, pause, end) and the saved settings.

const VERSION := "v1.1"
const SAVE_PATH := "user://kovan_nobeti.json"
const SETTING_RANGE := {"sens": [0.2, 3.0], "music": [0.0, 1.0], "sfx": [0.0, 1.0], "brightness": [0.6, 1.5]}

const Assets := preload("res://scripts/assets.gd")
const World := preload("res://scripts/world.gd")
const Player := preload("res://scripts/player.gd")
const Enemies := preload("res://scripts/enemies.gd")
const Weapons := preload("res://scripts/weapons.gd")
const Pickups := preload("res://scripts/pickups.gd")
const Fx := preload("res://scripts/fx.gd")
const Audio := preload("res://scripts/audio.gd")
const Game := preload("res://scripts/game.gd")
const Ui := preload("res://scripts/ui.gd")
const Bot := preload("res://scripts/bot.gd")

enum { MENU, PLAY, END }

var assets
var world
var player
var enemies
var weapons
var pickups
var fx
var audio
var game
var ui
var bot

var state := MENU
var paused := false
var last_frame_us := 0
var was_paused := false
var settings := {"sens": 1.0, "music": 0.9, "sfx": 0.9, "brightness": 1.0}
var record := {"runs": 0, "best_time": 0.0, "best_kills": 0, "wins": 0, "best_loop": 1}
var honey := 0
var meta := {}
var last_honey := 0
var story_seen := false
var fullscreen := false
var menu_yaw := 0.0
var hit_stop := 0.0
var hit_stop_cd := 0.0

# test hooks (debug builds only)
var bot_mode := false
var bot_once := false
var debug_god := false
var debug_speed := 1.0:
	set(v):
		debug_speed = clampf(v, 0.1, 20.0)
		if state == PLAY and game != null and not game.over:
			Engine.time_scale = debug_speed
var debug_time := -1.0:
	set(v):
		debug_time = v
		if game != null and v >= 0.0:
			game.time = v
			game.loop = 1 + int(floor(v / game.CYCLE_TIME))
			game.loop_time = fmod(v, game.CYCLE_TIME)
			game.next_wave = (floor(v / 60.0) + 1.0) * 60.0
			game.next_elite = v + 20.0
			game.champs_sent = 0
			for ct in game.CHAMP_TIMES:
				if game.loop_time > ct + 5.0:
					game.champs_sent += 1
var debug_levels := 0:
	set(v):
		debug_levels = v
		if game != null and v > 0:
			for i in mini(v, 200):
				game.level += 1
				game.xp_need = game._need(game.level)
				if bot_mode and not ui.hold_choice:
					var c: Array = game.choices()
					game.apply(c[ui.bot_pick(c)].id)
				else:
					game.queue.append("level")
var debug_ui := "":
	set(v):
		debug_ui = v
		if v == "settings" and ui != null:
			ui.open_settings()
			return
		if v == "hive" and ui != null:
			ui.open_hive()
			return
		if v == "story" and ui != null:
			ui.open_story(false)
			return
		if game == null or state != PLAY or not bot_mode:
			return
		if v == "ult":
			game.ult = 1.0
			game.try_ult()
		elif v == "choice":
			ui.hold_choice = true
			game.queue.append("level")
		elif v == "chest":
			ui.hold_choice = true
			game.queue.append("chest")
		elif v == "evo":
			ui.hold_choice = true
			weapons.levels.ari = 6
			weapons.levels.bomba = 3
			game.passives.cogalt = 2
			game._recalc()
			game.queue.append("chest")
		elif v == "evochest":
			ui.hold_choice = true
			weapons.levels.ari = 4
			weapons.levels.bomba = 3
			game._recalc()
			game.evo_chests = 1
			game.open_chest()
		elif v == "pause":
			toggle_pause()
		elif v == "win":
			game._on_boss_defeated(player.pos)
		elif v == "lose":
			player.hp = 0.0
			player.alive = false
			game.on_player_dead()
var debug_start := false:
	set(v):
		debug_start = v
		if v and state != PLAY and game != null:
			start_run()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_load()
	var want_time := -1.0
	var want_levels := 0
	var want_ui := ""
	var args := OS.get_cmdline_user_args() if OS.is_debug_build() else PackedStringArray()
	for a in args:
		if a == "--bot":
			bot_mode = true
		elif a == "--once":
			bot_once = true
		elif a == "--god":
			debug_god = true
		elif a.begins_with("--speed="):
			debug_speed = float(a.split("=")[1])
		elif a.begins_with("--time="):
			want_time = float(a.split("=")[1])
		elif a.begins_with("--levels="):
			want_levels = int(a.split("=")[1])
		elif a.begins_with("--ui="):
			want_ui = a.split("=")[1]
	if not bot_mode:
		debug_god = false
		debug_speed = 1.0
	assets = Assets.new()
	audio = Audio.new()
	add_child(audio)
	audio.setup(self)
	world = World.new()
	add_child(world)
	world.setup(self)
	fx = Fx.new()
	add_child(fx)
	fx.setup(self)
	enemies = Enemies.new()
	add_child(enemies)
	enemies.setup(self)
	player = Player.new()
	add_child(player)
	player.setup(self)
	weapons = Weapons.new()
	add_child(weapons)
	weapons.setup(self)
	pickups = Pickups.new()
	add_child(pickups)
	pickups.setup(self)
	game = Game.new()
	add_child(game)
	game.setup(self)
	bot = Bot.new()
	bot.setup(self)
	ui = Ui.new()
	add_child(ui)
	ui.setup(self)
	var names := {"World": world, "Fx": fx, "Enemies": enemies, "Player": player, "Weapons": weapons, "Pickups": pickups, "Game": game, "Audio": audio, "Ui": ui}
	for key in names:
		names[key].name = key
	for n in [world, fx, enemies, player, weapons, pickups, game]:
		n.process_mode = Node.PROCESS_MODE_PAUSABLE
	apply_settings()
	to_menu()
	if bot_mode:
		start_run()
		debug_time = want_time
		debug_levels = want_levels
		if want_ui != "":
			debug_ui = want_ui
	elif not story_seen:
		ui.open_story(true)

func _setup_input() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_fwd": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE], "slide": [KEY_SHIFT, KEY_CTRL], "pause": [KEY_ESCAPE],
		"ult": [KEY_Q], "fullscreen": [KEY_F11],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("ult", mb)

func _num(v) -> bool:
	return (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and is_finite(float(v))

func _load() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null or f.get_length() > 65536:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	var s = data.get("ayarlar")
	if typeof(s) == TYPE_DICTIONARY:
		for k in settings:
			if _num(s.get(k)):
				settings[k] = clampf(float(s[k]), SETTING_RANGE[k][0], SETTING_RANGE[k][1])
	var r = data.get("rekor")
	if typeof(r) == TYPE_DICTIONARY:
		for k in record:
			if _num(r.get(k)):
				var v: float = clampf(float(r[k]), 0.0, 1.0e9)
				if k == "best_time":
					record[k] = v
				elif k == "best_loop":
					record[k] = maxi(1, int(v))
				else:
					record[k] = int(v)
	if _num(data.get("bal")):
		honey = int(clampf(float(data["bal"]), 0.0, 1.0e7))
	var a = data.get("aricilik", data.get("arilik"))
	if typeof(a) == TYPE_DICTIONARY:
		for def in Game.META:
			if _num(a.get(def.id)):
				meta[def.id] = int(clampf(float(a[def.id]), 0.0, float(def.cost.size())))
	if typeof(data.get("hikaye_goruldu")) == TYPE_BOOL:
		story_seen = bool(data["hikaye_goruldu"])

func save_settings() -> void:
	if bot_mode:
		return
	var text := JSON.stringify({"ayarlar": settings, "rekor": record, "bal": honey, "aricilik": meta, "hikaye_goruldu": story_seen}, "\t")
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
		if DirAccess.rename_absolute(tmp, SAVE_PATH) == OK:
			return
	f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(text)

func meta_lv(id: String) -> int:
	return 0 if bot_mode else int(meta.get(id, 0))

func buy_meta(id: String) -> bool:
	for def in Game.META:
		if def.id == id:
			var lv := int(meta.get(id, 0))
			if lv >= def.cost.size() or honey < int(def.cost[lv]):
				return false
			honey -= int(def.cost[lv])
			meta[id] = lv + 1
			save_settings()
			return true
	return false

func toggle_fullscreen() -> void:
	if bot_mode:
		return
	fullscreen = not fullscreen
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func apply_settings() -> void:
	audio.apply_volumes()
	world.set_brightness(settings.brightness)

func capture_mouse() -> void:
	if not bot_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func to_menu() -> void:
	state = MENU
	paused = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	game.active = false
	game.queue.clear()
	enemies.clear()
	pickups.reset()
	weapons.reset()
	world.reset()
	player.reset()
	fx.reset()
	ui.show_menu()
	release_mouse()
	audio.music("menu")

func start_run() -> void:
	state = PLAY
	paused = false
	get_tree().paused = false
	hit_stop = 0.0
	hit_stop_cd = 0.0
	game.start()
	ui.start_hud()
	capture_mouse()

func toggle_pause() -> void:
	if state != PLAY or game.over:
		return
	if ui.choosing:
		paused = not paused
		ui.show_pause(paused)
		if not paused:
			save_settings()
		return
	paused = not paused
	get_tree().paused = paused
	ui.show_pause(paused)
	if paused:
		release_mouse()
	else:
		save_settings()
		capture_mouse()

func leave_run() -> void:
	if state != PLAY or bot_mode or game.over:
		return
	record.runs += 1
	record.best_time = maxf(record.best_time, game.time)
	record.best_kills = maxi(record.best_kills, game.kills)
	record.best_loop = maxi(int(record.get("best_loop", 1)), game.loop)
	record.wins += game.boss_kills
	last_honey = game.honey_for_run(false)
	honey += last_honey
	save_settings()

func stop_for(d: float, always := false) -> void:
	if always or hit_stop_cd <= 0.0:
		hit_stop = maxf(hit_stop, d)
		hit_stop_cd = 0.5

func _notification(what: int) -> void:
	if ui == null:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if state == PLAY and not paused and not bot_mode:
			toggle_pause()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_settings()

func finish_run(victory: bool) -> void:
	state = END
	var new_record := false
	last_honey = game.honey_for_run(victory)
	if not bot_mode:
		honey += last_honey
		record.runs += 1
		record.wins += game.boss_kills
		record.best_loop = maxi(int(record.get("best_loop", 1)), game.loop)
		if game.time > record.best_time:
			record.best_time = game.time
			new_record = record.runs > 1
		record.best_kills = maxi(record.best_kills, game.kills)
		save_settings()
	release_mouse()
	ui.show_end(victory, new_record)
	if bot_mode and bot_once:
		get_tree().quit()

func quit_game() -> void:
	save_settings()
	get_tree().quit()

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("fullscreen"):
		toggle_fullscreen()
	elif ev.is_action_pressed("ult"):
		if state == PLAY and not paused and not ui.choosing:
			game.try_ult()
	elif ev.is_action_pressed("pause"):
		if ui.story_panel.visible:
			ui.close_story()
		elif ui.settings_overlay.visible:
			ui.close_settings()
		elif ui.hive_panel.visible:
			ui.close_hive()
		else:
			toggle_pause()
	elif ev is InputEventMouseMotion and state == PLAY and not paused and not ui.choosing and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.look((ev as InputEventMouseMotion).screen_relative)

func _process(dt: float) -> void:
	if bot_mode:
		var now := Time.get_ticks_usec()
		var ms := (now - last_frame_us) / 1000.0
		last_frame_us = now
		if ms > 40.0 and ms < 5000.0 and state == PLAY and game.time > 4.0 and not get_tree().paused and not was_paused:
			print("T HITCH ms=%d t=%d after=%s age=%dms" % [int(ms), int(game.time), game.last_event, Time.get_ticks_msec() - game.last_event_ms])
		was_paused = get_tree().paused
	if state == PLAY:
		if get_tree().paused:
			return
		var real := dt / maxf(0.05, Engine.time_scale)
		hit_stop_cd -= real
		if hit_stop > 0.0:
			hit_stop -= real
			player.buffer_input()
			player.hold_camera(real)
			return
		if bot_mode:
			bot.update(dt)
		game.update(dt)
	else:
		menu_yaw += dt * 0.12
		player.cam_yaw = menu_yaw
		player.cam_pitch = -0.2
		player.menu_idle(dt)
		fx.update(dt)
