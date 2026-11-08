## Collection book: relics, trophies, charts, lore and curios. Owns the
## duplicate-to-shard conversion, set progress and the global modifiers a
## collection grants. Mutates only the draft state passed by Actions.
class_name Collections
extends RefCounted

const SHARDS := {"common": 2, "uncommon": 3, "rare": 5, "epic": 8, "legendary": 12}
const KINDS := ["relic", "trophy", "chart", "lore", "curio"]


static func entry(id: String) -> Variant:
	return C.COLLECTIBLES.get(id)


static func kind(id: String) -> String:
	var rec = entry(id)
	return String(rec.get("kind", "")) if rec is Dictionary else ""


static func rarity(id: String) -> String:
	var rec = entry(id)
	return String(rec.get("rarity", "common")) if rec is Dictionary else "common"


static func name_key(id: String) -> String:
	var rec = entry(id)
	return String(rec.get("nameKey", "collectible." + id + ".name")) if rec is Dictionary else "collectible." + id + ".name"


static func desc_key(id: String) -> String:
	var rec = entry(id)
	return String(rec.get("descKey", "collectible." + id + ".desc")) if rec is Dictionary else "collectible." + id + ".desc"


static func icon(id: String) -> String:
	var rec = entry(id)
	if rec is Dictionary and rec.get("icon"):
		return String(rec.icon)
	return "ui_" + (kind(id) if kind(id) != "" else "relic")


static func sell_value(id: String) -> int:
	var rec = entry(id)
	if not (rec is Dictionary):
		return 0
	if rec.get("sell") != null:
		return int(rec.sell)
	return {"common": 30, "uncommon": 60, "rare": 120, "epic": 240, "legendary": 480}.get(rarity(id), 30)


static func duplicate_shards(id: String) -> int:
	return int(SHARDS.get(rarity(id), 2))


static func owns(state: Dictionary, id: String) -> bool:
	var inv: Dictionary = state.inventory
	if not inv.has("collectibles"):
		return false
	var rec = inv.collectibles.get(id)
	if rec is Dictionary:
		return int(rec.get("count", 0)) > 0
	return rec != null


static func count(state: Dictionary, id: String) -> int:
	var rec = state.inventory.get("collectibles", {}).get(id)
	if rec is Dictionary:
		return int(rec.get("count", 0))
	return 1 if rec != null else 0


static func owned_ids(state: Dictionary) -> Array:
	return state.inventory.get("collectibles", {}).keys()


static func row(state: Dictionary, id: String) -> Dictionary:
	var dup := owns(state, id)
	return {"id": "collect:" + id, "kind": "collectible", "ref": id, "qty": 1,
		"rarity": rarity(id), "icon": icon(id), "nameKey": name_key(id),
		"new": not dup, "duplicate": dup, "shards": duplicate_shards(id) if dup else 0}


## Grants one collectible. Returns {ok, id, new, shards, count, revealLocationId}.
## The caller is responsible for revealing a chart's location.
static func grant(d: Dictionary, id: String, opts: Dictionary = {}) -> Dictionary:
	if not C.COLLECTIBLES.has(id):
		return {"ok": false, "id": id, "reasonKey": "err.no_collectible"}
	var inv: Dictionary = d.inventory
	if not inv.has("collectibles"):
		inv.collectibles = {}
	if not d.codex.has("collectibles"):
		d.codex.collectibles = {}
	var rec: Dictionary = C.COLLECTIBLES[id]
	var now := int(d.envelope.get("gameClock", 0))
	if inv.collectibles.has(id):
		var old = inv.collectibles[id]
		if old is Dictionary:
			old.count = int(old.get("count", 1)) + 1
		else:
			inv.collectibles[id] = {"count": 2, "firstAt": now, "used": false}
		var shards := duplicate_shards(id)
		inv.curioShards = int(inv.get("curioShards", 0)) + shards
		d.codex.collectibles[id] = true
		GS.add_log(d, "log.collectible_duplicate", {"item": name_key(id), "n": shards})
		return {"ok": true, "id": id, "new": false, "shards": shards,
			"count": count(d, id), "revealLocationId": null}
	inv.collectibles[id] = {"count": 1, "firstAt": now, "used": false}
	d.codex.collectibles[id] = true
	GS.add_log(d, "log.collectible_new", {"item": name_key(id)})
	var reveal = rec.get("revealLocationId") if bool(opts.get("reveal", true)) else null
	return {"ok": true, "id": id, "new": true, "shards": 0, "count": 1, "revealLocationId": reveal}


