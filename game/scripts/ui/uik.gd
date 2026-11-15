## Small helpers for building themed native Controls in code.
class_name UIK
extends RefCounted


static func label(text: String, variation := "", autowrap := false, min_w := 0) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if autowrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = max(min_w, 60)
	elif min_w > 0:
		l.custom_minimum_size.x = min_w
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func para(text: String, variation := "DimLabel", min_w := 200) -> Label:
	return label(text, variation, true, min_w)


static func rich(bb: String, min_w := 200) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size.x = min_w
	r.text = bb
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


static func icon(name: String, tint := Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Art.icon(name)
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.custom_minimum_size = Vector2(16, 16)
	t.modulate = tint
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func tex(t: Texture2D, min_size := Vector2.ZERO) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.custom_minimum_size = min_size if min_size != Vector2.ZERO else (t.get_size() if t else Vector2(16, 16))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func button(text: String, cb: Callable, icon_name := "", variation := "", enabled := true, tip := "") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if icon_name != "":
		b.icon = Art.icon(icon_name)
		if icon_name == "ui_close":
			b.set_meta("sfx", "ui_close")
	if variation != "":
		b.theme_type_variation = variation
	b.disabled = not enabled
	if tip != "":
		b.tooltip_text = tip
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func primary(text: String, cb: Callable, icon_name := "", enabled := true, tip := "") -> Button:
	return button(text, cb, icon_name, "PrimaryButton", enabled, tip)


static func icon_button(icon_name: String, tip: String, cb: Callable, variation := "", enabled := true) -> Button:
	var b := button("", cb, icon_name, variation, enabled, tip)
	b.custom_minimum_size = Vector2(22, 22)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


static func hbox(children: Array = [], sep := 3) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	for c in children:
		if c != null:
			h.add_child(c)
	return h


static func vbox(children: Array = [], sep := 3) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	for c in children:
		if c != null:
			v.add_child(c)
	return v


static func grid(cols: int, sep := 3) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	return g


## Start with one column so a scroll body's minimum width stays bounded
## before its first layout. The grid measures card minima after theming.
static func responsive_grid(max_cols := 2, sep := 3) -> GridContainer:
	var g := preload("res://scripts/ui/responsive_grid.gd").new()
	g.max_columns = max_cols
	g.columns = 1
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	return g


static func flow(sep := 3) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", sep)
	f.add_theme_constant_override("v_separation", sep)
	return f


static func spacer(w := 0, h := 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if w == 0 and h == 0:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func panel(child: Control = null, variation := "") -> PanelContainer:
	var p := PanelContainer.new()
	if variation != "":
		p.theme_type_variation = variation
	if child:
		p.add_child(child)
	return p


static func card(children: Array, variation := "FlatPanel") -> PanelContainer:
	return panel(vbox(children, 2), variation)


static func sep() -> HSeparator:
	return HSeparator.new()


static func header(text: String, icon_name := "") -> HBoxContainer:
	var h := hbox([], 3)
	if icon_name != "":
		h.add_child(icon(icon_name))
	h.add_child(label(text, "GoldLabel"))
	return h


static func bar(frac: float, kind := "hp", w := 60, h := 6) -> ProgressBar:
	var p := ProgressBar.new()
	p.theme_type_variation = "Bar_" + kind
	p.show_percentage = false
	p.min_value = 0.0
	p.max_value = 1.0
	p.value = clampf(frac, 0.0, 1.0)
	p.custom_minimum_size = Vector2(w, h)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func stat(icon_name: String, text: String, variation := "", tip := "") -> HBoxContainer:
	var h := hbox([icon(icon_name), label(text, variation)], 2)
	if tip != "":
		h.tooltip_text = tip
		h.mouse_filter = Control.MOUSE_FILTER_PASS
	return h


static func scroll(child: Control, min_h := 120) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.custom_minimum_size.y = min_h
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


## Wrapping text asks for a comfortable minimum width, which can be more
## than a small panel (large UI scale, narrow screens) has to give. Such
## paragraphs under `n` are narrowed to `width` so they wrap instead of
## widening the panel. Vertical stacks pass their width on; a row passes on
## what its fixed children leave to its one flexible child; a two-column
## grid is read as a "key: value" table whose values wrap.
static func fit_paragraphs(n: Control, width: float) -> void:
	if width < 60.0:
		return
	if n is Label:
		var l := n as Label
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF and l.custom_minimum_size.x > width:
			l.custom_minimum_size.x = width
		return
	var kids: Array[Control] = []
	for c in n.get_children():
		if c is Control and (c as Control).visible:
			kids.append(c)
	if n is PanelContainer:
		width -= (n as PanelContainer).get_theme_stylebox("panel").get_minimum_size().x
	elif n is HBoxContainer:
		var flex := _flexible_child(kids)
		if flex == null:
			return
		width -= float(n.get_theme_constant("separation")) * (kids.size() - 1)
		for c in kids:
			if c != flex:
				width -= c.get_combined_minimum_size().x
		kids = [flex]
	elif n is GridContainer:
		var cols := (n as GridContainer).columns
		if cols == 2:
			# "key: value" table: the keys keep their width, the values wrap.
			var key_w := 0.0
			var values: Array[Control] = []
			for i in kids.size():
				if i % 2 == 0:
					key_w = maxf(key_w, kids[i].get_combined_minimum_size().x)
				else:
					values.append(kids[i])
			width -= key_w + float(n.get_theme_constant("h_separation"))
			kids = values
		elif cols != 1:
			return
	elif not (n is VBoxContainer or n is MarginContainer):
		return
	for c in kids:
		fit_paragraphs(c, width)


## The one child of a row that takes the spare width: the only expanding
## child, or failing that the only wrapping label.
static func _flexible_child(kids: Array[Control]) -> Control:
	var expanding: Array[Control] = []
	var wrapping: Array[Control] = []
	for c in kids:
		if c.size_flags_horizontal & Control.SIZE_EXPAND:
			expanding.append(c)
		if c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
			wrapping.append(c)
	if expanding.size() == 1:
		return expanding[0]
	if expanding.is_empty() and wrapping.size() == 1:
		return wrapping[0]
	return null


static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


static func cost_text(c: Variant) -> String:
	if c == null:
		return ""
	var parts := []
	if int(c.get("gold", 0)) > 0:
		parts.append("%s %s" % [I18n.fmt_num(c.gold), I18n.t("status.gold")])
	if int(c.get("materials", 0)) > 0:
		parts.append("%s %s" % [I18n.fmt_num(c.materials), I18n.t("status.materials")])
	if int(c.get("food", 0)) > 0:
		parts.append("%s %s" % [I18n.fmt_num(c.food), I18n.t("status.food")])
	if int(c.get("supplies", 0)) > 0:
		parts.append("%s %s" % [I18n.fmt_num(c.supplies), I18n.t("status.supplies")])
	if c.get("specialty") != null and c.specialty is Array:
		parts.append("%d %s" % [int(c.specialty[1]), I18n.t("spec.%s.name" % c.specialty[0])])
	return " · ".join(parts) if parts.size() else I18n.t("ui.free")


## Button row that behaves like tabs. Returns the container; `on_pick(id)`.
static func tab_row(ids: Array, labels: Array, current: String, on_pick: Callable, icons: Array = []) -> HBoxContainer:
	var h := hbox([], 1)
	var group := ButtonGroup.new()
	for i in ids.size():
		var b := Button.new()
		b.text = String(labels[i])
		b.theme_type_variation = "TabButton"
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		if i < icons.size() and String(icons[i]) != "":
			b.icon = Art.icon(icons[i])
		b.button_pressed = String(ids[i]) == current
		b.pressed.connect(on_pick.bind(ids[i]))
		h.add_child(b)
	return h


static func option(items: Array, current: Variant, on_pick: Callable) -> OptionButton:
	## items: [[id, text], ...]
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	var sel := 0
	for i in items.size():
		o.add_item(String(items[i][1]), i)
		o.set_item_metadata(i, items[i][0])
		if items[i][0] == current:
			sel = i
	o.select(sel)
	o.item_selected.connect(func(i): on_pick.call(o.get_item_metadata(i)))
	return o


static func color_hex(c: Color) -> String:
	return "#" + c.to_html(false)


## Small animated sprite inside a framed box: a sailor (look dict), a pet
## or an enemy. kind: "crew" | "pet" | "enemy".
static func portrait(kind: String, data: Variant, box := Vector2(28, 36), framed := true) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = box
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.clip_contents = true
	var a := Actor.new()
	match kind:
		"crew":
			a.setup_puppet(Art.crew_look(data))
		"pet":
			var info := Art.creature_info(Art.pet_key(data) if data is Dictionary else String(data))
			if info.is_empty():
				info = Art.creature_info("reef_crab")
			a.setup_creature(info)
		"enemy":
			a.setup_enemy(String(data))
		"look":
			a.setup_puppet(data)
	a.shadow.visible = false
	a.position = Vector2(round(box.x / 2.0), box.y - 3)
	holder.add_child(a)
	if not framed:
		return holder
	var p := PanelContainer.new()
	p.theme_type_variation = "PortraitPanel"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(holder)
	return p


static func line_edit(text: String, placeholder: String, on_submit: Callable, max_len := 18, w := 110) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = placeholder
	e.max_length = max_len
	e.custom_minimum_size.x = w
	e.text_submitted.connect(func(v): on_submit.call(v))
	e.focus_exited.connect(func(): if e.text != text: on_submit.call(e.text))
	return e


## Compact row of a sailor's six attributes (icon + value) for cards. Each
## value is coloured by its band and has the full breakdown as a tooltip.
static func attr_strip(m: Dictionary, sep := 5) -> HFlowContainer:
	var f := flow(sep)
	var tot := Attrs.totals(m)
	var tips := []
	for a in Attrs.IDS:
		var v := int(tot[a])
		var h := hbox([icon(Attrs.ICONS[a]), label(str(v), Fmt.attr_variation(v))], 1)
		h.tooltip_text = Fmt.attr_tip(m, a)
		h.mouse_filter = Control.MOUSE_FILTER_PASS
		f.add_child(h)
		tips.append(Fmt.attr_name(a) + " " + str(v))
	f.tooltip_text = " · ".join(tips)
	f.mouse_filter = Control.MOUSE_FILTER_PASS
	return f
