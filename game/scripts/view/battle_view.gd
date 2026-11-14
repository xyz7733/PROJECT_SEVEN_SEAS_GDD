## The spatial battle: an isometric arena (for boarding fights the player's
## own weather deck, drawn from the real hull with an enemy ship lashed
## alongside; otherwise the region's ground for island, dungeon, wreck and
## arena fights) with the
## crew, their pets and the enemy waves as animated actors. The view runs the
## same deterministic simulation as the rules (Combat.step) for presentation,
## records the player's commands with Combat.issue and, at the end, commits
## the result through Actions.resolve_encounter, which replays the battle
## from the encounter spec and those commands.
class_name BattleView
extends Node2D

## Emitted once the battle has been committed (or failed to commit).
## `res` is the Actions result dictionary.
signal finished(res: Dictionary)
signal hover_changed(text: String)

const SPEEDS := [1.0, 2.0, 4.0]
const ZOOMS := [1.0, 2.0, 3.0]
const LANE_INDEX := {"front": 0, "center": 1, "rear": 2}
const ALLY_FACE := Vector2(1, 0.25)
const BOSS_RED := Color(0.96, 0.36, 0.3)
const ENEMY_FACE := Vector2(-1, 0.25)
## Swing style for each melee weapon kind (see BattleFx.Swing).
const MELEE_STYLE := {"blade": "slash", "cutlass": "slash", "ladle": "slash", "tool": "slash", "banner": "slash",
	"spear": "thrust", "trident": "thrust", "musket": "thrust", "fist": "punch", "kit": "punch", "shield": "bash",
	"staff": "bash", "wand": "bash", "book": "bash", "lantern": "bash", "bow": "bash", "gun": "bash", "whip": "lash", "claws": "claw"}
## Projectile for each ranged weapon kind (see BattleFx.Shot).
const SHOT_KIND := {"gun": "bullet", "musket": "bullet", "bow": "arrow", "staff": "orb", "wand": "orb", "book": "orb",
	"lantern": "orb", "trident": "orb", "kit": "vial"}
const SHOT_SPEED := {"bullet": 520.0, "arrow": 250.0, "orb": 290.0, "vial": 210.0, "spit": 230.0}
const SHOT_ARC := {"bullet": 0.0, "arrow": 22.0, "orb": 4.0, "vial": 26.0, "spit": 16.0}
## How long a drop lies on the field before it is collected (seconds at x1).
const DROP_SECS := 0.9
## Drops shown per fallen opponent; further shares ride on the last one.
const DROP_MAX := 6
## The battle log keeps a few recent lines; older ones are dimmer.
const LOG_LINES := 4
const LOG_FADE := [0.5, 0.66, 0.83, 1.0]
const LOG_SECS := 7.0
## Log width and the height it takes over the control bar (base px).
const LOG_W := 230.0
const LOG_H := 46.0
const LOG_TYPES := ["skill", "ko", "wave", "windup", "interrupt", "pet", "hazard", "encore", "end", "command", "heal", "stun"]

var enc: Dictionary = {}
var sim: Dictionary = {}
var rid := "dawnwater"
var arena := "island"
var boarding := false
var paused := false
var speed_i := 0
var cam: Camera2D
var sea: TileMapLayer
var land_sides: TileMapLayer
var land_low: TileMapLayer
var land_band: TileMapLayer
var land_ground: TileMapLayer
var stage: Node2D
var fx_root: Node2D
var canvas_mod: CanvasModulate
var ui: CanvasLayer
var ui_root: Control

var _acc := 0.0
var _t := 0.0
var _last_seq := 0
var _actors := {}
var _pets := {}
var _home := {}
var _units := {}
var _anim_tick := {}
var _dying := {}
var _ended := false
var _end_t := 0.0
var _committed := false
var _quiet := false
var _zoom_i := 1
var _drag := false
var _drag_moved := 0.0
var _shake := 0.0
var _hitstop := 0.0
var _rng := RandomNumberGenerator.new()
var _bounds := Rect2(-220, -120, 440, 240)
# Sea coverage: land cells, the sea layer alignment, the area already
# covered with sea tiles, and the flat deep-water underlay.
var _land := {}
## Land battles: the authored setting and its coast (null when boarding).
var scene: ArenaScene
var coast: Coast
var _foam: Node2D
var _sea_info: Dictionary = {}
var _sea_cover := Rect2()
var _underlay: Polygon2D
var _hover_uid: Variant = null
# Boarding on the real ship: our weather deck (deck 0), the enemy hull and
# its offset in ship cells (it lies off our far rail, behind the fight).
var _on_ship := false
var _ship_deck: Dictionary = {}
var _ship_occ: Dictionary = {}
## Boarding: world cells of deck fittings (sorted like ShipView fittings)
## and weather-deck cells holding a hatch or stair foot ("x:y", deck-local).
var _fit_cells: Dictionary = {}
var _portal_cells: Dictionary = {}
var _foe_hull := "starter"
var _foe_deck: Dictionary = {}
var _foe_off := Vector2.ZERO
var _night := false
## Ambient life around the arena (gulls, glints, cloud shadows).
var ambience: Ambience

# UI
var _title_label: Label
var _wave_label: Label
var _time_label: Label
var _status_label: Label
var _log_box: VBoxContainer
var _pause_btn: Button
var _speed_btns: Array = []
var _stance_btns := {}
var _prio_opt: OptionButton
var _focus_label: Label
var _retreat_btn: Button
var _skip_btn: Button
var _banner: Label
var _paused_panel: PanelContainer
var _strip_panel: PanelContainer
var _status_panel: PanelContainer
var _log_panel: VBoxContainer
var _float_root: Control
var _bar: PanelContainer
var _spoils_box: HBoxContainer
var _spoils_icon: TextureRect
var _spoils_label: Label

# --- settlement presentation
## Spoils plan (Settle.plan): the live drops show its shares.
var plan: Dictionary = {}
## Reopened from a save taken after the fight ended (report pending).
var restored := false
var report_mode := false
var _spoils_n := 0
var _dropped := {}
var _pending_drop := {}
var _coin_t := 0.0
# --- effects
var _weap := {}
var _status := {}
var _tele := {}
var _fade := {}
var _ko_wait := {}
var _hp_hold := {}
var _impact_at := {}
var _lunged := {}
# Cinematics: the opening shot, a boss's intro and the finishing blow.
var _cam_tw: Tween
var _cine_tw: Tween
var _cine_hold := false
var _cine_card: VBoxContainer
var _cine_name: Label
var _cine_sub: Label
var _letterbox: Array[ColorRect] = []
var _cine_layer: CanvasLayer
var _flash_rect: ColorRect
var _boss_bar: BossBar
var _boss_uid: Variant = null
var _boss_met := {}
var _last_ko: Variant = null
var _skipped := false
## HUD insets (base px) the fight framing keeps clear: the top bar and the
## navigation bar.
var _hud_top := 22.0
var _hud_bottom := 30.0


func _init() -> void:
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	sea = TileMapLayer.new()
	sea.z_index = -20
	add_child(sea)
	# Terrain as in SiteView (see Coast): cliff sides, low beach ground (4px
	# up), the top bands of raised faces, raised ground (8px up). The surf
	# foam sits between the sea and the sides.
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
	stage = Node2D.new()
	stage.y_sort_enabled = true
	add_child(stage)
	fx_root = Node2D.new()
	fx_root.z_index = 8
	add_child(fx_root)
	cam = Camera2D.new()
	cam.zoom = Vector2(2, 2)
	add_child(cam)
	_rng.seed = 11


func _ready() -> void:
	cam.make_current()
	get_viewport().size_changed.connect(_on_viewport_resized)


## A larger or wider window shows more of the world: add sea tiles if the
## camera could now see past them.
func _on_viewport_resized() -> void:
	if _sea_info.is_empty():
		return
	if not _sea_cover.encloses(_needed_sea_cover()):
		_fill_sea()
	_clamp_cam()


func _needed_sea_cover() -> Rect2:
	return Art.camera_cover(_bounds, get_viewport_rect().size, float(ZOOMS[0]))


## Sea on every non-land cell the camera can show (a screen-aligned
## rectangle around the camera bounds at the widest zoom), with shallows
## beside land. Cells that already hold a tile are kept.
func _fill_sea() -> void:
	if scene != null and scene.underground:
		return
	_sea_cover = _needed_sea_cover()
	for c in Art.cells_in_rect(_sea_cover):
		if _land.has(c) or (coast != null and coast.is_land(c)):
			continue
		var mc := Art.layer_cell(_sea_info, c.x, c.y)
		if sea.get_cell_source_id(mc) != -1:
			continue
		if coast != null:
			sea.set_cell(mc, 0, Art.water_tile(coast.water_name(c)))
			continue
		var near := false
		if not boarding:
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
				if _land.has(c + o):
					near = true
					break
		sea.set_cell(mc, 0, Vector2i(0, 1) if near else Vector2i(0, 0))


# ================================================================ setup
## Starts presenting the active encounter of the live state.
func start(state: Dictionary) -> void:
	enc = state.encounter
	var spec: Dictionary = enc.spec.duplicate(true)
	var ended = enc.get("ended")
	plan = ended.plan if ended != null and ended.get("plan") != null else Settle.plan(state, enc)
	sim = Combat.create(spec) if ended == null else Combat.run(spec, ended.commands)
	var def: Dictionary = enc.def
	var ctx: Dictionary = enc.context
	var loc_id = ctx.get("locationId") if ctx.get("locationId") else ctx.get("toId")
	var loc = C.location(String(loc_id)) if loc_id != null else null
	var reg_id = def.get("regionId")
	if reg_id == null or String(reg_id) == "":
		reg_id = loc.regionId if loc != null else "dawnwater"
	rid = String(reg_id)
	boarding = String(def.get("arena", "")) == "boarding"
	arena = "boarding" if boarding else (String(loc.type) if loc != null else "island")
	var sp := int(Settings.get_value("battleSpeed"))
	speed_i = maxi(0, SPEEDS.find(float(sp)))
	paused = bool(Settings.get_value("pauseAtEncounterStart"))
	_build_arena()
	Audio.scene("battle", String(loc.type) if loc != null else "", boarding)
	if _on_ship:
		Audio.play("ram")
	_build_ui()
	if ended != null:
		_restore()
		return
	_sync_units(true)
	_consume_log()
	_refresh_controls()
	fit_view()
	_open_shot()


## The save was taken after the fight ended but before its report was
## settled: show the final field (survivors in place, the fallen gone,
## the spoils already picked up) and hand straight over to the report.
func _restore() -> void:
	restored = true
	_quiet = true
	_sync_units(true)
	for ev in sim.log:
		_last_seq = maxi(_last_seq, int(ev.seq))
	for uid in _actors:
		var a: Actor = _actors[uid]
		var u = _units.get(uid)
		a.stop()
		a.position = _home[uid]
		if u != null and not u.alive:
			if u.side == "enemy":
				a.visible = false
			else:
				a.play("down")
				a.modulate = Color(0.8, 0.8, 0.85)
	for uid in _pets:
		_pets[uid].stop()
		_pets[uid].position = _home[uid] + Vector2(-16, 12)
	_quiet = false
	_ended = true
	_committed = true
	if String(sim.outcome) == "victory":
		for uid in plan.get("drops", {}):
			_dropped[uid] = true
			_spoils_n += plan.drops[uid].size()
		for uid in _actors:
			var u2 = _units.get(uid)
			if u2 != null and u2.alive and u2.side == "ally":
				_actors[uid].play("cheer")
	_update_spoils_chip()
	_refresh_controls()
	fit_view()
	finished.emit.call_deferred({"ok": true, "restored": true})


func _title_text() -> String:
	var ctx: Dictionary = enc.context
	match String(ctx.get("type", "")):
		"sea":
			return I18n.t("battle.title_sea", {"kind": "sea.%s.title" % ctx.kind, "location": "loc.%s.name" % ctx.toId})
		"legend":
			return I18n.t("battle.title_legend", {"region": "region.%s.name" % rid})
		_:
			return I18n.t("battle.title_room", {"room": "room.%s.name" % ctx.get("roomId", ""), "location": "loc.%s.name" % ctx.get("locationId", "")})


