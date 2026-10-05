class_name FightSim
extends RefCounted

const INPUT_JAB := 1
const INPUT_CROSS := 2
const INPUT_LEFT_HOOK := 4
const INPUT_FORWARD := 64
const INPUT_BACK := 128
const INPUT_LEFT := 256
const INPUT_RIGHT := 512
const TICK_HZ := 60

var frame := 0
var telemetry_seed := 0
var rng := RandomNumberGenerator.new()
var fighters: Array[Dictionary] = []


func _init(seed_value := 1) -> void:
	telemetry_seed = seed_value
	rng.seed = seed_value
	fighters = [_fresh_fighter(-0.6), _fresh_fighter(0.6)]


func step(inputs: PackedInt32Array) -> void:
	frame += 1
	for index in range(fighters.size()):
		var fighter: Dictionary = fighters[index]
		if int(fighter.hitstop) > 0:
			fighter.hitstop = int(fighter.hitstop) - 1
			fighters[index] = fighter
			continue
		var bits := int(inputs[index]) if index < inputs.size() else 0
		_advance_fighter(fighter, bits, index)
		fighters[index] = fighter
	_resolve_hits()


func apply_hitstop(fighter_index: int, frames: int) -> void:
	if fighter_index < 0 or fighter_index >= fighters.size():
		return
	var fighter: Dictionary = fighters[fighter_index]
	fighter.hitstop = maxi(int(fighter.get("hitstop", 0)), frames)
	fighters[fighter_index] = fighter


func fighter_snapshot(fighter_index: int) -> Dictionary:
	if fighter_index < 0 or fighter_index >= fighters.size():
		return {}
	return fighters[fighter_index].duplicate(true)


func snapshot_hash() -> int:
	return hash(JSON.stringify({
		"frame": frame,
		"seed": telemetry_seed,
		"fighters": fighters,
	}))


func run_ai_fight(seed_value: int, max_frames := 3600) -> Dictionary:
	var script := load("res://scripts/sim/fight_sim.gd") as Script
	var sim: RefCounted = script.new(seed_value)
	for _i in range(max_frames):
		var inputs: PackedInt32Array = sim.call("_ai_inputs")
		sim.step(inputs)
		if float(sim.fighters[0].stability) <= 0.0 or float(sim.fighters[1].stability) <= 0.0:
			break
	var method := "KO" if float(sim.fighters[0].stability) <= 0.0 or float(sim.fighters[1].stability) <= 0.0 else "DECISION"
	return {
		"frames": sim.frame,
		"method": method,
		"hash": sim.snapshot_hash(),
		"p1": sim.fighter_snapshot(0),
		"p2": sim.fighter_snapshot(1),
	}


static func run_ai_fight_hash(seed_value: int, max_frames := 3600) -> int:
	var script := load("res://scripts/sim/fight_sim.gd") as Script
	var sim: RefCounted = script.new(seed_value)
	var result: Dictionary = sim.call("run_ai_fight", seed_value, max_frames)
	return int(result.hash)


func _fresh_fighter(x: float) -> Dictionary:
	return {
		"phase": "IDLE",
		"phase_frame": 0,
		"stamina": 100.0,
		"stability": 100.0,
		"guard": 100.0,
		"x": x,
		"z": 0.0,
		"yaw": 0.0,
		"hitstop": 0,
		"active_hit_done": false,
		"attack": "",
	}


func _advance_fighter(fighter: Dictionary, bits: int, fighter_index: int) -> void:
	_apply_movement(fighter, bits, fighter_index)
	var requested_attack := _attack_for_bits(bits)
	if requested_attack != "" and str(fighter.phase) == "IDLE":
		fighter.phase = "STARTUP"
		fighter.phase_frame = 0
		fighter.attack = requested_attack
		fighter.stamina = maxf(0.0, float(fighter.stamina) - _stamina_cost(requested_attack))
		fighter.active_hit_done = false
		return
	if str(fighter.phase) == "IDLE":
		return
	fighter.phase_frame = int(fighter.phase_frame) + 1
	if str(fighter.phase) == "STARTUP" and int(fighter.phase_frame) >= 3:
		fighter.phase = "ACTIVE"
		fighter.phase_frame = 0
	elif str(fighter.phase) == "ACTIVE" and int(fighter.phase_frame) >= 2:
		fighter.phase = "RECOVERY"
		fighter.phase_frame = 0
	elif str(fighter.phase) == "RECOVERY" and int(fighter.phase_frame) >= 5:
		fighter.phase = "IDLE"
		fighter.phase_frame = 0
		fighter.attack = ""


