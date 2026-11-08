## Compact in-world HUD: a slim resource strip, an objective line, icon
## navigation with hotkeys, view controls, the ship level selector, a
## contextual action, the build mode hint, a hover tooltip and toast notices.
##
## Layout is explicit rather than anchor-driven: `_do_layout` measures each
## panel's real content size and places it inside the visible rectangle of
## the (UI-scaled) viewport, so nothing can start inside the window and run
## past its edge. It runs again whenever the viewport, the UI scale or any
## panel's content changes. Narrow layouts (large UI sizes, long Chinese
## text) wrap the status strip onto a second row, stack the right-hand view
## controls above the navigation bar, trim long labels with an ellipsis (the
## full text stays in the tooltip) and let the level selector scroll.
class_name Hud
extends Control

signal nav(name: String)
signal context_action(name: String)
signal view_action(name: String)
## Space taken by the HUD, in HUD units: the bottom of the top strip, the
## bottom of the objective chip and the height kept free at the bottom.
signal insets_changed(top_bar: float, chips: float, bottom: float)

const NAV := [
	["ship", "ui_build", "nav.ship", "B"],
	["crew", "ui_crew", "nav.crew", "C"],
	["pets", "ui_pets", "nav.pets", "P"],
	["port", "ui_port", "nav.port", "O"],
	["chart", "ui_map", "nav.map", "M"],
	["codex", "ui_codex", "nav.codex", "K"],
	["log", "ui_quest", "hud.overview", "L"],
	["system", "ui_system", "nav.system", "Esc"],
]
## Gap kept between HUD panels and the edge of the visible area.
const M := 2.0
const GAP := 2.0

