extends SceneTree

const FighterDatabaseScript = preload("res://scripts/data/fighter_database.gd")

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FIGHTER_SELECT: " + message)

func _run() -> void:
	var packed := load("res://scenes/menus/fighter_select.tscn") as PackedScene
	_expect(packed != null, "fighter select scene must load")
	if packed != null:
		var menu := packed.instantiate()
		get_root().add_child(menu)
		await process_frame
		await process_frame
		_test_menu(menu)
		menu.queue_free()
		await process_frame
	await _test_preview()
	if failures == 0:
		print("FIGHTER SELECT TESTS PASSED")
		quit(0)
	else:
		push_error("FIGHTER SELECT TESTS FAILED: %d" % failures)
		quit(1)

func _test_menu(menu: Node) -> void:
	var cards := menu.find_children("FighterCard*", "Button", true, false)
	_expect(cards.size() == 3, "menu must expose exactly three fighter cards")
	var confirm := menu.find_child("ConfirmButton", true, false) as Button
	_expect(confirm != null and confirm.disabled, "confirm must start disabled")
	_expect(menu.select_player(&"fighter_1"), "player selection must accept a valid fighter")
	_expect(not menu.select_opponent(&"fighter_1"), "mirror match must be rejected")
	var random_id: StringName = menu.random_opponent()
	_expect(random_id != &"" and random_id != &"fighter_1", "random opponent must differ from player")
	_expect(confirm != null and not confirm.disabled, "confirm must enable after valid selections")
	var stats := menu.find_child("StatsLabel", true, false) as Label
	_expect(stats != null and stats.text.contains("60 kg") and stats.text.contains("170 cm"), "stats must come from FighterData")
	_expect(menu.prepare_fight(), "valid selections must prepare a fight")
	_expect(SaveSystem.session.selected_player == "fighter_1", "session must store selected player id")
	_expect(SaveSystem.session.selected_opponent == str(random_id), "session must store selected opponent id")
	_expect(str(SaveSystem.session.player_scene).ends_with(".tscn") and str(SaveSystem.session.enemy_scene).ends_with(".tscn"), "session must store both scene paths")
	var back := menu.find_child("BackButton", true, false) as Button
	_expect(back != null and not back.pressed.get_connections().is_empty(), "Back must be a connected real button")

func _test_preview() -> void:
	var preview_script := load("res://scripts/ui/fighter_preview.gd")
	_expect(preview_script != null and preview_script.can_instantiate(), "fighter preview script must compile")
	if preview_script == null or not preview_script.can_instantiate(): return
	var preview: Control = preview_script.new()
	get_root().add_child(preview)
	await process_frame
	preview.show_fighter(FighterDatabaseScript.by_id(&"fighter_1"))
	await process_frame
	preview.show_fighter(FighterDatabaseScript.by_id(&"fighter_2"))
	await process_frame
	_expect(preview.live_preview_count() == 1, "switching fighters must keep only one live preview")
	var invalid := FighterData.new()
	invalid.id = &"invalid"
	preview.show_fighter(invalid)
	await process_frame
	_expect(preview.live_preview_count() == 0 and preview.is_fallback_visible(), "invalid preview must show a fallback without a live fighter")
	preview.queue_free()
