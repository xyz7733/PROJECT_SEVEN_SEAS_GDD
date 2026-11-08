## World generation helpers ported from the reference world module:
## enemy records, encounter definitions, sea encounters and room rewards.
class_name World
extends RefCounted

const GROUPS_KEY := "GROUPS"


static func distance(a: String, b: String) -> float:
	var la = C.location(a)
	var lb = C.location(b)
	if not la or not lb:
		return 0.0
	var ra: int = C.region(la.regionId).order
	var rb: int = C.region(lb.regionId).order
	if ra == rb:
		return Vector2(float(la.x) - float(lb.x), float(la.y) - float(lb.y)).length()
	return abs(ra - rb) * 0.9 + 0.3


## Resolves an enemy id to its record: rival, pirate, decoy, roster member or boss.
static func enemy(enemy_id: String) -> Variant:
	var rivals: Dictionary = C.world.RIVALS
	if rivals.has(enemy_id):
		var r = rivals[enemy_id]
		return {"id": enemy_id, "archetype": "captain", "regionId": r.regionId, "skills": r.skills, "mult": r.mult,
			"burn": bool(r.get("burn", false)), "regen": r.get("regen", 0), "boss": true, "rival": true}
	var pirates: Dictionary = C.data.PIRATES
	if pirates.has(enemy_id):
		var a = C.data.ENEMY_ARCHETYPES[pirates[enemy_id]]
		return {"id": enemy_id, "archetype": pirates[enemy_id], "regionId": null, "skills": a.skills, "mult": 1, "pirate": true}
	if enemy_id == "crystal_decoy":
		return {"id": enemy_id, "archetype": "decoy", "regionId": "glass_current", "skills": [], "mult": 1, "decoy": true}
	for r in C.REGIONS:
		for arch in r.enemies:
			if r.enemies[arch] == enemy_id:
				var skills: Array = C.data.ENEMY_ARCHETYPES[arch].skills.duplicate()
				if r.mechanic == "intent" and arch == "brute":
					skills = ["e_charge"]
				if r.mechanic == "decoys" and arch == "brute":
					skills = ["e_crush", "e_shell"]
				if r.mechanic == "sealed" and arch == "caster":
					skills = ["e_hex", "e_stun_all"]
				return {"id": enemy_id, "archetype": arch, "regionId": r.id, "skills": skills, "mult": 1,
					"burn": r.mechanic == "burning" and (arch == "skirmisher" or arch == "shooter")}
		var bi: int = r.bosses.find(enemy_id)
		if bi >= 0:
			var skills := ["e_crush", "e_roar" if bi == 0 else "e_stun_all"]
			if r.mechanic == "sealed" or r.mechanic == "decoys":
				skills.append("e_shell")
			if r.mechanic == "intent":
				skills.append("e_charge")
			return {"id": enemy_id, "archetype": "boss", "regionId": r.id, "skills": skills, "mult": 1.0 + 0.06 * bi,
				"boss": true, "regen": 0.01 if r.mechanic == "sealed" else 0.0, "burn": r.mechanic == "burning"}
	return null


static func all_enemy_ids() -> Array:
	var ids := []
	for r in C.REGIONS:
		ids.append_array(r.enemies.values())
		ids.append_array(r.bosses)
	ids.append_array(C.data.PIRATES.keys())
	ids.append("crystal_decoy")
	ids.append_array(C.world.RIVALS.keys())
	return ids


static func _wave_entry(enemy_id: String, level: int) -> Dictionary:
	return {"enemyId": enemy_id, "level": level}


## Builds an encounter definition for a room (GDD encounter record).
static func encounter_for(loc_id: String, room_id: String, opts: Dictionary = {}) -> Dictionary:
	var loc = C.location(loc_id)
	var r = C.region(loc.regionId)
	var rm = C.room(loc_id, room_id)
	var rand := U.Rng.new(U.hash32("%s:%s:%s" % [loc_id, room_id, str(opts.get("variant", 0))]))
	var lvl: int = int(loc.level) + (1 if rm and rm.kind == "elite" else 0) + (2 if rm and rm.kind == "boss" else 0)
	var mods := []
	if r.hazard:
		mods.append(r.hazard)
	if r.mechanic:
		mods.append(r.mechanic)
	var waves := []
	var legend: bool = opts.get("legend", false)
	if rm and rm.kind == "trial":
		for w in r.trial.waves:
			var wave := []
			for entry in w:
				var arch: String = entry[0]
				if arch == "captain":
					wave.append(_wave_entry(r.rivalId, loc.level))
				elif arch == "rival":
					wave.append(_wave_entry(entry[1], int(loc.level) - 2))
				elif arch == "decoy":
					wave.append(_wave_entry("crystal_decoy", loc.level))
				else:
					wave.append(_wave_entry(r.enemies[arch], int(loc.level) - 1))
			waves.append(wave)
		if legend:
			var lg = C.world.LEGENDS[r.id]
			for w in waves:
				for e in w:
					e.level = int(e.level) + int(lg.levelBonus)
			if lg.restriction == "endless_waves":
				waves.append(waves[1].duplicate(true))
				waves.append(waves[0].duplicate(true))
			mods.append("legend_" + lg.restriction)
		else:
			mods.append("trial")
	else:
		var kind := "battle"
		if rm:
			kind = "boss" if rm.kind == "boss" else ("elite" if rm.kind == "elite" else "battle")
		var pool: Array = C.world.GROUPS[kind]
		var group: Array = pool[int(floor(rand.next() * pool.size()))].duplicate()
		if r.mechanic == "mixed":
			group = ["brute", "shooter", "caster"] if kind == "battle" else ["brute", "shooter", "caster", "healer"]
		if r.mechanic == "disruptor" and kind != "boss":
			group[group.size() - 1] = "caster"
		var boss_id: String = r.bosses[0] if int(loc.slot) == 5 else r.bosses[1]
		var wave := []
		for arch in group:
			wave.append(_wave_entry(boss_id if arch == "boss" else r.enemies[arch], lvl))
		if r.mechanic == "decoys":
			wave.push_front(_wave_entry("crystal_decoy", lvl))
		if r.mechanic == "elite":
			wave.append(_wave_entry(r.enemies.skirmisher, lvl - 1))
		waves = [wave]
		if r.mechanic == "waves" and (kind == "elite" or kind == "boss"):
			waves.push_front([_wave_entry(r.enemies.skirmisher, lvl - 1), _wave_entry(r.enemies.shooter, lvl - 1), _wave_entry(r.enemies.skirmisher, lvl - 1)])
	return {
		"id": loc_id + ":" + room_id + (":legend" if legend else ""), "locationId": loc_id, "roomId": room_id, "regionId": r.id,
		"arena": "arena" if loc.type == "arena" else loc.type, "waves": waves, "modifiers": mods, "level": lvl,
		"kind": rm.kind if rm else "battle", "staminaCost": (int(rm.cost) + (10 if legend else 0)) if rm else 0,
		"retreat": {"escapeSecs": 3}, "legend": legend, "restriction": C.world.LEGENDS[r.id].restriction if legend else null,
	}


