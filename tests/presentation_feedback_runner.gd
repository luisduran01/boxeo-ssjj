extends SceneTree

const FEEDBACK_SCRIPT_PATH := "res://scripts/presentation/hit_feedback_system.gd"

var failures: Array[String] = []
var fight
var events: Node


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("PRESENTATION FEEDBACK: " + message)


func _run() -> void:
	SaveSystem.session = {"mode": "sparring", "rounds": 3, "round_duration": 120.0, "selected_player": "fighter_1", "selected_opponent": "fighter_2"}
	SaveSystem.settings.camera_shake = 1.0
	var feedback_script := load(FEEDBACK_SCRIPT_PATH) as Script
	_expect(feedback_script != null, "HitFeedbackSystem script must load")
	change_scene_to_file("res://fight/fight.tscn")
	await process_frame
	await process_frame
	fight = current_scene
	events = root.get_node_or_null("Events")
	_expect(events != null, "Events autoload must be available")
	_expect(fight.get_node_or_null("HitFeedbackSystem") != null, "Fight scene must own a HitFeedbackSystem node")
	_test_round_and_finish_events()
	await _test_clean_hit_feedback()
	await _test_blocked_hit_feedback()
	_test_knockdown_focus()
	await _cleanup_scene()
	if failures.is_empty():
		print("PRESENTATION FEEDBACK TESTS PASSED")
		quit(0)
	else:
		push_error("PRESENTATION FEEDBACK TESTS FAILED: %d" % failures.size())
		quit(1)


func _test_round_and_finish_events() -> void:
	events.emit_signal("round_started", 2)
	_expect(fight.hud.round_label.text == "ROUND 2", "round_started must update broadcast round label")
	events.emit_signal("round_ended", 2, [{"judge": "Judge 1", "player": 10, "enemy": 9}])
	_expect(fight.hud.banner.visible and fight.hud.banner.text.contains("ROUND 2"), "round_ended must show between-round cards")
	events.emit_signal("fight_finished", {"winner_name": "PLAYER", "method": "TKO", "round": 2, "time": 37.0})
	_expect(fight.hud.result_panel.visible and fight.hud.banner.text.contains("TKO"), "fight_finished must show result overlay")
	_expect(str(fight.manager.audio.last_cue) == "announcer_result", "fight_finished must route announcer_result cue")


func _test_clean_hit_feedback() -> void:
	Engine.time_scale = 1.0
	var before_shake: float = fight.camera_rig.shake_strength
	events.emit_signal("punch_landed", fight.player, fight.enemy, {
		"attack_name": "right_hook",
		"damage": 16.0,
		"blocked": false,
		"counter_bonus": 1.0,
	})
	_expect(fight.camera_rig.shake_strength > before_shake, "clean heavy hit must trigger camera impact")
	_expect(str(fight.manager.audio.last_cue) == "right_hook", "clean hit must route attack cue")
	await create_timer(0.08, true, false, true).timeout
	_expect(Engine.time_scale == 1.0, "hitstop must restore Engine.time_scale")


func _test_blocked_hit_feedback() -> void:
	Engine.time_scale = 1.0
	var before_shake: float = fight.camera_rig.shake_strength
	events.emit_signal("punch_landed", fight.enemy, fight.player, {
		"attack_name": "jab",
		"damage": 2.0,
		"blocked": true,
		"counter_bonus": 1.0,
	})
	await process_frame
	_expect(str(fight.manager.audio.last_cue) == "block", "blocked hit must route block cue")
	_expect(fight.camera_rig.shake_strength <= before_shake + 0.002, "blocked hit must not trigger heavy camera impact")
	_expect(Engine.time_scale == 1.0, "blocked hit must not leave hitstop active")


func _test_knockdown_focus() -> void:
	events.emit_signal("knockdown_started", fight.player, fight.enemy)
	_expect(fight.camera_rig.knockdown_focus == fight.player, "knockdown_started must focus fallen fighter")
	_expect(str(fight.manager.audio.last_cue) == "crowd_knockdown", "knockdown_started must route crowd knockdown cue")


func _cleanup_scene() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(fight) and is_instance_valid(fight.manager) and is_instance_valid(fight.manager.audio):
		var audio: BoxingAudio = fight.manager.audio
		if is_instance_valid(audio.player):
			audio.player.stop()
			audio.player.stream = null
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
	fight = null
	await process_frame
