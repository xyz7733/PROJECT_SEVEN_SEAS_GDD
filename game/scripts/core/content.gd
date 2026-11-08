## Autoload "C": static game content exported from the reference data.
extends Node

var data: Dictionary = {}
var world: Dictionary = {}

var TUNING: Dictionary
var FACILITIES: Dictionary
var CLASSES: Dictionary
var ITEMS: Dictionary
var SKILLS: Dictionary
var PASSIVES: Dictionary
var HULLS: Array
var PET_SPECIES: Dictionary
var PET_FAMILIES: Array
var REGIONS: Array
var LOCATIONS: Dictionary
var PORTS: Dictionary
var QUESTS: Dictionary
var ROUTES: Array
var REGION_BY_ID: Dictionary = {}
var NEIGHBORS: Dictionary = {}
## Expansion content, merged into the reference data above.
var BESTIARY: Dictionary = {}
var COLLECTIONS: Dictionary = {}
var COLLECTIBLES: Dictionary = {}
var COLLECTION_SETS: Dictionary = {}
var MONSTERS_BY_ID: Dictionary = {}
var MONSTERS_BY_REGION: Dictionary = {}
var RARE_BY_REGION: Dictionary = {}
var SHOP_ITEMS: Array = []
var CURIOS_PER_PORT := 3


func _init() -> void:
	data = U.load_json("res://data/content.json")
	world = U.load_json("res://data/world.json")
	var best: Dictionary = U.load_json("res://data/bestiary.json")
	var coll: Dictionary = U.load_json("res://data/collections.json")
	_merge_dict(data.ENEMY_ARCHETYPES, best.get("ARCHETYPES", {}))
	_merge_dict(data.SKILLS, best.get("SKILLS", {}))
	_merge_dict(data.ITEMS, coll.get("ITEMS", {}))
	_merge_dict(data.INGREDIENTS, coll.get("INGREDIENTS", {}))
	_merge_dict(data.AFFIXES, coll.get("AFFIXES", {}))
	for key in ["battle", "elite", "boss"]:
		if not world.GROUPS.has(key):
			world.GROUPS[key] = []
		_merge_array_unique(world.GROUPS[key], best.get("GROUPS", {}).get(key, []))
	BESTIARY = best
	COLLECTIONS = coll
	COLLECTIBLES = coll.get("COLLECTIBLES", {})
	COLLECTION_SETS = coll.get("SETS", {})
	var shop: Dictionary = coll.get("SHOP", {})
	SHOP_ITEMS = shop.get("items", [])
	CURIOS_PER_PORT = int(shop.get("curiosPerPort", 3))
	for group in ["MONSTERS", "BOSSES", "RARES"]:
		for rec in best.get(group, []):
			var r: Dictionary = rec.duplicate(true)
			r["boss"] = bool(r.get("boss", false)) or group == "BOSSES"
			r["rare"] = bool(r.get("rare", false)) or group == "RARES"
			MONSTERS_BY_ID[r.id] = r
			var rid = r.get("regionId")
			if rid != null:
				if not MONSTERS_BY_REGION.has(rid):
					MONSTERS_BY_REGION[rid] = []
				if not MONSTERS_BY_REGION[rid].has(r.id):
					MONSTERS_BY_REGION[rid].append(r.id)
				if r.rare:
					RARE_BY_REGION[rid] = r.id
	TUNING = data.TUNING
	FACILITIES = data.FACILITIES
	CLASSES = data.CLASSES
	ITEMS = data.ITEMS
	SKILLS = data.SKILLS
	PASSIVES = data.PASSIVES
	HULLS = data.HULLS
	PET_SPECIES = data.PET_SPECIES
	PET_FAMILIES = data.PET_FAMILIES
	REGIONS = world.REGIONS
	LOCATIONS = world.LOCATIONS
	PORTS = world.PORTS
	QUESTS = world.QUESTS
	ROUTES = world.ROUTES
	for r in REGIONS:
		REGION_BY_ID[r.id] = r
	for pair in ROUTES:
		if not NEIGHBORS.has(pair[0]):
			NEIGHBORS[pair[0]] = []
		if not NEIGHBORS.has(pair[1]):
			NEIGHBORS[pair[1]] = []
		NEIGHBORS[pair[0]].append(pair[1])
		NEIGHBORS[pair[1]].append(pair[0])


func _merge_dict(into: Dictionary, extra: Variant) -> void:
	if not (extra is Dictionary):
		return
	for key in extra:
		into[key] = extra[key]


func _merge_array_unique(into: Array, extra: Variant) -> void:
	if not (extra is Array):
		return
	for value in extra:
		if not into.has(value):
			into.append(value)


func k(name: String) -> Variant:
	return data[name]


func hull(id: String) -> Dictionary:
	for h in HULLS:
		if h.id == id:
			return h
	return HULLS[0]


func pet_family(id: String) -> Variant:
	for f in PET_FAMILIES:
		if f.id == id:
			return f
	return null


func base_class_of(id: String) -> String:
	var c = CLASSES.get(id)
	if c and c.parent:
		return c.parent
	return id


func region(id: String) -> Variant:
	return REGION_BY_ID.get(id)


func location(id: String) -> Variant:
	return LOCATIONS.get(id)


func region_of(loc_id: String) -> Variant:
	var l = LOCATIONS.get(loc_id)
	return REGION_BY_ID.get(l.regionId) if l else null


func rooms(loc_id: String) -> Array:
	var l = LOCATIONS.get(loc_id)
	if not l:
		return []
	return world.ROOM_TEMPLATES.get(l.type, [])


func room(loc_id: String, room_id: String) -> Variant:
	for r in rooms(loc_id):
		if r.id == room_id:
			return r
	return null


func neighbors(loc_id: String) -> Array:
	return NEIGHBORS.get(loc_id, [])


func main_step(region_id: String, step: int) -> Variant:
	return QUESTS.get("main.%s.%d" % [region_id, step])


func side_quests(region_id: String) -> Array:
	var out := []
	for q in QUESTS.values():
		if q.kind == "side" and q.regionId == region_id:
			out.append(q)
	return out
