## Parse/load check for every UI and view script. Catches syntax errors and
## broken preloads in code that the core tests never instantiate.
class_name TestUiLoad
extends RefCounted

const DIRS := ["res://scripts/ui", "res://scripts/view"]


static func run(t: TestKit) -> void:
	for dir in DIRS:
		_walk(t, dir)


static func _walk(t: TestKit, path: String) -> void:
	var d := DirAccess.open(path)
	t.ok(d != null, "missing script directory " + path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name.begins_with("."):
			name = d.get_next()
			continue
		var p := path.path_join(name)
		if d.current_is_dir():
			_walk(t, p)
		elif name.ends_with(".gd"):
			var s = load(p)
			t.ok(s != null, "failed to load " + p)
		name = d.get_next()
	d.list_dir_end()
