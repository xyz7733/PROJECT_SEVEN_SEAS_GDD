## The weather is presentation only, but it must be stable: the same seed,
## region and watch always give the same sky, every region has a climate,
## the rolls follow the climate weights, spells hold for a few watches, the
## first morning of a new game is fair and an open storm event shows a storm.
class_name TestWeather
extends RefCounted


static func run(t: TestKit) -> void:
	_test_climates(t)
	_test_determinism(t)
	_test_distribution(t)
	_test_spells(t)
	_test_state(t)


static func _test_climates(t: TestKit) -> void:
	for r in C.REGIONS:
		t.ok(Weather.CLIMATE.has(String(r.id)), "region %s has a climate" % r.id)
	for rid in Weather.CLIMATE:
		t.ok(C.region(String(rid)) != null, "climate %s names a real region" % rid)
		var total := 0
		for k in Weather.CLIMATE[rid]:
			t.ok(k in Weather.KINDS, "climate %s uses a known sky (%s)" % [rid, k])
			t.ok(WeatherLayer.LOOKS.has(k), "sky %s has a look" % k)
			total += int(Weather.CLIMATE[rid][k])
		t.eq(total, 100, "climate %s weights add up to 100" % rid)
	for k in Weather.KINDS:
		t.ok(I18n.has("sky." + k), "sky %s has a name" % k)


static func _test_determinism(t: TestKit) -> void:
	var same := true
	for w in range(2, 60):
		if Weather.roll(4242, "stormbelt", w) != Weather.roll(4242, "stormbelt", w):
			same = false
	t.ok(same, "the same seed, region and watch give the same sky")
	var differ := false
	for w in range(2, 60):
		if Weather.roll(4242, "stormbelt", w) != Weather.roll(777, "stormbelt", w):
			differ = true
	t.ok(differ, "another seed gives other weather")
	for w in range(0, Weather.FAIR_UNTIL):
		t.eq(Weather.roll(4242, "stormbelt", w), "clear", "watch %d of a new game is fair" % w)


static func _test_distribution(t: TestKit) -> void:
	for rid in ["dawnwater", "stormbelt", "emberreach"]:
		var table: Dictionary = Weather.CLIMATE[rid]
		var seen := {}
		var n := 0
		for seed_value in range(1, 41):
			for w in range(6, 106):
				var k := Weather.roll(seed_value * 7919, rid, w)
				seen[k] = int(seen.get(k, 0)) + 1
				n += 1
		for k in seen:
			t.ok(table.has(k), "%s only rolls its own skies (%s)" % [rid, k])
		for k in table:
			var share := 100.0 * float(seen.get(k, 0)) / float(n)
			t.near(share, float(table[k]), "%s rolls %s about %d%% of watches" % [rid, k, table[k]], 4.0)


static func _test_spells(t: TestKit) -> void:
	var keeps := 0
	var n := 0
	for seed_value in range(1, 41):
		for w in range(3, 100):
			n += 1
			if Weather.roll(seed_value, "leviathan_ring", w) == Weather.roll(seed_value, "leviathan_ring", w - 1):
				keeps += 1
	var share := 100.0 * float(keeps) / float(n)
	# Held watches plus fresh rolls that happen to match (about 25% here).
	t.ok(share > float(Weather.HOLD) and share < 75.0, "weather holds for a few watches (%.0f%% repeat)" % share)


static func _test_state(t: TestKit) -> void:
	var s := GS.create_new_game(3301)
	t.eq(Weather.region_here(s), String(C.region_of(String(s.world.currentLocationId)).id), "the sky is the home region's")
	t.eq(Weather.now(s), "clear", "a new game starts under a clear sky")
	s.envelope.gameClock = 14 + 24 * 3
	var k := Weather.now(s)
	t.ok(k in Weather.KINDS, "a later watch rolls a known sky")
	s.voyage = {"route": {"to": String(s.world.currentLocationId)}, "event": {"kind": "weather", "regionId": "dawnwater"}}
	t.eq(Weather.now(s), "storm", "an open storm event shows a storm")
	s.voyage = null
	Weather.forced = "fog"
	t.eq(Weather.now(s), "fog", "the harness can force a sky")
	Weather.forced = ""
	t.eq(Weather.now(s), k, "clearing the override restores the roll")
	t.ok(Weather.wet("rain") and Weather.wet("storm") and not Weather.wet("fog"), "only rain and storms are wet")


## Exercise the real deck selector and scene wiring: the weather must stop
## on the very first frame below a roof, even during a lightning flash.
static func run_views(t: TestKit, host: Node) -> void:
	var old_state: Dictionary = Game.state
	var old_settings: Dictionary = Settings.values.duplicate(true)
	var old_forced := Weather.forced
	var old_locale := I18n.locale()
	Game.state = GS.create_new_game(3301)
	Settings.values.guide = false
	Settings.values.weather = true
	Weather.forced = "storm"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	host.add_child(main)
	# Give audio players their normal frame update between stage/deck
	# changes; starting and stopping all of them within _ready skips it.
	await host.get_tree().process_frame
	var wx: WeatherLayer = main.weather
	wx._process(0.1)
	t.ok(not wx.under and not wx._streaks.is_empty(), "storm rain reaches the open deck")
	wx._strike(1.0)
	t.ok(wx._flash.visible, "lightning is visible before going below deck")
	main.ship_view.set_view_level(1)
	t.ok(wx.under, "the real deck selector shelters the lower deck immediately")
	t.ok(wx._streaks.is_empty() and wx._splashes.is_empty(), "no outdoor rain remains below deck")
	t.eq(float(wx._k.fog), 0.0, "outdoor fog stops immediately below deck")
	t.ok(not wx._flash.visible and wx._flash.color.a == 0.0, "an active lightning flash stops below deck")
	t.eq(Audio._wx_id, "|0", "the weather audio bed fades out below deck")
	await host.get_tree().process_frame
	main.ship_view.set_view_level(0)
	wx._process(0.1)
	t.ok(not wx.under and not wx._streaks.is_empty(), "returning to the open deck restores rain")
	t.eq(Audio._wx_id, "storm|0", "returning to the open deck restores the storm bed")
	await host.get_tree().process_frame
	Weather.forced = "ash"
	main._update_weather()
	wx._process(1.0)
	t.ok(not wx._flakes.is_empty(), "ash reaches the open deck")
	main.ship_view.set_view_level(2)
	t.ok(wx.under and wx._flakes.is_empty(), "the hold also shelters from falling ash")
	await host.get_tree().process_frame
	main.free()
	Game.state = old_state
	Game._layout_tx = -1
	Settings.values = old_settings
	Weather.forced = old_forced
	I18n.set_locale(old_locale)
	Ambience.sky = "clear"
	GameWindow.hud_insets = false
	Audio.weather("")
	Audio.music("")
	Audio.ambience("")
	for player in host.get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		(player as AudioStreamPlayer).stop()
	# Stop() retires playbacks asynchronously on the audio thread. Allow a
	# full mix interval before quitting, as the screenshot harness does.
	await host.get_tree().create_timer(0.25, true, false, true).timeout
