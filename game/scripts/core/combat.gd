## Deterministic automatic combat. One engine serves island, dungeon, trial,
## monster and boarding fights. The same spec and command list always give
## the same result, so a reload cannot reroll an encounter. Commands are
## recorded with the tick they apply on. The battle view steps a live sim and
## reads its event log; resolution replays the spec with the recorded commands.
class_name Combat
extends RefCounted

const LANES := ["front", "center", "rear"]
const PRIORITY_ORDER := {
	"survival": ["survival", "support", "control", "damage"],
	"control": ["control", "damage", "support", "survival"],
	"damage": ["damage", "control", "support", "survival"],
	"support": ["support", "survival", "control", "damage"],
}
const STANCE := {
	"aggressive": {"dealt": 1.15, "taken": 1.1, "heal": 0.55, "dodge": 0.0},
	"balanced": {"dealt": 1.0, "taken": 1.0, "heal": 0.7, "dodge": 0.0},
	"defensive": {"dealt": 0.85, "taken": 0.8, "heal": 0.85, "dodge": 0.05},
	"escape": {"dealt": 0.6, "taken": 0.9, "heal": 0.8, "dodge": 0.15},
}
const STATUS_DECAY := ["stun", "slow", "mark", "taunt", "evade"]


static func dt() -> float:
	return float(C.TUNING.battleTick)


static func limit_ticks() -> int:
	return U.jround(float(C.TUNING.battleTimeLimit) / dt())


static func rnd(sim: Dictionary) -> float:
	sim.rs = (int(sim.rs) + 0x6d2b79f5) & U.M32
	return float(U.mix(sim.rs)) / 4294967296.0


# --------------------------------------------------------------- unit setup
static func make_status() -> Dictionary:
	return {"stun": 0.0, "slow": 0.0, "mark": 0.0, "taunt": 0.0, "evade": 0.0, "shield": 0, "buffAtk": 0.0, "buffAtkT": 0.0,
		"buffDef": 0.0, "buffDefT": 0.0, "regen": 0.0, "regenT": 0.0, "dot": 0.0, "dotT": 0.0, "sunder": 0, "sunderT": 0.0}


static func ally_unit(a: Dictionary, i: int) -> Dictionary:
	var s: Dictionary = a.stats
	var skills := []
	for id in s.get("skills", []):
		skills.append({"id": id, "cd": 0.0})
	var ratio: float = 1.0 if a.get("hpRatio") == null else float(a.hpRatio)
	var pet = null
	if a.get("pet") != null:
		pet = a.pet.duplicate(true)
		pet.timer = 3.0
	return {"uid": "a%d" % i, "side": "ally", "key": a.key, "defId": a.classId, "nameKey": a.get("nameKey"), "name": a.get("name"),
		"level": a.level, "lane": a.lane, "slot": a.slot, "range": s.range, "maxHp": s.hp, "hp": max(1, U.jround(float(s.hp) * ratio)),
		"atk": float(s.atk), "def": float(s.def), "spd": float(s.spd), "crit": float(s.crit), "dodge": float(s.dodge),
		"mods": s.get("mods", {}), "props": s.get("props", []), "resist": s.get("resist", []), "skills": skills,
		"roles": s.get("roles", []), "meter": 0.0, "st": make_status(), "alive": true, "boss": false, "decoy": false, "rival": false,
		"archetype": "", "pet": pet, "firstAidUsed": false, "windup": null, "dealt": 0, "healed": 0}


static func enemy_unit(e: Dictionary, i: int, wave: Variant, party_level: float) -> Dictionary:
	var def: Dictionary = World.enemy(e.enemyId)
	if def == null:
		return {}
	var arch: Dictionary = C.data.ENEMY_ARCHETYPES[def.archetype]
	var g: Dictionary = C.TUNING.enemyGrowth
	var sc: Dictionary = C.TUNING.enemyScale
	var L: int = max(1, int(e.level))
	var pl: float = party_level if party_level else float(L)
	var gap: float = max(0.55, min(2.2, 1.0 + float(C.TUNING.levelGap) * (L - pl)))
	var dm: float = float(def.get("mult", 1.0)) if def.get("mult") else 1.0
	var variant_id = e.get("variant", def.get("variant"))
	var vrec = Bestiary.variant_record(variant_id)
	var vm: Dictionary = vrec.get("mult", {}) if vrec is Dictionary else {}
	var m: float = dm * gap * (1.0 + float(sc.get("perLevel", 0)) * (L - 1))
	var hp := U.jround(float(arch.base.hp) * float(sc.hp) * (1.0 + float(g.hp) * (L - 1)) * m * float(vm.get("hp", 1.0)))
	var atk_mult: float = float(e.get("atkMult", 1.0)) if e.get("atkMult") else 1.0
	var skills := []
	for id in def.skills:
		skills.append({"id": id, "cd": float(2 + i)})
	var base_spd := float(arch.base.spd)
	var spd := (base_spd + float(g.spd) * (L - 1) * (1.0 if base_spd else 0.0)) * float(vm.get("spd", 1.0))
	var mods := {"regenPct": def.get("regen", 0)}
	var props: Array = ["burn"] if def.get("burn") else []
	var on_hit = null
	var summoner = null
	var volatile = null
	var splitter = null
	var berserk = null
	var survive_once := false
	var start_shield := 0.0
	for tid in Bestiary.traits_for(def, variant_id):
		var tr = C.BESTIARY.TRAITS.get(tid)
		if not (tr is Dictionary):
			continue
		U.add_mods(mods, tr.get("mods"))
		if tr.get("onHit") != null:
			on_hit = tr.onHit.duplicate(true)
		if tr.get("summon") != null:
			summoner = tr.summon.duplicate(true)
		if tr.get("onDeath") != null:
			if tr.onDeath.get("aoe") != null:
				volatile = tr.onDeath.duplicate(true)
			if tr.onDeath.get("spawn") != null:
				splitter = tr.onDeath.duplicate(true)
		if tr.get("hpBelow") != null:
			berserk = tr.duplicate(true)
		if tr.get("surviveOnce", false):
			survive_once = true
		start_shield += float(tr.get("startShield", 0.0))
	var st := make_status()
	st.shield = U.jround(float(hp) * start_shield)
	return {"uid": "e%s_%d" % [str(wave), i], "side": "enemy", "key": e.enemyId, "defId": e.enemyId, "nameKey": "enemy." + e.enemyId + ".name",
		"name": null, "level": L, "archetype": def.archetype, "lane": arch.lane, "slot": i, "range": arch.range, "maxHp": hp, "hp": hp,
		"atk": float(U.jround(float(arch.base.atk) * float(sc.atk) * (1.0 + float(g.atk) * (L - 1)) * m * atk_mult * float(vm.get("atk", 1.0)))),
		"def": float(U.jround(float(arch.base.def) * float(sc.def) * (1.0 + float(g.def) * (L - 1)) * dm * float(vm.get("def", 1.0)))),
		"spd": spd, "crit": 0.05 + U.num(mods, "crit"),
		"dodge": (0.05 if def.archetype == "skirmisher" else 0.0) + U.num(mods, "dodge"),
		"mods": mods, "props": props, "resist": [], "skills": skills, "roles": [], "meter": 0.0, "st": st,
		"alive": true, "boss": bool(def.get("boss", false)), "decoy": bool(def.get("decoy", false)), "rival": bool(def.get("rival", false)),
		"rare": bool(e.get("rare", def.get("rare", false))), "variantId": variant_id,
		"variantTint": vrec.get("tint") if vrec is Dictionary else null,
		"onHit": on_hit, "summoner": summoner, "volatile": volatile, "splitter": splitter, "berserk": berserk,
		"surviveOnce": survive_once, "survivedLethal": false, "enraged": false, "deathDone": false,
		"summoned": false, "summonOwner": null, "summonTimer": 0.0,
		"pet": null, "firstAidUsed": false, "windup": null, "dealt": 0, "healed": 0}


