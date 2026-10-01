class_name FightHUD
extends CanvasLayer

signal restart_requested
signal quit_requested
signal settings_requested

const GRAPHITE := Color("11161c")
const GRAPHITE_LIGHT := Color("222a33")
const INK := Color("080b0f")
const TEXT := Color("f1f3f2")
const MUTED := Color("9ca7ae")
const PLAYER_ACCENT := Color("65aebe")
const ENEMY_ACCENT := Color("c6645f")
const STAMINA_NORMAL := Color("d0b56b")
const STAMINA_LOW := Color("b9794f")
const STUN_COLOR := Color("d77955")

var player_health: ProgressBar
var player_health_trail: ProgressBar
var player_stamina: ProgressBar
var player_stun: ProgressBar
var enemy_health: ProgressBar
var enemy_health_trail: ProgressBar
var enemy_stamina: ProgressBar
var enemy_stun: ProgressBar
var player_name_label: Label
var enemy_name_label: Label
var round_label: Label
var timer_label: Label
var banner: Label
var top_bar: HBoxContainer
var clock_card: PanelContainer
var announcement_card: PanelContainer
var player_panel: PanelContainer
var enemy_panel: PanelContainer
var pause_panel: PanelContainer
var result_panel: PanelContainer
var debug_label: Label

var _player: BoxerController
var _enemy: BoxerController
var _root: Control
var _announcement_serial := 0
var _announcement_tween: Tween
var _low_time := false
var _initialized_fighters: Dictionary = {}
var _bar_tweens: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		_toggle_pause()


func setup(player: BoxerController, enemy: BoxerController) -> void:
	_player = player
	_enemy = enemy
	player_name_label.text = player.fighter_name.to_upper()
	enemy_name_label.text = enemy.fighter_name.to_upper()
	player.stats_changed.connect(_on_stats_changed)
	enemy.stats_changed.connect(_on_stats_changed)
	_on_stats_changed(player)
	_on_stats_changed(enemy)