func _apply_movement(fighter: Dictionary, bits: int, fighter_index: int) -> void:
	var dir := Vector2.ZERO
	if bits & INPUT_FORWARD != 0:
		dir.x += 1.0 if fighter_index == 0 else -1.0
	if bits & INPUT_BACK != 0:
		dir.x -= 1.0 if fighter_index == 0 else -1.0
	if bits & INPUT_LEFT != 0:
		dir.y -= 1.0
	if bits & INPUT_RIGHT != 0:
		dir.y += 1.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	var stamina_scale := clampf(float(fighter.stamina) / 100.0, 0.45, 1.0)
	var speed := 0.028 * stamina_scale
	fighter.x = float(fighter.x) + dir.x * speed
	fighter.z = float(fighter.z) + dir.y * speed
	fighter.x = clampf(float(fighter.x), -3.2, 3.2)
	fighter.z = clampf(float(fighter.z), -3.2, 3.2)
	if dir.length_squared() > 0.0:
		fighter.stamina = maxf(0.0, float(fighter.stamina) - 0.025)


func _attack_for_bits(bits: int) -> String:
	if bits & INPUT_JAB != 0:
		return "jab"
	if bits & INPUT_CROSS != 0:
		return "cross"
	if bits & INPUT_LEFT_HOOK != 0:
		return "left_hook"
	return ""


func _stamina_cost(attack: String) -> float:
	match attack:
		"cross":
			return 5.0
		"left_hook":
			return 6.0
	return 3.0


func _resolve_hits() -> void:
	for attacker_index in range(fighters.size()):
		var defender_index := 1 - attacker_index
		if defender_index < 0 or defender_index >= fighters.size():
			continue
		var attacker: Dictionary = fighters[attacker_index]
		var defender: Dictionary = fighters[defender_index]
		if str(attacker.phase) != "ACTIVE" or bool(attacker.active_hit_done):
			continue
		var distance := absf(float(attacker.x) - float(defender.x))
		if distance <= 1.25:
			defender.stability = maxf(0.0, float(defender.stability) - _stability_damage(str(attacker.attack)))
			defender.hitstop = max(0, int(defender.hitstop), 2)
			attacker.hitstop = max(0, int(attacker.hitstop), 1)
		attacker.active_hit_done = true
		fighters[attacker_index] = attacker
		fighters[defender_index] = defender


func _stability_damage(attack: String) -> float:
	match attack:
		"cross":
			return 5.8
		"left_hook":
			return 7.2
	return 4.0


func _ai_inputs() -> PackedInt32Array:
	var bits := PackedInt32Array([0, 0])
	for index in range(2):
		var fighter: Dictionary = fighters[index]
		var other: Dictionary = fighters[1 - index]
		var input := 0
		var distance := absf(float(fighter.x) - float(other.x))
		if distance > 1.05:
			input |= INPUT_FORWARD
		elif distance < 0.72:
			input |= INPUT_BACK
		var roll := rng.randi_range(0, 99)
		if str(fighter.phase) == "IDLE" and distance <= 1.24 and float(fighter.stamina) > 8.0:
			if roll < 38:
				input |= INPUT_JAB
			elif roll < 61:
				input |= INPUT_CROSS
			elif roll < 72:
				input |= INPUT_LEFT_HOOK
		if rng.randi_range(0, 99) < 18:
			input |= INPUT_LEFT if rng.randi_range(0, 1) == 0 else INPUT_RIGHT
		bits[index] = input
	return bits
