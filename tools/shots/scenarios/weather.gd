extends RefCounted
## Every sky on the main stages: the port by day under each weather, a
## stormy night with a lightning flash, the open sea in rain, an island in
## fog and land fights in rain and underground (where no weather shows).
## The sky is forced through Weather.forced; the real rolls are covered by the
## core tests.
##
## Run with tests/shots.tscn (see README, "Screenshot harness").


func run(h) -> void:
	await h.new_game(7)
	await h.wait(2.0)
	for sky in ["cloudy", "rain", "storm", "fog", "ash"]:
		await _sky(h, sky, 1.6)
		await h.shot("port_" + sky)
	Game.state.envelope.gameClock = 23
	h.main.ship_view.refresh()
	await _sky(h, "storm", 2.0)
	h.main.weather._strike(1.0)
	await h.wait(0.03)
	await h.shot("port_storm_night_flash")
	await h.wait(1.0)
	await h.shot("port_storm_night")
	Game.state.envelope.gameClock = 8
	h.main.ship_view.refresh()

	await _sky(h, "rain", 0.2)
	h.main.depart("gull_rock")
	await h.wait(1.8)
	await h.shot("sailing_rain")
	await h.wait(2.4)
	var fights := 0
	while Game.where() == "battle" and fights < 4:
		fights += 1
		await h.wait(1.5)
		if fights == 1:
			await h.shot("sea_battle_rain")
		if h.main.battle_view:
			h.main.battle_view.skip_to_end()
		await h.wait(4.0)
		if h.main._report != null:
			h.main._on_report_resolved({"recruit": false})
			await h.wait(3.5)
	await h.wait(5.0)
	await _sky(h, "fog", 1.6)
	await h.shot("island_fog")

	await _battle(h, "gull_rock", "landing", "rain", "island_battle_rain")
	await _battle(h, "old_lookout", "guardian", "storm", "dungeon_battle_storm")
	Weather.forced = ""


func _sky(h, sky: String, secs: float) -> void:
	Weather.forced = sky
	h.main._sky_stage = ""
	h.main._update_weather()
	await h.wait(secs)


func _battle(h, loc_id: String, room_id: String, sky: String, label: String) -> void:
	var d: Dictionary = Game.state
	Weather.forced = sky
	var def := World.encounter_for(loc_id, room_id)
	Actions.start_encounter(d, def, {"type": "room", "locationId": loc_id, "roomId": room_id})
	h.main._lock = 0
	h.main._sync_world()
	await h.wait(4.5)
	await h.shot(label)
	h.main._free_stage_views()
	d.encounter = null
	h.main._sync_world()
	await h.wait(0.3)
