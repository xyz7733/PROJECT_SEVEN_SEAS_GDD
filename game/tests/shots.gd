## Development-only visual tour. Runs the real main scene in a window and
## saves viewport screenshots, driven by a scenario script, so rendering can
## be reviewed without a manual playtest. Never exported (tests/* is excluded).
##
##   godot --path game res://tests/shots.tscn -- --out DIR --scenario FILE.gd
##
## The scenario is a GDScript file with `func run(h) -> void` (a coroutine);
## `h` is this node. Use an isolated XDG_DATA_HOME / APPDATA so the player's
## saves and settings are never touched.
extends Node

var main: Node
var out_dir := "user://shots"
var count := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scenario := ""
	var i := 0
	while i < args.size():
		match args[i]:
			"--out":
				out_dir = args[i + 1]
				i += 1
			"--scenario":
				scenario = args[i + 1]
				i += 1
			"--locale":
				Settings.set_value("locale", args[i + 1])
				i += 1
			"--ui":
				Settings.set_value("textScale", float(args[i + 1]))
				i += 1
		i += 1
	if not Settings.has_locale():
		Settings.set_value("locale", "en")
	Settings.set_value("guide", false)
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(4)
	if scenario == "":
		await wait(1.0)
		await shot("title")
	else:
		var src := FileAccess.get_file_as_string(scenario)
		var gs := GDScript.new()
		gs.source_code = src
		var err := gs.reload()
		if err != OK:
			push_error("scenario failed to compile: %s" % scenario)
			get_tree().quit(2)
			return
		var obj: Object = gs.new()
		await obj.run(self)
	print("shots done: %d written to %s" % [count, out_dir])
	await _silence()
	get_tree().quit(0)


## Stops every sound and lets the mixer drop the playbacks, so quitting in
## the middle of a track does not report them as leaked at exit.
func _silence() -> void:
	for p in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		(p as AudioStreamPlayer).stop()
	await wait(0.25)


# ---------------------------------------------------------------- timing
func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func shot(sname: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	count += 1
	var path := "%s/%02d_%s.png" % [out_dir, count, sname]
	img.save_png(path)
	print("shot ", path, " ", img.get_size())


# ----------------------------------------------------------------- state
func new_game(seed_value := 7) -> void:
	main._close_all_windows()
	Game.new_game(seed_value)
	main.enter_game()
	await frames(3)


func load_state(st: Dictionary) -> void:
	main._close_all_windows()
	Game.load_state(st)
	main.enter_game()
	await frames(3)


func act(res: Dictionary) -> bool:
	var ok := Game.act(res)
	if not ok:
		print("act failed: ", res.get("reasonKey", "?"), " ", res.get("reasonParams", {}))
	await frames(2)
	return ok


# ----------------------------------------------------------------- input
func key(code: Key, shift := false) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		ev.shift_pressed = shift
		Input.parse_input_event(ev)
		await frames(2)


func move(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	Input.parse_input_event(ev)
	Input.warp_mouse(p)
	await frames(2)


func click(p: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	await move(p)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = p
		ev.global_position = p
		ev.button_index = button
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await frames(2)


func wheel(p: Vector2, up: bool, n := 1) -> void:
	await move(p)
	for _i in n:
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.position = p
			ev.global_position = p
			ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
			ev.pressed = pressed
			Input.parse_input_event(ev)
			await frames(1)
