## Selection inspector docked on the left: facility, sailor, stair or
## bulkhead picked in the ship view, with the contextual actions.
extends GameWindow

var kind := ""
var payload: Variant = null


func window_title() -> String:
	match kind:
		"facility":
			var f = Actions.find_fac(st(), payload)
			return Fmt.fac(f.id) if f else I18n.t("ship.selection")
		"crew":
			var m = Rules.member(st(), payload)
			if m:
				return I18n.crew_name(m)
			for p in st().pets:
				if p.id == payload:
					return I18n.pet_name(p)
		"stair":
			return I18n.t("ship.stair")
		"bulkhead":
			return I18n.t("ship.bulkhead")
	return I18n.t("ship.selection")


func window_icon() -> String:
	match kind:
		"facility":
			var f = Actions.find_fac(st(), payload)
			return "cat_" + C.FACILITIES[f.id].category if f else "ui_info"
		"crew":
			return "ui_crew"
		"stair":
			return "ui_deck_up"
	return "ui_info"


func window_size() -> Vector2:
	return Vector2(196, 236)


func dock() -> String:
	return "left"


func show_selection(k: String, p: Variant) -> void:
	kind = k
	payload = p
	rebuild()


func build(b: VBoxContainer) -> void:
	match kind:
		"facility":
			_facility(b)
		"crew":
			_crew(b)
		"stair":
			_stair(b)
		"bulkhead":
			_bulkhead(b)


func _can_edit() -> bool:
	return main != null and main.ship_view != null and main.ship_view.can_edit()


func _facility(b: VBoxContainer) -> void:
	var s := st()
	var f = Actions.find_fac(s, payload)
	if f == null:
		close()
		return
	var def: Dictionary = C.FACILITIES[f.id]
	var lay := Game.layout()
	var info: Dictionary = lay.facilities.get(f.uid, {"reachable": false})
	var pic := TextureRect.new()
	pic.texture = Art.facility_card(f.id)
	pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	pic.custom_minimum_size = Vector2(64, 50)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := UIK.vbox([UIK.label(I18n.t("ui.lv", {"n": f.level}) + " · " + I18n.t("faccat." + def.category), "DimLabel")], 1)
	var status := "ship.status_active"
	var tone := "GoodLabel"
	if f.stowed:
		status = "ship.status_stowed"
		tone = "DimLabel"
	elif not info.reachable:
		status = "ship.status_disabled"
		tone = "BadLabel"
	elif f.damaged:
		status = "ship.status_damaged"
		tone = "WarnLabel"
	head.add_child(UIK.label(I18n.t(status), tone))
	if not f.stowed and int(f.deck) >= 0 and int(f.deck) < s.ship.decks.size():
		head.add_child(UIK.label(I18n.t("ship.on_level", {"deck": "deck.%s.title" % s.ship.decks[int(f.deck)].id}), "DimLabel"))
	b.add_child(UIK.hbox([pic, head], 4))
	b.add_child(UIK.para(I18n.t("fac.%s.desc" % f.id), "DimLabel", 176))
	if not info.reachable and not f.stowed:
		b.add_child(UIK.para(I18n.t(info.reasonKey, info.get("reasonParams", {})) + " " + I18n.t("ship.disabled_effect"), "WarnLabel", 176))
	elif f.damaged:
		b.add_child(UIK.para(I18n.t("ship.damaged_effect"), "WarnLabel", 176))
	# workers
	var slots := Rules.job_slots(f)
	if slots > 0:
		var workers: Array = s.crew.filter(func(m): return m.jobFacilityUid == f.uid)
		b.add_child(UIK.header(I18n.t("ship.jobs", {"n": workers.size(), "max": slots}), "ui_crew"))
		for m in workers:
			var row := UIK.hbox([UIK.label(I18n.crew_name(m)), UIK.label(I18n.t("ship.efficiency", {"pct": I18n.pct(Rules.worker_efficiency(s, m, f.id))}), "DimLabel")], 3)
			row.add_child(UIK.spacer())
			row.add_child(UIK.icon_button("ui_close", I18n.t("ship.unassign"), func(): act(Actions.assign_job(Game.state, m.id, null)), "FlatButton", s.encounter == null))
			b.add_child(row)
		if workers.size() < slots and info.reachable and not f.stowed:
			var items := [[null, I18n.t("ship.assign_worker")]]
			for m in s.crew:
				if m.jobFacilityUid == f.uid:
					continue
				var cur := ""
				if m.jobFacilityUid != null:
					var jf = Actions.find_fac(s, m.jobFacilityUid)
					if jf:
						cur = " (" + Fmt.fac(jf.id) + ")"
				items.append([m.id, "%s · %s%s" % [I18n.crew_name(m), I18n.pct(Rules.worker_efficiency(s, m, f.id)), cur]])
			b.add_child(UIK.option(items, null, func(id):
				if id != null:
					act(Actions.assign_job(Game.state, id, f.uid))))
		var sm := Rules.staff_mult(s, f.id)
		if sm > 1.0:
			b.add_child(UIK.label(I18n.t("ship.staff_bonus", {"pct": I18n.pct(sm - 1.0)}), "GoodLabel"))
	var helpers := []
	for p in s.pets:
		if p.assignment != null and p.assignment.kind == "helper" and p.assignment.target == f.uid:
			helpers.append(I18n.pet_name(p))
	if helpers.size():
		b.add_child(UIK.label(I18n.t("ship.pet_helpers", {"names": ", ".join(helpers)}), "DimLabel"))


