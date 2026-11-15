## First-session guide: one short card at a time that points at the control
## the player needs next, from looking inside the ship to the first landing.
##
## It runs only while the first main objective is open and the guide is on
## in Settings. Each step shows when its context is on screen (the right
## view, no dialog or report open, its control visible) and ends when the
## player does what it describes, or presses "Got it". "Hide guide" turns
## the whole guide off; "Show again" under System > Settings starts it
## again. Progress is a player preference (Settings), not part of the save.
##
## The card lives in the UI layer above the windows, so it can point into
## the sea chart. It is placed beside its target (left, above, below or
## right, whichever fits) and never on top of it; an arrow and a pulsing
## frame mark the target.
class_name Guide
extends Control

const STEPS := ["levels", "chart", "route", "sail", "site"]
const CARD_W := 180.0
const GAP := 10.0
const EDGE := 3.0
const GOLD := Color("e8c040")

var main: Node
var _step := ""
var _text_sig := ""
var _anchor := Rect2()
var _card: PanelContainer
var _title: Label
var _body: Label
var _t := 0.0
## View level when the "levels" step first appeared; a change completes it.
var _lvl0 := -1
## The site view the "site" step was shown on (party idle); a walk there,
## e.g. after the room dialog, completes it.
var _site_seen: Node = null
## The main objective's location id ("" when hidden), read when a step shows.
var _loc := ""


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = UIK.panel(null, "TipPanel")
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.visible = false
	add_child(_card)
	var box := UIK.vbox([], 3)
	_card.add_child(box)
	_title = UIK.label("", "GoldLabel")
	box.add_child(UIK.hbox([UIK.icon("ui_info"), _title], 3))
	_body = UIK.para("", "", int(CARD_W) - 12)
	box.add_child(_body)
	var hide := UIK.button(I18n.t("guide.hide"), _hide_all, "", "FlatButton", true, I18n.t("guide.hide_tip"))
	var ok := UIK.button(I18n.t("guide.ok"), _skip_step)
	box.add_child(UIK.hbox([hide, UIK.spacer(), ok], 4))


# ------------------------------------------------------------- progress
static func is_on() -> bool:
	return bool(Settings.get_value("guide"))


static func done_steps() -> Array:
	var v = Settings.get_value("guideDone")
	return v if v is Array else []


static func is_done(id: String) -> bool:
	return done_steps().has(id)


static func mark_done(ids: Array) -> void:
	var d := done_steps().duplicate()
	var changed := false
	for id in ids:
		if not d.has(id):
			d.append(id)
			changed = true
	if changed:
		Settings.set_value("guideDone", d)


## Turns the guide on again with every step pending (System window).
static func restart() -> void:
	Settings.set_value("guideDone", [])
	Settings.set_value("guide", true)


func _hide_all() -> void:
	Audio.play("ui_close")
	Settings.set_value("guide", false)
	_show("")


func _skip_step() -> void:
	Audio.play("ui_click")
	if _step != "":
		mark_done([_step])
	_show("")


## While the first main objective is open (a fresh game's first island).
func _first_session() -> bool:
	if not Game.has_game():
		return false
	var s: Dictionary = Game.state
	if s.captain.regionsUnlocked.size() != 1:
		return false
	var ms := Rules.main_status(s)
	return not ms.done and int(ms.step) == 0


# ---------------------------------------------------------------- tick
func _process(delta: float) -> void:
	_t += delta
	var next := _pick_step()
	if next != _step:
		_show(next)
	if _step == "":
		return
	var r = _anchor_rect(_step)
	if r == null:
		_card.visible = false
		queue_redraw()
		return
	_card.visible = true
	_anchor = r
	_refresh_text()
	_place_card()
	queue_redraw()


## Completes steps whose action has happened, then returns the first
## pending step whose context is on screen now ("" for none).
func _pick_step() -> String:
	if main == null or not is_on() or main.mode != "game" or not _first_session():
		return ""
	var s: Dictionary = Game.state
	var chart = main.windows.get("chart")
	if s.voyage != null:
		mark_done(["chart", "route", "sail"])
	elif chart != null:
		mark_done(["chart"])
		if chart.has_dest():
			mark_done(["route"])
	if _lvl0 >= 0 and main.world_mode == "port" and main.ship_view.visible and main.ship_view.view_level != _lvl0:
		mark_done(["levels"])
		_lvl0 = -1
	if main.world_mode == "battle" and _site_seen != null:
		mark_done(["site"])
	if _site_seen != null and is_instance_valid(_site_seen) and _site_seen == main.site_view and main.site_view.busy:
		mark_done(["site"])
		_site_seen = null
	if main._lock > 0 or main._modal_open() or main.world_mode == "battle":
		return ""
	var done := done_steps()
	for id in STEPS:
		if done.has(id):
			continue
		if _context_ok(id, chart):
			return id
	return ""


