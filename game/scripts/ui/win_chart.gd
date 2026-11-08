## Sea chart window: one illustrated chart of all ten seas with exploration
## fog, location markers, charted routes, the ship, the home port and the
## main objective, plus zoom, pan, fit and a legend. The side column puts the
## cost of the selected voyage first; the travel action always sits in the
## footer, which never scrolls. Geometry and fog come from SeaChart.
extends GameWindow

## View state lives on the window: every game-state change rebuilds the body,
## and the chart must keep its zoom and position across that.
var sel: Variant = null
var view: ChartView
var _side: VBoxContainer
var _side_w := 150
var _zoom := 0.0
var _center := Vector2.ZERO
var _legend := false
var _focus_sel := false
## True until the player zooms or pans: the view then re-fits the sea on
## every resize (the first resize can arrive before the window has its
## final size, and UI-size changes resize it again).
var _auto := true


func window_title() -> String:
	return I18n.t("map.title")


func window_icon() -> String:
	return "ui_map"


## As large as the free area allows: _layout clamps it between the HUD bars.
func window_size() -> Vector2:
	return Vector2(900, 560)


func fills_body() -> bool:
	return true


func select(loc_id: Variant) -> void:
	sel = loc_id
	_focus_sel = true
	_auto = true


func build(b: VBoxContainer) -> void:
	var s := st()
	if sel != null and (C.location(sel) == null or not Rules.is_known(s, String(sel))):
		sel = null
	var host_w := 640.0
	var host := get_parent() as Control
	if host != null and host.size.x > 0.0:
		host_w = host.size.x
	_side_w = 150 if host_w >= 520.0 else 126
	var row := UIK.hbox([], 4)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.add_child(row)
	var holder := UIK.panel(null, "PortraitPanel")
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view = ChartView.new()
	view.win = self
	view.custom_minimum_size = Vector2(120, 72)
	holder.add_child(view)
	row.add_child(holder)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(_side_w, 40)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side = UIK.vbox([], 3)
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_side)
	row.add_child(sc)
	_build_side()


## Selecting a destination only refreshes the side column, the footer and
## the markers; the chart itself keeps its view.
func pick(loc_id: String, focus := false) -> void:
	sel = loc_id
	pick_refresh()
	if focus and is_instance_valid(view):
		_focus_sel = true
		view.focus_on(SeaChart.loc_pos(loc_id))


func clear_pick() -> void:
	sel = null
	pick_refresh()


## The footer's buttons change with the selection, so the window is laid
## out again: it must stay inside the free area at every UI size.
func pick_refresh() -> void:
	_build_side()
	UIK.clear(_footer)
	build_footer(_footer)
	_footer.visible = _footer.get_child_count() > 0
	_layout()
	if is_instance_valid(view):
		view.marks.queue_redraw()


func current() -> String:
	return st().world.currentLocationId


func has_dest() -> bool:
	return sel != null and String(sel) != current()


static func leg_text(hours: Variant, food: Variant) -> String:
	return I18n.t("map.leg_short", {"h": hours, "f": food})


# ---------------------------------------------------------------- footer
func build_footer(f: HBoxContainer) -> void:
	var s := st()
	var status := UIK.label("", "DimLabel")
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.custom_minimum_size.x = 24
	status.clip_text = true
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	f.add_child(status)
	if s.voyage != null and s.encounter == null:
		if s.voyage.get("site") != null:
			f.add_child(UIK.button(I18n.t("map.explore_site"), func(): main.show_site(), "ui_map", "", true,
				I18n.t("site.title", {"location": "loc.%s.name" % s.voyage.site.locationId})))
		elif C.rooms(current()).size() > 0:
			f.add_child(UIK.button(I18n.t("site.land"), func(): main.land(), "loc_island", "", true, I18n.t("site.land_hint")))
	if not has_dest():
		status.text = I18n.t("map.no_selection")
		if Rules.at_port(s):
			f.add_child(UIK.button(I18n.t("home.open_port"), func(): main.open_window("port"), "ui_port"))
		f.add_child(UIK.button(I18n.t("route.sail"), Callable(), "ui_sail", "PrimaryButton", false, I18n.t("map.no_selection")))
		status.tooltip_text = status.text
		status.mouse_filter = Control.MOUSE_FILTER_PASS
		return
	var to_id := String(sel)
	var name := I18n.t("loc.%s.name" % to_id)
	if not Rules.region_unlocked(s, String(C.location(to_id).regionId)):
		status.text = name + " · " + I18n.t("err.region_locked")
		status.theme_type_variation = "WarnLabel"
		f.add_child(UIK.button(I18n.t("route.sail"), Callable(), "ui_sail", "PrimaryButton", false, I18n.t("err.region_locked")))
		return
	var info := Rules.route_info(s, to_id, false)
	var block: String = info.blockKey
	status.text = name + " · " + leg_text(info.hours, info.food)
	if block != "":
		status.text = I18n.t(block)
		status.theme_type_variation = "WarnLabel"
	status.tooltip_text = status.text
	status.mouse_filter = Control.MOUSE_FILTER_PASS
	if C.PORTS.has(to_id):
		var fb := Rules.sail_block(s, to_id, true)
		f.add_child(UIK.button(I18n.t("route.fast"), _sail.bind(to_id, true), "ui_ff", "", fb == "", I18n.t(fb) if fb != "" else I18n.t("route.fast_hint")))
	f.add_child(UIK.button(I18n.t("route.sail") + "  " + UIK.cost_text({"food": info.food}), _sail.bind(to_id, false), "ui_sail",
		"PrimaryButton", block == "", I18n.t(block) if block != "" else I18n.t("map.sail_hint", {"location": "loc.%s.name" % to_id})))


# ------------------------------------------------------------ side column
func _build_side() -> void:
	if not is_instance_valid(_side):
		return
	UIK.clear(_side)
	var w := _side_w - 12
	if has_dest():
		_dest(_side, String(sel), w)
		_voyage_card(_side, w)
	else:
		_here(_side, w)


