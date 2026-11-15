## Player actions. Every action is one atomic commit: the mutator works on a
## draft copy, validates, and either fails without side effects or returns
## the next state.
class_name Actions
extends RefCounted

const BUILD_LIMIT := {"crew_quarters": 3, "pantry": 3, "cargo_hold": 2}


static func T() -> Dictionary:
	return C.TUNING


static func fail(key: String, params: Dictionary = {}) -> Dictionary:
	return {"ok": false, "reasonKey": key, "reasonParams": params}


static func done(value: Variant = null, save_reason: Variant = null) -> Dictionary:
	return {"ok": true, "value": value, "saveReason": save_reason}


static func note(d: Dictionary, key: String, params: Dictionary = {}) -> void:
	GS.add_log(d, key, params)


static func loc_name(id: String) -> String:
	return "loc." + id + ".name"


static func run(state: Dictionary, kind: String, fn: Callable) -> Dictionary:
	return GS.commit(state, kind, func(d):
		var r = fn.call(d)
		if r is Dictionary and r.get("ok", true) == false:
			return r
		after_change(d)
		return r if r is Dictionary else done())


# ----------------------------------------------------------------- economy
static func has_cost(d: Dictionary, c: Dictionary) -> Variant:
	var inv: Dictionary = d.inventory
	if c.get("gold", 0) and int(inv.gold) < int(c.gold):
		return fail("err.no_gold", {"need": c.gold})
	if c.get("materials", 0) and int(inv.materials) < int(c.materials):
		return fail("err.no_materials", {"need": c.materials})
	if c.get("food", 0) and int(inv.food) < int(c.food):
		return fail("err.no_food", {"need": c.food})
	if c.get("supplies", 0) and int(inv.supplies) < int(c.supplies):
		return fail("err.no_supplies", {"need": c.supplies})
	if c.get("specialty") != null:
		var id: String = c.specialty[0]
		var n: int = c.specialty[1]
		if int(inv.specialties.get(id, 0)) < n:
			return fail("err.no_specialty", {"item": "spec." + id + ".name", "need": n})
	return null


static func pay(d: Dictionary, c: Dictionary) -> Variant:
	var bad = has_cost(d, c)
	if bad != null:
		return bad
	var inv: Dictionary = d.inventory
	inv.gold = int(inv.gold) - int(c.get("gold", 0))
	inv.materials = int(inv.materials) - int(c.get("materials", 0))
	inv.food = int(inv.food) - int(c.get("food", 0))
	inv.supplies = int(inv.supplies) - int(c.get("supplies", 0))
	if c.get("specialty") != null:
		inv.specialties[c.specialty[0]] = int(inv.specialties[c.specialty[0]]) - int(c.specialty[1])
	return null


## Gold and materials found on a voyage are unbanked until the ship docks.
static func gain(d: Dictionary, g: Dictionary) -> void:
	var inv: Dictionary = d.inventory
	var banked: bool = d.voyage == null
	if g.get("gold", 0):
		if banked: inv.gold = int(inv.gold) + int(g.gold)
		else: inv.ledger.gold = int(inv.ledger.gold) + int(g.gold)
	if g.get("materials", 0):
		if banked: inv.materials = int(inv.materials) + int(g.materials)
		else: inv.ledger.materials = int(inv.ledger.materials) + int(g.materials)


static func add_food(d: Dictionary, n: int) -> int:
	var cap := Rules.food_capacity(d)
	var room: int = max(0, cap - int(d.inventory.food))
	var got: int = min(room, n)
	d.inventory.food = int(d.inventory.food) + got
	if got < n:
		note(d, "log.food_overflow", {"n": n - got})
	return got


static func add_supplies(d: Dictionary, n: int) -> int:
	var cap := Rules.supply_capacity(d)
	var got: int = min(max(0, cap - int(d.inventory.supplies)), n)
	d.inventory.supplies = int(d.inventory.supplies) + got
	if got < n:
		note(d, "log.supply_overflow", {"n": n - got})
	return got


static func add_specialty(d: Dictionary, id: String, n: int) -> void:
	d.inventory.specialties[id] = int(d.inventory.specialties.get(id, 0)) + n


static func add_ingredient(d: Dictionary, id: String, n: int) -> void:
	d.inventory.ingredients[id] = int(d.inventory.ingredients.get(id, 0)) + n


static func item_name_key(item_id: String) -> String:
	var it: Dictionary = C.ITEMS[item_id]
	if it.get("nameKey"):
		return it.nameKey
	return "item." + ("w_" + it.wtype if it.get("wtype") else "o_" + it.otype) + ".t" + str(it.tier)


static func add_equipment(d: Dictionary, item_id: String, opts: Dictionary = {}) -> Variant:
	if d.inventory.equipment.size() >= Rules.equip_capacity(d):
		var mats: int = Rules.salvage_value({"itemId": item_id, "reinforce": 0}).materials
		gain(d, {"materials": mats})
		note(d, "log.equip_overflow", {"item": item_name_key(item_id), "n": mats})
		return null
	var inst := {"uid": GS.next_id(d, "eq"), "itemId": item_id, "reinforce": 0, "affix": opts.get("affix")}
	d.inventory.equipment.append(inst)
	d.codex.items[item_id] = true
	var it: Dictionary = C.ITEMS[item_id]
	if it.get("recipe") and not d.inventory.recipes.has(item_id):
		d.inventory.recipes.append(item_id)
	if it.get("unique") and not d.inventory.uniques.has(item_id):
		d.inventory.uniques.append(item_id)
	return inst


static func add_egg(d: Dictionary, family_id: String, grade: int) -> void:
	d.inventory.eggs.append({"id": GS.next_id(d, "egg"), "familyId": family_id, "grade": grade, "inputs": []})
	note(d, "log.egg_found", {"family": "petfam." + family_id + ".name"})


static func add_clue(d: Dictionary, clue_key: String) -> bool:
	if not d.codex.clues.has(clue_key):
		d.codex.clues.append(clue_key)
		note(d, "log.clue", {"clue": clue_key})
		return true
	return false


static func reveal(d: Dictionary, loc_id: String) -> bool:
	var l = d.world.locations.get(loc_id)
	if l and l.k == "hidden":
		l.k = "revealed"
		note(d, "log.revealed", {"location": loc_name(loc_id)})
		return true
	return false


static func advance_clock(d: Dictionary, hours: int) -> void:
	d.envelope.gameClock = int(d.envelope.gameClock) + hours


static func require_port(d: Dictionary) -> Variant:
	if d.encounter != null:
		return fail("err.in_encounter")
	if not Rules.at_port(d):
		return fail("err.need_port")
	return null


static func require_calm(d: Dictionary) -> Variant:
	if d.encounter != null:
		return fail("err.in_encounter")
	if d.voyage != null and d.voyage.event != null:
		return fail("err.event_pending")
	return null


static func here(d: Dictionary) -> String:
	return d.world.currentLocationId


static func here_region(d: Dictionary) -> String:
	return C.location(here(d)).regionId


# ------------------------------------------------------------ after change
static func after_change(d: Dictionary) -> void:
	d.ship.staminaMax = Rules.stamina_max(d)
	if int(d.ship.stamina) > int(d.ship.staminaMax):
		d.ship.stamina = d.ship.staminaMax
	var guard := 0
	while check_main(d) and guard < 6:
		guard += 1
	check_sides(d)
	check_crew_events(d)
	check_tidebound(d)
	for m in d.crew:
		d.codex.classes[m.classId] = true


static func step_done(d: Dictionary, q: Dictionary) -> bool:
	if q.type == "clear":
		return Rules.knowledge(d, q.locationId) == "cleared"
	if q.type == "visit":
		return Rules.is_visited(d, q.locationId)
	if q.type == "trial":
		return d.captain.trialsWon.has(q.regionId)
	return false  # deliveries complete through deliver_main()


static func complete_main(d: Dictionary, q: Dictionary) -> void:
	var rid: String = q.regionId
	d.captain.mainStep[rid] = int(q.step) + 1
	gain(d, {"gold": q.reward.gold})
	grant_xp(d, float(q.reward.xp), true)
	d.captain.reputation.conclave = int(d.captain.reputation.conclave) + int(q.reward.rep)
	for id in q.reveal:
		reveal(d, id)
	note(d, "log.main_done", {"quest": q.titleKey})
	if q.type == "trial":
		var reg: Dictionary = C.region(rid)
		if rid == "leviathan_ring" and not d.inventory.blueprints.has("legend_keel"):
			d.inventory.blueprints.append("legend_keel")
			note(d, "log.blueprint", {"item": "blueprint.legend_keel"})
		if reg.get("nextRegionId") and not d.captain.regionsUnlocked.has(reg.nextRegionId):
			var nx: Dictionary = C.region(reg.nextRegionId)
			d.captain.regionsUnlocked.append(nx.id)
			d.captain.mainStep[nx.id] = 0
			reveal(d, nx.locs[0])
			reveal(d, nx.locs[2])
			note(d, "log.region_unlocked", {"region": "region." + nx.id + ".name"})
		if not reg.get("nextRegionId") and not d.captain.postgame:
			d.captain.postgame = true
			d.captain.titleKey = "title.strongest"
			d.captain.flags.postgameAt = d.envelope.gameClock
			note(d, "log.postgame", {})


static func check_main(d: Dictionary) -> bool:
	for rid in d.captain.regionsUnlocked:
		var step := int(d.captain.mainStep.get(rid, 0))
		var q = C.main_step(rid, step)
		if q != null and step_done(d, q):
			complete_main(d, q)
			return true
	return false


static func check_sides(d: Dictionary) -> void:
	for qid in d.world.quests:
		var st: Dictionary = d.world.quests[qid]
		if st.status != "active":
			continue
		var q: Dictionary = C.QUESTS[qid]
		var ok: bool = Rules.is_visited(d, q.locationId) if q.type == "discover" else Rules.knowledge(d, q.locationId) == "cleared"
		if not ok:
			continue
		st.status = "done"
		var r: Dictionary = C.region(q.regionId)
		gain(d, {"gold": q.reward.gold, "materials": q.reward.materials})
		grant_xp(d, float(q.reward.xp), true)
		d.captain.reputation[q.faction] = int(d.captain.reputation[q.faction]) + int(q.reward.rep)
		if q.rewardKind == "recipe":
			var id := "o_armor_%d" % min(10, int(r.tier) + 1)
			if not d.inventory.recipes.has(id):
				d.inventory.recipes.append(id)
			st.extra = id
		if q.rewardKind == "supplies":
			add_supplies(d, 2)
		if q.rewardKind == "ingredients":
			var ing: String = C.data.INGREDIENT_BY_COLOR[C.pet_family(r.petFamilyId).color]
			add_ingredient(d, ing, 3)
			st.extra = ing
		if q.rewardKind == "clue":
			add_clue(d, "clue.pet." + r.petFamilyId)
		if q.rewardKind == "egg":
			add_egg(d, r.petFamilyId, 2)
		note(d, "log.side_done", {"quest": q.titleKey, "location": loc_name(q.locationId)})


static func origin_region(m: Dictionary) -> String:
	return C.data.REGION_ORDER[C.data.ORIGINS.find(m.originId)]


static func check_crew_events(d: Dictionary) -> void:
	for m in d.crew:
		if m.event.status != "active":
			continue
		var complete := false
		if m.eventId == "homesick":
			complete = Rules.at_port(d) and here_region(d) == origin_region(m) and int(m.event.progress) >= 0 and m.event.get("armed", false)
		if m.eventId == "proving" or m.eventId == "feast":
			complete = int(m.event.progress) >= 5
		if complete:
			finish_crew_event(d, m)


static func finish_crew_event(d: Dictionary, m: Dictionary) -> void:
	var story := Rules.fac_level(d, "story_deck")
	m.event.status = "done"
	var xp := U.jround(40.0 * float(m.level) * (1.0 + 0.5 * story))
	add_member_xp(d, m, float(xp))
	m.mastery[m.classId] = int(m.mastery.get(m.classId, 0)) + 10 + 5 * story
	gain(d, {"gold": 30 + 20 * story})
	note(d, "log.crew_event_done", {"crew": m.id, "event": "event." + m.eventId + ".title"})


static func check_tidebound(d: Dictionary) -> void:
	var rank := Rules.rep_rank(d, "tidebound")
	var got := int(d.captain.flags.get("tideClues", 0))
	if rank > got:
		d.captain.flags.tideClues = rank
		for r in d.captain.regionsUnlocked:
			var fam: String = C.region(r).petFamilyId
			if not d.codex.clues.has("clue.pet." + fam):
				add_clue(d, "clue.pet." + fam)
				break


