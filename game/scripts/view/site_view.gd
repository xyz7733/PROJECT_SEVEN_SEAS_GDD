## Exploration of a non-port location: an isometric island (or dungeon,
## wreck, hidden sanctum or arena) built from the region's terrain tiles,
## with the location's rooms laid out as a walkable graph. Room markers show
## what waits there (enemies, chests, relics) and whether a room is open,
## locked or cleared. The landing party walks between rooms; entering a room
## goes through Actions.enter_room on arrival.
class_name SiteView
extends Node2D

signal hover_changed(text: String)

const ZOOMS := [0.25, 0.5, 1.0, 2.0, 3.0]
const LANDING := "_landing"
const BATTLE_KINDS := ["battle", "elite", "boss", "trial"]
const KIND_ICON := {"battle": "ui_battle", "elite": "ui_star", "boss": "ui_warn", "trial": "ui_level", "resource": "ui_chest", "event": "ui_quest"}
## [base, trail, pad, beach, cliff side]
const PALETTE := {
	"island": ["", "dirt", "sand1", "sand0", "rock"],
	"dungeon": ["stone1", "floor0", "floor1", "stone0", "dark"],
	"wreck": ["sand0", "plank", "plank", "sand1", "sandside"],
	"secret": ["moss", "flowers", "crystal", "sand0", "rock"],
	"arena": ["stone0", "quay", "quay", "sand0", "stone"],
}
## Coast tile overrides and beach bias per location kind (see Coast.STYLE).
const COAST_STYLE := {
	"island": [0.2, {"trail": "path", "pad": "dirt"}],
	"dungeon": [-0.9, {"alt": "rubble", "trail": "floor0", "pad": "floor1", "dune": "rubble", "side": "rock"}],
	"wreck": [0.9, {"base": "sand0", "alt": "dune", "lush": "grass3", "meadow": "sand1", "trail": "plank", "pad": "sand1", "cliff": "dune",
		"side": "sandside"}],
	"secret": [0.0, {"alt": "moss", "trail": "flowers", "pad": "crystal"}],
	"arena": [-0.4, {"alt": "rubble", "trail": "slab0", "pad": "slab1", "cliff": "rubble", "side": "stone"}],
}
## Props that stand tall (groves) versus ground clutter.
const TALL_PROPS := ["tree", "tree_b", "palm", "dead_tree", "pillar", "pillar_broken", "statue", "crystal", "mushroom"]
const EXTRA_PROPS := {
	"island": [], "dungeon": ["pillar", "pillar_broken", "rock_big", "bones"], "wreck": ["barrels", "crate", "sacks", "barrel"],
	"secret": ["crystal", "mushroom"], "arena": ["statue", "pillar", "flag"],
}
## Where the landing party stands at a room, in screen px from the room
## node: a loose group in two staggered rows left of the room marker, so
## nobody stands straight behind anyone else and every head reads. Slot 0
## is the leader; on a walk the others follow its line in single file.
const PARTY_OFFSETS := [Vector2(-16, 3), Vector2(-36, 1), Vector2(-26, 15), Vector2(-46, 13)]
## The explorer pet's spot, in front beside the leader.
const PET_OFFSET := Vector2(-6, 16)
## Seconds between walkers in single file (about 19 px at walk speed).
const FILE_GAP := 0.3
## Landing-party walk speed on a site, px/s.
const WALK_SPEED := 64.0
## Small side-steps so the walkers in single file do not tread one line.
const FILE_LANE := [0.0, -2.0, 2.0, -1.0, 1.0]

var _info_panel: PanelContainer
var _inset_chips := 40.0
var _inset_bottom := 30.0
var main: Node
var st: Dictionary = {}
var loc_id := ""
var loc: Dictionary = {}
var rid := "dawnwater"
var kind := "island"
var busy := false
var cam: Camera2D
var sea: TileMapLayer
var land_sides: TileMapLayer
var land_low: TileMapLayer
var land_band: TileMapLayer
var land_ground: TileMapLayer
var coast: Coast
var _foam: Node2D
var _blend: Node2D
var _shore_nodes: Array = []
var stage: Node2D
var marks: Node2D
var canvas_mod: CanvasModulate
var ui: CanvasLayer

var _nodes := {}
var _edges := {}
var _room_vis := {}
var _party: Array = []
var _pet: Actor
var _here := LANDING
var _hover := ""
## Party member under the mouse (index into _party) or -1.
var _hover_m := -1
## Whether the pointer is over the moored rowboat (the way back to the ship).
var _hover_boat := false
## Walk generation: a follower's delayed start is dropped once a newer
## walk or placement has been ordered.
var _walk_gen := 0
var _arrive_cb := Callable()
## Where each walker (party member or pet) was last sent.
var _goal := {}
## Idle life per party member: {t, look} (seconds to the next glance and
## whether the member is glancing now).
var _idle: Array = []
var _irng := RandomNumberGenerator.new()
var _t := 0.0
var _zoom_i := 3
var _fit_active := false
var _drag := false
var _drag_moved := 0.0
var _bounds := Rect2()
## The rooms and landing (what fit_view frames); _bounds also covers land.
var _focus := Rect2()
var _gull_stacks: Array = []
## Cells where actors stand or walk (no props there).
var _walk := {}
var _title: Label
var _sub: Label
var _boat_back: RowBoat
# Sea coverage: the sea layer alignment, the area already covered with sea
# tiles, and the flat deep-water underlay.
var _sea_info: Dictionary = {}
var _sea_cover := Rect2()
var _underlay: Polygon2D
var _boat_front: RowBoat
var _berth := Vector2.ZERO
## Ambient life (gulls, glints, cloud shadows, butterflies and fireflies).
var ambience: Ambience
var _meadow: Array = []
## Presentation-only composition. Room identities and links remain in C.
var _profile: Dictionary = {}
var _landmark_at := Vector2.ZERO
var _landmark_foot := Rect2()
var _scenery_reserved := {}


func _init() -> void:
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	sea = TileMapLayer.new()
	sea.z_index = -20
	add_child(sea)
	# Terrain (see Coast): per-face cliff sides, low beach ground (4px up),
	# the top bands of raised faces redrawn over low ground, raised ground
	# (8px up). The surf foam sits between the sea and the sides.
	land_sides = TileMapLayer.new()
	land_sides.z_index = -14
	add_child(land_sides)
	land_low = TileMapLayer.new()
	land_low.z_index = -13
	add_child(land_low)
	land_band = TileMapLayer.new()
	land_band.z_index = -12
	add_child(land_band)
	land_ground = TileMapLayer.new()
	land_ground.z_index = -11
	add_child(land_ground)
	marks = Node2D.new()
	marks.z_index = -4
	add_child(marks)
	stage = Node2D.new()
	stage.y_sort_enabled = true
	add_child(stage)
	ambience = Ambience.new()
	add_child(ambience)
	cam = Camera2D.new()
	cam.zoom = Vector2(2, 2)
	add_child(cam)


func _ready() -> void:
	cam.make_current()
	get_viewport().size_changed.connect(_on_viewport_resized)


## A larger or wider window shows more of the world: add sea tiles if the
## camera could now see past them.
func _on_viewport_resized() -> void:
	if _sea_info.is_empty():
		return
	if _fit_active:
		fit_view()
		return
	if not _sea_cover.encloses(_needed_sea_cover()):
		_fill_sea()
	_clamp_cam()


func _needed_sea_cover() -> Rect2:
	# Build the extra ocean only when the player actually zooms out. Using
	# the smallest overview zoom here would prebuild it for every close-up.
	return Art.camera_cover(_bounds.expand(cam.position), get_viewport_rect().size, cam.zoom.x)


## Sea on every non-land cell the camera can show (a screen-aligned
## rectangle around the camera bounds at the widest zoom), with shallows
## beside land. Cells that already hold a tile are kept.
func _fill_sea() -> void:
	_sea_cover = _needed_sea_cover()
	for c in Art.cells_in_rect(_sea_cover):
		if coast != null and coast.is_land(c):
			continue
		var mc := Art.layer_cell(_sea_info, c.x, c.y)
		if sea.get_cell_source_id(mc) != -1:
			continue
		sea.set_cell(mc, 0, Art.water_tile(coast.water_name(c) if coast != null else "sea"))


# ================================================================ binding
func bind(state: Dictionary) -> void:
	_fit_active = false
	st = state
	loc_id = String(st.world.currentLocationId)
	loc = C.location(loc_id)
	rid = String(loc.regionId)
	kind = String(loc.type) if PALETTE.has(String(loc.type)) else "island"
	_profile = SceneProfiles.location(loc_id)
	_layout_graph()
	_build_terrain()
	_build_rooms()
	_build_party()
	_build_ui()
	refresh()
	_center_current_room()
	_clamp_cam()
	_build_boat()
	var site = st.voyage.site if st.voyage != null else null
	var fresh: bool = site is Dictionary and site.get("current") == null and _here == LANDING
	if fresh and not bool(Settings.get_value("reduceMotion")):
		_row_ashore()


## Re-reads room states after any committed change.
func refresh() -> void:
	if Game.has_game():
		st = Game.state
	if st.voyage == null or st.voyage.site == null:
		return
	var cur = st.voyage.site.current
	var new_here: String = String(cur) if cur != null and _nodes.has(String(cur)) else LANDING
	if new_here != _here and not busy:
		_here = new_here
		_place_party_at(_here)
	for id in _room_vis:
		_update_room(id)
	_update_ui()


func _rooms() -> Array:
	return C.rooms(loc_id)


func _cleared(id: String) -> bool:
	return st.world.locations[loc_id].rooms.has(id)