# ================================================================ arena
func _build_arena() -> void:
	var ts := Art.tileset(rid)
	for layer in [sea, land_ground, land_sides, land_low, land_band]:
		layer.tile_set = ts
	var info := Art.align_layer(sea)
	for layer in [land_ground, land_sides, land_low, land_band]:
		Art.align_layer(layer)
	land_low.position += Vector2(0, -float(Coast.LIFT[Coast.LOW]))
	land_ground.position += Vector2(0, -float(Coast.LIFT[Coast.HIGH]))
	_sea_info = info
	if _underlay == null:
		_underlay = Art.sea_underlay(rid)
		add_child(_underlay)
	var land := {}
	var tc := int(Game.state.envelope.gameClock) % 24 if Game.has_game() else 12
	_night = tc < 6 or tc >= 19
	_on_ship = boarding and _build_boarding()
	if ambience == null:
		ambience = Ambience.new()
		add_child(ambience)
	ambience.night = _night
	ambience.gull_target = 1
	ambience.whitecap_density = 0.6 if boarding else 0.0
	ambience.fish_every = Vector2(0, 0)
	if _on_ship:
		_land = {}
		_fill_sea()
		_dress_arena()
		return
	if not boarding:
		_build_scene()
		if scene.underground:
			ambience.gull_target = 0
			ambience.cloud_alpha = 0.0
			ambience.glint_density = 0.0
		return
	# Fallback without a live ship: two decks lashed together by planks.
	for gx in range(-16, 17):
		for gy in range(-16, 17):
			var p := Art.iso(gx, gy)
			var ours: bool = p.x >= -196 and p.x <= -14 and absf(p.y + p.x * 0.08) <= 64
			var theirs: bool = p.x >= 14 and p.x <= 196 and absf(p.y - p.x * 0.08) <= 64
			var bridge: bool = absf(p.x) < 18 and absf(p.y) <= 22
			if ours or theirs or bridge:
				land[Vector2i(gx, gy)] = "plank"
	for c in land:
		land_ground.set_cell(Art.layer_cell(info, c.x, c.y), 0, Vector2i(Art.ground_index(land[c]), 2))
		land_sides.set_cell(Art.layer_cell(info, c.x, c.y), 0, Vector2i(Art.side_index("wood"), 3))
	_land = land
	_fill_sea()
	_dress_arena()


## A land battle: the authored setting (ArenaScene) for this room, painted
## on the terrain layers, its props on the stage, its lights and tint.
func _build_scene() -> void:
	var foes := 0
	var people := 0
	var waves: Array = enc.def.get("waves", [])
	if not waves.is_empty():
		for e in waves[0]:
			foes += 1
			if Settle.is_human(String(e.get("enemyId", ""))):
				people += 1
	var key := "%s:%s:%s" % [str(enc.def.get("locationId", "")), str(enc.def.get("roomId", "")), rid]
	scene = ArenaScene.new()
	scene.build(arena, rid, key, foes > 0 and people * 2 >= foes, String(enc.def.get("kind", "battle")))
	coast = scene.coast
	coast.paint({"sea": sea, "sides": land_sides, "low": land_low, "band": land_band, "high": land_ground}, _sea_info)
	if scene.underground:
		# A platform in the dark: no water, a near-black void round it.
		sea.clear()
		_underlay.color = Color(0.035, 0.03, 0.05)
	else:
		_foam = coast.make_foam()
		add_child(_foam)
	add_child(coast.make_blend(Art.terrain_atlas(rid)))
	for pr in scene.props:
		_scene_prop(String(pr[0]), pr[1], bool(pr[2]))
	for l in scene.lights:
		_light(l[0], l[1], float(l[2]))
	# Camera centre range: the fight with its entries, the set pieces behind.
	_bounds = Rect2(-250, -150, 560, 250)
	_land = {}
	_sea_cover = Rect2()
	_fill_sea()
	var dark: Color = scene.tint
	if _night and not scene.underground:
		dark = dark * Color(0.6, 0.65, 0.9)
	canvas_mod.color = dark


# ------------------------------------------------------- boarding on deck
func _deck_pt(x: float, y: float) -> Vector2:
	return ShipView.siso(float(_ship_deck.x0) + x, y)


func _has_boss() -> bool:
	for e in sim.enemies:
		if e.get("boss", false):
			return true
	return false


## Builds the boarding arena from the live ship. Returns false if the hull
## art or ship data is unavailable (the plank fallback is used then).
func _build_boarding() -> bool:
	if not Game.has_game():
		return false
	var ship: Dictionary = Game.state.ship
	var hid := String(ship.hullId)
	var hd := Art.hull_data(hid)
	if hd.is_empty() or ship.decks.is_empty():
		return false
	_ship_deck = ship.decks[0]
	_ship_occ = Rules.occupancy(ship)
	_foe_hull = "voyager" if sim.enemies.size() >= 5 or _has_boss() else "starter"
	for h in C.HULLS:
		if h.id == _foe_hull:
			_foe_deck = h.decks[0]
	if _foe_deck.is_empty() or Art.hull_data(_foe_hull).is_empty():
		return false
	var our_mid := float(_ship_deck.x0) + float(_ship_deck.w) * 0.5
	var foe_mid := float(_foe_deck.x0) + float(_foe_deck.w) * 0.5
	_foe_off = Vector2(roundf(our_mid - foe_mid), -(float(_foe_deck.h) + 1.0))
	_hull_sprites(_foe_hull, _foe_off, Color(0.8, 0.74, 0.72), 0.85)
	_hull_sprites(hid, Vector2.ZERO, Color(1, 1, 1), 0.5)
	_deck_fittings(ship)
	_boarding_lines()
	var r := Rect2()
	var first := true
	for pair in [[hd.bounds, Vector2.ZERO], [Art.hull_data(_foe_hull).bounds, _foe_off]]:
		var b: Dictionary = pair[0]
		var o: Vector2 = pair[1]
		for c in [Vector2(b.minGx, b.minGy), Vector2(b.maxGx, b.minGy), Vector2(b.minGx, b.maxGy), Vector2(b.maxGx, b.maxGy)]:
			var q := ShipView.siso(c.x + o.x, c.y + o.y)
			if first:
				r = Rect2(q, Vector2.ZERO)
				first = false
			else:
				r = r.expand(q)
	_bounds = r.grow_individual(40, 160, 40, 90)
	return true


## View-0 hull pieces (hull and furled rig) of one ship, offset in cells.
func _hull_sprites(hid: String, off: Vector2, tint: Color, rig_alpha: float) -> void:
	var hd := Art.hull_data(hid)
	var shift := ShipView.siso(off.x, off.y)
	for p in hd.pieces:
		var layer := String(p.layer)
		if int(p.get("view", 0)) != 0 or layer == "rig_set":
			continue
		var rigged := layer != "hull"
		var base := ShipView.siso(float(p.cell[0]) + off.x, float(p.cell[1]) + off.y)
		var s := Sprite2D.new()
		s.centered = false
		s.texture = Art.hull_piece_tex(hid, p.rect)
		s.position = base + Vector2(0, -3.0 if rigged else -4.0)
		s.offset = base + Vector2(float(p.off[0]), float(p.off[1])) - s.position
		s.modulate = Color(tint.r, tint.g, tint.b, rig_alpha if rigged else 1.0)
		stage.add_child(s)
	for rp in hd.ropes:
		var a := Vector2(float(rp.a[0]), float(rp.a[1])) + shift
		var bb := Vector2(float(rp.b[0]), float(rp.b[1])) + shift
		var ln := Line2D.new()
		ln.width = 1.0
		ln.default_color = Color(0.22, 0.15, 0.1, 0.85 * rig_alpha)
		ln.position = (a if a.y > bb.y else bb) + Vector2(0, 2)
		ln.points = PackedVector2Array([a - ln.position, bb - ln.position])
		stage.add_child(ln)
	if _night:
		for l in hd.lights:
			if int(l.get("view", 0)) == 0:
				_light(Vector2(float(l.pos[0]), float(l.pos[1])) + shift, Color(1.0, 0.78, 0.48), 0.6)
	var i := 0
	for pair in hd.foam:
		if i % 3 == 0:
			for q in [pair[0], pair[1]]:
				var fs := AnimatedSprite2D.new()
				fs.sprite_frames = Art.foam_frames()
				fs.animation = "loop"
				fs.position = Vector2(float(q[0]), float(q[1])) + shift
				fs.frame = (i * 3) % 4
				fs.z_index = -15
				fs.play()
				add_child(fs)
		i += 1


## Fittings that stand on our open decks (lookout, boarding gate, guard
## post), the hatches the defenders climbed through and terrace stairs.
func _deck_fittings(ship: Dictionary) -> void:
	_fit_cells.clear()
	_portal_cells.clear()
	for f in ship.facilities:
		if f.stowed:
			continue
		var d := int(f.deck)
		if d < 0 or d >= ship.decks.size() or not Rules.is_open_deck(ship.decks[d]):
			continue
		var dk: Dictionary = ship.decks[d]
		var lift := float(dk.elev) * Art.LEVEL_PX
		for c in Rules.fac_cells(f):
			_fit_cells[Vector2i(int(dk.x0) + c.x, c.y)] = true
		for p in Art.facility_pieces(String(f.id), int(f.get("rot", 0)), false):
			var g := ShipView.siso(float(dk.x0) + int(f.x) + p.cell.x, int(f.y) + p.cell.y)
			var s := Sprite2D.new()
			s.centered = false
			s.texture = p.tex
			s.position = g + Vector2(0, -2)
			s.offset = g - Vector2(0, lift) + p.off - s.position
			stage.add_child(s)
	for sd in ship.stairs:
		var lo: Dictionary = ship.decks[int(sd.deck)]
		var up: Dictionary = ship.decks[int(sd.to)]
		if not Rules.is_open_deck(up):
			continue
		var terrace := Rules.is_open_deck(lo) and int(lo.x0) + int(sd.x) != int(up.x0) + int(sd.ux)
		if terrace and int(sd.deck) == 0:
			_portal_cells["%d:%d" % [int(sd.x), int(sd.y)]] = true
		elif not terrace and int(sd.to) == 0:
			_portal_cells["%d:%d" % [int(sd.ux), int(sd.y)]] = true
		var pd: Dictionary
		var g: Vector2
		var lift := 0.0
		if terrace:
			pd = Art.part("stair_mx" if int(lo.x0) + int(sd.x) > int(up.x0) + int(sd.ux) else "stair_px")
			g = ShipView.siso(float(lo.x0) + int(sd.x), int(sd.y))
			lift = float(lo.elev) * Art.LEVEL_PX
		else:
			pd = Art.part("hatch")
			g = ShipView.siso(float(up.x0) + int(sd.ux), int(sd.y))
			lift = float(up.elev) * Art.LEVEL_PX
		if pd.is_empty():
			continue
		var sp := Sprite2D.new()
		sp.centered = false
		sp.texture = pd.tex
		sp.position = g + Vector2(0, -6 if not terrace else -2)
		sp.offset = g - Vector2(0, lift) + pd.off - sp.position
		stage.add_child(sp)


## Boarding planks and grapnel lines from the enemy rail to ours.
func _boarding_lines() -> void:
	var w := float(_ship_deck.w)
	var our_rail := -0.5
	var foe_rail := _foe_off.y + float(_foe_deck.h) - 0.5
	var rail_h := 18.0
	for k in 3:
		var x := w * (0.3 + 0.2 * k)
		var gx := float(_ship_deck.x0) + x
		var a := ShipView.siso(gx, our_rail) - Vector2(0, rail_h)
		var b := ShipView.siso(gx, foe_rail) - Vector2(0, rail_h)
		var plank := Line2D.new()
		plank.width = 7.0
		plank.default_color = Color(0.48, 0.32, 0.18)
		plank.position = ShipView.siso(gx, our_rail) + Vector2(0, 1)
		plank.points = PackedVector2Array([a - plank.position, b - plank.position])
		var edge := Line2D.new()
		edge.width = 1.0
		edge.default_color = Color(0.25, 0.15, 0.08)
		edge.points = PackedVector2Array([a - plank.position + Vector2(0, 3), b - plank.position + Vector2(0, 3)])
		plank.add_child(edge)
		stage.add_child(plank)
	for k in 5:
		var x2 := w * (0.15 + 0.17 * k) + 0.4
		var gx2 := float(_ship_deck.x0) + x2
		var a2 := ShipView.siso(gx2, our_rail) - Vector2(0, rail_h + 2)
		var b2 := ShipView.siso(gx2 - 0.3, foe_rail) - Vector2(0, rail_h + 10)
		var rope := Line2D.new()
		rope.width = 1.0
		rope.default_color = Color(0.2, 0.14, 0.09, 0.9)
		rope.position = ShipView.siso(gx2, our_rail)
		var mid := (a2 + b2) * 0.5 + Vector2(0, 6)
		rope.points = PackedVector2Array([a2 - rope.position, mid - rope.position, b2 - rope.position])
		stage.add_child(rope)


## Nearest deck spot that is not a mast, helm, hatch trunk or fitting.
func _deck_spot(x: float, y: float) -> Vector2:
	var w := float(_ship_deck.w)
	var h := float(_ship_deck.h)
	x = clampf(x, 0.2, w - 0.8)
	y = clampf(y, 0.2, h - 0.8)
	for o in [Vector2.ZERO, Vector2(0, 0.8), Vector2(0, -0.8), Vector2(0.7, 0), Vector2(-0.7, 0), Vector2(0.7, 0.8), Vector2(-0.7, -0.8)]:
		var q: Vector2 = Vector2(x, y) + o
		var xi := int(roundf(q.x))
		var yi := int(roundf(q.y))
		if Rules.fixed_kind(_ship_deck, xi, yi) == "" and not _ship_occ.has("0:%d:%d" % [xi, yi]) \
				and not _portal_cells.has("%d:%d" % [xi, yi]):
			return _deck_pt(q.x, q.y)
	return _deck_pt(x, y)


