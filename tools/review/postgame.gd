extends RefCounted
## Five postgame rule contexts, played from the earned ten-trial checkpoint.
## The external review harness supplies the shipped scene and normal APIs.

const MAX_SECONDS := 300.0
const ORDER := ["grand_horizon", "leviathan_ring", "ashen_trench", "moonwake", "stormbelt"]
var _guide: Variant = null
var _start_usec := 0
var _stop_reason := ""
var _results: Array = []
var _original_formation: Array = []


func run(h) -> void:
	_start_usec = Time.get_ticks_usec()
	var saved: Dictionary = SaveStore.read(SaveStore.manual_path(0))
	if saved.get("status", "") != "ok":
		_stop_reason = "No valid copied manual slot zero; no progress fabricated"
		await _finish(h)
		return
	await h.load_state(saved.record.state)
	var eligible: bool = bool(Game.state.captain.postgame) and int(Game.state.captain.trialsWon.size()) == 10
	h.check("Postgame uses earned ten-trial checkpoint", eligible)
	if not eligible:
		_stop_reason = "Copied save has not unlocked postgame through ten main trials"
		await _finish(h)
		return
	var helper_path := ""
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--scenario" and i + 1 < args.size():
			helper_path = String(args[i + 1]).get_base_dir().path_join("campaign_guided.gd")
	var helper := GDScript.new()
	helper.source_code = FileAccess.get_file_as_string(helper_path)
	var compile_error := helper.reload()
	h.check("External normal campaign helper compiles", compile_error == OK)
	if compile_error != OK:
		_stop_reason = "External campaign_guided.gd helper could not compile"
		await _finish(h)
		return
	_guide = helper.new()
	_guide._start_usec = Time.get_ticks_usec()
	_original_formation = Game.state.formation.duplicate()
	Settings.set_value("battleSpeed", 4)
	await _guide._standby_offensive_pets(h)
	h.check("Shipped postgame catalogue has exactly five contexts", C.world.LEGENDS.size() == 5)
	h.record("postgame_method", {"normal_rules": true, "direct_state_edits": false,
		"resource_or_xp_grants": false, "resumed_tx": Game.state.envelope.lastTxId,
		"contexts": ORDER, "wall_seconds_budget": MAX_SECONDS,
		"ordering": "Descending adjacent regions with normal port stops to keep voyage food within earned supplies",
		"input": "Shipped Actions, report settlement and engine Input; no OS mouse control",
		"battle": "One normal attempt each; live sample followed by shipped Skip",
		"preparation": "Treat injuries, normal rations and food purchase, owned counter gear; no extra farming",
		"pet": "Offensive companion remains on standby as previously recorded bug mitigation; product is unmodified"})
	await h.shot("postgame_earned_checkpoint")
	for rid in ORDER:
		if not _within_budget():
			break
		var reg: Dictionary = C.region(rid)
		var rule: Dictionary = C.world.LEGENDS[rid]
		var row := {"region": rid, "restriction": rule.restriction,
			"arena": reg.locs[8], "normal_rules": true, "attempted": false,
			"legend_won_before": Game.state.captain.legendsWon.has(rid), "before": _snapshot()}
		if Game.state.encounter != null:
			_stop_reason = "Prior encounter is still pending; no second encounter started"
			row["status"] = "prior_encounter_pending"
			_results.append(row)
			break
		if not Rules.at_port(Game.state):
			await _guide._tx(h, "postgame_bank_and_return", Actions.emergency_return(Game.state))
		await _prepare_basics(h, rid)
		if not await _travel(h, String(reg.locs[0])):
			row["status"] = "port_travel_refused"
			row["reason"] = _stop_reason
			_results.append(row)
			h.record("postgame_context_result", row)
			continue
		await _prepare_basics(h, rid)
		await _prepare_formation(h, String(rule.restriction))
		await _equip_owned_counter(h, rid, String(rule.restriction))
		if not await _travel(h, String(reg.locs[8])):
			row["status"] = "arena_travel_refused"
			row["reason"] = _stop_reason
			_results.append(row)
			h.record("postgame_context_result", row)
			continue
		await _guide._stamina(h, 25)
		if not _within_budget():
			row["status"] = "preparation_budget_reached"
			row["after"] = _snapshot()
			_results.append(row)
			break
		await _capture_legend_choice(h, rid)
		var start: Dictionary = Actions.start_legend(Game.state)
		if not await _guide._tx(h, "start_legend:" + rid, start):
			row["status"] = "start_refused"
			row["reason"] = start.get("reasonKey", "")
			row["after"] = _snapshot()
			_results.append(row)
			h.record("postgame_context_result", row)
			continue
		row["attempted"] = true
		row.merge(await _play_battle(h, rid, String(rule.restriction), String(start.state.encounter.attemptId), true), true)
		row["legend_won_after"] = Game.state.captain.legendsWon.has(rid)
		row["after"] = _snapshot()
		_results.append(row)
		h.record("postgame_context_result", row)
		if Game.state.encounter == null:
			await _guide._save_checkpoint(h, "postgame_" + rid)
	if Game.state.encounter == null:
		if not Rules.at_port(Game.state):
			await _guide._tx(h, "postgame_bank_final_rewards", Actions.emergency_return(Game.state))
		await _restore_formation(h)
	await _finish(h)