var top: PanelContainer
var res_box: HBoxContainer
var status_box: HBoxContainer
var _row1: HBoxContainer
var _row2: HBoxContainer
var obj_label: Label
var obj_panel: PanelContainer
var nav_box: HBoxContainer
var _navp: PanelContainer
var _viewp: PanelContainer
var view_box: HBoxContainer
var ctx_box: BoxContainer
var hint_panel: PanelContainer
var hint_label: Label
var tip_panel: PanelContainer
var tip_label: Label
var toast_box: VBoxContainer
var deck_label: Label
var zoom_label: Label
var level_panel: PanelContainer
var level_scroll: ScrollContainer
var level_box: VBoxContainer
var _deck_up: Button
var _deck_down: Button
var _where_label: Label
var _level_sig := ""
var _level_buttons: Array[Button] = []
var _level_nat_w := 0.0
var _nav_buttons := {}
var _save_icon: TextureRect
var _sails_btn: Button
var _fit_btn: Button
var _world_mode := "port"
var _tip_text := ""
var _top_wrapped := false
var _layout_queued := false
var _obj_text := ""
var _where_text := ""
var _deck_text := ""
var _hint_text := ""
## Left edge of a window docked on the right (in HUD units), or INF. The
## level selector moves left of it so it stays usable while building.
var right_block_x := INF
var top_bar_bottom := 24.0
var chips_bottom := 40.0
var bottom_reserved := 30.0
## Top of the right-hand bottom cluster (view controls and context action).
var right_cluster_top := 300.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# --- top resource strip: resources left, status right; wraps to two rows
	top = UIK.panel(null, "HudBar")
	top.mouse_filter = Control.MOUSE_FILTER_PASS
	_managed(top)
	var rows := UIK.vbox([], 1)
	top.add_child(rows)
	res_box = UIK.hbox([], 8)
	status_box = UIK.hbox([], 6)
	_row1 = UIK.hbox([res_box, UIK.spacer(), status_box], 8)
	_row2 = UIK.hbox([UIK.spacer()], 0)
	_row2.visible = false
	rows.add_child(_row1)
	rows.add_child(_row2)
	# --- objective line
	obj_panel = UIK.panel(null, "ChipPanel")
	obj_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_managed(obj_panel)
	obj_label = UIK.label("", "")
	obj_label.add_theme_font_size_override("font_size", 12)
	obj_panel.add_child(UIK.hbox([UIK.icon("ui_quest"), obj_label], 3))
	obj_panel.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			nav.emit("log"))
	# --- bottom-left navigation
	_navp = UIK.panel(null, "HudBar")
	_navp.mouse_filter = Control.MOUSE_FILTER_PASS
	_managed(_navp)
	nav_box = UIK.hbox([], 2)
	_navp.add_child(nav_box)
	for n in NAV:
		var b := UIK.icon_button(n[1], "%s (%s)" % [I18n.t(n[2]), n[3]], func(): nav.emit(n[0]), "SlotButton")
		b.custom_minimum_size = Vector2(24, 24)
		nav_box.add_child(b)
		_nav_buttons[n[0]] = b
	# --- bottom-right view controls: level up / name / level down, zoom, rig
	_viewp = UIK.panel(null, "HudBar")
	_viewp.mouse_filter = Control.MOUSE_FILTER_PASS
	_managed(_viewp)
	view_box = UIK.hbox([], 2)
	_viewp.add_child(view_box)
	_deck_up = UIK.icon_button("ui_deck_up", I18n.t("view.deck_next"), func(): view_action.emit("level_up"), "FlatButton")
	view_box.add_child(_deck_up)
	deck_label = UIK.label("", "DimLabel")
	deck_label.mouse_filter = Control.MOUSE_FILTER_PASS
	view_box.add_child(deck_label)
	_deck_down = UIK.icon_button("ui_deck_down", I18n.t("view.deck_next"), func(): view_action.emit("level_down"), "FlatButton")
	view_box.add_child(_deck_down)
	view_box.add_child(UIK.icon_button("ui_zoom_out", I18n.t("view.zoom_out") + " (−)", func(): view_action.emit("zoom_out"), "FlatButton"))
	zoom_label = UIK.label("×2", "DimLabel")
	view_box.add_child(zoom_label)
	view_box.add_child(UIK.icon_button("ui_zoom_in", I18n.t("view.zoom_in") + " (+)", func(): view_action.emit("zoom_in"), "FlatButton"))
	_sails_btn = UIK.icon_button("ui_rig", I18n.t("view.sails_hide"), func(): view_action.emit("sails"), "FlatButton")
	view_box.add_child(_sails_btn)
	_fit_btn = UIK.icon_button("ui_fit", I18n.t("view.fit"), func(): view_action.emit("fit"), "FlatButton")
	view_box.add_child(_fit_btn)
	# --- right edge: ship level selector (weather deck on top, holds below)
	level_panel = UIK.panel(null, "HudBar")
	level_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	level_panel.visible = false
	_managed(level_panel)
	level_box = UIK.vbox([], 1)
	level_scroll = ScrollContainer.new()
	level_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	level_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	level_scroll.add_child(level_box)
	level_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_panel.add_child(level_scroll)
	# --- contextual primary action (above the view controls)
	ctx_box = BoxContainer.new()
	ctx_box.add_theme_constant_override("separation", 3)
	ctx_box.alignment = BoxContainer.ALIGNMENT_END
	ctx_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_managed(ctx_box)
	# --- mode hint (bottom centre)
	hint_panel = UIK.panel(null, "TipPanel")
	hint_panel.visible = false
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_managed(hint_panel)
	hint_label = UIK.label("", "")
	hint_panel.add_child(hint_label)
	# --- hover tooltip (placed in _process)
	tip_panel = UIK.panel(null, "TipPanel")
	tip_panel.visible = false
	tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_panel.z_index = 10
	add_child(tip_panel)
	tip_label = UIK.label("", "")
	tip_panel.add_child(tip_label)
	# --- toasts
	toast_box = UIK.vbox([], 2)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_managed(toast_box)


func _managed(c: Control) -> void:
	add_child(c)
	c.minimum_size_changed.connect(_queue_layout)
	c.visibility_changed.connect(_queue_layout)


func _ready() -> void:
	Game.notice.connect(toast)
	Game.saved.connect(func(_ok): _flash_save())
	_queue_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		_queue_layout()


func _queue_layout() -> void:
	if _layout_queued or not is_inside_tree():
		return
	_layout_queued = true
	_do_layout.call_deferred()


## Natural single-line width of `text` in a label's font.
func _text_w(l: Control, text: String) -> float:
	if text == "":
		return 0.0
	var f := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	if f == null:
		return float(text.length() * 8)
	return ceilf(f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x) + 1.0


