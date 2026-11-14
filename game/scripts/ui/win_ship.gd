## Ship window (docked right so the ship stays visible): the build
## palette, layout check and stowed facilities, hulls and presets, and
## repairs/production. Placement itself happens in the world view.
extends GameWindow

var cat := ""


func window_title() -> String:
	return I18n.t("nav.ship")


func window_icon() -> String:
	return "ui_build"


func window_size() -> Vector2:
	return Vector2(232, 306)


func dock() -> String:
	return "right"


func tabs() -> Array:
	return [["build", I18n.t("ship.build"), "ui_build"], ["layout", I18n.t("ship.layout"), "ui_check"],
		["hulls", I18n.t("ship.hulls"), "hull"], ["services", I18n.t("ship.services"), "ui_repair"]]


func _sv() -> ShipView:
	return main.ship_view if main else null


func build(b: VBoxContainer) -> void:
	match tab:
		"build":
			_build_tab(b)
		"layout":
			_layout_tab(b)
		"hulls":
			_hulls_tab(b)
		"services":
			_services_tab(b)


func _edit_note(b: VBoxContainer) -> bool:
	var ok := _sv() != null and _sv().can_edit()
	b.add_child(UIK.stat("ui_check" if ok else "ui_lock", I18n.t("ship.edit_ok") if ok else I18n.t("ship.edit_port_only"), "GoodLabel" if ok else "WarnLabel"))
	return ok


# ----------------------------------------------------------------- build
func _build_tab(b: VBoxContainer) -> void:
	var s := st()
	var can := _edit_note(b)
	var modes := UIK.hbox([], 2)
	var multi: bool = s.ship.decks.size() > 1
	var has_bulk := false
	for d in s.ship.decks:
		if d.bulkhead != null:
			has_bulk = true
	if multi:
		modes.add_child(UIK.button(I18n.t("ship.mode_stair"), func(): _sv().begin_stair(), "ui_deck_up", "", can, I18n.t("ship.stair_hint")))
	if has_bulk:
		modes.add_child(UIK.button(I18n.t("ship.mode_door"), func(): _sv().begin_door(), "ui_move", "", can, I18n.t("ship.door_hint")))
	if modes.get_child_count():
		b.add_child(modes)
	b.add_child(UIK.para(I18n.t("ship.build_zone_note"), "DimLabel", 200))
	var cats: Array = C.data.FACILITY_CATEGORIES
	if cat == "":
		cat = cats[0]
	var cat_row := UIK.flow(1)
	for c in cats:
		var cb := UIK.icon_button("cat_" + c, I18n.t("faccat." + c), _pick_cat.bind(c), "TabButton")
		cb.toggle_mode = true
		cb.button_pressed = c == cat
		cat_row.add_child(cb)
	b.add_child(cat_row)
	b.add_child(UIK.label(I18n.t("faccat." + cat), "GoldLabel"))
	for fid in C.FACILITIES:
		var def: Dictionary = C.FACILITIES[fid]
		if def.category != cat:
			continue
		b.add_child(_palette_card(fid, def, can))


func _pick_cat(c: String) -> void:
	cat = c
	rebuild()


func _palette_card(fid: String, def: Dictionary, can: bool) -> Control:
	var s := st()
	var count := 0
	for f in s.ship.facilities:
		if f.id == fid:
			count += 1
	var limit := int(Actions.BUILD_LIMIT.get(fid, 1))
	var reason := ""
	if int(s.ship.hullTier) < int(def.minTier):
		reason = I18n.t("err.hull_tier", {"tier": def.minTier})
	elif count >= limit:
		reason = I18n.t("err.build_limit")
	elif not Fmt.can_afford(s, def.cost):
		reason = I18n.t("ship.cannot_afford")
	var row := UIK.hbox([], 4)
	var pic := TextureRect.new()
	pic.texture = Art.facility_card(fid)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(34, 32)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	var txt := UIK.vbox([], 0)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := UIK.hbox([UIK.label(Fmt.fac(fid), "GoldLabel" if def.get("required", false) else "")], 3)
	if def.get("required", false):
		name_row.add_child(UIK.label(I18n.t("ship.required"), "WarnLabel"))
	txt.add_child(name_row)
	txt.add_child(UIK.label("%d×%d · %s" % [int(def.w), int(def.h), I18n.t("ship.owned", {"n": count, "max": limit})], "DimLabel"))
	txt.add_child(UIK.label(UIK.cost_text(def.cost), "DimLabel" if reason == "" else "BadLabel", true, 136))
	var where := []
	for d in Rules.eligible_decks(s.ship, fid):
		where.append(I18n.t("deck.%s.title" % s.ship.decks[int(d)].id))
	var zone_txt := I18n.t("ship.zone_" + Rules.zone_of(fid))
	if not where.is_empty():
		zone_txt += ": " + ", ".join(where)
	var zl := UIK.label(zone_txt, "DimLabel" if not where.is_empty() else "WarnLabel", true, 136)
	txt.add_child(zl)
	row.add_child(txt)
	var btn := UIK.icon_button("ui_plus", I18n.t("ship.place") + (" — " + reason if reason != "" else ""), func(): _sv().begin_build(fid), "PrimaryButton", can and reason == "")
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(btn)
	var card := UIK.panel(row, "FlatPanel")
	card.tooltip_text = I18n.t("fac.%s.desc" % fid)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	return card


