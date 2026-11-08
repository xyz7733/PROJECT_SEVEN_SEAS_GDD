## Content integrity checks: every expansion ID resolves and every display
## key exists in the shipped translations.
class_name TestContent
extends RefCounted


static func run(t: TestKit) -> void:
	_test_monsters(t)
	_test_collectibles(t)
	_test_regions(t)
	_test_shop(t)


static func _test_monsters(t: TestKit) -> void:
	for group in ["MONSTERS", "BOSSES", "RARES"]:
		for rec in C.BESTIARY.get(group, []):
			var id := String(rec.get("id", ""))
			t.ok(id != "", group + " record has no id")
			t.ok(C.MONSTERS_BY_ID.has(id), "catalogue missing " + id)
			t.ok(World.enemy(id) != null, "World.enemy failed for " + id)
			t.ok(not Art.creature_info(id).is_empty(), "missing creature sprite " + id)
			var arch := String(rec.get("archetype", ""))
			t.ok(C.data.ENEMY_ARCHETYPES.has(arch), "unknown archetype %s on %s" % [arch, id])
			var region_id := str(rec.get("regionId", ""))
			t.ok(rec.get("regionId") == null or C.REGION_BY_ID.has(region_id), "unknown region %s on %s" % [region_id, id])
			for skill in rec.get("skills", []):
				t.ok(C.SKILLS.has(String(skill)), "unknown skill %s on %s" % [skill, id])
			for trait_id in rec.get("traits", []):
				t.ok(C.BESTIARY.TRAITS.has(String(trait_id)), "unknown trait %s on %s" % [trait_id, id])
			var variant = rec.get("variant")
			if variant != null:
				t.ok(C.BESTIARY.VARIANTS.has(String(variant)), "unknown variant %s on %s" % [variant, id])
			for drop in rec.get("drops", []):
				_check_drop(t, drop, id)
			t.ok(I18n.has("enemy." + id + ".name"), "missing enemy name key " + id)
			var lore_key := String(rec.get("loreKey", ""))
			if lore_key != "":
				t.ok(I18n.has(lore_key), "missing lore key " + lore_key)
	for tid in C.BESTIARY.TRAITS:
		t.ok(I18n.has("etrait." + tid + ".name"), "missing trait name " + tid)
		t.ok(I18n.has("etrait." + tid + ".desc"), "missing trait desc " + tid)
	for sid in C.BESTIARY.SKILLS:
		t.ok(I18n.has("eskill." + sid + ".name"), "missing skill name " + sid)
	for vid in C.BESTIARY.VARIANTS:
		t.ok(I18n.has("variant." + vid + ".name"), "missing variant name " + vid)


static func _check_drop(t: TestKit, drop: Variant, owner_id: String) -> void:
	if not (drop is Dictionary):
		t.ok(false, "non-dictionary drop on " + owner_id)
		return
	var kind := String(drop.get("kind", ""))
	var ref := String(drop.get("id", ""))
	match kind:
		"item":
			t.ok(C.ITEMS.has(ref), "missing drop item %s on %s" % [ref, owner_id])
		"ingredient":
			t.ok(ref == "" or C.data.INGREDIENTS.has(ref), "missing drop ingredient %s on %s" % [ref, owner_id])
		"relic", "trophy", "chart", "lore", "curio", "collectible":
			t.ok(ref == "" or C.COLLECTIBLES.has(ref), "missing drop collectible %s on %s" % [ref, owner_id])
		"gold", "materials", "food", "supplies", "specialty", "egg":
			pass
		_:
			t.ok(false, "unknown drop kind %s on %s" % [kind, owner_id])
	t.ok(float(drop.get("chance", 1.0)) > 0.0 and float(drop.get("chance", 1.0)) <= 1.0,
		"bad drop chance on " + owner_id)


static func _test_collectibles(t: TestKit) -> void:
	for cid in C.COLLECTIBLES:
		var rec: Dictionary = C.COLLECTIBLES[cid]
		t.eq(String(rec.get("id", "")), String(cid), "collectible id mismatch " + String(cid))
		t.ok(Collections.KINDS.has(String(rec.get("kind", ""))), "bad collectible kind " + String(cid))
		t.ok(I18n.has(Collections.name_key(String(cid))), "missing collectible name " + String(cid))
		t.ok(I18n.has(Collections.desc_key(String(cid))), "missing collectible desc " + String(cid))
		t.ok(Art.has_icon(Collections.icon(String(cid))), "missing collectible icon " + String(cid))
		if String(rec.get("kind", "")) == "chart":
			var loc := String(rec.get("locationId", ""))
			t.ok(C.LOCATIONS.has(loc), "chart %s points at missing location %s" % [cid, loc])
			t.ok(C.LOCATIONS.has(String(rec.get("revealLocationId", loc))), "chart reveal missing " + String(cid))
	for sid in C.COLLECTION_SETS:
		var set: Dictionary = C.COLLECTION_SETS[sid]
		t.ok(I18n.has("set." + sid + ".name"), "missing set name " + sid)
		t.ok(I18n.has("set." + sid + ".desc"), "missing set desc " + sid)
		t.ok(set.get("members", []).size() > 0, "empty set " + sid)
		for member in set.get("members", []):
			t.ok(C.COLLECTIBLES.has(String(member)), "set %s references missing %s" % [sid, member])
		var bonus: Dictionary = set.get("bonus", {})
		var item = bonus.get("item")
		if item != null:
			t.ok(C.ITEMS.has(String(item)), "set %s bonus item missing %s" % [sid, item])
	t.ok(C.COLLECTIBLES.size() >= 80, "collection catalogue too small")


static func _test_regions(t: TestKit) -> void:
	for r in C.REGIONS:
		var rd: Dictionary = C.BESTIARY.REGIONS.get(r.id, {})
		t.ok(not rd.is_empty(), "missing expansion region data " + String(r.id))
		var boss := Bestiary.region_boss(String(r.id), 6)
		t.ok(boss != "" and World.enemy(boss) != null, "missing region boss " + String(r.id))
		var rare = Bestiary.region_rare(String(r.id))
		t.ok(rare != null and World.enemy(String(rare)) != null, "missing region rare " + String(r.id))
		for arch in Bestiary.region_archetypes(String(r.id)):
			t.ok(Bestiary.region_roster(String(r.id), String(arch)).size() > 0,
				"empty roster %s/%s" % [r.id, arch])
		for pool_name in ["seaMonsters"]:
			for id in rd.get(pool_name, []):
				t.ok(World.enemy(String(id)) != null, "bad sea monster %s in %s" % [id, r.id])
	for key in ["battle", "elite", "boss"]:
		for group in C.world.GROUPS.get(key, []):
			for arch in group:
				if arch == "boss":
					continue
				t.ok(C.data.ENEMY_ARCHETYPES.has(String(arch)), "bad group archetype " + String(arch))


static func _test_shop(t: TestKit) -> void:
	for offer in C.SHOP_ITEMS:
		t.ok(C.ITEMS.has(String(offer.get("id", ""))), "shop item missing " + str(offer))
		t.ok(int(offer.get("marketLevel", 0)) >= 1, "bad shop market level")
