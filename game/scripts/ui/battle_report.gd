## Post-battle report, docked on the right over a lightly veiled arena so
## the fight's aftermath stays readable behind it.
##
## Sections: rewards (gold, materials, plunder, crew XP, arrival), spoils
## (every planned item with its icon, rarity and quantity, plus storage
## notes), and a recruit section shown only when people were defeated:
## an offer with Sign on / Let go, a full-roster notice, or the chance that
## did not come up. A lost or abandoned battle shows its losses instead.
##
## The report is built from Actions.preview_encounter, so it shows exactly
## what the commit will grant. Nothing is stored until the player presses
## Collect: `resolved` carries the recruit decision, the owner commits it
## in one transaction and calls show_committed, which stamps the rows and
## closes the report shortly after (`closed`).
class_name BattleReport
extends Control

signal resolved(choice: Dictionary)
signal closed

const WIDTH := 236.0
const RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legendary"]

var sm: Dictionary = {}
var panel: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _foot: HBoxContainer
var _collect: Button
var _hint: Label
var _sign_btn: Button
var _go_btn: Button
var _recruit_note: Label
var _recruit_choice: Variant = null
var _needs_choice := false
var _stamps: Array = []
var _committed := false
var _close_t := -1.0
var _flash: ColorRect
var _insets := Vector2(24, 30)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.03, 0.06, 0.18)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var v := UIK.vbox([], 4)
	panel.add_child(v)
	_body = UIK.vbox([], 3)
	_scroll = UIK.scroll(_body, 40)
	v.add_child(_scroll)
	v.add_child(UIK.sep())
	_foot = UIK.hbox([], 4)
	_foot.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(_foot)
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.86, 0.4, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	resized.connect(_layout)
	panel.resized.connect(_place)


func _ready() -> void:
	Game.state_changed.connect(_on_state_changed)
	_layout()


## Builds the report for a preview summary. `insets` is the space the HUD
## keeps at the top and bottom, in this control's units (the panel starts
## under the top strip; see _layout for the bottom).
func setup(summary: Dictionary, insets: Vector2) -> BattleReport:
	sm = summary
	_insets = insets
	_build()
	_layout.call_deferred()
	return self


func panel_width() -> float:
	return WIDTH + 4.0


func _layout() -> void:
	var scr := _screen()
	var w := minf(WIDTH, scr.x - 8.0)
	# From under the HUD's top strip to the foot of the screen. The report is
	# modal and the battle controls are hidden while it is open, so it may
	# cover the bottom bar's right end; it must never run off the screen.
	var h := maxf(80.0, scr.y - (_insets.x + 3.0) - 4.0)
	# Rows and the footer wrap inside the planned width. Without this a long
	# button caption beside the footer note made the panel wider than WIDTH,
	# and it ran off the right edge of the screen.
	var inner := w - panel.get_theme_stylebox("panel").get_minimum_size().x
	UIK.fit_paragraphs(_body, inner - _scroll.get_v_scroll_bar().get_combined_minimum_size().x)
	UIK.fit_paragraphs(_foot, inner)
	# The scroll area expands to whatever the footer leaves.
	panel.custom_minimum_size = Vector2(w, h)
	panel.size = Vector2(w, h)
	_place()


## Docks the panel by its real size: content that still needs more than the
## planned width grows the panel to the left, never past the screen.
func _place() -> void:
	if not is_inside_tree():
		return
	var scr := _screen()
	panel.position = Vector2(maxf(2.0, scr.x - panel.size.x - 4.0),
		maxf(2.0, minf(_insets.x + 3.0, scr.y - panel.size.y - 2.0)))
	_flash.position = panel.position
	_flash.size = panel.size


func _screen() -> Vector2:
	return size if size.x > 0.0 else get_viewport_rect().size


