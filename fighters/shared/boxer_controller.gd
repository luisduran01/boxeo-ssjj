class_name BoxerController
extends CharacterBody3D

const FootworkModel = preload("res://scripts/combat/boxing_footwork_model.gd")
const AIPlanner = preload("res://scripts/ai/boxing_ai_planner.gd")
const Balance = preload("res://scripts/combat/gameplay_balance.gd")
const PresentationBridge = preload("res://scripts/presentation/presentation_bridge.gd")
const ProceduralFighterMotor = preload("res://scripts/presentation/procedural_fighter_motor.gd")
const CombatEventView = preload("res://scripts/presentation/combat_event_view.gd")

signal stats_changed(fighter: BoxerController)
signal punch_thrown(fighter: BoxerController, attack_name: String)
signal punch_landed(attacker: BoxerController, defender: BoxerController, result: Dictionary)
signal knockdown_requested(fighter: BoxerController)
signal knockdown_started(fighter: BoxerController)
signal defense_used(fighter: BoxerController, defense_name: String)
signal boxer_knocked_out(fighter: BoxerController)
signal boxer_tko_candidate(fighter: BoxerController)

@export var is_player := true:
	set(value):
		is_player = value
		if is_inside_tree() and not is_player:
			_configure_ai_planner()
@export var opponent: Node3D
@export_enum("Easy", "Medium", "Hard") var difficulty := "Medium"
@export var fighter_name := "PLAYER"
@export_range(0.30, 0.42, 0.01) var body_radius := 0.36
@export_range(1.30, 1.65, 0.01) var body_height := 1.48
@export_range(0.04, 0.16, 0.01) var separation_soft_zone := 0.10
@export var punch_debug_enabled := false
@export var debug_boxing_movement := false
@export var procedural_presentation_enabled := true
@export_group("Boxing Footwork")
@export_range(0.0, 0.5, 0.01) var input_deadzone := 0.20
@export_range(0.0, 1.0, 0.01) var short_step_threshold := 0.25
@export_range(0.0, 1.0, 0.01) var medium_step_threshold := 0.65
@export_range(0.0, 1.0, 0.01) var long_step_threshold := 0.90
@export_range(0.0, 1.0, 0.01) var long_step_rearm_threshold := 0.55
@export_range(0.1, 0.6, 0.01) var long_step_duration := 0.30
@export_range(0.2, 2.0, 0.05) var long_step_cooldown := 0.85
@export_range(0.5, 4.0, 0.05) var forward_speed := 2.35
@export_range(0.5, 4.0, 0.05) var backward_speed := 1.80
@export_range(0.5, 4.0, 0.05) var lateral_speed := 2.00
@export_range(1.0, 20.0, 0.5) var acceleration := 7.0
@export_range(1.0, 24.0, 0.5) var deceleration := 10.0
@export_range(1.0, 20.0, 0.5) var turn_responsiveness := 9.0
@export_range(0.25, 1.2, 0.01) var pivot_duration := 0.52
@export_range(0.4, 3.0, 0.05) var pivot_speed := 1.25
@export_range(0.8, 2.8, 0.05) var pivot_max_range := 2.10
@export_group("Boxing Distance")
@export_range(1.8, 4.0, 0.05) var outside_range_distance := 2.80
@export_range(1.2, 3.0, 0.05) var long_range_distance := 2.10
@export_range(0.8, 2.0, 0.05) var mid_range_distance := 1.35
@export_range(0.4, 1.2, 0.02) var too_close_distance := 0.78
@export_group("Fighter Separation")
@export_range(0.5, 1.5, 0.01) var minimum_fighter_distance := 0.82
@export_range(0.35, 1.0, 0.01) var hard_separation_distance := 0.66
@export_range(0.5, 12.0, 0.25) var soft_separation_strength := 6.0
@export_range(0.1, 2.0, 0.05) var maximum_separation_speed := 0.80
@export_range(2.4, 4.2, 0.05) var ring_limit := 3.25
@export_group("")
@export_node_path("AnimationPlayer") var animation_player_path := NodePath("boxer_green/AnimationPlayer2")
@export_node_path("Skeleton3D") var skeleton_path := NodePath("boxer_green/Skeleton3D")

const UNARMED_SUPPORT_SOURCES := {
	"block": "res://fighters/boxer_02/animations/unarmed_support/unarmed_block.res",
	"block_get_hit_1": "res://fighters/boxer_02/animations/unarmed_support/unarmed_block_get_hit_1.res",
	"block_get_hit_2": "res://fighters/boxer_02/animations/unarmed_support/unarmed_block_get_hit_2.res",
	"dodge_backward": "res://fighters/boxer_02/animations/unarmed_support/unarmed_dodge_backward.res",
	"dodge_left": "res://fighters/boxer_02/animations/unarmed_support/unarmed_dodge_left.res",
	"dodge_right": "res://fighters/boxer_02/animations/unarmed_support/unarmed_dodge_right.res",
	"get_hit_back": "res://fighters/boxer_02/animations/unarmed_support/unarmed_get_hit_back.res",
	"get_hit_front": "res://fighters/boxer_02/animations/unarmed_support/unarmed_get_hit_front.res",
	"get_hit_left": "res://fighters/boxer_02/animations/unarmed_support/unarmed_get_hit_left.res",
	"get_hit_right": "res://fighters/boxer_02/animations/unarmed_support/unarmed_get_hit_right.res",
	"get_up": "res://fighters/boxer_02/animations/unarmed_support/unarmed_get_up.res",
	"idle_injured": "res://fighters/boxer_02/animations/unarmed_support/unarmed_idle_injured.res",
	"knockdown": "res://fighters/boxer_02/animations/unarmed_support/unarmed_knockdown.res",
	"stunned": "res://fighters/boxer_02/animations/unarmed_support/unarmed_stunned.res",
}
const HUMANOID_BONE_ALIASES := {
	"Chest": "Spine1",
	"UpperChest": "Spine2",
	"LeftUpperArm": "LeftArm",
	"LeftLowerArm": "LeftForeArm",
	"RightUpperArm": "RightArm",
	"RightLowerArm": "RightForeArm",
	"LeftUpperLeg": "LeftUpLeg",
	"LeftLowerLeg": "LeftLeg",
	"RightUpperLeg": "RightUpLeg",
	"RightLowerLeg": "RightLeg",
}

var stats := CombatRules.fresh_stats()
var fight_enabled := false
var combat_state := "IDLE"
var ai_state := "IDLE"
var block_state := ""
var evasion_state := ""
var counter_window := 0.0
var guard_switch_frames_left := 0
var positional_disadvantage_frames := 0
var clinch_cooldown := 0.0
var clinch_partner: BoxerController
var clinch_animation_name := "clinch"
var guard_stamina := 100.0
var max_guard_stamina := 100.0
var stability := 100.0
var max_stability := 100.0
var long_term_fatigue := 0.0
var head_damage := 0.0
var body_damage := 0.0
var recovery_protection := 0.0
var knockdowns := 0
var round_hits := 0
var round_damage := 0.0
var round_knockdowns := 0
var _move_blend := Vector2.ZERO
var _smoothed_velocity := Vector3.ZERO
var _action_time := 0.0
var _active_time := 0.0
var _recovery_time := 0.0
var _current_attack := ""
var _buffered_attack := ""
var _buffered_attacks: Array[String] = []
var _buffer_time := 0.0
var _strike_done := false
var _reaction_time := 0.0
var _ai_think_time := 0.0
var _ai_move := Vector2.ZERO
var _pivot_cooldown := 0.0
var _last_forward := Vector3.FORWARD
var _knocked_down := false
var _neutral_target := Vector3.ZERO
var _moving_to_neutral := false
var _ai_last_attack := ""
var _attack_instance_id := 0
var _hit_targets: Dictionary = {}
var _attack_input := Vector2.ZERO
var _attack_momentum := 1.0
var _last_hit_result := "MISS"
var _last_hit_damage := 0.0
var _last_hit_distance := 0.0
var _last_counter := false
var range_state: int = FootworkModel.RangeState.OUTSIDE
var movement_intensity := 0.0
var locomotion_state := "IDLE"
var _movement_intent := Vector2.ZERO
var _raw_movement_input := Vector2.ZERO
var _long_step_armed := true
var _long_step_time := 0.0
var _long_step_cooldown := 0.0
var _pivot_request := 0.0
var _pivot_time := 0.0
var _pivot_input_armed := true
var _stable_separation_direction := Vector3.RIGHT
var _separation_correction := Vector3.ZERO
var _target_speed := 0.0
var _distance_to_opponent := INF
var _ai_lateral_direction := 1.0
var _ai_attack_cooldown := 0.0
var _ai_guard_time := 0.0
var _ai_guard_cooldown := 0.0
var _defense_time := 0.0
var _wobble_time := 0.0
var _combo_hit_count := 0
var _combo_timer := 0.0
var _last_received_counter := false
var _clinch_time := 0.0
var _defense_spam_window := 0.0
var _defense_spam_count := 0
var _last_guard_level := "head"
var _ai_memory: Array[String] = []
var ai_planner: BoxingAIPlanner
var procedural_motor := ProceduralFighterMotor.new()
var procedural_targets := {}
var procedural_move_frame := 0
var _procedural_debug := {}
var _procedural_bone_rest := {}

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_player: AnimationPlayer = _resolve_animation_player()
@onready var skeleton: Skeleton3D = _resolve_skeleton()
@onready var left_fist: Area3D = $Hitboxes/LeftFist
@onready var right_fist: Area3D = $Hitboxes/RightFist
@onready var body_collider: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	collision_layer = 3
	collision_mask = 19
	safe_margin = 0.025
	_configure_animation_libraries()
	_normalize_footwork_animations()
	_configure_body_collider()
	_configure_combat_areas()
	_cache_procedural_bone_rest()
	var playback := animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if playback != null:
		playback.start("Footwork")
	animation_tree.active = true
	animation_tree.advance(0.0)
	if animation_player != null and animation_player.has_animation("Boxing/boxing_idle"):
		animation_player.play("Boxing/boxing_idle", 0.0)
	if playback != null:
		playback.travel("Footwork")
	_configure_ai_planner()
	stats_changed.emit(self)