# ================================================================ layout
## Rooms by depth from the first room; siblings spread vertically. Step,
## spacing, jitter and mirroring vary per location so islands that share a
## room template do not share a layout.
func _layout_graph() -> void:
	_nodes.clear()
	_edges.clear()
	var rooms := _rooms()
	var depth := {}
	if rooms.size():
		depth[rooms[0].id] = 0
		var queue := [rooms[0].id]
		while queue.size():
			var id: String = queue.pop_front()
			var rm = C.room(loc_id, id)
			for n in rm.next:
				if not depth.has(n):
					depth[n] = int(depth[id]) + 1
					queue.append(n)
	var by_depth := {}
	for r in rooms:
		var d := int(depth.get(r.id, 0))
		if not by_depth.has(d):
			by_depth[d] = []
		by_depth[d].append(r.id)
	var max_d := 0
	for d in by_depth:
		max_d = maxi(max_d, int(d))
	var rng := RandomNumberGenerator.new()
	rng.seed = U.hash32("layout:" + loc_id)
	var step := rng.randf_range(124.0, 144.0)
	var spacing := rng.randf_range(84.0, 104.0)
	var flip := -1.0 if rng.randf() < 0.5 else 1.0
	var x0 := -float(max_d) * step * 0.5
	for d in range(max_d + 1):
		var ids: Array = by_depth.get(d, [])
		for k in ids.size():
			var y := (float(k) - float(ids.size() - 1) * 0.5) * spacing * flip
			var jx := rng.randf_range(-14.0, 14.0)
			var jy := rng.randf_range(-10.0, 10.0)
			_nodes[ids[k]] = Vector2(x0 + float(d) * step + jx, y + jy + float(d % 2) * 6.0).round()
	var first: Vector2 = _nodes[rooms[0].id] if rooms.size() else Vector2.ZERO
	_nodes[LANDING] = (first + Vector2(-rng.randf_range(100.0, 118.0), rng.randf_range(4.0, 20.0))).round()
	# The authored compositions replace only display coordinates. Incomplete
	# development profiles still use the seeded positions for missing nodes.
	var authored: Dictionary = _profile.get("nodes", {})
	for id in _nodes:
		if authored.has(id):
			_nodes[id] = SceneProfiles.point(authored[id]).round()
	_prepare_landmark()
	_link(LANDING, rooms[0].id if rooms.size() else LANDING)
	for r in rooms:
		for n in r.next:
			_link(r.id, n)
	var r2 := Rect2(_nodes[LANDING], Vector2.ZERO)
	for id in _nodes:
		r2 = r2.expand(_nodes[id])
	_focus = r2.grow(60)
	_bounds = _focus


func _link(a: String, b: String) -> void:
	if a == b:
		return
	if not _edges.has(a):
		_edges[a] = []
	if not _edges.has(b):
		_edges[b] = []
	if not _edges[a].has(b):
		_edges[a].append(b)
	if not _edges[b].has(a):
		_edges[b].append(a)


func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(0.001, ab.length_squared()), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# ================================================================ terrain
func _build_terrain() -> void:
	var ts := Art.tileset(rid)
	for layer in [sea, land_sides, land_low, land_band, land_ground]:
		layer.tile_set = ts
		layer.clear()
	var info := Art.align_layer(sea)
	for layer in [land_sides, land_low, land_band, land_ground]:
		Art.align_layer(layer)
	land_low.position += Vector2(0, -float(Coast.LIFT[Coast.LOW]))
	land_ground.position += Vector2(0, -float(Coast.LIFT[Coast.HIGH]))
	_sea_info = info
	if _underlay == null:
		_underlay = Art.sea_underlay(rid)
		add_child(_underlay)
	coast = _make_coast()
	coast.paint({"sea": sea, "sides": land_sides, "low": land_low, "band": land_band, "high": land_ground}, info)
	if _foam:
		_foam.queue_free()
	_foam = coast.make_foam()
	add_child(_foam)
	if _blend:
		_blend.queue_free()
	_blend = coast.make_blend(Art.terrain_atlas(rid))
	add_child(_blend)
	# The camera may pan over all of the land, not just the rooms.
	var lr := coast.land_rect()
	var px := Rect2(Art.iso(lr.position.x, lr.position.y), Vector2.ZERO)
	for c in [Vector2(lr.end.x, lr.position.y), Vector2(lr.position.x, lr.end.y), Vector2(lr.end)]:
		px = px.expand(Art.iso(c.x, c.y))
	_bounds = _focus.merge(px.grow(24.0))
	_sea_cover = Rect2()
	_meadow.clear()
	_scenery_reserved.clear()
	_build_profile_scenery()
	_fill_sea()
	_place_props()
	_build_shore_detail()
	_prop("flag", _nodes[LANDING] + Vector2(-10, -18), false)
	_prop("barrels", _nodes[LANDING] + Vector2(14, -14), false)
	_prop("signpost", _nodes[LANDING] + Vector2(18, 10), false)
	# Lighting by location type and hour.
	var hour := int(st.envelope.gameClock) % 24
	var night := hour < 6 or hour >= 19
	var region_profile := SceneProfiles.region(rid)
	var tint := Color.html(String(region_profile.get("light_day", "#fff7e9")))
	match kind:
		"dungeon":
			tint = Color(0.72, 0.69, 0.8)
		"secret":
			tint = tint.lerp(Color(0.8, 0.78, 0.96), 0.55)
	if night and kind != "dungeon":
		tint = tint * Color.html(String(region_profile.get("light_night", "#9eaddb")))
	canvas_mod.color = tint
	# Ambient life: open air over islands, wrecks and arenas; the caves and
	# hidden places keep only their still water and their fireflies.
	var enclosed := kind == "dungeon" or kind == "secret"
	ambience.reset()
	ambience.night = night or enclosed
	ambience.gull_target = 0 if enclosed else 2
	ambience.cloud_alpha = 0.0 if enclosed else 0.1
	ambience.glint_density = 0.5 if enclosed else 1.0
	ambience.fish_every = Vector2(0, 0) if enclosed else Vector2(6.0, 14.0)
	ambience.meadow = _meadow.duplicate()
	ambience.apply_region(rid, enclosed)
	if kind == "dungeon" or kind == "secret" or night:
		for id in _nodes:
			_light(_nodes[id] + Vector2(0, -20), Color.html(String(region_profile.get("warm_light", "#ffcc7a"))), 0.75)


## Scenic foundations stay outside every party route. Their sprites rise
## behind their foot, so ordinary y sorting also keeps actors readable.
func _prepare_landmark() -> void:
	_landmark_foot = Rect2()
	if _profile.is_empty() or not _profile.has("landmarkPosition"):
		return
	_landmark_at = SceneProfiles.point(_profile.landmarkPosition).round()
	var size_v := SceneProfiles.point(_profile.get("landmarkFootprint", [100, 36]))
	var landmark := Art.world_landmark(rid, int(_profile.get("landmarkVariant", 0)))
	var art_foot: Vector2 = landmark.get("footprint", Vector2(144, 64))
	size_v = Vector2(maxf(144.0, maxf(art_foot.x, size_v.x)), maxf(64.0, maxf(art_foot.y, size_v.y)))
	for attempt in 40:
		var foot := Rect2(_landmark_at - size_v * Vector2(0.5, 0.5), size_v)
		var clear := true
		for id in _nodes:
			if foot.grow(34.0).has_point(_nodes[id]):
				clear = false
		for room in _rooms():
			for next_id in room.next:
				var a: Vector2 = _nodes[room.id]
				var b: Vector2 = _nodes[next_id]
				if _seg_dist(_landmark_at, a, b) < size_v.length() * 0.5 + 30.0:
					clear = false
		var rooms := _rooms()
		if not rooms.is_empty() and _seg_dist(_landmark_at, _nodes[LANDING], _nodes[rooms[0].id]) < size_v.length() * 0.5 + 30.0:
			clear = false
		if clear:
			_landmark_foot = foot
			return
		_landmark_at.y -= 16.0


func _build_profile_scenery() -> void:
	if not _landmark_foot.has_area():
		return
	var landmark := Art.world_landmark(rid, int(_profile.get("landmarkVariant", 0)))
	if not landmark.is_empty():
		var s := Sprite2D.new()
		s.name = "LocationLandmark"
		s.centered = false
		s.texture = landmark.tex
		s.offset = -landmark.anchor
		s.position = _landmark_at
		s.set_meta("composition", _profile.get("compositionId", loc_id))
		stage.add_child(s)
		# The explicit Fit action includes the destination's skyline; normal
		# walking still follows the party at its existing close-up scale.
		var scenic_rect := Rect2(_landmark_at - landmark.anchor, landmark.tex.get_size())
		_focus = _focus.merge(scenic_rect.grow(12.0))
		_bounds = _bounds.merge(scenic_rect.grow(20.0))
	for piece in _profile.get("setPieces", []):
		if not (piece is Array) or piece.size() < 4:
			continue
		var p := Vector2(float(piece[1]), float(piece[2]))
		var c := coast.cell_at(p)
		if coast.level(c) < Coast.HIGH or _walk.has(c) or _landmark_foot.grow(12.0).has_point(p):
			continue
		var clear := true
		for id in _nodes:
			if p.distance_to(_nodes[id]) < 58.0:
				clear = false
		for a in _edges:
			for b in _edges[a]:
				if _seg_dist(p, _nodes[a], _nodes[b]) < 30.0:
					clear = false
		if not clear:
			continue
		if _prop(String(piece[0]), p + Vector2(0, 8), bool(piece[3])) != null:
			_scenery_reserved[c] = true
			if String(piece[0]) == "brazier":
				_light(p + Vector2(0, -18), Color.html(String(SceneProfiles.region(rid).get("warm_light", "#ffcc7a"))), 0.65)


## Continuous cell coordinates of the ground under a world point (the
## raised ground is drawn 8px up).
func _gp(p: Vector2) -> Vector2:
	return Art.uniso(p + Vector2(0, 8))


## Screen position of a continuous cell coordinate.
func _px(g: Vector2) -> Vector2:
	return Art.iso(g.x, g.y)


## Where party members and the pet stand relative to a room node.
func _actor_offsets() -> Array:
	var out := PARTY_OFFSETS.duplicate()
	out.append(PET_OFFSET)
	return out


## Slot of walker `i` (party members first, then the pet) at a room.
func _slot(i: int) -> Vector2:
	return PARTY_OFFSETS[i] if i < mini(_party.size(), PARTY_OFFSETS.size()) else PET_OFFSET


## The line walker `i` follows through intermediate rooms: the leader's
## spot with a small side-step.
func _lane(i: int) -> Vector2:
	return PARTY_OFFSETS[0] + Vector2(0, FILE_LANE[i % FILE_LANE.size()])


