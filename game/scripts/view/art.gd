## Autoload "Art": loads the generated atlases and their JSON sidecars and
## turns them into engine resources: AtlasTexture regions, a Theme built from
## 9-slice StyleBoxTextures and the bundled pixel font, one TileSet per sea
## region (animated water, ground and cliff tiles), SpriteFrames for FX and
## the sprite descriptions used by actors.
extends Node

const GEN := "res://assets/gen/"
const HALF_W := 16
const HALF_H := 8
const LEVEL_PX := 48
const FONT_PATH := "res://assets/fonts/fusion-pixel-12px-zh_hans.otf"

const INK := Color("#efe3c2")
const INK_DIM := Color("#b8a888")
const INK_DARK := Color("#3a2614")
const GOLD := Color("#f7d154")
const GOOD := Color("#8ee07a")
const BAD := Color("#ff7a66")
const WARN := Color("#ffc25a")
const CAT_COLORS := {"command": Color("#f7d154"), "living": Color("#f29a6a"), "training": Color("#e8645a"),
	"medical": Color("#7ad8a0"), "production": Color("#d89a4a"), "navigation": Color("#6ab8f0"),
	"storage": Color("#b8a07a"), "pet": Color("#d890e0"), "social": Color("#f0b0c8"), "defense": Color("#9aa8c0")}
const SKIN_KEYS := ["s1", "s2", "s3", "s4", "s5"]

var chars: Dictionary = {}
var creatures: Dictionary = {}
var env: Dictionary = {}
var ui: Dictionary = {}
var facilities: Dictionary = {}
var cards: Dictionary = {}
var parts: Dictionary = {}
var dressing: Dictionary = {}
var font: Font
var theme: Theme
var glow: Texture2D
var _hulls: Dictionary = {}
var _tex: Dictionary = {}
var _region: Dictionary = {}
var _tilesets: Dictionary = {}
var _fx_frames: Dictionary = {}
var _boxes: Dictionary = {}


func _init() -> void:
	chars = U.load_json(GEN + "chars/chars.json")
	creatures = U.load_json(GEN + "creatures/creatures.json")
	env = U.load_json(GEN + "env/env.json")
	ui = U.load_json(GEN + "ui/ui.json")
	facilities = U.load_json(GEN + "facilities/facilities.json")
	cards = U.load_json(GEN + "facilities/cards.json")
	parts = U.load_json(GEN + "ship/parts.json")
	dressing = U.load_json(GEN + "ship/dressing.json")
	font = _load_font()
	glow = _make_glow()
	theme = _build_theme()
	Controls.install()


# ----------------------------------------------------------------- basics
func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]


func region(path: String, r: Rect2) -> AtlasTexture:
	var key := "%s|%d,%d,%d,%d" % [path, r.position.x, r.position.y, r.size.x, r.size.y]
	if not _region.has(key):
		var a := AtlasTexture.new()
		a.atlas = tex(path)
		a.region = r
		a.filter_clip = true
		_region[key] = a
	return _region[key]


static func rect_of(a: Array) -> Rect2:
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))


static func iso(gx: float, gy: float) -> Vector2:
	return Vector2((gx - gy) * HALF_W, (gx + gy) * HALF_H)


## Inverse of iso(): fractional cell coordinates of a world point.
static func uniso(p: Vector2) -> Vector2:
	var a := p.x / HALF_W
	var b := p.y / HALF_H
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


## Everything a camera clamped to `bounds` can show in a viewport of size
## `vp` at its widest zoom `min_zoom`, plus `margin`. The viewport is never
## treated as smaller than the 640x360 design size, so a later resize to a
## larger window only needs a rebuild when it shows more than that.
static func camera_cover(bounds: Rect2, vp: Vector2, min_zoom: float, margin := 64.0) -> Rect2:
	var half := Vector2(maxf(vp.x, 640.0), maxf(vp.y, 360.0)) * 0.5 / maxf(min_zoom, 0.01)
	return bounds.grow_individual(half.x + margin, half.y + margin, half.x + margin, half.y + margin)


