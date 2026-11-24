@tool
extends EditorPlugin

const Workspace = preload("res://addons/cards/workspace.gd")

var _workspace: Workspace


func _enter_tree() -> void:
	_workspace = Workspace.new()
	_workspace.history = get_undo_redo()
	_workspace.hide()
	EditorInterface.get_editor_main_screen().add_child(_workspace)


func _exit_tree() -> void:
	if is_instance_valid(_workspace):
		_workspace.queue_free()


func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return "Cards"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("Node", "EditorIcons")


func _make_visible(visible: bool) -> void:
	if is_instance_valid(_workspace):
		_workspace.visible = visible
