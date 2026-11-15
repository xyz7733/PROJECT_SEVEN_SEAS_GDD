class_name SceneProfiles
extends RefCounted
## Read-only, presentation-only art direction. All coordinates are world pixels
## at ground contact; Coast callers convert through Art.uniso themselves.
## Gameplay and saved state remain owned by C and Game, never these profiles.

const PATH := "res://data/scene_profiles.json"
static var _data: Dictionary = {}


static func _load() -> Dictionary:
	if _data.is_empty():
		_data = U.load_json(PATH)
	return _data


static func region(id: String) -> Dictionary:
	return _load().get("regions", {}).get(id, {})


static func location(id: String) -> Dictionary:
	return _load().get("locations", {}).get(id, {})


static func battle(location_id: String, room_id: String) -> Dictionary:
	return _load().get("battleRooms", {}).get(location_id + ":" + room_id, {})


static func point(value: Array) -> Vector2:
	if value.size() < 2:
		return Vector2.ZERO
	return Vector2(float(value[0]), float(value[1]))
