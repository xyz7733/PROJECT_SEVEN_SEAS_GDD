## Persistent state model: locale-independent IDs, seeds and keys only.
## Mutations run on a deep copy and only replace the live state on success.
class_name GS
extends RefCounted

const SCHEMA_VERSION := 4
## Oldest save schema that migrate() can still upgrade.
const MIN_SCHEMA_VERSION := 3
const SAVE_FORMAT := "p7s-native-save"


static func T() -> Dictionary:
	return C.TUNING


static func next_u32(state: Dictionary) -> int:
	var rng: Dictionary = state.envelope.rng
	rng.s = (int(rng.s) + 0x6d2b79f5) & U.M32
	return U.mix(rng.s)


static func next_float(state: Dictionary) -> float:
	return float(next_u32(state)) / 4294967296.0


static func next_int(state: Dictionary, lo: int, hi: int) -> int:
	return lo + int(floor(next_float(state) * float(hi - lo + 1)))


static func pick(state: Dictionary, list: Array) -> Variant:
	return list[int(floor(next_float(state) * list.size()))]


static func next_id(state: Dictionary, prefix: String) -> String:
	var c: Dictionary = state.counters
	c[prefix] = int(c.get(prefix, 0)) + 1
	return prefix + "-" + U.pad4(c[prefix])


static func add_log(state: Dictionary, key: String, params: Dictionary = {}) -> void:
	state.log.push_front({"key": key, "params": params, "clock": state.envelope.gameClock})
	while state.log.size() > int(T().logLimit):
		state.log.pop_back()


## Deterministic recruit from an identity seed. Display names are derived
## from the seed by the active locale's name pool.
static func make_recruit(seed_value: int, o: Dictionary = {}) -> Dictionary:
	var r := U.Rng.new(seed_value)
	var class_pool: Array = o.get("classPool", C.data.BASE_CLASS_IDS)
	var class_id: String = o.classId if o.has("classId") else r.pick(class_pool)
	var origin_pool: Array = o.get("originPool", C.data.ORIGINS)
	var origin_id: String = o.originId if o.has("originId") else r.pick(origin_pool)
	var traits := []
	while traits.size() < 2:
		var t = r.pick(C.data.TRAITS)
		if not traits.has(t):
			traits.append(t)
	var apt_keys: Array = C.data.APTITUDES.keys()
	var aptitudes := []
	while aptitudes.size() < 2:
		var a = r.pick(apt_keys)
		if not aptitudes.has(a):
			aptitudes.append(a)
	var level: int = o.get("level", 1)
	var mastery := {}
	mastery[class_id] = T().qualifyMastery if o.get("qualified", false) else 0
	var apt_class = r.pick(C.data.BASE_CLASS_IDS)
	var pet_aff = r.pick(C.data.COLOR_TAGS)
	var event_id = r.pick(C.data.CREW_EVENTS)
	var variance := {"hp": r.range_int(-6, 6), "atk": r.range_int(-2, 2), "def": r.range_int(-2, 2), "spd": r.range_int(-1, 1)}
	return {
		"id": null, "seed": seed_value & U.M32, "nickname": null, "originId": origin_id, "traits": traits, "aptitudes": aptitudes,
		"aptClass": apt_class, "petAffinity": pet_aff, "eventId": event_id, "event": {"status": "active", "progress": 0},
		"variance": variance, "level": level, "xp": 0, "classId": class_id, "mastery": mastery, "legacy": [],
		"equipment": {"weapon": null, "outfit": null, "accessory": null}, "jobFacilityUid": null, "injured": false,
	}


## One ship level: deck-local coordinates, shared beam, elevation (0 is the
## exposed weather deck, raised open decks are above, interior levels are
## below). "kind" is "open" (combat and circulation) or "interior".
static func make_deck(hd: Dictionary) -> Dictionary:
	var bulkhead = hd.get("bulkhead")
	var doors := []
	if bulkhead != null:
		doors.append([int(bulkhead), int(hd.h) / 2])
	return {"id": hd.id, "kind": hd.get("kind", "open"), "w": hd.w, "h": hd.h, "x0": hd.x0, "elev": hd.elev, "fixed": hd.fixed.duplicate(true),
		"bulkhead": bulkhead, "doors": doors, "entry": hd.entry.duplicate() if hd.get("entry") != null else null}