# ---------------------------------------------------------------------- xp
static func xp_mult(d: Dictionary) -> float:
	return 1.0 + 0.05 * Rules.rep_rank(d, "conclave") + 0.05 * Rules.fac_level(d, "tide_archive") + 0.05 * Rules.fac_level(d, "music_room")


static func add_member_xp(d: Dictionary, m: Dictionary, xp: float) -> void:
	var mods: Dictionary = Rules.member_stats(d, m).mods
	m.xp = int(m.xp) + U.jround(xp * (1.0 + U.num(mods, "xpPct")))
	var cap := int(T().levelCap)
	while int(m.level) < cap and int(m.xp) >= Rules.xp_to_next(int(m.level)):
		m.xp = int(m.xp) - Rules.xp_to_next(int(m.level))
		m.level = int(m.level) + 1
		note(d, "log.level_up", {"crew": m.id, "level": m.level})
		if int(m.level) % Attrs.LEVELS_PER_POINT == 0:
			note(d, "log.train_point", {"crew": m.id})
	if int(m.level) >= cap:
		m.xp = 0


## Formation members get full XP; benched crew learn on the practice deck.
static func grant_xp(d: Dictionary, base: float, include_bench: bool) -> void:
	var k := xp_mult(d)
	var practice := Rules.fac_level(d, "practice_deck")
	for m in d.crew:
		if d.formation.has(m.id):
			add_member_xp(d, m, base * k)
		elif include_bench or practice:
			add_member_xp(d, m, base * k * ((0.3 + 0.15 * practice) if practice else 0.25) * Rules.staff_mult(d, "practice_deck"))


# ============================================================= SHIP EDITOR
static func find_fac(d: Dictionary, uid: Variant) -> Variant:
	for f in d.ship.facilities:
		if f.uid == uid:
			return f
	return null


static func deck_name(d: Dictionary, deck: int) -> String:
	return "deck.%s.name" % d.ship.decks[deck].id


static func build_facility(state: Dictionary, fac_id: String, deck: int, x: int, y: int, rot: int) -> Dictionary:
	return run(state, "ship.build", func(d):
		var bad = require_port(d)
		if bad: return bad
		var def = C.FACILITIES.get(fac_id)
		if not def: return fail("err.unknown")
		if int(d.ship.hullTier) < int(def.minTier): return fail("err.hull_tier", {"tier": def.minTier})
		var count := 0
		for f in d.ship.facilities:
			if f.id == fac_id: count += 1
		if count >= int(BUILD_LIMIT.get(fac_id, 1)): return fail("err.build_limit")
		var r := 1 if rot else 0
		var place := Rules.can_place(d.ship, fac_id, deck, x, y, r, null)
		if not place.ok: return place
		var c = pay(d, def.cost)
		if c: return c
		var f := {"uid": GS.next_id(d, "fac"), "id": fac_id, "deck": deck, "x": x, "y": y, "rot": r, "level": 1, "damaged": false, "stowed": false}
		d.ship.facilities.append(f)
		note(d, "log.built", {"facility": "fac." + fac_id + ".name"})
		return done(f.uid))


static func move_facility(state: Dictionary, uid: String, deck: int, x: int, y: int, rot: int) -> Dictionary:
	return run(state, "ship.move", func(d):
		var bad = require_port(d)
		if bad: return bad
		var f = find_fac(d, uid)
		if f == null: return fail("err.unknown")
		var r := 1 if rot else 0
		var place := Rules.can_place(d.ship, f.id, deck, x, y, r, f.uid)
		if not place.ok: return place
		f.deck = deck; f.x = x; f.y = y; f.rot = r; f.stowed = false
		return done(uid))


static func clear_assignments_for(d: Dictionary, uid: String) -> void:
	for m in d.crew:
		if m.jobFacilityUid == uid:
			m.jobFacilityUid = null
	for p in d.pets:
		if p.assignment != null and p.assignment.kind == "helper" and p.assignment.target == uid:
			p.assignment = null


static func stow_facility(state: Dictionary, uid: String) -> Dictionary:
	return run(state, "ship.stow", func(d):
		var bad = require_port(d)
		if bad: return bad
		var f = find_fac(d, uid)
		if f == null: return fail("err.unknown")
		f.stowed = true
		clear_assignments_for(d, uid)
		return done(uid))


static func demolish_facility(state: Dictionary, uid: String) -> Dictionary:
	return run(state, "ship.demolish", func(d):
		var bad = require_port(d)
		if bad: return bad
		var f = find_fac(d, uid)
		if f == null: return fail("err.unknown")
		if f.id == "captains_cabin": return fail("err.cannot_demolish_cabin")
		var ref := Rules.demolish_refund(f)
		d.inventory.gold = int(d.inventory.gold) + int(ref.gold)
		d.inventory.materials = int(d.inventory.materials) + int(ref.materials)
		if ref.specialty != null:
			add_specialty(d, ref.specialty[0], int(ref.specialty[1]) / 2)
		clear_assignments_for(d, uid)
		d.ship.facilities.erase(f)
		note(d, "log.demolished", {"facility": "fac." + f.id + ".name", "gold": ref.gold, "materials": ref.materials})
		return done(ref))


static func upgrade_facility(state: Dictionary, uid: String) -> Dictionary:
	return run(state, "ship.upgrade", func(d):
		var bad = require_port(d)
		if bad: return bad
		var f = find_fac(d, uid)
		if f == null: return fail("err.unknown")
		if int(f.level) >= 3: return fail("err.max_level")
		if int(f.level) + 1 > int(d.ship.hullTier) + 1: return fail("err.hull_tier", {"tier": f.level})
		var c = pay(d, Rules.upgrade_cost(f))
		if c: return c
		f.level = int(f.level) + 1
		note(d, "log.upgraded", {"facility": "fac." + f.id + ".name", "level": f.level})
		return done(f.level))


static func stair_open(ship: Dictionary, deck: int, x: int, y: int) -> bool:
	if deck < 0 or deck >= ship.decks.size():
		return false
	var dk: Dictionary = ship.decks[deck]
	if Rules.fixed_kind(dk, x, y) != "":
		return false
	if Rules.is_entry(dk, x, y):
		return false
	if Rules.occupancy(ship).has("%d:%d:%d" % [deck, x, y]):
		return false
	return Rules.stair_at(ship, deck, x, y) == null


## A stair is valid while its foot still leads to the recorded landing
## (hatch ladder or terrace stair) and both cells are open.
static func stair_cells_free(ship: Dictionary, s: Dictionary) -> bool:
	var slot = Rules.stair_target(ship, int(s.deck), int(s.x), int(s.y))
	if slot == null or int(slot.to) != int(s.to) or int(slot.ux) != int(s.ux):
		return false
	var occ := Rules.occupancy(ship)
	for e in [[int(s.deck), int(s.x)], [int(s.to), int(s.ux)]]:
		if Rules.fixed_kind(ship.decks[e[0]], e[1], int(s.y)) != "":
			return false
		if occ.has("%d:%d:%d" % [e[0], e[1], int(s.y)]):
			return false
	return true


## Places a stair whose foot is on lower-deck cell (deck, x, y): a hatch
## ladder up to the level above the same column, or a terrace stair up to an
## adjacent raised open deck.
static func place_stair(state: Dictionary, deck: int, x: int, y: int) -> Dictionary:
	return run(state, "ship.stair", func(d):
		var bad = require_port(d)
		if bad: return bad
		var slot = Rules.stair_target(d.ship, deck, x, y)
		if slot == null: return fail("err.no_stair_slot")
		if y < 0 or y >= int(d.ship.decks[deck].h) or y >= int(d.ship.decks[int(slot.to)].h): return fail("err.bad_cell")
		if not stair_open(d.ship, deck, x, y) or not stair_open(d.ship, int(slot.to), int(slot.ux), y): return fail("err.cell_blocked")
		var c = pay(d, C.data.STRUCTURES.stair.cost)
		if c: return c
		d.ship.stairs.append({"deck": deck, "x": x, "y": y, "to": int(slot.to), "ux": int(slot.ux)})
		return done())


static func remove_stair(state: Dictionary, index: int) -> Dictionary:
	return run(state, "ship.unstair", func(d):
		var bad = require_port(d)
		if bad: return bad
		if index < 0 or index >= d.ship.stairs.size(): return fail("err.unknown")
		d.ship.stairs.remove_at(index)
		d.inventory.materials = int(d.inventory.materials) + int(C.data.STRUCTURES.stair.cost.materials) / 2
		return done())


static func toggle_door(state: Dictionary, deck: int, y: int) -> Dictionary:
	return run(state, "ship.door", func(d):
		var bad = require_port(d)
		if bad: return bad
		if deck < 0 or deck >= d.ship.decks.size(): return fail("err.bad_cell")
		var dk: Dictionary = d.ship.decks[deck]
		if dk.bulkhead == null or y <= 0 or y >= int(dk.h) - 1: return fail("err.bad_cell")
		for i in dk.doors.size():
			if int(dk.doors[i][1]) == y:
				dk.doors.remove_at(i)
				return done(false)
		var c = pay(d, C.data.STRUCTURES.door.cost)
		if c: return c
		dk.doors.append([int(dk.bulkhead), y])
		return done(true))


static func save_preset(state: Dictionary, index: int) -> Dictionary:
	return run(state, "ship.preset_save", func(d):
		if index < 0 or index > 2: return fail("err.unknown")
		var facs := []
		for f in d.ship.facilities:
			facs.append({"id": f.id, "deckId": d.ship.decks[int(f.deck)].id, "deck": f.deck, "x": f.x, "y": f.y, "rot": f.rot, "stowed": f.stowed})
		var doors := []
		for dk in d.ship.decks:
			doors.append(dk.doors.duplicate(true))
		var stairs := []
		for st in d.ship.stairs:
			var e: Dictionary = st.duplicate(true)
			e.deckId = d.ship.decks[int(st.deck)].id
			e.toId = d.ship.decks[int(st.to)].id
			stairs.append(e)
		d.ship.presets[index] = {"hullId": d.ship.hullId, "hullTier": d.ship.hullTier, "facilities": facs, "stairs": stairs, "doors": doors}
		return done(index))


## Applies a stored layout to owned facilities; anything that no longer fits is stowed.
static func apply_preset(state: Dictionary, index: int) -> Dictionary:
	return run(state, "ship.preset_apply", func(d):
		var bad = require_port(d)
		if bad: return bad
		if index < 0 or index > 2 or d.ship.presets[index] == null: return fail("err.no_preset")
		var pr: Dictionary = d.ship.presets[index]
		var owned: Array = d.ship.facilities.duplicate()
		for f in owned:
			f.stowed = true
		d.ship.stairs = []
		for i in d.ship.decks.size():
			var dk: Dictionary = d.ship.decks[i]
			if dk.bulkhead != null and i < pr.doors.size():
				var nd := []
				for door in pr.doors[i]:
					if int(door[0]) == int(dk.bulkhead):
						nd.append(door.duplicate())
				dk.doors = nd
		for s in pr.stairs:
			var ns: Variant = remap_stair(d.ship, s)
			if ns != null and Rules.stair_target(d.ship, int(ns.deck), int(ns.x), int(ns.y)) != null:
				d.ship.stairs.append(ns)
		var used := {}
		for p in pr.facilities:
			if p.stowed: continue
			var f = null
			for o in owned:
				if o.id == p.id and not used.has(o.uid):
					f = o
					break
			if f == null: continue
			used[f.uid] = true
			var di := Rules.deck_index(d.ship, String(p.deckId)) if p.has("deckId") else int(p.deck)
			if di >= 0 and Rules.can_place(d.ship, f.id, di, int(p.x), int(p.y), int(p.rot), f.uid).ok:
				f.deck = di; f.x = p.x; f.y = p.y; f.rot = p.rot; f.stowed = false
		d.ship.stairs = d.ship.stairs.filter(func(s): return stair_cells_free(d.ship, s))
		auto_stairs(d)
		for f in owned:
			if f.stowed:
				clear_assignments_for(d, f.uid)
		return done(index))


static func delete_preset(state: Dictionary, index: int) -> Dictionary:
	return run(state, "ship.preset_delete", func(d):
		if index < 0 or index > 2 or d.ship.presets[index] == null: return fail("err.no_preset")
		d.ship.presets[index] = null
		return done())


## Maps a stored stair onto the current decks by deck id. Null if gone.
static func remap_stair(ship: Dictionary, s: Dictionary) -> Variant:
	var e: Dictionary = s.duplicate(true)
	if s.has("deckId"):
		e.deck = Rules.deck_index(ship, String(s.deckId))
		e.to = Rules.deck_index(ship, String(s.toId))
	e.erase("deckId")
	e.erase("toId")
	if int(e.deck) < 0 or int(e.to) < 0 or int(e.deck) >= ship.decks.size() or int(e.to) >= ship.decks.size():
		return null
	return e