func _here(b: VBoxContainer, w: int) -> void:
	var s := st()
	var cur := current()
	var reg: Dictionary = C.region(C.location(cur).regionId)
	b.add_child(UIK.hbox([UIK.tex(SeaChart.mark_tex("ship")), UIK.label(I18n.t("map.position"), "GoldLabel")], 3))
	b.add_child(UIK.label(Fmt.where_text(s), "", true, w))
	var home: String = String(s.world.get("lastSafePortId", ""))
	if home != "" and C.location(home) != null:
		b.add_child(UIK.hbox([UIK.tex(SeaChart.mark_tex("home")), UIK.label(I18n.t("map.home_port", {"port": "loc.%s.name" % home}), "DimLabel", true, w - 20)], 3))
	b.add_child(UIK.label(I18n.t("region.%s.name" % reg.id) + " · " + I18n.t("map.level", {"n": reg.level}), "GoldLabel", true, w))
	b.add_child(UIK.label(I18n.t("map.specialty", {"item": "spec.%s.name" % reg.specialtyId}), "DimLabel", true, w))
	if reg.get("hazard"):
		b.add_child(UIK.label(I18n.t("map.hazard", {"hazard": "hazard.%s.name" % reg.hazard}), "WarnLabel", true, w))
	if reg.get("mechanic"):
		b.add_child(UIK.label(I18n.t("mechanic.%s.name" % reg.mechanic), "WarnLabel", true, w))
	b.add_child(UIK.label(I18n.t("map.pet_family", {"family": "petfam.%s.name" % reg.petFamilyId}), "DimLabel", true, w))
	_voyage_card(b, w)
	b.add_child(UIK.sep())
	b.add_child(UIK.label(I18n.t("map.destinations", {"region": "region.%s.name" % reg.id}), "GoldLabel", true, w))
	var rows := []
	var hidden := 0
	for id in reg.locs:
		if id == cur:
			continue
		if not Rules.is_known(s, id):
			hidden += 1
			continue
		rows.append([id, Rules.leg_cost(s, cur, id)])
	rows.sort_custom(func(x, y): return int(x[1].food) < int(y[1].food) or (int(x[1].food) == int(y[1].food) and float(x[1].hours) < float(y[1].hours)))
	for r in rows:
		b.add_child(_dest_row(r[0], r[1], w))
	if rows.is_empty():
		b.add_child(UIK.label(I18n.t("map.none_known"), "DimLabel", true, w))
	if hidden:
		b.add_child(UIK.label(I18n.t("map.hidden_count", {"n": hidden}), "DimLabel", true, w))
	var others := []
	for p in Rules.known_ports(s):
		if C.location(p).regionId != reg.id:
			others.append([p, Rules.leg_cost(s, cur, p)])
	if others.size():
		others.sort_custom(func(x, y): return int(x[1].food) < int(y[1].food))
		b.add_child(UIK.label(I18n.t("map.other_seas"), "GoldLabel", true, w))
		for r in others:
			b.add_child(_dest_row(r[0], r[1], w))
	b.add_child(UIK.para(I18n.t("map.select_hint"), "DimLabel", w))


## One destination in the list: marker, name, then the leg's hours and food.
func _dest_row(id: String, leg: Dictionary, w: int) -> Control:
	var s := st()
	var bt := UIK.button(I18n.t("loc.%s.name" % id), pick.bind(id, true), "", "FlatButton")
	bt.icon = SeaChart.mark_tex(SeaChart.mark_for(s, id))
	bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
	bt.clip_text = true
	bt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bt.custom_minimum_size.x = 40
	var l: Dictionary = C.location(id)
	bt.tooltip_text = "%s · %s · %s\n%s" % [I18n.t("loctype." + l.type), I18n.t("know." + Rules.knowledge(s, id)),
		I18n.t("map.level", {"n": l.level}), leg_text(leg.hours, leg.food)]
	var cost := UIK.label(I18n.t("route.hours", {"n": leg.hours}), "DimLabel")
	var food := UIK.label(str(int(leg.food)), "BadLabel" if int(leg.food) > int(s.inventory.food) else "")
	var row := UIK.hbox([bt, cost, UIK.icon("food"), food], 1)
	row.custom_minimum_size.x = w
	return row


func _voyage_card(b: VBoxContainer, w: int) -> void:
	var s := st()
	if s.voyage == null or s.encounter != null:
		return
	b.add_child(UIK.sep())
	b.add_child(UIK.label(I18n.t("map.voyage"), "GoldLabel"))
	b.add_child(UIK.label(I18n.t("map.origin") + ": " + I18n.t("loc.%s.name" % s.voyage.originPortId), "DimLabel", true, w))
	if s.voyage.get("site") != null:
		var site_id: String = s.voyage.site.locationId
		b.add_child(UIK.label(I18n.t("map.rooms_cleared", {"n": s.world.locations[site_id].rooms.size(), "total": C.rooms(site_id).size()}), "DimLabel", true, w))
	b.add_child(UIK.label(I18n.t("home.ledger", {"gold": s.inventory.ledger.gold, "materials": s.inventory.ledger.materials}), "DimLabel", true, w))
	b.add_child(_fit_button(UIK.button(I18n.t("home.emergency_return"), _emergency_return, "ui_home", "", true, I18n.t("map.emergency_hint")), w))