# ---------------------------------------------------------------- layout
func _layout_tab(b: VBoxContainer) -> void:
	var s := st()
	var lay := Game.layout()
	var g := UIK.grid(2, 4)
	var rows := [
		["ship.capacity", I18n.t("home.crew_cap_value", {"n": s.crew.size(), "max": lay.capacity}), lay.overCapacity],
		["ship.food_cap", str(Rules.food_capacity(s, lay)), false],
		["ship.supply_cap", str(Rules.supply_capacity(s, lay)), false],
		["ship.equip_cap", str(Rules.equip_capacity(s, lay)), false],
		["ship.stamina_max", str(Rules.stamina_max(s, lay)), false],
		["home.damage", "%d%%" % int(s.ship.damage), int(s.ship.damage) >= 40],
	]
	for r in rows:
		g.add_child(UIK.label(I18n.t(r[0]), "DimLabel"))
		g.add_child(UIK.label(r[1], "BadLabel" if r[2] else ""))
	b.add_child(g)
	b.add_child(UIK.sep())
	var warn := false
	for id in lay.missingRequired:
		b.add_child(UIK.stat("ui_warn", I18n.t("home.missing_required", {"facility": "fac.%s.name" % id}), "BadLabel"))
		warn = true
	if lay.overCapacity:
		b.add_child(UIK.para(I18n.t("home.over_capacity"), "BadLabel", 200))
		warn = true
	for uid in lay.disabled:
		var f = Actions.find_fac(s, uid)
		if f == null or f.stowed:
			continue
		var info: Dictionary = lay.facilities[uid]
		var row := UIK.hbox([UIK.icon("ui_lock"), UIK.label(Fmt.fac(f.id), "WarnLabel")], 3)
		row.add_child(UIK.spacer())
		row.add_child(UIK.icon_button("ui_eye", I18n.t(info.reasonKey, info.get("reasonParams", {})), func(): _sv().select_facility(uid), "FlatButton"))
		b.add_child(row)
		warn = true
	for f in s.ship.facilities:
		if f.damaged:
			b.add_child(UIK.stat("ui_warn", I18n.t("home.facility_damaged", {"facility": "fac.%s.name" % f.id}), "WarnLabel"))
			warn = true
	if not warn:
		b.add_child(UIK.stat("ui_check", I18n.t("home.ship_ready"), "GoodLabel"))
	# stowed
	var stowed: Array = s.ship.facilities.filter(func(f): return f.stowed)
	if stowed.size():
		b.add_child(UIK.sep())
		b.add_child(UIK.header(I18n.t("ship.stowed"), "ui_chest"))
		var can := _sv() != null and _sv().can_edit()
		for f in stowed:
			var row := UIK.hbox([UIK.label(Fmt.fac(f.id) + " · " + I18n.t("ui.lv", {"n": f.level}))], 3)
			row.add_child(UIK.spacer())
			row.add_child(UIK.button(I18n.t("ship.place"), func(): _sv().begin_move(f.uid), "ui_move", "", can))
			b.add_child(row)
	b.add_child(UIK.sep())
	var legend := UIK.flow(6)
	for k in [["iso_ok", "ship.legend_walk"], ["iso_bad", "ship.legend_disabled"], ["iso_move", "ship.legend_stair"], ["iso_sel", "ship.legend_entry"]]:
		legend.add_child(UIK.hbox([UIK.tex(Art.ui_tex(k[0]), Vector2(20, 10)), UIK.label(I18n.t(k[1]), "DimLabel")], 2))
	b.add_child(legend)


