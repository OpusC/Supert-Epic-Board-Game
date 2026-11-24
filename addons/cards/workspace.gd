@tool
extends HSplitContainer

const Picker = preload("res://addons/cards/effect_picker.gd")
const CARDS_DIRECTORY := "res://content/cards"

var history: EditorUndoRedoManager
var load_cards: Callable = _discover_cards

var _paths: Array[String] = []
var _sources: Dictionary[String, CardDefinition] = {}
var _drafts: Dictionary[String, CardDefinition] = {}
var _saved: Dictionary[String, Array] = {}
var _path := ""
var _rendered_steps: Array[EffectStep] = []
var _library := ItemList.new()
var _form := VBoxContainer.new()
var _name := LineEdit.new()
var _cost := SpinBox.new()
var _rules := TextEdit.new()
var _steps := VBoxContainer.new()
var _add := Button.new()
var _save := Button.new()
var _status := Label.new()
var _picker := Picker.new()


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 205
	add_child(sidebar)
	_add_label(sidebar, "Cards")
	_library.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_library.item_selected.connect(_select_card)
	sidebar.add_child(_library)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 8)
	scroll.add_child(_form)

	var toolbar := HBoxContainer.new()
	_form.add_child(toolbar)
	_save.text = "Save"
	_save.pressed.connect(_save_card)
	toolbar.add_child(_save)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toolbar.add_child(_status)

	_add_label(_form, "Name")
	_form.add_child(_name)
	_name.text_changed.connect(func(value: String) -> void: _edit_field(&"display_name", value, "Edit Card Name"))
	_add_label(_form, "Discard cost")
	_configure_amount(_cost)
	_form.add_child(_cost)
	_cost.value_changed.connect(func(value: float) -> void: _edit_field(&"cost", int(value), "Edit Discard Cost"))
	_add_label(_form, "Rules text")
	_rules.custom_minimum_size.y = 90
	_rules.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_rules.text_changed.connect(func() -> void: _edit_field(&"rules_text", _rules.text, "Edit Rules Text"))
	_form.add_child(_rules)

	_add_label(_form, "Effects · top to bottom")
	_form.add_child(_steps)
	_add.text = "+ Add effect"
	_add.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_add.pressed.connect(func() -> void: _picker.open(_add))
	_form.add_child(_add)
	add_child(_picker)
	_picker.effect_selected.connect(_add_effect)

	if history != null:
		var global_history := history.get_history_undo_redo(EditorUndoRedoManager.GLOBAL_HISTORY)
		global_history.version_changed.connect(_sync)
	_load_library()
	if _paths.is_empty():
		_form.hide()
		_add_label(sidebar, "No cards found.")
	else:
		_library.select(0)
		_select_card(0)


func _discover_cards() -> Dictionary[String, CardDefinition]:
	var cards: Dictionary[String, CardDefinition] = {}
	for file in ResourceLoader.list_directory(CARDS_DIRECTORY):
		if file.get_extension() != "tres":
			continue
		var path := CARDS_DIRECTORY.path_join(file)
		var card := ResourceLoader.load(path) as CardDefinition
		if card != null:
			cards[path] = card
	return cards


func _load_library() -> void:
	var cards: Dictionary[String, CardDefinition] = load_cards.call()
	for path in cards:
		var card := cards[path]
		var draft := card.duplicate(true) as CardDefinition
		_sources[path] = card
		_drafts[path] = draft
		_saved[path] = _card_values(draft)
		_paths.append(path)
	_paths.sort_custom(func(first: String, second: String) -> bool:
		return _drafts[first].display_name.naturalnocasecmp_to(_drafts[second].display_name) < 0
	)
	for path in _paths:
		_library.add_item(_drafts[path].display_name)


func _select_card(index: int) -> void:
	_path = _paths[index]
	_rebuild_steps()
	_sync()


func _sync() -> void:
	if _path.is_empty():
		return
	for index in _paths.size():
		var path := _paths[index]
		var card := _drafts[path]
		var title := card.display_name if not card.display_name.strip_edges().is_empty() else String(card.id)
		_library.set_item_text(index, title + (" *" if _is_dirty(path) else ""))
	var draft := _drafts[_path]
	_set_text(_name, draft.display_name)
	_cost.set_value_no_signal(draft.cost)
	_set_text(_rules, draft.rules_text)
	if _rendered_steps != draft.steps:
		_rebuild_steps()
	for index in _rendered_steps.size():
		var amount := _steps.get_child(index).get_node_or_null("Amount") as SpinBox
		if amount != null:
			amount.set_value_no_signal(draft.steps[index].amount)
	var dirty := _is_dirty(_path)
	var error := _validate(draft)
	_save.disabled = not dirty or not error.is_empty()
	_status.text = error if not error.is_empty() else ("Unsaved changes" if dirty else "")


