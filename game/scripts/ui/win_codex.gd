## Codex window: everything the captain has discovered, with progress
## counters, a bestiary, the class tree, pet families and the
## deterministic hatch log for repeating egg outcomes.
extends GameWindow

const TABS := ["locations", "enemies", "classes", "pets", "items", "clues", "collections"]
const TAB_ICONS := {"locations": "ui_map", "enemies": "ui_battle", "classes": "mastery", "pets": "ui_pets", "items": "ui_chest", "clues": "ui_quest", "collections": "ui_relic"}


func window_title() -> String:
	return I18n.t("codex.title")


func window_icon() -> String:
	return "ui_codex"


func window_size() -> Vector2:
	return Vector2(480, 304)


func tabs() -> Array:
	var out := []
	for id in TABS:
		out.append([id, I18n.t("codex.tab_" + id), TAB_ICONS[id]])
	return out


func build(b: VBoxContainer) -> void:
	var s := st()
	if tab == "":
		tab = "locations"
	b.add_child(UIK.label(I18n.t("codex.captain", {"title": s.captain.titleKey, "n": s.captain.trialsWon.size()}), "DimLabel"))
	var prog := Rules.codex_progress(s)
	var strip := UIK.hbox([], 6)
	for id in TABS:
		var pair: Array = prog[id]
		var v := UIK.vbox([], 0)
		v.custom_minimum_size.x = 58
		var txt := I18n.fmt_num(pair[0]) + (" / " + I18n.fmt_num(pair[1]) if pair[1] != null else "")
		v.add_child(UIK.label(txt, "GoldLabel" if tab == id else ""))
		v.add_child(UIK.label(I18n.t("codex.tab_" + id), "DimLabel"))
		if pair[1] != null and int(pair[1]) > 0:
			v.add_child(UIK.bar(float(pair[0]) / float(pair[1]), "xp", 52, 3))
		strip.add_child(v)
	b.add_child(strip)
	b.add_child(UIK.sep())
	match tab:
		"locations":
			_locations(b)
		"enemies":
			_enemies(b)
		"classes":
			_classes(b)
		"pets":
			_pets(b)
		"items":
			_items(b)
		"clues":
			_clues(b)
		"collections":
			_collections(b)


func _know_variation(k: String) -> String:
	match k:
		"cleared":
			return "GoodLabel"
		"visited":
			return ""
		"revealed":
			return "WarnLabel"
	return "DimLabel"


# ------------------------------------------------------------- locations
func _locations(b: VBoxContainer) -> void:
	var s := st()
	for r in C.REGIONS:
		var unlocked := Rules.region_unlocked(s, r.id)
		var v := UIK.vbox([], 1)
		v.add_child(UIK.hbox([UIK.label(I18n.t("region.%s.name" % r.id), "GoldLabel"),
			UIK.label(I18n.t("arc.%s.title" % r.id) if unlocked else I18n.t("codex.region_locked"), "DimLabel" if unlocked else "WarnLabel")], 6))
		if unlocked:
			v.add_child(UIK.para(I18n.t("region.%s.desc" % r.id), "DimLabel", 440))
			var kv := UIK.grid(4, 4)
			var pairs := [
				[I18n.t("map.specialty_label"), I18n.t("spec.%s.name" % r.specialtyId)],
				[I18n.t("codex.hazard"), I18n.t("hazard.%s.name" % r.hazard) if r.get("hazard") else I18n.t("codex.none_value")],
				[I18n.t("codex.mechanic"), I18n.t("mechanic.%s.name" % r.mechanic) if r.get("mechanic") else I18n.t("codex.none_value")],
				[I18n.t("codex.pet_family"), I18n.t("petfam.%s.name" % r.petFamilyId)],
				[I18n.t("codex.trial"), I18n.t("codex.trial_won") if s.captain.trialsWon.has(r.id) else I18n.t("codex.trial_pending")],
			]
			if s.captain.postgame and C.world.LEGENDS.has(r.id):
				pairs.append([I18n.t("legend.title"), I18n.t("codex.trial_won") if s.captain.legendsWon.has(r.id) else I18n.t("legend.restriction." + C.world.LEGENDS[r.id].restriction)])
			for p in pairs:
				kv.add_child(UIK.label(p[0], "DimLabel"))
				kv.add_child(UIK.label(p[1], "", false, 120))
			v.add_child(kv)
			var ms := int(s.captain.mainStep.get(r.id, 0))
			for i in mini(ms + 1, 5):
				v.add_child(UIK.label("%d. %s" % [i + 1, I18n.t("arc.%s.%d" % [r.id, i])], "DimLabel", true, 440))
		var fl := UIK.flow(6)
		for id in r.locs:
			var k := Rules.knowledge(s, id)
			var l: Dictionary = C.location(id)
			var icon_name := "ui_quest" if k == "hidden" else "loc_" + String(l.type)
			var name := I18n.t("codex.unknown_location") if k == "hidden" else I18n.t("loc.%s.name" % id)
			var chip := UIK.hbox([UIK.icon(icon_name if Art.has_icon(icon_name) else "ui_map"), UIK.label(name, _know_variation(k))], 2)
			chip.tooltip_text = I18n.t("know." + k)
			chip.mouse_filter = Control.MOUSE_FILTER_PASS
			fl.add_child(chip)
		v.add_child(fl)
		b.add_child(UIK.panel(v, "FlatPanel"))


