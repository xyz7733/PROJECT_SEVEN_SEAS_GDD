## Schema 4/5 migration and save round-trip integrity.
class_name TestSaveMigration
extends RefCounted


static func run(t: TestKit) -> void:
	_test_v4_to_v5(t)
	_test_v3_to_v5(t)
	_test_round_trip(t)


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
	t.eq(int(state.envelope.schemaVersion), 5, "schema becomes 5")
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
	t.eq(int(state.envelope.schemaVersion), 5, "schema 3 reaches 5")
	t.ok(state.inventory.has("collectibles"), "schema 3 gets collection fields")


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
		t.eq(int(loaded.envelope.schemaVersion), 5, "save carries schema 5")
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