func set_clock(round_number: int, round_time: float) -> void:
	round_label.text = "ROUND %d" % round_number
	var seconds := maxi(0, int(round_time))
	timer_label.text = "%d:%02d" % [seconds / 60, seconds % 60]
	var low_now := round_time <= 10.0 and round_time > 0.0
	if low_now != _low_time:
		_low_time = low_now
		timer_label.add_theme_color_override("font_color", Color("efb06a") if low_now else TEXT)
		var tween := timer_label.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(timer_label, "scale", Vector2(1.06, 1.06) if low_now else Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func announce(text: String, seconds := 1.5) -> void:
	_announcement_serial += 1
	var serial := _announcement_serial
	if _announcement_tween != null and _announcement_tween.is_valid():
		_announcement_tween.kill()
	banner.text = text
	banner.visible = true
	announcement_card.visible = true
	banner.add_theme_font_size_override("font_size", 62 if text.is_valid_int() else (46 if text == "FIGHT!" else 36))
	announcement_card.modulate = Color(1, 1, 1, 0)
	announcement_card.scale = Vector2(0.96, 0.96)
	_announcement_tween = announcement_card.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_announcement_tween.set_parallel(true)
	_announcement_tween.tween_property(announcement_card, "modulate", Color.WHITE, 0.16)
	_announcement_tween.tween_property(announcement_card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(seconds, true).timeout.connect(func():
		if serial != _announcement_serial or not is_instance_valid(announcement_card):
			return
		var fade := announcement_card.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fade.tween_property(announcement_card, "modulate", Color(1, 1, 1, 0), 0.2)
		fade.finished.connect(func():
			if serial == _announcement_serial:
				announcement_card.visible = false
				banner.visible = false
		)
	)


func set_knockdown_mode(active: bool) -> void:
	var tween := top_bar.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(top_bar, "modulate", Color(1, 1, 1, 0.42) if active else Color.WHITE, 0.22)


func show_result(text: String) -> void:
	set_knockdown_mode(false)
	var presentation := text.replace("\nKO\n", "\nKNOCKOUT\n")
	_announcement_serial += 1
	banner.text = presentation
	banner.visible = true
	banner.add_theme_font_size_override("font_size", 36)
	announcement_card.visible = true
	announcement_card.custom_minimum_size = Vector2(590, 184)
	announcement_card.modulate = Color.WHITE
	announcement_card.scale = Vector2.ONE
	result_panel.visible = true
	result_panel.modulate = Color(1, 1, 1, 0)
	var tween := result_panel.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(0.18)
	tween.tween_property(result_panel, "modulate", Color.WHITE, 0.22)


func flash_damage(fighter: BoxerController, damage: float) -> void:
	var panel := player_panel if fighter == _player else enemy_panel
	if panel == null:
		return
	var strength := clampf(damage / 24.0, 0.12, 0.42)
	panel.modulate = Color(1.0 + strength * 0.18, 0.82, 0.82, 1.0)
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate", Color.WHITE, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func set_debug(text: String) -> void:
	debug_label.text = text
	debug_label.visible = SaveSystem.settings.get("debug", false)


func _on_stats_changed(fighter: BoxerController) -> void:
	var is_initial := not _initialized_fighters.has(fighter)
	_initialized_fighters[fighter] = true
	var health := player_health if fighter == _player else enemy_health
	var trail := player_health_trail if fighter == _player else enemy_health_trail
	var stamina := player_stamina if fighter == _player else enemy_stamina
	var stun := player_stun if fighter == _player else enemy_stun
	_update_health_bar(health, trail, float(fighter.stats.health), is_initial)
	_update_smooth_bar(stamina, float(fighter.stats.stamina), 0.18, is_initial)
	_update_smooth_bar(stun, float(fighter.stats.stun), 0.15, is_initial)
	var reversed := fighter == _enemy
	_apply_progress_styles(stamina, Color(0.08, 0.09, 0.1, 0.9), STAMINA_LOW if fighter.stats.stamina < 24.0 else STAMINA_NORMAL, 3, reversed)


func _update_health_bar(main: ProgressBar, trail: ProgressBar, value: float, immediate: bool) -> void:
	_kill_bar_tween(main)
	_kill_bar_tween(trail)
	if immediate or value > main.value:
		main.value = value
		trail.value = value
		return
	var main_tween := main.create_tween()
	_bar_tweens[main] = main_tween
	main_tween.tween_property(main, "value", value, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var trail_tween := trail.create_tween()
	_bar_tweens[trail] = trail_tween
	trail_tween.tween_interval(0.22)
	trail_tween.tween_property(trail, "value", value, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_smooth_bar(bar: ProgressBar, value: float, duration: float, immediate: bool) -> void:
	_kill_bar_tween(bar)
	if immediate:
		bar.value = value
		return
	var tween := bar.create_tween()
	_bar_tweens[bar] = tween
	tween.tween_property(bar, "value", value, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _kill_bar_tween(bar: ProgressBar) -> void:
	var tween: Tween = _bar_tweens.get(bar)
	if tween != null and tween.is_valid():
		tween.kill()
	_bar_tweens.erase(bar)


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "BroadcastHUD"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	top_bar = HBoxContainer.new()
	top_bar.name = "TopSafeArea"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 40
	top_bar.offset_top = 24
	top_bar.offset_right = -40
	top_bar.offset_bottom = 142
	top_bar.add_theme_constant_override("separation", 20)
	_root.add_child(top_bar)

	player_panel = _fighter_panel(false)
	top_bar.add_child(player_panel)
	clock_card = _clock_panel()
	top_bar.add_child(clock_card)
	enemy_panel = _fighter_panel(true)
	top_bar.add_child(enemy_panel)

	announcement_card = PanelContainer.new()
	announcement_card.name = "AnnouncementCard"
	announcement_card.set_anchors_preset(Control.PRESET_CENTER)
	announcement_card.position = Vector2(-295, -88)
	announcement_card.size = Vector2(590, 142)
	announcement_card.pivot_offset = announcement_card.size * 0.5
	announcement_card.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.035, 0.045, 0.94), Color(0.55, 0.61, 0.64, 0.55), 1, 8))
	announcement_card.visible = false
	_root.add_child(announcement_card)
	banner = _label("", 36)
	banner.name = "Announcement"
	banner.visible = false
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	announcement_card.add_child(banner)

	debug_label = _label("", 14)
	debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	debug_label.position = Vector2(40, 156)
	debug_label.size = Vector2(380, 190)
	_root.add_child(debug_label)
	_build_pause(_root)
	_build_result(_root)


func _fighter_panel(reversed: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "EnemyPanel" if reversed else "PlayerPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(390, 112)
	var accent := ENEMY_ACCENT if reversed else PLAYER_ACCENT
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.045, 0.055, 0.91), Color(accent, 0.66), 1, 7))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_bottom", 11)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var corner := _label("RED CORNER" if reversed else "BLUE CORNER", 11)
	corner.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if reversed else HORIZONTAL_ALIGNMENT_RIGHT
	corner.add_theme_color_override("font_color", accent)
	box.add_child(corner)
	var name_label := _label("BOXER 02" if reversed else "BOXER GREEN", 21)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if reversed else HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(name_label)
	if reversed:
		enemy_name_label = name_label
	else:
		player_name_label = name_label

	var health_stack := Control.new()
	health_stack.custom_minimum_size.y = 25
	box.add_child(health_stack)
	var trail := _progress_bar(25, Color("d8c9b4"), reversed, 5)
	var health := _progress_bar(25, accent, reversed, 5)
	health_stack.add_child(trail)
	health_stack.add_child(health)
	trail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var stamina := _progress_bar(7, STAMINA_NORMAL, reversed, 3)
	box.add_child(stamina)
	var stun := _progress_bar(3, STUN_COLOR, reversed, 1)
	stun.value = 0
	box.add_child(stun)
	if reversed:
		enemy_health = health
		enemy_health_trail = trail
		enemy_stamina = stamina
		enemy_stun = stun
	else:
		player_health = health
		player_health_trail = trail
		player_stamina = stamina
		player_stun = stun
	return panel


