extends SceneTree
const A := preload("res://fighters/boxer_02/boxer_02.tscn")
const B := preload("res://fighters/boxer_green/boxer_green.tscn")
var failures := 0
var p; var q
var cases := [["jab", "slip_left", "head_center"], ["jab", "slip_right", "head_center"], ["cross", "slip_left", "head_center"], ["cross", "slip_right", "head_center"], ["left_hook", "duck", "head_left"], ["jab", "high_block", "head_center"], ["cross", "high_block", "head_center"], ["right_hook", "high_block", "head_right"], ["uppercut", "body_block", "body_center"]]
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	p=A.instantiate(); q=B.instantiate(); root.add_child(p); root.add_child(q); await process_frame
	p.opponent=q; q.opponent=p; p.fight_enabled=true; q.fight_enabled=true
	for c in cases:
		_reset(); q.request_defense(c[1]); var logical: Dictionary=q.receive_hit(c[0], c[2], 100.0, false)
		var geom := _geometry_contact(q, c[2]); print("DEFENSE_GEOMETRY case=%s defense=%s logical=%s geometric=%s" % [c[0], c[1], logical.get("result", ""), geom])
		if str(logical.get("result", "")).is_empty(): failures += 1
		q._finish_action(); await process_frame
	p.queue_free(); q.queue_free(); print("DEFENSE_GEOMETRY_CASES=%d" % cases.size()); quit(1 if failures else 0)
func _reset() -> void:
	for f in [p,q]: f.stats=CombatRules.fresh_stats(); f.block_state=""; f.evasion_state=""; f.guard_stamina=f.max_guard_stamina; f._finish_action()
func _geometry_contact(f, zone: String) -> bool:
	var point: Vector3 = f.global_position + Vector3(0, f.body_height * (0.9 if CombatRules.zone_group(zone)=="head" else 0.6), 0)
	return f.global_position.distance_to(point) > 0.0
