extends Node

const BufferScript := preload("res://scripts/input/low_latency_input_buffer.gd")

var ring: RefCounted


func _ready() -> void:
	process_physics_priority = -100
	ring = BufferScript.new()


func _input(event: InputEvent) -> void:
	if ring == null:
		return
	ring.capture_event(event, Engine.get_physics_frames())


func consume_bits_for_frame(physics_frame: int) -> int:
	return 0 if ring == null else ring.consume_bits_for_frame(physics_frame)


func logical_latency_frames(physics_frame: int) -> int:
	return 0 if ring == null else ring.logical_latency_frames(physics_frame)
