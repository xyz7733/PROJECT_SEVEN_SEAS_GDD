## Boot scene. Applies the saved language, or on the very first launch asks
## the player to pick one (in both languages, over the ship at dusk), then
## hands over to the main scene.
extends Node

const MAIN_SCENE := "res://scenes/main.tscn"

var _root: Control


func _ready() -> void:
	if Settings.has_locale():
		I18n.set_locale(String(Settings.get_value("locale")))
		_go.call_deferred()
		return
	var guess := "zh_CN" if OS.get_locale().begins_with("zh") else "en"
	I18n.set_locale(guess)
	var backdrop := ShipView.new()
	add_child(backdrop)
	backdrop.bind(GS.create_new_game(20260101), "title", false)
	backdrop.set_process_unhandled_input(false)
	backdrop.cam.make_current()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = Art.theme
	layer.add_child(_root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := UIK.panel(null, "")
	center.add_child(panel)
	var v := UIK.vbox([], 5)
	v.custom_minimum_size.x = 240
	panel.add_child(v)
	var head := UIK.hbox([UIK.icon("ui_globe")], 4)
	var title := UIK.label(_msg("en", "lang.choose") + " · " + _msg("zh_CN", "lang.choose"), "TitleLabel")
	head.add_child(title)
	v.add_child(head)
	for code in I18n.SUPPORTED:
		var b := UIK.button(I18n.language_name(code), _choose.bind(code), "",
			"PrimaryButton" if code == guess else "")
		b.custom_minimum_size.y = 22
		v.add_child(b)
		if code == guess:
			b.grab_focus.call_deferred()
	v.add_child(UIK.sep())
	for code in I18n.SUPPORTED:
		v.add_child(UIK.label(_msg(code, "lang.note"), "DimLabel", true, 236))


## Reads a key from one language's table, independent of the active locale.
func _msg(code: String, key: String) -> String:
	var tr_obj := TranslationServer.get_translation_object(code)
	if tr_obj:
		var s := String(tr_obj.get_message(key))
		if s != "":
			return s
	return I18n.t(key)


func _choose(code: String) -> void:
	Settings.set_value("locale", code)
	I18n.set_locale(code)
	_go()


func _go() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)