## Terrain cells whose centres lie inside the screen-aligned world rect `r`
## (a rectangle, not a diamond of cells), grown by one tile so tile edges
## reach past the rect.
static func cells_in_rect(r: Rect2) -> Array[Vector2i]:
	var cover := r.grow(float(HALF_W) * 2.0)
	var span := Rect2(uniso(cover.position), Vector2.ZERO)
	for pt in [Vector2(cover.end.x, cover.position.y), Vector2(cover.position.x, cover.end.y), cover.end]:
		span = span.expand(uniso(pt))
	var out: Array[Vector2i] = []
	for gx in range(floori(span.position.x) - 1, ceili(span.end.x) + 2):
		for gy in range(floori(span.position.y) - 1, ceili(span.end.y) + 2):
			if cover.has_point(iso(gx, gy)):
				out.append(Vector2i(gx, gy))
	return out


## Flat deep-water underlay for a region, far larger than any view: a
## fallback colour behind the sea tiles so no view can show the clear colour.
static func sea_underlay(region_id: String) -> Polygon2D:
	var p := Polygon2D.new()
	p.z_index = -21
	var big := Rect2(-8192, -8192, 16384, 16384)
	p.polygon = PackedVector2Array([big.position, Vector2(big.end.x, big.position.y), big.end, Vector2(big.position.x, big.end.y)])
	var col := Color(0.1, 0.3, 0.5)
	var reg = C.region(region_id)
	if reg != null and reg.has("palette"):
		col = Color.html(String(reg.palette.get("deep", "#2a6fae")))
	p.color = col
	return p


func icon(name: String) -> Texture2D:
	var p = ui.icons.get(name)
	if p == null:
		p = ui.icons.get("ui_info")
	return region(GEN + "ui/icons.png", Rect2(float(p[0]), float(p[1]), 16, 16))


func has_icon(name: String) -> bool:
	return ui.icons.has(name)


func ui_tex(name: String) -> AtlasTexture:
	for group in ["theme", "markers", "bubbles"]:
		if ui[group].has(name):
			return region(GEN + "ui/ui.png", rect_of(ui[group][name].rect))
	return region(GEN + "ui/ui.png", Rect2(0, 0, 1, 1))


func box(name: String, pad: int = -1) -> StyleBoxTexture:
	var key := "%s:%d" % [name, pad]
	if _boxes.has(key):
		return _boxes[key]
	var d: Dictionary = ui.theme[name]
	var sb := StyleBoxTexture.new()
	sb.texture = tex(GEN + "ui/ui.png")
	sb.region_rect = rect_of(d.rect)
	var m := float(d.margin)
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	var cm := float(pad) if pad >= 0 else m
	sb.content_margin_left = cm
	sb.content_margin_right = cm
	sb.content_margin_top = cm
	sb.content_margin_bottom = cm
	_boxes[key] = sb
	return sb


# ------------------------------------------------------------------- font
func _load_font() -> Font:
	var f = load(FONT_PATH)
	if f is FontFile:
		var ff: FontFile = f
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.hinting = TextServer.HINTING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		ff.generate_mipmaps = false
		return ff
	return ThemeDB.fallback_font


func _make_glow() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.35, Color(1, 1, 1, 0.35))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


