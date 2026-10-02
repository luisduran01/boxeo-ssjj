class_name BoxingCamera
extends Node3D

var player: Node3D
var enemy: Node3D
var camera: Camera3D
var shake_strength := 0.0
var distance_scale := 1.0
var height_scale := 1.0
var base_fov := 70.0
var shake_scale := 0.7


func setup(p_player: Node3D, p_enemy: Node3D) -> void:
	player = p_player
	enemy = p_enemy
	camera = Camera3D.new()
	camera.current = true
	apply_settings()
	camera.fov = base_fov
	add_child(camera)

func apply_settings() -> void:
	distance_scale = float(SaveSystem.settings.get("camera_distance", 1.0))
	height_scale = float(SaveSystem.settings.get("camera_height", 1.0))
	base_fov = float(SaveSystem.settings.get("camera_fov", 70.0))
	shake_scale = float(SaveSystem.settings.get("camera_shake", 0.7))


func impact(amount: float) -> void:
	shake_strength = maxf(shake_strength, amount)


func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(enemy) or camera == null:
		return
	var midpoint := (player.global_position + enemy.global_position) * 0.5
	var separation := player.global_position.distance_to(enemy.global_position)
	var fight_axis := (enemy.global_position - player.global_position).normalized()
	var side := Vector3.UP.cross(fight_axis).normalized()
	if side.dot(Vector3(1, 0, 1).normalized()) < 0.0:
		side = -side
	var distance := clampf(4.75 + separation * 0.45, 5.25, 6.9) * distance_scale
	var desired := midpoint + side * distance + Vector3.UP * clampf(2.55 + separation * 0.09, 2.62, 3.08) * height_scale
	global_position = global_position.lerp(desired, 1.0 - exp(-4.2 * delta))
	look_at(midpoint + Vector3.UP * 1.05, Vector3.UP)
	camera.fov = lerpf(camera.fov, clampf(base_fov - 5.0 + separation * 1.1, base_fov - 4.0, base_fov + 3.0), 1.0 - exp(-3.0 * delta))
	shake_strength = move_toward(shake_strength, 0.0, delta * 2.6)
	var applied_shake := shake_strength * shake_scale
	camera.position = Vector3(randf_range(-applied_shake, applied_shake), randf_range(-applied_shake, applied_shake), 0.0)
