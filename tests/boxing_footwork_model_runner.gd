extends SceneTree

var failures := 0
var model


func _initialize() -> void:
	model = load("res://scripts/combat/boxing_footwork_model.gd")
	_expect(model != null, "BoxingFootworkModel must exist")
	if model != null:
		_test_ranges()
		_test_input_tiers()
		_test_combat_basis_and_velocity()
		_test_separation()
		_test_long_step_latch()
	if failures == 0:
		print("BOXING FOOTWORK MODEL TESTS PASSED")
		quit(0)
	else:
		push_error("BOXING FOOTWORK MODEL TESTS FAILED: %d" % failures)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FOOTWORK MODEL: " + message)


func _near(a: float, b: float, tolerance := 0.001) -> bool:
	return absf(a - b) <= tolerance


func _test_ranges() -> void:
	_expect(model.classify_range(3.0, 2.8, 2.1, 1.35, 0.78) == model.RangeState.OUTSIDE, "3.0 must be OUTSIDE")
	_expect(model.classify_range(2.8, 2.8, 2.1, 1.35, 0.78) == model.RangeState.LONG_RANGE, "outside boundary must enter LONG_RANGE")
	_expect(model.classify_range(2.1, 2.8, 2.1, 1.35, 0.78) == model.RangeState.MID_RANGE, "long boundary must enter MID_RANGE")
	_expect(model.classify_range(1.35, 2.8, 2.1, 1.35, 0.78) == model.RangeState.POCKET, "mid boundary must enter POCKET")
	_expect(model.classify_range(0.78, 2.8, 2.1, 1.35, 0.78) == model.RangeState.TOO_CLOSE, "pocket boundary must enter TOO_CLOSE")
	_expect(model.classify_range(2.4, 0.78, 1.35, 2.1, 2.8) == model.RangeState.LONG_RANGE, "misordered thresholds must normalize deterministically")


func _test_input_tiers() -> void:
	_expect(model.apply_radial_deadzone(Vector2(0.1, 0.0), 0.25) == Vector2.ZERO, "deadzone must remove small input")
	var filtered: Vector2 = model.apply_radial_deadzone(Vector2(0.0, 0.625), 0.25)
	_expect(_near(filtered.length(), 0.5), "deadzone must rescale the surviving analog range")
	_expect(model.movement_tier(0.2, 0.25, 0.65, 0.9) == model.TIER_IDLE, "low input must idle")
	_expect(model.movement_tier(0.4, 0.25, 0.65, 0.9) == model.TIER_SHORT, "0.4 must select Short")
	_expect(model.movement_tier(0.7, 0.25, 0.65, 0.9) == model.TIER_MEDIUM, "0.7 must select Medium")
	_expect(model.movement_tier(0.95, 0.25, 0.65, 0.9) == model.TIER_LONG, "0.95 must select Long")


func _test_combat_basis_and_velocity() -> void:
	var basis: Dictionary = model.combat_basis(Vector3.ZERO, Vector3(0.0, 0.0, -2.0), Vector3.FORWARD)
	var forward: Vector3 = basis.forward
	var right: Vector3 = basis.right
	_expect(_near(forward.length(), 1.0) and _near(right.length(), 1.0), "combat basis vectors must be normalized")
	_expect(_near(forward.dot(right), 0.0), "combat basis vectors must be perpendicular")
	_expect(right.x > 0.999, "an opponent on -Z must make positive X the fighter's right side")
	var advance: Vector3 = model.relative_velocity(Vector2(0.0, 1.0), forward, right, 2.4, 1.8, 2.0)
	var retreat: Vector3 = model.relative_velocity(Vector2(0.0, -1.0), forward, right, 2.4, 1.8, 2.0)
	var lateral: Vector3 = model.relative_velocity(Vector2(1.0, 0.0), forward, right, 2.4, 1.8, 2.0)
	var diagonal: Vector3 = model.relative_velocity(Vector2(1.0, 1.0), forward, right, 2.4, 1.8, 2.0)
	_expect(_near(advance.length(), 2.4) and advance.dot(forward) > 0.0, "advance must use forward speed")
	_expect(_near(retreat.length(), 1.8) and retreat.dot(forward) < 0.0, "retreat must use backward speed")
	_expect(_near(lateral.length(), 2.0) and lateral.dot(right) > 0.0, "side movement must use lateral speed")
	_expect(diagonal.dot(forward) > 0.0 and diagonal.dot(right) > 0.0 and diagonal.length() <= 2.401, "diagonal must combine directions without a speed boost")


func _test_separation() -> void:
	var damped: Dictionary = model.separation_velocity(Vector3(-2.0, 0.0, 1.0), Vector3(0.85, 0.0, 0.0), Vector3.RIGHT, 1.0, 0.7, 6.0, 0.8)
	_expect(damped.velocity.x > -2.0, "soft separation must damp inward velocity")
	_expect(_near(damped.velocity.z, 1.0), "soft separation must preserve tangential velocity")
	var outward: Dictionary = model.separation_velocity(Vector3(1.0, 0.0, 0.0), Vector3(0.85, 0.0, 0.0), Vector3.RIGHT, 1.0, 0.7, 6.0, 0.8)
	_expect(_near(outward.velocity.x, 1.0), "separation must preserve outward velocity")
	var hard: Dictionary = model.separation_velocity(Vector3.ZERO, Vector3(0.2, 0.0, 0.0), Vector3.RIGHT, 1.0, 0.7, 6.0, 0.8)
	_expect(hard.correction.length() > 0.0 and hard.correction.length() <= 0.801, "hard correction must be positive and capped")
	var coincident_a: Dictionary = model.separation_velocity(Vector3.ZERO, Vector3.ZERO, Vector3.FORWARD, 1.0, 0.7, 6.0, 0.8)
	var coincident_b: Dictionary = model.separation_velocity(Vector3.ZERO, Vector3.ZERO, Vector3.FORWARD, 1.0, 0.7, 6.0, 0.8)
	_expect(coincident_a.correction == coincident_b.correction and coincident_a.correction.dot(Vector3.FORWARD) > 0.0, "coincident separation must use a stable fallback")


func _test_long_step_latch() -> void:
	var first: Dictionary = model.update_long_step_latch(0.95, true, 0.0, 0.9, 0.55)
	_expect(first.triggered and not first.armed, "entering Long while armed must trigger once")
	var held: Dictionary = model.update_long_step_latch(1.0, first.armed, 0.0, 0.9, 0.55)
	_expect(not held.triggered and not held.armed, "held Long input must not retrigger")
	var released: Dictionary = model.update_long_step_latch(0.3, held.armed, 0.0, 0.9, 0.55)
	_expect(released.armed and not released.triggered, "release below re-arm threshold must arm Long again")
	var cooling: Dictionary = model.update_long_step_latch(0.95, true, 0.2, 0.9, 0.55)
	_expect(not cooling.triggered, "cooldown must suppress a Long trigger")