func _physics_process(delta: float) -> void:
	_pivot_cooldown = maxf(0.0, _pivot_cooldown - delta)
	clinch_cooldown = maxf(0.0, clinch_cooldown - delta)
	_defense_spam_window = maxf(0.0, _defense_spam_window - delta)
	if positional_disadvantage_frames > 0:
		positional_disadvantage_frames -= 1
	if guard_switch_frames_left > 0:
		guard_switch_frames_left -= 1
	_update_procedural_presentation(delta)
	if combat_state == "CLINCH":
		_update_clinch(delta)
		return
	_long_step_time = maxf(0.0, _long_step_time - delta)
	_long_step_cooldown = maxf(0.0, _long_step_cooldown - delta)
	_buffer_time = maxf(0.0, _buffer_time - delta)
	counter_window = maxf(0.0, counter_window - delta)
	recovery_protection = maxf(0.0, recovery_protection - delta)
	_combo_timer = maxf(0.0, _combo_timer - delta)
	if _combo_timer <= 0.0:
		_combo_hit_count = 0
	_update_defense_timers(delta)
	if _buffer_time <= 0.0:
		_clear_attack_buffer()
	_update_stamina(delta)
	if _knocked_down:
		velocity = Vector3.ZERO
		return
	_update_range_state()
	_face_opponent(delta)
	if _moving_to_neutral:
		_move_to_neutral(delta)
		return
	if _reaction_time > 0.0:
		_reaction_time -= delta
		var stun_scale := 0.25 if combat_state == "WOBBLED" else 0.0
		velocity = _body_separation_velocity(_smoothed_velocity * stun_scale)
		move_and_slide()
		_apply_ring_limit()
		if _reaction_time <= 0.0:
			if combat_state == "WOBBLED" and _wobble_time > 0.0:
				_reaction_time = minf(_wobble_time, 0.25)
			else:
				_finish_action()
		return
	if _current_attack != "":
		_update_attack(delta)
		return
	if _pivot_time > 0.0:
		_update_pivot_movement(delta)
		return
	if not fight_enabled:
		_movement_intent = _prepare_movement_intent(Vector2.ZERO)
		velocity = _body_separation_velocity(velocity.move_toward(Vector3.ZERO, deceleration * delta))
		_update_footwork(Vector2.ZERO, delta)
		move_and_slide()
		_apply_ring_limit()
		velocity = Vector3(velocity.x, 0.0, velocity.z).limit_length(maximum_separation_speed)
		_smoothed_velocity = velocity
		return
	var raw_input := _player_input() if is_player else _ai_input(delta)
	var input_vector := _prepare_movement_intent(raw_input)
	if _current_attack != "":
		_update_attack(delta)
		return
	_maybe_request_input_pivot(input_vector)
	if _pivot_time > 0.0:
		_update_pivot_movement(delta)
		return
	_update_defense()
	_move_relative_to_opponent(input_vector, delta)
	_handle_attack_input()


func _player_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_backward", "move_forward")


func ai_move_to_opponent() -> void:
	if is_player:
		return
	_update_range_state()
	ai_state = "APPROACH"
	set_movement_intent(Vector2(_ai_lateral_direction * 0.12, 0.85))


func ai_attack() -> void:
	if is_player:
		return
	_update_range_state()
	if _current_attack != "" or _ai_attack_cooldown > 0.0:
		return
	_begin_ai_attack(_distance_to_opponent)


func ai_block() -> void:
	if is_player:
		return
	_begin_ai_guard()


func set_movement_intent(intent: Vector2) -> void:
	_movement_intent = intent.limit_length(1.0)
	if not is_player:
		_ai_move = _movement_intent
		_ai_think_time = maxf(_ai_think_time, 0.10)


func request_pivot(direction: float) -> bool:
	_update_range_state()
	if is_zero_approx(direction) or _pivot_cooldown > 0.0 or _current_attack != "" or _reaction_time > 0.0 or _knocked_down or _distance_to_opponent > pivot_max_range:
		return false
	_pivot_request = signf(direction)
	_pivot_time = pivot_duration
	_pivot_cooldown = 0.85
	locomotion_state = "PIVOT_RIGHT" if _pivot_request > 0.0 else "PIVOT_LEFT"
	var state_machine := animation_tree.tree_root as AnimationNodeStateMachine
	var playback := animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	var state_name := "PivotRight" if _pivot_request > 0.0 else "PivotLeft"
	if animation_tree.active and state_machine != null and state_machine.has_node(state_name) and playback != null:
		playback.travel(state_name)
	if opponent is BoxerController:
		(opponent as BoxerController).positional_disadvantage_frames = 12
	return true


func _maybe_request_input_pivot(input_vector: Vector2) -> void:
	if absf(input_vector.x) < 0.35:
		_pivot_input_armed = true
	if not _pivot_input_armed or absf(input_vector.x) < 0.78 or movement_intensity < medium_step_threshold:
		return
	if request_pivot(input_vector.x):
		_pivot_input_armed = false


func _update_pivot_movement(delta: float) -> void:
	_pivot_time = maxf(0.0, _pivot_time - delta)
	var basis: Dictionary = FootworkModel.combat_basis(global_position, opponent.global_position if is_instance_valid(opponent) else global_position + _last_forward, _last_forward)
	var tangent: Vector3 = basis.right * _pivot_request
	var target := _body_separation_velocity(tangent * pivot_speed)
	_smoothed_velocity = _smoothed_velocity.move_toward(target, acceleration * delta)
	velocity = _body_separation_velocity(_smoothed_velocity)
	_target_speed = target.length()
	move_and_slide()
	_apply_ring_limit()
	if _pivot_time <= 0.0:
		_pivot_request = 0.0
		locomotion_state = "IDLE"
		var playback := animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
		if playback != null:
			playback.travel("Footwork")


func _prepare_movement_intent(raw_input: Vector2) -> Vector2:
	_raw_movement_input = raw_input.limit_length(1.0)
	var filtered: Vector2 = FootworkModel.apply_radial_deadzone(_raw_movement_input, input_deadzone)
	movement_intensity = filtered.length()
	var latch: Dictionary = FootworkModel.update_long_step_latch(
		movement_intensity,
		_long_step_armed,
		_long_step_cooldown,
		long_step_threshold,
		long_step_rearm_threshold
	)
	_long_step_armed = bool(latch.armed)
	if bool(latch.triggered) and filtered.y > 0.25:
		_long_step_time = long_step_duration
		_long_step_cooldown = long_step_cooldown
	_movement_intent = filtered
	return _movement_intent


func _ai_input(delta: float) -> Vector2:
	_ai_attack_cooldown = maxf(0.0, _ai_attack_cooldown - delta)
	_ai_guard_time = maxf(0.0, _ai_guard_time - delta)
	_ai_guard_cooldown = maxf(0.0, _ai_guard_cooldown - delta)
	if _knocked_down or combat_state in ["STUNNED", "WOBBLED", "KNOCKDOWN", "GUARD_BREAK", "BLOCK_HIT"]:
		ai_state = "HURT"
		_ai_move = Vector2.ZERO
		return _ai_move
	if _ai_guard_time > 0.0:
		ai_state = "DEFEND"
		_ai_move = Vector2.ZERO
		return _ai_move
	if block_state != "":
		block_state = ""
	if ai_planner != null:
		var planned := ai_planner.decide(delta)
		set_movement_intent(planned)
		return planned
	_ai_think_time -= delta
	if _ai_think_time > 0.0:
		return _ai_move
	_update_range_state()
	_ai_think_time = {"Easy": 0.68, "Medium": 0.46, "Hard": 0.32}.get(difficulty, 0.46) + randf_range(-0.05, 0.12)
	var distance := _distance_to_opponent
	var ring_radius := maxf(absf(global_position.x), absf(global_position.z))
	if ring_radius > 3.08:
		ai_state = "RING_ESCAPE"
		_ai_move = _world_direction_to_input(-Vector3(global_position.x, 0.0, global_position.z).normalized())
	elif is_instance_valid(opponent) and str(opponent.combat_state) == "STARTUP" and distance <= 1.55 and _ai_guard_cooldown <= 0.0:
		_begin_ai_guard()
	elif is_instance_valid(opponent) and difficulty == "Hard" and str(opponent.combat_state) in ["STARTUP", "RECOVERY"] and distance <= 1.65 and stats.stamina > 10.0 and _ai_attack_cooldown <= 0.0:
		ai_state = "COUNTER"
		request_attack("jab" if distance > 1.25 else "right_hook")
		if _current_attack != "":
			_ai_attack_cooldown = _next_ai_attack_cooldown()
		_ai_move = Vector2.ZERO
	elif stats.stamina < 22.0:
		ai_state = "RETREAT"
		_ai_move = Vector2(_ai_lateral_direction * 0.35, -0.85)
	elif range_state == FootworkModel.RangeState.OUTSIDE:
		ai_state = "APPROACH"
		_ai_move = Vector2(_ai_lateral_direction * randf_range(0.05, 0.22), randf_range(0.78, 0.92))
	elif range_state == FootworkModel.RangeState.TOO_CLOSE:
		ai_state = "RETREAT"
		_ai_move = Vector2(_ai_lateral_direction * 0.45, -0.82)
		if randf() < 0.22:
			request_pivot(_ai_lateral_direction)
	elif range_state in [FootworkModel.RangeState.MID_RANGE, FootworkModel.RangeState.POCKET] and distance <= 1.55 and _ai_attack_cooldown <= 0.0 and stats.stamina > 12.0:
		_begin_ai_attack(distance)
	elif range_state == FootworkModel.RangeState.POCKET:
		ai_state = "RANGE_CONTROL"
		_ai_move = Vector2(_ai_lateral_direction * 0.62, -0.45)
	else:
		var roll := randf()
		var defense_chance: float = {"Easy": 0.10, "Medium": 0.19, "Hard": 0.27}.get(difficulty, 0.19)
		if roll < defense_chance:
			ai_state = "DEFEND"
			block_state = ["left", "right", "body"].pick_random()
			_ai_move = Vector2.ZERO
		elif roll < 0.62 and stats.stamina > 12.0 and _ai_attack_cooldown <= 0.0 and distance <= 1.55:
			_begin_ai_attack(distance)
		elif roll < 0.82:
			ai_state = "RANGE_CONTROL"
			_ai_move = Vector2(_ai_lateral_direction * randf_range(0.18, 0.52), clampf((distance - 1.70) * 0.45, -0.28, 0.28))
		else:
			if randf() < 0.34:
				_ai_lateral_direction *= -1.0
			ai_state = "CIRCLE"
			_ai_move = Vector2(_ai_lateral_direction * randf_range(0.55, 0.82), randf_range(-0.12, 0.18))
	set_movement_intent(_ai_move)
	return _ai_move


