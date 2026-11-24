class_name EffectStep extends Resource

enum Kind { MELEE, REPOSITION, GAIN_MOMENTUM, RESTORE_MOMENTUM }

@export var kind: Kind
@export var amount: int
