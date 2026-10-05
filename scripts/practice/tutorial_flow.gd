class_name TutorialFlow
extends Node

const DummyScript := preload("res://scripts/practice/practice_dummy.gd")

const LESSONS := [
	{"id": "movement_distance", "title": "Movement and distance"},
	{"id": "jab_cross", "title": "Jab and cross"},
	{"id": "hooks_uppercuts", "title": "Hooks and uppercuts"},
	{"id": "defense", "title": "Defense timing"},
	{"id": "counters", "title": "Counters and clinch"},
	{"id": "ring_control", "title": "Ring control"},
]


func lesson_count() -> int:
	return LESSONS.size()


func lesson(index: int) -> Dictionary:
	return LESSONS[clampi(index, 0, LESSONS.size() - 1)].duplicate(true)


func create_lesson_scene(index: int) -> Node:
	var data := lesson(index)
	var scene := Node3D.new()
	scene.name = "Lesson_%s" % str(data.id)
	scene.set_meta("playable", true)
	scene.set_meta("lesson_id", data.id)
	scene.set_meta("title", data.title)
	var dummy: Node = DummyScript.new()
	dummy.name = "PracticeDummy"
	match str(data.id):
		"defense", "counters":
			dummy.configure("counter", {"distance": "POCKET"})
		"ring_control":
			dummy.configure("block", {"distance": "MID_RANGE"})
		_:
			dummy.configure("passive", {"distance": "MID_RANGE"})
	scene.add_child(dummy)
	var frame_data := Label3D.new()
	frame_data.name = "FrameData"
	frame_data.text = "FRAME DATA / BUFFER / DAMAGE / DISTANCE"
	frame_data.position = Vector3(0.0, 1.9, -0.4)
	scene.add_child(frame_data)
	return scene