func _begin_ai_guard() -> void:
	ai_state = "DEFEND"
	_ai_move = Vector2.ZERO
	var incoming := CombatRules.attack_data(str(opponent._current_attack)) if is_instance_valid(opponent) else {}
	if str(incoming.get("target_level", "head")) == "body":
		block_state = "body"
	else:
		block_state = "right" if str(incoming.get("hand", "left")) == "right" else "left"
	_ai_guard_time = {"Easy": 0.34, "Medium": 0.48, "Hard": 0.62}.get(difficulty, 0.48)
	_ai_guard_cooldown = {"Easy": 1.85, "Medium": 1.35, "Hard": 0.95}.get(difficulty, 1.35)


func _begin_ai_attack(distance: float) -> void:
	ai_state = "ATTACK"
	_ai_last_attack = _choose_ai_attack(distance)
	_ai_move = Vector2.ZERO
	request_attack(_ai_last_attack)
	if _current_attack != "":
		_ai_attack_cooldown = _next_ai_attack_cooldown()


func _next_ai_attack_cooldown() -> float:
	var base: float = {"Easy": 1.25, "Medium": 0.92, "Hard": 0.68}.get(difficulty, 0.92)
	return base + randf_range(-0.08, 0.14)


func _combat_range(distance: float) -> String:
	var state: int = FootworkModel.classify_range(distance, outside_range_distance, long_range_distance, mid_range_distance, too_close_distance)
	return FootworkModel.RangeState.keys()[state]


func _update_range_state() -> void:
	if not is_instance_valid(opponent):
		_distance_to_opponent = INF
		range_state = FootworkModel.RangeState.OUTSIDE
		return
	var offset := opponent.global_position - global_position
	offset.y = 0.0
	_distance_to_opponent = offset.length()
	range_state = FootworkModel.classify_range(
		_distance_to_opponent,
		outside_range_distance,
		long_range_distance,
		mid_range_distance,
		too_close_distance
	)


func get_range_state_name() -> String:
	return FootworkModel.RangeState.keys()[range_state]


func get_distance_to_opponent() -> float:
	_update_range_state()
	return _distance_to_opponent


func get_combat_range_state() -> int:
	_update_range_state()
	return range_state


func get_buffered_attack_count() -> int:
	return _buffered_attacks.size()


func get_next_buffered_attack() -> String:
	return _buffered_attacks[0] if not _buffered_attacks.is_empty() else ""


func request_defense(defense_name: String) -> bool:
	if _knocked_down or _reaction_time > 0.0 or not fight_enabled:
		return false
	if not _can_defense_cancel(defense_name):
		return false
	_register_defense_attempt()
	match defense_name:
		"high_block":
			block_state = "left"
			evasion_state = ""
			combat_state = "BLOCK"
			_play_defense_animation("block_left", 0.20)
			defense_used.emit(self, "block")
			return true
		"body_block":
			block_state = "body"
			evasion_state = ""
			combat_state = "BLOCK"
			_play_defense_animation("block_body", 0.20)
			defense_used.emit(self, "block")
			return true
		"slip_left", "slip_right", "duck", "lean_back":
			var cost: float = float({"slip_left": 2.2, "slip_right": 2.2, "duck": 2.0, "lean_back": 2.8}.get(defense_name, 2.0))
			if stats.stamina < cost * 0.5:
				return false
			stats.stamina = maxf(0.0, stats.stamina - cost)
			block_state = ""
			evasion_state = defense_name
			_defense_time = float({"slip_left": 0.24, "slip_right": 0.24, "duck": 0.28, "lean_back": 0.26}.get(defense_name, 0.24))
			combat_state = defense_name.to_upper()
			_play_defense_animation(_defense_animation(defense_name), _defense_time)
			defense_used.emit(self, "slip")
			stats_changed.emit(self)
			return true
		"pivot_escape":
			return request_pivot(-1.0 if is_player else 1.0)
	return false


func get_guard_ratio() -> float:
	return clampf(guard_stamina / maxf(max_guard_stamina, 0.01), 0.0, 1.0)


func get_stability_ratio() -> float:
	return clampf(stability / maxf(max_stability, 0.01), 0.0, 1.0)


func is_counter_hit() -> bool:
	return _last_received_counter


func consume_counter_opportunity() -> bool:
	if counter_window <= 0.0:
		return false
	counter_window = 0.0
	return true


func get_technical_combat_debug() -> Dictionary:
	return {
		"guard": guard_stamina,
		"stability": stability,
		"fatigue": long_term_fatigue,
		"head_damage": head_damage,
		"body_damage": body_damage,
		"evasion": evasion_state,
		"counter_window": counter_window,
		"wobble": _wobble_time,
	}


func _stamina_performance_scale() -> float:
	return CombatRules.stamina_performance_scale(float(stats.stamina), float(stats.max_stamina))


func _world_direction_to_input(world_direction: Vector3) -> Vector2:
	var forward := _horizontal_direction_to_opponent()
	var right := forward.cross(Vector3.UP).normalized()
	return Vector2(world_direction.dot(right), world_direction.dot(forward)).limit_length(1.0)


func _choose_ai_attack(distance: float) -> String:
	if distance > 1.45:
		return "jab"
	if distance > 1.12:
		return ["jab", "cross", "cross", "left_hook", "right_hook"].pick_random()
	return ["left_hook", "right_hook", "uppercut"].pick_random()

func _resolve_animation_player() -> AnimationPlayer:
	var configured := get_node_or_null(animation_player_path) as AnimationPlayer
	if configured != null:
		return configured
	return find_child("*AnimationPlayer*", true, false) as AnimationPlayer

func _resolve_skeleton() -> Skeleton3D:
	var configured := get_node_or_null(skeleton_path) as Skeleton3D
	if configured != null:
		return configured
	return find_child("*Skeleton3D*", true, false) as Skeleton3D

func _configure_ai_planner() -> void:
	if is_player or get_node_or_null("BoxingAIPlanner") != null:
		return
	ai_planner = AIPlanner.new()
	ai_planner.name = "BoxingAIPlanner"
	add_child(ai_planner)
	ai_planner.setup(self)

func _configure_animation_libraries() -> void:
	if animation_player == null or skeleton == null:
		return
	_install_unarmed_support_library()
	for library_name in animation_player.get_animation_library_list():
		var source_library := animation_player.get_animation_library(library_name)
		if source_library == null:
			continue
		var retargeted_library := AnimationLibrary.new()
		for animation_name in source_library.get_animation_list():
			var animation := source_library.get_animation(animation_name)
			if animation == null:
				continue
			retargeted_library.add_animation(animation_name, _retarget_animation_to_skeleton(animation))
		animation_player.remove_animation_library(library_name)
		animation_player.add_animation_library(library_name, retargeted_library)


func _install_unarmed_support_library() -> void:
	if animation_player.has_animation_library("UnarmedSupport"):
		return
	var library := AnimationLibrary.new()
	for animation_name in UNARMED_SUPPORT_SOURCES:
		var animation := load(str(UNARMED_SUPPORT_SOURCES[animation_name])) as Animation
		if animation != null:
			library.add_animation(animation_name, animation)
	animation_player.add_animation_library("UnarmedSupport", library)


func _retarget_animation_to_skeleton(source: Animation) -> Animation:
	var animation := source.duplicate(true) as Animation
	for track_index in range(animation.get_track_count()):
		var path := str(animation.track_get_path(track_index))
		if not path.begins_with("Skeleton3D:"):
			continue
		var bone_path := path.get_slice(":", 1)
		var bone_name := bone_path.get_slice("/", 0)
		if skeleton.find_bone(bone_name) >= 0:
			continue
		var target_bone := str(HUMANOID_BONE_ALIASES.get(bone_name, bone_name))
		var prefixed_bone := "mixamorig_" + target_bone
		if skeleton.find_bone(prefixed_bone) >= 0:
			var suffix := bone_path.substr(bone_name.length())
			animation.track_set_path(track_index, NodePath("Skeleton3D:%s%s" % [prefixed_bone, suffix]))
	return animation

func _normalize_footwork_animations() -> void:
	if animation_player == null:
		return
	for locomotion_name in ["step_short", "medium_step", "step_forward", "step_backward", "step_left", "step_right"]:
		var animation_name: String = "Boxing/" + str(locomotion_name)
		if animation_player.has_animation(animation_name):
			var animation := animation_player.get_animation(animation_name)
			animation.loop_mode = Animation.LOOP_LINEAR
			_zero_horizontal_hips_drift(animation)
	for pivot_name in ["pivot_left", "pivot_right"]:
		var animation_name: String = "Boxing/" + str(pivot_name)
		if animation_player.has_animation(animation_name):
			var animation := animation_player.get_animation(animation_name)
			animation.loop_mode = Animation.LOOP_NONE
			_zero_horizontal_hips_drift(animation)

func _zero_horizontal_hips_drift(animation: Animation) -> void:
	for track_index in range(animation.get_track_count()):
		if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D or not str(animation.track_get_path(track_index)).to_lower().contains("hips"):
			continue
		if animation.track_get_key_count(track_index) < 1:
			continue
		var origin: Vector3 = animation.track_get_key_value(track_index, 0)
		for key_index in range(animation.track_get_key_count(track_index)):
			var value: Vector3 = animation.track_get_key_value(track_index, key_index)
			value.x = origin.x
			value.z = origin.z
			animation.track_set_key_value(track_index, key_index, value)

