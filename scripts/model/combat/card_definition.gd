class_name CardDefinition extends Resource

@export var id: StringName
@export var display_name: String
@export var cost: int
@export_multiline var rules_text: String
@export var steps: Array[EffectStep]
