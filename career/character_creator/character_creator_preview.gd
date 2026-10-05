class_name CharacterCreatorPreview
extends Node3D

const FIGHTER_SCENE := preload("res://fighters/boxer_green/boxer_green.tscn")

var last_skin_tone := "Medium"
var last_hair_style := "Short"
var last_hair_color := "Black"
var last_beard_style := "None"
var last_beard_color := "Black"
var last_shorts := "Classic"
var last_short_color := "Black"
var last_gloves := "Pro"
var last_glove_color := "Red"
var last_shoes := "High Top"
var _model: Node3D
var _cosmetics_root: Node3D


func _ready() -> void:
	_build_model()
	_build_cosmetics()
	call_deferred("_play_initial_idle")


func _play_initial_idle() -> void:
	play_preview_animation("idle")


func apply_appearance(appearance: Resource) -> void:
	if appearance == null:
		return
	last_skin_tone = appearance.skin_tone
	last_hair_style = appearance.hair_style
	last_hair_color = appearance.hair_color
	last_beard_style = appearance.beard_style
	last_beard_color = appearance.beard_color
	last_shorts = appearance.shorts
	last_short_color = appearance.shorts_color
	last_gloves = appearance.gloves
	last_glove_color = appearance.glove_color
	last_shoes = appearance.shoes
	scale = Vector3.ONE * clampf(float(appearance.height_cm) / 178.0, 0.90, 1.12)
	_apply_material_groups(appearance)
	_update_cosmetics(appearance)


func play_preview_animation(kind: String) -> void:
	var player := find_child("*AnimationPlayer*", true, false) as AnimationPlayer
	if player == null:
		return
	var tree := find_child("*AnimationTree*", true, false) as AnimationTree
	if tree != null:
		tree.active = false
	var candidates: Array = {
		"idle": ["Boxing/boxing_idle", "Boxing/fight_enter", "boxing_idle"],
		"breathing": ["Boxing/boxing_idle", "Boxing/fight_enter"],
		"guard": ["Boxing/block_left", "Boxing/boxing_idle"],
		"shadow_boxing": ["Boxing/jab", "Boxing/cross", "Boxing/boxing_idle"],
		"victory": ["Boxing/fight_enter", "Boxing/boxing_idle"],
	}.get(kind, ["Boxing/boxing_idle"])
	for animation_name in candidates:
		if player.has_animation(animation_name):
			player.play(animation_name)
			return
	var idle := load("res://fighters/boxer_02/animations/boxing_idle.res") as Animation
	if idle == null:
		idle = Animation.new()
		idle.length = 1.0
	if not player.has_animation_library("Preview"):
		var library := AnimationLibrary.new()
		library.add_animation("boxing_idle", idle)
		player.add_animation_library("Preview", library)
	player.play("Preview/boxing_idle")


func rotate_preview(amount: float) -> void:
	rotation.y += amount


func _build_model() -> void:
	_model = FIGHTER_SCENE.instantiate() as Node3D
	_model.name = "BoxerModel"
	_model.scale = Vector3.ONE * 1.15
	add_child(_model)
	_sanitize_preview(_model)


func _build_cosmetics() -> void:
	_cosmetics_root = Node3D.new()
	_cosmetics_root.name = "Cosmetics"
	add_child(_cosmetics_root)
	_add_cosmetic("HairSlot", Vector3(0.0, 1.82, 0.0), Vector3(0.36, 0.12, 0.30))
	_add_cosmetic("BeardSlot", Vector3(0.0, 1.58, -0.11), Vector3(0.28, 0.10, 0.06))
	_add_cosmetic("ShortsSlot", Vector3(0.0, 0.92, 0.0), Vector3(0.55, 0.28, 0.36))
	_add_cosmetic("LeftGloveSlot", Vector3(-0.48, 1.35, -0.10), Vector3(0.16, 0.16, 0.16))
	_add_cosmetic("RightGloveSlot", Vector3(0.48, 1.35, -0.10), Vector3(0.16, 0.16, 0.16))
	_add_cosmetic("LeftShoeSlot", Vector3(-0.20, 0.08, -0.06), Vector3(0.22, 0.08, 0.32))
	_add_cosmetic("RightShoeSlot", Vector3(0.20, 0.08, -0.06), Vector3(0.22, 0.08, 0.32))


func _add_cosmetic(node_name: String, position_value: Vector3, scale_value: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mesh.mesh = box
	mesh.position = position_value
	mesh.scale = scale_value
	_cosmetics_root.add_child(mesh)


func _sanitize_preview(node: Node) -> void:
	for child in node.get_children():
		if child is Area3D or child is CollisionShape3D or (child is CollisionObject3D and not child is CharacterBody3D):
			child.queue_free()
		else:
			_sanitize_preview(child)
	if node is BoxerController:
		var boxer := node as BoxerController
		boxer.fight_enabled = false
		boxer.is_player = true
		boxer.set_physics_process(false)
		boxer.set_process(false)


func _apply_material_groups(appearance: Resource) -> void:
	var skin := _color_for(appearance.skin_tone)
	for mesh in _mesh_instances(_model):
		var material := StandardMaterial3D.new()
		material.albedo_color = skin
		mesh.material_override = material


func _update_cosmetics(appearance: Resource) -> void:
	_set_cosmetic("HairSlot", appearance.hair_style != "None", _color_for(appearance.hair_color))
	_set_cosmetic("BeardSlot", appearance.beard_style != "None", _color_for(appearance.beard_color))
	_set_cosmetic("ShortsSlot", true, _color_for(appearance.shorts_color))
	_set_cosmetic("LeftGloveSlot", true, _color_for(appearance.glove_color))
	_set_cosmetic("RightGloveSlot", true, _color_for(appearance.glove_color))
	_set_cosmetic("LeftShoeSlot", true, _color_for(appearance.shoes))
	_set_cosmetic("RightShoeSlot", true, _color_for(appearance.shoes))


func _set_cosmetic(node_name: String, visible_value: bool, color: Color) -> void:
	var mesh := _cosmetics_root.get_node_or_null(node_name) as MeshInstance3D
	if mesh == null:
		return
	mesh.visible = visible_value
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material


func _mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_mesh_instances(child))
	return result


func _color_for(value: String) -> Color:
	return {
		"Pale": Color("d8a47f"),
		"Medium": Color("a96f45"),
		"Tan": Color("8a5434"),
		"Dark": Color("4e3023"),
		"Black": Color("101113"),
		"Brown": Color("4b2f20"),
		"Blonde": Color("d0a85c"),
		"Red": Color("b3272c"),
		"Blue": Color("254f8c"),
		"White": Color("e8e8dc"),
		"Gold": Color("c79a3c"),
		"High Top": Color("16181d"),
		"Low Cut": Color("f2f2ec"),
	}.get(value, Color("30343a"))
