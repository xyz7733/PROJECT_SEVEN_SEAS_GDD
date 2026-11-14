## Derived read-only rules: stacked multi-level ship layout, facility effects, crew
## stats, voyages, ports, taverns, contracts and pets.
class_name Rules
extends RefCounted

const TAVERN_SIZE := [1, 3, 4, 5]
const LANES := ["front", "center", "rear"]


static func T() -> Dictionary:
	return C.TUNING


# ------------------------------------------------------------------ layout
static func footprint(f: Dictionary) -> Vector2i:
	var def: Dictionary = C.FACILITIES[f.id]
	return Vector2i(def.h, def.w) if int(f.get("rot", 0)) else Vector2i(def.w, def.h)


static func fac_cells(f: Dictionary) -> Array:
	var fp := footprint(f)
	var out := []
	for dx in fp.x:
		for dy in fp.y:
			out.append(Vector2i(int(f.x) + dx, int(f.y) + dy))
	return out


static func is_door(deck: Dictionary, x: int, y: int) -> bool:
	for d in deck.doors:
		if int(d[0]) == x and int(d[1]) == y:
			return true
	return false


## "" for an open cell, otherwise the kind of fixed obstacle.
static func fixed_kind(deck: Dictionary, x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= int(deck.w) or y >= int(deck.h):
		return "out"
	for f in deck.fixed:
		if int(f[0]) == x and int(f[1]) == y:
			return f[2]
	if deck.bulkhead != null and int(deck.bulkhead) == x and not is_door(deck, x, y):
		return "bulkhead"
	return ""


## "open" for exposed decks (combat and circulation), "interior" for the
## covered levels inside the hull.
static func deck_kind(deck: Dictionary) -> String:
	return String(deck.get("kind", "open"))


static func is_open_deck(deck: Dictionary) -> bool:
	return deck_kind(deck) == "open"


## Facility placement zone: "deck" fittings only on open decks, everything
## else ("interior") only inside the hull.
static func zone_of(fac_id: String) -> String:
	return String(C.FACILITIES[fac_id].get("zone", "interior"))


static func zone_ok(deck: Dictionary, fac_id: String) -> bool:
	return is_open_deck(deck) == (zone_of(fac_id) == "deck")


## Deck indices where this facility may be built, top to bottom.
static func eligible_decks(ship: Dictionary, fac_id: String) -> Array:
	var out := []
	for i in ship.decks.size():
		if zone_ok(ship.decks[i], fac_id):
			out.append(i)
	return out


static func deck_index(ship: Dictionary, deck_id: String) -> int:
	for i in ship.decks.size():
		if ship.decks[i].id == deck_id:
			return i
	return -1


## Interior levels ordered from the highest to the lowest. View level 0 is
## the open decks; view level k is interior_levels()[k - 1].
static func interior_levels(ship: Dictionary) -> Array:
	var out := []
	for i in ship.decks.size():
		if not is_open_deck(ship.decks[i]):
			out.append(i)
	out.sort_custom(func(a, b): return int(ship.decks[a].elev) > int(ship.decks[b].elev))
	return out


## View level of a deck: 0 for open decks, k for the k-th interior level.
static func view_level(ship: Dictionary, d: int) -> int:
	if d < 0 or d >= ship.decks.size() or is_open_deck(ship.decks[d]):
		return 0
	return interior_levels(ship).find(d) + 1


## Stair whose foot (lower deck) or landing (upper deck) is on this cell.
static func stair_at(ship: Dictionary, d: int, x: int, y: int) -> Variant:
	for s in ship.stairs:
		if int(s.y) != y:
			continue
		if int(s.deck) == d and int(s.x) == x:
			return s
		if int(s.to) == d and int(s.ux) == x:
			return s
	return null


## Where a stair whose foot is on lower-deck cell (d, x, y) would lead.
## A hatch ladder climbs straight up to the deck one level higher that
## covers the same hull column; between two open decks a terrace stair
## climbs from the cell just past the raised deck's edge. Returns
## {to, ux, kind: "ladder"|"stair"} or null.
static func stair_target(ship: Dictionary, d: int, x: int, y: int) -> Variant:
	if d < 0 or d >= ship.decks.size():
		return null
	var L: Dictionary = ship.decks[d]
	if x < 0 or y < 0 or x >= int(L.w) or y >= int(L.h):
		return null
	var gx := int(L.x0) + x
	for ui in ship.decks.size():
		var U: Dictionary = ship.decks[ui]
		if int(U.elev) != int(L.elev) + 1 or y >= int(U.h):
			continue
		if gx >= int(U.x0) and gx < int(U.x0) + int(U.w):
			return {"to": ui, "ux": gx - int(U.x0), "kind": "ladder"}
	if not is_open_deck(L):
		return null
	for ui in ship.decks.size():
		var U: Dictionary = ship.decks[ui]
		if int(U.elev) != int(L.elev) + 1 or not is_open_deck(U) or y >= int(U.h):
			continue
		if gx == int(U.x0) + int(U.w):
			return {"to": ui, "ux": int(U.w) - 1, "kind": "stair"}
		if gx == int(U.x0) - 1:
			return {"to": ui, "ux": 0, "kind": "stair"}
	return null


## Pairs of decks that a stair can join: [{deck, to, kind, xs}] where xs
## lists the lower-deck columns that lead to `to`.
static func stair_boundaries(ship: Dictionary) -> Array:
	var pairs := {}
	for li in ship.decks.size():
		var L: Dictionary = ship.decks[li]
		for x in int(L.w):
			var t = stair_target(ship, li, x, 0)
			if t == null:
				continue
			var key := "%d>%d" % [li, int(t.to)]
			if not pairs.has(key):
				pairs[key] = {"deck": li, "to": int(t.to), "kind": t.kind, "xs": []}
			pairs[key].xs.append(x)
	return pairs.values()


static func stair_slot(ship: Dictionary, deck: int, x: int, y: int = 0) -> Variant:
	return stair_target(ship, deck, x, y)


static func occupancy(ship: Dictionary) -> Dictionary:
	var occ := {}
	for f in ship.facilities:
		if f.stowed:
			continue
		for c in fac_cells(f):
			occ["%d:%d:%d" % [int(f.deck), c.x, c.y]] = f.uid
	return occ


static func is_entry(deck: Dictionary, x: int, y: int) -> bool:
	return deck.entry != null and int(deck.entry[0]) == x and int(deck.entry[1]) == y


static func can_place(ship: Dictionary, fac_id: String, deck_index: int, x: int, y: int, rot: int, ignore_uid: Variant) -> Dictionary:
	if deck_index < 0 or deck_index >= ship.decks.size():
		return {"ok": false, "reasonKey": "err.bad_cell"}
	var deck: Dictionary = ship.decks[deck_index]
	if C.FACILITIES.has(fac_id) and not zone_ok(deck, fac_id):
		return {"ok": false, "reasonKey": "err.zone_deck" if zone_of(fac_id) == "deck" else "err.zone_interior"}
	var occ := occupancy(ship)
	for c in fac_cells({"id": fac_id, "x": x, "y": y, "rot": rot}):
		var k := fixed_kind(deck, c.x, c.y)
		if k != "":
			return {"ok": false, "reasonKey": "err.out_of_bounds" if k == "out" else "err.cell_blocked"}
		if deck.bulkhead != null and int(deck.bulkhead) == c.x:
			return {"ok": false, "reasonKey": "err.cell_door"}
		var o = occ.get("%d:%d:%d" % [deck_index, c.x, c.y])
		if o != null and o != ignore_uid:
			return {"ok": false, "reasonKey": "err.cell_occupied"}
		if stair_at(ship, deck_index, c.x, c.y) != null:
			return {"ok": false, "reasonKey": "err.cell_stair"}
		if is_entry(deck, c.x, c.y):
			return {"ok": false, "reasonKey": "err.cell_entry"}
	return {"ok": true}


## First free placement for a facility on its eligible levels, keeping
## every reachable facility reachable. Rooms against the hull walls are
## tried before cells that would split the central passage. `prefer` lists
## deck indices to try first. Returns {deck, x, y, rot} or null.
static func find_spot(ship: Dictionary, fac_id: String, ignore_uid: Variant = null, prefer: Array = []) -> Variant:
	var order := []
	for i in prefer:
		if int(i) >= 0 and int(i) < ship.decks.size() and zone_ok(ship.decks[int(i)], fac_id):
			order.append(int(i))
	for i in eligible_decks(ship, fac_id):
		if not order.has(i):
			order.append(i)
	var base := ship.duplicate(true)
	if ignore_uid != null:
		base.facilities = base.facilities.filter(func(f): return f.uid != ignore_uid)
	var before := analyze_layout(base)
	for wall_only in [true, false]:
		for di in order:
			var dk: Dictionary = ship.decks[di]
			for rot in [0, 1]:
				var fp := footprint({"id": fac_id, "rot": rot})
				for x in int(dk.w):
					for y in int(dk.h):
						if wall_only and not (y == 0 or y + fp.y == int(dk.h)):
							continue
						if not can_place(base, fac_id, di, x, y, rot, null).ok:
							continue
						var trial := base.duplicate(true)
						trial.facilities.append({"uid": "__probe", "id": fac_id, "deck": di, "x": x, "y": y, "rot": rot,
							"level": 1, "damaged": false, "stowed": false})
						var lay := analyze_layout(trial)
						if not lay.facilities["__probe"].reachable:
							continue
						var broke := false
						for uid in before.facilities:
							if before.facilities[uid].reachable and not lay.facilities[uid].reachable:
								broke = true
								break
						if not broke:
							return {"deck": di, "x": x, "y": y, "rot": rot}
	return null


static func walkable(ship: Dictionary, occ: Dictionary, d: int, x: int, y: int) -> bool:
	if d < 0 or d >= ship.decks.size():
		return false
	if fixed_kind(ship.decks[d], x, y) != "":
		return false
	return not occ.has("%d:%d:%d" % [d, x, y])


## Neighbouring walkable nodes for pathing: 4-way moves plus stair links.
static func links(ship: Dictionary, d: int, x: int, y: int) -> Array:
	var out := [Vector3i(d, x + 1, y), Vector3i(d, x - 1, y), Vector3i(d, x, y + 1), Vector3i(d, x, y - 1)]
	for s in ship.stairs:
		if int(s.y) != y:
			continue
		if int(s.deck) == d and int(s.x) == x:
			out.append(Vector3i(int(s.to), int(s.ux), y))
		if int(s.to) == d and int(s.ux) == x:
			out.append(Vector3i(int(s.deck), int(s.x), y))
	return out


## Breadth-first search from the gangway through walkable cells and stairs.
static func analyze_layout(ship: Dictionary, crew_count: int = -1) -> Dictionary:
	var occ := occupancy(ship)
	var reached := {}
	var queue := []
	var deck0: Dictionary = ship.decks[0]
	if deck0.entry != null and walkable(ship, occ, 0, int(deck0.entry[0]), int(deck0.entry[1])):
		var start := Vector3i(0, int(deck0.entry[0]), int(deck0.entry[1]))
		queue.append(start)
		reached[start] = true
	var qi := 0
	while qi < queue.size():
		var n: Vector3i = queue[qi]
		qi += 1
		for nb in links(ship, n.x, n.y, n.z):
			if reached.has(nb) or not walkable(ship, occ, nb.x, nb.y, nb.z):
				continue
			reached[nb] = true
			queue.append(nb)
	var decks_reached := {}
	for n in reached:
		decks_reached[n.x] = true
	var facilities := {}
	for f in ship.facilities:
		if f.stowed:
			facilities[f.uid] = {"reachable": false, "stowed": true, "reasonKey": "warn.facility_stowed", "reasonParams": {}}
			continue
		var ok := false
		for c in fac_cells(f):
			for nb in [Vector3i(int(f.deck), c.x + 1, c.y), Vector3i(int(f.deck), c.x - 1, c.y), Vector3i(int(f.deck), c.x, c.y + 1), Vector3i(int(f.deck), c.x, c.y - 1)]:
				if reached.has(nb):
					ok = true
					break
			if ok:
				break
		if ok:
			facilities[f.uid] = {"reachable": true}
		else:
			var deck_name := "deck.%s.name" % ship.decks[int(f.deck)].id
			facilities[f.uid] = {"reachable": false,
				"reasonKey": "warn.facility_unreachable" if decks_reached.has(int(f.deck)) else "warn.deck_no_stair",
				"reasonParams": {"deck": deck_name}}
	var missing := []
	for id in C.FACILITIES:
		if not C.FACILITIES[id].get("required", false):
			continue
		var found := false
		for f in ship.facilities:
			if f.id == id and facilities[f.uid].reachable:
				found = true
		if not found:
			missing.append(id)
	var disabled := []
	var capacity := 0
	for f in ship.facilities:
		if not facilities[f.uid].reachable:
			disabled.append(f.uid)
		elif f.id == "crew_quarters":
			capacity += 4 + 2 * int(f.level)
	var over := crew_count >= 0 and crew_count > capacity
	return {"facilities": facilities, "reached": reached, "decksReached": decks_reached, "missingRequired": missing,
		"disabled": disabled, "capacity": capacity, "overCapacity": over, "canDepart": missing.is_empty() and not over}


# -------------------------------------------------------------- facilities
static func layout_of(state: Dictionary) -> Dictionary:
	return analyze_layout(state.ship, state.crew.size())


static func active_facilities(state: Dictionary, lay: Variant = null) -> Array:
	var l: Dictionary = lay if lay != null else layout_of(state)
	var out := []
	for f in state.ship.facilities:
		if l.facilities.has(f.uid) and l.facilities[f.uid].reachable:
			out.append(f)
	return out


static func fac_level(state: Dictionary, id: String, allow_damaged := false, lay: Variant = null) -> int:
	var best := 0
	for f in active_facilities(state, lay):
		if f.id == id and (allow_damaged or not f.damaged):
			best = max(best, int(f.level))
	return best


static func best_facility(state: Dictionary, id: String, lay: Variant = null) -> Variant:
	var best = null
	for f in active_facilities(state, lay):
		if f.id == id and (best == null or int(f.level) > int(best.level) or (best.damaged and not f.damaged)):
			best = f
	return best


static func job_slots(f: Dictionary) -> int:
	var j: int = C.FACILITIES[f.id].jobs
	return j + (1 if j > 0 and int(f.level) >= 3 else 0)


static func worker_efficiency(state: Dictionary, m: Dictionary, fac_id: String) -> float:
	var cls: Dictionary = C.CLASSES[m.classId]
	var e := 1.0 if cls.jobs.has(fac_id) else 0.5
	e += U.num(member_stats(state, m).mods, "jobPct")
	return e


static func pet_helper_efficiency(pet: Dictionary) -> float:
	return (1.0 if pet_roles(pet).has("helper") else 0.5) * (1.4 if pet.evolved else 1.0)


static func staff_mult(state: Dictionary, fac_id: String, lay: Variant = null) -> float:
	var f = best_facility(state, fac_id, lay)
	if f == null or f.damaged:
		return 1.0
	var s := 0.0
	for m in state.crew:
		if m.jobFacilityUid == f.uid:
			s += worker_efficiency(state, m, fac_id)
	for p in state.pets:
		if p.assignment != null and p.assignment.kind == "helper" and p.assignment.target == f.uid:
			s += pet_helper_efficiency(p)
	return 1.0 + 0.5 * s


static func crew_capacity(state: Dictionary, lay: Variant = null) -> int:
	return (lay if lay != null else layout_of(state)).capacity + int(Collections.mod(state, "crewSlot"))


static func food_capacity(state: Dictionary, lay: Variant = null) -> int:
	var c := 0
	for f in active_facilities(state, lay):
		if f.id == "pantry":
			c += 20 + 10 * int(f.level)
	return c


static func supply_capacity(state: Dictionary, lay: Variant = null) -> int:
	return int(T().baseSupplyCap) + 5 * fac_level(state, "cargo_hold", true, lay)


static func equip_capacity(state: Dictionary, lay: Variant = null) -> int:
	return int(T().baseEquipCap) + 20 * fac_level(state, "cargo_hold", true, lay) + 30 * fac_level(state, "secure_locker", true, lay)


static func pet_capacity(state: Dictionary, lay: Variant = null) -> int:
	return 2 + 2 * fac_level(state, "pet_lab", true, lay) + 3 * fac_level(state, "creature_pens", true, lay)


static func egg_capacity(state: Dictionary, lay: Variant = null) -> int:
	return 2 + fac_level(state, "hatchery", true, lay)


static func stamina_max(state: Dictionary, lay: Variant = null) -> int:
	var cabin := fac_level(state, "captains_cabin", true, lay)
	return int(T().maxStamina) + 10 * max(0, cabin - 1) + 10 * (int(state.ship.hullTier) - 1)


static func upgrade_cost(f: Dictionary) -> Dictionary:
	var def: Dictionary = C.FACILITIES[f.id]
	var lvl := int(f.level) + 1
	var g := float(def.cost.gold) if def.cost.gold else 60.0
	var mt := float(def.cost.materials) if def.cost.materials else 10.0
	return {"gold": U.jround(g * 0.8 * lvl), "materials": U.jround(mt * lvl)}


static func demolish_refund(f: Dictionary) -> Dictionary:
	var def: Dictionary = C.FACILITIES[f.id]
	var materials: int = int(def.cost.get("materials", 0))
	var gold := U.jround(float(def.cost.get("gold", 0)) * 0.5)
	for l in range(2, int(f.level) + 1):
		var c := upgrade_cost({"id": f.id, "level": l - 1})
		materials += int(c.materials)
		gold += U.jround(c.gold * 0.5)
	return {"gold": gold, "materials": materials, "specialty": def.cost.get("specialty")}


# -------------------------------------------------------------------- crew
static func member(state: Dictionary, id: Variant) -> Variant:
	for m in state.crew:
		if m.id == id:
			return m
	return null


static func equip_inst(state: Dictionary, uid: Variant) -> Variant:
	if uid == null:
		return null
	for e in state.inventory.equipment:
		if e.uid == uid:
			return e
	return null


static func active_passives(m: Dictionary) -> Array:
	var out := [C.CLASSES[m.classId].passive]
	for p in m.legacy:
		if not out.has(p):
			out.append(p)
	return out


static func mastered_classes(m: Dictionary) -> Array:
	var out := []
	for c in m.mastery:
		if float(m.mastery[c]) >= float(T().masteredAt):
			out.append(c)
	return out


static func legacy_options(m: Dictionary) -> Array:
	var current: String = C.CLASSES[m.classId].passive
	var out := []
	for c in mastered_classes(m):
		var p: String = C.CLASSES[c].passive
		if p != current and not out.has(p):
			out.append(p)
	return out


static func qualified_for(m: Dictionary, class_id: String) -> bool:
	var c = C.CLASSES.get(class_id)
	if not c:
		return false
	if c.tier == "base":
		return true
	return float(m.mastery.get(c.parent, 0)) >= float(T().qualifyMastery) or float(m.mastery.get(class_id, 0)) > 0.0


static func weapon_compatible(class_id: String, item_id: String) -> bool:
	var it = C.ITEMS.get(item_id)
	if not it or it.slot != "weapon":
		return true
	return C.CLASSES[class_id].weapons.has(it.wtype)


static func weapon_range(class_id: String, item: Variant) -> String:
	if item == null:
		return C.CLASSES[class_id].range
	var w = item.get("wtype")
	if w in ["blade", "shield", "fist"]:
		return "melee"
	if w in ["spear", "whip"]:
		return "reach"
	if w == "gun":
		return "ranged"
	return C.CLASSES[class_id].range


static func slot_of(state: Dictionary, crew_id: Variant) -> int:
	return state.formation.find(crew_id)


static func lane_of_slot(i: int) -> String:
	return LANES[i / 2]


static func member_stats(state: Dictionary, m: Dictionary) -> Dictionary:
	var cls: Dictionary = C.CLASSES[m.classId]
	var g: Dictionary = T().growth
	var L := float(m.level)
	var mods := {}
	for p in active_passives(m):
		U.add_mods(mods, C.PASSIVES.get(p))
	for a in m.aptitudes:
		U.add_mods(mods, C.data.APTITUDES.get(a))
	U.add_mods(mods, Collections.mod_map(state))
	var props := []
	var resist := []
	var hp := float(cls.base.hp) * float(cls.mult.hp) * (1.0 + float(g.hp) * (L - 1.0)) + float(m.variance.hp)
	var atk := float(cls.base.atk) * float(cls.mult.atk) * (1.0 + float(g.atk) * (L - 1.0)) + float(m.variance.atk)
	var def := float(cls.base.def) * float(cls.mult.def) * (1.0 + float(g.def) * (L - 1.0)) + float(m.variance.def)
	var spd := float(cls.base.spd) * float(cls.mult.spd) + 0.25 * (L - 1.0) + float(m.variance.spd)
	var weapon_item = null
	for slot in ["weapon", "outfit", "accessory"]:
		var inst = equip_inst(state, m.equipment[slot])
		if inst == null:
			continue
		var it = C.ITEMS.get(inst.itemId)
		if not it:
			continue
		if slot == "weapon":
			weapon_item = it
		var f := 1.0 + 0.1 * float(inst.get("reinforce", 0))
		hp += U.num(it.stats, "hp") * f
		atk += U.num(it.stats, "atk") * f
		def += U.num(it.stats, "def") * f
		spd += U.num(it.stats, "spd")
		for p in it.get("props", []):
			if not props.has(p):
				props.append(p)
		for r in it.get("resist", []):
			if not resist.has(r):
				resist.append(r)
		U.add_mods(mods, it.get("mods"))
		if inst.get("affix") != null:
			U.add_mods(mods, C.data.AFFIXES.get(inst.affix))
	if props.has("crit"):
		mods.crit = U.num(mods, "crit") + 0.1
	if props.has("lifesteal"):
		mods.lifesteal = U.num(mods, "lifesteal") + 0.15
	if props.has("guard"):
		mods.guard = U.num(mods, "guard") + 0.1
	hp *= 1.0 + U.num(mods, "hpPct")
	atk *= 1.0 + U.num(mods, "atkPct")
	def *= 1.0 + U.num(mods, "defPct")
	spd += U.num(mods, "spd")
	if m.injured:
		var k := 1.0 - float(T().injuryPenalty)
		hp *= k; atk *= k; def *= k; spd *= k
	var slot := slot_of(state, m.id)
	return {"hp": U.jround(hp), "atk": U.jround(atk), "def": U.jround(def), "spd": U.round1(spd),
		"crit": 0.05 + U.num(mods, "crit"), "dodge": U.num(mods, "dodge"), "range": weapon_range(m.classId, weapon_item),
		"lane": lane_of_slot(slot) if slot >= 0 else cls.lane, "props": props, "mods": mods, "resist": resist,
		"skills": cls.skills.duplicate(), "passives": active_passives(m), "roles": cls.roles}


static func power(state: Dictionary, m: Dictionary) -> int:
	var s := member_stats(state, m)
	return U.jround(float(s.hp) / 6.0 + float(s.atk) * 2.0 + float(s.def) * 1.5 + float(s.spd) * 2.0)


static func xp_to_next(level: int) -> int:
	return int(T().xpBase) + int(T().xpPerLevel) * level


static func respec_cost(m: Dictionary) -> Dictionary:
	return {"gold": int(T().respecBase) + int(T().respecPerLevel) * int(m.level)}


static func treat_cost(m: Dictionary) -> Dictionary:
	return {"gold": 20 + 5 * int(m.level), "supplies": 1}


# -------------------------------------------------------------------- pets
static func pet_roles(pet: Dictionary) -> Array:
	var sp: Dictionary = C.PET_SPECIES[pet.speciesId]
	var roles := [sp.role]
	if pet.evolved:
		var alt = C.data.ROLE_BY_COLOR.get(pet.affinity)
		var pr: Array = C.data.PET_ROLES
		roles.append(alt if alt and alt != sp.role else pr[(pr.find(sp.role) + 1) % 3])
	return roles


static func input_color(input: String) -> Variant:
	var parts := input.split(":")
	if parts.size() < 2:
		return null
	if parts[0] == "ing" and C.data.INGREDIENTS.has(parts[1]):
		return C.data.INGREDIENTS[parts[1]].color
	if parts[0] == "spec" and C.data.SPECIALTIES.has(parts[1]):
		return C.data.SPECIALTIES[parts[1]].color
	return null


static func hatch_outcome(egg: Dictionary, inputs: Array) -> Dictionary:
	var fam: Dictionary = C.pet_family(egg.familyId)
	var colors := []
	for i in inputs:
		colors.append(input_color(i))
	var role: String = C.data.ROLE_BY_COLOR.get(colors[0], "companion")
	var sig: Array = fam.sig[role]
	var prime := colors.size() == 3
	if prime:
		for i in 3:
			if colors[i] != sig[i]:
				prime = false
	var counts := {}
	for c in colors:
		counts[c] = int(counts.get(c, 0)) + 1
	var affinity = colors[0]
	for c in colors:
		if counts[c] > counts[affinity]:
			affinity = c
	var lv := [1, 3, 5]
	return {"speciesId": fam.id + "_" + role, "familyId": fam.id, "role": role, "prime": prime, "affinity": affinity,
		"level": lv[int(egg.grade) - 1] if int(egg.grade) >= 1 and int(egg.grade) <= 3 else 1}


static func pet_level_needed(pet: Dictionary) -> int:
	return 4 if pet.prime else 5


static func evolve_cost(pet: Dictionary) -> Dictionary:
	var fam: Dictionary = C.pet_family(pet.familyId)
	var tier: int = C.data.REGION_ORDER.find(fam.regionId) + 1
	return {"materials": 15 + 5 * tier, "specialty": [C.data.REGION_SPECIALTY[fam.regionId], 2], "level": pet_level_needed(pet)}


static func pet_xp_to_next(level: int) -> int:
	return 20 * level


static func pet_power_mult(pet: Dictionary, owner: Variant, owner_stats: Variant) -> float:
	var k := (1.0 + 0.08 * (float(pet.level) - 1.0)) * (1.4 if pet.evolved else 1.0) * (1.25 if pet.prime else 1.0)
	var bonus := 0.0
	if owner_stats != null:
		bonus += U.num(owner_stats.mods, "petPct")
		if owner_stats.props.has("pet"):
			bonus += 0.25
	if owner != null and owner.petAffinity == pet.affinity:
		bonus += 0.2
	return k * (1.0 + bonus)


static func explorer_pet(state: Dictionary) -> Variant:
	for p in state.pets:
		if p.assignment != null and p.assignment.kind == "explorer":
			return p
	return null


# ------------------------------------------------------------------- world
static func knowledge(state: Dictionary, loc_id: String) -> String:
	var l = state.world.locations.get(loc_id)
	return l.k if l else "hidden"


static func is_known(state: Dictionary, loc_id: String) -> bool:
	return knowledge(state, loc_id) != "hidden"


static func is_visited(state: Dictionary, loc_id: String) -> bool:
	var k := knowledge(state, loc_id)
	return k == "visited" or k == "cleared"


static func region_unlocked(state: Dictionary, region_id: String) -> bool:
	return state.captain.regionsUnlocked.has(region_id)


static func day(state: Dictionary) -> int:
	return int(floor(float(state.envelope.gameClock) / 24.0))


static func rotation(state: Dictionary) -> int:
	return int(floor(float(day(state)) / 3.0))


static func at_port(state: Dictionary) -> bool:
	return state.voyage == null and C.PORTS.has(state.world.currentLocationId)


static func port_track(state: Dictionary, port_id: String, track: String) -> int:
	var p = state.world.ports.get(port_id)
	return int(p.tracks.get(track, 0)) if p else 0


static func rep_rank(state: Dictionary, faction: String) -> int:
	return min(3, int(floor(float(state.captain.reputation.get(faction, 0)) / 40.0)))


static func active_crew(state: Dictionary) -> Array:
	var out := []
	for id in state.formation:
		if id == null:
			continue
		var m = member(state, id)
		if m:
			out.append(m)
	return out


static func best_mod(state: Dictionary, key: String) -> float:
	var v := 0.0
	for m in active_crew(state):
		v = max(v, U.num(member_stats(state, m).mods, key))
	return v


static func sea_event_chance(state: Dictionary) -> float:
	return float(C.world.SEA_EVENT_CHANCE) * (1.0 - min(0.6, max(best_mod(state, "avoid"), Collections.mod(state, "avoid"))))


static func leg_cost(state: Dictionary, from_id: String, to_id: String) -> Dictionary:
	var a = C.location(from_id)
	var b = C.location(to_id)
	var d := World.distance(from_id, to_id)
	var cross: bool = a.regionId != b.regionId
	var food: int = max(1, int(ceil(d * 6.0))) + state.crew.size() / 5
	var lay := layout_of(state)
	var mess := fac_level(state, "mess_hall", false, lay)
	if mess:
		food -= 2 if mess >= 3 else 1
	if cross:
		food -= 2 * fac_level(state, "compass_room", false, lay)
	if not cross and state.world.shortcuts.get(a.regionId, false):
		food -= 1
	food -= int(max(best_mod(state, "foodSave"), Collections.mod(state, "foodSave")))
	if int(state.ship.damage) >= 40:
		food += 1
	return {"distance": d, "hours": U.jround(4.0 + d * 20.0), "food": max(1, food), "cross": cross}


static func known_ports(state: Dictionary) -> Array:
	var out := []
	for p in C.PORTS:
		if is_known(state, p) and region_unlocked(state, C.location(p).regionId):
			out.append(p)
	return out


static func hazard_known(state: Dictionary, region_id: String) -> bool:
	var r = C.region(region_id)
	for id in r.locs:
		if is_visited(state, id):
			return true
	if fac_level(state, "chart_table") > 0 or fac_level(state, "compass_room") > 0:
		return true
	return port_track(state, r.locs[0], "navigation") >= 1 or port_track(state, r.locs[1], "navigation") >= 1


static func forecast_exact(state: Dictionary, region_id: String) -> bool:
	var r = C.region(region_id)
	return fac_level(state, "chart_table") > 0 or port_track(state, r.locs[0], "navigation") >= 1 or port_track(state, r.locs[1], "navigation") >= 1


static func sea_weights(state: Dictionary, region_id: String) -> Dictionary:
	var r = C.region(region_id)
	var w: Dictionary = {}
	for k in r.sea:
		w[k] = float(r.sea[k])
	var chart := fac_level(state, "chart_table")
	if chart:
		var k := 1.0 + 0.5 * (staff_mult(state, "chart_table") - 1.0)
		w.pirate *= max(0.2, 1.0 - 0.15 * chart * k)
		w.monster *= max(0.2, 1.0 - 0.15 * chart * k)
	return w


static func planned_stamina(state: Dictionary, loc_id: String) -> int:
	var loc = C.location(loc_id)
	if not loc or loc.type == "port":
		return 0
	var done: Array = state.world.locations[loc_id].rooms
	var total := 0
	for r in C.rooms(loc_id):
		if not r.get("secret", false) and not done.has(r.id):
			total += int(r.cost)
	if total:
		return total
	for r in C.rooms(loc_id):
		if r.get("objective", false):
			total += int(r.cost)
	return total


static func route_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


static func charted_path(state: Dictionary, a: String, b: String) -> bool:
	var adj := {}
	for k in state.world.chartedRoutes:
		var p: PackedStringArray = k.split("|")
		if not adj.has(p[0]): adj[p[0]] = []
		if not adj.has(p[1]): adj[p[1]] = []
		adj[p[0]].append(p[1])
		adj[p[1]].append(p[0])
	var seen := {a: true}
	var q := [a]
	var i := 0
	while i < q.size():
		var c: String = q[i]
		i += 1
		if c == b:
			return true
		for n in adj.get(c, []):
			if not seen.has(n):
				seen[n] = true
				q.append(n)
	return false


static func sail_block(state: Dictionary, to_id: String, fast: bool) -> String:
	var loc = C.location(to_id)
	if not loc:
		return "err.unknown_location"
	if state.encounter != null:
		return "err.in_encounter"
	if state.voyage != null and state.voyage.event != null:
		return "err.event_pending"
	if to_id == state.world.currentLocationId:
		return "err.same_location"
	if not region_unlocked(state, loc.regionId):
		return "err.region_locked"
	var reg = C.region(loc.regionId)
	if reg.get("requiresHullTier") and int(state.ship.hullTier) < int(reg.requiresHullTier):
		return "err.hull_required"
	if not is_known(state, to_id):
		return "err.not_revealed"
	if state.voyage == null:
		var lay := layout_of(state)
		if not lay.canDepart:
			return "err.over_capacity" if lay.overCapacity else "err.layout_blocked"
	if fast:
		if not at_port(state) or not C.PORTS.has(to_id):
			return "err.fast_ports_only"
		if not is_visited(state, to_id):
			return "err.fast_not_visited"
		if not charted_path(state, state.world.currentLocationId, to_id):
			return "err.fast_not_charted"
	var leg := leg_cost(state, state.world.currentLocationId, to_id)
	if int(state.inventory.food) < int(leg.food):
		return "err.no_food_route"
	return ""


## A healthy scout in the active formation makes the route panel show exact
## intelligence instead of vague warnings.
static func scout_active(state: Dictionary) -> bool:
	for m in active_crew(state):
		if bool(m.get("injured", false)):
			continue
		var roles: Array = C.CLASSES.get(m.classId, {}).get("roles", [])
		if roles.has("scout"):
			return true
	return false


## Deterministic route intelligence for a destination. Returns an empty
## dictionary when no scout is aboard; otherwise threats, the regional rare
## monster, unseen hidden rooms and exact sea-event odds.
static func scout_intel(state: Dictionary, to_id: String) -> Dictionary:
	if not scout_active(state):
		return {}
	var loc = C.location(to_id)
	if loc == null:
		return {}
	var reg = C.region(loc.regionId)
	if reg == null:
		return {}
	var threats := []
	for arch in Bestiary.region_archetypes(reg.id):
		if not threats.has(arch):
			threats.append(String(arch))
	if reg.bosses.size() and not threats.has("boss"):
		threats.append("boss")
	threats.sort()
	var done: Array = state.world.locations.get(to_id, {}).get("rooms", [])
	var hidden := 0
	for rm in C.rooms(to_id):
		if done.has(rm.id):
			continue
		if rm.get("secret", false) or rm.get("objective", false):
			hidden += 1
	var sea := []
	if not C.PORTS.has(to_id):
		var w := sea_weights(state, loc.regionId)
		var total := U.sum_values(w)
		var chance := sea_event_chance(state)
		if total > 0.0:
			for k in C.world.SEA_EVENT_KINDS:
				var weight := float(w.get(k, 0.0))
				if weight > 0.0:
					sea.append({"kind": String(k), "pct": chance * weight / total})
	var rare = Bestiary.region_rare(reg.id)
	return {"threats": threats, "rare": String(rare) if rare != null else "", "hiddenRooms": hidden,
		"seaKinds": sea, "exact": true}


static func route_info(state: Dictionary, to_id: String, fast: bool) -> Dictionary:
	var from: String = state.world.currentLocationId
	var loc = C.location(to_id)
	var leg := leg_cost(state, from, to_id)
	var ports := []
	for p in known_ports(state):
		if p == to_id:
			continue
		var lc := leg_cost(state, to_id, p)
		ports.append({"id": p, "food": lc.food, "hours": lc.hours})
	ports.sort_custom(func(x, y): return int(x.food) < int(y.food))
	ports = ports.slice(0, 3)
	var return_food: int = 0 if C.PORTS.has(to_id) else (int(ports[0].food) if ports.size() else 0)
	var food_after: int = int(state.inventory.food) - int(leg.food)
	var reg = C.region(loc.regionId)
	var hz := []
	if reg.hazard: hz.append(reg.hazard)
	if reg.mechanic: hz.append(reg.mechanic)
	var planned := planned_stamina(state, to_id)
	var w := sea_weights(state, loc.regionId)
	var total := U.sum_values(w)
	var chance := sea_event_chance(state)
	var encounters := []
	if not fast:
		for k in C.world.SEA_EVENT_KINDS:
			var pct := U.jround(100.0 * chance * float(w[k]) / total)
			if pct > 0:
				encounters.append({"kind": k, "pct": pct})
	var supplies_now: int = int(state.inventory.supplies)
	return {"toId": to_id, "fromId": from, "fast": fast, "distance": leg.distance, "hours": leg.hours, "food": leg.food,
		"foodAfter": food_after, "returnFood": return_food, "returnOk": food_after >= return_food,
		"stamina": state.ship.stamina, "plannedStamina": planned, "staminaAfter": int(state.ship.stamina) - planned,
		"hazards": hz, "hazardsKnown": hazard_known(state, loc.regionId), "encounters": encounters,
		"supplies": supplies_now, "suppliesAfter": supplies_now,
		"scout": scout_active(state), "intel": scout_intel(state, to_id),
		"exact": forecast_exact(state, loc.regionId), "firstDiscovery": not is_visited(state, to_id), "level": loc.level,
		"capability": reg.capability, "returnPorts": ports, "blockKey": sail_block(state, to_id, fast)}


# -------------------------------------------------------------- main quest
static func main_status(state: Dictionary) -> Dictionary:
	var regs: Array = state.captain.regionsUnlocked
	for i in range(regs.size() - 1, -1, -1):
		var rid: String = regs[i]
		var step := int(state.captain.mainStep.get(rid, 0))
		if step < C.world.MAIN_TEMPLATE.size():
			var q = C.main_step(rid, step)
			var arena: String = C.region(rid).locs[8]
			return {"regionId": rid, "step": step, "quest": q, "trialLocationId": arena, "trialKnown": is_known(state, arena),
				"trialWon": state.captain.trialsWon.has(rid), "done": false}
	return {"done": true, "regionId": regs[regs.size() - 1]}


# ------------------------------------------------------------------- ports
static func region_tier_of_port(port_id: String) -> int:
	return int(C.region(C.PORTS[port_id].regionId).tier)


static func invest_cost(state: Dictionary, port_id: String, track: String) -> Variant:
	var lvl := port_track(state, port_id, track)
	if lvl >= 3:
		return null
	var t := region_tier_of_port(port_id)
	var nxt := lvl + 1
	var cost := {"gold": U.jround((70.0 + 55.0 * t) * nxt * (1.0 - 0.05 * rep_rank(state, "league"))), "level": nxt}
	if nxt == 3:
		cost.specialty = [C.region(C.PORTS[port_id].regionId).specialtyId, 2]
	return cost


static func prices(state: Dictionary, port_id: String) -> Dictionary:
	var t := float(region_tier_of_port(port_id))
	var disc := 0.9 if port_track(state, port_id, "market") >= 3 else 1.0
	return {"food": U.jround((3.0 + t) * disc), "supplies": U.jround((18.0 + 4.0 * t) * disc),
		"ingredient": U.jround((10.0 + 2.0 * t) * disc), "egg": U.jround((140.0 + 45.0 * t) * disc)}


static func specialty_buy_price(state: Dictionary, port_id: String, spec_id: String) -> int:
	return U.jround(float(C.data.SPECIALTIES[spec_id].price) * (0.9 if port_track(state, port_id, "market") >= 3 else 1.0))


static func specialty_sell_price(state: Dictionary, port_id: String, spec_id: String) -> int:
	var home := -1
	for r in C.data.REGION_SPECIALTY:
		if C.data.REGION_SPECIALTY[r] == spec_id:
			home = C.data.REGION_ORDER.find(r)
	var here: int = C.data.REGION_ORDER.find(C.PORTS[port_id].regionId)
	var k: float = min(1.4, 0.6 + 0.15 * abs(home - here))
	return U.jround(float(C.data.SPECIALTIES[spec_id].price) * k * (1.15 if port_track(state, port_id, "market") >= 3 else 1.0))


static func shop_items(state: Dictionary, port_id: String) -> Array:
	var m := port_track(state, port_id, "market")
	var t := region_tier_of_port(port_id)
	var out := []
	if m >= 1:
		out.append_array(["a_escape_rope", "a_work_gloves"])
	if m >= 2:
		for w in C.data.WEAPON_TYPES:
			out.append("w_%s_%d" % [w, t])
		out.append("o_coat_%d" % t)
		out.append("o_armor_%d" % t)
	if m >= 3:
		out.append("a_" + C.data.REGIONAL_ACCESSORIES[t - 1].id)
	var region_id := String(C.PORTS[port_id].regionId)
	for offer in C.SHOP_ITEMS:
		if not (offer is Dictionary):
			continue
		if m < int(offer.get("marketLevel", 3)):
			continue
		var regions: Array = offer.get("regions", [])
		if regions.size() and not regions.has(region_id):
			continue
		var item_id := String(offer.get("id", ""))
		if C.ITEMS.has(item_id) and not out.has(item_id):
			out.append(item_id)
	return out


static func item_price(item_id: String) -> int:
	return int(C.ITEMS[item_id].price)


## Deterministic daily curio stock: unowned curios from the port's region
## and its immediate neighbours. Same port on the same game day gives the
## same offers.
static func curio_offers(state: Dictionary, port_id: String) -> Array:
	var port = C.PORTS.get(port_id)
	if port == null:
		return []
	var home = C.region(String(port.regionId))
	if home == null:
		return []
	var regions := [String(home.id)]
	for rid in C.REGION_BY_ID:
		var r = C.region(String(rid))
		if r == null:
			continue
		if abs(int(r.order) - int(home.order)) <= 1 and not regions.has(String(rid)):
			regions.append(String(rid))
	var pool := []
	for cid in C.COLLECTIBLES:
		var rec: Dictionary = C.COLLECTIBLES[cid]
		if String(rec.get("kind", "")) != "curio":
			continue
		if not regions.has(String(rec.get("regionId", ""))):
			continue
		if Collections.owns(state, String(cid)):
			continue
		pool.append(String(cid))
	var rng := U.Rng.new(U.seed_of("curio:%s:%d" % [port_id, day(state)]))
	var out := []
	while out.size() < C.CURIOS_PER_PORT and not pool.is_empty():
		var idx := int(floor(rng.next() * float(pool.size())))
		var cid := String(pool[idx])
		pool.remove_at(idx)
		var rec: Dictionary = C.COLLECTIBLES[cid]
		var tier := region_tier_of_port(port_id)
		var price := U.jround(float(Collections.sell_value(cid)) * 1.6 + 25.0 * float(tier))
		out.append({"id": cid, "price": price, "nameKey": Collections.name_key(cid),
			"descKey": Collections.desc_key(cid), "icon": Collections.icon(cid),
			"rarity": Collections.rarity(cid), "kind": Collections.kind(cid),
			"regionId": String(rec.get("regionId", ""))})
	return out


## Shard exchange list for the port: unowned collectibles from the local
## region, priced by rarity. Sorted for a stable panel.
static func curio_exchange(state: Dictionary, port_id: String) -> Array:
	var port = C.PORTS.get(port_id)
	if port == null:
		return []
	var region_id := String(port.regionId)
	var costs := {"common": 4, "uncommon": 8, "rare": 16, "epic": 28, "legendary": 45}
	var out := []
	for cid in C.COLLECTIBLES:
		var rec: Dictionary = C.COLLECTIBLES[cid]
		if String(rec.get("regionId", "")) != region_id:
			continue
		if Collections.owns(state, String(cid)):
			continue
		out.append({"id": String(cid), "shards": int(costs.get(Collections.rarity(String(cid)), 8)),
			"nameKey": Collections.name_key(String(cid)), "icon": Collections.icon(String(cid)),
			"rarity": Collections.rarity(String(cid)), "kind": Collections.kind(String(cid))})
	out.sort_custom(func(a, b): return int(a.shards) < int(b.shards) or (int(a.shards) == int(b.shards) and String(a.id) < String(b.id)))
	return out


static func salvage_value(inst: Dictionary) -> Dictionary:
	var it: Dictionary = C.ITEMS[inst.itemId]
	var base := float(it.recipe.materials) if it.get("recipe") else 4.0
	return {"materials": max(2, U.jround(base * 0.6 + 2.0 * float(inst.get("reinforce", 0))))}


static func workshop_discount(state: Dictionary) -> float:
	return 0.75 if at_port(state) and port_track(state, state.world.currentLocationId, "workshop") >= 3 else 1.0


static func reinforce_cost(inst: Dictionary, state: Dictionary) -> Dictionary:
	var it: Dictionary = C.ITEMS[inst.itemId]
	var k := workshop_discount(state)
	return {"materials": U.jround((6.0 + 4.0 * float(it.tier) + 4.0 * float(inst.get("reinforce", 0))) * k), "gold": U.jround(20.0 * float(it.tier) * k)}


static func craft_cost(item_id: String, affix: Variant, state: Dictionary) -> Variant:
	var it = C.ITEMS.get(item_id)
	if not it or not it.get("recipe"):
		return null
	var k := workshop_discount(state)
	var c := {"materials": U.jround(float(it.recipe.materials) * k), "specialty": it.recipe.specialty.duplicate(), "gold": U.jround(float(it.price) * 0.25 * k)}
	if affix:
		c.specialty = [c.specialty[0], int(c.specialty[1]) + 1]
	return c


static func can_craft_here(state: Dictionary) -> bool:
	if at_port(state) and port_track(state, state.world.currentLocationId, "workshop") >= 1:
		return true
	return fac_level(state, "workshop") > 0


static func can_reinforce_here(state: Dictionary) -> bool:
	if at_port(state) and port_track(state, state.world.currentLocationId, "workshop") >= 2:
		return true
	return fac_level(state, "workshop") >= 2


static func repair_cost(state: Dictionary) -> Dictionary:
	var t := region_tier_of_port(state.world.currentLocationId) if at_port(state) else 1
	var dmg_fac := 0
	for f in state.ship.facilities:
		if f.damaged:
			dmg_fac += 1
	var dmg := int(state.ship.damage)
	return {"gold": U.jround(dmg * (2 + t) + 30 * dmg_fac), "materials": int(ceil(dmg / 4.0)) + 5 * dmg_fac, "needed": dmg > 0 or dmg_fac > 0}


static func hull_available(state: Dictionary, hull: Dictionary) -> Dictionary:
	if int(hull.tier) != int(state.ship.hullTier) + 1:
		return {"ok": false, "reasonKey": "err.hull_owned" if int(hull.tier) <= int(state.ship.hullTier) else "err.hull_previous"}
	var region_idx: int = state.captain.regionsUnlocked.size()
	if region_idx < int(hull.unlockRegion):
		return {"ok": false, "reasonKey": "err.hull_region", "reasonParams": {"region": "region." + C.data.REGION_ORDER[int(hull.unlockRegion) - 1] + ".name"}}
	if hull.get("blueprint") and not state.inventory.blueprints.has(hull.blueprint):
		return {"ok": false, "reasonKey": "err.hull_blueprint"}
	if not at_port(state) or port_track(state, state.world.currentLocationId, "workshop") < 2:
		return {"ok": false, "reasonKey": "err.need_workshop2"}
	return {"ok": true}


static func emergency_needs(state: Dictionary) -> Array:
	if not at_port(state):
		return []
	var needs := []
	var inv: Dictionary = state.inventory
	var pr := prices(state, state.world.currentLocationId)
	if int(inv.food) < 1 and int(inv.gold) < int(pr.food):
		needs.append("meal")
	if int(state.ship.stamina) < 15 and int(inv.food) < 1 and int(inv.supplies) < 1 and int(inv.gold) < int(pr.food):
		if not needs.has("meal"):
			needs.append("meal")
	var injured := []
	for m in state.crew:
		if m.injured:
			injured.append(m)
	if injured.size() and int(inv.supplies) < 1 and int(inv.gold) < int(treat_cost(injured[0]).gold):
		needs.append("treatment")
	var rc := repair_cost(state)
	var any_damaged := false
	for f in state.ship.facilities:
		if f.damaged:
			any_damaged = true
	if (int(state.ship.damage) >= 30 or any_damaged) and int(inv.gold) < int(rc.gold) and int(inv.materials) < int(rc.materials):
		needs.append("repair")
	return needs


static func recovery_contract_available(state: Dictionary) -> bool:
	return at_port(state) and int(state.inventory.gold) < 60


# ------------------------------------------------------------------ tavern
static func tavern_pool(state: Dictionary, port_id: String) -> Array:
	var lvl := port_track(state, port_id, "tavern")
	var rot := rotation(state)
	var tv = state.world.taverns.get(port_id)
	var hired: Array = tv.hired if tv and int(tv.rotation) == rot else []
	var reg = C.region(C.PORTS[port_id].regionId)
	var ri: int = int(reg.order) - 1
	var corner := fac_level(state, "tavern_corner")
	var size: int = TAVERN_SIZE[lvl] + (1 if corner else 0)
	var base := U.seed_of(state.envelope.profileId + ":tavern:" + port_id + ":" + str(rot))
	var r := U.Rng.new(base)
	var classes: Array = C.data.BASE_CLASS_IDS.duplicate()
	for i in range(classes.size() - 1, 0, -1):
		var j := int(floor(r.next() * (i + 1)))
		var tmp = classes[i]
		classes[i] = classes[j]
		classes[j] = tmp
	var class_pool: Array = C.data.BASE_CLASS_IDS if lvl >= 2 else classes.slice(0, 8 if lvl >= 1 else 4)
	var O: Array = C.data.ORIGINS
	var origin_pool: Array = O if lvl >= 2 else ([O[ri], O[max(0, ri - 1)], O[min(9, ri + 1)]] if lvl >= 1 else [O[ri]])
	var level: int = max(1, int(reg.level) + (1 if lvl >= 2 else 0) + (1 if lvl >= 3 else 0))
	var out := []
	for i in size:
		var m := GS.make_recruit(U.seed_of(str(base) + ":" + str(i)), {"classPool": class_pool, "originPool": origin_pool, "level": level, "qualified": lvl >= 3 and i < 2})
		out.append({"index": i, "member": m, "cost": recruit_cost(state, m), "hired": U.arr_has(hired, i), "aptVisible": lvl >= 2})
	return out


static func recruit_cost(state: Dictionary, m: Dictionary) -> int:
	return U.jround((50.0 + 20.0 * float(m.level)) * (1.0 - 0.1 * fac_level(state, "tavern_corner")))


# --------------------------------------------------------------- contracts
static func contract_offers(state: Dictionary, port_id: String) -> Array:
	if port_track(state, port_id, "quest_board") < 2:
		return []
	var rot := rotation(state)
	var reg = C.region(C.PORTS[port_id].regionId)
	var t: int = reg.tier
	var r := U.Rng.new(U.seed_of(state.envelope.profileId + ":contracts:" + port_id + ":" + str(rot)))
	var types: Array = C.world.CONTRACT_TYPES
	var out := []
	var used := []
	for i in 2:
		var type: String = r.pick(types)
		if used.has(type):
			type = types[(types.find(type) + 1) % 3]
		used.append(type)
		var id := "contract:%s:%d:%d" % [port_id, rot, i]
		var pr := prices(state, port_id)
		var c := {}
		if type == "hunt":
			c = {"need": 3, "reward": {"gold": 40 + 30 * t, "materials": 8 + 4 * t, "rep": 4}}
		elif type == "supply":
			var n := 4 + t
			c = {"need": n, "reward": {"gold": U.jround(n * float(pr.food) * 1.6), "materials": 0, "rep": 3}}
		else:
			var unlocked := []
			for x in state.captain.regionsUnlocked:
				if x != reg.id:
					unlocked.append(x)
			var src: String = unlocked[int(floor(r.next() * unlocked.size()))] if unlocked.size() else reg.id
			var spec: String = C.region(src).specialtyId
			c = {"need": 2, "specialtyId": spec, "reward": {"gold": U.jround(specialty_sell_price(state, port_id, spec) * 2 * 1.5), "materials": 4 * t, "rep": 4}}
		var saved = state.world.contracts.get(id)
		var offer := {"id": id, "portId": port_id, "type": type, "regionId": reg.id,
			"status": saved.status if saved else "offered", "progress": saved.progress if saved else 0}
		offer.merge(c)
		out.append(offer)
	return out


static func active_contracts(state: Dictionary) -> Array:
	var out := []
	for id in state.world.contracts:
		var c: Dictionary = state.world.contracts[id]
		if c.status == "active":
			var o := c.duplicate()
			o.id = id
			out.append(o)
	return out


# ------------------------------------------------------------------- codex
static func codex_progress(state: Dictionary) -> Dictionary:
	var loc_seen := 0
	for l in state.world.locations.values():
		if l.k != "hidden":
			loc_seen += 1
	var recipes_total := 0
	for it in C.ITEMS.values():
		if it.get("recipe"):
			recipes_total += 1
	var collection_progress := Collections.completeness(state)
	return {"locations": [loc_seen, C.LOCATIONS.size()], "enemies": [state.codex.enemies.size(), World.all_enemy_ids().size()],
		"classes": [state.codex.classes.size(), C.CLASSES.size()], "pets": [state.codex.pets.size(), C.PET_SPECIES.size()],
		"recipes": [state.inventory.recipes.size(), recipes_total], "items": [state.codex.items.size(), C.ITEMS.size()],
		"collections": [int(collection_progress.owned), int(collection_progress.total)],
		"clues": [state.codex.clues.size(), null]}
