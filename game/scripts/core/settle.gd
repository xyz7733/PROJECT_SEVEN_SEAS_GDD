## Post-battle settlement.
##
## A battle's spoils are planned from the encounter and the captain's
## standing bonuses, which a fight does not change: a list of ledger rows
## (kind, quantity, rarity) and the share of every row that each opponent
## carries. The plan is seeded by the attempt, so the battle view (live
## drops when an opponent falls) and Actions.end_encounter (which stores it
## on the encounter) get the same plan. Nothing is granted during the
## fight. When the player closes the post-battle report,
## Actions.resolve_encounter grants exactly the stored rows in one
## transaction, together with the recruit decision.
##
## The recruit offer is a chance driven by the defeated opponents: only
## people (not creatures, constructs, spirits or decoys) can ask to sign on,
## each archetype has its own base chance, and the encounter kind scales it.
## The roll is seeded by the profile and the attempt id, so reloading the
## report shows the same offer.
class_name Settle
extends RefCounted

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]

## Base chance per defeated person of this archetype.
const RECRUIT_BASE := {"skirmisher": 0.12, "shooter": 0.12, "healer": 0.12, "caster": 0.08, "brute": 0.06}
## Encounter kind scale. Trials and legends are duels with a rival's crew
## and never yield recruits; boss guards rarely do.
const RECRUIT_KIND := {"battle": 1.0, "elite": 1.15, "boss": 0.6, "boarding": 1.0, "trial": 0.0}
const RECRUIT_CAP := 0.45
## Base classes a recruit of each archetype can arrive as.
const RECRUIT_CLASSES := {
	"skirmisher": ["duelist", "brawler", "quartermaster"],
	"brute": ["guard", "brawler", "spearfighter"],
	"shooter": ["gunner", "navigator", "tinkerer"],
	"caster": ["mystic", "beastkeeper"],
	"healer": ["medic", "cook"],
}
## Regional opponents who are people. Every other regional opponent is a
## creature, construct or spirit. Pennant pirates are always people; rivals
## and bosses never join.
const HUMANS := [
	"gull_raider", "spray_gunner", "brine_witch", "kelp_tender",
	"ash_slinger", "flame_seer", "ember_monk",
	"thorn_archer", "spore_shaman", "bloom_nurse",
	"shard_fencer", "prism_sniper", "mirror_mage", "lens_cleric",
	"cutpurse", "crown_enforcer", "musket_noble", "court_hexer", "gilded_medic",
	"squall_runner", "gale_harpooner", "storm_witch", "beacon_keeper",
	"star_archer", "moon_oracle",
	"relic_thief", "trench_gunner", "ash_hexer", "deep_priest",
	"ring_raider", "tide_shaman", "reef_mender",
	"gate_duelist", "horizon_knight", "sky_gunner", "dawn_mage", "conclave_medic",
]
## Pirate base chances (the bosun commands and seldom turns coat).
const PIRATE_BASE := {"pennant_deckhand": 0.16, "pennant_gunner": 0.12, "pennant_hexer": 0.08, "pennant_surgeon": 0.12, "pennant_bosun": 0.04}


## True when the opponent id is a person.
static func is_human(enemy_id: String) -> bool:
	return HUMANS.has(enemy_id) or C.data.PIRATES.has(enemy_id)


## Chance that this defeated opponent asks to join, before the kind scale.
static func base_chance(enemy_id: String) -> float:
	if C.data.PIRATES.has(enemy_id):
		return float(PIRATE_BASE.get(enemy_id, 0.1))
	if not HUMANS.has(enemy_id):
		return 0.0
	var e = World.enemy(enemy_id)
	if e == null or e.get("boss", false) or e.get("rival", false):
		return 0.0
	return float(RECRUIT_BASE.get(String(e.archetype), 0.0))


# ===================================================================== plan
## The encounter's location record (rooms and trials) or the voyage's
## destination (sea encounters).
static func location_of(ctx: Dictionary) -> Variant:
	if ctx.get("locationId"):
		return C.location(String(ctx.locationId))
	if ctx.get("toId"):
		return C.location(String(ctx.toId))
	return null


