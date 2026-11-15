## Leaving the landing to board the ship, and going ashore again.
class_name TestSite
extends RefCounted


static func run(t: TestKit) -> void:
	_test_leave_and_land(t)
	_test_guards(t)
	_test_camera_frames(t)
	_test_shore_detail(t)


## A state that has just arrived at an island: the ship is there, the party
## is ashore and the site stands at the landing.
static func _ashore_state(seed_value: int) -> Dictionary:
	var state := GS.create_new_game(seed_value)
	state.voyage = {"id": GS.next_id(state, "voy"), "originPortId": "brightquay", "at": "brightquay",
		"route": null, "event": null, "site": null}
	state.world.currentLocationId = "gull_rock"
	Actions.arrive(state, "gull_rock")
	return state


static func _test_leave_and_land(t: TestKit) -> void:
	var state := _ashore_state(6001)
	t.ok(state.voyage != null and state.voyage.site != null, "arrival puts the party ashore")
	var clock := int(state.envelope.gameClock)
	var stamina := int(state.ship.stamina)
	var food := int(state.inventory.food)
	var left := Actions.leave_site(state)
	t.ok(left.get("ok", false), "returning to the ship succeeds")
	if left.get("ok", false):
		state = left.state
	t.eq(state.voyage.site, null, "returning to the ship clears the site")
	t.eq(String(state.world.currentLocationId), "gull_rock", "the ship stays at the island")
	t.eq(int(state.envelope.gameClock), clock, "returning to the ship costs no time")
	t.eq(int(state.ship.stamina), stamina, "returning to the ship costs no stamina")
	t.eq(int(state.inventory.food), food, "returning to the ship costs no food")
	var back := Actions.land(state)
	t.ok(back.get("ok", false), "going ashore again succeeds")
	if back.get("ok", false):
		state = back.state
	t.ok(state.voyage.site != null, "landing restores the site")
	if state.voyage.site != null:
		t.eq(String(state.voyage.site.locationId), "gull_rock", "the site is the current island")
		t.eq(state.voyage.site.current, null, "the party starts at the landing")


static func _test_guards(t: TestKit) -> void:
	var docked := GS.create_new_game(6002)
	t.eq(String(Actions.leave_site(docked).get("reasonKey", "")), "err.already_docked",
		"cannot leave a site from port")
	t.eq(String(Actions.land(docked).get("reasonKey", "")), "err.already_docked",
		"cannot land without a voyage")
	var state := _ashore_state(6003)
	state.encounter = {}
	t.eq(String(Actions.leave_site(state).get("reasonKey", "")), "err.in_encounter",
		"cannot leave during a battle")
	var ashore := _ashore_state(6004)
	t.eq(String(Actions.land(ashore).get("reasonKey", "")), "err.already_ashore",
		"cannot land while already ashore")
	var left := Actions.leave_site(ashore)
	var at_sea: Dictionary = left.state
	at_sea.voyage.event = {"kind": "cache", "regionId": "dawnwater", "variant": 0}
	t.eq(String(Actions.land(at_sea).get("reasonKey", "")), "err.event_pending",
		"cannot land with a sea event pending")


