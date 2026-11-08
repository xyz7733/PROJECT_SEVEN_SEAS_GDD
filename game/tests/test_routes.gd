## Route projection, scout intel and expansion shop stock.
class_name TestRoutes
extends RefCounted


static func run(t: TestKit) -> void:
	_test_route(t)
	_test_scout(t)
	_test_shop(t)


static func _test_route(t: TestKit) -> void:
	var state := GS.create_new_game(5001)
	var info := Rules.route_info(state, "gull_rock", false)
	t.eq(int(info.supplies), int(state.inventory.supplies), "route shows current supplies")
	t.eq(int(info.suppliesAfter), int(state.inventory.supplies), "route projects supplies after")
	t.eq(bool(info.scout), false, "fresh crew has no scout")
	t.eq(info.intel, {}, "no scout means no intel")


static func _test_scout(t: TestKit) -> void:
	var state := GS.create_new_game(5002)
	var scout := GS.make_recruit(9001, {"classId": "navigator", "originId": "dawnwater_fishers"})
	scout.id = GS.next_id(state, "crew")
	state.crew.append(scout)
	state.formation[0] = scout.id
	t.ok(Rules.scout_active(state), "navigator is a scout")
	var info := Rules.route_info(state, "gull_rock", false)
	t.eq(bool(info.scout), true, "route reports scout")
	t.ok(info.intel.get("exact", false), "scout intel is exact")
	t.ok(info.intel.get("threats", []).size() > 0, "threat tags present")
	t.ok(String(info.intel.get("rare", "")) != "", "rare sighting present")
	t.ok(info.intel.get("seaKinds", []).size() > 0, "sea event odds present")
	var again := Rules.route_info(state, "gull_rock", false)
	t.eq(var_to_bytes(info), var_to_bytes(again), "route info is deterministic")
	scout.injured = true
	t.eq(Rules.scout_active(state), false, "injured scout supplies no intel")


static func _test_shop(t: TestKit) -> void:
	var state := GS.create_new_game(5003)
	var port_id := ""
	for pid in C.PORTS:
		if String(C.PORTS[pid].regionId) == "grand_horizon":
			port_id = String(pid)
			break
	t.ok(port_id != "", "grand horizon has a port")
	if port_id == "":
		return
	state.world.ports[port_id].tracks.market = 3
	var stock := Rules.shop_items(state, port_id)
	t.ok(stock.has("x_w_blade_4"), "expansion equipment appears at market level 3")
	t.ok(C.ITEMS.has("x_w_blade_4"), "expansion equipment data loaded")
	var cheap := Rules.item_price("x_w_blade_4")
	t.ok(cheap > 0, "expansion equipment has a price")
