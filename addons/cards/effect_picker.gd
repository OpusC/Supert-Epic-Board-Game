@tool
extends PopupPanel

signal effect_selected(kind: int)

const EFFECTS := {
	EffectStep.Kind.MELEE: ["Melee Damage", "Deal the specified base melee damage to an adjacent enemy.", true],
	EffectStep.Kind.REPOSITION: ["Reposition", "Move the hero to an empty hero cell.", false],
	EffectStep.Kind.GAIN_MOMENTUM: ["Gain Momentum", "Add the specified amount of Momentum, up to the cap.", true],
	EffectStep.Kind.RESTORE_MOMENTUM: ["Restore Momentum", "Refund the Momentum spent by this card’s preceding melee hit.", false],
}

var _search := LineEdit.new()
var _rows := VBoxContainer.new()
var _buttons: Array[Button] = []
var _anchor: Button


func _ready() -> void:
	var padding := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 8)
	add_child(padding)
	var layout := VBoxContainer.new()
	padding.add_child(layout)
	_search.placeholder_text = "Search effects"
	_search.clear_button_enabled = true
	_search.text_changed.connect(_filter)
	_search.gui_input.connect(_search_input)
	_search.text_submitted.connect(func(_query: String) -> void:
		if not _buttons.is_empty():
			_buttons[0].pressed.emit()
	)
	layout.add_child(_search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	layout.add_child(scroll)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	popup_hide.connect(func() -> void:
		if is_instance_valid(_anchor) and _anchor.is_visible_in_tree():
			_anchor.grab_focus()
	)


func open(anchor: Button) -> void:
	_anchor = anchor
	_search.clear()
	_filter("")
	var bounds := anchor.get_viewport_rect().size
	var anchor_rect := anchor.get_global_rect()
	var popup_size := Vector2(450, 265).min(bounds)
	var origin := Vector2(anchor_rect.position.x, anchor_rect.end.y)
	if origin.y + popup_size.y > bounds.y:
		origin.y = anchor_rect.position.y - popup_size.y
	origin = origin.clamp(Vector2.ZERO, bounds - popup_size)
	popup_on_parent(Rect2i(Vector2i(origin), Vector2i(popup_size)))
	_search.grab_focus()


func _filter(query: String) -> void:
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	_buttons.clear()
	var needle := query.strip_edges().to_lower()
	for kind: int in EFFECTS:
		var effect: Array = EFFECTS[kind]
		var searchable_text := ("%s %s" % [effect[0], effect[1]]).to_lower()
		if not needle.is_empty() and not searchable_text.contains(needle):
			continue
		var button := Button.new()
		button.text = "%s\n%s" % [effect[0], effect[1]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 54
		button.pressed.connect(_choose.bind(kind))
		button.gui_input.connect(_row_input.bind(button))
		_rows.add_child(button)
		_buttons.append(button)
	if _buttons.is_empty():
		var empty := Label.new()
		empty.text = "No matching effects."
		_rows.add_child(empty)


func _search_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down") and not _buttons.is_empty():
		_search.accept_event()
		_buttons[0].grab_focus()


func _row_input(event: InputEvent, button: Button) -> void:
	var index := _buttons.find(button)
	if event.is_action_pressed("ui_up"):
		button.accept_event()
		if index == 0:
			_search.grab_focus()
		else:
			_buttons[index - 1].grab_focus()
	elif event.is_action_pressed("ui_down"):
		button.accept_event()
		_buttons[mini(index + 1, _buttons.size() - 1)].grab_focus()


func _choose(kind: int) -> void:
	hide()
	effect_selected.emit(kind)