## Waypoints for walker `i` along `route` (rooms after the current one):
## the file line through every room on the way, then the walker's own slot
## at the last room. The leader keeps to its slot line throughout.
func _walk_points(i: int, route: Array) -> Array:
	var pts := []
	for k in route.size():
		var last := k == route.size() - 1
		var off: Vector2 = _slot(i) if last or i == 0 else _lane(i)
		pts.append([_nodes[String(route[k])] + off, 0.0])
	return pts


func _landing_cell() -> Vector2i:
	var lc := Art.uniso(_nodes[LANDING])
	return Vector2i(roundi(lc.x), roundi(lc.y))


## The jetty's walkable centre line: its root by the landing and its tip.
func _jetty_line() -> Array:
	var lc := _landing_cell()
	return [Art.iso(lc.x - 1, lc.y + 1) + Vector2(0, -8), Art.iso(lc.x - 4, lc.y + 4) + Vector2(0, -8)]


## The island around the room graph: one mass per room and trail, extra
## lobes, coves cut beside trails, a headland with a reef off its tip and
## offshore islets, all seeded by the location. Every place an actor stands
## or walks is forced raised land; the jetty is built; the boat lane and the
## water around the jetty are forced open.
func _make_coast() -> Coast:
	var cs := Coast.new()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for id in _nodes:
		var g := _gp(_nodes[id])
		lo = Vector2(minf(lo.x, g.x), minf(lo.y, g.y))
		hi = Vector2(maxf(hi.x, g.x), maxf(hi.y, g.y))
	if _landmark_foot.has_area():
		for p in [_landmark_foot.position, _landmark_foot.end]:
			var g := _gp(p)
			lo = Vector2(minf(lo.x, g.x), minf(lo.y, g.y))
			hi = Vector2(maxf(hi.x, g.x), maxf(hi.y, g.y))
	var rect := Rect2i(Vector2i(floori(lo.x) - 18, floori(lo.y) - 18), Vector2i(ceili(hi.x - lo.x) + 37, ceili(hi.y - lo.y) + 37))
	cs.setup(rect, U.hash32("coast:" + loc_id))
	cs.use_region(rid)
	var cfg: Array = COAST_STYLE.get(kind, COAST_STYLE.island)
	cs.beach_bias = float(cfg[0])
	for k in cfg[1]:
		cs.style[k] = cfg[1][k]
	var rng := RandomNumberGenerator.new()
	rng.seed = U.hash32("coastshape:" + loc_id)
	var land_px: Vector2 = _nodes[LANDING]
	var land_g := _gp(land_px)
	var rooms := []
	var centre := Vector2.ZERO
	for id in _nodes:
		if id != LANDING:
			rooms.append(id)
			centre += _gp(_nodes[id])
	centre /= maxf(1.0, float(rooms.size()))
	# masses
	var node_r := {}
	for id in rooms:
		node_r[id] = rng.randf_range(4.2, 5.6)
		cs.add_disk(_gp(_nodes[id]), node_r[id])
	cs.add_disk(land_g + Vector2(1, -1).normalized() * 1.2, 2.6)
	var edges := []
	for a in _edges:
		for b in _edges[a]:
			if String(a) < String(b):
				edges.append([a, b])
	for e in edges:
		var landing_edge: bool = e[0] == LANDING or e[1] == LANDING
		cs.add_capsule(_gp(_nodes[e[0]]), _gp(_nodes[e[1]]), 2.4 if landing_edge else rng.randf_range(3.0, 4.0))
	var lobes := rng.randi_range(3, 5)
	for k in lobes:
		if rooms.is_empty():
			break
		var id: String = rooms[rng.randi() % rooms.size()]
		var c: Vector2 = _gp(_nodes[id]) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(3.5, 6.5)
		var r := rng.randf_range(2.4, 3.8)
		if _clear_of_lane(c, r):
			cs.add_disk(c, r)
	# coves beside trails between rooms
	var room_edges := []
	for e in edges:
		if e[0] != LANDING and e[1] != LANDING:
			room_edges.append(e)
	var coves := rng.randi_range(1, 2)
	for k in coves:
		if room_edges.is_empty():
			break
		var e: Array = room_edges[rng.randi() % room_edges.size()]
		var a := _gp(_nodes[e[0]])
		var b := _gp(_nodes[e[1]])
		var nrm := (b - a).orthogonal().normalized()
		if nrm == Vector2.ZERO:
			nrm = Vector2(1, 1).normalized()
		var sgn := -1.0 if rng.randf() < 0.5 else 1.0
		var c2: Vector2 = a.lerp(b, rng.randf_range(0.35, 0.65)) + nrm * sgn * rng.randf_range(5.2, 6.4)
		cs.cut_disk(c2, rng.randf_range(2.0, 3.0))
	# a sheltered bay at the landing: a spit above the jetty, sometimes
	if rng.randf() < 0.55:
		cs.add_capsule(_gp(land_px + Vector2(24, -46)), _gp(land_px + Vector2(-96, -58)), rng.randf_range(1.2, 1.6))
	# headland from the outermost room, with a reef off its tip
	var far_id := ""
	var far_d := -1.0
	for id in rooms:
		var g := _gp(_nodes[id])
		var dd := g.distance_to(centre) + rng.randf() * 0.8
		var dir := (g - centre).normalized() if g.distance_to(centre) > 0.5 else Vector2(1, -1).normalized()
		if dd > far_d and _clear_of_lane(g + dir * 6.0, 1.5):
			far_d = dd
			far_id = id
	if far_id != "":
		var g := _gp(_nodes[far_id])
		var dir := (g - centre).normalized() if g.distance_to(centre) > 0.5 else Vector2(1, -1).normalized()
		dir = dir.rotated(rng.randf_range(-0.6, 0.6))
		var tip: Vector2 = g + dir * (float(node_r[far_id]) + rng.randf_range(3.5, 6.0))
		if _clear_of_lane(tip, 2.0):
			cs.add_capsule(g, tip, rng.randf_range(1.2, 1.7))
			cs.add_reef(tip + dir * 1.8, rng.randf_range(1.8, 2.6))
	# offshore islets
	var islets := 1 + (1 if rng.randf() < 0.4 else 0)
	for k in islets:
		if rooms.is_empty():
			break
		for attempt in 6:
			var id: String = rooms[rng.randi() % rooms.size()]
			var dir := Vector2.from_angle(rng.randf() * TAU)
			var c3: Vector2 = _gp(_nodes[id]) + dir * rng.randf_range(9.0, 11.0)
			var r3 := rng.randf_range(1.9, 2.6)
			var ok := _clear_of_lane(c3, r3 + 1.0)
			for id2 in _nodes:
				ok = ok and _gp(_nodes[id2]).distance_to(c3) >= 8.5
			if ok:
				cs.add_disk(c3, r3)
				if rng.randf() < 0.45:
					cs.add_reef(c3 + dir * 1.2, r3 + 1.6)
				break
	_gull_stacks = []
	if loc_id == "gull_rock":
		_author_gull_rock(cs, centre)
	# Authored coastline accents precede the protected walk core below.
	var authored_coast: Dictionary = _profile.get("coast", {})
	for shape in authored_coast.get("lobes", []):
		if shape is Array and shape.size() >= 3:
			var cg := _gp(Vector2(float(shape[0]), float(shape[1])))
			if _clear_of_lane(cg, float(shape[2])):
				cs.add_disk(cg, float(shape[2]))
	for shape in authored_coast.get("cuts", []):
		if shape is Array and shape.size() >= 3:
			cs.cut_disk(_gp(Vector2(float(shape[0]), float(shape[1]))), float(shape[2]))
	if _landmark_foot.has_area():
		cs.add_disk(_gp(_landmark_at), 4.0)
		for y in range(cs.rect.position.y, cs.rect.end.y):
			for x in range(cs.rect.position.x, cs.rect.end.x):
				if _landmark_foot.grow(8.0).has_point(Art.iso(x, y) - Vector2(0, 8)):
					cs.force_land(Vector2i(x, y))
	# the jetty, its flanks and the boat lane
	var lc := _landing_cell()
	for k in range(1, 5):
		cs.build(lc + Vector2i(-k, k), "plank", "wood")
		cs.force_water(lc + Vector2i(-k - 1, k))
		if k >= 2:
			cs.force_water(lc + Vector2i(-k, k + 1))
	cs.force_water(lc + Vector2i(-5, 5))
	var berth := _boat_berth()
	var lane := Rect2(berth.x - 250.0, berth.y - 12.0, 276.0, 32.0)
	for i in cs.lvl.size():
		var c4 := cs.cell_of(i)
		if lane.has_point(Art.iso(c4.x, c4.y)):
			cs.force_water(c4)
	# walkable core: room pads, trails, every party offset and the walk off
	# the jetty
	var offs := _actor_offsets()
	_walk.clear()
	var tn := FastNoiseLite.new()
	tn.seed = U.hash32("trail:" + loc_id)
	tn.frequency = 0.35
	for id in _nodes:
		var g := _gp(_nodes[id])
		_force_segment(cs, g, g, 2.0, "", 0.0)
		for o in offs:
			_force_segment(cs, _gp(_nodes[id] + o), _gp(_nodes[id] + o), 1.0, "", 0.75)
		if id != LANDING:
			_paint_worn(cs, g, g, 0.9, String(cs.style.pad), tn)
	var mid := Vector2(-14, 3)
	for e in edges:
		var pa: Vector2 = _nodes[e[0]]
		var pb: Vector2 = _nodes[e[1]]
		_force_segment(cs, _gp(pa), _gp(pb), 1.6, "", 0.0)
		for o in offs:
			_force_segment(cs, _gp(pa + o), _gp(pb + o), 0.9, "", 0.75)
		# the file legs: from a spot onto a lane of the leader's line, along
		# it, and back off it at the far end (either direction)
		for k in FILE_LANE.size():
			var ln := _lane(k)
			_force_segment(cs, _gp(pa + ln), _gp(pb + ln), 0.9, "", 0.75)
			for o in offs:
				_force_segment(cs, _gp(pa + o), _gp(pb + ln), 0.9, "", 0.75)
				_force_segment(cs, _gp(pa + ln), _gp(pb + o), 0.9, "", 0.75)
		_paint_worn(cs, _gp(pa + mid), _gp(pb + mid), 0.55, String(cs.style.trail), tn)
	var jl := _jetty_line()
	for o in offs:
		_force_segment(cs, _gp(jl[0]), _gp(land_px + o), 0.8, "", 0.75)
	cs.generate()
	for g in _gull_stacks:
		if not cs.is_land(Vector2i(roundi(g.x), roundi(g.y))):
			cs.rocks.append([g, "sea_stack"])
	return cs


