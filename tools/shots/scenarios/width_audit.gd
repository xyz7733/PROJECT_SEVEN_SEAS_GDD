extends RefCounted
## Prints one line per window tab: "ok" when the content fits the window's
## width, "OVERFLOW" with the widest offending controls when the player would
## have to scroll sideways. Takes no screenshots. Run it once per language
## and UI size (--locale zh_CN, --ui 1.25, --ui 1.5).
##
## The layout suite (tests/test_ui_layout.tscn) asserts the same thing; this
## scenario is for finding out which control is too wide.
##
## Run with tests/shots.tscn (see README, "Screenshot harness").

func _widest(n: Control, limit: float, depth: int, out: Array) -> void:
	var ms := n.get_combined_minimum_size()
	if ms.x <= limit:
		return
	var kids := 0
	for c in n.get_children():
		if c is Control and (c as Control).get_combined_minimum_size().x > limit:
			kids += 1
			_widest(c, limit, depth + 1, out)
	if kids == 0:
		var txt := n.get_class()
		if n is Label:
			txt += " '" + (n as Label).text.left(36) + "'"
		elif n is Button:
			txt += " '" + (n as Button).text.left(36) + "'"
		var kidtxt := []
		for c in n.get_children():
			if c is Control and (c as Control).visible:
				var cc := c as Control
				var d: String = cc.get_class() + ("*" if cc.size_flags_horizontal & Control.SIZE_EXPAND else "")
				if cc is Label:
					d += "'" + (cc as Label).text.left(14) + "'" + ("~" if (cc as Label).autowrap_mode != 0 else "")
				elif cc is Button:
					d += "'" + (cc as Button).text.left(14) + "'"
				kidtxt.append("%s=%d" % [d, int(cc.get_combined_minimum_size().x)])
		out.append("%s min_w=%d {%s}" % [txt, int(ms.x), ", ".join(kidtxt)])

func _check(h, wname: String, tab: String, tag := "") -> void:
	var w = h.main.open_window(wname, tab)
	if w == null:
		print("SKIP ", wname, " ", tab)
		return
	await h.frames(4)
	var sc: ScrollContainer = w._scroll
	var vb := sc.get_v_scroll_bar()
	var avail := sc.size.x - (vb.size.x if vb.visible else 0.0)
	var need: float = w.body.get_combined_minimum_size().x
	if need > avail + 0.5 and not w.fills_body():
		var out := []
		_widest(w.body, avail, 0, out)
		print("OVERFLOW %s/%s%s need=%d avail=%d :: %s" % [wname, tab, tag, int(need), int(avail), " | ".join(out.slice(0, 4))])
	else:
		print("ok %s/%s%s need=%d avail=%d" % [wname, tab, tag, int(need), int(avail)])

func run(h) -> void:
	await h.new_game(7)
	await h.wait(0.5)
	var plan := {
		"crew": ["formation", "detail", "equipment", "skills", "classes"],
		"pets": ["hatch", "roster"],
		"port": ["invest", "market", "tavern", "workshop", "board", "services"],
		"codex": ["seas", "enemies", "classes", "pets", "items", "clues", "collections"],
		"log": ["overview", "log"],
		"system": ["saves", "settings", "captain"],
		"ship": ["layout", "hulls", "services"],
		"chart": [""],
	}
	for wname in plan:
		for tab in plan[wname]:
			await _check(h, wname, tab)
		h.main._close_all_windows()
		await h.frames(2)
	for c in C.data.FACILITY_CATEGORIES:
		var w = h.main.open_window("ship", "build")
		w.cat = c
		await _check(h, "ship", "build", ":" + c)
	h.main._close_all_windows()
