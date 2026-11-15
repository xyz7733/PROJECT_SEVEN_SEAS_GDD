extends RefCounted
## Exercise the shipped title Quit handler rather than the harness cleanup.
## Its result is the runner's process status and shutdown log; the process
## exits before the harness can write its usual final JSON.

func run(h) -> void:
	var button := _find_button(h.main.title_root, I18n.t("title.quit"))
	h.check("Title Quit button found", button != null)
	if button == null:
		return
	await h.shot("title_before_normal_quit")
	var point: Vector2 = button.get_viewport().get_screen_transform() * button.get_global_transform_with_canvas() * (button.size * 0.5)
	h.record("normal_ui_quit_requested", {"text": button.text, "physicalPoint": str(point),
		"method": "Godot Input mouse button on the shipped title Quit control; Audio.quit_cleanly handler",
		"audio": h._audio_scope, "result": "Read runner exit status and runtime shutdown log"})
	var f := FileAccess.open(h.out_dir.path_join("quit-ui-evidence.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"device": h._device(), "checks": h.checks,
			"events": h.evidence, "requested": true, "completion": "External runner exit/log"}, "\t"))
	await h.click(point)
	await h.wait(2.0)
	h.check("Normal title Quit should have terminated the process", false)
	h._finish(2)


func _find_button(node: Node, wanted: String) -> Button:
	if node is Button and node.text == wanted and node.is_visible_in_tree():
		return node as Button
	for child in node.get_children():
		var result := _find_button(child, wanted)
		if result != null:
			return result
	return null
