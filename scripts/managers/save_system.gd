class_name SaveSystem
extends RefCounted

const SETTINGS_PATH := "user://settings.json"
const CAREER_PATH := "user://career.json"
static var settings := {"master": 0.8, "music": 0.65, "sfx": 0.85, "crowd": 0.6, "fullscreen": false, "resolution": "1280x720", "graphics": "High", "camera_shake": 0.7, "difficulty": "Medium", "debug": false}
static var career := {"name": "SANTIAGO GREEN", "wins": 0, "losses": 0, "kos": 0, "ranking": 50, "money": 1200, "fans": 80, "training_points": 0}
static var session := {"mode": "quick", "rounds": 3, "round_duration": 120.0}


static func load_all() -> void:
	settings.merge(_read_json(SETTINGS_PATH), true)
	career.merge(_read_json(CAREER_PATH), true)
	ensure_audio_buses()
	apply_settings()


static func save_settings() -> void:
	_write_json(SETTINGS_PATH, settings)
	apply_settings()


static func save_career() -> void:
	_write_json(CAREER_PATH, career)


static func apply_settings() -> void:
	ensure_audio_buses()
	AudioServer.set_bus_volume_db(0, linear_to_db(float(settings.master)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(float(settings.music)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(float(settings.sfx)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Crowd"), linear_to_db(float(settings.crowd)))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not settings.fullscreen:
		var parts := str(settings.resolution).split("x")
		if parts.size() == 2:
			DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
	var viewport := Engine.get_main_loop().root as Viewport
	if viewport:
		viewport.msaa_3d = {"Low": Viewport.MSAA_DISABLED, "Medium": Viewport.MSAA_2X, "High": Viewport.MSAA_4X}.get(str(settings.graphics), Viewport.MSAA_4X)


static func ensure_audio_buses() -> void:
	for bus_name in ["Music", "SFX", "Crowd"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


static func record_result(won: bool, by_ko: bool) -> void:
	career.wins += 1 if won else 0
	career.losses += 0 if won else 1
	career.kos += 1 if won and by_ko else 0
	career.money += 650 if won else 250
	career.fans += 55 if won else 8
	career.ranking = maxi(1, career.ranking - 2) if won else mini(99, career.ranking + 1)
	save_career()


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var source := FileAccess.get_file_as_string(path).strip_edges()
	if source.is_empty():
		return {}
	var json := JSON.new()
	if json.parse(source) != OK:
		return {}
	var parsed = json.data
	return parsed if parsed is Dictionary else {}


static func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(value, "  "))
