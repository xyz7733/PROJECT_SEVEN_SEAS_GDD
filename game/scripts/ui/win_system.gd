## System window: manual save slots, rotating recovery saves, settings,
## language restart, captain statistics, title screen and quit.
## Also reachable from the title screen (settings only, no live game).
extends GameWindow

var pending_locale := ""
var _vol_dirty := ""


func window_title() -> String:
	return I18n.t("system.title")


func window_icon() -> String:
	return "ui_system"


func window_size() -> Vector2:
	return Vector2(440, 300)


func needs_game() -> bool:
	return false


func tabs() -> Array:
	var out := []
	if Game.has_game():
		out.append(["saves", I18n.t("system.manual"), "ui_save"])
	out.append(["settings", I18n.t("system.settings"), "ui_system"])
	if Game.has_game():
		out.append(["captain", I18n.t("system.captain"), "fame"])
	return out


func build(b: VBoxContainer) -> void:
	if pending_locale == "":
		pending_locale = I18n.locale()
	if tab == "" or (not Game.has_game() and tab != "settings"):
		tab = "saves" if Game.has_game() else "settings"
	match tab:
		"saves":
			_saves(b)
		"settings":
			_settings(b)
		"captain":
			_captain(b)


func _busy() -> bool:
	return Game.has_game() and st().encounter != null


func _when(unix: int) -> String:
	if unix <= 0:
		return ""
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_datetime_string_from_unix_time(unix + bias, true)


func _meta_line(sm: Dictionary) -> String:
	return " · ".join([I18n.t(String(sm.get("titleKey", "title.unknown_captain"))), I18n.t("loc.%s.name" % sm.get("locationId", "")),
		I18n.t("ui.day", {"n": int(sm.get("day", 0)) + 1}), I18n.t("system.crew_n", {"n": int(sm.get("crew", 0))}),
		I18n.t("system.trials_n", {"n": int(sm.get("trials", 0))})])


# ----------------------------------------------------------------- saves
func _saves(b: VBoxContainer) -> void:
	var busy := _busy()
	var status := UIK.hbox([UIK.label(I18n.t("system.storage_local"), "GoodLabel")], 6)
	if not Game.last_save_ok:
		status.add_child(UIK.label(I18n.t("system.last_save_failed"), "BadLabel"))
	elif Game.last_saved_unix > 0:
		status.add_child(UIK.label(I18n.t("system.last_saved", {"time": _when(Game.last_saved_unix)}), "DimLabel"))
	b.add_child(status)
	if not Game.last_save_ok:
		b.add_child(UIK.para(I18n.t("err.save_write_failed"), "WarnLabel", 410))
	b.add_child(UIK.header(I18n.t("system.manual"), "ui_save"))
	b.add_child(UIK.para(I18n.t("system.manual_hint"), "DimLabel", 410))
	for sl in SaveStore.list_manual():
		var i: int = sl.index
		var ok: bool = sl.status == "ok"
		var info := UIK.vbox([UIK.label(I18n.t("system.slot_n", {"n": i + 1}), "GoldLabel")], 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if ok:
			info.add_child(UIK.label(_meta_line(sl.record.summary), "", true, 250))
			info.add_child(UIK.label(_when(int(sl.record.savedAt)), "DimLabel"))
		else:
			info.add_child(UIK.label(I18n.t("system.slot_corrupt") if sl.status == "corrupt" else I18n.t("system.slot_empty"), "BadLabel" if sl.status == "corrupt" else "DimLabel"))
		var row := UIK.hbox([info], 3)
		row.add_child(UIK.button(I18n.t("system.save_here"), _save_slot.bind(i, sl.status != "empty"), "ui_save", "PrimaryButton", not busy, I18n.t("err.in_encounter") if busy else ""))
		row.add_child(UIK.button(I18n.t("system.load"), _load_slot.bind(i), "ui_load", "", ok, "" if ok else I18n.t("system.slot_empty")))
		row.add_child(UIK.icon_button("ui_trash", I18n.t("system.delete"), _delete_slot.bind(i), "", sl.status != "empty"))
		b.add_child(UIK.panel(row, "FlatPanel"))
	b.add_child(UIK.header(I18n.t("system.recovery"), "ui_load"))
	b.add_child(UIK.para(I18n.t("system.recovery_hint", {"n": SaveStore.RECOVERY_COUNT}), "DimLabel", 410))
	var rec := SaveStore.list_recovery()
	if rec.is_empty():
		b.add_child(UIK.label(I18n.t("system.no_recovery"), "DimLabel"))
	for k in rec.size():
		var r: Dictionary = rec[k]
		var info := UIK.vbox([UIK.label(I18n.t("system.recovery_latest") if k == 0 else I18n.t("system.recovery_older", {"n": k}), "GoldLabel"),
			UIK.label(I18n.t(String(r.record.reason if r.record.reason else "save.reason_auto")) + " · " + _meta_line(r.record.summary), "", true, 300),
			UIK.label(_when(int(r.record.savedAt)), "DimLabel")], 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_child(UIK.panel(UIK.hbox([info, UIK.button(I18n.t("system.load"), _load_recovery.bind(int(r.index)), "ui_load")], 3), "FlatPanel"))
	b.add_child(UIK.hbox([UIK.button(I18n.t("system.open_folder"), _open_folder, "ui_load", "FlatButton"),
		UIK.label(ProjectSettings.globalize_path(SaveStore.DIR), "DimLabel", true, 300)], 4))


func _save_slot(i: int, occupied: bool) -> void:
	if occupied:
		confirm(I18n.t("system.overwrite_title"), I18n.t("system.overwrite_body", {"n": i + 1}), _do_save.bind(i))
	else:
		_do_save(i)


func _do_save(i: int) -> void:
	if Game.save_manual(i):
		Game.say("system.saved_slot", {"n": i + 1}, "good")
	else:
		Game.say("err.save_write_failed", {}, "error")
	rebuild()


func _load_slot(i: int) -> void:
	confirm(I18n.t("system.load_title"), I18n.t("system.load_body"), _do_load.bind(SaveStore.manual_path(i)))


func _load_recovery(i: int) -> void:
	confirm(I18n.t("system.load_title"), I18n.t("system.load_recovery_body"), _do_load.bind(SaveStore.recovery_path(i)))


func _do_load(path: String) -> void:
	var r := SaveStore.read(path)
	if r.status != "ok":
		Game.say("system.slot_corrupt", {}, "error")
		rebuild()
		return
	if main != null and main.has_method("load_game"):
		main.load_game(r.record.state)
	else:
		Game.load_state(r.record.state)
	Game.say("system.loaded", {}, "good")


func _delete_slot(i: int) -> void:
	confirm(I18n.t("system.delete_title"), I18n.t("system.delete_body", {"n": i + 1}), _do_delete.bind(i))


func _do_delete(i: int) -> void:
	SaveStore.delete_manual(i)
	rebuild()


func _open_folder() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveStore.DIR))
	OS.shell_open(ProjectSettings.globalize_path(SaveStore.DIR))