func _boarding_home(u: Dictionary) -> Vector2:
	var li: int = LANE_INDEX.get(String(u.lane), 0)
	var w := float(_ship_deck.w)
	var h := float(_ship_deck.h)
	var mid := w * 0.5 - 0.5
	var cy := (h - 1.0) * 0.5
	if u.side == "ally":
		var k := int(u.slot) % 2
		return _deck_spot(mid - 1.4 - li * 1.5, cy + (float(k) - 0.5) * minf(2.4, h - 2.0) + li * 0.2)
	var same := []
	for e in sim.enemies:
		if String(e.lane) == String(u.lane):
			same.append(e.uid)
	var idx := same.find(u.uid)
	var n := maxi(1, same.size())
	var span := minf(1.3, (h - 1.4) / maxf(1.0, float(n - 1)))
	var x := mid + 1.4 + li * 1.5 + (0.35 if idx % 2 == 1 else 0.0) + (0.5 if u.boss else 0.0)
	return _deck_spot(x, cy + (float(idx) - float(n - 1) * 0.5) * span)


## Weather-deck hatch closest to a defender's home: [rim point, hatch
## centre], where the rim is where the ladder comes up (ShipView's
## LADDER_TOP_U). Empty if the ship has no hatch onto the weather deck.
func _nearest_hatch(home: Vector2) -> Array:
	var best := []
	var bd := INF
	if Game.has_game():
		for sd in Game.state.ship.stairs:
			if int(sd.to) != 0 or Rules.is_open_deck(Game.state.ship.decks[int(sd.deck)]):
				continue
			var q := _deck_pt(float(sd.ux), float(sd.y))
			if q.distance_to(home) < bd:
				bd = q.distance_to(home)
				best = [_deck_pt(float(sd.ux) + ShipView.LADDER_TOP_U, float(sd.y)), q]
	return best


## Defender coming up a hatch: it appears on the rim with its feet on the
## deck (never sunk into it) and walks home around the opening. Without a
## hatch it fades in a little aft of its home, on the deck.
func _emerge_from_hatch(a: Actor, home: Vector2) -> void:
	var h := _nearest_hatch(home)
	if h.is_empty():
		var hm0 := ShipView.suniso(home) - Vector2(float(_ship_deck.x0), 0.0)
		a.position = _deck_spot(hm0.x - 1.6, hm0.y)
		a.lift = 0.0
		a.fade_in(0.3)
		a.walk_path([[home, 0.0]], 50.0)
		return
	var rim: Vector2 = h[0]
	var centre: Vector2 = h[1]
	var pts := []
	var hc := ShipView.suniso(centre)
	var hm := ShipView.suniso(home)
	if hm.x > hc.x + 0.3:
		# Home lies past the opening: step round its +y or -y side first.
		var side := 0.75 if hm.y >= hc.y else -0.75
		pts.append([ShipView.siso(hc.x + ShipView.LADDER_TOP_U, hc.y + side), 0.0])
		pts.append([ShipView.siso(hc.x + 0.6, hc.y + side), 0.0])
	pts.append([home, 0.0])
	a.position = rim
	a.lift = 0.0
	a.fade_in(0.3)
	a.walk_path(pts, 50.0)


## Boarding: per-frame sort key on the deck (see ShipView.depth_key).
func _apply_deck_depth(a: Actor) -> void:
	var c := Vector2i(ShipView.suniso(a.position).round())
	a.depth_bias = ShipView.depth_key(a.position, _fit_cells.has(c)) - a.position.y


## Where a boarder starts (on the enemy deck) and the gap it crosses.
func _boarding_entry(home: Vector2) -> Array:
	var c := ShipView.suniso(home)
	var foe_y := _foe_off.y + (float(_foe_deck.h) - 1.0) * 0.5
	var start := ShipView.siso(c.x + _rng.randf_range(-0.6, 0.6), foe_y + _rng.randf_range(-1.0, 1.0))
	var gap := ShipView.siso(c.x, -1.0)
	return [start, gap]


## A prop on the 8px-raised deck or ground at cell-level point `at`.
func _prop_at(name: String, at: Vector2, region_variant := true) -> Sprite2D:
	return _scene_prop(name, at + Vector2(0, -8), region_variant)


## A prop whose foot is at `at` on the drawn ground.
func _scene_prop(name: String, at: Vector2, region_variant := true) -> Sprite2D:
	var pr := Art.prop(name, rid if region_variant else "")
	if pr.is_empty():
		return null
	var s := Sprite2D.new()
	s.centered = false
	s.texture = pr.tex
	s.offset = -pr.anchor
	s.position = at
	stage.add_child(s)
	return s


func _light(at: Vector2, color: Color, scale_f: float) -> void:
	var lp := PointLight2D.new()
	lp.texture = Art.glow
	lp.texture_scale = scale_f
	lp.color = color
	lp.energy = 0.9
	lp.position = at
	add_child(lp)


## Boarding: lighting on the live ship, or the props of the fallback decks.
## (Land battles are dressed by _build_scene.)
func _dress_arena() -> void:
	var dark := Color(1, 1, 1)
	if _on_ship:
		if _night:
			dark = Color(0.55, 0.6, 0.85)
	elif boarding:
		for p in [Vector2(-180, -30), Vector2(-150, 44), Vector2(178, -34), Vector2(150, 46)]:
			_prop_at("barrels" if p.x < 0 else "crate", p, false)
		_prop_at("cannon", Vector2(-120, -54), false)
		_prop_at("cannon", Vector2(120, -54), false)
		_prop_at("flag", Vector2(-196, 4), false)
		_prop_at("flag", Vector2(196, 4), false)
		_prop_at("lamp", Vector2(-60, -60), false)
		_prop_at("lamp", Vector2(60, -60), false)
		var t := int(Game.state.envelope.gameClock) % 24 if Game.has_game() else 12
		if t < 6 or t >= 19:
			dark = Color(0.55, 0.6, 0.85)
	canvas_mod.color = dark


# ================================================================ units
func _unit_home(u: Dictionary) -> Vector2:
	if _on_ship:
		return _boarding_home(u)
	var li: int = LANE_INDEX.get(String(u.lane), 0)
	if u.side == "ally":
		var k := int(u.slot) % 2
		return Vector2(-46.0 - li * 36.0, -14.0 + k * 30.0 + li * 3.0)
	# Enemies: spread each lane's members vertically.
	var same := []
	for e in sim.enemies:
		if String(e.lane) == String(u.lane):
			same.append(e.uid)
	var idx := same.find(u.uid)
	var n := maxi(1, same.size())
	var span := 26.0 if n <= 3 else 20.0
	var y := (float(idx) - float(n - 1) * 0.5) * span
	var x := 50.0 + li * 40.0 + (8.0 if idx % 2 == 1 else 0.0)
	if u.boss:
		x += 16.0
	return Vector2(x, y + li * 3.0)


func _make_actor(u: Dictionary) -> Actor:
	var a := Actor.new()
	if u.side == "ally":
		var m = Rules.member(Game.state, String(u.key)) if Game.has_game() else null
		a.setup_puppet(Art.crew_look(m) if m != null else {})
		a.key = String(u.key)
	else:
		a.setup_enemy(String(u.key), u.get("variantTint"))
	a.show_hp(true, u.side == "ally")
	a.face(ALLY_FACE if u.side == "ally" else ENEMY_FACE)
	stage.add_child(a)
	var sm := BattleFx.Status.new()
	sm.h = a.height()
	sm.st = u.st
	a.attach_fx(sm)
	_status[u.uid] = sm
	return a


func _make_pet(u: Dictionary) -> Actor:
	var p: Dictionary = u.pet
	var key := Art.pet_key({"familyId": p.familyId, "speciesId": p.speciesId, "evolved": p.get("evolved", false)})
	var info := Art.creature_info(key)
	if info.is_empty():
		return null
	var a := Actor.new()
	a.setup_creature(info)
	a.face(ALLY_FACE)
	stage.add_child(a)
	return a


## Creates actors for new units and drops actors for units that left.
func _sync_units(initial := false) -> void:
	var seen := {}
	for u in sim.allies + sim.enemies:
		seen[u.uid] = true
		_units[u.uid] = u
		if _actors.has(u.uid):
			continue
		var a := _make_actor(u)
		_actors[u.uid] = a
		var home := _unit_home(u)
		_home[u.uid] = home
		if u.side == "enemy" and u.get("boss", false):
			_meet_boss(u.uid, a, initial)
		if _on_ship and u.side == "enemy":
			# Boarders swarm over the planks from the enemy deck.
			var ent := _boarding_entry(home)
			a.position = ent[0]
			a.walk_path([[ent[1], 14.0], [home, 0.0]], 80.0 if initial else 95.0)
		elif _on_ship and u.side == "ally" and initial:
			# Defenders come up through the nearest hatch and form on deck.
			_emerge_from_hatch(a, home)
		elif u.side == "enemy" and not initial:
			a.position = home + Vector2(130, 0)
			a.walk_path([[home, 0.0]], 90.0)
		elif u.side == "ally" and initial:
			a.position = home + Vector2(-70, 0)
			a.walk_path([[home, 0.0]], 70.0)
		else:
			a.position = home
		if u.side == "ally" and u.pet != null:
			var pa := _make_pet(u)
			if pa != null:
				_pets[u.uid] = pa
				if _on_ship and initial:
					# Pets come up with their owner instead of walking in over the side.
					pa.position = a.position + Vector2(-6, 4)
					pa.fade_in(0.3)
					pa.walk_path([[home + Vector2(-16, 12), 0.0]], 50.0)
				else:
					pa.position = home + Vector2(-16, 12) + (Vector2(-70, 0) if initial else Vector2.ZERO)
					pa.walk_path([[home + Vector2(-16, 12), 0.0]], 70.0)
	for uid in _actors.keys():
		if not seen.has(uid) and not _dying.has(uid):
			_dying[uid] = 0.6
			_actors[uid].play("down")


func _update_actors(delta: float) -> void:
	if _on_ship:
		for group in [_actors, _pets]:
			for k in group:
				_apply_deck_depth(group[k])
	for uid in _actors:
		var a: Actor = _actors[uid]
		var u = _units.get(uid)
		if u == null:
			continue
		if not _hp_hold.has(uid):
			a.set_hp(float(u.hp) / float(maxi(1, int(u.maxHp))))
		if not u.alive and a.anim != "down" and not _ko_wait.has(uid):
			a.play("down")
		var sm: Node2D = _status.get(uid)
		if sm != null and is_instance_valid(sm):
			sm.visible = u.alive
		if u.side == "enemy":
			a.set_marker("iso_target" if sim.focus == uid else ("iso_hover" if _hover_uid == uid else ""))
		else:
			a.set_marker("iso_hover" if _hover_uid == uid else "")
		if u.alive and not a.is_walking() and a.anim_done() and a.anim != "down":
			a.play("idle")
			a.face(ALLY_FACE if u.side == "ally" else ENEMY_FACE)
	_update_telegraphs()
	for uid in _fade.keys():
		var fa: Actor = _actors.get(uid)
		if fa == null or not is_instance_valid(fa):
			_fade.erase(uid)
			continue
		var left: float = _fade[uid].secs - delta
		_fade[uid].secs = left
		if left < 0.45 and not _fade[uid].puffed:
			_fade[uid].puffed = true
			if not _fade[uid].human and not _quiet:
				_fx("smoke", fa.position + Vector2(0, -6))
		fa.modulate.a = clampf(left / 0.45, 0.0, 1.0)
		if left <= 0.0:
			fa.visible = false
			_fade.erase(uid)
	for uid in _dying.keys():
		_dying[uid] -= delta
		var a2: Actor = _actors.get(uid)
		if a2:
			a2.modulate.a = clampf(_dying[uid] / 0.6, 0.0, 1.0)
		if _dying[uid] <= 0.0:
			if a2:
				a2.queue_free()
			_actors.erase(uid)
			_home.erase(uid)
			_units.erase(uid)
			_dying.erase(uid)
	for uid in _pets.keys():
		var pa: Actor = _pets[uid]
		var owner = _units.get(uid)
		if owner == null or not owner.alive:
			pa.modulate.a = maxf(0.0, pa.modulate.a - delta * 2.0)
		elif not pa.is_walking() and pa.anim_done():
			pa.play("idle")