## True when a shape at cell position `g` of radius `r` cells stays to the
## right of the landing, away from the jetty and the boat lane.
func _clear_of_lane(g: Vector2, r: float) -> bool:
	return _px(g).x - r * 22.6 > float(_nodes[LANDING].x) - 8.0


## Gull Rock: a cliff-girt rock with a sheltered landing cove, a long
## headland to the north-east and a cluster of sea stacks over a reef.
func _author_gull_rock(cs: Coast, centre: Vector2) -> void:
	cs.beach_bias = -1.3
	cs.warp_amp = 1.8
	cs.style.dune = "cliff"
	var tip := centre + Vector2(3.5, -11.0)
	cs.add_capsule(centre + Vector2(1.0, -3.0), tip, 1.8)
	cs.add_disk(tip, 2.2)
	cs.add_reef(tip + Vector2(1.5, -3.5), 3.2)
	cs.cut_disk(centre + Vector2(-5.5, -6.5), 2.6)
	_gull_stacks = [tip + Vector2(1.0, -4.2), tip + Vector2(3.2, -3.0), tip + Vector2(-0.8, -5.6)]


## Forces raised land within `r` cells of the segment a-b (a disk when
## a == b); cells within `walk_r` are where actors stand or walk and stay
## free of props.
func _force_segment(cs: Coast, a: Vector2, b: Vector2, r: float, paint: String, walk_r: float) -> void:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(r, r)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(r, r)
	for y in range(floori(lo.y), ceili(hi.y) + 1):
		for x in range(floori(lo.x), ceili(hi.x) + 1):
			var c := Vector2i(x, y)
			var d := _seg_dist(Vector2(c), a, b)
			if d <= r and not cs.is_built(c):
				cs.force_land(c, paint)
				if d <= walk_r:
					_walk[c] = true


## A worn trail or clearing: about `w` cells either side of a-b with a
## ragged noisy edge, painted on land that is already forced.
func _paint_worn(cs: Coast, a: Vector2, b: Vector2, w: float, paint: String, tn: FastNoiseLite) -> void:
	var r := w + 0.4
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(r, r)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(r, r)
	for y in range(floori(lo.y), ceili(hi.y) + 1):
		for x in range(floori(lo.x), ceili(hi.x) + 1):
			var c := Vector2i(x, y)
			if cs.is_built(c):
				continue
			if _seg_dist(Vector2(c), a, b) <= w + 0.28 * tn.get_noise_2d(float(x), float(y)):
				cs.force_land(c, paint)


## Groves where a slow noise is high, palms on the edge of the beach,
## driftwood, grass tufts and reeds on the shore, rocks in the surf. Nothing
## where actors stand or walk, on trails or clearings, and nothing tall just
## in front of a walked cell.
func _place_props() -> void:
	var kind_props: Array = EXTRA_PROPS[kind]
	var pool: Array = Art.env.regionProps.get(rid, ["rock", "bush"])
	if kind == "dungeon" or kind == "arena":
		pool = pool.filter(func(n): return n != "palm")
	pool = pool + kind_props
	var tall := []
	var small := []
	for n in pool:
		if TALL_PROPS.has(n):
			tall.append(n)
		else:
			small.append(n)
	if tall.is_empty():
		tall = small
	if small.is_empty():
		small = tall
	var has_palm := pool.has("palm")
	var shore_ok := kind != "dungeon"
	var gn := FastNoiseLite.new()
	gn.seed = U.hash32("grove:" + loc_id)
	gn.frequency = 0.15
	var behind: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-2, -1), Vector2i(-1, -2),
		Vector2i(-2, -2), Vector2i(-2, 0), Vector2i(0, -2)]
	var placed := 0
	var salt := U.hash32("prop:" + loc_id)
	for i in coast.lvl.size():
		if placed >= 170:
			break
		var c := coast.cell_of(i)
		var l := coast.level(c)
		if l == Coast.WATER or coast.is_built(c) or _walk.has(c) or coast.paint_names.has(c) or _scenery_reserved.has(c):
			continue
		var ground_point := Art.iso(c.x, c.y) + Vector2(0, -coast.lift(c))
		if _landmark_foot.has_area() and _landmark_foot.grow(24.0).has_point(ground_point):
			continue
		var h := Coast.ihash(c.x, c.y, salt) % 1000
		var at := Art.iso(c.x, c.y) + Vector2(float(h % 7) - 3.0, float((h / 7) % 5) - 2.0)
		var low_n := 0
		var wet_n := 0
		for o in Coast.N4:
			var lv := coast.level(c + o)
			if lv == Coast.LOW:
				low_n += 1
			elif lv == Coast.WATER:
				wet_n += 1
		var shades := false
		for k in behind:
			if _walk.has(c + k):
				shades = true
				break
		var name := ""
		var near_room := INF
		for id in _nodes:
			if id != LANDING:
				near_room = minf(near_room, Vector2(c).distance_to(_gp(_nodes[id])))
		if l == Coast.HIGH:
			var gv := gn.get_noise_2d(float(c.x), float(c.y))
			if kind_props.size() and near_room <= 6.0 and h < 200 and not shades:
				name = kind_props[h % kind_props.size()]
			elif gv > 0.05 and h < (380 if kind == "dungeon" or kind == "arena" else 520) and not shades:
				name = tall[h % tall.size()]
			elif has_palm and low_n > 0 and h < 110 and not shades:
				name = "palm"
			elif gv > -0.15 and h < 110:
				name = small[h % small.size()]
			elif h < 40:
				name = small[h % small.size()]
			elif shore_ok and h > 940:
				name = "tuft"
		elif shore_ok:
			if wet_n > 0 and coast.openness[i] < 0.5 and h < 90:
				name = "reeds"
			elif wet_n == 0 and h < 60:
				name = "tuft"
			elif h > 985:
				name = "driftwood"
		elif h < 50:
			name = small[h % small.size()]
		if name == "":
			continue
		_prop(name, at, true, coast.lift(c))
		placed += 1
		if l == Coast.HIGH and (name == "bush" or name == "herb" or name == "tuft" or name == "mushroom") and h % 2 == 0:
			_meadow.append(at + Vector2(0, -coast.lift(c)))
	for r in coast.rocks:
		var rp: Vector2 = r[0]
		_prop(String(r[1]), _px(rp), true, -1.0)


## A prop standing on ground `lift` px up (8 raised, 4 beach, about -1 in
## the water).
func _prop(name: String, at: Vector2, regional := true, lift := 8.0) -> Sprite2D:
	var pr := Art.prop(name, rid if regional else "")
	if pr.is_empty():
		pr = Art.prop(name)
	if pr.is_empty():
		return null
	var s := Sprite2D.new()
	s.centered = false
	s.texture = pr.tex
	s.offset = -pr.anchor
	s.position = at + Vector2(0, -lift)
	stage.add_child(s)
	return s


func _light(at: Vector2, color: Color, scale_f: float) -> void:
	var lp := PointLight2D.new()
	lp.texture = Art.glow
	lp.texture_scale = scale_f
	lp.color = color
	lp.energy = 0.8
	lp.position = at
	add_child(lp)


## Two batched scenic meshes soften water-depth steps and add small wet
## sand tongues at exposed beach edges. This never edits Coast's cells,
## room pads, walking graph or the protected boat approach.
func _build_shore_detail() -> void:
	for node in _shore_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_shore_nodes.clear()
	if kind == "dungeon":
		return
	var region: Dictionary = C.region(rid)
	var palette: Dictionary = region.get("palette", {})
	var deep := Color.html(String(palette.get("deep", "#2a6fae")))
	var sea_color := Color.html(String(palette.get("sea", "#3a8fd0")))
	var sand := Color.html(String(palette.get("land", "#e9d58f")))
	var detail := shore_detail_data(coast, deep, sea_color, sand)
	for entry in [["water", -20], ["shore", -10]]:
		var key := String(entry[0])
		var vertices: PackedVector3Array = detail[key + "_vertices"]
		if vertices.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = detail[key + "_colors"]
		arrays[Mesh.ARRAY_INDEX] = detail[key + "_indices"]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var node := MeshInstance2D.new()
		node.name = "NaturalDepth" if key == "water" else "WetShoreFragments"
		node.mesh = mesh
		node.z_index = int(entry[1])
		add_child(node)
		_shore_nodes.append(node)
	for point in detail.rocks:
		var rock := _prop("sea_rock_s", point, true, -1.0)
		if rock != null:
			_shore_nodes.append(rock)


static func _shore_protected(cs: Coast, c: Vector2i) -> bool:
	for y in range(-2, 3):
		for x in range(-2, 3):
			if cs.is_forced(c + Vector2i(x, y)):
				return true
	return false


