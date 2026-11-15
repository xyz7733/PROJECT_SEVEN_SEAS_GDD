## Crew attributes: data integrity, the seeded roll, the effect of each
## attribute on member stats, training points, training and retraining, and
## the recruit paths that hand out attributes.
class_name TestAttrs
extends RefCounted


static func run(t: TestKit) -> void:
	_test_data(t)
	_test_roll(t)
	_test_neutral(t)
	_test_effects(t)
	_test_points(t)
	_test_train(t)
	_test_retrain(t)
	_test_level_note(t)
	_test_recruits(t)


static func _test_data(t: TestKit) -> void:
	t.eq(Attrs.IDS.size(), 6, "six attributes")
	for a in Attrs.IDS:
		t.ok(Attrs.EFFECTS.has(a), "attribute %s has effects" % a)
		t.ok(Art.has_icon(Attrs.ICONS[a]), "attribute %s has an icon" % a)
		for k in ["name", "short", "desc"]:
			t.ok(I18n.has("attr.%s.%s" % [a, k]), "attribute %s has %s text" % [a, k])
		for k in Attrs.EFFECTS[a]:
			t.ok(I18n.has("attrfx." + k), "effect %s has text" % k)
			t.ok(Fmt.ATTR_FX_ORDER.has(k), "effect %s has a display slot" % k)
	for b in Attrs.BANDS:
		t.ok(I18n.has("attr.band." + String(b[1])), "band %s has text" % b[1])
	for o in C.data.ORIGINS:
		var lean: Array = Attrs.ORIGIN_LEAN.get(o, [])
		t.eq(lean.size(), 2, "origin %s leans toward two attributes" % o)
		for a in lean:
			t.ok(Attrs.IDS.has(a), "origin %s leans toward a real attribute" % o)
	for tr in C.data.TRAITS:
		t.ok(Attrs.TRAIT_SHIFT.has(tr), "trait %s shifts attributes" % tr)
		var net := 0
		for a in Attrs.TRAIT_SHIFT.get(tr, {}):
			t.ok(Attrs.IDS.has(a), "trait %s shifts a real attribute" % tr)
			net += int(Attrs.TRAIT_SHIFT[tr][a])
		t.eq(net, 1, "trait %s nets +1" % tr)
	for id in C.CLASSES:
		var keys := Attrs.class_keys(String(id))
		t.eq(keys.size(), 2, "class %s has two key attributes" % id)
	# POOL keeps the average sailor neutral once two traits (+1 each) apply.
	t.eq(Attrs.ROLL_FLOOR * Attrs.IDS.size() + Attrs.POOL + 2, Attrs.NEUTRAL * Attrs.IDS.size(), "rolled total plus traits averages 10")


static func _test_roll(t: TestKit) -> void:
	var same := true
	var in_range := true
	var budget := true
	var varied := false
	var first := Attrs.roll(1, "glass_reefs")
	for i in 300:
		var o: String = C.data.ORIGINS[i % C.data.ORIGINS.size()]
		var v := Attrs.roll(i * 7919 + 13, o)
		same = same and v == Attrs.roll(i * 7919 + 13, o)
		var sum := 0
		for a in Attrs.IDS:
			in_range = in_range and int(v[a]) >= Attrs.ROLL_FLOOR and int(v[a]) <= Attrs.ROLL_CAP
			sum += int(v[a])
		budget = budget and sum == Attrs.ROLL_FLOOR * Attrs.IDS.size() + Attrs.POOL
		if o == "glass_reefs" and v != first:
			varied = true
	t.ok(same, "the same seed and origin roll the same attributes")
	t.ok(in_range, "rolled attributes stay within the roll range")
	t.ok(budget, "every roll deals the whole pool")
	t.ok(varied, "different seeds roll different attributes")
	# Origins lean: their two attributes average clearly higher.
	for o in ["ember_forges", "glass_reefs", "moon_isles"]:
		var lean_sum := 0.0
		var other_sum := 0.0
		for i in 400:
			var v := Attrs.roll(i * 31 + 7, o)
			for a in Attrs.IDS:
				if Attrs.ORIGIN_LEAN[o].has(a):
					lean_sum += float(v[a]) / 2.0
				else:
					other_sum += float(v[a]) / 4.0
		t.ok(lean_sum / 400.0 > other_sum / 400.0 + 2.0, "origin %s rolls its leanings higher" % o)


static func _plain(attrs: Dictionary = {}) -> Dictionary:
	var m := GS.make_recruit(99, {"classId": "duelist", "originId": "dawnwater_fishers"})
	m.id = "crew-test"
	m.traits = []
	m.aptitudes = []
	var base := {}
	for a in Attrs.IDS:
		base[a] = int(attrs.get(a, Attrs.NEUTRAL))
	m.attrs = base
	return m


