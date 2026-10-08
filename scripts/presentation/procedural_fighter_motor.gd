class_name ProceduralFighterMotor
extends RefCounted

const FPS := 60.0
const BoneOwnershipConfigScript := preload("res://scripts/presentation/bone_ownership_config.gd")

var ownership = BoneOwnershipConfigScript.new()
var procedural_strength := 0.0
var head_reaction := Vector3.ZERO
var head_velocity := Vector3.ZERO
var neck_reaction := Vector3.ZERO
var neck_velocity := Vector3.ZERO
var core_reaction := Vector3.ZERO
var core_velocity := Vector3.ZERO
var last_targets := {}
var last_curve: Array = []
var last_impact_vector := Vector3.ZERO


func tick(view, move: Dictionary, delta: float) -> Dictionary:
	procedural_strength = clampf(float(move.get("procedural_strength", 0.0)), 0.0, 1.0)
	var targets := _neutral_targets(view)
	if procedural_strength > 0.0 and str(view.move_id) == "jab":
		targets = _jab_targets(view, move)
	_apply_defensive_targets(targets, view)
	_integrate_reaction(delta)
	targets.head_reaction = head_reaction
	targets.neck_reaction = neck_reaction
	targets.core_reaction = core_reaction
	targets.procedural_strength = procedural_strength
	targets.has_nan = _targets_have_nan(targets)
	last_targets = targets
	return targets


func add_impact(event) -> void:
	var side := 1.0
	if event.hit_point.x < 0.0:
		side = -1.0
	var lateral: Vector3 = event.punch_dir.cross(Vector3.UP).normalized()
	if lateral.length_squared() < 0.0001:
		lateral = Vector3.RIGHT * side
	var impulse: Vector3 = (event.punch_dir * 0.55 + lateral * 0.45).normalized() * lerpf(0.04, 0.18, event.power_norm)
	if event.move_id == &"jab":
		impulse *= 0.72
	if event.blocked:
		impulse *= 0.25
	head_velocity += Vector3(-impulse.z, impulse.x, -impulse.x)
	neck_velocity += Vector3(-impulse.z, impulse.x, -impulse.x) * 0.55
	core_velocity += Vector3(-impulse.z, impulse.x, 0.0) * (0.16 if event.blocked else 0.28)
	last_impact_vector = impulse


func has_valid_ownership() -> bool:
	return ownership.validate_unique_owners().is_empty()


func _neutral_targets(view) -> Dictionary:
	var right: Vector3 = view.facing.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	var head: Vector3 = view.pos + Vector3(0.0, 1.52, 0.0)
	var guard_left: Vector3 = head - right * 0.16 + view.facing * 0.24 + Vector3(0.0, -0.12, 0.0)
	var guard_right: Vector3 = head + right * 0.16 + view.facing * 0.18 + Vector3(0.0, -0.13, 0.0)
	return {
		"head": head,
		"neck": head + Vector3(0.0, -0.16, 0.0),
		"torso": view.pos + Vector3(0.0, 1.08, 0.0),
		"pelvis": view.pos + Vector3(0.0, 0.86, 0.0),
		"com": view.pos + Vector3(0.0, 0.92, 0.0),
		"left_hand": guard_left,
		"right_hand": guard_right,
		"left_guard": guard_left,
		"right_guard": guard_right,
		"left_foot": view.pos - right * 0.18 + view.facing * 0.22,
		"right_foot": view.pos + right * 0.18 - view.facing * 0.18,
		"active": str(view.phase) == "ACTIVE",
		"move_frame": view.move_frame,
	}