## Distance to the actual coast drives the water colour at shared tile
## corners. A slow seeded shelf variation bends long depth boundaries;
## neighbour interpolation removes the old one-tone-per-diamond jump.
static func shore_detail_data(cs: Coast, deep: Color, sea_color: Color, sand: Color) -> Dictionary:
	var out := {"water_vertices": PackedVector3Array(), "water_colors": PackedColorArray(),
		"water_indices": PackedInt32Array(), "shore_vertices": PackedVector3Array(),
		"shore_colors": PackedColorArray(), "shore_indices": PackedInt32Array(), "rocks": []}
	var shelf := FastNoiseLite.new()
	shelf.seed = cs.seed + 217
	shelf.frequency = 0.105
	var shallow := sea_color.lerp(sand, 0.16).lightened(0.12)
	var fragments := 0
	for i in cs.lvl.size():
		var c := cs.cell_of(i)
		if _shore_protected(cs, c):
			continue
		if cs.lvl[i] == Coast.WATER and float(cs.dist[i]) < 8.0:
			var first: int = out.water_vertices.size()
			for corner in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
				var g: Vector2 = Vector2(c) + corner
				var distance := 0.0
				for oy in [0, 1]:
					for ox in [0, 1]:
						var sample_cell := Vector2i(floori(g.x) + ox, floori(g.y) + oy)
						var index := cs.idx(sample_cell)
						distance += minf(8.0, float(cs.dist[index])) if index >= 0 and cs.lvl[index] == Coast.WATER else 0.0
				distance = distance * 0.25 + shelf.get_noise_2dv(g) * 0.8
				var depth := smoothstep(0.1, 7.5, distance)
				var colour := shallow.lerp(sea_color, smoothstep(0.0, 0.5, depth)).lerp(deep, smoothstep(0.28, 1.0, depth))
				colour.a = 0.76 * (1.0 - smoothstep(6.0, 8.0, distance))
				var p := Art.iso(g.x, g.y)
				out.water_vertices.append(Vector3(p.x, p.y, 0))
				out.water_colors.append(colour)
			for index in [0, 1, 2, 0, 2, 3]:
				out.water_indices.append(first + index)
		elif cs.lvl[i] != Coast.WATER:
			var h := Coast.ihash(c.x, c.y, cs.seed + 911)
			for direction in [Vector2i(1, 0), Vector2i(0, 1)]:
				var water_cell: Vector2i = c + direction
				if cs.level(water_cell) != Coast.WATER or _shore_protected(cs, water_cell):
					continue
				var centre := Art.iso(c.x, c.y)
				var a := centre + (Vector2(0, 8) if direction.x else Vector2(-16, 0))
				var b := centre + (Vector2(16, 0) if direction.x else Vector2(0, 8))
				if cs.lvl[i] == Coast.LOW and fragments < 72 and h % 100 < 58:
					var normal := Vector2(0.45 if direction.x else -0.45, 0.9)
					var reach := 2.0 + float(h % 4)
					var points := [a.lerp(b, 0.12) - Vector2(0, 3), a.lerp(b, 0.2) + normal,
						a.lerp(b, 0.45) + normal * reach, a.lerp(b, 0.72) + normal * (reach - 1.0),
						a.lerp(b, 0.92), a.lerp(b, 0.85) - Vector2(0, 3)]
					var first: int = out.shore_vertices.size()
					for point in points:
						var p: Vector2 = point.round()
						out.shore_vertices.append(Vector3(p.x, p.y, 0))
						out.shore_colors.append(sand.lerp(sea_color, 0.24))
					for j in range(1, points.size() - 1):
						out.shore_indices.append_array(PackedInt32Array([first, first + j, first + j + 1]))
					fragments += 1
				elif h % 47 == 0 and out.rocks.size() < 12:
					out.rocks.append(a.lerp(b, 0.48).round() + Vector2(0, 3))
	return out


# ================================================================== rooms
func _build_rooms() -> void:
	for id in _room_vis:
		for n in _room_vis[id].nodes:
			if is_instance_valid(n):
				n.queue_free()
	_room_vis.clear()
	# Trail dots between rooms for readability.
	for a in _edges:
		for b in _edges[a]:
			if String(a) < String(b):
				var pa: Vector2 = _nodes[a]
				var pb: Vector2 = _nodes[b]
				var steps := int(pa.distance_to(pb) / 14.0)
				for k in range(1, steps):
					var dot := Sprite2D.new()
					dot.texture = Art.ui_tex("iso_dot")
					dot.position = (pa.lerp(pb, float(k) / float(steps)) + Vector2(0, -8)).round()
					dot.modulate = Color(1, 1, 1, 0.45)
					marks.add_child(dot)
	for r in _rooms():
		var id: String = r.id
		var p: Vector2 = _nodes[id]
		var ring := Sprite2D.new()
		ring.position = p + Vector2(0, -8)
		marks.add_child(ring)
		var icon := Sprite2D.new()
		icon.texture = Art.icon(KIND_ICON.get(String(r.kind), "ui_info"))
		icon.z_index = 6
		add_child(icon)
		var vis := {"ring": ring, "icon": icon, "obj": [], "nodes": [ring, icon], "state": ""}
		_room_vis[id] = vis


func _room_state(id: String) -> String:
	var rm = C.room(loc_id, id)
	if _cleared(id):
		return "cleared"
	if not Actions.room_accessible(st, loc_id, id):
		return "locked"
	if rm.get("secret", false) and Rules.explorer_pet(st) == null:
		return "hidden"
	return "open"


func _update_room(id: String) -> void:
	var vis: Dictionary = _room_vis[id]
	var state := _room_state(id)
	var rm = C.room(loc_id, id)
	var p: Vector2 = _nodes[id]
	var ring: Sprite2D = vis.ring
	ring.texture = Art.ui_tex({"cleared": "iso_dot", "locked": "iso_bad", "hidden": "iso_bad", "open": "iso_ok"}[state])
	if id == _here:
		ring.texture = Art.ui_tex("iso_sel")
	ring.modulate = Color(1, 1, 1, 0.5 if state == "locked" else 1.0)
	vis.icon.visible = state != "cleared"
	vis.icon.modulate = Color(1, 1, 1, 0.45) if state != "open" else Color.WHITE
	var preparation_active := bool(World.preparation(st, loc_id).get("active", false))
	if vis.state == state and bool(vis.get("preparation_active", false)) == preparation_active:
		return
	vis.state = state
	vis["preparation_active"] = preparation_active
	for n in vis.obj:
		if is_instance_valid(n):
			n.queue_free()
	vis.obj = []
	var objs: Array = []
	var k := String(rm.kind)
	if BATTLE_KINDS.has(k):
		if state == "cleared":
			var f := _prop("flag", p + Vector2(4, 0), false)
			if f:
				objs.append(f)
		else:
			var ids := _preview_enemies(id)
			for i in ids.size():
				var a := Actor.new()
				a.setup_enemy(String(ids[i]))
				a.position = p + Vector2(6 + i * 12, -4 + i * 8)
				a.face(Vector2(-1, 0.3))
				stage.add_child(a)
				if state != "open":
					a.modulate = Color(0.6, 0.6, 0.7, 0.85)
				objs.append(a)
	elif k == "resource":
		var c := _prop("chest_open" if state == "cleared" else "chest", p + Vector2(6, 0), false)
		if c:
			if state == "hidden":
				c.modulate = Color(1, 1, 1, 0.35)
			objs.append(c)
		if state != "cleared" and not rm.get("secret", false):
			var bush := _prop("bush", p + Vector2(-14, -6))
			if bush:
				objs.append(bush)
	else:
		var cr := _prop("crystal", p + Vector2(4, -2))
		if cr:
			cr.modulate = Color(1, 1, 1, 0.5) if state == "cleared" else Color.WHITE
			objs.append(cr)
	vis.obj = objs
	vis.nodes = [vis.ring, vis.icon] + objs


func _preview_enemies(id: String) -> Array:
	var def := World.encounter_for_state(st, loc_id, id, {})
	var out := []
	if def.waves.size():
		var last: Array = def.waves[def.waves.size() - 1]
		for e in last.slice(0, 2 if String(def.kind) != "battle" else 1):
			out.append(String(e.enemyId))
	return out


# ================================================================== party
func _build_party() -> void:
	for a in _party:
		a.queue_free()
	_party.clear()
	_hover_m = -1
	_goal.clear()
	for id in st.formation:
		if id == null or _party.size() >= 4:
			continue
		var m = Rules.member(st, id)
		if m == null:
			continue
		var a := Actor.new()
		a.setup_puppet(Art.crew_look(m))
		a.key = String(m.id)
		stage.add_child(a)
		_party.append(a)
	if _pet:
		_pet.queue_free()
		_pet = null
	var ex = Rules.explorer_pet(st)
	if ex != null:
		var info := Art.creature_info(Art.pet_key(ex))
		if not info.is_empty():
			_pet = Actor.new()
			_pet.setup_creature(info)
			stage.add_child(_pet)
	var cur = st.voyage.site.current if st.voyage != null and st.voyage.site != null else null
	_here = String(cur) if cur != null and _nodes.has(String(cur)) else LANDING
	_irng.seed = U.hash32("party:" + loc_id)
	_idle = []
	for i in _party.size():
		_party[i].desync(_irng.randf())
		_idle.append({"t": _irng.randf_range(2.0, 6.0), "look": false})
	_place_party_at(_here)


# ============================================================ landing boat
## Seats in the rowboat, relative to its waterline centre (bow toward +x).
const BOAT_SEATS := [Vector2(13, 0), Vector2(1, 1), Vector2(-11, -1), Vector2(-21, 0)]
const BOAT_ROW_SECS := 3.4


## The jetty berth: beside the outer end of the planks, on the seaward side.
func _boat_berth() -> Vector2:
	var lc := Art.uniso(_nodes[LANDING])
	return Art.iso(roundi(lc.x) - 4, roundi(lc.y) + 4) + Vector2(4, 17)


func _build_boat() -> void:
	_berth = _boat_berth()
	_boat_back = RowBoat.new()
	_boat_front = RowBoat.new()
	_boat_front.front = true
	stage.add_child(_boat_back)
	stage.add_child(_boat_front)
	_set_boat(_berth, 0.0)


func _set_boat(at: Vector2, bob: float) -> void:
	var p := at + Vector2(0, roundf(bob))
	_boat_back.position = p + Vector2(0, -RowBoat.SORT_OFF)
	_boat_front.position = p + Vector2(0, RowBoat.SORT_OFF)


## Rows the landing party in from open water, moors, then walks them up the
## jetty to the landing. Input that starts a walk is ignored while busy.
func _row_ashore() -> void:
	busy = true
	var start := _berth + Vector2(-210, 6)
	for a in _all_ashore():
		a.shadow.visible = false
		a.lift = -5.0
		a.play("idle")
		a.face(Vector2(1, 0.2))
	_boat_back.rowing = true
	_boat_front.rowing = true
	_row_step(0.0, start)
	cam.position = start + Vector2(60, -10)
	_clamp_cam()
	Audio.play_for("rowing", BOAT_ROW_SECS + 0.6)
	var tw := create_tween()
	tw.tween_method(_row_step.bind(start), 0.0, 1.0, BOAT_ROW_SECS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_disembark)


