## Bounded runtime diagnostics: a repeated problem is reported a few times
## with its context, then counted silently, so a per-frame fault can never
## flood stderr (a native playtest once logged 7,860 identical errors).
class_name Diag
extends RefCounted

const MAX_REPORTS := 3

static var _counts := {}


## Reports `msg` the first MAX_REPORTS times `key` occurs, then once more to
## say further occurrences are suppressed. Returns the occurrence count.
static func once(key: String, msg: String) -> int:
	var n := int(_counts.get(key, 0)) + 1
	_counts[key] = n
	if n <= MAX_REPORTS:
		push_warning("[diag %s #%d] %s" % [key, n, msg])
	elif n == MAX_REPORTS + 1:
		push_warning("[diag %s] repeated; further reports suppressed" % key)
	return n


## Occurrences per key so far (for a summary line, e.g. on quit).
static func counts() -> Dictionary:
	return _counts.duplicate()