# ----------------------------------------------------------------- hulls
func _hulls_tab(b: VBoxContainer) -> void:
	var s := st()
	for h in C.HULLS:
		var cur: bool = h.id == s.ship.hullId
		var av := Rules.hull_available(s, h)
		var head := UIK.hbox([UIK.icon("hull"), UIK.label(I18n.t("hull.%s.name" % h.id), "GoldLabel" if cur else ""),
			UIK.label(I18n.t("ship.tier", {"n": h.tier}), "DimLabel")], 3)
		var open_l := []
		var inner_l := []
		for d in h.decks:
			if String(d.get("kind", "open")) == "interior":
				inner_l.append(I18n.t("deck.%s.title" % d.id))
			else:
				open_l.append(I18n.t("deck.%s.title" % d.id))
		var box := UIK.vbox([head, UIK.para(I18n.t("hull.%s.desc" % h.id), "DimLabel", 196),
			UIK.label(I18n.t("ship.decks", {"n": h.decks.size()}), "DimLabel"),
			UIK.para(I18n.t("ship.hull_levels", {"open": ", ".join(open_l), "inner": ", ".join(inner_l)}), "DimLabel", 196)], 2)
		if cur:
			box.add_child(UIK.label(I18n.t("ship.current_hull"), "GoodLabel"))
		elif int(h.tier) < int(s.ship.hullTier):
			box.add_child(UIK.label(I18n.t("ship.hull_owned"), "DimLabel"))
		else:
			box.add_child(UIK.para(UIK.cost_text(h.cost), "DimLabel", 196))
			var ok: bool = av.ok and Fmt.can_afford(s, h.cost)
			var tip := I18n.reason(av) if not av.ok else ("" if ok else I18n.t("ship.cannot_afford"))
			box.add_child(UIK.primary(I18n.t("ship.upgrade_hull"), _upgrade_hull.bind(h.id), "ui_up", ok, tip))
			if tip != "":
				box.add_child(UIK.para(tip, "WarnLabel", 196))
		b.add_child(UIK.panel(box, "FlatPanel"))
	b.add_child(UIK.header(I18n.t("ship.presets"), "ui_save"))
	b.add_child(UIK.para(I18n.t("ship.presets_hint"), "DimLabel", 200))
	var can := _sv() != null and _sv().can_edit()
	for i in s.ship.presets.size():
		var p = s.ship.presets[i]
		var row := UIK.hbox([UIK.label(I18n.t("ship.preset_n", {"n": i + 1})),
			UIK.label(I18n.t("ship.preset_info", {"n": p.facilities.size()}) if p != null else I18n.t("ship.preset_empty"), "DimLabel")], 3)
		row.add_child(UIK.spacer())
		row.add_child(UIK.icon_button("ui_save", I18n.t("ship.preset_save"), func(): act(Actions.save_preset(Game.state, i)), "FlatButton", can))
		row.add_child(UIK.icon_button("ui_load", I18n.t("ship.preset_apply"), func(): act(Actions.apply_preset(Game.state, i)), "FlatButton", can and p != null))
		row.add_child(UIK.icon_button("ui_trash", I18n.t("ui.delete"), func(): act(Actions.delete_preset(Game.state, i)), "FlatButton", p != null))
		b.add_child(row)


func _upgrade_hull(hid: String) -> void:
	confirm(I18n.t("ship.hull_confirm", {"hull": "hull.%s.name" % hid}), I18n.t("ship.hull_confirm_body"),
		func(): act(Actions.upgrade_hull(Game.state, hid)))


# -------------------------------------------------------------- services
func _services_tab(b: VBoxContainer) -> void:
	var s := st()
	var rc := Rules.repair_cost(s)
	b.add_child(UIK.header(I18n.t("ship.repair"), "ui_repair"))
	b.add_child(UIK.label(I18n.t("home.damage") + ": %d%%" % int(s.ship.damage), "BadLabel" if int(s.ship.damage) >= 40 else ""))
	if int(s.ship.damage) >= 40:
		b.add_child(UIK.para(I18n.t("ship.damage_penalty"), "WarnLabel", 200))
	var cost := {"gold": rc.gold, "materials": rc.materials} if Rules.at_port(s) else {"supplies": 1}
	b.add_child(UIK.hbox([UIK.button(I18n.t("ship.repair"), func(): act(Actions.repair_ship(Game.state)), "ui_repair", "", rc.needed and Fmt.can_afford(s, cost),
		"" if rc.needed else I18n.t("err.nothing_to_repair")), UIK.label(UIK.cost_text(cost) if Rules.at_port(s) else "1 " + I18n.t("status.supplies"), "DimLabel")], 4))
	b.add_child(UIK.sep())
	b.add_child(UIK.para(I18n.t("ship.production_hint"), "DimLabel", 200))
	var gl := Rules.fac_level(s, "galley")
	var n := U.jround(float(2 + gl) * Rules.staff_mult(s, "galley")) if gl else 0
	b.add_child(UIK.hbox([UIK.button(I18n.t("ship.produce_food", {"n": n}), func(): act(Actions.produce_food(Game.state)), "ui_cook", "", gl > 0,
		"" if gl else I18n.t("err.need_facility", {"facility": "fac.galley.name"})), UIK.label("3 " + I18n.t("status.materials"), "DimLabel")], 4))
	var wl := Rules.fac_level(s, "workshop")
	b.add_child(UIK.hbox([UIK.button(I18n.t("ship.produce_supplies"), func(): act(Actions.produce_supplies(Game.state)), "supplies", "", wl > 0,
		"" if wl else I18n.t("err.need_facility", {"facility": "fac.workshop.name"})), UIK.label("4 " + I18n.t("status.materials"), "DimLabel")], 4))
	b.add_child(UIK.sep())
	b.add_child(UIK.header(I18n.t("home.stamina"), "stamina"))
	var T: Dictionary = C.TUNING
	b.add_child(UIK.button(I18n.t("home.serve_ration", {"n": int(T.rationStamina) + 3 * Rules.fac_level(s, "mess_hall")}), func(): act(Actions.serve_ration(Game.state)), "food"))
	b.add_child(UIK.button(I18n.t("home.use_supply", {"n": T.supplyStamina}), func(): act(Actions.use_supply(Game.state)), "supplies"))