func _all_ashore() -> Array:
	var out := _party.duplicate()
	if _pet:
		out.append(_pet)
	return out


func _row_step(f: float, start: Vector2) -> void:
	var at := start.lerp(_berth, f)
	var bob := sin(_t * 3.1) * 1.2 * (1.0 - f * 0.6)
	_set_boat(at, bob)
	var seats := _all_ashore()
	for i in seats.size():
		var seat: Vector2 = BOAT_SEATS[mini(i, BOAT_SEATS.size() - 1)]
		if i >= BOAT_SEATS.size():
			seat = Vector2(23, 0)
		seats[i].position = at + seat + Vector2(0, roundf(bob))


func _disembark() -> void:
	_boat_back.rowing = false
	_boat_front.rowing = false
	_set_boat(_berth, 0.0)
	Audio.play("creak")
	if _party.is_empty():
		busy = false
		if _pet:
			_pet.shadow.visible = true
			_pet.lift = 0.0
			_place_party_at(LANDING)
		return
	var land: Vector2 = _nodes[LANDING]
	var everyone := _all_ashore()
	# Up onto the planks, along the jetty's centre line, then ashore.
	var jl := _jetty_line()
	for i in everyone.size():
		var a: Actor = everyone[i]
		var dest: Vector2 = land + _slot(i)
		_goal[a] = dest
		var lane_y := float(i % 3 - 1) * 2.0
		var up := Vector2(clampf(a.position.x, jl[1].x - 8.0, jl[0].x), jl[0].y + lane_y)
		var root: Vector2 = jl[0] + Vector2(0, lane_y)
		if i == 0:
			_party[0].arrived.connect(_on_landed, CONNECT_ONE_SHOT)
		var tm := get_tree().create_timer(0.22 * float(i))
		tm.timeout.connect(_step_up.bind(a, [[up, 0.0], [root, 0.0], [dest, 0.0]]))


func _step_up(a: Actor, pts: Array) -> void:
	if not is_instance_valid(a):
		return
	a.shadow.visible = true
	Audio.play("step")
	a.walk_path(pts, 54.0)


func _on_landed() -> void:
	busy = false
	for a in _party:
		a.face(Vector2(1, 0.3))
	if _pet:
		_pet.face(Vector2(1, 0.3))


func _place_party_at(id: String) -> void:
	_walk_gen += 1
	_drop_arrival()
	var p: Vector2 = _nodes[id]
	var everyone := _all_ashore()
	for i in everyone.size():
		var a: Actor = everyone[i]
		a.stop()
		a.position = p + _slot(i)
		_goal[a] = a.position
		a.play("idle")
		a.face(Vector2(1, 0.3))


func _route(from: String, to: String) -> Array:
	if from == to:
		return [to]
	var prev := {from: ""}
	var queue := [from]
	while queue.size():
		var n: String = queue.pop_front()
		if n == to:
			break
		for m in _edges.get(n, []):
			if not prev.has(m):
				prev[m] = n
				queue.append(m)
	if not prev.has(to):
		return [to]
	var path := [to]
	var cur: String = to
	while prev[cur] != "":
		cur = prev[cur]
		path.push_front(cur)
	return path


## Walks the party to a room; `done` runs when the leader arrives. Called
## only while no walk is running (room clicks are ignored while busy).
func walk_to(id: String, done: Callable) -> void:
	busy = true
	var route := _route(_here, id)
	if route.size() and route[0] == _here:
		route.pop_front()
	if _party.is_empty():
		_here = id
		busy = false
		done.call()
		return
	# Anyone still on the way from the last walk steps to their spot first,
	# so every walker starts this walk from its slot at the current room.
	_walk_gen += 1
	_drop_arrival()
	var gen := _walk_gen
	var everyone := _all_ashore()
	for a in everyone:
		if _goal.has(a) and (a.is_walking() or a.position.distance_to(_goal[a]) > 0.5):
			a.stop()
			a.position = _goal[a]
			a.play("idle")
	# The leader sets off first. On a longer walk the others step onto its
	# line and follow in single file, each held back so they reach the
	# line FILE_GAP apart (they start from different spots), then spread to
	# their own spots on arrival. A walk to the next room is a short shift
	# of the whole group, with only a slight stagger.
	var paths := []
	var order := []
	for i in everyone.size():
		var a: Actor = everyone[i]
		var pts := _walk_points(i, route)
		paths.append(pts)
		_goal[a] = pts[pts.size() - 1][0] if pts.size() else a.position
		if i > 0:
			order.append([a.position.distance_to(pts[0][0]) / WALK_SPEED if pts.size() else 0.0, i])
	# Followers nearest the leader's line join it first, so nobody waiting
	# for a turn is walked through by the ones behind.
	order.sort()
	var leader: Actor = everyone[0]
	var t_prev := 0.0
	if paths[0].size():
		t_prev = leader.position.distance_to(paths[0][0][0]) / WALK_SPEED
	_arrive_cb = _on_arrived.bind(id, done)
	leader.arrived.connect(_arrive_cb, CONNECT_ONE_SHOT)
	leader.walk_path(paths[0], WALK_SPEED)
	for k in order.size():
		var i: int = order[k][1]
		var delay := 0.07 * float(k + 1)
		if route.size() > 1:
			t_prev = maxf(float(order[k][0]), t_prev + FILE_GAP)
			delay = t_prev - float(order[k][0])
		get_tree().create_timer(delay).timeout.connect(_follow.bind(everyone[i], paths[i], gen))


## A walk that is replaced before the leader arrives must not report its
## arrival later.
func _drop_arrival() -> void:
	if _party.size() and is_instance_valid(_party[0]) and _arrive_cb.is_valid() and _party[0].arrived.is_connected(_arrive_cb):
		_party[0].arrived.disconnect(_arrive_cb)
	_arrive_cb = Callable()


func _follow(a: Actor, pts: Array, gen: int) -> void:
	if gen != _walk_gen or not is_instance_valid(a):
		return
	a.walk_path(pts, WALK_SPEED)


func _on_arrived(id: String, done: Callable) -> void:
	_here = id
	busy = false
	for a in _party:
		a.face(Vector2(1, 0.3))
	done.call()


# ================================================================ interaction
func _room_at(p: Vector2) -> String:
	var best := ""
	var best_d := 22.0
	for id in _nodes:
		if id == LANDING:
			continue
		var d: float = p.distance_to(_nodes[id] + Vector2(0, -10))
		if d < best_d:
			best_d = d
			best = id
	return best


func _room_tip(id: String) -> String:
	var rm = C.room(loc_id, id)
	var lines := [I18n.t("room.%s.name" % id) + " · " + I18n.t("roomkind." + String(rm.kind))]
	match _room_state(id):
		"cleared":
			lines.append(I18n.t("site.cleared") + " — " + I18n.t("site.move_free"))
		"locked":
			lines.append(I18n.t("site.locked"))
		"hidden":
			lines.append(I18n.t("err.need_explorer"))
		_:
			lines.append(I18n.t("site.cost", {"n": rm.cost}))
	var preparation := _preparation_text(id)
	if not preparation.is_empty():
		lines.append(preparation)
	return "\n".join(lines)


## The optional western detour affects this ruin only. The same stateful
## definition supplies both the visible threat preview and Actions entry.
func _preparation_text(id: String) -> String:
	var preparation := World.preparation(st, loc_id)
	if preparation.is_empty():
		return ""
	var room = C.room(loc_id, id)
	var branch := id == String(preparation.room)
	if not branch and (room == null or not BATTLE_KINDS.has(String(room.kind))):
		return ""
	var status := "active" if bool(preparation.active) else ("branch" if branch else "inactive")
	return I18n.t("site.prep.%s.%s" % [String(preparation.id), status])


## The moored rowboat is the way back to the ship.
func _over_boat(p: Vector2) -> bool:
	return Rect2(_berth + Vector2(-34, -15), Vector2(68, 30)).has_point(p)


func _boat_tip() -> String:
	return I18n.t("site.leave") + "\n" + I18n.t("site.leave_hint")


## Walks the landing party back to the rowboat (free along cleared paths),
## then boards the ship. Ignored mid-walk, like room clicks.
func return_to_ship() -> void:
	if busy or main == null:
		return
	if _here == LANDING:
		_commit_leave()
		return
	walk_to(LANDING, _commit_leave)


func _commit_leave() -> void:
	Game.act(Actions.leave_site(Game.state))


func _click_room(id: String) -> void:
	if busy or main == null:
		return
	var rm = C.room(loc_id, id)
	var state := _room_state(id)
	var k := String(rm.kind)
	var d := Dialog.new().setup(I18n.t("room.%s.name" % id), KIND_ICON.get(k, "ui_info"), 280)
	d.text(I18n.t("roomkind." + k) + " · " + I18n.t("loc.%s.name" % loc_id), "DimLabel")
	match state:
		"cleared":
			d.line("ui_check", I18n.t("site.cleared"), "GoodLabel")
			d.text(I18n.t("site.move_free"), "DimLabel")
		"locked":
			d.line("ui_lock", I18n.t("site.locked"), "WarnLabel")
		"hidden":
			d.line("ui_lock", I18n.t("err.need_explorer"), "WarnLabel")
	if state != "cleared":
		d.line("stamina", I18n.t("site.cost", {"n": rm.cost}) + "  (" + I18n.t("home.stamina_value", {"n": st.ship.stamina, "max": st.ship.staminaMax}) + ")")
	var preparation := _preparation_text(id)
	if not preparation.is_empty():
		var active := bool(World.preparation(st, loc_id).get("active", false))
		d.line("ui_check" if active else "ui_info", preparation, "GoodLabel" if active else "DimLabel")
	if BATTLE_KINDS.has(k) and state != "cleared":
		var names := []
		var def := World.encounter_for_state(st, loc_id, id, {})
		for w in def.waves:
			for e in w:
				var nm := I18n.t("enemy.%s.name" % e.enemyId)
				if not names.has(nm):
					names.append(nm)
		d.line("ui_battle", ", ".join(names))
		if k == "trial" and int(st.captain.mainStep.get(rid, 0)) < 4 and not st.captain.trialsWon.has(rid):
			d.line("ui_lock", I18n.t("err.trial_locked"), "WarnLabel")
	d.text(I18n.t("site.stamina_rule"), "DimLabel")
	d.button(I18n.t("ui.cancel"), "cancel")
	if state == "cleared":
		if BATTLE_KINDS.has(k):
			d.button(I18n.t("site.repeat") + "  " + I18n.t("site.cost", {"n": rm.cost}), "repeat", false, int(st.ship.stamina) >= int(rm.cost), I18n.t("site.repeat_hint"), "ui_battle")
		if k == "trial" and st.captain.postgame and C.world.LEGENDS.has(rid):
			d.button(I18n.t("site.legend"), "legend", false, true, I18n.t("legend.challenge"), "ui_star")
		d.button(I18n.t("site.move"), "move", true, id != _here, "", "ui_arrow_right")
	else:
		var label := I18n.t("site.fight") if BATTLE_KINDS.has(k) else I18n.t("site.search")
		d.button(label, "enter", true, state == "open", "", KIND_ICON.get(k, "ui_info"))
	d.done.connect(_on_room_choice.bind(id))
	main.show_dialog(d)