# --------------------------------------------------------------- enemies
func _enemies(b: VBoxContainer) -> void:
	var s := st()
	for r in C.REGIONS:
		var ids := Bestiary.region_ids(String(r.id))
		if ids.is_empty():
			continue
		var p := Bestiary.progress(s, String(r.id))
		var head := UIK.hbox([UIK.label(I18n.t("codex.bestiary_region", {"region": I18n.t("region.%s.name" % r.id),
			"seen": int(p.seen), "total": int(p.total), "defeated": int(p.defeated)}), "GoldLabel")], 5)
		head.add_child(UIK.spacer(4, 0))
		for tier in [50, 100]:
			var key := "%s:%d" % [r.id, tier]
			if s.captain.bestiaryRewards.has(key):
				head.add_child(UIK.label(I18n.t("codex.collection_claimed"), "DimLabel"))
			else:
				var can: bool = Bestiary.claimable(s, String(r.id)).has(tier)
				var btn := UIK.button(I18n.t("codex.bestiary_claim_%d" % tier),
					func(): act(Actions.claim_bestiary_reward(Game.state, String(r.id), tier)), "ui_relic", "FlatButton",
					can, "" if can else I18n.t("err.not_ready"))
				head.add_child(btn)
		b.add_child(UIK.panel(head, "FlatPanel"))
		var g := UIK.grid(3, 4)
		for id in ids:
			g.add_child(_enemy_card(s, String(id)))
		b.add_child(g)


func _enemy_card(s: Dictionary, id: String) -> Control:
	var c = s.codex.enemies.get(id)
	var e = World.enemy(id)
	if c == null or e == null:
		var unknown := UIK.hbox([UIK.icon("ui_quest"), UIK.label(I18n.t("codex.unknown_enemy"), "DimLabel")], 3)
		unknown.custom_minimum_size = Vector2(146, 34)
		return UIK.panel(unknown, "FlatPanel")
	var lines := UIK.vbox([], 0)
	lines.add_child(UIK.label(I18n.t("enemy.%s.name" % id), "GoldLabel", true, 100))
	lines.add_child(UIK.label(I18n.t("archetype." + String(e.archetype)), "DimLabel", true, 100))
	lines.add_child(UIK.label(I18n.t("codex.kills", {"n": int(c.get("kills", c.get("defeated", 0)))}), "DimLabel"))
	if e.get("rare", false):
		lines.add_child(UIK.label(I18n.t("codex.rare_enemy"), "WarnLabel"))
	elif e.get("boss", false):
		lines.add_child(UIK.label(I18n.t("codex.rival" if e.get("rival") else "codex.boss"), "BadLabel"))
	var variants: Array = c.get("variants", [])
	if variants.size() > 0:
		var names := []
		for v in variants:
			names.append(I18n.t("variant.%s.name" % v))
		lines.add_child(UIK.label(", ".join(names), "DimLabel", true, 100))
	var card := UIK.hbox([UIK.portrait("enemy", id, Vector2(36, 40)), lines], 3)
	card.custom_minimum_size.x = 146
	return UIK.panel(card, "FlatPanel")


# --------------------------------------------------------------- classes
func _classes(b: VBoxContainer) -> void:
	var s := st()
	b.add_child(UIK.para(I18n.t("codex.classes_hint"), "DimLabel", 440))
	var g := UIK.grid(2, 4)
	for base in C.data.BASE_CLASS_IDS:
		var cls: Dictionary = C.CLASSES[base]
		var ids := [base]
		ids.append_array(cls.get("branches", []))
		var v := UIK.vbox([], 1)
		v.custom_minimum_size.x = 222
		for id in ids:
			var known: bool = s.codex.classes.has(id)
			v.add_child(UIK.label(I18n.t("class.%s.name" % id) if known else I18n.t("codex.unknown_class"), ("GoldLabel" if id == base else "") if known else "DimLabel"))
			if known:
				v.add_child(UIK.label(I18n.t("class.%s.desc" % id), "DimLabel", true, 214))
		g.add_child(UIK.panel(v, "FlatPanel"))
	b.add_child(g)


