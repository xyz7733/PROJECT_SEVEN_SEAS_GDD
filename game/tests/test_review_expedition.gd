## The optional west fight prepares only its own sample dungeon, using
## existing room progress. Old pending encounters keep their saved rules.
class_name TestReviewExpedition
extends RefCounted

const GLASS := ["crystal_vault", "refraction_maze"]
const STORM := ["drowned_beacon", "tempest_caverns"]


static func run(t: TestKit) -> void:
	for loc_id in GLASS + STORM:
		_test_route_choice(t, loc_id)
		_test_pending_old_save(t, loc_id)
	_test_scope(t)


static func _state_at(loc_id: String) -> Dictionary:
	var state := GS.create_new_game(8401)
	# A trained crew isolates route/rule assertions from combat difficulty.
	for member in state.crew:
		member.level = 60
	state.ship.stamina = Rules.stamina_max(state)
	state.world.currentLocationId = loc_id
	state.world.locations[loc_id].k = "visited"
	state.world.locations[loc_id].rooms = ["gate"]
	state.voyage = {"id": GS.next_id(state, "voy"), "originPortId": "brightquay", "at": loc_id,
		"route": null, "event": null, "site": {"locationId": loc_id, "current": "gate"}}
	return state


static func _decoys(def: Dictionary) -> int:
	var count := 0
	for wave in def.waves:
		for enemy in wave:
			if enemy.enemyId == "crystal_decoy":
				count += 1
	return count


static func _settle_west(t: TestKit, state: Dictionary, label: String) -> Dictionary:
	var attempt := String(state.encounter.attemptId)
	var ended := Actions.end_encounter(state, attempt, [])
	t.ok(ended.get("ok", false), label + " west fight enters report")
	if not ended.get("ok", false):
		return {}
	var result := Actions.resolve_encounter(ended.state, attempt, [], {"recruit": false})
	t.ok(result.get("ok", false), label + " west report settles")
	if not result.get("ok", false):
		return {}
	t.eq(result.value.outcome, "victory", label + " trained crew wins preparation fight")
	return result.state


static func _assert_prepared_definition(t: TestKit, state: Dictionary, def: Dictionary, loc_id: String, label: String) -> void:
	var removed: Array = World.preparation(state, loc_id).removedmods
	for modifier in removed:
		t.ok(not def.modifiers.has(modifier), label + " removes " + String(modifier))
	var sim := Combat.create({"allies": Actions.build_allies(state, null), "waves": def.waves,
		"modifiers": def.modifiers, "seed": 8402, "stance": "balanced", "priority": "auto"})
	if GLASS.has(loc_id):
		t.eq(_decoys(def), 0, label + " removes actual decoy wave entries")
		for enemy in sim.enemies:
			t.ok(not bool(enemy.decoy), label + " creates no decoy combat unit")
		t.ok(not Combat.hazards(sim).has("glare"), label + " combat has no glare hazard")
	else:
		t.ok(not Combat.hazards(sim).has("storm"), label + " combat has no storm hazard")
		var normal := World.encounter_for(loc_id, String(def.roomId))
		# Beacon shelter changes no enemy/intent behavior or other modifier.
		var expected: Array = normal.modifiers.filter(func(value): return value != "storm")
		t.eq(def.modifiers, expected, label + " preserves all non-storm mechanics")
		t.eq(var_to_bytes(def.waves), var_to_bytes(normal.waves), label + " preserves enemies and intent skills")