## The raw reward table of a won encounter (before the captain's bonuses).
static func table(d: Dictionary, def: Dictionary, ctx: Dictionary) -> Dictionary:
	var loc = location_of(ctx)
	var reg: Dictionary = C.region(String(loc.regionId)) if loc != null else C.region(String(def.get("regionId", "dawnwater")))
	if ctx.type == "sea":
		var pen := 1.0 + 0.05 * Rules.rep_rank(d, "pennants")
		return {"gold": U.jround((15.0 + 12.0 * float(reg.tier)) * pen), "materials": 4 + 2 * int(reg.tier),
			"food": 0, "supplies": 0, "specialty": 0, "ingredient": 1 if ctx.get("kind") == "monster" else 0, "items": []}
	if ctx.type == "legend":
		var first: bool = not d.captain.legendsWon.has(loc.regionId)
		var rw := World.room_rewards(ctx.locationId, "trial", false)
		if first:
			rw.unique = C.world.LEGENDS[loc.regionId].reward
		return rw
	var first_clear: bool = not d.world.locations[ctx.locationId].rooms.has(ctx.roomId)
	return World.room_rewards(ctx.locationId, ctx.roomId, first_clear)


static func item_icon(item_id: String) -> String:
	var it = C.ITEMS.get(item_id)
	if it == null:
		return "ui_chest"
	if it.get("wtype"):
		return "w_" + String(it.wtype)
	return "w_outfit" if it.slot == "outfit" else "w_accessory"


static func rarity_of_item(item_id: String) -> String:
	var it = C.ITEMS.get(item_id)
	if it == null:
		return "rare"
	if it.get("unique", false):
		return "legendary"
	if String(item_id).begins_with("a_"):
		return "epic"
	return "rare"


## Turns a reward table into ledger rows with the captain's bonuses applied.
## `pick` chooses an ingredient from a key list (seeded per caller).
## Row: {id, kind, ref, qty, rarity, icon}.
static func roll(d: Dictionary, r: Dictionary, loc: Variant, pick: Callable) -> Array:
	var bonus := 1.0 + Actions.crew_mod_max(d, "lootPct") + Collections.mod(d, "lootPct")
	var gold_pct := 1.0 + Actions.crew_mod_max(d, "goldPct") + Collections.mod(d, "goldPct")
	var bench := 1.0 + 0.15 * Rules.fac_level(d, "material_bench") * Rules.staff_mult(d, "material_bench")
	var rows := []
	var gold := U.jround(float(r.get("gold", 0)) * gold_pct)
	if gold > 0:
		rows.append({"id": "gold", "kind": "gold", "ref": null, "qty": gold, "rarity": "common", "icon": "gold"})
	var mats := U.jround(float(r.get("materials", 0)) * bonus * bench)
	if mats > 0:
		rows.append({"id": "materials", "kind": "materials", "ref": null, "qty": mats, "rarity": "common", "icon": "materials"})
	if int(r.get("food", 0)) > 0:
		rows.append({"id": "food", "kind": "food", "ref": null, "qty": int(r.food), "rarity": "common", "icon": "food"})
	if int(r.get("supplies", 0)) > 0:
		rows.append({"id": "supplies", "kind": "supplies", "ref": null, "qty": int(r.supplies), "rarity": "common", "icon": "supplies"})
	var reg = C.region(String(loc.regionId)) if loc != null else null
	if int(r.get("specialty", 0)) > 0 and reg != null:
		var n := U.jround(float(r.specialty) * bonus)
		if n > 0:
			var sid := String(reg.specialtyId)
			rows.append({"id": "spec:" + sid, "kind": "specialty", "ref": sid, "qty": n, "rarity": "uncommon", "icon": "sp_" + sid})
	if int(r.get("ingredient", 0)) > 0:
		var keys: Array = C.data.INGREDIENTS.keys()
		var by := {}
		var order := []
		for i in int(r.ingredient):
			var ing := String(pick.call(keys))
			if not by.has(ing):
				by[ing] = 0
				order.append(ing)
			by[ing] = int(by[ing]) + 1
		for ing in order:
			rows.append({"id": "ing:" + ing, "kind": "ingredient", "ref": ing, "qty": by[ing], "rarity": "uncommon", "icon": "ing_" + ing})
	if r.get("egg") != null:
		var g := int(r.egg.grade)
		rows.append({"id": "egg", "kind": "egg", "ref": {"familyId": String(r.egg.familyId), "grade": g}, "qty": 1,
			"rarity": "rare" if g <= 1 else ("epic" if g == 2 else "legendary"), "icon": "ui_egg"})
	for it in r.get("items", []):
		rows.append({"id": "item:" + String(it), "kind": "item", "ref": String(it), "qty": 1, "rarity": rarity_of_item(String(it)), "icon": item_icon(String(it))})
	if r.get("unique") and not d.inventory.uniques.has(r.unique):
		rows.append({"id": "item:" + String(r.unique), "kind": "item", "ref": String(r.unique), "qty": 1, "rarity": "legendary", "icon": item_icon(String(r.unique))})
	if r.get("clue"):
		rows.append({"id": "clue", "kind": "clue", "ref": String(r.clue), "qty": 1, "rarity": "rare", "icon": "ui_quest"})
	return rows


