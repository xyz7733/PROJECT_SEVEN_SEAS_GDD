## Ambient life for a stage: glints and whitecaps on the water, leaping
## fish, gulls gliding over with their shadows, slow cloud shadows, and
## butterflies by day or fireflies by night over greenery. A lighthouse can
## register a beacon that sweeps a beam after dark.
##
## Add it as a child of a stage (at the stage origin) and set the public
## fields; it reads the active camera each frame and keeps everything inside
## the visible area, so it costs the same on a small island and a big port.
##
## Draw order: the water layer sits just above the sea tiles and below land,
## hull and props, which therefore hide whatever spawns under them. The air
## layer is above the world. Emissive things (fireflies, the beacon) are on
## a canvas layer of their own that follows the camera, so the night tint
## (CanvasModulate) does not dim them.
class_name Ambience
extends Node2D

const META_PATH := "res://assets/gen/env/ambient.json"
const ATLAS_PATH := "res://assets/gen/env/ambient.png"
const WATER_Z := -19
const AIR_Z := 40
const GULL_SEQ := [0, 1, 2, 3, 2, 1]
const FLY_TINTS := [Color("#fff6e0"), Color("#ffd84a"), Color("#8fd0ff"), Color("#ff9ec4")]
const FIREFLY := Color(0.86, 1.0, 0.45)

## Glints per 22,000 px² of visible water (0 turns them off).
var glint_density := 1.0
## Whitecaps per 30,000 px² (open sea; 0 turns them off).
var whitecap_density := 0.0
## How many gulls to keep in the air by day.
var gull_target := 2
## Opacity of the drifting cloud shadows (0 turns them off).
var cloud_alpha := 0.1
## Seconds between fish leaps (min, max); x <= 0 turns them off.
var fish_every := Vector2(5.0, 12.0)
var night := false
## Drift of everything afloat, in px/s: set while the ship is under way so
## the sea streams past.
var drift := Vector2.ZERO
var wind := Vector2(9.0, 4.5)
## World points over land that butterflies and fireflies wander around.
var meadow: Array = []
## World points of lighthouse lamps.
var beacons: Array = []

## The sky over every stage (see Weather and WeatherLayer): heavier cloud
## shadows when overcast, gulls shelter from storms, and butterflies and
## fireflies stay hidden in the rain.
static var sky := "clear"
const SKY_CLOUDS := {"clear": 1.0, "cloudy": 2.2, "rain": 1.8, "storm": 1.5, "fog": 0.5, "ash": 1.2}
const SKY_GULLS := {"rain": 0.5, "storm": 0.0, "fog": 0.5, "ash": 0.5}

static var _meta: Dictionary = {}
static var _atlas: Texture2D

var _water: Node2D
var _air: Node2D
var _glow_layer: CanvasLayer
var _glow: Node2D
var _rng := RandomNumberGenerator.new()
var _glints: Array = []
var _caps: Array = []
var _fish: Array = []
var _gulls: Array = []
var _clouds: Array = []
var _flies: Array = []
var _fish_t := 4.0
var _t := 0.0
var _cloud_a := 0.0
var _night_k := 0.0
var _view := Rect2(-320, -180, 640, 360)
var _meadow_sig := -1


## The shared ambient atlas and the source rect of one frame of a strip, for
## other views that draw these sprites themselves (see SailFx).
static func atlas() -> Texture2D:
	if _meta.is_empty():
		_meta = U.load_json(META_PATH)
		_atlas = load(ATLAS_PATH)
	return _atlas


static func frame_rect(sname: String, frame: int) -> Rect2:
	atlas()
	var d: Dictionary = _meta.get(sname, {})
	if d.is_empty():
		return Rect2()
	var w := float(d.w)
	return Rect2(float(d.rect[0]) + w * float(clampi(frame, 0, int(d.frames) - 1)), float(d.rect[1]), w, float(d.h))


func _init() -> void:
	atlas()
	_rng.seed = 20261114
	_water = Node2D.new()
	_water.z_index = WATER_Z
	_water.draw.connect(_draw_water)
	add_child(_water)
	_air = Node2D.new()
	_air.z_index = AIR_Z
	_air.draw.connect(_draw_air)
	add_child(_air)
	_glow_layer = CanvasLayer.new()
	_glow_layer.layer = 1
	_glow_layer.follow_viewport_enabled = true
	add_child(_glow_layer)
	_glow = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.draw.connect(_draw_glow)
	_glow_layer.add_child(_glow)
	visibility_changed.connect(_sync_glow_layer)