# ============================================================ simulation
func _process(delta: float) -> void:
	if sim.is_empty():
		return
	_t += delta
	var pan := Vector2(Input.get_axis("pan_left", "pan_right"), Input.get_axis("pan_up", "pan_down"))
	if pan != Vector2.ZERO:
		_stop_glide()
		cam.position += pan * 240.0 * delta / cam.zoom.x
		_clamp_cam()
	# Hit-stop: a heavy blow or a knockout holds the fight for an instant.
	# A boss's intro holds it until the intro ends.
	if _hitstop > 0.0:
		_hitstop = maxf(0.0, _hitstop - delta)
	elif not paused and not _ended and not _cine_hold:
		_acc += delta * float(SPEEDS[speed_i])
		var dtt := Combat.dt()
		var n := 0
		while _acc >= dtt and n < 40:
			_acc -= dtt
			n += 1
			Combat.step(sim)
			_after_step()
			if sim.outcome != null:
				break
	_update_actors(delta)
	_update_dynamic_ui()
	_update_boss_bar()
	_coin_t = maxf(0.0, _coin_t - delta)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		cam.offset = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 2.0 * (_shake / 0.25)
	else:
		cam.offset = Vector2.ZERO
	if _ended and not _committed:
		_end_t += delta
		if _end_t >= 1.4:
			_commit()


func _after_step() -> void:
	_sync_units()
	_consume_log()
	if sim.outcome != null and not _ended:
		_begin_end()


func _consume_log() -> void:
	for ev in sim.log:
		if int(ev.seq) <= _last_seq:
			continue
		_last_seq = int(ev.seq)
		_present(ev)
		if LOG_TYPES.has(String(ev.type)) or (ev.type == "hit" and ev.get("crit", false)):
			_push_log_line(ev)


## Instantly resolves the rest of the battle with the current tactics.
func skip_to_end() -> void:
	if _ended or sim.is_empty():
		return
	_skipped = true
	_end_cine()
	_quiet = true
	var guard := 0
	while sim.outcome == null and guard < 20000:
		Combat.step(sim)
		guard += 1
		_sync_units()
		_consume_log()
	_quiet = false
	if not _ended:
		_begin_end()


func _begin_end() -> void:
	_ended = true
	_end_t = 0.0
	var outcome := String(sim.outcome)
	for uid in _tele.keys():
		_drop_tele(uid, false)
	if outcome == "victory":
		# Opponents that fell during a skip (or out of sight) drop now.
		for c in Settle.carriers(enc.def):
			var cu := String(c.uid)
			if _dropped.has(cu):
				continue
			var at = _pending_drop.get(cu)
			if at == null:
				var ca := _actor(cu)
				at = ca.position if ca != null else _home.get(cu, Vector2(70, 0))
			_spawn_drops(cu, at)
	elif _spoils_box != null:
		_spoils_box.modulate = Color(1, 1, 1, 0.45)
	for uid in _actors:
		var u = _units.get(uid)
		var a: Actor = _actors[uid]
		if u == null or not u.alive:
			continue
		if outcome == "victory" and u.side == "ally":
			a.play("cheer")
		elif outcome == "retreat" and u.side == "ally":
			a.face(Vector2(-1, 0.2))
			a.walk_path([[a.position + Vector2(-140, 0), 0.0]], 80.0)
	for uid in _pets:
		if outcome == "retreat":
			_pets[uid].walk_path([[_pets[uid].position + Vector2(-140, 0), 0.0]], 80.0)
		elif outcome == "victory":
			_pets[uid].play("cheer")
	if outcome == "victory" and not _skipped:
		_finishing_blow()
	var key := "battle.outcome_" + outcome
	if outcome == "defeat" and sim.reason == "timeout":
		key = "battle.outcome_defeat_timeout"
	_show_banner(I18n.t(key), Art.GOLD if outcome == "victory" else (Art.BAD if outcome == "defeat" else Art.INK))
	if outcome == "victory" or outcome == "defeat":
		Audio.stinger(outcome == "victory")
	elif outcome == "retreat":
		Audio.play("ui_minimize")
		Audio.play("cloth")
	_refresh_controls()


## The fight is over: store its commands, outcome and spoils plan on the
## encounter (nothing is granted yet) and hand over to the report.
func _commit() -> void:
	_committed = true
	_normal_time()
	var res := Actions.end_encounter(Game.state, String(enc.attemptId), sim.commands)
	finished.emit(res)


# ============================================================ presentation
func _uname(uid: Variant) -> String:
	var u = _units.get(uid)
	if u == null:
		u = Combat.unit_by_uid(sim, uid)
	if u == null:
		return "?"
	if u.side == "ally":
		var m = Rules.member(Game.state, String(u.key))
		return I18n.crew_name(m) if m != null else String(u.key)
	return I18n.t(String(u.nameKey))


func _skill_name(id: Variant) -> String:
	if id == null or String(id) == "":
		return I18n.t("battle.basic_attack")
	return I18n.t("skill.%s.name" % id)


func _actor(uid: Variant) -> Actor:
	return _actors.get(uid)


func _ranged(uid: Variant) -> bool:
	var u = _units.get(uid)
	return u != null and String(u.get("range", "melee")) == "ranged"


func _present(ev: Dictionary) -> void:
	var tick := int(ev.tick)
	match String(ev.type):
		"wave":
			if int(ev.wave) > 1 and not _quiet:
				Audio.play("bell")
				_show_banner(I18n.t("battle.wave", {"n": ev.wave, "max": sim.spec.waves.size()}), Art.INK)
		"encore":
			_show_banner(I18n.t("battle.ev_encore"), Art.WARN)
		"skill":
			var had_tele := _tele.has(ev.src)
			_drop_tele(ev.src, false)
			_attack_anim(ev.src, tick)
			if not _quiet:
				Audio.play("skill")
				var sa := _actor(ev.src)
				if sa:
					var col := _side_color(ev.src)
					_burst(sa.position + Vector2(0, -2), col, 30.0 if had_tele else 26.0, 0, true)
					var g := BattleFx.Glyph.new()
					g.cat = String(C.SKILLS.get(String(ev.skill), {}).get("cat", "damage"))
					g.color = col
					g.rate = _fx_rate()
					sa.attach_fx(g, Vector2(0, -sa.height() - 15))
					_float_text(sa.head_point() + Vector2(0, -30), _skill_name(ev.skill), Art.GOLD, 0.9)
		"windup":
			var a2 := _actor(ev.src)
			if a2 and not _quiet:
				Audio.play("swing", -2.0, 0.8)
				a2.bubble("alert", 1.6)
				_float_text(a2.head_point() + Vector2(0, -6), _skill_name(ev.skill) + "!", Art.WARN, 1.1)
				_add_tele(ev)
		"hit", "miss":
			if _anim_tick.get(ev.src, -1) != tick:
				_attack_anim(ev.src, tick)
			_deliver(ev)
		"heal":
			var t4 := _actor(ev.tgt)
			if t4 and not _quiet and int(ev.amount) > 0:
				Audio.play("heal")
				var hr := BattleFx.HealRise.new()
				hr.rate = _fx_rate()
				t4.attach_fx(hr)
				_float_text(t4.head_point(), "+" + str(int(ev.amount)), Art.GOOD, 0.8)
		"ko":
			_drop_tele(ev.tgt, false)
			var t5 := _actor(ev.tgt)
			var u5 = _units.get(ev.tgt)
			if t5 == null or u5 == null:
				return
			if u5.side == "enemy":
				_last_ko = ev.tgt
			if _quiet:
				t5.play("down")
				_fallen(String(ev.tgt), t5, true)
				return
			_ko_wait[ev.tgt] = true
			_after(_impact_delay(ev.tgt, tick) + 0.03, _ko_react.bind(ev.tgt))
		"stun":
			# The lasting stars come from the status marks; add a jolt.
			var t6 := _actor(ev.tgt)
			if t6 and not _quiet:
				Audio.play("block", -6.0, 1.4)
		"interrupt":
			var t7 := _actor(ev.tgt)
			_drop_tele(ev.tgt, true)
			if t7 and not _quiet:
				_float_text(t7.head_point() + Vector2(0, -6), I18n.t("battle.interrupted"), Art.GOOD, 1.0)
		"pet":
			var pa: Actor = _pets.get(ev.src)
			if pa and not _quiet:
				pa.play("attack", true)
				_fx("sparkle", pa.position + Vector2(0, -8))
				_float_text(pa.head_point(), I18n.t("petability." + String(ev.ability)), Art.GOOD, 0.9)
		"dot":
			var t8 := _actor(ev.tgt)
			if t8 and not _quiet:
				_fx("fire", t8.position + Vector2(0, -6))
				_float_text(t8.head_point(), str(int(ev.amount)), Art.WARN, 0.7)
		"thorns", "trap":
			var t9 := _actor(ev.tgt)
			if t9 and not _quiet:
				Audio.play("block")
				_fx("sparks", t9.position + Vector2(0, -8))
				_float_text(t9.head_point(), str(int(ev.amount)), Art.WARN, 0.7)
		"intercept":
			var s1 := _actor(ev.src)
			var t10 := _actor(ev.tgt)
			if s1 and t10 and not _quiet:
				Audio.play("block", 2.0)
				_lunge(s1, t10.position, 0.5)
				var bash := BattleFx.Swing.new()
				bash.style = "bash"
				bash.dir = (t10.position - s1.position).normalized()
				bash.color = BattleFx.STEEL
				bash.rate = _fx_rate()
				t10.attach_fx(bash, Vector2(0, -t10.height() * 0.5))
		"resist":
			var t11 := _actor(ev.tgt)
			if t11 and not _quiet:
				_fx("sparkle", t11.position + Vector2(0, -10))
		"hazard":
			if not _quiet:
				Audio.play("splash" if _on_ship else "cannon_hit", -4.0)
				_show_banner(I18n.t("hazard.%s.name" % ev.hazard), Art.WARN, 0.9)
				var tw := create_tween()
				var base := canvas_mod.color
				tw.tween_property(canvas_mod, "color", base * Color(1.2, 0.9, 0.8), 0.15)
				tw.tween_property(canvas_mod, "color", base, 0.35)


## Effects run a little faster at higher battle speeds (x2 -> 1.4, x4 -> 2).
func _fx_rate() -> float:
	return sqrt(float(SPEEDS[speed_i]))


func _side_color(uid: Variant) -> Color:
	return BattleFx.ALLY if _units.get(uid, {}).get("side") == "ally" else BattleFx.FOE


## Runs `cb` after `secs` of presentation time (immediately for 0).
func _after(secs: float, cb: Callable) -> void:
	if secs <= 0.0:
		cb.call()
		return
	var tw := create_tween()
	tw.tween_interval(secs)
	tw.tween_callback(cb)


## How a combatant fights, from the weapon it carries: the swing style
## for melee blows, the projectile for ranged ones and the projectile
## colour. People use their weapon (crew: equipped weapon kind; opponents:
## their outfit's weapon); creatures claw, or crush when big; their ranged
## attacks are spit.
func _weapon(uid: Variant) -> Dictionary:
	if _weap.has(uid):
		return _weap[uid]
	var u = _units.get(uid)
	var w := {"melee": "claw", "shot": "spit", "color": Color("#ffa070")}
	if u != null:
		var ws := ""
		if u.side == "ally":
			var m = Rules.member(Game.state, String(u.key)) if Game.has_game() else null
			if m != null:
				ws = String(Art.crew_look(m).get("weapon", ""))
		else:
			var v := Art.enemy_visual(String(u.key))
			if v.type == "puppet":
				ws = String(v.look.get("weapon", ""))
		var arch := String(u.get("archetype", ""))
		if ws != "":
			var parts := ws.split(":")
			var kind := parts[0]
			w.melee = MELEE_STYLE.get(kind, "slash")
			w.shot = SHOT_KIND.get(kind, {"caster": "orb", "shooter": "arrow", "healer": "vial"}.get(arch, "bullet"))
			w.color = Color.from_string(parts[1], Color("#7af0f0")) if parts.size() > 1 else Color("#7af0f0")
			if w.shot == "vial":
				w.color = BattleFx.HEAL
		else:
			w.melee = "crush" if u.get("boss", false) or arch == "brute" else "claw"
			w.color = Color("#b8f07a") if u.side == "ally" else Color("#ffa070")
			if arch == "caster":
				w.shot = "orb"
				w.color = Color("#c8a0ff")
	_weap[uid] = w
	return w


func _attack_anim(src_uid: Variant, tick: int) -> void:
	_anim_tick[src_uid] = tick
	var a := _actor(src_uid)
	var u = _units.get(src_uid)
	if a == null or u == null or not u.alive:
		return
	a.play("attack", true)