func _move_relative_to_opponent(input_vector: Vector2, delta: float) -> void:
	# Base de combate relativa al rival.
	var opponent_position := global_position + _last_forward

	if is_instance_valid(opponent):
		opponent_position = opponent.global_position

	var basis: Dictionary = FootworkModel.combat_basis(
		global_position,
		opponent_position,
		_last_forward
	)

	var forward: Vector3 = basis.forward
	var right: Vector3 = basis.right

	# ---------------------------------------------------------
	# STAMINA
	# ---------------------------------------------------------
	var stamina_ratio: float = clampf(
		stats.stamina / maxf(stats.max_stamina, 0.01),
		0.0,
		1.0
	)

	var stamina_scale: float = _stamina_performance_scale()

	# ---------------------------------------------------------
	# LONG STEP
	# ---------------------------------------------------------
	var long_multiplier: float = 1.0

	if _long_step_time > 0.0 and input_vector.y > 0.0:
		long_multiplier = 1.18

	# ---------------------------------------------------------
	# VELOCIDAD BASE
	# ---------------------------------------------------------
	var target_velocity: Vector3 = FootworkModel.relative_velocity(
		input_vector,
		forward,
		right,
		forward_speed * stamina_scale * long_multiplier,
		backward_speed * stamina_scale,
		lateral_speed * stamina_scale
	)

	# ---------------------------------------------------------
	# ORBITADO ALREDEDOR DEL RIVAL
	# ---------------------------------------------------------
	if is_instance_valid(opponent):
		var to_opponent := opponent.global_position - global_position
		to_opponent.y = 0.0

		var distance := to_opponent.length()

		if distance > 0.01:
			var radial_direction := to_opponent / distance

			# Vector tangencial al círculo alrededor del rival.
			var tangent := Vector3(
				-radial_direction.z,
				0.0,
				radial_direction.x
			)

			# Cuanto más lateral sea el input, más domina el orbitado.
			var lateral_amount := absf(input_vector.x)

			if lateral_amount > 0.05:
				var orbit_direction := tangent * input_vector.x
				var orbit_speed := lateral_speed * stamina_scale

				var orbit_velocity := orbit_direction * orbit_speed

				# Conservamos parte del componente adelante/atrás.
				var radial_velocity := radial_direction * input_vector.y

				if input_vector.y >= 0.0:
					radial_velocity *= forward_speed * stamina_scale * long_multiplier
				else:
					radial_velocity *= backward_speed * stamina_scale

				var professional_velocity := orbit_velocity + radial_velocity

				target_velocity = target_velocity.lerp(
					professional_velocity,
					clampf(lateral_amount * 0.85, 0.0, 0.85)
				)

	# ---------------------------------------------------------
	# SEPARACIÓN ENTRE BOXEADORES
	# ---------------------------------------------------------
	target_velocity = _body_separation_velocity(target_velocity)

	_target_speed = target_velocity.length()

	# ---------------------------------------------------------
	# ACELERACIÓN / FRENADO
	# ---------------------------------------------------------
	var rate := acceleration

	if target_velocity.length_squared() <= 0.0001:
		rate = deceleration

	_smoothed_velocity = _smoothed_velocity.move_toward(
		target_velocity,
		rate * delta
	)

	_smoothed_velocity = _body_separation_velocity(_smoothed_velocity)

	velocity = Vector3(
		_smoothed_velocity.x,
		0.0,
		_smoothed_velocity.z
	)

	move_and_slide()
	_apply_ring_limit()

	# ---------------------------------------------------------
	# ANIMACIONES DE FOOTWORK
	# ---------------------------------------------------------
	_update_footwork(input_vector, delta)

	# ---------------------------------------------------------
	# COSTE DE STAMINA POR MOVIMIENTO INTENSO
	# ---------------------------------------------------------
	if input_vector.length() > 0.75:
		var stamina_before: float = stats.stamina

		stats.stamina = maxf(
			0.0,
			stats.stamina - 0.7 * delta
		)

		if int(stamina_before) != int(stats.stamina):
			stats_changed.emit(self)


func _update_footwork(input_vector: Vector2, delta: float) -> void:
	_move_blend = _move_blend.lerp(input_vector, 1.0 - exp(-7.5 * delta))
	animation_tree.set("parameters/Footwork/blend_position", _move_blend)
	var tier: int = FootworkModel.movement_tier(movement_intensity, short_step_threshold, medium_step_threshold, long_step_threshold)
	if _long_step_time > 0.0 and input_vector.y > 0.0:
		tier = FootworkModel.TIER_LONG
	elif tier == FootworkModel.TIER_LONG:
		tier = FootworkModel.TIER_MEDIUM
	locomotion_state = ["IDLE", "SHORT", "MEDIUM", "LONG"][tier]
	if animation_tree.active:
		var speed_ratio := velocity.length() / maxf(_target_speed, 0.01) if _target_speed > 0.01 else 1.0
		animation_player.speed_scale = clampf(speed_ratio, 0.86, 1.16)


func _face_opponent(delta: float) -> void:
	if not is_instance_valid(opponent):
		return
	var forward := _horizontal_direction_to_opponent()
	if forward.length_squared() < 0.001:
		return
	var desired_yaw := atan2(-forward.x, -forward.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, 1.0 - exp(-turn_responsiveness * delta))
	_last_forward = forward


func _horizontal_direction_to_opponent() -> Vector3:
	if not is_instance_valid(opponent):
		return _last_forward
	var direction := opponent.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.000001:
		return _last_forward
	return direction.normalized()


func _update_defense() -> void:
	if not is_player:
		if _current_attack != "":
			return
		combat_state = "BLOCK" if block_state != "" else "IDLE"
		if block_state != "" and animation_tree.active:
			_play_brief_animation("block_" + block_state, _ai_guard_time)
		return
	for defense_action in ["slip_left", "slip_right", "duck", "lean_back"]:
		if InputMap.has_action(defense_action) and Input.is_action_just_pressed(defense_action):
			request_defense(defense_action)
			return
	if Input.is_action_pressed("gamepad_guard"):
		var guard_direction := _player_input()
		block_state = "body" if guard_direction.y < -0.55 else ("right" if guard_direction.x > 0.3 else "left")
	else:
		block_state = "body" if Input.is_action_pressed("block_body") else ("left" if Input.is_action_pressed("block_left") else ("right" if Input.is_action_pressed("block_right") else ""))
	combat_state = "BLOCK" if block_state != "" else "IDLE"
	if block_state != "" and not animation_player.is_playing():
		_play_brief_animation("block_" + block_state, 0.28)


func _can_defense_cancel(defense_name: String) -> bool:
	if _current_attack == "":
		return true
	var attack := CombatRules.attack_data(_current_attack)
	if attack.is_empty():
		return false
	var is_light := str(attack.attack_name) == "jab"
	if combat_state == "RECOVERY" and is_light and _recovery_time <= float(attack.recovery) * 0.58:
		_finish_action()
		return true
	return false


func _register_defense_attempt() -> void:
	if _defense_spam_window <= 0.0:
		_defense_spam_window = 0.7
		_defense_spam_count = 0
	_defense_spam_count += 1
	if _defense_spam_count > 1:
		stats.stamina = maxf(0.0, stats.stamina - Balance.DEFENSE_SPAM_COST * _defense_spam_count)
		guard_stamina = maxf(0.0, guard_stamina - Balance.DEFENSE_SPAM_COST)


func defense_quality_for_impact(frames_before_impact: int) -> String:
	if frames_before_impact >= 0 and frames_before_impact <= Balance.PERFECT_DEFENSE_FRAMES:
		return "PERFECT"
	if frames_before_impact > Balance.PERFECT_DEFENSE_FRAMES and frames_before_impact <= Balance.NORMAL_DEFENSE_FRAMES:
		return "NORMAL"
	return "LATE"


func apply_defense_quality(quality: String) -> void:
	match quality:
		"PERFECT":
			counter_window = maxf(counter_window, 0.30)
			guard_stamina = minf(max_guard_stamina, guard_stamina + 4.0)
		"NORMAL":
			counter_window = maxf(counter_window, 0.12)
		"LATE":
			stats.stamina = maxf(0.0, stats.stamina - 1.5)


func change_guard_level(level: String) -> void:
	var normalized := "body" if level == "body" else "head"
	if normalized != _last_guard_level:
		guard_switch_frames_left = Balance.GUARD_SWITCH_FRAMES
	_last_guard_level = normalized
	block_state = "body" if normalized == "body" else "left"


func _defense_animation(defense_name: String) -> String:
	match defense_name:
		"slip_left":
			return "UnarmedSupport/dodge_left" if animation_player.has_animation("UnarmedSupport/dodge_left") else "pivot_left"
		"slip_right":
			return "UnarmedSupport/dodge_right" if animation_player.has_animation("UnarmedSupport/dodge_right") else "pivot_right"
		"lean_back":
			return "UnarmedSupport/dodge_backward" if animation_player.has_animation("UnarmedSupport/dodge_backward") else "step_backward"
		"duck":
			return "block_body"
	return "boxing_idle"


func _play_defense_animation(animation_name: String, duration: float) -> void:
	animation_tree.active = false
	animation_player.speed_scale = 1.0
	var full_name := animation_name if animation_name.contains("/") else "Boxing/" + animation_name
	if animation_player.has_animation(full_name):
		animation_player.play(full_name, 0.04)
	get_tree().create_timer(duration).timeout.connect(func():
		if _current_attack == "" and _reaction_time <= 0.0 and not _knocked_down and _defense_time <= 0.0:
			_finish_action()
	)


func _update_defense_timers(delta: float) -> void:
	_defense_time = maxf(0.0, _defense_time - delta)
	_wobble_time = maxf(0.0, _wobble_time - delta)
	if evasion_state != "" and _defense_time <= 0.0:
		evasion_state = ""
	if combat_state == "WOBBLED" and _wobble_time <= 0.0 and _reaction_time <= 0.0:
		stability = minf(max_stability, stability + 18.0)
		_finish_action()


func _attack_is_evaded(attack: Dictionary, zone: String) -> bool:
	if evasion_state == "" or _defense_time <= 0.0:
		return false
	var target_group := CombatRules.zone_group(zone)
	var attack_type := str(attack.get("attack_type", ""))
	if evasion_state.begins_with("slip"):
		return target_group == "head" and attack_type == "straight"
	if evasion_state == "duck":
		return target_group == "head" and attack_type == "straight"
	if evasion_state == "lean_back":
		return target_group == "head" and attack_type == "straight"
	return false


func _block_covers_zone(zone: String) -> bool:
	var target_group := CombatRules.zone_group(zone)
	return block_state == "body" and target_group == "body" or block_state in ["left", "right"] and target_group == "head"


func _play_reaction_animation(animation_name: String, blend := 0.04) -> void:
	var full_name := animation_name if animation_name.contains("/") else "Boxing/" + animation_name
	if not animation_player.has_animation(full_name):
		full_name = "Boxing/hit_reaction"
	animation_tree.active = false
	animation_player.speed_scale = 1.0
	animation_player.play(full_name, blend)


func _handle_attack_input() -> void:
	if not is_player:
		return
	for action in ["jab", "cross", "left_hook", "right_hook", "uppercut"]:
		if Input.is_action_just_pressed(action):
			request_attack(action)
			return
	if Input.is_action_just_pressed("punch_left"):
		if Input.is_action_pressed("hook_modifier"):
			request_attack("left_hook")
		elif Input.is_action_pressed("uppercut_modifier"):
			# The imported library has no distinct left uppercut clip; keep the slot reserved.
			return
		elif not Input.is_action_pressed("body_modifier"):
			request_attack("jab")
		return
	if Input.is_action_just_pressed("punch_right"):
		if Input.is_action_pressed("hook_modifier"):
			request_attack("right_hook")
		elif Input.is_action_pressed("uppercut_modifier"):
			request_attack("uppercut")
		else:
			request_attack("cross")
		return


