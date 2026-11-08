## Modal dialog: title, free-form body and a row of buttons. Used for
## confirmations, sea events, rewards and battle reports.
##
## Safe area: the dialog is centred and never larger than the (UI-scaled)
## screen minus a margin. The title and the button row always stay
## visible; a body taller than the remaining height scrolls.
class_name Dialog
extends Control

const MARGIN := 6.0

signal done(choice: Variant)

var panel: PanelContainer
var body: VBoxContainer
var buttons: HBoxContainer
var _title: Label
var _icon: TextureRect
var _width := 300
var _head: HBoxContainer
var _scroll: ScrollContainer
var _fit_queued := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	center.add_child(panel)
	var v := UIK.vbox([], 5)
	panel.add_child(v)
	_head = UIK.hbox([], 4)
	_icon = UIK.icon("ui_info")
	_head.add_child(_icon)
	_title = UIK.label("", "TitleLabel")
	_head.add_child(_title)
	v.add_child(_head)
	body = UIK.vbox([], 3)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)
	v.add_child(_scroll)
	buttons = UIK.hbox([], 4)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(buttons)
	body.minimum_size_changed.connect(_queue_fit)
	buttons.minimum_size_changed.connect(_queue_fit)
	resized.connect(_queue_fit)


func _queue_fit() -> void:
	if _fit_queued:
		return
	_fit_queued = true
	_fit.call_deferred()


## Caps the body height so the whole dialog fits the screen; the body
## scrolls when it needs more. Re-run when content or screen size changes.
func _fit() -> void:
	_fit_queued = false
	if not is_inside_tree():
		return
	var scr := size
	if scr.x <= 0.0 or scr.y <= 0.0:
		scr = get_viewport_rect().size
	var pad := Vector2.ZERO
	var sb := panel.get_theme_stylebox("panel")
	if sb != null:
		pad = sb.get_minimum_size()
	panel.custom_minimum_size.x = minf(float(_width), maxf(120.0, scr.x - 2.0 * MARGIN - pad.x))
	var fixed := _head.get_combined_minimum_size().y + buttons.get_combined_minimum_size().y + 10.0
	var room := maxf(40.0, scr.y - 2.0 * MARGIN - pad.y - fixed)
	var want := body.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = minf(want, room)


func setup(title: String, icon_name := "ui_info", width := 300) -> Dialog:
	_title.text = title
	_icon.texture = Art.icon(icon_name)
	_width = width
	panel.custom_minimum_size.x = width
	_queue_fit()
	return self


func text(s: String, variation := "") -> Dialog:
	if s != "":
		body.add_child(UIK.label(s, variation, true, _width - 16))
	return self


func line(icon_name: String, s: String, variation := "") -> Dialog:
	var h := UIK.hbox([UIK.icon(icon_name), UIK.label(s, variation, true, _width - 40)], 3)
	body.add_child(h)
	return self


func add(c: Control) -> Dialog:
	body.add_child(c)
	return self


func button(label: String, choice: Variant, primary := false, enabled := true, tip := "", icon_name := "") -> Button:
	var b := UIK.button(label, func(): _choose(choice), icon_name, "PrimaryButton" if primary else "", enabled, tip)
	if not primary and String(choice) in ["cancel", "close", "ignore", "refuse", "leave", "back", "no"]:
		b.set_meta("sfx", "ui_back")
	buttons.add_child(b)
	return b


func _choose(choice: Variant) -> void:
	done.emit(choice)
	queue_free()


func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		# Esc picks the last non-primary button when one exists.
		for i in range(buttons.get_child_count() - 1, -1, -1):
			var b: Button = buttons.get_child(i)
			if b.theme_type_variation != "PrimaryButton" and not b.disabled:
				b.pressed.emit()
				return
