## Port window: investment tracks, controlled market, tavern recruits,
## workshop crafting, quest board/contracts and emergency services.
## Opened from the HUD or by clicking a building on the quay.
extends GameWindow

var affix: Variant = null


func window_title() -> String:
	var s := st()
	if not Rules.at_port(s):
		return I18n.t("port.title")
	return I18n.t("loc.%s.name" % s.world.currentLocationId)


func window_icon() -> String:
	return "ui_port"


func window_size() -> Vector2:
	return Vector2(488, 304)


func tabs() -> Array:
	if not Rules.at_port(st()):
		return []
	var needs := Rules.emergency_needs(st())
	var svc := I18n.t("port.tab_services") + (" (%d)" % needs.size() if needs.size() else "")
	return [["invest", I18n.t("port.tab_invest"), "ui_invest"], ["market", I18n.t("port.tab_market"), "ui_trade"],
		["tavern", I18n.t("port.tab_tavern"), "ui_recruit"], ["workshop", I18n.t("port.tab_workshop"), "ui_build"],
		["board", I18n.t("port.tab_board"), "ui_quest"], ["services", svc, "ui_heal"]]


func build(b: VBoxContainer) -> void:
	var s := st()
	if not Rules.at_port(s):
		b.add_child(UIK.label(I18n.t("port.not_docked"), "GoldLabel"))
		b.add_child(UIK.para(Fmt.where_text(s), "", 440))
		b.add_child(UIK.para(I18n.t("port.not_docked_hint", {"location": "loc.%s.name" % s.world.lastSafePortId}), "DimLabel", 440))
		var row := UIK.hbox([], 4)
		if s.voyage != null and s.encounter == null:
			row.add_child(UIK.button(I18n.t("home.emergency_return"), _emergency_return, "ui_home"))
		row.add_child(UIK.button(I18n.t("home.open_chart"), func(): main.open_window("chart"), "ui_map"))
		b.add_child(row)
		return
	var port_id: String = s.world.currentLocationId
	var reg: Dictionary = C.region(C.PORTS[port_id].regionId)
	var reps := []
	for f in C.data.FACTIONS:
		reps.append(I18n.t("faction.%s.name" % f) + " " + I18n.t("rank.%d" % Rules.rep_rank(s, f)))
	b.add_child(UIK.label(I18n.t("region.%s.name" % reg.id) + " · " + I18n.t("map.specialty", {"item": "spec.%s.name" % reg.specialtyId}), "GoldLabel"))
	b.add_child(UIK.label(I18n.t("port.reputation", {"list": " · ".join(reps)}), "DimLabel", true, 460))
	if tab == "":
		tab = "invest"
	match tab:
		"invest":
			_invest(b, port_id)
		"market":
			_market(b, port_id, reg)
		"tavern":
			_tavern(b, port_id)
		"workshop":
			_workshop(b)
		"board":
			_board(b, port_id, reg)
		"services":
			_services(b, port_id)


func _emergency_return() -> void:
	confirm(I18n.t("home.emergency_return"), I18n.t("home.emergency_hint"), func(): act(Actions.emergency_return(Game.state)))


## A cost-labelled action button that greys out when unaffordable or blocked.
func _cost_btn(text: String, cb: Callable, cost: Variant, reason := "", icon_name := "", variation := "") -> Button:
	var s := st()
	var why := reason
	if why == "" and cost != null and not Fmt.can_afford(s, cost):
		why = I18n.t("ship.cannot_afford")
	var label := text
	if cost != null:
		label += "  " + UIK.cost_text(cost)
	return UIK.button(label, cb, icon_name, variation, why == "", why)