static func create_new_game(seed_input: int = -1) -> Dictionary:
	var seed_value := seed_input
	if seed_value < 0:
		seed_value = randi() & U.M32
	var hull: Dictionary = C.HULLS[0]
	var locations := {}
	for loc in C.LOCATIONS.values():
		locations[loc.id] = {"k": loc.initial, "firstVisit": loc.initial == "visited", "rooms": []}
	var ports := {}
	for p in C.PORTS.values():
		ports[p.id] = {"tracks": p.base.duplicate()}
	var decks := []
	for hd in hull.decks:
		decks.append(make_deck(hd))
	var Tn := T()
	var state := {
		"envelope": {"schemaVersion": SCHEMA_VERSION, "contentVersion": C.data.CONTENT_VERSION,
			"profileId": "captain-" + U.hash_hex("profile:" + str(seed_value)), "seed": seed_value, "lastTxId": 0,
			"lastTxKind": "new_game", "gameClock": 8, "rng": {"s": seed_value}, "recoveryGeneration": 0, "stateHash": ""},
		"counters": {},
		"captain": {"titleKey": "title.unknown_captain", "regionId": "dawnwater", "regionsUnlocked": ["dawnwater"],
			"mainStep": {"dawnwater": 0}, "trialsWon": [], "legendsWon": [],
			"reputation": {"conclave": 0, "league": 0, "tidebound": 0, "pennants": 0}, "postgame": false,
			"stats": {"battlesWon": 0, "battlesLost": 0, "retreats": 0, "rations": 0, "voyages": 0, "hatches": 0}, "flags": {}},
		"world": {"currentLocationId": "brightquay", "lastSafePortId": "brightquay", "locations": locations, "chartedRoutes": [],
			"clues": [], "ports": ports, "shortcuts": {}, "quests": {}, "contracts": {}, "taverns": {}},
		"ship": {"hullId": hull.id, "hullTier": hull.tier, "decks": decks, "stairs": [], "facilities": [],
			"stamina": Tn.startStamina, "staminaMax": Tn.maxStamina, "damage": 0, "presets": [null, null, null]},
		"crew": [], "formation": [null, null, null, null, null, null], "tactics": {"stance": "balanced", "priority": "auto"},
		"pets": [],
		"inventory": {"gold": Tn.startGold, "food": Tn.startFood, "supplies": Tn.startSupplies, "materials": Tn.startMaterials,
			"specialties": {}, "ingredients": {}, "equipment": [], "eggs": [], "recipes": [], "uniques": [], "blueprints": [],
			"ledger": {"gold": 0, "materials": 0}},
		"codex": {"locations": {}, "enemies": {}, "classes": {}, "pets": {}, "recipes": [], "clues": [], "items": {}, "hatchLog": []},
		"voyage": null, "encounter": null, "committed": {}, "committedOrder": [], "log": [],
	}
	Actions.auto_stairs(state)
	# Starting rooms sit inside the hull; the weather deck stays clear.
	var layout := [["captains_cabin", "lower", 0, 0], ["crew_quarters", "lower", 0, 4], ["muster_deck", "lower", 10, 0], ["pantry", "hold", 0, 0]]
	for p in layout:
		var f := {"uid": next_id(state, "fac"), "id": p[0], "deck": Rules.deck_index(state.ship, p[1]), "x": p[2], "y": p[3], "rot": 0,
			"level": 1, "damaged": false, "stowed": false}
		if f.deck < 0 or not Rules.can_place(state.ship, f.id, f.deck, f.x, f.y, 0, null).ok:
			var spot = Rules.find_spot(state.ship, f.id)
			if spot != null:
				f.deck = spot.deck; f.x = spot.x; f.y = spot.y; f.rot = spot.rot
		state.ship.facilities.append(f)
	var starters := [["guard", 0, "w_shield_1"], ["duelist", 1, "w_blade_1"], ["gunner", 4, "w_gun_1"], ["medic", 5, "w_kit_1"]]
	for i in starters.size():
		var s: Array = starters[i]
		var m := make_recruit(U.seed_of(state.envelope.profileId + ":starter:" + str(i)), {"classId": s[0], "originId": "dawnwater_fishers"})
		m.id = next_id(state, "crew")
		if i == 0:
			m.eventId = "proving"
		var uid := next_id(state, "eq")
		state.inventory.equipment.append({"uid": uid, "itemId": s[2], "reinforce": 0, "affix": null})
		m.equipment.weapon = uid
		state.crew.append(m)
		state.formation[s[1]] = m.id
		state.codex.classes[s[0]] = true
		state.codex.items[s[2]] = true
		if not state.inventory.recipes.has(s[2]):
			state.inventory.recipes.append(s[2])
	state.inventory.eggs.append({"id": next_id(state, "egg"), "familyId": "tidefin", "grade": 1, "inputs": []})
	state.inventory.ingredients = {"fire_pepper": 1, "sea_pearl": 2, "salt_crystal": 1}
	state.codex.locations["brightquay"] = true
	add_log(state, "log.new_game", {})
	add_log(state, "log.arrived", {"location": "loc.brightquay.name"})
	return state


## Upgrades a loaded state from an older schema in place. Schema 3 ships
## had management rooms on the exposed deck; schema 4 rebuilds the hull's
## stacked levels and moves every ordinary facility into interior space,
## keeping uids, levels, damage and crew assignments. Returns false if the
## state cannot be migrated.
static func migrate(state: Dictionary) -> bool:
	var v := int(state.envelope.get("schemaVersion", 0))
	if v < MIN_SCHEMA_VERSION or v > SCHEMA_VERSION:
		return false
	if v == 3:
		var hull = C.hull(String(state.ship.get("hullId", "starter")))
		if hull == null or hull.is_empty():
			return false
		var on_deck := 0
		for f in state.ship.facilities:
			if not f.stowed and Rules.zone_of(f.id) != "deck":
				on_deck += 1
		Actions.rebuild_decks(state, hull)
		# Old layout presets point at the old single-level decks.
		state.ship.presets = [null, null, null]
		add_log(state, "log.ship_refit", {"n": on_deck})
		state.envelope.schemaVersion = 4
	return true


## Applies `mutator` to a deep copy. Returns {ok, state, value, reasonKey, ...}.
static func commit(state: Dictionary, kind: String, mutator: Callable) -> Dictionary:
	var draft: Dictionary = state.duplicate(true)
	var result = mutator.call(draft)
	if result is Dictionary and result.get("ok", true) == false:
		return {"ok": false, "state": state, "reasonKey": result.get("reasonKey", "err.unknown"), "reasonParams": result.get("reasonParams", {})}
	draft.envelope.lastTxId = int(draft.envelope.lastTxId) + 1
	draft.envelope.lastTxKind = kind
	var value = result.get("value") if result is Dictionary else null
	var reason = result.get("saveReason") if result is Dictionary else null
	return {"ok": true, "state": draft, "value": value, "saveReason": reason}


static func record_attempt(state: Dictionary, attempt_id: String, value: Variant) -> void:
	state.committed[attempt_id] = value
	state.committedOrder.append(attempt_id)
	while state.committedOrder.size() > int(T().committedLimit):
		state.committed.erase(state.committedOrder.pop_front())
