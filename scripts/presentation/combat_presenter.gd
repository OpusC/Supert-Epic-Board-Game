class_name CombatPresenter extends Control

## Draws the battle grid and shows moves, damage, and stat changes from resolved combat.

## A player clicked a board cell.
signal cell_selected(cell: Vector2i)
## The result is fully visible after playback or a skip.
signal playback_finished

const CELL_SIZE := Vector2(116, 66)
const CELL_SPACING := Vector2(126, 76)
const BOARD_ORIGIN := Vector2(6, 6)
const ROW_COLORS := [Color("#e3aeb2"), Color("#84b2c6"), Color("#a9b4d1")]
const ATTACK_COLOR := Color("#ad432b")
const ATTACK_BORDER := Color("#ffd08e")

var _hero_piece: Panel
var _enemy_piece: Panel
var _status: Label
var _momentum: Label
var _tiles: Dictionary[Vector2i, Button] = {}
var _character_hp: Label
var _hero_max_hp: int
var _hero_hp: Label
var _enemy_hp: Label
var _tween: Tween
var _generation := 0
var _result: CombatResult


func build(status: Label, momentum_label: Label, character_hp: Label) -> void:
	_status = status
	_momentum = momentum_label
	_character_hp = character_hp
	custom_minimum_size = Vector2(390, 234)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for row in 3:
		for column in 3:
			var cell := Vector2i(column, row)
			var tile := Button.new()
			tile.position = _position(cell)
			tile.size = CELL_SIZE
			_tiles[cell] = tile
			tile.pressed.connect(func(): cell_selected.emit(cell))
			add_child(tile)
	_hero_piece = _make_piece("Hero", Color("#22485f"))
	_enemy_piece = _make_piece("Training Slime", Color("#46582c"))
	_hero_hp = _hero_piece.get_node("HP")
	_enemy_hp = _enemy_piece.get_node("HP")


func back_row_button(column: int) -> Button:
	# The hand links to this row so keyboard players can reach the board.
	return _tiles[Vector2i(column, CombatBoard.HERO_BACK)]


func show_snapshot(state: Dictionary) -> void:
	_hero_piece.position = _position(state.hero_cell) + Vector2(4, 4)
	_enemy_piece.position = _position(state.enemy_cell) + Vector2(4, 4)
	_hero_piece.visible = state.hero_hp > 0
	_enemy_piece.visible = state.enemy_hp > 0
	_hero_max_hp = state.hero_max_hp
	_show_hp(_hero_hp, state.hero_hp)
	for cell in _tiles:
		_style_tile(_tiles[cell], cell, cell in state.enemy_targets, state.enemy_damage)
	_show_hp(_enemy_hp, state.enemy_hp)
	_show_momentum(state.momentum)


func play(result: CombatResult) -> void:
	_result = result
	_generation += 1
	var generation := _generation
	for fact in result.facts:
		match fact.kind:
			CombatResult.Kind.CARD_PLAYED:
				_status.text = "Playing %s…" % fact.name
				_tween = create_tween()
				_tween.tween_interval(0.22)
				await _tween.finished
			CombatResult.Kind.MOVED:
				_tween = create_tween()
				_tween.tween_property(_hero_piece, "position", _position(fact.to) + Vector2(4, 4), 0.25)
				await _tween.finished
			CombatResult.Kind.DAMAGE:
				await _animate_hit(fact)
			CombatResult.Kind.MOMENTUM:
				_show_momentum(fact.amount)
			CombatResult.Kind.ENEMY_TURN:
				_status.text = "The slime strikes its column."
				_tween = create_tween()
				_tween.tween_interval(0.25)
				await _tween.finished
		if generation != _generation:
			return
	_finish()


func skip() -> void:
	if _result == null:
		return
	_generation += 1
	if _tween and _tween.is_valid():
		# Finish the wait without running the remaining tween callbacks.
		_tween.stop()
		_tween.finished.emit()
		_tween.kill()
	_finish()


func _finish() -> void:
	show_snapshot(_result.snapshot)
	_result = null
	playback_finished.emit()


func _animate_hit(fact: Dictionary) -> void:
	var piece := _enemy_piece if fact.hits_hero else _hero_piece
	var target_hp := _hero_hp if fact.hits_hero else _enemy_hp
	var target_piece := _hero_piece if fact.hits_hero else _enemy_piece
	var start := piece.position
	var direction := (_position(fact.to) - _position(fact.from)).normalized()
	_tween = create_tween()
	_tween.tween_property(piece, "position", start + direction * 28, 0.15)
	_tween.tween_callback(func():
		_show_hp(target_hp, fact.after)
		target_piece.visible = fact.after > 0
	)
	_tween.tween_property(piece, "position", start, 0.18)
	await _tween.finished


func _style_tile(tile: Button, cell: Vector2i, threatened: bool, damage: int) -> void:
	var color: Color = ATTACK_COLOR if threatened else ROW_COLORS[cell.y]
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(9)
	if threatened:
		style.border_color = ATTACK_BORDER
		style.set_border_width_all(3)
	tile.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.12)
	tile.add_theme_stylebox_override("hover", hover)
	tile.add_theme_stylebox_override("pressed", hover)
	var row_name: String = ["Slime side", "Hero front", "Hero back"][cell.y]
	tile.tooltip_text = "%s, column %d" % [row_name, cell.x + 1]
	if threatened:
		tile.tooltip_text += " • Slime attack, %d damage" % damage


func _position(cell: Vector2i) -> Vector2:
	return BOARD_ORIGIN + Vector2(cell) * CELL_SPACING


func _show_hp(label: Label, hp: int) -> void:
	label.text = "%d HP" % hp
	if label == _hero_hp:
		_character_hp.text = "Health  %d / %d HP" % [hp, _hero_max_hp]


func _show_momentum(amount: int) -> void:
	_momentum.text = "Momentum  %d / %d" % [amount, CombatResolver.MAX_MOMENTUM]


func _make_piece(title: String, color: Color) -> Panel:
	var piece := Panel.new()
	piece.size = CELL_SIZE - Vector2(8, 12)
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(9)
	piece.add_theme_stylebox_override("panel", style)
	add_child(piece)
	for data in [[title, "Title", 7], ["", "HP", 29]]:
		var label := Label.new()
		label.text = data[0]
		label.name = data[1]
		label.position = Vector2(0, data[2])
		label.size.x = piece.size.x
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece.add_child(label)
	return piece
