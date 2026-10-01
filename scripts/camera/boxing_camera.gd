class_name BoxingCamera
extends Node3D

var player: Node3D
var enemy: Node3D
var camera: Camera3D
var shake_strength := 0.0


func setup(p_player: Node3D, p_enemy: Node3D) -> void:
	player = p_player
	enemy = p_enemy
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 52.0
	add_child(camera)


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
	var distance := clampf(4.75 + separation * 0.45, 5.25, 6.9)
	var desired := midpoint + side * distance + Vector3.UP * clampf(2.55 + separation * 0.09, 2.62, 3.08)
	global_position = global_position.lerp(desired, 1.0 - exp(-4.2 * delta))
	look_at(midpoint + Vector3.UP * 1.05, Vector3.UP)
	camera.fov = lerpf(camera.fov, clampf(46.0 + separation * 1.1, 47.5, 54.0), 1.0 - exp(-3.0 * delta))
	shake_strength = move_toward(shake_strength, 0.0, delta * 2.6)
	camera.position = Vector3(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength), 0.0)
