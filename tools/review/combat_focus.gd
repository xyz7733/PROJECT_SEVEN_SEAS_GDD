extends RefCounted
## Targeted real-time follow-up to the broad paused catalogue. All content
## placement is an explicit fixture; crew/resources remain the seed-7 start.
## Commands use visible button input or their normal UI callbacks. No combat
## invulnerability, health, damage, outcome, or simulation-state edits.

var cases: Array = []


func run(h) -> void:
	h.record("combat_focus_scope", {"method": "Exact shipped PCK, real-time x1 battle, engine Input plus normal UI callbacks",
		"fixture": "Direct location placement and prerequisite room clearance only; seed7 starter crew/equipment/resources",
		"naturalBattleWallLimitSeconds": 26, "organicCampaignCompletion": false})
	Settings.set_value("guide", false)
	Settings.set_value("textScale", 1.0)
	Settings.set_value("battleSpeed", 1)
	Settings.set_value("weather", true)
	Weather.forced = "clear"
	await _site_fit(h, "gull_rock")
	await _site_fit(h, "old_lookout")
	await _live_battle(h, "gull_rock", "landing", false, true)
	await _live_battle(h, "old_lookout", "guardian", false, false)
	await _paused_entry(h)
	await _outdoor_nights_and_weather(h)
	await _shelter_precondition(h)
	Weather.forced = ""
	Settings.set_value("reduceMotion", false)
	Settings.set_value("pauseAtEncounterStart", false)
	var file := FileAccess.open(h.out_dir.path_join("combat-focus.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"scope": "Targeted native fullscreen fixture follow-up", "cases": cases}, "\t"))
	h.record("combat_focus_complete", {"cases": cases.size()})


func _fixture(loc_id: String, room_id := "") -> Dictionary:
	var state: Dictionary = GS.create_new_game(7)
	var loc: Dictionary = C.location(loc_id)
	state.world.currentLocationId = loc_id
	state.captain.regionId = loc.regionId
	state.world.locations[loc_id].k = "visited"
	state.codex.locations[loc_id] = true
	if String(loc.type) == "port":
		state.world.lastSafePortId = loc_id
		state.voyage = null
	else:
		state.voyage = {"id": "focus-fixture", "originPortId": "brightquay", "at": loc_id,
			"route": null, "event": null, "site": {"locationId": loc_id, "current": null}}
	if room_id != "":
		for room in C.rooms(loc_id):
			if room.id != room_id:
				state.world.locations[loc_id].rooms.append(room.id)
	return state


func _load(h, state: Dictionary) -> void:
	h.main.mode = "fixture_loading"
	await h.load_state(state)
	await h.wait(0.35)


func _click_control(h, control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return false
	var physical: Vector2 = control.get_viewport().get_screen_transform() * control.get_global_transform_with_canvas() * (control.size * 0.5)
	await h.click(physical)
	await h.frames(4)
	return true


func _fit_ui(h) -> void:
	var clicked: bool = await _click_control(h, h.main.hud._fit_btn)
	h.check("Fit HUD input available", clicked)
	await h.frames(6)


func _site_fit(h, loc_id: String) -> void:
	Settings.set_value("reduceMotion", true)
	await _load(h, _fixture(loc_id))
	var site = h.main.site_view
	if site == null:
		h.check("Site exists " + loc_id, false)
		return
	await h.shot("focus_site_" + loc_id + "_default")
	await _fit_ui(h)
	var vp: Vector2 = site.get_viewport_rect().size
	var top := clampf(float(site._inset_chips) + 4.0, 0.0, vp.y * 0.4)
	var free := Rect2(Vector2(0, top), Vector2(vp.x, maxf(64.0, vp.y - top - 34.0)))
	var room_points := []
	var all_nodes := true
	for id in site._nodes:
		var p: Vector2 = site.get_global_transform_with_canvas() * site._nodes[id]
		var inside := free.grow(1.0).has_point(p)
		all_nodes = all_nodes and inside
		room_points.append({"id": id, "canvas": str(p), "insideFreeArea": inside})
	var landmark = site.stage.get_node_or_null("LocationLandmark")
	var landmark_rect := Rect2()
	var landmark_fits := false
	if landmark != null:
		landmark_rect = landmark.get_global_transform_with_canvas() * landmark.get_rect()
		landmark_fits = free.grow(1.0).encloses(landmark_rect)
	var info := {"name": "site_fit:" + loc_id, "fixture": true, "input": "Godot Input click on HUD Fit button",
		"viewport": str(vp), "freeArea": str(free), "cameraPosition": str(site.cam.position), "zoom": str(site.cam.zoom),
		"nodes": room_points, "allRoomNodesInFreeArea": all_nodes,
		"landmarkRect": str(landmark_rect), "landmarkInsideFreeArea": landmark_fits}
	cases.append(info)
	h.record("focus_site_fit", info)
	h.check("HUD Fit shows every room node " + loc_id, all_nodes)
	h.check("HUD Fit shows complete landmark " + loc_id, landmark_fits)
	await h.shot("focus_site_" + loc_id + "_hud_fit")


func _live_battle(h, loc_id: String, room_id: String, reduced: bool, commands: bool) -> void:
	Settings.set_value("reduceMotion", reduced)
	Settings.set_value("pauseAtEncounterStart", false)
	await _load(h, _fixture(loc_id, room_id))
	var entered: bool = await h.act(Actions.enter_room(Game.state, room_id))
	h.check("Real-time encounter entered " + loc_id, entered)
	if not entered or h.main.battle_view == null:
		return
	var battle = h.main.battle_view
	battle.set_speed(0)
	var label := loc_id + "_" + room_id
	var start := Time.get_ticks_usec()
	for mark in [0.0, 0.35, 2.0, 4.0, 8.0]:
		await _until(h, start, float(mark))
		if not is_instance_valid(battle):
			break
		await _capture_battle(h, battle, label, "t" + str(mark).replace(".", "_"))
		if commands and is_equal_approx(float(mark), 2.0) and battle.sim.outcome == null:
			await _commands(h, battle, label)
	var natural := true
	while is_instance_valid(battle) and battle.sim.outcome == null and float(Time.get_ticks_usec() - start) / 1000000.0 < 26.0:
		await h.wait(0.2)
	if is_instance_valid(battle) and battle.sim.outcome == null:
		natural = false
		h.record("focus_wall_limit", {"case": label, "wallSeconds": 26, "simTick": battle.sim.tick,
			"action": "Normal Skip control after the bounded x1 observation; outcome is not natural real-time completion"})
		await _click_control(h, battle._skip_btn)
	var waits := 0
	while h.main._report == null and waits < 35:
		await h.wait(0.1)
		waits += 1
	if h.main._report == null:
		h.check("Real-time report appeared " + label, false)
		return
	var summary: Dictionary = h.main._report.sm.duplicate(true)
	var info := {"name": "real_time_battle:" + label, "fixture": true,
		"crew": "Unmodified seed7 four starters/equipment; no level or resource changes",
		"x1NaturalCompletion": natural, "wallSeconds": float(Time.get_ticks_usec() - start) / 1000000.0,
		"outcome": summary.get("outcome", ""), "battleSeconds": summary.get("time", 0), "hpAvg": summary.get("hpAvg", 0)}
	cases.append(info)
	h.record("focus_real_time_result", info)
	await h.shot("focus_" + label + "_outcome")
	if h.main._report._needs_choice:
		h.main._report._choose_recruit(false)
	await _click_control(h, h.main._report._collect)
	await h.frames(4)
	await h.key(KEY_ENTER)
	await h.frames(5)


func _commands(h, battle, label: String) -> void:
	await _click_control(h, battle._pause_btn)
	var paused_tick := int(battle.sim.tick)
	await h.wait(0.4)
	h.check("Pause button holds combat tick", battle.paused and int(battle.sim.tick) == paused_tick)
	await _capture_battle(h, battle, label, "paused")
	await _click_control(h, battle._stance_btns.defensive)
	h.check("Stance UI applies while paused", String(battle.sim.stance) == "defensive")
	var option: OptionButton = battle._prio_opt
	for index in option.item_count:
		if option.get_item_metadata(index) == "survival":
			option.select(index)
			option.item_selected.emit(index)
			break
	h.check("Priority normal UI callback applies while paused", String(battle.sim.priority) == "survival")
	var focus_target: Variant = null
	for uid in battle._actors:
		var unit = battle._units.get(uid)
		if unit != null and unit.side == "enemy" and unit.alive:
			focus_target = uid
			var actor: Actor = battle._actors[uid]
			var center: Vector2 = actor.pick_rect().get_center()
			var physical: Vector2 = actor.get_viewport().get_screen_transform() * battle.stage.get_global_transform_with_canvas() * center
			await h.click(physical)
			await h.frames(4)
			break
	h.check("Enemy focus click records target while paused", focus_target != null and battle.sim.focus == focus_target)
	h.record("focus_commands", {"case": label, "commands": battle.sim.commands.duplicate(true),
		"pauseTick": paused_tick, "focusTarget": focus_target,
		"methods": "pause/stance/enemy by Godot Input; priority via same OptionButton selected-item callback"})
	await h.shot("focus_" + label + "_orders_paused")
	await _click_control(h, battle._pause_btn)
	await h.wait(0.2)
	h.check("Resume button advances combat tick", not battle.paused and int(battle.sim.tick) > paused_tick)


func _paused_entry(h) -> void:
	Settings.set_value("reduceMotion", true)
	Settings.set_value("pauseAtEncounterStart", true)
	await _load(h, _fixture("gull_rock", "landing"))
	var entered: bool = await h.act(Actions.enter_room(Game.state, "landing"))
	if not entered or h.main.battle_view == null:
		h.check("Reduced paused entry exists", false)
		return
	var battle = h.main.battle_view
	var start := Time.get_ticks_usec()
	for mark in [0.0, 0.35, 2.0, 4.0]:
		await _until(h, start, float(mark))
		await _capture_battle(h, battle, "reduced_paused", "t" + str(mark).replace(".", "_"))
	await _fit_ui(h)
	await _capture_battle(h, battle, "reduced_paused", "after_hud_fit")
	await _click_control(h, battle._pause_btn)
	await h.wait(2.0)
	await _capture_battle(h, battle, "reduced_paused", "resumed_2s")
	await _click_control(h, battle._pause_btn)
	await _capture_battle(h, battle, "reduced_paused", "paused_again")


func _outdoor_nights_and_weather(h) -> void:
	# View selection persists across fixtures. Explicitly expose level zero
	# on every case so a night/sky screenshot cannot silently be sheltered.
	Settings.set_value("reduceMotion", false)
	Settings.set_value("weather", true)
	for region in C.REGIONS:
		await _outdoor_case(h, String(region.locs[0]), "clear", 23,
			"night_outdoor_" + String(region.id))
	for pair in [["brightquay", "cloudy"], ["brightquay", "rain"], ["gale_harbor", "storm"],
		["lanternport", "fog"], ["cinderport", "ash"]]:
		await _outdoor_case(h, String(pair[0]), String(pair[1]), 8,
			"weather_outdoor_" + String(pair[0]) + "_" + String(pair[1]))


func _outdoor_case(h, loc_id: String, sky: String, clock: int, label: String) -> void:
	Weather.forced = sky
	var state := _fixture(loc_id)
	state.envelope.gameClock = clock
	await _load(h, state)
	h.main._on_view_action("level:0")
	h.main._sky_stage = ""
	h.main._update_weather()
	await h.wait(0.2)
	var ship = h.main.ship_view
	var weather = h.main.weather
	var exposed: bool = Game.where() == "port" and ship.visible and ship.view_level == 0 and not weather.under
	h.check("Outdoor capture preconditions " + label, exposed)
	var timing: Dictionary = await _stable_outdoor_sample(h, label, 0.65)
	var info := {"name": label, "fixture": true, "locationId": loc_id, "sky": sky, "gameClock": clock,
		"where": Game.where(), "shipVisible": ship.visible, "viewLevel": ship.view_level,
		"weatherUnder": weather.under, "exposedPrecondition": exposed,
		"weatherIntensity": weather._k.duplicate(), "worldTint": str(ship.canvas_mod.color),
		"windowSize": str(DisplayServer.window_get_size()), "frameSample": timing,
		"correction": "Explicit exposed level0; earlier catalogue night/weather frames may have inherited sheltered view1"}
	cases.append(info)
	h.record("focus_outdoor_capture", info)
	await h.shot("focus_" + label)


func _stable_outdoor_sample(h, label: String, seconds: float) -> Dictionary:
	var values: Array[float] = []
	var calls := 0.0
	var previous := Time.get_ticks_usec()
	var until := previous + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < until:
		await h.get_tree().process_frame
		var now := Time.get_ticks_usec()
		values.append(float(now - previous) / 1000.0)
		previous = now
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	if values.is_empty():
		return {"name": label, "frames": 0, "screenshotsExcluded": true}
	values.sort()
	var sum := 0.0
	for value in values:
		sum += value
	return {"name": label, "requestedSeconds": seconds, "frames": values.size(),
		"meanFps": 1000.0 * float(values.size()) / sum,
		"p95FrameMs": values[mini(values.size() - 1, int(values.size() * 0.95))],
		"maxFrameMs": values[-1], "meanDrawCalls": calls / float(values.size()),
		"screenshotsExcluded": true,
		"scope": "VSync-inclusive process-frame wall intervals; no GPU execution-time or loading-hitch claim"}


func _shelter_precondition(h) -> void:
	# Correct the catalogue's invalid assumption that a newly loaded hull
	# resets its persistent view level to the exposed deck. Establish and
	# record that precondition BEFORE forging a visible lightning strike.
	Settings.set_value("reduceMotion", false)
	Settings.set_value("weather", true)
	Weather.forced = "storm"
	var state: Dictionary = GS.create_new_game(7)
	await _load(h, state)
	h.main._on_view_action("level:0")
	h.main._sky_stage = ""
	h.main._update_weather()
	await h.wait(0.2)
	var weather = h.main.weather
	h.check("Shelter retest starts on exposed deck", h.main.ship_view.view_level == 0 and not weather.under)
	h.check("Shelter retest starts with storm rain", float(weather._k.rain) > 0.5)
	var services := {}
	for entry in h.main.ship_view._buildings:
		if String(entry.kind) != "":
			services[String(entry.kind)] = true
	h.check("Port has six distinct named services", services.size() == 6)
	h.record("catalogue_assertion_correction", {"catalogueRawInteractiveEntries": h.main.ship_view._buildings.size(),
		"namedServiceKinds": services.keys(), "explanation": "Seventh interactive entry is the boarding plank with empty kind, not a seventh service building"})
	weather._strike(0.8)
	await h.frames(2)
	h.check("Shelter retest strike is actually visible outdoors", weather._flash.visible)
	await h.shot("focus_shelter_before_visible_flash")
	await h.key(KEY_PAGEDOWN)
	h.check("PageDown enters shelter", h.main.ship_view.view_level == 1 and weather.under)
	h.check("PageDown immediately clears active lightning", not weather._flash.visible)
	h.check("PageDown removes storm rain", float(weather._k.rain) == 0.0)
	h.record("shelter_targeted_retest", {"precondition": "Exposed level0, underfalse, stormrain and flash proven visible",
		"afterPageDown": {"level": h.main.ship_view.view_level, "under": weather.under,
			"flashVisible": weather._flash.visible, "rain": weather._k.rain}})
	await h.shot("focus_shelter_after_pagedown")
	await h.key(KEY_PAGEUP)
	h.check("PageUp restores exposed deck storm", h.main.ship_view.view_level == 0 and not weather.under and float(weather._k.rain) > 0.5)
	await h.shot("focus_shelter_restored_outdoors")
	Settings.set_value("weather", false)
	h.main._update_weather()


func _until(h, start: int, seconds: float) -> void:
	var left := seconds - float(Time.get_ticks_usec() - start) / 1000000.0
	if left > 0.0:
		await h.wait(left)


func _capture_battle(h, battle, label: String, mark: String) -> void:
	var vp: Vector2 = battle.get_viewport_rect().size
	var pixel_bounds := Rect2(Vector2.ZERO, Vector2(DisplayServer.window_get_size()))
	var top := maxf(25.0, float(battle._hud_top) + 3.0) + 20.0 + (21.0 if battle._boss_uid != null else 0.0)
	var bottom := maxf(32.0, float(battle._hud_bottom) + 4.0)
	var safe := Rect2(Vector2(4, top), Vector2(vp.x - 8.0, vp.y - top - bottom))
	var pause_rect: Rect2 = battle._paused_panel.get_global_rect()
	var all_feet := true
	var all_safe := true
	var paused_overlaps := []
	var actors := []
	for uid in battle._actors:
		var actor: Actor = battle._actors[uid]
		var unit = battle._units.get(uid)
		if unit == null or not unit.alive:
			continue
		var canvas: Vector2 = actor.get_global_transform_with_canvas() * Vector2(0, -actor.lift)
		var pixels: Vector2 = actor.get_viewport().get_screen_transform() * canvas
		var inside := pixel_bounds.grow(1.0).has_point(pixels)
		var safe_foot := safe.grow(1.0).has_point(canvas)
		all_feet = all_feet and inside
		all_safe = all_safe and safe_foot
		var sprite: Rect2 = battle.stage.get_global_transform_with_canvas() * actor.pick_rect()
		var covered := bool(battle._paused_panel.visible) and pause_rect.intersects(sprite)
		if covered:
			paused_overlaps.append(uid)
		actors.append({"uid": uid, "side": unit.side, "world": str(actor.position), "canvas": str(canvas),
			"pixels": str(pixels), "homeDistance": actor.position.distance_to(battle._home.get(uid, actor.position)),
			"footInsideNativeWindow": inside, "footInsideHudFreeArea": safe_foot,
			"pausedNoticeOverSprite": covered, "animation": actor.anim})
	var info := {"case": label, "mark": mark, "tick": battle.sim.tick,
		"simSeconds": float(battle.sim.tick) * Combat.dt(), "outcome": battle.sim.outcome,
		"paused": battle.paused, "cinematicHold": battle._cine_hold, "speedIndex": battle.speed_i,
		"viewport": str(vp), "camera": str(battle.cam.position), "zoom": str(battle.cam.zoom),
		"hudFreeRect": str(safe), "allLivingFeetInsideNativeWindow": all_feet,
		"allLivingFeetInsideHudFreeArea": all_safe, "pauseNoticeRect": str(pause_rect),
		"pauseNoticeVisible": battle._paused_panel.visible, "pauseNoticeOverActors": paused_overlaps, "actors": actors}
	cases.append(info)
	h.record("focus_frame_geometry", info)
	await h.shot("focus_" + label + "_" + mark)
