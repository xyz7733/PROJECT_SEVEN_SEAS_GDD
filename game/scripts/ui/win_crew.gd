## Crew window: formation and tactics, sailor details, equipment,
## skills/legacy passives and the class tree. The roster column on the
## left selects which sailor the right side shows.
extends GameWindow

var sel: Variant = null


func window_title() -> String:
	var lay := Game.layout()
	return I18n.t("crew.title") + "  ·  " + I18n.t("home.crew_cap_value", {"n": st().crew.size(), "max": lay.capacity})


func window_icon() -> String:
	return "ui_crew"


func window_size() -> Vector2:
	return Vector2(480, 304)


func tabs() -> Array:
	return [["formation", I18n.t("crew.formation"), "ui_battle"], ["detail", I18n.t("crew.details"), "ui_info"],
		["equipment", I18n.t("crew.equipment"), "w_blade"], ["skills", I18n.t("crew.skills"), "ui_star"],
		["classes", I18n.t("crew.classes"), "mastery"]]


func select(id: Variant) -> void:
	sel = id
	if tab == "formation" or tab == "":
		tab = "detail"


func _member() -> Variant:
	var s := st()
	if sel == null or Rules.member(s, sel) == null:
		sel = s.crew[0].id if s.crew.size() else null
	return Rules.member(s, sel) if sel != null else null


func build(b: VBoxContainer) -> void:
	if tab == "formation":
		_formation(b)
		return
	var row := UIK.hbox([], 6)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.add_child(row)
	var left := UIK.vbox([], 2)
	left.custom_minimum_size.x = 132
	row.add_child(left)
	var m = _member()
	for c in st().crew:
		left.add_child(_chip(c, m != null and c.id == m.id))
	var right := UIK.vbox([], 3)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	if m == null:
		right.add_child(UIK.label(I18n.t("crew.none"), "DimLabel"))
		return
	match tab:
		"detail":
			_detail(right, m)
		"equipment":
			_equipment(right, m)
		"skills":
			_skills(right, m)
		"classes":
			_classes(right, m)


