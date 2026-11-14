## The sky over whichever stage is showing (see Weather for what the weather
## is; this only draws and plays it):
## - an overcast tint multiplied over the world,
## - rain streaks falling across the screen and splashes pinned to the
##   world where they land,
## - fog banks that drift with the world, ordered-dithered like the art,
## - falling ash with the odd ember,
## - in storms, lightning flashes followed by thunder after a delay that
##   says how far off it struck.
##
## The main scene owns one and calls set_sky() when the stage, region or
## watch changes. It sits on canvas layer 2: above the world and its glow
## layer, below the stage overlays and the HUD. Settings "weather" turns it
## off; "reduceMotion" keeps the rain and fog but drops the flashes.
class_name WeatherLayer
extends CanvasLayer

## Per sky: overcast tint (multiplied), rain, fog and ash strength (0..1).
const LOOKS := {
	"clear": {"tint": Color(1, 1, 1), "rain": 0.0, "fog": 0.0, "ash": 0.0},
	"cloudy": {"tint": Color(0.84, 0.87, 0.93), "rain": 0.0, "fog": 0.12, "ash": 0.0},
	"rain": {"tint": Color(0.78, 0.82, 0.9), "rain": 0.65, "fog": 0.2, "ash": 0.0},
	"storm": {"tint": Color(0.64, 0.68, 0.8), "rain": 1.0, "fog": 0.3, "ash": 0.0},
	"fog": {"tint": Color(0.94, 0.95, 0.97), "rain": 0.0, "fog": 1.0, "ash": 0.0},
	"ash": {"tint": Color(0.86, 0.78, 0.72), "rain": 0.0, "fog": 0.45, "ash": 1.0},
}
## Fog colour by region (default: sea mist).
const FOG_TINT := {
	"moonwake": Color(0.78, 0.72, 0.94),
	"emberreach": Color(0.86, 0.72, 0.6),
	"ashen_trench": Color(0.7, 0.66, 0.66),
	"verdant_maw": Color(0.78, 0.88, 0.78),
}
const FOG_DEFAULT := Color(0.86, 0.9, 0.95)
## Streaks / flakes at full strength per 640x360 screen.
const MAX_STREAKS := 300
const MAX_FLAKES := 130
const MAX_SPLASHES := 70
const EASE := 0.45

var kind := "clear"
var region_id := ""
var under := false
var night := false

var _tint: ColorRect
var _fog: ColorRect
var _fog_mat: ShaderMaterial
var _air: Node2D
var _flash: ColorRect
var _rng := RandomNumberGenerator.new()
var _k := {"rain": 0.0, "fog": 0.0, "ash": 0.0}
var _tint_now := Color(1, 1, 1)
var _streaks: Array = []
var _flakes: Array = []
var _splashes: Array = []
var _bolt_t := 6.0
var _flash_tw: Tween
var _t := 0.0


func _init() -> void:
	layer = 2
	_rng.seed = 1114
	_tint = ColorRect.new()
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mul := CanvasItemMaterial.new()
	mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_tint.material = mul
	_tint.color = Color.WHITE
	add_child(_tint)
	_fog = ColorRect.new()
	_fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = _fog_shader()
	_fog.material = _fog_mat
	_fog.visible = false
	add_child(_fog)
	_air = Node2D.new()
	_air.draw.connect(_draw_air)
	add_child(_air)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flash.material = add
	_flash.color = Color(0.7, 0.76, 1.0, 0.0)
	_flash.visible = false
	add_child(_flash)


## Shows a sky. `under`: the stage is underground (no weather at all).
## `snap`: jump straight to it (a fresh stage) instead of easing over.
func set_sky(sky: String, region: String, underground: bool, is_night: bool, snap := false) -> void:
	var on := bool(Settings.get_value("weather"))
	kind = sky if LOOKS.has(sky) and on else "clear"
	region_id = region
	under = underground
	night = is_night
	if under or kind != "storm":
		if _flash_tw != null and _flash_tw.is_valid():
			_flash_tw.kill()
		_flash.visible = false
		_flash.color.a = 0.0
	Ambience.sky = "clear" if under else kind
	var bed := ""
	if not under and Weather.wet(kind):
		bed = kind
	Audio.weather(bed)
	if snap:
		var look := _look()
		_tint_now = look.tint
		for e in _k:
			_k[e] = float(look[e])
		_streaks.clear()
		_flakes.clear()
		_splashes.clear()
	_bolt_t = _rng.randf_range(2.5, 6.0)


func _look() -> Dictionary:
	if under:
		return LOOKS.clear
	return LOOKS.get(kind, LOOKS.clear)