# ------------------------------------------------------------------ theme
func _build_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 12
	var empty := StyleBoxEmpty.new()
	# Labels
	th.set_color("font_color", "Label", INK)
	th.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.0))
	th.set_constant("line_spacing", "Label", 1)
	th.set_type_variation("DarkLabel", "Label")
	th.set_color("font_color", "DarkLabel", INK_DARK)
	th.set_type_variation("DimLabel", "Label")
	th.set_color("font_color", "DimLabel", INK_DIM)
	th.set_type_variation("GoldLabel", "Label")
	th.set_color("font_color", "GoldLabel", GOLD)
	th.set_type_variation("GoodLabel", "Label")
	th.set_color("font_color", "GoodLabel", GOOD)
	th.set_type_variation("BadLabel", "Label")
	th.set_color("font_color", "BadLabel", BAD)
	th.set_type_variation("WarnLabel", "Label")
	th.set_color("font_color", "WarnLabel", WARN)
	th.set_type_variation("ShadowLabel", "Label")
	th.set_color("font_shadow_color", "ShadowLabel", Color(0.04, 0.03, 0.06, 0.9))
	th.set_constant("shadow_offset_x", "ShadowLabel", 1)
	th.set_constant("shadow_offset_y", "ShadowLabel", 1)
	th.set_type_variation("TitleLabel", "Label")
	th.set_color("font_color", "TitleLabel", GOLD)
	th.set_color("font_shadow_color", "TitleLabel", Color(0.1, 0.05, 0.02, 1))
	th.set_constant("shadow_offset_x", "TitleLabel", 1)
	th.set_constant("shadow_offset_y", "TitleLabel", 1)
	th.set_color("default_color", "RichTextLabel", INK)
	th.set_constant("line_separation", "RichTextLabel", 1)
	# Panels
	th.set_stylebox("panel", "Panel", box("panel"))
	th.set_stylebox("panel", "PanelContainer", box("panel"))
	for v in [["LightPanel", "panel_light", 6], ["FlatPanel", "panel_flat", 4], ["HudBar", "hudbar", 3],
			["SlotPanel", "slot", 3], ["SelPanel", "slot_sel", 3], ["ChipPanel", "chip", 2], ["TipPanel", "tooltip", 4],
			["PortraitPanel", "portrait", 3]]:
		th.set_type_variation(v[0], "PanelContainer")
		th.set_stylebox("panel", v[0], box(v[1], v[2]))
	# Buttons
	th.set_stylebox("normal", "Button", box("btn_normal", 3))
	th.set_stylebox("hover", "Button", box("btn_hover", 3))
	th.set_stylebox("pressed", "Button", box("btn_pressed", 3))
	th.set_stylebox("hover_pressed", "Button", box("btn_pressed", 3))
	th.set_stylebox("disabled", "Button", box("btn_disabled", 3))
	th.set_stylebox("focus", "Button", empty)
	th.set_color("font_color", "Button", Color("#f4e8c8"))
	th.set_color("font_hover_color", "Button", Color("#fff7dc"))
	th.set_color("font_pressed_color", "Button", GOLD)
	th.set_color("font_hover_pressed_color", "Button", GOLD)
	th.set_color("font_focus_color", "Button", Color("#f4e8c8"))
	th.set_color("font_disabled_color", "Button", Color("#7d7468"))
	th.set_color("icon_disabled_color", "Button", Color(1, 1, 1, 0.4))
	th.set_constant("h_separation", "Button", 3)
	th.set_type_variation("PrimaryButton", "Button")
	th.set_stylebox("normal", "PrimaryButton", box("btnp_normal", 3))
	th.set_stylebox("hover", "PrimaryButton", box("btnp_hover", 3))
	th.set_stylebox("pressed", "PrimaryButton", box("btnp_pressed", 3))
	th.set_stylebox("hover_pressed", "PrimaryButton", box("btnp_pressed", 3))
	th.set_color("font_color", "PrimaryButton", INK_DARK)
	th.set_color("font_hover_color", "PrimaryButton", Color("#1e1208"))
	th.set_color("font_pressed_color", "PrimaryButton", Color("#1e1208"))
	th.set_color("font_focus_color", "PrimaryButton", INK_DARK)
	th.set_type_variation("TabButton", "Button")
	th.set_stylebox("normal", "TabButton", box("tab_off", 3))
	th.set_stylebox("hover", "TabButton", box("tab_off", 3))
	th.set_stylebox("pressed", "TabButton", box("tab_on", 3))
	th.set_stylebox("hover_pressed", "TabButton", box("tab_on", 3))
	th.set_stylebox("disabled", "TabButton", box("tab_off", 3))
	th.set_color("font_color", "TabButton", INK_DIM)
	th.set_color("font_pressed_color", "TabButton", GOLD)
	th.set_color("font_hover_pressed_color", "TabButton", GOLD)
	th.set_type_variation("FlatButton", "Button")
	th.set_stylebox("normal", "FlatButton", empty)
	th.set_stylebox("hover", "FlatButton", box("chip", 2))
	th.set_stylebox("pressed", "FlatButton", box("slot_sel", 2))
	th.set_stylebox("hover_pressed", "FlatButton", box("slot_sel", 2))
	th.set_stylebox("disabled", "FlatButton", empty)
	th.set_type_variation("SlotButton", "Button")
	th.set_stylebox("normal", "SlotButton", box("slot", 3))
	th.set_stylebox("hover", "SlotButton", box("chip", 3))
	th.set_stylebox("pressed", "SlotButton", box("slot_sel", 3))
	th.set_stylebox("hover_pressed", "SlotButton", box("slot_sel", 3))
	th.set_stylebox("disabled", "SlotButton", box("slot", 3))
	# Option menus and popups
	for t in ["OptionButton", "MenuButton"]:
		th.set_stylebox("normal", t, box("btn_normal", 3))
		th.set_stylebox("hover", t, box("btn_hover", 3))
		th.set_stylebox("pressed", t, box("btn_pressed", 3))
		th.set_stylebox("disabled", t, box("btn_disabled", 3))
		th.set_stylebox("focus", t, empty)
		th.set_color("font_color", t, Color("#f4e8c8"))
		th.set_color("font_disabled_color", t, Color("#7d7468"))
	th.set_icon("arrow", "OptionButton", icon("ui_down"))
	th.set_stylebox("panel", "PopupMenu", box("tooltip", 3))
	th.set_stylebox("hover", "PopupMenu", box("btn_hover", 2))
	th.set_color("font_color", "PopupMenu", INK)
	th.set_color("font_hover_color", "PopupMenu", Color("#fff7dc"))
	th.set_color("font_disabled_color", "PopupMenu", Color("#7d7468"))
	th.set_constant("v_separation", "PopupMenu", 3)
	th.set_stylebox("panel", "TooltipPanel", box("tooltip", 4))
	th.set_color("font_color", "TooltipLabel", INK)
	# Line edit
	th.set_stylebox("normal", "LineEdit", box("slot", 3))
	th.set_stylebox("focus", "LineEdit", box("slot_sel", 3))
	th.set_stylebox("read_only", "LineEdit", box("slot", 3))
	th.set_color("font_color", "LineEdit", INK)
	th.set_color("font_placeholder_color", "LineEdit", Color(0.72, 0.66, 0.56, 0.6))
	th.set_color("caret_color", "LineEdit", GOLD)
	# Check boxes
	for t in ["CheckBox", "CheckButton"]:
		th.set_icon("checked", t, ui_tex("check_on"))
		th.set_icon("unchecked", t, ui_tex("check_off"))
		th.set_icon("checked_disabled", t, ui_tex("check_on"))
		th.set_icon("unchecked_disabled", t, ui_tex("check_off"))
		th.set_stylebox("normal", t, empty)
		th.set_stylebox("hover", t, empty)
		th.set_stylebox("pressed", t, empty)
		th.set_stylebox("hover_pressed", t, empty)
		th.set_stylebox("focus", t, empty)
		th.set_color("font_color", t, INK)
		th.set_color("font_hover_color", t, Color("#fff7dc"))
		th.set_color("font_pressed_color", t, INK)
		th.set_constant("h_separation", t, 4)
	# Scroll bars
	th.set_stylebox("scroll", "VScrollBar", box("scroll_bg", 0))
	th.set_stylebox("grabber", "VScrollBar", box("scroll_grab", 0))
	th.set_stylebox("grabber_highlight", "VScrollBar", box("scroll_grab", 0))
	th.set_stylebox("grabber_pressed", "VScrollBar", box("scroll_grab", 0))
	th.set_stylebox("scroll", "HScrollBar", box("scroll_bg", 0))
	th.set_stylebox("grabber", "HScrollBar", box("scroll_grab", 0))
	th.set_stylebox("grabber_highlight", "HScrollBar", box("scroll_grab", 0))
	th.set_stylebox("grabber_pressed", "HScrollBar", box("scroll_grab", 0))
	th.set_stylebox("panel", "ScrollContainer", empty)
	# Progress bars
	th.set_stylebox("background", "ProgressBar", box("bar_bg", 0))
	th.set_stylebox("fill", "ProgressBar", box("fill_hp", 0))
	th.set_color("font_color", "ProgressBar", INK)
	th.set_color("font_outline_color", "ProgressBar", Color(0, 0, 0, 1))
	th.set_constant("outline_size", "ProgressBar", 0)
	for f in ["hp", "hp_ally", "xp", "sta", "food", "hull", "mp"]:
		var vn: String = "Bar_" + f
		th.set_type_variation(vn, "ProgressBar")
		th.set_stylebox("fill", vn, box("fill_" + f, 0))
	# Separators
	var sep := box("line_h", 0)
	th.set_stylebox("separator", "HSeparator", sep)
	th.set_constant("separation", "HSeparator", 4)
	th.set_constant("separation", "VBoxContainer", 3)
	th.set_constant("separation", "HBoxContainer", 3)
	th.set_constant("h_separation", "GridContainer", 3)
	th.set_constant("v_separation", "GridContainer", 3)
	th.set_constant("h_separation", "HFlowContainer", 3)
	th.set_constant("v_separation", "HFlowContainer", 3)
	return th


