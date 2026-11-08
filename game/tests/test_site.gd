## Leaving the landing to board the ship, and going ashore again.
class_name TestSite
extends RefCounted


static func run(t: TestKit) -> void:
	_test_leave_and_land(t)
	_test_guards(t)


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
