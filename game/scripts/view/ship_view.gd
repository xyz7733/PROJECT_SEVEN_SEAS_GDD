## The ship stage: an animated ocean, the stacked hull assembled from
## generated pieces, furnished facilities with idle/working states, stairs,
## hatches, bulkheads, rails, rigging and lights, a living crew and pets, and
## (at a port) the quay with clickable town buildings. It also owns the camera
## and the build / move / stair / door editing modes.
##
## The ship is shown one *view level* at a time: level 0 is the exposed
## weather deck with its raised castles (the combat and circulation space);
## level k is the k-th covered interior level from the top, drawn as a
## cutaway with everything above it removed. Ship cells are 2 x 2 terrain
## tiles (64 x 32 px) and one deck level is 48 px high.
class_name ShipView
extends Node2D

signal selected(kind: String, payload: Variant)
signal hover_changed(text: String)
signal mode_changed(mode: String, text: String)
signal sailing_done

const LEVEL_PX := 48.0
## Where the ladder sprite meets the lower deck and the hatch rim above,
## as cell-local x offsets (the ladder leans toward -x).
const LADDER_FOOT_U := 0.25
const LADDER_TOP_U := -0.31
const ZOOMS := [0.5, 1.0, 2.0]
## How fast the sea streams past the hull while under way (px/s, toward the
## stern: the bow points to +x in ship cells, down-right on screen).
const SAIL_DRIFT := Vector2(-16, -8) * 3.4
## How far past the hull bounds the camera centre may be panned.
const CAM_MARGIN := 160.0
const MARK_SCALE := Vector2(2, 2)
const BUILDING_KINDS := ["navigation", "market", "tavern", "workshop", "quest_board", "house"]
## Authored layout style per port: town (dense rows, bunting, street stalls),
## market (open plaza with a landmark and stalls), fort (cannon line, flags,
## gate) or outpost (sparse homes, net racks, a fire).
const PORT_STYLE := {
	"brightquay": "town", "saltmarsh_landing": "outpost", "cinderport": "fort", "ashfall_harbor": "outpost",
	"rootharbor": "outpost", "fernwater_post": "market", "prismhaven": "market", "mirrorbay": "town",
	"crownport": "market", "silkmarket": "town", "gale_harbor": "fort", "beacon_rest": "outpost",
	"lanternport": "town", "dusk_mooring": "outpost", "ashport": "fort", "relic_dock": "market",
	"ringhold": "fort", "migration_post": "outpost", "horizon_gate": "market", "conclave_harbor": "town",
}
## Pennant colours per region (also used for stall canopies).
const BUNTING := {
	"dawnwater": [Color(0.85, 0.32, 0.28), Color(0.96, 0.86, 0.45), Color(0.3, 0.6, 0.86)],
	"emberreach": [Color(0.9, 0.45, 0.18), Color(0.3, 0.24, 0.22), Color(0.95, 0.75, 0.3)],
	"verdant_maw": [Color(0.45, 0.72, 0.3), Color(0.95, 0.82, 0.4), Color(0.75, 0.35, 0.5)],
	"glass_current": [Color(0.55, 0.85, 0.95), Color(0.92, 0.95, 1.0), Color(0.5, 0.55, 0.9)],
	"crown_shoals": [Color(0.92, 0.75, 0.25), Color(0.6, 0.2, 0.3), Color(0.95, 0.92, 0.85)],
	"stormbelt": [Color(0.4, 0.5, 0.65), Color(0.9, 0.88, 0.8), Color(0.85, 0.65, 0.25)],
	"moonwake": [Color(0.55, 0.45, 0.85), Color(0.95, 0.9, 0.6), Color(0.3, 0.35, 0.6)],
	"ashen_trench": [Color(0.6, 0.25, 0.22), Color(0.55, 0.52, 0.5), Color(0.85, 0.6, 0.3)],
	"leviathan_ring": [Color(0.25, 0.6, 0.6), Color(0.9, 0.85, 0.7), Color(0.7, 0.3, 0.3)],
	"grand_horizon": [Color(0.95, 0.85, 0.5), Color(0.35, 0.55, 0.85), Color(0.95, 0.95, 0.95)],
}
const REGION_TINT := {
	"dawnwater": Color(1.0, 0.95, 0.85), "emberreach": Color(1.0, 0.82, 0.7), "verdant_maw": Color(0.85, 1.0, 0.82),
	"glass_current": Color(0.85, 0.95, 1.0), "crown_shoals": Color(1.0, 0.95, 0.8), "stormbelt": Color(0.85, 0.88, 0.95),
	"moonwake": Color(0.88, 0.85, 1.0), "ashen_trench": Color(0.9, 0.85, 0.82), "leviathan_ring": Color(0.82, 0.95, 0.95),
	"grand_horizon": Color(1.0, 0.97, 0.88),
}
const TOWNSFOLK := ["kelp_tender", "bloom_nurse", "beacon_keeper", "reef_mender", "pennant_deckhand", "conclave_medic", "cutpurse"]
const REGION_GROUND := {
	"dawnwater": ["grass0", "sand0"], "emberreach": ["dirt", "stone1"], "verdant_maw": ["grass1", "moss"],
	"glass_current": ["crystal", "stone0"], "crown_shoals": ["stone0", "flowers"], "stormbelt": ["moss", "stone1"],
	"moonwake": ["moss", "floor1"], "ashen_trench": ["floor1", "dirt"], "leviathan_ring": ["sand0", "sand1"],
	"grand_horizon": ["grass2", "stone0"],
}
const FX_ALIAS := {"hearts": "heart"}
const LIGHT_COLORS := {"lamp": Color(1.0, 0.82, 0.48), "candle": Color(1.0, 0.68, 0.36), "water": Color(0.45, 0.85, 1.0),
	"heat": Color(1.0, 0.45, 0.2), "lantern": Color(1.0, 0.78, 0.42), "gate": Color(1.0, 0.86, 0.55),
	"window": Color(1.0, 0.8, 0.5), "nest": Color(1.0, 0.85, 0.5)}

var st: Dictionary = {}
var live := true
var context := "port"
var rid := "dawnwater"
var mode := "view"
var place_fid := ""
var place_uid: Variant = null
var place_rot := 0
var view_level := 0
var sel_kind := ""
var sel_payload: Variant = null
var editable := true

var cam: Camera2D
var sea: TileMapLayer
var land_sides: TileMapLayer
var land_low: TileMapLayer
var land_band: TileMapLayer
var land_ground: TileMapLayer
## The port's land (null at sea and on the title backdrop).
var coast: Coast
var world_sort: Node2D
var ship_root: Node2D
var shadow_poly: Polygon2D
var foam_root: Node2D
var sort: Node2D
var overlay: Node2D
var lights_root: Node2D
var fx_root: Node2D
var canvas_mod: CanvasModulate

var _hull: Dictionary = {}
var _sig := ""
var _statics: Array = []
var _rig_nodes: Array = []
var _deck_nodes: Array = []
var _facs: Dictionary = {}
var _lights: Array = []
var _actors: Dictionary = {}
var _brains: Dictionary = {}
var _pets: Dictionary = {}
var _town: Array = []
var _buildings: Array = []
var _occ: Dictionary = {}
var _reach: Dictionary = {}
## Stair, ladder and hatch cells by node: {kind, approach, ...}.
var _portals: Dictionary = {}
## Reachable cells where crew may idle or spawn (no portal cells).
var _rest_cells: Array = []
## Facility cells by Vector3i(view level, world column, row).
var _fac_world: Dictionary = {}
## Floor lift of each interior view level, top to bottom.
var _level_lifts: Array = []
## Interior dressing (see ShipDress): blocked cells by Vector3i(deck, x, y)
## -> {name, rot}, the layout per deck index, chore spots for idle crew
## [{node, pos, name}] and the sprites faded while placing.
var _dress: Dictionary = {}
var _dress_plan: Dictionary = {}
var _dress_chores: Array = []
var _dress_nodes: Array = []
var _hover_cell := Vector3i(-1, 0, 0)
var _hover_sprite: Sprite2D
var _ghost: Node2D
var _sel_nodes: Array = []
var _mode_marks: Array = []
var _zoom_i := 0
var _drag := false
var _drag_moved := 0.0
var _t := 0.0
var _sail_t := -1.0
var _sail_len := 2.6
var _sea_shift := Vector2.ZERO
## Title backdrop: the ship stays under way (sails set, sea streaming past).
var cruising := false
var _sail_fx: SailFx
## Rocks and stacks passing by while under way: [{node, p}].
var _passing: Array = []
var _pass_t := 0.0
var _rng := RandomNumberGenerator.new()
var _bounds := Rect2()
var _hour := 12
var _lookups_dirty := true
var _world_built := ""
var _sea_origin := Vector2.ZERO
## World rectangle the sea tiles cover. The camera clamp keeps every normal
## view inside it, so no undrawn world edge (black void) can show.
var _sea_cover := Rect2()
## Flat ocean-coloured underlay below the sea tiles: a fallback colour for
## anything the tiles miss (sailing shift, a window resized larger).
var _sea_floor: Polygon2D
## Surf along the port's coast.
var _coast_foam: Node2D
## Port layout of the current world (quay span, walk area): see _plan_port.
var _port: Dictionary = {}
## Viewport area not covered by HUD panels, in viewport pixels (set by
## main from the HUD insets); used to fit the current level into view.
var free_screen := Rect2()
## Ambient life (gulls, glints, cloud shadows, fireflies, the beacon).
var ambience: Ambience
## Lit-window overlays of the port buildings, shown after dark.
var _windows: Array = []
## Greenery spots for butterflies and fireflies, collected while dressing.
var _meadow: Array = []


func _init() -> void:
	y_sort_enabled = false
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	_sea_floor = Polygon2D.new()
	_sea_floor.z_index = -21
	add_child(_sea_floor)
	sea = TileMapLayer.new()
	sea.z_index = -20
	add_child(sea)
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
	world_sort = Node2D.new()
	world_sort.y_sort_enabled = true
	world_sort.z_index = -5
	add_child(world_sort)
	ship_root = Node2D.new()
	add_child(ship_root)
	shadow_poly = Polygon2D.new()
	shadow_poly.color = Color(0.02, 0.06, 0.12, 0.28)
	ship_root.add_child(shadow_poly)
	foam_root = Node2D.new()
	ship_root.add_child(foam_root)
	sort = Node2D.new()
	sort.y_sort_enabled = true
	ship_root.add_child(sort)
	fx_root = Node2D.new()
	fx_root.z_index = 8
	ship_root.add_child(fx_root)
	overlay = Node2D.new()
	overlay.z_index = 10
	ship_root.add_child(overlay)
	lights_root = Node2D.new()
	ship_root.add_child(lights_root)
	_hover_sprite = Sprite2D.new()
	_hover_sprite.texture = Art.ui_tex("iso_hover")
	_hover_sprite.scale = MARK_SCALE
	_hover_sprite.visible = false
	overlay.add_child(_hover_sprite)
	_ghost = Node2D.new()
	_ghost.modulate = Color(1, 1, 1, 0.62)
	overlay.add_child(_ghost)
	ambience = Ambience.new()
	add_child(ambience)
	cam = Camera2D.new()
	cam.zoom = Vector2(0.5, 0.5)
	add_child(cam)
	_rng.seed = 7


func _ready() -> void:
	cam.make_current()
	get_viewport().size_changed.connect(_on_viewport_resized)
	mode_changed.connect(func(_m, _t): _apply_dress_fade())


## A larger window shows more of the world: rebuild the sea if the camera
## could now see past the tiles.
func _on_viewport_resized() -> void:
	if st.is_empty() or _sea_cover.size == Vector2.ZERO:
		return
	if not _sea_cover.encloses(_needed_sea_cover()):
		_build_world()
	_clamp_cam()


## Everything the camera can show: the clamp area plus half a view at the
## widest zoom, plus the drift of the "under way" sea animation.
func _needed_sea_cover() -> Rect2:
	var vp := get_viewport_rect().size
	vp = Vector2(maxf(vp.x, 640.0), maxf(vp.y, 360.0))
	var half := vp * 0.5 / float(ZOOMS[0])
	return _bounds.grow(CAM_MARGIN).grow_individual(half.x + 160.0, half.y + 160.0, half.x + 160.0, half.y + 160.0)


# ================================================================ binding
## Binds the view to a state. `ctx` is port, sea, site or title.
func bind(state: Dictionary, ctx: String, is_live := true) -> void:
	st = state
	live = is_live
	context = ctx
	cruising = ctx == "title"
	var loc = C.location(String(st.world.currentLocationId))
	rid = String(loc.regionId) if loc != null else "dawnwater"
	_sig = ""
	if view_level >= level_count():
		view_level = 0
	refresh()
	_center_camera()


func refresh() -> void:
	if st.is_empty():
		return
	var sig := _structure_sig()
	if sig != _sig:
		_sig = sig
		_build_ship()
	var wsig := "%s|%s|%s" % [context, rid, String(st.ship.hullId)]
	if wsig != _world_built:
		_world_built = wsig
		_build_world()
	_sync_crew()
	_sync_pets()
	_apply_daylight()
	_apply_visibility()
	_refresh_selection()
	if mode != "view":
		_update_ghost()


func _structure_sig() -> String:
	var parts := [String(st.ship.hullId), JSON.stringify(st.ship.decks), JSON.stringify(st.ship.stairs)]
	for f in st.ship.facilities:
		parts.append("%s:%s:%d:%d:%d:%d:%s:%s" % [f.uid, f.id, int(f.deck), int(f.x), int(f.y), int(f.get("rot", 0)), str(f.stowed), str(f.get("damaged", false))])
	return "|".join(parts)


# =============================================================== geometry
## World point of a ship cell centre (one ship cell = 2 x 2 terrain tiles).
static func siso(gx: float, gy: float) -> Vector2:
	return Art.iso(gx * 2.0, gy * 2.0)


static func suniso(p: Vector2) -> Vector2:
	return Art.uniso(p) * 0.5


func deck(d: int) -> Dictionary:
	return st.ship.decks[d]


func deck_lift(d: int) -> float:
	return float(deck(d).elev) * LEVEL_PX


## Ground (sort) point of a deck-local cell position.
func ground(d: int, x: float, y: float) -> Vector2:
	return siso(float(deck(d).x0) + x, y)


## Drawn point on the deck surface.
func surface(d: int, x: float, y: float) -> Vector2:
	return ground(d, x, y) - Vector2(0, deck_lift(d))


func _deck_order() -> Array:
	var idx := range(st.ship.decks.size())
	idx.sort_custom(func(a, b): return int(deck(a).elev) > int(deck(b).elev))
	return idx


# ============================================================ view levels
func level_count() -> int:
	if st.is_empty():
		return 1
	return 1 + Rules.interior_levels(st.ship).size()


## Deck indices drawn and pickable in the current view level.
func visible_decks() -> Array:
	if st.is_empty():
		return []
	if view_level <= 0:
		return _deck_order().filter(func(d): return Rules.is_open_deck(deck(d)))
	var lv := Rules.interior_levels(st.ship)
	if view_level - 1 < lv.size():
		return [lv[view_level - 1]]
	return []


func level_title(k: int) -> String:
	if k <= 0:
		return I18n.t("deck.weather.title")
	var lv := Rules.interior_levels(st.ship)
	if k - 1 >= lv.size():
		return ""
	return I18n.t("deck.%s.title" % deck(lv[k - 1]).id)


## Crew currently standing on a view level (by their pathing node).
func crew_on_level(k: int) -> int:
	var n := 0
	for id in _brains:
		var node: Vector3i = _brains[id].node
		if node.x >= 0 and node.x < st.ship.decks.size() and Rules.view_level(st.ship, node.x) == k:
			n += 1
	return n


