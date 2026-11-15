## Regression for collecting reports without reward rows: no empty tween,
## and Continue still closes defeat/retreat reports after committing.
class_name TestReviewBattleReport
extends RefCounted


static func run(t: TestKit, root: Node) -> void:
	var host := Control.new()
	host.theme = Art.theme
	host.size = Vector2(640, 400)
	root.add_child(host)
	for outcome in ["defeat", "retreat"]:
		await _empty_report(t, host, outcome)
	await _reward_stamp(t, host)
	host.free()


static func _summary(outcome: String) -> Dictionary:
	return {"outcome": outcome, "time": 3.0, "hpAvg": 0.0,
		"returnedTo": "brightquay", "losses": {"gold": 0, "materials": 0},
		"injured": [], "spoils": [], "ledger": [], "rewards": {"gold": 0, "materials": 0},
		"recruit": {}, "xp": 0}


static func _empty_report(t: TestKit, host: Control, outcome: String) -> void:
	var report := BattleReport.new()
	host.add_child(report)
	report.setup(_summary(outcome), Vector2(24, 30))
	await host.get_tree().process_frame
	t.eq(report._stamps.size(), 0, outcome + " report has no reward stamps")
	var tweens_before := host.get_tree().get_processed_tweens().size()
	var closed := [0]
	report.closed.connect(func(): closed[0] += 1)
	report.show_committed({"outcome": outcome})
	t.eq(host.get_tree().get_processed_tweens().size(), tweens_before,
		outcome + " collection does not create an empty animation")
	t.ok(report._committed, outcome + " report enters committed state")
	t.ok(report._close_t > 0.0, outcome + " report retains automatic close")
	# Let the engine process any created tweens: the old unconditional tween
	# logs its no-Tweeners error here as well as failing the count above.
	await host.get_tree().process_frame
	var button: Button = report._foot.get_child(report._foot.get_child_count() - 1)
	t.eq(button.text, I18n.t("battle.continue"), outcome + " exposes Continue")
	button.pressed.emit()
	await host.get_tree().process_frame
	t.eq(closed[0], 1, outcome + " Continue closes the report once")


static func _reward_stamp(t: TestKit, host: Control) -> void:
	var summary := _summary("victory")
	summary.rewards.gold = 5
	var report := BattleReport.new()
	host.add_child(report)
	report.setup(summary, Vector2(24, 30))
	await host.get_tree().process_frame
	t.eq(report._stamps.size(), 1, "gold reward creates one stamp")
	var tweens_before := host.get_tree().get_processed_tweens().size()
	report.show_committed({"outcome": "victory"})
	t.eq(host.get_tree().get_processed_tweens().size(), tweens_before + 2,
		"victory retains reward-stamp and flash animations")
	await host.get_tree().create_timer(0.25).timeout
	t.near(report._stamps[0].modulate.a, 1.0, "collected gold stamp becomes visible")
	report._close()
	await host.get_tree().process_frame