# ------------------------------------------------------------------ pets
func _pets(b: VBoxContainer) -> void:
	var s := st()
	b.add_child(UIK.header(I18n.t("codex.hatch_log"), "ui_egg"))
	b.add_child(UIK.para(I18n.t("codex.hatch_hint"), "DimLabel", 440))
	if s.codex.hatchLog.is_empty():
		b.add_child(UIK.label(I18n.t("codex.no_hatches"), "DimLabel"))
	else:
		var g := UIK.grid(3, 3)
		for h in [I18n.t("codex.family"), I18n.t("codex.order"), I18n.t("codex.result")]:
			g.add_child(UIK.label(h, "GoldLabel"))
		for x in s.codex.hatchLog:
			g.add_child(UIK.label(I18n.t("petfam.%s.name" % x.familyId)))
			var seq := UIK.hbox([], 2)
			for c in x.colors:
				var d := ColorRect.new()
				d.color = Fmt.color_of(String(c))
				d.custom_minimum_size = Vector2(7, 7)
				d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				seq.add_child(d)
			seq.add_child(UIK.label(" → ".join(x.colors.map(func(c): return I18n.t("color." + c))), "DimLabel"))
			g.add_child(seq)
			g.add_child(UIK.label(I18n.t("pet.%s.name" % x.speciesId) + (" · " + I18n.t("pets.prime") if x.prime else "")))
		b.add_child(g)
	b.add_child(UIK.header(I18n.t("codex.tab_pets"), "ui_pets"))
	var fg := UIK.grid(2, 4)
	for f in C.PET_FAMILIES:
		var v := UIK.vbox([UIK.label(I18n.t("petfam.%s.name" % f.id), "GoldLabel"),
			UIK.label(I18n.t("region.%s.name" % f.regionId) + " · " + I18n.t("petability." + String(f.ability)), "DimLabel", true, 170)], 0)
		for r in C.data.PET_ROLES:
			for evo in ["", "_evo"]:
				var sp: String = "%s_%s%s" % [f.id, r, evo]
				var c = s.codex.pets.get(sp)
				v.add_child(UIK.label((I18n.t("pet.%s.name" % sp) + (" ★" if c.prime else "")) if c != null else I18n.t("codex.unknown_pet"), "" if c != null else "DimLabel"))
		var card := UIK.hbox([UIK.portrait("pet", "%s_companion" % f.id, Vector2(30, 30)), v], 3)
		card.custom_minimum_size.x = 222
		fg.add_child(UIK.panel(card, "FlatPanel"))
	b.add_child(fg)


# ----------------------------------------------------------------- items
func _items(b: VBoxContainer) -> void:
	var s := st()
	var recipes: Array = s.inventory.recipes
	b.add_child(UIK.header(I18n.t("codex.items_seen"), "ui_chest"))
	if s.codex.items.is_empty():
		b.add_child(UIK.label(I18n.t("codex.none"), "DimLabel"))
	var g := UIK.grid(2, 3)
	for id in s.codex.items:
		if not C.ITEMS.has(id):
			continue
		var row := UIK.hbox([UIK.icon(Fmt.item_icon(id)), UIK.vbox([UIK.label(I18n.item_name(id, null)),
			UIK.label(I18n.t("slot." + String(C.ITEMS[id].slot)) + (" · " + I18n.t("codex.recipe_known") if recipes.has(id) else ""), "DimLabel")], 0)], 3)
		row.custom_minimum_size.x = 222
		g.add_child(row)
	b.add_child(g)
	b.add_child(UIK.header(I18n.t("codex.recipes"), "ui_build"))
	if recipes.is_empty():
		b.add_child(UIK.label(I18n.t("codex.none"), "DimLabel"))
	for id in recipes:
		var it = C.ITEMS.get(id)
		if it == null or not it.get("recipe"):
			continue
		var rc: Dictionary = it.recipe
		b.add_child(UIK.hbox([UIK.icon(Fmt.item_icon(id)), UIK.label(I18n.item_name(id, null)),
			UIK.label(I18n.t("codex.recipe_cost", {"n": rc.materials, "item": "spec.%s.name" % rc.specialty[0], "k": rc.specialty[1]}), "DimLabel")], 4))
	var bps: Array = s.inventory.blueprints.map(func(x): return I18n.t("blueprint." + x))
	var uniq: Array = s.inventory.uniques.map(func(u): return I18n.item_name(u, null))
	b.add_child(UIK.label(I18n.t("codex.blueprints") + ": " + (", ".join(bps) if bps.size() else "—"), "DimLabel", true, 440))
	b.add_child(UIK.label(I18n.t("codex.uniques") + ": " + (", ".join(uniq) if uniq.size() else "—"), "DimLabel", true, 440))


