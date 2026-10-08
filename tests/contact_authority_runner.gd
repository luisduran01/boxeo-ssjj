extends SceneTree
const A := preload("res://fighters/boxer_02/boxer_02.tscn")
const B := preload("res://fighters/boxer_green/boxer_green.tscn")
const Q := preload("res://scripts/combat/hitbox_query.gd")
var p; var q; var query = Q.new(); var failures := 0
var cases := [["jab","slip_left","head_center"],["jab","slip_right","head_center"],["cross","slip_left","head_center"],["cross","slip_right","head_center"],["left_hook","duck","head_left"],["jab","high_block","head_center"],["cross","high_block","head_center"],["right_hook","high_block","head_right"],["uppercut","body_block","body_center"]]
func _initialize()->void: _run.call_deferred()
func _run()->void:
	p=A.instantiate(); q=B.instantiate(); root.add_child(p); root.add_child(q); await process_frame
	p.opponent=q; q.opponent=p; p.fight_enabled=true; q.fight_enabled=true
	for c in cases:
		_reset(); q.request_defense(c[1]); var legacy: Dictionary=q.receive_hit(c[0],c[2],100.0,false)
		var prev: Vector3=q.global_position+Vector3(0,1.2,0)-q.global_basis.z*0.2; var cur: Vector3=prev-q.global_basis.z*0.35
		var physical: Array[Dictionary]=query.query_fighter(q,prev,cur,0.16,5)
		print("CONTACT_AUTHORITY attack=%s defense=%s LEGACY=%s PHYSICAL_HITS=%d zones=%s" % [c[0],c[1],legacy.get("result",""),physical.size(),physical.map(func(x): return x.zone)])
		q._finish_action(); await process_frame
	p.queue_free(); q.queue_free(); print("CONTACT_AUTHORITY_CASES=%d" % cases.size()); quit(1 if failures else 0)
func _reset()->void:
	for f in [p,q]: f.stats=CombatRules.fresh_stats(); f.block_state=""; f.evasion_state=""; f.guard_stamina=f.max_guard_stamina; f._finish_action()
