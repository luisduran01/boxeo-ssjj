class_name BoxerController
extends CharacterBody3D

const FootworkModel = preload("res://scripts/combat/boxing_footwork_model.gd")

signal stats_changed(fighter: BoxerController)
signal punch_landed(attacker: BoxerController, defender: BoxerController, result: Dictionary)
signal knockdown_requested(fighter: BoxerController)

@export var is_player := true
@export var opponent: Node3D
@export_enum("Easy", "Medium", "Hard") var difficulty := "Medium"
@export var fighter_name := "PLAYER"
@export_range(0.30, 0.42, 0.01) var body_radius := 0.36
@export_range(1.30, 1.65, 0.01) var body_height := 1.48
@export_range(0.04, 0.16, 0.01) var separation_soft_zone := 0.10
@export var punch_debug_enabled := false
@export var debug_boxing_movement := false
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
@export_group("")
@export_node_path("AnimationPlayer") var animation_player_path := NodePath("boxer_green/AnimationPlayer2")
@export_node_path("Skeleton3D") var skeleton_path := NodePath("boxer_green/Skeleton3D")

var stats := CombatRules.fresh_stats()
var fight_enabled := false
var combat_state := "IDLE"
var ai_state := "IDLE"
var block_state := ""
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
	_normalize_footwork_animations()
	_configure_body_collider()
	_configure_combat_areas()
	animation_tree.active = true
	stats_changed.emit(self)


func _physics_process(delta: float) -> void:
	_pivot_cooldown = maxf(0.0, _pivot_cooldown - delta)
	_long_step_time = maxf(0.0, _long_step_time - delta)
	_long_step_cooldown = maxf(0.0, _long_step_cooldown - delta)
	_buffer_time = maxf(0.0, _buffer_time - delta)
	if _buffer_time <= 0.0:
		_buffered_attack = ""
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
		velocity = _body_separation_velocity(Vector3.ZERO)
		move_and_slide()
		if _reaction_time <= 0.0:
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


func set_movement_intent(intent: Vector2) -> void:
	_movement_intent = intent.limit_length(1.0)
	if not is_player:
		_ai_move = _movement_intent
		_ai_think_time = maxf(_ai_think_time, 0.10)


func request_pivot(direction: float) -> bool:
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
	if _ai_guard_time > 0.0:
		ai_state = "DEFEND"
		_ai_move = Vector2.ZERO
		return _ai_move
	if block_state != "":
		block_state = ""
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

	var stamina_scale: float = lerpf(0.86, 1.0, stamina_ratio)

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
	if Input.is_action_pressed("gamepad_guard"):
		var guard_direction := _player_input()
		block_state = "body" if guard_direction.y < -0.55 else ("right" if guard_direction.x > 0.3 else "left")
	else:
		block_state = "body" if Input.is_action_pressed("block_body") else ("left" if Input.is_action_pressed("block_left") else ("right" if Input.is_action_pressed("block_right") else ""))
	combat_state = "BLOCK" if block_state != "" else "IDLE"
	if block_state != "" and not animation_player.is_playing():
		_play_brief_animation("block_" + block_state, 0.28)


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
	if not fight_enabled or _knocked_down or _reaction_time > 0.0:
		return
	var attack := CombatRules.attack_data(attack_name)
	if attack.is_empty():
		return
	if _current_attack != "":
		_buffered_attack = attack_name
		_buffer_time = 0.22
		return
	if stats.stamina < attack.cost * 0.45:
		return
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
	var speed: float = stats.punch_speed * float(attack.animation_speed) * lerpf(0.88, 1.0, stats.stamina / stats.max_stamina)
	_action_time = attack.startup / speed
	_active_time = attack.active_time / speed
	var fatigue_recovery := lerpf(1.14, 1.0, stats.stamina / stats.max_stamina)
	_recovery_time = attack.recovery * fatigue_recovery / speed
	stats.stamina = maxf(0.0, stats.stamina - CombatRules.stamina_cost(attack_name, false))
	animation_tree.active = false
	animation_player.speed_scale = speed
	animation_player.play("Boxing/" + str(attack.animation_name), 0.07)
	stats_changed.emit(self)


