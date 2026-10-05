extends SceneTree

const HitboxQueryScript := preload("res://scripts/combat/hitbox_query.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("HIT QUERY: " + message)


func _run() -> void:
	_test_zoned_hurtboxes_and_sweep_no_tunneling()
	_test_no_double_impact_and_environment_ignored()
	if failures.is_empty():
		print("HIT_QUERY_TESTS_PASSED")
		quit(0)
		return
	push_error("HIT_QUERY_TESTS_FAILED: %d" % failures.size())
	quit(1)


func _test_zoned_hurtboxes_and_sweep_no_tunneling() -> void:
	var query = HitboxQueryScript.new()
	query.configure_default_zones()
	_expect(query.hurtboxes.size() >= 6, "hurtboxes must cover head, jaw, torso, liver sides and arms")
	_expect(query.hurtboxes_by_bone().has("mixamorig_Head"), "head hurtbox must be attached to head bone")
	var tunneled := 0
	for i in range(120):
		var y := 1.45 + sin(float(i)) * 0.04
		var hits: Array = query.sweep_hit(Vector3(-1.2, y, 0.0), Vector3(1.2, y, 0.0), 0.16, 5)
		if hits.is_empty():
			tunneled += 1
	_expect(tunneled == 0, "fast jabs must have 0 tunneling with sweep substeps")


func _test_no_double_impact_and_environment_ignored() -> void:
	var query = HitboxQueryScript.new()
	query.configure_default_zones()
	query.add_environment_body("referee", Vector3.ZERO, 0.8)
	query.add_environment_body("ropes", Vector3(0.0, 1.2, 0.0), 0.8)
	var hits: Array = query.sweep_hit(Vector3(-1.2, 1.2, 0.0), Vector3(1.2, 1.2, 0.0), 0.18, 5)
	for hit in hits:
		_expect(not str(hit.get("zone", "")).contains("referee") and not str(hit.get("zone", "")).contains("ropes"), "referee and ropes must not block or receive punch hits")
	_expect(query.register_active_hit("jab", int(hits[0].zone_id)), "first active hit must register")
	_expect(not query.register_active_hit("jab", int(hits[0].zone_id)), "same active phase must have 0 double impact")
