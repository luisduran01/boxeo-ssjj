extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var requested_size := OS.get_environment("BOXING_CAPTURE_SIZE")
	change_scene_to_file("res://fight/fight.tscn")
	await process_frame
	if requested_size == "1920x1080":
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		get_root().size = Vector2i(1920, 1080)
	for frame in range(24):
		await process_frame
	var fight = current_scene
	if fight == null or fight.player == null or fight.enemy == null or fight.referee == null:
		push_error("VISUAL_CAPTURE_SCENE_INCOMPLETE")
		quit(1)
		return
	fight.player.fight_enabled = false
	fight.enemy.fight_enabled = false
	fight.camera_rig._process(1.0)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	var error := image.save_png("res://tests/fight_capture.png")
	if error == OK:
		print("FIGHT_VISUAL_CAPTURE_OK")
		quit(0)
	else:
		push_error("FIGHT_VISUAL_CAPTURE_FAILED: %s" % error_string(error))
		quit(1)