func _update_attack(delta: float) -> void:
	var attack := CombatRules.attack_data(_current_attack)
	if attack.is_empty():
		_finish_action()
		return
	_update_attack_movement(delta, attack)
	var remaining := delta
	if combat_state == "STARTUP":
		_track_attack_target(delta, float(attack.tracking_strength))
		_action_time -= remaining
		if _action_time > 0.0: return
		remaining = -_action_time
		combat_state = "ACTIVE"
		_strike_done = true
		_set_fist_active(true)
		_attempt_strike()
	if combat_state == "ACTIVE":
		_active_time -= remaining
		if _active_time > 0.0: return
		remaining = -_active_time
		_set_fist_active(false)
		combat_state = "RECOVERY"
	if combat_state != "RECOVERY": return
	_recovery_time -= remaining
	if _buffered_attack != "" and _buffer_time > 0.0 and _recovery_time <= float(attack.cancel_window):
		var queued := _buffered_attack
		_buffered_attack = ""
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
	var allowed_speed: float = stats.movement_speed * float(attack.movement_allowed)
	var target: Vector3 = FootworkModel.relative_velocity(command, basis.forward, basis.right, allowed_speed, allowed_speed * 0.82, allowed_speed * 0.9)
	if combat_state == "STARTUP" and command.y > 0.05:
		target += basis.forward * float(attack.step_in) * command.y
	target = _body_separation_velocity(target)
	_target_speed = target.length()
	_smoothed_velocity = _smoothed_velocity.move_toward(target, 8.0 * delta)
	velocity = _body_separation_velocity(Vector3(_smoothed_velocity.x, 0.0, _smoothed_velocity.z))
	move_and_slide()
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
	var origin: Vector3 = (left_fist if attack.hand == "left" else right_fist).global_position
	var to_target := target_position - origin
	var planar := Vector3(to_target.x, 0.0, to_target.z)
	var direction := planar.normalized()
	var facing := -global_basis.z.dot(direction)
	var distance := global_position.distance_to(opponent.global_position)
	_last_hit_distance = distance
	if distance >= float(attack.min_range) and distance <= float(attack.range) and facing > 0.58:
		var center: float = (float(attack.min_range) + float(attack.range)) * 0.5
		var half_width: float = maxf((float(attack.range) - float(attack.min_range)) * 0.5, 0.01)
		var distance_quality := 1.0 - clampf(absf(distance - center) / half_width, 0.0, 1.0)
		var quality := clampf(distance_quality * 0.72 + facing * 0.28, 0.15, 1.0)
		var counter: bool = str(opponent.combat_state) in ["STARTUP", "RECOVERY"]
		var result: Dictionary = opponent.receive_hit(_current_attack, attack.target_level, stats.stamina, counter, quality, _attack_momentum, signf(global_basis.x.dot(direction)))
		if not result.is_empty():
			_hit_targets[opponent.get_instance_id()] = _attack_instance_id
			_last_hit_result = str(result.result)
			_last_hit_damage = float(result.damage)
			_last_counter = bool(result.counter)
			round_hits += 1
			round_damage += float(result.damage)
			punch_landed.emit(self, opponent, result)
	else:
		stats.stamina = maxf(0.0, stats.stamina - CombatRules.stamina_cost(_current_attack, true) * 0.12)


func preview_hit(attack_name: String) -> Dictionary:
	var attack := CombatRules.attack_data(attack_name)
	if attack.is_empty() or not is_instance_valid(opponent): return {"result":"MISS"}
	var distance := global_position.distance_to(opponent.global_position)
	if distance < float(attack.min_range) or distance > float(attack.range): return {"result":"MISS"}
	var guarded: bool = opponent.block_state == attack.target_level or (attack.target_level == "head" and opponent.block_state in ["left", "right"])
	return CombatRules.calculate_hit(attack_name, attack.target_level, stats.stamina, opponent.stats.defense, guarded, opponent.combat_state in ["STARTUP", "RECOVERY"], 0.85, _attack_momentum)


