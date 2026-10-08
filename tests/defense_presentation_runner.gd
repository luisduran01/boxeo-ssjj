extends SceneTree
const A := preload("res://fighters/boxer_02/boxer_02.tscn")
const B := preload("res://fighters/boxer_green/boxer_green.tscn")
var p; var q; var failures:=0
func _initialize()->void: _run.call_deferred()
func _run()->void:
	p=A.instantiate(); q=B.instantiate(); root.add_child(p); root.add_child(q); await process_frame
	p.opponent=q; q.opponent=p; p.fight_enabled=true; q.fight_enabled=true
	for c in [["jab","high_block","head_center"],["cross","high_block","head_center"],["right_hook","high_block","head_right"],["uppercut","body_block","body_center"],["jab","slip_left","head_center"]]:
		q._finish_action(); q.request_defense(c[1]); var r=q.receive_hit(c[0],c[2],100.0,false); print("DEFENSE_PRESENTATION attack=%s defense=%s result=%s guard=%s counter=%.3f" % [c[0],c[1],r.get("result",""),q.block_state,q.counter_window]); if str(r.get("result","")).is_empty(): failures+=1
	p.queue_free(); q.queue_free(); print("DEFENSE_PRESENTATION %s" % ("PASS" if failures==0 else "FAIL")); quit(1 if failures else 0)