## Grants ledger rows. Returns {out, rows}: `out` is the classic reward
## dictionary (gold, materials, food, supplies, specialty, ingredients,
## egg, items, clue) and `rows` are copies of the rows with what was
## actually stored: got, lost (no room) and salvaged (materials for
## equipment that did not fit in the sea chest).
static func grant(d: Dictionary, rows: Array, r: Dictionary, loc: Variant) -> Dictionary:
	var out := {"gold": 0, "materials": 0, "items": [], "collectibles": [], "shards": 0}
	var done_rows := []
	var reg = C.region(String(loc.regionId)) if loc != null else null
	for row0 in rows:
		var row: Dictionary = row0.duplicate(true)
		var q := int(row.qty)
		row.qty = q
		row.got = q
		row.lost = 0
		row.salvaged = 0
		match String(row.kind):
			"gold":
				Actions.gain(d, {"gold": q})
				out.gold = int(out.gold) + q
			"materials":
				Actions.gain(d, {"materials": q})
				out.materials = int(out.materials) + q
			"food":
				row.got = Actions.add_food(d, q)
				row.lost = q - int(row.got)
				out.food = row.got
			"supplies":
				row.got = Actions.add_supplies(d, q)
				row.lost = q - int(row.got)
				out.supplies = row.got
			"specialty":
				Actions.add_specialty(d, String(row.ref), q)
				out.specialty = [String(row.ref), q]
			"ingredient":
				Actions.add_ingredient(d, String(row.ref), q)
				if not out.has("ingredients"):
					out.ingredients = []
				for i in q:
					out.ingredients.append(String(row.ref))
			"egg":
				Actions.add_egg(d, String(row.ref.familyId), int(row.ref.grade))
				out.egg = row.ref
			"item":
				var iid := String(row.ref)
				if C.ITEMS.get(iid, {}).get("unique", false) and d.inventory.uniques.has(iid):
					row.got = 0
				elif Actions.add_equipment(d, iid) != null:
					out.items.append(iid)
				else:
					row.got = 0
					row.salvaged = int(Rules.salvage_value({"itemId": iid, "reinforce": 0}).materials)
			"clue":
				Actions.add_clue(d, String(row.ref))
				out.clue = row.ref
			"collectible", "relic", "trophy", "chart", "lore", "curio":
				var cid := String(row.ref)
				var new_count := 0
				var shards := 0
				var reveal = null
				for i in maxi(1, q):
					var res := Collections.grant(d, cid)
					if not bool(res.get("ok", false)):
						break
					if bool(res.get("new", false)):
						new_count += 1
						if reveal == null:
							reveal = res.get("revealLocationId")
					shards += int(res.get("shards", 0))
				row.qty = maxi(1, q)
				row.got = new_count
				row.new = new_count > 0
				row.duplicate = new_count == 0
				row.shards = shards
				row.lost = 0 if new_count > 0 or shards > 0 else q
				out.shards = int(out.shards) + shards
				out.collectibles.append({"id": cid, "new": row.new, "shards": shards})
				if reveal != null:
					Actions.reveal(d, String(reveal))
		done_rows.append(row)
	if r.get("shortcut") and reg != null:
		d.world.shortcuts[reg.id] = true
	return {"out": out, "rows": done_rows}


