extends GutTest

const Workspace = preload("res://addons/cards/workspace.gd")
const TEST_CARD_PATH := "res://test_card.tres"
const EFFECT_NAMES := ["Melee Damage", "Reposition", "Gain Momentum", "Restore Momentum"]

var _workspace: Workspace


func before_each() -> void:
	var card := CardDefinition.new()
	card.id = &"test_card"
	card.display_name = "Test Card"
	var cards: Dictionary[String, CardDefinition] = {TEST_CARD_PATH: card}
	_workspace = Workspace.new()
	_workspace.load_cards = func() -> Dictionary[String, CardDefinition]: return cards
	add_child_autofree(_workspace)
	assert_eq(_workspace._library.item_count, 1)
	assert_eq(_workspace._name.text, "Test Card")
	_workspace._add.pressed.emit()


func test_empty_search_lists_every_effect_with_its_description() -> void:
	assert_eq(_workspace._picker._search.text, "")
	assert_eq(_visible_effect_names(), EFFECT_NAMES)
	for button in _workspace._picker._buttons:
		assert_false(button.text.get_slice("\n", 1).is_empty(), button.text)


func test_search_matches_names_and_descriptions_and_clearing_restores_all_effects() -> void:
	_search("  mOmEnTuM  ")
	assert_eq(_visible_effect_names(), ["Gain Momentum", "Restore Momentum"])

	_search("empty hero cell")
	assert_eq(_visible_effect_names(), ["Reposition"])

	_search("")
	assert_eq(_visible_effect_names(), EFFECT_NAMES)

	await get_tree().process_frame


func _search(query: String) -> void:
	var field := _workspace._picker._search
	field.text = query
	field.text_changed.emit(query)


func _visible_effect_names() -> Array[String]:
	var names: Array[String] = []
	for child in _workspace._picker._rows.get_children():
		if child is Button and child.is_visible_in_tree():
			names.append(child.text.get_slice("\n", 0))
	return names
