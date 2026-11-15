extends RefCounted
## Rendered checks against the new PCK. Organic save compatibility and pet
## assignment are kept distinct from explicitly placed expedition fixtures.
const MAX_SECONDS := 90.0
const SITES := ["crystal_vault", "drowned_beacon"]
var _began := 0
var _earned: Dictionary = {}
var _results: Array = []
var _battles: Array = []
var _stop := ""
var _last_summary: Dictionary = {}


func run(h) -> void:
	_began = Time.get_ticks_usec()
	var read: Dictionary = SaveStore.read(SaveStore.manual_path(0))
	h.check("Old earned manual save verifies under new PCK", read.get("status", "") == "ok")
	if read.get("status", "") != "ok":
		_stop = "No valid copied old manual save"
		await _finish(h)
		return
	var old: Dictionary = read.record.state.duplicate(true)
	var old_tx := int(old.envelope.lastTxId)
	var old_hash := SaveStore.state_hash(old)
	h.check("Old saved content hash remains valid", old_hash == String(old.envelope.stateHash))
	await h.load_state(old)
	h.check("Old load preserves transaction", int(Game.state.envelope.lastTxId) == old_tx)
	h.check("Old load preserves trials and Legends", Game.state.captain.trialsWon == old.captain.trialsWon and Game.state.captain.legendsWon == old.captain.legendsWon)
	h.check("Old load preserves earned crew and equipment", var_to_bytes(Game.state.crew) == var_to_bytes(old.crew) and var_to_bytes(Game.state.inventory.equipment) == var_to_bytes(old.inventory.equipment))
	h.record("fixes_old_save_compatibility", {"status": read.status, "schema": read.record.schemaVersion,
		"tx": old_tx, "saved_hash": old.envelope.stateHash, "verified_hash": old_hash,
		"trials": old.captain.trialsWon, "legends": old.captain.legendsWon})
	Settings.set_value("battleSpeed", 4)
	Settings.set_value("pauseAtEncounterStart", false)
	var pet_id := ""
	for pet in Game.state.pets:
		if pet.familyId == "tidefin" and Rules.pet_roles(pet).has("companion"):
			pet_id = String(pet.id)
			break
	var owner_id := ""
	for member in Rules.active_crew(Game.state):
		if C.base_class_of(String(member.classId)) == "beastkeeper":
			owner_id = String(member.id)
			break
	if owner_id == "" and not Rules.active_crew(Game.state).is_empty():
		owner_id = String(Rules.active_crew(Game.state)[0].id)
	h.check("Old save owns a usable Tidefin and active owner", pet_id != "" and owner_id != "")
	if pet_id == "" or owner_id == "":
		_stop = "Required earned Tidefin/owner missing; no pet or crew fabricated"
		await _finish(h)
		return
	var assigned: bool = await _act(h, "normally_restore_owned_tidefin_companion", Actions.assign_pet(Game.state, pet_id, "companion", owner_id))
	h.check("Owned Tidefin companion assignment commits normally", assigned)
	_earned = Game.state.duplicate(true)
	h.record("fixes_method", {"normal_operation": "Load unchanged earned save and assign its owned Tidefin through Actions",
		"fixtures": "Placement, room progress, injury reset and full stamina only; levels, XP, mastery, equipment and HP are not edited",
		"pet_owner": owner_id, "pet": pet_id, "max_seconds": MAX_SECONDS,
		"ui": "Actual room dialogs and hover-tip builders, EN/ZH at textScale1.5",
		"save_slots": "Original slot0 preserved; fixture uses slot2; restored earned companion state uses slot1"})
	await h.shot("fixes_old_earned_save_with_companion")
	await _pet_battle(h, owner_id)
	for locale in ["en", "zh_CN"]:
		if not _within_budget():
			break
		await _locale(h, locale)
		for loc_id in SITES:
			for active in [false, true]:
				if not _within_budget():
					break
				await _site_ui(h, locale, loc_id, active)
	if _within_budget():
		await _west_and_saved_depths(h)
	if _within_budget():
		await _storm_actual(h)
	await _finish(h)


func _within_budget() -> bool:
	if float(Time.get_ticks_usec() - _began) / 1000000.0 < MAX_SECONDS:
		return true
	_stop = "Bounded90-second rendered regression budget reached"
	return false


