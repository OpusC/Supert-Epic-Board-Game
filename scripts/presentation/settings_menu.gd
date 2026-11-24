extends ColorRect

var _resume: Button
var _buttons: Array[Button] = []
var _previous_focus: Control
var _fullscreen_hint: Label = Label.new()
var _windowed_mode: Window.Mode = Window.MODE_WINDOWED


func _ready() -> void:
	# Keep the menu responsive while the encounter and its animations are paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	color = Color(0.04, 0.06, 0.09, 0.8)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()

	var center: CenterContainer = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)
	var options: VBoxContainer = VBoxContainer.new()
	options.custom_minimum_size.x = 220
	options.add_theme_constant_override("separation", 8)
	panel.add_child(options)

	_resume = _add_button(options, "Resume", close)
	_add_button(options, "Exit", get_tree().quit)
	_add_button(options, "Fullscreen", _toggle_fullscreen)
	_set_focus_navigation()
	_fullscreen_hint.custom_minimum_size.x = 260
	_fullscreen_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fullscreen_hint.text = "For fullscreen, turn off Embed Game on Next Play in Godot’s Game tab, then restart the demo."
	_fullscreen_hint.hide()
	options.add_child(_fullscreen_hint)


func _input(event: InputEvent) -> void:
	# Handle Escape once per press, even when the key is held down.
	var key: InputEventKey = event as InputEventKey
	if key == null or key.keycode != KEY_ESCAPE or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	if visible:
		close()
	else:
		open()


func open() -> void:
	_previous_focus = get_viewport().gui_get_focus_owner()
	get_tree().paused = true
	show()
	_resume.grab_focus()


func close() -> void:
	hide()
	get_tree().paused = false
	if is_instance_valid(_previous_focus):
		_previous_focus.grab_focus()


func _add_button(options: VBoxContainer, label: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.custom_minimum_size.y = 40
	button.pressed.connect(action)
	options.add_child(button)
	_buttons.append(button)
	return button


func _set_focus_navigation() -> void:
	# Keep arrow keys and Tab inside the menu while the battle is paused.
	for index: int in _buttons.size():
		var button: Button = _buttons[index]
		var previous: Button = _buttons[posmod(index - 1, _buttons.size())]
		var next: Button = _buttons[(index + 1) % _buttons.size()]
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_bottom = button.get_path_to(next)
		button.focus_neighbor_left = NodePath(".")
		button.focus_neighbor_right = NodePath(".")
		button.focus_previous = button.focus_neighbor_top
		button.focus_next = button.focus_neighbor_bottom


func _toggle_fullscreen() -> void:
	# An editor-embedded run cannot change the desktop window mode.
	if Engine.is_embedded_in_editor():
		_fullscreen_hint.show()
		return

	# Restore the previous mode when leaving fullscreen.
	var window: Window = get_window()
	if window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
		window.mode = _windowed_mode
	else:
		_windowed_mode = window.mode
		window.mode = Window.MODE_FULLSCREEN
