## Main scene. Hosts the title screen and the running game in one place:
## a world layer (the persistent ship stage, plus the exploration and battle
## stages created on demand), the compact HUD, the game windows and modal
## dialogs. It routes HUD navigation, hotkeys and stage selections to the
## right window, plays the sailing transition and follows Game.where() to
## show the matching stage.
extends Node

const WINDOWS := {
	"ship": preload("res://scripts/ui/win_ship.gd"),
	"inspect": preload("res://scripts/ui/win_inspect.gd"),
	"crew": preload("res://scripts/ui/win_crew.gd"),
	"pets": preload("res://scripts/ui/win_pets.gd"),
	"port": preload("res://scripts/ui/win_port.gd"),
	"chart": preload("res://scripts/ui/win_chart.gd"),
	"codex": preload("res://scripts/ui/win_codex.gd"),
	"log": preload("res://scripts/ui/win_log.gd"),
	"system": preload("res://scripts/ui/win_system.gd"),
}
## Town buildings on the quay open these windows/tabs.
const BUILDING_TARGETS := {
	"market": ["port", "market"], "tavern": ["port", "tavern"], "workshop": ["port", "workshop"],
	"quest_board": ["port", "board"], "house": ["port", "invest"], "navigation": ["chart", ""],
}
const HOTKEYS := {
	"open_build": "ship", "open_crew": "crew", "open_chart": "chart", "open_pets": "pets",
	"open_port": "port", "open_codex": "codex", "open_log": "log",
}

var mode := "title"
var world_mode := ""
var world: Node2D
var ship_view: ShipView
var site_view: SiteView
var battle_view: BattleView
var ui_layer: CanvasLayer
var ui_root: Control
var hud: Hud
var win_layer: Control
## First-session guide card, above the windows (see guide.gd).
var guide: Guide
var modal_layer: CanvasLayer
var modal_root: Control
var title_root: Control
## Title screen parts for the explicit layout (panel, scroll, body, grid,
## wrapped labels, footer, tagline).
var _title := {}
var _title_layout_queued := false
var windows := {}

var _lock := 0
var _ship_key := ""
var _sea_dialog: Dialog
var _report_open := false
var _report: BattleReport
var _level_t := 0.0
## HUD insets in base-viewport pixels: [top strip, objective chip, bottom].
var _hud_insets := Vector3(24, 40, 30)
## The sky over the stage (presentation only, see Weather).
var weather: WeatherLayer
var _sky_key := ""
var _sky_stage := ""
## Sweeps the old stage away when the stage changes (see Curtain).
var curtain: Curtain


func _ready() -> void:
	if Settings.has_locale():
		I18n.set_locale(String(Settings.get_value("locale")))
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	ship_view = ShipView.new()
	ship_view.name = "ShipView"
	world.add_child(ship_view)
	ship_view.selected.connect(_on_stage_selected)
	ship_view.hover_changed.connect(_on_hover)
	ship_view.mode_changed.connect(_on_mode_changed)
	weather = WeatherLayer.new()
	weather.name = "Weather"
	add_child(weather)
	curtain = Curtain.new()
	curtain.name = "Curtain"
	add_child(curtain)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = Art.theme
	ui_layer.add_child(ui_root)
	hud = Hud.new()
	ui_root.add_child(hud)
	hud.nav.connect(_on_nav)
	hud.context_action.connect(_on_context_action)
	hud.view_action.connect(_on_view_action)
	hud.insets_changed.connect(_on_hud_insets)
	win_layer = Control.new()
	win_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(win_layer)
	guide = Guide.new()
	guide.main = self
	ui_root.add_child(guide)
	modal_layer = CanvasLayer.new()
	modal_layer.layer = 10
	add_child(modal_layer)
	modal_root = Control.new()
	modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_root.theme = Art.theme
	modal_layer.add_child(modal_root)
	Game.state_changed.connect(_on_state_changed)
	Settings.changed.connect(_apply_ui_scale)
	Settings.changed.connect(_update_weather)
	get_viewport().size_changed.connect(_apply_ui_scale)
	_apply_ui_scale()
	if Game.has_game():
		enter_game()
	else:
		show_title()


# ================================================================== title
func show_title() -> void:
	curtain.cover(true)
	mode = "title"
	world_mode = ""
	_close_all_windows()
	_free_stage_views()
	hud.visible = false
	GameWindow.hud_insets = false
	var preview: Dictionary
	var newest = SaveStore.newest()
	if newest != null:
		preview = newest.record.state
	else:
		preview = GS.create_new_game(20260101)
	ship_view.visible = true
	ship_view.process_mode = Node.PROCESS_MODE_INHERIT
	ship_view.cancel_mode()
	ship_view.bind(preview, "title", false)
	ship_view.cam.make_current()
	ship_view.set_process_unhandled_input(false)
	_ship_key = ""
	_build_title(newest)
	Audio.scene("title")
	_update_weather()