func _act(h, label: String, result: Dictionary) -> bool:
	var before := int(Game.state.envelope.lastTxId)
	var ok: bool = await h.act(result)
	h.record("fixes_action", {"action": label, "ok": ok, "reason": result.get("reasonKey", ""),
		"tx_before": before, "tx_after": Game.state.envelope.lastTxId})
	return ok


func _crew_fingerprint(state: Dictionary) -> PackedByteArray:
	var crew: Array = state.crew.duplicate(true)
	for member in crew:
		member.erase("injured")
	return var_to_bytes(crew)


func _fixture(loc_id: String, active: bool) -> Dictionary:
	var state: Dictionary = _earned.duplicate(true)
	state.encounter = null
	for member in state.crew:
		member.injured = false
	state.ship.stamina = Rules.stamina_max(state)
	state.world.currentLocationId = loc_id
	state.world.locations[loc_id].k = "visited"
	var rooms: Array = ["trial"] if C.location(loc_id).type == "arena" else (["gate", "west"] if active else ["gate"])
	state.world.locations[loc_id].rooms = rooms
	state.voyage = {"id": "review_fixes_fixture", "originPortId": state.world.lastSafePortId, "at": loc_id,
		"route": null, "event": null, "site": {"locationId": loc_id, "current": "trial" if C.location(loc_id).type == "arena" else "gate"}}
	return state


func _load_fixture(h, loc_id: String, active: bool) -> void:
	var state := _fixture(loc_id, active)
	await h.load_state(state)
	h.check("Fixture preserves earned crew/gear " + loc_id, _crew_fingerprint(Game.state) == _crew_fingerprint(_earned) and var_to_bytes(Game.state.inventory.equipment) == var_to_bytes(_earned.inventory.equipment))
	h.record("fixes_explicit_fixture", {"location": loc_id, "west_cleared": active,
		"changed": ["location/voyage/site placement", "room-clear test fixture", "injury reset", "stamina refill"],
		"level_xp_mastery_equipment_hp_edits": false})


func _locale(h, locale: String) -> void:
	Settings.set_value("locale", locale)
	I18n.set_locale(locale)
	Settings.set_value("textScale", 1.5)
	h.main._close_all_windows()
	h.main.queue_free()
	await h.frames(3)
	h.main = load("res://scenes/main.tscn").instantiate()
	h.add_child(h.main)
	await h.frames(8)


func _decoys(definition: Dictionary) -> int:
	var count := 0
	for wave in definition.waves:
		for enemy in wave:
			if enemy.enemyId == "crystal_decoy":
				count += 1
	return count