# ----------------------------------------------------------------- clues
func _clues(b: VBoxContainer) -> void:
	var s := st()
	if s.codex.clues.is_empty():
		b.add_child(UIK.label(I18n.t("codex.no_clues"), "DimLabel"))
	for c in s.codex.clues:
		b.add_child(UIK.hbox([UIK.icon("ui_quest"), UIK.label(I18n.t(c), "", true, 420)], 3))


# ------------------------------------------------------------- collections
func _collections(b: VBoxContainer) -> void:
	var s := st()
	var comp := Collections.completeness(s)
	b.add_child(UIK.hbox([UIK.icon("ui_relic"), UIK.label(I18n.t("codex.collection_progress",
		{"n": int(comp.owned), "max": int(comp.total)}), "GoldLabel")], 3))
	b.add_child(UIK.label(I18n.t("codex.collection_shards", {"n": int(s.inventory.get("curioShards", 0))}), "DimLabel"))
	b.add_child(UIK.header(I18n.t("codex.collection_sets"), "ui_relic"))
	var grid := UIK.grid(2, 4)
	for sid in C.COLLECTION_SETS:
		grid.add_child(_collection_set_card(s, String(sid)))
	b.add_child(grid)
	b.add_child(UIK.header(I18n.t("codex.collection_charts"), "ui_chart"))
	var charts := 0
	for cid in s.inventory.get("collectibles", {}):
		if Collections.kind(String(cid)) != "chart":
			continue
		charts += 1
		b.add_child(_chart_row(s, String(cid)))
	if charts == 0:
		b.add_child(UIK.label(I18n.t("codex.no_collectibles"), "DimLabel"))


func _collection_set_card(s: Dictionary, sid: String) -> Control:
	var set: Dictionary = C.COLLECTION_SETS[sid]
	var progress := Collections.set_progress(s, sid)
	var v := UIK.vbox([], 1)
	v.custom_minimum_size.x = 222
	v.add_child(UIK.label(I18n.t(set.nameKey), "GoldLabel", true, 214))
	v.add_child(UIK.para(I18n.t(set.descKey), "DimLabel", 214))
	var icons := UIK.flow(2)
	for member in set.get("members", []):
		var mid := String(member)
		var ic := UIK.icon(Collections.icon(mid), Color.WHITE if Collections.owns(s, mid) else Color(1, 1, 1, 0.28))
		ic.tooltip_text = I18n.t(Collections.name_key(mid))
		ic.mouse_filter = Control.MOUSE_FILTER_PASS
		icons.add_child(ic)
	v.add_child(icons)
	v.add_child(UIK.bar(float(progress[0]) / float(max(1, progress[1])), "xp", 200, 3))
	if Collections.set_complete(s, sid):
		if s.captain.collectionSets.has(sid):
			v.add_child(UIK.label(I18n.t("codex.collection_claimed"), "GoodLabel"))
		else:
			v.add_child(UIK.button(I18n.t("codex.collection_claim"),
				func(): act(Actions.claim_collection_set(Game.state, sid)), "ui_relic", "PrimaryButton"))
	else:
		v.add_child(UIK.label(I18n.t("codex.collection_incomplete"), "DimLabel"))
	return UIK.panel(v, "FlatPanel")


func _chart_row(s: Dictionary, cid: String) -> Control:
	var rec: Dictionary = C.COLLECTIBLES[cid]
	var owned = s.inventory.collectibles.get(cid)
	var used: bool = owned is Dictionary and bool(owned.get("used", false))
	var loc_id := String(rec.get("locationId", ""))
	var row := UIK.hbox([UIK.icon(Collections.icon(cid)), UIK.label(I18n.t(Collections.name_key(cid)), "", true, 150)], 4)
	if used:
		row.add_child(UIK.label(I18n.t("codex.collection_chart_used"), "DimLabel"))
		return UIK.panel(row, "FlatPanel")
	var here_ok: bool = s.world.currentLocationId == loc_id
	var tip := "" if here_ok else I18n.t("codex.collection_chart_here", {"place": "loc.%s.name" % loc_id})
	row.add_child(UIK.button(I18n.t("codex.collection_use_chart"),
		func(): act(Actions.use_chart(Game.state, cid)), "ui_chart", "FlatButton", here_ok, tip))
	return UIK.panel(row, "FlatPanel")