func _build_title(newest: Variant) -> void:
	if title_root:
		title_root.queue_free()
	_title = {}
	title_root = Control.new()
	title_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(title_root)
	ui_root.move_child(title_root, 0)
	# Main panel: header, primary actions, then the secondary actions in a
	# grid that switches to two columns when one column does not fit. The
	# body scrolls only if even that is too tall (explicit layout below).
	var panel := UIK.panel(null, "")
	title_root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v := UIK.vbox([], 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	# Emblem (dropped by the layout when the screen is short), title, motto.
	var emblem := TextureRect.new()
	emblem.texture = Art.title_tex("wheel")
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	emblem.custom_minimum_size = Vector2(47, 47)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(emblem)
	var title_lbl := UIK.label(I18n.t("app.title"), "TitleLabel")
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Art.GOLD)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title_lbl)
	var sub := UIK.label(I18n.t("title.strongest"), "DimLabel", true, 120)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(UIK.sep())
	var wrapped: Array = [sub]
	if newest != null:
		var sm: Dictionary = newest.record.summary
		var cont := UIK.primary(I18n.t("title.continue"), _continue_newest.bind(newest.record.state), "ui_play")
		v.add_child(cont)
		var meta := UIK.label(_meta_line(sm), "DimLabel", true, 120)
		v.add_child(meta)
		wrapped.append(meta)
	v.add_child(UIK.button(I18n.t("title.new_game"), _title_new_game, "ui_plus", "PrimaryButton" if newest == null else ""))
	var grid := UIK.grid(1, 4)
	grid.add_theme_constant_override("v_separation", 4)
	for b in [UIK.button(I18n.t("title.load"), _title_load, "ui_load"),
			UIK.button(I18n.t("title.settings"), func(): open_window("system", "settings"), "ui_system"),
			UIK.button(I18n.t("title.language", {"lang": I18n.language_name(I18n.locale())}), func(): open_window("system", "settings"), "ui_globe", "FlatButton"),
			UIK.button(I18n.t("title.quit"), func(): get_tree().quit(), "ui_close", "FlatButton")]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		grid.add_child(b)
	v.add_child(grid)
	# Build revision (version · checkpoint) so a playtest can confirm which
	# exported checkpoint is running.
	var rev := "v%s · %s" % [String(ProjectSettings.get_setting("application/config/version", "")),
		String(ProjectSettings.get_setting("application/config/build_revision", "dev"))]
	var foot := UIK.label(I18n.t("title.footer") + "  ·  " + rev, "DimLabel")
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_root.add_child(foot)
	var tag := UIK.label(I18n.t("app.tagline"), "", true, 120)
	var tp := UIK.panel(tag, "TipPanel")
	tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.add_child(tp)
	_title = {"panel": panel, "scroll": scroll, "body": v, "grid": grid, "wrapped": wrapped,
		"foot": foot, "tag": tag, "tag_panel": tp, "emblem": emblem}
	v.minimum_size_changed.connect(_queue_title_layout)
	_queue_title_layout()


## Title screen safe-area layout, in UI units (the UI layer is scaled by the
## UI size setting, so 1280x720 at 1.5 leaves about 426x240 units). Re-run on
## window resize, UI size change and whenever the panel content re-measures.
func _queue_title_layout() -> void:
	if _title_layout_queued:
		return
	_title_layout_queued = true
	_layout_title.call_deferred()


