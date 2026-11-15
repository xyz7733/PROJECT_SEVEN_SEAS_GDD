extends RefCounted
## Bounded, earned-save rematch of the remaining Grand Horizon Legend.
const MAX_SECONDS := 300.0
var _start_usec := 0
var _guide: Variant = null
var _postgame: Variant = null
var _attempts: Array = []
var _start_legends: Array = []
var _stop_reason := ""


func run(h) -> void:
	_start_usec = Time.get_ticks_usec()
	var saved: Dictionary = SaveStore.read(SaveStore.manual_path(0))
	if saved.get("status", "") != "ok":
		_stop_reason = "No valid copied manual checkpoint"
		await _finish(h)
		return
	await h.load_state(saved.record.state)
	var eligible: bool = bool(Game.state.captain.postgame) and int(Game.state.captain.trialsWon.size()) == 10 and int(Game.state.captain.legendsWon.size()) >= 4
	h.check("Finale starts from earned ten-trial/four-Legend save", eligible)
	if not eligible:
		_stop_reason = "Required normal-earned checkpoint is unavailable"
		await _finish(h)
		return
	_start_legends = Game.state.captain.legendsWon.duplicate()
	var base := ""
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--scenario" and i + 1 < args.size():
			base = String(args[i + 1]).get_base_dir()
	var guide_script := GDScript.new()
	guide_script.source_code = FileAccess.get_file_as_string(base.path_join("campaign_guided.gd"))
	var post_script := GDScript.new()
	post_script.source_code = FileAccess.get_file_as_string(base.path_join("postgame.gd"))
	var guide_error := guide_script.reload()
	var post_error := post_script.reload()
	h.check("Finale external helpers compile", guide_error == OK and post_error == OK)
	if guide_error != OK or post_error != OK:
		_stop_reason = "External review helpers did not compile"
		await _finish(h)
		return
	_guide = guide_script.new()
	_guide._start_usec = Time.get_ticks_usec()
	_postgame = post_script.new()
	_postgame._guide = _guide
	_postgame._start_usec = _start_usec
	_postgame._original_formation = Game.state.formation.duplicate()
	Settings.set_value("battleSpeed", 4)
	await _guide._standby_offensive_pets(h)
	h.record("postgame_finale_method", {"normal_rules": true, "direct_state_edits": false,
		"resource_or_xp_grants": false, "farming": false, "max_grand_attempts": 2,
		"wall_seconds_budget": MAX_SECONDS, "start_legends": _start_legends,
		"travel": "Normal adjacent visited ports, including any real voyage encounters",
		"preparation": "Normal treatment/food/rations and earned owned equipment",
		"commands": "Normal live focus per wave; bounded second attempt changes tactics",
		"encore_observation": "Retained live simulation Dictionary reference survives BattleView closure"})
	await h.shot("finale_earned_four_legend_checkpoint")
	if Game.state.captain.legendsWon.has("grand_horizon"):
		_stop_reason = "Grand Horizon already won in this copied checkpoint; no extra rematch"
		await _finish(h)
		return
	if not Rules.at_port(Game.state):
		await _guide._tx(h, "finale_bank_and_return", Actions.emergency_return(Game.state))
	var current_order := int(C.region(String(C.location(String(Game.state.world.currentLocationId)).regionId)).order)
	for reg in C.REGIONS:
		if int(reg.order) <= current_order:
			continue
		if not _within_budget():
			break
		await _postgame._prepare_basics(h, String(reg.id))
		if not await _postgame._travel(h, String(reg.locs[0])):
			_stop_reason = "Normal adjacent-port travel failed: " + String(_postgame._stop_reason)
			break
	if _stop_reason != "":
		await _finish(h)
		return
	for number in range(1, 3):
		if not _within_budget() or Game.state.captain.legendsWon.has("grand_horizon"):
			break
		if not Rules.at_port(Game.state):
			await _guide._tx(h, "finale_return_for_preparation", Actions.emergency_return(Game.state))
		await _postgame._prepare_basics(h, "grand_horizon")
		await _equip_earned_rewards(h)
		if not await _postgame._travel(h, "horizon_arena"):
			_stop_reason = "Normal travel to Grand Horizon arena failed: " + String(_postgame._stop_reason)
			break
		await _guide._stamina(h, 25)
		await _capture_ready_legend_choice(h)
		var start: Dictionary = Actions.start_legend(Game.state)
		if not await _guide._tx(h, "finale_start_grand_legend:" + str(number), start):
			_attempts.append({"number": number, "attempted": false, "reason": start.get("reasonKey"), "normal_rules": true})
			break
		var row: Dictionary = await _battle(h, number, String(start.state.encounter.attemptId))
		_attempts.append(row)
		h.record("postgame_finale_attempt", row)
		if Game.state.encounter != null:
			_stop_reason = "Pending battle was not settled; no further attempt started"
			break
		await _guide._save_checkpoint(h, "grand_legend_finale_" + str(number))
	if Game.state.encounter == null and not Rules.at_port(Game.state):
		await _guide._tx(h, "finale_bank_rewards", Actions.emergency_return(Game.state))
	await _finish(h)


