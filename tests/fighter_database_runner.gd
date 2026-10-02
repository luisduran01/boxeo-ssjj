extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FIGHTER_DATABASE: " + message)


func _run() -> void:
	var data_script := load("res://scripts/data/fighter_data.gd")
	var database_script := load("res://scripts/data/fighter_database.gd")
	_expect(data_script != null, "fighter_data.gd must load")
	_expect(database_script != null, "fighter_database.gd must load")
	if data_script != null and database_script != null:
		_test_registry(data_script, database_script)
	if failures == 0:
		print("FIGHTER DATABASE TESTS PASSED")
		quit(0)
	else:
		push_error("FIGHTER DATABASE TESTS FAILED: %d" % failures)
		quit(1)


func _test_registry(data_script: Script, database_script: Script) -> void:
	var fighters: Array = database_script.all()
	_expect(fighters.size() == 3, "database must contain exactly three fighters")
	var expected_styles := ["FAJADOR", "TÉCNICO", "ESTILISTA"]
	var ids: Dictionary = {}
	for index in range(fighters.size()):
		var fighter = fighters[index]
		_expect(not str(fighter.id).is_empty(), "fighter id must not be empty")
		ids[fighter.id] = true
		_expect(fighter.weight_kg == 60, "fighter weight must be 60 kg")
		_expect(fighter.height_cm == 170, "fighter height must be 170 cm")
		_expect(fighter.reach_cm == 55, "fighter reach must be 55 cm")
		_expect(fighter.style == expected_styles[index], "fighter style must match the approved roster")
		for stat in [fighter.power, fighter.speed, fighter.stamina, fighter.defense, fighter.technique]:
			_expect(stat >= 0 and stat <= 100, "fighter stats must remain in 0..100")
		_expect(fighter.scene is PackedScene, "fighter scene must be loadable")
		if fighter.scene is PackedScene:
			var instance: Node = (fighter.scene as PackedScene).instantiate()
			_expect(instance is BoxerController, "fighter scene root must use BoxerController")
			if fighter.id == &"fighter_3":
				_expect(instance.fighter_name == "FIGHTER 3", "Boxer 03 metadata must identify FIGHTER 3")
				_expect(instance.get_node_or_null("AnimationTree") is AnimationTree, "Fighter 3 must expose the controller AnimationTree path")
				_expect(instance.get_node_or_null(instance.animation_player_path) is AnimationPlayer, "Fighter 3 animation player path must resolve")
				_expect(instance.get_node_or_null(instance.skeleton_path) is Skeleton3D, "Fighter 3 skeleton path must resolve")
			instance.free()
	_expect(ids.size() == 3, "fighter IDs must be unique")
	_expect(database_script.by_id(&"fighter_2") == fighters[1], "lookup by id must return the registered resource")
	var invalid = data_script.new()
	invalid.id = &"invalid"
	var candidates: Array = fighters.duplicate()
	candidates.append(invalid)
	_expect(database_script.filter_valid(candidates).size() == 3, "invalid fighter entries must be excluded")
	_expect(database_script.valid_for_fight().size() == 3, "all three real fighters must be valid for a fight")
