class_name CombatResolver extends RefCounted

const STAB = preload("res://content/cards/stab.tres")
const ACROBATICS = preload("res://content/cards/acrobatics.tres")
const QUICK_ATTACK = preload("res://content/cards/quick_attack.tres")
const HAND_SIZE := 6
const MAX_MOMENTUM := 3
const SLIME_DAMAGE := 3

var board := CombatBoard.new()
var hero := Combatant.new("Hero", 10)
var enemy := Combatant.new("Training Slime", 14)
var momentum := 0
var round_number := 1
var deck: CombatDeck


func _init(seed_value: int = 21) -> void:
	var cards: Array[CardDefinition] = [
		STAB, STAB, STAB, STAB, ACROBATICS, ACROBATICS, QUICK_ATTACK, QUICK_ATTACK,
	]
	deck = CombatDeck.new(cards, seed_value)
	deck.draw_hand(HAND_SIZE)


func snapshot() -> Dictionary:
	var hand: Array[Dictionary] = []
	for id in deck.hand:
		hand.append({"id": id, "card": deck.definition(id)})
	return {
		"hero_cell": board.hero_cell, "enemy_cell": board.enemy_cell,
		"hero_hp": hero.health, "hero_max_hp": hero.max_health,
		"enemy_hp": enemy.health, "enemy_max_hp": enemy.max_health,
		"hand": hand, "momentum": momentum, "round": round_number,
		"draw_pile": deck.draw_pile_contents(), "discard_pile": deck.discard_pile_contents(),
		"enemy_targets": _enemy_targets(), "enemy_damage": SLIME_DAMAGE,
		"finished": not hero.alive or not enemy.alive,
	}


func play_card(id: int, payment: Array[int], target: Vector2i) -> CombatResult:
	var result := CombatResult.new()
	result.error = _validate_play(id, payment, target)
	if not result.error.is_empty():
		return result
	var card := deck.definition(id)
	result.facts.append({"kind": CombatResult.Kind.CARD_PLAYED, "name": card.display_name})
	deck.discard(id, CombatDeck.DiscardReason.PLAYED)
	for payment_id in payment:
		deck.discard(payment_id, CombatDeck.DiscardReason.PAYMENT)

	var momentum_spent := 0
	for step in card.steps:
		match step.kind:
			EffectStep.Kind.MELEE:
				momentum_spent = momentum
				_set_momentum(result, 0)
				_damage(result, false, step.amount + 2 * momentum_spent)
			EffectStep.Kind.REPOSITION:
				result.facts.append({
					"kind": CombatResult.Kind.MOVED, "from": board.hero_cell, "to": target,
				})
				board.hero_cell = target
				# The slice grants the hero this rule independently of any class.
				_set_momentum(result, momentum + 1)
			EffectStep.Kind.GAIN_MOMENTUM:
				_set_momentum(result, momentum + step.amount)
			EffectStep.Kind.RESTORE_MOMENTUM:
				_set_momentum(result, momentum + momentum_spent)
	result.snapshot = snapshot()
	return result


func end_turn() -> CombatResult:
	var result := CombatResult.new()
	if not hero.alive or not enemy.alive:
		result.error = "Combat is over."
		return result
	result.facts.append({"kind": CombatResult.Kind.ENEMY_TURN})
	# The slime attacks its column, including the back cell if the front is empty.
	if board.hero_cell in _enemy_targets():
		hero.add_block(momentum)
		_set_momentum(result, 0)
		_damage(result, true, SLIME_DAMAGE)
	if hero.alive:
		deck.discard_hand()
		deck.draw_hand(HAND_SIZE)
		round_number += 1
	result.snapshot = snapshot()
	return result


func _enemy_targets() -> Array[Vector2i]:
	if not enemy.alive or not hero.alive:
		return []
	return [
		Vector2i(board.enemy_cell.x, CombatBoard.HERO_FRONT),
		Vector2i(board.enemy_cell.x, CombatBoard.HERO_BACK),
	]


func _validate_play(id: int, payment: Array[int], target: Vector2i) -> String:
	if not hero.alive or not enemy.alive:
		return "Combat is over."
	if not deck.hand.has(id):
		return "Choose a card from your hand."
	var card := deck.definition(id)
	if payment.size() != card.cost:
		return "Select %d other cards to discard." % card.cost
	var seen: Dictionary = {}
	for payment_id in payment:
		if payment_id == id or seen.has(payment_id) or not deck.hand.has(payment_id):
			return "Payment must use distinct other cards from your hand."
		seen[payment_id] = true
	for step in card.steps:
		if step.kind == EffectStep.Kind.REPOSITION and not board.can_reposition(target):
			return "Select an empty hero cell."
		if step.kind == EffectStep.Kind.MELEE:
			if target != board.enemy_cell or not board.in_melee_range():
				return "Select the slime from an orthogonally adjacent cell."
	return ""


func _set_momentum(result: CombatResult, amount: int) -> void:
	var next := clampi(amount, 0, MAX_MOMENTUM)
	if next != momentum:
		momentum = next
		result.facts.append({"kind": CombatResult.Kind.MOMENTUM, "amount": momentum})


func _damage(result: CombatResult, hits_hero: bool, amount: int) -> void:
	var defender := hero if hits_hero else enemy
	var hp_before := defender.health
	defender.take_damage(amount)
	result.facts.append({
		"kind": CombatResult.Kind.DAMAGE,
		"hits_hero": hits_hero,
		"from": board.enemy_cell if hits_hero else board.hero_cell,
		"to": board.hero_cell if hits_hero else board.enemy_cell,
		"before": hp_before, "after": defender.health,
	})
