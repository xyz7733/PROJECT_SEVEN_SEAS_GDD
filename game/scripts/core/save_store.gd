## Native save storage under user://saves. Every write goes to a temporary
## file that is renamed into place, and each save carries a SHA-256 content
## hash so a damaged file is detected instead of loaded. Three manual slots
## plus three rotating recovery saves.
class_name SaveStore
extends RefCounted

const DIR := "user://saves"
const RECOVERY_COUNT := 3


static func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


static func manual_path(i: int) -> String:
	return "%s/slot_%d.p7s" % [DIR, i + 1]


static func recovery_path(i: int) -> String:
	return "%s/recovery_%d.p7s" % [DIR, i + 1]


static func state_hash(state: Dictionary) -> String:
	var copy: Dictionary = state.duplicate(true)
	copy.envelope.stateHash = ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes(copy))
	return ctx.finish().hex_encode()


static func summary_of(state: Dictionary) -> Dictionary:
	return {"titleKey": state.captain.titleKey, "day": Rules.day(state), "locationId": state.world.currentLocationId,
		"crew": state.crew.size(), "trials": state.captain.trialsWon.size(), "hullId": state.ship.hullId}


static func write(path: String, state: Dictionary, reason: Variant) -> bool:
	_ensure_dir()
	var data: Dictionary = state.duplicate(true)
	data.envelope.stateHash = state_hash(data)
	var record := {"format": GS.SAVE_FORMAT, "schemaVersion": GS.SCHEMA_VERSION, "savedAt": int(Time.get_unix_time_from_system()),
		"reason": reason, "summary": summary_of(data), "state": data}
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(record)
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK


## Returns {status: "empty"|"ok"|"corrupt", record?}
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": "empty"}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"status": "corrupt"}
	var rec = f.get_var()
	f.close()
	if not (rec is Dictionary) or rec.get("format") != GS.SAVE_FORMAT or not (rec.get("state") is Dictionary):
		return {"status": "corrupt"}
	var ver := int(rec.get("schemaVersion", 0))
	if ver < GS.MIN_SCHEMA_VERSION or ver > GS.SCHEMA_VERSION:
		return {"status": "corrupt"}
	var st: Dictionary = rec.state
	if st.get("envelope") == null or state_hash(st) != String(st.envelope.get("stateHash", "")):
		return {"status": "corrupt"}
	# Verified older saves are upgraded in memory; the next save writes the
	# current schema and a fresh hash.
	if ver < GS.SCHEMA_VERSION:
		if not GS.migrate(st):
			return {"status": "corrupt"}
		st.envelope.stateHash = state_hash(st)
		rec.schemaVersion = GS.SCHEMA_VERSION
		rec.migratedFrom = ver
		rec.summary = summary_of(st)
	return {"status": "ok", "record": rec}


static func save_manual(i: int, state: Dictionary) -> bool:
	return write(manual_path(i), state, "save.reason_manual")


static func delete_manual(i: int) -> void:
	if FileAccess.file_exists(manual_path(i)):
		DirAccess.remove_absolute(manual_path(i))


## Rotating recovery: a new generation goes to the next file; a refresh
## overwrites the newest one.
static func save_recovery(state: Dictionary, reason: Variant, rotate: bool) -> bool:
	var s: Dictionary = state.duplicate(true)
	var gen := int(s.envelope.recoveryGeneration)
	if rotate or gen == 0:
		gen += 1
	s.envelope.recoveryGeneration = gen
	return write(recovery_path((gen - 1) % RECOVERY_COUNT), s, reason)


static func list_manual() -> Array:
	var out := []
	for i in int(C.TUNING.manualSlotCount):
		var r := read(manual_path(i))
		r.index = i
		out.append(r)
	return out


## Recovery saves, newest first.
static func list_recovery() -> Array:
	var out := []
	for i in RECOVERY_COUNT:
		var r := read(recovery_path(i))
		if r.status == "ok":
			r.index = i
			out.append(r)
	out.sort_custom(func(a, b): return int(a.record.state.envelope.recoveryGeneration) > int(b.record.state.envelope.recoveryGeneration))
	return out


static func newest() -> Variant:
	var best = null
	for r in list_manual() + list_recovery():
		if r.status != "ok":
			continue
		if best == null or int(r.record.savedAt) > int(best.record.savedAt) or \
				(int(r.record.savedAt) == int(best.record.savedAt) and int(r.record.state.envelope.lastTxId) > int(best.record.state.envelope.lastTxId)):
			best = r
	return best