## Shows `text` in one line no wider than `max_w`, trimming with an ellipsis.
func _fit_label(l: Label, text: String, max_w: float) -> void:
	var nat := _text_w(l, text)
	max_w = maxf(24.0, floorf(max_w))
	if nat <= max_w:
		l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		l.custom_minimum_size.x = 0.0
	else:
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.custom_minimum_size.x = max_w


## Wraps `text` when it is wider than `max_w`.
func _wrap_label(l: Label, text: String, max_w: float) -> void:
	var nat := _text_w(l, text)
	max_w = maxf(40.0, floorf(max_w))
	if nat <= max_w:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.custom_minimum_size.x = 0.0
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = max_w


func _pad(p: Control) -> Vector2:
	var sb := p.get_theme_stylebox("panel")
	return sb.get_minimum_size() if sb != null else Vector2.ZERO


func _place(c: Control, pos: Vector2) -> Rect2:
	var s := c.get_combined_minimum_size()
	c.position = pos.round()
	c.size = s
	return Rect2(c.position, s)


## Moves `r` up until it no longer overlaps any of `others`.
func _lift_clear(r: Rect2, others: Array) -> Rect2:
	for _pass in 3:
		for o in others:
			if r.intersects(o):
				r.position.y = o.position.y - GAP - r.size.y
	return r


func _do_layout() -> void:
	_layout_queued = false
	var vw := size.x
	var vh := size.y
	if vw < 64.0 or vh < 64.0:
		return
	var avail := vw - 2.0 * M
	# --- top strip
	var tpad := _pad(top)
	var res_w := res_box.get_combined_minimum_size().x
	var others := 0.0
	var n_status := 0
	for c in status_box.get_children():
		if c is Control and c != _where_label and (c as Control).visible:
			others += (c as Control).get_combined_minimum_size().x
			n_status += 1
	others += 6.0 * n_status
	var where_nat := _text_w(_where_label, _where_text) if _where_label != null else 0.0
	var one_row := res_w + 8.0 + others + where_nat + 8.0 + tpad.x <= avail
	_set_top_wrapped(not one_row)
	if _where_label != null:
		var row_w := avail - tpad.x - (0.0 if _top_wrapped else res_w + 16.0)
		_fit_label(_where_label, _where_text, row_w - others)
		_where_label.tooltip_text = _where_text
	top.position = Vector2(M, M)
	top.size = Vector2(avail, top.get_combined_minimum_size().y)
	top_bar_bottom = top.position.y + top.size.y if top.visible else 0.0
	# --- objective chip
	chips_bottom = top_bar_bottom
	if obj_panel.visible:
		var opad := obj_panel.get_combined_minimum_size().x - obj_label.get_combined_minimum_size().x
		_fit_label(obj_label, _obj_text, avail - opad)
		var r := _place(obj_panel, Vector2(M, top_bar_bottom + GAP))
		chips_bottom = r.end.y
	# --- bottom-left navigation
	var nav_r := _place(_navp, Vector2(M, vh - M - _navp.get_combined_minimum_size().y))
	var blocked: Array = [nav_r] if _navp.visible else []
	bottom_reserved = vh - nav_r.position.y + GAP if _navp.visible else M
	# --- bottom-right view controls (beside the navigation, or above it)
	var right_bottom := vh - M
	var right_rects: Array = []
	if _viewp.visible:
		var vpad := _viewp.get_combined_minimum_size().x - deck_label.get_combined_minimum_size().x
		_fit_label(deck_label, _deck_text, minf(160.0, avail - vpad))
		var vs := _viewp.get_combined_minimum_size()
		var vr := Rect2(Vector2(maxf(M, vw - M - vs.x), vh - M - vs.y), vs)
		vr = _lift_clear(vr, blocked)
		vr = _place(_viewp, vr.position)
		right_rects.append(vr)
		right_bottom = vr.position.y
	# --- context action above the view controls
	if ctx_box.get_child_count() > 0:
		var row_w := 0.0
		var n := 0
		for c in ctx_box.get_children():
			if c is Control:
				row_w += (c as Control).get_combined_minimum_size().x
				n += 1
		row_w += 3.0 * maxf(0.0, n - 1)
		ctx_box.vertical = row_w > avail
		var cs := ctx_box.get_combined_minimum_size()
		var cr := Rect2(Vector2(maxf(M, vw - M - cs.x), right_bottom - GAP - cs.y), cs)
		cr = _lift_clear(cr, blocked)
		cr = _place(ctx_box, cr.position)
		right_rects.append(cr)
		right_bottom = minf(right_bottom, cr.position.y)
	right_cluster_top = right_bottom
	# --- toasts: top right, under the strip (or under the objective chip)
	var tw := toast_box.get_combined_minimum_size()
	var ty := top_bar_bottom + GAP
	if obj_panel.visible and obj_panel.position.x + obj_panel.size.x > vw - M - tw.x - 4.0:
		ty = chips_bottom + GAP
	_place(toast_box, Vector2(maxf(M, vw - M - tw.x), ty))
	# --- ship level selector on the right, between the strip and the cluster
	if level_panel.visible:
		_layout_levels(vw, avail, blocked + right_rects)
	# --- mode hint, bottom centre, clear of everything at the bottom
	if hint_panel.visible:
		var hpad := _pad(hint_panel)
		_wrap_label(hint_label, _hint_text, minf(360.0, avail - hpad.x))
		var hs := hint_panel.get_combined_minimum_size()
		var hr := Rect2(Vector2(clampf(roundf((vw - hs.x) * 0.5), M, maxf(M, vw - M - hs.x)), vh - M - hs.y), hs)
		hr = _lift_clear(hr, blocked + right_rects)
		hr.position.y = maxf(hr.position.y, chips_bottom + GAP)
		_place(hint_panel, hr.position)
	GameWindow.inset_top = top_bar_bottom + GAP
	GameWindow.inset_bottom = bottom_reserved
	GameWindow.inset_bottom_right = vh - right_cluster_top + GAP
	insets_changed.emit(top_bar_bottom, chips_bottom, bottom_reserved)