## Selected destination, cost first: sailing time, food, return and
## stamina, then whatever blocks the voyage, then the details.
func _dest(b: VBoxContainer, to_id: String, w: int) -> void:
	var s := st()
	var l: Dictionary = C.location(to_id)
	var k := Rules.knowledge(s, to_id)
	b.add_child(UIK.hbox([UIK.tex(SeaChart.mark_tex(SeaChart.mark_for(s, to_id))), UIK.label(I18n.t("loc.%s.name" % to_id), "GoldLabel", true, w - 20)], 3))
	var sub := I18n.t("loctype." + l.type) + " · " + I18n.t("know." + k)
	if l.type != "port":
		sub += " · " + I18n.t("map.level", {"n": l.level})
	b.add_child(UIK.label(sub, "DimLabel", true, w))
	if not Rules.region_unlocked(s, l.regionId):
		b.add_child(UIK.para(I18n.t("map.region_locked_hint"), "WarnLabel", w))
		return
	var info := Rules.route_info(s, to_id, false)
	var is_port := C.PORTS.has(to_id)
	var card := UIK.vbox([], 1)
	var cw := w - 8
	_cost_row(card, "time", I18n.t("map.cost_time", {"n": info.hours}), "", I18n.t("route.distance"), cw)
	_cost_row(card, "food", I18n.t("map.cost_food", {"n": info.food, "after": info.foodAfter}), "BadLabel" if int(info.foodAfter) < 0 else "", I18n.t("route.food"), cw)
	_cost_row(card, "supplies", I18n.t("route.supplies_after", {"now": info.supplies, "after": info.suppliesAfter}),
		"", I18n.t("status.supplies"), cw)
	if not is_port:
		var ret := I18n.t("route.no_return")
		if info.returnPorts.size():
			ret = I18n.t("map.cost_return", {"n": info.returnFood, "port": "loc.%s.name" % info.returnPorts[0].id})
		_cost_row(card, "ui_home", ret, "" if info.returnOk else "WarnLabel", I18n.t("route.return"), cw)
		_cost_row(card, "stamina", I18n.t("map.cost_stamina", {"need": info.plannedStamina, "have": info.stamina}), "WarnLabel" if int(info.staminaAfter) < 0 else "", I18n.t("route.stamina"), cw)
	b.add_child(UIK.panel(card, "FlatPanel"))
	var block: String = info.blockKey
	if block != "":
		b.add_child(UIK.hbox([UIK.icon("ui_lock"), UIK.label(I18n.t(block), "WarnLabel", true, w - 20)], 3))
	if not info.returnOk and not is_port:
		b.add_child(UIK.hbox([UIK.icon("ui_warn"), UIK.label(I18n.t("route.return_warning"), "WarnLabel", true, w - 20)], 3))
	if info.firstDiscovery:
		b.add_child(UIK.label(I18n.t("route.first_discovery"), "GoodLabel", true, w))
	b.add_child(UIK.sep())
	b.add_child(UIK.para(I18n.t("loctype.%s.desc" % l.type), "DimLabel", w))
	if is_port:
		var tr := []
		for t in C.data.INVESTMENT_TRACKS:
			tr.append(I18n.t("track.%s.name" % t) + " " + str(Rules.port_track(s, to_id, t)))
		b.add_child(UIK.label(I18n.t("map.port_services", {"list": " · ".join(tr)}), "DimLabel", true, w))
	var rooms: Array = C.rooms(to_id)
	if rooms.size() and s.world.locations.has(to_id):
		b.add_child(UIK.label(I18n.t("map.rooms_cleared", {"n": s.world.locations[to_id].rooms.size(), "total": rooms.size()}), "DimLabel", true, w))
	var hz := I18n.t("route.unknown")
	if info.hazardsKnown:
		var names := []
		for z in info.hazards:
			names.append(I18n.t("hazard.%s.name" % z) if I18n.has("hazard.%s.name" % z) else I18n.t("mechanic.%s.name" % z))
		hz = ", ".join(names) if names.size() else I18n.t("route.none")
	b.add_child(UIK.label(I18n.t("route.hazards") + ": " + hz, "", true, w))
	var caps: Array = info.capability.map(func(r): return I18n.t("role." + r))
	b.add_child(UIK.label(I18n.t("route.capability") + ": " + ", ".join(caps), "", true, w))
	b.add_child(UIK.label(I18n.t("route.scout_yes") if info.scout else I18n.t("route.scout_no"),
		"GoodLabel" if info.scout else "DimLabel", true, w))
	if info.scout and info.intel is Dictionary:
		var intel: Dictionary = info.intel
		var threats := []
		for a in intel.get("threats", []):
			threats.append(I18n.t("archetype." + String(a)) if I18n.has("archetype." + String(a)) else String(a))
		b.add_child(UIK.label(I18n.t("route.scout_threats", {"list": ", ".join(threats)}), "DimLabel", true, w))
		if String(intel.get("rare", "")) != "":
			b.add_child(UIK.label(I18n.t("route.scout_rare", {"name": "enemy.%s.name" % intel.rare}), "WarnLabel", true, w))
		b.add_child(UIK.label(I18n.t("route.scout_hidden", {"n": int(intel.get("hiddenRooms", 0))}), "DimLabel", true, w))
		var sea := []
		for e in intel.get("seaKinds", []):
			sea.append(I18n.t("sea.%s.title" % e.kind) + " " + I18n.pct(float(e.pct)))
		if sea.size():
			b.add_child(UIK.label(I18n.t("route.scout_sea", {"list": ", ".join(sea)}), "DimLabel", true, w))
	if not is_port:
		b.add_child(UIK.label(I18n.t("route.level") + ": " + I18n.fmt_num(info.level), "WarnLabel" if float(info.level) > _avg_level() + 3.0 else "", true, w))
	if info.encounters.size():
		b.add_child(UIK.label(I18n.t("route.events_exact") if info.exact else I18n.t("route.events_rough"), "DimLabel", true, w))
		for e in info.encounters:
			var odds: String = "%d%%" % int(e.pct) if info.exact else I18n.t("odds." + ("high" if int(e.pct) >= 15 else ("mid" if int(e.pct) >= 7 else "low")))
			b.add_child(UIK.label("· " + I18n.t("sea.%s.title" % e.kind) + "  " + odds, "", true, w))
	b.add_child(_fit_button(UIK.button(I18n.t("map.clear_pick"), clear_pick, "ui_left", "FlatButton"), w))


## One cost line: icon and value, with the full name as the tooltip.
func _cost_row(box: VBoxContainer, icon_name: String, text: String, variation: String, tip: String, w: int) -> void:
	var h := UIK.hbox([UIK.icon(icon_name), UIK.label(text, variation, true, w - 18)], 2)
	h.tooltip_text = tip
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(h)