func _within_budget() -> bool:
	if float(Time.get_ticks_usec() - _start_usec) / 1000000.0 < MAX_SECONDS:
		return true
	_stop_reason = "Bounded 300-second postgame sample budget reached"
	return false


func _snapshot() -> Dictionary:
	if Game.state.is_empty():
		return {}
	if _guide == null:
		return {"postgame": Game.state.captain.postgame, "trials": Game.state.captain.trialsWon.duplicate(),
			"legends": Game.state.captain.legendsWon.duplicate(), "tx": Game.state.envelope.lastTxId}
	var snap: Dictionary = _guide._snapshot()
	snap["legends"] = Game.state.captain.legendsWon.duplicate()
	snap["formation"] = Game.state.formation.duplicate()
	snap["tx"] = Game.state.envelope.lastTxId
	return snap


func _prepare_basics(h, rid: String) -> void:
	if not Rules.at_port(Game.state):
		return
	for aid in Rules.emergency_needs(Game.state):
		await _guide._tx(h, "postgame_emergency_aid:" + String(aid), Actions.emergency_aid(Game.state, String(aid)))
	for member in Game.state.crew.duplicate(true):
		if bool(member.injured):
			await _guide._tx(h, "postgame_treat:" + String(member.id), Actions.treat(Game.state, String(member.id)))
	var prices: Dictionary = Rules.prices(Game.state, String(Game.state.world.currentLocationId))
	var qty := mini(Rules.food_capacity(Game.state) - int(Game.state.inventory.food), 16 - int(Game.state.inventory.food))
	qty = mini(qty, maxi(0, (int(Game.state.inventory.gold) - 20) / maxi(1, int(prices.food))))
	if qty > 0:
		await _guide._tx(h, "postgame_buy_food", Actions.buy_goods(Game.state, "food", null, qty))
	await _guide._stamina(h, 40)
	h.record("postgame_normal_preparation", {"region": rid, "state": _snapshot()})


