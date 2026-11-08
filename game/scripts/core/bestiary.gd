## Bestiary: the expansion enemy catalogue, encounter rosters, variants,
## per-monster drops and region progress. Read-only; state changes stay in
## Actions.
class_name Bestiary
extends RefCounted

const VARIANT_WEIGHTS := ["alpha", "elder", "corrupted", "swift", "armored", "feral"]


static func entry(enemy_id: String) -> Variant:
	return C.MONSTERS_BY_ID.get(enemy_id)


static func all_ids() -> Array:
	var out := []
	for id in C.MONSTERS_BY_ID:
		var rec: Dictionary = C.MONSTERS_BY_ID[id]
		if rec.get("summonOnly", false):
			continue
		if not out.has(id):
			out.append(id)
	return out


static func region_ids(region_id: String) -> Array:
	var out := []
	var r = C.region(region_id)
	if r == null:
		return out
	for arch in r.enemies:
		var id = String(r.enemies[arch])
		if not out.has(id):
			out.append(id)
	for id in r.bosses:
		if not out.has(id):
			out.append(id)
	if r.get("rivalId") and not out.has(r.rivalId):
		out.append(String(r.rivalId))
	var rd: Dictionary = C.BESTIARY.REGIONS.get(region_id, {})
	for arch in rd.get("roster", {}):
		for id in rd.roster[arch]:
			if not out.has(id):
				out.append(id)
	if rd.get("boss") and not out.has(rd.boss):
		out.append(rd.boss)
	if rd.get("rare") and not out.has(rd.rare):
		out.append(rd.rare)
	return out


static func region_roster(region_id: String, archetype: String) -> Array:
	var out := []
	var r = C.region(region_id)
	if r != null and r.enemies.has(archetype):
		out.append(String(r.enemies[archetype]))
	var rd: Dictionary = C.BESTIARY.REGIONS.get(region_id, {})
	for id in rd.get("roster", {}).get(archetype, []):
		if not out.has(id):
			out.append(id)
	if archetype == "swarm" and out.is_empty() and C.MONSTERS_BY_ID.has("swarmling"):
		out.append("swarmling")
	return out


static func pick_roster(region_id: String, archetype: String, rng: U.Rng) -> String:
	var pool := region_roster(region_id, archetype)
	if pool.is_empty():
		return ""
	return String(rng.pick(pool))


static func region_archetypes(region_id: String) -> Array:
	var out := []
	var r = C.region(region_id)
	if r != null:
		for arch in r.enemies:
			if not out.has(arch):
				out.append(arch)
	var rd: Dictionary = C.BESTIARY.REGIONS.get(region_id, {})
	for arch in rd.get("roster", {}):
		if not out.has(arch):
			out.append(arch)
	return out


static func region_rare(region_id: String) -> Variant:
	return C.RARE_BY_REGION.get(region_id)


static func region_boss(region_id: String, slot: int) -> String:
	var r = C.region(region_id)
	if r == null:
		return ""
	var rd: Dictionary = C.BESTIARY.REGIONS.get(region_id, {})
	if slot == 6 and rd.get("boss"):
		return String(rd.boss)
	if r.bosses.size():
		return String(r.bosses[0])
	return String(rd.get("boss", ""))


static func progress(state: Dictionary, region_id: String) -> Dictionary:
	var ids := region_ids(region_id)
	var seen := 0
	var defeated := 0
	var kills := 0
	for id in ids:
		var rec: Dictionary = state.codex.enemies.get(id, {})
		if rec.get("seen", false):
			seen += 1
		var n := int(rec.get("defeated", rec.get("kills", 0)))
		if n > 0:
			defeated += 1
		kills += n
	var total: int = ids.size()
	return {"regionId": region_id, "seen": seen, "defeated": defeated, "kills": kills, "total": total,
		"seenRatio": float(seen) / float(max(1, total)), "defeatedRatio": float(defeated) / float(max(1, total))}