static func _test_neutral(t: TestKit) -> void:
	var m := _plain()
	t.ok(Attrs.mods_of(m).is_empty(), "10 in every attribute adds no modifiers")
	t.eq(Attrs.class_fit(m, "duelist"), 10.0, "neutral sailor has a neutral class fit")
	var state := GS.create_new_game(5101)
	var s := Rules.member_stats(state, m)
	var other := {}
	for p in Rules.active_passives(m):
		U.add_mods(other, C.PASSIVES.get(p))
	U.add_mods(other, Collections.mod_map(state))
	t.near(float(s.crit), 0.05 + U.num(other, "crit"), "neutral sailor keeps the class crit")
	t.near(float(s.dodge), U.num(other, "dodge"), "neutral sailor keeps the class dodge")
	t.eq(Attrs.value(_plain({"might": 1}), "might"), 1, "values bottom out at 1")
	var high := _plain({"might": 29})
	high.traits = ["reckless"]
	t.eq(Attrs.value(high, "might"), Attrs.MAX_VALUE, "values top out at the maximum")


static func _test_effects(t: TestKit) -> void:
	var state := GS.create_new_game(5102)
	var base := Rules.member_stats(state, _plain())
	var up := func(a: String, v: int) -> Dictionary: return Rules.member_stats(state, _plain({a: v}))
	t.ok(int(up.call("might", 16).atk) > int(base.atk), "might raises ATK")
	t.ok(int(up.call("might", 6).atk) < int(base.atk), "low might lowers ATK")
	t.ok(int(up.call("vigor", 16).hp) > int(base.hp), "vigor raises HP")
	t.ok(int(up.call("vigor", 16).def) >= int(base.def), "vigor does not lower DEF")
	t.ok(float(up.call("agility", 16).spd) > float(base.spd), "agility raises SPD")
	t.ok(float(up.call("agility", 16).dodge) > 0.0, "agility above 10 adds dodge")
	t.near(float(up.call("agility", 6).dodge), 0.0, "agility below 10 never gives negative dodge")
	t.ok(float(up.call("focus", 16).crit) > float(base.crit), "focus raises crit")
	t.ok(U.num(up.call("focus", 16).mods, "controlPct") > 0.0, "focus strengthens control")
	t.ok(U.num(up.call("will", 16).mods, "healPct") > 0.0, "will strengthens healing")
	t.ok(U.num(up.call("will", 16).mods, "cdr") > 0.0, "will shortens cooldowns")
	var hand := _plain({"seamanship": 16})
	var lubber := _plain({"seamanship": 6})
	state.crew.append(hand)
	t.ok(Rules.worker_efficiency(state, hand, "galley") > Rules.worker_efficiency(state, lubber, "galley"), "seamanship improves ship jobs")
	t.ok(Rules.power(state, _plain({"might": 16, "vigor": 16})) > Rules.power(state, _plain()), "strong attributes raise power")
	# Traits are part of the total.
	var stubborn := _plain()
	stubborn.traits = ["stubborn"]
	t.eq(Attrs.value(stubborn, "vigor"), 12, "a stubborn sailor gains vigor")
	t.eq(Attrs.value(stubborn, "agility"), 9, "a stubborn sailor loses agility")
	t.ok(Fmt.attr_fx_lines(Attrs.mods_of(stubborn)).size() > 0, "trait shifts show as effect lines")


static func _test_points(t: TestKit) -> void:
	t.eq(Attrs.points_earned(1), 0, "no training points at level 1")
	t.eq(Attrs.points_earned(3), 0, "no training points at level 3")
	t.eq(Attrs.points_earned(4), 1, "first training point at level 4")
	t.eq(Attrs.points_earned(int(C.TUNING.levelCap)), int(C.TUNING.levelCap) / Attrs.LEVELS_PER_POINT, "points at the level cap")
	var m := _plain()
	m.level = 9
	m.train = {"might": 1}
	t.eq(Attrs.points_free(m), 1, "spent points come off the earned points")
	m.train = {"might": 3}
	t.eq(Attrs.points_free(m), 0, "free points never go negative")


