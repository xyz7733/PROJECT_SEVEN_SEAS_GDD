extends SceneTree
## Compile external scenarios after the pack's autoloads are registered.
func _initialize() -> void:
	call_deferred("_check")
func _check() -> void:
	var directory: String = String(get_script().resource_path).get_base_dir()
	var failures := 0
	for filename in ["controls.gd", "campaign.gd", "catalogue.gd", "campaign_guided.gd", "combat_focus.gd", "title_quit.gd", "window_close.gd", "postgame.gd", "postgame_finale.gd", "r4_regression.gd", "fixes_regression.gd"]:
		var path := directory.path_join(filename)
		if not FileAccess.file_exists(path):
			print("[parse] MISSING ", filename)
			failures += 1
			continue
		var script := GDScript.new()
		script.source_code = FileAccess.get_file_as_string(path)
		var result := script.reload()
		print("[parse] ", filename, " ", result)
		if result != OK: failures += 1
	quit(failures)
