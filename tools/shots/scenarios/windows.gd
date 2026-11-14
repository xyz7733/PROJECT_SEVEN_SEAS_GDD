extends RefCounted
## One screenshot of every tab of every window, from a new game in port.
## Add --locale zh_CN and --ui 1.25 or 1.5 to review the other layouts.
##
## Run with tests/shots.tscn (see README, "Screenshot harness").

const TABS := {
	"ship": ["build", "layout", "hulls", "services"],
	"crew": ["formation", "detail", "equipment", "skills", "classes"],
	"pets": ["hatch", "roster"],
	"port": ["invest", "market", "tavern", "workshop", "board", "services"],
	"chart": [""],
	"codex": ["seas", "enemies", "classes", "pets", "items", "clues", "collections"],
	"log": ["overview", "log"],
	"system": ["saves", "settings", "captain"],
}


func run(h) -> void:
	await h.new_game(7)
	await h.wait(0.6)
	for window in TABS:
		for tab in TABS[window]:
			h.main.open_window(window, tab)
			await h.wait(0.5)
			await h.shot(window if tab == "" else "%s_%s" % [window, tab])
		h.main._close_all_windows()
		await h.frames(2)