# ------------------------------------------------------------------ fx
## SpriteFrames for one FX strip with a looping and a one-shot animation.
func fx_frames(name: String) -> SpriteFrames:
	if _fx_frames.has(name):
		return _fx_frames[name]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var d = ui.fx.get(name)
	if d == null:
		d = ui.fx.sparkle
	for anim in ["loop", "once"]:
		sf.add_animation(anim)
		sf.set_animation_loop(anim, anim == "loop")
		sf.set_animation_speed(anim, 10.0)
		for i in int(d.frames):
			sf.add_frame(anim, region(GEN + "ui/fx.png", Rect2(float(i * int(d.w)), float(d.y), float(d.w), float(d.h))))
	_fx_frames[name] = sf
	return sf


func foam_frames() -> SpriteFrames:
	if _fx_frames.has("_foam"):
		return _fx_frames["_foam"]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("loop")
	sf.set_animation_loop("loop", true)
	sf.set_animation_speed("loop", 5.0)
	for i in 4:
		sf.add_frame("loop", region(GEN + "env/foam.png", Rect2(float(i * 12), 0, 12, 6)))
	_fx_frames["_foam"] = sf
	return sf


## A ready-to-play FX node. One-shot FX free themselves when done.
func fx_node(name: String, once: bool = true, speed: float = 10.0) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = fx_frames(name)
	a.animation = "once" if once else "loop"
	a.speed_scale = speed / 10.0
	a.centered = true
	if once:
		a.animation_finished.connect(a.queue_free)
	a.play()
	return a