func _rebuild_steps() -> void:
	for child in _steps.get_children():
		_steps.remove_child(child)
		child.queue_free()
	_rendered_steps = _drafts[_path].steps.duplicate()
	if _rendered_steps.is_empty():
		_add_label(_steps, "No effects yet.")
	for index in _rendered_steps.size():
		var step := _rendered_steps[index]
		var row := HBoxContainer.new()
		_steps.add_child(row)
		var effect: Array = Picker.EFFECTS.get(step.kind, []) if step != null else []
		var title: String = effect[0] if not effect.is_empty() else "Unsupported effect"
		var name_label := _add_label(row, "%d. %s" % [index + 1, title])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not effect.is_empty() and effect[2]:
			var amount := SpinBox.new()
			amount.name = "Amount"
			_configure_amount(amount)
			amount.set_value_no_signal(step.amount)
			amount.value_changed.connect(_edit_amount.bind(step))
			row.add_child(amount)
		_add_row_button(row, "↑", "Move effect up", index == 0, _move_effect.bind(index, -1))
		_add_row_button(row, "↓", "Move effect down", index == _rendered_steps.size() - 1, _move_effect.bind(index, 1))
		_add_row_button(row, "Remove", "Remove effect", false, _remove_effect.bind(index))


func _add_effect(kind: EffectStep.Kind) -> void:
	var step := EffectStep.new()
	step.kind = kind
	if Picker.EFFECTS[kind][2]:
		step.amount = 1
	var steps: Array[EffectStep] = _drafts[_path].steps.duplicate()
	steps.append(step)
	_edit_field(&"steps", steps, "Add Card Effect", UndoRedo.MERGE_DISABLE)


func _remove_effect(index: int) -> void:
	var steps: Array[EffectStep] = _drafts[_path].steps.duplicate()
	steps.remove_at(index)
	_edit_field(&"steps", steps, "Remove Card Effect", UndoRedo.MERGE_DISABLE)


func _move_effect(index: int, direction: int) -> void:
	var steps: Array[EffectStep] = _drafts[_path].steps.duplicate()
	var step := steps[index]
	steps.remove_at(index)
	steps.insert(index + direction, step)
	_edit_field(&"steps", steps, "Reorder Card Effects", UndoRedo.MERGE_DISABLE)


func _edit_field(field: StringName, value: Variant, action: String, merge := UndoRedo.MERGE_ENDS) -> void:
	var draft := _drafts[_path]
	_edit_property(draft, field, value, action, merge)


func _edit_amount(value: float, step: EffectStep) -> void:
	_edit_property(step, &"amount", int(value), "Edit Effect Amount", UndoRedo.MERGE_DISABLE)


func _edit_property(target: Resource, field: StringName, value: Variant, action: String, merge: UndoRedo.MergeMode) -> void:
	var previous: Variant = target.get(field)
	if previous == value:
		return
	# The file-backed resource puts draft edits in global editor history.
	history.create_action("%s (%s)" % [action, _path.get_file()], merge, _sources[_path], false, false)
	history.force_fixed_history()
	history.add_do_property(target, field, value)
	history.add_undo_property(target, field, previous)
	history.commit_action()
	_sync()


func _save_card() -> void:
	var draft := _drafts[_path]
	var error := _validate(draft)
	if not error.is_empty():
		_status.text = error
		return
	var result := ResourceSaver.save(draft, _path)
	if result != OK:
		_status.text = "Could not save card. %s" % error_string(result)
		return
	_saved[_path] = _card_values(draft)
	ResourceLoader.load(_path, "Resource", ResourceLoader.CACHE_MODE_REPLACE)
	_sync()
	_status.text = "Saved %s." % draft.display_name


func _is_dirty(path: String) -> bool:
	return _card_values(_drafts[path]) != _saved[path]


func _card_values(card: CardDefinition) -> Array:
	var effects: Array = []
	for step in card.steps:
		effects.append([step.kind, step.amount] if step != null else null)
	return [card.display_name, card.cost, card.rules_text, effects]


func _validate(card: CardDefinition) -> String:
	if card.display_name.strip_edges().is_empty():
		return "Enter a card name."
	if card.cost < 0:
		return "Discard cost must be zero or greater."
	var has_melee := false
	for index in card.steps.size():
		var step := card.steps[index]
		if step == null or not Picker.EFFECTS.has(step.kind):
			return "Effect %d is unsupported." % (index + 1)
		if Picker.EFFECTS[step.kind][2] and step.amount < 0:
			return "Effect %d needs a nonnegative amount." % (index + 1)
		if step.kind == EffectStep.Kind.RESTORE_MOMENTUM and not has_melee:
			return "Effect %d needs a preceding Melee Damage effect." % (index + 1)
		if step.kind == EffectStep.Kind.MELEE:
			has_melee = true
	return ""


func _set_text(control: Control, value: String) -> void:
	if control.text != value:
		control.set_block_signals(true)
		control.text = value
		control.set_block_signals(false)


func _configure_amount(input: SpinBox) -> void:
	input.min_value = 0
	input.allow_greater = true
	input.step = 1
	input.update_on_text_changed = true


func _add_label(parent: Control, title: String) -> Label:
	var label := Label.new()
	label.text = title
	parent.add_child(label)
	return label


func _add_row_button(parent: Control, title: String, hint: String, disabled: bool, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.tooltip_text = hint
	button.disabled = disabled
	button.pressed.connect(action)
	parent.add_child(button)
