## Overview window: current objective, stamina and food actions, ship
## readiness, formation summary, active quests/contracts and the log.
extends GameWindow


func window_title() -> String:
	return I18n.t("hud.overview")


func window_icon() -> String:
	return "ui_quest"


func window_size() -> Vector2:
	return Vector2(456, 300)


func tabs() -> Array:
	return [["overview", I18n.t("hud.overview"), "ui_quest"], ["log", I18n.t("home.log"), "ui_codex"]]


func build(b: VBoxContainer) -> void:
	if tab == "log":
		_log(b)
	else:
		_overview(b)


func _overview(b: VBoxContainer) -> void:
	var s := st()
	var T: Dictionary = C.TUNING
	var lay := Game.layout()
	# headline
	b.add_child(UIK.hbox([UIK.icon("ui_port" if Rules.at_port(s) else "ui_sail"), UIK.label(I18n.t(s.captain.titleKey), "GoldLabel"),
		UIK.label(Fmt.where_text(s), "", true, 300)], 4))
	b.add_child(UIK.label(I18n.t("home.last_safe", {"location": "loc.%s.name" % s.world.lastSafePortId}), "DimLabel"))
	var acts := UIK.hbox([], 3)
	if Rules.at_port(s):
		acts.add_child(UIK.button(I18n.t("home.open_port"), func(): main.open_window("port"), "ui_port", "PrimaryButton"))
	acts.add_child(UIK.button(I18n.t("home.open_chart"), func(): main.open_window("chart"), "ui_map"))
	if s.voyage != null and s.encounter == null:
		acts.add_child(UIK.button(I18n.t("home.emergency_return"), _emergency_return, "ui_home", "", true, I18n.t("home.emergency_hint")))
	b.add_child(acts)
	# objective
	var obj := Fmt.objective(s)
	b.add_child(UIK.header(I18n.t("home.objective"), "ui_quest"))
	if obj.done:
		b.add_child(UIK.label(obj.line, "", true, 430))
		b.add_child(UIK.label(obj.target, "DimLabel"))
	else:
		b.add_child(UIK.label(obj.region + " · " + obj.arc + " · " + obj.step, "DimLabel", true, 430))
		b.add_child(UIK.label(obj.title, "GoldLabel", true, 430))
		b.add_child(UIK.para(obj.why, "", 430))
		b.add_child(UIK.label(obj.target, "WarnLabel" if obj.locationId == null else "", true, 430))
		b.add_child(UIK.label(obj.trial, "DimLabel", true, 430))
		if obj.locationId != null:
			b.add_child(UIK.button(I18n.t("obj.show_on_chart"), func(): main.open_window("chart", "", obj.locationId), "ui_map", "FlatButton"))
	# stamina
	b.add_child(UIK.header(I18n.t("home.stamina"), "stamina"))
	b.add_child(UIK.hbox([UIK.bar(float(s.ship.stamina) / float(max(1, int(s.ship.staminaMax))), "stamina", 120, 6),
		UIK.label(I18n.t("home.stamina_value", {"n": s.ship.stamina, "max": s.ship.staminaMax}))], 4))
	var calm := s.encounter == null
	var ration := {"food": T.rationFood}
	var row := UIK.hbox([], 3)
	row.add_child(UIK.button(I18n.t("home.serve_ration", {"n": int(T.rationStamina) + 3 * Rules.fac_level(s, "mess_hall")}) + "  " + UIK.cost_text(ration),
		func(): act(Actions.serve_ration(Game.state)), "food", "", calm and Fmt.can_afford(s, ration)))
	row.add_child(UIK.button(I18n.t("home.use_supply", {"n": T.supplyStamina}) + "  " + UIK.cost_text({"supplies": 1}),
		func(): act(Actions.use_supply(Game.state)), "supplies", "", calm and int(s.inventory.supplies) > 0))
	b.add_child(row)
	b.add_child(UIK.para(I18n.t("home.stamina_rule"), "DimLabel", 430))
	if int(s.inventory.ledger.gold) or int(s.inventory.ledger.materials):
		b.add_child(UIK.hbox([UIK.icon("ui_save"), UIK.label(I18n.t("home.ledger", {"gold": s.inventory.ledger.gold, "materials": s.inventory.ledger.materials}), "WarnLabel", true, 400)], 3))
	if Rules.emergency_needs(s).size():
		b.add_child(UIK.hbox([UIK.icon("ui_warn"), UIK.label(I18n.t("home.aid_available"), "WarnLabel"),
			UIK.button(I18n.t("home.open_port"), func(): main.open_window("port", "services"), "ui_port", "FlatButton", Rules.at_port(s))], 3))
	# ship
	var hull: Dictionary = C.hull(s.ship.hullId)
	b.add_child(UIK.header(I18n.t("home.ship"), "hull"))
	b.add_child(UIK.label(I18n.t("home.hull") + ": " + I18n.t("hull.%s.name" % hull.id) + " · " + I18n.t("ship.tier", {"n": hull.tier}) + "    "
		+ I18n.t("home.crew_cap") + ": " + I18n.t("home.crew_cap_value", {"n": s.crew.size(), "max": lay.capacity}) + "    "
		+ I18n.t("home.damage") + ": %d%%" % int(s.ship.damage), "BadLabel" if int(s.ship.damage) >= 40 else "", true, 430))
	var warns := 0
	for id in lay.missingRequired:
		b.add_child(UIK.hbox([UIK.icon("ui_warn"), UIK.label(I18n.t("home.missing_required", {"facility": "fac.%s.name" % id}), "BadLabel")], 3))
		warns += 1
	if lay.overCapacity:
		b.add_child(UIK.hbox([UIK.icon("ui_warn"), UIK.label(I18n.t("home.over_capacity"), "BadLabel")], 3))
		warns += 1
	for uid in lay.disabled:
		var f = Actions.find_fac(s, uid)
		if f == null:
			continue
		var info: Dictionary = lay.facilities[uid]
		b.add_child(UIK.hbox([UIK.icon("ui_lock"), UIK.label(Fmt.fac(f.id) + " — " + I18n.t(info.reasonKey, info.get("reasonParams", {})), "WarnLabel", true, 400)], 3))
		warns += 1
	for f in s.ship.facilities:
		if f.damaged:
			b.add_child(UIK.hbox([UIK.icon("ui_warn"), UIK.label(I18n.t("home.facility_damaged", {"facility": "fac.%s.name" % f.id}), "WarnLabel")], 3))
			warns += 1
	if warns == 0:
		b.add_child(UIK.hbox([UIK.icon("ui_check"), UIK.label(I18n.t("home.ship_ready"), "GoodLabel")], 3))
	b.add_child(UIK.button(I18n.t("home.open_ship"), func(): main.open_window("ship"), "ui_build", "FlatButton"))
	# formation
	b.add_child(UIK.header(I18n.t("home.formation"), "ui_battle"))
	var lanes := UIK.hbox([], 8)
	var lane_ids: Array = C.data.FORMATION_LANES
	for li in lane_ids.size():
		var col := UIK.vbox([UIK.label(I18n.t("lane." + lane_ids[li]), "DimLabel")], 1)
		for k in 2:
			var id = s.formation[li * 2 + k]
			var m = Rules.member(s, id) if id != null else null
			if m:
				col.add_child(UIK.hbox([UIK.portrait("crew", m, Vector2(16, 20), false), UIK.label(I18n.crew_name(m), "BadLabel" if m.injured else "")], 2))
			else:
				col.add_child(UIK.label(I18n.t("crew.empty_slot"), "DimLabel"))
		lanes.add_child(col)
	b.add_child(lanes)
	b.add_child(UIK.hbox([UIK.icon("stance_" + String(s.tactics.stance)), UIK.label(I18n.t("stance.%s.name" % s.tactics.stance)),
		UIK.icon("prio_" + String(s.tactics.priority)), UIK.label(I18n.t("priority.%s.name" % s.tactics.priority)),
		UIK.button(I18n.t("home.open_crew"), func(): main.open_window("crew", "formation"), "ui_crew", "FlatButton")], 3))
	# quests
	b.add_child(UIK.header(I18n.t("home.quests"), "ui_star"))
	var any := false
	for qid in s.world.quests:
		var qs: Dictionary = s.world.quests[qid]
		if qs.status != "active" or not C.QUESTS.has(qid):
			continue
		var q: Dictionary = C.QUESTS[qid]
		b.add_child(UIK.hbox([UIK.icon("ui_quest"), UIK.label(I18n.t(q.titleKey, {"location": "loc.%s.name" % q.locationId}) + " · " + I18n.t("loc.%s.name" % q.locationId), "", true, 400)], 3))
		any = true
	for c in Rules.active_contracts(s):
		b.add_child(UIK.hbox([UIK.icon("ui_bell"), UIK.label(Fmt.contract_text(c), "", true, 400)], 3))
		any = true
	if not any:
		b.add_child(UIK.label(I18n.t("home.no_quests"), "DimLabel"))


func _emergency_return() -> void:
	confirm(I18n.t("home.emergency_return"), I18n.t("home.emergency_hint"), func(): act(Actions.emergency_return(Game.state)))


func _log(b: VBoxContainer) -> void:
	var s := st()
	var last_day := -1
	for e in s.log:
		var clock := int(e.get("clock", 0))
		var d := int(floor(clock / 24.0))
		if d != last_day:
			last_day = d
			b.add_child(UIK.label(I18n.t("ui.day", {"n": d + 1}), "GoldLabel"))
		b.add_child(UIK.hbox([UIK.label("%02d:00" % (clock % 24), "DimLabel"), UIK.label(I18n.log_line(e), "", true, 380)], 4))
