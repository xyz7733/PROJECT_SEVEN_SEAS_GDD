extends RefCounted
## Supplemental fullscreen control and UI review of the shipped game.
## UI inputs use Godot's native Input route; transactions are labelled API.
## No Windows input injection, campaign progression fixture or resource cheat.

var audit_cases := 0
var overflow_cases := []
var _failure_shots := 0


func run(h) -> void:
	h.record("controls_scope", {"method": "Native engine Input and labelled public transaction/API calls", "organic_campaign": false,
		"state": "Fresh seed7; normal starting resources; all writes in isolated user profile"})
	Settings.set_value("locale", "en")
	I18n.set_locale("en")
	Settings.set_value("textScale", 1.0)
	await _recreate_main(h)
	await h.new_game(7)
	Guide.restart()
	await h.wait(0.8)
	h.check("controls fullscreen mode", h.main.get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN])
	h.check("new-game guide visible", h.main.guide._card.is_visible_in_tree())
	h.record("new_game_guide", {"step": h.main.guide._step, "card": str(h.main.guide._card.get_global_rect()), "target": str(h.main.guide._anchor)})
	await h.shot("controls_guide_new_game")
	await _decks_and_camera(h)
	await _chart_and_guide(h)
	await _build_pet_and_crew(h)
	await _save_roundtrip(h)
	await _all_window_layouts(h)
	Settings.set_value("textScale", 1.0)
	Settings.set_value("locale", "zh_CN")
	I18n.set_locale("zh_CN")
	await _recreate_main(h)
	h.record("controls_summary", {"windowTabCases": audit_cases, "overflowCases": overflow_cases,
		"nineManagementWindows": true, "battleReport": "Separate encounter surface; reviewed by campaign scenario",
		"osMouseOrSpeakerAssessment": "Not performed"})
	await h.shot("controls_end")


func _recreate_main(h) -> void:
	# The product intentionally restarts its UI on language changes. Rebuild
	# the main scene too, so constructor labels are not a mixed-language fixture.
	h.main._close_all_windows()
	h.main.queue_free()
	await h.frames(3)
	h.main = load("res://scenes/main.tscn").instantiate()
	h.add_child(h.main)
	await h.frames(8)


func _point(control: Control) -> Vector2:
	# Input.parse_input_event consumes containing-window screen pixels.
	# Official feeding-custom-input formula includes the viewport stretch.
	# https://docs.godotengine.org/en/stable/tutorials/2d/2d_transforms.html
	return control.get_viewport().get_screen_transform() * control.get_global_transform_with_canvas() * (control.size * 0.5)


