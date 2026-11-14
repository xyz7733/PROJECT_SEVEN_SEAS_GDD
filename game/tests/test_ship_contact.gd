## Movement must update depth and deck visibility in the actor's frame,
## after the parent ShipView has already processed its own frame.
class_name TestShipContact
extends RefCounted


static func run(t: TestKit) -> void:
	_test_cell_crossing(t)
	_test_ladder_threshold(t)


## Use the real crew-creation path, including its movement-signal wiring,
## without building terrain or starting a simulation clock.
static func _view_with_crew() -> ShipView:
	var view := ShipView.new()
	view.st = GS.create_new_game(6601)
	view.st.crew = [view.st.crew[0]]
	view._level_lifts = [-48.0, -96.0]
	var n := Vector3i(0, 0, 0)
	view._reach = {n: true}
	view._rest_cells = [n]
	view._sync_crew()
	return view


static func _test_cell_crossing(t: TestKit) -> void:
	var view := _view_with_crew()
	var a: Actor = view._actors.values()[0]
	# Walk across the rear edge of the next isometric cell. Its floor key
	# jumps from -4 to 12 while the continuous foot point is near y = 8.
	a.position = ShipView.siso(0.49, 0.0)
	a.lift = 0.0
	view._apply_actor_visibility()
	var old_bias := a.depth_bias
	a.walk_path([[ShipView.siso(0.9, 0.0), 0.0]], 42.0)
	a._process(0.02)
	var floor_y := ShipView.siso(1.0, 0.0).y - 4.0
	t.ok(a.position.y + old_bias < floor_y, "crossing reproduces previous-frame floor occlusion")
	t.ok(a.position.y + a.depth_bias > floor_y, "crossing actor is drawn after its new floor in the same frame")
	t.near(a.position.y + a.depth_bias, view.deck_depth_y(a.position, 0), "movement refreshes the foot depth immediately")
	# A fitting at that cell still occludes its worker from behind. Do not
	# solve floor clipping by putting every actor in front of furnishings.
	view._fac_world[Vector3i(0, 1, 0)] = true
	view._apply_actor_visibility()
	a._process(0.01)
	var fitting_y := ShipView.siso(1.0, 0.0).y - 2.0
	t.ok(a.position.y + a.depth_bias < fitting_y, "fitting can still occlude an actor behind its contact line")
	t.eq(a.z_index, 0, "crew retain the shared contact-point y-sort layer")
	t.near(a.rig.global_position.y, a.position.y - a.lift, "sorting never moves the sprite's foot point")
	view.free()


static func _test_ladder_threshold(t: TestKit) -> void:
	var view := _view_with_crew()
	var a: Actor = view._actors.values()[0]
	a.position = ShipView.siso(0.0, 0.0)
	a.lift = -0.75
	view.view_level = 1
	view._apply_actor_visibility()
	t.ok(a.visible, "climber remains on the lower deck before reaching its hatch")
	a.walk_path([[a.position, 0.0]], 42.0)
	a._process(0.02)
	t.near(a.lift, 0.0, "climber reaches the upper floor")
	t.ok(not a.visible, "climber leaves the lower view in its arrival frame")
	t.eq(a.get_meta("lv"), 0, "climber's level metadata matches its current feet")
	view.free()
