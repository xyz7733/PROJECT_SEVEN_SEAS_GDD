extends Node
## Purpose-built engine review driver, distinct from OS mouse automation.
## All scenarios identify API transactions versus synthetic Godot inputs.

var main: Node
var out_dir := ""
var count := 0
var evidence: Array = []
var checks: Array = []
var timings: Array[float] = []
var _last_frame := 0
var _started := 0
var _scenario := ""
var _audio_scope := "Dummy"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var locale := "zh_CN"
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size(): out_dir = args[i + 1]
		if args[i] == "--scenario" and i + 1 < args.size(): _scenario = args[i + 1]
		if args[i] == "--locale" and i + 1 < args.size(): locale = args[i + 1]
		if args[i] == "--audio-scope" and i + 1 < args.size(): _audio_scope = args[i + 1]
	if out_dir == "":
		push_error("Review requires an isolated --out directory")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_started = Time.get_ticks_usec()
	Settings.set_value("locale", locale)
	I18n.set_locale(locale)
	# Fullscreen is the requested operating mode; verify the actual server.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	await frames(8)
	var device := _device()
	record("device", device)
	check("Native Windows display", DisplayServer.get_name() != "headless")
	check("Fullscreen mode", DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN])
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(8)
	await wait(1.0)
	await shot("title_fullscreen")
	if _scenario != "":
		var code := FileAccess.get_file_as_string(_scenario)
		var script := GDScript.new()
		script.source_code = code
		var error := script.reload()
		if error != OK:
			check("Scenario compiles", false)
			Audio.stop_all()
			await wait(0.25)
			_finish(2)
			return
		await script.new().run(self)
	else:
		await new_game(7)
		await wait(1.5)
		await shot("fresh_port_fullscreen")
		main.ship_view.set_view_level(1)
		await wait(0.8)
		await shot("fresh_interior_fullscreen")
	await Audio.stop_all()
	await wait(0.25)
	_finish(0)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_frame > 0:
		timings.append(float(now - _last_frame) / 1000.0)
	_last_frame = now

func _device() -> Dictionary:
	var screens: Array = []
	for i in DisplayServer.get_screen_count():
		screens.append({"index": i, "size": str(DisplayServer.screen_get_size(i)), "hz": DisplayServer.screen_get_refresh_rate(i)})
	return {"engine": Engine.get_version_info().string,
		"revision": ProjectSettings.get_setting("application/config/build_revision", ""),
		"display_server": DisplayServer.get_name(), "adapter": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(), "window_mode": DisplayServer.window_get_mode(),
		"window_size": str(DisplayServer.window_get_size()), "viewport_size": str(get_viewport().get_visible_rect().size),
		"screen": DisplayServer.window_get_current_screen(), "screens": screens,
		"audio": _audio_scope + "; no speaker listening claimed", "input": "Game API and Godot Input events; no OS mouse control"}

func _finish(code: int) -> void:
	var sorted := timings.duplicate()
	sorted.sort()
	var result := {"device": _device(), "scenario": _scenario, "checks": checks,
		"events": evidence, "screenshots": count, "elapsed_seconds": float(Time.get_ticks_usec() - _started) / 1000000.0,
		"frame_intervals": {"count": sorted.size(), "p95_ms": sorted[int(sorted.size() * 0.95)] if not sorted.is_empty() else 0.0,
		"max_ms": sorted[-1] if not sorted.is_empty() else 0.0, "includes_capture_and_stage_construction": true},
		"scope": "Full-screen exact shipped PCK driven through engine APIs. Fixtures and organic progression labelled by scenario. No OS mouse or speaker listening evidence."}
	var f := FileAccess.open(out_dir.path_join("review-evidence.json"), FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(result, "\t"))
	print("[review-complete] ", count, " screenshots; ", checks.size(), " checks")
	get_tree().quit(code)

func record(label: String, details: Variant = {}) -> void:
	evidence.append({"name": label, "details": details, "seconds": float(Time.get_ticks_usec() - _started) / 1000000.0})
	print("[review] ", label, " ", JSON.stringify(details))

func check(label: String, passed: bool) -> void:
	checks.append({"name": label, "passed": passed})
	print("[review-check] ", "PASS " if passed else "FAIL ", label)

func frames(n: int) -> void:
	for i in n: await get_tree().process_frame

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	count += 1
	var path := out_dir.path_join("%03d_%s.png" % [count, label.validate_filename()])
	img.save_png(path)
	record("screenshot", {"name": label, "file": path.get_file(), "size": str(img.get_size())})

func new_game(seed_value := 7) -> void:
	main._close_all_windows()
	Game.new_game(seed_value)
	main.enter_game()
	await frames(4)

func load_state(state: Dictionary) -> void:
	main._close_all_windows()
	Game.load_state(state)
	main.enter_game()
	await frames(4)

func act(result: Dictionary) -> bool:
	var ok := Game.act(result)
	if not ok: record("transaction_failed", {"reasonKey": result.get("reasonKey", "?"), "params": result.get("reasonParams", {})})
	await frames(3)
	return ok

func key(code: Key, shift := false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		event.shift_pressed = shift
		Input.parse_input_event(event)
		await frames(2)

func click(point: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	Input.warp_mouse(point)
	await frames(2)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(3)