## spec: {allies: [{key, classId, level, slot, lane, stats, pet, hpRatio}], waves, modifiers, seed, stance, priority, bonuses}
static func create(spec: Dictionary) -> Dictionary:
	var allies := []
	for i in spec.allies.size():
		allies.append(ally_unit(spec.allies[i], i))
	var mods := []
	for m in spec.get("modifiers", []):
		if not mods.has(m):
			mods.append(m)
	var pl := 1.0
	if spec.allies.size():
		var s := 0.0
		for a in spec.allies:
			s += float(a.level)
		pl = s / spec.allies.size()
	var sd: int = int(spec.get("seed", 1))
	var sim := {"spec": spec, "tick": 0, "rs": (sd if sd else 1) & U.M32, "wave": 0, "allies": allies, "enemies": [],
		"stance": spec.get("stance", "balanced"), "priority": spec.get("priority", "auto"), "focus": null, "retreating": 0.0,
		"outcome": null, "reason": null, "commands": [], "cmdIndex": 0, "log": [], "logSeq": 0, "defeated": [],
		"defeatedDetails": [], "onDeathDepth": 0, "summonSerial": 0, "plunder": 0,
		"trap": null, "encored": false, "mods": mods, "partyLevel": pl}
	var b: Dictionary = spec.get("bonuses", {})
	for u in allies:
		u.meter = min(95.0, float(b.get("startMeter", 0)) + U.num(u.mods, "quickStart"))
		if b.get("frontShield", 0) and u.lane == "front":
			u.st.shield += U.jround(float(u.maxHp) * float(b.frontShield))
	var team_shield := 0.0
	for u in allies:
		team_shield = max(team_shield, U.num(u.mods, "teamShield"))
	if team_shield:
		for u in allies:
			u.st.shield += U.jround(float(u.maxHp) * team_shield)
	spawn_wave(sim, 0)
	return sim


static func spawn_wave(sim: Dictionary, w: int) -> void:
	sim.wave = w
	var list := []
	var wave: Array = sim.spec.waves[w]
	for i in wave.size():
		list.append(enemy_unit(wave[i], i, w, sim.partyLevel))
	sim.enemies = list
	sim.focus = null
	push_log(sim, {"type": "wave", "wave": w + 1})


static func push_log(sim: Dictionary, ev: Dictionary) -> void:
	sim.logSeq = int(sim.logSeq) + 1
	ev.tick = sim.tick
	ev.seq = sim.logSeq
	sim.log.append(ev)
	if sim.log.size() > 80:
		sim.log.pop_front()


# ------------------------------------------------------------------ helpers
static func living(list: Array) -> Array:
	return list.filter(func(u): return u.alive)


static func has_mod(sim: Dictionary, m: String) -> bool:
	return sim.mods.has(m)


static func hazard_active(_sim: Dictionary, u: Dictionary, h: String) -> bool:
	if u.side != "ally":
		return false
	if U.num(u.mods, "hazardResist") or u.resist.has(h):
		return false
	return true


static func hazards(sim: Dictionary) -> Array:
	return sim.mods.filter(func(m): return C.data.HAZARDS.has(m))


static func hazard_scale(sim: Dictionary) -> int:
	return 2 if has_mod(sim, "legend_double_hazard") else 1


static func aura_max(sim: Dictionary, side: String, key: String) -> float:
	var v := 0.0
	for u in living(sim.allies if side == "ally" else sim.enemies):
		v = max(v, U.num(u.mods, key) + (0.06 if key == "auraAtk" and u.props.has("aura") else 0.0))
	return v


static func lane_order(list: Array) -> Array:
	var out := []
	for l in LANES:
		for u in list:
			if u.alive and u.lane == l:
				out.append(l)
				break
	return out


static func reachable(attacker: Dictionary, foes: Array, skill: Variant, force_ranged := false) -> Array:
	var alive := living(foes)
	if alive.is_empty():
		return []
	var fx: Dictionary = skill.get("fx", {}) if skill != null else {}
	if force_ranged or attacker.range == "ranged" or fx.get("reachAll") or fx.get("snipe"):
		return alive
	var lanes := lane_order(foes)
	var allowed := lanes.slice(0, 2 if attacker.range == "reach" else 1)
	return alive.filter(func(u): return allowed.has(u.lane))


