extends SceneTree
## External review entry point. Loads the unmodified shipped PCK plus an
## external harness; no review code is added to the distributed resources.

func _initialize() -> void:
	call_deferred("_start_review")

func _start_review() -> void:
	var root_dir: String = String(get_script().resource_path).get_base_dir()
	var runner = load(root_dir.path_join("harness.gd"))
	if runner == null:
		push_error("Review harness could not load")
		quit(2)
		return
	var host := Node.new()
	host.set_script(runner)
	root.add_child(host)
