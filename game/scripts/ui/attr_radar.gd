## Hexagon chart of a sailor's six attributes, clockwise from the top in
## Attrs.IDS order. Rings mark 5, 10, 15 and 20. The gold ring is 10, the
## neutral value. The filled shape is the sailor, and their class's key
## attributes get a gold vertex.
class_name AttrRadar
extends Control

const SCALE_MAX := 20.0
const FILL := Color(0.45, 0.78, 0.86, 0.36)
const EDGE := Color("#8fd6e0")

var values := {}
var keys: Array = []
var show_icons := true


static func make(vals: Dictionary, key_attrs: Array = [], side := 104, icons := true) -> AttrRadar:
	var r := AttrRadar.new()
	r.values = vals
	r.keys = key_attrs
	r.show_icons = icons
	r.custom_minimum_size = Vector2(side, side)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


func _dirs() -> Array:
	var out := []
	var n := Attrs.IDS.size()
	for i in n:
		var a := -PI / 2.0 + TAU * float(i) / float(n)
		out.append(Vector2(cos(a), sin(a)))
	return out


func _draw() -> void:
	var c := (size / 2.0).floor()
	var pad := 12.0 if show_icons else 2.0
	var rad := floorf(minf(size.x, size.y) / 2.0 - pad)
	if rad < 8.0:
		return
	var dirs := _dirs()
	var bg := PackedVector2Array()
	for d in dirs:
		bg.append(c + d * rad)
	draw_colored_polygon(bg, Color(0.04, 0.08, 0.12, 0.5))
	for d in dirs:
		draw_line(c, c + d * rad, Color(Art.INK_DIM, 0.16), 1.0)
	for ring in [5.0, 10.0, 15.0, 20.0]:
		var pts := PackedVector2Array()
		for d in dirs:
			pts.append(c + d * rad * ring / SCALE_MAX)
		pts.append(pts[0])
		draw_polyline(pts, Color(Art.GOLD, 0.6) if ring == 10.0 else Color(Art.INK_DIM, 0.2), 1.0)
	var shape := PackedVector2Array()
	for i in dirs.size():
		var v := clampf(float(values.get(Attrs.IDS[i], Attrs.NEUTRAL)), 0.6, SCALE_MAX * 1.12)
		shape.append(c + dirs[i] * rad * v / SCALE_MAX)
	draw_colored_polygon(shape, FILL)
	var edge := shape.duplicate()
	edge.append(shape[0])
	draw_polyline(edge, EDGE, 1.0)
	for i in dirs.size():
		var key: bool = keys.has(Attrs.IDS[i])
		var s := 3.0 if key else 2.0
		draw_rect(Rect2(shape[i] - Vector2(s, s) / 2.0, Vector2(s, s)), Art.GOLD if key else Color.WHITE)
	if show_icons:
		for i in dirs.size():
			var p: Vector2 = (c + dirs[i] * (rad + 4.0)).round()
			var t := Art.icon(Attrs.ICONS[Attrs.IDS[i]])
			draw_texture(t, p - Vector2(8, 8), Color(1, 1, 1, 1.0 if keys.has(Attrs.IDS[i]) or keys.is_empty() else 0.82))
