## Headless layout regression using the real pixel font and window builders.
## Run: godot --headless --path game res://tests/test_ui_layout.tscn
extends Node

const CODEX := preload("res://scripts/ui/win_codex.gd")
const PORT := preload("res://scripts/ui/win_port.gd")
const INSPECTOR := preload("res://scripts/ui/win_inspect.gd")
## Every other window tab: its content must fit the window's width, so the
## player never has to scroll sideways to read a card or reach a button.
const FIT := [
	[preload("res://scripts/ui/win_ship.gd"), ["build", "layout", "hulls", "services"]],
	[preload("res://scripts/ui/win_crew.gd"), ["formation", "detail", "attrs", "equipment", "skills", "classes"]],
	[preload("res://scripts/ui/win_pets.gd"), ["hatch", "roster"]],
	[PORT, ["invest", "tavern", "workshop", "board", "services"]],
	[preload("res://scripts/ui/win_log.gd"), ["overview", "log"]],
	[preload("res://scripts/ui/win_system.gd"), ["saves", "settings", "captain"]],
]


func _ready() -> void:
	var t := TestKit.new()
	var previous_state: Dictionary = Game.state
	var previous_locale := I18n.locale()
	Game.state = _discovered_state()
	for logical in [Vector2(640, 360), Vector2(640, 400)]:
		for ui_scale in [1.0, 1.25, 1.5]:
			for locale in ["en", "zh_CN"]:
				I18n.set_locale(locale)
				var host := Control.new()
				host.theme = Art.theme
				host.size = (logical / ui_scale).floor()
				add_child(host)
				for tab in CODEX.TABS:
					await _check_window(t, host, CODEX, tab,
						"codex/%s %s %.2f %s" % [tab, locale, ui_scale, logical])
				# The dealer must have unowned stock to exercise buy/exchange buttons.
				var owned: Dictionary = Game.state.inventory.collectibles
				Game.state.inventory.collectibles = {}
				await _check_window(t, host, PORT, "market",
					"market %s %.2f %s" % [locale, ui_scale, logical])
				Game.state.inventory.collectibles = owned
				# Width is what these check; the taller logical size adds nothing.
				for entry in (FIT if logical.y == 360.0 else []):
					var script: Script = entry[0]
					for tab in entry[1]:
						await _check_fit(t, host, script, tab, "%s/%s %s %.2f" % [
							script.resource_path.get_file().get_basename(), tab, locale, ui_scale])
				if logical.y == 360.0:
					await _check_report(t, host, "battle report %s %.2f" % [locale, ui_scale])
				await _check_inspector(t, host, "inspector %s %.2f %s" % [locale, ui_scale, logical])
				host.free()
	await _check_grid_resize(t)
	Game.state = previous_state
	I18n.set_locale(previous_locale)
	get_tree().quit(0 if t.finish() else 1)


func _check_window(t: TestKit, host: Control, script: Script, tab: String, context: String) -> void:
	var win: GameWindow = script.new()
	host.add_child(win)
	win.open_tab(tab)
	for i in 10:
		await get_tree().process_frame
	if script == CODEX:
		t.ok(win.body.get_child_count() > 3, context + " builds tab content beyond the summary strip")
	t.ok(win.position.x >= -0.5 and win.position.y >= -0.5, context + " starts on screen")
	t.ok(win.get_rect().end.x <= host.size.x + 0.5 and win.get_rect().end.y <= host.size.y + 0.5,
		context + " ends on screen")
	var scroll: ScrollContainer = win._scroll
	var horizontal := scroll.get_h_scroll_bar()
	t.ok(horizontal.max_value <= horizontal.page + 1.0, context + " needs no horizontal scroll")
	# Vertical scrolling is intentional. Every action must fit the content
	# width, even if it starts below the currently visible rows.
	var bounds := scroll.get_global_rect()
	if scroll.get_v_scroll_bar().visible:
		bounds.size.x -= scroll.get_v_scroll_bar().size.x
	var buttons := win.body.find_children("*", "Button", true, false)
	var actions_fit := true
	for button in buttons:
		var rect: Rect2 = button.get_global_rect()
		if rect.position.x < bounds.position.x - 1.0 or rect.end.x > bounds.end.x + 1.0:
			actions_fit = false
			print("OVERFLOW ", context, " button=", button.text, " rect=", rect, " bounds=", bounds)
	t.ok(actions_fit, context + " every action fits the visible content width")
	win.free()