func _process(delta: float) -> void:
	_t += delta
	var look := _look()
	var e := clampf(delta * EASE, 0.0, 1.0)
	_tint_now = _tint_now.lerp(look.tint, e)
	for k in _k:
		_k[k] = move_toward(float(_k[k]), float(look[k]), delta * EASE)
	var tint := _tint_now
	if night:
		# The night tint already darkens the world; keep the overcast milder.
		tint = Color(1, 1, 1).lerp(tint, 0.6)
	_tint.color = tint
	_tint.visible = not tint.is_equal_approx(Color.WHITE)
	_update_fog()
	var size := _screen()
	var area := size.x * size.y / (640.0 * 360.0)
	_tick_streaks(delta, size, int(round(MAX_STREAKS * area * float(_k.rain))))
	_tick_flakes(delta, size, int(round(MAX_FLAKES * area * float(_k.ash))))
	_tick_splashes(delta)
	_tick_lightning(delta)
	_air.queue_redraw()


func _screen() -> Vector2:
	var vp := get_viewport()
	return vp.get_visible_rect().size if vp != null else Vector2(640, 360)


func _canvas() -> Transform2D:
	var vp := get_viewport()
	return vp.get_canvas_transform() if vp != null else Transform2D.IDENTITY


# ------------------------------------------------------------------ rain
## Rain slants with the wind (down and to the right, like the cloud drift).
func _rain_dir() -> Vector2:
	return Vector2(0.22 + 0.2 * float(_k.rain), 1.0).normalized()


func _tick_streaks(delta: float, size: Vector2, want: int) -> void:
	while _streaks.size() < want:
		var s := _new_streak(size)
		# Spread the first fall over the whole screen height.
		s.p.y = _rng.randf_range(-20.0, size.y)
		_streaks.append(s)
	var dir := _rain_dir()
	var xf := _canvas()
	for i in range(_streaks.size() - 1, -1, -1):
		var s: Dictionary = _streaks[i]
		s.p += dir * float(s.v) * delta
		if s.p.y >= float(s.land):
			if _splashes.size() < MAX_SPLASHES:
				_splashes.append({"w": xf.affine_inverse() * (s.p as Vector2), "t": 0.0})
			if _streaks.size() > want:
				_streaks.remove_at(i)
			else:
				_streaks[i] = _new_streak(size)


func _new_streak(size: Vector2) -> Dictionary:
	var heavy := float(_k.rain)
	return {
		"p": Vector2(_rng.randf_range(-60.0, size.x), _rng.randf_range(-24.0, -4.0)),
		"v": _rng.randf_range(300.0, 380.0) + 120.0 * heavy,
		"len": _rng.randf_range(4.0, 7.0) + 3.0 * heavy,
		"land": _rng.randf_range(size.y * 0.15, size.y + 10.0),
		"a": _rng.randf_range(0.3, 0.62),
	}


func _tick_splashes(delta: float) -> void:
	for i in range(_splashes.size() - 1, -1, -1):
		_splashes[i].t = float(_splashes[i].t) + delta
		if float(_splashes[i].t) > 0.24:
			_splashes.remove_at(i)


# ------------------------------------------------------------------- ash
func _tick_flakes(delta: float, size: Vector2, want: int) -> void:
	while _flakes.size() < want:
		var f := _new_flake(size)
		f.p.y = _rng.randf_range(0.0, size.y)
		_flakes.append(f)
	for i in range(_flakes.size() - 1, -1, -1):
		var f: Dictionary = _flakes[i]
		f.p += Vector2(8.0 + sin(_t * float(f.w) + float(f.ph)) * 10.0, float(f.v)) * delta
		if f.p.y > size.y + 4.0 or f.p.x > size.x + 8.0:
			if _flakes.size() > want:
				_flakes.remove_at(i)
			else:
				_flakes[i] = _new_flake(size)


func _new_flake(size: Vector2) -> Dictionary:
	var ember := _rng.randf() < (0.14 if region_id == "emberreach" else 0.05)
	return {
		"p": Vector2(_rng.randf_range(-30.0, size.x), _rng.randf_range(-12.0, -2.0)),
		"v": _rng.randf_range(12.0, 30.0), "w": _rng.randf_range(0.8, 2.2), "ph": _rng.randf_range(0.0, TAU),
		"ember": ember, "big": _rng.randf() < 0.3,
	}


# ------------------------------------------------------------------- fog
func _update_fog() -> void:
	var d := float(_k.fog)
	_fog.visible = d > 0.01
	if not _fog.visible:
		return
	var xf := _canvas()
	var zoom := xf.x.length()
	var col: Color = FOG_TINT.get(region_id, FOG_DEFAULT)
	if night:
		col = col.darkened(0.55)
	_fog_mat.set_shader_parameter("fog_color", col)
	_fog_mat.set_shader_parameter("density", d)
	_fog_mat.set_shader_parameter("origin", xf.affine_inverse() * Vector2.ZERO)
	_fog_mat.set_shader_parameter("zoom", zoom)
	_fog_mat.set_shader_parameter("view_size", _screen())
	_fog_mat.set_shader_parameter("drift", Vector2(_t * 4.0, _t * 1.4))


