extends Control

const SettingsMenu = preload("res://scripts/presentation/settings_menu.gd")

var _battle: CombatResolver
var _presenter: CombatPresenter = CombatPresenter.new()
var _hand: HFlowContainer = HFlowContainer.new()
var _status: Label = Label.new()
var _round: Label = Label.new()
var _momentum: Label = Label.new()
var _character_hp: Label = Label.new()
var _enemy_intent: Label = Label.new()
var _draw_pile: Button = Button.new()
var _discard_pile: Button = Button.new()
var _pile_menu: PileMenu = PileMenu.new()
var _shown_state: Dictionary
var _end_turn: Button = Button.new()
var _skip: Button = Button.new()
var _restart: Button = Button.new()
var _settings_menu: SettingsMenu = SettingsMenu.new()
var _active_card: int = -1
var _payment: Array[int] = []
var _busy: bool = false


func _ready() -> void:
	var layout: VBoxContainer = _build_layout()
	_build_encounter(layout)
	_build_hand_area(layout)
	add_child(_settings_menu)

	# Populate the UI once its controls and signals are ready.
	_restart_battle()


func _build_layout() -> VBoxContainer:
	# Create the main column with screen margins, the title, and the round label.
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var header: HBoxContainer = HBoxContainer.new()
	layout.add_child(header)
	var title: Label = Label.new()
	title.text = "Training Encounter"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var settings: Button = Button.new()
	settings.text = "Settings"
	settings.pressed.connect(_settings_menu.open)
	_restart.text = "Restart"
	_restart.pressed.connect(_restart_battle)
	header.add_child(_restart)
	header.add_child(settings)
	layout.add_child(_round)
	return layout


func _build_encounter(layout: VBoxContainer) -> void:
	# Place the board beside the character details, with enemy intent below.
	var encounter: HBoxContainer = HBoxContainer.new()
	encounter.add_theme_constant_override("separation", 20)
	layout.add_child(encounter)
	encounter.add_child(_presenter)
	_build_character_details(encounter)
	_presenter.build(_status, _momentum, _character_hp)
	# A board click supplies the target for the selected card.
	_presenter.cell_selected.connect(_on_cell_selected)
	# When animation finishes or is skipped, refresh the hand and re-enable input.
	_presenter.playback_finished.connect(_on_playback_finished)

	var turn_row: HBoxContainer = HBoxContainer.new()
	layout.add_child(turn_row)
	_enemy_intent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_row.add_child(_enemy_intent)
	_end_turn.text = "End turn"
	_end_turn.pressed.connect(func() -> void: _play_result(_battle.end_turn()))
	turn_row.add_child(_end_turn)
	_skip.text = "Skip animation"
	_skip.pressed.connect(_presenter.skip)
	turn_row.add_child(_skip)


func _build_hand_area(layout: VBoxContainer) -> void:
	# Place the card selection and payment prompt above the hand.
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 46
	layout.add_child(_status)
	_hand.add_theme_constant_override("h_separation", 8)
	_hand.add_theme_constant_override("v_separation", 8)
	# Place the draw and discard controls at the two ends of the hand.
	var hand_row: HBoxContainer = HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 12)
	layout.add_child(hand_row)
	_hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand.alignment = FlowContainer.ALIGNMENT_CENTER
	for control: Control in [_draw_pile, _hand, _discard_pile]:
		control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hand_row.add_child(control)
	_draw_pile.icon = _make_pile_icon(Color("#9ebedd"))
	_discard_pile.icon = _make_pile_icon(Color("#daa77e"))
	add_child(_pile_menu)
	_draw_pile.pressed.connect(func() -> void: _pile_menu.show_draw_pile(_shown_state.draw_pile))
	_discard_pile.pressed.connect(func() -> void: _pile_menu.show_discard_pile(_shown_state.discard_pile))


func _make_pile_icon(accent: Color) -> ImageTexture:
	# Draw two overlapping card silhouettes at button-icon size.
	var image: Image = Image.create_empty(21, 23, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(2, 1, 13, 17), accent.darkened(0.30))
	image.fill_rect(Rect2i(6, 5, 13, 17), accent)
	image.fill_rect(Rect2i(8, 7, 9, 13), Color("#252f3d"))
	return ImageTexture.create_from_image(image)


func _build_character_details(parent: HBoxContainer) -> void:
	# Add the hero’s HP and Momentum labels beside the board for the presenter to update.
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.x = 220
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(panel)
	var padding: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(padding)
	var details: VBoxContainer = VBoxContainer.new()
	details.add_theme_constant_override("separation", 8)
	padding.add_child(details)
	var heading: Label = Label.new()
	heading.text = "Character details"
	heading.add_theme_font_size_override("font_size", 20)
	details.add_child(heading)
	var hero_name: Label = Label.new()
	hero_name.text = "Hero"
	details.add_child(hero_name)
	details.add_child(_character_hp)
	details.add_child(_momentum)


func _restart_battle() -> void:
	# Create a fresh encounter, clear the card selection, and show the opening board and hand.
	_battle = CombatResolver.new()
	_active_card = -1
	_payment.clear()
	_presenter.show_snapshot(_battle.snapshot())
	_refresh()


