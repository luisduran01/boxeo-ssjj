extends SceneTree

const CREATOR_SCENE := "res://career/character_creator/character_creator.tscn"
const CareerFighter := preload("res://career/character_creator/career_fighter.gd")

var failures := 0
var creator: Node


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("CHARACTER CREATOR: " + message)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveSystem.configure_paths("user://creator_settings.cfg", "user://creator_career.json")
	SaveSystem.settings = SaveSystem.default_settings()
	SaveSystem.career = SaveSystem.default_career()
	var packed := load(CREATOR_SCENE) as PackedScene
	_expect(packed != null, "character_creator.tscn must exist and load")
	if packed != null:
		creator = packed.instantiate()
		root.add_child(creator)
		await process_frame
		await process_frame
		_test_scene_structure()
		_test_preview_is_sanitized_and_animated()
		_test_categories_and_realtime_appearance()
		_test_rotation_and_camera_focus()
		_test_save_to_career()
	if failures > 0:
		push_error("CHARACTER CREATOR TESTS FAILED: %d" % failures)
		quit(1)
	else:
		print("CHARACTER CREATOR TESTS PASSED")
		quit(0)


func _test_scene_structure() -> void:
	_expect(creator.name == "CharacterCreator", "root must be CharacterCreator")
	for path in [
		"Background",
		"LeftPanel/VBoxContainer/Title",
		"LeftPanel/VBoxContainer/FighterName",
		"LeftPanel/VBoxContainer/CategoryTitle",
		"LeftPanel/VBoxContainer/Options",
		"SubViewportContainer/SubViewport/PreviewWorld/Camera3D",
		"SubViewportContainer/SubViewport/PreviewWorld/DirectionalLight3D",
		"SubViewportContainer/SubViewport/PreviewWorld/FighterPreview",
		"BottomControls",
	]:
		_expect(creator.get_node_or_null(path) != null, "missing node %s" % path)
	_expect((creator.get_node("LeftPanel/VBoxContainer/Options") is GridContainer), "Options must be a GridContainer")


func _test_preview_is_sanitized_and_animated() -> void:
	var preview := creator.get_node("SubViewportContainer/SubViewport/PreviewWorld/FighterPreview")
	_expect(preview.has_method("apply_appearance"), "FighterPreview must expose apply_appearance")
	_expect(preview.has_method("play_preview_animation"), "FighterPreview must expose animation selector")
	_expect(preview.get_node_or_null("BoxerModel") != null, "preview must instantiate the real boxer model")
	_expect(preview.find_child("*Skeleton3D*", true, false) is Skeleton3D, "preview must retain Skeleton3D")
	_expect(preview.find_child("*AnimationPlayer*", true, false) is AnimationPlayer, "preview must retain AnimationPlayer")
	_expect(preview.find_child("*AnimationTree*", true, false) is AnimationTree, "preview must retain AnimationTree")
	_expect(_count_nodes_of_type(preview, "Area3D") == 0 and _count_nodes_of_type(preview, "CollisionShape3D") == 0, "preview must strip hitboxes/hurtboxes/colliders")
	_expect(preview.get_node_or_null("BoxingAIPlanner") == null and preview.get_node_or_null("FightManager") == null, "preview must not include AI or FightManager")
	var player := preview.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
	_expect(player.current_animation.contains("idle") or player.current_animation.contains("boxing_idle"), "preview must autoplay idle/boxing_idle, got %s" % player.current_animation)


func _test_categories_and_realtime_appearance() -> void:
	var categories: Array = creator.get("categories")
	for required in ["Nombre", "Apellido", "Apodo", "Edad", "País", "Mano dominante", "Guardia", "Altura", "Peso", "Color de piel", "Corte de pelo", "Color de pelo", "Barba", "Color de barba", "Short", "Color de short", "Guantes", "Color de guantes", "Zapatos", "Estilo de pelea"]:
		_expect(categories.has(required), "missing category %s" % required)
	var appearance: Resource = creator.get("appearance")
	_expect(appearance is CareerFighter, "creator must use CareerFighter resource")
	creator.call("select_category", "Color de piel")
	creator.call("select_option_for_test", "Tan")
	_expect(str(appearance.get("skin_tone")) == "Tan", "skin option must update resource")
	var preview := creator.get_node("SubViewportContainer/SubViewport/PreviewWorld/FighterPreview")
	_expect(str(preview.get("last_skin_tone")) == "Tan", "skin option must update 3D preview")
	creator.call("select_category", "Color de guantes")
	creator.call("select_option_for_test", "Red")
	_expect(str(appearance.get("glove_color")) == "Red", "glove color must update resource")
	_expect(str(preview.get("last_glove_color")) == "Red", "glove color must update preview")


func _test_rotation_and_camera_focus() -> void:
	var preview := creator.get_node("SubViewportContainer/SubViewport/PreviewWorld/FighterPreview")
	var before: float = preview.rotation.y
	creator.call("rotate_preview_for_test", 1.0)
	await process_frame
	_expect(absf(preview.rotation.y - before) > 0.01, "Q/E/gamepad rotation path must rotate preview")
	var camera := creator.get_node("SubViewportContainer/SubViewport/PreviewWorld/Camera3D") as Camera3D
	creator.call("select_category", "Corte de pelo")
	await create_timer(0.25).timeout
	var face_distance := camera.position.length()
	creator.call("select_category", "Short")
	await create_timer(0.25).timeout
	_expect(camera.position.length() > face_distance, "camera must pull back from face focus to body/clothing focus")


func _test_save_to_career() -> void:
	creator.call("set_identity_for_test", "Luis", "Duran", "El Rayo", 24)
	creator.call("confirm_creation")
	_expect(SaveSystem.career.has("created_fighter"), "confirm must save created fighter appearance")
	var created: Dictionary = SaveSystem.career.created_fighter
	_expect(created.first_name == "Luis" and created.last_name == "Duran" and created.nickname == "El Rayo" and int(created.age) == 24, "identity must be saved")
	_expect(created.has("style") and created.has("appearance"), "style and appearance must be saved for career")


func _count_nodes_of_type(node: Node, type_name: String) -> int:
	var count := 1 if node.is_class(type_name) else 0
	for child in node.get_children():
		count += _count_nodes_of_type(child, type_name)
	return count
