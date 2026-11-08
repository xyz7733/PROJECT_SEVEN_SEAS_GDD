## Pixel-safe window fill (autoload "Display").
##
## Godot's built-in "integer" stretch floors window / viewport per axis and
## letterboxes the remainder. A client area even one pixel short of a
## multiple therefore drops a whole zoom step. Windows gives Godot's
## borderless fullscreen window a 1 px border, so on a 2560x1600 monitor the
## client is 2558x1598: 2558 / 640 = 3.997 was floored to 3, and the 640x400
## view filled only a centred 1920x1200 rectangle with black around it.
##
## Instead this picks the zoom for the current client size (an integer, with
## a small tolerance) and sizes the logical viewport so that it covers the
## whole client: content_scale_size = ceil(client / zoom). The project uses
## fractional canvas_items stretch with aspect "expand", so whatever is left
## of the scale error is below the tolerance and the same on both axes:
## no bars, and no non-uniform sprite stretch. Exact multiples (1280x720,
## 1920x1080, 2560x1440, 2560x1600, 3840x2160) render at exactly 2x, 3x,
## 4x, 4x and 6x. A wider or taller window shows more of the world; every
## view covers the logical viewport with its own ocean and lays out the HUD
## from the actual viewport size.
extends Node

## Design size: the smallest logical view the HUD and windows are laid out
## for at 1x UI size.
const BASE := Vector2i(640, 360)
## A client this fraction short of the next zoom step still gets that step
## (covers window borders and odd monitor sizes). The logical view is then
## at most this much smaller than BASE.
const TOLERANCE := 0.03

## Current integer zoom (screen pixels per logical pixel, before the
## sub-percent fill correction).
var zoom := 2
## Current logical viewport size.
var logical := BASE
var _last := Vector2i(-1, -1)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var w := get_window()
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	w.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	w.min_size = BASE
	refit()


## Polled every frame (a cheap size compare) so that window resizes, F11,
## the fullscreen checkbox and moving the window to another monitor are all
## picked up, whichever of them changed the client size.
func _process(_delta: float) -> void:
	if get_window().size != _last:
		refit()


static func zoom_for(client: Vector2i) -> int:
	return maxi(1, floori(minf(float(client.x) / float(BASE.x), float(client.y) / float(BASE.y)) + TOLERANCE))


static func logical_for(client: Vector2i, z: int) -> Vector2i:
	return Vector2i(ceili(float(client.x) / float(z)), ceili(float(client.y) / float(z)))


func refit() -> void:
	var w := get_window()
	var s := w.size
	_last = s
	if s.x < 2 or s.y < 2:
		return  # minimised
	zoom = zoom_for(s)
	logical = logical_for(s, zoom)
	if w.content_scale_size != logical:
		w.content_scale_size = logical
		# One line per change, so a log shows the real client size (for
		# example the 1 px border Windows gives borderless fullscreen).
		print("[display] ", describe())


## One line for logs and the settings page: client, zoom and logical size.
func describe() -> String:
	var s := get_window().size
	return "%dx%d client, %dx zoom, %dx%d view" % [s.x, s.y, zoom, logical.x, logical.y]
