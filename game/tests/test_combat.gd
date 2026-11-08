## Combat smoke tests: every catalogue enemy resolves, variants apply, and
## replaying the same spec produces byte-identical results.
class_name TestCombat
extends RefCounted


static func run(t: TestKit) -> void:
	_test_catalogue_battles(t)
	_test_variants(t)
	_test_summon_cap(t)


static func _def_for(enemy_id: String) -> Dictionary:
	var e = World.enemy(enemy_id)
	var level := 1
	if e != null and e.get("boss", false):
		level = 3
	return {"id": "test:" + enemy_id, "regionId": String(e.get("regionId", "dawnwater")) if e != null else "dawnwater",
		"kind": "battle", "level": level, "waves": [[{"enemyId": enemy_id, "level": level}]],
		"modifiers": [], "arena": "ship", "retreat": {"escapeSecs": 3}}


static func _test_catalogue_battles(t: TestKit) -> void:
	var state := GS.create_new_game(3001)
	var ids := Bestiary.all_ids()
	t.ok(ids.size() >= 40, "catalogue battle count")
	var completed := 0
	for id in ids:
		var def := _def_for(String(id))
		Actions.start_encounter(state, def, {"type": "battle", "regionId": def.regionId})
		var spec: Dictionary = state.encounter.spec
		var r1 := Combat.resolve(spec, [])
		var r2 := Combat.resolve(spec, [])
		if r1.get("outcome") != null:
			completed += 1
		if var_to_bytes(r1) != var_to_bytes(r2):
			t.ok(false, "non-deterministic combat for " + String(id))
	t.eq(completed, ids.size(), "all catalogue battles finish")


static func _test_variants(t: TestKit) -> void:
	var state := GS.create_new_game(3002)
	var def := _def_for("tide_jelly")
	def.waves = [[{"enemyId": "tide_jelly", "level": 1, "variant": "alpha"}]]
	Actions.start_encounter(state, def, {"type": "battle", "regionId": "dawnwater"})
	var sim := Combat.create(state.encounter.spec)
	var unit: Dictionary = sim.enemies[0]
	t.eq(String(unit.get("variantId", "")), "alpha", "variant id copied to unit")
	t.ok(String(unit.get("variantTint", "")) != "", "variant tint present")
	var base := Combat.enemy_unit({"enemyId": "tide_jelly", "level": 1}, 0, 0, 1.0)
	t.ok(int(unit.maxHp) > int(base.maxHp), "alpha increases max hp")
	var res := Combat.resolve(state.encounter.spec, [])
	t.ok(res.get("outcome") != null, "variant battle finishes")


static func _test_summon_cap(t: TestKit) -> void:
	var state := GS.create_new_game(3003)
	var def := _def_for("spore_matriarch")
	Actions.start_encounter(state, def, {"type": "battle", "regionId": "verdant_maw"})
	var sim := Combat.run(state.encounter.spec, [], 3600)
	var living_enemies := 0
	for e in sim.enemies:
		if e.alive:
			living_enemies += 1
	t.ok(living_enemies <= 8, "summon cap respected")
	t.ok(sim.outcome != null or int(sim.tick) >= 3600, "summoner battle terminates")
