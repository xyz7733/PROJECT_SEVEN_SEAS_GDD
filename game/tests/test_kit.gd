## Minimal assertion helper for the headless test scene.
class_name TestKit
extends RefCounted

var checks := 0
var failures: Array = []


func ok(cond: Variant, label: String) -> void:
	checks += 1
	if not bool(cond):
		failures.append(label)


func eq(got: Variant, want: Variant, label: String) -> void:
	checks += 1
	if got != want:
		failures.append("%s (got %s, want %s)" % [label, str(got), str(want)])


func near(got: float, want: float, label: String, eps: float = 0.0001) -> void:
	checks += 1
	if absf(got - want) > eps:
		failures.append("%s (got %s, want %s)" % [label, str(got), str(want)])


func finish() -> bool:
	if failures.is_empty():
		print("TESTS PASS: %d checks" % checks)
		return true
	print("TESTS FAIL: %d/%d checks failed" % [failures.size(), checks])
	for f in failures:
		print("  - " + f)
	return false
