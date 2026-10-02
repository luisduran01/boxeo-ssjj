extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("MENU_VISUAL: " + message)


func _run() -> void:
	var theme_script := load("res://scripts/ui/boxing_theme.gd")
	var components_script := load("res://scripts/ui/menu_components.gd")
	_expect(theme_script != null, "boxing_theme.gd must load")
	_expect(components_script != null, "menu_components.gd must load")
	if theme_script != null and components_script != null:
		_test_theme(theme_script)
		_test_components(components_script)
	if failures == 0:
		print("MENU VISUAL SYSTEM TESTS PASSED")
		quit(0)
	else:
		push_error("MENU VISUAL SYSTEM TESTS FAILED: %d" % failures)
		quit(1)


func _test_theme(theme_script: Script) -> void:
	var colors: Dictionary = theme_script.palette()
	_expect(colors.background == Color("07090d"), "background color must match the design")
	_expect(colors.panel == Color("0b0d12e6"), "panel color must match the design")
	_expect(colors.panel_secondary == Color("101319"), "secondary panel must match the design")
	_expect(colors.gold == Color("c6a34a"), "gold color must match the design")
	_expect(colors.bright_gold == Color("e5cb78"), "bright gold must match the design")
	_expect(colors.white == Color("f4f4f4"), "white color must match the design")
	_expect(colors.gray_text == Color("a9adb5"), "gray text must match the design")
	var theme: Theme = theme_script.create()
	var styles: Array[StyleBox] = []
	for state in [&"normal", &"hover", &"focus", &"pressed", &"disabled"]:
		var style := theme.get_stylebox(state, &"Button")
		_expect(style != null, "Button %s style must exist" % state)
		styles.append(style)
	for index in range(styles.size()):
		for other in range(index + 1, styles.size()):
			_expect(styles[index] != styles[other], "Button states must use distinct style resources")


func _test_components(components_script: Script) -> void:
	var root := Control.new()
	get_root().add_child(root)
	var screen: Dictionary = components_script.create_screen(root, null, "BOXEO SSSJ")
	_expect(root.anchor_right == 1.0 and root.anchor_bottom == 1.0, "screen root must fill its viewport")
	_expect(screen.has("content") and screen.content is MarginContainer, "screen must expose a content margin")
	_expect(screen.has("title") and screen.title is Label, "screen must expose a title label")
	var button: Button = components_script.action_button("QUICK FIGHT", 1)
	_expect(button.custom_minimum_size.y >= 48.0, "action button must be at least 48 px tall")
	_expect(button.text.contains("01") and button.text.contains("QUICK FIGHT"), "numbered action button must include its index")
	_expect(components_script.panel("TEST") is VBoxContainer, "panel builder must return VBoxContainer")
	_expect(components_script.stat_bar("POWER", 75.0) is Control, "stat builder must return Control")
	var option_values: Array[String] = ["3", "6", "12"]
	var options: OptionButton = components_script.option_row("ROUNDS", option_values)
	_expect(options.item_count == 3, "option row must populate all values")
	var toggle: CheckButton = components_script.toggle_row("HUD", true)
	_expect(toggle.button_pressed, "toggle row must preserve its initial value")
	var slider: HSlider = components_script.slider_row("MUSIC", 0.7, 0.0, 1.0, 0.05)
	_expect(is_equal_approx(slider.value, 0.7) and is_equal_approx(slider.step, 0.05), "slider row must preserve value and step")
	root.queue_free()