func _travel(h, destination: String) -> bool:
	if String(Game.state.world.currentLocationId) == destination and Game.state.encounter == null:
		if not Rules.at_port(Game.state) and Game.state.voyage != null and Game.state.voyage.site == null:
			return await _guide._tx(h, "postgame_go_ashore", Actions.land(Game.state))
		return true
	var preview: Dictionary = Actions.depart(Game.state, destination, {"confirmed": true})
	if not preview.get("ok", false):
		h.record("postgame_departure_refused", {"destination": destination, "reason": preview.get("reasonKey"), "state": _snapshot()})
		_stop_reason = "Normal departure refused: " + String(preview.get("reasonKey", "unknown"))
		return false
	var tx_before := int(Game.state.envelope.lastTxId)
	h.main.depart(destination, false, true)
	var attempt := ""
	if Game.state.encounter != null:
		attempt = String(Game.state.encounter.attemptId)
	var sail_started := Time.get_ticks_usec()
	var used_skip := false
	# Game.where() changes to battle when the transaction creates an
	# encounter. Its rendered stage is created later by sailing_done.
	# Observe the actual animation instead of equating a wall timer with it.
	while h.main.ship_view.is_sailing() and float(Time.get_ticks_usec() - sail_started) / 1000000.0 < 12.0:
		if not used_skip and float(Time.get_ticks_usec() - sail_started) / 1000000.0 >= 3.0:
			h.main.ship_view.skip_sailing()
			used_skip = true
			h.record("postgame_sailing_skip", {"destination": destination, "method": "Shipped ShipView Skip Sailing control"})
		await h.wait(0.05)
	await h.frames(4)
	while Game.state.encounter != null and h.main.battle_view == null and h.main._report == null and float(Time.get_ticks_usec() - sail_started) / 1000000.0 < 12.0:
		await h.wait(0.05)
	h.record("postgame_departure_ready", {"destination": destination, "attempt": attempt,
		"tx_before": tx_before, "tx_after": Game.state.envelope.lastTxId,
		"sailing": h.main.ship_view.is_sailing(), "world_mode": h.main.world_mode,
		"lock": h.main._lock, "battle_view": h.main.battle_view != null,
		"report": h.main._report != null, "time_scale": Engine.time_scale,
		"wait_seconds": float(Time.get_ticks_usec() - sail_started) / 1000000.0})
	if attempt != "":
		var rid := String(C.location(destination).regionId)
		var battle: Dictionary = await _play_battle(h, rid, "", attempt, false)
		h.record("postgame_voyage_battle", battle)
		if battle.get("outcome", "unknown") != "victory":
			_stop_reason = "Normal voyage battle did not resolve in victory"
			return false
	if Game.state.voyage != null and Game.state.voyage.event != null:
		var kind := String(Game.state.voyage.event.kind)
		var choice := "refuse" if kind == "inspection" else ("ignore" if kind == "vessel" else "continue")
		if h.main._sea_dialog != null and is_instance_valid(h.main._sea_dialog):
			h.main._sea_dialog._choose(choice)
		else:
			h.main._on_sea_choice(choice)
		await h.frames(5)
	return String(Game.state.world.currentLocationId) == destination and Game.state.encounter == null


func _restore_formation(h) -> void:
	if not Rules.at_port(Game.state):
		return
	for slot in mini(6, _original_formation.size()):
		if Game.state.formation[slot] != _original_formation[slot]:
			await _guide._tx(h, "postgame_restore_formation:" + str(slot), Actions.set_formation(Game.state, slot, _original_formation[slot]))


func _prepare_formation(h, restriction: String) -> void:
	await _restore_formation(h)
	if restriction != "four_crew":
		return
	# The rule uses the first four formation slots. Include the earned healer
	# and a ranged attacker rather than silently omitting both rear slots.
	var selected: Array = []
	for desired in ["guard", "duelist", "gunner", "medic"]:
		for member in Game.state.crew:
			if C.base_class_of(String(member.classId)) == desired and not selected.has(member.id):
				selected.append(member.id)
	for member in Game.state.crew:
		if selected.size() >= 4:
			break
		if not selected.has(member.id):
			selected.append(member.id)
	for slot in mini(4, selected.size()):
		if Game.state.formation[slot] != selected[slot]:
			await _guide._tx(h, "postgame_four_crew_formation:" + str(slot), Actions.set_formation(Game.state, slot, selected[slot]))
	h.record("postgame_four_crew_selection", {"first_four": Game.state.formation.slice(0, 4)})


func _counter_score(state: Dictionary, member: Dictionary, hazard: Variant, restriction: String) -> float:
	var score := float(Rules.power(state, member))
	var stats: Dictionary = Rules.member_stats(state, member)
	if hazard != null and (stats.resist.has(hazard) or float(stats.mods.get("hazardResist", 0)) > 0):
		score += 280.0 if restriction == "double_hazard" else 160.0
	return score