func _layout_title() -> void:
	_title_layout_queued = false
	if title_root == null or not is_instance_valid(title_root) or _title.is_empty():
		return
	var scr: Vector2 = ui_root.size
	if scr.x <= 0.0 or scr.y <= 0.0:
		return
	var m := 6.0 if scr.y < 300.0 else 10.0
	# Footer: bottom right, one line when it fits, otherwise wrapped to the
	# screen width. It always keeps its own band, so nothing overlaps it.
	var foot: Label = _title.foot
	var font := foot.get_theme_font("font")
	var fs := foot.get_theme_font_size("font_size")
	var max_w := scr.x - 2.0 * m
	var one := font.get_string_size(foot.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 2.0
	var fw := minf(ceilf(one), max_w)
	foot.autowrap_mode = TextServer.AUTOWRAP_OFF if one <= max_w else TextServer.AUTOWRAP_WORD_SMART
	var fh := ceilf(font.get_multiline_string_size(foot.text, HORIZONTAL_ALIGNMENT_RIGHT, fw, fs).y)
	foot.custom_minimum_size = Vector2(fw, 0)
	foot.position = Vector2(scr.x - m - fw, scr.y - 3.0 - fh)
	foot.size = Vector2(fw, fh)
	# Main panel on the left, centred in the band above the footer.
	var panel: PanelContainer = _title.panel
	var scroll: ScrollContainer = _title.scroll
	var body: VBoxContainer = _title.body
	var grid: GridContainer = _title.grid
	var pad := Vector2.ZERO
	var sb := panel.get_theme_stylebox("panel")
	if sb != null:
		pad = sb.get_minimum_size()
	var band_top := m
	var band_h := maxf(60.0, foot.position.y - 4.0 - band_top)
	# The emblem is shown only where the menu still fits in one column.
	var emblem: TextureRect = _title.emblem
	var want_emblem := band_h >= 300.0
	if emblem.visible != want_emblem:
		emblem.visible = want_emblem
		_queue_title_layout()
		return
	var left := 24.0 if scr.x >= 560.0 else m
	var avail_w := scr.x - left - m
	# A short band (large UI size) also tightens the spacing.
	var gap := 2 if band_h < 232.0 else 4
	if body.get_theme_constant("separation") != gap:
		body.add_theme_constant_override("separation", gap)
		grid.add_theme_constant_override("v_separation", gap)
		grid.add_theme_constant_override("h_separation", gap)
		_queue_title_layout()
		return
	# Height with one column of secondary actions; two columns save two rows.
	var btn_h := 0.0
	var btn_w := 0.0
	for b in grid.get_children():
		var bm := (b as Control).get_combined_minimum_size()
		btn_h = maxf(btn_h, bm.y)
		btn_w = maxf(btn_w, (b as Button).get_theme_font("font").get_string_size((b as Button).text, HORIZONTAL_ALIGNMENT_LEFT, -1, (b as Button).get_theme_font_size("font_size")).x + 34.0)
	var rows_saved := ceili(grid.get_child_count() / 2.0)
	var h_now := body.get_combined_minimum_size().y
	var h_one := h_now + (float(rows_saved) * (btn_h + float(gap)) if grid.columns == 2 else 0.0)
	var two_w := 2.0 * btn_w + float(gap)
	var want_two := h_one + pad.y > band_h and two_w + pad.x <= avail_w
	var cols := 2 if want_two else 1
	var cw := clampf(two_w if want_two else 196.0, 150.0, maxf(150.0, avail_w - pad.x))
	if not want_two:
		cw = minf(196.0, maxf(150.0, avail_w - pad.x))
	for l in _title.wrapped:
		(l as Label).custom_minimum_size.x = cw - 6.0
	if grid.columns != cols:
		grid.columns = cols
		_queue_title_layout()  # re-measure with the new column count
		return
	var content_h := body.get_combined_minimum_size().y
	var ph := minf(content_h + pad.y, band_h)
	var needs_scroll := content_h + pad.y > band_h + 0.5
	var sbw := scroll.get_v_scroll_bar().get_combined_minimum_size().x if needs_scroll else 0.0
	var pw := cw + pad.x + sbw
	panel.position = Vector2(left, roundf(band_top + (band_h - ph) * 0.5))
	panel.size = Vector2(pw, ph)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if needs_scroll else ScrollContainer.SCROLL_MODE_DISABLED
	# Tagline: top right, only when it has room beside the panel.
	var tp: PanelContainer = _title.tag_panel
	var tag: Label = _title.tag
	var tpad := Vector2.ZERO
	var tsb := tp.get_theme_stylebox("panel")
	if tsb != null:
		tpad = tsb.get_minimum_size()
	var room := scr.x - (left + pw) - 2.0 * m
	tp.visible = room >= 140.0
	if tp.visible:
		var tw := minf(260.0, room)
		tag.custom_minimum_size.x = tw - tpad.x
		var th := ceilf(tag.get_theme_font("font").get_multiline_string_size(tag.text, HORIZONTAL_ALIGNMENT_LEFT, tw - tpad.x, tag.get_theme_font_size("font_size")).y) + tpad.y
		tp.position = Vector2(scr.x - m - tw, m)
		tp.size = Vector2(tw, th)
		tp.visible = th <= band_h
	# Frame the ship in the part of the screen the menu leaves free.
	var sc := ui_layer.scale.x
	var vp := get_viewport().get_visible_rect().size
	var free_x := (left + pw + m) * sc
	if vp.x - free_x >= 200.0 and ship_view != null and not ship_view.st.is_empty():
		ship_view.free_screen = Rect2(free_x, 0.0, vp.x - free_x, vp.y)
		ship_view.fit_view()


func _meta_line(sm: Dictionary) -> String:
	return " · ".join([I18n.t(String(sm.get("titleKey", "title.unknown_captain"))), I18n.t("loc.%s.name" % sm.get("locationId", "")),
		I18n.t("ui.day", {"n": int(sm.get("day", 0)) + 1}), I18n.t("system.crew_n", {"n": int(sm.get("crew", 0))}),
		I18n.t("system.trials_n", {"n": int(sm.get("trials", 0))})])


func _continue_newest(state: Dictionary) -> void:
	load_game(state)


func _title_new_game() -> void:
	if SaveStore.newest() != null:
		confirm(I18n.t("system.new_title"), I18n.t("system.new_body"), start_new_game)
	else:
		start_new_game()


func _title_load() -> void:
	var d := Dialog.new().setup(I18n.t("title.load"), "ui_load", 340)
	var any := false
	d.add(UIK.header(I18n.t("system.manual"), "ui_save"))
	for sl in SaveStore.list_manual():
		if sl.status == "ok":
			any = true
			d.add(UIK.hbox([UIK.label(I18n.t("system.slot_n", {"n": int(sl.index) + 1}), "GoldLabel"),
				UIK.label(_meta_line(sl.record.summary), "", true, 220),
				UIK.button(I18n.t("title.continue"), _load_from_dialog.bind(sl.record.state, d), "ui_load", "FlatButton")], 4))
		elif sl.status == "corrupt":
			d.add(UIK.label(I18n.t("system.slot_corrupt"), "BadLabel"))
	if not any:
		d.text(I18n.t("title.no_slots"), "DimLabel")
	var rec := SaveStore.list_recovery()
	if rec.size():
		d.add(UIK.header(I18n.t("title.recovery"), "ui_repair"))
		for r in rec:
			d.add(UIK.hbox([UIK.label(_meta_line(r.record.summary), "", true, 250),
				UIK.button(I18n.t("title.continue"), _load_from_dialog.bind(r.record.state, d), "ui_load", "FlatButton")], 4))
	d.button(I18n.t("ui.close"), "close")
	show_dialog(d)


func _load_from_dialog(state: Dictionary, d: Dialog) -> void:
	if is_instance_valid(d):
		d.queue_free()
	load_game(state)


# ============================================================ game entry
func start_new_game() -> void:
	_close_all_windows()
	Game.new_game()
	enter_game()


func load_game(state: Dictionary) -> void:
	_close_all_windows()
	Game.load_state(state)
	enter_game()


func to_title() -> void:
	Game.close_game()
	show_title()


func restart_scene() -> void:
	get_tree().reload_current_scene()


func enter_game() -> void:
	curtain.cover()
	mode = "game"
	if title_root:
		title_root.queue_free()
		title_root = null
	hud.forget_resources()
	hud.visible = true
	GameWindow.hud_insets = true
	ship_view.set_process_unhandled_input(true)
	_ship_key = ""
	_free_stage_views()
	_lock = 0
	world_mode = ""
	_sync_world()


# ================================================================ world
func _sync_world() -> void:
	if mode != "game" or not Game.has_game():
		return
	if _lock > 0:
		return
	var w := Game.where()
	match w:
		"battle":
			if battle_view == null:
				_show_battle()
		"site":
			if site_view == null:
				_show_site_stage()
			else:
				site_view.refresh()
		_:
			_show_ship_stage("port" if w == "port" else "sea")
	if w != world_mode and w != "battle":
		var lt = C.location(String(Game.state.world.currentLocationId))
		Audio.scene(w, String(lt.type) if lt != null else "")
	world_mode = w
	hud.refresh(w)
	_update_weather()
	_update_view_info()
	if w == "at_sea" and Game.state.voyage != null and Game.state.voyage.event != null:
		_open_sea_event()


func _show_ship_stage(ctx: String) -> void:
	var key := "%s|%s" % [ctx, String(Game.state.world.currentLocationId)]
	if site_view != null or battle_view != null:
		curtain.cover(true)
	elif key != _ship_key and _ship_key != "":
		curtain.cover()
	if site_view:
		site_view.queue_free()
		site_view = null
	if battle_view:
		battle_view.queue_free()
		battle_view = null
	ship_view.visible = true
	ship_view.process_mode = Node.PROCESS_MODE_INHERIT
	if key != _ship_key:
		_ship_key = key
		ship_view.bind(Game.state, ctx, true)
	else:
		ship_view.st = Game.state
		ship_view.refresh()
	ship_view.cam.make_current()


func _hide_ship_stage() -> void:
	ship_view.cancel_mode()
	ship_view.visible = false
	ship_view.process_mode = Node.PROCESS_MODE_DISABLED
	hud.set_hint("")
	hud.set_tip("")


func _show_site_stage() -> void:
	curtain.cover()
	_close_window("ship")
	_close_window("inspect")
	_hide_ship_stage()
	if battle_view:
		battle_view.queue_free()
		battle_view = null
	site_view = SiteView.new()
	site_view.main = self
	world.add_child(site_view)
	site_view.hover_changed.connect(_on_hover)
	site_view.bind(Game.state)
	site_view.set_hud_insets(_hud_insets.x, _hud_insets.y, _hud_insets.z)
	site_view.cam.make_current()
	_ship_key = ""


## Opens the exploration stage for the current site (called by the chart).
func show_site() -> void:
	_close_center_windows()
	_sync_world()


func _show_battle() -> void:
	curtain.cover()
	_close_all_windows()
	_hide_ship_stage()
	if site_view:
		site_view.queue_free()
		site_view = null
	battle_view = BattleView.new()
	world.add_child(battle_view)
	battle_view.hover_changed.connect(_on_hover)
	battle_view.finished.connect(_on_battle_finished)
	battle_view.start(Game.state)
	battle_view.set_hud_insets(_hud_insets.x, _hud_insets.y, _hud_insets.z)
	battle_view.cam.make_current()
	_ship_key = ""


func _free_stage_views() -> void:
	_close_report()
	if site_view:
		site_view.queue_free()
		site_view = null
	if battle_view:
		battle_view.queue_free()
		battle_view = null


func _on_state_changed(kind: String) -> void:
	if mode != "game":
		return
	if kind == "loaded" or kind == "new_game":
		_ship_key = ""
		hud.forget_resources()
	else:
		Audio.tx(kind)
	hud.refresh(world_mode if _lock > 0 and world_mode != "" else Game.where())
	for n in windows:
		windows[n].mark_dirty()
	_sync_world()


## Matches the sky to the stage now showing: the region's weather for this
## watch, none underground. A new stage gets its sky at once; on the same
## stage a change of weather eases in.
func _update_weather() -> void:
	if weather == null:
		return
	if mode != "game" or not Game.has_game():
		_sky_key = ""
		_sky_stage = ""
		weather.set_sky("clear", "", false, false, true)
		return
	var s := Game.state
	var hour := int(s.envelope.gameClock) % 24
	var night := hour >= 20 or hour < 6
	var stage := "ship"
	var under := false
	if battle_view != null:
		stage = "battle"
		under = battle_view.arena in ["dungeon", "secret"]
	elif site_view != null:
		stage = "site"
		var lt = C.location(String(s.world.currentLocationId))
		under = lt != null and String(lt.type) in ["dungeon", "secret"]
	else:
		under = ship_view != null and ship_view.view_level > 0
	var sky := Weather.now(s)
	var rid := Weather.region_here(s)
	var key := "%s|%s|%s|%s|%s" % [sky, rid, under, night, Settings.get_value("weather")]
	# Crossing a roof must remove particles immediately, including when the
	# stage stays "ship" and only the selected deck changes.
	var snap := stage != _sky_stage or under != weather.under
	if key == _sky_key and not snap:
		return
	_sky_key = key
	_sky_stage = stage
	weather.set_sky(sky, rid, under, night, snap)


# ================================================================ voyage
func depart(to_id: String, fast := false, confirmed := false) -> void:
	if not Game.has_game():
		return
	var res := Actions.depart(Game.state, to_id, {"fast": fast, "confirmed": confirmed})
	if not res.get("ok", false):
		if String(res.get("reasonKey", "")) == "warn.confirm_unreachable":
			confirm(I18n.t("hud.sail"), I18n.reason(res), depart.bind(to_id, fast, true))
			return
		Game.act(res)
		return
	_close_center_windows()
	_close_window("inspect")
	_close_window("ship")
	_lock += 1
	curtain.cover(true)
	Game.act(res)
	_free_stage_views()
	ship_view.visible = true
	ship_view.process_mode = Node.PROCESS_MODE_INHERIT
	_ship_key = "sea|%s" % String(Game.state.world.currentLocationId)
	ship_view.bind(Game.state, "sea", true)
	ship_view.cam.make_current()
	world_mode = "at_sea"
	Audio.scene("at_sea")
	Audio.play("bell")
	Audio.play("cloth")
	hud.sailing_to = to_id
	_update_weather()
	hud.refresh("at_sea")
	hud.set_hint(I18n.t("hud.sailing_to", {"location": "loc.%s.name" % to_id}))
	ship_view.sailing_done.connect(_on_sailing_done, CONNECT_ONE_SHOT)
	ship_view.start_sailing(1.2 if bool(Settings.get_value("reduceMotion")) else 2.6)


func _on_sailing_done() -> void:
	hud.sailing_to = ""
	hud.set_hint("")
	Audio.play("bell")
	_lock = maxi(0, _lock - 1)
	_sync_world()


func _open_sea_event() -> void:
	if _sea_dialog != null and is_instance_valid(_sea_dialog):
		return
	var s := Game.state
	var ev: Dictionary = s.voyage.event
	var k := String(ev.kind)
	var reg: Dictionary = C.region(String(ev.regionId))
	var n := 10 + 5 * int(reg.tier)
	var d := Dialog.new().setup(I18n.t("sea.%s.title" % k), "ui_sail", 300)
	d.text(I18n.t("sea.event"), "DimLabel")
	d.text(I18n.t("sea.%s.desc" % k, {"region": "region.%s.name" % ev.regionId}))
	d.text(I18n.t("sea.%s.effect" % k, {"n": n}), "DimLabel")
	match k:
		"vessel":
			d.button(I18n.t("sea.vessel.ignore"), "ignore")
			d.button(I18n.t("sea.vessel.help") + "  " + UIK.cost_text({"food": 2}), "help", true, Fmt.can_afford(s, {"food": 2}))
		"inspection":
			d.button(I18n.t("sea.inspection.refuse"), "refuse")
			d.button(I18n.t("sea.inspection.pay") + "  " + UIK.cost_text({"gold": n}), "pay", true, Fmt.can_afford(s, {"gold": n}))
		_:
			d.button(I18n.t("sea.continue"), "continue", true)
	d.done.connect(_on_sea_choice)
	_sea_dialog = d
	show_dialog(d)


func _on_sea_choice(choice: Variant) -> void:
	_sea_dialog = null
	Game.act(Actions.resolve_sea_event(Game.state, String(choice)))


# ================================================================ battle
## The battle view ended the fight (Actions.end_encounter: outcome and
## spoils plan stored, nothing granted) or reopened one whose report was
## still pending. Adopt the ended state, then open the report.
func _on_battle_finished(res: Dictionary) -> void:
	_lock += 1
	if not res.get("ok", false):
		_battle_error(res)
		return
	if not res.get("restored", false):
		Game.act(res)
	_open_report()


func _battle_error(res: Dictionary) -> void:
	var e := Dialog.new().setup(I18n.t("battle.report"), "ui_warn", 280)
	e.text(I18n.t("battle.result_error"), "BadLabel")
	e.text(I18n.reason(res), "DimLabel")
	e.button(I18n.t("battle.continue"), "ok", true)
	e.done.connect(_after_report)
	_report_open = true
	show_dialog(e)


## Shows the post-battle report for the ended encounter. It is built from
## a dry run of the settlement, so it lists exactly what Collect stores.
func _open_report() -> void:
	var pv := Actions.preview_encounter(Game.state)
	if not pv.get("ok", false):
		_battle_error(pv)
		return
	_close_report()
	var sc := modal_layer.scale.x if modal_layer != null else 1.0
	_report = BattleReport.new()
	modal_root.add_child(_report)
	_report.setup(pv.value, Vector2(_hud_insets.x / sc, _hud_insets.z / sc))
	_report.resolved.connect(_on_report_resolved)
	_report.closed.connect(_after_report.bind(null))
	_report_open = true
	if battle_view:
		battle_view.set_report_mode(true, _report.panel_width() * sc)


## Collect: settle the encounter (rewards, losses and the recruit decision)
## in one transaction with an autosave, then let the report confirm it.
func _on_report_resolved(choice: Dictionary) -> void:
	if _report == null or not is_instance_valid(_report):
		return
	var enc = Game.state.encounter
	if enc == null:
		_report.show_committed({})
		return
	var res := Actions.resolve_encounter(Game.state, String(enc.attemptId), [], choice)
	if not Game.act(res):
		_report.fail(I18n.reason(res))
		return
	_report.show_committed(res.value)


func _close_report() -> void:
	if _report != null and is_instance_valid(_report):
		_report.queue_free()
	_report = null
	_report_open = false


func _after_report(_choice: Variant) -> void:
	curtain.cover(true)
	_report = null
	_report_open = false
	_lock = maxi(0, _lock - 1)
	if battle_view:
		battle_view.queue_free()
		battle_view = null
	_ship_key = ""
	_sync_world()


# ================================================================ windows
func open_window(wname: String, tab := "", sel: Variant = null) -> GameWindow:
	if not WINDOWS.has(wname):
		return null
	if mode == "title" and wname != "system":
		return null
	if mode == "game" and world_mode == "battle" and wname != "system":
		return null
	var w: GameWindow = windows.get(wname)
	if w == null:
		w = WINDOWS[wname].new()
		w.main = self
		if w.needs_game() and not Game.has_game():
			w.free()
			return null
		if w.dock() == "center":
			_close_center_windows()
		windows[wname] = w
		win_layer.add_child(w)
		Audio.play("ui_open")
		w.closed.connect(_close_window.bind(wname))
		w.laid_out.connect(_sync_right_block)
	if tab != "":
		w.tab = tab
	if sel != null and w.has_method("select"):
		w.select(sel)
	win_layer.move_child(w, -1)
	w.rebuild()
	return w


func _close_window(wname: String) -> void:
	var w: GameWindow = windows.get(wname)
	if w == null:
		return
	windows.erase(wname)
	w.queue_free()
	Audio.play("ui_close")
	_sync_right_block.call_deferred()
	if wname == "ship" and ship_view and ship_view.mode != "view":
		ship_view.cancel_mode()
	elif wname == "inspect" and ship_view:
		ship_view.clear_selection()


func close_window(wname: String) -> void:
	_close_window(wname)


func toggle_window(wname: String, tab := "") -> void:
	if windows.has(wname):
		_close_window(wname)
	else:
		open_window(wname, tab)


func _close_center_windows() -> void:
	for n in windows.keys():
		if windows.has(n) and windows[n].dock() == "center":
			_close_window(n)


func _close_all_windows() -> void:
	for n in windows.keys():
		_close_window(n)


func _topmost_window() -> String:
	var best := ""
	var best_i := -1
	for n in windows:
		var i: int = windows[n].get_index()
		if i > best_i:
			best_i = i
			best = n
	return best


func show_dialog(d: Dialog) -> void:
	modal_root.add_child(d)


func confirm(title: String, body: String, cb: Callable) -> void:
	var d := Dialog.new().setup(title, "ui_warn", 280)
	d.text(body)
	d.button(I18n.t("ui.cancel"), "cancel")
	d.button(I18n.t("ui.ok"), "ok", true)
	d.done.connect(_on_confirm.bind(cb))
	show_dialog(d)


func _on_confirm(choice: Variant, cb: Callable) -> void:
	if choice == "ok" and cb.is_valid():
		cb.call()


func _modal_open() -> bool:
	if _report != null and is_instance_valid(_report) and not _report.is_queued_for_deletion():
		return true
	for c in modal_root.get_children():
		if c is Dialog and not c.is_queued_for_deletion():
			return true
	return false


# ============================================================= HUD hooks
func _on_nav(wname: String) -> void:
	toggle_window(wname)


func _on_context_action(wname: String) -> void:
	match wname:
		"sail":
			open_window("chart")
		"return":
			confirm(I18n.t("home.emergency_return"), I18n.t("home.emergency_hint"), _do_emergency_return)
		"leave_site":
			leave_site()
		"land":
			land()


func _do_emergency_return() -> void:
	_close_center_windows()
	Game.act(Actions.emergency_return(Game.state))


## Returns the landing party to the ship. The site view walks them back to
## the rowboat first; without a site stage the action commits directly.
func leave_site() -> void:
	if not Game.has_game():
		return
	_close_center_windows()
	if site_view != null and is_instance_valid(site_view):
		site_view.return_to_ship()
		return
	Game.act(Actions.leave_site(Game.state))


## Goes ashore again at the island the ship is anchored beside.
func land() -> void:
	if not Game.has_game():
		return
	_close_center_windows()
	Game.act(Actions.land(Game.state))


func _on_view_action(wname: String) -> void:
	match wname:
		"deck":
			if ship_view.visible:
				ship_view.cycle_deck()
		"level_up":
			if ship_view.visible:
				ship_view.level_step(-1)
		"level_down":
			if ship_view.visible:
				ship_view.level_step(1)
		"zoom_in":
			_stage_zoom(1)
		"zoom_out":
			_stage_zoom(-1)
		"sails":
			if ship_view.visible:
				ship_view.toggle_sails()
		"fit":
			_stage_fit()
		_:
			if wname.begins_with("level:") and ship_view.visible:
				ship_view.set_view_level(int(wname.substr(6)))
	_update_view_info()


## Fits the current stage (ship level, island or arena) into the screen
## area the HUD leaves free.
func _stage_fit() -> void:
	if battle_view:
		battle_view.fit_view()
	elif site_view:
		site_view.fit_view()
	else:
		_fit_ship_view()


func _fit_ship_view() -> void:
	if ship_view == null or not ship_view.visible:
		return
	ship_view.free_screen = _free_screen()
	ship_view.fit_view()
	_update_view_info()


## Screen rectangle (viewport pixels) not covered by the HUD bars, the
## level selector or a right-docked window.
func _free_screen() -> Rect2:
	var vp := get_viewport().get_visible_rect().size
	if hud == null or ui_layer == null:
		return Rect2(Vector2.ZERO, vp)
	var sc := ui_layer.scale.x
	var top := hud.chips_bottom + 2.0
	var bottom := minf(hud.size.y - hud.bottom_reserved, hud.right_cluster_top - 2.0)
	var right := hud.size.x
	if hud.level_panel.visible:
		right = minf(right, hud.level_panel.position.x - 2.0)
	if not is_inf(hud.right_block_x):
		right = minf(right, hud.right_block_x - 2.0)
	var r := Rect2(Vector2(0.0, top) * sc, Vector2(maxf(64.0, right), maxf(64.0, bottom - top)) * sc)
	return r.intersection(Rect2(Vector2.ZERO, vp))


func _stage_zoom(dir: int) -> void:
	if battle_view:
		battle_view.zoom_step(dir, false)
	elif site_view:
		site_view.zoom_step(dir, false)
	else:
		ship_view.zoom_step(dir, false)


func _update_view_info() -> void:
	if hud == null:
		return
	var zl := ship_view.zoom_label()
	if site_view:
		zl = site_view.zoom_label()
	elif battle_view:
		zl = battle_view.zoom_label()
	var ship_shown := site_view == null and battle_view == null
	var up_name := ""
	var down_name := ""
	if ship_shown and not ship_view.st.is_empty():
		var k := ship_view.view_level
		if k > 0:
			up_name = ship_view.level_title(k - 1)
		if k + 1 < ship_view.level_count():
			down_name = ship_view.level_title(k + 1)
	hud.set_view_info(I18n.t("view.deck", {"deck": ship_view.focus_name()}) if ship_shown else "", zl,
		bool(Settings.get_value("showRoofs")), ship_shown, up_name, down_name)
	var levels := []
	if ship_shown and not ship_view.st.is_empty():
		for k in ship_view.level_count():
			levels.append({"title": ship_view.level_title(k), "crew": ship_view.crew_on_level(k),
				"hint": I18n.t("ship.level_open_hint" if k == 0 else "ship.level_interior_hint")})
	hud.set_levels(levels, ship_view.view_level, ship_shown and mode == "game")


## UI size setting: scales the HUD, windows and dialogs (not the world).
## 1.5 keeps whole screen pixels at the default 2x window scale.
func _apply_ui_scale() -> void:
	var sc := clampf(float(Settings.get_value("textScale")), 1.0, 1.5)
	var vp := get_viewport().get_visible_rect().size
	for pair in [[ui_layer, ui_root], [modal_layer, modal_root]]:
		var layer: CanvasLayer = pair[0]
		var root: Control = pair[1]
		if layer == null or root == null:
			continue
		layer.scale = Vector2(sc, sc)
		root.set_anchors_preset(Control.PRESET_TOP_LEFT)
		root.position = Vector2.ZERO
		root.size = (vp / sc).floor()
	if title_root != null and is_instance_valid(title_root):
		_queue_title_layout()
	if win_layer != null:
		for w in win_layer.get_children():
			if w.visible and w.has_method("_layout"):
				w._layout()


func _process(delta: float) -> void:
	_level_t += delta
	if _level_t >= 1.0:
		_level_t = 0.0
		if mode == "game" and hud != null and ship_view != null and ship_view.visible:
			_update_view_info()


func _on_hover(text: String) -> void:
	hud.set_tip(text)


func _on_mode_changed(_m: String, text: String) -> void:
	hud.set_hint(text)
	_update_view_info()
	_update_weather()


func _on_stage_selected(kind: String, payload: Variant) -> void:
	if mode != "game":
		return
	match kind:
		"none":
			if windows.has("inspect"):
				var w: GameWindow = windows["inspect"]
				windows.erase("inspect")
				w.queue_free()
		"building":
			var tgt: Array = BUILDING_TARGETS.get(String(payload), ["port", ""])
			if tgt[0] == "port" and not Rules.at_port(Game.state):
				return
			open_window(tgt[0], tgt[1])
		_:
			var w2 := open_window("inspect")
			if w2 and w2.has_method("show_selection"):
				w2.show_selection(kind, payload)


# ================================================================= input
## Ship level keys are read before the GUI: Godot uses Tab for focus
## navigation, so a focused control would otherwise swallow it and the
## level would not change. Text fields keep their keys.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		var c := Diag.counts()
		if not c.is_empty():
			print("diag summary: ", JSON.stringify(c))


func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	if mode != "game" or _modal_open():
		return
	var fo := get_viewport().gui_get_focus_owner()
	if fo is LineEdit or fo is TextEdit or fo is SpinBox:
		return
	var k := ev as InputEventKey
	if k.keycode == KEY_HOME:
		_stage_fit()
		get_viewport().set_input_as_handled()
		return
	if world_mode == "battle" or site_view != null or not ship_view.visible:
		return
	var step := 0
	if ev.is_action_pressed("deck_next"):
		step = -1 if k.shift_pressed else 1
		if step > 0 and ship_view.view_level + 1 >= ship_view.level_count():
			ship_view.set_view_level(0)
			step = 0
		elif step < 0 and ship_view.view_level == 0:
			ship_view.set_view_level(ship_view.level_count() - 1)
			step = 0
	elif k.keycode == KEY_PAGEDOWN:
		step = 1
	elif k.keycode == KEY_PAGEUP:
		step = -1
	else:
		return
	if step != 0:
		ship_view.level_step(step)
	if fo != null:
		fo.release_focus()
	get_viewport().set_input_as_handled()
	_update_view_info()


## Forwards the HUD's reserved space (scaled to base pixels) to the
## stage overlays that are not part of the scaled UI layer.
func _on_hud_insets(top_bar: float, chips: float, bottom: float) -> void:
	var sc := ui_layer.scale.x if ui_layer != null else 1.0
	_hud_insets = Vector3(top_bar * sc, chips * sc, bottom * sc)
	for v in [battle_view, site_view]:
		if v != null and is_instance_valid(v) and v.has_method("set_hud_insets"):
			v.set_hud_insets(_hud_insets.x, _hud_insets.y, _hud_insets.z)
	for wn in windows:
		var w: GameWindow = windows[wn]
		if is_instance_valid(w) and w.visible:
			w._queue_layout()


## Keeps the HUD level selector left of any window docked on the right.
func _sync_right_block() -> void:
	if hud == null:
		return
	var x := INF
	for wn in windows:
		var w: GameWindow = windows[wn]
		if is_instance_valid(w) and not w.is_queued_for_deletion() and w.visible and w.dock() == "right":
			x = minf(x, w.position.x)
	hud.set_right_block(x)


func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("fullscreen"):
		var fs := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
		return
	if _modal_open():
		return
	if ev.is_action_pressed("cancel"):
		var top := _topmost_window()
		if top != "":
			_close_window(top)
		elif mode == "game":
			open_window("system")
		get_viewport().set_input_as_handled()
		return
	if mode != "game" or world_mode == "battle":
		return
	for action in HOTKEYS:
		if ev.is_action_pressed(action):
			var wname: String = HOTKEYS[action]
			if wname == "port" and not Rules.at_port(Game.state):
				return
			toggle_window(wname)
			get_viewport().set_input_as_handled()
			return
