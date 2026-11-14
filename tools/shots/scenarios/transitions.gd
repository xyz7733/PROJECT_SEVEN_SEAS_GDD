extends RefCounted
## Stage changes caught mid-sweep (see Curtain): setting sail, a sea fight
## starting and ending, landing on an island, going back to the title and
## into the game, and the crossfade used with "reduceMotion". It also saves
## the frozen frame the curtain holds next to a screenshot of it on screen,
## so the two can be compared pixel for pixel (no colour shift).
##
## Run with tests/shots.tscn (see README, "Screenshot harness").

const MID := 0.2


func run(h) -> void:
	Settings.set_value("reduceMotion", false)
	await h.new_game(7)
	await h.wait(1.5)
	var cur: Curtain = h.main.curtain
	cur.cover()
	cur._tw.kill()
	cur._set_progress(0.0)
	cur._rect.texture.get_image().save_png("%s/held_frame.png" % h.out_dir)
	await h.wait(0.6)
	await h.shot("held_on_screen")
	cur._done()
	await h.wait(0.3)

	h.main.depart("gull_rock")
	await h.wait(MID)
	await h.shot("depart_sweep")
	await h.wait(3.6)
	var fights := 0
	while Game.where() == "battle" and fights < 4:
		fights += 1
		if fights == 1:
			await h.shot("sea_battle_settled")
		if h.main.battle_view:
			h.main.battle_view.skip_to_end()
		await h.wait(3.0)
		if h.main._report != null:
			h.main._on_report_resolved({"recruit": false})
			await h.wait(1.0)
			h.main._after_report(null)
			if fights == 1:
				await h.wait(MID)
				await h.shot("after_report_sweep")
		await h.wait(4.0)
	for _i in 300:
		if h.main.site_view != null:
			break
		await h.frames(1)
	await h.wait(0.15)
	await h.shot("landing_sweep")
	await h.wait(2.0)

	h.main.to_title()
	await h.wait(MID)
	await h.shot("to_title_sweep")
	await h.wait(1.5)
	h.main.start_new_game()
	await h.wait(MID)
	await h.shot("enter_game_sweep")
	await h.wait(1.5)

	Settings.set_value("reduceMotion", true)
	var def := World.encounter_for("gull_rock", "landing")
	Actions.start_encounter(Game.state, def, {"type": "room", "locationId": "gull_rock", "roomId": "landing"})
	h.main._lock = 0
	h.main._sync_world()
	await h.wait(0.1)
	await h.shot("battle_fade_reduce_motion")
	await h.wait(1.0)
	Settings.set_value("reduceMotion", false)
	h.main._free_stage_views()
	Game.state.encounter = null
	h.main._sync_world()
	await h.wait(0.3)