func _click_control(h, control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return false
	var logical: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	var physical := _point(control)
	var target_name := String(control.name)
	h.record("input_point_mapping", {"control": target_name, "logical": str(logical), "windowPixels": str(physical),
		"canvasScreenTransform": str(control.get_screen_transform()), "viewportScreenTransform": str(control.get_viewport().get_screen_transform()),
		"windowPosition": str(control.get_window().position), "windowSize": str(control.get_window().size),
		"viewport": str(control.get_viewport().get_visible_rect().size)})
	await h.click(physical)
	await h.frames(5)
	if is_instance_valid(control):
		h.record("input_point_outcome", {"control": target_name, "viewportMouse": str(control.get_viewport().get_mouse_position()),
			"localMouse": str(control.get_local_mouse_position()), "targetSize": str(control.size)})
	else:
		h.record("input_point_outcome", {"control": target_name, "targetRebuiltAfterAction": true})
	return true


func _button_text(root: Node, text: String) -> Variant:
	for node in root.find_children("*", "Button", true, false):
		if node.text == text and node.is_visible_in_tree():
			return node
	return null


func _decks_and_camera(h) -> void:
	var hud = h.main.hud
	var sv = h.main.ship_view
	await _click_control(h, hud._level_toggle)
	h.check("deck list opens through native Input click", hud._level_expanded)
	await h.shot("controls_deck_list_open")
	if hud._level_buttons.size() > 1:
		await _click_control(h, hud._level_buttons[1])
		await h.wait(1.1)
		h.check("deck selection changes visible level", sv.view_level == 1)
		h.check("deck selection collapses list", not hud._level_expanded)
		h.check("deck guide progresses", Guide.is_done("levels"))
		await h.shot("controls_interior_selected")
	await h.key(KEY_PAGEDOWN)
	await h.wait(0.2)
	h.check("PageDown reaches hold", sv.view_level == 2)
	await h.shot("controls_hold_keyboard")
	await h.key(KEY_PAGEUP)
	await h.wait(0.2)
	h.check("PageUp returns interior", sv.view_level == 1)
	var before: float = sv.cam.zoom.x
	await h.key(KEY_EQUAL)
	await h.wait(0.3)
	h.check("zoom keyboard increases camera scale", sv.cam.zoom.x > before)
	await h.key(KEY_MINUS)
	await h.wait(0.3)
	h.check("zoom keyboard restores camera scale", is_equal_approx(sv.cam.zoom.x, before))
	var camera_before: Vector2 = sv.cam.position
	var down := InputEventKey.new()
	down.keycode = KEY_D
	down.physical_keycode = KEY_D
	down.pressed = true
	Input.parse_input_event(down)
	await h.wait(0.2)
	var up := InputEventKey.new()
	up.keycode = KEY_D
	up.physical_keycode = KEY_D
	up.pressed = false
	Input.parse_input_event(up)
	await h.frames(3)
	h.record("camera_pan_input", {"before": str(camera_before), "after": str(sv.cam.position), "moved": camera_before.distance_to(sv.cam.position) > 0.1})
	sv.fit_view()
	await h.wait(0.2)
	await _click_control(h, hud._level_toggle)
	await h.key(KEY_ESCAPE)
	h.check("Escape collapses deck list", not hud._level_expanded)
	h.check("Escape deck dismissal does not open System", not h.main.windows.has("system"))
	h.record("deck_and_camera", {"input": "Godot Input click/key", "levelCount": sv.level_count(), "finalLevel": sv.view_level, "zoom": sv.cam.zoom.x})


func _chart_and_guide(h) -> void:
	h.main._close_all_windows()
	await h.key(KEY_M)
	await h.wait(0.4)
	h.check("chart hotkey opens window", h.main.windows.has("chart"))
	if not h.main.windows.has("chart"):
		return
	var chart = h.main.windows.chart
	var row = h.main.guide._dest_button(chart)
	if row != null:
		await _click_control(h, row)
	else:
		# This fallback is recorded; it does not establish a working hit target.
		chart.pick("gull_rock", true)
		h.record("chart_destination_api_fallback", {"reason": "guide target did not expose a visible destination row"})
	await h.wait(0.4)
	h.check("chart selects Gull Rock", chart.sel == "gull_rock")
	var sail = h.main.guide._sail_button()
	h.check("chart exposes Sail footer", sail != null and sail.is_visible_in_tree())
	if sail != null:
		var host: Rect2 = Rect2(Vector2.ZERO, h.main.ui_root.size)
		h.check("Sail footer is inside fullscreen UI", host.grow(1.0).encloses(sail.get_global_rect()))
		if h.main.guide._card.is_visible_in_tree():
			h.check("guide avoids Sail hit target", not h.main.guide._card.get_global_rect().intersects(sail.get_global_rect()))
		h.record("chart_sail_button", {"enabled": not sail.disabled, "rect": str(sail.get_global_rect()), "guideStep": h.main.guide._step})
	await h.shot("controls_chart_selected_guide")
	await h.key(KEY_ESCAPE)
	await h.frames(5)
	h.check("Escape closes chart", not h.main.windows.has("chart"))
	Settings.set_value("guide", false)


func _build_pet_and_crew(h) -> void:
	var sv = h.main.ship_view
	var invalid: Dictionary = Actions.build_facility(Game.state, "hatchery", 0, 3, 2, 0)
	h.check("management room rejected on weather deck", not invalid.ok and invalid.reasonKey == "err.zone_interior")
	var spot = Rules.find_spot(Game.state.ship, "hatchery")
	h.check("starter has safe hatchery placement", spot != null)
	if spot != null:
		sv.begin_build("hatchery")
		await h.frames(4)
		h.check("building mode chooses interior", sv.view_level > 0)
		var rotation: int = sv.place_rot
		await h.key(KEY_R)
		h.check("R rotates build preview", sv.place_rot != rotation)
		await h.shot("controls_hatchery_rotate_preview")
		await h.key(KEY_R)
		var built: Dictionary = Actions.build_facility(Game.state, "hatchery", int(spot.deck), int(spot.x), int(spot.y), int(spot.rot))
		var uid := String(built.get("value", ""))
		var ok: bool = await h.act(built)
		h.check("hatchery commits through normal build transaction", ok)
		sv.cancel_mode()
		if ok:
			await h.wait(0.4)
			h.record("build_api", {"facility": "hatchery", "uid": uid, "spot": spot, "gold": Game.state.inventory.gold, "materials": Game.state.inventory.materials})
			var next_spot = Rules.find_spot(Game.state.ship, "hatchery", uid)
			if next_spot != null:
				var moved: bool = await h.act(Actions.move_facility(Game.state, uid, int(next_spot.deck), int(next_spot.x), int(next_spot.y), int(next_spot.rot)))
				h.check("facility move transaction", moved)
			var stowed: bool = await h.act(Actions.stow_facility(Game.state, uid))
			h.check("facility stow transaction", stowed)
			var restore: bool = await h.act(Actions.move_facility(Game.state, uid, int(spot.deck), int(spot.x), int(spot.y), int(spot.rot)))
			h.check("stowed facility restores normally", restore)
			sv.select_facility(uid)
			await h.wait(0.3)
			await h.shot("controls_hatchery_inspector")
			h.main._close_all_windows()
			await h.frames(3)
			if not Game.state.inventory.eggs.is_empty():
				var egg_id := String(Game.state.inventory.eggs[0].id)
				var pet_win = h.main.open_window("pets", "hatch")
				pet_win.inputs = ["ing:fire_pepper"]
				pet_win.rebuild()
				await h.wait(0.3)
				await h.shot("controls_egg_recipe_ready")
				var before_pets: int = Game.state.pets.size()
				var hatched: bool = await h.act(Actions.hatch_egg(Game.state, egg_id, ["ing:fire_pepper"]))
				h.check("starter egg hatches through normal transaction", hatched and Game.state.pets.size() == before_pets + 1)
				if hatched:
					var pet_id := String(Game.state.pets[-1].id)
					await h.act(Actions.assign_pet(Game.state, pet_id, "companion", Game.state.crew[0].id))
					h.main.open_window("pets", "roster", pet_id)
					await h.wait(0.3)
					await h.shot("controls_pet_roster")
	h.main._close_all_windows()
	await h.frames(3)
	var food_before: int = Game.state.inventory.food
	var traded: bool = await h.act(Actions.buy_goods(Game.state, "food", null, 1))
	h.check("port food trade commits", traded and int(Game.state.inventory.food) == food_before + 1)
	var pool: Array = Rules.tavern_pool(Game.state, "brightquay")
	var best := -1
	var price := 999999
	for i in pool.size():
		if not pool[i].hired and int(pool[i].cost) < price:
			price = int(pool[i].cost)
			best = i
	if best >= 0 and price <= int(Game.state.inventory.gold):
		var previous: int = Game.state.crew.size()
		var recruited: bool = await h.act(Actions.recruit(Game.state, best))
		h.check("tavern recruit commits", recruited and Game.state.crew.size() == previous + 1)
	else:
		h.record("recruit_affordability", {"lowestCost": price, "availableGold": Game.state.inventory.gold, "result": "Normal starting budget cannot recruit after chosen hatchery purchase"})
	var crew_id := String(Game.state.crew[0].id)
	var original_slot: int = Rules.slot_of(Game.state, crew_id)
	var changed: bool = await h.act(Actions.set_formation(Game.state, 2, crew_id))
	h.check("formation assignment commits", changed and Rules.slot_of(Game.state, crew_id) == 2)
	await h.act(Actions.set_formation(Game.state, original_slot, crew_id))
	var weapon = Rules.member(Game.state, crew_id).equipment.weapon
	var removed: bool = await h.act(Actions.equip(Game.state, crew_id, "weapon", null))
	var restored: bool = await h.act(Actions.equip(Game.state, crew_id, "weapon", weapon))
	h.check("equipment remove and restore commits", removed and restored and Rules.member(Game.state, crew_id).equipment.weapon == weapon)
	h.main.open_window("crew", "formation")
	await h.wait(0.3)
	await h.shot("controls_crew_formation")
	h.record("normal_preparation_budget", {"gold": Game.state.inventory.gold, "food": Game.state.inventory.food,
		"materials": Game.state.inventory.materials, "crew": Game.state.crew.size(), "pets": Game.state.pets.size(), "method": "Public transactions, no injected wealth or progress"})
	h.main._close_all_windows()
	await h.frames(3)


func _save_roundtrip(h) -> void:
	await h.frames(5)
	var tx_before: int = Game.state.envelope.lastTxId
	var wrote: bool = Game.save_manual(0)
	h.check("manual save writes isolated slot", wrote)
	var read: Dictionary = SaveStore.read(SaveStore.manual_path(0))
	h.check("manual save hash verifies", read.status == "ok")
	if read.status == "ok":
		h.check("manual save preserves transaction", int(read.record.state.envelope.lastTxId) == tx_before)
		var saved_summary: Dictionary = SaveStore.summary_of(Game.state)
		await h.load_state(read.record.state)
		h.check("manual save reload preserves summary", SaveStore.summary_of(Game.state) == saved_summary)
		h.record("save_reload_api", {"slot": 1, "status": read.status, "tx": tx_before, "summary": saved_summary})
	var sys = h.main.open_window("system", "saves")
	await h.wait(0.3)
	await h.shot("controls_saved_slots")
	h.check("save slots render after reload", sys.body.get_child_count() > 0)
	h.main._close_all_windows()
	await h.frames(4)


func _all_window_layouts(h) -> void:
	var names := ["ship", "inspect", "crew", "pets", "port", "chart", "codex", "log", "system"]
	for locale in ["en", "zh_CN"]:
		I18n.set_locale(locale)
		Settings.set_value("locale", locale)
		await _recreate_main(h)
		for ui in [1.0, 1.25, 1.5]:
			Settings.set_value("textScale", ui)
			h.main._close_all_windows()
			await h.frames(8)
			for name in names:
				h.main._close_all_windows()
				await h.frames(3)
				var win = h.main.open_window(name)
				if win == null:
					h.check("window opens %s %s %s" % [name, locale, ui], false)
					continue
				if name == "inspect":
					win.show_selection("crew", Game.state.crew[0].id)
				if name == "chart":
					win.pick("gull_rock", true)
				# Window opening has a real-time fade; eight240Hz frames is
				# not enough to judge its opacity or text readability.
				await h.wait(0.5 if name == "inspect" else 0.25)
				var tabs: Array = win.tabs()
				if tabs.is_empty():
					tabs = [["", ""]]
				for i in tabs.size():
					var tab := String(tabs[i][0])
					win.open_tab(tab)
					await h.frames(8)
					var context := "%s/%s %s %.2f" % [name, tab, locale, ui]
					if name == "inspect":
						_diagnose_inspector(h, win, context)
					var failures: Array = _layout_problems(win, h.main.ui_root.size)
					audit_cases += 1
					h.check("fullscreen UI " + context, failures.is_empty())
					h.record("window_layout", {"case": context, "rect": str(win.get_rect()), "host": str(h.main.ui_root.size), "problems": failures})
					if not failures.is_empty():
						overflow_cases.append({"case": context, "problems": failures})
						if _failure_shots < 20:
							_failure_shots += 1
							await h.shot("controls_overflow_%s_%s_%s_%s" % [name, tab, locale, str(ui).replace(".", "_")])
					elif (locale == "en" and ui == 1.0 and i == 0) or (locale == "zh_CN" and ui == 1.5):
						await h.shot("controls_window_%s_%s_%s_%s" % [name, tab, locale, str(ui).replace(".", "_")])


func _layout_problems(win: GameWindow, host_size: Vector2) -> Array:
	var out := []
	var rect: Rect2 = win.get_rect()
	if not Rect2(Vector2.ZERO, host_size).grow(1.0).encloses(rect):
		out.append("window_outside_safe_host")
	var scroll: ScrollContainer = win._scroll
	if scroll.get_h_scroll_bar().max_value > scroll.get_h_scroll_bar().page + 1.0:
		out.append("horizontal_scroll_required")
	var content: Rect2 = scroll.get_global_rect()
	if scroll.get_v_scroll_bar().visible:
		content.size.x -= scroll.get_v_scroll_bar().size.x
	if not win.fills_body():
		for b in win.body.find_children("*", "Button", true, false):
			var r: Rect2 = b.get_global_rect()
			if r.position.x < content.position.x - 1.0 or r.end.x > content.end.x + 1.0:
				out.append("action_too_wide:" + String(b.text))
	if win._footer.visible:
		var local_host := Rect2(Vector2.ZERO, host_size).grow(1.0)
		for b in win._footer.find_children("*", "Button", true, false):
			if not local_host.encloses(b.get_global_rect()):
				out.append("footer_action_offscreen:" + String(b.text))
	return out


func _diagnose_inspector(h, win: GameWindow, context: String) -> void:
	var labels := []
	for label in win.body.find_children("*", "Label", true, false):
		labels.append({"text": String(label.text), "minimumWidth": label.get_combined_minimum_size().x,
			"rect": str(label.get_global_rect()), "wrapMode": label.autowrap_mode, "alpha": label.modulate.a})
	var title_rect: Rect2 = win._title_label.get_global_rect()
	var objective_rect: Rect2 = h.main.hud.obj_panel.get_global_rect()
	var overlaps_objective: bool = h.main.hud.obj_panel.is_visible_in_tree() and title_rect.intersects(objective_rect)
	h.check("inspector opening fade settled " + context, win.modulate.a >= 0.99)
	h.check("inspector title avoids objective " + context, not overlaps_objective)
	h.record("inspector_stable_diagnostic", {"case": context, "windowAlpha": win.modulate.a,
		"bodyAlpha": win.body.modulate.a, "titleAlpha": win._title_label.modulate.a,
		"windowRect": str(win.get_rect()), "titleRect": str(title_rect), "objectiveRect": str(objective_rect),
		"titleOverlapsObjective": overlaps_objective,
		"bodyMinimumWidth": win.body.get_combined_minimum_size().x, "scrollSize": str(win._scroll.size),
		"horizontalMax": win._scroll.get_h_scroll_bar().max_value, "horizontalPage": win._scroll.get_h_scroll_bar().page,
		"labels": labels})
