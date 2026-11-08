## Pet window: ordered egg feeding with deterministic, Codex-recorded
## outcomes, and the pet roster with companion/helper/explorer duties,
## evolution and renaming.
extends GameWindow

var egg_sel: Variant = null
var inputs: Array = []
var pet_sel: Variant = null


func window_title() -> String:
	return I18n.t("pets.title")


func window_icon() -> String:
	return "ui_pets"


func window_size() -> Vector2:
	return Vector2(476, 300)


func tabs() -> Array:
	return [["hatch", I18n.t("pets.eggs") + " (%d)" % st().inventory.eggs.size(), "ui_egg"],
		["roster", I18n.t("pets.roster") + " (%d)" % st().pets.size(), "ui_pets"]]


func select(id: Variant) -> void:
	pet_sel = id
	tab = "roster"


func build(b: VBoxContainer) -> void:
	var s := st()
	var hatchery := Rules.fac_level(s, "hatchery", true)
	var lab := Rules.fac_level(s, "pet_lab")
	var tags := UIK.hbox([UIK.label(I18n.t("pets.count", {"n": s.pets.size(), "max": Rules.pet_capacity(s)}), "DimLabel"),
		UIK.label(I18n.t("pets.eggs_count", {"n": s.inventory.eggs.size(), "max": Rules.egg_capacity(s)}), "DimLabel"),
		UIK.label(I18n.t("pets.hatchery_level", {"n": hatchery}) if hatchery else I18n.t("pets.no_hatchery"), "GoodLabel" if hatchery else "BadLabel"),
		UIK.label(I18n.t("pets.lab_level", {"n": lab}) if lab else I18n.t("pets.no_lab"), "GoodLabel" if lab else "DimLabel")], 8)
	b.add_child(tags)
	if tab == "roster":
		_roster(b, lab)
	else:
		_hatch(b, hatchery)


func _egg_tex(fam_id: String) -> TextureRect:
	var fam: Dictionary = C.pet_family(fam_id)
	return UIK.icon("ui_egg", Fmt.color_of(String(fam.color)).lerp(Color.WHITE, 0.35))