static func _has_link(ship: Dictionary, lower: int, upper: int) -> bool:
	for s in ship.stairs:
		if int(s.deck) == lower and int(s.to) == upper:
			return true
	return false


static func _try_stair(d: Dictionary, lower: int, x: int, y: int) -> bool:
	var t = Rules.stair_target(d.ship, lower, x, y)
	if t == null:
		return false
	if not stair_open(d.ship, lower, x, y) or not stair_open(d.ship, int(t.to), int(t.ux), y):
		return false
	d.ship.stairs.append({"deck": lower, "x": x, "y": y, "to": int(t.to), "ux": int(t.ux)})
	return true


## Gives every pair of joinable decks at least one free stair or hatch
## ladder: the hull's default ladder first, then the open cell nearest the
## middle of the shared span and beam.
static func auto_stairs(d: Dictionary) -> void:
	var hull = C.hull(d.ship.hullId)
	if hull != null:
		for ld in hull.get("ladders", []):
			var li := Rules.deck_index(d.ship, String(ld[0]))
			if li < 0:
				continue
			var t = Rules.stair_target(d.ship, li, int(ld[1]), int(ld[2]))
			if t != null and not _has_link(d.ship, li, int(t.to)):
				_try_stair(d, li, int(ld[1]), int(ld[2]))
	for b in Rules.stair_boundaries(d.ship):
		if _has_link(d.ship, int(b.deck), int(b.to)):
			continue
		var h: int = d.ship.decks[int(b.deck)].h
		var ys := [h / 2]
		for k in range(1, h):
			ys.append(h / 2 - k)
			ys.append(h / 2 + k)
		var xs: Array = b.xs.duplicate()
		var mid := float(xs[0] + xs[xs.size() - 1]) / 2.0
		xs.sort_custom(func(p, q): return absf(p - mid) < absf(q - mid))
		# First pass: only cells whose stair can be stepped onto from its
		# low end; second pass: any open cell.
		var placed := false
		for strict in [true, false]:
			for x in xs:
				for y in ys:
					if (y < 1 or y >= h - 1) and h > 2:
						continue
					if strict and not _stair_approach_open(d.ship, int(b.deck), int(x), int(y)):
						continue
					if _try_stair(d, int(b.deck), int(x), int(y)):
						placed = true
						break
				if placed:
					break
			if placed:
				break


## True when an open-deck stair at (x, y) can be entered from its low end:
## the cell before its foot (away from the upper deck) is walkable. Hatch
## ladders between interior levels can be entered from any side.
static func _stair_approach_open(ship: Dictionary, lower: int, x: int, y: int) -> bool:
	var t = Rules.stair_target(ship, lower, x, y)
	if t == null:
		return false
	var lo: Dictionary = ship.decks[lower]
	var up: Dictionary = ship.decks[int(t.to)]
	if not (Rules.is_open_deck(lo) and Rules.is_open_deck(up)):
		return true
	var wx_lo := int(lo.x0) + x
	var wx_up := int(up.x0) + int(t.ux)
	if wx_lo == wx_up:
		return true
	return Rules.walkable(ship, Rules.occupancy(ship), lower, x - signi(wx_up - wx_lo), y)


## Preferred levels for a facility: storage goes low in the hold, everything
## else on the highest interior level first.
static func preferred_decks(ship: Dictionary, fac_id: String) -> Array:
	var levels := Rules.interior_levels(ship)
	var cat := String(C.FACILITIES[fac_id].get("category", ""))
	if cat == "storage":
		levels.reverse()
	return levels


## Re-seats facilities after the deck list changed: each keeps its spot when
## it is still valid for its zone, otherwise it moves to the first free
## spot on a suitable level, otherwise it is stowed. Required facilities go
## first so they get the best rooms. Returns the uids that moved or stowed.
static func reseat_facilities(d: Dictionary) -> Dictionary:
	var moved := []
	var stowed := []
	var active: Array = d.ship.facilities.filter(func(f): return not f.stowed)
	active.sort_custom(func(a, b):
		var ra := 0 if C.FACILITIES[a.id].get("required", false) else 1
		var rb := 0 if C.FACILITIES[b.id].get("required", false) else 1
		return ra < rb)
	for f in active:
		f.stowed = true
	for f in active:
		var di := int(f.deck)
		if di >= 0 and di < d.ship.decks.size() and Rules.can_place(d.ship, f.id, di, int(f.x), int(f.y), int(f.rot), f.uid).ok:
			f.stowed = false
			continue
		var spot = Rules.find_spot(d.ship, f.id, f.uid, preferred_decks(d.ship, f.id))
		if spot == null:
			stowed.append(f.uid)
			clear_assignments_for(d, f.uid)
			continue
		f.deck = spot.deck; f.x = spot.x; f.y = spot.y; f.rot = spot.rot; f.stowed = false
		moved.append(f.uid)
	return {"moved": moved, "stowed": stowed}


static func upgrade_hull(state: Dictionary, hull_id: String) -> Dictionary:
	return run(state, "ship.hull", func(d):
		var bad = require_port(d)
		if bad: return bad
		var hull = C.hull(hull_id)
		if hull == null: return fail("err.unknown")
		var av := Rules.hull_available(d, hull)
		if not av.ok: return av
		var c = pay(d, hull.cost)
		if c: return c
		rebuild_decks(d, hull)
		note(d, "log.hull_upgraded", {"hull": "hull." + hull.id + ".name"})
		return done(hull.id, "save.reason_hull"))


## Replaces the deck list with the hull's levels, carrying facilities,
## doors and stairs over by deck id, then re-seats anything that no longer
## fits and adds the default stairs and hatch ladders.
static func rebuild_decks(d: Dictionary, hull: Dictionary) -> void:
	var old_decks: Array = d.ship.decks
	d.ship.hullId = hull.id
	d.ship.hullTier = hull.tier
	var decks := []
	for hd in hull.decks:
		var nd := GS.make_deck(hd)
		for od in old_decks:
			if od.id == nd.id and od.get("bulkhead") == nd.bulkhead and nd.bulkhead != null:
				nd.doors = od.doors.duplicate(true)
		decks.append(nd)
	var stairs := []
	for s in d.ship.stairs:
		if int(s.deck) < old_decks.size() and int(s.to) < old_decks.size():
			stairs.append({"deckId": old_decks[int(s.deck)].id, "toId": old_decks[int(s.to)].id, "deck": s.deck, "x": s.x, "y": s.y, "to": s.to, "ux": s.ux})
	for f in d.ship.facilities:
		var od = old_decks[int(f.deck)] if int(f.deck) >= 0 and int(f.deck) < old_decks.size() else null
		f.deck = -1
		if od != null:
			for i in decks.size():
				if decks[i].id == od.id:
					f.deck = i
	d.ship.decks = decks
	d.ship.stairs = []
	for s in stairs:
		var ns = remap_stair(d.ship, s)
		if ns != null:
			d.ship.stairs.append(ns)
	# Keep only stairs that still lead somewhere, then seat stairs before rooms.
	var keep := []
	for s in d.ship.stairs:
		var t = Rules.stair_target(d.ship, int(s.deck), int(s.x), int(s.y))
		if t != null and int(t.to) == int(s.to) and int(t.ux) == int(s.ux):
			keep.append(s)
	d.ship.stairs = keep
	var saved_stow := {}
	for f in d.ship.facilities:
		saved_stow[f.uid] = f.stowed
		f.stowed = true
	d.ship.stairs = d.ship.stairs.filter(func(s): return stair_cells_free(d.ship, s))
	auto_stairs(d)
	for f in d.ship.facilities:
		f.stowed = saved_stow[f.uid]
		if int(f.deck) < 0 and not f.stowed:
			f.deck = 0
	reseat_facilities(d)
	d.ship.stairs = d.ship.stairs.filter(func(s): return stair_cells_free(d.ship, s))
	auto_stairs(d)


static func repair_ship(state: Dictionary) -> Dictionary:
	return run(state, "ship.repair", func(d):
		if d.encounter != null: return fail("err.in_encounter")
		var rc := Rules.repair_cost(d)
		if not rc.needed: return fail("err.nothing_to_repair")
		if Rules.at_port(d):
			var c = pay(d, {"gold": rc.gold, "materials": rc.materials})
			if c: return c
		else:
			if not Rules.fac_level(d, "workshop", true): return fail("err.need_workshop")
			var c = pay(d, {"materials": int(ceil(float(rc.materials) * 1.5))})
			if c: return c
		d.ship.damage = 0
		for f in d.ship.facilities:
			f.damaged = false
		advance_clock(d, 2)
		note(d, "log.repaired", {})
		return done())


# ==================================================================== CREW
static func recruit(state: Dictionary, index: int) -> Dictionary:
	return run(state, "crew.recruit", func(d):
		var bad = require_port(d)
		if bad: return bad
		var port_id := here(d)
		var pool := Rules.tavern_pool(d, port_id)
		if index < 0 or index >= pool.size(): return fail("err.unknown")
		var offer: Dictionary = pool[index]
		if offer.hired: return fail("err.already_hired")
		if d.crew.size() >= Rules.crew_capacity(d): return fail("err.over_capacity")
		var c = pay(d, {"gold": offer.cost})
		if c: return c
		var m: Dictionary = offer.member.duplicate(true)
		join_crew(d, m)
		var rot := Rules.rotation(d)
		var tv = d.world.taverns.get(port_id)
		if tv == null or int(tv.rotation) != rot:
			d.world.taverns[port_id] = {"rotation": rot, "hired": [index]}
		else:
			tv.hired.append(index)
		note(d, "log.recruited", {"crew": m.id})
		return done(m.id))


static func dismiss(state: Dictionary, crew_id: String) -> Dictionary:
	return run(state, "crew.dismiss", func(d):
		var bad = require_port(d)
		if bad: return bad
		if d.crew.size() <= 1: return fail("err.last_crew")
		var m = Rules.member(d, crew_id)
		if m == null: return fail("err.unknown")
		d.crew.erase(m)
		for i in 6:
			if d.formation[i] == crew_id:
				d.formation[i] = null
		for p in d.pets:
			if p.assignment != null and p.assignment.kind == "companion" and p.assignment.target == crew_id:
				p.assignment = null
		return done())


static func set_formation(state: Dictionary, slot: int, crew_id: Variant) -> Dictionary:
	return run(state, "crew.formation", func(d):
		var bad = require_calm(d)
		if bad: return bad
		if not Rules.at_port(d) and not Rules.fac_level(d, "muster_deck", true): return fail("err.need_muster")
		if slot < 0 or slot > 5: return fail("err.unknown")
		if crew_id and Rules.member(d, crew_id) == null: return fail("err.unknown")
		var prev = d.formation[slot]
		var from: int = d.formation.find(crew_id) if crew_id else -1
		if from >= 0:
			d.formation[from] = prev
		d.formation[slot] = crew_id if crew_id else null
		var any := false
		for x in d.formation:
			if x != null: any = true
		if not any: return fail("err.empty_formation")
		for p in d.pets:
			if p.assignment != null and p.assignment.kind == "companion" and not d.formation.has(p.assignment.target):
				p.assignment = null
		return done())


static func assign_job(state: Dictionary, crew_id: String, fac_uid: Variant) -> Dictionary:
	return run(state, "crew.job", func(d):
		var bad = require_calm(d)
		if bad: return bad
		var m = Rules.member(d, crew_id)
		if m == null: return fail("err.unknown")
		if fac_uid:
			var f = find_fac(d, fac_uid)
			if f == null: return fail("err.unknown")
			var lay := Rules.layout_of(d)
			if not lay.facilities[f.uid].reachable: return fail("warn.facility_unreachable", {"deck": deck_name(d, int(f.deck))})
			var slots := Rules.job_slots(f)
			if not slots: return fail("err.no_job_slots")
			var used := 0
			for x in d.crew:
				if x.jobFacilityUid == f.uid and x.id != crew_id: used += 1
			if used >= slots: return fail("err.job_full")
		m.jobFacilityUid = fac_uid if fac_uid else null
		return done())


