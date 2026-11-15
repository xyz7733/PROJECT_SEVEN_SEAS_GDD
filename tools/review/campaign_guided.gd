extends RefCounted
## Normal-rules campaign run for the external, fullscreen release harness.
## Every progress/resource change goes through the shipped Actions API. No
## seeded late-game fixtures, XP grants, invulnerability, or direct state edits.

const MAX_REGION_FIGHTS := 60
const MAX_SECONDS := 1200.0
const BRANCHES := {"guard": "guardian", "duelist": "blade_dancer", "spearfighter": "dragoon",
	"gunner": "sharpshooter", "brawler": "breaker", "medic": "surgeon", "cook": "provisioner",
	"navigator": "pathfinder", "tinkerer": "engineer", "beastkeeper": "beastwarden",
	"mystic": "hexbreaker", "quartermaster": "standard_bearer"}
var _start_usec := 0
var _region_fights := 0
var _total_fights := 0
var _sampled := {}
var _trace: Array = []
var _stop_reason := ""
var _last_outcome := ""
var _hard_failures: Dictionary = {}
var _readiness_deferred := false
var _preview_refusals: Dictionary = {}


func run(h) -> void:
	_start_usec = Time.get_ticks_usec()
	var saved: Dictionary = SaveStore.read(SaveStore.manual_path(0))
	if saved.get("status", "") != "ok":
		h.check("Guided run has valid manual checkpoint", false)
		h.record("guided_stop", {"reason": "No valid copied manual slot zero. Refusing to invent progress."})
		return
	await h.load_state(saved.record.state)
	h.record("campaign_method", {"guided_followup": true, "resumed_tx": Game.state.envelope.lastTxId,
		"review_driver_policy": "Normal storage construction and protected obsolete-gear salvage; purchase refusals recorded",
		"normal_rules": true, "direct_state_edits": false,
		"input": "Shipped action/report APIs and engine input, not OS mouse input",
		"battle_skip": "Normal shipped Skip control after sampled live action",
		"pet_mitigation": "Offensive pet detached through normal assignment UI action; shipped bug is not fixed",
		"max_region_fights": MAX_REGION_FIGHTS, "wall_seconds_budget": MAX_SECONDS})
	Settings.set_value("battleSpeed", 4)
	await _standby_offensive_pets(h)
	await h.wait(0.7)
	await h.shot("guided_resumed_checkpoint")
	await _port_prepare(h)
	var region_results: Array = []
	for reg in C.REGIONS:
		var rid := String(reg.id)
		if not Game.state.captain.regionsUnlocked.has(rid):
			_stop_reason = "Region not unlocked after preceding trial: " + rid
			break
		_region_fights = 0
		var attempts := 0
		var stagnant := 0
		while int(Game.state.captain.mainStep.get(rid, 0)) < 5 and _within_budget():
			attempts += 1
			if attempts > 140 or _region_fights >= MAX_REGION_FIGHTS:
				_stop_reason = "Bounded retry/fight budget reached in " + rid
				break
			var step_before := int(Game.state.captain.mainStep.get(rid, 0))
			var quest = C.main_step(rid, step_before)
			if quest == null:
				_stop_reason = "Missing main quest: " + rid + ":" + str(step_before)
				break
			h.record("main_quest_attempt", {"region": rid, "step": step_before, "type": quest.type,
				"target": quest.locationId, "state": _snapshot()})
			if Rules.at_port(Game.state):
				await _port_prepare(h)
			var progressed := false
			match String(quest.type):
				"visit":
					progressed = await _travel(h, String(quest.locationId))
				"deliver":
					if await _travel(h, String(quest.locationId)):
						progressed = await _tx(h, "deliver_main", Actions.deliver_main(Game.state))
						if not progressed:
							await _grind(h, reg, true)
				_:
					if await _travel(h, String(quest.locationId)):
						progressed = await _clear_location(h, String(quest.locationId))
			var now_step := int(Game.state.captain.mainStep.get(rid, 0))
			if now_step > step_before:
				stagnant = 0
				h.record("main_step_completed", {"region": rid, "from": step_before, "to": now_step, "state": _snapshot()})
			else:
				stagnant += 1
				if _readiness_deferred or stagnant >= 2 or _last_outcome == "defeat":
					await _grind(h, reg, false)
					if _region_fights < MAX_REGION_FIGHTS and _within_budget():
						await _grind(h, reg, false)
					_readiness_deferred = false
					stagnant = 0
			if not progressed and _stop_reason != "":
				break
		var won: bool = bool(Game.state.captain.trialsWon.has(rid))
		region_results.append({"region": rid, "trial_won": won,
			"main_step": Game.state.captain.mainStep.get(rid, 0), "fights": _region_fights, "state": _snapshot()})
		h.record("region_result", region_results.back())
		await _save_checkpoint(h, rid)
		if not won:
			break
		await h.shot("normal_completed_" + rid)
	var complete: bool = bool(Game.state.captain.postgame) and int(Game.state.captain.trialsWon.size()) == 10
	if not complete and _stop_reason == "":
		_stop_reason = "Campaign did not reach all ten trials within bounded normal-rule run"
	var result := {"guided_followup": true, "normal_campaign_complete": complete, "stop_reason": _stop_reason,
		"elapsed_seconds": _elapsed(), "battles_exercised": _total_fights, "regions": region_results,
		"final": _snapshot(), "trace": _trace}
	var file := FileAccess.open(h.out_dir.path_join("campaign_result.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result, "\t"))
	h.record("campaign_result", result.duplicate())
	h.check("Normal campaign reached ten trials", complete)
	await h.shot("normal_final_state")


func _within_budget() -> bool:
	if _elapsed() < MAX_SECONDS:
		return true
	_stop_reason = "Wall-clock safety budget reached after %.1f seconds" % _elapsed()
	return false


func _elapsed() -> float:
	return float(Time.get_ticks_usec() - _start_usec) / 1000000.0


func _snapshot() -> Dictionary:
	var levels: Array = []
	for member in Game.state.crew:
		levels.append({"id": member.id, "class": member.classId, "level": member.level, "injured": member.injured})
	return {"location": Game.state.world.currentLocationId, "where": Game.where(),
		"equipment_count": Game.state.inventory.equipment.size(), "equipment_capacity": Rules.equip_capacity(Game.state),
		"gold": Game.state.inventory.gold, "food": Game.state.inventory.food,
		"supplies": Game.state.inventory.supplies, "materials": Game.state.inventory.materials,
		"ledger": Game.state.inventory.ledger.duplicate(), "specialties": Game.state.inventory.specialties.duplicate(),
		"stamina": Game.state.ship.stamina, "damage": Game.state.ship.damage,
		"hull": Game.state.ship.hullId, "crew": levels, "pets": Game.state.pets.size(),
		"trials": Game.state.captain.trialsWon.duplicate(), "stats": Game.state.captain.stats.duplicate()}


func _tx(h, label: String, result: Dictionary) -> bool:
	var line := {"action": label, "ok": bool(result.get("ok", false)),
		"reason": String(result.get("reasonKey", "")), "tx_before": Game.state.envelope.lastTxId}
	if not result.get("ok", false):
		_trace.append(line)
		h.record("normal_action_refused", line)
		return false
	var ok: bool = await h.act(result)
	line["committed"] = ok
	line["tx_after"] = Game.state.envelope.lastTxId
	_trace.append(line)
	h.record("normal_action", line)
	return ok


func _travel(h, destination: String) -> bool:
	if not _within_budget():
		return false
	if String(Game.state.world.currentLocationId) == destination:
		if not Rules.at_port(Game.state) and Game.state.voyage != null and Game.state.voyage.site == null:
			return await _tx(h, "go_ashore", Actions.land(Game.state))
		return true
	for attempt in 3:
		var preview: Dictionary = Actions.depart(Game.state, destination, {"confirmed": true})
		if not preview.get("ok", false):
			var reason := String(preview.get("reasonKey", ""))
			h.record("departure_blocked", {"destination": destination, "reason": reason, "state": _snapshot()})
			if reason == "err.no_food_route":
				if not Rules.at_port(Game.state):
					await _tx(h, "emergency_return_for_food", Actions.emergency_return(Game.state))
				await _port_prepare(h)
				continue
			if reason == "err.hull_required":
				if not Rules.at_port(Game.state):
					await _tx(h, "return_for_required_hull", Actions.emergency_return(Game.state))
				await _port_prepare(h)
				if Rules.sail_block(Game.state, destination, false) != "err.hull_required":
					continue
				_readiness_deferred = true
				h.record("guided_hull_preparation_needed", {"destination": destination,
					"reason": "Required hull still needs earned resources, workshop or blueprint", "state": _snapshot()})
			return false
		h.main.depart(destination, false, true)
		await h.wait(2.85)
		if Game.where() == "battle":
			if not await _battle(h):
				return false
		if Game.state.voyage != null and Game.state.voyage.event != null:
			var kind := String(Game.state.voyage.event.kind)
			var choice := "refuse" if kind == "inspection" else ("ignore" if kind == "vessel" else "continue")
			if h.main._sea_dialog != null and is_instance_valid(h.main._sea_dialog):
				h.main._sea_dialog._choose(choice)
			else:
				h.main._on_sea_choice(choice)
			await h.frames(5)
		if String(Game.state.world.currentLocationId) == destination:
			await h.wait(0.2)
			return true
	return false


func _clear_location(h, location_id: String) -> bool:
	if String(Game.state.world.currentLocationId) != location_id:
		return false
	var kind := String(C.location(location_id).type)
	var order: Array = ["trial"] if kind == "arena" else (["gate", "east", "depths", "guardian"] if kind == "dungeon" else ["landing", "grove", "heart"])
	for room_id in order:
		if not _within_budget() or _region_fights >= MAX_REGION_FIGHTS:
			return false
		var room = C.room(location_id, room_id)
		if room == null:
			_stop_reason = "Unexpected normal route room " + location_id + ":" + String(room_id)
			return false
		if String(room.kind) in ["boss", "trial"] and not _ready_for_hard_fight(location_id, String(room_id)):
			_readiness_deferred = true
			h.record("guided_readiness_deferred", {"target": location_id + ":" + String(room_id),
				"reason": "Earned levels or regional counter equipment need preparation before another major fight", "state": _snapshot()})
			if not Rules.at_port(Game.state):
				await _tx(h, "return_for_counter_preparation", Actions.emergency_return(Game.state))
			await _port_prepare(h)
			return false
		if not await _stamina(h, int(room.cost)):
			if not Rules.at_port(Game.state):
				await _tx(h, "emergency_return_for_stamina", Actions.emergency_return(Game.state))
			await _port_prepare(h)
			return false
		if not await _tx(h, "enter:" + location_id + ":" + String(room_id), Actions.enter_room(Game.state, String(room_id))):
			return false
		if Game.where() == "battle" and not await _battle(h):
			return false
		if String(Game.state.world.currentLocationId) != location_id:
			return false
	return Rules.knowledge(Game.state, location_id) == "cleared"


func _stamina(h, needed: int) -> bool:
	for attempt in 12:
		if int(Game.state.ship.stamina) >= needed:
			return true
		if int(Game.state.inventory.supplies) > 0:
			if not await _tx(h, "use_supply", Actions.use_supply(Game.state)):
				break
		elif int(Game.state.inventory.food) > 2:
			if not await _tx(h, "serve_ration", Actions.serve_ration(Game.state)):
				break
		else:
			break
	return int(Game.state.ship.stamina) >= needed


func _battle(h) -> bool:
	if Game.state.encounter == null:
		return false
	_region_fights += 1
	_total_fights += 1
	var encounter: Dictionary = Game.state.encounter.duplicate(true)
	var region := String(encounter.def.get("regionId", C.location(String(Game.state.world.currentLocationId)).regionId))
	var kind := String(encounter.def.get("kind", "battle"))
	var sample := region + ":" + kind
	var sampled := not _sampled.has(sample)
	_sampled[sample] = true
	await h.frames(4)
	if h.main.battle_view == null:
		h.check("Battle view exists for " + sample, false)
		_stop_reason = "Battle view missing for active encounter"
		return false
	# These are normal player commands, recorded by Combat.issue and replayed
	# by the authoritative result resolver rather than editing simulation stats.
	h.main.battle_view._issue("stance", "defensive")
	h.main.battle_view._issue("priority", "survival")
	var focus = _focus_target(h.main.battle_view.sim)
	if focus != null:
		h.main.battle_view._issue("focus", focus)
	h.record("guided_battle_orders", {"attempt": encounter.attemptId, "stance": "defensive", "priority": "survival", "focus": focus})
	if sampled:
		await h.wait(0.8)
		await h.shot("normal_" + region + "_" + kind + "_opening")
		await h.wait(1.8)
		await h.shot("normal_" + region + "_" + kind + "_live")
	if h.main.battle_view != null:
		h.main.battle_view.skip_to_end()
	var waits := 0
	while h.main._report == null and waits < 100:
		await h.wait(0.1)
		waits += 1
	if h.main._report == null:
		_stop_reason = "Battle report did not open after normal Skip"
		h.check("Report appeared after " + sample, false)
		return false
	var summary: Dictionary = h.main._report.sm.duplicate(true)
	_last_outcome = String(summary.get("outcome", "unknown"))
	var fight_key := String(encounter.context.get("locationId", "sea")) + ":" + String(encounter.context.get("roomId", "sea"))
	if _last_outcome != "victory":
		_hard_failures[fight_key] = int(_hard_failures.get(fight_key, 0)) + 1
		h.record("guided_defeat_diagnosis", {"target": fight_key, "reason": summary.get("reason"),
			"enemy_level": encounter.def.get("level"), "counter": _counter_readiness(), "state": _snapshot()})
	if sampled:
		await h.shot("normal_" + region + "_" + kind + "_report")
	var recruit: Dictionary = summary.get("recruit", {}) if summary.get("recruit") is Dictionary else {}
	if bool(recruit.get("offered", false)):
		h.main._report._choose_recruit(not bool(recruit.get("full", false)))
	h.main._report._on_collect()
	await h.frames(4)
	await h.key(KEY_ENTER)
	await h.frames(5)
	h.record("normal_battle", {"attempt": encounter.attemptId, "region": region, "kind": kind,
		"context": encounter.context, "outcome": _last_outcome, "battle_seconds": summary.get("time", 0),
		"hpAvg": summary.get("hpAvg", 0), "recruitOffered": recruit.get("offered", false), "state": _snapshot()})
	return _last_outcome == "victory"


func _port_prepare(h) -> void:
	if not Rules.at_port(Game.state) or Game.state.encounter != null:
		return
	await _standby_offensive_pets(h)
	await _earned_rewards(h)
	for aid in Rules.emergency_needs(Game.state):
		await _tx(h, "port_aid:" + String(aid), Actions.emergency_aid(Game.state, String(aid)))
	if int(Game.state.inventory.gold) < 60:
		await _tx(h, "dock_work", Actions.dock_work(Game.state))
	await _sell_excess(h)
	# Counter equipment precedes optional repairs. Ship damage does not reduce
	# land combat statistics; spending the entire purse on it delayed recovery.
	await _equip_owned(h)
	await _manage_equipment_capacity(h)
	await _buy_upgrades(h)
	await _craft_upgrades(h)
	await _equip_owned(h)
	for member in Game.state.crew.duplicate(true):
		if member.injured:
			await _tx(h, "treat:" + String(member.id), Actions.treat(Game.state, String(member.id)))
	for aid in Rules.emergency_needs(Game.state):
		await _tx(h, "port_aid_after_equipment:" + String(aid), Actions.emergency_aid(Game.state, String(aid)))
	var prices: Dictionary = Rules.prices(Game.state, String(Game.state.world.currentLocationId))
	var qty := mini(Rules.food_capacity(Game.state) - int(Game.state.inventory.food), 12 - int(Game.state.inventory.food))
	qty = mini(qty, maxi(0, (int(Game.state.inventory.gold) - 30) / maxi(1, int(prices.food))))
	if qty > 0:
		await _tx(h, "buy_food", Actions.buy_goods(Game.state, "food", null, qty))
	await _stamina(h, mini(55, int(Game.state.ship.staminaMax)))
	await _upgrade_hull(h)
	if Game.state.crew.size() < mini(6, Rules.crew_capacity(Game.state)):
		var offers: Array = Rules.tavern_pool(Game.state, String(Game.state.world.currentLocationId))
		for offer in offers:
			if Game.state.crew.size() >= mini(6, Rules.crew_capacity(Game.state)):
				break
			if not offer.hired and int(offer.cost) <= int(Game.state.inventory.gold) - 50:
				await _tx(h, "recruit:" + str(offer.index), Actions.recruit(Game.state, int(offer.index)))
	await _specialize(h)
	await _arrange_formation(h)
	await _reinforce_upgrades(h)
	await _tx(h, "defensive_survival_tactics", Actions.set_tactics(Game.state, "defensive", "survival"))
	var repair: Dictionary = Rules.repair_cost(Game.state)
	if repair.needed and int(Game.state.inventory.gold) >= int(repair.gold) + 150 and Actions.has_cost(Game.state, {"gold": repair.gold, "materials": repair.materials}) == null:
		await _tx(h, "repair_after_preparation", Actions.repair_ship(Game.state))
	h.record("guided_port_prepared", {"counter": _counter_readiness(), "state": _snapshot()})


func _sell_excess(h) -> void:
	for id in Game.state.inventory.specialties.keys():
		var keep := 3
		for hull in C.HULLS:
			if int(hull.tier) == int(Game.state.ship.hullTier) + 1 and hull.cost.get("specialty") != null and hull.cost.specialty[0] == id:
				keep = maxi(keep, int(hull.cost.specialty[1]))
		# Learned counter recipes are cheap to duplicate. Save their ingredients
		# until the active formation has regional protection.
		var counter: Dictionary = _counter_readiness()
		for item_id in Game.state.inventory.recipes:
			var item: Dictionary = C.ITEMS[item_id]
			if item.get("recipe") and item.recipe.specialty[0] == id and item.get("resist", []).has(counter.hazard):
				keep = maxi(keep, int(6 - int(counter.protected)) + 3)
		var excess := int(Game.state.inventory.specialties[id]) - keep
		if excess > 0:
			await _tx(h, "sell_excess:" + String(id), Actions.sell_specialty(Game.state, String(id), excess))


func _equip_owned(h) -> void:
	for member in Game.state.crew.duplicate(true):
		for slot in ["weapon", "outfit", "accessory"]:
			var current = Rules.member(Game.state, member.id)
			var best_power: float = _gear_score(Game.state, current)
			var best: Dictionary = {}
			for item in Game.state.inventory.equipment:
				if Actions.is_equipped(Game.state, String(item.uid)) or String(C.ITEMS[item.itemId].slot) != slot:
					continue
				var result: Dictionary = Actions.equip(Game.state, String(member.id), slot, item.uid)
				if not result.get("ok", false):
					continue
				var power: float = _gear_score(result.state, Rules.member(result.state, member.id))
				if power > best_power:
					best_power = power
					best = result
			if not best.is_empty():
				await _tx(h, "equip_owned:" + String(member.id) + ":" + slot, best)


func _specialize(h) -> void:
	for member in Game.state.crew.duplicate(true):
		if not BRANCHES.has(member.classId):
			continue
		var branch := String(BRANCHES[member.classId])
		var cost: Dictionary = Rules.respec_cost(member)
		if C.CLASSES.has(branch) and Rules.qualified_for(member, branch) and int(cost.gold) <= int(Game.state.inventory.gold) - 80:
			await _tx(h, "class_branch:" + branch, Actions.change_class(Game.state, String(member.id), branch))
	await _equip_owned(h)


func _standby_offensive_pets(h) -> void:
	for pet in Game.state.pets.duplicate(true):
		if pet.assignment == null or pet.assignment.kind != "companion":
			continue
		var family: Dictionary = C.pet_family(String(pet.familyId))
		var ability_id: String = String(family.ability)
		if not C.data.PET_ABILITIES.get(ability_id, {}).has("target"):
			await _tx(h, "workaround_offensive_pet_standby:" + String(pet.id), Actions.assign_pet(Game.state, String(pet.id), null, null))
			h.record("known_bug_mitigation", {"pet": pet.id, "ability": ability_id,
				"action": "Standby through normal pet assignment. Product remains unmodified."})


func _upgrade_hull(h) -> void:
	var wanted_tier := int(Game.state.ship.hullTier) + 1
	for hull in C.HULLS:
		if int(hull.tier) != wanted_tier or Game.state.captain.regionsUnlocked.size() < int(hull.unlockRegion):
			continue
		if hull.get("blueprint") and not Game.state.inventory.blueprints.has(hull.blueprint):
			return
		if Actions.has_cost(Game.state, hull.cost) != null:
			return
		var port := String(Game.state.world.currentLocationId)
		for invest_attempt in 2:
			if Rules.port_track(Game.state, port, "workshop") >= 2:
				break
			var inv_cost = Rules.invest_cost(Game.state, port, "workshop")
			if inv_cost == null or int(Game.state.inventory.gold) < int(hull.cost.gold) + int(inv_cost.gold):
				return
			if not await _tx(h, "invest_workshop_for_hull", Actions.invest(Game.state, "workshop")):
				return
		if await _tx(h, "upgrade_hull:" + String(hull.id), Actions.upgrade_hull(Game.state, String(hull.id))):
			await h.shot("normal_hull_" + String(hull.id))
		return


func _buy_upgrades(h) -> void:
	var port := String(Game.state.world.currentLocationId)
	if Rules.port_track(Game.state, port, "market") < 2:
		var investment = Rules.invest_cost(Game.state, port, "market")
		if investment != null and int(Game.state.inventory.gold) >= int(investment.gold) + 100:
			await _tx(h, "invest_market_for_regional_gear", Actions.invest(Game.state, "market"))
	for member in Game.state.crew.duplicate(true):
		var best: Dictionary = {}
		var best_gain := 5.0
		for item_id in Rules.shop_items(Game.state, port):
			var item: Dictionary = C.ITEMS[item_id]
			if int(Rules.item_price(String(item_id))) > int(Game.state.inventory.gold) - 50:
				continue
			var buy: Dictionary = Actions.buy_item(Game.state, String(item_id))
			if not buy.get("ok", false):
				_preview_refused(h, "buy_item:" + String(item_id), buy)
				continue
			var eq: Dictionary = Actions.equip(buy.state, String(member.id), String(item.slot), buy.value)
			if not eq.get("ok", false):
				continue
			var gain: float = _gear_score(eq.state, Rules.member(eq.state, member.id)) - _gear_score(Game.state, Rules.member(Game.state, member.id))
			if gain > best_gain:
				best_gain = gain
				best = {"id": item_id, "slot": item.slot, "gain": gain}
		if not best.is_empty():
			var buy: Dictionary = Actions.buy_item(Game.state, String(best.id))
			if await _tx(h, "buy_counter_equipment:" + String(best.id), buy):
				await _tx(h, "equip_bought:" + String(member.id), Actions.equip(Game.state, String(member.id), String(best.slot), buy.value))
				# Owning an item teaches the actual recipe. Crafting following
				# copies saves scarce gold while using earned regional materials.
				await _craft_upgrades(h)
				await _equip_owned(h)


func _grind(h, region: Dictionary, needs_specialty: bool) -> void:
	if not _within_budget() or _region_fights >= MAX_REGION_FIGHTS:
		return
	if not Rules.at_port(Game.state):
		await _tx(h, "bank_before_repeat", Actions.emergency_return(Game.state))
	await _port_prepare(h)
	var island := String(region.locs[2])
	if Rules.sail_block(Game.state, island, false) == "err.hull_required":
		for candidate in C.REGIONS:
			var candidate_island := String(candidate.locs[2])
			if int(candidate.tier) < int(region.tier) and Rules.knowledge(Game.state, candidate_island) == "cleared" and Rules.sail_block(Game.state, candidate_island, false) != "err.hull_required":
				island = candidate_island
	if not await _travel(h, island):
		return
	# A short expedition keeps food spending proportional to earned rewards.
	# Elites award specialty, XP, mastery and gold; after a defeat use the
	# easier landing to recover without repeating the same failed boss.
	for lap in 3:
		if not _within_budget() or _region_fights >= MAX_REGION_FIGHTS or String(Game.state.world.currentLocationId) != island:
			break
		var target := "heart" if Actions.room_accessible(Game.state, island, "heart") and _last_outcome != "defeat" else "landing"
		var room: Dictionary = C.room(island, target)
		if not await _stamina(h, int(room.cost)):
			break
		if await _tx(h, "repeat_for_growth:" + island + ":" + target, Actions.enter_room(Game.state, target, {"repeat": true})):
			if Game.where() == "battle" and not await _battle(h):
				break
	h.record("normal_repeat", {"reason": "specialty" if needs_specialty else "growth_after_stalled_progress", "state": _snapshot()})
	if Game.state.encounter == null and not Rules.at_port(Game.state):
		await _tx(h, "bank_repeat_rewards", Actions.emergency_return(Game.state))
	await _port_prepare(h)


func _active_region() -> Dictionary:
	var status: Dictionary = Rules.main_status(Game.state)
	return C.region(String(status.regionId))


func _gear_score(state: Dictionary, member: Dictionary) -> float:
	var score := float(Rules.power(state, member))
	var hazard = _active_region().hazard
	var stats: Dictionary = Rules.member_stats(state, member)
	if hazard != null and (stats.resist.has(hazard) or float(stats.mods.get("hazardResist", 0)) > 0):
		score += 120.0
	return score


func _counter_readiness() -> Dictionary:
	var reg: Dictionary = _active_region()
	var protected := 0
	var total_levels := 0
	var equipped := 0
	var count := 0
	for member in Rules.active_crew(Game.state):
		var stats: Dictionary = Rules.member_stats(Game.state, member)
		count += 1
		total_levels += int(member.level)
		if reg.hazard == null or stats.resist.has(reg.hazard) or float(stats.mods.get("hazardResist", 0)) > 0:
			protected += 1
		if member.equipment.outfit != null:
			equipped += 1
	return {"region": reg.id, "hazard": reg.hazard, "protected": protected,
		"outfits": equipped, "crew": count, "average_level": float(total_levels) / maxi(1, count)}


func _ready_for_hard_fight(location_id: String, room_id: String) -> bool:
	var ready: Dictionary = _counter_readiness()
	var reg: Dictionary = C.region(String(C.location(location_id).regionId))
	var failures := int(_hard_failures.get(location_id + ":" + room_id, 0))
	var required_level := int(reg.level) + 2 + mini(8, failures * 2)
	if float(ready.average_level) < required_level:
		return false
	if reg.hazard != null and int(ready.protected) < mini(int(ready.crew), 3 + failures):
		return false
	return true


func _focus_target(sim: Dictionary) -> Variant:
	var best = null
	var best_score := -INF
	for enemy in sim.enemies:
		if not bool(enemy.alive) or bool(enemy.get("decoy", false)):
			continue
		var score := 0.0
		match String(enemy.get("archetype", "")):
			"healer": score = 1000.0
			"caster": score = 500.0
			_: score = 100.0 if bool(enemy.get("boss", false)) else 0.0
		score += 100.0 * (1.0 - float(enemy.hp) / maxi(1, int(enemy.maxHp)))
		if score > best_score:
			best_score = score
			best = enemy.uid
	return best


func _earned_rewards(h) -> void:
	for reg in C.REGIONS:
		for tier in Bestiary.claimable(Game.state, String(reg.id)):
			await _tx(h, "claim_earned_bestiary:" + String(reg.id) + ":" + str(tier), Actions.claim_bestiary_reward(Game.state, String(reg.id), int(tier)))
	for set_id in C.COLLECTION_SETS:
		if not Game.state.captain.get("collectionSets", []).has(set_id) and Collections.set_complete(Game.state, String(set_id)):
			await _tx(h, "claim_earned_collection:" + String(set_id), Actions.claim_collection_set(Game.state, String(set_id)))
	var port := String(Game.state.world.currentLocationId)
	for quest_id in C.QUESTS:
		var quest: Dictionary = C.QUESTS[quest_id]
		if quest.kind == "side" and quest.giverId == port and not Game.state.world.quests.has(quest_id) and quest.get("template", "") != "legend":
			await _tx(h, "accept_available_sidequest:" + String(quest_id), Actions.accept_quest(Game.state, String(quest_id)))
	for contract in Rules.active_contracts(Game.state):
		if contract.portId == port and contract.type == "hunt" and int(contract.progress) >= int(contract.need):
			await _tx(h, "claim_completed_hunt:" + String(contract.id), Actions.complete_contract(Game.state, String(contract.id)))
	for offer in Rules.contract_offers(Game.state, port):
		if offer.type == "hunt" and not Game.state.world.contracts.has(offer.id) and Rules.active_contracts(Game.state).size() < 3:
			await _tx(h, "accept_available_hunt:" + String(offer.id), Actions.accept_contract(Game.state, String(offer.id)))


func _preview_refused(h, action: String, result: Dictionary) -> void:
	var reason := String(result.get("reasonKey", "unknown"))
	var count := int(Game.state.inventory.equipment.size())
	var capacity: int = Rules.equip_capacity(Game.state)
	# Avoid repeating the same read-only candidate rejection for every crew
	# member. A changed count/capacity produces new diagnostic evidence.
	var key := action + ":" + reason + ":" + str(count) + ":" + str(capacity)
	if _preview_refusals.has(key):
		return
	_preview_refusals[key] = true
	var line := {"phase": "preview", "action": action, "ok": false,
		"reason": reason, "reason_params": result.get("reasonParams", {}),
		"equipment_count": count, "equipment_capacity": capacity,
		"gold": Game.state.inventory.gold, "tx": Game.state.envelope.lastTxId}
	_trace.append(line)
	h.record("normal_preview_refused", line)


func _protected_equipment(inst: Dictionary) -> bool:
	var item: Dictionary = C.ITEMS[inst.itemId]
	if bool(item.get("unique", false)) or bool(inst.get("unique", false)) or String(inst.itemId).begins_with("u_"):
		return true
	for key in ["quest", "questItem", "questId"]:
		if item.get(key) or inst.get(key):
			return true
	for quest in C.QUESTS.values():
		if quest.get("itemId") == inst.itemId or quest.get("equipmentId") == inst.itemId:
			return true
	return false


func _reserve_strength(inst: Dictionary) -> float:
	var item: Dictionary = C.ITEMS[inst.itemId]
	var stats: Dictionary = item.get("stats", {})
	return float(item.get("tier", 0)) * 100.0 + float(inst.get("reinforce", 0)) * 5.0 + float(stats.get("hp", 0)) / 6.0 + float(stats.get("atk", 0)) * 2.0 + float(stats.get("def", 0)) * 1.5 + float(stats.get("spd", 0)) * 2.0


func _manage_equipment_capacity(h) -> void:
	if not Rules.at_port(Game.state) or Game.state.encounter != null:
		return
	var wanted_free := 12
	var capacity: int = Rules.equip_capacity(Game.state)
	var before := int(Game.state.inventory.equipment.size())
	if capacity - before >= wanted_free:
		return
	h.record("guided_equipment_capacity", {"count": before, "capacity": capacity,
		"free": capacity - before, "policy": "Build reachable storage first; salvage obsolete spare gear only if still needed"})
	# Both are normal build controls. find_spot verifies reachability and that
	# existing reachable rooms stay connected; the action still validates the
	# hull tier, build limit, placement and earned construction costs.
	for facility_id in ["secure_locker", "cargo_hold"]:
		if Rules.fac_level(Game.state, facility_id, true) > 0:
			continue
		var definition: Dictionary = C.FACILITIES[facility_id]
		if int(Game.state.ship.hullTier) < int(definition.minTier) or int(Game.state.inventory.gold) < int(definition.cost.gold) + 50 or Actions.has_cost(Game.state, definition.cost) != null:
			continue
		var spot = Rules.find_spot(Game.state.ship, facility_id)
		if spot == null:
			h.record("guided_storage_unavailable", {"facility": facility_id, "reason": "No reachable placement without disconnecting rooms"})
			continue
		var build: Dictionary = Actions.build_facility(Game.state, facility_id, int(spot.deck), int(spot.x), int(spot.y), int(spot.rot))
		if not build.get("ok", false):
			_preview_refused(h, "build_storage:" + facility_id, build)
			continue
		var old_capacity: int = Rules.equip_capacity(Game.state)
		if await _tx(h, "build_storage_for_equipment:" + facility_id, build):
			capacity = Rules.equip_capacity(Game.state)
			h.check("Normal storage adds reachable equipment capacity", capacity > old_capacity)
			if capacity - int(Game.state.inventory.equipment.size()) >= wanted_free:
				return
	var reserve: Dictionary = {}
	var by_item: Dictionary = {}
	var item_count: Dictionary = {}
	for inst in Game.state.inventory.equipment:
		var id := String(inst.itemId)
		item_count[id] = int(item_count.get(id, 0)) + 1
		if not by_item.has(id) or _reserve_strength(inst) > _reserve_strength(by_item[id]):
			by_item[id] = inst
		for hazard in C.ITEMS[id].get("resist", []):
			if not reserve.has(hazard) or _reserve_strength(inst) > _reserve_strength(reserve[hazard]):
				reserve[hazard] = inst
	var reserved_uids: Array = []
	for inst in reserve.values():
		if not reserved_uids.has(inst.uid):
			reserved_uids.append(inst.uid)
	var candidates: Array = []
	var tier := int(_active_region().tier)
	for inst in Game.state.inventory.equipment:
		if Actions.is_equipped(Game.state, String(inst.uid)) or _protected_equipment(inst) or reserved_uids.has(inst.uid):
			continue
		var item: Dictionary = C.ITEMS[inst.itemId]
		var duplicate_spare: bool = int(item_count[inst.itemId]) > 1 and by_item[inst.itemId].uid != inst.uid
		if int(item.get("tier", 0)) < tier or duplicate_spare:
			candidates.append(inst.duplicate(true))
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _reserve_strength(a) < _reserve_strength(b))
	var salvaged: Array = []
	for inst in candidates:
		if Rules.equip_capacity(Game.state) - int(Game.state.inventory.equipment.size()) >= wanted_free:
			break
		if await _tx(h, "salvage_obsolete_spare:" + String(inst.itemId) + ":" + String(inst.uid), Actions.salvage(Game.state, String(inst.uid))):
			salvaged.append({"uid": inst.uid, "item": inst.itemId})
	h.record("guided_capacity_management", {"before": before, "after": Game.state.inventory.equipment.size(),
		"capacity": Rules.equip_capacity(Game.state), "salvaged": salvaged,
		"regional_resistance_reserves": reserved_uids,
		"protected": "All equipped gear, unique and quest equipment; strongest owned spare per regional resistance preserved"})


func _craft_upgrades(h) -> void:
	if not Rules.can_craft_here(Game.state):
		return
	for member in Game.state.crew.duplicate(true):
		var best: Dictionary = {}
		var best_gain := 5.0
		for item_id in Game.state.inventory.recipes:
			var cost = Rules.craft_cost(String(item_id), null, Game.state)
			if cost == null or int(cost.gold) > int(Game.state.inventory.gold) - 50 or Actions.has_cost(Game.state, cost) != null:
				continue
			var craft: Dictionary = Actions.craft_item(Game.state, String(item_id), null)
			if not craft.get("ok", false):
				_preview_refused(h, "craft_item:" + String(item_id), craft)
				continue
			var item: Dictionary = C.ITEMS[item_id]
			var equip: Dictionary = Actions.equip(craft.state, String(member.id), String(item.slot), craft.value)
			if not equip.get("ok", false):
				continue
			var gain: float = _gear_score(equip.state, Rules.member(equip.state, member.id)) - _gear_score(Game.state, Rules.member(Game.state, member.id))
			if gain > best_gain:
				best_gain = gain
				best = {"id": item_id, "slot": item.slot}
		if not best.is_empty():
			var craft: Dictionary = Actions.craft_item(Game.state, String(best.id), null)
			if await _tx(h, "craft_counter_equipment:" + String(best.id), craft):
				await _tx(h, "equip_crafted:" + String(member.id), Actions.equip(Game.state, String(member.id), String(best.slot), craft.value))


func _arrange_formation(h) -> void:
	var frontline: Array = []
	var center: Array = []
	var rear: Array = []
	for member in Game.state.crew:
		var base: String = C.base_class_of(String(member.classId))
		if base in ["guard", "beastkeeper", "brawler"]:
			frontline.append(member.id)
		elif base in ["medic", "gunner", "mystic", "cook", "quartermaster"]:
			rear.append(member.id)
		else:
			center.append(member.id)
	var ordered: Array = frontline + center + rear
	for slot in mini(6, ordered.size()):
		if Game.state.formation[slot] != ordered[slot]:
			await _tx(h, "arrange_formation:" + str(slot), Actions.set_formation(Game.state, slot, ordered[slot]))


func _reinforce_upgrades(h) -> void:
	if not Rules.can_reinforce_here(Game.state):
		return
	var ready: Dictionary = _counter_readiness()
	if int(ready.protected) < int(ready.crew):
		return
	var count := 0
	for member in Rules.active_crew(Game.state):
		for slot in ["weapon", "outfit"]:
			var inst = Rules.equip_inst(Game.state, member.equipment[slot])
			if inst == null or int(inst.get("reinforce", 0)) >= 2:
				continue
			var cost: Dictionary = Rules.reinforce_cost(inst, Game.state)
			if int(cost.gold) <= int(Game.state.inventory.gold) - 180 and Actions.has_cost(Game.state, cost) == null:
				if await _tx(h, "reinforce_equipment:" + String(inst.uid), Actions.reinforce(Game.state, String(inst.uid))):
					count += 1
			if count >= 2:
				return


func _save_checkpoint(h, region: String) -> void:
	if Game.state.encounter != null:
		return
	var ok: bool = bool(Game.save_manual(0))
	h.check("Manual save checkpoint " + region, ok)
	if not ok:
		return
	var read: Dictionary = SaveStore.read(SaveStore.manual_path(0))
	h.check("Read/hash checkpoint " + region, read.get("status", "") == "ok")
	if read.get("status", "") == "ok":
		var tx := int(Game.state.envelope.lastTxId)
		await h.load_state(read.record.state)
		h.check("Reload transaction checkpoint " + region, int(Game.state.envelope.lastTxId) == tx)