static func global_progress(state: Dictionary) -> Dictionary:
	var ids := all_ids()
	var seen := 0
	var defeated := 0
	for id in ids:
		var rec: Dictionary = state.codex.enemies.get(id, {})
		if rec.get("seen", false):
			seen += 1
		if int(rec.get("defeated", rec.get("kills", 0))) > 0:
			defeated += 1
	return {"seen": seen, "defeated": defeated, "total": ids.size()}


static func claimable(state: Dictionary, region_id: String) -> Array:
	var p := progress(state, region_id)
	var out := []
	for tier in [50, 100]:
		var key := "%s:%d" % [region_id, tier]
		if state.captain.get("bestiaryRewards", []).has(key):
			continue
		if float(p.defeatedRatio) * 100.0 + 0.0001 >= float(tier):
			out.append(tier)
	return out


static func variant_record(variant_id: Variant) -> Variant:
	if variant_id == null or variant_id == "":
		return null
	return C.BESTIARY.VARIANTS.get(String(variant_id))


static func pick_variant(rng: U.Rng, kind: String, force: Variant = null) -> Variant:
	if force != null and C.BESTIARY.VARIANTS.has(String(force)):
		return String(force)
	if kind == "boss":
		return null
	var chance: float = {"battle": 0.10, "elite": 0.30, "boarding": 0.10, "boss_minion": 0.50}.get(kind, 0.0)
	if rng.next() >= chance:
		return null
	return String(rng.pick(VARIANT_WEIGHTS))


static func traits_for(rec: Variant, variant_id: Variant = null) -> Array:
	var out := []
	if rec is Dictionary:
		for t in rec.get("traits", []):
			if not out.has(t):
				out.append(t)
	var v = variant_record(variant_id)
	if v != null and v.get("trait") and not out.has(v.trait):
		out.append(v.trait)
	return out


static func default_drops(region_id: String, boss: bool = false) -> Array:
	if boss:
		return [{"kind": "materials", "qty": [8, 14], "chance": 1.0},
			{"kind": "ingredient", "chance": 0.35}]
	return [{"kind": "materials", "qty": [2, 5], "chance": 1.0},
		{"kind": "ingredient", "chance": 0.22},
		{"kind": "collectible", "chance": 0.008}]


static func legacy_traits(archetype: String) -> Array:
	if archetype == "brute":
		return ["armored"]
	if archetype == "boss":
		return ["armored"]
	if archetype == "healer":
		return ["regen"]
	return []


# ------------------------------------------------------------------ drops
static func drop_rows(d: Dictionary, carrier: Dictionary, first_kill: bool, rng: U.Rng) -> Array:
	var eid := String(carrier.get("enemyId", ""))
	var rec = entry(eid)
	var region_id := String(carrier.get("regionId", ""))
	if rec == null:
		var e = World.enemy(eid)
		if e == null:
			return []
		region_id = str(e.get("regionId", region_id))
		rec = {"drops": default_drops(region_id, bool(e.get("boss", false)))}
	var drops: Array = rec.get("drops", default_drops(region_id, false))
	var rows := []
	for drop in drops:
		if not (drop is Dictionary):
			continue
		if drop.get("firstOnly", false) and not first_kill:
			continue
		var chance := float(drop.get("chance", 1.0))
		if chance < 1.0 and rng.next() >= chance:
			continue
		var row = _row_for_drop(d, drop, region_id, rng)
		if row != null:
			rows.append(row)
	var variant = variant_record(carrier.get("variant"))
	if variant != null and not bool(carrier.get("rare", false)) and variant.get("drop"):
		if rng.next() < 0.35:
			var extra = _variant_drop(d, String(variant.drop), region_id, rng)
			if extra != null:
				rows.append(extra)
	return rows