## Opponents that carry spoils, in wave order:
## {uid, enemyId, weight, regionId, variant, rare, wave}.
## Decoys and summoned units carry nothing; bosses and rivals carry a
## larger share.
static func carriers(def: Dictionary) -> Array:
	var out := []
	var waves: Array = def.waves
	for w in waves.size():
		var wave: Array = waves[w]
		for i in wave.size():
			var entry: Dictionary = wave[i]
			if entry.get("summoned", false):
				continue
			var eid := String(entry.enemyId)
			var e = World.enemy(eid)
			if e == null or e.get("decoy", false):
				continue
			var wt := 3.0 if (e.get("boss", false) or e.get("rival", false)) else 1.0
			var region_id := str(e.get("regionId", ""))
			if region_id == "":
				region_id = String(def.get("regionId", ""))
			out.append({"uid": "e%d_%d" % [w, i], "enemyId": eid, "weight": wt, "wave": w,
				"regionId": region_id, "variant": entry.get("variant"), "rare": bool(entry.get("rare", false))})
	return out


## Splits `qty` units over carriers by weight (largest remainder; ties go
## to the later carrier). Returns an Array of ints.
static func _split(qty: int, carriers_list: Array) -> Array:
	var tot := 0.0
	for c in carriers_list:
		tot += float(c.weight)
	var parts := []
	var rems := []
	var given := 0
	for i in carriers_list.size():
		var exact := float(qty) * float(carriers_list[i].weight) / maxf(tot, 0.001)
		var f := int(floor(exact))
		parts.append(f)
		rems.append([exact - f, i])
		given += f
	rems.sort_custom(func(a, b): return a[0] > b[0] or (is_equal_approx(a[0], b[0]) and a[1] > b[1]))
	var k := 0
	while given < qty and rems.size():
		parts[rems[k % rems.size()][1]] += 1
		given += 1
		k += 1
	return parts


## The full plan for an encounter: {rows, table, drops}. drops maps a
## carrier uid to [[row index, quantity], ...]; for every row the shares
## add up to the row's quantity. Deterministic for a state and encounter.
static func plan(d: Dictionary, enc: Dictionary) -> Dictionary:
	var def: Dictionary = enc.def
	var ctx: Dictionary = enc.context
	var loc = location_of(ctx)
	var r := table(d, def, ctx)
	var rng := U.Rng.new(U.seed_of(String(d.envelope.profileId) + ":loot:" + String(enc.attemptId)))
	var rows := roll(d, r, loc, func(keys: Array): return rng.pick(keys))
	var cs := carriers(def)
	var drops := {}
	if cs.is_empty():
		return {"rows": rows, "table": r, "drops": drops}
	var strongest := 0
	for i in cs.size():
		if float(cs[i].weight) >= float(cs[strongest].weight):
			strongest = i
	var rr := 0
	for ri in rows.size():
		var row: Dictionary = rows[ri]
		var shares := []
		match String(row.kind):
			"gold", "materials":
				shares = _split(int(row.qty), cs)
			"item", "egg", "clue":
				shares = []
				for i in cs.size():
					shares.append(int(row.qty) if i == strongest else 0)
			_:
				# Goods: one unit per carrier in turn, starting after the
				# strongest so they spread over the field.
				shares = []
				for i in cs.size():
					shares.append(0)
				for u in int(row.qty):
					var idx := (strongest + 1 + rr) % cs.size()
					shares[idx] += 1
					rr += 1
		for i in cs.size():
			if int(shares[i]) > 0:
				var uid: String = cs[i].uid
				if not drops.has(uid):
					drops[uid] = []
				drops[uid].append([ri, int(shares[i])])
	# Per-monster loot tables. This uses its own stream so the existing
	# room-reward rolls stay byte-identical for the same attempt.
	var drop_rng := U.Rng.new(U.seed_of(String(d.envelope.profileId) + ":drops:" + String(enc.attemptId)))
	var enemy_codex: Dictionary = d.codex.get("enemies", {})
	for c in cs:
		var rec: Dictionary = enemy_codex.get(c.enemyId, {})
		if not (rec is Dictionary):
			rec = {}
		var first_kill := int(rec.get("kills", rec.get("defeated", 0))) == 0
		var extra := Bestiary.drop_rows(d, c, first_kill, drop_rng)
		for row0 in extra:
			var row: Dictionary = row0
			var idx := rows.size()
			rows.append(row)
			var uid: String = c.uid
			if not drops.has(uid):
				drops[uid] = []
			drops[uid].append([idx, int(row.qty)])
	return {"rows": rows, "table": r, "drops": drops}