func request_attack(attack_name: String) -> void:
	if not fight_enabled or _knocked_down or _reaction_time > 0.0 or combat_state in ["WOBBLED", "KNOCKDOWN", "GUARD_BREAK"]:
		return
	var attack := CombatRules.attack_data(attack_name)
	if attack.is_empty():
		return
	if _current_attack != "":
		_queue_attack(attack_name)
		return
	if stats.stamina < attack.cost * 0.45:
		return
	punch_thrown.emit(self, attack_name)
	_attack_instance_id += 1
	_hit_targets.clear()
	_current_attack = attack_name
	combat_state = "STARTUP"
	_strike_done = false
	_last_hit_result = "MISS"
	_last_hit_damage = 0.0
	_last_counter = false
	_attack_input = _player_input() if is_player else _ai_move
	var forward_amount := _attack_input.y
	_attack_momentum = clampf(1.0 + forward_amount * 0.06, 0.94, 1.06)
	var speed: float = stats.punch_speed * float(attack.animation_speed) * _stamina_performance_scale()
	_action_time = attack.startup / speed
	_active_time = attack.active_time / speed
	var fatigue_recovery := lerpf(1.34, 1.0, _stamina_performance_scale())
	_recovery_time = attack.recovery * fatigue_recovery / speed
	stats.stamina = maxf(0.0, stats.stamina - CombatRules.stamina_cost(attack_name, false))
	animation_tree.active = false
	animation_player.speed_scale = speed
	procedural_move_frame = 0
	if _uses_procedural_attack(attack_name, attack):
		animation_player.play("Boxing/" + str(attack.animation_name), 0.0)
		animation_tree.active = true
		var playback = animation_tree.get("parameters/playback")
		if playback:
			playback.travel("Footwork")
	else:
		animation_player.play("Boxing/" + str(attack.animation_name), 0.07)
	stats_changed.emit(self)


func _update_attack(delta: float) -> void:
	var attack := CombatRules.attack_data(_current_attack)
	if attack.is_empty():
		_finish_action()
		return
	procedural_move_frame += 1
	_update_attack_movement(delta, attack)
	var remaining := delta
	if combat_state == "STARTUP":
		_track_attack_target(delta, float(attack.tracking_strength))
		_action_time -= remaining
		if _action_time > 0.0: return
		remaining = -_action_time
		combat_state = "ACTIVE"
		procedural_move_frame = int(round(float(attack.get("startup_frames", procedural_move_frame))))
		_strike_done = true
		_set_fist_active(true)
		_attempt_strike()
	if combat_state == "ACTIVE":
		_active_time -= remaining
		if _active_time > 0.0: return
		remaining = -_active_time
		_set_fist_active(false)
		combat_state = "RECOVERY"
		procedural_move_frame = 0
	if combat_state != "RECOVERY": return
	_recovery_time -= remaining
	if _buffered_attack != "" and _buffer_time > 0.0 and _recovery_time <= float(attack.cancel_window) + 0.12:
		var queued := _pop_buffered_attack()
		_current_attack = ""
		request_attack(queued)
		return
	if _recovery_time <= 0.0:
		_finish_action()


func _update_attack_movement(delta: float, attack: Dictionary) -> void:
	var raw_command := _player_input() if is_player else _attack_input
	var command: Vector2 = FootworkModel.apply_radial_deadzone(raw_command, input_deadzone)
	_raw_movement_input = raw_command
	_movement_intent = command
	movement_intensity = command.length()
	var basis: Dictionary = FootworkModel.combat_basis(global_position, opponent.global_position if is_instance_valid(opponent) else global_position + _last_forward, _last_forward)
	var allowed_speed: float = stats.movement_speed * float(attack.movement_allowed) * _stamina_performance_scale()
	var target: Vector3 = FootworkModel.relative_velocity(command, basis.forward, basis.right, allowed_speed, allowed_speed * 0.82, allowed_speed * 0.9)
	if combat_state == "STARTUP" and command.y > 0.05:
		target += basis.forward * float(attack.step_in) * command.y
	target = _body_separation_velocity(target)
	_target_speed = target.length()
	_smoothed_velocity = _smoothed_velocity.move_toward(target, 8.0 * delta)
	velocity = _body_separation_velocity(Vector3(_smoothed_velocity.x, 0.0, _smoothed_velocity.z))
	move_and_slide()
	_apply_ring_limit()
	_update_footwork(command, delta)


func _track_attack_target(delta: float, strength: float) -> void:
	if not is_instance_valid(opponent): return
	var direction := _horizontal_direction_to_opponent()
	var desired_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, 1.0 - exp(-7.0 * strength * delta))


func _attempt_strike() -> void:
	if not is_instance_valid(opponent) or not opponent.has_method("receive_hit"):
		return
	if _hit_targets.has(opponent.get_instance_id()):
		return
	var attack := CombatRules.attack_data(_current_attack)
	if attack.is_empty(): return
	var target_area := opponent.get_node_or_null("Hurtboxes/Body" if attack.target_level == "body" else "Hurtboxes/Head") as Area3D
	var target_position: Vector3 = target_area.global_position if target_area else opponent.global_position
	var origin: Vector3 = _procedural_hand_position(str(attack.hand), (left_fist if attack.hand == "left" else right_fist).global_position)
	var to_target := target_position - origin
	var planar := Vector3(to_target.x, 0.0, to_target.z)
	var direction := planar.normalized()
	var facing := -global_basis.z.dot(direction)
	var distance := global_position.distance_to(opponent.global_position)
	_last_hit_distance = distance
	if distance >= float(attack.min_range) and distance <= float(attack.range) and facing > 0.58:
		var quality := clampf(CombatRules.impact_quality_for_distance(_current_attack, distance, 0.0) * 0.72 + facing * 0.28, 0.15, 1.0)
		var counter: bool = str(opponent.combat_state) in ["STARTUP", "RECOVERY"]
		var result: Dictionary = opponent.receive_hit(_current_attack, attack.target_level, stats.stamina, counter, quality, _attack_momentum, signf(global_basis.x.dot(direction)))
		if not result.is_empty():
			result["attack_name"] = _current_attack
			_hit_targets[opponent.get_instance_id()] = _attack_instance_id
			_last_hit_result = str(result.result)
			_last_hit_damage = float(result.damage)
			_last_counter = bool(result.counter)
			round_hits += 1
			round_damage += float(result.damage)
			punch_landed.emit(self, opponent, result)
	else:
		var miss_cost := CombatRules.stamina_cost(_current_attack, true) - CombatRules.stamina_cost(_current_attack, false)
		stats.stamina = maxf(0.0, stats.stamina - maxf(0.0, miss_cost))
		_recovery_time += float(attack.get("recovery", 0.0)) * float(attack.get("whiff_recovery_extra", 0.15))
		_last_hit_result = "MISS"
		var events := get_node_or_null("/root/Events")
		if events != null and events.has_signal("punch_missed"):
			events.emit_signal("punch_missed", self, _current_attack)


func preview_hit(attack_name: String) -> Dictionary:
	var attack := CombatRules.attack_data(attack_name)
	if attack.is_empty() or not is_instance_valid(opponent): return {"result":"MISS"}
	var distance := global_position.distance_to(opponent.global_position)
	if distance < float(attack.min_range) or distance > float(attack.range): return {"result":"MISS"}
	var guarded: bool = opponent._block_covers_zone(str(attack.target_level))
	return CombatRules.calculate_hit(attack_name, attack.target_level, stats.stamina, opponent.stats.defense, guarded, opponent.combat_state in ["STARTUP", "RECOVERY"], 0.85, _attack_momentum)


func receive_hit(attack_name: String, zone: String, attacker_stamina: float, counter: bool, impact_quality := 1.0, momentum := 1.0, lateral_direction := 0.0) -> Dictionary:
	if _knocked_down or recovery_protection > 0.0:
		return {}
	var attack := CombatRules.attack_data(attack_name)
	if attack.is_empty():
		return {}
	var target_group := CombatRules.zone_group(zone)
	if _attack_is_evaded(attack, zone):
		counter_window = 0.42
		evasion_state = ""
		_defense_time = 0.0
		var events := get_node_or_null("/root/Events")
		if events != null and events.has_signal("punch_slipped"):
			events.emit_signal("punch_slipped", null, self, {"attack_name": attack_name, "zone": zone})
		return {"result":"EVADED", "damage":0.0, "stun":0.0, "stamina_damage":0.0, "counter_bonus":1.0, "blocked":false, "counter":false, "is_counter_hit":false, "target_group":target_group, "zone":zone, "stability_loss":0.0, "guard_broken":false}
	var guarded := _block_covers_zone(zone)
	var forced_counter := counter or combat_state in ["STARTUP", "RECOVERY"] or counter_window > 0.0
	var result := CombatRules.calculate_hit(attack_name, zone, attacker_stamina, stats.defense, guarded, forced_counter, impact_quality, momentum, _combo_hit_count)
	if _near_rope_or_corner():
		result.damage = float(result.damage) * Balance.CORNER_DAMAGE_BONUS
		result.stability_loss = float(result.stability_loss) * Balance.CORNER_DAMAGE_BONUS
	if str(attack.get("target_level", zone)) == "body" and str(attack.get("attack_type", "")).contains("hook") and stats.stamina < 28.0:
		result.stun = float(result.stun) + Balance.LIVER_SHOT_STUN
	_last_received_counter = bool(result.is_counter_hit)
	_combo_hit_count += 1
	_combo_timer = 1.15
	if guarded:
		var guard_damage := float(result.stamina_damage) * (1.0 + clampf(body_damage / 120.0, 0.0, 0.35))
		guard_stamina = maxf(0.0, guard_stamina - guard_damage)
		stats.stamina = maxf(0.0, stats.stamina - guard_damage * 0.45)
		counter_window = 0.18 if impact_quality >= 0.92 else counter_window
		if guard_stamina <= 0.0:
			result.guard_broken = true
			result.blocked = false
			result.result = "GUARD_BREAK"
			combat_state = "GUARD_BREAK"
			block_state = ""
			_reaction_time = 0.34
			_play_reaction_animation("UnarmedSupport/block_get_hit_2")
		else:
			result.guard_broken = false
			_reaction_time = clampf(0.08 + float(result.stun) * 0.004, 0.08, 0.18)
			combat_state = "BLOCK_HIT"
			_play_reaction_animation("UnarmedSupport/block_get_hit_1")
			stats_changed.emit(self)
			return result
	else:
		result.guard_broken = false
	stats.health = maxf(0.0, stats.health - float(result.damage))
	stats.stamina = maxf(0.0, stats.stamina - float(result.stamina_damage))
	stats.stun = minf(stats.max_stun, stats.stun + float(result.stun))
	if target_group == "head":
		head_damage = minf(100.0, head_damage + float(result.damage) * 1.05)
		stats.head_health = maxf(0.0, stats.head_health - float(result.damage) * 1.15)
	else:
		body_damage = minf(100.0, body_damage + float(result.damage) * 1.15)
		long_term_fatigue = minf(65.0, long_term_fatigue + float(result.damage) * 0.18)
		stats.body_health = maxf(0.0, stats.body_health - float(result.damage) * 1.2)
	var fatigue_bonus := (1.0 - _stamina_performance_scale()) * 12.0
	var accumulated_bonus := head_damage * 0.06 if target_group == "head" else body_damage * 0.012
	var stability_loss := float(result.stability_loss) + fatigue_bonus + accumulated_bonus
	result.stability_loss = stability_loss
	stability = maxf(0.0, stability - stability_loss)
	stats_changed.emit(self)
	var flash_knockdown := forced_counter and impact_quality >= 0.95 and stability < max_stability * 0.34 and str(result.severity) == "HEAVY"
	if FightRules.should_knockdown(stats.health, stats.head_health, stats.stun - float(result.stun), float(result.stun)) or stability <= 0.0 or flash_knockdown:
		knockdown_requested.emit(self)
		begin_knockdown()
		return result
	if stability < max_stability * 0.28 or stats.stun >= 62.0:
		_begin_wobble(result, lateral_direction)
		_emit_fighter_event("wobbled", [self, null, result])
	elif not guarded:
		var reaction := _reaction_for_hit(attack_name, target_group, lateral_direction, str(result.severity))
		_reaction_time = clampf(0.08 + float(result.stun) * 0.008, 0.10, 0.34)
		combat_state = "STUNNED"
		_play_reaction_animation(reaction)
		_emit_fighter_event("stunned", [self, null, result])
	if not result.is_empty():
		_apply_procedural_hit_reaction(attack_name, result, lateral_direction)
	return result


