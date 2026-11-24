class_name CombatBoard extends RefCounted

const COLUMNS := 3
const HERO_FRONT := 1
const HERO_BACK := 2

var hero_cell := Vector2i(1, HERO_FRONT)
var enemy_cell := Vector2i(1, 0)


func can_reposition(destination: Vector2i) -> bool:
	return (
		destination.x >= 0 and destination.x < COLUMNS
		and destination.y in [HERO_FRONT, HERO_BACK]
		and destination != hero_cell
	)


func in_melee_range() -> bool:
	var delta := hero_cell - enemy_cell
	return absi(delta.x) + absi(delta.y) == 1
