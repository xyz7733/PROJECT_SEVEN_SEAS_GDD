extends RefCounted
## A walk through every stage of a new game: the title, the port by day and
## by night, the lower decks, a crossing, the first island and a land fight.
## Sea encounters on the way are skipped to their report and collected.
##
## Run with tests/shots.tscn (see README, "Screenshot harness").


func run(h) -> void:
	await h.wait(3.0)
	await h.shot("title")
	await h.new_game(7)
	await h.wait(2.5)
	await h.shot("port_day")
	var sv = h.main.ship_view
	sv.set_view_level(1)
	await h.wait(1.0)
	await h.shot("gun_deck")
	sv.set_view_level(2)
	await h.wait(1.0)
	await h.shot("hold")
	sv.set_view_level(0)
	Game.state.envelope.gameClock = 23
	sv.refresh()
	await h.wait(2.5)
	await h.shot("port_night")
	Game.state.envelope.gameClock = 8
	sv.refresh()

	h.main.depart("gull_rock")
	await h.wait(1.6)
	await h.shot("sailing")
	await h.wait(2.4)
	var fights := 0
	while Game.where() == "battle" and fights < 5:
		fights += 1
		await h.wait(2.0)
		await h.shot("sea_battle_%d" % fights)
		await _finish_battle(h, "sea_report_%d" % fights)
	await h.wait(6.5)
	await h.shot("island")
	if h.main.site_view == null:
		print("tour: no island stage (where=%s)" % Game.where())
		return

	h.main._stage_zoom(1)
	await h.wait(0.5)
	await h.shot("island_zoom")
	var rooms: Array = h.main.site_view._rooms()
	await h.act(Actions.enter_room(Game.state, String(rooms[0].id)))
	await h.wait(2.0)
	await h.shot("land_battle_a")
	await h.wait(2.0)
	await h.shot("land_battle_b")
	if Game.where() == "battle":
		await _finish_battle(h, "land_report")
	await h.shot("after_battle")


func _finish_battle(h, report_name: String) -> void:
	if h.main.battle_view:
		h.main.battle_view.skip_to_end()
	await h.wait(4.0)
	await h.shot(report_name)
	if h.main._report != null:
		h.main._on_report_resolved({"recruit": false})
		await h.wait(3.5)
