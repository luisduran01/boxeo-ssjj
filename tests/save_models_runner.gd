extends SceneTree

const SETTINGS_FIXTURE := "user://codex_test_settings.cfg"
const CAREER_FIXTURE := "user://codex_test_career.json"
const LEGACY_SETTINGS_FIXTURE := "user://codex_test_settings.json"
const LEGACY_CAREER_FIXTURE := "user://codex_test_career_legacy.json"

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("SAVE_MODELS: " + message)


func _run() -> void:
	_cleanup()
	var save_script := load("res://scripts/managers/save_system.gd")
	var career_script := load("res://scripts/data/career_data.gd")
	_expect(save_script != null, "save_system.gd must load")
	_expect(career_script != null, "career_data.gd must load")
	_expect(save_script != null and save_script.can_instantiate(), "save_system.gd must compile")
	_expect(career_script != null and career_script.can_instantiate(), "career_data.gd must compile")
	if save_script != null and career_script != null and save_script.can_instantiate() and career_script.can_instantiate():
		_test_defaults_and_validation(save_script)
		_test_career_progression(save_script)
		_test_persistence_and_fallback(save_script)
	_cleanup()
	if failures == 0:
		print("SAVE MODEL TESTS PASSED")
		quit(0)
	else:
		push_error("SAVE MODEL TESTS FAILED: %d" % failures)
		quit(1)


func _test_defaults_and_validation(save_script: Script) -> void:
	var settings: Dictionary = save_script.default_settings()
	for key in [&"difficulty", &"rounds", &"round_duration", &"units", &"master", &"music", &"sfx", &"voice", &"crowd", &"ui", &"display_mode", &"resolution", &"vsync", &"fps_limit", &"camera_distance", &"camera_height", &"camera_fov", &"camera_shake", &"language", &"text_scale", &"subtitles", &"high_contrast"]:
		_expect(settings.has(key), "settings defaults missing %s" % key)
	var career: Dictionary = save_script.default_career()
	for key in [&"fighter", &"wins", &"losses", &"draws", &"kos", &"ranking", &"money", &"fitness", &"training_progress", &"next_opponent", &"next_fight_date", &"fight_history", &"attributes", &"fatigue", &"current_week"]:
		_expect(career.has(key), "career defaults missing %s" % key)
	save_script.settings = settings
	_expect(not save_script.update_setting(&"not_a_setting", 3, false), "unknown setting must be rejected")
	_expect(not save_script.update_setting(&"rounds", 5, false), "unsupported round count must be rejected")
	_expect(save_script.update_setting(&"rounds", 12, false) and save_script.settings.rounds == 12, "supported round count must be stored")
	save_script.ensure_audio_buses()
	for bus_name in ["Master", "Music", "SFX", "Voice", "Crowd", "UI"]:
		_expect(AudioServer.get_bus_index(bus_name) >= 0, "missing audio bus %s" % bus_name)


func _test_career_progression(save_script: Script) -> void:
	save_script.career = save_script.default_career()
	save_script.career.attributes.power = 100
	var start_week: int = save_script.career.current_week
	var trained: Dictionary = save_script.advance_week(&"power")
	_expect(trained.attributes.power == 100, "training stat must cap at 100")
	_expect(trained.current_week == start_week + 1, "training must advance one week")
	_expect(trained.fatigue >= 0 and trained.fatigue <= 100, "fatigue must stay in range")
	_expect(trained.fitness >= 0 and trained.fitness <= 100, "fitness must stay in range")
	var fatigue_before: int = trained.fatigue
	var rested: Dictionary = save_script.advance_week(&"rest")
	_expect(rested.fatigue < fatigue_before, "rest must reduce fatigue")
	save_script.record_fight(&"WIN", &"TKO", 6, &"fighter_2", "2026-10-12")
	var entry: Dictionary = save_script.career.fight_history[0]
	_expect(entry == {"result": "WIN", "method": "TKO", "round": 6, "opponent": "fighter_2", "date": "2026-10-12"}, "fight history must preserve all result fields")


func _test_persistence_and_fallback(save_script: Script) -> void:
	save_script.configure_paths(SETTINGS_FIXTURE, CAREER_FIXTURE, LEGACY_SETTINGS_FIXTURE, LEGACY_CAREER_FIXTURE)
	save_script.settings = save_script.default_settings()
	save_script.career = save_script.default_career()
	save_script.settings.music = 0.35
	save_script.career.money = 4321
	save_script.save_settings()
	save_script.save_career()
	save_script.settings = {}
	save_script.career = {}
	save_script.load_all()
	_expect(is_equal_approx(float(save_script.settings.music), 0.35), "settings.cfg must reload saved audio")
	_expect(save_script.career.money == 4321, "career_save.json must reload career data")
	var malformed := FileAccess.open(CAREER_FIXTURE, FileAccess.WRITE)
	malformed.store_string("{not json")
	malformed.close()
	save_script.career = {}
	save_script.load_all()
	_expect(save_script.career.fitness == 100 and save_script.career.fight_history is Array, "malformed career data must fall back to defaults")


func _cleanup() -> void:
	for path in [SETTINGS_FIXTURE, CAREER_FIXTURE, LEGACY_SETTINGS_FIXTURE, LEGACY_CAREER_FIXTURE]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