func build_footer(ft: HBoxContainer) -> void:
	if kind == "facility":
		var s := st()
		var f = Actions.find_fac(s, payload)
		if f == null:
			return
		var can := _can_edit()
		if int(f.level) < 3:
			var uc := Rules.upgrade_cost(f)
			ft.add_child(UIK.icon_button("ui_up", I18n.t("ship.upgrade") + " → " + I18n.t("ui.lv", {"n": int(f.level) + 1}) + " · " + UIK.cost_text(uc),
				func(): act(Actions.upgrade_facility(Game.state, f.uid)), "PrimaryButton", can and Fmt.can_afford(s, uc)))
		ft.add_child(UIK.icon_button("ui_move", I18n.t("ship.move") + " — " + I18n.t("ship.move_hint", {"facility": "fac.%s.name" % f.id}),
			func(): main.ship_view.begin_move(f.uid), "", can))
		if not f.stowed:
			ft.add_child(UIK.icon_button("ui_chest", I18n.t("ship.stow") + " — " + I18n.t("ship.stow_hint"), func(): act(Actions.stow_facility(Game.state, f.uid)), "", can))
		if f.id != "captains_cabin":
			var ref := Rules.demolish_refund(f)
			ft.add_child(UIK.icon_button("ui_demolish", I18n.t("ship.demolish"), _demolish.bind(f.uid, f.id, ref), "", can))
	elif kind == "crew":
		var m = Rules.member(st(), payload)
		if m:
			ft.add_child(UIK.button(I18n.t("home.open_crew"), func(): main.open_window("crew", "", payload), "ui_crew"))
	elif kind == "stair":
		ft.add_child(UIK.button(I18n.t("ship.remove_stair"), _remove_stair, "ui_trash", "", _can_edit()))
	elif kind == "bulkhead":
		var d := int(payload[0])
		var y := int(payload[1])
		var is_door := Rules.is_door(st().ship.decks[d], int(st().ship.decks[d].bulkhead), y)
		var c: Dictionary = C.data.STRUCTURES.door.cost
		ft.add_child(UIK.button(I18n.t("ship.remove_door") if is_door else I18n.t("ship.add_door") + " · " + UIK.cost_text(c),
			func(): act(Actions.toggle_door(Game.state, d, y)), "ui_move", "", _can_edit()))


