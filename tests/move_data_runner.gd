extends SceneTree

const MOVE_LIBRARY_PATH := "res://scripts/combat/move_library.gd"
const MOVE_DATA_PATH := "res://scripts/combat/move_data.gd"
const MOVE_IDS: Array[StringName] = [&"jab", &"cross", &"left_hook", &"right_hook", &"uppercut"]
const FPS := 60.0
const PUBLIC_KEYS := [
	"attack_name",
	"animation_name",
	"hand",
	"attack_type",
	"target_level",
	"startup",
	"active_time",
	"recovery",
	"damage",
	"stamina_cost",
	"min_range",
	"range",
	"power",
	"stun",
	"counter_bonus",
	"movement_allowed",
	"tracking_strength",
	"step_in",
	"hit_stop",
	"camera_feedback",
	"animation_speed",
	"cancel_window",
	"active",
	"cost",
	"zone",
]

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("MOVE DATA: " + message)


func _run() -> void:
	var data_script := load(MOVE_DATA_PATH) as Script
	var library_script := load(MOVE_LIBRARY_PATH) as Script
	_expect(data_script != null, "MoveData script must load")
	_expect(library_script != null, "MoveLibrary script must load")
	if library_script != null:
		_assert_library(library_script)
	_assert_combat_rules_public_contract()
	if failures > 0:
		push_error("MOVE DATA TESTS FAILED: %d" % failures)
		quit(1)
	else:
		print("MOVE DATA TESTS PASSED")
		quit(0)


func _assert_library(library_script: Script) -> void:
	var library := library_script
	var errors: Array = library.validate()
	_expect(errors.is_empty(), "MoveLibrary.validate must be clean: %s" % [errors])
	var ids: Array = library.all_ids()
	for move_id in MOVE_IDS:
		_expect(ids.has(move_id), "MoveLibrary.all_ids must include %s" % move_id)
		var data: Dictionary = library.attack_data(move_id)
		_expect(not data.is_empty(), "MoveLibrary.attack_data(%s) must return data" % move_id)
		if data.is_empty():
			continue
		_assert_required_public_keys(data, str(move_id))
		_expect(float(data.startup) == float(data.startup_frames) / FPS, "%s startup must derive from startup_frames at 60 fps" % move_id)
		_expect(float(data.active_time) == float(data.active_frames) / FPS, "%s active_time must derive from active_frames at 60 fps" % move_id)
		_expect(float(data.recovery) == float(data.recovery_frames) / FPS, "%s recovery must derive from recovery_frames at 60 fps" % move_id)
		for key in ["startup_frames", "active_frames", "recovery_frames", "damage", "stamina_cost", "min_range", "range", "power", "stun", "counter_bonus", "animation_speed"]:
			_expect(float(data.get(key, 0.0)) > 0.0, "%s %s must be positive" % [move_id, key])


func _assert_combat_rules_public_contract() -> void:
	for move_id in MOVE_IDS:
		var data := CombatRules.attack_data(str(move_id))
		_expect(not data.is_empty(), "CombatRules.attack_data(%s) must return data" % move_id)
		if data.is_empty():
			continue
		_assert_required_public_keys(data, str(move_id))


func _assert_required_public_keys(data: Dictionary, move_id: String) -> void:
	for key in PUBLIC_KEYS:
		_expect(data.has(key), "%s missing public key %s" % [move_id, key])