func _ready() -> void:
	_sync_glow_layer()


## A canvas layer does not inherit its parent's visibility.
func _sync_glow_layer() -> void:
	_glow_layer.visible = is_visible_in_tree()


## Drops everything so the next frame repopulates (after a scene rebuild).
func reset() -> void:
	_glints.clear()
	_caps.clear()
	_fish.clear()
	_gulls.clear()
	_clouds.clear()
	_flies.clear()
	_meadow_sig = -1
	_fish_t = _rng.randf_range(2.0, 6.0)


# ------------------------------------------------------------------ frame
func _process(delta: float) -> void:
	_t += delta
	_view = _view_rect()
	_night_k = move_toward(_night_k, 1.0 if night else 0.0, delta * 1.5)
	_tick_glints(delta)
	_tick_caps(delta)
	_tick_fish(delta)
	_tick_gulls(delta)
	_tick_clouds(delta)
	_tick_flies()
	_water.queue_redraw()
	_air.queue_redraw()
	_glow.queue_redraw()


## The visible world rectangle in this node's coordinates.
func _view_rect() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return _view
	var to_local := (vp.get_canvas_transform() * get_global_transform()).affine_inverse()
	return to_local * Rect2(Vector2.ZERO, vp.get_visible_rect().size)


func _rand_in(r: Rect2) -> Vector2:
	return Vector2(_rng.randf_range(r.position.x, r.end.x), _rng.randf_range(r.position.y, r.end.y))


func _tick_glints(delta: float) -> void:
	var area := _view.size.x * _view.size.y
	var want := 0
	if glint_density > 0.0:
		want = clampi(int(area / 22000.0 * glint_density * (0.5 if night else 1.0)), 4, 40)
	while _glints.size() < want:
		_glints.append({"p": _rand_in(_view), "t": _rng.randf(), "dur": _rng.randf_range(0.5, 0.95)})
	if _glints.size() > want:
		_glints.resize(want)
	var pad := _view.grow(12.0)
	for g in _glints:
		g.t += delta / float(g.dur)
		g.p += drift * delta
		if g.t >= 1.0 or not pad.has_point(g.p):
			g.p = _rand_in(_view)
			g.t = 0.0 if g.t >= 1.0 else g.t
			g.dur = _rng.randf_range(0.5, 0.95)


func _tick_caps(delta: float) -> void:
	var area := _view.size.x * _view.size.y
	var want := 0
	if whitecap_density > 0.0:
		want = clampi(int(area / 30000.0 * whitecap_density), 2, 28)
	while _caps.size() < want:
		_caps.append({"p": _rand_in(_view), "t": _rng.randf(), "dur": _rng.randf_range(0.9, 1.5), "flip": _rng.randf() < 0.5})
	if _caps.size() > want:
		_caps.resize(want)
	var pad := _view.grow(24.0)
	for c in _caps:
		c.t += delta / float(c.dur)
		c.p += drift * delta
		if c.t >= 1.0 or not pad.has_point(c.p):
			# Under way, new crests appear ahead so they stream past the hull.
			c.p = _rand_in(_view) if c.t >= 1.0 or drift == Vector2.ZERO else _rand_in(_view) - drift.normalized() * 8.0
			c.t = 0.0 if c.t >= 1.0 else c.t
			c.dur = _rng.randf_range(0.9, 1.5)
			c.flip = _rng.randf() < 0.5


func _tick_fish(delta: float) -> void:
	for f in _fish:
		f.t += delta * 9.0
		f.p += drift * delta
	_fish = _fish.filter(func(f): return float(f.t) < 8.0)
	if fish_every.x <= 0.0:
		return
	_fish_t -= delta
	if _fish_t <= 0.0:
		_fish_t = _rng.randf_range(fish_every.x, fish_every.y)
		_fish.append({"p": _rand_in(_view.grow(-24.0)), "t": 0.0, "flip": _rng.randf() < 0.5})