# ----------------------------------------------------------------- hatch
func _hatch(b: VBoxContainer, hatchery: int) -> void:
	var s := st()
	var egg = null
	for e in s.inventory.eggs:
		if e.id == egg_sel:
			egg = e
	if egg == null:
		egg_sel = s.inventory.eggs[0].id if s.inventory.eggs.size() else null
		inputs = []
		egg = s.inventory.eggs[0] if s.inventory.eggs.size() else null
	var row := UIK.hbox([], 6)
	b.add_child(row)
	var left := UIK.vbox([], 2)
	left.custom_minimum_size.x = 132
	row.add_child(left)
	if s.inventory.eggs.is_empty():
		left.add_child(UIK.label(I18n.t("pets.no_eggs"), "DimLabel"))
	for e in s.inventory.eggs:
		var bt := UIK.button(I18n.t("petfam.%s.name" % e.familyId) + " · " + I18n.t("pets.grade", {"n": e.grade}), _pick_egg.bind(e.id), "ui_egg", "SlotButton")
		bt.toggle_mode = true
		bt.button_pressed = e.id == egg_sel
		var tint := Fmt.color_of(String(C.pet_family(e.familyId).color)).lerp(Color.WHITE, 0.35)
		for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
			bt.add_theme_color_override(k, tint)
		bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
		bt.custom_minimum_size = Vector2(130, 22)
		left.add_child(bt)
	left.add_child(UIK.para(I18n.t("pets.egg_sources"), "DimLabel", 128))
	var right := UIK.vbox([], 3)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	if egg == null:
		right.add_child(UIK.label(I18n.t("pets.feed_title_none"), "GoldLabel"))
		right.add_child(UIK.para(I18n.t("pets.no_eggs_hint"), "DimLabel", 300))
		return
	var fam: Dictionary = C.pet_family(egg.familyId)
	right.add_child(UIK.hbox([_egg_tex(egg.familyId), UIK.label(I18n.t("pets.feed_title", {"family": "petfam.%s.name" % egg.familyId}), "GoldLabel")], 3))
	right.add_child(UIK.para(I18n.t("pets.feed_rule"), "DimLabel", 300))
	# feeding slots
	var slots := UIK.hbox([], 3)
	for i in 3:
		var v := UIK.vbox([UIK.label(I18n.t("pets.feed_n", {"n": i + 1}), "DimLabel")], 0)
		v.custom_minimum_size = Vector2(96, 30)
		if i < inputs.size():
			var c = Rules.input_color(inputs[i])
			v.add_child(UIK.hbox([_dot(String(c)), UIK.label(Fmt.input_label(inputs[i]), "", true, 80)], 2))
		else:
			v.add_child(UIK.label(I18n.t("pets.empty_slot"), "DimLabel"))
		slots.add_child(UIK.panel(v, "SelPanel" if i < inputs.size() else "FlatPanel"))
	right.add_child(slots)
	# picker
	var queued := {}
	for inp in inputs:
		queued[inp] = int(queued.get(inp, 0)) + 1
	var avail := []
	for id in s.inventory.ingredients:
		if int(s.inventory.ingredients[id]) > 0:
			avail.append(["ing:" + id, int(s.inventory.ingredients[id]), String(C.data.INGREDIENTS[id].color)])
	for id in s.inventory.specialties:
		if int(s.inventory.specialties[id]) > 0:
			avail.append(["spec:" + id, int(s.inventory.specialties[id]), String(C.data.SPECIALTIES[id].color)])
	if avail.is_empty():
		right.add_child(UIK.label(I18n.t("pets.no_inputs"), "WarnLabel"))
	var pick := UIK.flow(2)
	for a in avail:
		var left_n: int = a[1] - int(queued.get(a[0], 0))
		var why := ""
		if left_n <= 0:
			why = I18n.t("pets.none_left")
		elif inputs.size() >= 3:
			why = I18n.t("pets.max_inputs")
		var bt := UIK.button(Fmt.input_label(a[0]) + " ×%d" % max(0, left_n), _push_input.bind(a[0]), "", "FlatButton", why == "", why if why != "" else I18n.t("color." + a[2]))
		bt.add_theme_color_override("font_color", Fmt.color_of(a[2]).lerp(Color.WHITE, 0.45))
		pick.add_child(bt)
	right.add_child(pick)
	# prediction
	var colors := []
	for inp in inputs:
		colors.append(Rules.input_color(inp))
	var known = null
	if colors.size():
		for x in s.codex.hatchLog:
			if x.familyId == egg.familyId and x.colors == colors:
				known = x
				break
	var role = C.data.ROLE_BY_COLOR.get(colors[0]) if colors.size() else null
	var kv := UIK.grid(2, 4)
	kv.add_child(UIK.label(I18n.t("pets.predicted_role"), "DimLabel"))
	kv.add_child(UIK.label(I18n.t("petrole." + role) if role else "—"))
	kv.add_child(UIK.label(I18n.t("pets.known_outcome"), "DimLabel"))
	var known_text := "—"
	if known != null:
		known_text = I18n.t("pet.%s.name" % known.speciesId) + (" · " + I18n.t("pets.prime") if known.prime else "")
	elif colors.size():
		known_text = I18n.t("pets.unrecorded")
	kv.add_child(UIK.label(known_text))
	kv.add_child(UIK.label(I18n.t("pets.hatch_level"), "DimLabel"))
	kv.add_child(UIK.label(str([1, 3, 5][clampi(int(egg.grade) - 1, 0, 2)])))
	right.add_child(kv)
	if s.codex.clues.has("clue.pet." + egg.familyId):
		right.add_child(UIK.label(I18n.t("pets.signatures"), "GoldLabel"))
		for r in C.data.PET_ROLES:
			var seq: Array = fam.sig[r].map(func(c): return I18n.t("color." + c))
			right.add_child(UIK.label("· " + I18n.t("petrole." + r) + ": " + " → ".join(seq), "DimLabel", true, 300))
	else:
		right.add_child(UIK.para(I18n.t("pets.signature_hint"), "DimLabel", 300))
	var why := ""
	if not hatchery:
		why = I18n.t("err.need_facility", {"facility": "fac.hatchery.name"})
	elif inputs.is_empty():
		why = I18n.t("err.hatch_inputs")
	elif s.pets.size() >= Rules.pet_capacity(s):
		why = I18n.t("err.pet_full")
	right.add_child(UIK.hbox([UIK.button(I18n.t("pets.clear"), _clear_inputs, "ui_close", "", inputs.size() > 0, "" if inputs.size() else I18n.t("pets.nothing_queued")),
		UIK.button(I18n.t("pets.hatch"), _hatch_now.bind(egg.id), "ui_pets", "PrimaryButton", why == "", why)], 4))


func _dot(color: String) -> Control:
	var d := ColorRect.new()
	d.color = Fmt.color_of(color)
	d.custom_minimum_size = Vector2(7, 7)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return d


func _pick_egg(id: String) -> void:
	egg_sel = id
	inputs = []
	rebuild()


func _push_input(inp: String) -> void:
	if inputs.size() < 3:
		inputs.append(inp)
	rebuild()


func _clear_inputs() -> void:
	inputs = []
	rebuild()


func _hatch_now(egg_id: String) -> void:
	var feed := inputs.duplicate()
	if act(Actions.hatch_egg(Game.state, egg_id, feed)):
		inputs = []
		var pets: Array = st().pets
		if pets.size():
			pet_sel = pets[pets.size() - 1].id
			tab = "roster"
		rebuild()