func _equip_owned_counter(h, rid: String, restriction: String) -> void:
	var hazard = C.region(rid).hazard
	for member in Game.state.crew.duplicate(true):
		for slot in ["weapon", "outfit", "accessory"]:
			var best_score: float = _counter_score(Game.state, Rules.member(Game.state, member.id), hazard, restriction)
			var best: Dictionary = {}
			for inst in Game.state.inventory.equipment:
				if Actions.is_equipped(Game.state, String(inst.uid)) or String(C.ITEMS[inst.itemId].slot) != slot:
					continue
				var equip: Dictionary = Actions.equip(Game.state, String(member.id), slot, inst.uid)
				if not equip.get("ok", false):
					continue
				var score: float = _counter_score(equip.state, Rules.member(equip.state, member.id), hazard, restriction)
				if score > best_score:
					best_score = score
					best = equip
			if not best.is_empty():
				await _guide._tx(h, "postgame_owned_counter:" + rid + ":" + String(member.id) + ":" + slot, best)


func _capture_legend_choice(h, rid: String) -> void:
	await h.frames(4)
	var opened := false
	if h.main.site_view != null:
		h.main.site_view._click_room("trial")
		await h.wait(0.2)
		for child in h.main.modal_root.get_children():
			if child is Dialog:
				for button in child.buttons.get_children():
					if button is Button and button.text == I18n.t("site.legend"):
						opened = true
		await h.shot("postgame_" + rid + "_legend_choice")
		for child in h.main.modal_root.get_children():
			if child is Dialog:
				child._choose("cancel")
		await h.frames(3)
	h.check("Legend choice is available: " + rid, opened)
	h.record("postgame_choice", {"region": rid, "legend_button_visible": opened,
		"start_method": "Captured normal cleared-trial dialog, cancelled it, then committed shipped Actions.start_legend API"})


func _report_for_attempt(h, attempt: String) -> Variant:
	if h.main._report != null and is_instance_valid(h.main._report) and String(h.main._report.sm.get("attemptId", "")) == attempt:
		return h.main._report
	for child in h.main.modal_root.get_children():
		if child is BattleReport and String(child.sm.get("attemptId", "")) == attempt:
			return child
	return null


