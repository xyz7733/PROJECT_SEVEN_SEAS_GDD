extends RefCounted
## Fullscreen R4 follow-up. Location/prerequisite placement, stamina and
## injury resets are explicit fixtures. Battles then use the normal
## encounter actions, simulation, speed and pause controls without forged
## events, HP edits, infinite health, or selected outcomes.

var cases: Array = []
var _earned: Dictionary = {}


func run(h) -> void:
	var saved: Dictionary = SaveStore.read(SaveStore.manual_path(0))
	if saved.get("status", "") == "ok" and bool(saved.record.state.captain.postgame):
		_earned = saved.record.state.duplicate(true)
	h.record("r4_scope", {"fixture": true, "earnedCheckpointAvailable": not _earned.is_empty(),
		"method": "Actual fullscreen window, engine input, natural deterministic x4 fights after explicit fixture placement",
		"fixtureChanges": "Direct location/prerequisite placement, full stamina and cleared injury flags; crew levels/equipment/formation preserved",
		"source": "Copied earned postgame manual save for dense Legend, otherwise seed7 starter crew at Old Lookout",
		"organicCampaignCompletion": false, "forgedCombatEvents": false})
	Settings.set_value("guide", false)
	Settings.set_value("textScale", 1.0)
	Settings.set_value("battleSpeed", 4)
	Weather.forced = "clear"
	var original_locale := I18n.locale()
	for locale in ["en", "zh_CN"]:
		I18n.set_locale(locale)
		Settings.set_value("locale", locale)
		await _paused(h, locale)
		await _dense(h, locale)
	I18n.set_locale(original_locale)
	Settings.set_value("locale", original_locale)
	Settings.set_value("reduceMotion", false)
	Settings.set_value("pauseAtEncounterStart", false)
	Weather.forced = ""
	var file := FileAccess.open(h.out_dir.path_join("r4-regression.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"scope": "R4 fixture visual/geometry follow-up", "cases": cases}, "\t"))
	h.record("r4_complete", {"cases": cases.size()})


func _fixture(state: Dictionary, loc_id: String, room_id: String) -> Dictionary:
	var d := state.duplicate(true)
	var loc: Dictionary = C.location(loc_id)
	d.encounter = null
	d.world.currentLocationId = loc_id
	d.captain.regionId = loc.regionId
	d.world.locations[loc_id].k = "visited"
	d.codex.locations[loc_id] = true
	d.ship.stamina = Rules.stamina_max(d)
	for member in d.crew:
		member.injured = false
	d.voyage = {"id": "r4-fixture", "originPortId": "brightquay", "at": loc_id,
		"route": null, "event": null, "site": {"locationId": loc_id, "current": null}}
	for room in C.rooms(loc_id):
		if room.id != room_id and not d.world.locations[loc_id].rooms.has(room.id):
			d.world.locations[loc_id].rooms.append(room.id)
	return d


func _load(h, state: Dictionary) -> void:
	h.main.mode = "fixture_loading"
	await h.load_state(state)
	await h.wait(0.35)


func _click(h, control: Control) -> void:
	var physical: Vector2 = control.get_viewport().get_screen_transform() * control.get_global_transform_with_canvas() * (control.size * 0.5)
	await h.click(physical)
	await h.frames(4)


func _paused(h, locale: String) -> void:
	Settings.set_value("reduceMotion", true)
	Settings.set_value("pauseAtEncounterStart", true)
	await _load(h, _fixture(GS.create_new_game(7), "gull_rock", "landing"))
	var entered: bool = await h.act(Actions.enter_room(Game.state, "landing"))
	h.check("R4 paused fixture starts " + locale, entered and h.main.battle_view != null)
	if not entered or h.main.battle_view == null:
		return
	var view = h.main.battle_view
	await h.wait(1.5) # Entry movement has completed although simulation is paused.
	var tick := int(view.sim.tick)
	var vp := Rect2(Vector2.ZERO, view.get_viewport_rect().size)
	var bar: Rect2 = view._bar.get_global_rect()
	var pause: Rect2 = view._paused_panel.get_global_rect()
	var overlaps := []
	for uid in view._actors:
		var actor: Actor = view._actors[uid]
		if pause.intersects(_sprite_rect(actor)):
			overlaps.append(uid)
	h.check("R4 paused control bar stays in viewport " + locale, vp.grow(1.0).encloses(bar))
	h.check("R4 pause notice is docked in controls " + locale, view._paused_panel.is_visible_in_tree() and bar.grow(1.0).encloses(pause))
	h.check("R4 pause notice leaves every actor clear " + locale, overlaps.is_empty())
	await h.wait(0.2)
	h.check("R4 pause still holds simulation " + locale, view.paused and tick == int(view.sim.tick))
	var info := {"case": "pause:" + locale, "fixture": true, "viewport": str(vp), "bar": str(bar),
		"pauseNotice": str(pause), "coveredActors": overlaps, "tick": tick}
	cases.append(info)
	h.record("r4_paused_geometry", info)
	await h.shot("r4_" + locale + "_paused_docked")
	await _click(h, view._pause_btn)
	await h.wait(0.25)
	h.check("R4 Resume advances normal combat " + locale, not view.paused and int(view.sim.tick) > tick)


func _dense(h, locale: String) -> void:
	Settings.set_value("reduceMotion", false)
	Settings.set_value("pauseAtEncounterStart", true)
	var legendary := not _earned.is_empty()
	var base: Dictionary = _earned if legendary else GS.create_new_game(7)
	var loc_id := "horizon_arena" if legendary else "old_lookout"
	var room_id := "trial" if legendary else "guardian"
	await _load(h, _fixture(base, loc_id, room_id))
	var entered: bool = await h.act(Actions.start_legend(Game.state) if legendary else Actions.enter_room(Game.state, room_id))
	h.check("R4 dense natural encounter starts " + locale, entered and h.main.battle_view != null)
	if not entered or h.main.battle_view == null:
		return
	var view = h.main.battle_view
	view.set_speed(2) # Normal x4 speed callback, no simulation edits.
	await h.wait(0.35)
	var intro := bool(view._cine_hold)
	if intro:
		h.check("R4 boss intro suppresses paused notice " + locale, not view._paused_panel.is_visible_in_tree())
		h.check("R4 boss intro suppresses floating text " + locale, not view._float_root.is_visible_in_tree())
		await h.shot("r4_" + locale + "_boss_intro_clean")
	var began := Time.get_ticks_usec()
	while is_instance_valid(view) and view._cine_hold and Time.get_ticks_usec() - began < 6000000:
		await h.wait(0.1)
	if not is_instance_valid(view):
		h.check("R4 dense view survives intro " + locale, false)
		return
	await h.wait(0.3)
	h.check("R4 natural boss intro completes " + locale, not view._cine_hold)
	await h.shot("r4_" + locale + "_boss_paused_after_intro")
	await _click(h, view._pause_btn)
	var stats := {"case": "dense:" + locale, "fixture": true, "location": loc_id,
		"legend": legendary, "copiedEarnedCrew": legendary, "bossIntroObserved": intro,
		"samples": 0, "maxVisibleLabels": 0, "maxStoredLabels": 0, "maxBossBarWidth": 0.0,
		"duplicateChannels": [], "outOfWindow": [], "actorOverlaps": [], "labelOverlaps": [],
		"hudOverlaps": [], "bannerOverlaps": [], "encoreObserved": false, "simulationTicks": 0}
	var start_tick := int(view.sim.tick)
	began = Time.get_ticks_usec()
	var shots := 0
	var last_shot := -10.0
	while is_instance_valid(view) and not view.report_mode and Time.get_ticks_usec() - began < 18000000:
		await RenderingServer.frame_post_draw
		if not is_instance_valid(view) or view.report_mode:
			break
		var elapsed := float(Time.get_ticks_usec() - began) / 1000000.0
		if not view._cine_hold:
			_observe(view, stats)
		if bool(view.sim.get("encored", false)) and not bool(stats.encoreObserved):
			stats.encoreObserved = true
			await h.shot("r4_" + locale + "_normal_encore")
		if int(stats.maxVisibleLabels) >= 3 and shots < 3 and elapsed - last_shot > 2.0:
			last_shot = elapsed
			shots += 1
			await h.shot("r4_" + locale + "_dense_x4_" + str(shots))
		stats.simulationTicks = int(view.sim.tick) - start_tick
		if view._ended:
			break
	h.check("R4 samples include real x4 progression " + locale, int(stats.simulationTicks) > 0 and int(stats.samples) > 0)
	h.check("R4 dense observation actually renders simultaneous labels " + locale, int(stats.maxVisibleLabels) >= 3)
	h.check("R4 visible popups remain inside window " + locale, stats.outOfWindow.is_empty())
	h.check("R4 visible popups leave actor sprites and HP clear " + locale, stats.actorOverlaps.is_empty())
	h.check("R4 visible popup labels do not overlap " + locale, stats.labelOverlaps.is_empty())
	h.check("R4 visible popups leave HUD clear " + locale, stats.hudOverlaps.is_empty())
	h.check("R4 global notices leave actors and boss bar clear " + locale, stats.bannerOverlaps.is_empty())
	h.check("R4 one popup per unit/channel " + locale, stats.duplicateChannels.is_empty())
	h.check("R4 sampled popup density is bounded " + locale, int(stats.maxStoredLabels) <= 12)
	cases.append(stats)
	h.record("r4_dense_geometry", stats)
	if is_instance_valid(view) and not view.report_mode:
		await h.shot("r4_" + locale + "_dense_observation_end")


func _sprite_rect(actor: Actor) -> Rect2:
	return actor.rig.get_global_transform_with_canvas() * Rect2(-actor._origin, actor._frame_size)


func _remember(array: Array, item: Dictionary) -> void:
	if array.size() < 8:
		array.append(item)


func _observe(view, stats: Dictionary) -> void:
	stats.samples = int(stats.samples) + 1
	stats.maxStoredLabels = maxi(int(stats.maxStoredLabels), view._popups.size())
	var vp := Rect2(Vector2.ZERO, view.get_viewport_rect().size)
	var bodies: Array[Rect2] = []
	for actor in view._actors.values() + view._pets.values():
		if not is_instance_valid(actor) or not actor.is_visible_in_tree() or actor.modulate.a < 0.2:
			continue
		bodies.append(_sprite_rect(actor))
		if actor._hp_root != null and actor._hp_root.is_visible_in_tree():
			bodies.append(actor._hp_root.get_global_transform_with_canvas() * Rect2(Vector2(-actor._hp_w * 0.5 - 1.0, 0), Vector2(actor._hp_w + 2.0, 4)))
	var hud: Array[Rect2] = []
	for control in [view._strip_panel, view._status_panel, view._boss_bar, view._bar, view._log_panel]:
		if control.is_visible_in_tree() and control.modulate.a > 0.2:
			hud.append(control.get_global_rect())
	if view._boss_bar.is_visible_in_tree():
		stats.maxBossBarWidth = maxf(float(stats.maxBossBarWidth), view._boss_bar.size.x)
	var seen := {}
	var labels: Array[Rect2] = []
	for popup in view._popups:
		var label: Label = popup.label
		var key := str(popup.uid) + ":" + String(popup.channel)
		if seen.has(key):
			_remember(stats.duplicateChannels, {"tick": view.sim.tick, "key": key})
		seen[key] = true
		if not label.is_visible_in_tree() or label.modulate.a < 0.2:
			continue
		var rect := label.get_global_rect()
		var detail := {"tick": view.sim.tick, "key": key, "rect": str(rect), "text": label.text}
		if not vp.grow(1.0).encloses(rect):
			_remember(stats.outOfWindow, detail)
		for body in bodies:
			if rect.intersects(body):
				_remember(stats.actorOverlaps, detail)
		for other in labels:
			if rect.intersects(other):
				_remember(stats.labelOverlaps, detail)
		for block in hud:
			if rect.intersects(block):
				_remember(stats.hudOverlaps, detail)
		labels.append(rect)
	stats.maxVisibleLabels = maxi(int(stats.maxVisibleLabels), labels.size())
	if view._banner.is_visible_in_tree() and view._banner.modulate.a > 0.2:
		var rect: Rect2 = view._banner.get_global_rect()
		for body in bodies:
			if rect.intersects(body):
				_remember(stats.bannerOverlaps, {"tick": view.sim.tick, "actor": str(body), "notice": str(rect)})
		if view._boss_bar.is_visible_in_tree() and rect.intersects(view._boss_bar.get_global_rect()):
			_remember(stats.bannerOverlaps, {"tick": view.sim.tick, "bossBar": str(view._boss_bar.get_global_rect()), "notice": str(rect)})