# ================================================================== build
func _build() -> void:
	var outcome := String(sm.get("outcome", "victory"))
	var title_key := "battle.outcome_" + outcome
	if outcome == "defeat" and sm.get("reason") == "timeout":
		title_key = "battle.outcome_defeat_timeout"
	var icon := "ui_star" if outcome == "victory" else ("ui_retreat" if outcome == "retreat" else "ui_warn")
	var tl := UIK.label(I18n.t(title_key), "TitleLabel")
	tl.add_theme_color_override("font_color", Art.GOLD if outcome == "victory" else (Art.BAD if outcome == "defeat" else Art.INK))
	_body.add_child(UIK.hbox([UIK.icon(icon), tl], 4))
	_body.add_child(UIK.label(I18n.t("battle.report") + " · " + I18n.t("battle.result_time", {"n": I18n.fmt_num(sm.get("time", 0)), "hp": I18n.pct(float(sm.get("hpAvg", 0)))}), "DimLabel", true, int(WIDTH) - 16))
	_build_special_foes()
	match outcome:
		"victory":
			_build_rewards()
			_build_items()
			_build_recruit()
		"defeat":
			_build_defeat()
		_:
			_body.add_child(UIK.sep())
			_body.add_child(UIK.para(I18n.t("battle.retreat_result"), "", int(WIDTH) - 16))
			_left_behind()
	_hint = UIK.label("", "WarnLabel", true, 120)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_foot.add_child(_hint)
	var key := "settle.collect" if outcome == "victory" else "battle.continue"
	_collect = UIK.button(I18n.t(key) + " (Enter)", _on_collect, "ui_chest" if outcome == "victory" else "ui_check", "PrimaryButton")
	_foot.add_child(_collect)
	_refresh_foot()


func _section(text: String, icon_name: String, extra := "") -> void:
	_body.add_child(UIK.sep())
	var h := UIK.header(text, icon_name)
	if extra != "":
		var e := UIK.label(extra, "DimLabel")
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(e)
	_body.add_child(h)


## A stamped row: icon, text, an optional right-hand chip, and a check
## mark that appears when the rewards are committed.
func _row(icon_name: String, text: String, variation := "", right: Control = null, tint := Color.WHITE) -> HBoxContainer:
	var ic := UIK.icon(icon_name)
	var l := UIK.label(text, variation, true, 120)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tint != Color.WHITE:
		l.add_theme_color_override("font_color", tint)
	var h := UIK.hbox([ic, l], 3)
	if right != null:
		h.add_child(right)
	var st := UIK.icon("ui_check")
	st.modulate.a = 0.0
	h.add_child(st)
	_stamps.append(st)
	_body.add_child(h)
	return h


## One line per rare or variant foe defeated, so a special kill is visible
## without opening the Codex.
func _build_special_foes() -> void:
	var seen := {}
	for e in sm.get("enemies", []):
		var id := String(e.get("enemyId", ""))
		var tags := []
		if bool(e.get("rare", false)):
			tags.append(I18n.t("codex.rare_enemy"))
		var variant = e.get("variant")
		if variant != null:
			tags.append(I18n.t("variant.%s.name" % String(variant)))
		if tags.is_empty():
			continue
		var text := I18n.t("enemy.%s.name" % id) + " · " + " · ".join(tags)
		if seen.has(text):
			continue
		seen[text] = true
		_body.add_child(UIK.hbox([UIK.icon("ui_eye"), UIK.label(text, "WarnLabel", true, int(WIDTH) - 40)], 3))


func _build_rewards() -> void:
	var rw: Dictionary = sm.get("rewards") if sm.get("rewards") is Dictionary else {}
	_section(I18n.t("settle.rewards"), "gold")
	var plunder := int(sm.get("plunder", 0))
	if int(rw.get("gold", 0)) > 0:
		var txt := I18n.t("battle.r_gold", {"n": rw.gold})
		if plunder > 0:
			txt += "  " + I18n.t("settle.plunder", {"n": plunder})
		_row("gold", txt, "GoldLabel")
	if int(rw.get("materials", 0)) > 0:
		var salv := 0
		for r in sm.get("ledger", []):
			salv += int(r.get("salvaged", 0))
		_row("materials", I18n.t("battle.r_materials", {"n": int(rw.materials) + salv}))
	if int(sm.get("xp", 0)) > 0:
		_row("xp", I18n.t("settle.xp", {"n": sm.xp}))
	if (int(rw.get("gold", 0)) > 0 or int(rw.get("materials", 0)) > 0) and Game.has_game() and Game.state.voyage != null:
		_body.add_child(UIK.para(I18n.t("battle.r_ledger"), "DimLabel", int(WIDTH) - 16))
	if sm.get("arrived"):
		_body.add_child(UIK.hbox([UIK.icon("ui_sail"), UIK.label(I18n.t("battle.r_arrived", {"location": "loc.%s.name" % sm.arrived}), "GoodLabel", true, int(WIDTH) - 40)], 3))