static func hp_ratio(u: Dictionary) -> float:
	return float(u.hp) / float(u.maxHp)


static func lowest(list: Array) -> Variant:
	var b = null
	for u in list:
		if b == null or hp_ratio(u) < hp_ratio(b):
			b = u
	return b


static func front_lane(list: Array) -> Array:
	var lo := lane_order(list)
	if lo.is_empty():
		return []
	var l: String = lo[0]
	return living(list).filter(func(u): return u.lane == l)


static func pick_enemy_target(sim: Dictionary, src: Dictionary, skill: Variant, force_ranged := false) -> Variant:
	var pool := reachable(src, sim.enemies, skill, force_ranged)
	if pool.is_empty():
		return null
	if sim.focus != null:
		for u in pool:
			if u.uid == sim.focus:
				return u
	for u in pool:
		if u.st.taunt > 0:
			return u
	var decoy = null
	for u in pool:
		if u.decoy:
			decoy = u
			break
	if decoy != null and rnd(sim) < 0.7:
		return decoy
	var non_decoy := pool.filter(func(u): return not u.decoy)
	var fx: Dictionary = skill.get("fx", {}) if skill != null else {}
	if fx.get("snipe"):
		for arch in ["healer", "caster"]:
			for u in non_decoy:
				if u.archetype == arch:
					return u
	for u in non_decoy:
		if u.st.mark > 0:
			return u
	return lowest(non_decoy if non_decoy.size() else pool)


static func pick_ally_target(sim: Dictionary, src: Dictionary, skill: Variant) -> Variant:
	var pool := reachable(src, sim.allies, skill)
	if pool.is_empty():
		return null
	for u in pool:
		if u.st.taunt > 0:
			return u
	if src.boss or src.archetype == "shooter":
		return lowest(pool)
	return pool[int(floor(rnd(sim) * pool.size()))]


# -------------------------------------------------------------- damage/heal
static func deal_damage(sim: Dictionary, src: Dictionary, target: Dictionary, power: float, o: Dictionary = {}) -> int:
	var tgt := target
	if not tgt.alive:
		return 0
	if src.side == "enemy" and tgt.side == "ally" and tgt.lane != "front" and not o.get("noIntercept", false):
		var best = null
		var best_c := 0.0
		for g in living(sim.allies):
			if g.uid == tgt.uid or g.lane != "front":
				continue
			var c := U.num(g.mods, "intercept") + U.num(g.mods, "guard")
			if c > 0 and (best == null or c > best_c):
				best = g
				best_c = c
		if best != null and rnd(sim) < best_c:
			push_log(sim, {"type": "intercept", "src": best.uid, "tgt": tgt.uid})
			tgt = best
	var stance_a: Dictionary = STANCE[sim.stance]
	var dodge: float = tgt.dodge + (0.5 if tgt.st.evade > 0 else 0.0)
	if tgt.side == "ally":
		dodge += stance_a.dodge + aura_max(sim, "ally", "auraDodge")
	if not o.get("noDodge", false) and dodge > 0 and rnd(sim) < min(0.75, dodge):
		push_log(sim, {"type": "miss", "src": src.uid, "tgt": tgt.uid})
		return 0
	var atk_buff: float = 1.0 + tgt_buff(src) + (aura_max(sim, "ally", "auraAtk") if src.side == "ally" else 0.0)
	var atk: float = src.atk * atk_buff
	var ignore: float = min(0.8, U.num(src.mods, "defIgnore") + float(o.get("pierce", 0) if o.get("pierce") else 0) + (0.25 if src.props.has("pierce") else 0.0))
	var def: float = max(0.0, tgt.def * (1.0 + tgt.st.buffDef) * (1.0 - 0.08 * tgt.st.sunder) * (1.0 - ignore))
	var K: float = 40.0 + 6.0 * float(tgt.level)
	var dmg: float = atk * power * K / (K + def)
	var crit := false
	if rnd(sim) < src.crit:
		dmg *= 1.5
		crit = true
	if tgt.boss:
		dmg *= 1.0 + U.num(src.mods, "bossDmg") + float(o.get("boss", 0) if o.get("boss") else 0)
	if tgt.st.mark > 0:
		dmg *= 1.2 + U.num(src.mods, "markedDmg")
	if src.side == "ally":
		if sim.focus == tgt.uid:
			dmg *= 1.15 + U.num(src.mods, "focusDmg")
		dmg *= stance_a.dealt
		if has_mod(sim, "glare") and hazard_active(sim, src, "glare"):
			dmg *= float(C.data.HAZARDS.glare.dealtMult)
		if sim.retreating > 0:
			dmg *= 0.5
	else:
		dmg *= stance_a.taken
		if has_mod(sim, "pressure") and hazard_active(sim, tgt, "pressure"):
			dmg *= float(C.data.HAZARDS.pressure.takenMult)
		var bt: float = float(sim.spec.get("bonuses", {}).get("boardingTaken", 0))
		if bt:
			dmg *= 1.0 - bt
	if o.get("execute") and hp_ratio(tgt) < 0.3:
		dmg *= 1.0 + float(o.execute)
	var dmg_i: int = max(1, U.jround(dmg))
	var flat_pct := minf(0.6, U.num(tgt.mods, "flatReducePct"))
	if flat_pct > 0.0:
		dmg_i = max(1, U.jround(float(dmg_i) * (1.0 - flat_pct)))
	var flat := U.num(tgt.mods, "flatReduce")
	if flat > 0.0:
		dmg_i = max(1, dmg_i - U.jround(flat))
	var absorbed := 0
	if tgt.st.shield > 0:
		absorbed = min(int(tgt.st.shield), dmg_i)
		tgt.st.shield = int(tgt.st.shield) - absorbed
	var net := dmg_i - absorbed
	if net >= int(tgt.hp) and tgt.get("surviveOnce", false) and not tgt.get("survivedLethal", false):
		net = max(0, int(tgt.hp) - 1)
		tgt.survivedLethal = true
		push_log(sim, {"type": "endure", "tgt": tgt.uid})
	tgt.hp = int(tgt.hp) - net
	src.dealt = int(src.dealt) + dmg_i
	push_log(sim, {"type": "hit", "src": src.uid, "tgt": tgt.uid, "amount": dmg_i, "crit": crit, "skill": o.get("skill"), "absorbed": absorbed})
	if src.alive and src.get("onHit") != null and tgt.alive and not tgt.decoy:
		var oh: Dictionary = src.onHit
		if oh.get("dot"):
			tgt.st.dot = max(float(tgt.st.dot), float(oh.dot) * float(src.atk))
			tgt.st.dotT = max(float(tgt.st.dotT), float(oh.get("dur", 3)))
			push_log(sim, {"type": "venom", "src": src.uid, "tgt": tgt.uid})
	if U.num(tgt.mods, "thorns") and src.range != "ranged" and src.alive:
		var r: int = max(1, U.jround(dmg_i * U.num(tgt.mods, "thorns")))
		src.hp = int(src.hp) - r
		push_log(sim, {"type": "thorns", "src": tgt.uid, "tgt": src.uid, "amount": r})
		check_death(sim, src)
	if U.num(src.mods, "lifesteal"):
		heal(sim, src, src, dmg_i * U.num(src.mods, "lifesteal"), {"quiet": true})
	if src.side == "enemy" and sim.trap != null and src.alive:
		var tr: Dictionary = sim.trap
		sim.trap = null
		src.hp = int(src.hp) - int(tr.dmg)
		apply_stun(sim, src, float(tr.stun))
		push_log(sim, {"type": "trap", "tgt": src.uid, "amount": tr.dmg})
		check_death(sim, src)
	check_death(sim, tgt)
	if tgt.alive and tgt.side == "ally" and U.num(tgt.mods, "firstAid") and not tgt.firstAidUsed and hp_ratio(tgt) < 0.35:
		tgt.firstAidUsed = true
		heal(sim, tgt, tgt, float(tgt.maxHp) * U.num(tgt.mods, "firstAid"), {"force": true})
	return net