func _remove_stair() -> void:
	if act(Actions.remove_stair(Game.state, int(payload))):
		close()


func _demolish(uid: String, fid: String, ref: Dictionary) -> void:
	confirm(I18n.t("ship.demolish_confirm", {"facility": "fac.%s.name" % fid}), I18n.t("ship.refund", {"gold": ref.gold, "materials": ref.materials}),
		func(): act(Actions.demolish_facility(Game.state, uid)))


func _crew(b: VBoxContainer) -> void:
	var s := st()
	var m = Rules.member(s, payload)
	if m == null:
		for p in s.pets:
			if p.id == payload:
				b.add_child(UIK.label(I18n.t("pet.%s.name" % p.speciesId) + " · " + I18n.t("ui.lv", {"n": p.level}), "DimLabel"))
				b.add_child(UIK.label(Fmt.pet_assign_text(s, p), ""))
				return
		close()
		return
	var face := Actor.new().setup_puppet(Art.crew_look(m))
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(28, 34)
	face.position = Vector2(14, 32)
	holder.add_child(face)
	var txt := UIK.vbox([UIK.label(Fmt.crew_sub(s, m), "DimLabel"), UIK.label(I18n.t("crew.power", {"n": Rules.power(s, m)}), "GoldLabel")], 1)
	b.add_child(UIK.hbox([holder, txt], 4))
	var stats := Rules.member_stats(s, m)
	b.add_child(UIK.label("%s %d  %s %d  %s %d  %s %d" % [I18n.t("stat.hp_short"), int(stats.hp), I18n.t("stat.atk_short"), int(stats.atk),
		I18n.t("stat.def_short"), int(stats.def), I18n.t("stat.spd_short"), int(stats.spd)], ""))
	var slot := Rules.slot_of(s, m.id)
	b.add_child(UIK.label(I18n.t("lane." + Rules.lane_of_slot(slot)) if slot >= 0 else I18n.t("crew.reserve"), "DimLabel"))
	var state_text := I18n.t("view.off_duty")
	if m.injured:
		state_text = I18n.t("view.injured")
	elif m.jobFacilityUid != null:
		var jf = Actions.find_fac(s, m.jobFacilityUid)
		if jf:
			state_text = I18n.t("view.working", {"facility": "fac.%s.name" % jf.id})
	var hour := int(s.envelope.gameClock) % 24
	if not m.injured and (hour >= 22 or hour < 6):
		state_text = I18n.t("view.sleeping")
	b.add_child(UIK.label(state_text, "WarnLabel" if m.injured else ""))
	b.add_child(UIK.label(I18n.t("crew.traits") + ": " + ", ".join(m.traits.map(func(x): return I18n.t("trait." + x))), "DimLabel", true, 176))


func _stair(b: VBoxContainer) -> void:
	var s := st()
	var i := int(payload)
	if i < 0 or i >= s.ship.stairs.size():
		close()
		return
	var sd: Dictionary = s.ship.stairs[i]
	var kind := "stair"
	var t = Rules.stair_target(s.ship, int(sd.deck), int(sd.x), int(sd.y))
	if t != null:
		kind = String(t.kind)
	b.add_child(UIK.label(I18n.t("ship.access_" + kind), "GoldLabel"))
	b.add_child(UIK.para(I18n.t("ship.stair_info", {"a": "deck.%s.name" % s.ship.decks[int(sd.deck)].id, "b": "deck.%s.name" % s.ship.decks[int(sd.to)].id}), "", 176))


func _bulkhead(b: VBoxContainer) -> void:
	var s := st()
	var d := int(payload[0])
	b.add_child(UIK.para(I18n.t("ship.bulkhead_info", {"deck": "deck.%s.name" % s.ship.decks[d].id}), "", 176))
	b.add_child(UIK.para(I18n.t("ship.door_hint"), "DimLabel", 176))
