class_name Attrs
extends RefCounted
## Personal attributes of a sailor: Might, Vigor, Agility, Focus, Will and
## Seamanship. Each sailor's base values are rolled once from their identity
## seed and origin (a separate stream, so the rest of the recruit roll never
## changes). Personality traits nudge them, and training points earned every
## few levels raise them. 10 is neutral: a sailor with 10 everywhere has the
## same numbers as before attributes existed. Values above or below 10 add
## small modifiers to combat stats and ship work through member_stats().
## There is no rarity ladder. Every spread has strong and weak sides.

const IDS := ["might", "vigor", "agility", "focus", "will", "seamanship"]
const NEUTRAL := 10
const MIN_VALUE := 1
const MAX_VALUE := 30

## Rolling: every attribute starts at ROLL_FLOOR and POOL points are dealt
## one at a time by weighted draw. Origin leanings, one random talent and
## one random weakness bend the weights; TAPER makes high values rarer and
## ROLL_CAP stops a single attribute running away. POOL is two below the
## neutral total because every trait pair adds a net +2.
const ROLL_FLOOR := 6
const POOL := 22
const ROLL_CAP := 16
const LEAN_WEIGHT := 2.2
const TALENT_WEIGHT := 2.0
const WEAK_WEIGHT := 0.35
const TAPER := 0.3

## One training point per this many levels (15 points at the level cap).
const LEVELS_PER_POINT := 4

## Modifier per point away from 10. Keys are member_stats() mod names.
const EFFECTS := {
	"might": {"atkPct": 0.012},
	"vigor": {"hpPct": 0.015, "defPct": 0.008},
	"agility": {"spd": 0.1, "dodge": 0.004},
	"focus": {"crit": 0.005, "controlPct": 0.015},
	"will": {"healPct": 0.015, "cdr": 0.006},
	"seamanship": {"jobPct": 0.03},
}
## Effects that only apply above 10 (nobody gets a negative dodge).
const ABOVE_ONLY := {"dodge": true}

## Origin -> the two attributes its people lean toward.
const ORIGIN_LEAN := {
	"dawnwater_fishers": ["seamanship", "vigor"],
	"ember_forges": ["might", "vigor"],
	"verdant_villages": ["vigor", "will"],
	"glass_reefs": ["agility", "focus"],
	"crown_courts": ["focus", "will"],
	"storm_harbors": ["seamanship", "might"],
	"moon_isles": ["will", "focus"],
	"trench_divers": ["vigor", "focus"],
	"ring_nomads": ["agility", "seamanship"],
	"horizon_wanderers": ["agility", "might"],
}

## Trait -> attribute shifts. Every trait nets +1.
const TRAIT_SHIFT := {
	"brave": {"might": 1, "will": 1, "focus": -1},
	"cautious": {"agility": 1, "focus": 1, "might": -1},
	"cheerful": {"will": 1, "seamanship": 1, "focus": -1},
	"stubborn": {"vigor": 2, "agility": -1},
	"curious": {"focus": 1, "seamanship": 1, "will": -1},
	"loyal": {"will": 1, "vigor": 1, "agility": -1},
	"thrifty": {"seamanship": 2, "might": -1},
	"calm": {"focus": 1, "will": 1, "agility": -1},
	"reckless": {"might": 2, "focus": -1},
	"kind": {"will": 2, "might": -1},
	"proud": {"might": 1, "focus": 1, "seamanship": -1},
	"sleepy": {"vigor": 1, "will": 1, "agility": -1},
}

## Base class -> the attributes it relies on most. Branches use their root.
const CLASS_KEYS := {
	"guard": ["vigor", "will"],
	"duelist": ["might", "agility"],
	"spearfighter": ["might", "focus"],
	"gunner": ["focus", "agility"],
	"brawler": ["might", "vigor"],
	"medic": ["will", "focus"],
	"cook": ["will", "vigor"],
	"navigator": ["focus", "agility"],
	"tinkerer": ["focus", "will"],
	"beastkeeper": ["will", "might"],
	"mystic": ["focus", "will"],
	"quartermaster": ["vigor", "will"],
}

## Value bands for labels and colours: [lowest value, band id].
const BANDS := [[20, "heroic"], [15, "great"], [12, "good"], [8, "fair"], [MIN_VALUE, "poor"]]

const ICONS := {
	"might": "at_might", "vigor": "at_vigor", "agility": "at_agility",
	"focus": "at_focus", "will": "at_will", "seamanship": "at_seamanship",
}