static func tgt_buff(u: Dictionary) -> float:
	return float(u.st.buffAtk)


static func heal(sim: Dictionary, src: Dictionary, tgt: Variant, amount: float, o: Dictionary = {}) -> int:
	if tgt == null or not tgt.alive:
		return 0
	if tgt.side == "ally" and has_mod(sim, "legend_no_healing") and not o.get("force", false):
		return 0
	var amt := U.jround(amount * (1.0 + U.num(src.mods, "healPct")))
	var real: int = min(int(tgt.maxHp) - int(tgt.hp), amt)
	if real <= 0:
		return 0
	tgt.hp = int(tgt.hp) + real
	src.healed = int(src.healed) + real
	if not o.get("quiet", false):
		push_log(sim, {"type": "heal", "src": src.uid, "tgt": tgt.uid, "amount": real})
	return real


static func apply_stun(sim: Dictionary, u: Dictionary, secs: float) -> void:
	if not u.alive or u.decoy:
		return
	if U.num(u.mods, "stunImmune"):
		push_log(sim, {"type": "resist", "tgt": u.uid})
		return
	var d := secs * 0.5 if u.boss else secs
	u.st.stun = max(float(u.st.stun), d)
	if u.windup != null:
		push_log(sim, {"type": "interrupt", "tgt": u.uid, "skill": u.windup.skill})
		u.windup = null
	push_log(sim, {"type": "stun", "tgt": u.uid, "secs": d})


static func check_death(sim: Dictionary, u: Dictionary) -> void:
	if not u.alive or int(u.hp) > 0:
		return
	u.hp = 0
	u.alive = false
	u.windup = null
	push_log(sim, {"type": "ko", "tgt": u.uid})
	if u.side == "enemy":
		if not u.get("summoned", false):
			sim.defeated.append(u.key)
			if not sim.has("defeatedDetails"):
				sim.defeatedDetails = []
			sim.defeatedDetails.append({"enemyId": u.key, "variant": u.get("variantId"), "rare": bool(u.get("rare", false)),
				"wave": int(sim.wave)})
		if not u.get("deathDone", false) and int(sim.get("onDeathDepth", 0)) < 1:
			u.deathDone = true
			sim.onDeathDepth = int(sim.get("onDeathDepth", 0)) + 1
			if u.get("volatile") != null:
				volatile_burst(sim, u)
			if u.get("splitter") != null:
				split_on_death(sim, u)
			sim.onDeathDepth = max(0, int(sim.get("onDeathDepth", 1)) - 1)
	if sim.focus == u.uid:
		sim.focus = null


static func volatile_burst(sim: Dictionary, u: Dictionary) -> void:
	var power := float(u.volatile.get("aoe", 0.3))
	if power <= 0.0:
		return
	push_log(sim, {"type": "burst", "src": u.uid})
	for a in living(sim.allies).duplicate():
		if a.alive:
			deal_damage(sim, u, a, power, {"noDodge": true, "skill": "volatile"})


static func split_on_death(sim: Dictionary, u: Dictionary) -> void:
	var count := int(u.splitter.get("spawn", 2))
	var ratio := float(u.splitter.get("hp", 0.3))
	for i in count:
		if living(sim.enemies).size() >= 8:
			break
		var copy = summon_unit(sim, u, String(u.key), ratio)
		if copy == null:
			break
		copy.hp = max(1, U.jround(float(copy.maxHp) * ratio))
		copy.tint_done = true


static func summon_unit(sim: Dictionary, owner: Dictionary, enemy_id: String, hp_ratio: float = 1.0) -> Variant:
	if living(sim.enemies).size() >= 8:
		return null
	if Bestiary.entry(enemy_id) == null:
		return null
	sim.summonSerial = int(sim.get("summonSerial", 0)) + 1
	var copy := enemy_unit({"enemyId": enemy_id, "level": owner.level}, 100 + int(sim.summonSerial), "s", sim.partyLevel)
	if copy.is_empty():
		return null
	copy.uid = "s%d_%d" % [int(sim.summonSerial), int(sim.tick)]
	copy.hp = max(1, U.jround(float(copy.maxHp) * hp_ratio))
	copy.summoned = true
	copy.summonOwner = owner.uid
	copy.summoner = null
	copy.summonTimer = 0.0
	copy.volatile = null
	copy.splitter = null
	copy.surviveOnce = false
	copy.survivedLethal = false
	copy.rare = false
	copy.boss = false
	copy.deathDone = false
	sim.enemies.append(copy)
	push_log(sim, {"type": "summon", "src": owner.uid, "tgt": copy.uid, "enemy": enemy_id})
	return copy