func _site_ui(h, locale: String, loc_id: String, active: bool) -> void:
	await _load_fixture(h, loc_id, active)
	await h.frames(4)
	var prep: Dictionary = World.preparation(Game.state, loc_id)
	var expected_mods: Array = ["glare", "decoys"] if loc_id == "crystal_vault" else ["storm"]
	var definition := World.encounter_for_state(Game.state, loc_id, "depths")
	var legacy := World.encounter_for(loc_id, "depths")
	for modifier in expected_mods:
		h.check("Local modifier " + locale + ":" + loc_id + ":" + str(active) + ":" + modifier, definition.modifiers.has(modifier) == (not active))
	if loc_id == "crystal_vault":
		h.check("Actual decoy entries follow preparation " + str(active), (_decoys(definition) == 0) if active else (_decoys(definition) > 0))
	else:
		h.check("Beacon preserves enemy/intent definitions", var_to_bytes(definition.waves) == var_to_bytes(legacy.waves))
	var cases: Array = []
	for room_id in ["west", "depths"]:
		var status := "active" if active else ("branch" if room_id == "west" else "inactive")
		var key := "site.prep.%s.%s" % [String(prep.id), status]
		var translated := I18n.t(key)
		var tip: String = h.main.site_view._room_tip(room_id)
		h.check("Localized preparation tip " + locale + ":" + loc_id + ":" + status, translated != key and tip.contains(translated))
		h.main._on_hover(tip)
		await h.frames(4)
		var tip_bounds: Rect2 = h.main.hud.tip_panel.get_global_rect()
		var ui_bounds := Rect2(Vector2.ZERO, h.main.ui_root.size)
		h.check("Preparation tip fits150percent " + locale + ":" + room_id, ui_bounds.grow(1.0).encloses(tip_bounds))
		if room_id == "west":
			await h.shot("fixes_tip_" + locale + "_" + loc_id + "_" + status)
		h.main._on_hover("")
		h.main.site_view._click_room(room_id)
		await h.wait(0.18)
		var dialog: Variant = null
		for child in h.main.modal_root.get_children():
			if child is Dialog:
				dialog = child
		var fit := false
		var text_seen := false
		var bounds := Rect2()
		if dialog != null:
			bounds = dialog.panel.get_global_rect()
			fit = Rect2(Vector2.ZERO, h.main.modal_root.size).grow(1.0).encloses(bounds)
			for label in dialog.body.find_children("*", "Label", true, false):
				if label.text.contains(translated):
					text_seen = true
			for button in dialog.buttons.get_children():
				if button is Button and not bounds.grow(1.0).encloses(button.get_global_rect()):
					fit = false
		h.check("Preparation dialog is localized and bounded " + locale + ":" + loc_id + ":" + room_id + ":" + status, dialog != null and text_seen and fit)
		await h.shot("fixes_dialog_" + locale + "_" + loc_id + "_" + room_id + "_" + status)
		cases.append({"room": room_id, "key": key, "tip": tip, "tip_rect": str(tip_bounds), "dialog_rect": str(bounds), "localized": text_seen, "fits": fit})
		if dialog != null:
			dialog._choose("cancel")
		await h.frames(3)
	_results.append({"fixture": true, "locale": locale, "scale": 1.5, "location": loc_id,
		"preparation": prep, "modifiers": definition.modifiers, "decoys": _decoys(definition), "ui": cases})


func _pet_battle(h, owner_id: String) -> void:
	await _load_fixture(h, "horizon_arena", false)
	# Attach before the first battle frame instead of letting _act's frame
	# waits run combat before the observer exists. Processing stays enabled.
	var before_tx := int(Game.state.envelope.lastTxId)
	var start: Dictionary = Actions.start_legend(Game.state)
	var started: bool = Game.act(start)
	h.record("fixes_action", {"action": "sample_grand_legend_with_owned_tidefin", "ok": started,
		"reason": start.get("reasonKey", ""), "tx_before": before_tx, "tx_after": Game.state.envelope.lastTxId})
	h.check("Grand Legend with restored owned pet starts", started)
	if not started:
		return
	var view = h.main.battle_view
	if view == null:
		h.check("Pet battle view exists", false)
		return
	var sim: Dictionary = view.sim
	var spec_pet := false
	for ally in Game.state.encounter.spec.allies:
		if ally.key == owner_id and ally.pet != null:
			spec_pet = String(ally.pet.ability) == "splash"
	h.check("Earned Tidefin reaches real companion battle spec", spec_pet)
	view._issue("stance", "defensive")
	view._issue("priority", "survival")
	var observation := {"last_seq": 0, "last_tick": int(sim.tick), "frames": 0,
		"max_tick_jump": 0, "log_gaps": [], "owner_states": [],
		"pet_events": [], "positive_damage_events": []}
	var wall := Time.get_ticks_usec()
	_scan_pet_observation(sim, observation, owner_id)
	while sim.get("outcome") == null and float(sim.tick) * Combat.dt() < 18.0 and float(Time.get_ticks_usec() - wall) / 1000000.0 < 12.0:
		if float(sim.tick) * Combat.dt() >= 5.0 and not observation.pet_events.is_empty() and not observation.positive_damage_events.is_empty():
			break
		# The combat log retains only80 events. Read after each rendered frame,
		# rather than every50ms, and record any sequence gap instead of assuming
		# an absent event proves the pet did not act.
		await RenderingServer.frame_post_draw
		_scan_pet_observation(sim, observation, owner_id)
	# The stopping tick can itself contain the first pet hit.
	_scan_pet_observation(sim, observation, owner_id)
	var simulated_seconds := float(sim.tick) * Combat.dt()
	h.check("Restored pet runs at least five simulated seconds", simulated_seconds >= 5.0)
	h.check("Restored Tidefin actually acts and damages an enemy", not observation.pet_events.is_empty() and not observation.positive_damage_events.is_empty())
	await h.shot("fixes_owned_tidefin_live")
	h.record("fixes_real_pet_effect", {"fixture": true, "earned_pet_normal_assignment": true,
		"owner": owner_id, "simulated_seconds": simulated_seconds, "pet_events": observation.pet_events,
		"positive_damage_events": observation.positive_damage_events})
	h.record("fixes_pet_observation", {"method": "Normal BattleView process, observe every frame_post_draw and final tick",
		"simulation_processing_modified": false, "simulated_seconds": simulated_seconds,
		"wall_seconds": float(Time.get_ticks_usec() - wall) / 1000000.0, "max_simulated_seconds": 18.0,
		"max_wall_seconds": 12.0, "frames": observation.frames, "max_tick_jump": observation.max_tick_jump,
		"last_seq": observation.last_seq, "log_gaps": observation.log_gaps, "owner_states": observation.owner_states})
	await _settle_battle(h, "owned_tidefin_grand")


