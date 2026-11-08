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


func _init() -> void:
	data = U.load_json("res://data/content.json")
	world = U.load_json("res://data/world.json")
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
