class_name RefereeController
extends CharacterBody3D

enum State { OBSERVING, COUNTING, INTERVENING, STOPPED }

@export var movement_speed := 1.65
@export var observation_distance := 2.65
@export_range(0.26, 0.38, 0.01) var body_radius := 0.31
@export_range(1.35, 1.70, 0.01) var body_height := 1.55
@export_range(0.15, 0.45, 0.01) var avoidance_margin := 0.28

var player: BoxerController
var enemy: BoxerController
var state := State.OBSERVING
var current_count := 0
var _fallen: BoxerController
var _standing: BoxerController
var _clinch_time := 0.0
var _orbit_sign := 1.0

@onready var animation_player: AnimationPlayer = $referee_model/AnimationPlayer2
@onready var body_collider: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	collision_layer = 16
	collision_mask = 3
	safe_margin = 0.02
	_configure_body_collider()
	_play("ref_idle", 0.0)


func setup(p_player: BoxerController, p_enemy: BoxerController) -> void:
	player = p_player
	enemy = p_enemy


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(enemy):
		return
	var target := _count_target() if state == State.COUNTING else _observation_target(delta)
	_move_toward_target(target, delta)
	var look_target := _fallen.global_position if state == State.COUNTING and is_instance_valid(_fallen) else (player.global_position + enemy.global_position) * 0.5
	_face_position(look_target, delta)
	if state == State.OBSERVING:
		_update_clinch(delta)


func _observation_target(delta: float) -> Vector3:
	var midpoint := (player.global_position + enemy.global_position) * 0.5
	var fight_axis := enemy.global_position - player.global_position
	fight_axis.y = 0.0
	if fight_axis.length_squared() < 0.01:
		fight_axis = Vector3.FORWARD
	var side := Vector3.UP.cross(fight_axis.normalized()) * _orbit_sign
	var target := midpoint + side * observation_distance
	var nearest_distance := minf(global_position.distance_to(player.global_position), global_position.distance_to(enemy.global_position))
	if nearest_distance < 1.25:
		_orbit_sign *= -1.0
		target = midpoint - side * (observation_distance + 0.5)
	target.x = clampf(target.x, -3.25, 3.25)
	target.z = clampf(target.z, -3.25, 3.25)
	return target


func _count_target() -> Vector3:
	if not is_instance_valid(_fallen):
		return global_position
	var away := global_position - _fallen.global_position
	away.y = 0.0
	if is_instance_valid(_standing):
		away = _fallen.global_position - _standing.global_position
		away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.RIGHT
	var target := _fallen.global_position + away.normalized() * 1.15
	target.x = clampf(target.x, -3.25, 3.25)
	target.z = clampf(target.z, -3.25, 3.25)
	return target


func _move_toward_target(target: Vector3, delta: float) -> void:
	var offset := target - global_position
	offset.y = 0.0
	if offset.length() > 0.16:
		velocity = offset.normalized() * movement_speed
		if state == State.OBSERVING:
			_play_if_changed("ref_walk")
	else:
		velocity = velocity.move_toward(Vector3.ZERO, movement_speed * 5.0 * delta)
		if state == State.OBSERVING:
			_play_if_changed("ref_idle")
	velocity = _avoid_fighters(velocity)
	move_and_slide()


func _avoid_fighters(base_velocity: Vector3) -> Vector3:
	var result := base_velocity
	for fighter: BoxerController in [player, enemy]:
		if not is_instance_valid(fighter):
			continue
		var offset: Vector3 = global_position - fighter.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance < 0.001:
			offset = Vector3.UP.cross(enemy.global_position - player.global_position).normalized()
			if offset.length_squared() < 0.01:
				offset = Vector3.RIGHT
			distance = 0.001
		var safe_distance: float = body_radius + fighter.body_radius + avoidance_margin
		if distance < safe_distance:
			var urgency := clampf((safe_distance - distance) / avoidance_margin, 0.0, 1.0)
			var outward: Vector3 = offset / distance
			var inward_speed := minf(result.dot(outward), 0.0)
			result -= outward * inward_speed
			result += outward * lerpf(0.65, movement_speed * 1.35, urgency)
	return result.limit_length(movement_speed * 1.45)


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


func _face_position(target: Vector3, delta: float) -> void:
	var direction := target - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	var desired_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, 1.0 - exp(-7.0 * delta))


func _update_clinch(delta: float) -> void:
	var distance := player.global_position.distance_to(enemy.global_position)
	var quiet := player.combat_state in ["IDLE", "BLOCK"] and enemy.combat_state in ["IDLE", "BLOCK"]
	_clinch_time = _clinch_time + delta if distance < 0.86 and quiet else 0.0
	if _clinch_time >= 1.6:
		_clinch_time = 0.0
		intercept_clinch()


func intercept_clinch() -> void:
	if state != State.OBSERVING:
		return
	state = State.INTERVENING
	_play("ref_intercept", 0.08)
	var axis := enemy.global_position - player.global_position
	axis.y = 0.0
	if axis.length_squared() < 0.01:
		axis = Vector3.FORWARD
	axis = axis.normalized()
	player.global_position -= axis * 0.28
	enemy.global_position += axis * 0.28
	get_tree().create_timer(0.75).timeout.connect(func():
		if state == State.INTERVENING:
			state = State.OBSERVING
			_play("ref_idle", 0.08)
	)


func begin_count(fallen: BoxerController, standing: BoxerController) -> void:
	_fallen = fallen
	_standing = standing
	current_count = 0
	state = State.COUNTING
	_play("ref_look_down", 0.08)


func count(count_value: int) -> void:
	current_count = count_value
	if count_value == 1 or not animation_player.is_playing():
		_play("ref_count", 0.08)


func resume_fight() -> void:
	current_count = 0
	_fallen = null
	_standing = null
	state = State.OBSERVING
	_play("ref_walk_backward", 0.08)


func finish_fight(_reason: String) -> void:
	state = State.STOPPED
	velocity = Vector3.ZERO
	_play("ref_stop_fight", 0.08)


func _play_if_changed(animation_name: String) -> void:
	if animation_player.current_animation != "Referee/" + animation_name:
		_play(animation_name, 0.12)


func _play(animation_name: String, blend: float) -> void:
	var full_name := "Referee/" + animation_name
	if animation_player.has_animation(full_name):
		animation_player.play(full_name, blend)