static func cleanse(u: Dictionary) -> void:
	u.st.stun = 0.0
	u.st.slow = 0.0
	u.st.dot = 0.0
	u.st.dotT = 0.0
	u.st.mark = 0.0
	u.st.sunder = 0


# ------------------------------------------------------------------- skills
static func heal_threshold(sim: Dictionary) -> float:
	var t: float = STANCE[sim.stance].heal
	if sim.priority == "damage":
		t = min(t, 0.5)
	if sim.priority == "support" or sim.priority == "survival":
		t = max(t, 0.8)
	return t


static func friends_of(sim: Dictionary, u: Dictionary) -> Array:
	return sim.allies if u.side == "ally" else sim.enemies


static func foes_of(sim: Dictionary, u: Dictionary) -> Array:
	return sim.enemies if u.side == "ally" else sim.allies


static func skill_usable(sim: Dictionary, u: Dictionary, sk: Dictionary) -> bool:
	var def = C.SKILLS.get(sk.id)
	if def == null or sk.cd > 0:
		return false
	var fx: Dictionary = def.get("fx", {})
	var friends := living(friends_of(sim, u))
	if def.get("heal"):
		if u.side == "ally" and has_mod(sim, "legend_no_healing"):
			return bool(fx.get("buffAtk") or fx.get("cleanse"))
		var thr: float = 0.35 if def.get("cond") == "critical" else (heal_threshold(sim) if u.side == "ally" else 0.6)
		for f in friends:
			if hp_ratio(f) < thr:
				return true
		return false
	if fx.get("pet") and u.pet == null:
		return false
	if def.cat == "survival" and (fx.get("shield") or fx.get("taunt") or fx.get("evade") or fx.get("buffDef")):
		var lim := 0.97 if u.side == "ally" and sim.stance == "defensive" else 0.85
		if def.scope == "self":
			return hp_ratio(u) < lim or u.lane == "front"
		for f in friends:
			if hp_ratio(f) < lim:
				return true
		return false
	if u.side == "ally" and sim.retreating > 0 and def.cat != "survival" and def.cat != "support":
		return false
	if def.scope == "enemy" or def.scope == "enemy_lane":
		return reachable(u, sim.enemies if u.side == "ally" else sim.allies, def).size() > 0
	return true


static func windup_pending(sim: Dictionary) -> bool:
	for e in living(sim.enemies):
		if e.windup != null:
			return true
	return false


static func choose_skill(sim: Dictionary, u: Dictionary) -> Variant:
	var ready: Array = u.skills.filter(func(sk): return skill_usable(sim, u, sk))
	if ready.is_empty():
		return null
	if u.side == "enemy":
		return ready[0]
	var order: Array
	if sim.priority == "auto":
		var danger := false
		for f in living(sim.allies):
			if hp_ratio(f) < 0.45:
				danger = true
		var windup := windup_pending(sim)
		if danger:
			order = ["survival", "support", "control", "damage"]
		elif windup:
			order = ["control", "damage", "support", "survival"]
		else:
			order = ["damage", "control", "support", "survival"]
		if sim.stance == "defensive":
			order = ["survival", "support", "control", "damage"]
	else:
		order = PRIORITY_ORDER[sim.priority]
	if sim.retreating > 0:
		order = ["survival", "support", "control", "damage"]
	var interrupting := windup_pending(sim)
	for cat in order:
		for sk in ready:
			var d: Dictionary = C.SKILLS[sk.id]
			if cat == "control" and interrupting and not d.get("fx", {}).get("stun"):
				continue
			if d.cat == cat:
				return sk
	return ready[0]


static func cast(sim: Dictionary, u: Dictionary, sk: Dictionary) -> void:
	var def: Dictionary = C.SKILLS[sk.id]
	var fx: Dictionary = def.get("fx", {})
	sk.cd = float(def.get("cd", 0)) * (1.0 - U.num(u.mods, "cdr"))
	if fx.get("windup") and u.windup == null:
		var tgt = pick_ally_target(sim, u, def) if u.side == "enemy" else pick_enemy_target(sim, u, def)
		if tgt == null:
			return
		u.windup = {"skill": sk.id, "left": float(fx.windup), "target": tgt.uid}
		push_log(sim, {"type": "windup", "src": u.uid, "skill": sk.id, "tgt": tgt.uid})
		return
	push_log(sim, {"type": "skill", "src": u.uid, "skill": sk.id})
	resolve_skill(sim, u, def, sk.id, null)


static func unit_by_uid(sim: Dictionary, uid: Variant) -> Variant:
	for x in sim.allies:
		if x.uid == uid:
			return x
	for x in sim.enemies:
		if x.uid == uid:
			return x
	return null