func _reaction_for_hit(attack_name: String, target_group: String, lateral_direction: float, severity: String) -> String:
	if target_group == "body":
		return "hit_kidney" if lateral_direction < 0.0 else "hit_rib"
	if attack_name == "uppercut":
		return "hit_uppercut"
	if animation_player.has_animation("UnarmedSupport/get_hit_left") and absf(lateral_direction) > 0.35 and severity != "LIGHT":
		return "UnarmedSupport/get_hit_left" if lateral_direction < 0.0 else "UnarmedSupport/get_hit_right"
	if animation_player.has_animation("UnarmedSupport/get_hit_back") and severity == "HEAVY":
		return "UnarmedSupport/get_hit_back"
	return "hit_reaction"


func _begin_wobble(result: Dictionary, lateral_direction: float) -> void:
	combat_state = "WOBBLED"
	_wobble_time = clampf(0.85 + float(result.stun) * 0.018, 0.9, 2.2)
	_reaction_time = minf(_wobble_time, 0.34)
	block_state = ""
	_clear_attack_buffer()
	_set_fist_active(false)
	_smoothed_velocity *= 0.35
	_play_reaction_animation("UnarmedSupport/stunned" if animation_player.has_animation("UnarmedSupport/stunned") else _reaction_for_hit("", "head", lateral_direction, "HEAVY"))


func begin_knockdown() -> void:
	if _knocked_down:
		return
	_knocked_down = true
	knockdowns += 1
	round_knockdowns += 1
	combat_state = "KNOCKDOWN"
	fight_enabled = false
	block_state = ""
	evasion_state = ""
	_clear_attack_buffer()
	_set_fist_active(false)
	animation_tree.active = false
	if animation_player.has_animation("UnarmedSupport/knockdown"):
		animation_player.speed_scale = 1.0
		animation_player.play("UnarmedSupport/knockdown", 0.04)
	else:
		animation_player.stop()
		var tween := create_tween()
		tween.tween_property(self, "rotation:z", deg_to_rad(82.0) * (-1.0 if is_player else 1.0), 0.42).set_trans(Tween.TRANS_QUAD)
		tween.parallel().tween_property(self, "position:y", 0.18, 0.42)
	knockdown_started.emit(self)
	if knockdowns >= 3:
		boxer_tko_candidate.emit(self)


func recover_from_knockdown() -> void:
	rotation.z = 0.0
	position.y = 0.0
	_knocked_down = false
	stats.health = maxf(18.0, stats.health)
	stats.head_health = maxf(15.0, stats.head_health)
	stats.stun = minf(30.0, stats.stun)
	var get_up_penalty := clampf((head_damage + body_damage + long_term_fatigue) / 260.0, 0.0, 0.45)
	stats.stamina = clampf(maxf(stats.stamina, 24.0) - long_term_fatigue * 0.12 - get_up_penalty * 18.0, 14.0, stats.max_stamina)
	stability = maxf(max_stability * 0.34, stability)
	recovery_protection = 0.55
	fight_enabled = true
	animation_tree.active = false
	animation_player.speed_scale = 1.0
	var get_up_animation := "UnarmedSupport/get_up" if animation_player.has_animation("UnarmedSupport/get_up") else "Boxing/get_up"
	animation_player.play(get_up_animation, 0.08)
	await get_tree().create_timer(0.7).timeout
	_finish_action()


func reset_for_round(spawn_position: Vector3) -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	_smoothed_velocity = Vector3.ZERO
	stats.max_stamina = maxf(55.0, stats.max_stamina * (1.0 - Balance.ROUND_FATIGUE))
	stats.stamina = minf(stats.max_stamina, stats.stamina + 24.0)
	stats.stun = maxf(0.0, stats.stun - 55.0)
	guard_stamina = max_guard_stamina
	stability = max_stability
	counter_window = 0.0
	evasion_state = ""
	round_hits = 0
	round_damage = 0.0
	round_knockdowns = 0
	_finish_action()


func move_to_neutral(fallen_position: Vector3) -> void:
	var away := global_position - fallen_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.RIGHT if is_player else Vector3.LEFT
	_neutral_target = fallen_position + away.normalized() * 3.0
	_neutral_target.x = clampf(_neutral_target.x, -3.2, 3.2)
	_neutral_target.z = clampf(_neutral_target.z, -3.2, 3.2)
	_moving_to_neutral = true
	block_state = ""


func release_from_neutral() -> void:
	_moving_to_neutral = false


func _move_to_neutral(delta: float) -> void:
	var offset := _neutral_target - global_position
	offset.y = 0.0
	if offset.length() < 0.08:
		_moving_to_neutral = false
		velocity = Vector3.ZERO
		_update_footwork(Vector2.ZERO, delta)
		return
	var world_direction := offset.normalized()
	var input_direction := _world_direction_to_input(world_direction)
	_move_relative_to_opponent(input_direction * 0.75, delta)


func _finish_action() -> void:
	_set_fist_active(false)
	_current_attack = ""
	procedural_move_frame = 0
	procedural_targets = {}
	_procedural_debug = {}
	_clear_procedural_skeleton_pose()
	_reaction_time = 0.0
	combat_state = "IDLE"
	animation_player.stop()
	animation_player.speed_scale = 1.0
	animation_tree.active = true
	var playback = animation_tree.get("parameters/playback")
	if playback: playback.travel("Footwork")
	if _buffered_attack != "" and _buffer_time > 0.0 and fight_enabled:
		var next := _pop_buffered_attack()
		request_attack(next)


func get_punch_debug() -> Dictionary:
	var data := CombatRules.attack_data(_current_attack)
	return {"attack":_current_attack if _current_attack != "" else "NONE", "phase":combat_state, "hand":str(data.get("hand", "NONE")), "range":float(data.get("range", 0.0)), "target":str(data.get("target_level", "NONE")), "hitbox_active":left_fist.monitoring or right_fist.monitoring, "hit_result":_last_hit_result, "damage":_last_hit_damage, "stamina_cost":float(data.get("stamina_cost", 0.0)), "counter":_last_counter, "distance":_last_hit_distance}


func get_procedural_debug() -> Dictionary:
	return _procedural_debug.duplicate(true)


func _uses_procedural_attack(attack_name: String, attack: Dictionary) -> bool:
	return procedural_presentation_enabled and attack_name == "jab" and float(attack.get("procedural_strength", 0.0)) > 0.0


func _update_procedural_presentation(delta: float) -> void:
	if procedural_motor == null:
		return
	if not procedural_presentation_enabled:
		_clear_procedural_skeleton_pose()
		_update_procedural_recovery_only(delta)
		return
	var attack := CombatRules.attack_data(_current_attack)
	var view = PresentationBridge.fighter_view(self, get_instance_id())
	if attack.is_empty():
		attack = {"procedural_strength": 0.0}
	procedural_targets = procedural_motor.tick(view, attack, delta)
	if not procedural_targets.is_empty():
		_apply_procedural_pose_offsets()
		_procedural_debug = {
			"procedural_strength": procedural_targets.get("procedural_strength", 0.0),
			"frame": procedural_move_frame,
			"active": combat_state == "ACTIVE",
			"punch_target": procedural_targets.get("left_hand", Vector3.ZERO),
			"curve": procedural_motor.last_curve,
			"impact_vector": procedural_motor.last_impact_vector,
			"head_reaction": procedural_targets.get("head_reaction", Vector3.ZERO),
			"active_contact_error": procedural_targets.get("contact_frame_error", 999.0),
			"opposite_guard": procedural_targets.get("chin_protected", false),
			"has_nan": procedural_targets.get("has_nan", false),
		}


func _update_procedural_recovery_only(delta: float) -> void:
	var view = PresentationBridge.fighter_view(self, get_instance_id())
	procedural_targets = procedural_motor.tick(view, {"procedural_strength": 0.0}, delta)


func _apply_procedural_pose_offsets() -> void:
	if skeleton == null:
		return
	_apply_procedural_hand_pose("left", "left_hand")
	_apply_procedural_hand_pose("right", "right_hand")
	_apply_procedural_core_pose()
	var head_offset: Vector3 = procedural_targets.get("head_reaction", Vector3.ZERO)
	var neck_offset: Vector3 = procedural_targets.get("neck_reaction", Vector3.ZERO)
	var core_offset: Vector3 = procedural_targets.get("core_reaction", Vector3.ZERO)
	_apply_bone_rotation(["mixamorig_Head", "Head"], head_offset)
	_apply_bone_rotation(["mixamorig_Neck", "Neck"], neck_offset)
	_apply_bone_rotation(["mixamorig_Spine2", "Spine2", "mixamorig_Spine1", "Spine1"], core_offset * 0.7)
	_apply_bone_rotation(["mixamorig_Hips", "Hips"], core_offset * 0.25)