# -------------------------------------------------------------- settings
func _settings(b: VBoxContainer) -> void:
	b.add_child(UIK.header(I18n.t("system.settings"), "ui_system"))
	var g := UIK.grid(2, 6)
	g.add_child(UIK.label(I18n.t("system.battle_speed"), "DimLabel"))
	var speeds := []
	for v in [1, 2, 4]:
		speeds.append([v, "×%d" % v])
	g.add_child(UIK.option(speeds, int(Settings.get_value("battleSpeed")), _set_setting.bind("battleSpeed")))
	g.add_child(UIK.label(I18n.t("system.ui_size"), "DimLabel"))
	var sizes := [[1.0, I18n.t("system.ui_size_normal")], [1.25, I18n.t("system.ui_size_large")], [1.5, I18n.t("system.ui_size_xlarge")]]
	var cur := float(Settings.get_value("textScale"))
	var cur_pick: float = 1.0
	for o in sizes:
		if absf(float(o[0]) - cur) < 0.01:
			cur_pick = o[0]
	g.add_child(UIK.option(sizes, cur_pick, _set_ui_size))
	g.add_child(UIK.label(I18n.t("system.fullscreen"), "DimLabel"))
	var fs := CheckButton.new()
	fs.focus_mode = Control.FOCUS_NONE
	fs.button_pressed = DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	fs.toggled.connect(_set_fullscreen)
	g.add_child(fs)
	for pair in [["reduceMotion", "system.reduce_motion"], ["pauseAtEncounterStart", "system.pause_start"], ["showRoofs", "ship.show_rigging"]]:
		if not I18n.has(pair[1]):
			continue
		g.add_child(UIK.label(I18n.t(pair[1]), "DimLabel"))
		var cb := CheckButton.new()
		cb.focus_mode = Control.FOCUS_NONE
		cb.button_pressed = bool(Settings.get_value(pair[0]))
		cb.toggled.connect(_set_setting.bind(pair[0]))
		g.add_child(cb)
	g.add_child(UIK.label(I18n.t("system.guide"), "DimLabel"))
	g.add_child(UIK.button(I18n.t("system.guide_restart"), _restart_guide, "ui_info", "", true, I18n.t("system.guide_restart_tip")))
	b.add_child(g)
	# audio
	b.add_child(UIK.header(I18n.t("system.audio"), "ui_sound"))
	var ag := UIK.grid(3, 6)
	for pair in [["masterVolume", "system.vol_master"], ["musicVolume", "system.vol_music"], ["ambienceVolume", "system.vol_ambience"], ["sfxVolume", "system.vol_sfx"]]:
		ag.add_child(UIK.label(I18n.t(pair[1]), "DimLabel"))
		var sl := HSlider.new()
		sl.min_value = 0
		sl.max_value = 100
		sl.step = 5
		sl.focus_mode = Control.FOCUS_NONE
		sl.custom_minimum_size = Vector2(150, 14)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sl.value = roundf(float(Settings.get_value(pair[0])) * 100.0)
		var pct := UIK.label(_pct(sl.value), "GoldLabel")
		pct.custom_minimum_size.x = 34
		sl.value_changed.connect(_on_volume.bind(pair[0], pct))
		sl.drag_ended.connect(_on_volume_done.bind(pair[0]))
		ag.add_child(sl)
		ag.add_child(pct)
	b.add_child(ag)
	b.add_child(UIK.para(I18n.t("system.audio_note"), "DimLabel", 410))
	# language
	b.add_child(UIK.header(I18n.t("system.language"), "ui_globe"))
	b.add_child(UIK.para(I18n.t("system.language_hint"), "DimLabel", 410))
	var langs := []
	for c in I18n.SUPPORTED:
		langs.append([c, I18n.language_name(c)])
	var why := ""
	if pending_locale == I18n.locale():
		why = I18n.t("system.language_current")
	elif _busy():
		why = I18n.t("err.in_encounter")
	b.add_child(UIK.hbox([UIK.option(langs, pending_locale, _pick_locale),
		UIK.button(I18n.t("system.restart_language"), _restart_language, "ui_globe", "PrimaryButton", why == "", why)], 4))
	b.add_child(UIK.header(I18n.t("system.shortcuts"), "ui_info"))
	b.add_child(UIK.para(I18n.t("system.shortcuts_list"), "DimLabel", 410))


