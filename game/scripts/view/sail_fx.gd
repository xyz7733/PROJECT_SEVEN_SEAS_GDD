## White water thrown up by a hull under way, drawn in the ship's own space
## under the hull sprites:
##   - a pale churned trail astern that fades with distance;
##   - foam shed along both waterlines (thickest at the bow) and boiled up
##     under the stern, drifting astern with the sea and breaking up;
##   - a curling bow wave on each side of the stem;
##   - bursts of spray at the stem, raised above the hull.
## Foam shed on the far side only shows once it has cleared the stern.
class_name SailFx
extends Node2D

const SIDE_RATE := 150.0
const STERN_RATE := 190.0
const LIFE := Vector2(1.2, 2.6)
const AXIS := Vector2(0.8944, 0.4472)    # heading (stern to bow)
const NEAR := Vector2(-0.4472, 0.8944)   # outward from the near (port) side
const FAR := Vector2(0.4472, -0.8944)
const TRAIL := 300.0

## Waterline points from stern (index 0) to bow, near side and far side.
var port_pts := PackedVector2Array()
var star_pts := PackedVector2Array()
## Sea drift relative to the hull, px/s.
var drift := Vector2(-54, -27)
var active := false:
	set(v):
		active = v
		set_process(true)

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _span := PackedFloat32Array()
var _size := PackedByteArray()
var _side_acc := 0.0
var _stern_acc := 0.0
var _spray_t := 0.0
var _sprays: Array = []
var _spray_node: Node2D
var _rng := RandomNumberGenerator.new()
var _t := 0.0
## 0..1: how developed the wake is (grows after getting under way).
var _k := 0.0


func _init() -> void:
	_rng.seed = 4711
	_spray_node = Node2D.new()
	_spray_node.z_index = 9
	_spray_node.draw.connect(_draw_spray)
	add_child(_spray_node)


func _emit(at: Vector2, vel: Vector2, big: int) -> void:
	_pos.append(at)
	_vel.append(vel)
	_life.append(0.0)
	_span.append(_rng.randf_range(LIFE.x, LIFE.y))
	_size.append(big)


func _bow() -> Vector2:
	var n := port_pts.size()
	return (port_pts[n - 1] + star_pts[n - 1]) * 0.5


func _process(delta: float) -> void:
	_t += delta
	var n := port_pts.size()
	_k = move_toward(_k, 1.0 if active else 0.0, delta * (1.6 if active else 0.9))
	if active and n >= 2:
		_side_acc += SIDE_RATE * delta
		while _side_acc >= 1.0:
			_side_acc -= 1.0
			# Squared bias: most foam is shed by the bow, less along the sides.
			var u := _rng.randf()
			var i := clampi(n - 1 - int(u * u * float(n)), 0, n - 1)
			var near := _rng.randf() < 0.65
			var out := NEAR if near else FAR
			var base: Vector2 = port_pts[i] if near else star_pts[i]
			_emit(base + out * _rng.randf_range(0.0, 4.0) + Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-1, 1)),
				drift * _rng.randf_range(0.82, 1.0) + out * _rng.randf_range(4.0, 20.0), _rng.randi() % 3)
		_stern_acc += STERN_RATE * delta
		while _stern_acc >= 1.0:
			_stern_acc -= 1.0
			var k := _rng.randf()
			var at: Vector2 = port_pts[0].lerp(star_pts[0], k)
			_emit(at + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-3, 3)),
				drift * _rng.randf_range(0.65, 1.0) + (NEAR if k < 0.5 else FAR) * _rng.randf_range(0.0, 12.0) * absf(k - 0.5) * 2.0,
				1 + _rng.randi() % 2)
		_spray_t -= delta
		if _spray_t <= 0.0:
			_spray_t = _rng.randf_range(0.22, 0.5)
			_sprays.append({"p": _bow() + NEAR * _rng.randf_range(-14.0, 16.0) + Vector2(_rng.randf_range(-6, 6), 2.0), "t": 0.0,
				"flip": _rng.randf() < 0.5, "s": 2.0 if _rng.randf() < 0.7 else 3.0})
	var i2 := 0
	while i2 < _life.size():
		_life[i2] += delta
		if _life[i2] >= _span[i2]:
			var last := _life.size() - 1
			_pos[i2] = _pos[last]
			_vel[i2] = _vel[last]
			_life[i2] = _life[last]
			_span[i2] = _span[last]
			_size[i2] = _size[last]
			_pos.resize(last)
			_vel.resize(last)
			_life.resize(last)
			_span.resize(last)
			_size.resize(last)
			continue
		_pos[i2] += _vel[i2] * delta
		i2 += 1
	for s in _sprays:
		s.t += delta * 10.0
		s.p += drift * delta * 0.35
	_sprays = _sprays.filter(func(s): return float(s.t) < 5.0)
	queue_redraw()
	_spray_node.queue_redraw()
	if not active and _k <= 0.0 and _life.is_empty() and _sprays.is_empty():
		set_process(false)