# ------------------------------------------------------------- tile sets
## One TileSet per region terrain atlas: animated water tiles at (0,0) deep,
## (4,0) open sea and (0,1) shallows, ground diamonds on row 2 and cliff
## sides on row 3.
func tileset(rid: String) -> TileSet:
	if _tilesets.has(rid):
		return _tilesets[rid]
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(32, 16)
	var src := TileSetAtlasSource.new()
	var path: String = env.terrain.get(rid, env.terrain.values()[0])
	src.texture = tex(path)
	src.texture_region_size = Vector2i(32, 16)
	var water_bases: Array = [Vector2i(0, 0), Vector2i(4, 0), Vector2i(0, 1)]
	for k in env.get("water", {}):
		var w: Array = env.water[k]
		if not water_bases.has(Vector2i(int(w[0]), int(w[1]))):
			water_bases.append(Vector2i(int(w[0]), int(w[1])))
	for base in water_bases:
		src.create_tile(base)
		src.set_tile_animation_columns(base, 4)
		src.set_tile_animation_frames_count(base, int(env.waterFrames))
		for i in int(env.waterFrames):
			src.set_tile_animation_frame_duration(base, i, 0.32)
		src.set_tile_animation_mode(base, TileSetAtlasSource.TILE_ANIMATION_MODE_RANDOM_START_TIMES)
	for i in env.ground.size():
		src.create_tile(Vector2i(i, 2))
	for i in env.sides.size():
		src.create_tile(Vector2i(i, 3))
	for i in env.get("ground2", []).size():
		src.create_tile(Vector2i(i, 7))
	for k in env.get("sideSets", {}):
		var ss: Array = env.sideSets[k]
		if int(ss[1]) == 3:
			continue
		for i in env.sides.size():
			src.create_tile(Vector2i(int(ss[0]) + i, int(ss[1])))
	ts.add_source(src, 0)
	_tilesets[rid] = ts
	return ts


func ground_index(name: String) -> int:
	return max(0, env.ground.find(name))


func side_index(name: String) -> int:
	return max(0, env.sides.find(name))


## Atlas cell of a ground tile from either ground row (row 2, or the coast
## and town row 7).
func ground_tile(name: String) -> Vector2i:
	var i: int = env.ground.find(name)
	if i >= 0:
		return Vector2i(i, 2)
	i = env.get("ground2", []).find(name)
	if i >= 0:
		return Vector2i(i, 7)
	return Vector2i(0, 2)


