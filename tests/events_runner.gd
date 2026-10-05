extends SceneTree

const FIGHT_SCENE := preload("res://scripts/fight/fight_scene.gd")

var failures := 0
var observed := {
	"fight_started": 0,
	"round_started": 0,
	"round_ended": 0,
	"punch_landed": 0,
	"knockdown_started": 0,
	"fight_finished": 0,
}
var fight: Node


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("EVENTS: " + message)


func _run() -> void:
	_test_events_autoload_contract()
	_connect_events()
	await _spawn_fight({"mode": "sparring", "rounds": 1, "round_duration": 0.18, "selected_player": "fighter_1", "selected_opponent": "fighter_2"})
	await create_timer(0.45).timeout
	_force_one_hit()
	await process_frame
	_force_one_knockdown()
	await create_timer(1.0).timeout
	_expect(observed.fight_started >= 1, "Events must emit fight_started")
	_expect(observed.round_started >= 1, "Events must emit round_started")
	_expect(observed.punch_landed >= 1, "Events must emit punch_landed without direct BoxerController subscriptions")
	_expect(observed.knockdown_started >= 1, "Events must emit knockdown_started")
	_expect(observed.fight_finished >= 1, "Events must emit fight_finished")
	if failures > 0:
		push_error("EVENTS TESTS FAILED: %d" % failures)
		quit(1)
	else:
		print("EVENTS TESTS PASSED")
		quit(0)


func _test_events_autoload_contract() -> void:
	_expect(Engine.has_singleton("Events") or get_root().has_node("/root/Events"), "Events autoload must exist")
	if not get_root().has_node("/root/Events"):
		return
	var events := get_root().get_node("/root/Events")
	for signal_name in [
		"fight_started",
		"round_started",
		"round_ended",
		"punch_thrown",
		"punch_landed",
		"punch_blocked",
		"punch_missed",
		"punch_slipped",
		"guard_broken",
		"stunned",
		"wobbled",
		"clinch_started",
		"clinch_ended",
		"counter_hit",
		"knockdown_started",
		"fight_finished",
	]:
		_expect(events.has_signal(signal_name), "Events must expose signal %s" % signal_name)


func _connect_events() -> void:
	if not get_root().has_node("/root/Events"):
		return
	var events := get_root().get_node("/root/Events")
	events.fight_started.connect(func(): observed.fight_started += 1)
	events.round_started.connect(func(_round_number: int): observed.round_started += 1)
	events.round_ended.connect(func(_round_number: int, _cards: Array): observed.round_ended += 1)
	events.punch_landed.connect(func(_attacker: Node, _defender: Node, _result: Dictionary): observed.punch_landed += 1)
	events.knockdown_started.connect(func(_fallen: Node, _standing: Node): observed.knockdown_started += 1)
	events.fight_finished.connect(func(_result: Dictionary): observed.fight_finished += 1)


func _spawn_fight(session: Dictionary) -> void:
	SaveSystem.load_all()
	SaveSystem.session = session
	fight = FIGHT_SCENE.new()
	get_root().add_child(fight)
	await process_frame


func _force_one_hit() -> void:
	fight.manager.state = FightManager.State.FIGHTING
	fight.manager.fight_stats.start_round(fight.manager.current_round)
	fight.manager._on_punch_landed(fight.player, fight.enemy, {
		"damage": 7.0,
		"zone": "head_center",
		"counter": false,
		"blocked": false,
	})


func _force_one_knockdown() -> void:
	fight.manager.state = FightManager.State.FIGHTING
	fight.manager._knockdown_in_progress = false
	fight.enemy.knockdowns = fight.manager.tko_knockdown_limit - 1
	fight.manager._on_knockdown(fight.enemy)