static func change_class(state: Dictionary, crew_id: String, class_id: String) -> Dictionary:
	return run(state, "crew.respec", func(d):
		var bad = require_calm(d)
		if bad: return bad
		if not Rules.at_port(d) and not Rules.fac_level(d, "class_hall"): return fail("err.need_class_hall")
		var m = Rules.member(d, crew_id)
		var cls = C.CLASSES.get(class_id)
		if m == null or cls == null: return fail("err.unknown")
		if m.classId == class_id: return fail("err.same_class")
		if not Rules.qualified_for(m, class_id): return fail("err.not_qualified", {"cls": "class." + str(cls.get("parent")) + ".name"})
		var c = pay(d, Rules.respec_cost(m))
		if c: return c
		var from_id: String = m.classId
		m.classId = class_id
		if not m.mastery.has(class_id):
			m.mastery[class_id] = 0
		m.legacy = m.legacy.filter(func(p): return p != cls.passive)
		var w = Rules.equip_inst(d, m.equipment.weapon)
		if w != null and not Rules.weapon_compatible(class_id, w.itemId):
			m.equipment.weapon = null
			note(d, "log.unequipped", {"crew": m.id, "item": item_name_key(w.itemId)})
		d.codex.classes[class_id] = true
		note(d, "log.respec", {"crew": m.id, "from": "class." + from_id + ".name", "to": "class." + class_id + ".name"})
		return done())


## Spends one of the sailor's training points on an attribute.
static func train_attr(state: Dictionary, crew_id: String, attr: String) -> Dictionary:
	return run(state, "crew.train", func(d):
		var bad = require_calm(d)
		if bad: return bad
		var m = Rules.member(d, crew_id)
		if m == null: return fail("err.unknown")
		var block := Attrs.train_block(m, attr)
		if block != "": return fail(block)
		if not (m.get("train") is Dictionary):
			m.train = {}
		m.train[attr] = int(m.train.get(attr, 0)) + 1
		return done())


## Refunds every training point the sailor has spent, for a fee. Needs a
## port or a Class Hall, like changing class.
static func retrain(state: Dictionary, crew_id: String) -> Dictionary:
	return run(state, "crew.retrain", func(d):
		var bad = require_calm(d)
		if bad: return bad
		if not Rules.at_port(d) and not Rules.fac_level(d, "class_hall"): return fail("err.need_class_hall")
		var m = Rules.member(d, crew_id)
		if m == null: return fail("err.unknown")
		if Attrs.points_spent(m) <= 0: return fail("err.nothing_to_retrain")
		var c = pay(d, Attrs.retrain_cost(m))
		if c: return c
		var n := Attrs.points_spent(m)
		m.train = {}
		note(d, "log.retrained", {"crew": m.id, "n": n})
		return done())


static func set_legacy(state: Dictionary, crew_id: String, slot: int, passive_id: Variant) -> Dictionary:
	return run(state, "crew.legacy", func(d):
		var bad = require_calm(d)
		if bad: return bad
		var m = Rules.member(d, crew_id)
		if m == null or slot < 0 or slot >= int(T().legacySlots): return fail("err.unknown")
		if passive_id:
			if not Rules.legacy_options(m).has(passive_id): return fail("err.not_mastered")
			if m.legacy.has(passive_id) and (slot >= m.legacy.size() or m.legacy[slot] != passive_id): return fail("err.legacy_duplicate")
		var nxt: Array = m.legacy.duplicate()
		while nxt.size() <= slot:
			nxt.append(null)
		nxt[slot] = passive_id if passive_id else null
		var out := []
		for p in nxt:
			if p and out.size() < int(T().legacySlots):
				out.append(p)
		m.legacy = out
		return done())


static func equip(state: Dictionary, crew_id: String, slot: String, eq_uid: Variant) -> Dictionary:
	return run(state, "crew.equip", func(d):
		var bad = require_calm(d)
		if bad: return bad
		var m = Rules.member(d, crew_id)
		if m == null or not slot in ["weapon", "outfit", "accessory"]: return fail("err.unknown")
		if eq_uid:
			var inst = Rules.equip_inst(d, eq_uid)
			if inst == null: return fail("err.unknown")
			var it: Dictionary = C.ITEMS[inst.itemId]
			if it.slot != slot: return fail("err.wrong_slot")
			if not Rules.weapon_compatible(m.classId, inst.itemId): return fail("err.weapon_incompatible", {"cls": "class." + m.classId + ".name"})
			for o in d.crew:
				for s in ["weapon", "outfit", "accessory"]:
					if o.equipment[s] == eq_uid:
						o.equipment[s] = null
		m.equipment[slot] = eq_uid if eq_uid else null
		return done())


static func rename(state: Dictionary, crew_id: String, nickname: String) -> Dictionary:
	return run(state, "crew.rename", func(d):
		var m = Rules.member(d, crew_id)
		if m == null: return fail("err.unknown")
		m.nickname = clean_name(nickname)
		return done())


static func clean_name(text: String) -> Variant:
	var out := ""
	for i in text.length():
		var ch := text.unicode_at(i)
		if ch < 0x20 or ch == 0x3c or ch == 0x3e:
			continue
		out += char(ch)
	out = out.strip_edges().substr(0, 18)
	return out if out != "" else null


static func treat(state: Dictionary, crew_id: String) -> Dictionary:
	return run(state, "crew.treat", func(d):
		if d.encounter != null: return fail("err.in_encounter")
		var m = Rules.member(d, crew_id)
		if m == null: return fail("err.unknown")
		if not m.injured: return fail("err.not_injured")
		if Rules.at_port(d):
			var rr := Rules.fac_level(d, "recovery_room")
			var dy := Rules.day(d)
			var used: int = int(d.captain.flags.get("recoveryUsed", 0)) if d.captain.flags.get("recoveryDay") == dy else 0
			if rr and used < rr:
				d.captain.flags.recoveryDay = dy
				d.captain.flags.recoveryUsed = used + 1
			else:
				var c = pay(d, {"gold": Rules.treat_cost(m).gold})
				if c: return c
		else:
			if not Rules.fac_level(d, "infirmary"): return fail("err.need_infirmary")
			var c = pay(d, {"supplies": 1})
			if c: return c
		m.injured = false
		advance_clock(d, 2)
		note(d, "log.treated", {"crew": m.id})
		return done())


static func crew_event_deliver(state: Dictionary, crew_id: String) -> Dictionary:
	return run(state, "crew.event", func(d):
		var bad = require_port(d)
		if bad: return bad
		var m = Rules.member(d, crew_id)
		if m == null or m.eventId != "collector" or m.event.status != "active": return fail("err.unknown")
		var spec: String = C.region(origin_region(m)).specialtyId
		var c = pay(d, {"specialty": [spec, 1]})
		if c: return c
		finish_crew_event(d, m)
		return done())


# =============================================================== EQUIPMENT
static func buy_item(state: Dictionary, item_id: String) -> Dictionary:
	return run(state, "eq.buy", func(d):
		var bad = require_port(d)
		if bad: return bad
		if not Rules.shop_items(d, here(d)).has(item_id): return fail("err.not_sold")
		if d.inventory.equipment.size() >= Rules.equip_capacity(d): return fail("err.equip_full")
		var c = pay(d, {"gold": Rules.item_price(item_id)})
		if c: return c
		return done(add_equipment(d, item_id).uid))


static func craft_item(state: Dictionary, item_id: String, affix: Variant) -> Dictionary:
	return run(state, "eq.craft", func(d):
		var bad = require_calm(d)
		if bad: return bad
		if not Rules.can_craft_here(d): return fail("err.need_workshop")
		if not d.inventory.recipes.has(item_id): return fail("err.no_recipe")
		if affix and not C.data.AFFIXES.has(affix): return fail("err.unknown")
		if affix and not Rules.can_reinforce_here(d): return fail("err.need_workshop2")
		if d.inventory.equipment.size() >= Rules.equip_capacity(d): return fail("err.equip_full")
		var cost = Rules.craft_cost(item_id, affix, d)
		if cost == null: return fail("err.no_recipe")
		var c = pay(d, cost)
		if c: return c
		advance_clock(d, 1)
		var inst = add_equipment(d, item_id, {"affix": affix if affix else null})
		note(d, "log.crafted", {"item": item_name_key(item_id)})
		return done(inst.uid))


static func reinforce(state: Dictionary, eq_uid: String) -> Dictionary:
	return run(state, "eq.reinforce", func(d):
		var bad = require_calm(d)
		if bad: return bad
		if not Rules.can_reinforce_here(d): return fail("err.need_workshop2")
		var inst = Rules.equip_inst(d, eq_uid)
		if inst == null: return fail("err.unknown")
		if int(inst.get("reinforce", 0)) >= 3: return fail("err.max_level")
		var c = pay(d, Rules.reinforce_cost(inst, d))
		if c: return c
		inst.reinforce = int(inst.get("reinforce", 0)) + 1
		return done(inst.reinforce))


static func is_equipped(d: Dictionary, eq_uid: String) -> bool:
	for m in d.crew:
		for s in m.equipment:
			if m.equipment[s] == eq_uid:
				return true
	return false


static func salvage(state: Dictionary, eq_uid: String) -> Dictionary:
	return run(state, "eq.salvage", func(d):
		var bad = require_calm(d)
		if bad: return bad
		if not Rules.at_port(d) and not Rules.fac_level(d, "material_bench") and not Rules.fac_level(d, "workshop"): return fail("err.need_bench")
		var inst = Rules.equip_inst(d, eq_uid)
		if inst == null: return fail("err.unknown")
		if is_equipped(d, eq_uid): return fail("err.equipped")
		var v := Rules.salvage_value(inst)
		var bench := Rules.fac_level(d, "material_bench")
		var mats := U.jround(float(v.materials) * (1.0 + 0.15 * bench))
		d.inventory.equipment.erase(inst)
		d.inventory.materials = int(d.inventory.materials) + mats
		return done(mats))


# =================================================================== PORTS
static func invest(state: Dictionary, track: String) -> Dictionary:
	return run(state, "port.invest", func(d):
		var bad = require_port(d)
		if bad: return bad
		var port_id := here(d)
		if not C.data.INVESTMENT_TRACKS.has(track): return fail("err.unknown")
		var cost = Rules.invest_cost(d, port_id, track)
		if cost == null: return fail("err.max_level")
		var c = pay(d, cost)
		if c: return c
		d.world.ports[port_id].tracks[track] = cost.level
		d.captain.reputation.league = int(d.captain.reputation.league) + 3
		var reg: Dictionary = C.region(C.PORTS[port_id].regionId)
		if track == "navigation" and int(cost.level) >= 2:
			var a: String = reg.locs[0]
			var b: String = reg.locs[1]
			if Rules.is_visited(d, a) and Rules.is_visited(d, b):
				var k := Rules.route_key(a, b)
				if not d.world.chartedRoutes.has(k):
					d.world.chartedRoutes.append(k)
		if track == "navigation" and int(cost.level) >= 3:
			for i in 9:
				reveal(d, reg.locs[i])
		if track == "quest_board" and int(cost.level) >= 3:
			reveal(d, reg.locs[9])
		note(d, "log.invested", {"port": loc_name(port_id), "track": "track." + track + ".name", "level": cost.level})
		return done(cost.level))


static func buy_goods(state: Dictionary, kind: String, id: Variant, qty: int) -> Dictionary:
	return run(state, "port.buy", func(d):
		var bad = require_port(d)
		if bad: return bad
		var port_id := here(d)
		var n: int = clamp(qty if qty else 1, 1, 99)
		var pr := Rules.prices(d, port_id)
		var m := Rules.port_track(d, port_id, "market")
		var reg: Dictionary = C.region(C.PORTS[port_id].regionId)
		if kind == "food":
			if int(d.inventory.food) + n > Rules.food_capacity(d): return fail("err.food_full")
			var c = pay(d, {"gold": int(pr.food) * n})
			if c: return c
			d.inventory.food = int(d.inventory.food) + n
		elif kind == "supplies":
			if m < 1: return fail("err.market_level", {"level": 1})
			if int(d.inventory.supplies) + n > Rules.supply_capacity(d): return fail("err.supplies_full")
			var c = pay(d, {"gold": int(pr.supplies) * n})
			if c: return c
			d.inventory.supplies = int(d.inventory.supplies) + n
		elif kind == "ingredient":
			if m < 1: return fail("err.market_level", {"level": 1})
			if not C.data.INGREDIENTS.has(id): return fail("err.unknown")
			var c = pay(d, {"gold": int(pr.ingredient) * n})
			if c: return c
			add_ingredient(d, id, n)
		elif kind == "specialty":
			if m < 2: return fail("err.market_level", {"level": 2})
			if id != reg.specialtyId: return fail("err.not_sold")
			var c = pay(d, {"gold": Rules.specialty_buy_price(d, port_id, id) * n})
			if c: return c
			add_specialty(d, id, n)
		elif kind == "egg":
			if m < 3: return fail("err.market_level", {"level": 3})
			var c = pay(d, {"gold": pr.egg})
			if c: return c
			add_egg(d, reg.petFamilyId, 1)
		else:
			return fail("err.unknown")
		return done(n))