## The reported islands/dungeons exceeded the former minimum 1x view.
## Check actual authored extents and landmark textures at both supported
## aspect ratios and every HUD size without constructing 80 world stages.
static func _test_camera_frames(t: TestKit) -> void:
	var sites := 0
	var overview_count := 0
	for loc_id in C.LOCATIONS:
		var loc: Dictionary = C.LOCATIONS[loc_id]
		if String(loc.type) == "port":
			continue
		sites += 1
		var profile := SceneProfiles.location(String(loc_id))
		var nodes := {}
		for id in profile.get("nodes", {}):
			nodes[id] = SceneProfiles.point(profile.nodes[id])
		var art := Art.world_landmark(String(loc.regionId), int(profile.get("landmarkVariant", 0)))
		t.ok(not art.is_empty(), "site fit has landmark art " + String(loc_id))
		if art.is_empty() or nodes.is_empty():
			continue
		var at := SceneProfiles.point(profile.landmarkPosition)
		var landmark_rect := Rect2(at - (art.anchor as Vector2), art.tex.get_size())
		var landing: Vector2 = nodes["_landing"]
		var lc := Art.uniso(landing)
		var berth := Art.iso(roundi(lc.x) - 4, roundi(lc.y) + 4) + Vector2(4, 17)
		var content := SiteView.content_rect(nodes, landmark_rect, berth)
		for viewport in [Vector2(640, 360), Vector2(640, 400)]:
			for scale_value in [1.0, 1.25, 1.5]:
				# Conservative full-width strip for HUD + two-line site title.
				var top := 50.0 * float(scale_value) + 36.0
				var bottom := 34.0 * float(scale_value)
				var safe := Rect2(Vector2(4, top), Vector2(viewport.x - 8, viewport.y - top - bottom))
				var plan := SiteView.frame_plan(content, viewport, safe)
				var z := float(plan.zoom)
				var screen := Rect2((content.position - (plan.position as Vector2)) * z + viewport * 0.5, content.size * z)
				var label := "%s %s HUD%.2f" % [loc_id, str(viewport), float(scale_value)]
				t.ok(safe.grow(0.01).encloses(screen), "site content fits safe view " + label)
				var landmark_screen := Rect2((landmark_rect.position - (plan.position as Vector2)) * z + viewport * 0.5, landmark_rect.size * z)
				t.ok(safe.grow(0.01).encloses(landmark_screen), "complete site landmark fits " + label)
				for point in nodes.values():
					t.ok(safe.grow(0.01).has_point(((point as Vector2) - (plan.position as Vector2)) * z + viewport * 0.5),
						"site room/landing contact fits " + label)
				if z < 1.0:
					overview_count += 1
		t.ok(content.encloses(landmark_rect), "site bounds retain complete skyline " + String(loc_id))
		t.ok(content.has_point(landing + Vector2(-60, -34)), "site bounds retain landing party " + String(loc_id))
	t.eq(sites, 80, "camera framing covers all 80 exploration sites")
	t.ok(overview_count > 0, "large authored sites use a genuine overview zoom")
	var huge := Rect2(-5000, -5000, 10000, 10000)
	var small_safe := Rect2(12, 94, 290, 180)
	var adaptive := SiteView.frame_plan(huge, Vector2(640, 360), small_safe)
	var adaptive_z := float(adaptive.zoom)
	var projected := Rect2((huge.position - (adaptive.position as Vector2)) * adaptive_z + Vector2(320, 180), huge.size * adaptive_z)
	t.ok(adaptive_z < float(SiteView.ZOOMS[0]), "Fit can go below a zoom step when the viewport requires it")
	t.ok(small_safe.grow(0.01).encloses(projected), "off-centre HUD safe area is preserved at adaptive zoom")


static func _test_shore_detail(t: TestKit) -> void:
	var cs := Coast.new()
	cs.setup(Rect2i(-12, -12, 25, 25), 20261114)
	cs.use_region("dawnwater")
	cs.beach_bias = 1.0
	cs.add_disk(Vector2.ZERO, 5.5)
	for x in range(-7, 8):
		cs.force_land(Vector2i(x, 0), "path")
	for x in range(-11, -7):
		cs.force_water(Vector2i(x, 4))
	cs.generate()
	var levels := cs.lvl.duplicate()
	var flags := cs.flags.duplicate()
	var one := SiteView.shore_detail_data(cs, Color("#2a6fae"), Color("#3a8fd0"), Color("#e9d58f"))
	var again := SiteView.shore_detail_data(cs, Color("#2a6fae"), Color("#3a8fd0"), Color("#e9d58f"))
	t.eq(cs.lvl, levels, "shore detail leaves all terrain levels unchanged")
	t.eq(cs.flags, flags, "shore detail preserves room/path/boat protection flags")
	t.ok(one.water_vertices.size() > 0, "shore detail builds a coastal water transition")
	t.eq(one.water_vertices, again.water_vertices, "coastal water vertices reproduce for the same seed")
	t.eq(one.water_colors, again.water_colors, "coastal shelf colours reproduce for the same seed")
	t.eq(one.shore_vertices, again.shore_vertices, "wet shore fragments reproduce for the same seed")
	t.eq(one.rocks, again.rocks, "shore rocks reproduce for the same seed")
	t.ok(one.shore_vertices.size() <= 72 * 6 and one.rocks.size() <= 12, "shore decoration has a bounded draw budget")
	for i in range(0, one.water_vertices.size(), 4):
		var centre := Vector2.ZERO
		for j in 4:
			var vertex: Vector3 = one.water_vertices[i + j]
			centre += Vector2(vertex.x, vertex.y) * 0.25
		var g := Art.uniso(centre)
		var c := Vector2i(roundi(g.x), roundi(g.y))
		t.eq(cs.level(c), Coast.WATER, "depth overlay occupies existing water only")
		t.ok(not SiteView._shore_protected(cs, c), "depth overlay keeps clear of protected routes and boat lane")
