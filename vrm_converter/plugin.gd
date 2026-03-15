@tool
extends EditorPlugin

var _importer: EditorSceneFormatImporter
var _original_importer: EditorSceneFormatImporter


func _enter_tree() -> void:
	if not ResourceLoader.exists("res://addons/vrm/vrm_extension.gd"):
		push_error("[VRM Converter] godot-vrm not found. Enable it first.")
		return
	_original_importer = load("res://addons/vrm/import_vrm.gd").new()
	remove_scene_format_importer_plugin(_original_importer)
	_importer = load("res://addons/vrm_converter/vrm_import_converter.gd").new()
	add_scene_format_importer_plugin(_importer)


func _exit_tree() -> void:
	if _importer:
		remove_scene_format_importer_plugin(_importer)
		_importer = null
	if _original_importer:
		add_scene_format_importer_plugin(_original_importer)
		_original_importer = null