static func sell_specialty(state: Dictionary, spec_id: String, qty: int) -> Dictionary:
	return run(state, "port.sell", func(d):
		var bad = require_port(d)
		if bad: return bad
		var n: int = max(1, qty)
		if int(d.inventory.specialties.get(spec_id, 0)) < n: return fail("err.no_specialty", {"item": "spec." + spec_id + ".name", "need": n})
		var price := Rules.specialty_sell_price(d, here(d), spec_id)
		d.inventory.specialties[spec_id] = int(d.inventory.specialties[spec_id]) - n
		d.inventory.gold = int(d.inventory.gold) + price * n
		return done(price * n))


# ============================================================== COLLECTIONS
static func _grant_collectible(d: Dictionary, id: String) -> Dictionary:
	var res := Collections.grant(d, id)
	if bool(res.get("ok", false)) and res.get("revealLocationId") != null:
		reveal(d, String(res.revealLocationId))
	return res


## Returns the regions and tiers whose bestiary rewards are claimable. The
## reward itself is only granted by claim_bestiary_reward.
static func check_bestiary(d: Dictionary) -> Array:
	var out := []
	for r in C.REGIONS:
		for tier in Bestiary.claimable(d, String(r.id)):
			out.append({"regionId": String(r.id), "tier": int(tier)})
	return out


static func claim_bestiary_reward(state: Dictionary, region_id: String, tier: int) -> Dictionary:
	return run(state, "bestiary.claim", func(d):
		var reg = C.region(region_id)
		if reg == null or not (tier == 50 or tier == 100): return fail("err.unknown")
		if not d.captain.has("bestiaryRewards"):
			d.captain.bestiaryRewards = []
		var key := "%s:%d" % [region_id, int(tier)]
		if d.captain.bestiaryRewards.has(key): return fail("err.already_claimed")
		var p := Bestiary.progress(d, region_id)
		if float(p.defeatedRatio) * 100.0 + 0.0001 < float(tier): return fail("err.not_ready")
		d.captain.bestiaryRewards.append(key)
		var t: int = int(reg.tier)
		var gold_reward: int = 60 * t if tier == 50 else 180 * t
		var mat_reward: int = 8 * t if tier == 50 else 24 * t
		var shard_reward: int = 2 if tier == 50 else 6
		var reward := {"gold": gold_reward, "materials": mat_reward, "shards": shard_reward, "collectibleId": null}
		gain(d, {"gold": int(reward.gold), "materials": int(reward.materials)})
		d.inventory.curioShards = int(d.inventory.curioShards) + int(reward.shards)
		if tier == 100:
			var cid := _region_reward_collectible(region_id)
			if cid != "":
				var res := _grant_collectible(d, cid)
				reward.collectibleId = cid
				reward.collectibleNew = bool(res.get("new", false))
				reward.collectibleShards = int(res.get("shards", 0))
		note(d, "log.bestiary_claim", {"region": "region." + region_id + ".name", "pct": int(tier)})
		return done(reward))


static func _region_reward_collectible(region_id: String) -> String:
	var fallback := ""
	for cid in C.COLLECTIBLES:
		var rec: Dictionary = C.COLLECTIBLES[cid]
		if String(rec.get("regionId", "")) != region_id:
			continue
		if String(rec.get("kind", "")) == "lore":
			return String(cid)
		if String(rec.get("kind", "")) == "relic" and fallback == "":
			fallback = String(cid)
	return fallback


static func claim_collection_set(state: Dictionary, set_id: String) -> Dictionary:
	return run(state, "collection.set", func(d):
		if not C.COLLECTION_SETS.has(set_id): return fail("err.unknown")
		if not d.captain.has("collectionSets"):
			d.captain.collectionSets = []
		if d.captain.collectionSets.has(set_id): return fail("err.already_claimed")
		if not Collections.set_complete(d, set_id): return fail("err.set_incomplete")
		d.captain.collectionSets.append(set_id)
		var bonus: Dictionary = C.COLLECTION_SETS[set_id].get("bonus", {})
		var gold := int(bonus.get("gold", 0))
		var materials := int(bonus.get("materials", 0))
		var shards := int(bonus.get("shards", 0))
		if gold or materials:
			gain(d, {"gold": gold, "materials": materials})
		d.inventory.curioShards = int(d.inventory.curioShards) + shards
		var item_id = bonus.get("item")
		if item_id != null and C.ITEMS.has(String(item_id)):
			add_equipment(d, String(item_id))
		note(d, "log.set_claim", {"set": "set." + set_id + ".name"})
		return done({"setId": set_id, "gold": gold, "materials": materials, "shards": shards, "item": item_id}))


static func use_chart(state: Dictionary, chart_id: String) -> Dictionary:
	return run(state, "collection.chart", func(d):
		if not Collections.owns(d, chart_id): return fail("err.no_chart")
		if Collections.kind(chart_id) != "chart": return fail("err.no_chart")
		var rec: Dictionary = C.COLLECTIBLES[chart_id]
		var loc_id := String(rec.get("locationId", ""))
		if loc_id == "" or d.world.currentLocationId != loc_id: return fail("err.chart_wrong_place")
		var inv: Dictionary = d.inventory
		var owned = inv.collectibles.get(chart_id)
		if owned is Dictionary and bool(owned.get("used", false)): return fail("err.chart_used")
		if not (owned is Dictionary):
			inv.collectibles[chart_id] = {"count": 1, "firstAt": int(d.envelope.gameClock), "used": false}
		var rows := Collections.chart_rows(d, chart_id)
		var got := Settle.grant(d, rows, {}, C.location(loc_id))
		var now = inv.collectibles.get(chart_id)
		if now is Dictionary:
			now.used = true
		note(d, "log.chart_used", {"item": Collections.name_key(chart_id)})
		return done({"rows": got.rows, "out": got.out}))


static func buy_curio(state: Dictionary, curio_id: String) -> Dictionary:
	return run(state, "port.curio", func(d):
		var bad = require_port(d)
		if bad: return bad
		var offer = null
		for o in Rules.curio_offers(d, here(d)):
			if String(o.id) == curio_id:
				offer = o
				break
		if offer == null: return fail("err.not_sold")
		if Collections.owns(d, curio_id): return fail("err.already_claimed")
		var c = pay(d, {"gold": int(offer.price)})
		if c: return c
		var res := _grant_collectible(d, curio_id)
		if not bool(res.get("ok", false)): return fail("err.no_collectible")
		note(d, "log.curio_buy", {"item": Collections.name_key(curio_id)})
		return done(res))


static func exchange_curio(state: Dictionary, curio_id: String) -> Dictionary:
	return run(state, "port.curio_exchange", func(d):
		var bad = require_port(d)
		if bad: return bad
		var offer = null
		for o in Rules.curio_exchange(d, here(d)):
			if String(o.id) == curio_id:
				offer = o
				break
		if offer == null: return fail("err.not_sold")
		if Collections.owns(d, curio_id): return fail("err.already_claimed")
		var cost := int(offer.shards)
		if int(d.inventory.get("curioShards", 0)) < cost: return fail("err.no_shards")
		d.inventory.curioShards = int(d.inventory.get("curioShards", 0)) - cost
		var res := _grant_collectible(d, curio_id)
		if not bool(res.get("ok", false)): return fail("err.no_collectible")
		note(d, "log.curio_exchange", {"item": Collections.name_key(curio_id)})
		return done(res))


static func accept_quest(state: Dictionary, qid: String) -> Dictionary:
	return run(state, "port.quest", func(d):
		var bad = require_port(d)
		if bad: return bad
		var q = C.QUESTS.get(qid)
		if q == null or q.kind != "side": return fail("err.unknown")
		if q.giverId != here(d): return fail("err.wrong_port")
		if Rules.port_track(d, here(d), "quest_board") < 1: return fail("err.board_level", {"level": 1})
		if d.world.quests.has(qid): return fail("err.already_accepted")
		d.world.quests[qid] = {"status": "active"}
		if q.type == "discover": reveal(d, q.locationId)
		if q.get("template") != "legend": reveal(d, q.locationId)
		note(d, "log.quest_accepted", {"quest": q.titleKey, "location": loc_name(q.locationId)})
		return done(qid))


static func accept_contract(state: Dictionary, contract_id: String) -> Dictionary:
	return run(state, "port.contract", func(d):
		var bad = require_port(d)
		if bad: return bad
		var offer = null
		for o in Rules.contract_offers(d, here(d)):
			if o.id == contract_id:
				offer = o
		if offer == null: return fail("err.unknown")
		if d.world.contracts.has(contract_id): return fail("err.already_accepted")
		if Rules.active_contracts(d).size() >= 3: return fail("err.contract_limit")
		d.world.contracts[contract_id] = {"status": "active", "progress": 0, "type": offer.type, "portId": offer.portId, "regionId": offer.regionId,
			"need": offer.need, "specialtyId": offer.get("specialtyId"), "reward": offer.reward.duplicate(true)}
		return done(contract_id))


static func complete_contract(state: Dictionary, contract_id: String) -> Dictionary:
	return run(state, "port.contract_done", func(d):
		var bad = require_port(d)
		if bad: return bad
		var c = d.world.contracts.get(contract_id)
		if c == null or c.status != "active": return fail("err.unknown")
		if c.portId != here(d): return fail("err.wrong_port")
		if c.type == "hunt" and int(c.progress) < int(c.need): return fail("err.contract_incomplete", {"have": c.progress, "need": c.need})
		if c.type == "supply":
			var p = pay(d, {"food": c.need})
			if p: return p
		if c.type == "haul":
			var p = pay(d, {"specialty": [c.specialtyId, c.need]})
			if p: return p
		c.status = "done"
		d.inventory.gold = int(d.inventory.gold) + int(c.reward.gold)
		d.inventory.materials = int(d.inventory.materials) + int(c.reward.materials)
		d.captain.reputation.league = int(d.captain.reputation.league) + int(c.reward.rep)
		note(d, "log.contract_done", {"gold": c.reward.gold})
		return done())


static func deliver_main(state: Dictionary) -> Dictionary:
	return run(state, "main.deliver", func(d):
		var bad = require_port(d)
		if bad: return bad
		var ms := Rules.main_status(d)
		if ms.done or ms.quest.type != "deliver": return fail("err.nothing_to_deliver")
		if ms.quest.locationId != here(d): return fail("err.wrong_port")
		var c = pay(d, {"specialty": [ms.quest.itemId, ms.quest.count]})
		if c: return c
		complete_main(d, ms.quest)
		return done())


## Free emergency assistance so a captain can never be soft-locked.
static func emergency_aid(state: Dictionary, kind: String) -> Dictionary:
	return run(state, "port.aid", func(d):
		var bad = require_port(d)
		if bad: return bad
		if not Rules.emergency_needs(d).has(kind): return fail("err.aid_not_needed")
		if kind == "meal":
			d.inventory.food = int(d.inventory.food) + 2
			d.ship.stamina = min(int(d.ship.staminaMax), max(int(d.ship.stamina), 30))
		if kind == "treatment":
			for m in d.crew:
				m.injured = false
		if kind == "repair":
			d.ship.damage = min(int(d.ship.damage), 10)
			for f in d.ship.facilities:
				f.damaged = false
		d.captain.flags.aidCount = int(d.captain.flags.get("aidCount", 0)) + 1
		note(d, "log.aid", {"kind": "aid." + kind})
		return done(kind))


static func dock_work(state: Dictionary) -> Dictionary:
	return run(state, "port.work", func(d):
		var bad = require_port(d)
		if bad: return bad
		if not Rules.recovery_contract_available(d): return fail("err.aid_not_needed")
		var t := Rules.region_tier_of_port(here(d))
		advance_clock(d, 6)
		d.inventory.food = int(d.inventory.food) + 3
		d.inventory.gold = int(d.inventory.gold) + 20 + 5 * t
		note(d, "log.dock_work", {"gold": 20 + 5 * t})
		return done())


static func wait_at_port(state: Dictionary) -> Dictionary:
	return run(state, "port.wait", func(d):
		var bad = require_port(d)
		if bad: return bad
		advance_clock(d, 24)
		note(d, "log.waited", {})
		return done())


# ================================================================= STAMINA
static func serve_ration(state: Dictionary) -> Dictionary:
	return run(state, "stamina.ration", func(d):
		if d.encounter != null: return fail("err.in_encounter")
		if int(d.ship.stamina) >= int(d.ship.staminaMax): return fail("err.stamina_full")
		var c = pay(d, {"food": T().rationFood})
		if c: return c
		var g: int = int(T().rationStamina) + 3 * Rules.fac_level(d, "mess_hall")
		d.ship.stamina = min(int(d.ship.staminaMax), int(d.ship.stamina) + g)
		d.captain.stats.rations = int(d.captain.stats.rations) + 1
		for m in d.crew:
			if m.eventId == "feast" and m.event.status == "active":
				m.event.progress = int(m.event.progress) + 1
		return done(g))