func _draw() -> void:
	var n := port_pts.size()
	if n < 2:
		return
	if _k > 0.0:
		# Churned trail astern: widening, fading out.
		var back := -AXIS * TRAIL
		var sp := port_pts[0]
		var ss := star_pts[0]
		var c0 := Color(0.8, 0.92, 1.0, 0.17 * _k)
		var c1 := Color(0.8, 0.92, 1.0, 0.0)
		draw_polygon(PackedVector2Array([sp, ss, ss + back + FAR * 34.0, sp + back + NEAR * 34.0]), PackedColorArray([c0, c0, c1, c1]))
		# Bow wave: foam curling off the stem and peeling away from each
		# waterline as it runs aft.
		var arm := mini(16, n - 1)
		for side in 2:
			var out := NEAR if side == 0 else FAR
			var src := port_pts if side == 0 else star_pts
			var pts := PackedVector2Array()
			for j in arm + 1:
				var u := float(j) / float(arm)
				var wob := sin(_t * 7.0 - u * 6.0 + float(side) * 2.0) * 1.3
				pts.append((src[n - 1 - j] + out * (2.0 + 15.0 * sqrt(u) + wob) + AXIS * (4.0 * (1.0 - u))).round())
			for j in arm:
				var u2 := float(j) / float(arm)
				var w := 4.0 - 3.0 * u2
				draw_line(pts[j], pts[j + 1], Color(0.72, 0.87, 0.98, 0.8 * _k * (1.0 - u2 * 0.7)), w + 2.0)
				draw_line(pts[j], pts[j + 1], Color(1, 1, 1, _k * (1.0 - u2 * 0.6)), w)
	for i in _life.size():
		var f := _life[i] / _span[i]
		var p := _pos[i].round()
		var big := int(_size[i])
		if f < 0.3:
			draw_rect(Rect2(p, Vector2(3 + big, 2)), Color(1, 1, 1, 0.95))
		elif f < 0.62:
			draw_rect(Rect2(p, Vector2(2 + big, 1 + mini(big, 1))), Color(0.88, 0.95, 1.0, 0.82))
		else:
			draw_rect(Rect2(p, Vector2(1 + mini(big, 1), 1)), Color(0.74, 0.88, 0.98, 0.75 * (1.0 - f) / 0.38))


func _draw_spray() -> void:
	var tex := Ambience.atlas()
	for s in _sprays:
		var src := Ambience.frame_rect("spray", int(s.t))
		var size := src.size * float(s.s)
		var dst := Rect2(((s.p as Vector2) - Vector2(size.x * 0.5, size.y)).round(), size)
		if s.flip:
			dst.position.x += size.x
			dst.size.x = -size.x
		_spray_node.draw_texture_rect_region(tex, dst, src)