func _scan_pet_observation(sim: Dictionary, observation: Dictionary, owner_id: String) -> void:
	var tick := int(sim.tick)
	observation.frames = int(observation.frames) + 1
	observation.max_tick_jump = maxi(int(observation.max_tick_jump), tick - int(observation.last_tick))
	observation.last_tick = tick
	for event in sim.log:
		var seq := int(event.seq)
		if seq <= int(observation.last_seq):
			continue
		if seq > int(observation.last_seq) + 1:
			observation.log_gaps.append({"after_seq": observation.last_seq, "next_seq": seq, "tick": tick})
		observation.last_seq = seq
		if event.get("type") == "pet" and event.get("ability") == "splash":
			observation.pet_events.append(event.duplicate(true))
		if event.get("type") == "hit" and event.get("skill") == "pet_splash" and int(event.get("amount", 0)) > 0:
			observation.positive_damage_events.append(event.duplicate(true))
	var previous_tick := -10
	if not observation.owner_states.is_empty():
		previous_tick = int(observation.owner_states.back().tick)
	if tick - previous_tick >= 10:
		for ally in sim.allies:
			if ally.key == owner_id:
				observation.owner_states.append({"tick": tick, "alive": ally.alive, "hp": ally.hp,
					"pet_timer": ally.pet.get("timer") if ally.pet != null else null,
					"stun": ally.st.stun, "windup": ally.windup.get("skill") if ally.windup != null else null})
				break


func _report(h, attempt: String) -> Variant:
	for child in h.main.modal_root.get_children():
		if child is BattleReport and String(child.sm.get("attemptId", "")) == attempt:
			return child
	return null


func _settle_battle(h, label: String) -> bool:
	if Game.state.encounter == null:
		return false
	var attempt := String(Game.state.encounter.attemptId)
	if h.main.battle_view != null:
		h.main.battle_view.skip_to_end()
	var report = _report(h, attempt)
	var waits := 0
	while report == null and not Game.state.committed.has(attempt) and waits < 120:
		await h.wait(0.1)
		waits += 1
		report = _report(h, attempt)
	_last_summary = {}
	if report != null:
		_last_summary = report.sm.duplicate(true)
		await h.shot("fixes_" + label + "_report")
		if not bool(report._committed):
			if bool(_last_summary.get("recruit", {}).get("offered", false)):
				report._choose_recruit(false)
			report._on_collect()
			await h.frames(4)
		if is_instance_valid(report) and bool(report._committed):
			report._close()
		await h.frames(5)
	elif Game.state.committed.has(attempt):
		_last_summary = Game.state.committed[attempt].duplicate(true)
	var settled: bool = Game.state.encounter == null and not _last_summary.is_empty()
	h.check("Normal report settles " + label, settled)
	_battles.append({"fixture": true, "label": label, "attempt": attempt,
		"settled": settled, "outcome": _last_summary.get("outcome"), "time": _last_summary.get("time")})
	return settled and _last_summary.get("outcome", "") == "victory"