func _layout_levels(vw: float, avail: float, others: Array) -> void:
	var lpad := _pad(level_panel)
	var max_w := clampf(avail * 0.42, 84.0, 168.0)
	var inner := minf(_level_nat_w, max_w - lpad.x)
	var trim := _level_nat_w > inner + 0.5
	for b in _level_buttons:
		if not is_instance_valid(b):
			continue
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if trim else TextServer.OVERRUN_NO_TRIMMING
		b.clip_text = trim
		b.custom_minimum_size.x = inner if trim else 96.0
	var right_edge := minf(vw - M, right_block_x - GAP)
	var band_top := top_bar_bottom + GAP
	var band_bot := right_cluster_top - GAP
	var lx := right_edge - lpad.x - inner
	# Clear of the objective chip and the navigation bar when they reach this far.
	if obj_panel.visible and obj_panel.position.x + obj_panel.size.x > lx - GAP:
		band_top = chips_bottom + GAP
	for o in others:
		var r: Rect2 = o
		if r.end.x > lx - GAP and r.position.y < band_bot:
			band_bot = minf(band_bot, r.position.y - GAP)
	var box := level_box.get_combined_minimum_size()
	var avail_h := maxf(24.0, band_bot - band_top - lpad.y)
	var sh := minf(box.y, avail_h)
	var bar_w := 0.0
	if sh < box.y:
		bar_w = level_scroll.get_v_scroll_bar().get_combined_minimum_size().x + 1.0
	level_scroll.custom_minimum_size = Vector2(inner + bar_w, sh)
	var ls := level_panel.get_combined_minimum_size()
	var x := maxf(M, right_edge - ls.x)
	var y := band_top + maxf(0.0, (band_bot - band_top - ls.y) * 0.5)
	_place(level_panel, Vector2(x, y))


func _set_top_wrapped(w: bool) -> void:
	if w == _top_wrapped:
		return
	_top_wrapped = w
	status_box.get_parent().remove_child(status_box)
	if w:
		_row2.add_child(status_box)
	else:
		_row1.add_child(status_box)
	_row2.visible = w


func set_right_block(x: float) -> void:
	if absf(x - right_block_x) < 0.5 or (is_inf(x) and is_inf(right_block_x)):
		return
	right_block_x = x
	_queue_layout()


