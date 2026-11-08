## Autoload "Audio": music, ambience and sound effects on separate buses.
##
## Buses: Master <- Music, Ambience, SFX. Volumes come from Settings
## (masterVolume, musicVolume, ambienceVolume, sfxVolume; 0..1 linear).
## Music tracks are authored loops and use the stream's own loop flag.
## Ambience beds are field recordings, so they are looped by crossfading two
## players a few seconds before the end, which hides the seam.
## Effects go through a small voice pool with per-sound cooldowns, a voice
## cap, variant rotation and a slight pitch jitter so repeats stay restrained.
## Every file and its licence is listed in docs/AUDIO_LICENSES.md.
extends Node

const DIR := "res://assets/audio/"
const MUSIC := {
	"chant": "music/sailors_chant.ogg",
	"theme": "music/pirate_ship_theme.ogg",
	"battle": "music/pirates_incoming.wav",
}
## id -> [file, bed volume dB]
const AMBIENCE := {
	"sea": ["ambience/masts_whistling.ogg", -6.0],
	"harbor": ["ambience/harbor_gulls.ogg", -8.0],
	"coast": ["ambience/coast_waves_terns.ogg", -7.0],
	"cave": ["ambience/cave.ogg", -4.0],
}
## id -> [files, volume dB, cooldown s, max voices, pitch jitter]
const SFX := {
	"ui_click": [["ui_click_001.ogg"], -10.0, 0.04, 2, 0.03],
	"ui_confirm": [["ui_confirmation_001.ogg"], -8.0, 0.08, 1, 0.0],
	"ui_back": [["ui_back_001.ogg"], -8.0, 0.08, 1, 0.0],
	"ui_open": [["ui_open_001.ogg"], -11.0, 0.08, 1, 0.0],
	"ui_close": [["ui_close_001.ogg"], -10.0, 0.08, 1, 0.0],
	"ui_error": [["ui_error_001.ogg"], -8.0, 0.3, 1, 0.0],
	"ui_switch": [["ui_switch_002.ogg"], -10.0, 0.05, 1, 0.03],
	"ui_toggle": [["ui_toggle_001.ogg"], -10.0, 0.05, 1, 0.0],
	"ui_minimize": [["ui_minimize_001.ogg"], -8.0, 0.2, 1, 0.0],
	"ui_maximize": [["ui_maximize_001.ogg"], -8.0, 0.2, 1, 0.0],
	"place": [["impactWood_medium_000.ogg", "impactWood_medium_001.ogg", "impactWood_medium_002.ogg"], -5.0, 0.06, 2, 0.05],
	"demolish": [["impactPlank_medium_000.ogg", "impactPlank_medium_001.ogg"], -5.0, 0.1, 2, 0.05],
	"repair": [["impactWood_light_000.ogg", "impactWood_light_001.ogg", "impactWood_light_002.ogg"], -5.0, 0.09, 3, 0.05],
	"metal": [["metalClick.ogg"], -7.0, 0.1, 1, 0.05],
	"door_open": [["doorOpen_1.ogg"], -7.0, 0.2, 1, 0.03],
	"door_close": [["doorClose_1.ogg"], -7.0, 0.2, 1, 0.03],
	"creak": [["creak1.ogg", "creak2.ogg", "creak3.ogg"], -8.0, 0.35, 1, 0.05],
	"coins": [["handleCoins.ogg", "handleCoins2.ogg"], -6.0, 0.15, 1, 0.04],
	"page": [["bookFlip1.ogg"], -9.0, 0.12, 1, 0.05],
	"cloth": [["cloth1.ogg", "cloth2.ogg"], -7.0, 0.25, 1, 0.05],
	"bell": [["impactBell_heavy_000.ogg"], -9.0, 0.6, 1, 0.0],
	"step": [["footstep_wood_000.ogg", "footstep_wood_001.ogg", "footstep_wood_002.ogg"], -15.0, 0.14, 2, 0.06],
	"swing": [["drawKnife1.ogg", "drawKnife2.ogg"], -11.0, 0.07, 2, 0.06],
	"slash": [["knifeSlice.ogg"], -10.0, 0.08, 2, 0.06],
	"hit": [["impactPunch_medium_000.ogg", "impactPunch_medium_001.ogg", "impactPunch_medium_002.ogg"], -7.0, 0.05, 3, 0.06],
	"hit_heavy": [["impactPunch_heavy_000.ogg", "impactPunch_heavy_001.ogg"], -5.0, 0.1, 2, 0.04],
	"block": [["impactPlate_light_000.ogg"], -8.0, 0.1, 2, 0.06],
	"ko": [["impactSoft_heavy_000.ogg", "impactSoft_heavy_001.ogg"], -5.0, 0.12, 2, 0.04],
	"skill": [["jingles_HIT00.ogg", "jingles_HIT02.ogg"], -10.0, 0.3, 1, 0.0],
	"heal": [["jingles_HIT01.ogg"], -13.0, 0.4, 1, 0.0],
	"gun": [["cannon_fire.ogg"], -15.0, 0.25, 2, 0.08],
	"cannon": [["cannon_fire.ogg"], -8.0, 0.5, 1, 0.03],
	"cannon_hit": [["cannon_hit.ogg"], -9.0, 0.5, 1, 0.03],
	"splash": [["cannon_miss.ogg"], -10.0, 0.5, 1, 0.04],
	"ram": [["ship_ram.ogg"], -7.0, 1.5, 1, 0.0],
	"rowing": [["ambience/rowing_slowly.ogg"], -6.0, 2.0, 1, 0.0],
	"victory": [["stinger_victory.wav"], -4.0, 2.0, 1, 0.0],
	"defeat": [["stinger_defeat.wav"], -4.0, 2.0, 1, 0.0],
}
const VOICES := 12
const AMB_XFADE := 3.0
const MUSIC_FADE := 1.6

