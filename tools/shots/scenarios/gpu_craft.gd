extends RefCounted
## Automated real-window craft probe. No OS input or pointer movement.
## Frame intervals are wall time between process frames, including VSync
## and presentation waits. They are not GPU execution times. Screenshots
## are taken outside stable sample windows to avoid readback in the samples.

var checks: Array = []
var samples: Array = []
var transitions: Array = []


func run(h) -> void:
	Settings.set_value("reduceMotion", false)
	Settings.set_value("weather", true)
	var info := _device_info()
	print("[gpu] ", JSON.stringify(info))
	_check("native display server", DisplayServer.get_name() != "headless")
	await h.new_game(7)
	await h.wait(2.0)
	_check("first morning clear", Weather.now(Game.state) == "clear")
	for sky in ["clear", "rain", "storm", "fog", "ash"]:
		await _sky(h, sky)
		await _sample(h, "port_" + sky, 2.0)
		if sky in ["clear", "storm", "fog", "ash"]:
			await h.shot("port_" + sky)

	await _sky(h, "storm")
	var wx = h.main.weather
	wx._strike(0.8)
	await h.frames(2)
	await h.shot("storm_flash")
	await h.wait(0.7)
	Settings.set_value("reduceMotion", true)
	h.main._update_weather()
	wx._bolt_t = 0.0
	wx._tick_lightning(0.0)
	await h.frames(2)
	_check("reduce motion suppresses new lightning flashes", not wx._flash.visible)
	_check("reduce motion preserves rain", float(wx._k.rain) > 0.9)
	# Simulate an already scheduled delayed thunder callback, then disable
	# weather before it arrives. Audio's last-start stamp proves no new voice.
	var before := _thunder_stamp()
	h.get_tree().create_timer(0.15).timeout.connect(wx._thunder.bind(0.5))
	Settings.set_value("weather", false)
	h.main._update_weather()
	await h.wait(0.3)
	_check("weather off cancels delayed thunder playback", _thunder_stamp() == before)
	await h.wait(2.5)
	_check("weather off clears weather bed", String(Audio._wx_id).get_slice("|", 0) == "")
	_check("weather off clears rain", float(wx._k.rain) == 0.0)
	Settings.set_value("weather", true)
	Settings.set_value("reduceMotion", false)
	await _sky(h, "rain")
	h.main.ship_view.set_view_level(1)
	await h.frames(3)
	h.main._update_weather()
	await h.wait(2.5)
	_check("below decks suppresses weather", wx.under and float(wx._k.rain) == 0.0 and String(Audio._wx_id).get_slice("|", 0) == "")
	await h.shot("below_decks_no_rain")
	h.main.ship_view.set_view_level(0)
	await h.frames(3)
	h.main._update_weather()
	await h.wait(2.5)
	_check("returning to weather deck restores rain", not wx.under and float(wx._k.rain) > 0.6)

	# Use real voyage transactions, but advance arrival directly. This tests
	# sea/island rendering without waiting for random sea encounter settlement.
	var departure: Dictionary = Actions.depart(Game.state, "gull_rock", {"confirmed": true})
	_check("test voyage starts", bool(departure.get("ok", false)))
	if departure.get("ok", false):
		Game.state = departure.state
		Game.state.encounter = null
		Game.state.voyage.event = null
		Game.state.voyage.site = null
		h.main._lock = 0
		_sync(h, "port_to_sea")
		await _sample(h, "sea_transition", 0.6)
		await h.shot("sea_after_sweep")
		await _sky(h, "storm")
		await _sample(h, "sea_storm", 3.0)
		await h.shot("sea_storm")
		Actions.arrive(Game.state, "gull_rock")
		h.main._lock = 0
		_sync(h, "sea_to_island")
		await _sample(h, "island_transition", 0.6)
		await _sky(h, "fog")
		await h.wait(2.0)
		await _sample(h, "island_fog", 2.0)
		await h.shot("island_fog")

	await _battle(h, "gull_rock", "landing", "land", false)
	await _battle(h, "old_lookout", "guardian", "boss", false)
	Settings.set_value("reduceMotion", true)
	await _battle(h, "gull_rock", "landing", "reduce_motion", true)
	Settings.set_value("reduceMotion", false)
	Weather.forced = ""
	Engine.time_scale = 1.0
	# Let distance-delayed thunder callbacks expire before the harness stops
	# audio and quits, with no new storm callbacks scheduled in the meantime.
	Settings.set_value("weather", false)
	h.main._update_weather()
	await h.wait(3.0)
	var report := {"device": info, "samples": samples, "transitions": transitions, "checks": checks,
		"scope": "Automated source-project rendering only. No mouse playtest, human motion assessment, speaker listening, or campaign balance review.",
		"timing": "Wall process-frame intervals include VSync and presentation. Process/physics monitors are CPU-side engine counters; none are GPU timers."}
	var file := FileAccess.open(h.out_dir.path_join("metrics.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	else:
		push_error("could not write GPU metrics")
	for check in checks:
		if not check.passed:
			push_error("GPU check failed: " + String(check.name))


func _device_info() -> Dictionary:
	var screens: Array = []
	for i in DisplayServer.get_screen_count():
		screens.append({"index": i, "size": str(DisplayServer.screen_get_size(i)),
			"position": str(DisplayServer.screen_get_position(i)), "refresh_hz": DisplayServer.screen_get_refresh_rate(i)})
	return {"engine": Engine.get_version_info().string,
		"build_revision": ProjectSettings.get_setting("application/config/build_revision", ""),
		"display_server": DisplayServer.get_name(),
		"adapter": RenderingServer.get_video_adapter_name(), "vendor": RenderingServer.get_video_adapter_vendor(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"vsync_mode": DisplayServer.window_get_vsync_mode(), "screens": screens,
		"window_size": str(DisplayServer.window_get_size())}


func _check(label: String, passed: bool) -> void:
	checks.append({"name": label, "passed": passed})
	print("[gpu-check] ", "PASS " if passed else "FAIL ", label)


func _thunder_stamp() -> String:
	return "%s|%s" % [Audio._last.get("thunder_near", -1), Audio._last.get("thunder_far", -1)]


func _sky(h, sky: String) -> void:
	Weather.forced = sky
	h.main._sky_stage = ""
	h.main._update_weather()
	await h.wait(2.5)


func _sample(h, label: String, seconds: float) -> void:
	var intervals: Array[float] = []
	var process_ms := 0.0
	var physics_ms := 0.0
	var calls := 0.0
	var end_usec := Time.get_ticks_usec() + int(seconds * 1000000.0)
	var previous := Time.get_ticks_usec()
	while Time.get_ticks_usec() < end_usec:
		await h.get_tree().process_frame
		var now := Time.get_ticks_usec()
		intervals.append(float(now - previous) / 1000.0)
		previous = now
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	if intervals.is_empty():
		return
	var sum_ms := 0.0
	for t in intervals:
		sum_ms += t
	intervals.sort()
	var n := intervals.size()
	var sample := {"stage": label, "frames": n, "mean_frame_ms": sum_ms / n,
		"p50_frame_ms": intervals[int(floor((n - 1) * 0.50))],
		"p95_frame_ms": intervals[int(floor((n - 1) * 0.95))],
		"p99_frame_ms": intervals[int(floor((n - 1) * 0.99))], "max_frame_ms": intervals[-1],
		"mean_process_cpu_ms": process_ms / n, "mean_physics_cpu_ms": physics_ms / n,
		"mean_draw_calls": calls / n, "engine_time_scale": Engine.time_scale}
	samples.append(sample)
	print("[gpu-sample] ", JSON.stringify(sample))


func _sync(h, label: String) -> void:
	var started := Time.get_ticks_usec()
	h.main._sync_world()
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	transitions.append({"stage": label, "sync_stage_ms": elapsed})
	print("[gpu] sync_stage ", label, " ", elapsed, " ms (CPU wall time, includes synchronous curtain readback/bind)")


func _battle(h, location: String, room: String, label: String, reduced: bool) -> void:
	await h.new_game(7)
	h.main._free_stage_views()
	Game.state.encounter = null
	var def := World.encounter_for(location, room)
	Actions.start_encounter(Game.state, def, {"type": "room", "locationId": location, "roomId": room})
	h.main._lock = 0
	_sync(h, label + "_battle_entry")
	await _sample(h, label + "_battle_transition", 0.12 if reduced else 0.3)
	await h.shot(label + "_opening")
	var bv = h.main.battle_view
	_check(label + " battle started", bv != null)
	if bv == null:
		return
	if label == "boss":
		await h.wait(1.8)
		await h.shot("boss_intro")
		_check("boss intro holds combat", bool(bv._cine_hold))
		_check("dungeon boss has no weather", bool(h.main.weather.under))
		await h.wait(3.0)
		_check("boss health bar visible after intro", bv._boss_bar.visible)
	else:
		await h.wait(1.8)
	await _sample(h, label + "_battle", 3.0)
	await h.shot(label + "_battle")
	bv.set_speed(2)
	await _sample(h, label + "_battle_4x", 2.0)
	h.main._free_stage_views()
	Game.state.encounter = null
	h.main._lock = 0
	_sync(h, label + "_battle_exit")
	await _sample(h, label + "_battle_exit_transition", 0.7)