func set_view_level(k: int) -> void:
	k = clampi(k, 0, level_count() - 1)
	if k == view_level:
		return
	view_level = k
	Audio.play("creak", -3.0)
	_hover_cell = Vector3i(-1, 0, 0)
	_apply_daylight()
	_apply_visibility()
	_refresh_selection()
	if mode == "stair" or mode == "door":
		_update_mode_marks()
	elif mode != "view":
		_update_ghost()
	mode_changed.emit(mode, _mode_text())


func cycle_deck() -> void:
	set_view_level((view_level + 1) % level_count())


func level_step(dir: int) -> void:
	set_view_level(view_level + dir)


func focus_name() -> String:
	return level_title(view_level)


## View level an actor is drawn on, judged by its feet: it belongs to the
## highest level whose floor is at or below its feet. While climbing a
## ladder it therefore stays on the lower level (on the ladder sprite) until
## its feet reach the hatch rim, and is never drawn standing inside the
## upper deck.
func _lift_view(lift: float) -> int:
	if lift >= -0.5:
		return 0
	for i in _level_lifts.size():
		if float(_level_lifts[i]) <= lift + 0.5:
			return i + 1
	return _level_lifts.size()


## Sort key for an actor whose ground point is g. A raw ground point in the
## back half of a cell sorts before that cell's own floor piece (key
## centre - 4), which then paints over the feet. The key is raised to just
## after the cell's floor, stair, ladder and hatch pieces (centre - 1.5);
## in fitting cells only past the floor (centre - 3.5), so fittings (-2)
## still hide crew standing behind them. Pieces of cells in front sort at
## centre + 12 or later and keep occluding.
static func depth_key(g: Vector2, fitting: bool) -> float:
	var c := suniso(g).round()
	return maxf(g.y, siso(c.x, c.y).y + (-3.5 if fitting else -1.5))


func deck_depth_y(g: Vector2, view: int) -> float:
	var c := Vector2i(suniso(g).round())
	return depth_key(g, _fac_world.has(Vector3i(view, c.x, c.y)))


## Deck cell under a point in ship_root coordinates, or (-1,0,0).
func pick_cell(p: Vector2, only_deck := -1) -> Vector3i:
	for d in visible_decks():
		if only_deck >= 0 and d != only_deck:
			continue
		var c := suniso(p + Vector2(0, deck_lift(d)))
		var gx := roundi(c.x)
		var gy := roundi(c.y)
		var dk := deck(d)
		var lx := gx - int(dk.x0)
		if lx >= 0 and lx < int(dk.w) and gy >= 0 and gy < int(dk.h):
			return Vector3i(d, lx, gy)
	return Vector3i(-1, 0, 0)


# ============================================================ ship build
## Adds a sorted static sprite shown only on view level `view`.
func _add_static(n: Node2D, view: int, rigged := false) -> void:
	sort.add_child(n)
	_statics.append(n)
	n.set_meta("view", view)
	if rigged:
		_rig_nodes.append(n)
	else:
		_deck_nodes.append(n)