func _check_fit(t: TestKit, host: Control, script: Script, tab: String, context: String) -> void:
	var win: GameWindow = script.new()
	host.add_child(win)
	win.open_tab(tab)
	for i in 6:
		await get_tree().process_frame
	t.ok(win.get_rect().end.x <= host.size.x + 0.5 and win.get_rect().end.y <= host.size.y + 0.5,
		context + " ends on screen")
	var scroll: ScrollContainer = win._scroll
	var available := scroll.size.x
	if scroll.get_v_scroll_bar().visible:
		available -= scroll.get_v_scroll_bar().size.x
	var needed: float = win.body.get_combined_minimum_size().x
	if needed > available + 0.5:
		print("OVERFLOW ", context, " needs=", needed, " available=", available)
	t.ok(needed <= available + 0.5, context + " needs no horizontal scroll")
	win.free()


## The inspector must leave the objective readable and fit every stat in
## its fixed-width column, even when large UI sizes need vertical scrolling.
func _check_inspector(t: TestKit, host: Control, context: String) -> void:
	var previous_insets := Vector3(GameWindow.inset_top, GameWindow.inset_bottom, GameWindow.inset_bottom_right)
	var previous_hud_insets := GameWindow.hud_insets
	GameWindow.hud_insets = true
	var hud := Hud.new()
	host.add_child(hud)
	hud.refresh("port")
	for i in 6:
		await get_tree().process_frame
	var win := INSPECTOR.new()
	host.add_child(win)
	win.show_selection("crew", Game.state.crew[0].id)
	for i in 6:
		await get_tree().process_frame
	t.ok(hud.obj_panel.visible, context + " exercises a visible objective")
	t.ok(not win.get_rect().intersects(hud.obj_panel.get_rect()), context + " leaves the objective clear")
	t.ok(win.position.y >= hud.obj_panel.get_rect().end.y + Hud.GAP - 0.5,
		context + " starts below the objective")
	t.ok(win.get_rect().end.y <= host.size.y + 0.5, context + " ends on screen")
	var scroll: ScrollContainer = win._scroll
	var horizontal := scroll.get_h_scroll_bar()
	t.ok(horizontal.max_value <= horizontal.page + 1.0, context + " needs no horizontal scroll")
	var bounds := scroll.get_global_rect()
	if scroll.get_v_scroll_bar().visible:
		bounds.size.x -= scroll.get_v_scroll_bar().size.x
	var stats := Rules.member_stats(Game.state, Game.state.crew[0])
	var labels := win.body.find_children("*", "Label", true, false)
	for key in ["hp", "atk", "def", "spd"]:
		var text := "%s %d" % [I18n.t("stat.%s_short" % key), int(stats[key])]
		var matches := labels.filter(func(label): return label.text == text)
		t.eq(matches.size(), 1, context + " shows " + text)
		if matches.size() == 1:
			var label: Label = matches[0]
			var rect := label.get_global_rect()
			t.ok(rect.position.x >= bounds.position.x - 0.5 and rect.end.x <= bounds.end.x + 0.5
				and label.get_combined_minimum_size().x <= label.size.x + 0.5,
				context + " fits " + text)
	# Battles hide the objective; the shared window inset must release its
	# space while keeping the independently measured stage insets intact.
	hud.refresh("battle")
	for i in 6:
		await get_tree().process_frame
	win._layout()
	t.ok(not hud.obj_panel.visible, context + " hides the objective in battle")
	t.near(win.position.y, hud.top_bar_bottom + Hud.GAP, context + " releases hidden objective space", 0.5)
	win.free()
	hud.free()
	GameWindow.inset_top = previous_insets.x
	GameWindow.inset_bottom = previous_insets.y
	GameWindow.inset_bottom_right = previous_insets.z
	GameWindow.hud_insets = previous_hud_insets


## The battle report docks on the right edge. Neither its rows nor its
## footer may push it off the screen, before or after Collect.
func _check_report(t: TestKit, host: Control, context: String) -> void:
	var summary := _report_summary()
	var report := BattleReport.new()
	host.add_child(report)
	report.setup(summary, Vector2(24, 30))
	for i in 6:
		await get_tree().process_frame
	_report_on_screen(t, report, host, context)
	report.show_committed(summary)
	for i in 6:
		await get_tree().process_frame
	_report_on_screen(t, report, host, context + " after Collect")
	report.free()