## Forced boarding at sea: pirates or regional monsters.
static func sea_encounter(region_id: String, kind: String, variant: int, level: int) -> Dictionary:
	var r = C.region(region_id)
	var rand := U.Rng.new(U.hash32("%s:sea:%s:%d" % [region_id, kind, variant]))
	var wave := []
	if kind == "pirate":
		var ids: Array = C.data.PIRATES.keys()
		var n := 4 if int(r.tier) >= 4 else 3
		wave.append(_wave_entry("pennant_bosun", level))
		for i in range(1, n):
			wave.append(_wave_entry(ids[int(floor(rand.next() * ids.size()))], level))
	else:
		var battle: Array = C.world.GROUPS.battle
		var g: Array = battle[int(floor(rand.next() * battle.size()))]
		for a in g:
			wave.append(_wave_entry(r.enemies[a], level))
	var mods := ["boarding"]
	if r.hazard:
		mods.append(r.hazard)
	return {"id": "sea:%s:%s" % [region_id, kind], "locationId": null, "roomId": null, "regionId": region_id, "arena": "boarding",
		"waves": [wave], "modifiers": mods, "level": level, "kind": "boarding", "staminaCost": 0, "forced": true,
		"retreat": {"escapeSecs": 3}, "legend": false, "restriction": null}


## Room reward table: fixed first-clear rewards and smaller repeat rewards.
static func room_rewards(loc_id: String, room_id: String, first: bool) -> Dictionary:
	var loc = C.location(loc_id)
	var r = C.region(loc.regionId)
	var rm = C.room(loc_id, room_id)
	var t: int = r.tier
	var out := {"gold": 0, "materials": 0, "food": 0, "supplies": 0, "specialty": 0, "ingredient": 0, "egg": null,
		"items": [], "unique": null, "clue": null, "shortcut": false}
	var k: String = rm.kind
	var secret: bool = rm.get("secret", false)
	match k:
		"battle":
			out.gold = 10 + 12 * t; out.materials = 3 + 2 * t
		"elite":
			out.gold = 18 + 22 * t; out.materials = 6 + 3 * t; out.ingredient = 1; out.specialty = 1
		"boss":
			out.gold = 40 + 45 * t; out.materials = 12 + 4 * t; out.specialty = 2; out.supplies = 1
		"resource":
			out.materials = 5 + 3 * t; out.specialty = 1; out.food = 2 if loc.type == "island" else 0; out.ingredient = 1
		"event":
			out.materials = 6 + 2 * t; out.ingredient = 2
		"trial":
			out.gold = 100 + 90 * t; out.materials = 10 + 5 * t; out.specialty = 2
	if secret:
		out.specialty += 1
		out.ingredient += 1
	if not first:
		out.gold = U.jround(out.gold * 0.5)
		out.materials = U.jround(out.materials * 0.6)
		out.specialty = min(out.specialty, 1)
		out.food = min(out.food, 1)
		out.supplies = 0
		if k == "resource":
			out.ingredient = 1
		return out
	out.gold = U.jround(out.gold * 1.5)
	var uniq: Array = C.world.UNIQUE_BY_REGION[r.id]
	if k == "resource" and not secret:
		out.specialty += 1
	if k == "boss" and int(loc.slot) == 5:
		out.unique = uniq[0]
	if k == "boss" and int(loc.slot) == 6:
		out.egg = {"familyId": r.petFamilyId, "grade": 2}
	if k == "elite" and loc.type == "wreck":
		out.items.append("a_" + C.data.REGIONAL_ACCESSORIES[t - 1].id)
	if k == "elite" and loc.type == "island":
		out.items.append(("o_coat_%d" % t) if t % 2 == 1 else ("w_blade_%d" % t))
	if secret:
		out.egg = {"familyId": r.petFamilyId, "grade": 1}
	if k == "event":
		out.egg = {"familyId": r.petFamilyId, "grade": 3}
		out.clue = "clue.pet." + r.petFamilyId
		out.shortcut = true
	if k == "trial":
		out.unique = uniq[1]
	return out