func _sprite(tex: Texture2D, topleft: Vector2, sort_pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.texture = tex
	s.position = sort_pos
	s.offset = topleft - sort_pos
	return s


func _build_ship() -> void:
	for n in _statics:
		n.queue_free()
	_statics.clear()
	_rig_nodes.clear()
	_deck_nodes.clear()
	for l in _lights:
		l.node.queue_free()
	_lights.clear()
	for c in foam_root.get_children():
		c.queue_free()
	for c in fx_root.get_children():
		c.queue_free()
	_facs.clear()
	var hid := String(st.ship.hullId)
	_hull = Art.hull_data(hid)
	if view_level >= level_count():
		view_level = 0
	var b: Dictionary = _hull.bounds
	var left := siso(float(b.minGx), float(b.maxGy)).x
	var right := siso(float(b.maxGx), float(b.minGy)).x
	_bounds = Rect2(left - 48, float(b.get("top", -400)) - 20, right - left + 96, 0)
	_bounds.size.y = float(b.get("bottom", 200)) - _bounds.position.y + 60
	# Hull pieces per view level, then the rig (open-deck view only)
	for p in _hull.pieces:
		var cell := Vector2i(int(p.cell[0]), int(p.cell[1]))
		var layer := String(p.layer)
		var rigged := layer != "hull"
		var key := -3.0 if rigged else -4.0
		var base := siso(cell.x, cell.y)
		var s := _sprite(Art.hull_piece_tex(hid, p.rect), base + Vector2(float(p.off[0]), float(p.off[1])), base + Vector2(0, key))
		s.set_meta("layer", layer)
		_add_static(s, int(p.get("view", 0)), rigged)
	# Ropes
	for r in _hull.ropes:
		var a := Vector2(float(r.a[0]), float(r.a[1]))
		var bb := Vector2(float(r.b[0]), float(r.b[1]))
		var lo := a if a.y > bb.y else bb
		var ln := Line2D.new()
		ln.width = 1.0
		ln.default_color = Color(0.22, 0.15, 0.1, 0.85)
		ln.position = lo + Vector2(0, 2)
		ln.points = PackedVector2Array([a - ln.position, bb - ln.position])
		if r.get("ladder", false):
			var ln2 := Line2D.new()
			ln2.width = 1.0
			ln2.default_color = ln.default_color
			ln2.points = PackedVector2Array([a - ln.position + Vector2(4, 0), bb - ln.position + Vector2(4, 0)])
			ln.add_child(ln2)
			var n := int((a - bb).length() / 6.0)
			for i in range(1, n):
				var q: Vector2 = a.lerp(bb, float(i) / n) - ln.position
				var rung := Line2D.new()
				rung.width = 1.0
				rung.default_color = Color(0.3, 0.2, 0.12, 0.8)
				rung.points = PackedVector2Array([q, q + Vector2(4, 0)])
				ln.add_child(rung)
		ln.set_meta("layer", "rope")
		_add_static(ln, 0, true)
	# Lights (each belongs to one view level)
	for l in _hull.lights:
		_add_light(Vector2(float(l.pos[0]), float(l.pos[1])), String(l.kind), 0.7, int(l.get("view", 0)))
	# Foam + shadow
	var port_pts := PackedVector2Array()
	var star_pts := PackedVector2Array()
	var i := 0
	for pair in _hull.foam:
		var pa := Vector2(float(pair[0][0]), float(pair[0][1]))
		var pb := Vector2(float(pair[1][0]), float(pair[1][1]))
		port_pts.append(pa)
		star_pts.append(pb)
		if i % 3 == 0:
			for q in [pa, pb]:
				var fs := AnimatedSprite2D.new()
				fs.sprite_frames = Art.foam_frames()
				fs.animation = "loop"
				fs.position = q
				fs.frame = (i * 3) % 4
				fs.speed_scale = 0.7 + 0.1 * (i % 4)
				fs.play()
				foam_root.add_child(fs)
		i += 1
	var poly := port_pts.duplicate()
	var rev := star_pts.duplicate()
	rev.reverse()
	poly.append_array(rev)
	for k in poly.size():
		poly[k] += Vector2(0, 6)
	shadow_poly.polygon = poly
	_sail_fx = SailFx.new()
	_sail_fx.port_pts = port_pts
	_sail_fx.star_pts = star_pts
	_sail_fx.drift = SAIL_DRIFT
	foam_root.add_child(_sail_fx)
	# Stairs, hatches and ladders
	var landings := {}
	for si in st.ship.stairs.size():
		var s = st.ship.stairs[si]
		var lo_d := int(s.deck)
		var up_d := int(s.to)
		landings["%d:%d:%d" % [up_d, int(s.ux), int(s.y)]] = true
		var terrace := Rules.is_open_deck(deck(lo_d)) and Rules.is_open_deck(deck(up_d)) and int(deck(lo_d).x0) + int(s.x) != int(deck(up_d).x0) + int(s.ux)
		if terrace:
			var dir_m := int(deck(lo_d).x0) + int(s.x) > int(deck(up_d).x0) + int(s.ux)
			var pd := Art.part("stair_mx" if dir_m else "stair_px")
			if pd.is_empty():
				continue
			var g := ground(lo_d, int(s.x), int(s.y))
			var sp := _sprite(pd.tex, g - Vector2(0, deck_lift(lo_d)) + pd.off, g + Vector2(0, -2))
			sp.set_meta("stair", si)
			_add_static(sp, 0)
		else:
			var pl := Art.part("ladder")
			if not pl.is_empty():
				var g2 := ground(lo_d, int(s.x), int(s.y))
				var sl := _sprite(pl.tex, g2 - Vector2(0, deck_lift(lo_d)) + pl.off, g2 + Vector2(0, -2))
				sl.set_meta("stair", si)
				_add_static(sl, Rules.view_level(st.ship, lo_d))
			var ph := Art.part("hatch")
			if not ph.is_empty():
				var g3 := ground(up_d, int(s.ux), int(s.y))
				var sh := _sprite(ph.tex, g3 - Vector2(0, deck_lift(up_d)) + ph.off, g3 + Vector2(0, -6))
				sh.set_meta("stair", si)
				_add_static(sh, Rules.view_level(st.ship, up_d))
	# Bulkheads and terrace rails
	for d in st.ship.decks.size():
		var dk := deck(d)
		var vl := Rules.view_level(st.ship, d)
		if dk.bulkhead != null:
			for y in int(dk.h):
				var is_door := Rules.is_door(dk, int(dk.bulkhead), y)
				var pd2 := Art.part("bulkhead_door" if is_door else "bulkhead_wall")
				if pd2.is_empty():
					continue
				var g4 := ground(d, int(dk.bulkhead), y)
				_add_static(_sprite(pd2.tex, g4 - Vector2(0, deck_lift(d)) + pd2.off, g4 + Vector2(0, -1)), vl)
		if int(dk.elev) > 0 and Rules.is_open_deck(dk):
			for o in st.ship.decks.size():
				var ok := deck(o)
				if int(ok.elev) >= int(dk.elev) or not Rules.is_open_deck(ok):
					continue
				var edge := -1
				var pname2 := ""
				if int(dk.x0) + int(dk.w) == int(ok.x0):
					edge = int(dk.w) - 1
					pname2 = "rail_px"
				elif int(ok.x0) + int(ok.w) == int(dk.x0):
					edge = 0
					pname2 = "rail_mx"
				if edge < 0:
					continue
				var pd3 := Art.part(pname2)
				if pd3.is_empty():
					continue
				for y in int(dk.h):
					if landings.has("%d:%d:%d" % [d, edge, y]):
						continue
					var g5 := ground(d, edge, y)
					var key2 := 3.0 if pname2 == "rail_px" else -3.0
					_add_static(_sprite(pd3.tex, g5 - Vector2(0, deck_lift(d)) + pd3.off, g5 + Vector2(0, key2)), 0)
	for f in st.ship.facilities:
		if f.stowed:
			continue
		_build_facility(f)
	_lookups_dirty = true
	_rebuild_lookups()
	_build_dressing()
	# The layout changed. Anyone stopped mid-route is put on the nearest node
	# (never left mid-step inside a new fitting); a worker whose fitting did
	# not move keeps its spot and its way down; everyone else steps back
	# onto its node. _think re-homes anyone whose node is gone.
	for uid in _brains:
		var br: Dictionary = _brains[uid]
		var a: Actor = _actors.get(uid)
		var walking := a != null and a.is_walking()
		var gf = br.get("goal_fac")
		var f = _fac_by_uid(gf) if gf != null else null
		var kept: bool = not walking and f != null and not f.stowed and _fac_sig(f) == String(br.get("spot_sig", "")) and _reach.has(br.node)
		br.timer = 0.0
		br.state = ""
		br.fac = null
		if not kept:
			br.exit_pts = []
		if a == null:
			continue
		a.stop()
		a.play("idle")
		if kept:
			continue
		if walking or not _reach.has(br.node):
			br.node = _nearest_node(a)
		if br.node.x >= 0 and _off_node(a, br.node):
			var pt := _node_point(br.node)
			a.position = pt[0]
			a.lift = pt[1]
	for pid in _pets:
		var pa: Actor = _pets[pid]
		var pn: Vector3i = pa.get_meta("node", Vector3i(-1, 0, 0))
		if pa.is_walking() or not _reach.has(pn):
			pn = _nearest_node(pa)
			pa.set_meta("node", pn)
		pa.stop()
		if pn.x >= 0 and _off_node(pa, pn):
			var ppt := _node_point(pn)
			pa.position = ppt[0]
			pa.lift = ppt[1]


func _build_facility(f: Dictionary) -> void:
	var d := int(f.deck)
	var vl := Rules.view_level(st.ship, d)
	var rot := int(f.get("rot", 0))
	var entry := {"f": f, "idle": [], "work": [], "fx": [], "working": false, "view": vl}
	for state_name in ["idle", "work"]:
		for p in Art.facility_pieces(String(f.id), rot, state_name == "work"):
			var cx: int = int(f.x) + int(p.cell.x)
			var cy: int = int(f.y) + int(p.cell.y)
			var g := ground(d, cx, cy)
			var s := _sprite(p.tex, g - Vector2(0, deck_lift(d)) + p.off, g + Vector2(0, -2))
			s.set_meta("fac", f.uid)
			s.set_meta("state", state_name)
			if f.get("damaged", false):
				s.self_modulate = Color(0.82, 0.72, 0.68)
			_add_static(s, vl)
			entry[state_name].append(s)
	var meta := Art.facility_meta(String(f.id), rot)
	var anchor := surface(d, int(f.x), int(f.y))
	for fx in meta.get("fx", []):
		var kind := String(fx[2])
		var node := Art.fx_node(FX_ALIAS.get(kind, kind), false, 6.0)
		node.position = anchor + Vector2(float(fx[0]), float(fx[1]))
		node.visible = false
		node.modulate = Color(1, 1, 1, 0.9)
		node.scale = Vector2(1.5, 1.5)
		node.set_meta("view", vl)
		fx_root.add_child(node)
		entry.fx.append(node)
	for l in meta.get("lights", []):
		_add_light(anchor + Vector2(float(l[0]), float(l[1])), String(l[2]), 0.55, vl)
	if f.get("damaged", false):
		var sm := Art.fx_node("smoke", false, 4.0)
		sm.position = anchor + Vector2(0, -40)
		sm.modulate = Color(1, 1, 1, 0.7)
		sm.set_meta("view", vl)
		sm.set_meta("always", true)
		fx_root.add_child(sm)
	_facs[f.uid] = entry


## view -1: a world light that is always shown.
func _add_light(pos: Vector2, kind: String, scale_f: float, view := -1) -> void:
	var l := PointLight2D.new()
	l.texture = Art.glow
	l.texture_scale = scale_f
	l.color = LIGHT_COLORS.get(kind, Color(1, 0.8, 0.5))
	l.position = pos
	l.energy = 0.6
	l.shadow_enabled = false
	lights_root.add_child(l)
	_lights.append({"node": l, "kind": kind, "view": view})


func _set_working(uid: Variant, on: bool) -> void:
	var e = _facs.get(uid)
	if e == null or e.working == on:
		return
	e.working = on
	var shown: bool = int(e.view) == view_level
	for s in e.idle:
		s.visible = shown and not on
	for s in e.work:
		s.visible = shown and on
	for n in e.fx:
		n.visible = shown and on


# ===================================================== port / open sea
## Terrain-tile extent of the hull ({x0, x1, y0, y1}); ship cells are 2 tiles.
func _tile_span() -> Dictionary:
	var b: Dictionary = _hull.bounds
	return {"x0": int(b.minGx) * 2, "x1": int(b.maxGx) * 2, "y0": int(b.minGy) * 2, "y1": int(b.maxGy) * 2}


func _build_sea_floor(r: Rect2) -> void:
	var big := r.grow(2048.0)
	_sea_floor.polygon = PackedVector2Array([big.position, Vector2(big.end.x, big.position.y), big.end, Vector2(big.position.x, big.end.y)])
	var reg = C.region(rid)
	var col := Color(0.1, 0.3, 0.5)
	if reg != null and reg.has("palette"):
		col = Color.html(String(reg.palette.get("deep", "#2a6fae")))
	_sea_floor.color = col


func _build_world() -> void:
	for layer in [sea, land_sides, land_low, land_band, land_ground]:
		layer.clear()
	for n in _buildings:
		n.node.queue_free()
	_buildings.clear()
	for a in _town:
		a.queue_free()
	_town.clear()
	for c in world_sort.get_children():
		c.queue_free()
	if _coast_foam != null:
		_coast_foam.queue_free()
		_coast_foam = null
	coast = null
	_port = {}
	_windows.clear()
	_meadow.clear()
	var ts := Art.tileset(rid)
	for layer in [sea, land_sides, land_low, land_band, land_ground]:
		layer.tile_set = ts
	var info := Art.align_layer(sea)
	for layer in [land_sides, land_low, land_band, land_ground]:
		Art.align_layer(layer)
	land_low.position += Vector2(0, -float(Coast.LIFT[Coast.LOW]))
	land_ground.position += Vector2(0, -float(Coast.LIFT[Coast.HIGH]))
	if context == "port":
		_port = _plan_port()
		coast = _make_port_coast(_port)
		coast.paint({"sea": sea, "sides": land_sides, "low": land_low, "band": land_band, "high": land_ground}, info)
		_coast_foam = coast.make_foam()
		add_child(_coast_foam)
	# Cover a screen-aligned rectangle (not a diamond of cells): every cell
	# whose centre lies in the area the camera can show. The coast paints
	# its own rectangle (land and water).
	_sea_cover = _needed_sea_cover()
	var cover := _sea_cover.grow(float(Art.HALF_W) * 2.0)
	var span := Rect2(Art.uniso(cover.position), Vector2.ZERO)
	for pt in [Vector2(cover.end.x, cover.position.y), Vector2(cover.position.x, cover.end.y), cover.end]:
		span = span.expand(Art.uniso(pt))
	_build_sea_floor(cover)
	_sea_shift = Vector2.ZERO
	_sea_origin = sea.position
	_clear_passing()
	for gx in range(floori(span.position.x) - 1, ceili(span.end.x) + 2):
		for gy in range(floori(span.position.y) - 1, ceili(span.end.y) + 2):
			if not cover.has_point(Art.iso(gx, gy)):
				continue
			var atlas: Vector2i
			if coast != null:
				if coast.idx(Vector2i(gx, gy)) >= 0:
					continue
				atlas = Art.water_tile(coast.water_name(Vector2i(gx, gy)))
			else:
				# Open ocean: one deep tone. Whitecaps, glints and cloud
				# shadows give it its variety (see Ambience).
				atlas = Art.water_tile("deep")
			sea.set_cell(Art.layer_cell(info, gx, gy), 0, atlas)
	if coast != null:
		_build_port(_port)
	_setup_ambience()


## Moves the sea toward the stern while under way. The layer slides and
## wraps every four cells; the water tiles repeat per cell, so the wrap
## cannot be seen and the sea streams past for as long as the ship sails.
func _advance_sea(delta: float) -> void:
	_sea_shift += SAIL_DRIFT * delta
	if _sea_shift.x <= -64.0:
		_sea_shift += Vector2(64, 32)
	sea.position = _sea_origin + _sea_shift.round()


func _under_way() -> bool:
	return cruising or _sail_t >= 0.0


func _clear_passing() -> void:
	for e in _passing:
		if is_instance_valid(e.node):
			e.node.queue_free()
	_passing.clear()
	_pass_t = 0.0


## A rock or sea stack that slides past on one side of the hull's lane.
## `ahead` is how far along the heading it starts (px from the ship's centre).
func _spawn_passing(ahead: float) -> void:
	var names := ["sea_rock", "sea_rock_s", "sea_stack", "sea_rock"]
	var pr := Art.prop(names[_rng.randi() % names.size()], rid)
	if pr.is_empty():
		return
	var b: Dictionary = _hull.bounds
	var centre := siso((float(b.minGx) + float(b.maxGx)) * 0.5, (float(b.minGy) + float(b.maxGy)) * 0.5)
	var beam := float(int(b.maxGy) - int(b.minGy)) * 14.3
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var at := centre + Vector2(0.8944, 0.4472) * ahead + Vector2(-0.4472, 0.8944) * side * (beam + _rng.randf_range(70.0, 300.0))
	var s := _world_sprite(pr.tex, pr.anchor, at.round())
	s.flip_h = _rng.randf() < 0.5
	_passing.append({"node": s, "p": at})


func _tick_passing(delta: float) -> void:
	if not _under_way() or coast != null:
		if not _passing.is_empty():
			_clear_passing()
		return
	var b: Dictionary = _hull.bounds
	var centre := siso((float(b.minGx) + float(b.maxGx)) * 0.5, (float(b.minGy) + float(b.maxGy)) * 0.5)
	_pass_t -= delta
	if _pass_t <= 0.0:
		_pass_t = _rng.randf_range(3.5, 8.0)
		var vp := get_viewport_rect().size / cam.zoom.x
		_spawn_passing(vp.length() * 0.5 + 80.0)
	for i in range(_passing.size() - 1, -1, -1):
		var e: Dictionary = _passing[i]
		e.p += SAIL_DRIFT * delta
		(e.node as Node2D).position = (e.p as Vector2).round()
		if ((e.p as Vector2) - centre).dot(Vector2(0.8944, 0.4472)) < -1100.0:
			(e.node as Node2D).queue_free()
			_passing.remove_at(i)


## Ambient life to suit the place: a busy harbour sky and a bay with fish
## in port, whitecaps and a lone gull on the open sea.
func _setup_ambience() -> void:
	ambience.reset()
	ambience.meadow = _meadow.duplicate()
	ambience.beacons = []
	ambience.drift = Vector2.ZERO
	if context == "port":
		ambience.gull_target = 3
		ambience.whitecap_density = 0.0
		ambience.fish_every = Vector2(6.0, 14.0)
		if _port.has("lighthouse") and not Art.prop("lighthouse").is_empty():
			var lhp: Vector2 = _port.lighthouse
			ambience.beacons = [Art.iso(lhp.x, lhp.y) + Vector2(0, -8 - 62)]
	else:
		ambience.gull_target = 2 if context == "title" else 1
		ambience.whitecap_density = 0.8
		ambience.fish_every = Vector2(7.0, 16.0)


func _world_sprite(tex: Texture2D, anchor: Vector2, at: Vector2, parent: Node2D = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.texture = tex
	s.position = at
	s.offset = -anchor
	(parent if parent else world_sort).add_child(s)
	return s


func _world_light(at: Vector2, scale_f: float, color: Color) -> void:
	var lp := PointLight2D.new()
	lp.texture = Art.glow
	lp.texture_scale = scale_f
	lp.color = color
	lp.position = at
	world_sort.add_child(lp)
	_lights.append({"node": lp, "kind": "lamp", "view": -1})


## The port's layout in terrain cells, decided before the land is shaped so
## the coast is built around it: the quay along the ship (columns qa..qb,
## rows -5..-3), public buildings on the street behind it, homes in curved
## rows further back. Each port has its own layout style and seed (two
## ports share a region's building art, so order, spacing, landmarks and
## street dressing differ).
func _plan_port() -> Dictionary:
	var t := _tile_span()
	var loc_id := String(st.world.currentLocationId) if st.has("world") else rid
	var style := String(PORT_STYLE.get(loc_id, "town"))
	var rng := RandomNumberGenerator.new()
	rng.seed = U.hash32("port:" + loc_id)
	var order: Array = BUILDING_KINDS.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var span: int = t.x1 - t.x0
	var step: int = maxi(5, span / BUILDING_KINDS.size())
	var gx: int = t.x0 + 1 + rng.randi_range(0, 2)
	var plaza := -9999
	var fronts: Array = []   # [kind, gx, gy] of each public building
	for k in order.size():
		var kind: String = order[k]
		if Art.building(rid, kind).is_empty():
			continue
		if style == "market" and k == 3 and plaza == -9999:
			plaza = gx + 1
			gx += 6
		var gy := -8 - (rng.randi() % 2 if style != "fort" else 0)
		if kind == "house":
			gy += 1
		fronts.append([kind, gx, gy])
		gx += step + rng.randi_range(-1, 1)
	# Homes in staggered rows that bend with a slow curve; outposts are
	# sparse, towns dense.
	var homes: Array = []
	if not Art.building(rid, "house").is_empty():
		var phase := rng.randf_range(0.0, TAU)
		var hx: int = t.x0 - 4 + rng.randi_range(0, 2)
		var row := 0
		var gap_p := 0.45 if style == "outpost" else (0.12 if style == "town" else 0.25)
		while hx < t.x1 + 6:
			var skip := rng.randf() < gap_p or (plaza != -9999 and absi(hx - plaza - 2) <= 2)
			var hy := -12 - (row % 2) - (1 if rng.randf() < 0.3 else 0) - roundi(1.2 + 1.2 * sin(float(hx) * 0.16 + phase))
			if not skip:
				homes.append([hx, hy])
			hx += 4 + rng.randi_range(0, 2)
			row += 1
	return {"t": t, "loc": loc_id, "style": style, "qa": int(t.x0) - 3, "qb": int(t.x1) + 3, "fronts": fronts,
		"homes": homes, "plaza": plaza, "seed": U.hash32("coast:" + loc_id)}


## The port's island: large masses behind the town with lobes and a bay on
## the far shore; on the left a cove with a plank pier and moored boats, a
## rocky arm, reefs and an islet; on the right a headland carrying the
## lighthouse, a reef off its tip and a second cove. The quay is the only
## straight edge (a built harbour wall along the ship); streets, lanes and
## building plots are forced raised land with their own paving. Adds the
## pier, boats and lighthouse cells to `plan`.
func _make_port_coast(plan: Dictionary) -> Coast:
	var qa: int = plan.qa
	var qb: int = plan.qb
	var rng := RandomNumberGenerator.new()
	rng.seed = int(plan.seed)
	var nz := FastNoiseLite.new()
	nz.seed = int(plan.seed) + 17
	nz.frequency = 0.35
	var cs := Coast.new()
	cs.setup(Rect2i(qa - 32, -50, qb - qa + 64, 62), int(plan.seed))
	cs.use_region(rid)
	cs.deep_from = 99.0
	cs.beach_bias = 0.2
	# Masses behind the town, then a broken far shore: ridges of different
	# depth with bays between them, a long peninsula off one back corner
	# and islets offshore.
	var x := float(qa - 6)
	while x <= float(qb + 4):
		cs.add_disk(Vector2(x + rng.randf_range(-1.5, 1.5), rng.randf_range(-16.0, -13.0)), rng.randf_range(10.5, 12.5))
		x += 7.0
	var ridge := float(qa) - 2.0 + rng.randf_range(0.0, 6.0)
	while ridge < float(qb):
		var depth := rng.randf_range(-33.0, -24.0)
		var rr := rng.randf_range(5.0, 8.0)
		cs.add_capsule(Vector2(ridge, -18.0), Vector2(ridge + rng.randf_range(-3.0, 3.0), depth), rr)
		ridge += rr * 2.0 + rng.randf_range(2.0, 7.0)
	for k in rng.randi_range(2, 3):
		cs.cut_disk(Vector2(rng.randf_range(float(qa) + 4.0, float(qb) - 4.0), rng.randf_range(-36.0, -30.0)), rng.randf_range(3.5, 5.5))
	var pen_left := rng.randf() < 0.5
	var pen_a := Vector2(float(qa) - 6.0, -22.0) if pen_left else Vector2(float(qb) + 4.0, -22.0)
	var pen_b := pen_a + (Vector2(-rng.randf_range(8.0, 12.0), -rng.randf_range(6.0, 10.0)) if pen_left else Vector2(rng.randf_range(4.0, 8.0), -rng.randf_range(10.0, 14.0)))
	cs.add_capsule(pen_a, pen_b, rng.randf_range(2.6, 3.4))
	cs.add_disk(pen_b, rng.randf_range(3.0, 4.0))
	cs.add_reef(pen_b + (Vector2(-3.5, -1.0) if pen_left else Vector2(1.0, -3.5)), rng.randf_range(2.4, 3.2))
	for k in 2:
		var ix := rng.randf_range(float(qa) + 4.0, float(qb) - 4.0)
		var iy := rng.randf_range(-45.0, -41.0)
		cs.add_disk(Vector2(ix, iy), rng.randf_range(1.8, 2.8))
		if rng.randf() < 0.5:
			cs.add_reef(Vector2(ix + 2.0, iy + 0.5), 2.5)
	# Left: cove, rocky arm, reefs and an islet.
	var cove := Vector2(float(qa) - 7.0 + rng.randf_range(-1.0, 0.5), rng.randf_range(-3.5, -2.5))
	var cove_r := rng.randf_range(3.4, 4.0)
	cs.cut_disk(cove, cove_r)
	var arm_b := Vector2(float(qa) - 11.5 + rng.randf_range(-1.0, 1.0), rng.randf_range(0.5, 2.5))
	cs.add_capsule(Vector2(float(qa) - 12.0 + rng.randf_range(-1.0, 1.0), -8.0), arm_b, rng.randf_range(1.8, 2.3))
	cs.add_reef(arm_b + Vector2(-1.5, 2.5), rng.randf_range(2.2, 3.0))
	var islet := Vector2(float(qa) - 16.0 + rng.randf_range(-2.0, 1.0), rng.randf_range(4.0, 7.0))
	cs.add_disk(islet, rng.randf_range(1.6, 2.2))
	if rng.randf() < 0.6:
		cs.add_reef(islet + Vector2(2.0, 0.5), rng.randf_range(2.2, 3.0))
	# Right: lighthouse headland, reef, a second cove and a lobe behind it.
	var hl_b := Vector2(float(qb) + 4.0 + rng.randf_range(-0.5, 1.5), rng.randf_range(-1.0, 0.5))
	cs.add_capsule(Vector2(float(qb) + 2.0 + rng.randf_range(-0.5, 1.0), -8.0), hl_b, rng.randf_range(2.0, 2.4))
	cs.add_reef(hl_b + Vector2(2.5, 2.5), rng.randf_range(2.2, 3.0))
	var cove2 := Vector2(float(qb) + 10.5 + rng.randf_range(-1.0, 1.5), rng.randf_range(-6.0, -4.0))
	cs.cut_disk(cove2, rng.randf_range(3.4, 4.2))
	cs.add_disk(Vector2(float(qb) + 12.0 + rng.randf_range(-1.0, 2.0), rng.randf_range(-15.0, -12.0)), rng.randf_range(3.5, 5.0))
	# The harbour: the ship's water and the quay along it.
	for gx in range(qa, qb + 1):
		for gy in range(-2, 12):
			cs.force_water(Vector2i(gx, gy))
		for gy in range(-5, -2):
			cs.build(Vector2i(gx, gy), ["slab0", "slab1", "slab2", "slab0", "slab1"][U.hash32("quay:%d:%d" % [gx, gy]) % 5], "stone")
	# The street behind the quay, ragged on its far side.
	var cobble := ["cobble0", "cobble1", "cobble2"]
	for gx in range(qa - 2, qb + 3):
		var v := nz.get_noise_2d(float(gx) * 0.6, 3.0)
		for gy in [-6, -7, -8]:
			var paved: bool = gy == -6 or (gy == -7 and v > -0.35) or (gy == -8 and v > 0.45)
			var c := Vector2i(gx, gy)
			cs.force_land(c, cobble[U.hash32("st:%d:%d" % [gx, gy]) % 3] if paved else "")
	# Building plots, lanes up between the public buildings, the plaza.
	var fronts: Array = plan.fronts
	for f in fronts:
		_coast_pad(cs, Vector2(float(f[1]), float(f[2])), 1.9)
	for h in plan.homes:
		_coast_pad(cs, Vector2(float(h[0]), float(h[1])), 1.6)
	for i in fronts.size() - 1:
		var mid := (float(fronts[i][1]) + float(fronts[i + 1][1])) * 0.5 + 0.5
		_coast_lane(cs, Vector2(mid, -7.0), Vector2(mid + 1.0, -12.0), 0.9, 0.45, ["path"], nz)
	if int(plan.plaza) != -9999:
		var pc := Vector2(float(plan.plaza) + 2.0, -9.5)
		_coast_pad(cs, pc, 2.4)
		for px in range(int(plan.plaza) - 1, int(plan.plaza) + 6):
			for py in range(-12, -7):
				var c := Vector2i(px, py)
				if Vector2(c).distance_to(pc) <= 2.2 + 0.5 * nz.get_noise_2dv(Vector2(c) * 1.3):
					cs.force_land(c, cobble[U.hash32("pl:%d:%d" % [px, py]) % 3])
	match String(plan.style):
		"fort":
			_coast_pad(cs, Vector2(float(qa) - 4.0, -10.0), 1.6)
		"outpost":
			_coast_pad(cs, Vector2(float(qb), -9.0), 1.3)
	# Cove pier: a lane down to its root, planks out over the water and two
	# boats moored either side.
	var px := roundi(cove.x)
	var top := roundi(cove.y - cove_r) - 1
	var tip := roundi(cove.y + cove_r * 0.35)
	_coast_lane(cs, Vector2(float(qa) - 2.0, -6.0), Vector2(float(px), float(top)), 0.9, 0.5, ["path"], nz)
	for gy in range(top + 1, tip + 1):
		cs.build(Vector2i(px, gy), "plank", "wood")
		if gy > top + 1:
			cs.force_water(Vector2i(px - 1, gy))
			cs.force_water(Vector2i(px + 1, gy))
	var boats: Array = [Vector2(float(px) - 2.2, float(tip) - 0.6), Vector2(float(px) + 2.2, float(tip) - 1.2)]
	if rng.randf() < 0.55:
		boats.append(cove2 + Vector2(0.0, 1.0))
	for b in boats:
		var bc := Vector2i(roundi(b.x), roundi(b.y))
		for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			cs.force_water(bc + o)
	# Lighthouse on the headland and a path out to it.
	var lh := Vector2(roundf(hl_b.x - 0.5), roundf(hl_b.y - 1.0))
	_coast_pad(cs, lh, 1.3)
	_coast_lane(cs, Vector2(float(qb) + 2.0, -6.0), lh, 0.9, 0.45, ["path"], nz)
	cs.generate()
	plan.pier = [px, top + 1, tip]
	plan.boats = boats
	plan.lighthouse = lh
	return cs


## Raised land in a disk (a building plot, a landmark's footing).
func _coast_pad(cs: Coast, c: Vector2, r: float) -> void:
	for gx in range(floori(c.x - r), ceili(c.x + r) + 1):
		for gy in range(floori(c.y - r), ceili(c.y + r) + 1):
			var cc := Vector2i(gx, gy)
			if Vector2(cc).distance_to(c) <= r and not cs.is_built(cc):
				cs.force_land(cc)


## Raised land within `r` cells of the segment a-b, paved with one of
## `paint` within a noisy `w` of it (a worn lane).
func _coast_lane(cs: Coast, a: Vector2, b: Vector2, r: float, w: float, paint: Array, nz: FastNoiseLite) -> void:
	r = maxf(r, w + 0.35)
	for gx in range(floori(minf(a.x, b.x) - r), ceili(maxf(a.x, b.x) + r) + 1):
		for gy in range(floori(minf(a.y, b.y) - r), ceili(maxf(a.y, b.y) + r) + 1):
			var c := Vector2i(gx, gy)
			if cs.is_built(c):
				continue
			var p := Vector2(c)
			var d := Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p)
			if d > r:
				continue
			var paved := d <= w + 0.3 * nz.get_noise_2dv(p)
			cs.force_land(c, String(paint[U.hash32("ln:%d:%d" % [gx, gy]) % paint.size()]) if paved else "")


func _build_port(plan: Dictionary) -> void:
	var lift := Vector2(0, -8)
	var qa: int = plan.qa
	var qb: int = plan.qb
	var style := String(plan.style)
	var rng := RandomNumberGenerator.new()
	rng.seed = U.hash32("dress:" + String(plan.loc))
	var fronts: Array = []   # [gx, gy, half width in tiles] of each public building
	for f in plan.fronts:
		var kind := String(f[0])
		var bd := Art.building(rid, kind)
		var at := Art.iso(int(f[1]), int(f[2])) + lift
		var s := _world_sprite(bd.tex, bd.anchor, at)
		_lit_windows(s, kind, bd.anchor)
		_buildings.append({"node": s, "kind": kind, "rect": Rect2(at - bd.anchor, bd.tex.get_size())})
		fronts.append([int(f[1]), int(f[2]), bd.tex.get_size().x / 36.0])
	var hb := Art.building(rid, "house")
	var homes: Array = []
	for h in plan.homes:
		var hx: int = h[0]
		var hy: int = h[1]
		var hs := _world_sprite(hb.tex, hb.anchor, Art.iso(hx, hy) + lift)
		hs.flip_h = rng.randf() < 0.45
		hs.self_modulate = Color(1, 1, 1).darkened(rng.randf_range(0.0, 0.12)).lerp(REGION_TINT.get(rid, Color.WHITE), rng.randf_range(0.0, 0.18))
		# Most homes have someone in after dark; a few stay dark.
		if rng.randf() < 0.8:
			_lit_windows(hs, "house", hb.anchor)
		homes.append([hx, hy, hs])
		if rng.randf() < 0.4:
			_chimney_smoke(Art.iso(hx, hy) + lift, -hb.anchor + Vector2(hb.tex.get_size().x * (0.3 if hs.flip_h else 0.7), 8))
	# Bunting across the lanes between public buildings, laundry between homes.
	var flags: Array = BUNTING.get(rid, [Color(0.85, 0.3, 0.25), Color(0.95, 0.85, 0.4), Color(0.3, 0.55, 0.85)])
	for i in fronts.size() - 1:
		if rng.randf() < (0.35 if style == "outpost" else 0.75):
			var fa: Array = fronts[i]
			var fb: Array = fronts[i + 1]
			var ya := float(fa[1]) + 0.6
			var pa := Art.iso(float(fa[0]) + float(fa[2]), ya) + lift + Vector2(0, -30)
			var pb := Art.iso(float(fb[0]) - float(fb[2]), ya) + lift + Vector2(0, -30)
			_string_line(pa, pb, flags, "pennant", rng.randi())
	for i in homes.size() - 1:
		if rng.randf() < 0.3 and int(homes[i + 1][0]) - int(homes[i][0]) <= 6 and int(homes[i + 1][1]) == int(homes[i][1]):
			var la := Art.iso(float(homes[i][0]) + 1.2, float(homes[i][1]) + 1.0) + lift + Vector2(0, -18)
			var lb := Art.iso(float(homes[i + 1][0]) - 1.2, float(homes[i][1]) + 1.0) + lift + Vector2(0, -18)
			_string_line(la, lb, [Color(0.92, 0.9, 0.84), Color(0.55, 0.68, 0.82), Color(0.8, 0.55, 0.45)], "laundry", rng.randi())
	# Style set pieces.
	var rprops: Array = Art.env.regionProps.get(rid, [])
	var entry_gx := _entry_gx()
	var plaza: int = plan.plaza
	match style:
		"market":
			if plaza != -9999:
				var mark := ""
				for cand in ["statue", "pillar", "crystal", "pillar_broken", "tree"]:
					if rprops.has(cand):
						mark = cand
						break
				var mp := Art.prop(mark, rid) if mark != "" else Art.prop("lamp")
				if not mp.is_empty():
					_world_sprite(mp.tex, mp.anchor, Art.iso(plaza + 2, -9.5) + lift)
				for k in 3:
					var sc: Color = flags[k % flags.size()]
					_stall(Art.iso(plaza + 0.2 + k * 1.7, -10.6 + (k % 2) * 2.6) + lift, sc)
				for nm in ["sacks", "crate", "barrel"]:
					var pr := Art.prop(nm)
					if not pr.is_empty():
						_world_sprite(pr.tex, pr.anchor, Art.iso(plaza + rng.randf_range(0.5, 4.0), rng.randf_range(-10.8, -8.2)) + lift)
		"fort":
			var span: int = qb - qa - 6
			for k in 4:
				var cx: int = qa + 5 + k * maxi(5, span / 4)
				var cn := Art.prop("cannon")
				if not cn.is_empty() and absi(cx - entry_gx) > 2:
					_world_sprite(cn.tex, cn.anchor, Art.iso(cx, -4.6) + lift)
				var fl := Art.prop("flag")
				if not fl.is_empty() and k % 2 == 0 and coast.level(Vector2i(cx + 2, -10)) == Coast.HIGH:
					_world_sprite(fl.tex, fl.anchor, Art.iso(cx + 2, -9.6) + lift)
			var gp := Art.prop("gate", rid)
			if not gp.is_empty():
				_world_sprite(gp.tex, gp.anchor, Art.iso(qa - 4, -10) + lift)
		"outpost":
			for k in 3:
				var nx := qa + 2 + k * 3
				if absi(nx - entry_gx) > 2:
					_net_rack(Art.iso(nx, -5.8) + lift)
			var cf := Art.prop("campfire")
			if not cf.is_empty():
				_world_sprite(cf.tex, cf.anchor, Art.iso(qb, -9) + lift)
				_world_light(Art.iso(qb, -9) + lift + Vector2(0, -6), 0.5, LIGHT_COLORS.candle)
		_:
			for k in 2:
				var sc2: Color = flags[(k + 1) % flags.size()]
				_stall(Art.iso(qb - 9 + k * 2, -7.2) + lift, sc2)
	# Boats moored at the cove pier (and in the far cove).
	for b in plan.boats:
		_moored_boat(Art.iso(b.x, b.y) + Vector2(rng.randi_range(-2, 2), 0))
	_port_greenery(plan)
	# Quay clutter, away from the gangway.
	var clutter := ["barrels", "crate", "sacks", "barrel", "lamp", "crate", "signpost", "lamp", "cannon", "flag", "barrels", "lamp", "crate", "sacks"]
	var cstep: int = maxi(3, (qb - qa - 2) / clutter.size())
	for k in clutter.size():
		var cx := qa + 1 + k * cstep + rng.randi_range(0, 1)
		if absi(cx - entry_gx) <= 2:
			cx += 4
		if cx > qb - 1:
			continue
		var cy := -6 + (k % 2)
		var pr3 := Art.prop(clutter[k])
		if not pr3.is_empty():
			_world_sprite(pr3.tex, pr3.anchor, Art.iso(cx, cy) + lift)
		if clutter[k] == "lamp":
			_world_light(Art.iso(cx, cy) + lift + Vector2(0, -20), 0.6, LIGHT_COLORS.lamp)
	var lh := Art.prop("lighthouse")
	var lhp: Vector2 = plan.lighthouse
	if not lh.is_empty():
		_world_sprite(lh.tex, lh.anchor, Art.iso(lhp.x, lhp.y) + lift)
		_world_light(Art.iso(lhp.x, lhp.y) + lift + Vector2(0, -80), 1.2, Color(1, 0.9, 0.6))
	# Gangway plank from the entry cell to the quay.
	var e = deck(0).entry
	if e != null:
		var top := surface(0, int(e[0]), -0.5)
		var bot := siso(float(int(deck(0).x0) + int(e[0])), -1.6) + lift
		var plank := Polygon2D.new()
		var side := Vector2(10, 5)
		plank.polygon = PackedVector2Array([top - side, top + side, bot + side, bot - side])
		plank.color = Color(0.55, 0.36, 0.2)
		var edge := Line2D.new()
		edge.width = 1
		edge.default_color = Color(0.3, 0.18, 0.1)
		edge.points = PackedVector2Array([top + side, bot + side])
		plank.add_child(edge)
		var n := 6
		for k in range(1, n):
			var q := top.lerp(bot, float(k) / n)
			var slat := Line2D.new()
			slat.width = 1
			slat.default_color = Color(0.36, 0.22, 0.12)
			slat.points = PackedVector2Array([q - side, q + side])
			plank.add_child(slat)
		plank.z_index = -4
		add_child(plank)
		plank.set_meta("gangway", true)
		_buildings.append({"node": plank, "kind": "", "rect": Rect2()})
	# Townsfolk strolling on the quay.
	for k in 7:
		var a := Actor.new()
		a.setup_puppet(Art.npc_look(TOWNSFOLK[(k + U.hash32(rid)) % TOWNSFOLK.size()]))
		a.position = Art.iso(rng.randi_range(qa + 2, qb - 2), rng.randf_range(-5.4, -3.6))
		a.lift = 8
		world_sort.add_child(a)
		_town.append(a)
		a.set_meta("timer", rng.randf_range(0.5, 4.0))


## Adds the lit-window overlay of a building as a child of its sprite, so it
## is sorted and hidden exactly like the building. _apply_daylight fades it
## in after dark and cancels the night tint on it.
func _lit_windows(building: Sprite2D, kind: String, anchor: Vector2) -> void:
	var lit := Art.building_lit(rid, kind)
	if lit == null:
		return
	var w := Sprite2D.new()
	w.centered = false
	w.texture = lit
	w.offset = -anchor
	w.flip_h = building.flip_h
	w.visible = false
	building.add_child(w)
	_windows.append(w)


## True when a tall prop at cell c would stand in front of (hide) forced
## land: a building plot, street, lane or the quay.
func _shades_town(c: Vector2i) -> bool:
	for oy in range(-3, 1):
		for ox in range(-3, 1):
			var b := c + Vector2i(ox, oy)
			if (ox != 0 or oy != 0) and coast.is_land(b) and coast.is_forced(b):
				return true
	return false


## Groves, shrubs and shore plants on the open land around the town, and
## the rocks off the coast. Nothing tall stands just in front of a
## building plot, street, lane or the quay, where it would hide them.
func _port_greenery(plan: Dictionary) -> void:
	var pool: Array = Art.env.regionProps.get(rid, ["rock", "bush"])
	# Groves are trees (or crystals, mushrooms); pillars and statues stand
	# alone as rare landmarks.
	var tall := []
	var small := []
	var marks := []
	for nm in pool:
		if ["pillar", "pillar_broken", "statue"].has(nm):
			marks.append(nm)
		elif SiteView.TALL_PROPS.has(nm):
			tall.append(nm)
		else:
			small.append(nm)
	if tall.is_empty():
		tall = small
	if small.is_empty():
		small = tall
	var has_palm := pool.has("palm")
	var gn := FastNoiseLite.new()
	gn.seed = U.hash32("grove:" + String(plan.loc))
	gn.frequency = 0.13
	var salt := U.hash32("pprop:" + String(plan.loc))
	for i in coast.lvl.size():
		var c := coast.cell_of(i)
		var l := coast.level(c)
		if l == Coast.WATER or coast.is_forced(c):
			continue
		var h := Coast.ihash(c.x, c.y, salt) % 1000
		var low_n := 0
		var wet_n := 0
		for o in Coast.N4:
			var lv := coast.level(c + o)
			if lv == Coast.LOW:
				low_n += 1
			elif lv == Coast.WATER:
				wet_n += 1
		var nm := ""
		if l == Coast.HIGH:
			var shades := h < 430 and _shades_town(c)
			var gv := gn.get_noise_2d(float(c.x), float(c.y))
			if marks.size() and h < 7 and not shades:
				nm = marks[h % marks.size()]
			elif gv > 0.08 and h < 430 and not shades:
				nm = tall[h % tall.size()]
			elif has_palm and low_n > 0 and h < 120 and not shades:
				nm = "palm"
			elif gv > -0.2 and h < 80:
				nm = small[h % small.size()]
			elif h < 25:
				nm = small[h % small.size()]
			elif h > 955:
				nm = "tuft"
		elif wet_n > 0 and coast.openness[i] < 0.5 and h < 80:
			nm = "reeds"
		elif wet_n == 0 and h < 50:
			nm = "tuft"
		elif h > 985:
			nm = "driftwood"
		if nm == "":
			continue
		var pr := Art.prop(nm, rid)
		if pr.is_empty():
			continue
		var at := Art.iso(c.x, c.y) + Vector2(float(h % 7) - 3.0, float((h / 7) % 5) - 2.0 - coast.lift(c))
		_world_sprite(pr.tex, pr.anchor, at)
		if l == Coast.HIGH and (nm == "bush" or nm == "herb" or nm == "tuft" or nm == "mushroom") and h % 3 == 0:
			_meadow.append(at)
	for r in coast.rocks:
		var rp: Vector2 = r[0]
		var pr2 := Art.prop(String(r[1]), rid)
		if not pr2.is_empty():
			_world_sprite(pr2.tex, pr2.anchor, Art.iso(rp.x, rp.y) + Vector2(0, 1))


## Puffs of chimney smoke rising from a roof. The holder sits at the house's
## base so it y-sorts with the house; the emitter is offset up to the roof.
func _chimney_smoke(base: Vector2, roof: Vector2) -> void:
	var holder := Node2D.new()
	holder.position = base + Vector2(0, 1)
	world_sort.add_child(holder)
	var pt := CPUParticles2D.new()
	pt.position = roof
	pt.amount = 7
	pt.lifetime = 3.2
	pt.preprocess = 3.0
	pt.direction = Vector2(0.2, -1)
	pt.spread = 12.0
	pt.gravity = Vector2(3, -4)
	pt.initial_velocity_min = 5.0
	pt.initial_velocity_max = 8.0
	pt.scale_amount_min = 2.0
	pt.scale_amount_max = 3.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.85, 0.82, 0.55))
	ramp.set_color(1, Color(0.85, 0.85, 0.82, 0.0))
	pt.color_ramp = ramp
	pt.local_coords = false
	holder.add_child(pt)