func _clock_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ClockCard"
	panel.custom_minimum_size = Vector2(166, 112)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.03, 0.036, 0.96), Color(0.72, 0.75, 0.76, 0.65), 1, 7))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", -1)
	panel.add_child(box)
	var event := _label("SSJJ • LIVE", 10)
	event.add_theme_color_override("font_color", MUTED)
	box.add_child(event)
	round_label = _label("ROUND 1", 14)
	round_label.add_theme_color_override("font_color", Color("c6cdd1"))
	box.add_child(round_label)
	timer_label = _label("2:00", 39)
	timer_label.pivot_offset = Vector2(70, 24)
	box.add_child(timer_label)
	return panel


func _progress_bar(height: float, fill_color: Color, reversed: bool, radius: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false
	bar.custom_minimum_size.y = height
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN if reversed else ProgressBar.FILL_BEGIN_TO_END
	_apply_progress_styles(bar, Color(0.06, 0.07, 0.08, 0.92), fill_color, radius, reversed)
	return bar


func _apply_progress_styles(bar: ProgressBar, background: Color, fill: Color, radius: int, _reversed: bool) -> void:
	bar.add_theme_stylebox_override("background", _panel_style(background, Color(0.3, 0.33, 0.35, 0.45), 1, radius))
	bar.add_theme_stylebox_override("fill", _panel_style(fill, Color(fill.lightened(0.18), 0.75), 1, radius))


func _panel_style(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.anti_aliasing = true
	return style


func _build_pause(root: Control) -> void:
	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-170, -190)
	pause_panel.size = Vector2(340, 380)
	pause_panel.visible = false
	pause_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.04, 0.05, 0.97), GRAPHITE_LIGHT, 1, 8))
	root.add_child(pause_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	pause_panel.add_child(box)
	box.add_child(_label("PAUSA", 34))
	for entry in [["CONTINUAR", "resume"], ["SETTINGS", "settings"], ["REINICIAR PELEA", "restart"], ["MAIN MENU", "quit"]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size.y = 52
		button.pressed.connect(_pause_action.bind(entry[1]))
		box.add_child(button)


func _toggle_pause() -> void:
	if banner.visible and (banner.text.contains("GANADOR") or banner.text.contains("WINNER")):
		return
	get_tree().paused = not get_tree().paused
	pause_panel.visible = get_tree().paused


func _pause_action(action: String) -> void:
	get_tree().paused = false
	pause_panel.visible = false
	if action == "restart": restart_requested.emit()
	elif action == "quit": quit_requested.emit()
	elif action == "settings": settings_requested.emit()


func _build_result(root: Control) -> void:
	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.position = Vector2(-190, 92)
	result_panel.size = Vector2(380, 132)
	result_panel.visible = false
	result_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.035, 0.045, 0.94), GRAPHITE_LIGHT, 1, 7))
	root.add_child(result_panel)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	result_panel.add_child(box)
	var rematch := Button.new()
	rematch.text = "REMATCH"
	rematch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rematch.custom_minimum_size.y = 52
	rematch.pressed.connect(func(): restart_requested.emit())
	box.add_child(rematch)
	var menu := Button.new()
	menu.text = "MAIN MENU"
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.custom_minimum_size.y = 52
	menu.pressed.connect(func(): quit_requested.emit())
	box.add_child(menu)


func _label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", TEXT)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label