var _cache := {}
var _pool: Array[AudioStreamPlayer] = []
var _last := {}        # sfx id -> msec of last start
var _last_pick := {}   # sfx id -> index of last variant
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_id := ""
var _amb: Array[AudioStreamPlayer] = []
var _amb_id := ""
var _amb_cur := 0
var _amb_db := 0.0
var _duck_tw: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "Ambience", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var bi := AudioServer.bus_count - 1
			AudioServer.set_bus_name(bi, bus)
			AudioServer.set_bus_send(bi, "Master")
	_music_a = _player("Music")
	_music_b = _player("Music")
	for _i in 2:
		_amb.append(_player("Ambience"))
	for _i in VOICES:
		_pool.append(_player("SFX"))
	Settings.changed.connect(apply_volumes)
	apply_volumes()
	get_tree().node_added.connect(_on_node_added)
	Game.notice.connect(_on_notice)


func _on_notice(_text: String, tone: String) -> void:
	if tone == "error":
		play("ui_error")


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


# ---------------------------------------------------------------- volumes
func apply_volumes() -> void:
	for pair in [["Master", "masterVolume"], ["Music", "musicVolume"], ["Ambience", "ambienceVolume"], ["SFX", "sfxVolume"]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i < 0:
			continue
		var v := clampf(float(Settings.get_value(pair[1])), 0.0, 1.0)
		AudioServer.set_bus_mute(i, v <= 0.001)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


# ---------------------------------------------------------------- loading
func _load(rel: String) -> AudioStream:
	if _cache.has(rel):
		return _cache[rel]
	var path := DIR + rel
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path) as AudioStream
	_cache[rel] = s
	return s


func _looping(rel: String) -> AudioStream:
	var s := _load(rel)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(round(w.get_length() * w.mix_rate))
	return s


# ------------------------------------------------------------------ music
## Crossfades to a music track ("" for silence). Same id is a no-op.
func music(id: String) -> void:
	if id == _music_id:
		return
	_music_id = id
	var old: AudioStreamPlayer = null
	if _music_a.playing:
		old = _music_a
	elif _music_b.playing:
		old = _music_b
	var nxt: AudioStreamPlayer = _music_b if old == _music_a else _music_a
	if old != null:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -60.0, MUSIC_FADE)
		tw.tween_callback(old.stop)
	if id == "" or not MUSIC.has(id):
		return
	var s := _looping(String(MUSIC[id]))
	if s == null:
		return
	nxt.stop()
	nxt.stream = s
	nxt.volume_db = -60.0
	nxt.play()
	var tw2 := create_tween()
	tw2.tween_property(nxt, "volume_db", 0.0, MUSIC_FADE)


