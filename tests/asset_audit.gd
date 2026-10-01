extends SceneTree


const ASSETS := [
	"res://fighters/boxer_green/model/boxer.green.fbx",
	"res://fighters/boxer_02/boxer_02.fbx",
	"res://fighters/boxer_02/model/boxer.green.fbx",
	"res://referee/model/arbitro (1).fbx",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for path in ASSETS:
		_audit(path)
	quit()


func _audit(path: String) -> void:
	print("ASSET ", path)
	var packed := load(path) as PackedScene
	if packed == null:
		print("  LOAD_FAILED")
		return
	var root := packed.instantiate()
	root.name = "AuditRoot"
	root.process_mode = Node.PROCESS_MODE_DISABLED
	get_root().add_child(root)
	root.print_tree_pretty()
	var min_y := INF
	var max_y := -INF
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var aabb := mesh_node.mesh.get_aabb()
		for corner_index in range(8):
			var corner := aabb.get_endpoint(corner_index)
			var transformed := mesh_node.global_transform * corner
			min_y = minf(min_y, transformed.y)
			max_y = maxf(max_y, transformed.y)
		print("  MESH ", root.get_path_to(mesh_node), " AABB=", aabb, " LOCAL=", mesh_node.transform, " GLOBAL=", mesh_node.global_transform)
	for node in root.find_children("*", "Skeleton3D", true, false):
		var skeleton := node as Skeleton3D
		var bone_names: Array[String] = []
		for bone_index in range(skeleton.get_bone_count()):
			bone_names.append(skeleton.get_bone_name(bone_index))
		print("  SKELETON ", root.get_path_to(skeleton), " XFORM=", skeleton.global_transform, " BONES=", skeleton.get_bone_count(), " NAMES=", bone_names)
	for node in root.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		print("  ANIMATION_PLAYER ", root.get_path_to(player), " LIBRARIES=", player.get_animation_library_list(), " ANIMATIONS=", player.get_animation_list())
	if min_y != INF:
		print("  BOUNDS_Y min=", min_y, " max=", max_y, " height=", max_y - min_y)
	root.queue_free()