## Base attributes for an identity seed and origin. Deterministic.
static func roll(seed_value: int, origin_id: String) -> Dictionary:
	var r := U.Rng.new(U.seed_of(str(seed_value & U.M32) + ":attrs"))
	var lean: Array = ORIGIN_LEAN.get(origin_id, [])
	var talent: String = r.pick(IDS)
	var weak_pool := []
	for a in IDS:
		if a != talent and not lean.has(a):
			weak_pool.append(a)
	var weak: String = r.pick(weak_pool)
	var v := {}
	var w := {}
	for a in IDS:
		v[a] = ROLL_FLOOR
		w[a] = (LEAN_WEIGHT if lean.has(a) else 1.0) * (TALENT_WEIGHT if a == talent else 1.0) * (WEAK_WEIGHT if a == weak else 1.0)
	for _i in POOL:
		var live := []
		var total := 0.0
		for a in IDS:
			if int(v[a]) < ROLL_CAP:
				var wa: float = float(w[a]) / (1.0 + TAPER * float(maxi(0, int(v[a]) - NEUTRAL)))
				live.append([a, wa])
				total += wa
		if live.is_empty():
			break
		var x := r.next() * total
		var chosen: String = live[live.size() - 1][0]
		for e in live:
			x -= float(e[1])
			if x < 0.0:
				chosen = e[0]
				break
		v[chosen] = int(v[chosen]) + 1
	return v


## Stored base attributes, or the roll for older records that predate them
## (stored battle offers and pre-schema-6 states before migration).
static func base_of(m: Dictionary) -> Dictionary:
	var a = m.get("attrs")
	if a is Dictionary and a.size() == IDS.size():
		return a
	return roll(int(m.get("seed", 0)), String(m.get("originId", "")))


static func trait_shift(m: Dictionary) -> Dictionary:
	var out := {}
	for a in IDS:
		out[a] = 0
	for t in m.get("traits", []):
		var sh: Dictionary = TRAIT_SHIFT.get(String(t), {})
		for a in sh:
			out[a] = int(out[a]) + int(sh[a])
	return out


static func trained(m: Dictionary, id: String) -> int:
	var t = m.get("train")
	return int(t.get(id, 0)) if t is Dictionary else 0


## {base, traits, train, total} for one attribute.
static func breakdown(m: Dictionary, id: String) -> Dictionary:
	var b := int(base_of(m).get(id, NEUTRAL))
	var s := int(trait_shift(m).get(id, 0))
	var t := trained(m, id)
	return {"base": b, "traits": s, "train": t, "total": clampi(b + s + t, MIN_VALUE, MAX_VALUE)}


static func value(m: Dictionary, id: String) -> int:
	return int(breakdown(m, id).total)


static func totals(m: Dictionary) -> Dictionary:
	var base := base_of(m)
	var sh := trait_shift(m)
	var out := {}
	for a in IDS:
		out[a] = clampi(int(base.get(a, NEUTRAL)) + int(sh[a]) + trained(m, a), MIN_VALUE, MAX_VALUE)
	return out


## Modifiers from one attribute value.
static func effect_of(id: String, v: int) -> Dictionary:
	var out := {}
	var d := v - NEUTRAL
	var fx: Dictionary = EFFECTS.get(id, {})
	for k in fx:
		if d < 0 and ABOVE_ONLY.has(k):
			continue
		if d != 0:
			out[k] = float(fx[k]) * float(d)
	return out


## Modifiers from all of a sailor's attributes, merged.
static func mods_of(m: Dictionary) -> Dictionary:
	var out := {}
	var tot := totals(m)
	for a in IDS:
		U.add_mods(out, effect_of(a, int(tot[a])))
	return out


static func points_earned(level: int) -> int:
	return maxi(0, level) / LEVELS_PER_POINT


static func points_spent(m: Dictionary) -> int:
	var n := 0
	for a in IDS:
		n += trained(m, a)
	return n


static func points_free(m: Dictionary) -> int:
	return maxi(0, points_earned(int(m.get("level", 1))) - points_spent(m))


## "" if one point can go into `id`, else the reason key.
static func train_block(m: Dictionary, id: String) -> String:
	if not IDS.has(id):
		return "err.bad_attr"
	var b := breakdown(m, id)
	if int(b.base) + int(b.traits) + int(b.train) >= MAX_VALUE:
		return "err.attr_max"
	if points_free(m) <= 0:
		return "err.no_train_points"
	return ""


static func retrain_cost(m: Dictionary) -> Dictionary:
	return {"gold": 30 + 6 * int(m.get("level", 1))}


static func root_class(class_id: String) -> String:
	var id := class_id
	for _i in 8:
		var cls = C.CLASSES.get(id)
		if cls == null or cls.get("parent") == null:
			break
		id = String(cls.parent)
	return id


static func class_keys(class_id: String) -> Array:
	return CLASS_KEYS.get(root_class(class_id), [])


## Mean of the class's key attributes for this sailor (10 = neutral fit).
static func class_fit(m: Dictionary, class_id: String) -> float:
	var keys := class_keys(class_id)
	if keys.is_empty():
		return float(NEUTRAL)
	var tot := totals(m)
	var s := 0.0
	for a in keys:
		s += float(tot[a])
	return s / float(keys.size())


static func band(v: int) -> String:
	for b in BANDS:
		if v >= int(b[0]):
			return String(b[1])
	return "poor"


## The sailor's two highest attributes (ties keep IDS order).
static func strongest(m: Dictionary, n: int = 2) -> Array:
	var tot := totals(m)
	var ids := IDS.duplicate()
	ids.sort_custom(func(a, b): return int(tot[a]) > int(tot[b]) or (int(tot[a]) == int(tot[b]) and IDS.find(a) < IDS.find(b)))
	return ids.slice(0, n)