static func _test_route_choice(t: TestKit, loc_id: String) -> void:
	var state := _state_at(loc_id)
	var untouched := var_to_bytes(state)
	var stamina := int(state.ship.stamina)
	var prep := World.preparation(state, loc_id)
	t.eq(prep.room, "west", loc_id + " names the optional west fight")
	t.eq(prep.id, "glass_lenses" if GLASS.has(loc_id) else "storm_beacon", loc_id + " preparation identity")
	t.eq(prep.active, false, loc_id + " starts unprepared")
	t.eq(prep.removedmods, [], loc_id + " removes nothing before winning west")
	var east := Actions.enter_room(state, "east")
	t.ok(east.get("ok", false), loc_id + " direct east route is available")
	if not east.get("ok", false):
		return
	t.eq(east.state.encounter, null, loc_id + " east remains a resource room")
	t.eq(int(east.state.ship.stamina), stamina - 6, loc_id + " direct east spends six stamina")
	t.eq(World.preparation(east.state, loc_id).active, false, loc_id + " east does not grant preparation")
	var west_preview := World.encounter_for_state(state, loc_id, "west")
	var west := Actions.enter_room(state, "west")
	t.ok(west.get("ok", false), loc_id + " optional west fight is available")
	if not west.get("ok", false):
		return
	t.eq(var_to_bytes(state), untouched, loc_id + " route previews/actions leave input untouched")
	t.eq(int(west.state.ship.stamina), stamina - 10, loc_id + " west spends ten stamina")
	t.eq(var_to_bytes(west.state.encounter.def), var_to_bytes(west_preview), loc_id + " UI preview matches actual west fight")
	t.eq(World.preparation(west.state, loc_id).active, false, loc_id + " entering west does not grant preparation")
	t.ok(west.state.encounter.def.modifiers.has("glare" if GLASS.has(loc_id) else "storm"), loc_id + " west fight itself keeps regional hazard")
	if GLASS.has(loc_id):
		t.ok(_decoys(west.state.encounter.def) > 0, loc_id + " west fight still includes decoys")
	var won := _settle_west(t, west.state, loc_id)
	if won.is_empty():
		return
	t.ok(won.world.locations[loc_id].rooms.has("west"), loc_id + " victory records existing west room progress")
	t.eq(World.preparation(won, loc_id).active, true, loc_id + " winning west activates local preparation")
	var loaded: Dictionary = bytes_to_var(var_to_bytes(won))
	t.eq(World.preparation(loaded, loc_id), World.preparation(won, loc_id), loc_id + " room-based preparation survives save serialization")
	var depth_preview := World.encounter_for_state(loaded, loc_id, "depths")
	var depth := Actions.enter_room(loaded, "depths")
	t.ok(depth.get("ok", false), loc_id + " west unlocks the onward battle")
	if depth.get("ok", false):
		t.eq(var_to_bytes(depth.state.encounter.def), var_to_bytes(depth_preview), loc_id + " prepared preview matches actual encounter")
		_assert_prepared_definition(t, loaded, depth.state.encounter.def, loc_id, loc_id + " depths")
	var moved := Actions.enter_room(loaded, "west")
	t.ok(moved.get("ok", false), loc_id + " cleared west remains freely revisitable")
	t.eq(int(moved.state.ship.stamina), int(loaded.ship.stamina), loc_id + " cleared-room movement costs no extra stamina")
	var repeat := Actions.enter_room(loaded, "west", {"repeat": true})
	t.ok(repeat.get("ok", false), loc_id + " prepared west can be repeated normally")
	if repeat.get("ok", false):
		t.eq(int(repeat.state.ship.stamina), int(loaded.ship.stamina) - 10, loc_id + " repeated west still spends normal stamina")
		# Repeats vary enemies; compare local rules rather than a fixed variant.
		for modifier in World.preparation(loaded, loc_id).removedmods:
			t.ok(not repeat.state.encounter.def.modifiers.has(modifier), loc_id + " repeated battle keeps preparation")
		if GLASS.has(loc_id):
			t.eq(_decoys(repeat.state.encounter.def), 0, loc_id + " repeated west does not restore decoys")
	var sister := String(C.region(String(C.location(loc_id).regionId)).locs[6 if int(C.location(loc_id).slot) == 5 else 5])
	t.eq(World.preparation(loaded, sister).active, false, loc_id + " preparation does not leak to the other dungeon")
	var tired := _state_at(loc_id)
	tired.ship.stamina = 9
	var tired_bytes := var_to_bytes(tired)
	var blocked := Actions.enter_room(tired, "west")
	t.eq(blocked.get("reasonKey"), "err.no_stamina", loc_id + " west cannot be entered for free")
	t.eq(var_to_bytes(tired), tired_bytes, loc_id + " refused preparation fight changes nothing")