func _restart_guide() -> void:
	Guide.restart()
	Game.say("system.guide_restarted", {}, "good")


func _set_setting(v: Variant, key: String) -> void:
	Settings.set_value(key, v)


func _pct(v: float) -> String:
	return I18n.t("system.vol_off") if v <= 0.0 else "%d%%" % int(v)


## Volume sliders apply live and persist when the drag ends (or on wheel and
## click changes, which end immediately), so dragging never spams the file.
func _on_volume(v: float, key: String, pct: Label) -> void:
	Settings.values[key] = v / 100.0
	Audio.apply_volumes()
	pct.text = _pct(v)
	_vol_dirty = key
	_save_volume.call_deferred()


func _on_volume_done(_changed: bool, key: String) -> void:
	Settings.set_value(key, float(Settings.values[key]))
	if key == "sfxVolume" or key == "masterVolume":
		Audio.play("place")
	_vol_dirty = ""


func _save_volume() -> void:
	# Wheel or click changes arrive without a drag; save them on the next idle
	# frame unless a drag is still under way.
	if _vol_dirty == "" or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	var key := _vol_dirty
	_vol_dirty = ""
	Settings.set_value(key, float(Settings.values[key]))


func _set_ui_size(v: Variant) -> void:
	Settings.set_value("textScale", float(v))
	rebuild.call_deferred()


func _set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


func _pick_locale(code: Variant) -> void:
	pending_locale = String(code)
	rebuild.call_deferred()


func _restart_language() -> void:
	var code := pending_locale
	confirm(I18n.t("system.restart_title"), I18n.t("system.restart_body", {"lang": I18n.language_name(code)}), _apply_locale.bind(code))


func _apply_locale(code: String) -> void:
	Settings.set_value("locale", code)
	I18n.set_locale(code)
	if main != null and main.has_method("restart_scene"):
		main.restart_scene.call_deferred()


# --------------------------------------------------------------- captain
func _captain(b: VBoxContainer) -> void:
	var s := st()
	var busy := _busy()
	var cs: Dictionary = s.captain.stats
	var g := UIK.grid(2, 4)
	var rows := [
		[I18n.t("system.profile"), String(s.envelope.profileId)],
		[I18n.t("system.seed"), str(s.envelope.seed)],
		[I18n.t("system.transactions"), I18n.fmt_num(s.envelope.lastTxId)],
		[I18n.t("system.battles"), I18n.t("system.battles_value", {"w": cs.battlesWon, "l": cs.battlesLost, "r": cs.retreats})],
		[I18n.t("system.voyages"), I18n.fmt_num(cs.voyages)],
		[I18n.t("system.postgame"), I18n.t("ui.yes") if s.captain.postgame else I18n.t("ui.no")],
	]
	for r in rows:
		g.add_child(UIK.label(r[0], "DimLabel"))
		g.add_child(UIK.label(r[1]))
	b.add_child(g)
	var row := UIK.hbox([], 4)
	row.add_child(UIK.button(I18n.t("system.title_screen"), _to_title, "ui_home", "", not busy, I18n.t("err.in_encounter") if busy else ""))
	row.add_child(UIK.button(I18n.t("system.new_game"), _new_game, "ui_plus", "", not busy, I18n.t("err.in_encounter") if busy else ""))
	row.add_child(UIK.button(I18n.t("system.quit"), _quit, "ui_close"))
	b.add_child(row)


func _to_title() -> void:
	if main != null and main.has_method("to_title"):
		main.to_title()


func _new_game() -> void:
	confirm(I18n.t("system.new_title"), I18n.t("system.new_body"), _do_new_game)


func _do_new_game() -> void:
	if main != null and main.has_method("start_new_game"):
		main.start_new_game()
	else:
		Game.new_game()


func _quit() -> void:
	get_tree().quit()
