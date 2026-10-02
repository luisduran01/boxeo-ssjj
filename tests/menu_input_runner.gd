extends SceneTree

const SCENES := [
	"res://scenes/menus/main_menu.tscn",
	"res://scenes/menus/fighter_select.tscn",
	"res://scenes/menus/career.tscn",
	"res://scenes/menus/settings.tscn",
]

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("MENU_INPUT: " + message)

func _run() -> void:
	var component_script := load("res://scripts/ui/menu_components.gd") as Script
	var methods: Array[StringName] = []
	for method in component_script.get_script_method_list():
		methods.append(StringName(str(method.name)))
	_expect(&"animate_screen_in" in methods, "MenuComponents must expose animate_screen_in")
	_expect(&"bind_focus_feedback" in methods, "MenuComponents must expose bind_focus_feedback")
	_expect(&"play_ui_cue" in methods, "MenuComponents must expose play_ui_cue")
	for scene_path in SCENES:
		await _check_scene(scene_path)
	if failures == 0:
		print("MENU INPUT TESTS PASSED")
		quit(0)
	else:
		push_error("MENU INPUT TESTS FAILED: %d" % failures)
		quit(1)

func _check_scene(scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	_expect(packed != null, "%s must load" % scene_path)
	if packed == null:
		return
	var screen := packed.instantiate() as Control
	get_root().add_child(screen)
	await process_frame
	await process_frame
	_expect(get_root().gui_get_focus_owner() != null, "%s must set initial keyboard focus" % scene_path)
	var controls: Array[Control] = []
	_collect_focusables(screen, controls)
	_expect(not controls.is_empty(), "%s must expose focusable controls" % scene_path)
	for control in controls:
		_expect(control.focus_mode != Control.FOCUS_NONE, "%s focusable %s must keep native focus" % [scene_path, control.name])
	var before := get_root().gui_get_focus_owner()
	_send_action(&"ui_down")
	await process_frame
	_expect(get_root().gui_get_focus_owner() != null, "%s ui_down must keep focus alive" % scene_path)
	if before == get_root().gui_get_focus_owner():
		_send_action(&"ui_right")
		await process_frame
		_expect(get_root().gui_get_focus_owner() != null, "%s ui_right must keep focus alive" % scene_path)
	var confirm := screen.find_child("ConfirmButton", true, false) as Button
	if confirm != null and confirm.disabled:
		confirm.grab_focus()
		await process_frame
		_expect(get_root().gui_get_focus_owner() != confirm, "%s disabled actions must not receive focus" % scene_path)
	screen.queue_free()
	await process_frame

func _collect_focusables(node: Node, out: Array[Control]) -> void:
	if node is Control:
		var control := node as Control
		if control.focus_mode != Control.FOCUS_NONE and control.is_visible_in_tree():
			out.append(control)
	for child in node.get_children():
		_collect_focusables(child, out)

func _send_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
