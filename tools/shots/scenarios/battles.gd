extends RefCounted
## Land battles in each kind of arena, opened directly from a new game:
## the opening shot, the fight a few seconds in, a boss intro and the
## finishing blow. Faster than the tour when only battles changed.
##
## Run with tests/shots.tscn (see README, "Screenshot harness").

## [location, room, label]
const CASES := [
	["gull_rock", "landing", "island"],
	["old_lookout", "guardian", "dungeon_boss"],
	["driftplank_wreck", "cabin", "wreck_elite"],
	["dawn_trial_ring", "trial", "trial_ring"],
	["magma_vents", "guardian", "ember_boss"],
]


func run(h) -> void:
	await h.new_game(7)
	await h.wait(1.0)
	for c in CASES:
		await _battle(h, String(c[0]), String(c[1]), String(c[2]))


func _battle(h, loc_id: String, room_id: String, label: String) -> void:
	var d: Dictionary = Game.state
	var def := World.encounter_for(loc_id, room_id)
	Actions.start_encounter(d, def, {"type": "room", "locationId": loc_id, "roomId": room_id})
	# A finished fight leaves its report's stage lock behind; start clean.
	h.main._lock = 0
	h.main._sync_world()
	await h.wait(0.35)
	await h.shot(label + "_open")
	await h.wait(1.6)
	await h.shot(label + "_intro")
	await h.wait(2.8)
	await h.shot(label + "_fight")
	var bv = h.main.battle_view
	if bv != null:
		bv.set_speed(2)
		await h.wait(9.0)
		await h.shot(label + "_late")
	h.main._free_stage_views()
	d.encounter = null
	await h.wait(0.3)
