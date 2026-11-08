## Input actions, registered with the engine's InputMap at start-up so the
## bindings live in one readable place.
class_name Controls
extends RefCounted

const KEYS := {
	"pan_left": [KEY_A, KEY_LEFT],
	"pan_right": [KEY_D, KEY_RIGHT],
	"pan_up": [KEY_W, KEY_UP],
	"pan_down": [KEY_S, KEY_DOWN],
	"zoom_in": [KEY_EQUAL, KEY_KP_ADD],
	"zoom_out": [KEY_MINUS, KEY_KP_SUBTRACT],
	"rotate": [KEY_R],
	"deck_next": [KEY_TAB],
	"toggle_sails": [KEY_H],
	"cancel": [KEY_ESCAPE],
	"battle_pause": [KEY_SPACE],
	"speed_1": [KEY_1],
	"speed_2": [KEY_2],
	"speed_4": [KEY_3, KEY_4],
	"open_build": [KEY_B],
	"open_crew": [KEY_C],
	"open_chart": [KEY_M],
	"open_pets": [KEY_P],
	"open_port": [KEY_O],
	"open_codex": [KEY_K],
	"open_log": [KEY_L],
	"fullscreen": [KEY_F11],
}


static func install() -> void:
	for action in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("pan_drag"):
		InputMap.add_action("pan_drag")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_MIDDLE
		InputMap.action_add_event("pan_drag", mb)