## A sagging string of pennants or laundry between two points.
func _string_line(a: Vector2, b: Vector2, colors: Array, kind: String, seed_v: int) -> void:
	var n := StringLine.new()
	n.position = Vector2(roundf((a.x + b.x) * 0.5), roundf(maxf(a.y, b.y) + 34.0))
	n.a = a - n.position
	n.b = b - n.position
	n.colors = colors
	n.kind = kind
	n.seed_v = seed_v
	world_sort.add_child(n)


## A market stall: striped canopy on two posts over a counter.
func _stall(at: Vector2, color: Color) -> void:
	var n := Stall.new()
	n.position = at.round()
	n.color = color
	world_sort.add_child(n)


## A fishing-net drying rack on the quay.
func _net_rack(at: Vector2) -> void:
	var n := NetRack.new()
	n.position = at.round()
	world_sort.add_child(n)


func _moored_boat(at: Vector2) -> void:
	var back := SiteView.RowBoat.new()
	var front := SiteView.RowBoat.new()
	front.front = true
	back.position = at + Vector2(0, -SiteView.RowBoat.SORT_OFF)
	front.position = at + Vector2(0, SiteView.RowBoat.SORT_OFF)
	world_sort.add_child(back)
	world_sort.add_child(front)


## Terrain-tile column of the gangway.
func _entry_gx() -> int:
	var e = deck(0).entry
	return 2 * (int(deck(0).x0) + (int(e[0]) if e != null else 0))