# ---------------------------------------------------------------- roster
func _roster(b: VBoxContainer, lab: int) -> void:
	var s := st()
	var p = null
	for x in s.pets:
		if x.id == pet_sel:
			p = x
	if p == null and s.pets.size():
		p = s.pets[0]
		pet_sel = p.id
	var row := UIK.hbox([], 6)
	b.add_child(row)
	var left := UIK.vbox([], 2)
	left.custom_minimum_size.x = 132
	row.add_child(left)
	if s.pets.is_empty():
		left.add_child(UIK.label(I18n.t("pets.no_pets"), "DimLabel"))
	for x in s.pets:
		left.add_child(_chip(x, p != null and x.id == p.id))
	if p == null:
		return
	var right := UIK.vbox([], 3)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_detail(right, p, lab)


func _chip(p: Dictionary, active: bool) -> Control:
	var s := st()
	var b := Button.new()
	b.theme_type_variation = "SlotButton"
	b.toggle_mode = true
	b.button_pressed = active
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(130, 30)
	b.pressed.connect(_pick_pet.bind(p.id))
	var h := UIK.hbox([UIK.portrait("pet", p, Vector2(24, 28), false)], 3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.position = Vector2(3, 1)
	var sub := I18n.t("ui.lv", {"n": p.level}) + (" · " + I18n.t("pets.prime") if p.prime else "")
	var v := UIK.vbox([UIK.label(I18n.pet_name(p)), UIK.label(sub, "DimLabel")], 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	b.add_child(h)
	b.tooltip_text = Fmt.pet_assign_text(s, p)
	return b


func _pick_pet(id: String) -> void:
	pet_sel = id
	rebuild()


func _detail(b: VBoxContainer, p: Dictionary, lab: int) -> void:
	var s := st()
	var fam: Dictionary = C.pet_family(p.familyId)
	var roles := Rules.pet_roles(p)
	var ab: Dictionary = C.data.PET_ABILITIES[fam.ability]
	var ec := Rules.evolve_cost(p)
	var a: Dictionary = p.assignment if p.assignment != null else {}
	var head := UIK.vbox([UIK.label(I18n.pet_name(p), "GoldLabel"),
		UIK.label(I18n.t("pet.%s.name" % p.speciesId) + " · " + I18n.t("petfam.%s.name" % p.familyId), "DimLabel")], 1)
	var tags := UIK.hbox([], 4)
	if p.prime:
		tags.add_child(UIK.label(I18n.t("pets.prime"), "GoodLabel"))
	if p.evolved:
		tags.add_child(UIK.label(I18n.t("pets.evolved"), "GoodLabel"))
	tags.add_child(UIK.label(I18n.t("pets.affinity", {"color": "color." + p.affinity}), "DimLabel"))
	head.add_child(tags)
	var need := Rules.pet_xp_to_next(int(p.level))
	head.add_child(UIK.hbox([UIK.bar(float(p.xp) / float(max(1, need)), "xp", 90, 6), UIK.label(I18n.t("ui.lv", {"n": p.level}) + " · " + I18n.t("crew.xp", {"n": p.xp, "max": need}), "DimLabel")], 3))
	b.add_child(UIK.hbox([UIK.portrait("pet", p, Vector2(34, 36)), head], 4))
	var owner = Rules.member(s, a.target) if a.get("kind") == "companion" else null
	var power := Rules.pet_power_mult(p, owner, Rules.member_stats(s, owner) if owner != null else null)
	var kv := UIK.grid(2, 4)
	var rows := [
		[I18n.t("pets.roles"), ", ".join(roles.map(func(r): return I18n.t("petrole." + r)))],
		[I18n.t("pets.ability"), I18n.t("petability." + fam.ability) + " — " + _ability_text(ab)],
		[I18n.t("pets.power"), "×" + I18n.fmt_num(snappedf(power, 0.01))],
		[I18n.t("pets.assignment"), Fmt.pet_assign_text(s, p)],
		[I18n.t("pets.inputs"), " → ".join(p.get("inputs", []).map(func(x): return Fmt.input_label(x))) if p.get("inputs", []).size() else "—"],
	]
	for r in rows:
		kv.add_child(UIK.label(r[0], "DimLabel"))
		kv.add_child(UIK.label(r[1], "", true, 240))
	b.add_child(kv)
	var calm := s.encounter == null
	# companion
	b.add_child(UIK.header(I18n.t("petrole.companion"), "pet_companion"))
	var copts := [[null, "—"]]
	for id in s.formation:
		if id != null:
			copts.append([id, I18n.crew_name(Rules.member(s, id))])
	var co := UIK.option(copts, a.target if a.get("kind") == "companion" else null, _assign_companion.bind(p.id))
	co.disabled = not calm or not roles.has("companion")
	b.add_child(UIK.hbox([co, UIK.label(I18n.t("petrole.companion.desc") if roles.has("companion") else I18n.t("err.pet_role", {"role": "petrole.companion"}), "DimLabel", true, 190)], 4))
	# helper
	b.add_child(UIK.header(I18n.t("petrole.helper"), "pet_helper"))
	var lay := Game.layout()
	var hopts := [[null, "—"]]
	for f in s.ship.facilities:
		if f.stowed:
			continue
		var reach: bool = lay.facilities.has(f.uid) and lay.facilities[f.uid].reachable
		hopts.append([f.uid, Fmt.fac(f.id) + " · " + I18n.t("deck.%s.name" % s.ship.decks[int(f.deck)].id) + ("" if reach else " — " + I18n.t("ship.status_disabled"))])
	var ho := UIK.option(hopts, a.target if a.get("kind") == "helper" else null, _assign_helper.bind(p.id))
	ho.disabled = not calm
	ho.custom_minimum_size.x = 150
	ho.clip_text = true
	b.add_child(UIK.hbox([ho, UIK.label(I18n.t("petrole.helper.desc") if roles.has("helper") else I18n.t("pets.helper_half"), "DimLabel", true, 150)], 4))
	# explorer
	b.add_child(UIK.header(I18n.t("petrole.explorer"), "pet_explorer"))
	var exploring: bool = a.get("kind") == "explorer"
	var ex := UIK.button(I18n.t("pets.recall") if exploring else I18n.t("pets.send_explore"), _toggle_explore.bind(p.id, exploring), "ui_map", "",
		calm and roles.has("explorer"), "" if roles.has("explorer") else I18n.t("err.pet_role", {"role": "petrole.explorer"}))
	b.add_child(UIK.hbox([ex, UIK.label(I18n.t("petrole.explorer.desc"), "DimLabel", true, 190)], 4))
	if p.assignment != null:
		b.add_child(UIK.button(I18n.t("pets.unassign"), _unassign.bind(p.id), "ui_close", "", calm))
	# evolution
	b.add_child(UIK.header(I18n.t("pets.evolution"), "ui_star"))
	if p.evolved:
		b.add_child(UIK.para(I18n.t("pets.evolved_note"), "DimLabel", 300))
	else:
		b.add_child(UIK.para(I18n.t("pets.evolve_hint", {"level": ec.level}), "DimLabel", 300))
		var cost := {"materials": ec.materials, "specialty": ec.specialty}
		var why := ""
		if not lab:
			why = I18n.t("err.need_facility", {"facility": "fac.pet_lab.name"})
		elif int(p.level) < int(ec.level):
			why = I18n.t("err.pet_level", {"level": ec.level})
		elif not Fmt.can_afford(s, cost):
			why = I18n.t("ship.cannot_afford")
		b.add_child(UIK.button(I18n.t("pets.evolve") + "  " + UIK.cost_text(cost), _evolve.bind(p.id), "ui_up", "PrimaryButton", why == "" and calm, why))
	var plain: Dictionary = p.duplicate()
	plain.nickname = null
	b.add_child(UIK.hbox([UIK.label(I18n.t("crew.rename"), "DimLabel"),
		UIK.line_edit(p.nickname if p.nickname else "", I18n.pet_name(plain), _rename.bind(p.id))], 3))


func _ability_text(ab: Dictionary) -> String:
	var parts := [I18n.t("pets.target_" + String(ab.get("target", "enemy")))]
	if ab.get("power"):
		parts.append(I18n.t("pets.ab_power", {"pct": I18n.pct(float(ab.power))}))
	if ab.get("heal"):
		parts.append(I18n.t("pets.ab_heal", {"pct": I18n.pct(float(ab.heal))}))
	if ab.get("shield"):
		parts.append(I18n.t("pets.ab_shield", {"pct": I18n.pct(float(ab.shield))}))
	parts.append_array(Fmt.fx_lines(ab.get("fx")))
	return ", ".join(parts)


func _assign_companion(target: Variant, pet_id: String) -> void:
	act(Actions.assign_pet(Game.state, pet_id, "companion" if target != null else null, target))


func _assign_helper(target: Variant, pet_id: String) -> void:
	act(Actions.assign_pet(Game.state, pet_id, "helper" if target != null else null, target))


func _toggle_explore(pet_id: String, exploring: bool) -> void:
	act(Actions.assign_pet(Game.state, pet_id, null if exploring else "explorer", null))


func _unassign(pet_id: String) -> void:
	act(Actions.assign_pet(Game.state, pet_id, null, null))


func _evolve(pet_id: String) -> void:
	act(Actions.evolve_pet(Game.state, pet_id))


func _rename(nick: String, pet_id: String) -> void:
	act(Actions.rename_pet(Game.state, pet_id, nick), true)
