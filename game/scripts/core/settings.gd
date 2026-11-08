## Autoload "Settings": player preferences in a ConfigFile (not part of saves).
extends Node

signal changed

const PATH := "user://settings.cfg"
const DEFAULTS := {"locale": "", "textScale": 1.0, "reduceMotion": false, "pauseAtEncounterStart": false, "battleSpeed": 1,
	"masterVolume": 0.8, "musicVolume": 0.6, "ambienceVolume": 0.7, "sfxVolume": 0.8, "showRoofs": true,
	"guide": true, "guideDone": []}

var values: Dictionary = DEFAULTS.duplicate()


func _init() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in DEFAULTS:
			values[k] = cf.get_value("settings", k, DEFAULTS[k])


func get_value(k: String) -> Variant:
	return values.get(k, DEFAULTS.get(k))


func set_value(k: String, v: Variant) -> void:
	values[k] = v
	var cf := ConfigFile.new()
	for key in values:
		cf.set_value("settings", key, values[key])
	cf.save(PATH)
	changed.emit()


func has_locale() -> bool:
	return String(values.locale) != ""