## Atlas cell of a cliff side: `level` is "high" (full 9px face of raised
## land), "low" (5px face of a beach ledge) or "band" (the top 4px of a high
## face); `faces` is "LR", "L" (toward +gy) or "R" (toward +gx).
func side_tile(kind: String, level: String, faces: String) -> Vector2i:
	var ss = env.get("sideSets", {}).get(level + ":" + faces)
	var i := side_index(kind)
	if ss == null:
		return Vector2i(i, 3)
	return Vector2i(int(ss[0]) + i, int(ss[1]))


## Atlas cell of an animated water tile: sea, deep, shallow, reef, lagoon.
func water_tile(name: String) -> Vector2i:
	var w = env.get("water", {}).get(name)
	if w == null:
		return Vector2i(0, 1) if name == "shallow" else Vector2i(0, 0)
	return Vector2i(int(w[0]), int(w[1]))


## Placement helper for TileMapLayer: finds how the engine's diamond-down
## axes map onto this project's iso axes (+gx = down-right, +gy = down-left)
## and offsets the layer so cell (0,0) is centred on the origin.
func align_layer(layer: TileMapLayer) -> Dictionary:
	var o := layer.map_to_local(Vector2i(0, 0))
	var ax := layer.map_to_local(Vector2i(1, 0)) - o
	layer.position = -o
	var swap := ax.x < 0.0
	return {"swap": swap}


static func layer_cell(info: Dictionary, gx: int, gy: int) -> Vector2i:
	return Vector2i(gy, gx) if info.get("swap", false) else Vector2i(gx, gy)


# ------------------------------------------------------------------- props
func prop(name: String, rid: String = "") -> Dictionary:
	var key := (rid + ":" + name) if rid != "" else name
	var d = env.props.get(key)
	if d == null:
		d = env.props.get(name)
	if d == null:
		return {}
	return {"tex": region(GEN + "env/props.png", rect_of(d.rect)), "anchor": Vector2(float(d.anchor[0]), float(d.anchor[1]))}


func building(rid: String, name: String) -> Dictionary:
	var d = env.buildings.get(rid + ":" + name)
	if d == null:
		return {}
	return {"tex": region(GEN + "env/buildings.png", rect_of(d.rect)), "anchor": Vector2(float(d.anchor[0]), float(d.anchor[1]))}


func chart_icon(name: String) -> Texture2D:
	var i: int = max(0, env.chartIcons.find(name))
	return region(GEN + "env/chart_icons.png", Rect2(float(i * 16), 0, 16, 16))


# ----------------------------------------------------------------- ship art
func hull_data(id: String) -> Dictionary:
	if not _hulls.has(id):
		_hulls[id] = U.load_json(GEN + "ship/hull_%s.json" % id)
	return _hulls[id]


func hull_piece_tex(id: String, r: Array) -> AtlasTexture:
	return region(GEN + "ship/hull_%s.png" % id, rect_of(r))


func part(name: String) -> Dictionary:
	var d = parts.get(name)
	if d == null:
		return {}
	return {"tex": region(GEN + "ship/parts.png", rect_of(d.rect)), "off": Vector2(float(d.off[0]), float(d.off[1]))}


## One interior dressing piece from ship/dressing.json ({rect, off}):
## {tex, off}, or {} when the entry has no packed rect.
func dress_piece(e: Variant) -> Dictionary:
	if not (e is Dictionary) or not e.has("rect"):
		return {}
	return {"tex": region(GEN + "ship/dressing.png", rect_of(e.rect)), "off": Vector2(float(e.off[0]), float(e.off[1]))}


## Facility pieces for one rotation and state: [{cell: Vector2i, tex, off}].
func facility_pieces(fid: String, rot: int, working: bool) -> Array:
	var f = facilities.get(fid)
	if f == null:
		return []
	var r: Dictionary = f.rot[str(rot)]
	var out := []
	for p in r["work" if working else "idle"]:
		out.append({"cell": Vector2i(int(p.cell[0]), int(p.cell[1])), "tex": region(GEN + "facilities/facilities.png", rect_of(p.rect)),
			"off": Vector2(float(p.off[0]), float(p.off[1]))})
	return out


func facility_meta(fid: String, rot: int) -> Dictionary:
	var f = facilities.get(fid)
	if f == null:
		return {"spots": [], "fx": [], "lights": []}
	return f.rot[str(rot)]


func facility_card(fid: String) -> Texture2D:
	var c = cards.get(fid)
	if c == null:
		return null
	return region(GEN + "facilities/cards.png", rect_of(c.rect))


