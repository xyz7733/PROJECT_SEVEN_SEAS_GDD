extends RefCounted
## Exercises the actual root Window signal connection, not an OS close click.
func run(h) -> void:
	h.check("Window close waits for application cleanup", not h.get_tree().auto_accept_quit)
	h.check("Window close is connected to bounded audio Quit", h.get_tree().root.close_requested.is_connected(Audio.quit_cleanly))
	await h.new_game(7)
	await h.wait(0.5)
	h.main._on_view_action("level:1")
	await h.wait(0.5)
	await h.shot("window_close_from_cabin")
	h.record("window_close_requested", {"method": "Root Window.close_requested signal; not OS mouse/Alt+F4",
		"audio": h._audio_scope, "result": "External runner exit status and resource log"})
	var f := FileAccess.open(h.out_dir.path_join("window-close-evidence.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"device": h._device(), "checks": h.checks, "events": h.evidence,
			"method": "Engine Window.close_requested signal; no OS close automation"}, "\t"))
	h.get_tree().root.close_requested.emit()
	await h.wait(2.0)
	h.check("Window close handler should terminate process", false)
	h._finish(2)