func _jab_targets(view, move: Dictionary) -> Dictionary:
	var targets := _neutral_targets(view)
	var startup_frames := maxf(float(move.get("startup_frames", 4.0)), 1.0)
	var active_frames := maxf(float(move.get("active_frames", 2.0)), 1.0)
	var recovery_frames := maxf(float(move.get("recovery_frames", 10.0)), 1.0)
	var frame := float(view.move_frame)
	var right: Vector3 = view.facing.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	var guard: Vector3 = targets.left_guard
	var target := _impact_target(view, move)
	var t_out := clampf(frame / startup_frames, 0.0, 1.0)
	var t_back := 0.0
	if str(view.phase) == "RECOVERY":
		t_back = clampf(frame / recovery_frames, 0.0, 1.0)
	elif str(view.phase) == "ACTIVE":
		t_back = clampf(frame / maxf(active_frames + recovery_frames, 1.0), 0.0, 0.15)
	var outbound := _bezier3(guard, guard + view.facing * 0.28 + Vector3(0.0, 0.03, 0.0), target - view.facing * 0.10, target, _ease_out_quad(t_out))
	var retract := _bezier3(target, target - view.facing * 0.20 + Vector3(0.0, 0.02, 0.0), guard + view.facing * 0.12, guard, _ease_in_out(t_back))
	var hand := outbound if t_back <= 0.0 else retract
	targets.left_hand = guard.lerp(hand, procedural_strength)
	targets.right_hand = targets.right_guard + view.facing * 0.03 + Vector3(0.0, 0.03, 0.0)
	targets.torso = targets.torso + right * deg_to_rad(6.0) * procedural_strength
	targets.pelvis = targets.pelvis + view.facing * float(move.get("step_in", 0.10)) * 0.22 * procedural_strength
	targets.com = targets.com + view.facing * float(move.get("step_in", 0.10)) * 0.28 * procedural_strength
	targets.left_shoulder = targets.left_hand - view.facing * 0.34 + Vector3(0.0, 0.05, 0.0)
	targets.chin_protected = targets.right_hand.distance_to(targets.head) < 0.42
	targets.contact_frame_error = absf(frame - startup_frames) if str(view.phase) == "ACTIVE" else 999.0
	targets.impact_target = target
	last_curve = _sample_curve(guard, target, view)
	return targets


func _attack_targets(view, move: Dictionary) -> Dictionary:
	var targets := _neutral_targets(view)
	var attack_type := str(move.get("attack_type", "straight"))
	var hand := str(move.get("hand", "left"))
	var right: Vector3 = view.facing.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	var guard: Vector3 = targets.right_guard if hand == "right" else targets.left_guard
	var target := _impact_target(view, move)
	var startup := maxf(float(move.get("startup_frames", 6.0)), 1.0)
	var active := maxf(float(move.get("active_frames", 5.0)), 1.0)
	var recovery := maxf(float(move.get("recovery_frames", 14.0)), 1.0)
	var frame := float(view.move_frame)
	var phase := str(view.phase)
	var progress := clampf(frame / startup, 0.0, 1.0)
	if phase == "ACTIVE":
		progress = 1.0
	elif phase == "RECOVERY":
		progress = 1.0 - clampf(frame / recovery, 0.0, 1.0)
	var destination := target
	if attack_type == "hook":
		destination = target + right * (-0.16 if hand == "left" else 0.16) + Vector3(0.0, 0.02, 0.0)
	elif attack_type == "uppercut":
		destination = target + Vector3(0.0, -0.12, 0.0)
	elif str(move.get("target_level", "head")) == "body":
		destination = view.opp_body_pos
	var control := guard.lerp(destination, _ease_out_quad(progress))
	if attack_type == "hook":
		control += right * (0.18 if hand == "left" else -0.18) * sin(progress * PI)
	if attack_type == "uppercut":
		control.y += 0.18 * sin(progress * PI)
	var key := "right_hand" if hand == "right" else "left_hand"
	targets[key] = control
	targets.left_shoulder = targets.left_guard.lerp(targets[key], 0.35)
	targets.right_shoulder = targets.right_guard.lerp(targets[key], 0.35)
	targets.torso += right * (0.08 if attack_type == "hook" else 0.035) * sin(progress * PI)
	targets.pelvis += view.facing * float(move.get("step_in", 0.0)) * 0.18 * sin(progress * PI)
	targets.com += view.facing * float(move.get("step_in", 0.0)) * 0.22 * sin(progress * PI)
	targets.contact_frame_error = 0.0 if phase == "ACTIVE" else 999.0
	targets.impact_target = target
	return targets