func _good_row(label: String, icon_name: String, color: String, sub: String, buttons: Array) -> Control:
	var lead: Control
	if icon_name != "":
		lead = UIK.icon(icon_name)
	else:
		var dot := ColorRect.new()
		dot.color = Fmt.color_of(color)
		dot.custom_minimum_size = Vector2(8, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lead = dot
	var txt := UIK.vbox([UIK.label(label), UIK.label(sub, "DimLabel")], 0)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UIK.hbox([lead, txt], 4)
	for bt in buttons:
		row.add_child(bt)
	return row


# ---------------------------------------------------------------- invest
func _invest(b: VBoxContainer, port_id: String) -> void:
	var s := st()
	b.add_child(UIK.header(I18n.t("port.invest_title"), "ui_invest"))
	b.add_child(UIK.para(I18n.t("port.invest_hint"), "DimLabel", 460))
	var g := UIK.grid(2, 4)
	for tr in C.data.INVESTMENT_TRACKS:
		var lvl := Rules.port_track(s, port_id, tr)
		var cost = Rules.invest_cost(s, port_id, tr)
		var v := UIK.vbox([], 1)
		v.custom_minimum_size.x = 222
		v.add_child(UIK.hbox([UIK.label(I18n.t("track.%s.name" % tr), "GoldLabel"), UIK.label(I18n.t("port.track_level", {"n": lvl}), "DimLabel")], 4))
		v.add_child(UIK.para(I18n.t("track.%s.desc" % tr), "DimLabel", 214))
		for n in [1, 2, 3]:
			v.add_child(UIK.hbox([UIK.icon("ui_check" if n <= lvl else "ui_lock"), UIK.label(I18n.t("track.%s.l%d" % [tr, n]), "" if n <= lvl else "DimLabel", true, 196)], 2))
		if cost != null:
			var c: Dictionary = cost.duplicate()
			c.erase("level")
			v.add_child(_cost_btn(I18n.t("port.invest_to", {"n": cost.level}), func(): act(Actions.invest(Game.state, tr)), c, "", "ui_up", "PrimaryButton"))
		else:
			v.add_child(UIK.label(I18n.t("port.track_max"), "GoodLabel"))
		g.add_child(UIK.panel(v, "FlatPanel"))
	b.add_child(g)


# ---------------------------------------------------------------- market
func _market(b: VBoxContainer, port_id: String, reg: Dictionary) -> void:
	var s := st()
	var pr := Rules.prices(s, port_id)
	var m := Rules.port_track(s, port_id, "market")
	var food_cap := Rules.food_capacity(s)
	var sup_cap := Rules.supply_capacity(s)
	var inv: Dictionary = s.inventory
	b.add_child(UIK.header(I18n.t("port.goods"), "food"))
	var food_btns := []
	for q in [1, 5, 10]:
		food_btns.append(_cost_btn("+%d" % q, _buy.bind("food", null, q), {"gold": int(pr.food) * q}, I18n.t("err.food_full") if int(inv.food) + q > food_cap else ""))
	b.add_child(_good_row(I18n.t("status.food"), "food", "", I18n.t("port.stock", {"n": inv.food, "max": food_cap}), food_btns))
	var sup_btns := []
	for q in [1, 3]:
		var why := _locked(m, 1)
		if why == "" and int(inv.supplies) + q > sup_cap:
			why = I18n.t("err.supplies_full")
		sup_btns.append(_cost_btn("+%d" % q, _buy.bind("supplies", null, q), {"gold": int(pr.supplies) * q}, why))
	b.add_child(_good_row(I18n.t("status.supplies"), "supplies", "", I18n.t("port.stock", {"n": inv.supplies, "max": sup_cap}), sup_btns))
	b.add_child(UIK.para(I18n.t("port.food_rule"), "DimLabel", 460))
	# ingredients
	b.add_child(UIK.header(I18n.t("port.ingredients"), "ui_cook"))
	if _locked(m, 1) != "":
		b.add_child(UIK.label(_locked(m, 1), "WarnLabel"))
	var ig := UIK.grid(2, 4)
	for id in C.data.INGREDIENTS:
		var ing: Dictionary = C.data.INGREDIENTS[id]
		var row := _good_row(I18n.t("ing.%s.name" % id), "ing_" + id if Art.has_icon("ing_" + id) else "", ing.color,
			I18n.t("port.owned", {"n": int(inv.ingredients.get(id, 0))}) + " · " + I18n.t("color." + ing.color),
			[_cost_btn("+1", _buy.bind("ingredient", id, 1), {"gold": pr.ingredient}, _locked(m, 1))])
		row.custom_minimum_size.x = 224
		ig.add_child(row)
	b.add_child(ig)
	# specialties (controlled trade: buy only the local one)
	b.add_child(UIK.header(I18n.t("port.specialties"), "sp_" + String(reg.specialtyId)))
	var local: String = reg.specialtyId
	b.add_child(_good_row(I18n.t("spec.%s.name" % local), "sp_" + local if Art.has_icon("sp_" + local) else "", C.data.SPECIALTIES[local].color,
		I18n.t("port.owned", {"n": int(inv.specialties.get(local, 0))}) + " · " + I18n.t("port.local_specialty"),
		[_cost_btn("+1", _buy.bind("specialty", local, 1), {"gold": Rules.specialty_buy_price(s, port_id, local)}, _locked(m, 2))]))
	for id in inv.specialties:
		var n := int(inv.specialties[id])
		if n <= 0:
			continue
		var price := Rules.specialty_sell_price(s, port_id, id)
		b.add_child(_good_row(I18n.t("spec.%s.name" % id), "sp_" + id if Art.has_icon("sp_" + id) else "", C.data.SPECIALTIES[id].color,
			I18n.t("port.owned", {"n": n}) + " · " + I18n.t("port.sell_price", {"n": price}),
			[UIK.button(I18n.t("port.sell_one"), func(): act(Actions.sell_specialty(Game.state, id, 1)), "gold")]))
	b.add_child(UIK.para(I18n.t("port.specialty_rule"), "DimLabel", 460))
	# eggs
	b.add_child(UIK.header(I18n.t("port.eggs"), "ui_egg"))
	b.add_child(_good_row(I18n.t("port.egg_offer", {"family": "petfam.%s.name" % reg.petFamilyId}), "ui_egg", "", "",
		[_cost_btn(I18n.t("port.buy_egg"), _buy.bind("egg", null, 1), {"gold": pr.egg}, _locked(m, 3))]))
	# equipment shop
	var items := Rules.shop_items(s, port_id)
	var cap := Rules.equip_capacity(s)
	b.add_child(UIK.header(I18n.t("port.equipment_shop"), "w_blade"))
	b.add_child(UIK.label(I18n.t("port.equip_stock", {"n": inv.equipment.size(), "max": cap}), "DimLabel"))
	if items.is_empty():
		b.add_child(UIK.label(I18n.t("err.market_level", {"level": 1}), "WarnLabel"))
	var sg := UIK.grid(2, 4)
	for id in items:
		var full := I18n.t("err.equip_full") if inv.equipment.size() >= cap else ""
		sg.add_child(_item_card(id, null, [_cost_btn(I18n.t("port.buy"), func(): act(Actions.buy_item(Game.state, id)), {"gold": Rules.item_price(id)}, full)]))
	b.add_child(sg)


func _locked(level: int, need: int) -> String:
	return I18n.t("err.market_level", {"level": need}) if level < need else ""


func _buy(kind: String, id: Variant, qty: int) -> void:
	act(Actions.buy_goods(Game.state, kind, id, qty))


func _item_card(item_id: String, inst: Variant, actions: Array) -> Control:
	var it: Dictionary = C.ITEMS[item_id]
	var v := UIK.vbox([], 1)
	v.custom_minimum_size.x = 222
	v.add_child(UIK.hbox([UIK.icon(Fmt.item_icon(item_id)), UIK.label(I18n.item_name(item_id, inst), "GoldLabel", true, 120), UIK.label(Fmt.item_tags(item_id), "DimLabel")], 3))
	v.add_child(UIK.label("  ".join(Fmt.item_lines(item_id, inst)), "", true, 214))
	if it.get("wtype"):
		var users := []
		for c in C.data.BASE_CLASS_IDS:
			if C.CLASSES[c].weapons.has(it.wtype):
				users.append(I18n.t("class.%s.name" % c))
		v.add_child(UIK.label(I18n.t("port.usable_by", {"list": ", ".join(users)}), "DimLabel", true, 214))
	var row := UIK.flow(3)
	for a in actions:
		row.add_child(a)
	v.add_child(row)
	return UIK.panel(v, "FlatPanel")


# ---------------------------------------------------------------- tavern
func _tavern(b: VBoxContainer, port_id: String) -> void:
	var s := st()
	var pool := Rules.tavern_pool(s, port_id)
	var cap := Rules.crew_capacity(s)
	var lvl := Rules.port_track(s, port_id, "tavern")
	var next_day := (Rules.rotation(s) + 1) * 3 + 1
	var T: Dictionary = C.TUNING
	b.add_child(UIK.header(I18n.t("port.tavern_title"), "ui_recruit"))
	b.add_child(UIK.para(I18n.t("port.tavern_hint", {"day": next_day, "level": lvl}), "DimLabel", 460))
	b.add_child(UIK.label(I18n.t("home.crew_cap_value", {"n": s.crew.size(), "max": cap}), "DimLabel"))
	var g := UIK.grid(2, 4)
	for o in pool:
		var m: Dictionary = o.member
		var cls: Dictionary = C.CLASSES[m.classId]
		var look: Dictionary = m.duplicate()
		look.id = "pool%d" % int(o.index)
		var v := UIK.vbox([], 1)
		v.custom_minimum_size.x = 222
		v.add_child(UIK.hbox([UIK.portrait("crew", look, Vector2(24, 32)), UIK.vbox([UIK.label(I18n.crew_name(m), "GoldLabel"),
			UIK.label(I18n.t("class.%s.name" % m.classId) + " · " + I18n.t("ui.lv", {"n": m.level}), "DimLabel")], 0)], 4))
		var kv := [
			[I18n.t("crew.origin"), I18n.t("origin." + m.originId)],
			[I18n.t("crew.traits"), ", ".join(m.traits.map(func(x): return I18n.t("trait." + x)))],
			[I18n.t("crew.aptitudes"), ", ".join(m.aptitudes.map(func(a): return I18n.t("apt.%s.name" % a))) if o.aptVisible else I18n.t("port.aptitudes_hidden")],
			[I18n.t("route.capability"), ", ".join(cls.roles.map(func(r): return I18n.t("role." + r)))],
		]
		for r in kv:
			v.add_child(UIK.label(r[0] + ": " + r[1], "DimLabel", true, 214))
		if float(m.mastery.get(m.classId, 0)) >= float(T.qualifyMastery):
			v.add_child(UIK.label(I18n.t("port.qualified", {"cls": "class.%s.name" % m.classId}), "GoodLabel"))
		if o.hired:
			v.add_child(UIK.label(I18n.t("port.hired"), "GoodLabel"))
		else:
			v.add_child(_cost_btn(I18n.t("port.recruit"), _recruit.bind(int(o.index)), {"gold": o.cost},
				I18n.t("err.over_capacity") if s.crew.size() >= cap else "", "ui_recruit", "PrimaryButton"))
		g.add_child(UIK.panel(v, "FlatPanel"))
	b.add_child(g)


func _recruit(index: int) -> void:
	act(Actions.recruit(Game.state, index))


# -------------------------------------------------------------- workshop
func _workshop(b: VBoxContainer) -> void:
	var s := st()
	var craft := Rules.can_craft_here(s)
	var reinf := Rules.can_reinforce_here(s)
	b.add_child(UIK.header(I18n.t("port.workshop_title"), "ui_build"))
	b.add_child(UIK.para(I18n.t("port.workshop_ok") if craft else I18n.t("err.need_workshop"), "DimLabel" if craft else "WarnLabel", 460))
	var opts := [[null, I18n.t("port.no_affix")]]
	for a in C.data.AFFIXES:
		opts.append([a, I18n.t("affix.%s.name" % a) + " — " + ", ".join(Fmt.mod_lines(C.data.AFFIXES[a]))])
	var o := UIK.option(opts, affix, _pick_affix)
	o.disabled = not reinf
	o.custom_minimum_size.x = 260
	o.clip_text = true
	var arow := UIK.hbox([UIK.label(I18n.t("port.affix"), "DimLabel"), o], 4)
	if not reinf:
		arow.add_child(UIK.label(I18n.t("err.need_workshop2"), "DimLabel"))
	b.add_child(arow)
	var recipes := []
	for id in s.inventory.recipes:
		if C.ITEMS.has(id) and C.ITEMS[id].get("recipe"):
			recipes.append(id)
	if recipes.is_empty():
		b.add_child(UIK.label(I18n.t("port.no_recipes"), "DimLabel"))
	var g := UIK.grid(2, 4)
	for id in recipes:
		var cost = Rules.craft_cost(id, affix, s)
		var preview = {"affix": affix} if affix != null else null
		g.add_child(_item_card(id, preview, [_cost_btn(I18n.t("port.craft"), _craft.bind(id), cost, "" if craft else I18n.t("err.need_workshop"), "ui_build")]))
	b.add_child(g)
	b.add_child(UIK.header(I18n.t("port.inventory", {"n": s.inventory.equipment.size(), "max": Rules.equip_capacity(s)}), "ui_chest"))
	if s.inventory.equipment.is_empty():
		b.add_child(UIK.label(I18n.t("port.no_equipment"), "DimLabel"))
	var ig := UIK.grid(2, 4)
	for e in s.inventory.equipment:
		var owner = null
		for c in s.crew:
			if c.equipment.values().has(e.uid):
				owner = c
		var rc := Rules.reinforce_cost(e, s)
		var why := ""
		if not reinf:
			why = I18n.t("err.need_workshop2")
		elif int(e.get("reinforce", 0)) >= 3:
			why = I18n.t("err.max_level")
		var acts := []
		if owner != null:
			acts.append(UIK.label(I18n.t("port.equipped_by", {"name": I18n.crew_name(owner)}), "DimLabel"))
		acts.append(_cost_btn(I18n.t("port.reinforce"), _reinforce.bind(e.uid), rc, why, "ui_up"))
		acts.append(UIK.button(I18n.t("port.salvage", {"n": Rules.salvage_value(e).materials}), _salvage.bind(e.uid), "ui_trash", "",
			owner == null, I18n.t("err.equipped") if owner != null else ""))
		ig.add_child(_item_card(e.itemId, e, acts))
	b.add_child(ig)


func _pick_affix(v: Variant) -> void:
	affix = v
	rebuild.call_deferred()


func _craft(id: String) -> void:
	act(Actions.craft_item(Game.state, id, affix))


func _reinforce(uid: String) -> void:
	act(Actions.reinforce(Game.state, uid))


func _salvage(uid: String) -> void:
	act(Actions.salvage(Game.state, uid))


# ----------------------------------------------------------------- board
func _board(b: VBoxContainer, port_id: String, reg: Dictionary) -> void:
	var s := st()
	var ms := Rules.main_status(s)
	var qb := Rules.port_track(s, port_id, "quest_board")
	b.add_child(UIK.header(I18n.t("port.main_quest"), "ui_quest"))
	var obj := Fmt.objective(s)
	b.add_child(UIK.label(obj.title, "GoldLabel", true, 460))
	b.add_child(UIK.para(obj.get("why", obj.get("line", "")), "DimLabel", 460))
	if not ms.done and ms.quest != null and ms.quest.type == "deliver":
		b.add_child(_cost_btn(I18n.t("port.deliver", {"n": ms.quest.count, "item": "spec.%s.name" % ms.quest.itemId}),
			func(): act(Actions.deliver_main(Game.state)), {"specialty": [ms.quest.itemId, ms.quest.count]},
			I18n.t("err.wrong_port") if ms.quest.locationId != port_id else "", "ui_chest", "PrimaryButton"))
	b.add_child(UIK.header(I18n.t("port.side_quests"), "ui_star"))
	if qb < 1:
		b.add_child(UIK.label(I18n.t("err.board_level", {"level": 1}), "WarnLabel"))
	var any := false
	for q in C.side_quests(reg.id):
		if q.giverId != port_id:
			continue
		any = true
		var qs = s.world.quests.get(q.id)
		var loc_key := "loc.%s.name" % q.locationId
		var txt := UIK.vbox([UIK.label(I18n.t(q.titleKey, {"location": loc_key})),
			UIK.label(I18n.t("side.%s.desc" % q.template, {"location": loc_key}) + " · " + I18n.t("faction.%s.name" % q.faction), "DimLabel", true, 330),
			UIK.label(I18n.t("port.reward", {"gold": q.reward.gold, "xp": q.reward.xp, "extra": "reward.kind." + q.rewardKind}), "DimLabel", true, 330)], 0)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := UIK.hbox([txt], 4)
		if qs == null:
			row.add_child(UIK.button(I18n.t("port.accept"), func(): act(Actions.accept_quest(Game.state, q.id)), "ui_check", "", qb >= 1,
				I18n.t("err.board_level", {"level": 1}) if qb < 1 else ""))
		else:
			var done: bool = qs.status == "done"
			row.add_child(UIK.label(I18n.t("port.quest_done" if done else "port.quest_active"), "GoodLabel" if done else "DimLabel"))
		b.add_child(UIK.panel(row, "FlatPanel"))
	if not any:
		b.add_child(UIK.label(I18n.t("port.no_side"), "DimLabel"))
	b.add_child(UIK.header(I18n.t("port.contracts"), "ui_bell"))
	b.add_child(UIK.para(I18n.t("err.board_level", {"level": 2}) if qb < 2 else I18n.t("port.contract_hint"), "WarnLabel" if qb < 2 else "DimLabel", 460))
	for c in Rules.contract_offers(s, port_id):
		var txt := UIK.vbox([UIK.label(I18n.t("contract.%s.title" % c.type)), UIK.label(Fmt.contract_text(c), "DimLabel", true, 330),
			UIK.label(I18n.t("port.contract_reward", {"gold": c.reward.gold, "materials": c.reward.materials}), "DimLabel")], 0)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := UIK.hbox([txt], 4)
		if c.status == "offered":
			row.add_child(UIK.button(I18n.t("port.accept"), _accept_contract.bind(c.id), "ui_check"))
		elif c.status == "active":
			var cost = null
			if c.type == "supply":
				cost = {"food": c.need}
			elif c.type == "haul":
				cost = {"specialty": [c.specialtyId, c.need]}
			var why := ""
			if c.type == "hunt" and int(c.progress) < int(c.need):
				why = I18n.t("err.contract_incomplete", {"have": c.progress, "need": c.need})
			row.add_child(_cost_btn(I18n.t("port.complete"), _complete_contract.bind(c.id), cost, why, "ui_check", "PrimaryButton"))
		else:
			row.add_child(UIK.label(I18n.t("port.quest_done"), "GoodLabel"))
		b.add_child(UIK.panel(row, "FlatPanel"))
	var elsewhere := []
	for c in Rules.active_contracts(s):
		if c.portId != port_id:
			elsewhere.append(c)
	if elsewhere.size():
		b.add_child(UIK.label(I18n.t("port.contracts_elsewhere"), "GoldLabel"))
		for c in elsewhere:
			b.add_child(UIK.label("· " + Fmt.contract_text(c), "DimLabel", true, 460))


func _accept_contract(id: String) -> void:
	act(Actions.accept_contract(Game.state, id))


func _complete_contract(id: String) -> void:
	act(Actions.complete_contract(Game.state, id))


# -------------------------------------------------------------- services
func _services(b: VBoxContainer, port_id: String) -> void:
	var s := st()
	var needs := Rules.emergency_needs(s)
	b.add_child(UIK.header(I18n.t("port.aid_title"), "ui_heal"))
	b.add_child(UIK.para(I18n.t("port.aid_hint"), "DimLabel", 460))
	var arow := UIK.hbox([], 3)
	for k in ["meal", "treatment", "repair"]:
		var need: bool = needs.has(k)
		var bt := UIK.button(I18n.t("aid." + k), _aid.bind(k), "", "PrimaryButton" if need else "", need, I18n.t("aid.%s.desc" % k) if need else I18n.t("err.aid_not_needed"))
		arow.add_child(bt)
	b.add_child(arow)
	var dock_ok := Rules.recovery_contract_available(s)
	b.add_child(UIK.hbox([UIK.button(I18n.t("port.dock_work", {"n": 20 + 5 * Rules.region_tier_of_port(port_id)}), func(): act(Actions.dock_work(Game.state)), "gold", "", dock_ok,
		"" if dock_ok else I18n.t("port.dock_work_locked")), UIK.label(I18n.t("port.dock_work_hint"), "DimLabel", true, 260)], 4))
	b.add_child(UIK.header(I18n.t("port.treatment"), "ui_heal"))
	var rr := Rules.fac_level(s, "recovery_room")
	var injured := 0
	for m in s.crew:
		if not m.injured:
			continue
		injured += 1
		var cost = null if rr else {"gold": Rules.treat_cost(m).gold}
		var row := UIK.hbox([UIK.portrait("crew", m, Vector2(18, 22), false), UIK.label(I18n.crew_name(m))], 4)
		row.add_child(UIK.spacer())
		row.add_child(_cost_btn(I18n.t("crew.treat"), _treat.bind(m.id), cost, "", "ui_heal"))
		b.add_child(row)
	if injured == 0:
		b.add_child(UIK.label(I18n.t("port.no_injured"), "DimLabel"))
	if rr:
		b.add_child(UIK.label(I18n.t("port.recovery_room", {"n": rr}), "GoodLabel"))
	b.add_child(UIK.header(I18n.t("port.repair"), "ui_repair"))
	var rc := Rules.repair_cost(s)
	b.add_child(UIK.hbox([UIK.label(I18n.t("home.damage") + " %d%%" % int(s.ship.damage)),
		_cost_btn(I18n.t("ship.repair"), func(): act(Actions.repair_ship(Game.state)), {"gold": rc.gold, "materials": rc.materials},
			"" if rc.needed else I18n.t("err.nothing_to_repair"), "ui_repair")], 6))
	b.add_child(UIK.header(I18n.t("port.wait_title"), "time"))
	b.add_child(UIK.hbox([UIK.para(I18n.t("port.wait_hint"), "DimLabel", 300), UIK.button(I18n.t("port.wait"), func(): act(Actions.wait_at_port(Game.state)), "ui_sleep")], 4))


func _aid(kind: String) -> void:
	act(Actions.emergency_aid(Game.state, kind))


func _treat(id: String) -> void:
	act(Actions.treat(Game.state, id))