static func resolve_skill(sim: Dictionary, u: Dictionary, def: Dictionary, skill_id: String, fixed_target: Variant) -> void:
	var fx: Dictionary = def.get("fx", {})
	var foes := foes_of(sim, u)
	var friends := friends_of(sim, u)
	var targets := []
	var scope: String = def.scope
	if scope == "enemy":
		var t = fixed_target if fixed_target != null and fixed_target.alive else (pick_enemy_target(sim, u, def) if u.side == "ally" else pick_ally_target(sim, u, def))
		if t != null:
			targets = [t]
	elif scope == "enemy_lane":
		var t = pick_enemy_target(sim, u, def) if u.side == "ally" else pick_ally_target(sim, u, def)
		if t != null:
			var lane: String = t.lane
			targets = living(foes).filter(func(x): return x.lane == lane)
	elif scope == "enemies":
		targets = living(foes)
	elif scope == "ally":
		targets = [lowest(living(friends))]
	elif scope == "allies":
		targets = living(friends)
	elif scope == "front_allies":
		targets = front_lane(friends)
	elif scope == "self":
		targets = [u]
	targets = targets.filter(func(x): return x != null)
	var power: float = float(def.get("power", 0))
	if fx.get("pet") and u.pet != null:
		power *= float(fx.pet) * float(u.pet.mult)
	var no_heal: bool = u.side == "ally" and has_mod(sim, "legend_no_healing")
	for t in targets:
		var hostile: bool = t.side != u.side
		var dealt := 0
		if hostile and power > 0:
			var hits: int = max(1, int(fx.get("hits", 1)))
			for h in hits:
				if not t.alive:
					break
				dealt += deal_damage(sim, u, t, power, {"skill": skill_id, "pierce": fx.get("pierce"), "execute": fx.get("execute"), "boss": fx.get("boss")})
			if fx.get("healSelf") and dealt > 0:
				heal(sim, u, u, float(dealt) * float(fx.healSelf), {"quiet": true})
		if not t.alive and hostile:
			continue
		if def.get("heal") and not hostile:
			heal(sim, u, t, float(def.heal) * u.atk)
		var ctrl := 1.0 + U.num(u.mods, "controlPct")
		if hostile:
			if fx.get("stun"):
				apply_stun(sim, t, float(fx.stun) * ctrl)
			if fx.get("slow") and not t.decoy:
				t.st.slow = max(float(t.st.slow), float(fx.slow) * ctrl)
			if fx.get("mark"):
				t.st.mark = max(float(t.st.mark), float(fx.mark))
			if fx.get("sunder"):
				t.st.sunder = min(3, int(t.st.sunder) + 2)
				t.st.sunderT = float(fx.sunder)
			if fx.get("dot"):
				t.st.dot = max(float(t.st.dot), float(fx.dot) * u.atk)
				t.st.dotT = float(fx.get("dotDur", 4)) if fx.get("dotDur") else 4.0
			if fx.get("dispel"):
				t.st.shield = 0
				t.st.buffAtk = 0.0
				t.st.buffDef = 0.0
				t.st.regen = 0.0
		else:
			var hb := 1.0 + U.num(u.mods, "healPct")
			if fx.get("shield") and not no_heal:
				t.st.shield = int(t.st.shield) + U.jround(float(fx.shield) * float(t.maxHp) * hb)
			if fx.get("shield") and no_heal:
				t.st.shield = int(t.st.shield) + U.jround(float(fx.shield) * 0.5 * float(t.maxHp))
			if fx.get("taunt"):
				t.st.taunt = max(float(t.st.taunt), float(fx.taunt))
			if fx.get("evade"):
				t.st.evade = max(float(t.st.evade), float(fx.evade))
			if fx.get("buffAtk"):
				t.st.buffAtk = max(float(t.st.buffAtk), float(fx.buffAtk))
				t.st.buffAtkT = float(fx.buffDur) if fx.get("buffDur") else 5.0
			if fx.get("buffDef"):
				t.st.buffDef = max(float(t.st.buffDef), float(fx.buffDef))
				t.st.buffDefT = float(fx.buffDur) if fx.get("buffDur") else 5.0
			if fx.get("regen"):
				t.st.regen = float(fx.regen)
				t.st.regenT = float(fx.regenDur) if fx.get("regenDur") else 5.0
			if fx.get("meter"):
				t.meter = min(99.0, float(t.meter) + float(fx.meter))
			if fx.get("cleanse"):
				cleanse(t)
			if fx.get("trap"):
				sim.trap = {"dmg": U.jround(u.atk * float(fx.trap)), "stun": float(fx.trapStun) if fx.get("trapStun") else 1.0}
	if fx.get("cleanseAllies"):
		for f in living(friends):
			cleanse(f)
	if fx.get("plunder") and targets.size():
		sim.plunder = int(sim.plunder) + U.jround(2.0 + 1.5 * float(targets[0].level))
	if fx.get("pet") and u.pet != null:
		u.pet.timer = 0.0


## Basic action, shaped by the equipped weapon's properties.
static func basic_attack(sim: Dictionary, u: Dictionary) -> void:
	var friends := living(friends_of(sim, u))
	var no_heal := has_mod(sim, "legend_no_healing")
	if u.side == "ally" and u.props.has("mend") and not no_heal:
		var low = lowest(friends)
		if low != null and hp_ratio(low) < heal_threshold(sim):
			heal(sim, u, low, 0.9 * u.atk)
			return
	if u.side == "ally" and sim.retreating > 0:
		return
	var tgt = pick_enemy_target(sim, u, null) if u.side == "ally" else pick_ally_target(sim, u, null)
	if tgt == null:
		return
	if u.props.has("double"):
		deal_damage(sim, u, tgt, 0.6)
		if tgt.alive:
			deal_damage(sim, u, tgt, 0.6)
	else:
		deal_damage(sim, u, tgt, 1.0)
	if u.props.has("splash"):
		for o in living(foes_of(sim, u)):
			if o.uid != tgt.uid and o.lane == tgt.lane:
				deal_damage(sim, u, o, 0.35, {"noDodge": true})
	if u.props.has("sunder") and tgt.alive:
		tgt.st.sunder = min(3, int(tgt.st.sunder) + 1)
		tgt.st.sunderT = 6.0
	if u.props.has("chill") and tgt.alive and not tgt.decoy:
		tgt.st.slow = max(float(tgt.st.slow), 1.0)
	if u.props.has("burn") and tgt.alive and not (tgt.resist.has("heat") or U.num(tgt.mods, "hazardResist")):
		tgt.st.dot = max(float(tgt.st.dot), 0.15 * u.atk)
		tgt.st.dotT = 3.0
	if u.props.has("nourish") and not no_heal:
		var low = lowest(friends)
		if low != null:
			heal(sim, u, low, 0.35 * u.atk, {"quiet": true})