## A side-column button that never forces the column wider than `w`.
func _fit_button(bt: Button, w: int) -> Button:
	bt.clip_text = true
	bt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bt.custom_minimum_size.x = mini(w, 60)
	bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if bt.tooltip_text == "":
		bt.tooltip_text = bt.text
	return bt


func _avg_level() -> float:
	var a := Rules.active_crew(st())
	if a.is_empty():
		return 1.0
	var sum := 0.0
	for m in a:
		sum += float(m.level)
	return sum / a.size()


func _sail(to_id: String, fast: bool) -> void:
	main.depart(to_id, fast)


func _emergency_return() -> void:
	confirm(I18n.t("home.emergency_return"), I18n.t("home.emergency_hint"), func(): act(Actions.emergency_return(Game.state)))


# ================================================================ chart view
## The chart viewport: a map layer (chart art, islands, fog) moved and scaled
## as one transform, a marker layer drawn in screen space so icons and labels
## keep their size at any zoom, a toolbar and a legend. Wheel zooms at the
## cursor; any mouse button drags to pan (the left button after 4 px, so a
## click still selects).
class ChartView extends Control:
	const MAX_ZOOM := 4.0
	var win: Variant
	var zoom := 1.0
	var center := Vector2.ZERO
	var map: MapLayer
	var marks: MarkLayer
	var tools: PanelContainer
	var legend: PanelContainer
	var _legend_body: Control
	var _shown: Variant = null
	var hover: Variant = null
	var _btn := 0
	var _drag := false
	var _press := Vector2.ZERO
	var _press_center := Vector2.ZERO
	var _ready_view := false

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		map = MapLayer.new()
		map.view = self
		add_child(map)
		marks = MarkLayer.new()
		marks.view = self
		marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(marks)
		var tb := UIK.hbox([], 0)
		tb.add_child(UIK.icon_button("ui_zoom_out", I18n.t("map.tool_zoom_out"), step_zoom.bind(-1), "FlatButton"))
		tb.add_child(UIK.icon_button("ui_zoom_in", I18n.t("map.tool_zoom_in"), step_zoom.bind(1), "FlatButton"))
		tb.add_child(UIK.icon_button("ui_fit", I18n.t("map.tool_fit_sea"), _fit_sea_tool, "FlatButton"))
		tb.add_child(UIK.icon_button("ui_globe", I18n.t("map.tool_world"), _world_tool, "FlatButton"))
		tb.add_child(UIK.icon_button("ui_sail", I18n.t("map.tool_ship"), _ship_tool, "FlatButton"))
		tb.add_child(UIK.icon_button("ui_info", I18n.t("map.tool_legend"), toggle_legend, "FlatButton"))
		tools = UIK.panel(tb, "FlatPanel")
		add_child(tools)
		legend = _make_legend()
		legend.visible = win._legend
		add_child(legend)
		resized.connect(_on_resized)
		_on_resized()

	func _process(_delta: float) -> void:
		if is_visible_in_tree():
			_update_filter()
			marks.queue_redraw()

	## Chart pixels on the monitor: chart zoom x UI size x window zoom. Two or
	## more device pixels per chart pixel stay crisp (nearest); below that the
	## chart is filtered so it does not shimmer or alias. Checked every frame,
	## so F11, monitor moves and UI-size changes are picked up.
	func _update_filter() -> void:
		var vp := get_viewport()
		var dev := map.get_global_transform_with_canvas().get_scale().x
		var logical := vp.get_visible_rect().size.x
		if logical > 0.0:
			dev *= float(get_window().size.x) / logical
		var f := CanvasItem.TEXTURE_FILTER_NEAREST if dev >= 1.95 else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if map.texture_filter != f:
			map.texture_filter = f

	# ---------------------------------------------------------- transform
	func to_screen(p: Vector2) -> Vector2:
		return map.position + p * zoom

	func to_chart(p: Vector2) -> Vector2:
		return (p - map.position) / zoom

	func min_zoom() -> float:
		var cs := SeaChart.chart_size()
		if size.x <= 0.0 or size.y <= 0.0:
			return 0.1
		return minf(1.0, minf(size.x / cs.x, size.y / cs.y))

	## Above 1x the zoom is a whole number, so chart pixels stay square.
	func set_zoom(z: float) -> void:
		z = clampf(z, min_zoom(), MAX_ZOOM)
		if z > 1.0:
			z = floorf(z + 0.001)
		zoom = z

	func apply() -> void:
		var cs := SeaChart.chart_size()
		var half := size / (2.0 * zoom)
		for ax in 2:
			if half[ax] * 2.0 >= cs[ax]:
				center[ax] = cs[ax] / 2.0
			else:
				center[ax] = clampf(center[ax], half[ax], cs[ax] - half[ax])
		map.position = (size / 2.0 - center * zoom).round()
		map.scale = Vector2(zoom, zoom)
		_update_filter()
		marks.queue_redraw()
		win._zoom = zoom
		win._center = center

	## A fit just under 1x snaps to 1x: crisp chart pixels are worth a few
	## pixels of margin.
	func fit_rect(r: Rect2) -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		var z := minf(size.x / r.size.x, size.y / r.size.y)
		if z > 0.9 and z < 1.0:
			z = 1.0
		set_zoom(z)
		center = r.get_center()
		apply()

	## The player took over the view: stop re-fitting it on resize.
	func _manual() -> void:
		win._auto = false
		win._focus_sel = false

	## Fit the sea (of the selection, else the ship) and keep it fitted.
	func _auto_fit() -> void:
		fit_sea()
		if win._focus_sel and win.sel != null and SeaChart.has_loc(win.sel):
			focus_on(SeaChart.loc_pos(String(win.sel)))

	func _fit_sea_tool() -> void:
		win._auto = true
		win._focus_sel = false
		_auto_fit()

	func _world_tool() -> void:
		_manual()
		fit_world()

	func _ship_tool() -> void:
		_manual()
		focus_on(SeaChart.loc_pos(win.current()))

	func fit_sea() -> void:
		var id: String = String(win.sel) if win.sel != null and SeaChart.has_loc(win.sel) else win.current()
		fit_rect(SeaChart.sea_rect(String(C.location(id).regionId)).grow(6.0))

	func fit_world() -> void:
		fit_rect(Rect2(Vector2.ZERO, SeaChart.chart_size()))

	func focus_on(p: Vector2) -> void:
		center = p
		apply()

	func step_zoom(dir: int, at: Variant = null) -> void:
		_manual()
		var pivot: Vector2 = at if at is Vector2 else size / 2.0
		var cp := to_chart(pivot)
		var z := zoom
		if dir > 0:
			z = z * 1.25 if z < 1.0 else floorf(z + 0.001) + 1.0
			if zoom < 1.0 and z > 1.0:
				z = 1.0
		else:
			z = z / 1.25 if z <= 1.0 else ceilf(z - 0.001) - 1.0
		set_zoom(z)
		center = cp - (pivot - size / 2.0) / zoom
		apply()

	func toggle_legend() -> void:
		win._legend = not win._legend
		legend.visible = win._legend
		_place_overlays()
		_place_overlays.call_deferred()

	## Until the player zooms or pans, every resize re-fits the sea. After
	## that the view keeps its zoom and centre, also across the rebuilds a
	## state change causes (the window holds them).
	func _on_resized() -> void:
		if size.x < 2.0 or size.y < 2.0:
			return
		if win._auto:
			_auto_fit()
		elif not _ready_view and win._zoom > 0.0:
			set_zoom(win._zoom)
			center = win._center
			apply()
		else:
			set_zoom(zoom)
			apply()
		_ready_view = true
		_place_overlays()

	func _place_overlays() -> void:
		var ts := tools.get_combined_minimum_size()
		tools.size = ts
		tools.position = (size - ts - Vector2(3, 3)).round()
		if legend.visible:
			# The panel's own minimum gives the width; the height is the
			# content's, capped by the room above the toolbar (then it scrolls).
			var ls := legend.get_combined_minimum_size()
			var pad := legend.get_theme_stylebox("panel").get_minimum_size()
			var need := _legend_body.get_combined_minimum_size().y + pad.y
			var room := Vector2(size.x - 6.0, size.y - ts.y - 9.0)
			ls = Vector2(minf(ls.x, room.x), minf(need, room.y))
			legend.size = ls
			legend.position = Vector2(size.x - ls.x - 3.0, tools.position.y - ls.y - 3.0).round()

	func _make_legend() -> PanelContainer:
		var two: bool = win._side_w >= 150
		var entries := [["port", "loctype.port"], ["island", "loctype.island"], ["dungeon", "loctype.dungeon"],
			["wreck", "loctype.wreck"], ["arena", "loctype.arena"], ["secret", "loctype.secret"],
			["island", "map.legend_visited"], ["island_r", "map.legend_charted"], ["cleared", "map.legend_cleared"],
			["ship", "map.legend_ship"], ["home", "map.legend_home"], ["target", "map.legend_target"],
			["@route", "map.legend_route"], ["@plan", "map.legend_plan"], ["@haze", "map.legend_fog"], ["lock", "map.legend_locked"]]
		var v := UIK.vbox([], 2)
		v.add_child(UIK.label(I18n.t("map.legend_title"), "DarkLabel"))
		var grid := UIK.grid(4 if two else 2, 3)
		for e in entries:
			grid.add_child(_legend_swatch(String(e[0])))
			grid.add_child(UIK.label(I18n.t(e[1]), "DarkLabel"))
		v.add_child(grid)
		v.add_child(UIK.label(I18n.t("map.drag_hint"), "DarkLabel", true, 110))
		_legend_body = v
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.add_child(v)
		var p := UIK.panel(sc, "LightPanel")
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		return p

	func _legend_swatch(kind: String) -> Control:
		if not kind.begins_with("@"):
			return UIK.tex(SeaChart.mark_tex(kind), Vector2(16, 16))
		var sw := Swatch.new()
		sw.kind = kind.substr(1)
		sw.custom_minimum_size = Vector2(16, 16)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return sw

	# -------------------------------------------------------------- input
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			var mb := e as InputEventMouseButton
			if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
				step_zoom(1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1, mb.position)
				accept_event()
				return
			if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
				if mb.pressed:
					if _btn == 0:
						_btn = mb.button_index
						_press = mb.position
						_press_center = center
						_drag = mb.button_index != MOUSE_BUTTON_LEFT
				elif mb.button_index == _btn:
					if not _drag and mb.button_index == MOUSE_BUTTON_LEFT:
						var h = hit(mb.position)
						if h != null:
							win.pick.call_deferred(h)
					_btn = 0
					_drag = false
					mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover != null else Control.CURSOR_ARROW
				accept_event()
		elif e is InputEventMouseMotion:
			var mm := e as InputEventMouseMotion
			if _btn != 0:
				if not _drag and mm.position.distance_to(_press) > 4.0:
					_drag = true
				if _drag:
					_manual()
					mouse_default_cursor_shape = Control.CURSOR_DRAG
					center = _press_center - (mm.position - _press) / zoom
					apply()
				accept_event()
				return
			var h = hit(mm.position)
			if h != hover:
				hover = h
				tooltip_text = _tip(h) if h != null else ""
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h != null else Control.CURSOR_ARROW
		elif e is InputEventMagnifyGesture:
			var mg := e as InputEventMagnifyGesture
			_manual()
			var cp := to_chart(mg.position)
			set_zoom(zoom * mg.factor)
			center = cp - (mg.position - size / 2.0) / zoom
			apply()
			accept_event()
		elif e is InputEventPanGesture:
			_manual()
			center += (e as InputEventPanGesture).delta * 6.0 / zoom
			apply()
			accept_event()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and hover != null:
			hover = null
			tooltip_text = ""

	func _tip(id: String) -> String:
		var s: Dictionary = Game.state
		var l: Dictionary = C.location(id)
		var out := I18n.t("loc.%s.name" % id) + "\n" + I18n.t("loctype." + l.type) + " · " + I18n.t("know." + Rules.knowledge(s, id))
		if id == win.current():
			return out + "\n" + I18n.t("map.you_are_here")
		if Rules.region_unlocked(s, String(l.regionId)):
			var leg := Rules.leg_cost(s, win.current(), id)
			out += "\n" + win.leg_text(leg.hours, leg.food)
		return out

	## Locations that have a marker: charted, in an open sea. Cached: any
	## state change rebuilds the window and with it this view.
	func shown() -> Array:
		if _shown != null:
			return _shown
		var s: Dictionary = Game.state
		var out := []
		for id in C.LOCATIONS:
			if not SeaChart.has_loc(id) or not Rules.is_known(s, id):
				continue
			if not Rules.region_unlocked(s, String(C.location(id).regionId)):
				continue
			out.append(id)
		_shown = out
		return out

	func hit(p: Vector2) -> Variant:
		var best = null
		var bd := 10.0
		for id in shown():
			var d := p.distance_to(to_screen(SeaChart.loc_pos(id)))
			if d < bd:
				bd = d
				best = id
		return best