## Townsfolk wander the quay (columns qa+1..qb-1, rows -5.5..-3.5).
func _tick_town(delta: float) -> void:
	if _port.is_empty():
		return
	for a in _town:
		var tm: float = a.get_meta("timer") - delta
		if tm <= 0.0 and not a.is_walking():
			var target := Art.iso(_rng.randf_range(float(_port.qa) + 1.0, float(_port.qb) - 1.0), _rng.randf_range(-5.5, -3.5))
			a.walk_path([[target, 8.0]], 26.0)
			tm = _rng.randf_range(3.0, 9.0)
			if _rng.randf() < 0.25:
				a.bubble(["dots", "coin", "music", "question"][_rng.randi() % 4], 2.0)
		a.set_meta("timer", tm)


# =========================================================== crew & pets
func _rebuild_lookups() -> void:
	_occ = Rules.occupancy(st.ship)
	_reach.clear()
	_portals.clear()
	_rest_cells.clear()
	_fac_world.clear()
	_level_lifts.clear()
	for d in Rules.interior_levels(st.ship):
		_level_lifts.append(deck_lift(d))
	for f in st.ship.facilities:
		if f.stowed:
			continue
		var vl := Rules.view_level(st.ship, int(f.deck))
		var fx0 := int(deck(int(f.deck)).x0)
		for c in Rules.fac_cells(f):
			_fac_world[Vector3i(vl, fx0 + c.x, c.y)] = true
	var start := Vector3i(-1, 0, 0)
	var d0 := deck(0)
	if d0.entry != null and Rules.walkable(st.ship, _occ, 0, int(d0.entry[0]), int(d0.entry[1])):
		start = Vector3i(0, int(d0.entry[0]), int(d0.entry[1]))
	else:
		for y in int(d0.h):
			for x in int(d0.w):
				if Rules.walkable(st.ship, _occ, 0, x, y):
					start = Vector3i(0, x, y)
					break
			if start.x >= 0:
				break
	if start.x < 0:
		_dress.clear()
		_dress_plan.clear()
		_dress_chores.clear()
		return
	# Undressed reach first: the dressing is laid out around it, then the
	# dressed cells are taken out of the walkable set.
	_dress.clear()
	_flood(start)
	_build_portals()
	_plan_dressing()
	if not _dress.is_empty():
		_reach.clear()
		_portals.clear()
		_flood(start)
		_build_portals()
	_plan_chores()
	for n in _reach:
		if not _portals.has(n):
			_rest_cells.append(n)
	_lookups_dirty = false


## Breadth-first reach from the gangway through walkable, undressed cells.
func _flood(start: Vector3i) -> void:
	var queue := [start]
	_reach[start] = true
	var qi := 0
	while qi < queue.size():
		var n: Vector3i = queue[qi]
		qi += 1
		for nb in Rules.links(st.ship, n.x, n.y, n.z):
			if not _reach.has(nb) and not _dress.has(nb) and Rules.walkable(st.ship, _occ, nb.x, nb.y, nb.z):
				_reach[nb] = true
				queue.append(nb)


## Interior dressing for every interior level (ShipDress.layout), from the
## undressed reach and portals. Routes must join every ladder approach,
## bulkhead door side and facility work-spot access; facility fronts stay
## clear so rooms are not walled in.
func _plan_dressing() -> void:
	_dress.clear()
	_dress_plan.clear()
	if Art.dressing.is_empty():
		return
	var hid := String(st.ship.hullId)
	for d in Rules.interior_levels(st.ship):
		var dk := deck(d)
		var free := {}
		for x in int(dk.w):
			for y in int(dk.h):
				if _reach.has(Vector3i(d, x, y)):
					free[Vector2i(x, y)] = true
		if free.is_empty():
			continue
		var portals := {}
		var goals := []
		var keep := {}
		for n in _portals:
			if n.x != d:
				continue
			var pc := Vector2i(n.y, n.z)
			portals[pc] = true
			var ap: Vector2i = _portals[n].approach
			goals.append(pc + ap)
		if dk.bulkhead != null:
			for y in int(dk.h):
				if Rules.is_door(dk, int(dk.bulkhead), y):
					var dc := Vector2i(int(dk.bulkhead), y)
					keep[dc] = true
					for o in [Vector2i(-1, 0), Vector2i(1, 0)]:
						keep[dc + o] = true
						goals.append(dc + o)
		for f in st.ship.facilities:
			if f.stowed or int(f.deck) != d:
				continue
			var acc := _fac_access(f)
			var meta := Art.facility_meta(String(f.id), int(f.get("rot", 0)))
			var any := false
			for sp in meta.get("spots", []):
				var a = _access_for_spot(f, sp, acc)
				if a != null:
					keep[Vector2i(a.y, a.z)] = true
					goals.append(Vector2i(a.y, a.z))
					any = true
			if not any and not acc.is_empty():
				var a0: Vector3i = acc.keys()[0]
				keep[Vector2i(a0.y, a0.z)] = true
				goals.append(Vector2i(a0.y, a0.z))
			for c in Rules.fac_cells(f):
				keep[c + Vector2i(1, 0)] = true
				keep[c + Vector2i(0, 1)] = true
		var plan := ShipDress.layout(dk, free, portals, goals, keep, "%s:%s" % [hid, String(dk.id)])
		_dress_plan[d] = plan
		for it in plan.items:
			_dress[Vector3i(d, int(it.x), int(it.y))] = it


## Where idle crew can lend a hand: the free cell in front of each dressing
## piece that has a chore (guns, pump, bench, cargo...).
func _plan_chores() -> void:
	_dress_chores.clear()
	var items: Dictionary = Art.dressing.get("items", {})
	for key in _dress:
		var it: Dictionary = _dress[key]
		var e: Dictionary = items.get(String(it.name), {})
		if not bool(e.get("chore", false)):
			continue
		var prefs := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]
		if int(it.rot) == 1:
			prefs = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0)]
		for o in prefs:
			var n := Vector3i(key.x, key.y + o.x, key.z + o.y)
			if _reach.has(n) and not _portals.has(n):
				_dress_chores.append({"node": n, "pos": ground(key.x, key.y, key.z), "name": String(it.name)})
				break


## Dressing sprites: floor runners and patches just above the floor pieces,
## shadows sliced per floor cell, the pieces themselves sorted like
## facility pieces, battens just in front of them, and lantern lights.
func _build_dressing() -> void:
	_dress_nodes.clear()
	var items: Dictionary = Art.dressing.get("items", {})
	for d in _dress_plan:
		var plan: Dictionary = _dress_plan[d]
		var dk := deck(d)
		var vl := Rules.view_level(st.ship, d)
		var up := Vector2(0, deck_lift(d))
		for fl in plan.floor:
			var pf := Art.dress_piece(Art.dressing.get(String(fl.set), {}).get(String(fl.key)))
			if pf.is_empty():
				continue
			var g := ground(d, int(fl.x), int(fl.y))
			_add_static(_sprite(pf.tex, g - up + pf.off, g + Vector2(0, -3.95)), vl)
		for it in plan.items:
			var e = items.get(String(it.name), {}).get("rot", {}).get(str(int(it.rot)))
			if e == null:
				continue
			var g := ground(d, int(it.x), int(it.y))
			var pi := Art.dress_piece(e)
			if not pi.is_empty():
				var s := _sprite(pi.tex, g - up + pi.off, g + Vector2(0, -2))
				_add_static(s, vl)
				_dress_nodes.append(s)
			for sh in e.get("shadow", []):
				var cx := int(it.x) + int(sh.cell[0])
				var cy := int(it.y) + int(sh.cell[1])
				if Rules.fixed_kind(dk, cx, cy) != "" or _portals.has(Vector3i(d, cx, cy)):
					continue
				var ps := Art.dress_piece(sh)
				if ps.is_empty():
					continue
				var g2 := ground(d, cx, cy)
				_add_static(_sprite(ps.tex, g2 - up + ps.off, g2 + Vector2(0, -3.9)), vl)
			for l in e.get("lights", []):
				_add_light(g - up + Vector2(float(l[0]), float(l[1])), String(l[2]), 0.5, vl)
		for fe in plan.fences:
			var pfe := Art.dress_piece(Art.dressing.get("fence", {}).get(String(fe.edge)))
			if pfe.is_empty():
				continue
			var g3 := ground(d, int(fe.x), int(fe.y))
			var sf := _sprite(pfe.tex, g3 - up + pfe.off, g3 + Vector2(0, -1.8))
			_add_static(sf, vl)
			_dress_nodes.append(sf)
	_apply_dress_fade()


## Dressing pieces fade while a facility, stair or door is being placed:
## they are scenery and never block placement.
func _apply_dress_fade() -> void:
	var a := 1.0 if mode == "view" else 0.35
	for n in _dress_nodes:
		if is_instance_valid(n):
			n.modulate.a = a


## Stair, ladder and hatch cells. Each is a solid fitting that crew may only
## step onto from one side (its approach) and cross to the other deck:
##   stair_foot - terrace stair on the lower open deck, rising toward `dir`
##                (world x); entered from the low end.
##   ladder     - ladder foot on the lower deck; the ladder leans toward -x.
##   hatch      - open hatch on the upper deck above a ladder.
func _build_portals() -> void:
	for s in st.ship.stairs:
		var lo_d := int(s.deck)
		var up_d := int(s.to)
		if lo_d < 0 or up_d < 0 or lo_d >= st.ship.decks.size() or up_d >= st.ship.decks.size():
			continue
		var lo := Vector3i(lo_d, int(s.x), int(s.y))
		var up := Vector3i(up_d, int(s.ux), int(s.y))
		var wx_lo := int(deck(lo_d).x0) + int(s.x)
		var wx_up := int(deck(up_d).x0) + int(s.ux)
		if Rules.is_open_deck(deck(lo_d)) and Rules.is_open_deck(deck(up_d)) and wx_lo != wx_up:
			var dir := signi(wx_up - wx_lo)
			_portals[lo] = {"kind": "stair_foot", "dir": dir, "lo": deck_lift(lo_d), "hi": deck_lift(up_d),
				"approach": Vector2i(-dir, 0)}
		else:
			_portals[lo] = {"kind": "ladder",
				"approach": _approach_side(lo, [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0)])}
			_portals[up] = {"kind": "hatch",
				"approach": _approach_side(up, [Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0)])}


## First side (cell offset) with a reachable neighbour on the same deck.
func _approach_side(n: Vector3i, prefs: Array) -> Vector2i:
	for o in prefs:
		if _reach.has(Vector3i(n.x, n.y + o.x, n.z + o.y)):
			return o
	return prefs[0]


## True if a same-deck step a -> b goes into or out of a portal cell from a
## side other than its approach (through the ladder, over the open hatch, or
## up the side of a stair).
func _blocked_step(a: Vector3i, b: Vector3i) -> bool:
	if a.x != b.x:
		return false
	var pb = _portals.get(b)
	if pb != null and Vector3i(b.x, b.y + pb.approach.x, b.z + pb.approach.y) != a:
		return true
	var pa = _portals.get(a)
	if pa != null and Vector3i(a.x, a.y + pa.approach.x, a.z + pa.approach.y) != b:
		return true
	return false


## Shortest node route from `from` to any goal. Routes that respect the
## portal approach sides are preferred; a layout that leaves no such route
## falls back to plain 4-way moves.
func _path(from: Vector3i, goals: Dictionary) -> Array:
	if goals.has(from):
		return [from]
	var r := _bfs(from, goals, true)
	if r.is_empty():
		r = _bfs(from, goals, false)
	return r


func _bfs(from: Vector3i, goals: Dictionary, strict: bool) -> Array:
	var prev := {from: from}
	var queue := [from]
	var qi := 0
	while qi < queue.size():
		var n: Vector3i = queue[qi]
		qi += 1
		for nb in Rules.links(st.ship, n.x, n.y, n.z):
			if prev.has(nb) or not _reach.has(nb):
				continue
			if strict and _blocked_step(n, nb):
				continue
			prev[nb] = n
			if goals.has(nb):
				var out := [nb]
				var c: Vector3i = nb
				while c != from:
					c = prev[c]
					out.push_front(c)
				return out
			queue.append(nb)
	return []