func _west_and_saved_depths(h) -> void:
	await _load_fixture(h, "crystal_vault", false)
	var preview := World.encounter_for_state(Game.state, "crystal_vault", "west")
	var stamina := int(Game.state.ship.stamina)
	var entered: bool = await _act(h, "normal_optional_west_fight", Actions.enter_room(Game.state, "west"))
	h.check("West preparation fight starts normally and spends ten", entered and int(Game.state.ship.stamina) == stamina - 10)
	if not entered:
		return
	h.check("West fight matches preview and is not prematurely prepared", var_to_bytes(Game.state.encounter.def) == var_to_bytes(preview) and Game.state.encounter.def.modifiers.has("glare") and _decoys(Game.state.encounter.def) > 0)
	if not await _settle_battle(h, "glass_west"):
		return
	h.check("Real west victory activates local preparation", bool(World.preparation(Game.state, "crystal_vault").active))
	var depth_preview := World.encounter_for_state(Game.state, "crystal_vault", "depths")
	if not await _act(h, "normal_prepared_depths", Actions.enter_room(Game.state, "depths")):
		return
	h.check("Next actual Glass fight removes glare and decoys", var_to_bytes(Game.state.encounter.def) == var_to_bytes(depth_preview) and not Game.state.encounter.def.modifiers.has("glare") and not Game.state.encounter.def.modifiers.has("decoys") and _decoys(Game.state.encounter.def) == 0)
	var def_bytes := var_to_bytes(Game.state.encounter.def)
	var spec_bytes := var_to_bytes(Game.state.encounter.spec)
	var tx := int(Game.state.envelope.lastTxId)
	var wrote: bool = bool(Game.save_manual(2))
	var read: Dictionary = SaveStore.read(SaveStore.manual_path(2))
	h.check("New fixture save roundtrip verifies", wrote and read.get("status", "") == "ok")
	if read.get("status", "") == "ok":
		await h.load_state(read.record.state)
		h.check("Saved prepared room and pending definition stay frozen", int(Game.state.envelope.lastTxId) == tx and bool(World.preparation(Game.state, "crystal_vault").active) and var_to_bytes(Game.state.encounter.def) == def_bytes and var_to_bytes(Game.state.encounter.spec) == spec_bytes)
		h.record("fixes_fixture_save_roundtrip", {"slot": 2, "status": read.status, "tx": tx,
			"active": World.preparation(Game.state, "crystal_vault").active, "modifiers": Game.state.encounter.def.modifiers})
	await _settle_battle(h, "glass_prepared_depths_reloaded")


func _storm_actual(h) -> void:
	await _load_fixture(h, "drowned_beacon", true)
	var preview := World.encounter_for_state(Game.state, "drowned_beacon", "depths")
	var normal := World.encounter_for("drowned_beacon", "depths")
	if not await _act(h, "normal_prepared_storm_depths", Actions.enter_room(Game.state, "depths")):
		return
	h.check("Actual beacon-sheltered fight agrees with preview", var_to_bytes(Game.state.encounter.def) == var_to_bytes(preview) and not Game.state.encounter.spec.modifiers.has("storm") and var_to_bytes(Game.state.encounter.def.waves) == var_to_bytes(normal.waves))
	await _settle_battle(h, "storm_prepared_depths")


func _finish(h) -> void:
	var restored := false
	if not _earned.is_empty():
		await h.load_state(_earned)
		restored = var_to_bytes(Game.state.captain.trialsWon) == var_to_bytes(_earned.captain.trialsWon) and var_to_bytes(Game.state.crew) == var_to_bytes(_earned.crew) and var_to_bytes(Game.state.inventory) == var_to_bytes(_earned.inventory)
		h.check("Fixture rewards/XP do not leak into restored earned save", restored)
		var saved: bool = bool(Game.save_manual(1))
		var check_saved: Dictionary = SaveStore.read(SaveStore.manual_path(1))
		h.check("Normally assigned earned pet state saves separately", saved and check_saved.get("status", "") == "ok")
	var result := {"scope": "New-PCK rendered fixes regression; organic old-save/assignment checks and explicitly labelled placement fixtures",
		"stop_reason": _stop, "elapsed_seconds": float(Time.get_ticks_usec() - _began) / 1000000.0,
		"ui_cases": _results, "battles": _battles, "earned_state_restored": restored,
		"no_level_xp_mastery_gear_hp_edits": true}
	var file := FileAccess.open(h.out_dir.path_join("fixes_regression_result.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result, "\t"))
	h.record("fixes_regression_result", result)
	if not _earned.is_empty():
		await h.shot("fixes_restored_earned_companion_state")
