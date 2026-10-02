class_name FighterPreview
extends Control

var _viewport: SubViewport
var _stage: Node3D
var _fallback: TextureRect
var _fighter: Node3D

func _ready() -> void:
	custom_minimum_size = Vector2(420, 420)
	clip_contents = true
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(512, 512)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)
	_stage = Node3D.new()
	_stage.name = "PreviewStage"
	_viewport.add_child(_stage)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.15, 3.15)
	camera.look_at_from_position(camera.position, Vector3(0, 0.95, 0))
	_stage.add_child(camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -25, 0)
	key.light_energy = 1.8
	_stage.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.5, 1.8, 1.5)
	fill.light_energy = 4.0
	fill.omni_range = 6.0
	_stage.add_child(fill)
	_fallback = TextureRect.new()
	_fallback.name = "PortraitFallback"
	_fallback.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fallback.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fallback)
	_fallback.hide()

func show_fighter(data: FighterData) -> void:
	clear()
	if data == null or data.scene == null:
		_fallback.texture = data.portrait if data != null else null
		_fallback.show()
		return
	_fighter = data.scene.instantiate() as Node3D
	if _fighter == null:
		_fallback.texture = data.portrait
		_fallback.show()
		return
	_fighter.name = "PreviewFighter"
	_fighter.process_mode = Node.PROCESS_MODE_DISABLED
	_fighter.scale = Vector3.ONE * 1.35
	_disable_collisions(_fighter)
	_stage.add_child(_fighter)
	_fallback.hide()

func clear() -> void:
	if is_instance_valid(_fighter):
		_fighter.free()
	_fighter = null
	if is_instance_valid(_fallback): _fallback.hide()

func live_preview_count() -> int:
	return 1 if is_instance_valid(_fighter) else 0

func is_fallback_visible() -> bool:
	return is_instance_valid(_fallback) and _fallback.visible

func _disable_collisions(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	for child in node.get_children(): _disable_collisions(child)