static func _row_for_drop(d: Dictionary, drop: Dictionary, region_id: String, rng: U.Rng) -> Variant:
	var kind := String(drop.get("kind", ""))
	var qty := _qty(drop.get("qty", 1), rng)
	match kind:
		"gold":
			return {"id": "gold", "kind": "gold", "ref": null, "qty": qty, "rarity": "common", "icon": "gold"}
		"materials":
			return {"id": "materials", "kind": "materials", "ref": null, "qty": qty, "rarity": "common", "icon": "materials"}
		"food":
			return {"id": "food", "kind": "food", "ref": null, "qty": qty, "rarity": "common", "icon": "food"}
		"supplies":
			return {"id": "supplies", "kind": "supplies", "ref": null, "qty": qty, "rarity": "common", "icon": "supplies"}
		"ingredient":
			var iid := String(drop.get("id", ""))
			if iid == "" or not C.data.INGREDIENTS.has(iid):
				iid = _region_ingredient(region_id)
			if iid == "":
				return null
			return {"id": "ing:" + iid, "kind": "ingredient", "ref": iid, "qty": qty, "rarity": "uncommon", "icon": "ing_" + iid}
		"specialty":
			var sid := String(drop.get("id", ""))
			if sid == "":
				var reg = C.region(region_id)
				sid = String(reg.specialtyId) if reg != null else ""
			if sid == "":
				return null
			return {"id": "spec:" + sid, "kind": "specialty", "ref": sid, "qty": qty, "rarity": "uncommon", "icon": "sp_" + sid}
		"item":
			var item_id := String(drop.get("id", ""))
			if not C.ITEMS.has(item_id):
				return null
			return {"id": "item:" + item_id, "kind": "item", "ref": item_id, "qty": qty,
				"rarity": _item_rarity(item_id), "icon": "ui_chest"}
		"collectible", "relic", "trophy", "chart", "lore", "curio":
			var cid := String(drop.get("id", ""))
			if cid == "":
				cid = _collectible_for(kind, region_id)
			if cid == "" or not C.COLLECTIBLES.has(cid):
				return null
			var row := Collections.row(d, cid)
			row.qty = qty
			return row
	return null


static func _variant_drop(d: Dictionary, kind: String, region_id: String, rng: U.Rng) -> Variant:
	if kind == "materials":
		return {"id": "materials", "kind": "materials", "ref": null, "qty": rng.range_int(2, 6),
			"rarity": "common", "icon": "materials"}
	if kind == "ingredient":
		var ing := _region_ingredient(region_id)
		if ing == "":
			return null
		return {"id": "ing:" + ing, "kind": "ingredient", "ref": ing, "qty": 1, "rarity": "uncommon", "icon": "ing_" + ing}
	var cid := _collectible_for(kind, region_id)
	if cid == "":
		return null
	return Collections.row(d, cid)


static func _qty(value: Variant, rng: U.Rng) -> int:
	if value is Array and value.size() >= 2:
		return rng.range_int(int(value[0]), int(value[1]))
	return max(1, int(value))


static func _region_ingredient(region_id: String) -> String:
	var reg = C.region(region_id)
	if reg == null:
		return ""
	var t: int = int(reg.tier)
	var keys: Array = C.data.INGREDIENTS.keys()
	if keys.is_empty():
		return ""
	return String(keys[(t - 1) % keys.size()])


static func _collectible_for(kind: String, region_id: String) -> String:
	var want := "relic" if kind == "relic" else kind
	for cid in C.COLLECTIBLES:
		var rec: Dictionary = C.COLLECTIBLES[cid]
		if String(rec.get("kind", "")) == want and String(rec.get("regionId", "")) == region_id:
			return String(cid)
	return ""


static func _item_rarity(item_id: String) -> String:
	var it: Dictionary = C.ITEMS.get(item_id, {})
	if it.get("unique", false):
		return "legendary"
	if int(it.get("tier", 1)) >= 4:
		return "epic"
	return "rare"


static func lore_key(enemy_id: String) -> String:
	var rec = entry(enemy_id)
	if rec is Dictionary and rec.get("loreKey"):
		return String(rec.loreKey)
	return ""


static func name_key(enemy_id: String) -> String:
	return "enemy." + enemy_id + ".name"
