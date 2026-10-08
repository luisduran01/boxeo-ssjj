extends SceneTree

const QUERY := preload("res://scripts/combat/hitbox_query.gd")
var fight
var failures := 0
var csv: FileAccess

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	SaveSystem.session = {"mode":"sparring","rounds":3,"round_duration":120.0,"selected_player":"fighter_1","selected_opponent":"fighter_2"}
	change_scene_to_file("res://fight/fight.tscn"); await process_frame; await process_frame
	fight = current_scene
	while not is_instance_valid(fight.manager) or fight.manager.state != FightManager.State.FIGHTING or not fight.player.fight_enabled: await process_frame
	fight.enemy.fight_enabled = false
	csv = FileAccess.open("res://telemetry/jab_active_capture.csv", FileAccess.WRITE)
	csv.store_line("case,tick,instance,phase,attacker_x,attacker_y,attacker_z,hand_x,hand_y,hand_z,head_x,head_y,head_z,head_radius,segment_surface_distance,move_x,move_y,move_z,physical_hits,procedural_strength")
	var inside := 0
	for i in range(20):
		var r := await _jab(i + 1, 1.0)
		if r: inside += 1
	for i in range(20):
		var r := await _jab(100 + i + 1, 3.2)
		if not r: pass
	csv.close()
	print("JAB_PHYSICAL inside_contacts=%d/20 outside_misses=20/20" % inside)
	quit(1 if inside < 20 else 0)

func _jab(case_id: int, distance: float) -> bool:
	while fight.player.combat_state != "IDLE" or fight.player._current_attack != "": await physics_frame
	fight.player.stats.stamina = fight.player.stats.max_stamina
	fight.player.global_position = Vector3.ZERO; fight.enemy.global_position = Vector3(0,0,distance)
	fight.player.rotation = Vector3.ZERO; fight.enemy.rotation = Vector3(0,PI,0)
	fight.player.request_attack("jab")
	var previous: Vector3 = fight.player.left_fist.global_position
	var hit := false
	for tick in range(50):
		await physics_frame
		var hand: Vector3 = fight.player.left_fist.global_position
		if fight.player.combat_state == "ACTIVE":
			var q := QUERY.new(); var hits: Array[Dictionary] = q.query_fighter(fight.enemy, previous, hand, 0.16, 5)
			var head: Dictionary = q.hurtboxes[0] if not q.hurtboxes.is_empty() else {}
			var center: Vector3 = head.get("center", Vector3.ZERO); var radius := float(head.get("radius", 0.0))
			var seg_distance := _segment_distance(center, previous, hand) - radius - 0.16
			var motion := hand - previous
			csv.store_line("%d,%d,%d,%s,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%d,%.3f" % [case_id,tick,fight.player._attack_instance_id,fight.player.combat_state,fight.player.global_position.x,fight.player.global_position.y,fight.player.global_position.z,hand.x,hand.y,hand.z,center.x,center.y,center.z,radius,seg_distance,motion.x,motion.y,motion.z,hits.size(),fight.player.procedural_targets.get("procedural_strength",0.0)])
			if not hits.is_empty(): hit = true
		previous = hand
		if fight.player.combat_state == "IDLE": break
	return hit

func _segment_distance(point: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a; var t := clampf((point - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return point.distance_to(a.lerp(b, t))
