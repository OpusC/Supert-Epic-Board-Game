extends GutTest

var battle: CombatResolver


func before_each() -> void:
	battle = CombatResolver.new()


func test_reposition_triggers_momentum_before_card_bonus() -> void:
	var result := battle.play_card(4, [0], Vector2i(1, 2))
	assert_eq(result.error, "")
	assert_eq(result.facts[1].kind, CombatResult.Kind.MOVED)
	assert_eq(result.facts[2].amount, 1)
	assert_eq(result.facts[3].amount, 2)
	assert_eq(battle.deck.hand, [1, 3, 2, 6])


func test_quick_attack_restores_the_momentum_its_hit_spent() -> void:
	battle.momentum = 2
	var result := battle.play_card(6, [0, 1], battle.board.enemy_cell)
	assert_eq(result.error, "")
	assert_eq(result.facts[1].amount, 0)
	assert_eq(result.facts[2].before, 14)
	assert_eq(result.facts[2].after, 9)
	assert_eq(result.facts[3].amount, 2)


func test_invalid_payment_and_out_of_range_leave_state_alone() -> void:
	battle.board.hero_cell = Vector2i(1, 2)
	var before := battle.snapshot()
	assert_ne(battle.play_card(6, [1, 1], battle.board.enemy_cell).error, "")
	assert_ne(battle.play_card(6, [1, 2], battle.board.enemy_cell).error, "")
	assert_eq(battle.snapshot(), before)


func test_enemy_hits_back_row_in_its_column_and_draws_next_hand() -> void:
	battle.board.hero_cell = Vector2i(1, 2)
	battle.momentum = 1
	var result := battle.end_turn()
	assert_eq(result.snapshot.hero_hp, 8)
	assert_eq(result.snapshot.momentum, 0)
	assert_eq(result.snapshot.round, 2)
	assert_eq(result.snapshot.hand.size(), 6)


func test_skip_applies_the_same_hp_as_completed_playback() -> void:
	var initial := battle.snapshot()
	var result := battle.play_card(0, [1], battle.board.enemy_cell)
	var presenter := CombatPresenter.new()
	var status := Label.new()
	var momentum_label := Label.new()
	add_child_autofree(presenter)
	add_child_autofree(status)
	add_child_autofree(momentum_label)
	var character_hp := Label.new()
	add_child_autofree(character_hp)
	presenter.build(status, momentum_label, character_hp)
	presenter.show_snapshot(initial)
	watch_signals(presenter)
	presenter.play(result)
	assert_eq(presenter._enemy_hp.text, "14 HP")
	presenter.skip()
	assert_eq(presenter._enemy_hp.text, "12 HP")
	assert_signal_emit_count(presenter, "playback_finished", 1)

	presenter.show_snapshot(initial)
	presenter.play(result)
	await wait_for_signal(presenter.playback_finished, 2.0)
	assert_eq(presenter._enemy_hp.text, "12 HP")
	assert_signal_emit_count(presenter, "playback_finished", 2)


func test_scene_plays_card_through_hand_and_target_buttons() -> void:
	var scene = load("res://scenes/training_encounter.tscn").instantiate()
	add_child_autofree(scene)
	# The seeded opening hand starts with two separate copies of Stab.
	scene._hand.get_child(0).pressed.emit()
	scene._hand.get_child(1).pressed.emit()
	scene._presenter.get_child(1).pressed.emit()
	assert_true(scene._busy)
	assert_eq(scene._battle.enemy.health, 12)
	assert_eq(scene._presenter._enemy_hp.text, "14 HP")
	scene._skip.pressed.emit()
	assert_false(scene._busy)
	assert_eq(scene._presenter._enemy_hp.text, "12 HP")
	assert_eq(scene._hand.get_child_count(), 4)

	await get_tree().process_frame
	await get_tree().process_frame


func test_piles_preserve_discard_reasons_and_refill_only_on_an_extra_draw() -> void:
	var result := battle.play_card(6, [3, 1], battle.board.enemy_cell)
	var discarded: Array[Dictionary] = result.snapshot.discard_pile
	assert_eq(discarded[0].card.id, &"quick_attack")
	assert_eq(discarded[0].reason, CombatDeck.DiscardReason.PLAYED)
	assert_eq(discarded[1].reason, CombatDeck.DiscardReason.PAYMENT)
	assert_eq(discarded[2].reason, CombatDeck.DiscardReason.PAYMENT)
	assert_eq(battle.deck.draw_pile_contents().size(), 2)

	battle.deck.draw_hand(2)
	assert_eq(battle.deck.draw_pile_contents().size(), 0)
	assert_eq(battle.deck.discard_pile_contents(), discarded)

	battle.deck.draw_hand(1)
	assert_eq(battle.deck.draw_pile_contents().size(), 2)
	assert_true(battle.deck.discard_pile_contents().is_empty())
	assert_eq(battle.deck.hand.size(), 6)


func test_draw_preview_uses_catalog_order_and_leaves_the_actual_draw_unchanged() -> void:
	var cards: Array[CardDefinition] = [CombatResolver.STAB, CombatResolver.QUICK_ATTACK, CombatResolver.ACROBATICS]
	var first := CombatDeck.new(cards, 21)
	var second := CombatDeck.new(cards, 9)
	var control := CombatDeck.new(cards, 21)
	assert_eq(first.draw_pile_contents(), cards)
	assert_eq(second.draw_pile_contents(), cards)
	first.draw_hand(3)
	second.draw_hand(3)
	control.draw_hand(3)
	assert_ne(first.hand, second.hand)
	assert_eq(first.hand, control.hand)


func test_scene_shows_character_details_attack_preview_and_pile_menus() -> void:
	var scene = load("res://scenes/training_encounter.tscn").instantiate()
	add_child_autofree(scene)
	assert_eq(scene._character_hp.text, "Health  10 / 10 HP")
	assert_eq(scene._momentum.text, "Momentum  0 / 3")
	assert_eq(scene._presenter._tiles[Vector2i(1, 0)].text, "")
	var threatened: Button = scene._presenter._tiles[Vector2i(1, 2)]
	assert_eq(threatened.get_theme_stylebox("normal").bg_color, CombatPresenter.ATTACK_COLOR)
	scene._draw_pile.pressed.emit()
	assert_true(scene._pile_menu.visible)
	assert_eq(scene._pile_menu._rows.get_child_count(), 2)
	scene._pile_menu.hide()
	scene._discard_pile.pressed.emit()
	assert_eq(scene._pile_menu._heading.text, "This pile is empty.")
	scene._pile_menu.hide()

	scene._end_turn.pressed.emit()
	scene._skip.pressed.emit()
	assert_eq(scene._character_hp.text, "Health  7 / 10 HP")
	await get_tree().process_frame
	await get_tree().process_frame
