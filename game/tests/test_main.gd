## Headless test entry point. Run with:
##   godot --headless --path game res://tests/test_main.tscn
extends Node


func _ready() -> void:
	var t := TestKit.new()
	TestContent.run(t)
	TestCombat.run(t)
	TestBestiary.run(t)
	TestCollections.run(t)
	TestSaveMigration.run(t)
	TestRoutes.run(t)
	TestSite.run(t)
	TestUiLoad.run(t)
	var ok := t.finish()
	get_tree().quit(0 if ok else 1)
