## A sprite actor on an isometric stage: a layered human puppet (outfit,
## skin, tinted hair, hat, weapon), a creature/pet sprite, or a static prop.
## The node's position is the ground point; the visual is lifted by `lift`
## pixels for raised decks or nests.
##
## Draw order: the actor is y-sort enabled, so inside a y-sorted parent its
## child chain is sorted in the parent's sort by the chain's own position.
## `_depth` is offset by `depth_bias` and `_undo` cancels that offset, so a
## view can move the actor's sort key (for example in front of the floor
## tile it stands on) without moving the drawn sprite or `position`.
class_name Actor
extends Node2D

signal arrived
signal clicked(actor: Actor)

const PUPPET_LAYERS := ["hair_back", "outfit", "skin", "hair_front", "hat", "weapon"]

var kind := "puppet"
var key := ""
var data: Variant = null
var anim := "idle"
var facing := Vector2(1, 1)
var lift := 0.0:
	set(v):
		lift = v
		if rig:
			rig.position.y = -v
var speed := 42.0
## Sort-key offset in pixels (see the header); 0 sorts at `position`.
var depth_bias := 0.0:
	set(v):
		depth_bias = v
		if _depth:
			_depth.position.y = v
			_undo.position.y = -v
var rig: Node2D
var _depth: Node2D
var _undo: Node2D
var shadow: Sprite2D
var marker: Sprite2D
var _layers: Array = []
var _rows: Array = []
var _anims: Dictionary = {}
var _frame_size := Vector2(24, 32)
var _origin := Vector2(12, 29)
var _sheet_mode := "chars"
var _creature: Dictionary = {}
var _t := 0.0
var _fi := 0
var _hold := false
var _path: Array = []
var _bubble: Sprite2D
var _bubble_t := 0.0
var _hp_root: Node2D
var _hp_fill: NinePatchRect
var _hp_w := 18.0
var _anim_speed := 1.0
var _flip := false
var _back := false


func _init() -> void:
	y_sort_enabled = true
	_depth = Node2D.new()
	add_child(_depth)
	_undo = Node2D.new()
	_depth.add_child(_undo)
	rig = Node2D.new()
	_undo.add_child(rig)
	marker = Sprite2D.new()
	marker.centered = true
	marker.visible = false
	rig.add_child(marker)
	shadow = Sprite2D.new()
	shadow.centered = true
	shadow.modulate = Color(1, 1, 1, 0.75)
	rig.add_child(shadow)


# ------------------------------------------------------------------ setup
func setup_puppet(look: Dictionary) -> Actor:
	kind = "puppet"
	_sheet_mode = "chars"
	_anims = Art.chars.anims
	_frame_size = Vector2(24, 32)
	_origin = Vector2(float(Art.chars.origin[0]), float(Art.chars.origin[1]))
	shadow.texture = Art.ui_tex("shadow")
	_clear_layers()
	var hair: String = look.get("hair", "")
	var hc := Art.hair_color(look.get("hairColor", ""))
	var weapon: String = look.get("weapon", "")
	if weapon != "" and Art.char_row("weapons", weapon) == null:
		var wt := weapon.split(":")[0]
		weapon = Art.chars.weapons.get(wt, "")
	var skin: String = look.get("skin", "s2")
	var defs := {
		"hair_back": ["bodies", "hairb:" + hair if hair != "" else ""],
		"outfit": ["outfits", look.get("outfit", "")],
		"skin": ["bodies", "skin:" + skin],
		"hair_front": ["bodies", "hair:" + hair if hair != "" else ""],
		"hat": ["hats", look.get("hat", "")],
		"weapon": ["weapons", weapon],
	}
	for layer in PUPPET_LAYERS:
		var d: Array = defs[layer]
		if String(d[1]) == "":
			continue
		var row = Art.char_row(d[0], d[1])
		if row == null:
			continue
		var s := Sprite2D.new()
		s.centered = false
		s.offset = -_origin
		if layer.begins_with("hair"):
			s.self_modulate = hc
		rig.add_child(s)
		_layers.append({"sprite": s, "sheet": d[0], "row": row})
	_apply_frame()
	return self