static func use_supply(state: Dictionary) -> Dictionary:
	return run(state, "stamina.supply", func(d):
		if d.encounter != null: return fail("err.in_encounter")
		if int(d.ship.stamina) >= int(d.ship.staminaMax): return fail("err.stamina_full")
		var c = pay(d, {"supplies": 1})
		if c: return c
		var pct := 0.0
		for m in Rules.active_crew(d):
			pct = max(pct, U.num(Rules.member_stats(d, m).mods, "supplyPct"))
		var g := U.jround(float(T().supplyStamina) * (1.0 + pct))
		d.ship.stamina = min(int(d.ship.staminaMax), int(d.ship.stamina) + g)
		return done(g))


static func produce_food(state: Dictionary) -> Dictionary:
	return run(state, "prod.galley", func(d):
		var bad = require_calm(d)
		if bad: return bad
		var L := Rules.fac_level(d, "galley")
		if not L: return fail("err.need_facility", {"facility": "fac.galley.name"})
		var c = pay(d, {"materials": 3})
		if c: return c
		var n := U.jround(float(2 + L) * Rules.staff_mult(d, "galley"))
		var got := add_food(d, n)
		if not got: return fail("err.food_full")
		advance_clock(d, 1)
		return done(got))


static func produce_supplies(state: Dictionary) -> Dictionary:
	return run(state, "prod.workshop", func(d):
		var bad = require_calm(d)
		if bad: return bad
		var L := Rules.fac_level(d, "workshop")
		if not L: return fail("err.need_facility", {"facility": "fac.workshop.name"})
		if int(d.inventory.supplies) >= Rules.supply_capacity(d): return fail("err.supplies_full")
		var c = pay(d, {"materials": 4})
		if c: return c
		var n: int = max(1, int(floor((2.0 if L >= 2 else 1.0) * Rules.staff_mult(d, "workshop"))))
		add_supplies(d, n)
		advance_clock(d, 1)
		return done(n))


# ================================================================== VOYAGE
static func dock(d: Dictionary, port_id: String) -> Dictionary:
	var inv: Dictionary = d.inventory
	var banked := {"gold": int(inv.ledger.gold), "materials": int(inv.ledger.materials)}
	inv.gold = int(inv.gold) + banked.gold
	inv.materials = int(inv.materials) + banked.materials
	inv.ledger = {"gold": 0, "materials": 0}
	var prev = d.world.lastSafePortId
	if prev and prev != port_id:
		var k := Rules.route_key(prev, port_id)
		if not d.world.chartedRoutes.has(k):
			d.world.chartedRoutes.append(k)
	d.world.lastSafePortId = port_id
	d.world.currentLocationId = port_id
	d.voyage = null
	for m in d.crew:
		if m.eventId == "homesick" and m.event.status == "active" and origin_region(m) != C.location(port_id).regionId:
			m.event.armed = true
	if banked.gold or banked.materials:
		note(d, "log.banked", banked)
	return banked


static func arrive(d: Dictionary, to_id: String) -> Variant:
	var loc: Dictionary = C.location(to_id)
	var ls: Dictionary = d.world.locations[to_id]
	var first: bool = ls.k == "hidden" or ls.k == "revealed"
	if first:
		ls.k = "visited"
		ls.firstVisit = true
	d.codex.locations[to_id] = true
	d.captain.regionId = loc.regionId
	d.world.currentLocationId = to_id
	note(d, "log.arrived", {"location": loc_name(to_id)})
	if Rules.fac_level(d, "lookout"):
		for n in C.neighbors(to_id):
			var nl: Dictionary = C.location(n)
			if nl.type != "secret" and nl.regionId == loc.regionId:
				reveal(d, n)
	var ex = Rules.explorer_pet(d)
	if ex != null and first:
		var secret: String = C.region(loc.regionId).locs[9]
		if C.neighbors(to_id).has(secret) and reveal(d, secret):
			note(d, "log.pet_found_secret", {})
		add_pet_xp(d, ex, 6)
	for p in d.pets:
		if p.assignment != null and p.assignment.kind == "helper":
			add_pet_xp(d, p, 3)
	if C.PORTS.has(to_id):
		return dock(d, to_id)
	if d.voyage != null:
		d.voyage.site = {"locationId": to_id, "current": null}
	return null


static func sea_event_for(d: Dictionary, region_id: String) -> Variant:
	if GS.next_float(d) >= Rules.sea_event_chance(d):
		return null
	var w := Rules.sea_weights(d, region_id)
	var total := U.sum_values(w)
	var r := GS.next_float(d) * total
	for k in C.world.SEA_EVENT_KINDS:
		r -= float(w[k])
		if r < 0.0:
			return k
	return "cache"


## Departs for a revealed destination. Food is charged once per leg here.
static func depart(state: Dictionary, to_id: String, opts: Dictionary = {}) -> Dictionary:
	var fast: bool = opts.get("fast", false)
	return run(state, "voyage.fast" if fast else "voyage.depart", func(d):
		var block := Rules.sail_block(d, to_id, fast)
		if block != "": return fail(block)
		var lay := Rules.layout_of(d)
		if Rules.at_port(d) and lay.disabled.size() and not opts.get("confirmed", false):
			return fail("warn.confirm_unreachable", {"n": lay.disabled.size()})
		var from := here(d)
		var leg := Rules.leg_cost(d, from, to_id)
		d.inventory.food = int(d.inventory.food) - int(leg.food)
		advance_clock(d, int(leg.hours))
		d.captain.stats.voyages = int(d.captain.stats.voyages) + 1
		if d.voyage == null:
			d.voyage = {"id": GS.next_id(d, "voy"), "originPortId": from, "at": from, "route": null, "event": null, "site": null}
		d.voyage.route = {"from": from, "to": to_id, "food": leg.food, "hours": leg.hours, "fast": fast}
		d.voyage.site = null
		var to_loc: Dictionary = C.location(to_id)
		var kind = null if fast else sea_event_for(d, to_loc.regionId)
		if kind == "pirate" or kind == "monster":
			var reg: Dictionary = C.region(to_loc.regionId)
			var variant := GS.next_int(d, 0, 999)
			var def := World.sea_encounter(reg.id, kind, variant, max(1, int(to_loc.level)))
			start_encounter(d, def, {"type": "sea", "kind": kind, "toId": to_id, "fromId": from})
			note(d, "log.boarded", {"kind": "sea." + kind + ".title"})
			return done({"event": kind}, "save.reason_battle")
		if kind != null:
			d.voyage.event = {"kind": kind, "regionId": to_loc.regionId, "variant": GS.next_int(d, 0, 999)}
			return done({"event": kind})
		var banked = arrive(d, to_id)
		return done({"arrived": to_id, "banked": banked}, "save.reason_port" if C.PORTS.has(to_id) else null))


static func resolve_sea_event(state: Dictionary, choice: String) -> Dictionary:
	return run(state, "voyage.event", func(d):
		if d.voyage == null or d.voyage.event == null: return fail("err.no_event")
		var ev: Dictionary = d.voyage.event
		var reg: Dictionary = C.region(ev.regionId)
		var t: int = reg.tier
		if ev.kind == "cache":
			add_supplies(d, 1)
			gain(d, {"materials": 5 + 2 * t})
		if ev.kind == "vessel" and choice == "help":
			var c = pay(d, {"food": 2})
			if c: return c
			d.captain.reputation.tidebound = int(d.captain.reputation.tidebound) + 5
			gain(d, {"gold": 20 + 10 * t})
		if ev.kind == "shortcut":
			var hidden := []
			for i in reg.locs.size():
				if i != 9 and d.world.locations[reg.locs[i]].k == "hidden":
					hidden.append(reg.locs[i])
			if hidden.size():
				reveal(d, hidden[int(ev.variant) % hidden.size()])
			d.world.shortcuts[reg.id] = true
		if ev.kind == "weather":
			var nav := false
			for m in Rules.active_crew(d):
				if C.base_class_of(m.classId) == "navigator":
					nav = true
			if not Rules.fac_level(d, "barricade_room") and not nav:
				d.ship.damage = min(100, int(d.ship.damage) + 8)
				advance_clock(d, 2)
				note(d, "log.weather_damage", {})
		if ev.kind == "inspection":
			if choice == "pay":
				var c = pay(d, {"gold": 10 + 5 * t})
				if c: return c
				d.captain.reputation.pennants = int(d.captain.reputation.pennants) + 2
			else:
				advance_clock(d, 6)
		if ev.kind == "clue":
			if not add_clue(d, "clue.pet." + reg.petFamilyId):
				d.captain.reputation.tidebound = int(d.captain.reputation.tidebound) + 3
			if d.codex.clues.has("clue.pet." + reg.petFamilyId):
				reveal(d, reg.locs[9])
		d.voyage.event = null
		var to_id: String = d.voyage.route.to
		var banked = arrive(d, to_id)
		return done({"arrived": to_id, "banked": banked}, "save.reason_port" if C.PORTS.has(to_id) else null))


## Always available safe return; no food, gold, or stamina is required.
static func emergency_return(state: Dictionary) -> Dictionary:
	return run(state, "voyage.return", func(d):
		if d.encounter != null: return fail("err.in_encounter")
		if d.voyage == null: return fail("err.already_docked")
		var port_id: String = d.world.lastSafePortId
		advance_clock(d, 12)
		d.voyage.event = null
		if d.world.locations[port_id].k == "hidden":
			d.world.locations[port_id].k = "visited"
		d.world.currentLocationId = port_id
		d.captain.regionId = C.location(port_id).regionId
		var banked := dock(d, port_id)
		note(d, "log.emergency_return", {"location": loc_name(port_id)})
		return done({"banked": banked}, "save.reason_port"))


# ------------------------------------------------------------------- rooms
## Returns the landing party to the ship without sailing away. Free: no
## stamina, food or time. Cleared rooms stay cleared for the next landing.
static func leave_site(state: Dictionary) -> Dictionary:
	return run(state, "site.leave", func(d):
		var bad = require_calm(d)
		if bad: return bad
		if d.voyage == null: return fail("err.already_docked")
		if d.voyage.site == null: return fail("err.not_at_site")
		d.voyage.site = null
		return done({"aboard": true}))


## Puts the party ashore again at the ship's current island, starting from
## the landing. The mirror of leave_site.
static func land(state: Dictionary) -> Dictionary:
	return run(state, "site.land", func(d):
		var bad = require_calm(d)
		if bad: return bad
		if d.voyage == null: return fail("err.already_docked")
		if d.voyage.site != null: return fail("err.already_ashore")
		var loc_id := here(d)
		if C.PORTS.has(loc_id) or C.rooms(loc_id).is_empty():
			return fail("err.already_docked")
		d.voyage.site = {"locationId": loc_id, "current": null}
		return done({"landed": loc_id}))


static func room_accessible(d: Dictionary, loc_id: String, room_id: String) -> bool:
	var rooms: Array = C.rooms(loc_id)
	var cleared: Array = d.world.locations[loc_id].rooms
	if rooms.size() and rooms[0].id == room_id:
		return true
	for r in rooms:
		if cleared.has(r.id) and r.next.has(room_id):
			return true
	return false


const BATTLE_ROOMS := ["battle", "elite", "boss", "trial"]


static func enter_room(state: Dictionary, room_id: String, opts: Dictionary = {}) -> Dictionary:
	return run(state, "site.room", func(d):
		var bad = require_calm(d)
		if bad: return bad
		var loc_id := here(d)
		var loc: Dictionary = C.location(loc_id)
		if d.voyage == null or d.voyage.site == null or d.voyage.site.locationId != loc_id: return fail("err.not_at_site")
		var rm = C.room(loc_id, room_id)
		if rm == null: return fail("err.unknown")
		if not room_accessible(d, loc_id, room_id): return fail("err.room_locked")
		if rm.get("secret", false) and Rules.explorer_pet(d) == null: return fail("err.need_explorer")
		var cleared: bool = d.world.locations[loc_id].rooms.has(room_id)
		var repeat: bool = cleared and opts.get("repeat", false)
		if cleared and not repeat:
			d.voyage.site.current = room_id
			return done({"moved": true})
		if rm.kind == "trial":
			var ms := int(d.captain.mainStep.get(loc.regionId, 0))
			if ms < 4 and not d.captain.trialsWon.has(loc.regionId): return fail("err.trial_locked")
		if repeat and not BATTLE_ROOMS.has(rm.kind): return fail("err.room_depleted")
		var cost: int = rm.cost
		if int(d.ship.stamina) < cost: return fail("err.no_stamina", {"need": cost, "have": d.ship.stamina})
		d.ship.stamina = int(d.ship.stamina) - cost
		d.voyage.site.current = room_id
		if BATTLE_ROOMS.has(rm.kind):
			var variant := GS.next_int(d, 1, 999) if repeat else 0
			var def := World.encounter_for_state(d, loc_id, room_id, {"variant": variant})
			start_encounter(d, def, {"type": "trial" if rm.kind == "trial" else "room", "locationId": loc_id, "roomId": room_id, "repeat": repeat})
			return done({"encounter": true}, "save.reason_trial" if rm.kind == "trial" else null)
		var rewards := World.room_rewards(loc_id, room_id, true)
		var got := apply_rewards(d, rewards, loc)
		clear_room(d, loc_id, room_id)
		return done({"rewards": got}))