static func _test_pending_old_save(t: TestKit, loc_id: String) -> void:
	# Before this feature, an old save could already have west cleared while
	# a later battle still contained the original regional rules.
	var old := _state_at(loc_id)
	old.world.locations[loc_id].rooms.append("west")
	var legacy := World.encounter_for(loc_id, "depths")
	var attempt := Actions.start_encounter(old, legacy, {"type": "room", "locationId": loc_id, "roomId": "depths"})
	var def_bytes := var_to_bytes(old.encounter.def)
	var spec_bytes := var_to_bytes(old.encounter.spec)
	var loaded: Dictionary = bytes_to_var(var_to_bytes(old))
	t.eq(World.preparation(loaded, loc_id).active, true, loc_id + " old west-clear save recognizes preparation")
	var next_def := World.encounter_for_state(loaded, loc_id, "depths")
	t.ok(next_def.modifiers != legacy.modifiers, loc_id + " only newly generated encounters use preparation")
	t.eq(var_to_bytes(loaded.encounter.def), def_bytes, loc_id + " loading/preview preserves pending definition")
	t.eq(var_to_bytes(loaded.encounter.spec), spec_bytes, loc_id + " loading/preview preserves pending replay spec")
	var ended := Actions.end_encounter(loaded, attempt, [])
	t.ok(ended.get("ok", false), loc_id + " old pending encounter can still end")
	if not ended.get("ok", false):
		return
	t.eq(var_to_bytes(ended.state.encounter.def), def_bytes, loc_id + " report phase keeps frozen old definition")
	t.eq(var_to_bytes(ended.state.encounter.spec), spec_bytes, loc_id + " report phase keeps frozen old replay spec")
	var settled := Actions.resolve_encounter(ended.state, attempt, [], {"recruit": false})
	t.ok(settled.get("ok", false), loc_id + " old pending report settles normally")
	if settled.get("ok", false):
		var repeat := Actions.enter_room(settled.state, "depths", {"repeat": true})
		t.ok(repeat.get("ok", false), loc_id + " a new repeat after old settlement is available")
		if repeat.get("ok", false):
			for modifier in World.preparation(settled.state, loc_id).removedmods:
				t.ok(not repeat.state.encounter.def.modifiers.has(modifier), loc_id + " new repeat uses persisted preparation")


static func _test_scope(t: TestKit) -> void:
	var state := GS.create_new_game(8403)
	var region_bytes := var_to_bytes(C.REGIONS)
	for loc_id in C.LOCATIONS:
		if C.room(String(loc_id), "west") != null:
			state.world.locations[loc_id].rooms.append("west")
	var applicable := 0
	for loc_id in C.LOCATIONS:
		var prep := World.preparation(state, String(loc_id))
		if not prep.is_empty():
			applicable += 1
			continue
		for room in C.rooms(String(loc_id)):
			if not Actions.BATTLE_ROOMS.has(room.kind):
				continue
			var opts := {"variant": 17, "forceRare": true, "forceVariant": "armored"}
			t.eq(var_to_bytes(World.encounter_for_state(state, String(loc_id), String(room.id), opts)),
				var_to_bytes(World.encounter_for(String(loc_id), String(room.id), opts)),
				"unrelated encounter unchanged " + String(loc_id) + ":" + String(room.id))
		var loc: Dictionary = C.location(String(loc_id))
		if loc.type == "arena" and C.world.LEGENDS.has(loc.regionId):
			t.eq(var_to_bytes(World.encounter_for_state(state, String(loc_id), "trial", {"legend": true})),
				var_to_bytes(World.encounter_for(String(loc_id), "trial", {"legend": true})),
				"legend rules unchanged " + String(loc_id))
	t.eq(applicable, 4, "preparation applies only to the four sample dungeons")
	t.eq(World.preparation(state, "missing_location"), {}, "unknown locations have no preparation")
	t.eq(var_to_bytes(C.REGIONS), region_bytes, "preparation never mutates global region rules")
