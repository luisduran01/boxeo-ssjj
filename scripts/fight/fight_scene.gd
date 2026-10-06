extends Node3D

const BOXING_RING_SCENE := preload("res://ring/boxing_ring.tscn")
const REFEREE_SCENE := preload("res://referee/referee.tscn")
const FIGHTER_DATABASE := preload("res://scripts/data/fighter_database.gd")
const HIT_FEEDBACK_SYSTEM := preload("res://scripts/presentation/hit_feedback_system.gd")
const PROCEDURAL_DEBUG_OVERLAY := preload("res://scripts/ui/procedural_debug_overlay.gd")

var player: BoxerController
var enemy: BoxerController
var camera_rig: BoxingCamera
var hud: FightHUD
var manager: FightManager
var referee: RefereeController
var hit_feedback: Node
var procedural_debug_overlay: Label


func _ready() -> void:
	SaveSystem.load_all()
	var ring := BOXING_RING_SCENE.instantiate()
	add_child(ring)
	var default_player := ring.get_node_or_null("Player")
	var default_enemy := ring.get_node_or_null("Boxer02")
	if default_player:
		ring.remove_child(default_player)
		default_player.queue_free()
	if default_enemy:
		ring.remove_child(default_enemy)
		default_enemy.queue_free()
	var player_data := _selected_fighter("selected_player", &"fighter_1")
	var enemy_data := _selected_fighter("selected_opponent", &"fighter_2")
	if enemy_data == player_data:
		enemy_data = FIGHTER_DATABASE.by_id(&"fighter_2" if player_data.id != &"fighter_2" else &"fighter_1")
	player = player_data.scene.instantiate() as BoxerController
	player.name = "Player"
	player.scale = Vector3.ONE * 1.55
	player.position = Vector3(0, 0, 1.9)
	ring.add_child(player)
	player.is_player = true
	player.fighter_name = player_data.display_name
	enemy = enemy_data.scene.instantiate() as BoxerController
	enemy.name = "Enemy"
	enemy.scale = Vector3.ONE * 1.55
	enemy.position = Vector3(0, 0, -1.9)
	ring.add_child(enemy)
	enemy.is_player = false
	enemy.fighter_name = enemy_data.display_name
	enemy.difficulty = str(SaveSystem.settings.difficulty)
	player.opponent = enemy
	enemy.opponent = player
	camera_rig = BoxingCamera.new()
	camera_rig.name = "BoxingCamera"
	add_child(camera_rig)
	camera_rig.setup(player, enemy)
	hud = FightHUD.new()
	add_child(hud)
	hud.setup(player, enemy)
	hud.restart_requested.connect(func(): get_tree().reload_current_scene())
	hud.quit_requested.connect(func(): get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn"))
	hud.settings_requested.connect(_open_settings)
	procedural_debug_overlay = PROCEDURAL_DEBUG_OVERLAY.new()
	procedural_debug_overlay.name = "ProceduralDebugOverlay"
	procedural_debug_overlay.position = Vector2(930, 156)
	procedural_debug_overlay.size = Vector2(330, 210)
	procedural_debug_overlay.add_theme_font_size_override("font_size", 13)
	add_child(procedural_debug_overlay)
	var audio := BoxingAudio.new()
	add_child(audio)
	manager = FightManager.new()
	add_child(manager)
	hit_feedback = HIT_FEEDBACK_SYSTEM.new()
	hit_feedback.name = "HitFeedbackSystem"
	add_child(hit_feedback)
	hit_feedback.setup(camera_rig, audio, hud)
	referee = REFEREE_SCENE.instantiate() as RefereeController
	referee.name = "Referee"
	referee.position = Vector3(-2.7, 0.0, 0.0)
	add_child(referee)
	referee.setup(player, enemy)
	manager.setup(player, enemy, hud, audio, referee)


func _selected_fighter(session_key: String, fallback_id: StringName) -> FighterData:
	var id := StringName(str(SaveSystem.session.get(session_key, fallback_id)))
	var data: FighterData = FIGHTER_DATABASE.by_id(id)
	if data == null:
		data = FIGHTER_DATABASE.by_id(fallback_id)
	return data


func _open_settings() -> void:
	get_tree().paused = false
	SaveSystem.session.settings_return_scene = "res://fight/fight.tscn"
	get_tree().change_scene_to_file("res://scenes/menus/settings.tscn")


func _process(delta: float) -> void:
	if is_instance_valid(referee) and is_instance_valid(player) and is_instance_valid(enemy):
		var distance := player.global_position.distance_to(enemy.global_position)
		if player.debug_boxing_movement:
			var movement := player.get_boxing_movement_debug()
			hud.set_debug("FOOTWORK %s  RANGE %s\nDISTANCE %.2f  INTENSITY %.2f\nINPUT %s  SPEED %.2f / %.2f\nTARGET %s  FACING %.2f\nSEPARATION %s  AI %s" % [movement.locomotion_state, movement.range_state, movement.distance, movement.movement_intensity, movement.input_vector, movement.speed, movement.target_speed, movement.target, movement.facing_alignment, movement.separation_correction, enemy.ai_state])
		elif player.punch_debug_enabled:
			var punch := player.get_punch_debug()
			hud.set_debug("ATTACK %s  PHASE %s  HAND %s\nRANGE %.2f  TARGET %s  ACTIVE %s\nRESULT %s  DAMAGE %.1f  COST %.1f\nCOUNTER %s  DISTANCE %.2f\nAI %s  REF %s" % [punch.attack, punch.phase, punch.hand, punch.range, punch.target, punch.hitbox_active, punch.hit_result, punch.damage, punch.stamina_cost, punch.counter, punch.distance, enemy.ai_state, RefereeController.State.keys()[referee.state]])
		else:
			hud.set_debug("")
		if procedural_debug_overlay != null:
			procedural_debug_overlay.update_from_debug(player.get_procedural_debug() if SaveSystem.settings.get("debug", false) else {})
