## The change between stages (title, ship, island, battle). Instead of a hard
## cut, the last frame of the old stage is frozen on top and swept away in
## the art's own pixel grid: a diagonal band with a 4x4 ordered-dither edge
## and a thin dark rim, forwards when going into a place and backwards when
## coming out. With "reduceMotion" it is a plain short crossfade.
##
## The main scene owns one and calls cover() just before it swaps the stage;
## the frame on screen is still the old one at that point. It sits on canvas
## layer 9: over the world, the HUD and the battle cinematics, under modal
## dialogs. It never takes input.
class_name Curtain
extends CanvasLayer

const SECS := 0.5
const FADE_SECS := 0.25
## Art pixels per dither cell (2 keeps the pattern readable at 640x360).
const CELL := 2.0

var _rect: TextureRect
var _mat: ShaderMaterial
var _tw: Tween
var _frame := -1


func _init() -> void:
	layer = 9
	_rect = TextureRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mat = ShaderMaterial.new()
	_mat.shader = _curtain_shader()
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


## Freezes the frame on screen and sweeps it away. `out` reverses the sweep
## (leaving a place). Several stage swaps in one frame share one curtain.
func cover(out := false) -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	if Engine.get_frames_drawn() < 2:
		return
	var f := Engine.get_process_frames()
	if f == _frame:
		return
	_frame = f
	var tex := get_viewport().get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null or img.is_empty():
		return
	_rect.texture = ImageTexture.create_from_image(img)
	var fade := bool(Settings.get_value("reduceMotion"))
	_mat.set_shader_parameter("cells", get_viewport().get_visible_rect().size / CELL)
	_mat.set_shader_parameter("reverse", out)
	_mat.set_shader_parameter("fade", fade)
	_set_progress(0.0)
	_rect.visible = true
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_method(_set_progress, 0.0, 1.0, FADE_SECS if fade else SECS) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_callback(_done)


## True while an old frame is still on screen.
func busy() -> bool:
	return _rect.visible


func _set_progress(p: float) -> void:
	_mat.set_shader_parameter("progress", p)


func _done() -> void:
	_rect.visible = false
	_rect.texture = null


static var _shader: Shader


static func _curtain_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CURTAIN_SHADER
	return _shader


## Each cell gets a value from its place along the diagonal (70%) and its
## 4x4 Bayer rank (30%); cells whose value is under `progress` are gone and
## the ones just above it form a darker rim. The band starts fully off the
## frame at progress 0 and has passed it at 1.
const CURTAIN_SHADER := """
shader_type canvas_item;
uniform float progress = 0.0;
uniform vec2 cells = vec2(320.0, 180.0);
uniform bool reverse = false;
uniform bool fade = false;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[y * 4 + x]) + 0.5) / 16.0;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (fade) {
		COLOR = vec4(c.rgb, 1.0 - progress);
	} else {
		vec2 cell = floor(UV * cells);
		float d = (cell.x + cell.y * 1.6) / (cells.x + cells.y * 1.6);
		if (reverse) {
			d = 1.0 - d;
		}
		float v = d * 0.7 + bayer4(cell) * 0.3;
		float p = progress * 1.08;
		if (v < p) {
			discard;
		}
		float rim = step(v, p + 0.035) * step(0.001, progress);
		COLOR = vec4(c.rgb * (1.0 - 0.45 * rim), 1.0);
	}
}
"""