func receive_hit(attack_name: String, zone: String, attacker_stamina: float, counter: bool, impact_quality := 1.0, momentum := 1.0, lateral_direction := 0.0) -> Dictionary:
	if _knocked_down:
		return {}
	var guarded := block_state == zone or (zone == "head" and block_state in ["left", "right"])
	var result := CombatRules.calculate_hit(attack_name, zone, attacker_stamina, stats.defense, guarded, counter or combat_state in ["STARTUP", "RECOVERY"], impact_quality, momentum)
	stats.health = maxf(0.0, stats.health - result.damage)
	stats.stamina = maxf(0.0, stats.stamina - result.stamina_damage)
	stats.stun = minf(stats.max_stun, stats.stun + result.stun)
	if zone == "head": stats.head_health = maxf(0.0, stats.head_health - result.damage * 1.15)
	else: stats.body_health = maxf(0.0, stats.body_health - result.damage * 1.2)
	stats_changed.emit(self)
	if FightRules.should_knockdown(stats.health, stats.head_health, stats.stun - result.stun, result.stun):
		knockdown_requested.emit(self)
		return result
	if not guarded:
		var reaction := "hit_uppercut" if attack_name == "uppercut" else (("hit_kidney" if lateral_direction < 0.0 else "hit_rib") if zone == "body" else "hit_reaction")
		_reaction_time = clampf(0.11 + result.stun * 0.008, 0.12, 0.32)
		combat_state = "STUNNED"
		animation_tree.active = false
		animation_player.speed_scale = 1.0
		animation_player.play("Boxing/" + reaction, 0.04)
	return result


func begin_knockdown() -> void:
	_knocked_down = true
	knockdowns += 1
	round_knockdowns += 1
	combat_state = "KNOCKDOWN"
	fight_enabled = false
	_set_fist_active(false)
	animation_tree.active = false
	animation_player.stop()
	var tween := create_tween()
	tween.tween_property(self, "rotation:z", deg_to_rad(82.0) * (-1.0 if is_player else 1.0), 0.42).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(self, "position:y", 0.18, 0.42)


func recover_from_knockdown() -> void:
	rotation.z = 0.0
	position.y = 0.0
	_knocked_down = false
	stats.health = maxf(18.0, stats.health)
	stats.head_health = maxf(15.0, stats.head_health)
	stats.stun = 25.0
	stats.stamina = maxf(stats.stamina, 24.0)
	animation_tree.active = false
	animation_player.speed_scale = 1.0
	animation_player.play("Boxing/get_up", 0.08)
	await get_tree().create_timer(0.7).timeout
	_finish_action()


func reset_for_round(spawn_position: Vector3) -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	_smoothed_velocity = Vector3.ZERO
	stats.stamina = minf(stats.max_stamina, stats.stamina + 24.0)
	stats.stun = maxf(0.0, stats.stun - 55.0)
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
	_reaction_time = 0.0
	combat_state = "IDLE"
	animation_player.stop()
	animation_player.speed_scale = 1.0
	animation_tree.active = true
	var playback = animation_tree.get("parameters/playback")
	if playback: playback.travel("Footwork")
	if _buffered_attack != "" and _buffer_time > 0.0 and fight_enabled:
		var next := _buffered_attack
		_buffered_attack = ""
		request_attack(next)


func get_punch_debug() -> Dictionary:
	var data := CombatRules.attack_data(_current_attack)
	return {"attack":_current_attack if _current_attack != "" else "NONE", "phase":combat_state, "hand":str(data.get("hand", "NONE")), "range":float(data.get("range", 0.0)), "target":str(data.get("target_level", "NONE")), "hitbox_active":left_fist.monitoring or right_fist.monitoring, "hit_result":_last_hit_result, "damage":_last_hit_damage, "stamina_cost":float(data.get("stamina_cost", 0.0)), "counter":_last_counter, "distance":_last_hit_distance}


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
	if not fight_enabled or _current_attack != "" or block_state != "": return
	var before: float = stats.stamina
	stats.stamina = minf(stats.max_stamina, stats.stamina + (5.0 + stats.recovery * 2.2) * delta)
	stats.stun = maxf(0.0, stats.stun - 10.0 * delta)
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
		maximum_separation_speed
	)
	_separation_correction = result.correction
	return result.velocity


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
