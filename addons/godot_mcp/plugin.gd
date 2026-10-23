@tool
extends EditorPlugin

## Main plugin entry point for Godot MCP AI Agent integration.

const DOCK_SCENE_PATH := "res://addons/godot_mcp/mcp_dock.tscn"

var _dock_instance: Control = null


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		_setup_dock()


func _exit_tree() -> void:
	if _dock_instance:
		remove_control_from_docks(_dock_instance)
		_dock_instance.queue_free()
		_dock_instance = null


func _setup_dock() -> void:
	var dock_scene := load(DOCK_SCENE_PATH) as PackedScene
	if dock_scene:
		_dock_instance = dock_scene.instantiate() as Control
		if _dock_instance:
			add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock_instance)
			_dock_instance.set_name("MCP AI")


func _get_plugin_name() -> String:
	return "Godot MCP"


func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("Script", "EditorIcons")