# --------------------------------------------------------------- refresh
func refresh(world_mode: String) -> void:
	_world_mode = world_mode
	if not Game.has_game():
		return
	var s := Game.state
	UIK.clear(res_box)
	UIK.clear(status_box)
	var inv: Dictionary = s.inventory
	var lay := Game.layout()
	res_box.add_child(UIK.stat("gold", I18n.fmt_num(inv.gold), "GoldLabel", I18n.t("status.gold")))
	var food_cap := Rules.food_capacity(s, lay)
	res_box.add_child(UIK.stat("food", "%s/%s" % [I18n.fmt_num(inv.food), I18n.fmt_num(food_cap)], "BadLabel" if int(inv.food) <= 2 else "", I18n.t("status.food")))
	res_box.add_child(UIK.stat("supplies", I18n.fmt_num(inv.supplies), "", I18n.t("status.supplies")))
	res_box.add_child(UIK.stat("materials", I18n.fmt_num(inv.materials), "", I18n.t("status.materials")))
	var sta := UIK.hbox([UIK.icon("stamina")], 2)
	sta.tooltip_text = I18n.t("home.stamina_rule")
	sta.mouse_filter = Control.MOUSE_FILTER_PASS
	var smax := maxi(1, int(s.ship.staminaMax))
	var bar := UIK.bar(float(s.ship.stamina) / float(smax), "sta", 44, 6)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sta.add_child(bar)
	sta.add_child(UIK.label("%d/%d" % [int(s.ship.stamina), smax], "DimLabel"))
	res_box.add_child(sta)
	var led: Dictionary = inv.ledger
	if int(led.gold) > 0 or int(led.materials) > 0:
		res_box.add_child(UIK.stat("ui_chest", "%s · %s" % [I18n.fmt_num(led.gold), I18n.fmt_num(led.materials)], "WarnLabel",
			I18n.t("status.ledger") + " — " + I18n.t("status.ledger_hint")))
	var hour := int(s.envelope.gameClock) % 24
	status_box.add_child(UIK.stat("day" if hour >= 6 and hour < 19 else "night", Fmt.clock_text(s.envelope.gameClock), "DimLabel"))
	_where_text = Fmt.where_text(s)
	_where_label = UIK.label(_where_text, "")
	_where_label.mouse_filter = Control.MOUSE_FILTER_PASS
	status_box.add_child(_where_label)
	_save_icon = UIK.icon("ui_save", Color(1, 1, 1, 0.5) if Game.last_save_ok else Color(1, 0.4, 0.4))
	_save_icon.tooltip_text = I18n.t("status.saved") if Game.last_save_ok else I18n.t("status.save_failed")
	_save_icon.mouse_filter = Control.MOUSE_FILTER_PASS
	status_box.add_child(_save_icon)
	# objective
	var ob := Fmt.objective(s)
	_obj_text = ob.title + "  ·  " + ob.target if not ob.done else ob.title + " · " + ob.line
	obj_label.text = _obj_text
	obj_panel.tooltip_text = _obj_text + "\n" + ob.get("why", ob.get("line", "")) + "\n" + ob.get("trial", "")
	obj_panel.visible = world_mode != "battle"
	# navigation availability
	_nav_buttons.port.disabled = not Rules.at_port(s) or s.encounter != null
	for k in ["ship", "crew", "pets", "chart", "port", "log"]:
		_nav_buttons[k].visible = world_mode != "battle"
	_nav_buttons.codex.visible = world_mode != "battle"
	# context actions
	UIK.clear(ctx_box)
	match world_mode:
		"port":
			ctx_box.add_child(UIK.primary(I18n.t("hud.sail"), func(): context_action.emit("sail"), "ui_sail"))
		"site":
			ctx_box.add_child(UIK.button(I18n.t("home.open_chart"), func(): context_action.emit("sail"), "ui_map"))
			ctx_box.add_child(UIK.button(I18n.t("home.emergency_return"), func(): context_action.emit("return"), "ui_home", "", true, I18n.t("home.emergency_hint")))
		"at_sea":
			if s.voyage != null and s.encounter == null:
				ctx_box.add_child(UIK.button(I18n.t("home.emergency_return"), func(): context_action.emit("return"), "ui_home", "", true, I18n.t("home.emergency_hint")))
	_viewp.visible = world_mode == "port" or world_mode == "at_sea" or world_mode == "site"
	_queue_layout()