## Chart art, the islands of charted locations and the fog, in chart pixels.
## Moving or zooming the view only changes this node's transform.
class MapLayer extends Node2D:
	var view: Variant
	var _fog: Texture2D

	func _ready() -> void:
		_fog = SeaChart.fog_texture(Game.state)
		set_process(_fog == null)

	## Waits for a background fog build, then swaps it in.
	func _process(_delta: float) -> void:
		if SeaChart.poll() or _fog == null:
			_fog = SeaChart.fog_texture(Game.state)
			if _fog != null:
				print("[chart] fog built in %d ms" % SeaChart.last_build_ms)
				set_process(false)
				queue_redraw()

	func _draw() -> void:
		var s: Dictionary = Game.state
		if s.is_empty():
			return
		var d := SeaChart.data()
		var cs := SeaChart.chart_size()
		draw_texture_rect(Art.tex(String(d.tex)), Rect2(Vector2.ZERO, cs), false)
		var isles := Art.tex(String(d.isles))
		for id in d.locs:
			if not Rules.is_known(s, id) or not Rules.region_unlocked(s, String(C.location(id).regionId)):
				continue
			var it := SeaChart.isle(id)
			draw_texture_rect_region(isles, it.dst, it.src)
		if _fog != null:
			draw_texture_rect(_fog, Rect2(Vector2.ZERO, cs), false)
		else:
			draw_texture_rect(SeaChart.fog_placeholder(), Rect2(Vector2.ZERO, cs), false)