func _spawn_gull(g: Dictionary) -> void:
	var r := _view.grow(50.0)
	var side := _rng.randi() % 4
	var from := Vector2.ZERO
	match side:
		0:
			from = Vector2(r.position.x, _rng.randf_range(r.position.y, r.end.y))
		1:
			from = Vector2(r.end.x, _rng.randf_range(r.position.y, r.end.y))
		2:
			from = Vector2(_rng.randf_range(r.position.x, r.end.x), r.position.y)
		_:
			from = Vector2(_rng.randf_range(r.position.x, r.end.x), r.end.y)
	var to := _rand_in(_view.grow(-_view.size.x * 0.2))
	g.p = from
	g.v = (to - from).normalized() * _rng.randf_range(34.0, 56.0)
	g.alt = _rng.randf_range(44.0, 78.0)
	g.turn = _rng.randf_range(-0.14, 0.14)
	g.ph = _rng.randf() * 6.0
	g.wait = 0.0
	g.seen = false


func _tick_gulls(delta: float) -> void:
	var want := 0 if night else int(round(float(gull_target) * float(SKY_GULLS.get(sky, 1.0))))
	while _gulls.size() < want:
		var g := {"p": Vector2.ZERO, "v": Vector2.RIGHT, "alt": 60.0, "turn": 0.0, "ph": 0.0, "wait": 0.0, "seen": false}
		_spawn_gull(g)
		if _gulls.is_empty() and _t < 1.0:
			# The first gull is already on its way across when a scene opens.
			g.p = _rand_in(_view.grow(-_view.size.x * 0.25))
			g.seen = true
		else:
			g.wait = _rng.randf_range(0.5, 6.0)
		_gulls.append(g)
	var far := _view.grow(110.0)
	for i in range(_gulls.size() - 1, -1, -1):
		var g: Dictionary = _gulls[i]
		if float(g.wait) > 0.0:
			g.wait = float(g.wait) - delta
			continue
		g.v = (g.v as Vector2).rotated(float(g.turn) * delta)
		g.p += g.v * delta
		g.ph = float(g.ph) + delta
		if _view.has_point(g.p):
			g.seen = true
		if not far.has_point(g.p) or (g.seen and not _view.grow(40.0).has_point(g.p)):
			if _gulls.size() > want:
				_gulls.remove_at(i)
			else:
				_spawn_gull(g)
				g.wait = _rng.randf_range(2.0, 9.0)


func _tick_clouds(delta: float) -> void:
	var target := cloud_alpha * (0.3 if night else 1.0) * float(SKY_CLOUDS.get(sky, 1.0))
	_cloud_a = move_toward(_cloud_a, target, delta * 0.2)
	if cloud_alpha <= 0.0 and _cloud_a <= 0.0:
		_clouds.clear()
		return
	var margin := 380.0
	var r := _view.grow(margin)
	while _clouds.size() < 4:
		var names := ["cloud_a", "cloud_b", "cloud_c", "cloud_a"]
		_clouds.append({"p": _rand_in(r), "n": names[_clouds.size()], "s": 1.0, "k": _rng.randf_range(0.8, 1.25)})
	for c in _clouds:
		c.p += (wind * float(c.k) + drift) * delta
		if c.p.x > r.end.x:
			c.p.x -= r.size.x
			c.p.y = _rng.randf_range(r.position.y, r.end.y)
		elif c.p.x < r.position.x:
			c.p.x += r.size.x
		if c.p.y > r.end.y:
			c.p.y -= r.size.y
			c.p.x = _rng.randf_range(r.position.x, r.end.x)
		elif c.p.y < r.position.y:
			c.p.y += r.size.y


func _tick_flies() -> void:
	if meadow.size() == _meadow_sig:
		return
	_meadow_sig = meadow.size()
	_flies.clear()
	if meadow.is_empty():
		return
	var n := mini(12, meadow.size())
	var step := maxi(1, meadow.size() / n)
	for i in n:
		var at: Vector2 = meadow[(i * step + _rng.randi() % step) % meadow.size()]
		_flies.append({"a": at, "ph": _rng.randf() * TAU, "r": _rng.randf_range(7.0, 16.0), "c": FLY_TINTS[_rng.randi() % FLY_TINTS.size()],
			"sp": _rng.randf_range(0.6, 1.1)})


# ------------------------------------------------------------------- draw
func _blit(ci: CanvasItem, sname: String, frame: int, at: Vector2, flip := false, mod := Color.WHITE, scale_f := 1.0) -> void:
	var src := frame_rect(sname, frame)
	if src.size == Vector2.ZERO:
		return
	var size := src.size * scale_f
	var dst := Rect2((at - size * 0.5).round(), size)
	if flip:
		# A negative width mirrors the sprite and draws leftward from the origin.
		dst.position.x += size.x
		dst.size.x = -size.x
	ci.draw_texture_rect_region(_atlas, dst, src, mod)