func setup_creature(info: Dictionary) -> Actor:
	kind = "creature"
	_sheet_mode = "creatures"
	_creature = info
	_anims = Art.creatures.anims
	var sz := float(info.size)
	_frame_size = Vector2(sz, sz)
	_origin = info.origin
	shadow.texture = Art.ui_tex("shadow_big" if info.kind == "bosses" else "shadow")
	_clear_layers()
	var s := Sprite2D.new()
	s.centered = false
	s.offset = -_origin
	rig.add_child(s)
	_layers.append({"sprite": s, "sheet": "", "row": info.row})
	_apply_frame()
	return self


func setup_prop(tex: Texture2D, anchor: Vector2) -> Actor:
	kind = "prop"
	_clear_layers()
	shadow.texture = Art.ui_tex("shadow")
	var s := Sprite2D.new()
	s.centered = false
	s.texture = tex
	s.offset = -anchor
	rig.add_child(s)
	_layers.append({"sprite": s, "sheet": "", "row": Vector2.ZERO})
	return self


## Builds the right visual for an enemy id (puppet, creature or prop).
func setup_enemy(enemy_id: String) -> Actor:
	key = enemy_id
	var v := Art.enemy_visual(enemy_id)
	match v.type:
		"puppet":
			setup_puppet(v.look)
		"creature":
			setup_creature(v.info)
		_:
			var p := Art.prop("crystal")
			if p.is_empty():
				setup_creature(Art.creature_info("reef_crab"))
			else:
				setup_prop(p.tex, p.anchor)
	return self


func _clear_layers() -> void:
	for l in _layers:
		l.sprite.queue_free()
	_layers.clear()


# -------------------------------------------------------------- animation
func play(name: String, restart := false, rate := 1.0) -> void:
	_anim_speed = rate
	if name == anim and not restart:
		return
	anim = name
	_t = 0.0
	_fi = 0
	_hold = false
	_apply_frame()


## Starts the current loop at another point so a group of actors does not
## animate in step. `f` is in [0, 1).
func desync(f: float) -> void:
	var n: int = (_anim_def().get("frames", [0]) as Array).size()
	_fi = int(f * float(n)) % maxi(1, n)
	_t = fposmod(f * 7.0, 1.0)
	_apply_frame()


func face(dir: Vector2) -> void:
	if dir.length_squared() < 0.0001:
		return
	facing = dir
	_back = dir.y < -0.01 and kind == "puppet"
	_flip = (dir.x > 0.0) if _back else (dir.x < 0.0)
	_apply_frame()


func _resolved_anim() -> String:
	if _back and (anim == "idle" or anim == "walk"):
		return anim + "_back"
	return anim


func _anim_def() -> Dictionary:
	var a := _resolved_anim()
	if _anims.has(a):
		return _anims[a]
	return _anims.get("idle", {"frames": [0], "fps": 1})


func _apply_frame() -> void:
	if kind == "prop" or _layers.is_empty():
		return
	var d := _anim_def()
	var frames: Array = d.frames
	var f := int(frames[clampi(_fi, 0, frames.size() - 1)])
	for l in _layers:
		var s: Sprite2D = l.sprite
		if kind == "puppet":
			s.texture = Art.char_frame(l.sheet, l.row, f)
		else:
			s.texture = Art.creature_frame(_creature, f)
		s.flip_h = _flip


func _process(delta: float) -> void:
	if kind != "prop" and not _hold:
		var d := _anim_def()
		_t += delta * float(d.get("fps", 4)) * _anim_speed
		if _t >= 1.0:
			_t -= floor(_t)
			var n: int = d.frames.size()
			if _fi + 1 >= n:
				if d.get("loop", true):
					_fi = 0
				else:
					_hold = true
			else:
				_fi += 1
			_apply_frame()
	if not _path.is_empty():
		_step_path(delta)
	if _bubble and _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble.queue_free()
			_bubble = null


## True once a non-looping animation has reached its last frame.
func anim_done() -> bool:
	return _hold


# --------------------------------------------------------------- movement
## Walks through world points; each entry is [ground: Vector2, lift: float].
func walk_path(points: Array, walk_speed := 42.0) -> void:
	_path = points.duplicate()
	speed = walk_speed
	if _path.is_empty():
		arrived.emit()
		return
	play("walk")


func stop() -> void:
	_path.clear()


func is_walking() -> bool:
	return not _path.is_empty()