func _within_budget() -> bool:
	if float(Time.get_ticks_usec() - _start_usec) / 1000000.0 < MAX_SECONDS:
		return true
	_stop_reason = "Bounded 300-second finale budget reached"
	return false


func _snapshot() -> Dictionary:
	if Game.state.is_empty():
		return {}
	var snap: Dictionary = _guide._snapshot() if _guide != null else {}
	snap["legends"] = Game.state.captain.legendsWon.duplicate()
	snap["tx"] = Game.state.envelope.lastTxId
	return snap


func _gear_score(state: Dictionary, member: Dictionary) -> float:
	var stats: Dictionary = Rules.member_stats(state, member)
	var score := float(Rules.power(state, member))
	# Value the new rewards' actual properties as well as their printed stats.
	score += float(stats.mods.get("lifesteal", 0)) * 150.0
	score += float(stats.mods.get("thorns", 0)) * 30.0
	score += float(stats.mods.get("stunImmune", 0)) * 15.0
	score += float(stats.mods.get("dodge", 0)) * 100.0
	for prop in stats.get("props", []):
		score += float({"double": 18, "sunder": 10, "pierce": 14, "lifesteal": 15}.get(prop, 0))
	return score


func _equip_earned_rewards(h) -> void:
	for member in Game.state.crew.duplicate(true):
		for slot in ["weapon", "outfit", "accessory"]:
			var best_score: float = _gear_score(Game.state, Rules.member(Game.state, member.id))
			var best: Dictionary = {}
			var choice := ""
			for inst in Game.state.inventory.equipment:
				if Actions.is_equipped(Game.state, String(inst.uid)) or String(C.ITEMS[inst.itemId].slot) != slot:
					continue
				var equip: Dictionary = Actions.equip(Game.state, String(member.id), slot, inst.uid)
				if not equip.get("ok", false):
					continue
				var score: float = _gear_score(equip.state, Rules.member(equip.state, member.id))
				if score > best_score:
					best_score = score
					best = equip
					choice = String(inst.itemId)
			if not best.is_empty():
				await _guide._tx(h, "finale_equip_earned:" + String(member.id) + ":" + choice, best)
	h.record("finale_earned_equipment_ready", {"state": _snapshot()})


func _capture_ready_legend_choice(h) -> void:
	var began := Time.get_ticks_usec()
	while (h.main.site_view == null or bool(h.main.site_view.busy)) and float(Time.get_ticks_usec() - began) / 1000000.0 < 10.0:
		await h.wait(0.1)
	var ready: bool = h.main.site_view != null and not bool(h.main.site_view.busy)
	h.record("finale_site_entry_ready", {"ready": ready, "wait_seconds": float(Time.get_ticks_usec() - began) / 1000000.0})
	h.check("Finale Legend dialog waits for completed site entry", ready)
	if ready:
		await _postgame._capture_legend_choice(h, "grand_horizon_finale")