func _build_items() -> void:
	var rows := []
	for r in sm.get("ledger", []):
		if String(r.kind) in ["gold", "materials"]:
			continue
		if String(r.kind) == "item" and int(r.got) == 0 and int(r.get("salvaged", 0)) == 0:
			continue
		rows.append(r)
	var tally := {}
	var pieces := 0
	for r in rows:
		if String(r.kind) == "collectible" and bool(r.get("duplicate", false)):
			continue
		pieces += int(r.qty)
		tally[r.rarity] = int(tally.get(r.rarity, 0)) + int(r.qty)
	_section(I18n.t("settle.items"), "ui_chest", I18n.t("settle.items_count", {"n": pieces}) if pieces > 0 else "")
	if rows.is_empty():
		_body.add_child(UIK.label(I18n.t("settle.no_items"), "DimLabel", true, int(WIDTH) - 16))
		return
	# Rarity tally, rarest first, as coloured chips.
	var chips := UIK.hbox([], 4)
	for i in range(RARITY_ORDER.size() - 1, -1, -1):
		var rr: String = RARITY_ORDER[i]
		if tally.has(rr):
			chips.add_child(_rarity_chip(rr, int(tally[rr])))
	_body.add_child(chips)
	rows.sort_custom(func(a, b): return RARITY_ORDER.find(a.rarity) > RARITY_ORDER.find(b.rarity))
	for r in rows:
		var right := UIK.hbox([], 3)
		var qty := UIK.label("×%d" % int(r.qty), "")
		qty.add_theme_color_override("font_color", BattleFx.rarity_color(String(r.rarity)))
		right.add_child(qty)
		if String(r.kind) == "collectible":
			if bool(r.get("new", false)):
				right.add_child(UIK.label(I18n.t("settle.new"), "GoodLabel"))
			elif bool(r.get("duplicate", false)):
				right.add_child(UIK.label(I18n.t("settle.duplicate_short"), "DimLabel"))
		_row(String(r.icon), _row_name(r), "", right, BattleFx.rarity_color(String(r.rarity)) if String(r.rarity) != "common" else Color.WHITE)
		if int(r.get("lost", 0)) > 0:
			_body.add_child(_note(I18n.t("settle.lost", {"n": r.lost})))
		if int(r.get("salvaged", 0)) > 0:
			_body.add_child(_note(I18n.t("settle.salvaged", {"n": r.salvaged})))
		if String(r.kind) == "collectible" and int(r.get("shards", 0)) > 0:
			_body.add_child(_note(I18n.t("settle.duplicate_shards", {"n": r.shards})))

func _note(text: String) -> Control:
	var l := UIK.label(text, "WarnLabel", true, int(WIDTH) - 36)
	var h := UIK.hbox([UIK.spacer(19, 0), l], 0)
	return h


func _rarity_chip(rarity: String, n := -1) -> Control:
	var c := BattleFx.rarity_color(rarity)
	var l := UIK.label(I18n.t("settle.rarity_" + rarity) + (" ×%d" % n if n >= 0 else ""), "")
	l.add_theme_color_override("font_color", c)
	var p := UIK.panel(l, "ChipPanel")
	p.self_modulate = Color(c.r, c.g, c.b, 1.0).lerp(Color.WHITE, 0.5)
	return p


func _row_name(r: Dictionary) -> String:
	match String(r.kind):
		"food":
			return I18n.t("settle.food")
		"supplies":
			return I18n.t("settle.supplies")
		"specialty":
			return I18n.t("spec.%s.name" % r.ref)
		"ingredient":
			return I18n.t("ing.%s.name" % r.ref)
		"egg":
			return I18n.t("battle.r_egg", {"family": "petfam.%s.name" % r.ref.familyId, "n": int(r.ref.grade)})
		"item":
			return I18n.item_name(String(r.ref))
		"collectible":
			return I18n.t(Collections.name_key(String(r.ref)))
		"clue":
			return I18n.t("settle.clue")
	return String(r.id)