func _on_room_choice(choice: Variant, id: String) -> void:
	if choice == null or choice == "cancel":
		return
	var opts := {"repeat": choice == "repeat"}
	var probe: Dictionary
	if choice == "legend":
		probe = Actions.start_legend(Game.state)
	else:
		probe = Actions.enter_room(Game.state, id, opts)
	if not probe.get("ok", false):
		Game.act(probe)
		return
	walk_to(id, _arrive_and_act.bind(id, String(choice), opts))


func _arrive_and_act(id: String, choice: String, opts: Dictionary) -> void:
	var res: Dictionary = Actions.start_legend(Game.state) if choice == "legend" else Actions.enter_room(Game.state, id, opts)
	if not Game.act(res):
		return
	var v = res.get("value")
	if v is Dictionary and v.has("rewards"):
		var lines := Fmt.reward_lines(v.rewards)
		var d := Dialog.new().setup(I18n.t("site.found"), "ui_chest", 260)
		if lines.is_empty():
			d.text(I18n.t("site.nothing"), "DimLabel")
		for l in lines:
			d.line(l[0], l[1])
		if int(v.rewards.get("gold", 0)) > 0 or int(v.rewards.get("materials", 0)) > 0:
			d.text(I18n.t("battle.r_ledger"), "DimLabel")
		d.button(I18n.t("ui.ok"), "ok", true)
		main.show_dialog(d)
		for a in _party:
			a.play("cheer")
			a.bubble("coin", 1.6)