func music_id() -> String:
	return _music_id


## Lowers the music for a moment (used under victory/defeat stingers). The
## players are tweened rather than the bus, so the user's setting is kept.
func duck(secs := 3.0, depth_db := -14.0) -> void:
	if _duck_tw and _duck_tw.is_valid():
		_duck_tw.kill()
	var live: Array[AudioStreamPlayer] = []
	for p in [_music_a, _music_b]:
		if p.playing and p.volume_db > -30.0:
			live.append(p)
	if live.is_empty():
		return
	_duck_tw = create_tween().set_parallel(true)
	for p in live:
		_duck_tw.tween_property(p, "volume_db", depth_db, 0.25)
	_duck_tw.chain().tween_interval(secs)
	for i in live.size():
		if i == 0:
			_duck_tw.chain()
		_duck_tw.tween_property(live[i], "volume_db", 0.0, 1.2)


# --------------------------------------------------------------- ambience
## Switches the ambience bed ("" for none) with a fade.
func ambience(id: String) -> void:
	if id == _amb_id:
		return
	_amb_id = id
	for p in _amb:
		if p.playing:
			var tw0 := (p.get_meta("tw") if p.has_meta("tw") else null) as Tween
			if tw0 and tw0.is_valid():
				tw0.kill()
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -60.0, 1.5)
			tw.tween_callback(p.stop)
			p.set_meta("tw", tw)
	if id == "" or not AMBIENCE.has(id):
		return
	var s := _load(String(AMBIENCE[id][0]))
	if s == null:
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = false
	_amb_db = float(AMBIENCE[id][1])
	_amb_cur = (_amb_cur + 1) % 2
	_start_bed(_amb[_amb_cur], s, randf_range(0.0, maxf(0.0, s.get_length() * 0.5)))


func _start_bed(p: AudioStreamPlayer, s: AudioStream, from: float) -> void:
	var tw0 := (p.get_meta("tw") if p.has_meta("tw") else null) as Tween
	if tw0 and tw0.is_valid():
		tw0.kill()
	p.stop()
	p.stream = s
	p.volume_db = -60.0
	p.play(from)
	var tw := create_tween()
	tw.tween_property(p, "volume_db", _amb_db, AMB_XFADE)
	p.set_meta("tw", tw)


func _process(_delta: float) -> void:
	if _amb_id == "":
		return
	var cur := _amb[_amb_cur]
	if not cur.playing or cur.stream == null:
		return
	var left := cur.stream.get_length() - cur.get_playback_position()
	if left <= AMB_XFADE:
		var nxt := _amb[(_amb_cur + 1) % 2]
		var tw := create_tween()
		tw.tween_property(cur, "volume_db", -60.0, maxf(0.2, left))
		tw.tween_callback(cur.stop)
		cur.set_meta("tw", tw)
		_amb_cur = (_amb_cur + 1) % 2
		_start_bed(nxt, cur.stream, 0.0)


## Music and ambience for a world context ("title", "port", "at_sea",
## "site", "battle") and the location type (island, dungeon, ...).
## Exploration has no music on purpose: the ambience carries it.
func scene(where: String, loc_type := "", boarding := false) -> void:
	var cavern := loc_type in ["dungeon", "secret"]
	match where:
		"title":
			context("chant", "sea")
		"port":
			context("theme", "harbor")
		"site":
			context("", "cave" if cavern else "coast")
		"battle":
			context("battle", "sea" if boarding else ("cave" if cavern else ("harbor" if loc_type == "port" else "coast")))
		_:
			context("chant", "sea")


## Sets music and ambience for a scene context in one call.
func context(music_track: String, amb: String) -> void:
	music(music_track)
	ambience(amb)


# ---------------------------------------------------------------- effects
## Plays a sound effect by id. Returns false when skipped (cooldown or cap).
func play(id: String, vol_offset_db := 0.0, pitch := 1.0) -> bool:
	return _start(id, vol_offset_db, pitch) != null


