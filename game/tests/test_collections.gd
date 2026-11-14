## Collection book, set rewards, charts and the curio dealer.
class_name TestCollections
extends RefCounted


static func run(t: TestKit) -> void:
	_test_sets(t)
	_test_chart(t)
	_test_curios(t)
	_test_progress(t)


## Every Codex tab needs a matching progress counter before its body builds.
static func _test_progress(t: TestKit) -> void:
	var state := GS.create_new_game(2005)
	var progress := Rules.codex_progress(state)
	for tab in ["locations", "enemies", "classes", "pets", "items", "clues", "collections"]:
		t.ok(progress.has(tab), "codex progress includes " + tab)
	t.eq(progress.get("collections"), [0, C.COLLECTIBLES.size()], "fresh collection counter")
	Collections.grant(state, "chart_dawnwater")
	t.eq(Rules.codex_progress(state).collections, [1, C.COLLECTIBLES.size()], "owned chart counted once")
	Collections.grant(state, "chart_dawnwater")
	t.eq(Rules.codex_progress(state).collections, [1, C.COLLECTIBLES.size()], "duplicate adds no collection progress")


static func _own_all(state: Dictionary, set_id: String) -> void:
	for member in C.COLLECTION_SETS[set_id].members:
		Collections.grant(state, String(member))


static func _test_sets(t: TestKit) -> void:
	var state := GS.create_new_game(2001)
	t.eq(Collections.set_complete(state, "set_dawnwater"), false, "fresh set incomplete")
	_own_all(state, "set_dawnwater")
	t.eq(Collections.set_complete(state, "set_dawnwater"), true, "set completed")
	t.ok(Collections.mod(state, "hpPct") >= 0.04, "relic and set hp modifiers stack")
	var gold_before := int(state.inventory.gold)
	var r := Actions.claim_collection_set(state, "set_dawnwater")
	t.ok(bool(r.get("ok", false)), "set reward claimed")
	state = r.state
	t.ok(int(state.captain.collectionSets.size()) == 1, "set claim recorded")
	t.ok(int(state.inventory.gold) >= gold_before + 190, "set gold granted")
	r = Actions.claim_collection_set(state, "set_dawnwater")
	t.ok(not bool(r.get("ok", true)), "set reward cannot be claimed twice")
	t.eq(int(r.state.envelope.lastTxId), int(state.envelope.lastTxId), "failed set claim leaves state untouched")


static func _test_chart(t: TestKit) -> void:
	var state := GS.create_new_game(2002)
	Collections.grant(state, "chart_dawnwater")
	state.world.currentLocationId = "driftplank_wreck"
	var gold_before := int(state.inventory.gold)
	var r := Actions.use_chart(state, "chart_dawnwater")
	t.ok(bool(r.get("ok", false)), "chart used at its wreck")
	state = r.state
	t.ok(int(state.inventory.gold) >= gold_before + 150, "chart gold granted")
	t.ok(Collections.owns(state, "relic_saltglass_prism"), "chart stash collectible granted")
	t.ok(bool(state.inventory.collectibles["chart_dawnwater"].get("used", false)), "chart marked used")
	r = Actions.use_chart(state, "chart_dawnwater")
	t.ok(not bool(r.get("ok", true)), "used chart refused")
	r = Actions.use_chart(state, "chart_emberreach")
	t.ok(not bool(r.get("ok", true)), "owned chart absent refused")


static func _test_curios(t: TestKit) -> void:
	var state := GS.create_new_game(2003)
	var offers_a := Rules.curio_offers(state, "brightquay")
	var offers_b := Rules.curio_offers(state, "brightquay")
	t.eq(offers_a, offers_b, "curio offers stable in one game day")
	t.ok(offers_a.size() > 0, "curio offers available")
	state.inventory.gold = 999999
	var first: Dictionary = offers_a[0]
	var r := Actions.buy_curio(state, String(first.id))
	t.ok(bool(r.get("ok", false)), "curio purchased")
	state = r.state
	t.ok(Collections.owns(state, String(first.id)), "purchased curio owned")
	var offers_after := Rules.curio_offers(state, "brightquay")
	var still_listed := false
	for o in offers_after:
		if String(o.id) == String(first.id):
			still_listed = true
	t.eq(still_listed, false, "owned curio leaves the offer list")
	var state2 := GS.create_new_game(2004)
	state2.inventory.curioShards = 999
	var exchange := Rules.curio_exchange(state2, "brightquay")
	t.ok(exchange.size() > 0, "shard exchange list available")
	var target: Dictionary = exchange[0]
	var shards_before := int(state2.inventory.curioShards)
	r = Actions.exchange_curio(state2, String(target.id))
	t.ok(bool(r.get("ok", false)), "curio exchanged")
	state2 = r.state
	t.ok(Collections.owns(state2, String(target.id)), "exchanged curio owned")
	t.eq(int(state2.inventory.curioShards), shards_before - int(target.shards), "shards deducted")
