class_name CardView extends Button

const CARD_WIDTH := 122
const ART_SIZE := 76
const COST_SIZE := 26


func configure(card: CardDefinition, interactive: bool = true) -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, 252)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tooltip_text = "%s • %d discard%s\n%s" % [
		card.display_name, card.cost, "" if card.cost == 1 else "s", card.rules_text,
	]
	if not interactive:
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_theme_stylebox_override("normal", _frame(Color("#232d3c"), Color("#697b91"), 10))
	add_theme_stylebox_override("hover", _frame(Color("#2f4055"), Color("#a2bdd6"), 10))
	add_theme_stylebox_override("pressed", _frame(Color("#1d2a39"), Color("#b7d9ed"), 10))
	add_theme_stylebox_override("disabled", _frame(Color("#202835"), Color("#526173"), 10))

	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 6)
	add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 8
	layout.offset_right = -8
	layout.offset_top = 8
	layout.offset_bottom = -8

	var title := _label(card.display_name, 15)
	var title_margin := MarginContainer.new()
	title_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_margin.add_theme_constant_override("margin_left", COST_SIZE)
	title_margin.custom_minimum_size.y = 32
	title_margin.add_child(title)
	layout.add_child(title_margin)

	var art := Panel.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.custom_minimum_size = Vector2(ART_SIZE, ART_SIZE)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.add_theme_stylebox_override("panel", _frame(Color("#17212e"), Color("#657c94"), 0))
	layout.add_child(art)
	var art_title := _label(card.display_name, 12)
	art_title.add_theme_color_override("font_color", Color("#b0c1d2"))
	art.add_child(art_title)
	art_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_title.offset_left = 4
	art_title.offset_right = -4

	var rules := _label(card.rules_text, 12)
	rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(rules)

	var badge := Panel.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(6, 8)
	badge.size = Vector2(COST_SIZE, COST_SIZE)
	badge.add_theme_stylebox_override("panel", _frame(Color("#e6bd6d"), Color("#f6dda2"), COST_SIZE / 2))
	add_child(badge)
	var cost := _label(str(card.cost), 15)
	cost.add_theme_color_override("font_color", Color("#242018"))
	badge.add_child(cost)
	cost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _frame(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style