## Carries a blow (or a miss) from the attacker to the target: a lunge for
## melee, a projectile for ranged attacks, and the impact when it lands.
func _deliver(ev: Dictionary) -> void:
	var tick := int(ev.tick)
	var sa := _actor(ev.src)
	var ta := _actor(ev.tgt)
	if _quiet or sa == null or ta == null:
		_impact(ev)
		return
	if ev.type == "hit":
		_hp_hold[ev.tgt] = true
	var w := _weapon(ev.src)
	if _ranged(ev.src):
		var first: bool = _lunged.get(ev.src, -1) != tick
		_lunged[ev.src] = tick
		if first:
			match String(w.shot):
				"bullet":
					Audio.play("gun")
				"arrow":
					Audio.play("swing", -3.0, 1.3)
				"vial":
					Audio.play("cloth", -2.0, 1.2)
				"spit":
					Audio.play("swing", -4.0, 0.6)
				_:
					Audio.play("swing", -5.0, 0.7)
		var secs := _shot(sa, ta, String(w.shot), w.color, _impact.bind(ev), ev.type == "miss")
		_impact_at[ev.tgt] = [tick, secs]
	else:
		if _lunged.get(ev.src, -1) != tick:
			_lunged[ev.src] = tick
			Audio.play("swing", -2.0, 1.1)
			_lunge(sa, ta.position, 0.35)
		var d := 0.08 / _fx_rate()
		_impact_at[ev.tgt] = [tick, d]
		_after(d, _impact.bind(ev))


func _impact_delay(uid: Variant, tick: int) -> float:
	var ia = _impact_at.get(uid)
	if ia is Array and int(ia[0]) == tick:
		return float(ia[1])
	return 0.0


## The moment a blow lands: hit reaction, flash, the weapon's swing mark,
## sparks thrown away from the attacker, the number and, for heavy blows,
## a shake and a small knock-back.
func _impact(ev: Dictionary) -> void:
	_hp_hold.erase(ev.tgt)
	var t := _actor(ev.tgt)
	if t == null or not is_instance_valid(t):
		return
	if ev.type == "miss":
		if not _quiet:
			Audio.play("swing")
			_float_text(t.head_point(), I18n.t("battle.miss"), Art.INK_DIM, 0.7)
		return
	var u = _units.get(ev.tgt)
	if u != null and (u.alive or _ko_wait.has(ev.tgt)):
		t.play("hit", true)
	if _quiet:
		return
	t.flash()
	var su: Dictionary = _units.get(ev.src, {})
	var crit: bool = ev.get("crit", false)
	var heavy: bool = crit or su.get("boss", false)
	Audio.play("hit_heavy" if heavy else "hit")
	var sa := _actor(ev.src)
	var dir := Vector2.RIGHT if su.get("side") == "ally" else Vector2.LEFT
	if sa != null and sa.position.distance_to(t.position) > 1.0:
		dir = (t.position - sa.position).normalized()
	var chest := Vector2(0, -t.height() * 0.5)
	var w := _weapon(ev.src)
	if not _ranged(ev.src):
		var sw := BattleFx.Swing.new()
		sw.style = String(w.melee)
		sw.dir = dir
		sw.color = BattleFx.FIRE if crit else BattleFx.STEEL
		sw.size = 1.35 if heavy else 1.0
		sw.dur = 0.26
		sw.rate = _fx_rate()
		t.attach_fx(sw, chest)
		if w.melee == "slash" or w.melee == "claw":
			Audio.play("slash", -4.0)
	var sp := BattleFx.Sparks.new()
	sp.dir = dir
	sp.crit = crit
	sp.setup(_rng.randi())
	sp.rate = _fx_rate()
	t.attach_fx(sp, chest)
	if int(ev.get("absorbed", 0)) > 0:
		Audio.play("block", -3.0)
	var txt := str(int(ev.amount)) + ("!" if crit else "")
	_float_text(t.head_point(), txt, Art.GOLD if crit else (Art.BAD if su.get("side") == "enemy" else Art.INK), 0.8, crit)
	if heavy:
		_shake_cam(0.2)
	_knock(t, dir, 3.0 if heavy else 1.5)
	if ev.get("skill") != null and C.SKILLS.get(String(ev.skill), {}).get("fx", {}).get("plunder"):
		_coin_pop(t)


func _knock(a: Actor, dir: Vector2, px: float) -> void:
	if bool(Settings.get_value("reduceMotion")):
		return
	var tw := a.create_tween()
	tw.tween_property(a.rig, "position", (Vector2(0, -a.lift) + dir * px).round(), 0.05)
	tw.tween_property(a.rig, "position", Vector2(0, -a.lift), 0.12)


## A plundering blow knocks a coin loose; it flies to the spoils.
func _coin_pop(t: Actor) -> void:
	var d := BattleFx.Drop.new()
	d.icon = Art.icon("gold")
	d.rarity = "common"
	d.from = t.position
	d.to = t.position + Vector2(-10, 4)
	d.rate = _fx_rate()
	stage.add_child(d)
	_after(0.5 / _fx_rate(), _collect_drop.bind(d, 0))


## A defeated opponent's reaction after the last blow lands. People drop
## to a knee and raise a white flag, creatures collapse and dissolve in
## smoke; either way they fade out shortly so the field stays readable,
## and their share of the spoils spills out at once. Fallen crew stay down.
func _ko_react(uid: Variant) -> void:
	_ko_wait.erase(uid)
	var a := _actor(uid)
	if a == null or not is_instance_valid(a):
		return
	a.play("down")
	Audio.play("ko")
	_fx("dust", a.position)
	_burst(a.position, Color(0.85, 0.8, 0.7), 18.0, 0, true)
	var p = _pets.get(uid)
	if p:
		p.play("down")
	_fallen(String(uid), a, false)


func _fallen(uid: String, a: Actor, quiet: bool) -> void:
	var u = _units.get(uid)
	if u == null:
		return
	if u.side != "enemy":
		a.modulate = Color(0.8, 0.8, 0.85)
		return
	a.show_hp(false)
	var human: bool = Art.enemy_visual(String(u.key)).type == "puppet"
	if human and not quiet:
		a.attach_fx(BattleFx.Flag.new(), Vector2(6, -a.height() * 0.45))
	_fade[uid] = {"secs": 0.35 if quiet else (1.7 if human else 1.1), "human": human, "puffed": quiet}
	if quiet:
		_pending_drop[uid] = a.position
	else:
		_spawn_drops(uid, a.position)


# ------------------------------------------------------------ telegraphs
func _add_tele(ev: Dictionary) -> void:
	_drop_tele(ev.src, false)
	var sa := _actor(ev.src)
	var ta := _actor(ev.tgt)
	if sa == null or ta == null:
		return
	var col := _side_color(ev.src)
	var ring := BattleFx.Telegraph.new()
	ring.secs = float(C.SKILLS.get(String(ev.skill), {}).get("fx", {}).get("windup", 2.0))
	ring.color = col
	ring.radius = 18.0 if _units.get(ev.tgt, {}).get("boss", false) else 13.0
	ring.z_index = -1
	ring.position = ta.position
	stage.add_child(ring)
	var ch := BattleFx.Charge.new()
	ch.color = col
	sa.attach_fx(ch, Vector2(0, -sa.height() * 0.5))
	_tele[ev.src] = {"ring": ring, "charge": ch, "tgt": ev.tgt}


## Removes a caster's wind-up marks; `broken` (an interrupt) bursts the
## ring in green so the save reads at a glance.
func _drop_tele(uid: Variant, broken: bool) -> void:
	var tl = _tele.get(uid)
	if tl == null:
		return
	_tele.erase(uid)
	if broken and is_instance_valid(tl.ring) and not _quiet:
		_burst(tl.ring.position, Art.GOOD, 22.0, 6, true)
		Audio.play("block", 0.0, 0.8)
	for k in ["ring", "charge"]:
		if is_instance_valid(tl[k]):
			tl[k].queue_free()


func _update_telegraphs() -> void:
	for uid in _tele.keys():
		var tl: Dictionary = _tele[uid]
		var u = _units.get(uid)
		if u == null or not u.alive or u.windup == null or not is_instance_valid(tl.ring):
			_drop_tele(uid, false)
			continue
		var ta := _actor(tl.tgt)
		if ta != null:
			tl.ring.position = ta.position
		tl.ring.t = tl.ring.secs - float(u.windup.left)


# ================================================================== spoils
## Spills a fallen opponent's planned share of the spoils onto the field.
## The drops lie there briefly, then fly to the spoils counter; nothing is
## granted here (the report settles the plan after the battle).
func _spawn_drops(uid: String, at: Vector2) -> void:
	if _dropped.has(uid):
		return
	_dropped[uid] = true
	var shares: Array = plan.get("drops", {}).get(uid, [])
	if shares.is_empty():
		return
	var n := mini(shares.size(), DROP_MAX)
	var rate := _fx_rate()
	var rot := _rng.randf() * TAU
	for i in n:
		var row: Dictionary = plan.rows[int(shares[i][0])]
		var count := 1 if i < n - 1 else shares.size() - (n - 1)
		var d := BattleFx.Drop.new()
		d.icon = Art.icon(String(row.icon))
		d.rarity = String(row.rarity)
		d.from = at
		var q := rot + TAU * float(i) / float(n)
		var rad := 10.0 + 4.0 * float(i % 2)
		d.to = (at + Vector2(cos(q) * rad + 4.0, sin(q) * rad * 0.5)).round()
		d.rate = rate
		stage.add_child(d)
		if i == 0:
			Audio.play("coins" if row.kind == "gold" else ("metal" if row.kind == "item" else "cloth"), -3.0)
		_after((DROP_SECS + 0.08 * i) / rate, _collect_drop.bind(d, count))