## A companion pet acts on its own timer.
static func pet_act(sim: Dictionary, u: Dictionary) -> void:
	var p: Dictionary = u.pet
	var ab: Dictionary = C.data.PET_ABILITIES[p.ability]
	var fx: Dictionary = ab.get("fx", {})
	var mult := float(p.mult)
	var base: float = u.atk * mult
	push_log(sim, {"type": "pet", "src": u.uid, "ability": p.ability})
	if ab.target == "owner":
		if ab.get("heal"):
			heal(sim, u, lowest(living(sim.allies)), float(ab.heal) * base)
		if ab.get("shield"):
			u.st.shield = int(u.st.shield) + U.jround(float(ab.shield) * float(u.maxHp) * min(2.0, mult))
		if fx.get("taunt"):
			u.st.taunt = max(float(u.st.taunt), float(fx.taunt))
		return
	if ab.target == "allies":
		for a in living(sim.allies):
			if ab.get("heal"):
				heal(sim, u, a, float(ab.heal) * base, {"quiet": true})
			if fx.get("meter"):
				a.meter = min(99.0, float(a.meter) + float(fx.meter) * min(2.0, mult))
		return
	var tgt = pick_enemy_target(sim, u, null, true)
	if tgt == null:
		return
	if ab.get("power"):
		deal_damage(sim, u, tgt, float(ab.power) * mult, {"noDodge": true, "skill": "pet_" + p.ability})
	if not tgt.alive:
		return
	if fx.get("slow"):
		tgt.st.slow = max(float(tgt.st.slow), float(fx.slow))
	if fx.get("stun"):
		apply_stun(sim, tgt, float(fx.stun))
	if fx.get("mark"):
		tgt.st.mark = max(float(tgt.st.mark), float(fx.mark))
	if fx.get("dot"):
		tgt.st.dot = max(float(tgt.st.dot), float(fx.dot) * base)
		tgt.st.dotT = float(fx.get("dotDur", 0))


# -------------------------------------------------------------------- ticks
static func apply_command(sim: Dictionary, cmd: Dictionary) -> void:
	var v = cmd.get("value")
	if cmd.type == "focus":
		sim.focus = null
		for e in sim.enemies:
			if e.uid == v and e.alive:
				sim.focus = e.uid
	elif cmd.type == "stance" and STANCE.has(v):
		sim.stance = v
	elif cmd.type == "priority" and (v == "auto" or PRIORITY_ORDER.has(v)):
		sim.priority = v
	elif cmd.type == "retreat" and not sim.retreating:
		var secs: float = float(sim.spec.get("retreatSecs", 3)) if sim.spec.get("retreatSecs") else 3.0
		for a in sim.allies:
			if a.alive and U.num(a.mods, "escape"):
				secs *= 0.5
				break
		if sim.stance == "escape":
			secs *= 0.67
		sim.retreating = max(dt(), secs)
	push_log(sim, {"type": "command", "cmd": cmd.type, "value": v})


## Records a command for the current tick (applied before the tick advances).
static func issue(sim: Dictionary, type: String, value: Variant) -> bool:
	if sim.outcome != null:
		return false
	sim.commands.append({"tick": sim.tick, "type": type, "value": value})
	return true


static func update_status(sim: Dictionary, u: Dictionary) -> void:
	var st: Dictionary = u.st
	var DT := dt()
	for k in STATUS_DECAY:
		if st[k] > 0:
			st[k] = max(0.0, float(st[k]) - DT)
	if st.buffAtkT > 0:
		st.buffAtkT -= DT
		if st.buffAtkT <= 0:
			st.buffAtk = 0.0
	if st.buffDefT > 0:
		st.buffDefT -= DT
		if st.buffDefT <= 0:
			st.buffDef = 0.0
	if st.sunderT > 0:
		st.sunderT -= DT
		if st.sunderT <= 0:
			st.sunder = 0
	var sec: bool = int(sim.tick) % 10 == 0
	if sec and st.regenT > 0:
		heal(sim, u, u, float(st.regen) * float(u.maxHp), {"quiet": true})
		st.regenT -= 1.0
		if st.regenT <= 0:
			st.regen = 0.0
	if sec and st.dotT > 0 and u.alive:
		u.hp = int(u.hp) - max(1, U.jround(float(st.dot)))
		st.dotT -= 1.0
		if st.dotT <= 0:
			st.dot = 0.0
		push_log(sim, {"type": "dot", "tgt": u.uid, "amount": U.jround(float(st.dot))})
		check_death(sim, u)
	if sec and U.num(u.mods, "regenPct") and u.alive:
		heal(sim, u, u, U.num(u.mods, "regenPct") * float(u.maxHp), {"quiet": true, "force": true})
	for sk in u.skills:
		if sk.cd > 0:
			sk.cd = max(0.0, float(sk.cd) - DT)


static func apply_hazards(sim: Dictionary) -> void:
	var sc := hazard_scale(sim)
	for h in hazards(sim):
		var H: Dictionary = C.data.HAZARDS[h]
		if not H.get("every"):
			continue
		var period := U.jround(float(H.every) / dt() / (1.5 if sc > 1 else 1.0))
		if int(sim.tick) == 0 or int(sim.tick) % period != 0:
			continue
		var victims := living(sim.allies).filter(func(u): return hazard_active(sim, u, h))
		if victims.is_empty():
			continue
		push_log(sim, {"type": "hazard", "hazard": h})
		for u in victims:
			if H.get("dmgPct"):
				u.hp = int(u.hp) - max(1, U.jround(float(u.maxHp) * float(H.dmgPct) * sc))
				check_death(sim, u)
			if H.get("slow"):
				u.st.slow = max(float(u.st.slow), float(H.slow))
		if H.get("stunRandom"):
			var v := living(victims)
			if v.size():
				apply_stun(sim, v[int(floor(rnd(sim) * v.size()))], float(H.stunRandom) * sc)


static func speed_mult(sim: Dictionary, u: Dictionary) -> float:
	var k := 0.6 if u.st.slow > 0 else 1.0
	if has_mod(sim, "tide") and hazard_active(sim, u, "tide"):
		k *= float(C.data.HAZARDS.tide.spdMult)
	return k