func _battle(h, number: int, attempt: String) -> Dictionary:
	var before: Dictionary = _snapshot()
	var encounter: Dictionary = Game.state.encounter.duplicate(true)
	await h.frames(4)
	var view = h.main.battle_view
	if view == null:
		return {"number": number, "attempt": attempt, "attempted": true, "normal_rules": true, "status": "battle_view_missing"}
	_guide._total_fights += 1
	var sim: Dictionary = view.sim
	var stance := "defensive" if number == 1 else "balanced"
	var priority := "survival" if number == 1 else "control"
	view._issue("stance", stance)
	view._issue("priority", priority)
	var levels: Array = []
	for wave in encounter.def.waves:
		var wave_levels: Array = []
		for enemy in wave:
			wave_levels.append(enemy.level)
		levels.append(wave_levels)
	h.record("finale_real_encounter", {"attempt": attempt, "wave_enemy_levels": levels,
		"modifiers": sim.mods, "party_level": sim.partyLevel, "stance": stance, "priority": priority})
	var seen_encore := false
	var last_wave := -1
	var last_focus: Variant = null
	var began := Time.get_ticks_usec()
	var live_captured := false
	while sim.get("outcome") == null and float(Time.get_ticks_usec() - began) / 1000000.0 < 55.0 and _within_budget():
		if is_instance_valid(view):
			var focus = _guide._focus_target(sim)
			if int(sim.wave) != last_wave or focus != last_focus:
				last_wave = int(sim.wave)
				last_focus = focus
				if focus != null:
					view._issue("focus", focus)
				h.record("finale_normal_wave_focus", {"attempt": attempt, "wave": last_wave, "focus": focus})
			if not live_captured and float(Time.get_ticks_usec() - began) / 1000000.0 >= 1.0:
				await h.shot("finale_attempt_" + str(number) + "_live")
				live_captured = true
			if bool(sim.get("encored", false)) and not seen_encore:
				seen_encore = true
				h.record("finale_encore_observed", {"attempt": attempt, "tick": sim.tick, "wave": sim.wave})
				await h.shot("finale_attempt_" + str(number) + "_encore")
				await h.wait(0.8)
				view.skip_to_end()
		await h.wait(0.1)
	if sim.get("outcome") == null and is_instance_valid(view):
		view.skip_to_end()
	seen_encore = seen_encore or bool(sim.get("encored", false))
	var report = _postgame._report_for_attempt(h, attempt)
	var waits := 0
	while report == null and not Game.state.committed.has(attempt) and waits < 120:
		await h.wait(0.1)
		waits += 1
		report = _postgame._report_for_attempt(h, attempt)
	var summary: Dictionary = {}
	if report != null:
		summary = report.sm.duplicate(true)
		await h.shot("finale_attempt_" + str(number) + "_report")
		if not bool(report._committed):
			report._on_collect()
			await h.frames(4)
		if is_instance_valid(report) and bool(report._committed):
			report._close()
		await h.frames(5)
	elif Game.state.committed.has(attempt):
		summary = Game.state.committed[attempt].duplicate(true)
	else:
		_stop_reason = "Finale battle report did not become available"
	return {"number": number, "attempt": attempt, "attempted": true, "normal_rules": true,
		"stance": stance, "priority": priority, "normal_focus_per_wave": true,
		"outcome": summary.get("outcome", "unknown"), "battle_seconds": summary.get("time"),
		"hpAvg": summary.get("hpAvg"), "encore_observed": seen_encore,
		"simulation_reference_retained": true, "wave_enemy_levels": levels,
		"before": before, "after": _snapshot(), "legend_won": Game.state.captain.legendsWon.has("grand_horizon")}


func _finish(h) -> void:
	var observed := false
	for row in _attempts:
		observed = observed or bool(row.get("encore_observed", false))
	var save := {"written": false, "hash_valid": false, "reload_tx_preserved": false}
	if _guide != null and Game.state.encounter == null:
		var tx := int(Game.state.envelope.lastTxId)
		save.written = bool(Game.save_manual(0))
		var read: Dictionary = SaveStore.read(SaveStore.manual_path(0))
		save.hash_valid = read.get("status", "") == "ok"
		if bool(save.hash_valid):
			await h.load_state(read.record.state)
			save.reload_tx_preserved = int(Game.state.envelope.lastTxId) == tx
	var complete: bool = not Game.state.is_empty() and int(Game.state.captain.legendsWon.size()) == 5
	h.check("Finale observes Encore in bounded normal attempts", observed)
	h.check("Five Legends cleared through normal rules", complete)
	h.check("Finale earned checkpoint save validates", bool(save.written) and bool(save.hash_valid) and bool(save.reload_tx_preserved))
	var result := {"normal_rules": true, "direct_state_edits": false, "resource_or_xp_grants": false,
		"farming": false, "start_legends": _start_legends, "attempt_limit": 2,
		"attempts": _attempts, "encore_observed": observed, "five_legends_won": complete,
		"stop_reason": _stop_reason, "elapsed_seconds": float(Time.get_ticks_usec() - _start_usec) / 1000000.0,
		"final": _snapshot(), "final_save": save, "trace": _guide._trace if _guide != null else []}
	var file := FileAccess.open(h.out_dir.path_join("postgame_finale_result.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result, "\t"))
	h.record("postgame_finale_result", result)
	if _guide != null:
		await h.shot("postgame_finale_final_state")
