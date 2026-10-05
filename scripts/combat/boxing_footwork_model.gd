class_name BoxingFootworkModel
extends RefCounted

enum RangeState {
	OUTSIDE,
	LONG_RANGE,
	MID_RANGE,
	POCKET,
	TOO_CLOSE,
}

const TIER_IDLE := 0
const TIER_SHORT := 1
const TIER_MEDIUM := 2
const TIER_LONG := 3


static func classify_range(
	distance: float,
	long_threshold: float,
	mid_threshold: float,
	pocket_threshold: float,
	too_close_threshold: float
) -> RangeState:
	var thresholds := [long_threshold, mid_threshold, pocket_threshold, too_close_threshold]
	thresholds.sort()
	var outside_boundary: float = float(thresholds[3])
	var long_boundary: float = float(thresholds[2])
	var mid_boundary: float = float(thresholds[1])
	var pocket_boundary: float = float(thresholds[0])
	if distance > outside_boundary:
		return RangeState.OUTSIDE
	if distance > long_boundary:
		return RangeState.LONG_RANGE
	if distance > mid_boundary:
		return RangeState.MID_RANGE
	if distance > pocket_boundary:
		return RangeState.POCKET
	return RangeState.TOO_CLOSE


static func apply_radial_deadzone(raw_input: Vector2, deadzone: float) -> Vector2:
	var magnitude := minf(raw_input.length(), 1.0)
	var safe_deadzone := clampf(deadzone, 0.0, 0.99)
	if magnitude <= safe_deadzone:
		return Vector2.ZERO
	var remapped := (magnitude - safe_deadzone) / (1.0 - safe_deadzone)
	return raw_input.normalized() * remapped


static func movement_tier(
	intensity: float,
	short_threshold: float,
	medium_threshold: float,
	long_threshold: float
) -> int:
	var short_start := minf(short_threshold, minf(medium_threshold, long_threshold))
	var long_start := maxf(short_threshold, maxf(medium_threshold, long_threshold))
	var medium_start := short_threshold + medium_threshold + long_threshold - short_start - long_start
	if intensity < short_start:
		return TIER_IDLE
	if intensity < medium_start:
		return TIER_SHORT
	if intensity < long_start:
		return TIER_MEDIUM
	return TIER_LONG


static func combat_basis(
	fighter_position: Vector3,
	opponent_position: Vector3,
	fallback_forward: Vector3
) -> Dictionary:
	var forward := opponent_position - fighter_position
	forward.y = 0.0
	if forward.length_squared() < 0.000001:
		forward = fallback_forward
		forward.y = 0.0
	if forward.length_squared() < 0.000001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	return {"forward": forward, "right": right}


static func relative_velocity(
	input_vector: Vector2,
	forward: Vector3,
	right: Vector3,
	forward_speed: float,
	backward_speed: float,
	lateral_speed: float
) -> Vector3:
	var intent := input_vector.limit_length(1.0)
	var longitudinal_speed := forward_speed if intent.y >= 0.0 else backward_speed
	var velocity := forward * intent.y * longitudinal_speed + right * intent.x * lateral_speed
	var maximum_speed := maxf(longitudinal_speed, lateral_speed)
	return velocity.limit_length(maximum_speed)


static func separation_velocity(
	base_velocity: Vector3,
	offset_from_opponent: Vector3,
	stable_fallback: Vector3,
	minimum_distance: float,
	hard_distance: float,
	strength: float,
	max_correction: float
) -> Dictionary:
	var planar_offset := offset_from_opponent
	planar_offset.y = 0.0
	var distance := planar_offset.length()
	var outward := planar_offset
	if distance < 0.0001:
		outward = stable_fallback
		outward.y = 0.0
	if outward.length_squared() < 0.000001:
		outward = Vector3.RIGHT
	outward = outward.normalized()
	var soft_boundary := maxf(minimum_distance, hard_distance + 0.001)
	var hard_boundary := minf(hard_distance, soft_boundary - 0.001)
	var result := Vector3(base_velocity.x, 0.0, base_velocity.z)
	if distance < soft_boundary:
		var inward_speed := minf(result.dot(outward), 0.0)
		var damping := clampf((soft_boundary - distance) / (soft_boundary - hard_boundary), 0.0, 1.0)
		result -= outward * inward_speed * damping
	var correction := Vector3.ZERO
	if distance < hard_boundary:
		correction = outward * minf((hard_boundary - distance) * maxf(strength, 0.0), maxf(max_correction, 0.0))
		result += correction
	return {"velocity": result, "correction": correction}


static func update_long_step_latch(
	intensity: float,
	armed: bool,
	cooldown: float,
	long_threshold: float,
	rearm_threshold: float
) -> Dictionary:
	var next_armed := armed
	if intensity <= rearm_threshold:
		next_armed = true
	var triggered := intensity >= long_threshold and next_armed and cooldown <= 0.0
	if triggered:
		next_armed = false
	return {"triggered": triggered, "armed": next_armed}