func _context_ok(id: String, chart: Variant) -> bool:
	match id:
		"levels":
			return main.world_mode == "port" and main.ship_view.visible and main.hud.level_panel.visible and main.windows.is_empty()
		"chart":
			return main.world_mode == "port" and main.windows.is_empty() and main.hud.ctx_box.get_child_count() > 0
		"route":
			return chart != null and not chart.has_dest() and main._topmost_window() == "chart"
		"sail":
			return chart != null and chart.has_dest() and main._topmost_window() == "chart"
		"site":
			return main.world_mode == "site" and main.site_view != null and not main.site_view.busy and main.windows.is_empty()
	return false


func _show(id: String) -> void:
	_step = id
	_text_sig = ""
	if id == "levels" and _lvl0 < 0:
		_lvl0 = main.ship_view.view_level
	if id == "site":
		_site_seen = main.site_view
	_loc = ""
	if id != "" and Game.has_game():
		var loc = Fmt.objective(Game.state).get("locationId")
		_loc = String(loc) if loc != null else ""
	_card.visible = false
	queue_redraw()


# ------------------------------------------------------------ content
func _refresh_text() -> void:
	var key := "guide." + _step
	var params := {}
	match _step:
		"chart", "route":
			if _loc != "":
				params = {"location": "loc.%s.name" % _loc}
			else:
				key += "_any"
		"sail":
			var b := _sail_button()
			if b != null and b.disabled:
				key = "guide.sail_blocked"
	var sig := "%s|%s|%s" % [key, str(params), I18n.locale()]
	if sig == _text_sig:
		return
	_text_sig = sig
	_title.text = I18n.t("guide.title", {"n": STEPS.find(_step) + 1, "total": STEPS.size()})
	_body.text = I18n.t(key, params)
	_card.reset_size()


## Rectangle (in this control's coordinates) of what the step points at,
## or null when it is not on screen.
func _anchor_rect(id: String) -> Variant:
	match id:
		"levels":
			return _rect_of(main.hud.level_panel)
		"chart":
			return _rect_of(main.hud.ctx_box.get_child(0) if main.hud.ctx_box.get_child_count() > 0 else null)
		"route":
			var chart = main.windows.get("chart")
			if chart == null:
				return null
			var row := _dest_button(chart)
			if row != null:
				var rr = _rect_of(row)
				# A row scrolled out of the list falls back to the list itself.
				var side = _rect_of(chart._side.get_parent())
				if rr != null and side != null and (side as Rect2).encloses(rr):
					return rr
				return side
			return _rect_of(chart.view)
		"sail":
			return _rect_of(_sail_button())
		"site":
			return _room_rect()
	return null


func _rect_of(c: Variant) -> Variant:
	if c == null or not is_instance_valid(c) or not (c as Control).is_visible_in_tree():
		return null
	var r: Rect2 = (c as Control).get_global_rect()
	if r.size.x < 2.0 or r.size.y < 2.0:
		return null
	return Rect2(r.position - get_global_position(), r.size)


## The chart's destination-list button for the objective's location.
func _dest_button(chart: Node) -> Button:
	if _loc == "" or not is_instance_valid(chart._side):
		return null
	var name := I18n.t("loc.%s.name" % _loc)
	for b in _buttons(chart._side):
		if b.text == name:
			return b
	return null


## The footer's primary Sail button of the open chart.
func _sail_button() -> Button:
	var chart = main.windows.get("chart")
	if chart == null or not is_instance_valid(chart._footer):
		return null
	var found: Button = null
	for b in _buttons(chart._footer):
		if b.theme_type_variation == "PrimaryButton":
			found = b
	return found


func _buttons(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_buttons(c))
	return out


