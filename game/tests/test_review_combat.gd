## Regression coverage for optional pet targets and deterministic settlement.
class_name TestReviewCombat
extends RefCounted


static func run(t: TestKit) -> void:
	_test_offensive_pets(t)
	_test_owner_pets(t)
	_test_allied_pets(t)
	_test_commanded_pet(t)
	_test_offensive_pet_replay_and_settlement(t)


static func _definition() -> Dictionary:
	return {"id": "review:pet", "locationId": "gull_rock", "roomId": "landing",
		"regionId": "dawnwater", "kind": "battle", "level": 3, "arena": "island",
		"waves": [[{"enemyId": "reef_crab", "level": 3}]], "modifiers": [],
		"retreat": {"escapeSecs": 3}, "restriction": null, "legend": false}


static func _sim(ability: String) -> Dictionary:
	var state := GS.create_new_game(8301)
	Actions.start_encounter(state, _definition(), {"type": "room", "locationId": "gull_rock", "roomId": "landing"})
	var sim := Combat.create(state.encounter.spec)
	# Keep the isolated ability assertions independent of random aptitudes,
	# defensive passives, dodge and killing blows.
	for ally in sim.allies:
		ally.mods = {}
		ally.props = []
	ally_pet(sim.allies[0], ability)
	var enemy: Dictionary = sim.enemies[0]
	enemy.mods = {}
	enemy.def = 0.0
	enemy.maxHp = 1000
	enemy.hp = 1000
	return sim


static func ally_pet(owner: Dictionary, ability: String) -> void:
	owner.atk = 40.0
	owner.pet = {"ability": ability, "mult": 1.25, "timer": 0.0}


static func _test_offensive_pets(t: TestKit) -> void:
	for ability in ["splash", "burn", "mark", "lull", "maul"]:
		t.ok(not C.data.PET_ABILITIES[ability].has("target"), ability + " exercises omitted enemy target")
		var sim := _sim(ability)
		var enemy: Dictionary = sim.enemies[0]
		var ally_hp: Array = []
		for ally in sim.allies:
			ally_hp.append(ally.hp)
		Combat.pet_act(sim, sim.allies[0])
		t.ok(int(enemy.hp) < 1000, ability + " damages its enemy")
		for i in sim.allies.size():
			t.eq(sim.allies[i].hp, ally_hp[i], ability + " does not damage ally " + str(i))
		match ability:
			"splash": t.near(float(enemy.st.slow), 2.0, "splash applies slow")
			"burn":
				t.ok(float(enemy.st.dot) > 0.0, "burn applies damage over time")
				t.near(float(enemy.st.dotT), 4.0, "burn retains its duration")
			"mark": t.near(float(enemy.st.mark), 4.0, "mark applies mark")
			"lull": t.near(float(enemy.st.stun), 1.5, "lull applies stun")
			"maul":
				var hit := false
				for event in sim.log:
					if event.get("type") == "hit" and event.get("skill") == "pet_maul":
						hit = true
				t.ok(hit, "maul records a damaging pet hit")


static func _test_owner_pets(t: TestKit) -> void:
	for ability in ["shell", "ward"]:
		var sim := _sim(ability)
		var owner: Dictionary = sim.allies[0]
		Combat.pet_act(sim, owner)
		t.ok(int(owner.st.shield) > 0, ability + " shields owner")
		t.eq(int(sim.allies[1].st.shield), 0, ability + " does not shield another ally")
		t.eq(int(sim.enemies[0].hp), 1000, ability + " does not attack enemy")
		if ability == "ward":
			t.near(float(owner.st.taunt), 3.0, "ward taunts through owner")
	var mend := _sim("mend")
	var owner: Dictionary = mend.allies[0]
	owner.hp = int(owner.maxHp) - 10
	var owner_hp := int(owner.hp)
	mend.allies[1].hp = 1
	mend.allies[2].hp = 0
	mend.allies[2].alive = false
	Combat.pet_act(mend, owner)
	# Preserve the shipped mend behavior: its owner branch heals the lowest
	# living ally. Changing that selection would be a separate balance edit.
	t.ok(int(mend.allies[1].hp) > 1, "mend heals the lowest living ally")
	t.eq(int(owner.hp), owner_hp, "mend retains existing lowest-ally selection")
	t.eq(int(mend.allies[2].hp), 0, "mend does not revive dead allies")
	t.eq(int(mend.enemies[0].hp), 1000, "mend does not attack enemy")


static func _test_allied_pets(t: TestKit) -> void:
	var gust := _sim("gust")
	gust.allies[0].meter = 10.0
	gust.allies[1].meter = 90.0
	gust.allies[2].alive = false
	gust.allies[2].hp = 0
	gust.allies[2].meter = 4.0
	gust.enemies[0].meter = 17.0
	Combat.pet_act(gust, gust.allies[0])
	t.near(float(gust.allies[0].meter), 28.75, "gust advances owner meter")
	t.near(float(gust.allies[1].meter), 99.0, "gust caps allied meter")
	t.near(float(gust.allies[2].meter), 4.0, "gust ignores dead allies")
	t.near(float(gust.enemies[0].meter), 17.0, "gust does not advance enemies")
	var radiance := _sim("radiance")
	for ally in radiance.allies:
		ally.hp = int(ally.maxHp) / 2
	radiance.allies[2].alive = false
	radiance.allies[2].hp = 0
	var before: Array = []
	for ally in radiance.allies:
		before.append(ally.hp)
	Combat.pet_act(radiance, radiance.allies[0])
	for i in radiance.allies.size():
		if i == 2:
			t.eq(int(radiance.allies[i].hp), 0, "radiance does not revive dead ally")
		else:
			t.ok(int(radiance.allies[i].hp) > int(before[i]), "radiance heals living ally " + str(i))
	t.eq(int(radiance.enemies[0].hp), 1000, "radiance does not attack enemy")