func _chip(m: Dictionary, active: bool) -> Control:
	var s := st()
	var b := Button.new()
	b.theme_type_variation = "SlotButton"
	b.toggle_mode = true
	b.button_pressed = active
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(130, 30)
	b.pressed.connect(_pick.bind(m.id))
	var h := UIK.hbox([UIK.portrait("crew", m, Vector2(22, 28), false)], 3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.position = Vector2(3, 1)
	var v := UIK.vbox([UIK.label(I18n.crew_name(m), "BadLabel" if m.injured else ""), UIK.label(Fmt.crew_sub(s, m), "DimLabel")], 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	b.add_child(h)
	var slot := Rules.slot_of(s, m.id)
	b.tooltip_text = (I18n.t("lane." + Rules.lane_of_slot(slot)) if slot >= 0 else I18n.t("crew.reserve")) + " · " + I18n.t("crew.power", {"n": Rules.power(s, m)})
	return b


# ------------------------------------------------------------- formation
func _formation(b: VBoxContainer) -> void:
	var s := st()
	var reason := ""
	if s.encounter != null:
		reason = I18n.t("err.in_encounter")
	elif not Rules.at_port(s) and not Rules.fac_level(s, "muster_deck", true):
		reason = I18n.t("err.need_muster")
	var lanes := UIK.hbox([], 6)
	var lane_ids: Array = C.data.FORMATION_LANES
	for li in lane_ids.size():
		var lane: String = lane_ids[li]
		# Three lanes share the window width (they used to need about 560 px
		# of a 480 px window, which pushed the rear lane off the right edge).
		var desc := UIK.para(I18n.t("lane.%s.desc" % lane), "DimLabel", 96)
		# Room for two lines in every lane, so the slot rows line up across.
		desc.custom_minimum_size.y = 27
		var col := UIK.vbox([UIK.label(I18n.t("lane." + lane), "GoldLabel"), desc], 3)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for k in 2:
			var slot := li * 2 + k
			var id = s.formation[slot]
			var m = Rules.member(s, id) if id != null else null
			var items := [[null, I18n.t("crew.empty_slot")]]
			for c in s.crew:
				items.append([c.id, I18n.crew_name(c) + " · " + I18n.t("class.%s.name" % c.classId)])
			var opt := UIK.option(items, id, func(v): act(Actions.set_formation(Game.state, slot, v)))
			opt.disabled = reason != ""
			# Sized by the lane, not by the longest name in the list.
			opt.fit_to_longest_item = false
			opt.custom_minimum_size.x = 84
			opt.clip_text = true
			opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			opt.tooltip_text = String(items[opt.selected][1])
			var slot_info := UIK.vbox([
				UIK.label(I18n.t("crew.slot_n", {"n": slot + 1}), "DimLabel"), opt,
				UIK.label(I18n.t("crew.power", {"n": Rules.power(s, m)}) if m else "", "DimLabel")], 1)
			slot_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var slot_box := UIK.hbox([UIK.portrait("crew", m, Vector2(24, 32)) if m else UIK.tex(Art.ui_tex("slot"), Vector2(24, 32)), slot_info], 3)
			col.add_child(UIK.panel(slot_box, "FlatPanel"))
		lanes.add_child(col)
	b.add_child(lanes)
	b.add_child(UIK.para(reason if reason != "" else I18n.t("crew.formation_hint"), "WarnLabel" if reason != "" else "DimLabel", 300))
	b.add_child(UIK.header(I18n.t("crew.tactics"), "stance_" + String(s.tactics.stance)))
	var srow := HFlowContainer.new()
	srow.add_child(UIK.label(I18n.t("battle.stance"), "DimLabel"))
	for sid in C.data.STANCES:
		var bt := UIK.button(I18n.t("stance.%s.name" % sid), func(): act(Actions.set_tactics(Game.state, sid, null)), "stance_" + sid, "TabButton", true, I18n.t("stance.%s.desc" % sid))
		bt.toggle_mode = true
		bt.button_pressed = s.tactics.stance == sid
		srow.add_child(bt)
	b.add_child(srow)
	var prow := HFlowContainer.new()
	prow.add_child(UIK.label(I18n.t("battle.priority"), "DimLabel"))
	for pid in C.data.PRIORITIES:
		var bt := UIK.button(I18n.t("priority.%s.name" % pid), func(): act(Actions.set_tactics(Game.state, null, pid)), "prio_" + pid, "TabButton", true, I18n.t("priority.%s.desc" % pid))
		bt.toggle_mode = true
		bt.button_pressed = s.tactics.priority == pid
		prow.add_child(bt)
	b.add_child(prow)
	b.add_child(UIK.para(I18n.t("crew.tactics_hint"), "DimLabel", 300))


# ---------------------------------------------------------------- detail
func _detail(b: VBoxContainer, m: Dictionary) -> void:
	var s := st()
	var T: Dictionary = C.TUNING
	var cls: Dictionary = C.CLASSES[m.classId]
	var xp_need := Rules.xp_to_next(int(m.level))
	var head := UIK.vbox([], 1)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sub := Fmt.crew_sub(s, m)
	if cls.tier == "branch":
		sub += " · " + I18n.t("crew.branch_of", {"base": "class.%s.name" % cls.parent})
	head.add_child(UIK.label(sub, "GoldLabel"))
	head.add_child(UIK.hbox([UIK.bar(float(m.xp) / float(max(1, xp_need)), "xp", 90, 6), UIK.label(I18n.t("crew.xp", {"n": int(m.xp), "max": xp_need}), "DimLabel")], 3))
	var plain: Dictionary = m.duplicate()
	plain.nickname = null
	head.add_child(UIK.hbox([UIK.label(I18n.t("crew.rename"), "DimLabel"),
		UIK.line_edit(m.nickname if m.nickname else "", I18n.crew_name(plain), func(v): act(Actions.rename(Game.state, m.id, v), true))], 3))
	b.add_child(UIK.hbox([UIK.portrait("crew", m, Vector2(30, 38)), head], 4))
	if m.injured:
		var at_port := Rules.at_port(s)
		var cost: Dictionary = {"gold": Rules.treat_cost(m).gold} if at_port else {"supplies": 1}
		var ok := at_port or Rules.fac_level(s, "infirmary") > 0
		b.add_child(UIK.panel(UIK.vbox([UIK.para(I18n.t("crew.injury_note", {"pct": I18n.pct(float(T.injuryPenalty))}), "BadLabel", 300),
			UIK.hbox([UIK.button(I18n.t("crew.treat"), func(): act(Actions.treat(Game.state, m.id)), "ui_heal", "", ok and Fmt.can_afford(s, cost),
				"" if ok else I18n.t("err.need_infirmary")), UIK.label(UIK.cost_text(cost) if at_port else "1 " + I18n.t("status.supplies"), "DimLabel")], 3)], 2), "FlatPanel"))
	var st_ := Rules.member_stats(s, m)
	var g := UIK.flow(6)
	for k in ["hp", "atk", "def", "spd"]:
		g.add_child(UIK.stat("ui_" + k, I18n.fmt_num(st_[k]), "", I18n.t("stat." + k)))
	g.add_child(UIK.label(I18n.t("stat.crit") + " " + I18n.pct(float(st_.crit)), "DimLabel"))
	g.add_child(UIK.label(I18n.t("stat.dodge") + " " + I18n.pct(float(st_.dodge)), "DimLabel"))
	b.add_child(g)
	var roles: Array = st_.roles.map(func(r): return I18n.t("role." + r))
	b.add_child(UIK.label("%s · %s · %s · %s" % [I18n.t("range." + st_.range), I18n.t("lane." + st_.lane), ", ".join(roles), I18n.t("crew.power", {"n": Rules.power(s, m)})], "DimLabel", true, 300))
	var kv := UIK.grid(2, 4)
	var rows := [
		["crew.origin", I18n.t("origin." + m.originId)],
		["crew.traits", ", ".join(m.traits.map(func(x): return I18n.t("trait." + x)))],
		["crew.aptitudes", ", ".join(m.aptitudes.map(func(a): return I18n.t("apt.%s.name" % a)))],
		["crew.affinity", I18n.t("color." + m.petAffinity)],
		["crew.event", I18n.t("event.%s.title" % m.eventId) + " — " + (I18n.t("crew.event_done") if m.event.status == "done" else
			I18n.t("event.%s.desc" % m.eventId, {"n": int(m.event.get("progress", 0)), "origin": "origin." + m.originId}))],
	]
	for r in rows:
		kv.add_child(UIK.label(I18n.t(r[0]), "DimLabel"))
		kv.add_child(UIK.label(r[1], "", true, 230))
	b.add_child(kv)
	for a in m.aptitudes:
		b.add_child(UIK.label("· " + I18n.t("apt.%s.name" % a) + ": " + ", ".join(Fmt.mod_lines(C.data.APTITUDES[a])), "DimLabel", true, 300))
	if m.eventId == "collector" and m.event.status == "active":
		b.add_child(UIK.button(I18n.t("crew.event_deliver"), func(): act(Actions.crew_event_deliver(Game.state, m.id)), "ui_chest", "", Rules.at_port(s)))
	# job
	b.add_child(UIK.header(I18n.t("crew.job"), "ui_build"))
	var cur = Actions.find_fac(s, m.jobFacilityUid) if m.jobFacilityUid != null else null
	b.add_child(UIK.label(I18n.t("crew.job_current", {"facility": "fac.%s.name" % cur.id, "pct": I18n.pct(Rules.worker_efficiency(s, m, cur.id))}) if cur else I18n.t("crew.job_none"), ""))
	b.add_child(UIK.label(I18n.t("crew.jobs_preferred", {"list": ", ".join(cls.jobs.map(func(j): return Fmt.fac(j)))}), "DimLabel", true, 300))
	var lay := Game.layout()
	var items := [[null, I18n.t("crew.job_none")]]
	for f in s.ship.facilities:
		if Rules.job_slots(f) <= 0 or f.stowed:
			continue
		var reach: bool = lay.facilities[f.uid].reachable
		items.append([f.uid, Fmt.fac(f.id) + " · " + I18n.pct(Rules.worker_efficiency(s, m, f.id)) + ("" if reach else " — " + I18n.t("ship.status_disabled"))])
	var opt := UIK.option(items, m.jobFacilityUid, func(v): act(Actions.assign_job(Game.state, m.id, v)))
	opt.disabled = s.encounter != null
	b.add_child(opt)
	var pet = null
	for p in s.pets:
		if p.assignment != null and p.assignment.kind == "companion" and p.assignment.target == m.id:
			pet = p
	b.add_child(UIK.label(I18n.t("crew.companion", {"pet": I18n.pet_name(pet)}) if pet else I18n.t("crew.no_companion"), "DimLabel"))
	var dis_reason := ""
	if not Rules.at_port(s):
		dis_reason = I18n.t("err.need_port")
	elif s.crew.size() <= 1:
		dis_reason = I18n.t("err.last_crew")
	b.add_child(UIK.button(I18n.t("crew.dismiss"), _dismiss.bind(m.id), "ui_trash", "", dis_reason == "", dis_reason))


func _pick(id: String) -> void:
	sel = id
	rebuild()


func _dismiss(id: String) -> void:
	var m = Rules.member(st(), id)
	if m == null:
		return
	confirm(I18n.t("crew.dismiss_confirm", {"name": I18n.crew_name(m)}), I18n.t("crew.dismiss_body"), func(): act(Actions.dismiss(Game.state, id)))


# ------------------------------------------------------------- equipment
func _equipment(b: VBoxContainer, m: Dictionary) -> void:
	var s := st()
	var cls: Dictionary = C.CLASSES[m.classId]
	var calm := s.encounter == null
	for slot in ["weapon", "outfit", "accessory"]:
		var inst = Rules.equip_inst(s, m.equipment[slot])
		var box := UIK.vbox([], 2)
		var head := UIK.hbox([UIK.icon("w_blade" if slot == "weapon" else "w_" + slot), UIK.label(I18n.t("slot." + slot), "GoldLabel")], 3)
		if slot == "weapon":
			var allowed := UIK.label(I18n.t("crew.weapons_allowed", {"list": ", ".join(cls.weapons.map(func(w): return I18n.t("wtype." + w)))}), "DimLabel", true, 120)
			allowed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			head.add_child(allowed)
		box.add_child(head)
		if inst != null:
			box.add_child(UIK.hbox([UIK.icon(Fmt.item_icon(inst.itemId)), UIK.label(I18n.item_name(inst.itemId, inst), "")], 3))
			box.add_child(UIK.label("  ".join(Fmt.item_lines(inst.itemId, inst)), "DimLabel", true, 300))
		else:
			box.add_child(UIK.label(I18n.t("crew.no_item"), "DimLabel"))
		var items := []
		for e in s.inventory.equipment:
			var it = C.ITEMS.get(e.itemId)
			if it == null or it.slot != slot or e.uid == m.equipment[slot]:
				continue
			var ok := Rules.weapon_compatible(m.classId, e.itemId)
			var other := ""
			for c in s.crew:
				if c.id != m.id and c.equipment.values().has(e.uid):
					other = " (" + I18n.crew_name(c) + ")"
			items.append([e.uid if ok else "", I18n.item_name(e.itemId, e) + ("" if ok else " — " + I18n.t("crew.incompatible")) + other])
		var row := UIK.hbox([], 3)
		var opts := [[null, I18n.t("crew.choose_item") if items.size() else I18n.t("crew.no_items_owned")]]
		opts.append_array(items)
		var o := UIK.option(opts, null, func(v): if v != null and v != "": act(Actions.equip(Game.state, m.id, slot, v)))
		o.disabled = not calm or items.is_empty()
		o.custom_minimum_size.x = 120
		o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		o.clip_text = true
		o.fit_to_longest_item = false
		row.add_child(o)
		if inst != null:
			row.add_child(UIK.button(I18n.t("crew.unequip"), func(): act(Actions.equip(Game.state, m.id, slot, null)), "ui_close", "", calm))
		box.add_child(row)
		b.add_child(UIK.panel(box, "FlatPanel"))


# ---------------------------------------------------------------- skills
func _skills(b: VBoxContainer, m: Dictionary) -> void:
	var s := st()
	var T: Dictionary = C.TUNING
	var cls: Dictionary = C.CLASSES[m.classId]
	var st_ := Rules.member_stats(s, m)
	for id in st_.skills:
		b.add_child(UIK.hbox([UIK.icon("ui_star"), UIK.label(I18n.t("skill.%s.name" % id), "GoldLabel")], 3))
		b.add_child(UIK.label(Fmt.skill_text(id), "DimLabel", true, 300))
	b.add_child(UIK.header(I18n.t("crew.passives"), "mastery"))
	b.add_child(UIK.hbox([UIK.label(I18n.t("passive.%s.name" % cls.passive)), UIK.label(I18n.t("crew.class_passive"), "DimLabel")], 4))
	b.add_child(UIK.label(Fmt.passive_text(cls.passive), "DimLabel", true, 300))
	b.add_child(UIK.header(I18n.t("crew.legacy"), "ui_star"))
	b.add_child(UIK.para(I18n.t("crew.legacy_hint", {"n": T.masteredAt}), "DimLabel", 300))
	var opts_src := Rules.legacy_options(m)
	for i in int(T.legacySlots):
		var cur = m.legacy[i] if i < m.legacy.size() else null
		var items := [[null, I18n.t("crew.legacy_none") if opts_src.size() else I18n.t("crew.legacy_locked")]]
		for p in opts_src:
			if m.legacy.has(p) and p != cur:
				continue
			items.append([p, I18n.t("passive.%s.name" % p)])
		var o := UIK.option(items, cur, func(v): act(Actions.set_legacy(Game.state, m.id, i, v)))
		o.disabled = s.encounter != null or opts_src.is_empty()
		b.add_child(UIK.hbox([UIK.label(I18n.t("crew.legacy_n", {"n": i + 1}), "DimLabel"), o], 3))
		if cur != null:
			b.add_child(UIK.label(Fmt.passive_text(cur), "DimLabel", true, 300))


# --------------------------------------------------------------- classes
func _classes(b: VBoxContainer, m: Dictionary) -> void:
	var s := st()
	var T: Dictionary = C.TUNING
	var reason := ""
	if s.encounter != null:
		reason = I18n.t("err.in_encounter")
	elif not Rules.at_port(s) and not Rules.fac_level(s, "class_hall"):
		reason = I18n.t("err.need_class_hall")
	var cost := Rules.respec_cost(m)
	b.add_child(UIK.para(I18n.t("crew.respec_rule") + " " + UIK.cost_text(cost), "DimLabel", 300))
	if reason != "":
		b.add_child(UIK.label(reason, "WarnLabel"))
	for base_id in C.data.BASE_CLASS_IDS:
		var base: Dictionary = C.CLASSES[base_id]
		var ids := [base_id]
		ids.append_array(base.get("branches", []))
		var row := UIK.flow(2)
		for id in ids:
			row.add_child(_class_node(m, id, reason, cost))
		b.add_child(row)


func _class_node(m: Dictionary, id: String, reason: String, cost: Dictionary) -> Control:
	var s := st()
	var T: Dictionary = C.TUNING
	var mast := float(m.mastery.get(id, 0))
	var qual := Rules.qualified_for(m, id)
	var current: bool = m.classId == id
	var v := UIK.vbox([], 1)
	v.custom_minimum_size.x = 100
	var name_l := UIK.label(I18n.t("class.%s.name" % id), "GoldLabel" if current else ("" if qual else "DimLabel"))
	v.add_child(name_l)
	v.add_child(UIK.bar(minf(mast, float(T.masteredAt)) / float(T.masteredAt), "xp", 90, 4))
	if current:
		v.add_child(UIK.label(I18n.t("crew.current_class"), "GoodLabel"))
	elif mast >= float(T.masteredAt):
		v.add_child(UIK.label(I18n.t("crew.mastered"), "GoodLabel"))
	else:
		var why := reason
		if why == "" and not qual:
			var cls: Dictionary = C.CLASSES[id]
			why = I18n.t("crew.need_mastery", {"cls": "class.%s.name" % (cls.parent if cls.parent else id), "n": T.qualifyMastery})
		elif why == "" and not Fmt.can_afford(s, cost):
			why = I18n.t("ship.cannot_afford")
		var bt := UIK.button(I18n.t("crew.change_class"), _change_class.bind(m.id, id), "", "FlatButton", why == "", why)
		v.add_child(bt)
	var p := UIK.panel(v, "SelPanel" if current else "FlatPanel")
	p.tooltip_text = I18n.t("class.%s.desc" % id) + "\n" + I18n.t("crew.mastery", {"n": int(mast), "max": T.masteredAt})
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


func _change_class(crew_id: String, class_id: String) -> void:
	var m = Rules.member(st(), crew_id)
	confirm(I18n.t("crew.respec_confirm", {"name": I18n.crew_name(m), "cls": "class.%s.name" % class_id}), I18n.t("crew.respec_body"),
		func(): act(Actions.change_class(Game.state, crew_id, class_id)))
