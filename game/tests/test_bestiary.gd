## Bestiary tracking, rewards, and per-monster drop planning.
class_name TestBestiary
extends RefCounted


static func run(t: TestKit) -> void:
	_test_codex(t)
	_test_rewards(t)
	_test_drops(t)


static func _test_codex(t: TestKit) -> void:
	var state := GS.create_new_game(1001)
	Actions.codex_see_enemy(state, "tide_jelly", "dawnwater")
	var rec: Dictionary = state.codex.enemies["tide_jelly"]
	t.eq(bool(rec.get("seen", false)), true, "seen flag set")
	t.eq(int(rec.get("defeated", -1)), 0, "seen enemy has no defeats")
	t.eq(int(rec.get("kills", -1)), 0, "seen enemy has no kills")
	Actions.codex_defeat_enemy(state, {"enemyId": "tide_jelly", "variant": "alpha", "rare": false}, "dawnwater")
	rec = state.codex.enemies["tide_jelly"]
	t.eq(int(rec.defeated), 1, "defeated counted")
	t.eq(int(rec.kills), 1, "kills counted")
	t.ok(rec.variants.has("alpha"), "variant recorded")
	t.ok(rec.regions.has("dawnwater"), "region recorded")
	Actions.codex_defeat_enemy(state, {"enemyId": "tide_jelly", "variant": "alpha", "rare": false}, "dawnwater")
	rec = state.codex.enemies["tide_jelly"]
	t.eq(int(rec.kills), 2, "second kill counted")
	t.eq(rec.variants.size(), 1, "variant not duplicated")
	t.ok(not Bestiary.all_ids().has("swarmling"), "summon-only monster excluded from codex total")
	var g := Bestiary.global_progress(state)
	t.ok(int(g.total) > 30, "large bestiary total")
	t.ok(int(g.seen) >= 1 and int(g.defeated) >= 1, "global progress counts")


static func _test_rewards(t: TestKit) -> void:
	var state := GS.create_new_game(1002)
	var ids := Bestiary.region_ids("dawnwater")
	t.ok(ids.size() > 0, "dawnwater has bestiary entries")
	for id in ids:
		state.codex.enemies[id] = {"seen": true, "defeated": 1, "kills": 1, "variants": [], "regions": ["dawnwater"]}
	var p := Bestiary.progress(state, "dawnwater")
	t.eq(int(p.seen), int(p.total), "all dawnwater entries seen")
	t.eq(int(p.defeated), int(p.total), "all dawnwater entries defeated")
	t.ok(Bestiary.claimable(state, "dawnwater").has(50), "50 percent claimable")
	t.ok(Bestiary.claimable(state, "dawnwater").has(100), "100 percent claimable")
	var r := Actions.claim_bestiary_reward(state, "dawnwater", 50)
	t.ok(bool(r.get("ok", false)), "50 percent reward claimed")
	var last_id := int(state.envelope.lastTxId)
	state = r.state
	t.ok(int(state.envelope.lastTxId) == last_id + 1, "claim committed once")
	r = Actions.claim_bestiary_reward(state, "dawnwater", 50)
	t.ok(not bool(r.get("ok", true)), "duplicate claim refused")
	t.eq(int(r.state.envelope.lastTxId), int(state.envelope.lastTxId), "failed claim leaves state untouched")
	r = Actions.claim_bestiary_reward(state, "dawnwater", 100)
	t.ok(bool(r.get("ok", false)), "100 percent reward claimed")
	state = r.state
	t.ok(state.captain.bestiaryRewards.has("dawnwater:50"), "50 percent recorded")
	t.ok(state.captain.bestiaryRewards.has("dawnwater:100"), "100 percent recorded")
	t.ok(int(state.inventory.curioShards) >= 8, "shard reward added")
	t.ok(Collections.completeness(state).owned >= 1, "100 percent grants a collectible")


static func _test_drops(t: TestKit) -> void:
	var state := GS.create_new_game(1003)
	var def := {"id": "test:sea:monster", "regionId": "dawnwater", "kind": "boarding", "level": 1,
		"waves": [[{"enemyId": "golden_crab", "level": 1, "rare": true}]], "modifiers": [], "arena": "boarding"}
	var ctx := {"type": "sea", "kind": "monster", "toId": "gull_rock", "fromId": "brightquay"}
	var enc := {"attemptId": "test-drops-1", "def": def, "context": ctx}
	var plan := Settle.plan(state, enc)
	t.ok(plan.rows.size() > 0, "drop plan has rows")
	var trophy_idx := -1
	for i in plan.rows.size():
		if str(plan.rows[i].get("ref", "")) == "trophy_golden_crab":
			trophy_idx = i
	t.ok(trophy_idx >= 0, "rare trophy in first-kill plan")
	var mapped := false
	for uid in plan.drops:
		for pair in plan.drops[uid]:
			if int(pair[0]) == trophy_idx:
				mapped = true
	t.ok(mapped, "per-carrier drop mapping points at trophy row")
	Settle.grant(state, plan.rows, plan.table, C.location("gull_rock"))
	t.ok(Collections.owns(state, "trophy_golden_crab"), "trophy granted")
	var before := int(state.inventory.get("curioShards", 0))
	var dup := Collections.grant(state, "trophy_golden_crab")
	t.eq(bool(dup.get("new", true)), false, "duplicate grant is not new")
	t.ok(int(state.inventory.curioShards) > before, "duplicate converted to shards")
	t.eq(Collections.count(state, "trophy_golden_crab"), 2, "duplicate count recorded")
	t.ok(state.codex.collectibles.has("trophy_golden_crab"), "collectible codex marked")
	var traits := Bestiary.traits_for(Bestiary.entry("golden_crab"), "alpha")
	t.ok(traits.has("armored"), "monster trait retained")
	t.ok(traits.size() > 1, "variant trait added")