## Where an actor stands on a node: [ground, lift]. Portal cells use the
## point where the climb starts (ladder foot, hatch rim, middle of a stair).
func _node_point(n: Vector3i) -> Array:
	var g := ground(n.x, n.y, n.z)
	var p = _portals.get(n)
	if p != null:
		match String(p.kind):
			"stair_foot":
				return [g, (float(p.lo) + float(p.hi)) * 0.5]
			"ladder":
				return [g + siso(LADDER_FOOT_U, 0.0), deck_lift(n.x)]
			"hatch":
				return [g + siso(LADDER_TOP_U, 0.0), deck_lift(n.x)]
	return [g, deck_lift(n.x)]


## Walk points for a node route (excluding its first node). Terrace stairs
## get their low and high edges as extra points so that the feet follow
## the stair surface instead of cutting through it.
func _route_points(route: Array) -> Array:
	var pts := []
	for k in range(1, route.size()):
		var a: Vector3i = route[k - 1]
		var b: Vector3i = route[k]
		var pa = _portals.get(a)
		var pb = _portals.get(b)
		if a.x == b.x:
			if pa != null and pa.kind == "stair_foot":
				pts.append(_stair_edge(a, pa, false))
			if pb != null and pb.kind == "stair_foot":
				pts.append(_stair_edge(b, pb, false))
		else:
			if pa != null and pa.kind == "stair_foot":
				pts.append(_stair_edge(a, pa, true))
			elif pb != null and pb.kind == "stair_foot":
				pts.append(_stair_edge(b, pb, true))
		pts.append(_node_point(b))
	return pts


## Low (far) or high (landing) edge of a terrace stair cell on its surface.
func _stair_edge(n: Vector3i, p: Dictionary, top: bool) -> Array:
	var half := 0.5 * float(p.dir) * (1.0 if top else -1.0)
	return [ground(n.x, n.y, n.z) + siso(half, 0.0), float(p.hi) if top else float(p.lo)]


## A reachable cell for idling or spawning (never a stair, ladder or hatch).
func _random_cell() -> Vector3i:
	var pool: Array = _rest_cells if not _rest_cells.is_empty() else _reach.keys()
	if pool.is_empty():
		return Vector3i(-1, 0, 0)
	return pool[_rng.randi() % pool.size()]


## Reachable node whose walk point is closest to where the actor is drawn.
func _nearest_node(a: Actor) -> Vector3i:
	var best := Vector3i(-1, 0, 0)
	var bd := INF
	for n in _reach:
		var pt := _node_point(n)
		var dl := a.lift - float(pt[1])
		var dd := a.position.distance_squared_to(pt[0]) + 4.0 * dl * dl
		if dd < bd:
			bd = dd
			best = n
	return best


func _fac_sig(f: Dictionary) -> String:
	return "%s:%d:%d:%d:%d" % [str(f.uid), int(f.deck), int(f.x), int(f.y), int(f.get("rot", 0))]


## True if the actor is not standing on the walk point of node n.
func _off_node(a: Actor, n: Vector3i) -> bool:
	var pt := _node_point(n)
	return a.position.distance_to(pt[0]) > 0.5 or absf(a.lift - float(pt[1])) > 0.5


func _look_sig(m: Dictionary) -> String:
	return "%s|%s|%s" % [m.classId, str(m.equipment.weapon), str(m.injured)]


func _sync_crew() -> void:
	var seen := {}
	for m in st.crew:
		seen[m.id] = true
		var a: Actor = _actors.get(m.id)
		if a != null and a.get_meta("look") != _look_sig(m):
			a.queue_free()
			_actors.erase(m.id)
			_brains.erase(m.id)
			a = null
		if a == null:
			a = Actor.new()
			a.setup_puppet(Art.crew_look(m))
			a.key = String(m.id)
			a.set_meta("look", _look_sig(m))
			a.arrived.connect(_on_arrived.bind(m.id))
			a.surface_moved.connect(_apply_actor_surface.bind(a))
			sort.add_child(a)
			_actors[m.id] = a
			var start := _random_cell()
			_brains[m.id] = {"node": start, "state": "", "timer": _rng.randf_range(0.0, 0.6), "spot": null, "fac": null, "exit_pts": []}
			if start.x >= 0:
				var pt := _node_point(start)
				a.position = pt[0]
				a.lift = pt[1]
			a.face(Vector2(1 if _rng.randf() < 0.5 else -1, 1))
	for id in _actors.keys():
		if not seen.has(id):
			_actors[id].queue_free()
			_actors.erase(id)
			_brains.erase(id)
	for id in _brains:
		_brains[id].timer = min(_brains[id].timer, 0.4)


func _sync_pets() -> void:
	var seen := {}
	for p in st.pets:
		var asg = p.get("assignment")
		if asg != null and asg.kind == "explorer":
			continue
		seen[p.id] = true
		var key := Art.pet_key(p)
		var a: Actor = _pets.get(p.id)
		if a != null and a.get_meta("key") != key:
			a.queue_free()
			_pets.erase(p.id)
			a = null
		if a == null:
			var info := Art.creature_info(key)
			if info.is_empty():
				continue
			a = Actor.new()
			a.setup_creature(info)
			a.set_meta("key", key)
			a.set_meta("timer", _rng.randf_range(0.2, 2.0))
			a.surface_moved.connect(_apply_actor_surface.bind(a))
			sort.add_child(a)
			_pets[p.id] = a
			var c := _random_cell()
			a.set_meta("node", c)
			if c.x >= 0:
				var pt := _node_point(c)
				a.position = pt[0] + Vector2(_rng.randf_range(-4, 4), 0)
				a.lift = pt[1]
		a.set_meta("pet", p)
	for id in _pets.keys():
		if not seen.has(id):
			_pets[id].queue_free()
			_pets.erase(id)


func _is_night() -> bool:
	return _hour >= 22 or _hour < 6


func _fac_by_uid(uid: Variant) -> Variant:
	for f in st.ship.facilities:
		if f.uid == uid:
			return f
	return null


func _first_fac(ids: Array) -> Variant:
	for id in ids:
		for f in st.ship.facilities:
			if f.id == id and not f.stowed and _fac_access(f).size() > 0:
				return f
	return null


## Walkable reachable cells next to a facility footprint (stair, ladder
## and hatch cells only if there is no other side to work from).
func _fac_access(f: Dictionary) -> Dictionary:
	var out := {}
	var portal := {}
	var d := int(f.deck)
	for c in Rules.fac_cells(f):
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := Vector3i(d, c.x + o.x, c.y + o.y)
			if _reach.has(n):
				if _portals.has(n):
					portal[n] = true
				else:
					out[n] = true
	return out if not out.is_empty() else portal


## Access cell a worker uses for a spot: the one nearest to it, so that the
## final step onto the spot does not cross the fitting. Ties prefer the
## front sides (+x/+y), where a climb is not hidden behind the fitting.
func _access_for_spot(f: Dictionary, s: Array, access: Dictionary) -> Variant:
	var sx := float(f.x) + float(s[0])
	var sy := float(f.y) + float(s[1])
	var order := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	if String(s[3]) == "y":
		order = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	var best: Variant = null
	var best_d := INF
	for n in access:
		var dx := float(n.y) - sx
		var dy := float(n.z) - sy
		var side := Vector2i(int(signf(dx)), 0) if absf(dx) >= absf(dy) else Vector2i(0, int(signf(dy)))
		var rank := order.find(side)
		var dist := dx * dx + dy * dy + 0.01 * float(rank if rank >= 0 else 4)
		if dist < best_d:
			best_d = dist
			best = n
	return best


func _spot_for(f: Dictionary, worker_index: int) -> Variant:
	var meta := Art.facility_meta(String(f.id), int(f.get("rot", 0)))
	var spots: Array = meta.get("spots", [])
	if spots.is_empty():
		return null
	var s: Array = spots[worker_index % spots.size()]
	var z := float(s[2])
	var d := int(f.deck)
	var g := ground(d, int(f.x) + float(s[0]), int(f.y) + float(s[1]))
	var extra := 3.0 * (z - 1.0) if z > 0.0 else 0.0
	var fp := Rules.footprint(f)
	var center := ground(d, int(f.x) + (fp.x - 1) * 0.5, int(f.y) + (fp.y - 1) * 0.5)
	var face_dir := center - g
	if face_dir.length() < 2.0:
		face_dir = Vector2(-1, -1) if String(s[3]) == "x" else Vector2(1, -1)
	return {"ground": g, "lift": deck_lift(d) + extra, "face": face_dir, "def": s}


## Points from an access node onto a spot and back off it. Raised spots
## (the lookout nest) are climbed straight up at the edge of the fitting
## instead of floating diagonally through it.
func _spot_moves(access: Vector3i, spot: Dictionary) -> Dictionary:
	var a := _node_point(access)
	var ga: Vector2 = a[0]
	var la: float = a[1]
	var gs: Vector2 = spot.ground
	var ls: float = spot.lift
	if ls - la <= 2.0:
		return {"enter": [[gs, ls]], "exit": []}
	var edge := ga.lerp(gs, 0.5)
	return {"enter": [[edge, la], [edge, ls], [gs, ls]], "exit": [[edge, ls], [edge, la]]}


func _think(id: Variant) -> void:
	var a: Actor = _actors.get(id)
	var br: Dictionary = _brains[id]
	if a == null:
		return
	if br.node.x < 0 or not _reach.has(br.node):
		br.node = _random_cell()
		br.exit_pts = []
		if br.node.x < 0:
			br.timer = 2.0
			return
		var pt := _node_point(br.node)
		a.position = pt[0]
		a.lift = pt[1]
	var m = Rules.member(st, id)
	if m == null:
		return
	var night := _is_night()
	var want := "wander"
	var target_fac: Variant = null
	if m.injured:
		target_fac = _first_fac(["recovery_room", "infirmary", "crew_quarters"])
		want = "rest"
	elif night:
		target_fac = _first_fac(["crew_quarters", "captains_cabin"])
		want = "sleep"
	elif m.jobFacilityUid != null:
		var f = _fac_by_uid(m.jobFacilityUid)
		if f != null and not f.stowed and _fac_access(f).size() > 0:
			target_fac = f
			want = "work"
	if want == "work" and br.state == "work" and br.fac == target_fac.uid:
		br.timer = _rng.randf_range(6.0, 12.0)
		if _rng.randf() < 0.18:
			a.bubble(["music", "dots", "sweat"][_rng.randi() % 3], 1.8)
		return
	if (want == "sleep" or want == "rest") and br.state == want:
		br.timer = 8.0
		return
	if br.state == "work" and br.fac != null:
		_set_working(br.fac, false)
	if br.state == "sleep" and br.fac != null:
		_set_working(br.fac, false)
	br.state = "walk"
	br.fac = null
	var spot: Variant = null
	var goals := {}
	if target_fac != null:
		goals = _fac_access(target_fac)
	var chore: Variant = null
	if goals.is_empty():
		want = "wander"
		chore = _pick_chore(id, br.node)
		if chore != null:
			want = "chore"
			goals[chore.node] = true
		else:
			var c := _random_cell()
			if c.x >= 0:
				goals[c] = true
	elif want != "wander":
		var idx := 0
		for o in st.crew:
			if o.id == id:
				break
			if o.jobFacilityUid == target_fac.uid or ((want == "sleep" or want == "rest") and o.injured == m.injured):
				idx += 1
		spot = _spot_for(target_fac, idx)
	var route := []
	if spot != null:
		var acc = _access_for_spot(target_fac, spot.def, goals)
		if acc != null:
			route = _path(br.node, {acc: true})
	if route.is_empty():
		route = _path(br.node, goals)
	if route.is_empty():
		br.timer = 1.5
		br.state = ""
		a.play("idle")
		return
	# Off a work spot first (down from a raised one), back onto the node,
	# then along the route.
	var pts := []
	pts.append_array(br.get("exit_pts", []))
	if not pts.is_empty() or _off_node(a, br.node):
		pts.append(_node_point(br.node))
	br.exit_pts = []
	pts.append_array(_route_points(route))
	var dest: Vector3i = route[-1]
	if spot != null:
		var mv := _spot_moves(dest, spot)
		pts.append_array(mv.enter)
		br.exit_pts = mv.exit
		br.spot_sig = _fac_sig(target_fac)
	elif target_fac != null and want != "wander":
		var center := surface(int(target_fac.deck), int(target_fac.x), int(target_fac.y))
		spot = {"face": center - ground(dest.x, dest.y, dest.z)}
	elif chore != null:
		spot = {"face": Vector2(chore.pos) - ground(dest.x, dest.y, dest.z)}
		br.chore = chore.name
	br.node = dest
	br.goal = want
	br.goal_fac = target_fac.uid if target_fac != null else null
	br.spot = spot
	# Set before walking: an empty walk arrives (and re-arms the timer) at once.
	br.timer = 999.0
	a.walk_path(pts, 30.0 if m.injured else 42.0)


func _on_arrived(id: Variant) -> void:
	var a: Actor = _actors.get(id)
	var br = _brains.get(id)
	if a == null or br == null:
		return
	var goal: String = br.get("goal", "wander")
	var spot = br.get("spot")
	if spot != null and spot.has("face"):
		a.face(spot.face)
	match goal:
		"work":
			br.state = "work"
			br.fac = br.goal_fac
			a.play("work")
			_set_working(br.fac, true)
			br.timer = _rng.randf_range(6.0, 12.0)
		"sleep":
			br.state = "sleep"
			br.fac = br.goal_fac
			a.play("down")
			_set_working(br.fac, true)
			a.bubble("sleep", 6.0)
			br.timer = 8.0
		"rest":
			br.state = "rest"
			br.fac = br.goal_fac
			a.play("down")
			a.bubble("sweat", 3.0)
			br.timer = 8.0
		"chore":
			# Off-duty hands lend a hand at the stores, guns and bench.
			br.state = "chore"
			a.play("work")
			br.timer = _rng.randf_range(4.0, 8.0)
			if _rng.randf() < 0.3:
				a.bubble(["dots", "music", "sweat"][_rng.randi() % 3], 1.8)
		_:
			br.state = "idle"
			a.play("idle")
			br.timer = _rng.randf_range(2.0, 6.0)
			var r := _rng.randf()
			if r < 0.2:
				a.bubble(["music", "dots", "love", "question", "coin"][_rng.randi() % 5], 2.0)
			elif r < 0.3:
				a.play("cheer")


## A chore spot for an off-duty hand (about 40% of idle wanders on a ship
## with dressing): preferably on the hand's own level and never one another
## hand is already heading to.
func _pick_chore(id: Variant, node: Vector3i) -> Variant:
	if _dress_chores.is_empty() or _rng.randf() >= 0.4:
		return null
	var taken := {}
	for oid in _brains:
		if oid != id:
			taken[_brains[oid].node] = true
	var same := []
	var other := []
	for ch in _dress_chores:
		if taken.has(ch.node) or not _reach.has(ch.node):
			continue
		if node.x >= 0 and ch.node.x == node.x:
			same.append(ch)
		else:
			other.append(ch)
	var pool := same if not same.is_empty() and (other.is_empty() or _rng.randf() < 0.7) else other
	if pool.is_empty():
		return null
	return pool[_rng.randi() % pool.size()]