## `up_name` / `down_name` name the level each arrow leads to ("" = none).
func set_view_info(deck_text: String, zoom_text: String, sails_shown: bool, show_deck := true, up_name := "", down_name := "") -> void:
	_deck_text = deck_text
	deck_label.text = deck_text
	zoom_label.text = zoom_text
	deck_label.visible = show_deck
	_deck_up.visible = show_deck
	_deck_down.visible = show_deck
	_deck_up.disabled = up_name == ""
	_deck_down.disabled = down_name == ""
	_deck_up.tooltip_text = I18n.t("view.level_up", {"deck": up_name}) if up_name != "" else I18n.t("view.level_top")
	_deck_down.tooltip_text = I18n.t("view.level_down", {"deck": down_name}) if down_name != "" else I18n.t("view.level_bottom")
	deck_label.tooltip_text = deck_text + "\n" + I18n.t("ship.level_keys")
	_sails_btn.visible = show_deck
	_sails_btn.tooltip_text = I18n.t("view.sails_hide") if sails_shown else I18n.t("view.sails_show")
	_queue_layout()


## Ship levels for the selector: [{title, crew, hint}], top level first.
func set_levels(items: Array, current: int, shown: bool) -> void:
	level_panel.visible = shown and items.size() > 1
	if not level_panel.visible:
		return
	var sig := "%d|%s" % [current, JSON.stringify(items)]
	if sig == _level_sig:
		return
	_level_sig = sig
	UIK.clear(level_box)
	_level_buttons.clear()
	var head := UIK.label(I18n.t("view.levels"), "DimLabel")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_box.add_child(head)
	_level_nat_w = head.get_combined_minimum_size().x
	for i in items.size():
		var it: Dictionary = items[i]
		var k := i
		var txt := I18n.t("view.level_entry", {"deck": it.title, "n": int(it.crew)})
		var b := UIK.button(txt, func(): view_action.emit("level:%d" % k),
			"ui_crew" if i == current else "", "", true, txt + "\n" + String(it.hint) + "\n" + I18n.t("ship.level_keys"))
		b.toggle_mode = true
		b.button_pressed = i == current
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(96, 18)
		level_box.add_child(b)
		_level_buttons.append(b)
		_level_nat_w = maxf(_level_nat_w, b.get_combined_minimum_size().x)
	_queue_layout()


func set_hint(text: String) -> void:
	_hint_text = text
	hint_label.text = text
	hint_panel.visible = text != ""
	_queue_layout()


func set_tip(text: String) -> void:
	if text == _tip_text:
		return
	_tip_text = text
	tip_label.text = text
	tip_panel.visible = text != ""
	if text != "":
		_wrap_label(tip_label, text, minf(260.0, size.x - 2.0 * M - _pad(tip_panel).x))
	tip_panel.reset_size()


func _process(_dt: float) -> void:
	if tip_panel.visible:
		var mp := get_local_mouse_position()
		var s := tip_panel.get_combined_minimum_size()
		var p := mp + Vector2(10, 12)
		var vp := size
		if p.x + s.x > vp.x - M:
			p.x = mp.x - s.x - 6
		if p.y + s.y > vp.y - M:
			p.y = mp.y - s.y - 6
		p.x = clampf(p.x, M, maxf(M, vp.x - M - s.x))
		p.y = clampf(p.y, M, maxf(M, vp.y - M - s.y))
		tip_panel.position = p.round()
		tip_panel.size = s


func toast(text: String, tone := "info") -> void:
	if text == "":
		return
	var p := UIK.panel(null, "TipPanel")
	var ic := "ui_warn" if tone == "error" or tone == "warn" else ("ui_check" if tone == "good" else "ui_bell")
	var l := UIK.label(text, "BadLabel" if tone == "error" else "", true, 60)
	p.add_child(UIK.hbox([UIK.icon(ic), l], 3))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(p)
	var max_w := minf(220.0, size.x - 2.0 * M - 30.0)
	l.custom_minimum_size.x = clampf(_text_w(l, text), 60.0, maxf(60.0, max_w))
	while toast_box.get_child_count() > 4:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	var tw := p.create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func _flash_save() -> void:
	if _save_icon and is_instance_valid(_save_icon):
		_save_icon.modulate = Color(1, 1, 1, 1) if Game.last_save_ok else Color(1, 0.4, 0.4)
		var tw := _save_icon.create_tween()
		tw.tween_property(_save_icon, "modulate:a", 0.5, 1.2)