func _report_on_screen(t: TestKit, report: BattleReport, host: Control, context: String) -> void:
	var rect := report.panel.get_rect()
	var fits := (rect.position.x >= -0.5 and rect.position.y >= -0.5
		and rect.end.x <= host.size.x + 0.5 and rect.end.y <= host.size.y + 0.5)
	if not fits:
		print("OVERFLOW ", context, " panel=", rect, " screen=", host.size)
	t.ok(fits, context + " stays on screen")
	t.ok(rect.size.x <= BattleReport.WIDTH + 0.5 or rect.size.x >= host.size.x - 8.5,
		context + " keeps its planned width")


## A victory with every kind of row: a rare foe, plunder, an arrival, gear,
## a new and a duplicate curio, and a recruit offer with a full roster.
func _report_summary() -> Dictionary:
	var foe: String = Bestiary.all_ids()[0]
	var curios: Array = C.COLLECTIBLES.keys()
	return {
		"outcome": "victory", "time": 123.4, "hpAvg": 0.82, "xp": 12345, "plunder": 2500,
		"arrived": "gull_rock",
		"enemies": [{"enemyId": foe, "rare": true, "variant": "armored"}],
		"rewards": {"gold": 123456, "materials": 6789},
		"ledger": [
			{"kind": "item", "id": "a", "ref": C.ITEMS.keys()[0], "icon": "ui_chest", "rarity": "epic",
				"qty": 12, "got": 12, "lost": 3, "salvaged": 2},
			{"kind": "collectible", "id": "b", "ref": curios[0], "icon": "ui_chest", "rarity": "legendary",
				"qty": 1, "got": 1, "new": true},
			{"kind": "collectible", "id": "c", "ref": curios[1], "icon": "ui_chest", "rarity": "rare",
				"qty": 1, "got": 1, "duplicate": true, "shards": 25},
			{"kind": "food", "id": "d", "ref": "", "icon": "food", "rarity": "common", "qty": 120, "got": 120},
		],
		"recruit": {"chance": 0.32, "offered": true, "accepted": false, "enemyId": foe,
			"member": Game.state.crew[0].duplicate(true), "crew": 6, "capacity": 6, "full": true},
	}


func _check_grid_resize(t: TestKit) -> void:
	var host := Control.new()
	host.theme = Art.theme
	add_child(host)
	var grid := UIK.responsive_grid(3, 4)
	for i in 6:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(140, 24)
		grid.add_child(card)
	var scroll := UIK.scroll(grid, 40)
	# Match GameWindow: AUTO keeps oversized content from setting the
	# viewport's minimum width before the responsive grid can reflow.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	host.add_child(scroll)
	for pair in [[Vector2(480, 100), 3], [Vector2(290, 100), 2], [Vector2(220, 100), 1], [Vector2(480, 100), 3]]:
		scroll.size = pair[0]
		for i in 6:
			await get_tree().process_frame
		t.eq(grid.columns, pair[1], "card grid resizes to %s" % pair[0])
	host.free()


func _discovered_state() -> Dictionary:
	var state := GS.create_new_game(20261111)
	for id in Bestiary.all_ids():
		state.codex.enemies[id] = {"seen": true, "defeated": 1234, "kills": 1234,
			"variants": ["alpha", "armored", "swift"], "regions": ["dawnwater"]}
	for id in C.ITEMS:
		state.codex.items[id] = true
		if C.ITEMS[id].get("recipe"):
			state.inventory.recipes.append(id)
	for id in C.CLASSES:
		state.codex.classes[id] = true
	for id in C.COLLECTIBLES:
		state.inventory.collectibles[id] = {"count": 1, "used": false}
	for f in C.PET_FAMILIES:
		for role in C.data.PET_ROLES:
			for evo in ["", "_evo"]:
				state.codex.pets["%s_%s%s" % [f.id, role, evo]] = {"prime": true}
	state.codex.hatchLog.append({"familyId": C.PET_FAMILIES[0].id,
		"speciesId": "%s_explorer_evo" % C.PET_FAMILIES[0].id,
		"colors": ["red", "blue", "yellow", "green", "purple", "white"], "prime": true})
	state.inventory.gold = 999999
	state.inventory.curioShards = 999999
	for track in C.data.INVESTMENT_TRACKS:
		state.world.ports.brightquay.tracks[track] = 3
	return state
