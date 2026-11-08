## Autoload "Game": owns the live state, applies committed transactions,
## autosaves to the rotating recovery files and tells views what changed.
extends Node

signal state_changed(kind: String)
signal notice(text: String, tone: String)
signal saved(ok: bool)

const ROTATE_REASONS := ["save.reason_port", "save.reason_battle", "save.reason_trial", "save.reason_hull", "save.reason_new_game", "save.reason_loaded"]

var state: Dictionary = {}
var last_save_ok := true
var last_saved_unix := 0
var _layout_cache: Dictionary = {}
var _layout_tx := -1
var _pending_reason: Variant = null
var _pending_rotate := false
var _save_queued := false


func has_game() -> bool:
	return not state.is_empty()


func new_game(seed_value: int = -1) -> void:
	state = GS.create_new_game(seed_value)
	_layout_tx = -1
	_queue_save("save.reason_new_game", true)
	state_changed.emit("new_game")


func load_state(st: Dictionary) -> void:
	state = st.duplicate(true)
	_layout_tx = -1
	_queue_save("save.reason_loaded", true)
	state_changed.emit("loaded")


## Leaves the running game (back to the title screen): writes a queued
## autosave first so nothing is lost, then drops the live state.
func close_game() -> void:
	if _save_queued and has_game():
		_flush_save()
	state = {}
	_layout_tx = -1


## Applies a transaction result. Returns true when it committed.
func act(res: Dictionary, quiet_fail := false) -> bool:
	if not res.get("ok", false):
		if not quiet_fail:
			notice.emit(I18n.reason(res), "error")
		return false
	if res.get("duplicate", false):
		return true
	state = res.state
	var reason = res.get("saveReason")
	_queue_save(reason if reason else "save.reason_auto", reason != null and ROTATE_REASONS.has(reason))
	state_changed.emit(String(state.envelope.lastTxKind))
	return true


## Layout analysis cached per committed transaction.
func layout() -> Dictionary:
	if not has_game():
		return {}
	var tx := int(state.envelope.lastTxId)
	if tx != _layout_tx or _layout_cache.is_empty():
		_layout_cache = Rules.layout_of(state)
		_layout_tx = tx
	return _layout_cache


func _queue_save(reason: Variant, rotate: bool) -> void:
	_pending_reason = reason
	_pending_rotate = _pending_rotate or rotate
	if not _save_queued:
		_save_queued = true
		call_deferred("_flush_save")


func _flush_save() -> void:
	_save_queued = false
	if not has_game():
		return
	var ok := SaveStore.save_recovery(state, _pending_reason, _pending_rotate)
	if ok:
		state.envelope.recoveryGeneration = int(state.envelope.recoveryGeneration) + (1 if _pending_rotate or int(state.envelope.recoveryGeneration) == 0 else 0)
		last_saved_unix = int(Time.get_unix_time_from_system())
	last_save_ok = ok
	_pending_rotate = false
	saved.emit(ok)


func save_manual(i: int) -> bool:
	var ok := SaveStore.save_manual(i, state)
	notice.emit(I18n.t("system.saved_slot", {"n": i + 1}) if ok else I18n.t("status.save_failed"), "info" if ok else "error")
	return ok


func say(key: String, params: Dictionary = {}, tone := "info") -> void:
	notice.emit(I18n.t(key, params, state), tone)


## Where the captain currently is: port, site, at_sea or battle.
func where() -> String:
	if not has_game():
		return ""
	if state.encounter != null:
		return "battle"
	if state.voyage != null and state.voyage.event != null:
		return "at_sea"
	if state.voyage != null and state.voyage.site != null:
		return "site"
	if Rules.at_port(state):
		return "port"
	return "at_sea"
