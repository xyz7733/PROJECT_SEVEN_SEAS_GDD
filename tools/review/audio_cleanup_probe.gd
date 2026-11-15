extends SceneTree
## Isolated ownership probe; no main scene, display interaction or save edits.

var mode := "stop"
var sequence := "title"
var tracked: Array[Dictionary] = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--mode" and i + 1 < args.size(): mode = args[i + 1]
		if args[i] == "--sequence" and i + 1 < args.size(): sequence = args[i + 1]
	call_deferred("_run")

func _run() -> void:
	var audio := root.get_node("Audio")
	if mode == "regression":
		if not _heartbeat_cases(audio):
			quit(2)
			return
	audio.scene("title")
	await create_timer(0.4).timeout
	_track(audio)
	print("[audio-probe] title ", JSON.stringify(_snapshot(audio)))
	if sequence == "cabin":
		audio.scene("port")
		await create_timer(0.4).timeout
		_track(audio)
		audio.set_sheltered(true)
		audio.play("creak")
		await create_timer(0.4).timeout
		_track(audio)
	if mode == "regression" and AudioServer.get_driver_name() == "Dummy":
		if not await _live_recovery(audio):
			audio.stop_all()
			await create_timer(0.25).timeout
			quit(2)
			return
		_track(audio)
	print("[audio-probe] before ", JSON.stringify(_snapshot(audio)))
	if mode == "quit":
		audio.tree_exiting.connect(func(): print("[audio-probe] quit_released ", JSON.stringify(_snapshot(audio))))
		audio.quit_cleanly()
		return
	audio.stop_all()
	print("[audio-probe] stopped ", JSON.stringify(_snapshot(audio)))
	await create_timer(0.25).timeout
	print("[audio-probe] after250ms ", JSON.stringify(_snapshot(audio)))
	quit()

func _heartbeat_cases(audio: Node) -> bool:
	audio.set_process(false)
	audio._last_mix_usec = -1
	audio._mix_heartbeats = 0
	audio._mixer_ready = false
	var checks: Array[Dictionary] = []
	checks.append({"case": "first sample is not progress", "pass": not audio._observe_mixer(1000000, 0.01) and not audio._mixer_ready})
	checks.append({"case": "same startup buffer does not enable output", "pass": not audio._observe_mixer(1010000, 0.02) and not audio._mixer_ready})
	checks.append({"case": "stale output stays unavailable", "pass": not audio._observe_mixer(2000000, 1.01) and not audio._mixer_ready})
	audio.scene("title")
	audio.scene("port")
	audio.set_sheltered(true)
	audio.weather("storm", -8.0)
	var playing := 0
	for child in audio.get_children():
		if child is AudioStreamPlayer and child.playing: playing += 1
	checks.append({"case": "unavailable output retains latest intent without allocating playback", "pass":
		playing == 0 and audio._cache.is_empty() and audio._music_request == "theme" and audio._amb_request == "harbor"
		and audio._wx_request == "storm" and audio._wx_muffle_request == -8.0 and audio._sheltered and audio._regional_enabled})
	checks.append({"case": "one recovered buffer is insufficient", "pass": not audio._observe_mixer(3000000, 0.001) and not audio._mixer_ready})
	checks.append({"case": "second recovered buffer enables replay", "pass": audio._observe_mixer(3010000, 0.001) and audio._mixer_ready})
	checks.append({"case": "same buffer does not replay again", "pass": not audio._observe_mixer(3011000, 0.002) and audio._mixer_ready})
	checks.append({"case": "later stall suspends new starts", "pass": not audio._observe_mixer(4000000, 0.991) and not audio._mixer_ready})
	audio._quitting = true
	audio.music("chant")
	audio.ambience("sea")
	audio.weather("rain")
	audio.scene("title")
	audio.set_sheltered(false)
	checks.append({"case": "late callbacks cannot restart during Quit", "pass": audio._music_request == "theme"
		and audio._amb_request == "harbor" and audio._wx_request == "storm" and audio._sheltered and not audio.play("creak")})
	audio._quitting = false
	audio.stop_all()
	checks.append({"case": "stop cancels deferred scene intent", "pass": audio._music_request == "" and audio._amb_request == ""
		and audio._wx_request == "" and not audio._regional_enabled})
	audio._last_mix_usec = -1
	audio._mix_heartbeats = 0
	audio._mixer_ready = false
	audio._sheltered = false
	audio.set_process(true)
	var passed := true
	for check in checks:
		print("[audio-probe] heartbeat-case ", JSON.stringify(check))
		passed = passed and check["pass"]
	return passed

func _live_recovery(audio: Node) -> bool:
	# Suspend only the readiness observer; the real Dummy backend keeps mixing.
	# This lets normal stream allocation and actual recovery be checked safely.
	audio.set_process(false)
	audio._observe_mixer(Time.get_ticks_usec(), 1.0)
	audio.scene("title")
	audio.set_sheltered(false)
	audio.weather("rain")
	var old_music: String = audio._music_id
	var dropped: bool = not audio.play("creak")
	var deferred: bool = old_music != "chant" and audio._music_request == "chant"
	audio.set_process(true)
	await create_timer(0.4).timeout
	var resumed: bool = audio._mixer_ready and audio._music_id == "chant" and audio._amb_id == "sea"
	resumed = resumed and audio._regional_key.begins_with("dawnwater|") and audio._wx_id == "rain|0"
	var check := {"case": "real mixer recovery applies latest deferred beds and drops stale SFX", "pass": dropped and deferred and resumed}
	print("[audio-probe] heartbeat-case ", JSON.stringify(check))
	return check["pass"]

func _track(audio: Node) -> void:
	for child in audio.get_children():
		if not child is AudioStreamPlayer or child.stream == null:
			continue
		var stream: AudioStream = child.stream
		var playback: AudioStreamPlayback = child.get_stream_playback() if child.has_stream_playback() else null
		var playback_id := playback.get_instance_id() if playback != null else 0
		var found := false
		for old in tracked:
			if old.id == stream.get_instance_id() and old.playback_id == playback_id: found = true
		if found: continue
		tracked.append({"id": stream.get_instance_id(), "playback_id": playback_id, "path": stream.resource_path,
			"stream": weakref(stream), "playback": weakref(playback) if playback != null else null})

func _snapshot(audio: Node) -> Dictionary:
	var players: Array = []
	for child in audio.get_children():
		if child is AudioStreamPlayer:
			players.append({"playing": child.playing, "stream": child.stream != null, "playback": child.has_stream_playback()})
	var refs: Array = []
	for old in tracked:
		var stream: RefCounted = old.stream.get_ref()
		var playback: RefCounted = old.playback.get_ref() if old.playback != null else null
		refs.append({"id": old.id, "playback_id": old.playback_id, "path": old.path, "stream_alive": stream != null, "stream_refs": stream.get_reference_count() if stream != null else 0,
			"playback_alive": playback != null, "playback_refs": playback.get_reference_count() if playback != null else 0})
	return {"mode": mode, "sequence": sequence, "backend": AudioServer.get_driver_name(), "mixer_ready": audio._mixer_ready,
		"since_last_mix": AudioServer.get_time_since_last_mix(), "to_next_mix": AudioServer.get_time_to_next_mix(),
		"players": players, "tracked": refs}
