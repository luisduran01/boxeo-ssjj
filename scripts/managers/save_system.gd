class_name SaveSystem
extends RefCounted

const CareerDataModel = preload("res://scripts/data/career_data.gd")

static var settings_path := "user://settings.cfg"
static var career_path := "user://career_save.json"
static var legacy_settings_path := "user://settings.json"
static var legacy_career_path := "user://career.json"
static var settings := default_settings()
static var career := default_career()
static var session := {"mode": "quick", "rounds": 3, "round_duration": 120.0}

static func default_settings() -> Dictionary:
	return {"difficulty": "Normal", "rounds": 3, "round_duration": 120, "units": "Métricas", "show_hud": true, "visible_damage": true, "replays": true, "tips": true, "tutorial": true, "master": 0.8, "music": 0.7, "sfx": 0.85, "voice": 0.8, "crowd": 0.75, "ui": 0.8, "vibration": true, "invert_camera": false, "punch_sensitivity": 1.0, "camera_sensitivity": 1.0, "display_mode": "Windowed", "fullscreen": false, "resolution": "1280x720", "vsync": true, "fps_limit": 60, "graphics": "High", "camera_type": "Dynamic", "camera_distance": 1.0, "camera_height": 1.0, "camera_fov": 70.0, "camera_shake": 0.7, "language": "es", "text_scale": 1.0, "subtitles": true, "high_contrast": false, "debug": false}

static func default_career() -> Dictionary:
	return CareerDataModel.defaults()

static func configure_paths(new_settings_path: String, new_career_path: String, new_legacy_settings_path: String = "", new_legacy_career_path: String = "") -> void:
	settings_path = new_settings_path
	career_path = new_career_path
	legacy_settings_path = new_legacy_settings_path
	legacy_career_path = new_legacy_career_path

static func load_all() -> void:
	settings = default_settings()
	var loaded_settings := _read_config(settings_path)
	if loaded_settings.is_empty() and not legacy_settings_path.is_empty(): loaded_settings = _read_json(legacy_settings_path)
	for key in loaded_settings: _update_setting_in(settings, StringName(key), loaded_settings[key])
	var loaded_career := _read_json(career_path)
	if loaded_career.is_empty() and not legacy_career_path.is_empty(): loaded_career = _read_json(legacy_career_path)
	career = CareerDataModel.normalize(loaded_career)
	ensure_audio_buses()
	apply_settings()

static func save_settings() -> void:
	var config := ConfigFile.new()
	for key in settings: config.set_value("settings", key, settings[key])
	config.save(settings_path)
	apply_settings()

static func save_career() -> void:
	_write_json(career_path, CareerDataModel.normalize(career))

static func update_setting(key: StringName, value: Variant, apply_now: bool = true) -> bool:
	var copy := settings.duplicate(true)
	if not _update_setting_in(copy, key, value): return false
	settings = copy
	if apply_now: apply_settings()
	return true

static func advance_week(action: StringName) -> Dictionary:
	career = CareerDataModel.advance_week(career, action)
	save_career()
	return career

static func record_fight(result: StringName, method: StringName, round_number: int, opponent_id: StringName, date: String) -> void:
	career = CareerDataModel.normalize(career)
	career.fight_history.push_front(CareerDataModel.history_entry(result, method, round_number, opponent_id, date))
	if result == &"WIN":
		career.wins += 1
		career.kos += 1 if method in [&"KO", &"TKO"] else 0
	elif result == &"LOSS": career.losses += 1
	else: career.draws += 1
	save_career()

static func apply_settings() -> void:
	ensure_audio_buses()
	for key in ["master", "music", "sfx", "voice", "crowd", "ui"]:
		var bus_name: String = "Master" if key == "master" else key.capitalize()
		var index := AudioServer.get_bus_index(bus_name)
		if index >= 0: AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, float(settings.get(key, 1.0)))))
	Engine.max_fps = int(settings.get("fps_limit", 60))
	if not DisplayServer.get_name().to_lower().contains("headless"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(settings.vsync) else DisplayServer.VSYNC_DISABLED)
		var mode := str(settings.display_mode)
		if mode == "Fullscreen": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif mode == "Borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		else:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var parts := str(settings.resolution).split("x")
			if parts.size() == 2: DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
	var viewport := Engine.get_main_loop().root as Viewport
	if viewport: viewport.msaa_3d = {"Low": Viewport.MSAA_DISABLED, "Medium": Viewport.MSAA_2X, "High": Viewport.MSAA_4X}.get(str(settings.graphics), Viewport.MSAA_4X)
	TranslationServer.set_locale(str(settings.language))

static func ensure_audio_buses() -> void:
	for bus_name in ["Music", "SFX", "Voice", "Crowd", "UI"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

static func record_result(won: bool, by_ko: bool) -> void:
	record_fight(&"WIN" if won else &"LOSS", &"KO" if by_ko else &"UD", 1, StringName(str(career.get("next_opponent", "fighter_2"))), str(career.get("current_date", "")))
	career.money += 650 if won else 250
	career.fans += 55 if won else 8
	career.ranking = maxi(1, career.ranking - 2) if won else mini(99, career.ranking + 1)
	save_career()

static func _update_setting_in(target: Dictionary, key: StringName, value: Variant) -> bool:
	if not target.has(key): return false
	match key:
		&"difficulty":
			if str(value) not in ["Easy", "Normal", "Hard", "Medium"]: return false
		&"rounds":
			if int(value) not in [3, 6, 8, 10, 12]: return false
		&"round_duration":
			if int(value) not in [60, 120, 180]: return false
		&"resolution":
			if str(value) not in ["1280x720", "1600x900", "1920x1080", "2560x1440"]: return false
		&"display_mode":
			if str(value) not in ["Windowed", "Fullscreen", "Borderless"]: return false
		&"fps_limit":
			if int(value) not in [0, 30, 60, 120, 144]: return false
		&"graphics":
			if str(value) not in ["Low", "Medium", "High"]: return false
		&"language":
			if str(value) not in ["es", "en"]: return false
		&"master", &"music", &"sfx", &"voice", &"crowd", &"ui", &"camera_shake": value = clampf(float(value), 0.0, 1.0)
		&"camera_distance", &"camera_height", &"punch_sensitivity", &"camera_sensitivity", &"text_scale": value = clampf(float(value), 0.5, 1.5)
		&"camera_fov": value = clampf(float(value), 50.0, 100.0)
	target[key] = value
	if key == &"fullscreen": target.display_mode = "Fullscreen" if bool(value) else "Windowed"
	return true

static func _read_config(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path): return {}
	var config := ConfigFile.new()
	if config.load(path) != OK: return {}
	var result: Dictionary = {}
	for key in config.get_section_keys("settings"): result[key] = config.get_value("settings", key)
	return result

static func _read_json(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path): return {}
	var source := FileAccess.get_file_as_string(path).strip_edges()
	if source.is_empty(): return {}
	var json := JSON.new()
	if json.parse(source) != OK: return {}
	return json.data if json.data is Dictionary else {}

static func _write_json(path: String, value: Dictionary) -> void:
	if path.is_empty(): return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(value, "  "))