## Markers, routes, sea names and labels in screen space (always 1:1).
class MarkLayer extends Control:
	const RED := Color8(176, 46, 38)
	var view: Variant
	var t := 0.0
	## Per-selection route info and the objective, cached for the life of
	## this layer (a state change rebuilds the window).
	var _info_id := ""
	var _info := {}
	var _obj: Variant = null

	func _route_info(s: Dictionary, id: String) -> Dictionary:
		if id != _info_id:
			_info_id = id
			_info = Rules.route_info(s, id, false)
		return _info

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(delta: float) -> void:
		t += delta

	func _draw() -> void:
		var s: Dictionary = Game.state
		if s.is_empty() or view == null:
			return
		var win = view.win
		var font: Font = Art.font
		var cur: String = s.world.currentLocationId
		var z: float = view.zoom
		var area := Rect2(Vector2.ZERO, size)
		_sea_names(s, font, area)
		# charted routes
		for key in s.world.chartedRoutes:
			var pr: PackedStringArray = String(key).split("|")
			if pr.size() != 2 or not SeaChart.has_loc(pr[0]) or not SeaChart.has_loc(pr[1]):
				continue
			if not Rules.is_known(s, pr[0]) or not Rules.is_known(s, pr[1]):
				continue
			var pts := _screen_pts(SeaChart.route_points(pr[0], pr[1]))
			_dashes(_trim(pts, 8.0, 8.0), Color(SeaChart.INK, 0.65), 1.0, 3.0, 3.0, 0.0)
		# planned route
		var plan := PackedVector2Array()
		var info := {}
		if win.has_dest() and Rules.region_unlocked(s, String(C.location(win.sel).regionId)):
			info = _route_info(s, String(win.sel))
			plan = _trim(_screen_pts(SeaChart.route_points(cur, String(win.sel))), 9.0, 11.0)
			var col := RED if info.blockKey == "" else Color8(120, 110, 100)
			_dashes(plan, Color(SeaChart.PAPER, 0.85), 4.0, 6.0, 2.0, t * 10.0)
			_dashes(plan, col, 2.0, 6.0, 2.0, t * 10.0)
			if plan.size() >= 2:
				_arrow(plan[plan.size() - 1], (plan[plan.size() - 1] - plan[plan.size() - 2]).normalized(), col)
		# markers, back to front
		var ids: Array = view.shown()
		ids.sort_custom(func(a, b): return SeaChart.loc_pos(a).y < SeaChart.loc_pos(b).y)
		var marks_tex := Art.tex(String(SeaChart.data().marks))
		if _obj == null:
			_obj = Fmt.objective(s)
		var target: Variant = _obj.get("locationId")
		var home: String = String(s.world.get("lastSafePortId", ""))
		var grown := area.grow(16.0)
		for id in ids:
			var p: Vector2 = view.to_screen(SeaChart.loc_pos(id)).round()
			if not grown.has_point(p):
				continue
			var l: Dictionary = C.location(id)
			var small: bool = z < 0.45 and l.type != "port" and id != win.sel and id != cur and id != target and id != view.hover
			if small:
				var c: Color = SeaChart.TYPE_COLORS.get(String(l.type), SeaChart.INK)
				if not Rules.is_visited(s, id):
					c = c.lerp(SeaChart.PAPER, 0.55)
				draw_rect(Rect2(p - Vector2(2, 2), Vector2(5, 5)), SeaChart.INK)
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), c)
				continue
			draw_texture_rect_region(marks_tex, Rect2(p - Vector2(8, 8), Vector2(16, 16)), SeaChart.mark_rect(SeaChart.mark_for(s, id)))
			if Rules.knowledge(s, id) == "cleared":
				draw_texture_rect_region(marks_tex, Rect2(p + Vector2(-1, -1), Vector2(16, 16)), SeaChart.mark_rect("cleared"))
			if id == home:
				draw_texture_rect_region(marks_tex, Rect2(p + Vector2(-21, -8), Vector2(16, 16)), SeaChart.mark_rect("home"))
		# selection and hover rings
		if win.sel != null and SeaChart.has_loc(win.sel) and view.shown().has(win.sel):
			var sp: Vector2 = view.to_screen(SeaChart.loc_pos(String(win.sel))).round()
			var r := 10.5 + 1.0 * sin(t * 5.0)
			draw_arc(sp, r + 1.0, 0.0, TAU, 28, Color(SeaChart.INK, 0.8), 1.0)
			draw_arc(sp, r, 0.0, TAU, 28, Color8(247, 209, 84), 1.5)
		if view.hover != null and view.hover != win.sel:
			draw_arc(view.to_screen(SeaChart.loc_pos(String(view.hover))).round(), 10.0, 0.0, TAU, 24, Color(1, 1, 1, 0.8), 1.0)
		# objective pin and ship
		if target != null and SeaChart.has_loc(target) and view.shown().has(target):
			var tp: Vector2 = view.to_screen(SeaChart.loc_pos(String(target))).round()
			var dx := -14.0 if target == cur else -8.0
			draw_texture_rect_region(marks_tex, Rect2(tp + Vector2(dx, -27 + roundf(2.0 * sin(t * 3.0))), Vector2(16, 16)), SeaChart.mark_rect("target"))
		if SeaChart.has_loc(cur):
			var shp: Vector2 = view.to_screen(SeaChart.loc_pos(cur)).round() + Vector2(4, -20 + roundf(1.5 * sin(t * 2.0)))
			draw_texture_rect_region(marks_tex, Rect2(shp, Vector2(16, 16)), SeaChart.mark_rect("ship"))
		_labels(s, font, ids, cur, target, area)
		if plan.size() >= 2 and not info.is_empty():
			_cost_tag(font, plan, info)

	func _screen_pts(pts: PackedVector2Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in pts:
			out.append(view.to_screen(p))
		return out

	## Shortens a polyline by `a` px at its start and `b` px at its end so
	## it starts and ends at the marker rims.
	func _trim(pts: PackedVector2Array, a: float, b: float) -> PackedVector2Array:
		if pts.size() < 2:
			return pts
		var out := pts.duplicate()
		var d0 := out[1] - out[0]
		if d0.length() > a:
			out[0] += d0.normalized() * a
		var n := out.size()
		var d1 := out[n - 2] - out[n - 1]
		if d1.length() > b:
			out[n - 1] += d1.normalized() * b
		return out

	## Dashed polyline; the pattern runs on across corners and moves
	## toward the end of the line as `phase` grows.
	func _dashes(pts: PackedVector2Array, col: Color, w: float, dash: float, gap: float, phase: float) -> void:
		var period := dash + gap
		var walked := 0.0
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var len := a.distance_to(b)
			if len < 0.5:
				continue
			var dir := (b - a) / len
			var x := -fposmod(walked - phase, period)
			while x < len:
				var s0 := maxf(x, 0.0)
				var s1 := minf(x + dash, len)
				if s1 > s0:
					draw_line(a + dir * s0, a + dir * s1, col, w)
				x += period
			walked += len

	func _arrow(tip: Vector2, dir: Vector2, col: Color) -> void:
		var n := Vector2(-dir.y, dir.x)
		var pts := PackedVector2Array([tip + dir * 2.0, tip - dir * 5.0 + n * 4.0, tip - dir * 5.0 - n * 4.0])
		draw_colored_polygon(pts, col)

	func _plate(r: Rect2, border: Color) -> void:
		draw_rect(r, Color(SeaChart.PAPER, 0.93))
		draw_rect(r, border, false, 1.0)

	func _text(font: Font, p: Vector2, s: String, col: Color) -> void:
		draw_string(font, p + Vector2(0, font.get_ascent(12)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)

	func _tw(font: Font, s: String) -> float:
		return ceilf(font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)

	## Sea names: an open sea's name and level stays at the top of its
	## visible part; a locked sea shows a lock, and the next one to open
	## also says how to open it.
	func _sea_names(s: Dictionary, font: Font, area: Rect2) -> void:
		var next_locked := ""
		var prev := ""
		var order := C.REGIONS.duplicate()
		order.sort_custom(func(a, b): return SeaChart.sea_index(String(a.id)) < SeaChart.sea_index(String(b.id)))
		for r in order:
			if not Rules.region_unlocked(s, String(r.id)):
				next_locked = String(r.id)
				break
			prev = String(r.id)
		var lh := 13.0
		for r in order:
			var rid := String(r.id)
			var tr := SeaChart.sea_rect(rid)
			var sr := Rect2(view.to_screen(tr.position), tr.size * view.zoom).intersection(area)
			if sr.size.x < 24.0 or sr.size.y < 14.0:
				continue
			var lines: Array = []
			var open := Rules.region_unlocked(s, rid)
			if open:
				lines.append(I18n.t("region.%s.name" % rid) + " · " + I18n.t("map.level", {"n": r.level}))
			elif rid == next_locked:
				lines.append(I18n.t("region.%s.name" % rid))
				if prev != "":
					lines.append(I18n.t("map.unlock_trial", {"region": "region.%s.name" % prev}))
				if r.get("requiresHullTier") and int(s.ship.hullTier) < int(r.requiresHullTier):
					lines.append(I18n.t("err.hull_tier", {"tier": int(r.requiresHullTier)}))
			else:
				lines.append(I18n.t("map.uncharted_sea"))
			var icon := 0.0 if open else 14.0
			var w := 0.0
			for ln in lines:
				w = maxf(w, _tw(font, ln))
			w = minf(w + icon + 6.0, sr.size.x - 4.0)
			var h := lh * lines.size() + 3.0
			var x := clampf(sr.get_center().x - w / 2.0, sr.position.x + 2.0, sr.end.x - w - 2.0)
			var y := sr.position.y + 3.0 if open else clampf(sr.get_center().y - h / 2.0, sr.position.y + 2.0, sr.end.y - h - 2.0)
			var box := Rect2(Vector2(x, y).round(), Vector2(w, h).round())
			_plate(box, SeaChart.INK if open else Color8(120, 100, 80))
			if not open:
				draw_texture_rect_region(Art.tex(String(SeaChart.data().marks)), Rect2(box.position + Vector2(1, roundf((h - 16.0) / 2.0)), Vector2(16, 16)), SeaChart.mark_rect("lock"))
			var col := SeaChart.INK if open or rid == next_locked else Color8(110, 96, 84)
			for i in lines.size():
				var ln: String = lines[i]
				var room: float = box.size.x - icon - 5.0
				if _tw(font, ln) > room:
					while ln.length() > 1 and _tw(font, ln + "…") > room:
						ln = ln.substr(0, ln.length() - 1)
					ln += "…"
				_text(font, box.position + Vector2(3.0 + icon, 1.0 + lh * i), ln, col)

	## Name labels: selected, current, hovered and objective first, then
	## ports (unless zoomed far out), then everything else from 1.5x. A label
	## that would overlap one already placed moves above its marker or is
	## left out.
	func _labels(s: Dictionary, font: Font, ids: Array, cur: String, target: Variant, area: Rect2) -> void:
		var win = view.win
		var z: float = view.zoom
		var order: Array = []
		for id in [win.sel, cur, view.hover, target]:
			if id != null and ids.has(id) and not order.has(id):
				order.append(id)
		var must := order.size()
		for id in ids:
			if order.has(id):
				continue
			if C.PORTS.has(id) and z >= 0.45:
				order.append(id)
		if z >= 1.5:
			for id in ids:
				if not order.has(id):
					order.append(id)
		var placed: Array[Rect2] = []
		for i in order.size():
			var id: String = order[i]
			var p: Vector2 = view.to_screen(SeaChart.loc_pos(id)).round()
			if not area.grow(8.0).has_point(p):
				continue
			var name := I18n.t("loc.%s.name" % id)
			var w := _tw(font, name) + 4.0
			var below := Rect2(Vector2(p.x - w / 2.0, p.y + 9.0), Vector2(w, 14.0))
			var above := Rect2(Vector2(p.x - w / 2.0, p.y - 23.0 - (18.0 if id == target or id == cur else 0.0)), Vector2(w, 14.0))
			var r := below
			if _hits(placed, r):
				r = above
				if _hits(placed, r) and i >= must:
					continue
			r.position.x = clampf(r.position.x, 1.0, size.x - r.size.x - 1.0)
			r = Rect2(r.position.round(), r.size)
			placed.append(r)
			var border := Color8(247, 209, 84) if id == win.sel else SeaChart.INK
			_plate(r, border)
			_text(font, r.position + Vector2(2, 1), name, SeaChart.INK)

	func _hits(placed: Array[Rect2], r: Rect2) -> bool:
		for q in placed:
			if q.intersects(r):
				return true
		return false

	## Cost tag at the middle of the planned route: hours and food, red when
	## the voyage is blocked or would leave the hold empty.
	func _cost_tag(font: Font, plan: PackedVector2Array, info: Dictionary) -> void:
		var total := 0.0
		for i in plan.size() - 1:
			total += plan[i].distance_to(plan[i + 1])
		if total < 30.0:
			return
		var half := total / 2.0
		var mid := plan[0]
		for i in plan.size() - 1:
			var l := plan[i].distance_to(plan[i + 1])
			if half <= l:
				mid = plan[i].lerp(plan[i + 1], half / maxf(l, 0.001))
				break
			half -= l
		var hours := I18n.t("route.hours", {"n": info.hours})
		var food := str(int(info.food))
		var w := 16.0 + _tw(font, hours) + 4.0 + 16.0 + _tw(font, food) + 4.0
		var r := Rect2((mid - Vector2(w / 2.0, 22.0)).round(), Vector2(w, 16.0))
		r.position.x = clampf(r.position.x, 1.0, size.x - w - 1.0)
		r.position.y = clampf(r.position.y, 1.0, size.y - 17.0)
		var bad := String(info.blockKey) != "" or int(info.foodAfter) < 0
		_plate(r, RED if bad else SeaChart.INK)
		var x := r.position.x
		draw_texture(Art.icon("time"), Vector2(x, r.position.y))
		x += 16.0
		_text(font, Vector2(x, r.position.y + 2.0), hours, SeaChart.INK)
		x += _tw(font, hours) + 4.0
		draw_texture(Art.icon("food"), Vector2(x, r.position.y))
		x += 16.0
		_text(font, Vector2(x, r.position.y + 2.0), food, RED if bad else SeaChart.INK)


## Legend samples that are lines or tints rather than markers.
class Swatch extends Control:
	var kind := ""

	func _draw() -> void:
		var y := size.y / 2.0
		match kind:
			"route":
				var x := 1.0
				while x < size.x - 1.0:
					draw_line(Vector2(x, y), Vector2(minf(x + 3.0, size.x - 1.0), y), SeaChart.INK, 1.0)
					x += 6.0
			"plan":
				draw_line(Vector2(1, y), Vector2(size.x - 1.0, y), Color(SeaChart.PAPER, 0.85), 4.0)
				var x := 1.0
				while x < size.x - 1.0:
					draw_line(Vector2(x, y), Vector2(minf(x + 6.0, size.x - 1.0), y), Color8(176, 46, 38), 2.0)
					x += 8.0
			"haze":
				draw_rect(Rect2(Vector2(1, 3), size - Vector2(2, 6)), Color8(74, 128, 176))
				draw_rect(Rect2(Vector2(1, 3), size - Vector2(2, 6)), Color(0.93, 0.91, 0.86, float(SeaChart.FOG_HAZE) / 255.0))
				draw_rect(Rect2(Vector2(1, 3), size - Vector2(2, 6)), SeaChart.INK, false, 1.0)
