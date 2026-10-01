extends Node3D

const PLAYER_BOXER_SCENE := preload("res://fighters/boxer_green/boxer_green.tscn")
const ENEMY_BOXER_SCENE := preload("res://fighters/boxer_02/boxer_02.tscn")
const REFEREE_SCENE := preload("res://referee/referee.tscn")

var player: BoxerController
var enemy: BoxerController
var camera_rig: BoxingCamera
var hud: FightHUD
var manager: FightManager
var referee: RefereeController


func _ready() -> void:
	SaveSystem.load_all()
	var ring := RingBuilder.new()
	add_child(ring)
	player = PLAYER_BOXER_SCENE.instantiate() as BoxerController
	player.name = "Player"
	player.is_player = true
	player.fighter_name = str(SaveSystem.career.name)
	player.position = Vector3(0, 0, 1.9)
	add_child(player)
	enemy = ENEMY_BOXER_SCENE.instantiate() as BoxerController
	enemy.name = "Enemy"
	enemy.is_player = false
	enemy.fighter_name = "MARCO ROJAS"
	enemy.difficulty = str(SaveSystem.settings.difficulty)
	enemy.position = Vector3(0, 0, -1.9)
	add_child(enemy)
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
	var audio := BoxingAudio.new()
	add_child(audio)
	manager = FightManager.new()
	add_child(manager)
	player.punch_landed.connect(_on_punch_landed)
	enemy.punch_landed.connect(_on_punch_landed)
	referee = REFEREE_SCENE.instantiate() as RefereeController
	referee.name = "Referee"
	referee.position = Vector3(-2.7, 0.0, 0.0)
	add_child(referee)
	referee.setup(player, enemy)
	manager.setup(player, enemy, hud, audio, referee)


func _open_settings() -> void:
	get_tree().paused = false
	SaveSystem.session.settings_return_scene = "res://fight/fight.tscn"
	get_tree().change_scene_to_file("res://scenes/menus/settings.tscn")


func _process(delta: float) -> void:
	if is_instance_valid(referee) and is_instance_valid(player) and is_instance_valid(enemy):
		var distance := player.global_position.distance_to(enemy.global_position)
		if player.punch_debug_enabled:
			var punch := player.get_punch_debug()
			hud.set_debug("ATTACK %s  PHASE %s  HAND %s\nRANGE %.2f  TARGET %s  ACTIVE %s\nRESULT %s  DAMAGE %.1f  COST %.1f\nCOUNTER %s  DISTANCE %.2f\nAI %s  REF %s" % [punch.attack, punch.phase, punch.hand, punch.range, punch.target, punch.hitbox_active, punch.hit_result, punch.damage, punch.stamina_cost, punch.counter, punch.distance, enemy.ai_state, RefereeController.State.keys()[referee.state]])
		else:
			hud.set_debug("")


func _on_punch_landed(attacker: BoxerController, defender: BoxerController, result: Dictionary) -> void:
	var attack_name: String = attacker._current_attack
	var attack := CombatRules.attack_data(attack_name)
	var strength: float = float(attack.get("camera_feedback", 0.004))
	if float(result.counter_bonus) > 1.0:
		strength += 0.006
	if bool(result.blocked):
		strength *= 0.28
	strength *= float(SaveSystem.settings.camera_shake)
	if strength > 0.003:
		camera_rig.impact(strength)
	hud.flash_damage(defender, float(result.damage))
	var audio: BoxingAudio = manager.audio
	audio.play_cue("block" if result.blocked else ("jab" if attack_name == "jab" else attack_name))
	if not bool(result.blocked):
		var hit_stop: float = float(attack.get("hit_stop", 0.02))
		if float(result.counter_bonus) > 1.0:
			hit_stop += 0.008
		Engine.time_scale = 0.38
		await get_tree().create_timer(hit_stop, true, false, true).timeout
		Engine.time_scale = 1.0
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, clampf(float(result.damage) / 35.0, 0.08, 0.35), clampf(float(result.damage) / 24.0, 0.12, 0.65), 0.09)