static func start_legend(state: Dictionary) -> Dictionary:
	return run(state, "site.legend", func(d):
		var bad = require_calm(d)
		if bad: return bad
		var loc_id := here(d)
		var loc: Dictionary = C.location(loc_id)
		if not d.captain.postgame: return fail("err.postgame_only")
		if loc.type != "arena" or not C.world.LEGENDS.has(loc.regionId): return fail("err.no_legend")
		if d.voyage == null or d.voyage.site == null: return fail("err.not_at_site")
		var def := World.encounter_for_state(d, loc_id, "trial", {"legend": true})
		if int(d.ship.stamina) < int(def.staminaCost): return fail("err.no_stamina", {"need": def.staminaCost, "have": d.ship.stamina})
		d.ship.stamina = int(d.ship.stamina) - int(def.staminaCost)
		start_encounter(d, def, {"type": "legend", "locationId": loc_id, "roomId": "trial"})
		return done({"encounter": true}, "save.reason_trial"))


static func clear_room(d: Dictionary, loc_id: String, room_id: String) -> void:
	var ls: Dictionary = d.world.locations[loc_id]
	if not ls.rooms.has(room_id):
		ls.rooms.append(room_id)
	var rm = C.room(loc_id, room_id)
	if rm.get("objective", false) and ls.k != "cleared":
		ls.k = "cleared"
		note(d, "log.cleared", {"location": loc_name(loc_id)})


static func crew_mod_max(d: Dictionary, key: String) -> float:
	var v := 0.0
	for m in Rules.active_crew(d):
		v = max(v, U.num(Rules.member_stats(d, m).mods, key))
	return v


static func apply_rewards(d: Dictionary, r: Dictionary, loc: Variant) -> Dictionary:
	var rows := Settle.roll(d, r, loc, func(keys: Array): return GS.pick(d, keys))
	return Settle.grant(d, rows, r, loc).out


# ============================================================== ENCOUNTERS
static func build_allies(d: Dictionary, restriction: Variant) -> Array:
	var allies := []
	for slot in 6:
		var id = d.formation[slot]
		if id == null:
			continue
		var m = Rules.member(d, id)
		if m == null:
			continue
		var stats := Rules.member_stats(d, m)
		var pet = null
		for p in d.pets:
			if p.assignment != null and p.assignment.kind == "companion" and p.assignment.target == m.id:
				pet = p
				break
		var pet_spec = null
		if pet != null and Rules.pet_roles(pet).has("companion"):
			var fam: Dictionary = C.pet_family(pet.familyId)
			pet_spec = {"petId": pet.id, "speciesId": pet.speciesId, "familyId": pet.familyId, "ability": fam.ability,
				"evolved": bool(pet.evolved), "mult": U.round2(Rules.pet_power_mult(pet, m, stats))}
		allies.append({"key": m.id, "classId": m.classId, "level": m.level, "slot": slot, "lane": Rules.lane_of_slot(slot),
			"stats": stats, "pet": pet_spec, "name": m.nickname})
	if restriction == "four_crew":
		allies = allies.slice(0, 4)
	return allies


static func battle_bonuses(d: Dictionary, def: Dictionary) -> Dictionary:
	var b := {"startMeter": 10.0 * Rules.fac_level(d, "muster_deck") * Rules.staff_mult(d, "muster_deck")}
	if def.arena == "boarding":
		b.startMeter += 25.0 * Rules.fac_level(d, "boarding_gate") * Rules.staff_mult(d, "boarding_gate")
		b.boardingTaken = min(0.4, 0.08 * Rules.fac_level(d, "barricade_room") * Rules.staff_mult(d, "barricade_room"))
		b.frontShield = 0.08 * Rules.fac_level(d, "guard_post") * Rules.staff_mult(d, "guard_post")
	b.startMeter = min(80, U.jround(b.startMeter))
	return b


static func start_encounter(d: Dictionary, def: Dictionary, context: Dictionary) -> String:
	var attempt_id := GS.next_id(d, "enc")
	var allies := build_allies(d, def.get("restriction"))
	var sd := GS.next_u32(d)
	var spec := {"allies": allies, "waves": def.waves, "modifiers": def.modifiers, "seed": sd if sd else 1,
		"stance": d.tactics.stance, "priority": d.tactics.priority, "bonuses": battle_bonuses(d, def),
		"retreatSecs": def.retreat.escapeSecs if def.get("retreat") != null else 3}
	d.encounter = {"attemptId": attempt_id, "def": def, "spec": spec, "context": context, "startedAt": d.envelope.gameClock}
	var region_id := str(def.get("regionId", context.get("regionId", "")))
	for w in def.waves:
		for e in w:
			codex_see_enemy(d, String(e.enemyId), region_id)
	return attempt_id


## Marks an enemy as seen in the codex and records the region where it was
## met. Reads from old saves with missing fields without requiring migration.
static func codex_see_enemy(d: Dictionary, enemy_id: String, region_id: String) -> void:
	if not d.codex.has("enemies"):
		d.codex.enemies = {}
	var rec: Dictionary = d.codex.enemies.get(enemy_id, {})
	if not (rec is Dictionary):
		rec = {}
	rec.seen = true
	if not rec.has("defeated"):
		rec.defeated = 0
	if not rec.has("kills"):
		rec.kills = int(rec.defeated)
	if not (rec.get("variants") is Array):
		rec.variants = []
	if not (rec.get("regions") is Array):
		rec.regions = []
	if region_id != "" and not rec.regions.has(region_id):
		rec.regions.append(region_id)
	d.codex.enemies[enemy_id] = rec


## Records one defeated enemy in the codex, including its variant and rare
## status. Summoned units never reach this path (Combat filters them out).
static func codex_defeat_enemy(d: Dictionary, detail: Dictionary, region_id: String) -> void:
	var enemy_id := String(detail.get("enemyId", ""))
	if enemy_id == "":
		return
	codex_see_enemy(d, enemy_id, region_id)
	var rec: Dictionary = d.codex.enemies[enemy_id]
	rec.defeated = int(rec.get("defeated", 0)) + 1
	rec.kills = int(rec.get("kills", rec.get("defeated", 1) - 1)) + 1
	var variant = detail.get("variant")
	if variant != null and String(variant) != "" and not rec.variants.has(String(variant)):
		rec.variants.append(String(variant))
	if bool(detail.get("rare", false)):
		rec.rareSeen = true
	d.codex.enemies[enemy_id] = rec


static func set_tactics(state: Dictionary, stance: Variant, priority: Variant) -> Dictionary:
	return run(state, "tactics", func(d):
		if stance and not C.data.STANCES.has(stance): return fail("err.unknown")
		if priority and not C.data.PRIORITIES.has(priority): return fail("err.unknown")
		if stance: d.tactics.stance = stance
		if priority: d.tactics.priority = priority
		if d.encounter != null:
			d.encounter.spec.stance = d.tactics.stance
			d.encounter.spec.priority = d.tactics.priority
		return done())


static func battle_xp(def: Dictionary) -> float:
	var kind_mult: float = {"battle": 1.0, "elite": 1.25, "boss": 1.6, "trial": 2.0, "boarding": 1.0}.get(def.kind, 1.0)
	var xp := 0.0
	for w in def.waves:
		for e in w:
			xp += 8.0 + 3.0 * float(e.level)
	return xp * kind_mult


static func level_gap_xp(m: Dictionary, lvl: int) -> float:
	var gap := int(m.level) - lvl
	return 1.0 + max(0, -gap) * 0.05 if gap <= 2 else max(0.2, 1.0 - 0.15 * (gap - 2))


static func add_pet_xp(d: Dictionary, p: Dictionary, xp: int) -> void:
	p.xp = int(p.xp) + xp
	while int(p.level) < 30 and int(p.xp) >= Rules.pet_xp_to_next(int(p.level)):
		p.xp = int(p.xp) - Rules.pet_xp_to_next(int(p.level))
		p.level = int(p.level) + 1


const COMMAND_TYPES := ["focus", "stance", "priority", "retreat"]


static func _clean_commands(commands: Array) -> Array:
	var cmds := []
	for c in commands:
		if c is Dictionary and typeof(c.get("tick")) == TYPE_INT and int(c.tick) >= 0 and COMMAND_TYPES.has(c.get("type")):
			cmds.append(c)
	return cmds.slice(0, 400)


## Ends the live battle without granting anything: stores the commands, the
## outcome and the spoils plan on the encounter so the post-battle report
## (and a reload of it) settles exactly this result. Idempotent.
static func end_encounter(state: Dictionary, attempt_id: String, commands: Array) -> Dictionary:
	if state.committed.has(attempt_id):
		return {"ok": true, "state": state, "value": state.committed[attempt_id].outcome, "duplicate": true}
	var enc0 = state.encounter
	if enc0 != null and enc0.attemptId == attempt_id and enc0.get("ended") != null:
		return {"ok": true, "state": state, "value": enc0.ended.outcome, "duplicate": true}
	return run(state, "encounter.end", func(d):
		var enc = d.encounter
		if enc == null or enc.attemptId != attempt_id: return fail("err.no_encounter")
		var cmds := _clean_commands(commands)
		var res := Combat.resolve(enc.spec, cmds)
		enc.ended = {"commands": cmds, "outcome": res.outcome, "plan": Settle.plan(d, enc)}
		return done(res.outcome, "save.reason_battle"))


## The settlement the report shows: the same transaction as the final
## commit, run on a draft that is thrown away. `value` is the summary.
static func preview_encounter(state: Dictionary) -> Dictionary:
	var enc = state.encounter
	if enc == null:
		return fail("err.no_encounter")
	var r := resolve_encounter(state, String(enc.attemptId), [], {"recruit": false})
	r.erase("state")
	return r


## Settles the active encounter in one transaction: outcome, rewards from the
## spoils plan, losses and the recruit decision (`choice.recruit`). The same
## attempt can only commit once; a repeat call (for example after a reload)
## returns the stored result. After end_encounter the stored commands and
## plan are used, so the report and the commit always agree.
static func resolve_encounter(state: Dictionary, attempt_id: String, commands: Array, choice: Dictionary = {}) -> Dictionary:
	if state.committed.has(attempt_id):
		return {"ok": true, "state": state, "value": state.committed[attempt_id], "duplicate": true}
	return run(state, "encounter.resolve", func(d):
		var enc = d.encounter
		if enc == null or enc.attemptId != attempt_id: return fail("err.no_encounter")
		var ended = enc.get("ended")
		var cmds: Array = ended.commands if ended != null else _clean_commands(commands)
		var res := Combat.resolve(enc.spec, cmds)
		var ctx: Dictionary = enc.context
		var def: Dictionary = enc.def
		var hp_vals: Array = res.allyHp.values()
		var hp_avg := U.round2(U.sum_values(res.allyHp) / hp_vals.size()) if hp_vals.size() else 0.0
		var plan: Dictionary = ended.plan if ended != null and ended.get("plan") != null else Settle.plan(d, enc)
		var summary := {"attemptId": attempt_id, "outcome": res.outcome, "reason": res.reason, "time": res.time, "context": ctx,
			"rewards": null, "losses": null, "injured": [], "allyHp": res.allyHp, "hpAvg": hp_avg, "defId": def.id, "kind": def.kind,
			"ledger": [], "plunder": int(res.get("plunder", 0)), "recruit": {}, "spoils": plan.rows}
		var codex_region := str(def.get("regionId", ctx.get("regionId", "")))
		var details: Array = res.get("enemyDetails", [])
		if details.is_empty() and res.enemiesDefeated.size() > 0:
			for id in res.enemiesDefeated:
				details.append({"enemyId": id, "variant": null, "rare": false})
		summary.enemies = details
		for detail in details:
			codex_defeat_enemy(d, detail, codex_region)
		check_bestiary(d)
		var offer := {}
		if res.outcome == "victory":
			offer = Settle.recruit_offer(d, enc)
		d.encounter = null
		if res.outcome == "victory":
			victory(d, def, ctx, res, summary, plan)
			summary.recruit = _settle_recruit(d, offer, bool(choice.get("recruit", false)))
		elif res.outcome == "retreat":
			retreat_outcome(d, ctx, summary)
		else:
			defeat(d, def, ctx, res, summary)
		var kept: Dictionary = summary.duplicate(true)
		if kept.recruit is Dictionary:
			kept.recruit.erase("member")
		GS.record_attempt(d, attempt_id, kept)
		return done(summary, "save.reason_battle"))


