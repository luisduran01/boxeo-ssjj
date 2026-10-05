class_name HitFeedbackSystem
extends Node

var camera: BoxingCamera
var audio: BoxingAudio
var hud: FightHUD
var _events: Node
var _hitstop_serial := 0


func setup(p_camera: BoxingCamera, p_audio: BoxingAudio, p_hud: FightHUD) -> void:
	camera = p_camera
	audio = p_audio
	hud = p_hud
	_events = get_node_or_null("/root/Events")
	if _events == null:
		return
	_connect_event("punch_landed", _on_punch_landed)
	_connect_event("round_started", _on_round_started)
	_connect_event("round_ended", _on_round_ended)
	_connect_event("knockdown_started", _on_knockdown_started)
	_connect_event("fight_finished", _on_fight_finished)


func _connect_event(signal_name: StringName, callable: Callable) -> void:
	if _events.has_signal(signal_name) and not _events.is_connected(signal_name, callable):
		_events.connect(signal_name, callable)


func _on_punch_landed(_attacker: Node, defender: Node, result: Dictionary) -> void:
	apply_hit_feedback(_attacker, defender, result)


func apply_hit_feedback(attacker: Node, defender: Node, result: Dictionary) -> void:
	var attack_name := str(result.get("attack_name", "jab"))
	var attack := MoveLibrary.attack_data(StringName(attack_name))
	if attack.is_empty():
		attack = CombatRules.attack_data(attack_name)
	var blocked := bool(result.get("blocked", false))
	var damage := float(result.get("damage", 0.0))
	var counter_bonus := float(result.get("counter_bonus", 1.0))
	var strength: float = float(attack.get("camera_feedback", 0.004))
	if counter_bonus > 1.0:
		strength += 0.006
	if blocked:
		strength *= 0.28
	strength *= float(SaveSystem.settings.get("camera_shake", 0.7))
	if is_instance_valid(camera) and strength > 0.003:
		camera.impact(strength)
	if is_instance_valid(hud):
		hud.flash_damage(defender as BoxerController, damage)
	if is_instance_valid(audio):
		audio.play_cue("block" if blocked else _attack_cue(attack_name))
	_apply_pushback(attacker as Node3D, defender as Node3D, attack, blocked)
	_apply_head_snap(defender as Node3D, damage, blocked)
	if not blocked:
		await _apply_hitstop(float(attack.get("hit_stop", 0.02)) + (0.008 if counter_bonus > 1.0 else 0.0), attacker, defender)
	_apply_vibration(damage)


func _on_round_started(round_number: int) -> void:
	if is_instance_valid(hud):
		hud.show_round_started(round_number)
	if is_instance_valid(audio):
		audio.play_cue("bell")


func _on_round_ended(round_number: int, cards: Array) -> void:
	if is_instance_valid(hud):
		hud.show_between_round_cards(round_number, cards)
	if is_instance_valid(audio):
		audio.play_cue("bell")


func _on_knockdown_started(fallen: Node, _standing: Node) -> void:
	if is_instance_valid(camera) and fallen is Node3D:
		camera.set_knockdown_focus(fallen as Node3D)
	if is_instance_valid(hud):
		hud.set_knockdown_mode(true)
	if is_instance_valid(audio):
		audio.play_cue("crowd_knockdown")


func _on_fight_finished(result: Dictionary) -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(hud):
		hud.show_result_from_data(result)
	if is_instance_valid(audio):
		audio.play_cue("announcer_result")


func _attack_cue(attack_name: String) -> String:
	if attack_name in ["jab", "cross", "left_hook", "right_hook", "uppercut"]:
		return attack_name
	return "jab"


func _apply_hitstop(seconds: float, attacker: Node = null, defender: Node = null) -> void:
	_hitstop_serial += 1
	var serial := _hitstop_serial
	var scaled_players: Array[AnimationPlayer] = []
	for node in [attacker, defender]:
		if node is BoxerController and is_instance_valid((node as BoxerController).animation_player):
			var anim := (node as BoxerController).animation_player
			scaled_players.append(anim)
			anim.speed_scale = 0.0
	await get_tree().create_timer(maxf(0.0, seconds), true, false, true).timeout
	if serial == _hitstop_serial:
		for anim in scaled_players:
			if is_instance_valid(anim):
				anim.speed_scale = 1.0


func _apply_pushback(attacker: Node3D, defender: Node3D, attack: Dictionary, blocked: bool) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		return
	var direction := defender.global_position - attacker.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = -attacker.global_basis.z
	var amount := float(attack.get("pushback", 0.08)) * (0.35 if blocked else 1.0)
	defender.global_position += direction.normalized() * amount


func _apply_head_snap(defender: Node3D, damage: float, blocked: bool) -> void:
	if not is_instance_valid(defender) or blocked:
		return
	defender.rotation.x = clampf(damage / 180.0, 0.0, 0.12)
	defender.rotation.z = clampf(damage / 220.0, 0.0, 0.10)


func _apply_vibration(damage: float) -> void:
	if not bool(SaveSystem.settings.get("vibration", true)):
		return
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, clampf(damage / 35.0, 0.08, 0.35), clampf(damage / 24.0, 0.12, 0.65), 0.09)