func _refresh() -> void:
	# Refresh the hand, prompts, and action buttons from the latest battle snapshot.
	var state: Dictionary = _battle.snapshot()
	_shown_state = state
	_round.text = "Round %d" % state.round
	_draw_pile.text = "Draw Pile (%d)" % state.draw_pile.size()
	_discard_pile.text = "Discard Pile (%d)" % state.discard_pile.size()
	_enemy_intent.visible = not state.enemy_targets.is_empty()
	_enemy_intent.text = "Slime attack • %d damage in the highlighted column" % state.enemy_damage
	_end_turn.disabled = _busy or state.finished
	_skip.visible = _busy
	_skip.disabled = not _busy
	_restart.disabled = _busy
	_draw_pile.disabled = _busy
	_discard_pile.disabled = _busy
	# Rebuilding the hand should keep focus on the same card while selecting payment.
	var focused: Control = get_viewport().gui_get_focus_owner()
	var focused_index: int = -1
	if focused != null and focused.get_parent() == _hand:
		focused_index = focused.get_index()
	for child: Node in _hand.get_children():
		_hand.remove_child(child)
		child.queue_free()
	for entry: Dictionary in state.hand:
		var id: int = entry.id
		var card: CardDefinition = entry.card
		var button: CardView = CardView.new()
		button.configure(card)
		button.disabled = _busy or state.finished
		if id == _active_card:
			button.modulate = Color("#91d9ff")
		elif id in _payment:
			button.modulate = Color("#ffc77c")
		button.pressed.connect(_on_card_selected.bind(id))
		_hand.add_child(button)

	_link_hand_navigation()
	if focused_index >= 0 and _hand.get_child_count() > 0:
		var restored: CardView = _hand.get_child(mini(focused_index, _hand.get_child_count() - 1))
		if not restored.disabled:
			restored.grab_focus()
	elif focused == null:
		_focus_hand()

	if _busy:
		return
	if state.finished:
		_status.text = "Victory!" if state.enemy_hp == 0 else "Defeat."
	elif _active_card == -1:
		_status.text = "Choose a card to play."
	else:
		var card: CardDefinition = _battle.deck.definition(_active_card)
		_status.text = "%s  %s Select %d more payment cards, then choose a board cell." % [
			card.display_name, card.rules_text, card.cost - _payment.size(),
		]
		if _payment.size() == card.cost:
			_status.text = "%s  %s Choose its target cell." % [card.display_name, card.rules_text]


func _link_hand_navigation() -> void:
	# Link visible cards and piles across the row, and connect the hand to targeting.
	var controls: Array[Control] = [_draw_pile]
	for card: CardView in _hand.get_children():
		if not card.disabled:
			controls.append(card)
	controls.append(_discard_pile)
	var board_entry: Control = _presenter.back_row_button(1)
	for index: int in controls.size():
		var control: Control = controls[index]
		control.focus_neighbor_left = control.get_path_to(controls[maxi(index - 1, 0)])
		control.focus_neighbor_right = control.get_path_to(controls[mini(index + 1, controls.size() - 1)])
		control.focus_neighbor_top = control.get_path_to(board_entry)
	if not _end_turn.disabled:
		_discard_pile.focus_neighbor_top = _discard_pile.get_path_to(_end_turn)
	_end_turn.focus_neighbor_bottom = _end_turn.get_path_to(_discard_pile)
	for column: int in CombatBoard.COLUMNS:
		var tile: Control = _presenter.back_row_button(column)
		tile.focus_neighbor_bottom = tile.get_path_to(controls[1])


func _focus_hand() -> void:
	var first_card: CardView = _hand.get_child(0) if _hand.get_child_count() > 0 else null
	if first_card != null and not first_card.disabled:
		first_card.grab_focus()
	else:
		_draw_pile.grab_focus()


func _on_card_selected(id: int) -> void:
	# Select a card to play, then toggle other cards as payment. Click the played card again to cancel.
	if _active_card == -1:
		_active_card = id
	elif _active_card == id:
		_active_card = -1
		_payment.clear()
	elif id in _payment:
		_payment.erase(id)
	elif _payment.size() < _battle.deck.definition(_active_card).cost:
		_payment.append(id)
	_refresh()


func _on_cell_selected(cell: Vector2i) -> void:
	# Submit the selected card and its payment to the resolver using the clicked cell as the target.
	if not _busy and _active_card != -1:
		_play_result(_battle.play_card(_active_card, _payment, cell))


func _play_result(result: CombatResult) -> void:
	# Show a rejection immediately or lock combat input while the presenter animates the result.
	if not result.error.is_empty():
		_status.text = result.error
		return
	_active_card = -1
	_payment.clear()
	_busy = true
	_end_turn.disabled = true
	_restart.disabled = true
	_draw_pile.disabled = true
	_discard_pile.disabled = true
	_skip.show()
	_skip.disabled = false
	_skip.grab_focus()
	for button: CardView in _hand.get_children():
		button.disabled = true
	_presenter.play(result)


func _on_playback_finished() -> void:
	# Restore input and show the updated hand when the animation finishes or is skipped.
	_busy = false
	_refresh()
	_focus_hand()