## Screen rectangle of the open room marker nearest the party, in UI units.
func _room_rect() -> Variant:
	var sv = main.site_view
	if sv == null or not is_instance_valid(sv):
		return null
	var here: Vector2 = sv._nodes[sv._here]
	var best := ""
	var best_d := INF
	for id in sv._room_vis:
		if String(sv._room_vis[id].state) != "open":
			continue
		var d: float = here.distance_to(sv._nodes[id])
		if d < best_d:
			best_d = d
			best = String(id)
	if best == "":
		return null
	var p: Vector2 = sv._nodes[best]
	var xf: Transform2D = sv.get_global_transform_with_canvas()
	var a: Vector2 = xf * (p + Vector2(-16, -56))
	var b: Vector2 = xf * (p + Vector2(16, 2))
	var sc := maxf(0.01, main.ui_layer.scale.x)
	var r := Rect2(a / sc, (b - a) / sc).abs()
	var view := Rect2(Vector2.ZERO, size)
	if not view.intersects(r):
		return null
	return r.intersection(view)


# ------------------------------------------------------------- layout
func _place_card() -> void:
	var cs := _card.get_combined_minimum_size()
	cs.x = maxf(cs.x, minf(CARD_W, size.x - 2.0 * EDGE))
	_card.size = cs
	# Below the top strip and the objective chip, which stay readable.
	var top := EDGE
	if main.hud != null:
		top = main.hud.chips_bottom + 2.0
	var safe := Rect2(Vector2(EDGE, top), Vector2(size.x - 2.0 * EDGE, size.y - top - EDGE))
	var a := _anchor
	var low := a.get_center().y > size.y * 0.6
	var right := a.get_center().x > size.x * 0.5
	var order: Array
	if low:
		order = ["above", "left" if right else "right", "below", "right" if right else "left"]
	elif right:
		order = ["left", "below", "above", "right"]
	else:
		order = ["right", "below", "above", "left"]
	var pick := Rect2()
	var ok := false
	for side in order:
		var r := _beside(a, cs, side, safe)
		if safe.encloses(r) and not r.grow(-1.0).intersects(a):
			pick = r
			ok = true
			break
	if not ok:
		pick = _beside(a, cs, "above", safe)
		pick.position = pick.position.clamp(safe.position, safe.end - cs)
	_card.position = pick.position.round()


func _beside(a: Rect2, cs: Vector2, side: String, safe: Rect2) -> Rect2:
	var p := Vector2.ZERO
	match side:
		"left":
			p = Vector2(a.position.x - GAP - cs.x, a.get_center().y - cs.y * 0.5)
		"right":
			p = Vector2(a.end.x + GAP, a.get_center().y - cs.y * 0.5)
		"above":
			p = Vector2(a.end.x - cs.x, a.position.y - GAP - cs.y)
		"below":
			p = Vector2(a.end.x - cs.x, a.end.y + GAP)
	if side == "left" or side == "right":
		p.y = clampf(p.y, safe.position.y, maxf(safe.position.y, safe.end.y - cs.y))
	else:
		p.x = clampf(p.x, safe.position.x, maxf(safe.position.x, safe.end.x - cs.x))
	return Rect2(p, cs)


func _draw() -> void:
	if _step == "" or not _card.visible:
		return
	var a := 0.55 + 0.45 * sin(_t * 4.0)
	var frame := _anchor.grow(2.0)
	draw_rect(frame, Color(GOLD, a), false, 1.5)
	# Arrow from the card's nearest edge to the target's nearest edge.
	var card := Rect2(_card.position, _card.size)
	var from := _edge_toward(card, frame.get_center())
	var to := _edge_toward(frame, from)
	if from.distance_to(to) < 4.0:
		return
	var dir := (to - from).normalized()
	var tip := to - dir * 1.0
	draw_line(from, tip - dir * 5.0, Color(GOLD, 0.9), 2.0)
	var n := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([tip, tip - dir * 7.0 + n * 4.0, tip - dir * 7.0 - n * 4.0]), Color(GOLD, 0.95))


## Point on the border of `r` along the line from its centre toward `p`.
static func _edge_toward(r: Rect2, p: Vector2) -> Vector2:
	var c := r.get_center()
	var d := p - c
	if absf(d.x) < 0.001 and absf(d.y) < 0.001:
		return c
	var hx := r.size.x * 0.5
	var hy := r.size.y * 0.5
	var t := INF
	if absf(d.x) > 0.001:
		t = minf(t, hx / absf(d.x))
	if absf(d.y) > 0.001:
		t = minf(t, hy / absf(d.y))
	return c + d * minf(t, 1.0)
