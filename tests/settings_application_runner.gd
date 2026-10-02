extends SceneTree

var failures := 0

func _initialize() -> void: _run.call_deferred()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("SETTINGS_APPLICATION: " + message)

func _run() -> void:
	var original := SaveSystem.settings.duplicate(true)
	var action_snapshot: Dictionary = {}
	for action in InputMap.get_actions(): action_snapshot[action] = InputMap.action_get_events(action).duplicate()
	_expect(SaveSystem.available_resolutions() == [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)], "supported resolutions must be exact")
	SaveSystem.ensure_audio_buses()
	for bus in ["Master", "Music", "SFX", "Voice", "Crowd", "UI"]: _expect(AudioServer.get_bus_index(bus) >= 0, "missing %s bus" % bus)
	SaveSystem.settings.music = 0.42
	SaveSystem.apply_audio_settings()
	_expect(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))), 0.42), "audio must apply live")
	for fps in [30, 60, 120, 144, 0]:
		SaveSystem.settings.fps_limit = fps
		SaveSystem.apply_runtime_settings()
		_expect(Engine.max_fps == fps, "FPS %d must apply" % fps)
	var previous_resolution: String = SaveSystem.settings.resolution
	_expect(not SaveSystem.update_setting(&"resolution", "111x222", false), "unsupported resolution must be rejected")
	_expect(SaveSystem.settings.resolution == previous_resolution, "rejected resolution must retain state")
	var camera := BoxingCamera.new()
	get_root().add_child(camera)
	camera.setup(Node3D.new(), Node3D.new())
	SaveSystem.settings.camera_distance = 1.2
	SaveSystem.settings.camera_height = 0.9
	SaveSystem.settings.camera_fov = 76.0
	SaveSystem.settings.camera_shake = 0.25
	camera.apply_settings()
	_expect(is_equal_approx(camera.distance_scale, 1.2) and is_equal_approx(camera.height_scale, 0.9), "camera geometry settings must apply")
	_expect(is_equal_approx(camera.base_fov, 76.0) and is_equal_approx(camera.shake_scale, 0.25), "camera FOV and shake must apply")
	for action in action_snapshot:
		_expect(InputMap.has_action(action) and InputMap.action_get_events(action) == action_snapshot[action], "settings must not alter input %s" % action)
	camera.queue_free()
	SaveSystem.settings = original
	SaveSystem.apply_settings()
	if failures == 0:
		print("SETTINGS APPLICATION TESTS PASSED")
		quit(0)
	else:
		push_error("SETTINGS APPLICATION TESTS FAILED: %d" % failures)
		quit(1)