func _play_battle(h, rid: String, restriction: String, attempt: String, require_legend: bool) -> Dictionary:
	_guide._total_fights += 1
	var encounter: Dictionary = Game.state.encounter.duplicate(true) if Game.state.encounter != null else {}
	var initial: Dictionary = {}
	var events: Dictionary = {}
	var encored: Variant = null
	var end_observed := false
	var prefix := "postgame_" + rid + ("" if require_legend else "_voyage")
	await h.frames(4)
	var view = h.main.battle_view
	if is_instance_valid(view) and not encounter.is_empty():
		var stance := "aggressive" if restriction == "no_healing" else "defensive"
		var priority := "damage" if restriction == "no_healing" else "survival"
		view._issue("stance", stance)
		view._issue("priority", priority)
		var focus = _guide._focus_target(view.sim)
		if focus != null:
			view._issue("focus", focus)
		initial = {"attempt": attempt, "legend": encounter.def.get("legend", false), "restriction": encounter.def.get("restriction"),
			"context": encounter.context, "enemy_level": encounter.def.level,
			"wave_count": encounter.def.waves.size(), "ally_count": view.sim.allies.size(),
			"modifiers": view.sim.mods.duplicate(), "party_level": view.sim.partyLevel,
			"stance": stance, "priority": priority, "focus": focus}
		if require_legend:
			h.check("Legend context is active: " + rid, bool(initial.legend) and String(encounter.context.type) == "legend")
			if restriction == "four_crew":
				h.check("Four-crew restriction is applied", int(initial.ally_count) == 4)
		h.record("postgame_encounter" if require_legend else "postgame_voyage_encounter", initial)
		await h.wait(0.8)
		await h.shot(prefix + "_opening")
		await h.wait(1.0 if not require_legend else 1.8)
		await h.shot(prefix + "_live")
		if is_instance_valid(view):
			view.skip_to_end()
			end_observed = true
			encored = bool(view.sim.get("encored", false))
			for event in view.sim.get("log", []):
				var type := String(event.get("type", "unknown"))
				events[type] = int(events.get(type, 0)) + 1
	var waits := 0
	var report = _report_for_attempt(h, attempt)
	while report == null and not Game.state.committed.has(attempt) and waits < 120:
		await h.wait(0.1)
		waits += 1
		report = _report_for_attempt(h, attempt)
	var summary: Dictionary = {}
	var status := "settled"
	if report != null:
		summary = report.sm.duplicate(true)
		await h.shot(prefix + "_report")
		if not bool(report._committed):
			if bool(summary.get("recruit", {}).get("offered", false)):
				report._choose_recruit(false)
			report._on_collect()
			await h.frames(4)
			# An orphaned report cannot use Main's transient pointer. Commit
			# the same normal settlement transaction, never fabricate a result.
			if Game.state.encounter != null and String(Game.state.encounter.attemptId) == attempt:
				var settle: Dictionary = Actions.resolve_encounter(Game.state, attempt, [], {"recruit": false})
				if await _guide._tx(h, "postgame_normal_report_settlement:" + attempt, settle):
					report.show_committed(settle.value)
					h.record("postgame_report_pointer_recovery", {"attempt": attempt, "normal_settlement_api": true})
		if is_instance_valid(report) and bool(report._committed):
			report._close()
		await h.frames(5)
	elif Game.state.committed.has(attempt):
		summary = Game.state.committed[attempt].duplicate(true)
		status = "already_settled_before_report_observation"
		h.record("postgame_committed_report_recovered", {"attempt": attempt, "outcome": summary.get("outcome"), "tx": Game.state.envelope.lastTxId})
	else:
		_stop_reason = "Battle UI/report did not become ready for " + attempt
		h.record("postgame_battle_ui_unready", {"attempt": attempt, "world_mode": h.main.world_mode,
			"lock": h.main._lock, "sailing": h.main.ship_view.is_sailing(), "state": _snapshot()})
		return {"status": "report_missing", "outcome": "unknown", "encounter": initial}
	return {"status": status, "attempt": attempt, "outcome": summary.get("outcome", "unknown"),
		"battle_seconds": summary.get("time", 0), "hpAvg": summary.get("hpAvg", 0),
		"reason": summary.get("reason"), "encounter": initial,
		"simulation_end_observed": end_observed, "encore_triggered": encored,
		"retained_simulation_event_counts": events}


func _finish(h) -> void:
	for rid in ORDER:
		var present := false
		for row in _results:
			if row.region == rid:
				present = true
		if not present:
			_results.append({"region": rid, "normal_rules": true, "attempted": false,
				"status": "not_attempted", "reason": _stop_reason})
	var attempted := 0
	var won := 0
	for row in _results:
		if bool(row.get("attempted", false)):
			attempted += 1
		if row.get("outcome", "") == "victory":
			won += 1
	var save := {"written": false, "hash_valid": false, "reload_tx_preserved": false}
	if _guide != null and Game.state.encounter == null:
		var tx := int(Game.state.envelope.lastTxId)
		save.written = bool(Game.save_manual(0))
		var read: Dictionary = SaveStore.read(SaveStore.manual_path(0))
		save.hash_valid = read.get("status", "") == "ok"
		if bool(save.hash_valid):
			await h.load_state(read.record.state)
			save.reload_tx_preserved = int(Game.state.envelope.lastTxId) == tx
		h.check("Postgame final manual save is valid", bool(save.written) and bool(save.hash_valid) and bool(save.reload_tx_preserved))
	h.check("Five postgame rule contexts attempted", attempted == 5)
	var result := {"normal_rules": true, "resource_or_xp_grants": false, "direct_state_edits": false,
		"expected_contexts": ORDER, "contexts_attempted": attempted, "legend_victories_this_sample": won,
		"battles_including_voyage_encounters": _guide._total_fights if _guide != null else 0,
		"stop_reason": _stop_reason, "elapsed_seconds": float(Time.get_ticks_usec() - _start_usec) / 1000000.0,
		"challenges": _results, "final": _snapshot(), "final_save": save,
		"trace": _guide._trace if _guide != null else []}
	var file := FileAccess.open(h.out_dir.path_join("postgame_result.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result, "\t"))
	h.record("postgame_result", result)
	if _guide != null:
		await h.shot("postgame_final_state")
