class_name CombatDeck extends RefCounted

enum DiscardReason { PLAYED, PAYMENT, END_TURN }

var hand: Array[int] = []
var _draw: Array[int] = []
var _discard: Array[Dictionary] = []
var _cards: Array[CardDefinition] = []
var _rng := RandomNumberGenerator.new()


func _init(cards: Array[CardDefinition], seed_value: int) -> void:
	_cards = cards.duplicate()
	_rng.seed = seed_value
	for id in cards.size():
		_draw.append(id)
	_shuffle()


func definition(id: int) -> CardDefinition:
	return _cards[id]


func discard(id: int, reason: DiscardReason) -> void:
	hand.erase(id)
	_discard.append({"id": id, "reason": reason})


func draw_pile_contents() -> Array[CardDefinition]:
	# Instance IDs are assigned before shuffling, so this order reveals no draw positions.
	var ids := _draw.duplicate()
	ids.sort()
	var cards: Array[CardDefinition] = []
	for id in ids:
		cards.append(definition(id))
	return cards


func discard_pile_contents() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in _discard:
		entries.append({"card": definition(entry.id), "reason": entry.reason})
	return entries


func draw_hand(count: int) -> void:
	for index in count:
		if _draw.is_empty():
			for entry in _discard:
				_draw.append(entry.id)
			_discard.clear()
			_shuffle()
		if _draw.is_empty():
			return
		hand.append(_draw.pop_back())


func discard_hand() -> void:
	for id in hand.duplicate():
		discard(id, DiscardReason.END_TURN)


func _shuffle() -> void:
	for index in range(_draw.size() - 1, 0, -1):
		var other := _rng.randi_range(0, index)
		var value := _draw[index]
		_draw[index] = _draw[other]
		_draw[other] = value