# ================================================================== recruit
## The recruit roll for a won encounter. Returns {} when no person was
## defeated, else {chance, humans, offered} and, when offered, the
## candidate: {enemyId, uid, member, full, crew, capacity}.
static func recruit_offer(d: Dictionary, enc: Dictionary) -> Dictionary:
	var def: Dictionary = enc.def
	if def.get("legend", false):
		return {}
	var kind_mult := float(RECRUIT_KIND.get(String(def.get("kind", "battle")), 1.0))
	var cands := []
	var waves: Array = def.waves
	for w in waves.size():
		for i in waves[w].size():
			var eid := String(waves[w][i].enemyId)
			var p := base_chance(eid) * kind_mult
			if p > 0.0:
				cands.append({"uid": "e%d_%d" % [w, i], "enemyId": eid, "p": p, "level": int(waves[w][i].level)})
	if cands.is_empty():
		return {}
	var miss := 1.0
	for c in cands:
		miss *= 1.0 - float(c.p)
	var chance := minf(RECRUIT_CAP, 1.0 - miss)
	var rng := U.Rng.new(U.seed_of(String(d.envelope.profileId) + ":recruit:" + String(enc.attemptId)))
	var out := {"chance": U.round2(chance), "humans": cands.size(), "offered": false}
	if rng.next() >= chance:
		return out
	var tot := 0.0
	for c in cands:
		tot += float(c.p)
	var x := rng.next() * tot
	var pickc: Dictionary = cands[cands.size() - 1]
	for c in cands:
		x -= float(c.p)
		if x < 0.0:
			pickc = c
			break
	var e = World.enemy(String(pickc.enemyId))
	var arch := String(C.data.PIRATES.get(pickc.enemyId, e.archetype if e != null else "skirmisher"))
	var reg = C.region(String(def.get("regionId", "dawnwater")))
	var origins: Array = C.data.ORIGINS
	var origin: String = origins[clampi(int(reg.order) - 1, 0, origins.size() - 1)] if reg != null else origins[0]
	var top := 1
	for m in d.crew:
		top = maxi(top, int(m.level))
	var level := clampi(int(pickc.level) - 1, 1, top)
	var seed_value := U.seed_of(String(d.envelope.profileId) + ":recruit:" + String(enc.attemptId) + ":" + String(pickc.uid))
	var m := GS.make_recruit(seed_value, {"classPool": RECRUIT_CLASSES.get(arch, C.data.BASE_CLASS_IDS), "originPool": [origin], "level": level})
	var cap := Rules.crew_capacity(d)
	out.offered = true
	out.enemyId = pickc.enemyId
	out.uid = pickc.uid
	out.member = m
	out.crew = d.crew.size()
	out.capacity = cap
	out.full = d.crew.size() >= cap
	return out