func _impact_target(view, move: Dictionary) -> Vector3:
	var base: Vector3 = view.opp_body_pos if str(move.get("target_level", "head")) == "body" else view.opp_head_pos
	var distance: float = view.pos.distance_to(base)
	var max_range := maxf(float(move.get("range", move.get("max_range", 1.5))), 0.1)
	var extension := clampf(distance / max_range, 0.72, 1.0)
	return view.pos + (base - view.pos).normalized() * minf(distance, max_range * extension)


func _integrate_reaction(delta: float) -> void:
	head_reaction = _spring_step(head_reaction, head_velocity, delta, 180.0, 16.0, "Head")
	head_velocity = _spring_velocity(head_reaction, head_velocity, delta, 180.0, 16.0)
	neck_reaction = _spring_step(neck_reaction, neck_velocity, delta, 140.0, 15.0, "Neck")
	neck_velocity = _spring_velocity(neck_reaction, neck_velocity, delta, 140.0, 15.0)
	core_reaction = _spring_step(core_reaction, core_velocity, delta, 95.0, 13.0, "Spine")
	core_velocity = _spring_velocity(core_reaction, core_velocity, delta, 95.0, 13.0)


func _apply_defensive_targets(targets: Dictionary, view) -> void:
	var action := str(view.defense_action)
	var right: Vector3 = view.facing.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	if action == "slip_left" or action == "slip_right":
		var side := -1.0 if action == "slip_left" else 1.0
		var shift := right * side * 0.16
		targets.head += shift + Vector3(0.0, 0.025, 0.0)
		targets.neck += shift * 0.78
		targets.torso += shift * 0.52
		targets.pelvis += shift * 0.16
		targets.com += shift * 0.20
	elif action == "duck":
		targets.head += Vector3(0.0, -0.20, 0.0)
		targets.neck += Vector3(0.0, -0.14, 0.0)
		targets.torso += Vector3(0.0, -0.08, 0.0)
		targets.pelvis += Vector3(0.0, -0.035, 0.0)
		targets.com += Vector3(0.0, -0.045, 0.0)
	if str(view.guard_state) == "body":
		targets.left_guard += Vector3(0.0, -0.16, 0.0)
		targets.right_guard += Vector3(0.0, -0.16, 0.0)
		targets.left_hand = targets.left_guard
		targets.right_hand = targets.right_guard
	targets.head_reaction = targets.get("head_reaction", Vector3.ZERO)


func _spring_step(value: Vector3, velocity: Vector3, delta: float, k: float, c: float, bone_name: String) -> Vector3:
	var accel := -k * value - c * velocity
	var next_velocity := velocity + accel * delta
	var next := value + next_velocity * delta
	return ownership.clamp_euler(bone_name, next)


func _spring_velocity(value: Vector3, velocity: Vector3, delta: float, k: float, c: float) -> Vector3:
	return velocity + (-k * value - c * velocity) * delta


static func _bezier3(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t


func _sample_curve(guard: Vector3, target: Vector3, view) -> Array:
	var points: Array = []
	for i in range(7):
		var t := float(i) / 6.0
		points.append(_bezier3(guard, guard + view.facing * 0.28, target - view.facing * 0.10, target, t))
	return points


static func _ease_out_quad(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


static func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _targets_have_nan(targets: Dictionary) -> bool:
	for value in targets.values():
		if value is Vector3:
			var v: Vector3 = value
			if is_nan(v.x) or is_nan(v.y) or is_nan(v.z):
				return true
	return false