# ===================================================================== UI
func _build_ui() -> void:
	if ui:
		ui.queue_free()
	ui = CanvasLayer.new()
	ui.layer = 4
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Art.theme
	ui.add_child(root)
	var p := UIK.panel(null, "ChipPanel")
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.offset_top = maxf(44.0, _inset_chips + 4.0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	_info_panel = p
	_title = UIK.label("", "GoldLabel")
	_sub = UIK.label("", "DimLabel")
	p.add_child(UIK.vbox([UIK.hbox([UIK.icon("loc_" + kind if Art.has_icon("loc_" + kind) else "loc_island"), _title], 3), _sub], 1))


## Keeps the site title clear of the (UI-scaled) HUD strip and objective.
func set_hud_insets(_top_bar: float, chips: float, bottom: float) -> void:
	_inset_chips = chips
	_inset_bottom = bottom
	if _info_panel != null and is_instance_valid(_info_panel):
		_info_panel.offset_top = maxf(44.0, chips + 4.0)
	if _fit_active:
		fit_view.call_deferred()


func _update_ui() -> void:
	if _title == null:
		return
	var rooms := _rooms()
	var n := 0
	for r in rooms:
		if _cleared(r.id):
			n += 1
	_title.text = I18n.t("site.title", {"location": "loc.%s.name" % loc_id}) + "  ·  %d/%d" % [n, rooms.size()]
	_sub.text = I18n.t("site.hint")


# ================================================================ frame
func _process(delta: float) -> void:
	if st.is_empty():
		return
	_t += delta
	var pan := Vector2(Input.get_axis("pan_left", "pan_right"), Input.get_axis("pan_up", "pan_down"))
	if pan != Vector2.ZERO:
		var f := get_viewport().gui_get_focus_owner()
		if f == null or not (f is LineEdit):
			_fit_active = false
			cam.position += pan * 240.0 * delta / cam.zoom.x
			_clamp_cam()
	for id in _room_vis:
		var vis: Dictionary = _room_vis[id]
		var bob := roundf(sin(_t * 2.4 + float(String(id).hash() % 7)) * 2.0)
		vis.icon.position = _nodes[id] + Vector2(0, -44 + bob)
		if vis.state == "open":
			vis.ring.modulate.a = 0.65 + 0.35 * sin(_t * 4.0)
		if id == _hover:
			vis.ring.modulate.a = 1.0
	if busy and _party.size() and not _fit_active:
		# Keep the walking party in view.
		cam.position = cam.position.lerp(_party[0].position + Vector2(30, -10), clampf(delta * 2.0, 0.0, 1.0))
		_clamp_cam()
	_idle_life(delta)


## Idle party members now and then glance aside, back toward the room or
## at a neighbour, then face front again, so a resting group does not
## stand like four copies of one sprite.
func _idle_life(delta: float) -> void:
	for i in mini(_party.size(), _idle.size()):
		var a: Actor = _party[i]
		var s: Dictionary = _idle[i]
		if a.is_walking() or busy:
			s.t = 0.35 + 0.1 * float(i)
			s.look = true
			continue
		s.t = float(s.t) - delta
		if float(s.t) > 0.0:
			continue
		if s.look:
			a.face(Vector2(1, 0.3))
			s.t = _irng.randf_range(3.0, 7.5)
			s.look = false
			continue
		var r := _irng.randi() % 3
		var dir := Vector2(-1, 0.3)
		if r == 1:
			dir = Vector2(1, -0.4)
		elif r == 2 and _party.size() > 1:
			var other: Actor = _party[(i + 1 + _irng.randi() % (_party.size() - 1)) % _party.size()]
			dir = other.position - a.position
			dir.y = 0.3 if dir.y >= 0.0 else dir.y
		a.face(dir)
		s.t = _irng.randf_range(1.2, 2.6)
		s.look = true


## Common content envelope: room icons bob up to 54px above their node;
## party silhouettes, enemy previews and selection rings extend beyond
## the contact points. The return boat is an interaction, too.
static func content_rect(nodes: Dictionary, landmark_rect: Rect2, berth: Vector2) -> Rect2:
	var rect := Rect2()
	var first := true
	for point in nodes.values():
		var node_box := Rect2((point as Vector2) + Vector2(-70, -58), Vector2(148, 106))
		rect = node_box if first else rect.merge(node_box)
		first = false
	if landmark_rect.has_area():
		rect = landmark_rect if first else rect.merge(landmark_rect)
		first = false
	if is_finite(berth.x) and is_finite(berth.y):
		var boat_box := Rect2(berth + Vector2(-42, -26), Vector2(84, 54))
		rect = boat_box if first else rect.merge(boat_box)
	return rect.grow(10.0)


## Camera2D is centred on the viewport, not on the HUD-free rectangle.
## Solve both scale and position in the same coordinate system.
static func frame_plan(rect: Rect2, viewport: Vector2, safe: Rect2) -> Dictionary:
	var free := safe.intersection(Rect2(Vector2.ZERO, viewport))
	if free.size.x < 16.0 or free.size.y < 16.0:
		free = Rect2(Vector2(4, 4), (viewport - Vector2(8, 8)).max(Vector2(16, 16)))
	var size_v := rect.size.max(Vector2.ONE)
	var limit := minf(free.size.x / size_v.x, free.size.y / size_v.y)
	var zoom := minf(float(ZOOMS[0]), limit)
	for step in ZOOMS:
		if float(step) <= limit:
			zoom = float(step)
	zoom = maxf(0.0001, zoom)
	return {"zoom": zoom, "position": rect.get_center() - (free.get_center() - viewport * 0.5) / zoom,
		"free": free, "content": rect}


func _free_view_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var top := _inset_chips + 4.0
	var bottom := maxf(34.0, _inset_bottom + 4.0)
	var free := Rect2(Vector2(4, top), Vector2(maxf(16.0, vp.x - 8.0), maxf(16.0, vp.y - top - bottom)))
	if main != null and main.has_method("_free_screen"):
		free = main._free_screen().intersection(Rect2(Vector2.ZERO, vp)).grow(-4.0)
	if _info_panel != null and is_instance_valid(_info_panel) and _info_panel.visible:
		var title_bottom := _info_panel.get_global_rect().end.y + 4.0
		var old_bottom := free.end.y
		free.position.y = maxf(free.position.y, title_bottom)
		free.size.y = maxf(16.0, old_bottom - free.position.y)
	return free


func _content_rect() -> Rect2:
	var landmark_rect := Rect2()
	var landmark := stage.get_node_or_null("LocationLandmark") as Sprite2D
	if landmark != null:
		landmark_rect = landmark.transform * landmark.get_rect()
	var rect := content_rect(_nodes, landmark_rect, _boat_berth())
	# A Fit clicked during landing also includes the moving party and boat.
	for actor in _all_ashore():
		if is_instance_valid(actor) and actor.visible:
			rect = rect.merge(actor.pick_rect().grow(8.0))
	if _boat_back != null and is_instance_valid(_boat_back):
		rect = rect.merge(Rect2(_boat_back.position + Vector2(0, RowBoat.SORT_OFF) - Vector2(42, 26), Vector2(84, 54)))
	return rect


func _center_current_room() -> void:
	if not _nodes.has(_here):
		return
	var free := _free_view_rect()
	cam.position = (_nodes[_here] as Vector2) + Vector2(0, -6) - (free.get_center() - get_viewport_rect().size * 0.5) / cam.zoom.x


## Overview includes complete scenery and interactions, at the largest
## supported step which fits. A very small viewport can fit below 0.25x.
func fit_view() -> void:
	if _nodes.is_empty():
		return
	_fit_active = true
	var plan := frame_plan(_content_rect(), get_viewport_rect().size, _free_view_rect())
	cam.zoom = Vector2.ONE * float(plan.zoom)
	cam.position = plan.position
	_zoom_i = 0
	for i in ZOOMS.size():
		if float(ZOOMS[i]) <= cam.zoom.x + 0.0001:
			_zoom_i = i
	# Do not clamp the solved centre back into the interactive-node bounds:
	# its offset is precisely what reserves the HUD/title safe area.
	if not _sea_info.is_empty() and not _sea_cover.encloses(_needed_sea_cover()):
		_fill_sea()
	cam.force_update_scroll()


func zoom_step(dir: int, at_mouse := true) -> void:
	var ni := -1
	if dir > 0:
		for i in ZOOMS.size():
			if float(ZOOMS[i]) > cam.zoom.x + 0.0001:
				ni = i
				break
	else:
		for i in range(ZOOMS.size() - 1, -1, -1):
			if float(ZOOMS[i]) < cam.zoom.x - 0.0001:
				ni = i
				break
	if ni < 0:
		return
	_fit_active = false
	var before := get_global_mouse_position()
	_zoom_i = ni
	cam.zoom = Vector2.ONE * ZOOMS[_zoom_i]
	if at_mouse:
		cam.position += before - get_global_mouse_position()
	_clamp_cam()
	if not _sea_info.is_empty() and not _sea_cover.encloses(_needed_sea_cover()):
		_fill_sea()


func zoom_label() -> String:
	var zoom := cam.zoom.x
	return "×%d" % int(roundf(zoom)) if zoom >= 1.0 else "×1/%d" % int(roundf(1.0 / zoom))


func _clamp_cam() -> void:
	cam.position.x = clampf(cam.position.x, _bounds.position.x, _bounds.end.x)
	cam.position.y = clampf(cam.position.y, _bounds.position.y, _bounds.end.y)


func _unhandled_input(ev: InputEvent) -> void:
	if st.is_empty():
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_step(1)
			get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_step(-1)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = mb.pressed
			if mb.pressed:
				_drag_moved = 0.0
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var wp := get_global_mouse_position()
			var pick := _pick(wp)
			if int(pick[1]) >= 0:
				if main != null:
					main.open_window("crew", "", _party[int(pick[1])].key)
			elif String(pick[0]) != "":
				_click_room(String(pick[0]))
			elif _over_boat(wp):
				return_to_ship()
			get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _drag:
			_fit_active = false
			cam.position -= mm.relative / cam.zoom.x
			_drag_moved += mm.relative.length()
			_clamp_cam()
		_update_hover(get_global_mouse_position())
	elif ev.is_action_pressed("zoom_in"):
		zoom_step(1, false)
	elif ev.is_action_pressed("zoom_out"):
		zoom_step(-1, false)


## What the mouse is over: [room id or "", party index or -1]. A party
## member wins unless the pointer is right on the room marker itself.
func _pick(wp: Vector2) -> Array:
	var id := _room_at(wp)
	var mi := _member_at(wp)
	if mi >= 0 and id != "" and wp.distance_to(_nodes[id] + Vector2(0, -10)) <= 12.0:
		mi = -1
	return ["" if mi >= 0 else id, mi]


## Front-most party member whose figure contains `wp`, or -1.
func _member_at(wp: Vector2) -> int:
	var best := -1
	for i in _party.size():
		var a: Actor = _party[i]
		if a.visible and a.pick_rect().has_point(wp) and (best < 0 or a.position.y > _party[best].position.y):
			best = i
	return best


func _update_hover(wp: Vector2) -> void:
	var pick := _pick(wp)
	var id := String(pick[0])
	var mi := int(pick[1])
	var boat := id == "" and mi < 0 and _over_boat(wp)
	if id == _hover and mi == _hover_m and boat == _hover_boat:
		return
	if _hover_m >= 0 and _hover_m < _party.size() and is_instance_valid(_party[_hover_m]):
		_party[_hover_m].set_marker("")
	if mi >= 0:
		_party[mi].set_marker("iso_sel")
	# While one member is under the pointer the others turn see-through,
	# so the one picked reads whole even where a neighbour overlaps it.
	var others := Color(1, 1, 1, 0.5) if mi >= 0 else Color.WHITE
	for i in _party.size():
		_party[i].modulate = Color.WHITE if i == mi else others
	if _pet:
		_pet.modulate = others
	_hover = id
	_hover_m = mi
	_hover_boat = boat
	hover_changed.emit(_member_tip(mi) if mi >= 0 else (_room_tip(id) if id != "" else (_boat_tip() if boat else "")))


## Hover text for a landing-party member: who they are and their role.
func _member_tip(i: int) -> String:
	var m = Rules.member(st, _party[i].key)
	if m == null:
		return ""
	var line := I18n.crew_name(m) + " · " + I18n.t("class.%s.name" % m.classId) + " " + I18n.t("ui.lv", {"n": m.level})
	var role := I18n.t("site.party_lead") if i == 0 else I18n.t("site.party_member")
	if m.get("injured", false):
		role = I18n.t("view.injured")
	return line + "\n" + role + "  ·  " + I18n.t("site.party_click")


## A small rowboat drawn in two halves so the y-sorted crew sits inside it:
## the back half (water shadow, floor, far wall, far oar) sorts behind the
## crew and the front half (near wall and near oar) sorts in front of them.
class RowBoat extends Node2D:
	const SORT_OFF := 7.0
	const L := 31.0
	const B := 7.0
	const F := 6.0
	const N := 14
	var front := false
	var rowing := false
	var t := 0.0

	func _process(delta: float) -> void:
		if rowing:
			t += delta
			queue_redraw()

	func _rim(sign_y: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in N + 1:
			var a := PI * float(i) / float(N)
			var x := cos(a) * L
			var taper := 1.0 - 0.4 * maxf(0.0, cos(a))
			pts.append(Vector2(maxf(x, -L * 0.86), sign_y * sin(a) * B * taper))
		return pts

	func _oar(lock: Vector2, out_y: float, col: Color) -> void:
		if rowing:
			var sweep := sin(t * 5.2)
			var tip := lock + Vector2(sweep * 11.0, out_y * (9.0 + 2.0 * cos(t * 5.2)))
			draw_line(lock, tip, col, 1.5)
			draw_rect(Rect2(tip - Vector2(2, 1), Vector2(4, 2)), col.darkened(0.2))
		else:
			draw_line(lock + Vector2(-12, -out_y), lock + Vector2(10, -out_y), col, 1.5)

	func _draw() -> void:
		var wood := Color(0.45, 0.29, 0.17)
		var dark := Color(0.28, 0.17, 0.1)
		var light := Color(0.66, 0.47, 0.29)
		var floor_c := Color(0.36, 0.23, 0.13)
		var oar_c := Color(0.74, 0.6, 0.42)
		var o := Vector2(0, SORT_OFF if not front else -SORT_OFF)
		var near := _rim(1.0)
		var far := _rim(-1.0)
		if not front:
			# water shadow and wake
			var sh := PackedVector2Array()
			for v in near:
				sh.append(o + Vector2(v.x * 1.08, v.y * 1.5 + F))
			for i in range(far.size() - 1, -1, -1):
				sh.append(o + Vector2(far[i].x * 1.08, far[i].y * 0.6 + F))
			draw_colored_polygon(sh, Color(0.05, 0.12, 0.2, 0.35))
			if rowing:
				for k in 4:
					var ph := fmod(t * 1.6 + float(k) * 0.25, 1.0)
					var wx := -L - 4.0 - ph * 26.0
					var c := Color(0.92, 0.97, 1.0, 0.55 * (1.0 - ph))
					draw_line(o + Vector2(wx, F - 2.0 - ph * 4.0), o + Vector2(wx - 6.0, F - 2.0 - ph * 4.0), c, 1.0)
					draw_line(o + Vector2(wx, F + 3.0 + ph * 4.0), o + Vector2(wx - 6.0, F + 3.0 + ph * 4.0), c, 1.0)
			# floor (the whole rim, sunk a little) and the inside of the far wall
			var fl := PackedVector2Array()
			for v in near:
				fl.append(o + v * 0.92 + Vector2(0, 2))
			for i in range(far.size() - 1, -1, -1):
				fl.append(o + far[i] * 0.92 + Vector2(0, 2))
			draw_colored_polygon(fl, floor_c)
			var wall := PackedVector2Array()
			for v in far:
				wall.append(o + v)
			for i in range(far.size() - 1, -1, -1):
				wall.append(o + far[i] * 0.9 + Vector2(0, 3))
			draw_colored_polygon(wall, wood)
			draw_polyline(_shift(far, o), light, 1.0)
			for x in [-12.0, 2.0, 15.0]:
				draw_line(o + Vector2(x, -B * 0.75), o + Vector2(x, B * 0.75), light.darkened(0.15), 2.0)
			_oar(o + Vector2(2, -B + 1), -1.0, oar_c)
		else:
			# near wall: rim down to the waterline, narrowing toward the keel.
			# Drawn as one quad per rim segment: the rim and its keel line
			# are one closed outline only in theory. At the clamped transom
			# the rim doubles back above its own keel line, so that outline
			# crossed itself and the triangulator rejected it ("Invalid
			# polygon data, triangulation failed", once per redraw).
			for i in near.size() - 1:
				var q := PackedVector2Array([o + near[i], o + near[i + 1],
					o + Vector2(near[i + 1].x * 0.9, near[i + 1].y + F), o + Vector2(near[i].x * 0.9, near[i].y + F)])
				if not Geometry2D.triangulate_polygon(q).is_empty():
					draw_colored_polygon(q, wood)
			var strake := PackedVector2Array()
			for v in near:
				strake.append(o + Vector2(v.x * 0.95, v.y + F * 0.55))
			draw_polyline(strake, dark, 1.0)
			draw_polyline(_shift(near, o), light, 1.0)
			var stern := o + Vector2(-L * 0.86, 0)
			draw_line(stern, stern + Vector2(0, F), dark, 1.0)
			_oar(o + Vector2(2, B - 1), 1.0, oar_c)

	func _shift(pts: PackedVector2Array, o: Vector2) -> PackedVector2Array:
		var out := PackedVector2Array()
		for v in pts:
			out.append(v + o)
		return out