# ---------------------------------------------------------------- actors
func char_row(sheet: String, key: String) -> Variant:
	var rows: Dictionary = chars.rows.get(sheet, {})
	var r = rows.get(key)
	return Vector2(float(r[0]), float(r[1])) if r != null else null


func char_frame(sheet: String, row: Vector2, frame: int) -> AtlasTexture:
	return region(chars.sheets[sheet], Rect2(row.x + frame * 24, row.y, 24, 32))


## Layer description for a crew member: class outfit, equipped weapon type,
## and a look derived from the identity seed.
func crew_look(m: Dictionary) -> Dictionary:
	var cls: Dictionary = chars.classes.get(m.classId, chars.classes.get(C.base_class_of(m.classId), chars.classes.guard))
	var s := int(m.get("seed", 0))
	var weapon: String = cls.weapon
	var eq = m.get("equipment", {})
	if eq is Dictionary and eq.get("weapon") != null and Game.has_game():
		var inst = Rules.equip_inst(Game.state, eq.weapon)
		if inst != null:
			var it = C.ITEMS.get(inst.itemId)
			if it != null and it.get("wtype") and chars.weapons.has(it.wtype):
				weapon = chars.weapons[it.wtype]
				if String(cls.weapon).begins_with(String(it.wtype) + ":"):
					weapon = cls.weapon
	var styles: Array = chars.hairStyles
	var colors: Array = chars.hairColors
	var h := U.hash32("look:" + str(s))
	return {"outfit": cls.outfit, "hat": cls.hat, "weapon": weapon, "skin": SKIN_KEYS[s % SKIN_KEYS.size()],
		"hair": styles[(h >> 4) % styles.size()] if cls.get("hair", true) else "", "hairColor": colors[(h >> 9) % colors.size()]}


func npc_look(id: String) -> Dictionary:
	var n = chars.npcs.get(id)
	if n == null:
		return {}
	return {"outfit": n.outfit, "hat": n.hat if n.hat != null else "", "weapon": n.weapon if n.weapon != null else "",
		"skin": n.skin if n.skin != null else "s2", "hair": n.hairStyle if n.hairStyle != null else "",
		"hairColor": n.hairColor if n.hairColor != null else "#3a2c2a"}


## {kind: monsters|bosses|pets, sheet, size, origin, row} or {}.
func creature_info(key: String) -> Dictionary:
	for kind in ["monsters", "bosses", "pets"]:
		var g: Dictionary = creatures[kind]
		if g.rows.has(key):
			var r: Array = g.rows[key]
			return {"kind": kind, "sheet": g.sheet, "size": int(g.size), "origin": Vector2(float(g.origin[0]), float(g.origin[1])),
				"row": Vector2(float(r[0]), float(r[1]))}
	return {}


func creature_frame(info: Dictionary, frame: int) -> AtlasTexture:
	var sz := float(info.size)
	return region(info.sheet, Rect2(info.row.x + frame * sz, info.row.y, sz, sz))


## How an enemy id is drawn: a layered human or a creature sprite.
func enemy_visual(enemy_id: String) -> Dictionary:
	if chars.npcs.has(enemy_id):
		return {"type": "puppet", "look": npc_look(enemy_id)}
	var ci := creature_info(enemy_id)
	if not ci.is_empty():
		return {"type": "creature", "info": ci}
	if enemy_id == "crystal_decoy":
		return {"type": "prop", "prop": "crystal"}
	if C.world.RIVALS.has(enemy_id):
		var reg: String = C.world.RIVALS[enemy_id].regionId
		var r = C.region(reg)
		if r != null:
			return {"type": "puppet", "look": npc_look(r.enemies.caster)}
	if C.data.PIRATES.has(enemy_id):
		return {"type": "puppet", "look": npc_look("gull_raider")}
	return {"type": "creature", "info": creature_info("reef_crab")}


func pet_key(p: Dictionary) -> String:
	var role: String = String(p.get("role", ""))
	if role == "":
		var sp = C.PET_SPECIES.get(p.get("speciesId", ""))
		role = String(sp.role) if sp != null and sp.has("role") else "companion"
	return "%s_%s%s" % [p.familyId, role, "_evo" if p.get("evolved", false) else ""]


func hair_color(hex: String) -> Color:
	return Color(hex) if hex != "" else Color("#3a2c2a")
