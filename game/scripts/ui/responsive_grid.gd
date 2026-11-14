## Card grid whose column count follows the enclosing scroll viewport.
## Measuring the viewport, rather than this grid's expanded size, lets a
## previously wide grid shrink again without creating horizontal scrolling.
extends GridContainer

var max_columns := 2
var _scroll: ScrollContainer
var _queued := false


func _ready() -> void:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			_scroll = ancestor
			break
		ancestor = ancestor.get_parent()
	if _scroll != null:
		_scroll.resized.connect(_queue_columns)
		_scroll.get_v_scroll_bar().visibility_changed.connect(_queue_columns)
	for child in get_children():
		_watch_child(child)
	child_entered_tree.connect(_watch_child)
	child_exiting_tree.connect(func(_child): _queue_columns())
	_queue_columns()


func _watch_child(child: Node) -> void:
	if child is Control:
		child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		child.minimum_size_changed.connect(_queue_columns)
	_queue_columns()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_queue_columns()


func _queue_columns() -> void:
	if _queued or not is_inside_tree():
		return
	_queued = true
	_refresh_columns.call_deferred()


func _refresh_columns() -> void:
	_queued = false
	if not is_inside_tree() or _scroll == null:
		return
	var available := _scroll.size.x
	var bar := _scroll.get_v_scroll_bar()
	if bar.visible:
		available -= bar.size.x
	# Account for a card grid nested inside a padded panel.
	available -= maxf(0.0, global_position.x - _scroll.global_position.x) * 2.0
	var widest := 1.0
	var count := 0
	for child in get_children():
		if child is Control and child.visible:
			widest = maxf(widest, child.get_combined_minimum_size().x)
			count += 1
	var gap := float(get_theme_constant("h_separation"))
	var fit := maxi(1, floori((available + gap) / (widest + gap)))
	var next := mini(maxi(1, count), mini(max_columns, fit))
	if columns != next:
		columns = next