## Flies a drop's icon from the field to the spoils counter.
func _collect_drop(d: BattleFx.Drop, count: int) -> void:
	if not is_instance_valid(d):
		_add_spoils(count)
		return
	var tex: Texture2D = d.icon
	var rarity := String(d.rarity)
	var sp := get_viewport().get_canvas_transform() * (d.position + Vector2(0, -10))
	d.queue_free()
	if _float_root == null or _spoils_icon == null or not _spoils_box.is_visible_in_tree():
		_add_spoils(count)
		return
	var r := TextureRect.new()
	r.texture = tex
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(16, 16)
	r.pivot_offset = Vector2(8, 8)
	r.position = (sp - Vector2(8, 8)).round()
	if rarity != "common":
		r.modulate = BattleFx.rarity_color(rarity).lerp(Color.WHITE, 0.55)
	_float_root.add_child(r)
	var dest := _spoils_icon.get_global_rect().get_center() - Vector2(8, 8)
	var tw := r.create_tween()
	tw.set_parallel(true)
	tw.tween_property(r, "position", dest, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(r, "scale", Vector2(0.7, 0.7), 0.38)
	tw.chain().tween_callback(func():
		r.queue_free()
		_add_spoils(count))


func _add_spoils(count: int) -> void:
	if count <= 0:
		return
	_spoils_n += count
	_update_spoils_chip()
	if _spoils_box != null:
		_spoils_box.pivot_offset = _spoils_box.size * 0.5
		var tw := _spoils_box.create_tween()
		tw.tween_property(_spoils_box, "scale", Vector2(1.25, 1.25), 0.05)
		tw.tween_property(_spoils_box, "scale", Vector2.ONE, 0.12)
	if _coin_t <= 0.0:
		_coin_t = 0.12
		Audio.play("coins", -6.0, 1.15)


func _update_spoils_chip() -> void:
	if _spoils_box == null:
		return
	_spoils_box.visible = _spoils_n > 0
	_spoils_label.text = str(_spoils_n)


## Hides the fight overlays while the report is open and frames the
## survivors in the part of the screen the report leaves free.
## `panel_w` is the report's width in base-viewport pixels.
func set_report_mode(on: bool, panel_w := 0.0) -> void:
	report_mode = on
	for p in [_strip_panel, _status_panel, _log_panel, _bar, _paused_panel, _banner, _boss_bar]:
		if p != null:
			p.visible = not on
	if not on:
		return
	_end_cine()
	var focus := Vector2.ZERO
	var n := 0
	for uid in _actors:
		var a: Actor = _actors[uid]
		var u = _units.get(uid)
		if a.visible and u != null and u.alive:
			focus += a.position
			n += 1
	if n == 0:
		for uid in _actors:
			if _actors[uid].visible:
				focus += _actors[uid].position
				n += 1
	focus = focus / float(n) if n > 0 else cam.position
	var z := float(ZOOMS[_zoom_i])
	var target := Vector2(focus.x + panel_w * 0.5 / z, focus.y - 14.0).round()
	_glide(target, z, 0.45, Tween.EASE_OUT)


func _lunge(a: Actor, toward: Vector2, frac: float) -> void:
	if bool(Settings.get_value("reduceMotion")):
		return
	var dv := (toward - a.position) * frac
	dv = dv.limit_length(26.0)
	var tw := a.create_tween()
	tw.tween_property(a.rig, "position", Vector2(dv.x, dv.y - a.lift), 0.08)
	tw.tween_property(a.rig, "position", Vector2(0, -a.lift), 0.14)


## A projectile from `from` to `to`; returns its flight time in seconds.
## A miss flies past the target.
func _shot(from: Actor, to: Actor, kind: String, color: Color, cb: Callable, miss := false) -> float:
	var s := BattleFx.Shot.new()
	s.kind = kind
	var dx := signf(to.position.x - from.position.x)
	if dx == 0.0:
		dx = 1.0
	s.from = from.position + Vector2(5.0 * dx, 0)
	s.to = to.position + (Vector2(14.0 * dx, 7.0) if miss else Vector2.ZERO)
	s.h0 = from.height() * 0.55 + from.lift
	s.h1 = to.height() * 0.5 + to.lift
	s.arc = float(SHOT_ARC.get(kind, 0.0))
	s.dur = clampf(s.from.distance_to(s.to) / float(SHOT_SPEED.get(kind, 300.0)), 0.08, 0.5)
	s.rate = _fx_rate()
	s.color = color
	s.on_hit = cb
	stage.add_child(s)
	if kind == "bullet":
		var mz := BattleFx.Muzzle.new()
		mz.dir = (s.to - s.from).normalized()
		from.attach_fx(mz, Vector2(0, -from.height() * 0.55))
	return s.dur / s.rate


func _fx(name: String, at: Vector2) -> void:
	var n := Art.fx_node(name, true, 12.0)
	n.position = at
	fx_root.add_child(n)


## A large, short-lived impact shape so key moments read at a glance:
## rays plus a ring for critical hits, a flat ground ring for skills and
## knockouts. Drawn in world space above the actors.
func _burst(at: Vector2, color: Color, radius: float, rays: int, ground := false) -> void:
	var b := Burst.new()
	b.position = at.round()
	b.color = color
	b.radius = radius
	b.rays = rays
	b.ground = ground
	b.z_index = 5 if not ground else -1
	fx_root.add_child(b)
	var secs := 0.32 if not ground else 0.45
	var tw := b.create_tween()
	tw.tween_property(b, "f", 1.0, secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(b.queue_free)


func _shake_cam(secs: float) -> void:
	if bool(Settings.get_value("reduceMotion")):
		return
	_shake = maxf(_shake, secs)
	# Shorter at higher battle speeds so fast fights keep their pace.
	_hitstop = maxf(_hitstop, 0.07 / float(SPEEDS[speed_i]))


## Floating text lives on the UI layer so it stays crisp at any zoom.
func _float_text(world_pos: Vector2, text: String, color: Color, secs := 0.8, big := false) -> void:
	if _float_root == null:
		return
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.06))
	l.add_theme_constant_override("outline_size", 4)
	if big:
		l.add_theme_font_size_override("font_size", 24)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_root.add_child(l)
	var sp := get_viewport().get_canvas_transform() * world_pos
	l.reset_size()
	l.position = (sp - Vector2(l.size.x * 0.5, l.size.y)).round()
	var tw := l.create_tween()
	tw.set_parallel(true)
	if not bool(Settings.get_value("reduceMotion")):
		# Numbers land with a pop (bigger for critical hits) and settle.
		l.pivot_offset = Vector2(l.size.x * 0.5, l.size.y)
		l.scale = Vector2.ONE * (1.6 if big else 1.3)
		tw.tween_property(l, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 14.0, secs)
	tw.tween_property(l, "modulate:a", 0.0, secs).set_delay(secs * 0.5)
	tw.chain().tween_callback(l.queue_free)


func _show_banner(text: String, color: Color, secs := 1.4) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 1.0
	_banner.visible = not report_mode
	var tw := _banner.create_tween()
	tw.tween_interval(secs)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.4)


func _ev_text(ev: Dictionary) -> String:
	match String(ev.type):
		"skill":
			return I18n.t("battle.ev_skill", {"src": _uname(ev.src), "skill": _skill_name(ev.skill)})
		"windup":
			return I18n.t("battle.ev_windup", {"src": _uname(ev.src), "skill": _skill_name(ev.skill), "tgt": _uname(ev.tgt)})
		"hit":
			return I18n.t("battle.ev_crit", {"src": _uname(ev.src), "tgt": _uname(ev.tgt), "skill": _skill_name(ev.get("skill")), "n": ev.amount})
		"heal":
			return I18n.t("battle.ev_heal", {"src": _uname(ev.src), "tgt": _uname(ev.tgt), "n": ev.amount})
		"ko":
			return I18n.t("battle.ev_ko", {"tgt": _uname(ev.tgt)})
		"stun":
			return I18n.t("battle.ev_stun", {"tgt": _uname(ev.tgt), "n": I18n.fmt_num(ev.secs)})
		"interrupt":
			return I18n.t("battle.ev_interrupt", {"tgt": _uname(ev.tgt), "skill": _skill_name(ev.skill)})
		"pet":
			return I18n.t("battle.ev_pet", {"src": _uname(ev.src), "ability": "petability." + String(ev.ability)})
		"wave":
			return I18n.t("battle.ev_wave", {"n": ev.wave, "max": sim.spec.waves.size()})
		"hazard":
			return I18n.t("battle.ev_hazard", {"hazard": "hazard.%s.name" % ev.hazard})
		"encore":
			return I18n.t("battle.ev_encore")
		"end":
			return I18n.t("battle.ev_end_" + String(ev.outcome))
		"command":
			var v = ev.get("value")
			match String(ev.cmd):
				"focus":
					return I18n.t("battle.ev_command_focus", {"value": _uname(v) if v != null else I18n.t("battle.focus_auto")})
				"stance":
					return I18n.t("battle.ev_command_stance", {"value": "stance.%s.name" % v})
				"priority":
					return I18n.t("battle.ev_command_priority", {"value": "priority.%s.name" % v})
				_:
					return I18n.t("battle.ev_command_retreat")
	return ""


func _push_log_line(ev: Dictionary) -> void:
	if _log_box == null or _quiet and ev.type != "end":
		return
	var s := _ev_text(ev)
	if s == "":
		return
	var tone := ""
	if ev.type == "ko":
		var u = _units.get(ev.tgt)
		tone = "BadLabel" if u != null and u.side == "ally" else "GoodLabel"
	elif ev.type == "windup" or ev.type == "hazard":
		tone = "WarnLabel"
	elif ev.type == "end" or ev.type == "wave":
		tone = "GoldLabel"
	var l := UIK.label(s, tone)
	l.custom_minimum_size.x = LOG_W
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.035, 0.06, 0.92))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_box.add_child(l)
	while _log_box.get_child_count() > LOG_LINES:
		var c := _log_box.get_child(0)
		_log_box.remove_child(c)
		c.queue_free()
	# Older lines dim; every line fades away after a while.
	var n := _log_box.get_child_count()
	for i in n:
		(_log_box.get_child(i) as Control).self_modulate.a = LOG_FADE[LOG_LINES - n + i]
	var tw := l.create_tween()
	tw.tween_interval(LOG_SECS)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


# ===================================================================== UI
func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 4
	add_child(ui)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = Art.theme
	ui.add_child(ui_root)
	_float_root = Control.new()
	_float_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_float_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(_float_root)
	# --- title strip (top centre, under the resource bar)
	var tp := UIK.panel(null, "ChipPanel")
	tp.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tp.offset_top = 25
	tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(tp)
	_strip_panel = tp
	_title_label = UIK.label(_title_text(), "GoldLabel")
	_wave_label = UIK.label("", "")
	_time_label = UIK.label("", "DimLabel")
	_spoils_icon = UIK.icon("ui_chest")
	_spoils_label = UIK.label("0", "GoldLabel")
	_spoils_box = UIK.hbox([_spoils_icon, _spoils_label], 2)
	_spoils_box.tooltip_text = I18n.t("settle.spoils_tip")
	_spoils_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_spoils_box.visible = false
	tp.add_child(UIK.hbox([UIK.icon("ui_battle"), _title_label, _wave_label, _time_label, _spoils_box], 6))
	_status_label = UIK.label("", "DimLabel")
	var sp := UIK.panel(_status_label, "TipPanel")
	sp.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sp.offset_top = 45
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.visible = false
	ui_root.add_child(sp)
	_status_panel = sp
	# --- boss health (top centre, under the title strip)
	_boss_bar = BossBar.new()
	_boss_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss_bar.offset_top = 46
	_boss_bar.visible = false
	ui_root.add_child(_boss_bar)
	# --- banner
	_banner = UIK.label("", "TitleLabel")
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 24)
	_banner.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.06))
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.offset_top = -70
	_banner.visible = false
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(_banner)
	# --- paused notice
	_paused_panel = UIK.panel(UIK.hbox([UIK.icon("ui_pause"), UIK.label(I18n.t("battle.paused"), "", true, 220)], 4), "TipPanel")
	_paused_panel.set_anchors_preset(Control.PRESET_CENTER)
	_paused_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_paused_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_paused_panel.offset_top = 40
	_paused_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(_paused_panel)
	# --- battle log (left, above the navigation): outlined lines with no
	# backing panel, so the fight stays visible behind them.
	var lp := UIK.vbox([], 0)
	lp.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	lp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lp.offset_left = 6
	lp.offset_top = -32
	lp.offset_bottom = -32
	lp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(lp)
	_log_panel = lp
	_log_box = lp
	_build_cine_ui()
	# --- control bar (bottom centre)
	var bar := UIK.panel(null, "HudBar")
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_bottom = -2
	bar.offset_left = 16
	bar.offset_right = 16
	ui_root.add_child(bar)
	_bar = bar
	var row := UIK.hbox([], 2)
	bar.add_child(row)
	_pause_btn = UIK.icon_button("ui_pause", I18n.t("battle.pause") + " (Space)", toggle_pause, "SlotButton")
	row.add_child(_pause_btn)
	for i in SPEEDS.size():
		var b := UIK.button("×%d" % int(SPEEDS[i]), set_speed.bind(i), "", "FlatButton", true, I18n.t("battle.speed") + " (%d)" % (i + 1))
		b.toggle_mode = true
		# The flat style has no margins until pressed; without matching
		# margins the pressed button clips its own label ("×1" showed "×").
		var flat := StyleBoxEmpty.new()
		flat.set_content_margin_all(2)
		b.add_theme_stylebox_override("normal", flat)
		b.add_theme_stylebox_override("disabled", flat)
		row.add_child(b)
		_speed_btns.append(b)
	row.add_child(VSeparator.new())
	row.add_child(UIK.label(I18n.t("battle.stance"), "DimLabel"))
	for id in C.data.STANCES:
		var sb := UIK.icon_button("stance_" + String(id), I18n.t("stance.%s.name" % id), _on_stance.bind(String(id)), "SlotButton")
		sb.toggle_mode = true
		row.add_child(sb)
		_stance_btns[String(id)] = sb
	row.add_child(VSeparator.new())
	var prios := []
	for id in C.data.PRIORITIES:
		prios.append([String(id), I18n.t("priority.%s.name" % id)])
	_prio_opt = UIK.option(prios, String(sim.priority), _on_priority)
	_prio_opt.tooltip_text = I18n.t("battle.priority")
	row.add_child(UIK.icon("prio_auto"))
	row.add_child(_prio_opt)
	row.add_child(VSeparator.new())
	_focus_label = UIK.label("", "")
	_focus_label.tooltip_text = I18n.t("battle.focus_click")
	_focus_label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(UIK.icon("ui_eye"))
	row.add_child(_focus_label)
	row.add_child(UIK.icon_button("ui_close", I18n.t("battle.focus_auto"), _clear_focus, "FlatButton"))
	row.add_child(VSeparator.new())
	_retreat_btn = UIK.button(I18n.t("battle.retreat"), _on_retreat, "ui_retreat", "", true,
		I18n.t("battle.retreat_hint", {"n": I18n.fmt_num(sim.spec.get("retreatSecs", 3))}))
	row.add_child(_retreat_btn)
	_skip_btn = UIK.button(I18n.t("battle.skip"), skip_to_end, "ui_skip", "", true, I18n.t("battle.skip_hint"))
	row.add_child(_skip_btn)


## Keeps the battle overlays clear of the (UI-scaled) HUD strip and the
## navigation bar. Values are in base-viewport pixels.
func set_hud_insets(top_bar: float, _chips: float, bottom: float) -> void:
	if _strip_panel == null:
		return
	_hud_top = top_bar
	_hud_bottom = bottom
	_strip_panel.offset_top = maxf(25.0, top_bar + 3.0)
	_status_panel.offset_top = _strip_panel.offset_top + 20.0
	_boss_bar.offset_top = _strip_panel.offset_top + 21.0
	if _boss_bar.visible:
		_status_panel.offset_top += _boss_bar.get_combined_minimum_size().y + 1.0
	_log_panel.offset_bottom = -maxf(32.0, bottom + 4.0)
	_log_panel.offset_top = _log_panel.offset_bottom


