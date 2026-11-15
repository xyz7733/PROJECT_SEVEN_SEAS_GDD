## Base class for the in-game windows: a framed panel with a title bar,
## optional tabs and a scrolling body that is rebuilt from the game state.
class_name GameWindow
extends PanelContainer

signal closed
## Emitted after the window was sized and placed (main keeps the HUD's
## level selector clear of right-docked windows).
signal laid_out

## Space the HUD keeps for itself, in UI units: set by Hud._do_layout.
## Windows stay below the top strip and objective chip, and above the
## bottom bars so neither the navigation nor (for right-docked windows)
## the context action and view controls are ever covered.
static var inset_top := 26.0
static var inset_bottom := 32.0
static var inset_bottom_right := 56.0
## False while the HUD is hidden (title screen): windows then use the whole
## screen minus a small margin instead of the last HUD bar insets.
static var hud_insets := true

var tab := ""
var main: Node
var body: VBoxContainer
var _title_label: Label
var _title_icon: TextureRect
var _tabs_box: HFlowContainer
var _scroll: ScrollContainer
var _footer: HBoxContainer
var _dirty := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var outer := UIK.vbox([], 3)
	add_child(outer)
	var head := UIK.hbox([], 3)
	_title_icon = UIK.icon("ui_info")
	head.add_child(_title_icon)
	_title_label = UIK.label("", "TitleLabel")
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title_label.custom_minimum_size.x = 40
	head.add_child(_title_label)
	head.add_child(UIK.icon_button("ui_close", I18n.t("ui.close"), close, "FlatButton"))
	outer.add_child(head)
	# Tabs wrap onto a second row instead of widening the window.
	_tabs_box = HFlowContainer.new()
	_tabs_box.add_theme_constant_override("h_separation", 1)
	_tabs_box.add_theme_constant_override("v_separation", 1)
	outer.add_child(_tabs_box)
	body = UIK.vbox([], 4)
	_scroll = UIK.scroll(body, 40)
	# Content wider than the window scrolls instead of pushing the window
	# past the edge of the screen.
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	outer.add_child(_scroll)
	minimum_size_changed.connect(_queue_layout)
	_footer = UIK.hbox([], 3)
	outer.add_child(_footer)


## Opens with a short fade instead of popping in. (Position and size are
## left alone: the layout owns them and the layout checks measure them.)
func _ready() -> void:
	if bool(Settings.get_value("reduceMotion")):
		return
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.14)


## Overridables -----------------------------------------------------------
func window_title() -> String:
	return ""


func window_icon() -> String:
	return "ui_info"


func window_size() -> Vector2:
	return Vector2(320, 300)


## Docking: "right", "left" or "center".
func dock() -> String:
	return "center"


func tabs() -> Array:
	return []


## True when the body manages its own scrolling and should exactly fill
## the window (the chart: map plus a scrolling detail column).
func fills_body() -> bool:
	return false


func build(_b: VBoxContainer) -> void:
	pass


func build_footer(_f: HBoxContainer) -> void:
	pass


# --------------------------------------------------------------------------
func open_tab(t: String) -> void:
	tab = t
	rebuild()


func rebuild() -> void:
	if not Game.has_game() and needs_game():
		return
	_title_label.text = window_title()
	_title_icon.texture = Art.icon(window_icon())
	UIK.clear(_tabs_box)
	var ts := tabs()
	if ts.size() > 0:
		if tab == "" or not ts.any(func(x): return x[0] == tab):
			tab = ts[0][0]
		var ids := []
		var labels := []
		var icons := []
		for x in ts:
			ids.append(x[0])
			labels.append(x[1])
			icons.append(x[2] if x.size() > 2 else "")
		var row := UIK.tab_row(ids, labels, tab, open_tab, icons)
		for c in row.get_children():
			row.remove_child(c)
			_tabs_box.add_child(c)
		row.free()
	_tabs_box.visible = ts.size() > 0
	var keep := _scroll.scroll_vertical
	if fills_body():
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIK.clear(body)
	build(body)
	UIK.clear(_footer)
	build_footer(_footer)
	_footer.visible = _footer.get_child_count() > 0
	_layout()
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = keep


func needs_game() -> bool:
	return true


var _layout_queued := false


func _queue_layout() -> void:
	if _layout_queued or not is_inside_tree():
		return
	_layout_queued = true
	(func():
		_layout_queued = false
		if is_inside_tree():
			_layout()).call_deferred()


## Sizes the window to its preferred size clamped to the free area between
## the HUD bars, then places it by its dock. The real size (content can
## need more than the preferred size) is clamped too, so the window is
## always entirely on screen.
func _host_size() -> Vector2:
	var vp := Vector2(640, 360)
	if is_inside_tree():
		vp = get_viewport_rect().size
		var host := get_parent() as Control
		if host != null and host.size.x > 0.0:
			vp = host.size
	return vp


## Width the body gets once laid out: the preferred width clamped to the
## free area, minus the panel border and the scrollbar. Builders use it to
## switch to a compact arrangement on narrow screens and large UI scales.
func body_width() -> float:
	var w := minf(window_size().x, maxf(80.0, _host_size().x - 8.0))
	return w - get_theme_stylebox("panel").get_minimum_size().x - _scroll.get_v_scroll_bar().get_combined_minimum_size().x


func _layout() -> void:
	var vp := _host_size()
	var top := clampf(inset_top if hud_insets else 4.0, 2.0, vp.y * 0.4)
	var bottom := clampf((inset_bottom_right if dock() == "right" else inset_bottom) if hud_insets else 4.0, 2.0, vp.y * 0.4)
	var free := Rect2(Vector2(4, top), Vector2(maxf(80.0, vp.x - 8.0), maxf(80.0, vp.y - top - bottom)))
	var s := window_size()
	s.x = minf(s.x, free.size.x)
	s.y = minf(s.y, free.size.y)
	custom_minimum_size = s
	# Paragraphs wrap to the column instead of making the body scroll sideways.
	if not fills_body():
		UIK.fit_paragraphs(body, s.x - get_theme_stylebox("panel").get_minimum_size().x
			- _scroll.get_v_scroll_bar().get_combined_minimum_size().x)
	size = s
	var real := size
	var pos: Vector2
	match dock():
		"right":
			pos = Vector2(free.end.x - real.x, top)
		"left":
			pos = Vector2(free.position.x, top)
		_:
			pos = (free.position + (free.size - real) / 2.0).round()
	pos.x = clampf(pos.x, 2.0, maxf(2.0, vp.x - real.x - 2.0))
	pos.y = clampf(pos.y, 2.0, maxf(2.0, vp.y - real.y - 2.0))
	position = pos
	laid_out.emit()


func mark_dirty() -> void:
	if visible:
		rebuild()


func close() -> void:
	closed.emit()


func act(res: Dictionary, quiet_fail := false) -> bool:
	return Game.act(res, quiet_fail)


func confirm(title: String, body_text: String, cb: Callable) -> void:
	if main and main.has_method("confirm"):
		main.confirm(title, body_text, cb)
	else:
		cb.call()


func st() -> Dictionary:
	return Game.state


func t(key: String, params: Variant = null) -> String:
	return I18n.t(key, params, Game.state)