static var _shader: Shader


static func _fog_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = FOG_SHADER
	return _shader


## Fog banks: value noise in world space (squashed 2:1 onto the iso ground
## plane) drifting with the wind, quantised to four levels with a 4x4
## ordered dither on the screen's pixel grid.
const FOG_SHADER := """
shader_type canvas_item;
uniform vec4 fog_color : source_color = vec4(0.86, 0.9, 0.95, 1.0);
uniform float density = 0.0;
uniform vec2 origin = vec2(0.0);
uniform float zoom = 1.0;
uniform vec2 view_size = vec2(640.0, 360.0);
uniform vec2 drift = vec2(0.0);

float h(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[y * 4 + x]) + 0.5) / 16.0;
}

void fragment() {
	vec2 px = floor(UV * view_size);
	vec2 w = origin + (px + 0.5) / zoom;
	vec2 q = (w + drift) * vec2(1.0, 2.0) / 150.0;
	float n = vnoise(q) * 0.6 + vnoise(q * 2.3 + 7.1) * 0.28 + vnoise(q * 5.1 - 3.7) * 0.12;
	// Thicker towards the top of the screen (farther away).
	float far = 1.0 - UV.y * 0.45;
	float d = clamp((n - 0.28) * 1.7, 0.0, 1.0) * density * far;
	float lv = floor(d * 4.0 + bayer4(px)) / 4.0;
	COLOR = vec4(fog_color.rgb, clamp(lv * 0.55, 0.0, 0.6));
}
"""


# ------------------------------------------------------------- lightning
func _tick_lightning(delta: float) -> void:
	if under or kind != "storm":
		return
	_bolt_t -= delta
	if _bolt_t > 0.0:
		return
	_bolt_t = _rng.randf_range(7.0, 16.0)
	var dist := _rng.randf_range(0.2, 2.6)
	if not bool(Settings.get_value("reduceMotion")):
		_strike(1.0 - clampf(dist / 2.6, 0.0, 0.8))
	get_tree().create_timer(dist, false).timeout.connect(_thunder.bind(dist))


func _strike(near: float) -> void:
	if _flash_tw != null and _flash_tw.is_valid():
		_flash_tw.kill()
	_flash.visible = true
	var peak := (0.32 if night else 0.22) * (0.5 + 0.5 * near)
	_flash.color.a = peak
	_flash_tw = create_tween()
	_flash_tw.tween_property(_flash, "color:a", peak * 0.15, 0.06)
	_flash_tw.tween_property(_flash, "color:a", peak * 0.8, 0.05)
	_flash_tw.tween_property(_flash, "color:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tw.tween_callback(_flash.hide)


func _thunder(dist: float) -> void:
	if kind != "storm" or under:
		return
	Audio.play("thunder_near" if dist < 1.1 else "thunder_far", -2.0 * dist)


# ------------------------------------------------------------------ draw
func _draw_air() -> void:
	var c := Color(0.78, 0.84, 0.95) if not night else Color(0.5, 0.56, 0.7)
	var dir := _rain_dir()
	for s in _streaks:
		var p: Vector2 = (s.p as Vector2).round()
		_air.draw_line(p, (p - dir * float(s.len)).round(), Color(c, float(s.a)), 1.0)
	var xf := _canvas()
	for sp in _splashes:
		var at: Vector2 = (xf * (sp.w as Vector2)).round()
		var t := float(sp.t) / 0.24
		var a := 0.55 * (1.0 - t)
		if t < 0.4:
			_air.draw_rect(Rect2(at + Vector2(-1, 0), Vector2(3, 1)), Color(c, a))
			_air.draw_rect(Rect2(at + Vector2(-1, -1), Vector2(1, 1)), Color(c, a * 0.8))
			_air.draw_rect(Rect2(at + Vector2(1, -1), Vector2(1, 1)), Color(c, a * 0.8))
		else:
			_air.draw_rect(Rect2(at + Vector2(-2, 0), Vector2(1, 1)), Color(c, a))
			_air.draw_rect(Rect2(at + Vector2(2, 0), Vector2(1, 1)), Color(c, a))
			_air.draw_rect(Rect2(at + Vector2(-1, -1), Vector2(3, 1)), Color(c, a * 0.5))
			_air.draw_rect(Rect2(at + Vector2(-1, 1), Vector2(3, 1)), Color(c, a * 0.5))
	for f in _flakes:
		var p2: Vector2 = (f.p as Vector2).round()
		var col := Color(1.0, 0.56, 0.22, 0.9) if f.ember else Color(0.6, 0.57, 0.56, 0.85)
		if f.ember:
			col.a *= 0.6 + 0.4 * sin(_t * 6.0 + float(f.ph))
		_air.draw_rect(Rect2(p2, Vector2(2 if f.big else 1, 2 if f.big else 1)), col)