func _tick_pets(delta: float) -> void:
	for id in _pets:
		var a: Actor = _pets[id]
		var t: float = a.get_meta("timer") - delta
		if t <= 0.0 and not a.is_walking():
			t = _rng.randf_range(3.0, 7.0)
			var p: Dictionary = a.get_meta("pet")
			var asg = p.get("assignment")
			var goal := Vector3i(-1, 0, 0)
			var near_owner: Actor = null
			if asg != null and asg.kind == "companion" and _actors.has(asg.target) and _brains.has(asg.target):
				goal = _brains[asg.target].node
				near_owner = _actors[asg.target]
			elif asg != null and asg.kind == "helper":
				var f = _fac_by_uid(asg.target)
				if f != null and not f.stowed:
					var acc := _fac_access(f).keys()
					if not acc.is_empty():
						goal = acc[_rng.randi() % acc.size()]
			if goal.x < 0 or not _reach.has(goal):
				goal = _random_cell()
			if goal.x >= 0:
				_walk_pet(a, goal, near_owner)
				if _rng.randf() < 0.25:
					a.bubble(["love", "music"][_rng.randi() % 2], 1.6)
		a.set_meta("timer", t)


## Pets follow the same routes as crew (stairs, ladders, around fittings).
## Only a pet with no node or no route left hops straight to the goal.
func _walk_pet(a: Actor, goal: Vector3i, near_owner: Actor) -> void:
	var node: Vector3i = a.get_meta("node", Vector3i(-1, 0, 0))
	var route: Array = _path(node, {goal: true}) if _reach.has(node) else []
	a.set_meta("node", goal)
	if route.is_empty():
		var pt := _node_point(goal)
		a.position = pt[0]
		a.lift = pt[1]
		a.fade_in(0.2)
		return
	var pts := []
	if _off_node(a, node):
		pts.append(_node_point(node))
	pts.append_array(_route_points(route))
	if near_owner != null and not _portals.has(goal):
		# Settle a little in front of the owner's node, inside the cell.
		var end := _node_point(goal)
		pts.append([end[0] + Vector2(_rng.randf_range(-10, 10), _rng.randf_range(2, 6)), end[1]])
	if pts.is_empty():
		return
	a.walk_path(pts, 30.0)


# ============================================================ day & night
func _apply_daylight() -> void:
	_hour = int(st.envelope.gameClock) % 24 if context != "title" else 19
	var c := Color.WHITE
	var e := 0.15
	if _hour >= 22 or _hour < 5:
		c = Color(0.46, 0.5, 0.74)
		e = 1.0
	elif _hour < 7:
		c = Color(0.86, 0.78, 0.82)
		e = 0.6
	elif _hour >= 20:
		c = Color(0.62, 0.6, 0.84)
		e = 0.85
	elif _hour >= 18:
		c = Color(1.0, 0.84, 0.72)
		e = 0.45
	var below := view_level > 0
	if below:
		# Below decks the lanterns are always lit and the light is warmer.
		c = c.lerp(Color(0.9, 0.8, 0.72), 0.45)
		e = maxf(e, 0.75)
	canvas_mod.color = c
	var world_tint := Color(0.72, 0.78, 0.9) if below else Color.WHITE
	for layer in [sea, land_ground, land_band, land_low, land_sides, world_sort, foam_root, _coast_foam]:
		if layer != null:
			layer.modulate = world_tint
	for l in _lights:
		if is_instance_valid(l.node):
			l.node.energy = e
			l["on"] = e > 0.2
	# Lit windows: shown from dusk, at full strength at night, with the night
	# tint divided back out so they stay warm and bright.
	var lit_a := clampf((e - 0.3) / 0.5, 0.0, 1.0)
	var undo := Color(1.0 / maxf(c.r * world_tint.r, 0.2), 1.0 / maxf(c.g * world_tint.g, 0.2), 1.0 / maxf(c.b * world_tint.b, 0.2), lit_a)
	for w in _windows:
		if is_instance_valid(w):
			w.visible = lit_a > 0.0
			w.modulate = undo
	ambience.night = _hour >= 20 or _hour < 6
	ambience.cloud_alpha = 0.0 if below else 0.1
	ambience.glint_density = 0.0 if below else 1.0
	_apply_light_visibility()


func _apply_light_visibility() -> void:
	for l in _lights:
		if not is_instance_valid(l.node):
			continue
		var v: int = int(l.get("view", -1))
		l.node.visible = bool(l.get("on", true)) and (v < 0 or v == view_level)


## Shows the hull, rig, fittings, facilities and FX of the current view
## level only; sails are set while under way.
func _apply_visibility() -> void:
	if st.is_empty():
		return
	var set_sails := context != "port" or _sail_t >= 0.0
	var show_rig := bool(Settings.get_value("showRoofs"))
	for n in _statics:
		if not is_instance_valid(n):
			continue
		var vis: bool = int(n.get_meta("view", 0)) == view_level
		var layer := String(n.get_meta("layer", ""))
		if layer == "rig_set":
			vis = vis and set_sails
		elif layer == "rig_furled":
			vis = vis and not set_sails
		# A null default counts as "no default" in Godot 4, so check first:
		# most statics (hull, rails, rig, lamps) are not facility pieces.
		var fu = n.get_meta("fac") if n.has_meta("fac") else null
		if fu != null:
			if _facs.has(fu):
				var working: bool = _facs[fu].working
				vis = vis and (String(n.get_meta("state", "idle")) == "work") == working
			else:
				Diag.once("ship_fac_piece", "facility piece %s has no facility entry (uid %s)" % [n.name, str(fu)])
		n.visible = vis
		if layer.begins_with("rig") or layer == "rope":
			n.modulate.a = 1.0 if show_rig else 0.12
	for e in _facs.values():
		for fxn in e.fx:
			fxn.visible = e.working and int(e.view) == view_level
	for c in fx_root.get_children():
		if c.has_meta("always"):
			c.visible = int(c.get_meta("view", 0)) == view_level
	_apply_light_visibility()
	_apply_actor_visibility()


## Crew and pets are drawn only on the level their feet are on, with a
## short fade when they come up or down onto the shown level, and sorted by
## their deck depth key (see depth_key).
func _apply_actor_visibility() -> void:
	for group in [_actors, _pets]:
		for id in group:
			_apply_actor_surface(group[id])


## The parent view processes before its Actor children. Refresh again when
## an actor finishes a movement step, so its floor key and ladder visibility
## describe the same contact point that will actually be rendered. Keeping
## the previous frame's bias can put a walking actor behind the floor of the
## cell it has just entered; lift changes can likewise expose the wrong deck.
func _apply_actor_surface(a: Actor) -> void:
	var lv := _lift_view(a.lift)
	var was: int = a.get_meta("lv", lv)
	a.set_meta("lv", lv)
	var vis := lv == view_level
	if vis and not a.visible and was != lv:
		a.fade_in(0.15)
	a.visible = vis
	if vis:
		a.depth_bias = deck_depth_y(a.position, lv) - a.position.y


func _apply_rig() -> void:
	_apply_visibility()


func toggle_sails() -> void:
	Settings.set_value("showRoofs", not bool(Settings.get_value("showRoofs")))
	_apply_visibility()


# =============================================================== camera
func _center_camera() -> void:
	var b: Dictionary = _hull.bounds
	var c := siso((float(b.minGx) + float(b.maxGx)) * 0.5, (float(b.minGy) + float(b.maxGy)) * 0.5) + Vector2(0, -40)
	if context == "port":
		c += Vector2(40, -40)
	cam.position = c
	_zoom_i = 0
	cam.zoom = Vector2.ONE * ZOOMS[_zoom_i]


func zoom_step(dir: int, at_mouse := true) -> void:
	var ni := clampi(_zoom_i + dir, 0, ZOOMS.size() - 1)
	if ni == _zoom_i:
		return
	var before := get_global_mouse_position()
	_zoom_i = ni
	cam.zoom = Vector2.ONE * ZOOMS[_zoom_i]
	if at_mouse:
		var after := get_global_mouse_position()
		cam.position += before - after
	_clamp_cam()


## Fits the current level into the part of the screen the HUD leaves free:
## the largest zoom that shows the whole level, centred in that area.
func fit_view() -> void:
	var r := _level_rect(view_level)
	if r.size.x < 1.0 or r.size.y < 1.0:
		_center_camera()
		return
	var vp := get_viewport_rect().size
	var free := free_screen if free_screen.size.x > 64.0 and free_screen.size.y > 64.0 else Rect2(Vector2.ZERO, vp)
	var zi := 0
	for i in ZOOMS.size():
		var zf: float = ZOOMS[i]
		if r.size.x * zf <= free.size.x - 8.0 and r.size.y * zf <= free.size.y - 8.0:
			zi = i
	_zoom_i = zi
	var z: float = ZOOMS[zi]
	cam.zoom = Vector2.ONE * z
	# The camera centre is drawn at the viewport centre.
	cam.position = r.get_center() - (free.get_center() - vp * 0.5) / z
	_clamp_cam()


## Bounding box (view space) of the hull and fittings drawn on level `k`,
## without the rig.
func _level_rect(k: int) -> Rect2:
	var inv := get_global_transform().affine_inverse()
	var r := Rect2()
	var any := false
	for n in _deck_nodes:
		if not is_instance_valid(n) or not (n is Sprite2D) or int(n.get_meta("view", 0)) != k:
			continue
		var sp := n as Sprite2D
		if sp.texture == null:
			continue
		var rr: Rect2 = (inv * sp.get_global_transform()) * sp.get_rect()
		r = rr if not any else r.merge(rr)
		any = true
	return r


func _clamp_cam() -> void:
	var r := _bounds.grow(CAM_MARGIN)
	cam.position.x = clampf(cam.position.x, r.position.x, r.end.x)
	cam.position.y = clampf(cam.position.y, r.position.y, r.end.y)


func zoom_label() -> String:
	var z: float = ZOOMS[_zoom_i]
	return "x%d" % int(z) if z >= 1.0 else "x1/%d" % int(round(1.0 / z))


# =============================================================== frame
func _process(delta: float) -> void:
	if st.is_empty():
		return
	_t += delta
	var pan := Vector2(Input.get_axis("pan_left", "pan_right"), Input.get_axis("pan_up", "pan_down"))
	if pan != Vector2.ZERO and _keyboard_free():
		cam.position += pan * 240.0 * delta / cam.zoom.x
		_clamp_cam()
	if context != "port":
		ship_root.position.y = round(sin(_t * 1.4) * 1.5)
	else:
		ship_root.position.y = round(sin(_t * 0.9) * 0.6)
	var moving := _under_way() and coast == null
	_sail_fx.active = moving
	ambience.drift = SAIL_DRIFT if moving else Vector2.ZERO
	if moving:
		_advance_sea(delta)
	_tick_passing(delta)
	if _sail_t >= 0.0:
		_sail_t += delta
		if _sail_t >= _sail_len:
			_sail_t = -1.0
			_apply_visibility()
			sailing_done.emit()
	for id in _brains:
		var br: Dictionary = _brains[id]
		br.timer -= delta
		if br.timer <= 0.0 and _actors.has(id) and not _actors[id].is_walking():
			_think(id)
	_tick_pets(delta)
	_tick_town(delta)
	_apply_actor_visibility()
	_update_hover()


func _keyboard_free() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f == null or not (f is LineEdit or f is TextEdit)


func _sea_base() -> Vector2:
	return _sea_origin


## Plays a short "under way" sequence: sails set, wake, moving sea.
func start_sailing(secs := 2.6) -> void:
	_sail_len = secs
	_sail_t = 0.0
	# A couple of rocks are already in sight when the ship gets under way.
	if coast == null and _passing.is_empty():
		_spawn_passing(_rng.randf_range(120.0, 260.0))
		_spawn_passing(_rng.randf_range(-60.0, 80.0))
	_apply_visibility()


func skip_sailing() -> void:
	if _sail_t >= 0.0:
		_sail_t = _sail_len


func is_sailing() -> bool:
	return _sail_t >= 0.0


# ================================================================ input
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
			if mb.pressed:
				_drag = true
				_drag_moved = 0.0
			else:
				_drag = false
				if _drag_moved < 4.0 and mb.button_index == MOUSE_BUTTON_RIGHT:
					if mode != "view":
						cancel_mode()
					else:
						clear_selection()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _sail_t >= 0.0:
				skip_sailing()
			else:
				_click()
			get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion and _drag:
		var mm := ev as InputEventMouseMotion
		cam.position -= mm.relative / cam.zoom.x
		_drag_moved += mm.relative.length()
		_clamp_cam()
	elif ev.is_action_pressed("zoom_in"):
		zoom_step(1, false)
	elif ev.is_action_pressed("zoom_out"):
		zoom_step(-1, false)
	elif ev.is_action_pressed("deck_next"):
		cycle_deck()
		get_viewport().set_input_as_handled()
	elif ev is InputEventKey and ev.pressed and not ev.echo and (ev.keycode == KEY_PAGEDOWN or ev.keycode == KEY_PAGEUP):
		level_step(1 if ev.keycode == KEY_PAGEDOWN else -1)
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("toggle_sails"):
		toggle_sails()
	elif ev.is_action_pressed("rotate") and (mode == "build" or mode == "move"):
		place_rot = 1 - place_rot
		_update_ghost()
		mode_changed.emit(mode, _mode_text())
	elif ev.is_action_pressed("cancel") and mode != "view":
		cancel_mode()
		get_viewport().set_input_as_handled()


func _mouse_ship() -> Vector2:
	return ship_root.to_local(get_global_mouse_position())


func _actor_at(p: Vector2) -> Variant:
	var best: Variant = null
	var best_y := -INF
	for id in _actors:
		var a: Actor = _actors[id]
		if not a.visible:
			continue
		if a.pick_rect().has_point(p) and a.position.y > best_y:
			best = id
			best_y = a.position.y
	return best


func _click() -> void:
	var p := _mouse_ship()
	match mode:
		"build", "move":
			var c := _placement_cell()
			if c.x < 0:
				return
			var res: Dictionary
			if mode == "build":
				res = Actions.build_facility(Game.state, place_fid, c.x, c.y, c.z, place_rot)
			else:
				res = Actions.move_facility(Game.state, place_uid, c.x, c.y, c.z, place_rot)
			if Game.act(res):
				var was := mode
				cancel_mode()
				if was == "move":
					select_facility(place_uid)
		"stair":
			var c2 := pick_cell(p)
			if c2.x >= 0 and _stair_slot_ok(c2):
				if Game.act(Actions.place_stair(Game.state, c2.x, c2.y, c2.z)):
					_update_mode_marks()
		"door":
			var c3 := pick_cell(p)
			if c3.x >= 0 and deck(c3.x).bulkhead != null and int(deck(c3.x).bulkhead) == c3.y:
				if Game.act(Actions.toggle_door(Game.state, c3.x, c3.z)):
					_update_mode_marks()
		_:
			var id = _actor_at(p)
			if id != null:
				_select("crew", id)
				var a: Actor = _actors[id]
				a.bubble(["alert", "music", "love"][_rng.randi() % 3], 1.2)
				return
			var c4 := pick_cell(p)
			if c4.x >= 0:
				var uid = _occ.get("%d:%d:%d" % [c4.x, c4.y, c4.z])
				if uid != null:
					_select("facility", uid)
					return
				for si in st.ship.stairs.size():
					var s = st.ship.stairs[si]
					if (int(s.deck) == c4.x and int(s.x) == c4.y and int(s.y) == c4.z) or (int(s.to) == c4.x and int(s.ux) == c4.y and int(s.y) == c4.z):
						_select("stair", si)
						return
				var dk := deck(c4.x)
				if dk.bulkhead != null and int(dk.bulkhead) == c4.y:
					_select("bulkhead", [c4.x, c4.z])
					return
			var wp := get_global_mouse_position()
			for b in _buildings:
				if b.kind != "" and b.rect.has_point(wp):
					_select("building", b.kind)
					return
			clear_selection()