static func set_progress(state: Dictionary, set_id: String) -> Array:
	var set = C.COLLECTION_SETS.get(set_id)
	if not (set is Dictionary):
		return [0, 0]
	var owned := 0
	for cid in set.get("members", []):
		if owns(state, String(cid)):
			owned += 1
	return [owned, set.get("members", []).size()]


static func set_complete(state: Dictionary, set_id: String) -> bool:
	var p := set_progress(state, set_id)
	return int(p[0]) == int(p[1]) and int(p[1]) > 0


static func mod_map(state: Dictionary) -> Dictionary:
	var mods := {}
	var inv: Dictionary = state.inventory
	for id in inv.get("collectibles", {}):
		var rec = C.COLLECTIBLES.get(id)
		if rec is Dictionary and String(rec.get("kind", "")) in ["relic", "trophy"]:
			U.add_mods(mods, rec.get("mods"))
	for sid in C.COLLECTION_SETS:
		if set_complete(state, sid):
			U.add_mods(mods, C.COLLECTION_SETS[sid].get("bonus", {}).get("mods"))
	return mods


static func mod(state: Dictionary, key: String) -> float:
	return float(mod_map(state).get(key, 0.0))


static func chart_rows(state: Dictionary, chart_id: String) -> Array:
	var rec = entry(chart_id)
	if not (rec is Dictionary):
		return []
	var rows := []
	for entry_row in rec.get("stash", []):
		if not (entry_row is Dictionary):
			continue
		var row_kind := String(entry_row.get("kind", ""))
		var qty := int(entry_row.get("qty", 1))
		match row_kind:
			"gold", "materials", "food", "supplies":
				rows.append({"id": row_kind, "kind": row_kind, "ref": null, "qty": qty,
					"rarity": "common", "icon": row_kind})
			"specialty":
				var sid := String(entry_row.get("id", ""))
				rows.append({"id": "spec:" + sid, "kind": "specialty", "ref": sid, "qty": qty,
					"rarity": "uncommon", "icon": "sp_" + sid})
			"ingredient":
				var iid := String(entry_row.get("id", ""))
				rows.append({"id": "ing:" + iid, "kind": "ingredient", "ref": iid, "qty": qty,
					"rarity": "uncommon", "icon": "ing_" + iid})
			"item":
				var item_id := String(entry_row.get("id", ""))
				if C.ITEMS.has(item_id):
					rows.append({"id": "item:" + item_id, "kind": "item", "ref": item_id, "qty": 1,
						"rarity": "legendary" if C.ITEMS[item_id].get("unique", false) else "epic", "icon": "ui_chest"})
			"collectible", "relic", "trophy", "lore", "curio", "chart":
				var cid := String(entry_row.get("id", ""))
				if C.COLLECTIBLES.has(cid):
					rows.append(row(state, cid))
	return rows


static func completeness(state: Dictionary) -> Dictionary:
	var total: int = C.COLLECTIBLES.size()
	var owned := 0
	for cid in C.COLLECTIBLES:
		if owns(state, String(cid)):
			owned += 1
	return {"owned": owned, "total": total, "ratio": float(owned) / float(max(1, total))}


static func missing_in_regions(state: Dictionary, region_ids: Array) -> Array:
	var out := []
	for cid in C.COLLECTIBLES:
		var rec: Dictionary = C.COLLECTIBLES[cid]
		if not region_ids.has(rec.get("regionId")):
			continue
		if not owns(state, String(cid)):
			out.append(String(cid))
	return out


static func first_missing(state: Dictionary, region_ids: Array, kind_filter: String = "") -> String:
	for cid in missing_in_regions(state, region_ids):
		if kind_filter == "" or kind(String(cid)) == kind_filter:
			return String(cid)
	return ""