func _build_recruit() -> void:
	var rc: Dictionary = sm.get("recruit") if sm.get("recruit") is Dictionary else {}
	if rc.is_empty():
		return
	var chance := I18n.pct(float(rc.get("chance", 0)))
	_section(I18n.t("settle.recruit"), "ui_recruit", I18n.t("settle.recruit_chance", {"p": chance}))
	if not rc.get("offered", false):
		_body.add_child(UIK.label(I18n.t("settle.recruit_none"), "DimLabel", true, int(WIDTH) - 16))
		return
	var m: Dictionary = rc.member
	var look: Dictionary = m.duplicate()
	look.id = "recruit"
	var enemy := I18n.t("enemy.%s.name" % rc.enemyId)
	_body.add_child(UIK.para(I18n.t("settle.recruit_offer", {"enemy": enemy}), "", int(WIDTH) - 16))
	var info := UIK.vbox([
		UIK.label(I18n.crew_name(m), "GoldLabel"),
		UIK.label(I18n.t("class.%s.name" % m.classId) + " · " + I18n.t("ui.lv", {"n": m.level}), ""),
		UIK.label(I18n.t("crew.origin") + ": " + I18n.t("origin." + String(m.originId)), "DimLabel", true, int(WIDTH) - 64),
		UIK.label(I18n.t("crew.traits") + ": " + ", ".join(m.traits.map(func(x): return I18n.t("trait." + x))), "DimLabel", true, int(WIDTH) - 64),
	], 0)
	var card := UIK.hbox([UIK.portrait("crew", look, Vector2(28, 36)), info], 5)
	_body.add_child(UIK.panel(card, "FlatPanel"))
	var crew_n := int(rc.get("crew", 0))
	var cap := int(rc.get("capacity", 0))
	var berths := UIK.label(I18n.t("settle.berths", {"n": crew_n, "max": cap}), "WarnLabel" if rc.get("full", false) else "DimLabel")
	_body.add_child(UIK.hbox([UIK.icon("ui_recruit"), berths], 3))
	_go_btn = UIK.button(I18n.t("settle.let_go"), _choose_recruit.bind(false), "ui_close", "", true)
	_go_btn.toggle_mode = true
	_go_btn.set_meta("sfx", "ui_back")
	_sign_btn = UIK.button(I18n.t("settle.sign_on"), _choose_recruit.bind(true), "ui_recruit", "", not rc.get("full", false),
		I18n.t("settle.recruit_full_short") if rc.get("full", false) else "")
	_sign_btn.toggle_mode = true
	var row := UIK.hbox([_go_btn, _sign_btn], 4)
	row.alignment = BoxContainer.ALIGNMENT_END
	_body.add_child(row)
	_recruit_note = UIK.label("", "WarnLabel", true, int(WIDTH) - 16)
	_body.add_child(_recruit_note)
	if rc.get("full", false):
		_recruit_note.text = I18n.t("settle.recruit_full", {"n": crew_n, "max": cap})
		_recruit_choice = false
		_go_btn.set_pressed_no_signal(true)
	else:
		_recruit_note.visible = false
		_needs_choice = true


func _choose_recruit(accept: bool) -> void:
	if _committed:
		return
	_recruit_choice = accept
	_needs_choice = false
	_sign_btn.set_pressed_no_signal(accept)
	_go_btn.set_pressed_no_signal(not accept)
	_refresh_foot()


func _build_defeat() -> void:
	var ls: Dictionary = sm.get("losses") if sm.get("losses") is Dictionary else {}
	_section(I18n.t("settle.losses"), "ui_warn")
	var back := String(sm.get("returnedTo", Game.state.world.lastSafePortId if Game.has_game() else ""))
	_body.add_child(UIK.para(I18n.t("battle.defeat_result", {"gold": ls.get("gold", 0), "materials": ls.get("materials", 0),
		"location": "loc.%s.name" % back}), "", int(WIDTH) - 16))
	var inj: Array = sm.get("injured", [])
	if inj.size() and Game.has_game():
		var names := []
		for id in inj:
			names.append(I18n.crew_name(Rules.member(Game.state, id)))
		_body.add_child(UIK.hbox([UIK.icon("ui_heal"), UIK.label(I18n.t("battle.defeat_injured", {"list": ", ".join(names)}), "WarnLabel", true, int(WIDTH) - 40)], 3))
	if ls.get("damagedFacility") != null:
		_body.add_child(UIK.hbox([UIK.icon("ui_warn"), UIK.label(I18n.t("battle.defeat_facility", {"facility": "fac.%s.name" % ls.damagedFacility}), "WarnLabel", true, int(WIDTH) - 40)], 3))
	_left_behind()
	_body.add_child(UIK.para(I18n.t("battle.defeat_keep"), "DimLabel", int(WIDTH) - 16))


