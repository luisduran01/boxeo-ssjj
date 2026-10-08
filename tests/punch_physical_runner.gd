extends SceneTree

const QUERY := preload("res://scripts/combat/hitbox_query.gd")
const CASES := [
	{"name":"cross", "distance":1.0, "zone":"head"},
	{"name":"right_hook", "distance":0.9, "zone":"head"},
	{"name":"uppercut", "distance":0.82, "zone":"head"},
	{"name":"uppercut_body", "distance":0.82, "zone":"body"},
]
var fight
var failures := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var selected := ""
	for arg in OS.get_cmdline_args():
		if arg in ["cross", "right_hook", "uppercut", "uppercut_body"]: selected = arg
	SaveSystem.session = {"mode":"sparring","rounds":3,"round_duration":120.0,"selected_player":"fighter_1","selected_opponent":"fighter_2"}
	change_scene_to_file("res://fight/fight.tscn"); await process_frame; await process_frame
	fight = current_scene
	while not is_instance_valid(fight.manager) or fight.manager.state != FightManager.State.FIGHTING or not fight.player.fight_enabled: await process_frame
	fight.enemy.fight_enabled = false
	var selected_cases := CASES if selected == "" else CASES.filter(func(item): return item.name == selected)
	for spec in selected_cases:
		var cycles := 0
		for i in range(20):
			if await _cycle(spec.name): cycles += 1
		var inside := 0
		for i in range(20):
			if await _contact(spec, i + 1, false): inside += 1
		var misses := 0
		for i in range(20):
			if not await _contact(spec, 100 + i + 1, true): misses += 1
		print("PUNCH name=%s distance=%.2f cycles=%d/20 contacts=%d/20 misses=%d/20" % [spec.name, spec.distance, cycles, inside, misses])
		if cycles < 20 or inside < 20 or misses < 20: failures += 1
	quit(1 if failures else 0)

func _prepare(distance: float) -> void:
	var guard := 0
	while (fight.player.combat_state != "IDLE" or fight.player._current_attack != "") and guard < 240:
		await physics_frame; guard += 1
	if guard >= 240: fight.player._finish_action()
	fight.player.stats.stamina = fight.player.stats.max_stamina
	fight.player._reaction_time = 0.0
	fight.player._wobble_time = 0.0
	fight.player.block_state = ""
	fight.player.evasion_state = ""
	fight.player.global_position = Vector3.ZERO; fight.enemy.global_position = Vector3(0,0,distance)
	fight.player.rotation = Vector3.ZERO; fight.enemy.rotation = Vector3(0,PI,0)
	fight.player._finish_action(); fight.enemy._finish_action()

func _cycle(attack: String) -> bool:
	await _prepare(1.0)
	fight.player.request_attack(attack)
	var phases: Array[String] = []
	for i in range(160):
		await physics_frame
		var state := str(fight.player.combat_state)
		if state in ["STARTUP","ACTIVE","RECOVERY"] and not phases.has(state): phases.append(state)
		if state == "IDLE" and phases.size() == 3: return true
	return false

func _contact(spec: Dictionary, case_id: int, outside: bool) -> bool:
	await _prepare(3.2 if outside else float(spec.distance))
	fight.player.request_attack(spec.name)
	var previous := _fist(fight.player, spec.name)
	var hit := false
	for tick in range(100):
		await physics_frame
		var current := _fist(fight.player, spec.name)
		if fight.player.combat_state == "ACTIVE":
			var q := QUERY.new()
			var hits: Array[Dictionary] = q.query_fighter(fight.enemy, previous, current, 0.16, 5)
			if not hits.is_empty(): hit = true
		previous = current
		if fight.player.combat_state == "IDLE": break
	return hit

func _fist(fighter, attack: String) -> Vector3:
	var right := attack in ["cross","right_hook","uppercut","uppercut_body"]
	return fighter.right_fist.global_position if right else fighter.left_fist.global_position
