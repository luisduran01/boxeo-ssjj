class_name RingBuilder
extends Node3D

const RING_HALF := 3.75


func _ready() -> void:
	_build_floor()
	_build_posts_and_ropes()
	_build_crowd()
	_build_arena_lights()
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-72, -24, 0)
	light.light_energy = 0.55
	light.light_color = Color("dbe5e8")
	light.shadow_enabled = true
	light.shadow_blur = 1.8
	light.directional_shadow_max_distance = 18.0
	add_child(light)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("05080c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("65808d")
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)


func _mesh_instance(mesh: Mesh, color: Color, position_value: Vector3, roughness := 0.74, metallic := 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position_value
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	instance.material_override = material
	add_child(instance)
	return instance


func _build_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(RING_HALF * 2.0 + 0.55, 0.28, RING_HALF * 2.0 + 0.55)
	var visual := _mesh_instance(mesh, Color("989b96"), Vector3(0, -0.16, 0), 0.92)
	visual.reparent(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	body.add_child(collision)
	collision.position.y = -0.16
	for edge in [Vector3(0, 0.7, -RING_HALF), Vector3(0, 0.7, RING_HALF), Vector3(-RING_HALF, 0.7, 0), Vector3(RING_HALF, 0.7, 0)]:
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		var wall_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(RING_HALF * 2.0 if edge.x == 0 else 0.16, 1.5, 0.16 if edge.x == 0 else RING_HALF * 2.0)
		wall_shape.shape = box
		wall.add_child(wall_shape)
		wall.position = edge
		add_child(wall)


func _build_posts_and_ropes() -> void:
	for x in [-RING_HALF - 0.05, RING_HALF + 0.05]:
		for z in [-RING_HALF - 0.05, RING_HALF + 0.05]:
			var post_mesh := CylinderMesh.new()
			post_mesh.top_radius = 0.17
			post_mesh.bottom_radius = 0.17
			post_mesh.height = 2.25
			_mesh_instance(post_mesh, Color("252b31"), Vector3(x, 1.02, z), 0.52, 0.28)
			var pad := BoxMesh.new()
			pad.size = Vector3(0.34, 0.82, 0.34)
			_mesh_instance(pad, Color("7f2f35") if z < 0.0 else Color("28536d"), Vector3(x * 0.965, 1.04, z * 0.965), 0.92)
	for height in [0.62, 1.04, 1.46]:
		for side in [-1.0, 1.0]:
			var horizontal := BoxMesh.new()
			horizontal.size = Vector3(RING_HALF * 2.0, 0.064, 0.064)
			_mesh_instance(horizontal, Color("d9dcdd") if height != 1.04 else Color("a63f46"), Vector3(0, height, side * RING_HALF), 0.58)
			var vertical := BoxMesh.new()
			vertical.size = Vector3(0.064, 0.064, RING_HALF * 2.0)
			_mesh_instance(vertical, Color("d9dcdd") if height != 1.04 else Color("356a8b"), Vector3(side * RING_HALF, height, 0), 0.58)


func _build_crowd() -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = 72
	var person := CapsuleMesh.new()
	person.radius = 0.18
	person.height = 0.85
	multimesh.mesh = person
	for i in range(multimesh.instance_count):
		var angle := TAU * float(i) / float(multimesh.instance_count)
		var radius := 6.5 + float(i % 3) * 0.55
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(cos(angle) * radius, 0.5 + float(i % 2) * 0.15, sin(angle) * radius)))
	var crowd := MultiMeshInstance3D.new()
	crowd.multimesh = multimesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("17222c")
	material.roughness = 1.0
	crowd.material_override = material
	add_child(crowd)


func _build_arena_lights() -> void:
	for x in [-2.6, 2.6]:
		for z in [-2.6, 2.6]:
			var spot := SpotLight3D.new()
			spot.position = Vector3(x, 5.7, z)
			spot.rotation_degrees.x = -90.0
			spot.light_color = Color("e5edef")
			spot.light_energy = 1.7
			spot.spot_range = 8.5
			spot.spot_angle = 47.0
			spot.shadow_enabled = false
			add_child(spot)