func _refresh_controls() -> void:
	if _pause_btn == null:
		return
	_pause_btn.icon = Art.icon("ui_play" if paused else "ui_pause")
	_pause_btn.tooltip_text = (I18n.t("battle.resume") if paused else I18n.t("battle.pause")) + " (Space)"
	for i in _speed_btns.size():
		_speed_btns[i].set_pressed_no_signal(i == speed_i)
	for id in _stance_btns:
		_stance_btns[id].set_pressed_no_signal(String(sim.stance) == id)
		_stance_btns[id].disabled = _ended
	var idx := 0
	for i in _prio_opt.item_count:
		if _prio_opt.get_item_metadata(i) == String(sim.priority):
			idx = i
	_prio_opt.select(idx)
	_prio_opt.disabled = _ended
	_retreat_btn.disabled = _ended or float(sim.retreating) > 0.0
	_skip_btn.disabled = _ended
	_paused_panel.visible = paused and not _ended and not report_mode


func _update_dynamic_ui() -> void:
	if _wave_label == null:
		return
	_wave_label.text = I18n.t("battle.wave", {"n": int(sim.wave) + 1, "max": sim.spec.waves.size()})
	var secs := float(sim.tick) * Combat.dt()
	_time_label.text = I18n.t("battle.time", {"n": int(secs), "max": int(C.TUNING.battleTimeLimit)})
	var focus_name := I18n.t("battle.focus_auto")
	if sim.focus != null:
		focus_name = _uname(sim.focus)
	_focus_label.text = focus_name
	# The status line only appears for something to act on: a retreat under
	# way or a foe winding up a big attack. The bar shows the tactics.
	var line := ""
	if float(sim.retreating) > 0.0 and not _ended:
		line = I18n.t("battle.retreating", {"n": I18n.fmt_num(snappedf(float(sim.retreating), 0.1))})
	elif not _ended:
		for u in sim.enemies:
			if u.alive and u.windup != null:
				line = I18n.t("battle.winding", {"skill": _skill_name(u.windup.skill), "n": I18n.fmt_num(snappedf(maxf(0.0, float(u.windup.left)), 0.1))})
				break
	_status_label.text = line
	_status_panel.visible = line != "" and not report_mode and not _cine_hold


func toggle_pause() -> void:
	if _ended:
		return
	paused = not paused
	_refresh_controls()


func set_speed(i: int) -> void:
	speed_i = clampi(i, 0, SPEEDS.size() - 1)
	_refresh_controls()


func _issue(type: String, value: Variant) -> void:
	if _ended:
		return
	if Combat.issue(sim, type, value) and paused:
		# Apply now so the paused view reflects the order. This matches what
		# the next Combat.step would do, so the replay stays identical.
		while int(sim.cmdIndex) < sim.commands.size():
			Combat.apply_command(sim, sim.commands[sim.cmdIndex])
			sim.cmdIndex = int(sim.cmdIndex) + 1
		_consume_log()
	_refresh_controls()


func _on_stance(id: String) -> void:
	_issue("stance", id)


func _on_priority(id: Variant) -> void:
	_issue("priority", String(id))


func _clear_focus() -> void:
	_issue("focus", null)


func _on_retreat() -> void:
	_issue("retreat", true)


# ================================================================ camera
## Default framing of the arena (also the HUD "fit" button).
func fit_view() -> void:
	_stop_glide()
	if _on_ship:
		# Frame the whole weather deck with the enemy rail behind it.
		cam.position = _deck_pt(float(_ship_deck.w) * 0.5 - 0.5, float(_ship_deck.h) * 0.5 - 1.2) + Vector2(0, -24)
		_zoom_i = 0
		cam.zoom = Vector2.ONE * ZOOMS[_zoom_i]
		return
	var fv := _fight_view()
	cam.position = fv[0]
	_zoom_i = ZOOMS.find(fv[1])
	cam.zoom = Vector2.ONE * fv[1]


## Every unit's place with room for its sprite, health bar and the numbers
## that float over it (world px).
func _fight_rect() -> Rect2:
	var r := Rect2()
	var first := true
	for uid in _home:
		var a: Actor = _actors.get(uid)
		var h := a.height() if a != null else 30.0
		var box := Rect2(_home[uid] + Vector2(-14.0, -h - 14.0), Vector2(28.0, h + 22.0))
		r = box if first else r.merge(box)
		first = false
	return Rect2(-140, -70, 300, 110) if first else r


## Camera centre and zoom that show the whole fight in the part of the
## screen the HUD leaves free: the closest zoom up to x2 that fits, centred
## between the title strip (and boss bar) and the control bar.
func _fight_view() -> Array:
	var r := _fight_rect()
	var vp := get_viewport_rect().size
	var top := maxf(25.0, _hud_top + 3.0) + 20.0
	if _boss_uid != null:
		top += 21.0
	var bottom := maxf(32.0, _hud_bottom + 4.0)
	var free := Vector2(vp.x - 8.0, vp.y - top - bottom)
	var z := float(ZOOMS[0])
	for zz in ZOOMS:
		if float(zz) <= 2.0 and r.size.x * float(zz) <= free.x and r.size.y * float(zz) <= free.y + 12.0:
			z = float(zz)
	var c := r.get_center()
	c.y -= (top - bottom) * 0.5 / z
	# Lift the fight off the log (bottom left) as far as the free band allows.
	var slack := free.y - r.size.y * z
	if slack > 0.0:
		c.y += clampf(LOG_H - slack * 0.5, 0.0, slack * 0.5) / z
	c.x = clampf(c.x, _bounds.position.x, _bounds.end.x)
	c.y = clampf(c.y, _bounds.position.y, _bounds.end.y)
	return [c.round(), z]


## The opening shot: the whole arena with its set pieces at x1, then the
## camera settles on the fight while the crew walks in. A boss met at the
## start gets its intro instead of the plain settle.
func _open_shot() -> void:
	if restored:
		return
	if _on_ship:
		_show_boss_bar()
		return
	if bool(Settings.get_value("reduceMotion")):
		if _boss_uid != null:
			_boss_intro(_boss_uid)
		return
	var fv := _fight_view()
	var wide: Vector2 = fv[0] + Vector2(0, -34)
	_zoom_i = 0
	cam.zoom = Vector2.ONE * ZOOMS[0]
	cam.position = wide.round()
	_clamp_cam()
	if _boss_uid != null:
		_boss_intro(_boss_uid, 0.5)
		return
	_glide(fv[0], fv[1], 1.15, Tween.EASE_IN_OUT, 0.5)


## Eases the camera to a centre and zoom. The zoom changes geometrically,
## so a x1 -> x2 move feels even; the HUD zoom label follows at the end.
func _glide(to: Vector2, z: float, secs: float, ease := Tween.EASE_IN_OUT, delay := 0.0) -> void:
	_stop_glide()
	var from := cam.position
	var z0 := cam.zoom.x
	_cam_tw = create_tween()
	if delay > 0.0:
		_cam_tw.tween_interval(delay)
	_cam_tw.tween_method(_cam_at.bind(from, z0, to, z), 0.0, 1.0, secs).set_trans(Tween.TRANS_SINE).set_ease(ease)
	_cam_tw.tween_callback(_settle_zoom.bind(z))


func _cam_at(t: float, p0: Vector2, z0: float, p1: Vector2, z1: float) -> void:
	var z := z0 * pow(z1 / z0, t)
	cam.zoom = Vector2.ONE * z
	cam.position = p0.lerp(p1, t)


func _settle_zoom(z: float) -> void:
	var i := ZOOMS.find(z)
	if i >= 0:
		_zoom_i = i
		cam.zoom = Vector2.ONE * z


func _stop_glide() -> void:
	if _cam_tw != null and _cam_tw.is_valid():
		_cam_tw.kill()
	_cam_tw = null
	cam.zoom = Vector2.ONE * ZOOMS[_zoom_i]


