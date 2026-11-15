extends RefCounted
## Normal-rules campaign run for the external, fullscreen release harness.
## Every progress/resource change goes through the shipped Actions API. No
## seeded late-game fixtures, XP grants, invulnerability, or direct state edits.

const MAX_REGION_FIGHTS := 25
const MAX_SECONDS := 900.0
const BRANCHES := {"guard": "guardian", "duelist": "blade_dancer", "gunner": "sharpshooter", "medic": "surgeon"}
var _start_usec := 0
var _region_fights := 0
var _total_fights := 0
var _sampled := {}
var _trace: Array = []
var _stop_reason := ""
var _last_outcome := ""


func run(h) -> void:
	_start_usec = Time.get_ticks_usec()
	await h.new_game(7)
	h.record("campaign_method", {"seed": 7, "normal_rules": true, "direct_state_edits": false,
		"input": "Shipped action/report APIs and engine input, not OS mouse input",
		"battle_skip": "Normal shipped Skip control after sampled live action",
		"max_region_fights": MAX_REGION_FIGHTS, "wall_seconds_budget": MAX_SECONDS})
	Settings.set_value("battleSpeed", 4)
	await h.wait(0.7)
	await h.shot("normal_new_game")
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
			if attempts > 45 or _region_fights >= MAX_REGION_FIGHTS:
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
				if stagnant >= 3:
					await _grind(h, reg, false)
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
	var result := {"normal_campaign_complete": complete, "stop_reason": _stop_reason,
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
				_stop_reason = "Progression blocked by required hull; normal resources/blueprint insufficient"
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
	for aid in Rules.emergency_needs(Game.state):
		await _tx(h, "port_aid:" + String(aid), Actions.emergency_aid(Game.state, String(aid)))
	for member in Game.state.crew.duplicate(true):
		if member.injured:
			await _tx(h, "treat:" + String(member.id), Actions.treat(Game.state, String(member.id)))
	var repair: Dictionary = Rules.repair_cost(Game.state)
	if repair.needed and Actions.has_cost(Game.state, {"gold": repair.gold, "materials": repair.materials}) == null:
		await _tx(h, "repair_ship", Actions.repair_ship(Game.state))
	if int(Game.state.inventory.gold) < 60:
		await _tx(h, "dock_work", Actions.dock_work(Game.state))
	await _sell_excess(h)
	var prices: Dictionary = Rules.prices(Game.state, String(Game.state.world.currentLocationId))
	var qty := mini(Rules.food_capacity(Game.state) - int(Game.state.inventory.food), 24 - int(Game.state.inventory.food))
	qty = mini(qty, maxi(0, (int(Game.state.inventory.gold) - 25) / maxi(1, int(prices.food))))
	if qty > 0:
		await _tx(h, "buy_food", Actions.buy_goods(Game.state, "food", null, qty))
	await _stamina(h, mini(75, int(Game.state.ship.staminaMax)))
	await _upgrade_hull(h)
	# Fill the available formation with actual tavern offers, reserving food money.
	if Game.state.crew.size() < mini(6, Rules.crew_capacity(Game.state)):
		var offers: Array = Rules.tavern_pool(Game.state, String(Game.state.world.currentLocationId))
		for offer in offers:
			if Game.state.crew.size() >= mini(6, Rules.crew_capacity(Game.state)):
				break
			if not offer.hired and int(offer.cost) <= int(Game.state.inventory.gold) - 100:
				await _tx(h, "recruit:" + str(offer.index), Actions.recruit(Game.state, int(offer.index)))
	await _equip_owned(h)
	await _specialize(h)
	await _hatch(h)
	await _buy_upgrades(h)


func _sell_excess(h) -> void:
	for id in Game.state.inventory.specialties.keys():
		var keep := 8 if id in ["ember_ore", "prism_quartz", "leviathan_scale"] else 3
		var excess := int(Game.state.inventory.specialties[id]) - keep
		if excess > 0:
			await _tx(h, "sell_excess:" + String(id), Actions.sell_specialty(Game.state, String(id), excess))


func _equip_owned(h) -> void:
	for member in Game.state.crew.duplicate(true):
		for slot in ["weapon", "outfit", "accessory"]:
			var current = Rules.member(Game.state, member.id)
			var best_power := Rules.power(Game.state, current)
			var best: Dictionary = {}
			for item in Game.state.inventory.equipment:
				if Actions.is_equipped(Game.state, String(item.uid)) or String(C.ITEMS[item.itemId].slot) != slot:
					continue
				var result: Dictionary = Actions.equip(Game.state, String(member.id), slot, item.uid)
				if not result.get("ok", false):
					continue
				var power := Rules.power(result.state, Rules.member(result.state, member.id))
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
		if Rules.qualified_for(member, branch) and int(cost.gold) <= int(Game.state.inventory.gold) - 250:
			await _tx(h, "class_branch:" + branch, Actions.change_class(Game.state, String(member.id), branch))
	await _equip_owned(h)


func _hatch(h) -> void:
	if not Game.state.pets.is_empty() or Game.state.inventory.eggs.is_empty():
		return
	if Rules.fac_level(Game.state, "hatchery", true) == 0:
		if int(Game.state.inventory.gold) < 200 or int(Game.state.inventory.materials) < 15:
			return
		var spot = Rules.find_spot(Game.state.ship, "hatchery")
		if spot == null:
			return
		if not await _tx(h, "build_hatchery", Actions.build_facility(Game.state, "hatchery", int(spot.deck), int(spot.x), int(spot.y), int(spot.rot))):
			return
	var inputs := ["ing:fire_pepper"] if int(Game.state.inventory.ingredients.get("fire_pepper", 0)) > 0 else []
	if inputs.is_empty():
		return
	if await _tx(h, "hatch_initial_egg", Actions.hatch_egg(Game.state, String(Game.state.inventory.eggs[0].id), inputs)):
		var pet: Dictionary = Game.state.pets.back()
		if Rules.pet_roles(pet).has("companion"):
			await _tx(h, "assign_companion", Actions.assign_pet(Game.state, String(pet.id), "companion", Game.state.formation[0]))
		await h.shot("normal_first_hatched_pet")


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
	if Rules.port_track(Game.state, port, "market") < 2 and int(Game.state.inventory.gold) > 700:
		await _tx(h, "invest_market", Actions.invest(Game.state, "market"))
	var bought := 0
	for member in Game.state.crew.duplicate(true):
		if bought >= 2:
			break
		for item_id in Rules.shop_items(Game.state, port):
			var item: Dictionary = C.ITEMS[item_id]
			if int(item.price) > int(Game.state.inventory.gold) - 350:
				continue
			var buy: Dictionary = Actions.buy_item(Game.state, String(item_id))
			if not buy.get("ok", false):
				continue
			var eq: Dictionary = Actions.equip(buy.state, String(member.id), String(item.slot), buy.value)
			if not eq.get("ok", false):
				continue
			if Rules.power(eq.state, Rules.member(eq.state, member.id)) > Rules.power(Game.state, Rules.member(Game.state, member.id)) + 8:
				if await _tx(h, "buy_equipment:" + String(item_id), buy):
					await _tx(h, "equip_bought", Actions.equip(Game.state, String(member.id), String(item.slot), buy.value))
					bought += 1
					break


func _grind(h, region: Dictionary, needs_specialty: bool) -> void:
	if not _within_budget() or _region_fights >= MAX_REGION_FIGHTS:
		return
	if not Rules.at_port(Game.state):
		await _tx(h, "bank_before_repeat", Actions.emergency_return(Game.state))
	await _port_prepare(h)
	var island := String(region.locs[2])
	if not await _travel(h, island):
		return
	var target := "heart" if Actions.room_accessible(Game.state, island, "heart") else "landing"
	var room: Dictionary = C.room(island, target)
	if not await _stamina(h, int(room.cost)):
		return
	if await _tx(h, "repeat_for_growth:" + island + ":" + target, Actions.enter_room(Game.state, target, {"repeat": true})):
		if Game.where() == "battle":
			await _battle(h)
	h.record("normal_repeat", {"reason": "specialty" if needs_specialty else "growth_after_stalled_progress", "state": _snapshot()})
	if Game.state.encounter == null and not Rules.at_port(Game.state):
		await _tx(h, "bank_repeat_rewards", Actions.emergency_return(Game.state))


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
