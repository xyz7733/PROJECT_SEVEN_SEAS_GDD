## Schema 4/5/6 migration and save round-trip integrity.
class_name TestSaveMigration
extends RefCounted


static func run(t: TestKit) -> void:
	_test_v4_to_v5(t)
	_test_v3_to_v5(t)
	_test_v5_to_v6(t)
	_test_round_trip(t)
	_test_v5_file(t)


static func _test_v4_to_v5(t: TestKit) -> void:
	var state := GS.create_new_game(4001)
	state.envelope.schemaVersion = 4
	state.inventory.erase("collectibles")
	state.inventory.erase("curioShards")
	state.captain.erase("collectionSets")
	state.captain.erase("bestiaryRewards")
	state.codex.erase("collectibles")
	state.codex.enemies["gull_raider"] = {"seen": true, "defeated": 3}
	t.ok(GS.migrate(state), "schema 4 migrates")
	t.eq(int(state.envelope.schemaVersion), GS.SCHEMA_VERSION, "schema 4 reaches the current schema")
	t.ok(state.inventory.has("collectibles"), "inventory collectibles added")
	t.eq(int(state.inventory.curioShards), 0, "curio shards default")
	t.ok(state.captain.has("collectionSets"), "collection sets added")
	t.ok(state.captain.has("bestiaryRewards"), "bestiary rewards added")
	t.ok(state.codex.has("collectibles"), "codex collectibles added")
	var rec: Dictionary = state.codex.enemies["gull_raider"]
	t.eq(int(rec.get("kills", -1)), 3, "kills backfilled from defeated")
	t.ok(rec.get("variants") is Array, "variants backfilled")
	t.ok(rec.get("regions") is Array, "regions backfilled")


static func _test_v3_to_v5(t: TestKit) -> void:
	var state := GS.create_new_game(4002)
	state.envelope.schemaVersion = 3
	t.ok(GS.migrate(state), "schema 3 migrates")
	t.eq(int(state.envelope.schemaVersion), GS.SCHEMA_VERSION, "schema 3 reaches the current schema")
	t.ok(state.inventory.has("collectibles"), "schema 3 gets collection fields")


## A schema 5 crew has no attributes: migration rolls exactly what a new
## hire with the same seed and origin would get, and an empty training record.
static func _test_v5_to_v6(t: TestKit) -> void:
	var state := GS.create_new_game(4004)
	var want := []
	for m in state.crew:
		want.append(m.attrs.duplicate())
		m.erase("attrs")
		m.erase("train")
	state.envelope.schemaVersion = 5
	t.ok(GS.migrate(state), "schema 5 migrates")
	t.eq(int(state.envelope.schemaVersion), 6, "schema 5 reaches 6")
	var same := true
	var trained := true
	for i in state.crew.size():
		same = same and state.crew[i].get("attrs") == want[i]
		trained = trained and state.crew[i].get("train") is Dictionary and state.crew[i].train.is_empty()
	t.ok(same, "migrated crew get their seed-rolled attributes")
	t.ok(trained, "migrated crew get an empty training record")
	state.crew[0].train = {"might": 1}
	GS._fill_schema6(state)
	t.eq(state.crew[0].train, {"might": 1}, "filling schema 6 twice keeps training")


static func _test_round_trip(t: TestKit) -> void:
	var path := "user://tests/collection_roundtrip.p7s"
	DirAccess.make_dir_recursive_absolute("user://tests")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var state := GS.create_new_game(4003)
	Collections.grant(state, "relic_tide_compass")
	state.inventory.curioShards = 7
	t.ok(SaveStore.write(path, state, "test"), "save written")
	var read := SaveStore.read(path)
	t.eq(String(read.get("status", "")), "ok", "save reads back")
	if read.get("status", "") == "ok":
		var loaded: Dictionary = read.record.state
		t.ok(loaded.inventory.get("collectibles", {}).has("relic_tide_compass"), "collectible survives round trip")
		t.eq(int(loaded.inventory.get("curioShards", 0)), 7, "shards survive round trip")
		t.eq(int(loaded.envelope.schemaVersion), GS.SCHEMA_VERSION, "save carries the current schema")
		t.eq(loaded.crew[0].get("attrs"), state.crew[0].attrs, "crew attributes survive round trip")
		var f := FileAccess.open(path, FileAccess.READ)
		var rec = f.get_var()
		f.close()
		rec.state.envelope.stateHash = "tampered"
		f = FileAccess.open(path, FileAccess.WRITE)
		f.store_var(rec)
		f.close()
		var bad := SaveStore.read(path)
		t.eq(String(bad.get("status", "")), "corrupt", "tampered save rejected")
	DirAccess.remove_absolute(path)


## A verified schema 5 save file loads, is migrated in memory and gains crew
## attributes.
static func _test_v5_file(t: TestKit) -> void:
	var path := "user://tests/schema5.p7s"
	DirAccess.make_dir_recursive_absolute("user://tests")
	var state := GS.create_new_game(4005)
	for m in state.crew:
		m.erase("attrs")
		m.erase("train")
	state.envelope.schemaVersion = 5
	state.envelope.stateHash = SaveStore.state_hash(state)
	var rec := {"format": GS.SAVE_FORMAT, "schemaVersion": 5, "savedAt": 0, "reason": "test", "summary": SaveStore.summary_of(state), "state": state}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_var(rec)
	f.close()
	var read := SaveStore.read(path)
	t.eq(String(read.get("status", "")), "ok", "schema 5 save reads")
	if read.get("status", "") == "ok":
		t.eq(int(read.record.get("migratedFrom", 0)), 5, "schema 5 save is migrated")
		var m: Dictionary = read.record.state.crew[0]
		t.ok(m.get("attrs") is Dictionary and m.attrs.size() == Attrs.IDS.size(), "schema 5 crew gain attributes")
		t.eq(m.attrs, Attrs.roll(int(m.seed), String(m.originId)), "schema 5 crew attributes come from the seed")
	DirAccess.remove_absolute(path)