func _draw_water() -> void:
	var tint := Color(1, 1, 1, 0.9).lerp(Color(0.8, 0.88, 1.0, 0.75), _night_k)
	for g in _glints:
		_blit(_water, "glint", int(float(g.t) * 5.0), g.p, false, tint)
	for c in _caps:
		_blit(_water, "whitecap", int(float(c.t) * 6.0), c.p, c.flip, Color(1, 1, 1, 0.85))
	for f in _fish:
		_blit(_water, "fish", int(f.t), f.p, f.flip)


func _draw_air() -> void:
	if _cloud_a > 0.003:
		var cm := Color(1, 1, 1, _cloud_a)
		for c in _clouds:
			_blit(_air, String(c.n), 0, c.p, false, cm, float(c.s))
	var day := 1.0 - _night_k
	for g in _gulls:
		if float(g.wait) > 0.0:
			continue
		var p: Vector2 = g.p
		var ph := float(g.ph)
		# Flap for a moment, then glide on level wings.
		var cyc := fmod(ph, 3.2)
		var fr := 2
		if cyc < 1.3:
			fr = GULL_SEQ[int(cyc * 9.0) % GULL_SEQ.size()]
		var alt := float(g.alt) + sin(ph * 1.7) * 2.0
		_blit(_air, "gull_shadow", 0, p, false, Color(1, 1, 1, 0.2 * day))
		_blit(_air, "gull", fr, p + Vector2(0, -alt), (g.v as Vector2).x < 0.0, Color(1, 1, 1, day))
	if day > 0.05 and not Weather.wet(sky):
		for f in _flies:
			var t := _t * float(f.sp) + float(f.ph)
			var at: Vector2 = f.a + Vector2(cos(t * 0.9) * float(f.r), sin(t * 1.3) * float(f.r) * 0.5 - 9.0 + sin(t * 5.0) * 1.5)
			var c: Color = f.c
			_blit(_air, "butterfly", int(_t * 8.0 + float(f.ph)) % 2, at, cos(t * 0.9) < 0.0, Color(c.r, c.g, c.b, day))


func _draw_glow() -> void:
	if _night_k <= 0.02:
		return
	for f in ([] if Weather.wet(sky) else _flies):
		var t := _t * float(f.sp) * 0.6 + float(f.ph)
		var at: Vector2 = (f.a + Vector2(cos(t * 0.7) * float(f.r) * 1.4, sin(t * 1.1) * float(f.r) * 0.6 - 8.0)).round()
		var a := _night_k * clampf(0.5 + 0.5 * sin(_t * 2.2 + float(f.ph) * 3.0), 0.0, 1.0)
		if a <= 0.03:
			continue
		_glow.draw_rect(Rect2(at, Vector2.ONE), Color(FIREFLY.r, FIREFLY.g, FIREFLY.b, a))
		_glow.draw_rect(Rect2(at + Vector2(-1, 0), Vector2(3, 1)), Color(FIREFLY.r, FIREFLY.g, FIREFLY.b, a * 0.3))
		_glow.draw_rect(Rect2(at + Vector2(0, -1), Vector2(1, 3)), Color(FIREFLY.r, FIREFLY.g, FIREFLY.b, a * 0.3))
	for b in beacons:
		_draw_beam(b as Vector2)


## Two opposite wedges of light turning in the ground plane (squashed 2:1
## for the isometric view), bright at the lamp and fading out.
func _draw_beam(at: Vector2) -> void:
	var ang := _t * 0.55
	var reach := 230.0
	var near := Color(1.0, 0.92, 0.62, 0.34 * _night_k)
	var far := Color(1.0, 0.92, 0.62, 0.0)
	for side in 2:
		var a := ang + PI * float(side)
		var p1 := at + Vector2(cos(a - 0.13), sin(a - 0.13) * 0.5) * reach
		var p2 := at + Vector2(cos(a + 0.13), sin(a + 0.13) * 0.5) * reach
		_glow.draw_primitive(PackedVector2Array([at, p1, p2]), PackedColorArray([near, far, far]), PackedVector2Array())