func _step_path(delta: float) -> void:
	var target: Vector2 = _path[0][0]
	var tl: float = _path[0][1]
	var cur := position + Vector2(0, -lift)
	var goal := target + Vector2(0, -tl)
	var dv := goal - cur
	var step := speed * delta
	if dv.length() <= step:
		position = target
		lift = tl
		_path.pop_front()
		if _path.is_empty():
			play("idle")
			arrived.emit()
		return
	face(dv)
	var nxt := cur + dv.normalized() * step
	var frac: float = 1.0 - (goal - nxt).length() / maxf(0.001, (goal - cur).length())
	var new_lift: float = lerp(lift, tl, clampf(frac, 0.0, 1.0))
	lift = new_lift
	position = nxt + Vector2(0, new_lift)


# ------------------------------------------------------------- decoration
func bubble(name: String, secs := 2.5) -> void:
	if _bubble:
		_bubble.queue_free()
	_bubble = Sprite2D.new()
	_bubble.texture = Art.ui_tex("bubble_" + name)
	_bubble.centered = true
	_bubble.position = Vector2(0, -_origin.y - 6)
	rig.add_child(_bubble)
	_bubble_t = secs


## Fades the actor in, e.g. when it comes up through a hatch onto the shown
## level. Uses the sort chain's modulate so `modulate` stays free for views.
func fade_in(secs := 0.15) -> void:
	_depth.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_depth, "modulate:a", 1.0, secs)


## Attaches a short-lived effect to the actor so it is drawn with the actor
## in the parent's y-sort: over the actor's own sprite, behind anyone
## standing nearer. `at` is relative to the ground point (lift included),
## and the effect is outside `rig`, so flash() does not tint it.
func attach_fx(n: Node2D, at := Vector2.ZERO) -> void:
	n.position = (at + Vector2(0, -lift)).round()
	_undo.add_child(n)


## Height of the sprite above the ground point (head top is -height).
func height() -> float:
	return _origin.y


func flash(c := Color(2.2, 2.2, 2.2), secs := 0.12) -> void:
	rig.modulate = c
	var tw := create_tween()
	tw.tween_property(rig, "modulate", Color.WHITE, secs)


func set_marker(name: String) -> void:
	if name == "":
		marker.visible = false
		return
	marker.texture = Art.ui_tex(name)
	marker.visible = true


func show_hp(on: bool, ally := true) -> void:
	if on and _hp_root == null:
		_hp_root = Node2D.new()
		_hp_w = 20.0 if _frame_size.x <= 32.0 else 30.0
		var bg := NinePatchRect.new()
		bg.texture = Art.ui_tex("bar_bg")
		bg.patch_margin_left = 2
		bg.patch_margin_right = 2
		bg.patch_margin_top = 2
		bg.patch_margin_bottom = 2
		bg.size = Vector2(_hp_w + 2, 4)
		bg.position = Vector2(-(_hp_w + 2) / 2.0, 0)
		_hp_root.add_child(bg)
		_hp_fill = NinePatchRect.new()
		_hp_fill.texture = Art.ui_tex("fill_hp_ally" if ally else "fill_hp")
		_hp_fill.patch_margin_left = 1
		_hp_fill.patch_margin_right = 1
		_hp_fill.patch_margin_top = 1
		_hp_fill.patch_margin_bottom = 1
		_hp_fill.size = Vector2(_hp_w, 2)
		_hp_fill.position = Vector2(-_hp_w / 2.0, 1)
		_hp_root.add_child(_hp_fill)
		_hp_root.position = Vector2(0, -_origin.y - 4)
		rig.add_child(_hp_root)
	if _hp_root:
		_hp_root.visible = on


func set_hp(frac: float) -> void:
	if _hp_fill:
		_hp_fill.size.x = max(0.0, round(_hp_w * clampf(frac, 0.0, 1.0)))
		_hp_fill.visible = frac > 0.0


## Screen-space rectangle (in parent coordinates) used for mouse picking.
func pick_rect() -> Rect2:
	return Rect2(position + Vector2(-_frame_size.x * 0.35, -lift - _origin.y + 2), Vector2(_frame_size.x * 0.7, _origin.y))


func head_point() -> Vector2:
	return position + Vector2(0, -lift - _origin.y)
