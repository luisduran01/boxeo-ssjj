extends SceneTree

const A := preload("res://fighters/boxer_02/boxer_02.tscn")
const B := preload("res://fighters/boxer_green/boxer_green.tscn")
var failures := 0
var left
var right
var attacks := ["jab", "cross", "left_hook", "right_hook", "uppercut"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	left = A.instantiate(); right = B.instantiate(); root.add_child(left); root.add_child(right)
	await process_frame
	left.opponent = right; right.opponent = left; left.fight_enabled = true; right.fight_enabled = true
	for i in range(200):
		_reset()
		var a: String = attacks[i % attacks.size()]
		var b: String = attacks[(i * 3 + 1) % attacks.size()]
		left.request_attack(a); right.request_attack(b)
		var r1: Dictionary = right.receive_hit(a, "body_center" if i % 4 == 0 else "head_center", 100.0, false)
		var r2: Dictionary = left.receive_hit(b, "head_center", 100.0, i % 5 == 0)
		_check(i, r1, r2)
	left._finish_action(); right._finish_action(); await process_frame
	left.queue_free(); right.queue_free()
	if failures == 0: print("IMPACT CONCURRENCY: 200/200 PASS"); quit(0)
	else: push_error("IMPACT CONCURRENCY FAILURES: %d" % failures); quit(1)

func _reset() -> void:
	for f in [left, right]:
		f.stats = CombatRules.fresh_stats(); f.block_state = ""; f.evasion_state = ""; f.counter_window = 0.0
		f.guard_stamina = f.max_guard_stamina; f.stability = f.max_stability; f._finish_action()

func _check(i: int, r1: Dictionary, r2: Dictionary) -> void:
	for r in [r1, r2]:
		for k in ["damage", "stability_loss", "stamina_damage"]:
			var v := float(r.get(k, 0.0)); if is_nan(v) or is_inf(v): failures += 1
	if not left.procedural_motor.has_valid_ownership() or not right.procedural_motor.has_valid_ownership(): failures += 1
	if left.combat_state == "KNOCKDOWN" or right.combat_state == "KNOCKDOWN": failures += 1