func _left_behind() -> void:
	var n := 0
	for r in sm.get("spoils", []):
		n += 1
	if n > 0:
		_body.add_child(UIK.hbox([UIK.icon("ui_chest", Color(1, 1, 1, 0.5)), UIK.label(I18n.t("settle.left_behind", {"n": n}), "DimLabel", true, int(WIDTH) - 40)], 3))


func _refresh_foot() -> void:
	if _collect == null:
		return
	_collect.disabled = _needs_choice or _committed
	_hint.text = I18n.t("settle.decide") if _needs_choice else ""


# ================================================================ actions
func _on_collect() -> void:
	if _needs_choice or _committed:
		return
	_collect.disabled = true
	resolved.emit({"recruit": _recruit_choice == true})


## The commit went through: stamp every row, show what was stored and
## close shortly after (or on the next click / key).
func show_committed(final: Dictionary) -> void:
	_committed = true
	if _go_btn:
		_go_btn.disabled = true
		_sign_btn.disabled = true
	var rc = final.get("recruit")
	if rc is Dictionary and rc.get("offered", false) and _recruit_note != null:
		_recruit_note.visible = true
		var who := I18n.crew_name(rc.member) if rc.get("member") is Dictionary else ""
		if rc.get("accepted", false):
			_recruit_note.text = I18n.t("settle.signed", {"name": who})
			_recruit_note.theme_type_variation = "GoodLabel"
		else:
			_recruit_note.text = I18n.t("settle.let_gone", {"name": who})
			_recruit_note.theme_type_variation = "DimLabel"
	UIK.clear(_foot)
	var outcome := String(final.get("outcome", "victory"))
	var done := UIK.label(I18n.t("settle.stowed") if outcome == "victory" else I18n.t("settle.saved"), "GoodLabel", true, 150)
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_foot.add_child(UIK.icon("ui_check"))
	_foot.add_child(done)
	_foot.add_child(UIK.button(I18n.t("battle.continue"), _close, "", "PrimaryButton"))
	_layout()
	var tw := create_tween()
	for i in _stamps.size():
		var st: TextureRect = _stamps[i]
		st.pivot_offset = Vector2(8, 8)
		st.scale = Vector2(1.8, 1.8)
		tw.tween_property(st, "modulate:a", 1.0, 0.05)
		tw.parallel().tween_property(st, "scale", Vector2.ONE, 0.09)
	if outcome == "victory":
		_flash.color.a = 0.0
		var tf := create_tween()
		tf.tween_property(_flash, "color:a", 0.22, 0.08)
		tf.tween_property(_flash, "color:a", 0.0, 0.45)
		Audio.play("coins")
	_close_t = 1.6 + 0.07 * _stamps.size()


func _close() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	closed.emit()
	queue_free()


func _process(delta: float) -> void:
	if _close_t > 0.0:
		_close_t -= delta
		if _close_t <= 0.0:
			_close()


func _gui_input(ev: InputEvent) -> void:
	if _committed and ev is InputEventMouseButton and ev.pressed:
		_close()
		accept_event()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	var k := ev as InputEventKey
	if k.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		if _committed:
			_close()
		elif not _collect.disabled:
			_on_collect()
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("cancel"):
		if _committed:
			_close()
		get_viewport().set_input_as_handled()


func _on_state_changed(kind: String) -> void:
	if kind == "loaded" or kind == "new_game":
		queue_free()


## The commit was refused: say why and let the player try again.
func fail(text: String) -> void:
	_committed = false
	_hint.text = text
	_hint.theme_type_variation = "BadLabel"
	_collect.disabled = false
