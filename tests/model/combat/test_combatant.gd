extends GutTest

var combatant: Combatant

func before_each() -> void:
	combatant = Combatant.new("Dummy", 15)

func test_take_damage_reduces_health() -> void:
	combatant.take_damage(5)
	assert_eq(combatant.health, 10, "health should drop by full damage without any block")

func test_block_absorbs_damage_first() -> void:
	combatant.add_block(5)
	combatant.take_damage(6)
	assert_eq(combatant.health, 14)