static func step(sim: Dictionary) -> Dictionary:
	if sim.outcome != null:
		return sim
	var DT := dt()
	while int(sim.cmdIndex) < sim.commands.size() and int(sim.commands[sim.cmdIndex].tick) <= int(sim.tick):
		var cmd: Dictionary = sim.commands[sim.cmdIndex]
		sim.cmdIndex = int(sim.cmdIndex) + 1
		apply_command(sim, cmd)
	sim.tick = int(sim.tick) + 1
	apply_hazards(sim)
	var aura_regen := 0.0
	for u in living(sim.allies):
		aura_regen = max(aura_regen, U.num(u.mods, "auraRegen"))
	var units := living(sim.allies) + living(sim.enemies)
	for u in units:
		if not u.alive:
			continue
		update_status(sim, u)
		if not u.alive:
			continue
		if aura_regen and u.side == "ally" and int(sim.tick) % 10 == 0:
			heal(sim, u, u, aura_regen * float(u.maxHp), {"quiet": true})
		if u.st.stun > 0 or u.decoy:
			continue
		if u.windup != null:
			u.windup.left = float(u.windup.left) - DT
			if u.windup.left <= 0:
				var w: Dictionary = u.windup
				u.windup = null
				push_log(sim, {"type": "skill", "src": u.uid, "skill": w.skill})
				resolve_skill(sim, u, C.SKILLS[w.skill], w.skill, unit_by_uid(sim, w.target))
			continue
		if u.side == "enemy":
			if u.get("berserk") != null and not u.get("enraged", false) and hp_ratio(u) <= float(u.berserk.get("hpBelow", 0.4)):
				u.enraged = true
				u.atk = float(u.atk) * (1.0 + float(u.berserk.get("atk", 0.35)))
				push_log(sim, {"type": "enrage", "src": u.uid})
			if u.get("summoner") != null and not u.get("summoned", false):
				u.summonTimer = float(u.get("summonTimer", 0.0)) + DT
				var summon_def: Dictionary = u.summoner
				if u.summonTimer >= float(summon_def.get("every", 9.0)):
					u.summonTimer = 0.0
					var cap := int(summon_def.get("cap", 3))
					var count := int(summon_def.get("count", 1))
					var owned := 0
					for other in sim.enemies:
						if other.alive and other.get("summonOwner") == u.uid:
							owned += 1
					var room: int = min(8 - living(sim.enemies).size(), cap - owned)
					for k in max(0, min(count, room)):
						summon_unit(sim, u, String(summon_def.get("enemyId", "swarmling")))
		if u.pet != null and u.alive and sim.retreating <= 0:
			var interval := (6.0 if u.pet.evolved else 7.0) - (1.0 if u.props.has("pet") else 0.0)
			u.pet.timer = float(u.pet.timer) + DT
			if u.pet.timer >= interval:
				u.pet.timer = 0.0
				pet_act(sim, u)
		u.meter = float(u.meter) + (40.0 + u.spd * 4.0) * DT * speed_mult(sim, u)
		if u.meter >= 100.0:
			u.meter -= 100.0
			var sk = choose_skill(sim, u)
			if sk != null:
				cast(sim, u, sk)
			else:
				basic_attack(sim, u)
		if end_check(sim):
			return sim
	if sim.retreating > 0:
		sim.retreating = float(sim.retreating) - DT
		if sim.retreating <= 1e-9:
			finish(sim, "retreat")
			return sim
	end_check(sim)
	if sim.outcome == null and int(sim.tick) >= limit_ticks():
		finish(sim, "defeat", "timeout")
	return sim


static func end_check(sim: Dictionary) -> bool:
	if sim.outcome != null:
		return true
	if living(sim.allies).is_empty():
		finish(sim, "defeat")
		return true
	if living(sim.enemies).filter(func(e): return not e.decoy).is_empty():
		if int(sim.wave) + 1 < sim.spec.waves.size():
			for a in living(sim.allies):
				heal(sim, a, a, float(a.maxHp) * 0.1, {"quiet": true, "force": true})
			spawn_wave(sim, int(sim.wave) + 1)
			return false
		if has_mod(sim, "legend_encore") and not sim.encored:
			sim.encored = true
			var last: Array = sim.spec.waves[sim.spec.waves.size() - 1]
			var cap := last.filter(func(e): return World.enemy(e.enemyId).get("rival", false))
			var src: Array = cap if cap.size() else last.slice(0, 1)
			var list := []
			for i in src.size():
				var e: Dictionary = src[i].duplicate()
				e.atkMult = 1.2
				list.append(enemy_unit(e, i, "x", sim.partyLevel))
			sim.enemies = list
			push_log(sim, {"type": "encore"})
			return false
		finish(sim, "victory")
		return true
	return false


static func finish(sim: Dictionary, outcome: String, reason: Variant = null) -> void:
	sim.outcome = outcome
	sim.reason = reason
	push_log(sim, {"type": "end", "outcome": outcome})


static func result(sim: Dictionary) -> Dictionary:
	var ko := []
	var hp := {}
	var dealt := {}
	var healed := {}
	for a in sim.allies:
		if not a.alive:
			ko.append(a.key)
		hp[a.key] = U.round2(float(a.hp) / float(a.maxHp))
		dealt[a.key] = a.dealt
		healed[a.key] = a.healed
	return {"outcome": sim.outcome, "reason": sim.reason, "ticks": sim.tick, "time": U.round1(float(sim.tick) * dt()),
		"wave": int(sim.wave) + 1, "waves": sim.spec.waves.size(), "koAllies": ko, "allyHp": hp,
		"enemiesDefeated": sim.defeated.duplicate(), "enemyDetails": sim.get("defeatedDetails", []).duplicate(true),
		"plunder": sim.plunder, "dealt": dealt, "healed": healed}


## Replays a full battle from a spec and a command list (stable by tick).
static func run(spec: Dictionary, commands: Array, until_tick: int = -1) -> Dictionary:
	var sim := create(spec)
	var indexed := []
	for i in commands.size():
		indexed.append([int(commands[i].tick), i, commands[i]])
	indexed.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for e in indexed:
		sim.commands.append(e[2])
	while sim.outcome == null and (until_tick < 0 or int(sim.tick) < until_tick):
		step(sim)
	return sim


static func resolve(spec: Dictionary, commands: Array) -> Dictionary:
	return result(run(spec, commands))
