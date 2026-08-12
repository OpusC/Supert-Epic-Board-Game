class_name Combatant extends RefCounted

signal health_changed(new_health: int, max_health: int)
signal block_changed(new_block: int)
signal died(combatant: Combatant)

var display_name: String
var max_health: int
var health: int
var block: int = 0
var board_position: Vector2i

var alive: bool:
	get: return health > 0

func _init(p_name: String, p_max_health: int) -> void:
	display_name = p_name
	max_health = p_max_health
	health = max_health

func take_damage(amount: int):
	var absorbed : int = min(block, amount)
	block -= absorbed
	var remaining := amount - absorbed

	var health_before := health
	health = max(health - remaining, 0)

	if absorbed > 0:
		block_changed.emit(block)
	if health != health_before:
		health_changed.emit(health, max_health)
	if not alive and health_before > 0:
		died.emit(self)

func heal(amount: int) -> void:
	if not alive:
		return
	var health_before := health
	health = min (health - amount, 0)
	if health != health_before:
		health_changed.emit(health, max_health)

func add_block(amount: int) -> void:
	block += amount
	block_changed.emit(block)

func clear_block() -> void:
	if block != 0:
		block = 0
		block_changed.emit(block)
