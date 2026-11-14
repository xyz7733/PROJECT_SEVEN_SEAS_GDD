## Headless test entry point. Run with:
##   godot --headless --path game res://tests/test_main.tscn
extends Node


func _ready() -> void:
	var t := TestKit.new()
	var validation_root := OS.get_environment("P7S_VALIDATION_ROOT").replace("\\", "/")
	if validation_root != "":
		var isolated := OS.get_user_data_dir().replace("\\", "/").begins_with(validation_root + "/")
		if not isolated:
			push_error("Validation must use an isolated user directory: " + OS.get_user_data_dir())
			get_tree().quit(1)
			return
		print("Validation user data: " + OS.get_user_data_dir())
	TestContent.run(t)
	TestCombat.run(t)
	TestBestiary.run(t)
	TestCollections.run(t)
	TestSaveMigration.run(t)
	TestRoutes.run(t)
	TestSite.run(t)
	TestShipContact.run(t)
	TestWeather.run(t)
	await TestWeather.run_views(t, self)
	TestUiLoad.run(t)
	var ok := t.finish()
	get_tree().quit(0 if ok else 1)
