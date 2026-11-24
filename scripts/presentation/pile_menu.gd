class_name PileMenu extends AcceptDialog

const REASON_LABELS := ["Played", "Payment", "End of turn"]

var _heading := Label.new()
var _rows := HFlowContainer.new()


func _ready() -> void:
	ok_button_text = "Close"
	var layout := VBoxContainer.new()
	layout.custom_minimum_size = Vector2(420, 290)
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)
	layout.add_child(_heading)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	# Tab can reach the scrollbar when the pile contains more than one screen of cards.
	var scrollbar: VScrollBar = scroll.get_v_scroll_bar()
	scrollbar.focus_mode = Control.FOCUS_ALL
	scrollbar.custom_step = 32
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("h_separation", 8)
	_rows.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_rows)


func show_draw_pile(cards: Array[CardDefinition]) -> void:
	_prepare("Draw pile", "This pile is empty." if cards.is_empty() else "Card list · draw order hidden")
	for card in cards:
		_add_card(card)
	popup_centered()


func show_discard_pile(entries: Array[Dictionary]) -> void:
	_prepare("Discard pile", "This pile is empty." if entries.is_empty() else "Oldest to newest")
	for entry in entries:
		_add_card(entry.card, REASON_LABELS[entry.reason])
	popup_centered()


func _prepare(pile_name: String, hint: String) -> void:
	title = pile_name
	_heading.text = hint
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()


func _add_card(card: CardDefinition, reason: String = "") -> void:
	var entry := VBoxContainer.new()
	_rows.add_child(entry)
	var view := CardView.new()
	view.configure(card, false)
	entry.add_child(view)
	if not reason.is_empty():
		var label := Label.new()
		label.text = reason
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		entry.add_child(label)
