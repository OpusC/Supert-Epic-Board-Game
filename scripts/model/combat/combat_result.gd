class_name CombatResult extends RefCounted

enum Kind { CARD_PLAYED, MOVED, DAMAGE, MOMENTUM, ENEMY_TURN }

var facts: Array[Dictionary] = []
var snapshot: Dictionary
var error: String