## Applies the recruit decision. Returns the offer with accepted / declined
## and, when accepted, the new member's id.
static func _settle_recruit(d: Dictionary, offer: Dictionary, accept: bool) -> Dictionary:
	if offer.is_empty() or not offer.get("offered", false):
		return offer
	var out := offer.duplicate(true)
	out.full = d.crew.size() >= Rules.crew_capacity(d)
	out.accepted = false
	if accept and not out.full:
		var m: Dictionary = out.member.duplicate(true)
		join_crew(d, m)
		out.accepted = true
		out.memberId = m.id
		out.member = m
		note(d, "log.battle_recruit", {"crew": m.id, "enemy": "enemy." + String(out.enemyId) + ".name"})
	return out


## Adds a new member to the crew: id, homesick check, first free formation
## slot and codex. The caller checks capacity.
static func join_crew(d: Dictionary, m: Dictionary) -> void:
	m.id = GS.next_id(d, "crew")
	if m.eventId == "homesick":
		m.event.armed = origin_region(m) != here_region(d)
	d.crew.append(m)
	var free: int = d.formation.find(null)
	if free >= 0:
		d.formation[free] = m.id
	d.codex.classes[m.classId] = true


static func victory(d: Dictionary, def: Dictionary, ctx: Dictionary, res: Dictionary, summary: Dictionary, plan: Dictionary) -> void:
	d.captain.stats.battlesWon = int(d.captain.stats.battlesWon) + 1
	var xp := battle_xp(def)
	var k := xp_mult(d)
	var practice := Rules.fac_level(d, "practice_deck")
	var lvl: int = def.level
	var class_hall := Rules.fac_level(d, "class_hall")
	for m in d.crew:
		if res.allyHp.has(m.id):
			add_member_xp(d, m, xp * k * level_gap_xp(m, lvl))
			var mods: Dictionary = Rules.member_stats(d, m).mods
			var mast := float(T().masteryPerBattle) * (2.0 if def.kind in ["boss", "trial"] else 1.0) * (1.0 + U.num(mods, "masteryPct") + 0.2 * class_hall)
			m.mastery[m.classId] = U.round1(float(m.mastery.get(m.classId, 0)) + mast)
			if m.eventId == "proving" and m.event.status == "active":
				m.event.progress = int(m.event.progress) + 1
		elif practice:
			add_member_xp(d, m, xp * k * (0.3 + 0.15 * practice) * level_gap_xp(m, lvl))
	for p in d.pets:
		if p.assignment != null and p.assignment.kind == "companion" and res.allyHp.has(p.assignment.target):
			add_pet_xp(d, p, U.jround(4.0 + float(def.level)))
	var loc: Dictionary = C.location(ctx.locationId) if ctx.get("locationId") else C.location(ctx.toId)
	var reg: Dictionary = C.region(loc.regionId)
	for c in Rules.active_contracts(d):
		if c.type == "hunt" and c.regionId == reg.id:
			d.world.contracts[c.id].progress = int(d.world.contracts[c.id].progress) + 1
	var got := Settle.grant(d, plan.rows, plan.table, loc)
	var rewards: Dictionary = got.out
	if ctx.type == "sea":
		if ctx.kind == "pirate":
			d.captain.reputation.pennants = int(d.captain.reputation.pennants) + 1
	elif ctx.type == "legend":
		if not d.captain.legendsWon.has(loc.regionId):
			d.captain.legendsWon.append(loc.regionId)
			note(d, "log.legend_won", {"region": "region." + loc.regionId + ".name"})
	else:
		clear_room(d, ctx.locationId, ctx.roomId)
		if ctx.type == "trial" and not d.captain.trialsWon.has(loc.regionId):
			d.captain.trialsWon.append(loc.regionId)
			note(d, "log.trial_won", {"region": "region." + loc.regionId + ".name", "rival": "enemy." + reg.rivalId + ".name"})
	if res.get("plunder", 0):
		gain(d, {"gold": res.plunder})
		rewards.gold = int(rewards.gold) + int(res.plunder)
	summary.rewards = rewards
	summary.ledger = got.rows
	summary.xp = U.jround(xp * k)
	if ctx.type == "sea":
		var banked = arrive(d, ctx.toId)
		summary.arrived = ctx.toId
		summary.banked = banked


static func retreat_outcome(d: Dictionary, ctx: Dictionary, summary: Dictionary) -> void:
	d.captain.stats.retreats = int(d.captain.stats.retreats) + 1
	if ctx.type == "sea":
		var origin: String = ctx.fromId
		d.world.currentLocationId = origin
		if C.PORTS.has(origin):
			dock(d, origin)
		else:
			d.voyage.site = {"locationId": origin, "current": null}
		summary.returnedTo = origin
	note(d, "log.retreated", {})


## Soft failure: permanent progress is kept; unbanked cargo is reduced, some
## crew are injured, and the ship returns to the last safe port.
static func defeat(d: Dictionary, def: Dictionary, ctx: Dictionary, res: Dictionary, summary: Dictionary) -> void:
	d.captain.stats.battlesLost = int(d.captain.stats.battlesLost) + 1
	var inv: Dictionary = d.inventory
	var lost_gold := int(floor(float(inv.ledger.gold) * float(T().defeatLossRate)))
	var lost_mats := int(floor(float(inv.ledger.materials) * float(T().defeatLossRate)))
	inv.ledger.gold = int(inv.ledger.gold) - lost_gold
	inv.ledger.materials = int(inv.ledger.materials) - lost_mats
	var max_inj: int = 1 if Rules.fac_level(d, "infirmary") >= 2 else int(T().maxInjuriesPerDefeat)
	for id in res.koAllies.slice(0, max_inj):
		var m = Rules.member(d, id)
		if m != null:
			m.injured = true
			summary.injured.append(id)
	d.ship.damage = min(100, int(d.ship.damage) + 10)
	var damaged = null
	if def.arena == "boarding":
		var cands := []
		for f in d.ship.facilities:
			if not f.stowed and not f.damaged and f.id != "captains_cabin":
				cands.append(f)
		if cands.size():
			damaged = cands[GS.next_int(d, 0, cands.size() - 1)]
			damaged.damaged = true
	summary.losses = {"gold": lost_gold, "materials": lost_mats, "damagedFacility": damaged.id if damaged != null else null}
	var port_id: String = d.world.lastSafePortId
	advance_clock(d, 12)
	d.world.currentLocationId = port_id
	d.captain.regionId = C.location(port_id).regionId
	if d.voyage == null:
		d.voyage = {"id": GS.next_id(d, "voy"), "originPortId": port_id, "at": port_id, "route": null, "event": null, "site": null}
	dock(d, port_id)
	summary.returnedTo = port_id
	note(d, "log.defeat", {"gold": lost_gold, "materials": lost_mats})


# ==================================================================== PETS
static func find_pet(d: Dictionary, pet_id: String) -> Variant:
	for p in d.pets:
		if p.id == pet_id:
			return p
	return null


static func hatch_egg(state: Dictionary, egg_id: String, inputs: Array) -> Dictionary:
	return run(state, "pet.hatch", func(d):
		var bad = require_calm(d)
		if bad: return bad
		if not Rules.fac_level(d, "hatchery", true): return fail("err.need_facility", {"facility": "fac.hatchery.name"})
		var egg = null
		for e in d.inventory.eggs:
			if e.id == egg_id:
				egg = e
		if egg == null: return fail("err.unknown")
		if inputs.size() < 1 or inputs.size() > 3: return fail("err.hatch_inputs")
		if d.pets.size() >= Rules.pet_capacity(d): return fail("err.pet_full")
		var need := {}
		for inp in inputs:
			if Rules.input_color(inp) == null: return fail("err.hatch_inputs")
			need[inp] = int(need.get(inp, 0)) + 1
		for inp in need:
			var parts: PackedStringArray = inp.split(":")
			var have: int = int(d.inventory.ingredients.get(parts[1], 0)) if parts[0] == "ing" else int(d.inventory.specialties.get(parts[1], 0))
			if have < int(need[inp]): return fail("err.no_input", {"item": ("ing." if parts[0] == "ing" else "spec.") + parts[1] + ".name"})
		for inp in need:
			var parts: PackedStringArray = inp.split(":")
			var bag: Dictionary = d.inventory.ingredients if parts[0] == "ing" else d.inventory.specialties
			bag[parts[1]] = int(bag[parts[1]]) - int(need[inp])
		var out := Rules.hatch_outcome(egg, inputs)
		d.inventory.eggs.erase(egg)
		var pet := {"id": GS.next_id(d, "pet"), "speciesId": out.speciesId, "familyId": out.familyId, "role": out.role, "prime": out.prime,
			"affinity": out.affinity, "level": out.level, "xp": 0, "evolved": false, "assignment": null, "nickname": null, "inputs": inputs.duplicate()}
		d.pets.append(pet)
		d.captain.stats.hatches = int(d.captain.stats.hatches) + 1
		var prev = d.codex.pets.get(out.speciesId)
		d.codex.pets[out.speciesId] = {"prime": bool(prev != null and prev.prime) or out.prime, "seen": true}
		var colors := []
		for i in inputs:
			colors.append(Rules.input_color(i))
		d.codex.hatchLog.push_front({"familyId": out.familyId, "colors": colors, "speciesId": out.speciesId, "prime": out.prime})
		if d.codex.hatchLog.size() > 60:
			d.codex.hatchLog.resize(60)
		note(d, "log.hatched_prime" if out.prime else "log.hatched", {"species": "pet." + out.speciesId + ".name"})
		return done(pet.id))


static func assign_pet(state: Dictionary, pet_id: String, kind: Variant, target: Variant) -> Dictionary:
	return run(state, "pet.assign", func(d):
		var bad = require_calm(d)
		if bad: return bad
		var p = find_pet(d, pet_id)
		if p == null: return fail("err.unknown")
		if not kind:
			p.assignment = null
			return done()
		if not Rules.pet_roles(p).has(kind): return fail("err.pet_role", {"role": "petrole." + kind})
		var tgt = target
		if kind == "companion":
			if not d.formation.has(tgt): return fail("err.pet_owner")
			for o in d.pets:
				if o.id != p.id and o.assignment != null and o.assignment.kind == "companion" and o.assignment.target == tgt:
					o.assignment = null
		elif kind == "helper":
			var f = find_fac(d, tgt)
			if f == null: return fail("err.unknown")
			if not Rules.layout_of(d).facilities[f.uid].reachable: return fail("warn.facility_unreachable", {"deck": deck_name(d, int(f.deck))})
		elif kind == "explorer":
			for o in d.pets:
				if o.id != p.id and o.assignment != null and o.assignment.kind == "explorer":
					o.assignment = null
			tgt = null
		else:
			return fail("err.unknown")
		p.assignment = {"kind": kind, "target": tgt if tgt else null}
		return done())


static func evolve_pet(state: Dictionary, pet_id: String) -> Dictionary:
	return run(state, "pet.evolve", func(d):
		var bad = require_calm(d)
		if bad: return bad
		if not Rules.fac_level(d, "pet_lab"): return fail("err.need_facility", {"facility": "fac.pet_lab.name"})
		var p = find_pet(d, pet_id)
		if p == null: return fail("err.unknown")
		if p.evolved: return fail("err.already_evolved")
		var cost := Rules.evolve_cost(p)
		if int(p.level) < int(cost.level): return fail("err.pet_level", {"level": cost.level})
		var c = pay(d, {"materials": cost.materials, "specialty": cost.specialty})
		if c: return c
		p.evolved = true
		var nxt = C.PET_SPECIES[p.speciesId].get("evolvesTo")
		if nxt:
			p.speciesId = nxt
		d.codex.pets[p.speciesId] = {"prime": p.prime, "seen": true}
		note(d, "log.evolved", {"species": "pet." + p.speciesId + ".name"})
		return done(p.speciesId))


static func rename_pet(state: Dictionary, pet_id: String, nickname: String) -> Dictionary:
	return run(state, "pet.rename", func(d):
		var p = find_pet(d, pet_id)
		if p == null: return fail("err.unknown")
		p.nickname = clean_name(nickname)
		return done())