# ============================================================ cinematics
func _build_cine_ui() -> void:
	# Intros play over the HUD: the letterbox slides over the top and
	# bottom bars (a click on it skips the intro, like a click on the field).
	_cine_layer = CanvasLayer.new()
	_cine_layer.layer = 6
	add_child(_cine_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Art.theme
	_cine_layer.add_child(root)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0.02, 0.02, 0.035)
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.mouse_filter = Control.MOUSE_FILTER_STOP
		bar.gui_input.connect(_on_letterbox_input)
		bar.visible = false
		root.add_child(bar)
		_letterbox.append(bar)
	_cine_card = UIK.vbox([], 0)
	_cine_card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_cine_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cine_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_cine_card.offset_bottom = -44
	_cine_card.alignment = BoxContainer.ALIGNMENT_END
	_cine_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cine_card.visible = false
	root.add_child(_cine_card)
	_cine_sub = UIK.label("", "DimLabel")
	_cine_name = UIK.label("", "TitleLabel")
	_cine_name.add_theme_font_size_override("font_size", 24)
	_cine_name.add_theme_color_override("font_color", BOSS_RED)
	_cine_sub.add_theme_color_override("font_color", Color(0.93, 0.84, 0.66))
	for l in [_cine_sub, _cine_name]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.04))
		l.add_theme_constant_override("outline_size", 6)
		_cine_card.add_child(l)
	var rule := ColorRect.new()
	rule.color = Color(BOSS_RED, 0.85)
	rule.custom_minimum_size = Vector2(150, 1)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cine_card.add_child(rule)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(1, 0.97, 0.9, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.visible = false
	ui_root.add_child(_flash_rect)


func _on_letterbox_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and _cine_hold:
		_end_cine()


## A boss arrived: mark it with an aura, name it on the boss bar and give
## it an intro (at the start of the fight, after the opening wide shot).
func _meet_boss(uid: Variant, a: Actor, initial: bool) -> void:
	if _boss_met.has(uid):
		return
	_boss_met[uid] = true
	var aura := BossAura.new()
	aura.rx = clampf(a.height() * 0.62, 14.0, 30.0)
	a.add_ground_fx(aura)
	var cur = Combat.unit_by_uid(sim, _boss_uid) if _boss_uid != null else null
	if cur == null or not cur.alive:
		# The bar follows the newest living boss.
		_boss_uid = uid
		_boss_bar.setup(_uname(uid))
		if not initial:
			_boss_bar.visible = false
			_boss_bar.modulate.a = 1.0
	if not initial and not _quiet:
		if _on_ship:
			_show_boss_bar()
		else:
			_boss_intro(uid)
	elif not initial:
		_show_boss_bar()


## Letterbox, the camera on the boss, its roar and name card; the fight
## holds until the intro ends (a click skips it).
func _boss_intro(uid: Variant, delay := 0.0) -> void:
	var a := _actor(uid)
	if a == null:
		return
	_end_cine()
	_cine_hold = true
	var u: Dictionary = _units.get(uid, {})
	_cine_sub.text = I18n.t("battle.boss_rival") if u.get("rival", false) else I18n.t("battle.boss_title", {"place": _place_name()})
	_cine_name.text = _uname(uid)
	_boss_bar.visible = false
	var still := bool(Settings.get_value("reduceMotion"))
	_cine_card.offset_bottom = -(_letterbox_h()[1] + 8.0)
	_cine_tw = create_tween()
	if still:
		_cine_tw.tween_callback(_letterbox_to.bind(1.0))
		_cine_tw.tween_callback(_roar.bind(uid))
		_cine_tw.tween_interval(1.8)
		_cine_tw.tween_callback(_end_cine)
		return
	var z := 2.0
	var home: Vector2 = _home.get(uid, a.position)
	var focus := (home + Vector2(0, -a.height() * 0.5 + 10.0)).round()
	_cine_tw.tween_interval(delay)
	_cine_tw.tween_callback(_letterbox_to.bind(1.0))
	_cine_tw.tween_callback(_glide.bind(focus, z, 0.9))
	_cine_tw.tween_interval(0.95)
	_cine_tw.tween_callback(_roar.bind(uid))
	_cine_tw.tween_interval(1.9)
	_cine_tw.tween_callback(_end_cine)


func _roar(uid: Variant) -> void:
	var a := _actor(uid)
	if a == null:
		return
	a.play("attack", true, 0.6)
	a.flash(Color(1.6, 0.9, 0.9), 0.4)
	Audio.duck(2.2, -10.0)
	Audio.play("boss")
	_shake = maxf(_shake, 0.35) if not bool(Settings.get_value("reduceMotion")) else _shake
	_burst(a.position + Vector2(0, -2), BOSS_RED, 34.0, 10, true)
	_cine_card.visible = true
	_cine_card.modulate.a = 0.0
	_fresh_tween(_cine_card).tween_property(_cine_card, "modulate:a", 1.0, 0.3)


## Ends any intro now: card and letterbox away, the fight framed, the boss
## bar up and the fight running again.
func _end_cine() -> void:
	if _cine_tw != null and _cine_tw.is_valid():
		_cine_tw.kill()
	_cine_tw = null
	var was := _cine_hold
	_cine_hold = false
	if _cine_card == null:
		return
	if _cine_card.visible:
		var tw := _fresh_tween(_cine_card)
		tw.tween_property(_cine_card, "modulate:a", 0.0, 0.25)
		tw.tween_callback(_cine_card.hide)
	_letterbox_to(0.0)
	if not was:
		return
	_show_boss_bar()
	if not report_mode:
		var fv := _fight_view()
		if bool(Settings.get_value("reduceMotion")):
			_stop_glide()
			cam.position = fv[0]
			_settle_zoom(fv[1])
		else:
			_glide(fv[0], fv[1], 0.8)


## The boss bar fades in under the title strip (the status line moves
## below it).
func _show_boss_bar() -> void:
	if _boss_uid == null or report_mode or _ended or _boss_bar.visible:
		return
	_boss_bar.visible = true
	_boss_bar.modulate.a = 0.0
	_fresh_tween(_boss_bar).tween_property(_boss_bar, "modulate:a", 1.0, 0.3)
	set_hud_insets(_hud_top, 0.0, _hud_bottom)


## Letterbox band heights (top, bottom): over the HUD bars, at least a
## tenth of the screen each.
func _letterbox_h() -> Array:
	var tenth := get_viewport_rect().size.y * 0.1
	return [maxf(tenth, _hud_top + 4.0), maxf(tenth, _hud_bottom + 6.0)]


## Slides the letterbox in (k = 1) or out (k = 0); the title strip and the
## log step aside while it is in.
func _letterbox_to(k: float) -> void:
	var hs := _letterbox_h()
	for c in [_strip_panel, _log_panel]:
		if c != null:
			_fresh_tween(c).tween_property(c, "modulate:a", 1.0 - k, 0.3)
	for i in _letterbox.size():
		var bar := _letterbox[i]
		if not bar.visible and k <= 0.0:
			continue
		var tw := _fresh_tween(bar)
		if k > 0.0:
			bar.visible = true
		var h: float = hs[i] * k
		var prop := "offset_bottom" if i == 0 else "offset_top"
		tw.tween_property(bar, prop, h if i == 0 else -h, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if k <= 0.0:
			tw.tween_callback(bar.hide)


## A tween on n that replaces the last one started through here (two
## tweens on one property would fight).
func _fresh_tween(n: Node) -> Tween:
	var old = n.get_meta("fx_tween") if n.has_meta("fx_tween") else null
	if old is Tween and old.is_valid():
		old.kill()
	var tw := n.create_tween()
	n.set_meta("fx_tween", tw)
	return tw


func _place_name() -> String:
	var ctx: Dictionary = enc.get("context", {})
	var loc_id = ctx.get("locationId") if ctx.get("locationId") else ctx.get("toId")
	if loc_id != null and C.location(String(loc_id)) != null:
		return I18n.t("loc.%s.name" % loc_id)
	return I18n.t("region.%s.name" % rid)


func _update_boss_bar() -> void:
	if _boss_bar == null or _boss_uid == null:
		return
	var u = Combat.unit_by_uid(sim, _boss_uid)
	if u == null:
		return
	_boss_bar.set_frac(float(u.hp) / float(maxi(1, int(u.maxHp))) if u.alive else 0.0)
	if not u.alive and _boss_bar.visible and not _boss_bar.leaving:
		_boss_bar.leaving = true
		var tw := _fresh_tween(_boss_bar)
		tw.tween_interval(0.9)
		tw.tween_property(_boss_bar, "modulate:a", 0.0, 0.5)
		tw.tween_callback(_hide_boss_bar)


func _hide_boss_bar() -> void:
	_boss_bar.visible = false
	_boss_bar.leaving = false
	_boss_bar.modulate.a = 1.0
	set_hud_insets(_hud_top, 0.0, _hud_bottom)


## The blow that wins the fight: a moment of slow motion, a soft flash and
## the camera leaning in on the last foe to fall (longer for a boss).
func _finishing_blow() -> void:
	if bool(Settings.get_value("reduceMotion")):
		return
	var a := _actor(_last_ko)
	if a == null:
		return
	var boss: bool = _units.get(_last_ko, {}).get("boss", false)
	var hold := 1.0 if boss else 0.6
	Engine.time_scale = 0.3
	get_tree().create_timer(hold, true, false, true).timeout.connect(_normal_time)
	_flash_rect.visible = true
	_flash_rect.color.a = 0.42 if boss else 0.26
	var ft := _flash_rect.create_tween().set_ignore_time_scale(true)
	ft.tween_property(_flash_rect, "color:a", 0.0, 0.35)
	ft.tween_callback(_flash_rect.hide)
	var p0 := cam.position
	var z0 := cam.zoom.x
	var p1 := p0.lerp(a.position + Vector2(0, -a.height() * 0.5), 0.4).round()
	_stop_glide()
	_cam_tw = create_tween().set_ignore_time_scale(true)
	_cam_tw.tween_method(_cam_at.bind(p0, z0, p1, z0 * 1.3), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cam_tw.tween_interval(hold - 0.2)
	_cam_tw.tween_method(_cam_at.bind(p1, z0 * 1.3, p0, z0), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tw.tween_callback(_settle_zoom.bind(z0))


func _normal_time() -> void:
	Engine.time_scale = 1.0


func _exit_tree() -> void:
	_normal_time()


func zoom_step(dir: int, at_mouse := true) -> void:
	_stop_glide()
	var ni := clampi(_zoom_i + dir, 0, ZOOMS.size() - 1)
	if ni == _zoom_i:
		return
	var before := get_global_mouse_position()
	_zoom_i = ni
	cam.zoom = Vector2.ONE * ZOOMS[_zoom_i]
	if at_mouse:
		cam.position += before - get_global_mouse_position()
	_clamp_cam()


func zoom_label() -> String:
	return "×%d" % int(ZOOMS[_zoom_i])


func _clamp_cam() -> void:
	cam.position.x = clampf(cam.position.x, _bounds.position.x, _bounds.end.x)
	cam.position.y = clampf(cam.position.y, _bounds.position.y, _bounds.end.y)


# ================================================================= input
func _enemy_at(p: Vector2) -> Variant:
	var best: Variant = null
	var best_y := -INF
	for uid in _actors:
		var u = _units.get(uid)
		if u == null or not u.alive:
			continue
		var a: Actor = _actors[uid]
		if a.pick_rect().grow(2).has_point(p) and a.position.y > best_y:
			best = uid
			best_y = a.position.y
	return best


func _unhandled_input(ev: InputEvent) -> void:
	if sim.is_empty():
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
				_stop_glide()
			else:
				_drag = false
				if _drag_moved < 4.0 and mb.button_index == MOUSE_BUTTON_RIGHT and sim.focus != null:
					_clear_focus()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _cine_hold:
				_end_cine()
			elif _ended and not _committed:
				_end_t = 99.0
			else:
				var uid = _enemy_at(get_global_mouse_position())
				if uid != null and _units[uid].side == "enemy":
					_issue("focus", uid)
			get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _drag:
			cam.position -= mm.relative / cam.zoom.x
			_drag_moved += mm.relative.length()
			_clamp_cam()
		var uid2 = _enemy_at(get_global_mouse_position())
		if uid2 != _hover_uid:
			_hover_uid = uid2
			hover_changed.emit(_unit_tip(uid2) if uid2 != null else "")
	elif ev.is_action_pressed("battle_pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("speed_1"):
		set_speed(0)
	elif ev.is_action_pressed("speed_2"):
		set_speed(1)
	elif ev.is_action_pressed("speed_4"):
		set_speed(2)
	elif ev.is_action_pressed("zoom_in"):
		zoom_step(1, false)
	elif ev.is_action_pressed("zoom_out"):
		zoom_step(-1, false)


func _unit_tip(uid: Variant) -> String:
	var u = _units.get(uid)
	if u == null:
		return ""
	var lines := ["%s  Lv %d" % [_uname(uid), int(u.level)], "%d / %d HP" % [int(u.hp), int(u.maxHp)]]
	if u.side == "enemy":
		lines.append(I18n.t("battle.focus_hint"))
	if float(u.st.stun) > 0.0:
		lines.append(I18n.t("battle.ev_stun", {"tgt": _uname(uid), "n": I18n.fmt_num(snappedf(float(u.st.stun), 0.1))}))
	return "\n".join(lines)


## Expanding ring (and optional rays) used by _burst.
class Burst extends Node2D:
	var color := Color.WHITE
	var radius := 20.0
	var rays := 0
	var ground := false
	var f := 0.0:
		set(v):
			f = v
			queue_redraw()

	func _draw() -> void:
		var a := 1.0 - f
		var r := radius * (0.35 + 0.65 * f)
		var c := Color(color.r, color.g, color.b, 0.9 * a)
		var squash := 0.5 if ground else 1.0
		var pts := PackedVector2Array()
		for i in 25:
			var ang := TAU * float(i) / 24.0
			pts.append((Vector2(cos(ang), sin(ang) * squash) * r).round())
		draw_polyline(pts, c, 2.0 if f < 0.5 else 1.0)
		if not ground:
			draw_circle(Vector2.ZERO, r * 0.35 * a, Color(1, 1, 1, 0.7 * a))
		for i in rays:
			var ang2 := TAU * float(i) / float(rays) + 0.3
			var d := Vector2(cos(ang2), sin(ang2))
			draw_line((d * r * 0.55).round(), (d * r * 1.15).round(), c, 2.0)


## The boss's name and health under the title strip. The bar drains with a
## pale trailing chip that catches up a moment later.
class BossBar extends PanelContainer:
	var leaving := false
	var _name: Label
	var _gauge: Gauge

	func _init() -> void:
		theme_type_variation = "ChipPanel"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 1)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		_name = Label.new()
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name.add_theme_color_override("font_color", BOSS_RED)
		box.add_child(_name)
		_gauge = Gauge.new()
		box.add_child(_gauge)

	func setup(title: String) -> void:
		_name.text = title
		_gauge.frac = 1.0
		_gauge.trail = 1.0
		_gauge.queue_redraw()

	func set_frac(f: float) -> void:
		_gauge.set_frac(clampf(f, 0.0, 1.0))


class Gauge extends Control:
	var frac := 1.0
	var trail := 1.0
	var _hold := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(200, 6)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_frac(f: float) -> void:
		if f < frac - 0.0001:
			_hold = 0.45
		frac = f
		if trail < frac:
			trail = frac
		queue_redraw()

	func _process(delta: float) -> void:
		if trail <= frac:
			return
		if _hold > 0.0:
			_hold -= delta
			return
		trail = maxf(frac, trail - delta * 0.6)
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.03, 0.05))
		draw_rect(Rect2(1, 1, w - 2, h - 2), Color(0.18, 0.08, 0.09))
		var inner := w - 2.0
		if trail > frac:
			draw_rect(Rect2(1 + roundf(inner * frac), 1, roundf(inner * (trail - frac)), h - 2), Color(1.0, 0.86, 0.66))
		var fw := roundf(inner * frac)
		if fw > 0.0:
			draw_rect(Rect2(1, 1, fw, h - 2), Color(0.78, 0.2, 0.18))
			draw_rect(Rect2(1, 1, fw, 1), Color(0.98, 0.45, 0.36))
		# Quarter ticks help read how far the fight has come.
		for q in [0.25, 0.5, 0.75]:
			draw_rect(Rect2(1 + roundf(inner * q), 1, 1, h - 2), Color(0.05, 0.03, 0.05, 0.55))


## A slow red ring on the ground under a boss.
class BossAura extends Node2D:
	var rx := 18.0
	var _t := 0.0
	var _still := false

	func _ready() -> void:
		_still = bool(Settings.get_value("reduceMotion"))
		z_index = -1

	func _process(delta: float) -> void:
		if _still:
			return
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(_t * 2.4)
		var ry := rx * 0.5
		var pts := PackedVector2Array()
		for i in 25:
			var a := TAU * float(i) / 24.0
			pts.append(Vector2(cos(a) * rx, sin(a) * ry).round())
		var fill := PackedVector2Array(pts)
		fill.remove_at(fill.size() - 1)
		draw_colored_polygon(fill, Color(BOSS_RED, 0.10 + 0.06 * pulse))
		draw_polyline(pts, Color(BOSS_RED, 0.45 + 0.3 * pulse), 1.0)
		var r2 := rx + 3.0 + 2.0 * pulse
		var arc := PackedVector2Array()
		for i in 25:
			var a := TAU * float(i) / 24.0
			arc.append(Vector2(cos(a) * r2, sin(a) * r2 * 0.5).round())
		draw_polyline(arc, Color(BOSS_RED, 0.18 * (1.0 - pulse)), 1.0)
