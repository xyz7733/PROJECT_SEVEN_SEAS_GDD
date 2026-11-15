extends RefCounted
## Supplemental presentation fixtures for the exact shipped resource pack.
## These fixtures do NOT establish organic discovery, economic balance, a
## completed campaign, OS mouse hit testing, or speaker listening quality.
## The caller owns the one native fullscreen window and isolated user profile.

var places: Array = []
var battles: Array = []
var hull_levels: Array = []
var samples: Array = []
var fixture_interventions := {
	"discovery": "all places visited, all regions unlocked, trial prerequisites supplied",
	"crew": "starter equipment; fixture crew levels set relative to location",
	"battle_access": "preceding rooms marked cleared, target entered through Actions.enter_room",
	"travel": "direct isolated fixture placement, not voyage/cost validation",
	"hulls": "Actions.rebuild_decks; furnished test layouts and assigned workers",
	"weather_time": "explicit Weather.forced and fixture game clock",
}


func run(h) -> void:
	h.record("catalogue_scope", {"kind": "supplemental_fixtures", "interventions": fixture_interventions,
		"ui_matrix": "separate controls scenario", "organic_progression": false})
	Settings.set_value("guide", false)
	Settings.set_value("textScale", 1.0)
	Settings.set_value("reduceMotion", true)
	Settings.set_value("pauseAtEncounterStart", true)
	Settings.set_value("weather", true)
	Weather.forced = "clear"
	await _places(h)
	await _battle_contexts(h)
	await _hulls(h)
	await _regional_nights(h)
	await _weather_and_motion(h)
	Weather.forced = ""
	Settings.set_value("pauseAtEncounterStart", false)
	Settings.set_value("reduceMotion", false)
	Engine.time_scale = 1.0
	h.check("All 100 location fixture views built", places.size() == 100)
	h.check("All 190 combat room contexts built", battles.size() == 190)
	var all_hulls := {}
	for entry in hull_levels:
		all_hulls[entry.hull] = true
	h.check("All four hulls sampled", all_hulls.size() == 4)
	var report := {"scope": "Native fullscreen shipped-PCK presentation fixtures; no organic completion or OS mouse claim",
		"interventions": fixture_interventions, "locations": places, "battleContexts": battles,
		"hullLevels": hull_levels, "stableFrameSamples": samples,
		"timing": "Process-frame wall intervals include VSync/presentation; screenshots excluded from sample periods"}
	var file := FileAccess.open(h.out_dir.path_join("catalogue-coverage.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	else:
		h.check("Catalogue coverage file written", false)
	h.record("catalogue_complete", {"locations": places.size(), "battleContexts": battles.size(),
		"hullLevels": hull_levels.size(), "stableFrameSamples": samples.size()})


func _fixture(loc_id: String, hull_id := "starter") -> Dictionary:
	var s: Dictionary = GS.create_new_game(20261114)
	var loc: Dictionary = C.location(loc_id)
	for region in C.REGIONS:
		var rid := String(region.id)
		if not s.captain.regionsUnlocked.has(rid):
			s.captain.regionsUnlocked.append(rid)
		s.captain.mainStep[rid] = 4
	for id in s.world.locations:
		s.world.locations[id].k = "visited"
		s.codex.locations[id] = true
	s.captain.regionId = loc.regionId
	s.world.currentLocationId = loc_id
	s.world.lastSafePortId = String(C.region(loc.regionId).locs[0])
	s.inventory.gold = 999999
	s.inventory.food = 30
	s.inventory.supplies = 15
	s.inventory.materials = 999999
	s.ship.stamina = 100
	if hull_id != "starter":
		Actions.rebuild_decks(s, C.hull(hull_id))
	for m in s.crew:
		m.level = mini(65, maxi(1, int(loc.level) + 5))
		m.injured = false
	if String(loc.type) != "port":
		s.voyage = {"id": "visual-fixture", "originPortId": s.world.lastSafePortId,
			"at": loc_id, "route": null, "event": null, "site": {"locationId": loc_id, "current": null}}
	return s


func _load(h, s: Dictionary) -> void:
	# Suppress the intermediate state-change view build. enter_game() restores
	# its normal mode and builds precisely the supplied fixture once.
	h.main.mode = "fixture_loading"
	await h.load_state(s)
	await h.wait(0.34)


func _places(h) -> void:
	for region in C.REGIONS:
		var rid := String(region.id)
		for id in region.locs:
			var loc_id := String(id)
			var loc: Dictionary = C.location(loc_id)
			var s := _fixture(loc_id)
			await _load(h, s)
			var correct := Game.where() == ("port" if loc.type == "port" else "site")
			h.check("Fixture stage " + loc_id, correct)
			var info := {"locationId": loc_id, "regionId": rid, "type": String(loc.type),
				"fixture": true, "stage": Game.where(), "defaultScreenshot": "place_" + loc_id + "_default"}
			await h.shot(String(info.defaultScreenshot))
			if loc.type == "port":
				var ship = h.main.ship_view
				if ship != null:
					var service_kinds := {}
					for entry in ship._buildings:
						if String(entry.kind) != "":
							service_kinds[String(entry.kind)] = true
					info["serviceBuildings"] = service_kinds.size()
					info["rawInteractiveEntries"] = ship._buildings.size()
					info["serviceKinds"] = service_kinds.keys()
					info["landmark"] = ship._port.has("landmark")
					h.check("Port exposes six service buildings " + loc_id, service_kinds.size() == 6)
					await _fit_input(h, loc_id)
					await h.shot("place_" + loc_id + "_ship_fit")
			else:
				var site = h.main.site_view
				if site != null:
					info["rooms"] = site._room_vis.size()
					info["landmarkBuilt"] = site.stage.get_node_or_null("LocationLandmark") != null
					h.check("Site landmark built " + loc_id, bool(info.landmarkBuilt))
					h.check("Site room count " + loc_id, site._room_vis.size() == C.rooms(loc_id).size())
					await _fit_input(h, loc_id)
					var visible: Rect2 = _camera_rect(site.cam, site.get_viewport_rect().size)
					var safe: Rect2 = h.main._free_screen().grow(-4.0)
					var safe_end := safe.end.y
					safe.position.y = maxf(safe.position.y, site._info_panel.get_global_rect().end.y + 4.0)
					safe.size.y = safe_end - safe.position.y
					var room_fit := true
					var room_safe := true
					for point in site._nodes.values():
						room_fit = room_fit and visible.grow(1.0).has_point(point)
						room_safe = room_safe and safe.grow(1.0).has_point(site.get_global_transform_with_canvas() * point)
					var landmark: Sprite2D = site.stage.get_node_or_null("LocationLandmark")
					var full_landmark: Rect2 = landmark.get_global_transform_with_canvas() * landmark.get_rect()
					info["allRoomNodesInFitSafeArea"] = room_safe
					info["fullLandmarkInsideFitSafeArea"] = safe.grow(1.0).encloses(full_landmark)
					h.check("Fit keeps room/landing nodes clear of HUD " + loc_id, room_safe)
					h.check("Fit keeps complete landmark clear of HUD " + loc_id, bool(info.fullLandmarkInsideFitSafeArea))
					info["allRoomNodesInFitViewport"] = room_fit
					info["fitCameraZoom"] = str(site.cam.zoom)
					info["fitCameraPosition"] = str(site.cam.position)
					await h.shot("place_" + loc_id + "_fit")
			places.append(info)
			h.record("location_fixture", info)
		# Timings from a steady regional port, away from capture and construction.
		await _load(h, _fixture(String(region.locs[0])))
		await _sample(h, "port_" + rid + "_steady", 0.55)


func _battle_contexts(h) -> void:
	var sampled_live := {}
	var sampled_intro := {}
	for region in C.REGIONS:
		var rid := String(region.id)
		for id in region.locs:
			var loc_id := String(id)
			for room in C.rooms(loc_id):
				if String(room.kind) not in ["battle", "elite", "boss", "trial"]:
					continue
				var room_id := String(room.id)
				var key := loc_id + ":" + room_id
				var s := _fixture(loc_id)
				for prior in C.rooms(loc_id):
					if prior.id != room_id:
						s.world.locations[loc_id].rooms.append(prior.id)
				await _load(h, s)
				var result: Dictionary = Actions.enter_room(Game.state, room_id)
				var entered: bool = await h.act(result)
				h.check("Battle fixture enters " + key, entered and Game.where() == "battle")
				if not entered or h.main.battle_view == null:
					h.record("battle_fixture_failed", {"key": key, "reasonKey": result.get("reasonKey", "unknown")})
					continue
				var battle = h.main.battle_view
				if battle._cine_hold and not sampled_intro.has(rid):
					sampled_intro[rid] = true
					await h.wait(0.65)
					await h.shot("boss_intro_" + key.replace(":", "_"))
				battle._end_cine()
				await h.wait(0.34)
				var info := {"locationId": loc_id, "roomId": room_id, "regionId": rid,
					"tier": String(room.kind), "fixture": true, "entry": "Actions.enter_room after fixture prerequisite rooms",
					"pausedForCatalogue": bool(battle.paused), "actors": battle._actors.size(),
					"landmarkBuilt": battle.stage.get_node_or_null("BattleLandmark") != null,
					"cameraZoom": str(battle.cam.zoom), "cameraPosition": str(battle.cam.position)}
				h.check("Battle actors built " + key, battle._actors.size() >= 2)
				h.check("Battle landmark built " + key, bool(info.landmarkBuilt))
				var visible := _camera_rect(battle.cam, battle.get_viewport_rect().size)
				var all_feet_visible := true
				for actor in battle._actors.values():
					all_feet_visible = all_feet_visible and visible.grow(1.0).has_point(actor.position)
				info["allActorFeetInViewport"] = all_feet_visible
				await h.shot("battle_" + loc_id + "_" + room_id)
				if not sampled_live.has(rid) and String(room.kind) == "battle":
					sampled_live[rid] = true
					battle.paused = false
					battle.set_speed(0)
					await _sample(h, "fight_" + rid + "_x1", 0.7)
					await h.shot("battle_live_" + loc_id + "_" + room_id)
					battle.set_speed(2)
					await _sample(h, "fight_" + rid + "_x4", 0.7)
					await h.shot("battle_x4_" + loc_id + "_" + room_id)
					if is_instance_valid(battle):
						battle.paused = true
					info["liveSampleSeconds"] = 1.4
				battles.append(info)
				h.record("battle_fixture", info)


func _hulls(h) -> void:
	for hull in C.HULLS:
		var hull_id := String(hull.id)
		var s := _fixture("brightquay", hull_id)
		_furnish(s)
		await _load(h, s)
		var ship = h.main.ship_view
		if ship == null:
			h.check("Hull view built " + hull_id, false)
			continue
		var level_count: int = ship.level_count()
		for level in level_count:
			ship.set_view_level(level)
			ship.fit_view()
			await h.wait(0.32)
			var visible_actors := 0
			for actor in ship._actors.values():
				if actor.visible:
					visible_actors += 1
			var info := {"hull": hull_id, "level": level, "title": ship.level_title(level),
				"decksShown": ship.visible_decks(), "visibleActors": visible_actors,
				"facilities": Game.state.ship.facilities.size(), "fixture": true}
			hull_levels.append(info)
			h.record("hull_level_fixture", info)
			await h.shot("hull_" + hull_id + "_level_" + str(level))
		if level_count > 1:
			ship.set_view_level(1)
			ship.fit_view()
			await _sample(h, "hull_" + hull_id + "_crew_motion", 1.2)
			await h.shot("hull_" + hull_id + "_crew_later")
		# Each regional port is also built around the largest hull, checking
		# the authored quay/skyline adaptation rather than only the starter.
	for region in C.REGIONS:
		for port_id in [region.locs[0], region.locs[1]]:
			await _load(h, _fixture(String(port_id), "legend"))
			h.main.ship_view.fit_view()
			await h.frames(3)
			await h.shot("large_hull_port_" + String(port_id))
			h.record("large_hull_port_fixture", {"locationId": port_id, "hull": "legend"})


func _furnish(s: Dictionary) -> void:
	# Test fixture only: seat eligible facilities using real placement rules.
	# This is not a purchased or economically achievable layout claim.
	for fac_id in C.FACILITIES:
		if int(C.FACILITIES[fac_id].minTier) > int(s.ship.hullTier):
			continue
		var exists := false
		for facility in s.ship.facilities:
			if facility.id == fac_id:
				exists = true
		if exists:
			continue
		var spot = Rules.find_spot(s.ship, String(fac_id))
		if spot == null:
			continue
		s.ship.facilities.append({"uid": GS.next_id(s, "fac"), "id": fac_id, "deck": spot.deck,
			"x": spot.x, "y": spot.y, "rot": spot.rot, "level": 1, "damaged": false, "stowed": false})
	var count := mini(16, Rules.crew_capacity(s))
	var classes: Array = C.CLASSES.keys()
	while s.crew.size() < count:
		var m := GS.make_recruit(1400 + s.crew.size(), {"classId": classes[s.crew.size() % classes.size()], "level": 20})
		m.id = GS.next_id(s, "crew")
		s.crew.append(m)
	for i in s.crew.size():
		if not s.ship.facilities.is_empty():
			s.crew[i].jobFacilityUid = s.ship.facilities[i % s.ship.facilities.size()].uid


func _regional_nights(h) -> void:
	for region in C.REGIONS:
		var s := _fixture(String(region.locs[0]))
		s.envelope.gameClock = 23
		await _load(h, s)
		h.main._on_view_action("level:0")
		h.main._sky_stage = ""
		h.main._update_weather()
		await h.frames(3)
		await h.shot("night_port_" + String(region.id))
		await _sample(h, "night_port_" + String(region.id), 0.5)


func _weather_and_motion(h) -> void:
	Settings.set_value("reduceMotion", false)
	for pair in [["brightquay", "cloudy"], ["brightquay", "rain"], ["gale_harbor", "storm"],
		["lanternport", "fog"], ["cinderport", "ash"]]:
		var loc_id := String(pair[0])
		var sky := String(pair[1])
		Weather.forced = sky
		await _load(h, _fixture(loc_id))
		h.main._on_view_action("level:0")
		h.main._sky_stage = ""
		h.main._update_weather()
		await h.wait(0.45)
		await _sample(h, "weather_" + loc_id + "_" + sky, 0.8)
		await h.shot("weather_" + loc_id + "_" + sky)
	Weather.forced = "storm"
	await _load(h, _fixture("gale_harbor"))
	h.main._on_view_action("level:0")
	h.main._sky_stage = ""
	h.main._update_weather()
	await h.frames(3)
	h.main.weather._strike(0.8)
	await h.frames(2)
	await h.shot("storm_lightning_fullscreen")
	h.main.ship_view.set_view_level(1)
	h.main._update_weather()
	await h.wait(0.4)
	h.check("Storm removed below decks", h.main.weather.under and float(h.main.weather._k.rain) == 0.0)
	h.check("Shelter clears lightning", not h.main.weather._flash.visible)
	await h.shot("storm_sheltered_interior")
	h.main.ship_view.set_view_level(0)
	h.main._update_weather()
	await h.wait(0.4)
	h.check("Storm returns above decks", not h.main.weather.under and float(h.main.weather._k.rain) > 0.5)
	Settings.set_value("reduceMotion", true)
	h.main._update_weather()
	h.main.weather._bolt_t = 0.0
	h.main.weather._tick_lightning(0.0)
	await h.frames(2)
	h.check("Reduce motion suppresses lightning", not h.main.weather._flash.visible)
	await h.shot("storm_reduce_motion")
	Settings.set_value("weather", false)
	h.main._update_weather()
	await h.wait(2.6)
	h.check("Weather toggle removes rain", float(h.main.weather._k.rain) == 0.0)
	await h.shot("weather_disabled_fullscreen")
	Weather.forced = ""
	Settings.set_value("weather", true)
	Settings.set_value("reduceMotion", false)


func _fit_input(h, loc_id: String) -> void:
	var button: Control = h.main.hud._fit_btn
	var available := button.is_visible_in_tree()
	h.check("HUD Fit input available " + loc_id, available)
	if not available:
		return
	var point: Vector2 = button.get_viewport().get_screen_transform() * button.get_global_transform_with_canvas() * (button.size * 0.5)
	await h.click(point)
	await h.frames(4)


func _camera_rect(camera: Camera2D, viewport: Vector2) -> Rect2:
	return Rect2(camera.position - viewport / camera.zoom * 0.5, viewport / camera.zoom)


func _sample(h, label: String, seconds: float) -> void:
	var intervals: Array[float] = []
	var calls := 0.0
	var last := Time.get_ticks_usec()
	var until := last + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < until:
		await h.get_tree().process_frame
		var now := Time.get_ticks_usec()
		intervals.append(float(now - last) / 1000.0)
		last = now
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	if intervals.is_empty():
		return
	intervals.sort()
	var sum := 0.0
	for value in intervals:
		sum += value
	var entry := {"name": label, "seconds": seconds, "frames": intervals.size(),
		"meanFps": 1000.0 * float(intervals.size()) / sum,
		"p95FrameMs": intervals[mini(intervals.size() - 1, int(intervals.size() * 0.95))],
		"maxFrameMs": intervals[-1], "meanDrawCalls": calls / float(intervals.size()),
		"screenshotsExcluded": true, "scope": "VSync-inclusive process-frame wall intervals, not GPU timers"}
	samples.append(entry)
	h.record("stable_frame_sample", entry)