func _procedural_hand_position(hand: String, fallback: Vector3) -> Vector3:
	if procedural_targets.is_empty():
		return fallback
	if hand == "left" and procedural_targets.has("left_hand"):
		return procedural_targets.left_hand
	if hand == "right" and procedural_targets.has("right_hand"):
		return procedural_targets.right_hand
	return fallback


func _apply_procedural_hit_reaction(attack_name: String, result: Dictionary, lateral_direction: float) -> void:
	if procedural_motor == null or not procedural_presentation_enabled:
		return
	var event := CombatEventView.new()
	event.move_id = StringName(attack_name)
	event.blocked = bool(result.get("blocked", false))
	event.counter = bool(result.get("counter", false))
	event.clean = str(result.get("result", "")) in ["CLEAN_HIT", "COUNTER"]
	event.power_norm = clampf(float(result.get("damage", 0.0)) / 18.0, 0.0, 1.0)
	var lateral := global_basis.x * (1.0 if lateral_direction >= 0.0 else -1.0)
	event.punch_dir = (-global_basis.z * 0.72 + lateral * 0.28).normalized()
	event.hit_point = global_position + Vector3(0.0, body_height * 0.9, 0.0) + lateral * 0.08
	procedural_motor.add_impact(event)
	_update_procedural_presentation(1.0 / 60.0)


func _cache_procedural_bone_rest() -> void:
	if skeleton == null:
		return
	for names in [
		["mixamorig_LeftHand", "LeftHand", "Left_Hand"],
		["mixamorig_RightHand", "RightHand", "Right_Hand"],
		["mixamorig_LeftArm", "LeftArm", "LeftUpperArm"],
		["mixamorig_RightArm", "RightArm", "RightUpperArm"],
		["mixamorig_Hips", "Hips"],
		["mixamorig_Spine", "Spine"],
		["mixamorig_Spine1", "Spine1"],
		["mixamorig_Spine2", "Spine2"],
		["mixamorig_Head", "Head"],
		["mixamorig_Neck", "Neck"],
	]:
		var bone := _find_bone_index(names)
		if bone >= 0 and not _procedural_bone_rest.has(bone):
			_procedural_bone_rest[bone] = {
				"position": skeleton.get_bone_pose_position(bone),
				"rotation": skeleton.get_bone_pose_rotation(bone),
			}


func _apply_procedural_hand_pose(hand: String, target_key: String) -> void:
	if not procedural_targets.has(target_key):
		return
	var names := ["mixamorig_LeftHand", "LeftHand", "Left_Hand"] if hand == "left" else ["mixamorig_RightHand", "RightHand", "Right_Hand"]
	var bone := _find_bone_index(names)
	if bone < 0:
		return
	var rest: Dictionary = _procedural_bone_rest.get(bone, {"position": skeleton.get_bone_pose_position(bone), "rotation": skeleton.get_bone_pose_rotation(bone)})
	var current_global := (left_fist if hand == "left" else right_fist).global_position
	var target: Vector3 = procedural_targets.get(target_key, current_global)
	var local_delta := skeleton.global_transform.basis.inverse() * (target - current_global)
	if local_delta.length() > 0.65:
		local_delta = local_delta.normalized() * 0.65
	var strength := float(procedural_targets.get("procedural_strength", 0.0))
	var defense_strength := 0.0
	if block_state != "":
		defense_strength = 0.72
	elif evasion_state != "":
		defense_strength = 0.82
	strength = maxf(strength, defense_strength)
	if target_key == "right_hand":
		strength = maxf(strength, 0.65 if _current_attack == "jab" else 0.0)
	skeleton.set_bone_pose_position(bone, rest.position + local_delta * strength)
	var arm_names := ["mixamorig_LeftArm", "LeftArm", "LeftUpperArm"] if hand == "left" else ["mixamorig_RightArm", "RightArm", "RightUpperArm"]
	var arm := _find_bone_index(arm_names)
	if arm >= 0:
		var arm_rest: Dictionary = _procedural_bone_rest.get(arm, {"position": skeleton.get_bone_pose_position(arm), "rotation": skeleton.get_bone_pose_rotation(arm)})
		var shoulder_turn := Vector3(0.0, -0.16 if hand == "left" else 0.10, 0.12 if hand == "left" else -0.08) * strength
		skeleton.set_bone_pose_rotation(arm, arm_rest.rotation * Quaternion.from_euler(shoulder_turn))


func _apply_procedural_core_pose() -> void:
	var strength := float(procedural_targets.get("procedural_strength", 0.0))
	if strength <= 0.0:
		return
	var hips := _find_bone_index(["mixamorig_Hips", "Hips"])
	if hips >= 0:
		var rest: Dictionary = _procedural_bone_rest.get(hips, {"position": skeleton.get_bone_pose_position(hips), "rotation": skeleton.get_bone_pose_rotation(hips)})
		skeleton.set_bone_pose_position(hips, rest.position + Vector3(0.0, 0.0, -0.018) * strength)
		skeleton.set_bone_pose_rotation(hips, rest.rotation * Quaternion.from_euler(Vector3(0.0, 0.04, 0.0) * strength))
	var spine := _find_bone_index(["mixamorig_Spine2", "Spine2", "mixamorig_Spine1", "Spine1"])
	if spine >= 0:
		var spine_rest: Dictionary = _procedural_bone_rest.get(spine, {"position": skeleton.get_bone_pose_position(spine), "rotation": skeleton.get_bone_pose_rotation(spine)})
		skeleton.set_bone_pose_rotation(spine, spine_rest.rotation * Quaternion.from_euler(Vector3(0.02, -0.08, 0.03) * strength))


func _apply_bone_rotation(names: Array, euler: Vector3) -> void:
	var bone := _find_bone_index(names)
	if bone < 0:
		return
	var rest: Dictionary = _procedural_bone_rest.get(bone, {"position": skeleton.get_bone_pose_position(bone), "rotation": skeleton.get_bone_pose_rotation(bone)})
	skeleton.set_bone_pose_rotation(bone, rest.rotation * Quaternion.from_euler(euler))


func _clear_procedural_skeleton_pose() -> void:
	if skeleton == null:
		return
	for bone in _procedural_bone_rest.keys():
		var rest: Dictionary = _procedural_bone_rest[bone]
		skeleton.set_bone_pose_position(int(bone), rest.position)
		skeleton.set_bone_pose_rotation(int(bone), rest.rotation)


func _find_bone_index(names: Array) -> int:
	if skeleton == null:
		return -1
	for name in names:
		var bone := skeleton.find_bone(str(name))
		if bone >= 0:
			return bone
	return -1


func apply_fighter_state(state: Dictionary) -> void:
	combat_state = str(state.get("phase", combat_state))
	stats.stamina = float(state.get("stamina", stats.stamina))
	stability = float(state.get("stability", stability))
	guard_stamina = float(state.get("guard", guard_stamina))
	global_position = Vector3(float(state.get("x", global_position.x)), global_position.y, float(state.get("z", global_position.z)))
	rotation.y = float(state.get("yaw", rotation.y))
	_current_attack = str(state.get("attack", _current_attack))
	_action_time = float(state.get("phase_frame", 0)) / 60.0
	if animation_tree != null:
		animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		if int(state.get("hitstop", 0)) <= 0:
			animation_tree.advance(1.0 / 60.0)
	stats_changed.emit(self)


func get_boxing_movement_debug() -> Dictionary:
	if not debug_boxing_movement:
		return {}
	var facing_alignment := 0.0
	if is_instance_valid(opponent) and _distance_to_opponent > 0.0001:
		facing_alignment = -global_basis.z.dot(_horizontal_direction_to_opponent())
	return {
		"distance": _distance_to_opponent,
		"range_state": get_range_state_name(),
		"input_vector": _raw_movement_input,
		"movement_intensity": movement_intensity,
		"locomotion_state": locomotion_state,
		"target": opponent.name if is_instance_valid(opponent) else "NONE",
		"speed": Vector2(velocity.x, velocity.z).length(),
		"target_speed": _target_speed,
		"facing_alignment": facing_alignment,
		"separation_correction": _separation_correction,
	}


func _play_brief_animation(animation_name: String, duration: float) -> void:
	if _current_attack != "" or _reaction_time > 0.0: return
	animation_tree.active = false
	animation_player.speed_scale = 1.0
	animation_player.play("Boxing/" + animation_name, 0.08)
	get_tree().create_timer(duration).timeout.connect(func():
		if _current_attack == "" and _reaction_time <= 0.0 and not _knocked_down: _finish_action()
	)


func _update_stamina(delta: float) -> void:
	if not fight_enabled:
		return
	var before: float = stats.stamina
	if block_state != "":
		stats.stamina = maxf(0.0, stats.stamina - 1.2 * delta)
		guard_stamina = maxf(0.0, guard_stamina - 1.6 * delta)
		stats_changed.emit(self)
		return
	if _current_attack != "":
		return
	var body_penalty := clampf(body_damage / 140.0, 0.0, 0.55)
	var fatigue_penalty := clampf(long_term_fatigue / 100.0, 0.0, 0.45)
	var recovery_scale := clampf(1.0 - body_penalty - fatigue_penalty, 0.35, 1.0)
	stats.stamina = minf(stats.max_stamina, stats.stamina + (5.0 + stats.recovery * 2.2) * recovery_scale * delta)
	stats.stun = maxf(0.0, stats.stun - 10.0 * delta)
	guard_stamina = minf(max_guard_stamina, guard_stamina + 7.0 * recovery_scale * delta)
	if combat_state != "WOBBLED":
		stability = minf(max_stability, stability + 5.5 * recovery_scale * delta)
	long_term_fatigue = maxf(0.0, long_term_fatigue - 0.22 * delta)
	if int(before) != int(stats.stamina): stats_changed.emit(self)