static func _pet_hits(sim: Dictionary) -> Array:
	return sim.log.filter(func(event): return event.get("type") == "hit" and event.get("skill") == "pet_splash")


static func _pet_events(sim: Dictionary) -> Array:
	return sim.log.filter(func(event): return event.get("type") == "pet")


static func _test_commanded_pet(t: TestKit) -> void:
	var natural := _sim("splash")
	natural.allies[0].crit = 0.0
	Combat.pet_act(natural, natural.allies[0])
	var commanded := _sim("splash")
	var owner: Dictionary = commanded.allies[0]
	owner.crit = 0.0
	owner.pet.timer = 2.5
	Combat.resolve_skill(commanded, owner, C.SKILLS.sic_em, "sic_em", commanded.enemies[0])
	var hits := _pet_hits(commanded)
	var baseline := _pet_hits(natural)
	t.eq(hits.size(), 1, "Sic Em immediately produces a real pet hit")
	t.eq(_pet_events(commanded).size(), 1, "Sic Em logs the commanded companion action")
	if hits.size() == 1 and baseline.size() == 1:
		t.ok(int(hits[0].amount) > 0, "commanded pet hit damages its enemy")
		t.eq(int(hits[0].amount), U.jround(float(baseline[0].amount) * 1.6), "Sic Em uses its declared 1.6 pet strength")
	t.near(float(owner.pet.timer), 0.0, "commanded action restarts the natural pet timer")
	t.near(float(commanded.enemies[0].st.slow), 2.0, "commanded splash retains its slow effect")
	var empty := _sim("splash")
	empty.enemies[0].hp = 0
	empty.enemies[0].alive = false
	Combat.resolve_skill(empty, empty.allies[0], C.SKILLS.sic_em, "sic_em", empty.enemies[0])
	t.eq(_pet_hits(empty).size(), 0, "Sic Em does not hit a dead enemy")
	t.eq(_pet_events(empty).size(), 0, "Sic Em creates no empty-target pet strike")
	t.eq(int(empty.enemies[0].hp), 0, "dead target remains untouched")
	var no_pet := _sim("splash")
	no_pet.allies[0].pet = null
	Combat.resolve_skill(no_pet, no_pet.allies[0], C.SKILLS.sic_em, "sic_em", no_pet.enemies[0])
	t.eq(_pet_events(no_pet).size(), 0, "Sic Em without a companion remains safe")
	t.ok(int(no_pet.enemies[0].hp) < 1000, "Sic Em retains its ordinary weapon damage without a pet")
	var dead_owner := _sim("splash")
	dead_owner.allies[0].alive = false
	dead_owner.allies[0].hp = 0
	Combat.pet_act(dead_owner, dead_owner.allies[0], 1.6)
	t.eq(_pet_events(dead_owner).size(), 0, "dead owner cannot command a companion strike")


static func _test_offensive_pet_replay_and_settlement(t: TestKit) -> void:
	var state := GS.create_new_game(8302)
	var owner: Dictionary = state.crew[0]
	state.pets.append({"id": GS.next_id(state, "pet"), "familyId": "tidefin",
		"speciesId": "tidefin_companion", "affinity": "blue", "level": 1,
		"xp": 0, "prime": false, "evolved": false,
		"assignment": {"kind": "companion", "target": owner.id}})
	var attempt := Actions.start_encounter(state, _definition(), {"type": "room", "locationId": "gull_rock", "roomId": "landing"})
	t.eq(String(state.encounter.spec.allies[0].pet.ability), "splash", "real companion enters encounter spec")
	var replay1 := Combat.resolve(state.encounter.spec, [])
	var replay2 := Combat.resolve(state.encounter.spec, [])
	t.eq(var_to_bytes(replay1), var_to_bytes(replay2), "offensive companion replay is deterministic")
	t.eq(String(replay1.outcome), "victory", "offensive companion fight resolves successfully")
	var before_hash := SaveStore.state_hash(state)
	var ended := Actions.end_encounter(state, attempt, [])
	t.ok(ended.get("ok", false), "pet encounter can enter report phase")
	t.eq(SaveStore.state_hash(state), before_hash, "ending a pet encounter leaves input state untouched")
	if not ended.get("ok", false):
		return
	var preview_hash := SaveStore.state_hash(ended.state)
	var preview := Actions.preview_encounter(ended.state)
	t.ok(preview.get("ok", false), "pet settlement preview succeeds")
	t.eq(SaveStore.state_hash(ended.state), preview_hash, "pet preview does not grant rewards")
	var settled := Actions.resolve_encounter(ended.state, attempt, [], {"recruit": false})
	t.ok(settled.get("ok", false), "pet report settles normally")
	if not settled.get("ok", false):
		return
	t.eq(int(settled.state.captain.stats.battlesWon), 1, "pet battle victory is granted once")
	var loaded: Dictionary = bytes_to_var(var_to_bytes(ended.state))
	var after_load := Actions.resolve_encounter(loaded, attempt, [], {"recruit": false})
	t.eq(var_to_bytes(settled.value), var_to_bytes(after_load.value), "saved pending pet report settles identically")
	var duplicate := Actions.resolve_encounter(settled.state, attempt, [], {"recruit": false})
	t.ok(duplicate.get("duplicate", false), "duplicate pet settlement is recognized")
	t.eq(var_to_bytes(duplicate.state), var_to_bytes(settled.state), "duplicate pet settlement grants nothing twice")
