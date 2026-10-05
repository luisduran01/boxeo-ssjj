class_name BoxingCamera
extends Node3D

var player: Node3D
var enemy: Node3D
var camera: Camera3D
var phantom_host: Node
var combat_phantom_camera: Node3D
var shake_strength := 0.0
var distance_scale := 1.0
var height_scale := 1.0
var base_fov := 70.0
var shake_scale := 0.7
var knockdown_focus: Node3D
var referee: Node3D
var anti_occlusion_active := false
var startup_visible := true


func setup(p_player: Node3D, p_enemy: Node3D) -> void:
	player = p_player
	enemy = p_enemy
	camera = Camera3D.new()
	camera.current = true
	apply_settings()
	camera.fov = base_fov
	add_child(camera)
	_setup_phantom_camera_nodes()


func _setup_phantom_camera_nodes() -> void:
	if ClassDB.class_exists("PhantomCameraHost"):
		phantom_host = ClassDB.instantiate("PhantomCameraHost") as Node
	else:
		phantom_host = Node.new()
	phantom_host.name = "PhantomCameraHost"
	add_child(phantom_host)
	if ClassDB.class_exists("PhantomCamera3D"):
		combat_phantom_camera = ClassDB.instantiate("PhantomCamera3D") as Node3D
	else:
		combat_phantom_camera = Node3D.new()
	combat_phantom_camera.name = "CombatPhantomCamera"
	combat_phantom_camera.top_level = true
	add_child(combat_phantom_camera)
	if combat_phantom_camera.has_method("set_priority"):
		combat_phantom_camera.call("set_priority", 10)

func apply_settings() -> void:
	distance_scale = float(SaveSystem.settings.get("camera_distance", 1.0))
	height_scale = float(SaveSystem.settings.get("camera_height", 1.0))
	base_fov = float(SaveSystem.settings.get("camera_fov", 70.0))
	shake_scale = float(SaveSystem.settings.get("camera_shake", 0.7))


func impact(amount: float) -> void:
	shake_strength = maxf(shake_strength, amount)


func set_knockdown_focus(fighter: Node3D) -> void:
	knockdown_focus = fighter


func set_referee(p_referee: Node3D) -> void:
	referee = p_referee


func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(enemy) or camera == null:
		return
	var midpoint := (player.global_position + enemy.global_position) * 0.5
	if is_instance_valid(knockdown_focus):
		midpoint = midpoint.lerp(knockdown_focus.global_position, 0.28)
	var separation := player.global_position.distance_to(enemy.global_position)
	var fight_axis := (enemy.global_position - player.global_position).normalized()
	var side := Vector3.UP.cross(fight_axis).normalized()
	if side.dot(Vector3(1, 0, 1).normalized()) < 0.0:
		side = -side
	var ring_bias := Vector3.ZERO
	var ring_edge := maxf(absf(midpoint.x), absf(midpoint.z))
	if ring_edge > 2.55:
		ring_bias = -Vector3(midpoint.x, 0.0, midpoint.z).normalized() * clampf((ring_edge - 2.55) * 0.8, 0.0, 0.45)
	anti_occlusion_active = _referee_occludes(midpoint, side)
	var occlusion_offset := side * 0.52 if anti_occlusion_active else Vector3.ZERO
	startup_visible = _startup_is_visible(separation)
	var startup_zoom_pad := 0.5 if startup_visible and _fighter_in_startup() else 0.0
	var distance := clampf(4.75 + separation * 0.52 + ring_edge * 0.16, 5.25, 7.25) * distance_scale
	var desired := midpoint + ring_bias + occlusion_offset + side * (distance + startup_zoom_pad) + Vector3.UP * clampf(2.55 + separation * 0.11, 2.62, 3.22) * height_scale
	global_position = global_position.lerp(desired, 1.0 - exp(-4.2 * delta))
	look_at(midpoint + Vector3.UP * 1.05, Vector3.UP)
	if combat_phantom_camera != null:
		combat_phantom_camera.global_transform = global_transform
	var target_fov := clampf(base_fov - 5.0 + separation * 1.1 + startup_zoom_pad * 1.4, base_fov - 4.0, base_fov + 4.0)
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-3.0 * delta))
	shake_strength = move_toward(shake_strength, 0.0, delta * 2.6)
	var applied_shake := shake_strength * shake_scale
	camera.position = Vector3(randf_range(-applied_shake, applied_shake), randf_range(-applied_shake, applied_shake), 0.0)


func _fighter_in_startup() -> bool:
	return (is_instance_valid(player) and str(player.get("combat_state")) == "STARTUP") or (is_instance_valid(enemy) and str(enemy.get("combat_state")) == "STARTUP")


func _startup_is_visible(separation: float) -> bool:
	return separation <= 2.2 or _fighter_in_startup()


func _referee_occludes(midpoint: Vector3, side: Vector3) -> bool:
	if not is_instance_valid(referee):
		return false
	var to_ref := referee.global_position - midpoint
	to_ref.y = 0.0
	return to_ref.length() < 0.9 and absf(to_ref.normalized().dot(side)) < 0.55
