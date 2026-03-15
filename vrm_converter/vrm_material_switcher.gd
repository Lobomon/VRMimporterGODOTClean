## VRMMaterialSwitcher
## Runtime helper: attach this script to a VRMTopLevel or any ancestor node
## that contains MeshInstance3D children.
##
## Usage (from your game code):
##   $YourVRMNode.get_node("VRMTopLevel").add_child(VRMaterialSwitcher.new())
##   # or simply:
##   var switcher = VRMaterialSwitcher.new()
##   add_child(switcher)
##   switcher.target_root = $YourVRMNode
##
## Then call:
##   switcher.use_mtoon()       # Switch all surfaces to MToon (toon look)
##   switcher.use_standard()    # Switch all surfaces to StandardMaterial3D
##   switcher.toggle()          # Flip between the two
##
## The StandardMaterial3D fallback is stored as metadata on the ShaderMaterial:
##   shader_mat.get_meta("standard_fallback")
## This was written by the VRM Converter plugin during import.

class_name VRMaterialSwitcher
extends Node

## Root node to scan for MeshInstance3D children.
## If null, uses the parent of this node.
@export var target_root: Node = null

enum Mode { MTOON, STANDARD }
var _current_mode: Mode = Mode.MTOON

## Cached list of [MeshInstance3D, surface_index, ShaderMaterial] tuples
var _surfaces: Array = []
var _ready_done: bool = false


func _ready() -> void:
	_scan()
	_ready_done = true


func _scan() -> void:
	_surfaces.clear()
	var root: Node = target_root if target_root else get_parent()
	if root == null:
		return
	_walk(root)


func _walk(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in range(mi.mesh.get_surface_count() if mi.mesh else 0):
			var mat: Material = mi.get_surface_override_material(i)
			if mat == null:
				mat = mi.mesh.surface_get_material(i) if mi.mesh else null
			if mat is ShaderMaterial and mat.has_meta("standard_fallback"):
				_surfaces.append([mi, i, mat as ShaderMaterial])
	for child in node.get_children():
		_walk(child)


## Switch all MToon surfaces to their StandardMaterial3D fallback.
func use_standard() -> void:
	if not _ready_done:
		_scan()
	for entry in _surfaces:
		var mi: MeshInstance3D = entry[0]
		var idx: int           = entry[1]
		var shader_mat: ShaderMaterial = entry[2]
		var fallback: StandardMaterial3D = shader_mat.get_meta("standard_fallback", null)
		if fallback:
			mi.set_surface_override_material(idx, fallback)
	_current_mode = Mode.STANDARD


## Restore all surfaces to their MToon ShaderMaterial.
func use_mtoon() -> void:
	if not _ready_done:
		_scan()
	for entry in _surfaces:
		var mi: MeshInstance3D = entry[0]
		var idx: int           = entry[1]
		var shader_mat: ShaderMaterial = entry[2]
		mi.set_surface_override_material(idx, shader_mat)
	_current_mode = Mode.MTOON


## Toggle between MToon and Standard.
func toggle() -> void:
	if _current_mode == Mode.MTOON:
		use_standard()
	else:
		use_mtoon()


## Returns true if currently showing MToon shading.
func is_mtoon() -> bool:
	return _current_mode == Mode.MTOON


## Re-scan the tree (call after adding new meshes at runtime).
func refresh() -> void:
	_scan()