func _configure_combat_areas() -> void:
	for fist in [left_fist, right_fist]:
		fist.collision_layer = 4
		fist.collision_mask = 8
		fist.monitoring = false
		if fist.get_child_count() == 0:
			var shape_node := CollisionShape3D.new()
			var shape := SphereShape3D.new()
			shape.radius = 0.16
			shape_node.shape = shape
			fist.add_child(shape_node)
	_attach_area_to_bone(left_fist, "mixamorig_LeftHand", Vector3.ZERO)
	_attach_area_to_bone(right_fist, "mixamorig_RightHand", Vector3.ZERO)
	for hurtbox: Area3D in [$Hurtboxes/Head, $Hurtboxes/Body]:
		hurtbox.collision_layer = 8
		hurtbox.collision_mask = 4
		if hurtbox.get_child_count() == 0:
			var shape_node := CollisionShape3D.new()
			var shape := CapsuleShape3D.new()
			shape.radius = 0.18 if hurtbox.name == "Head" else 0.26
			shape.height = 0.35 if hurtbox.name == "Head" else 0.72
			shape_node.shape = shape
			hurtbox.add_child(shape_node)
		_attach_area_to_bone(hurtbox, "mixamorig_Head" if hurtbox.name == "Head" else "mixamorig_Spine2", Vector3.ZERO)


func _configure_body_collider() -> void:
	if body_collider == null:
		return
	var capsule := body_collider.shape as CapsuleShape3D
	if capsule == null:
		capsule = CapsuleShape3D.new()
	else:
		capsule = capsule.duplicate() as CapsuleShape3D
	var scale_x := maxf(absf(scale.x), 0.001)
	var scale_y := maxf(absf(scale.y), 0.001)
	capsule.radius = body_radius / scale_x
	capsule.height = body_height / scale_y
	body_collider.shape = capsule
	body_collider.position = Vector3(0.0, body_height * 0.5 / scale_y, 0.0)


func _body_separation_velocity(base_velocity: Vector3) -> Vector3:
	var boxer_opponent := opponent as BoxerController
	if not is_instance_valid(boxer_opponent):
		_separation_correction = Vector3.ZERO
		return base_velocity
	var offset := global_position - boxer_opponent.global_position
	offset.y = 0.0
	if offset.length_squared() > 0.000001:
		_stable_separation_direction = offset.normalized()
	else:
		_stable_separation_direction = Vector3.RIGHT if get_instance_id() < boxer_opponent.get_instance_id() else Vector3.LEFT
	var effective_hard_distance := maxf(hard_separation_distance, body_radius + boxer_opponent.body_radius)
	var effective_minimum_distance := maxf(minimum_fighter_distance, effective_hard_distance + separation_soft_zone)
	var result: Dictionary = FootworkModel.separation_velocity(
		base_velocity,
		offset,
		_stable_separation_direction,
		effective_minimum_distance,
		effective_hard_distance,
		soft_separation_strength,
		minf(maximum_separation_speed * 0.2, 0.12)
	)
	if offset.length() < effective_minimum_distance:
		var outward_speed: float = result.velocity.dot(_stable_separation_direction)
		if outward_speed > 0.18:
			result.velocity -= _stable_separation_direction * (outward_speed - 0.18)
	_separation_correction = result.correction
	return result.velocity


func _queue_attack(attack_name: String) -> void:
	if _buffered_attacks.size() >= 3:
		_buffered_attacks.pop_front()
	_buffered_attacks.append(attack_name)
	_buffered_attack = _buffered_attacks[0]
	_buffer_time = 0.18


func _emit_fighter_event(signal_name: StringName, args: Array) -> void:
	var events := get_node_or_null("/root/Events")
	if events != null and events.has_signal(signal_name):
		events.emit_signal.callv([signal_name] + args)


func range_modifier_for_state(range_name: String) -> Dictionary:
	return Balance.range_modifier(range_name)


func step_in() -> void:
	stats.stamina = maxf(0.0, stats.stamina - 1.8)
	if is_instance_valid(opponent):
		global_position += _horizontal_direction_to_opponent() * 0.18


func step_out() -> void:
	stats.stamina = maxf(0.0, stats.stamina - 1.4)
	global_position -= _horizontal_direction_to_opponent() * 0.15


func zone_for_hurtbox(hurtbox_name: String) -> String:
	return "body" if hurtbox_name.to_lower().contains("body") else "head"


func try_clinch() -> bool:
	if clinch_cooldown > 0.0 or not is_instance_valid(opponent) or not opponent is BoxerController:
		return false
	_update_range_state()
	if not range_state in [FootworkModel.RangeState.TOO_CLOSE, FootworkModel.RangeState.POCKET]:
		return false
	clinch_partner = opponent as BoxerController
	clinch_partner.clinch_partner = self
	combat_state = "CLINCH"
	clinch_partner.combat_state = "CLINCH"
	_play_clinch_animation()
	clinch_partner._play_clinch_animation()
	_clinch_time = Balance.CLINCH_SECONDS
	clinch_partner._clinch_time = Balance.CLINCH_SECONDS
	stats.stamina = minf(stats.max_stamina, stats.stamina + Balance.CLINCH_STAMINA_RECOVERY)
	clinch_partner.stats.stamina = minf(clinch_partner.stats.max_stamina, clinch_partner.stats.stamina + Balance.CLINCH_STAMINA_RECOVERY * 0.5)
	_emit_fighter_event("clinch_started", [self, clinch_partner])
	return true


func _update_clinch(delta: float) -> void:
	_clinch_time -= delta
	velocity = Vector3.ZERO
	if _clinch_time <= 0.0:
		force_clinch_break("referee")


func force_clinch_break(reason: String) -> void:
	var partner := clinch_partner
	combat_state = "IDLE"
	clinch_partner = null
	clinch_cooldown = Balance.CLINCH_COOLDOWN
	if is_instance_valid(partner):
		partner.combat_state = "IDLE"
		partner.clinch_partner = null
		partner.clinch_cooldown = Balance.CLINCH_COOLDOWN
		var axis := partner.global_position - global_position
		axis.y = 0.0
		if axis.length_squared() < 0.01:
			axis = -global_transform.basis.z
		axis = axis.normalized()
		var midpoint := (global_position + partner.global_position) * 0.5
		var target_gap: float = maxf(mid_range_distance, 1.12)
		global_position = midpoint - axis * target_gap * 0.5
		partner.global_position = midpoint + axis * target_gap * 0.5
		_play_idle_after_clinch()
		partner._play_idle_after_clinch()
	_emit_fighter_event("clinch_ended", [self, partner, reason])


func _play_clinch_animation() -> void:
	if animation_player == null:
		return
	for candidate in [clinch_animation_name, "block_body", "boxing_idle"]:
		if animation_player.has_animation(candidate):
			animation_player.play(candidate, 0.08)
			return


func _play_idle_after_clinch() -> void:
	if animation_player != null and animation_player.has_animation("boxing_idle"):
		animation_player.play("boxing_idle", 0.08)


func gesture_to_attack(direction: Vector2, body := false) -> String:
	if direction.length() < 0.35:
		return ""
	var attack := "uppercut"
	if direction.x > 0.55:
		attack = "cross"
	elif direction.x < -0.55:
		attack = "left_hook"
	elif direction.y < -0.55:
		attack = "jab"
	return attack + "_body" if body and attack in ["jab", "cross", "left_hook", "right_hook", "uppercut"] else attack


func prompt_for_device(device_type: String) -> String:
	match device_type.to_lower():
		"playstation":
			return "Square jab, Triangle cross, L1 hook, R2 body"
		"xbox":
			return "X jab, Y cross, LB hook, RT body"
	return "J jab, K cross, U/I hooks, Space body"


func ai_reaction_delay_frames() -> int:
	if ai_planner != null:
		return ai_planner.reaction_frames_for_difficulty()
	return {"Rookie": 24, "Easy": 24, "Amateur": 18, "Medium": 18, "Pro": 12, "Hard": 12, "Elite": 9, "Legend": 6}.get(difficulty, 18)


func remember_opponent_punch(attack_name: String) -> void:
	_ai_memory.append(attack_name)
	while _ai_memory.size() > 8:
		_ai_memory.pop_front()


func ai_should_answer_jab_spam() -> bool:
	var count := 0
	for attack_name in _ai_memory:
		if attack_name == "jab":
			count += 1
	return count >= 4


func ai_tactical_mode() -> String:
	if is_instance_valid(opponent) and str(opponent.combat_state) == "WOBBLED" and stats.stamina > 20.0:
		return "FINISH"
	if stats.health < 28.0 or stats.stamina < 16.0 or stability < max_stability * 0.25:
		return "SURVIVE"
	if ai_should_answer_jab_spam():
		return "ANTI_JAB_SPAM"
	if is_instance_valid(opponent) and opponent.get_distance_to_opponent() > long_range_distance:
		return "ANTI_KITING"
	if is_instance_valid(opponent) and str(opponent.combat_state) == "BLOCK":
		return "ANTI_BLOCK"
	return "BOX"


func _near_rope_or_corner() -> bool:
	return absf(global_position.x) > ring_limit - 0.18 or absf(global_position.z) > ring_limit - 0.18


func _pop_buffered_attack() -> String:
	if _buffered_attacks.is_empty():
		_buffered_attack = ""
		return ""
	var next: String = _buffered_attacks.pop_front()
	_buffered_attack = _buffered_attacks[0] if not _buffered_attacks.is_empty() else ""
	if _buffered_attacks.is_empty():
		_buffer_time = 0.0
	return next


func _clear_attack_buffer() -> void:
	_buffered_attacks.clear()
	_buffered_attack = ""
	_buffer_time = 0.0


func _apply_ring_limit() -> void:
	if ring_limit <= 0.0:
		return
	var clamped := global_position
	clamped.x = clampf(clamped.x, -ring_limit, ring_limit)
	clamped.z = clampf(clamped.z, -ring_limit, ring_limit)
	if not clamped.is_equal_approx(global_position):
		global_position = clamped
		if absf(global_position.x) >= ring_limit:
			velocity.x = 0.0
			_smoothed_velocity.x = 0.0
		if absf(global_position.z) >= ring_limit:
			velocity.z = 0.0
			_smoothed_velocity.z = 0.0


func _attach_area_to_bone(area: Area3D, bone_name: String, local_offset: Vector3) -> void:
	if skeleton == null or skeleton.find_bone(bone_name) < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "%sAttachment" % area.name
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	var remote := RemoteTransform3D.new()
	remote.name = "%sFollower" % area.name
	remote.update_scale = false
	attachment.add_child(remote)
	remote.remote_path = remote.get_path_to(area)
	remote.position = local_offset


func _set_fist_active(active: bool) -> void:
	if not active:
		left_fist.monitoring = false
		right_fist.monitoring = false
		return
	var attack := CombatRules.attack_data(_current_attack)
	if attack.is_empty(): return
	var fist := left_fist if attack.hand == "left" else right_fist
	fist.monitoring = true
