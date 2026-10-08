extends SceneTree
const A := preload("res://fighters/boxer_02/boxer_02.tscn")
const B := preload("res://fighters/boxer_green/boxer_green.tscn")
var p; var q; var failures:=0
func _initialize()->void: _run.call_deferred()
func _run()->void:
	p=A.instantiate(); q=B.instantiate(); root.add_child(p); root.add_child(q); await process_frame
	p.opponent=q; q.opponent=p; p.fight_enabled=true; q.fight_enabled=true
	for c in [["jab","slip_left"],["jab","slip_right"],["cross","slip_left"],["cross","slip_right"],["left_hook","duck"],["jab","high_block"],["cross","high_block"],["right_hook","high_block"],["uppercut","body_block"]]:
		q._finish_action(); q.request_defense(c[1]); var result: Dictionary=q.receive_hit(c[0],"body_center" if c[1]=="body_block" else "head_center",100.0,false); print("DEFENSE_PHYSICAL attack=%s defense=%s result=%s" % [c[0],c[1],result.get("result","")])
		if result.is_empty(): failures+=1
	p.queue_free(); q.queue_free(); quit(1 if failures else 0)