static func _test_train(t: TestKit) -> void:
	var state := GS.create_new_game(5103)
	var id: String = state.crew[0].id
	var r := Actions.train_attr(state, id, "might")
	t.ok(not r.ok and r.reasonKey == "err.no_train_points", "a level 1 sailor has nothing to train")
	state.crew[0].level = 8
	var before := Attrs.value(state.crew[0], "focus")
	r = Actions.train_attr(state, id, "focus")
	t.ok(r.ok, "training spends a point")
	state = r.state
	t.eq(Attrs.value(state.crew[0], "focus"), before + 1, "training raises the attribute by one")
	t.eq(Attrs.points_free(state.crew[0]), 1, "one point left")
	r = Actions.train_attr(state, id, "luck")
	t.ok(not r.ok and r.reasonKey == "err.bad_attr", "unknown attributes are refused")
	var fight: Dictionary = state.duplicate(true)
	fight.encounter = {"def": {}, "context": {}}
	r = Actions.train_attr(fight, id, "focus")
	t.ok(not r.ok and r.reasonKey == "err.in_encounter", "no training in a fight")
	r = Actions.train_attr(state, id, "focus")
	state = r.state
	r = Actions.train_attr(state, id, "focus")
	t.ok(not r.ok and r.reasonKey == "err.no_train_points", "training stops when the points run out")
	var capped := state.duplicate(true)
	capped.crew[0].level = 60
	capped.crew[0].traits = []
	capped.crew[0].attrs.will = Attrs.MAX_VALUE - 2
	capped.crew[0].train = {"will": 2}
	t.eq(Attrs.value(capped.crew[0], "will"), Attrs.MAX_VALUE, "will at the maximum")
	r = Actions.train_attr(capped, id, "will")
	t.ok(not r.ok and r.reasonKey == "err.attr_max", "attributes cannot be trained past the maximum")


static func _test_retrain(t: TestKit) -> void:
	var state := GS.create_new_game(5104)
	var id: String = state.crew[1].id
	var r := Actions.retrain(state, id)
	t.ok(not r.ok and r.reasonKey == "err.nothing_to_retrain", "nothing to retrain without spent points")
	state.crew[1].level = 12
	for a in ["might", "might", "agility"]:
		state = Actions.train_attr(state, id, a).state
	t.eq(Attrs.points_spent(state.crew[1]), 3, "three points spent")
	var away: Dictionary = state.duplicate(true)
	for lid in C.LOCATIONS:
		if not C.PORTS.has(lid):
			away.world.currentLocationId = lid
			break
	r = Actions.retrain(away, id)
	t.ok(not r.ok and r.reasonKey == "err.need_class_hall", "retraining needs a port or a Class Hall")
	var gold := int(state.inventory.gold)
	var cost := Attrs.retrain_cost(state.crew[1])
	r = Actions.retrain(state, id)
	t.ok(r.ok, "retraining works in port")
	state = r.state
	t.eq(int(state.inventory.gold), gold - int(cost.gold), "retraining costs gold")
	t.eq(Attrs.points_spent(state.crew[1]), 0, "retraining refunds every point")
	t.eq(Attrs.points_free(state.crew[1]), 3, "refunded points can be spent again")
	t.eq(String(state.log[0].key), "log.retrained", "retraining is logged")
	var broke: Dictionary = state.duplicate(true)
	broke.crew[1].train = {"vigor": 1}
	broke.inventory.gold = 0
	r = Actions.retrain(broke, id)
	t.ok(not r.ok and r.reasonKey == "err.no_gold", "retraining needs the fee")


static func _test_level_note(t: TestKit) -> void:
	var state := GS.create_new_game(5105)
	var m: Dictionary = state.crew[0]
	m.level = 3
	m.xp = 0
	Actions.add_member_xp(state, m, float(Rules.xp_to_next(3)))
	t.eq(int(m.level), 4, "level 4 reached")
	var noted := false
	for e in state.log:
		if e.key == "log.train_point" and e.params.get("crew") == m.id:
			noted = true
	t.ok(noted, "a new training point is announced")


static func _test_recruits(t: TestKit) -> void:
	var m := GS.make_recruit(424242)
	t.eq(m.get("attrs"), Attrs.roll(424242, String(m.originId)), "recruits carry their seed-rolled attributes")
	t.eq(m.get("train"), {}, "recruits start untrained")
	var state := GS.create_new_game(5106)
	var ok := true
	for c in state.crew:
		ok = ok and c.attrs == Attrs.roll(int(c.seed), "dawnwater_fishers")
	t.ok(ok, "the starting crew roll with their dawnwater origin")
	var pool := Rules.tavern_pool(state, "brightquay")
	var have := pool.size() > 0
	for o in pool:
		have = have and o.member.get("attrs") is Dictionary
	t.ok(have, "tavern sailors have attributes")
	# Older records without stored attributes fall back to the seed roll.
	var old := m.duplicate(true)
	old.erase("attrs")
	old.erase("train")
	t.eq(Attrs.totals(old), Attrs.totals(m), "records without attributes use the seed roll")
	t.eq(Attrs.points_free(old), 0, "records without training have no spent points")