## Plays an effect and fades it out after `secs` (used for long recordings
## such as the rowing loop under the landing transition).
func play_for(id: String, secs: float, vol_offset_db := 0.0) -> void:
	var p := _start(id, vol_offset_db, 1.0)
	if p == null:
		return
	var tw := create_tween()
	tw.tween_interval(maxf(0.0, secs - 0.8))
	tw.tween_property(p, "volume_db", -60.0, 0.8)
	tw.tween_callback(p.stop)


func _start(id: String, vol_offset_db: float, pitch: float) -> AudioStreamPlayer:
	if not SFX.has(id):
		return null
	var def: Array = SFX[id]
	var now := Time.get_ticks_msec()
	if now - int(_last.get(id, -100000)) < int(float(def[2]) * 1000.0):
		return null
	var busy := 0
	for p in _pool:
		if p.playing and String(p.get_meta("id", "")) == id:
			busy += 1
	if busy >= int(def[3]):
		return null
	var files: Array = def[0]
	var pick := randi() % files.size()
	if files.size() > 1 and pick == int(_last_pick.get(id, -1)):
		pick = (pick + 1) % files.size()
	var rel := String(files[pick])
	if not rel.contains("/"):
		rel = "sfx/" + rel
	var s := _load(rel)
	if s == null:
		return null
	_last[id] = now
	_last_pick[id] = pick
	var v := _free_voice()
	v.stream = s
	v.volume_db = float(def[1]) + vol_offset_db
	var j := float(def[4])
	v.pitch_scale = pitch * (1.0 + randf_range(-j, j))
	v.set_meta("id", id)
	v.set_meta("t", now)
	v.play()
	return v


func _free_voice() -> AudioStreamPlayer:
	var oldest: AudioStreamPlayer = _pool[0]
	for p in _pool:
		if not p.playing:
			return p
		if int(p.get_meta("t", 0)) < int(oldest.get_meta("t", 0)):
			oldest = p
	oldest.stop()
	return oldest


func stinger(victory: bool) -> void:
	duck(2.6)
	play("victory" if victory else "defeat")


## Committed transaction kind -> effect. Kinds not listed stay silent (the
## button click already confirmed them).
const TX := {
	"ship.build": "place", "ship.move": "place", "ship.stair": "place", "ship.preset_apply": "place",
	"ship.demolish": "demolish", "ship.unstair": "demolish", "ship.stow": "demolish",
	"ship.repair": "repair", "ship.upgrade": "repair", "ship.door": "door_open", "ship.hull": "creak",
	"crew.recruit": "coins", "crew.equip": "metal", "crew.treat": "cloth", "crew.respec": "page", "crew.legacy": "page",
	"eq.buy": "coins", "eq.craft": "repair", "eq.reinforce": "metal", "eq.salvage": "demolish",
	"port.buy": "coins", "port.sell": "coins", "port.invest": "coins", "port.contract_done": "coins",
	"port.quest": "page", "port.contract": "page", "main.deliver": "coins", "port.aid": "coins",
	"pet.hatch": "skill", "pet.evolve": "skill", "site.legend": "skill",
	"prod.workshop": "repair", "prod.galley": "page", "stamina.ration": "cloth", "stamina.supply": "cloth",
}


func tx(kind: String) -> void:
	if TX.has(kind):
		play(String(TX[kind]))


# ------------------------------------------------------- automatic UI cues
func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("sfx_hooked"):
		n.set_meta("sfx_hooked", true)
		(n as BaseButton).pressed.connect(_on_button.bind(n))


func _on_button(b: Variant) -> void:
	if not is_instance_valid(b):
		return
	var btn := b as BaseButton
	if btn == null:
		return
	var cue := String(btn.get_meta("sfx", ""))
	if cue == "none":
		return
	if cue == "":
		if btn is CheckButton or btn is CheckBox:
			cue = "ui_toggle"
		elif btn is OptionButton:
			cue = "ui_click"
		elif btn.toggle_mode:
			cue = "ui_switch"
		elif btn.theme_type_variation == "PrimaryButton":
			cue = "ui_confirm"
		else:
			cue = "ui_click"
	play(cue)