func _select(kind: String, payload: Variant) -> void:
	sel_kind = kind
	sel_payload = payload
	_refresh_selection()
	selected.emit(kind, payload)


func select_facility(uid: Variant) -> void:
	var f = _fac_by_uid(uid)
	if f != null and not f.stowed:
		set_view_level(Rules.view_level(st.ship, int(f.deck)))
	_select("facility", uid)


## Shows the level of a crew member or selects them.
func focus_crew(id: Variant) -> void:
	var br = _brains.get(id)
	if br != null and br.node.x >= 0:
		set_view_level(Rules.view_level(st.ship, br.node.x))
	_select("crew", id)


func clear_selection() -> void:
	if sel_kind == "":
		return
	sel_kind = ""
	sel_payload = null
	_refresh_selection()
	selected.emit("none", null)


func _refresh_selection() -> void:
	for n in _sel_nodes:
		n.queue_free()
	_sel_nodes.clear()
	for id in _actors:
		_actors[id].set_marker("")
	match sel_kind:
		"crew":
			if _actors.has(sel_payload):
				_actors[sel_payload].set_marker("iso_sel")
		"facility":
			var f = _fac_by_uid(sel_payload)
			if f != null and not f.stowed and Rules.view_level(st.ship, int(f.deck)) == view_level:
				for c in Rules.fac_cells(f):
					_mark(surface(int(f.deck), c.x, c.y), "iso_sel")
		"stair":
			if sel_payload < st.ship.stairs.size():
				var s = st.ship.stairs[sel_payload]
				if Rules.view_level(st.ship, int(s.deck)) == view_level:
					_mark(surface(int(s.deck), int(s.x), int(s.y)), "iso_sel")
				if Rules.view_level(st.ship, int(s.to)) == view_level:
					_mark(surface(int(s.to), int(s.ux), int(s.y)), "iso_sel")
		"bulkhead":
			var dk := deck(int(sel_payload[0]))
			if Rules.view_level(st.ship, int(sel_payload[0])) == view_level:
				_mark(surface(int(sel_payload[0]), int(dk.bulkhead), int(sel_payload[1])), "iso_sel")


func _mark(at: Vector2, name: String, into: Variant = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Art.ui_tex(name)
	s.position = at
	s.scale = MARK_SCALE
	overlay.add_child(s)
	if into == null:
		_sel_nodes.append(s)
	else:
		into.append(s)
	return s


# ============================================================ hover info
func _update_hover() -> void:
	var p := _mouse_ship()
	var c := pick_cell(p)
	if mode == "view" and c != _hover_cell:
		_hover_cell = c
		_hover_sprite.visible = c.x >= 0
		if c.x >= 0:
			_hover_sprite.position = surface(c.x, c.y, c.z)
	elif mode != "view" and c != _hover_cell:
		_hover_cell = c
		_hover_sprite.visible = false
		_update_ghost()
	var text := ""
	var id = _actor_at(p)
	if id != null:
		text = _crew_status(id)
	elif c.x >= 0:
		var uid = _occ.get("%d:%d:%d" % [c.x, c.y, c.z])
		if uid != null:
			var f = _fac_by_uid(uid)
			if f != null:
				text = I18n.t("fac.%s.name" % f.id) + "  " + I18n.t("ui.lv", {"n": f.level})
		elif _dress.has(c):
			text = I18n.t("dress.%s" % String(_dress[c].name))
		else:
			text = _portal_text(c)
	else:
		var wp := get_global_mouse_position()
		for b in _buildings:
			if b.kind != "" and b.rect.has_point(wp):
				text = I18n.t("port.visit", {"place": I18n.t("port.house") if b.kind == "house" else I18n.t("track.%s.name" % b.kind)})
				break
	if text != get_meta("hover_text", ""):
		set_meta("hover_text", text)
		hover_changed.emit(text)


## Hover text for a ladder foot, hatch or terrace stair: where it leads.
func _portal_text(c: Vector3i) -> String:
	var p = _portals.get(c)
	if p == null:
		return ""
	for s in st.ship.stairs:
		if int(s.y) != c.z:
			continue
		if int(s.deck) == c.x and int(s.x) == c.y:
			var key := "ship.stairs_up" if String(p.kind) == "stair_foot" else "ship.ladder_up"
			return I18n.t(key, {"deck": _deck_title(int(s.to))})
		if int(s.to) == c.x and int(s.ux) == c.y:
			return I18n.t("ship.hatch_down", {"deck": _deck_title(int(s.deck))})
	return ""


func _deck_title(d: int) -> String:
	var key := "deck.%s.title" % String(deck(d).id)
	return I18n.t(key) if I18n.raw(key) != null else I18n.t("deck.weather.title")


func _crew_status(id: Variant) -> String:
	var m = Rules.member(st, id)
	if m == null:
		return ""
	var line := I18n.crew_name(m) + " · " + I18n.t("class.%s.name" % m.classId) + " " + I18n.t("ui.lv", {"n": m.level})
	var br = _brains.get(id)
	var status := I18n.t("view.off_duty")
	if m.injured:
		status = I18n.t("view.injured")
	elif br != null and br.state == "sleep":
		status = I18n.t("view.sleeping")
	elif br != null and br.state == "work" and br.fac != null:
		var f = _fac_by_uid(br.fac)
		if f != null:
			status = I18n.t("view.working", {"facility": "fac.%s.name" % f.id})
	elif br != null and br.state == "chore":
		var chore_id := String(br.get("chore", "crates"))
		if I18n.raw("chore." + chore_id) != null:
			status = I18n.t("chore." + chore_id)
		else:
			status = I18n.t("view.chore", {"task": "dress." + chore_id})
	return line + "\n" + status


# ========================================================== edit modes
func can_edit() -> bool:
	return live and context == "port"


func begin_build(fid: String) -> void:
	mode = "build"
	place_fid = fid
	place_uid = null
	place_rot = 0
	clear_selection()
	_ensure_eligible_view(fid)
	_update_ghost()
	mode_changed.emit(mode, _mode_text())


func begin_move(uid: Variant) -> void:
	var f = _fac_by_uid(uid)
	if f == null:
		return
	mode = "move"
	place_fid = String(f.id)
	place_uid = uid
	place_rot = int(f.get("rot", 0))
	_ensure_eligible_view(place_fid)
	_update_ghost()
	mode_changed.emit(mode, _mode_text())


func begin_stair() -> void:
	mode = "stair"
	clear_selection()
	_update_mode_marks()
	mode_changed.emit(mode, _mode_text())


func begin_door() -> void:
	mode = "door"
	clear_selection()
	_update_mode_marks()
	mode_changed.emit(mode, _mode_text())


## Switches to the best level for a facility when the current one cannot
## hold it (management rooms go inside the hull, fittings on the open deck).
func _ensure_eligible_view(fid: String) -> void:
	for d in visible_decks():
		if Rules.zone_ok(deck(d), fid):
			return
	var pref: Array = Actions.preferred_decks(st.ship, fid)
	if not pref.is_empty():
		set_view_level(Rules.view_level(st.ship, int(pref[0])))
	elif Rules.zone_of(fid) == "deck":
		set_view_level(0)


func cancel_mode() -> void:
	mode = "view"
	place_fid = ""
	for c in _ghost.get_children():
		c.queue_free()
	for n in _mode_marks:
		n.queue_free()
	_mode_marks.clear()
	mode_changed.emit(mode, "")


func _mode_text() -> String:
	var lvl := I18n.t("view.deck", {"deck": focus_name()})
	match mode:
		"build":
			return lvl + " · " + I18n.t("ship.placing", {"facility": "fac.%s.name" % place_fid}) + " · " + I18n.t("ship.zone_" + Rules.zone_of(place_fid)) + " · " + I18n.t("ship.rotate") + " (R) · " + I18n.t("ship.cancel_hint")
		"move":
			return lvl + " · " + I18n.t("ship.move_hint", {"facility": "fac.%s.name" % place_fid}) + " · " + I18n.t("ship.rotate") + " (R) · " + I18n.t("ship.cancel_hint")
		"stair":
			return lvl + " · " + I18n.t("ship.stair_hint") + " · " + I18n.t("ship.level_keys") + " · " + I18n.t("ship.cancel_hint")
		"door":
			return lvl + " · " + I18n.t("ship.door_hint") + " · " + I18n.t("ship.cancel_hint")
	return ""


## Anchor cell for placement: the hovered cell is the footprint's first cell.
func _placement_cell() -> Vector3i:
	return pick_cell(_mouse_ship())


func _update_ghost() -> void:
	for c in _ghost.get_children():
		c.queue_free()
	if mode != "build" and mode != "move":
		return
	var c := _placement_cell()
	if c.x < 0:
		return
	var check := Rules.can_place(st.ship, place_fid, c.x, c.y, c.z, place_rot, place_uid)
	var fake := {"id": place_fid, "x": c.y, "y": c.z, "rot": place_rot}
	for cell in Rules.fac_cells(fake):
		var inside: bool = cell.x < int(deck(c.x).w) and cell.y < int(deck(c.x).h)
		var s := Sprite2D.new()
		s.texture = Art.ui_tex("iso_ok" if check.ok else "iso_bad")
		s.scale = MARK_SCALE
		s.position = surface(c.x, cell.x, cell.y)
		s.modulate.a = 1.0 if inside else 0.6
		_ghost.add_child(s)
	for p in Art.facility_pieces(place_fid, place_rot, false):
		var g := surface(c.x, c.y + p.cell.x, c.z + p.cell.y)
		var sp := Sprite2D.new()
		sp.centered = false
		sp.texture = p.tex
		sp.position = g + p.off
		if not check.ok:
			sp.modulate = Color(1, 0.55, 0.5)
		_ghost.add_child(sp)
	var reason := "" if check.ok else I18n.t(String(check.reasonKey))
	hover_changed.emit(reason)


func _stair_slot_ok(c: Vector3i) -> bool:
	var t = Rules.stair_target(st.ship, c.x, c.y, c.z)
	if t == null:
		return false
	return Rules.stair_at(st.ship, c.x, c.y, c.z) == null and Rules.stair_at(st.ship, int(t.to), int(t.ux), c.z) == null \
		and Rules.walkable(st.ship, _occ, c.x, c.y, c.z) and Rules.walkable(st.ship, _occ, int(t.to), int(t.ux), c.z) \
		and not Rules.is_entry(deck(int(t.to)), int(t.ux), c.z)


func _update_mode_marks() -> void:
	for n in _mode_marks:
		n.queue_free()
	_mode_marks.clear()
	if mode == "stair":
		for d in visible_decks():
			var dk := deck(d)
			for x in int(dk.w):
				for y in int(dk.h):
					var c := Vector3i(d, x, y)
					if _stair_slot_ok(c):
						_mark(surface(d, x, y), "iso_move", _mode_marks)
	elif mode == "door":
		for d in visible_decks():
			var dk := deck(d)
			if dk.bulkhead == null:
				continue
			for y in int(dk.h):
				var door := Rules.is_door(dk, int(dk.bulkhead), y)
				_mark(surface(d, int(dk.bulkhead), y), "iso_ok" if door else "iso_move", _mode_marks)


## Screen position (canvas coordinates) of a facility, for anchoring panels.
func facility_screen_pos(uid: Variant) -> Vector2:
	var f = _fac_by_uid(uid)
	if f == null:
		return Vector2.ZERO
	var p := ship_root.to_global(surface(int(f.deck), int(f.x), int(f.y)))
	return get_viewport().get_canvas_transform() * p


func actor_of(id: Variant) -> Actor:
	return _actors.get(id)


## Sagging line with pennants or laundry hung along it (port dressing).
class StringLine extends Node2D:
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var colors: Array = []
	var kind := "pennant"
	var seed_v := 0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if Engine.get_process_frames() % 6 == 0:
			queue_redraw()

	func _pt(f: float) -> Vector2:
		var sag := 7.0 if kind == "pennant" else 5.0
		return a.lerp(b, f) + Vector2(0, sag * 4.0 * f * (1.0 - f))

	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in 13:
			pts.append(_pt(float(i) / 12.0).round())
		draw_polyline(pts, Color(0.25, 0.2, 0.16, 0.9), 1.0)
		var n := maxi(3, int(a.distance_to(b) / 9.0))
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v
		for i in n:
			var f := (float(i) + 0.5) / float(n)
			var p := _pt(f).round()
			var c: Color = colors[i % colors.size()] if kind == "pennant" else colors[rng.randi() % colors.size()]
			var sway := roundf(sin(_t * 2.0 + float(i)) * 0.8)
			if kind == "pennant":
				draw_colored_polygon(PackedVector2Array([p + Vector2(-2.5, 0), p + Vector2(2.5, 0), p + Vector2(sway, 5)]), c)
			else:
				var w := float(rng.randi_range(3, 5))
				var h := float(rng.randi_range(4, 7))
				draw_rect(Rect2(p + Vector2(-w * 0.5 + sway * 0.5, 0), Vector2(w, h)), c)
				draw_rect(Rect2(p + Vector2(-w * 0.5 + sway * 0.5, h - 1), Vector2(w, 1)), c.darkened(0.2))


## Market stall: two posts, a counter and a striped canopy.
class Stall extends Node2D:
	var color := Color(0.85, 0.3, 0.25)

	func _draw() -> void:
		var wood := Color(0.45, 0.3, 0.18)
		var dark := Color(0.28, 0.18, 0.1)
		var w := 26.0
		var light := Color(0.95, 0.92, 0.85)
		# counter
		draw_rect(Rect2(-w * 0.5, -9, w, 6), wood)
		draw_rect(Rect2(-w * 0.5, -10, w, 1), wood.lightened(0.25))
		draw_rect(Rect2(-w * 0.5, -3, w, 1), dark)
		# posts
		draw_rect(Rect2(-w * 0.5, -26, 2, 23), dark)
		draw_rect(Rect2(w * 0.5 - 2, -26, 2, 23), dark)
		# canopy with stripes and a scalloped valance
		var top := -30.0
		for i in 6:
			var x := -w * 0.5 - 2 + i * (w + 4) / 6.0
			draw_rect(Rect2(x, top, (w + 4) / 6.0 + 0.5, 5), color if i % 2 == 0 else light)
		for i in 6:
			var x2 := -w * 0.5 - 2 + i * (w + 4) / 6.0
			draw_colored_polygon(PackedVector2Array([Vector2(x2, top + 5), Vector2(x2 + (w + 4) / 6.0, top + 5), Vector2(x2 + (w + 4) / 12.0, top + 7)]), color.darkened(0.15) if i % 2 == 0 else light.darkened(0.1))
		draw_rect(Rect2(-w * 0.5 - 2, top - 1, w + 4, 1), color.darkened(0.3))
		# goods on the counter
		for i in 4:
			draw_rect(Rect2(-w * 0.5 + 3 + i * 6, -13, 4, 3), [Color(0.85, 0.6, 0.25), Color(0.5, 0.7, 0.35), Color(0.8, 0.35, 0.3), Color(0.9, 0.85, 0.6)][i])


## Fishing net hung to dry between two poles.
class NetRack extends Node2D:
	func _draw() -> void:
		var pole := Color(0.36, 0.24, 0.14)
		var net := Color(0.55, 0.6, 0.5, 0.85)
		draw_rect(Rect2(-14, -24, 2, 24), pole)
		draw_rect(Rect2(12, -24, 2, 24), pole)
		draw_line(Vector2(-13, -23), Vector2(13, -23), pole, 1.0)
		for i in 7:
			var x := -12.0 + i * 4.0
			draw_line(Vector2(x, -22), Vector2(x + 2.0, -8.0 + 2.0 * sin(float(i))), net, 1.0)
		for j in 4:
			var y := -20.0 + j * 4.0
			draw_line(Vector2(-12, y), Vector2(12, y + 1.0), net, 1.0)
