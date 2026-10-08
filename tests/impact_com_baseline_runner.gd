extends SceneTree
const A := preload("res://fighters/boxer_02/boxer_02.tscn")
const B := preload("res://fighters/boxer_green/boxer_green.tscn")
var failures := 0; var p; var q
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	p=A.instantiate(); q=B.instantiate(); root.add_child(p); root.add_child(q); await process_frame
	p.opponent=q; q.opponent=p; p.fight_enabled=true; q.fight_enabled=true
	var base := _pose(p); for i in range(100): p.receive_hit("cross" if i%2 else "left_hook", "body_center" if i%3==0 else "head_center", 100.0, false); p._finish_action(); await process_frame
	var final := _pose(p); var max_error := 0.0
	for k in base: max_error=maxf(max_error, base[k].distance_to(final[k]))
	print("COM_BASELINE initial=%s final=%s max_error=%.6f tolerance=0.100000" % [base, final, max_error])
	if max_error > 0.1: failures += 1
	p.queue_free(); q.queue_free(); quit(1 if failures else 0)
func _pose(f) -> Dictionary:
	return {"pelvis":f.global_position+Vector3(0,0.86,0),"torso":f.global_position+Vector3(0,1.08,0),"head":f.global_position+Vector3(0,1.52,0),"com":f.global_position+Vector3(0,0.92,0)}
