class_name FightTelemetry
extends Node

const OUTPUT_DIR := "res://telemetry"

var version_id := "phase_gameplay_v1"
var fight_id := ""
var totals := {}
var _events: Node


func _ready() -> void:
	_events = get_node_or_null("/root/Events")
	if _events == null:
		return
	_connect_event("punch_thrown", _on_punch_thrown)
	_connect_event("punch_landed", _on_punch_landed)
	_connect_event("punch_blocked", _on_punch_blocked)
	_connect_event("punch_missed", _on_punch_missed)
	_connect_event("knockdown_started", _on_knockdown_started)
	_connect_event("round_started", _on_round_started)
	_connect_event("fight_finished", _on_fight_finished)


func start_fight(p_version_id := "") -> void:
	if p_version_id != "":
		version_id = p_version_id
	fight_id = "%s_%d" % [version_id, Time.get_ticks_msec()]
	totals = {
		"rounds_started": 0,
		"punches_thrown": 0,
		"punches_landed": 0,
		"punches_blocked": 0,
		"punches_missed": 0,
		"knockdowns": 0,
		"damage": 0.0,
	}


func finish_fight(_result := {}) -> String:
	if fight_id == "":
		start_fight()
	var project_dir := DirAccess.open("res://")
	if project_dir != null:
		project_dir.make_dir_recursive("telemetry")
	var virtual_path := "%s/%s.csv" % [OUTPUT_DIR, fight_id]
	var path := ProjectSettings.globalize_path(virtual_path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return path
	var keys := ["version_id", "fight_id", "rounds_started", "punches_thrown", "punches_landed", "punches_blocked", "punches_missed", "knockdowns", "damage"]
	file.store_line(",".join(keys))
	file.store_line(",".join([
		version_id,
		fight_id,
		str(totals.rounds_started),
		str(totals.punches_thrown),
		str(totals.punches_landed),
		str(totals.punches_blocked),
		str(totals.punches_missed),
		str(totals.knockdowns),
		"%.2f" % float(totals.damage),
	]))
	file.close()
	return path


func _connect_event(signal_name: StringName, callable: Callable) -> void:
	if _events.has_signal(signal_name) and not _events.is_connected(signal_name, callable):
		_events.connect(signal_name, callable)


func _on_round_started(_round_number: int) -> void:
	totals.rounds_started = int(totals.get("rounds_started", 0)) + 1


func _on_punch_thrown(_attacker: Node, _attack_name: String) -> void:
	totals.punches_thrown = int(totals.get("punches_thrown", 0)) + 1


func _on_punch_landed(_attacker: Node, _defender: Node, result: Dictionary) -> void:
	if bool(result.get("blocked", false)):
		_on_punch_blocked(_attacker, _defender, result)
		return
	totals.punches_landed = int(totals.get("punches_landed", 0)) + 1
	totals.damage = float(totals.get("damage", 0.0)) + float(result.get("damage", 0.0))


func _on_punch_blocked(_attacker: Node, _defender: Node, _result: Dictionary) -> void:
	totals.punches_blocked = int(totals.get("punches_blocked", 0)) + 1


func _on_punch_missed(_attacker: Node, _attack_name: String) -> void:
	totals.punches_missed = int(totals.get("punches_missed", 0)) + 1


func _on_knockdown_started(_fallen: Node, _standing: Node) -> void:
	totals.knockdowns = int(totals.get("knockdowns", 0)) + 1


func _on_fight_finished(result: Dictionary) -> void:
	finish_fight(result)
