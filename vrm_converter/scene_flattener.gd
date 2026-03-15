@tool
## SceneFlattener: externaliza recursos (meshes, skins, materiales, texturas) y registra UIDs
## para que PackedScene.pack() no los embeba inline. Limpia metadata VRM (thumbnails, etc.)
## preservando vrm_meta para bone mapping.

extends RefCounted

const SAVE_WEBP_DEBUG := false

var base_path: String = ""

var _mesh_idx: int = 0
var _skin_idx: int = 0
var _mat_idx:  int = 0
var _tex_idx:  int = 0
var _lib_idx:  int = 0

var _tex_cache: Dictionary = {}

var _out_dir:    String = ""
var _model_name: String = ""

const VRM_METADATA_KEYS := [
	"spring_bones", "collider_groups", "vrm_pose_diffs",
	"vrm_meta", "vrm_secondary", "gltf_node_index",
	"thumbnail",
]

const PROTECTED_META_KEYS := [
	"humanoid_bone_mapping",
	"humanBones",
]
const META_KEYS_NEVER_REMOVE := ["vrm_meta"]


func flatten(source: Node) -> Node:
	if source == null:
		return null
	if base_path == "":
		push_error("[VRM Converter] SceneFlattener: base_path no definido")
		return null

	_model_name = base_path.get_file()
	_out_dir    = base_path.get_base_dir().path_join(_model_name) + "/"

	var abs_dir := ProjectSettings.globalize_path(_out_dir)
	if not DirAccess.dir_exists_absolute(abs_dir):
		var err := DirAccess.make_dir_recursive_absolute(abs_dir)
		if err != OK:
			push_error("[VRM Converter] No se pudo crear carpeta: %s (err=%d)" % [abs_dir, err])
			return null

	var flags: int = (
		Node.DUPLICATE_SIGNALS |
		Node.DUPLICATE_GROUPS  |
		Node.DUPLICATE_SCRIPTS
	)
	var copy: Node = source.duplicate(flags)
	if copy == null:
		push_error("[VRM Converter] SceneFlattener: duplicate() returned null")
		return null

	_reassign_owners(copy, copy)
	_strip_vrm_metadata(copy)
	_process_resources(copy)

	return copy


func resolve_textures(_node: Node) -> void:
	pass


# ─── Helper central de guardado ───────────────────────────────────────────────

func _save_res(res: Resource, path: String) -> Resource:
	res.take_over_path(path)
	var err := ResourceSaver.save(res, path, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("[VRM Converter] ResourceSaver.save() falló: %s (err=%d)" % [path, err])
		return res

	if Engine.is_editor_hint():
		_register_uid_and_force_external(path)
	
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as Resource


# ─── Owner reassignment ───────────────────────────────────────────────────────

func _reassign_owners(root: Node, node: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = root
		_reassign_owners(root, child)


func _strip_vrm_metadata(node: Node) -> void:
	var keys_to_remove := []
	var keys_to_update := {}

	for key in node.get_meta_list():
		var val = node.get_meta(key)
		if key in PROTECTED_META_KEYS:
			continue

		var original_val = val
		var cleaned_val = _strip_image_textures(original_val)

		if key == "vrm_meta":
			if cleaned_val == null:
				pass
			elif cleaned_val is Dictionary:
				var d: Dictionary = cleaned_val
				var has_bone_mapping: bool = d.has("humanoid_bone_mapping") or d.has("humanBones")
				if d.is_empty() or not has_bone_mapping:
					pass
				elif cleaned_val != original_val:
					keys_to_update[key] = cleaned_val
			elif cleaned_val != original_val:
				keys_to_update[key] = cleaned_val
			continue

		if cleaned_val == null:
			if key not in META_KEYS_NEVER_REMOVE:
				keys_to_remove.append(key)
		elif cleaned_val != original_val:
			keys_to_update[key] = cleaned_val

	for key in keys_to_remove:
		node.remove_meta(key)

	for key in keys_to_update:
		node.set_meta(key, keys_to_update[key])

	for child in node.get_children():
		_strip_vrm_metadata(child)


func _strip_image_textures(val: Variant) -> Variant:
	if val == null:
		return null
	if val is ImageTexture:
		return null
	if val is Image:
		return null
	if val is Array:
		var new_arr := []
		var changed := false
		for item in val:
			var new_item = _strip_image_textures(item)
			if new_item != null:
				new_arr.append(new_item)
			else:
				changed = true
		if changed or new_arr.size() != val.size():
			return new_arr if not new_arr.is_empty() else null
		return val
	if val is Dictionary:
		var new_dict := {}
		var changed := false
		for k in val:
			var new_item = _strip_image_textures(val[k])
			if new_item != null:
				new_dict[k] = new_item
			else:
				changed = true
		if changed or new_dict.size() != val.size():
			return new_dict if not new_dict.is_empty() else null
		return val
	return val


# ─── Procesado recursivo ──────────────────────────────────────────────────────

func _process_resources(node: Node) -> void:
	_externalise_node_resources(node)

	if node is MeshInstance3D:
		_process_mesh_instance(node as MeshInstance3D)
	elif node is AnimationPlayer:
		_process_animation_player(node as AnimationPlayer)

	for child in node.get_children():
		_process_resources(child)


func _externalise_node_resources(node: Node) -> void:
	var props := node.get_property_list()
	for p in props:
		if not (p.usage & PROPERTY_USAGE_STORAGE):
			continue
		if p.type == TYPE_OBJECT and p.class_name != "":
			var value = node.get(p.name)
			if value == null:
				continue
			if value is Texture2D:
				if p.name.to_lower() == "thumbnail":
					node.set(p.name, null)
					continue
				var new_val = _externalise_texture(value)
				node.set(p.name, new_val)
			elif value is Material:
				var new_val = _externalise_material(value)
				if new_val != value:
					node.set(p.name, new_val)
			elif value is Resource and p.name == "vrm_meta":
				var meta_res: Resource = value as Resource
				if meta_res.get("thumbnail_image") != null:
					var dup: Resource = meta_res.duplicate(true)
					dup.set("thumbnail_image", null)
					node.set(p.name, dup)


# ─── MeshInstance3D ───────────────────────────────────────────────────────────

func _process_mesh_instance(mi: MeshInstance3D) -> void:
	if mi.mesh != null:
		for i in range(mi.mesh.get_surface_count()):
			var mat: Material = mi.mesh.surface_get_material(i)
			if mat != null:
				var saved := _externalise_material(mat)
				if saved != null and saved != mat:
					mi.mesh.surface_set_material(i, saved)

	if mi.mesh != null:
		var mesh_path := _out_dir + "%s_mesh_%d.tres" % [_model_name, _mesh_idx]
		_mesh_idx += 1
		var mesh_copy: Mesh = mi.mesh.duplicate(true)
		var loaded := _save_res(mesh_copy, mesh_path)
		if loaded is Mesh:
			mi.mesh = loaded as Mesh

	if mi.skin != null:
		var skin_path := _out_dir + "%s_skin_%d.tres" % [_model_name, _skin_idx]
		_skin_idx += 1
		var skin_copy: Skin = mi.skin.duplicate(true)
		var loaded := _save_res(skin_copy, skin_path)
		if loaded is Skin:
			mi.skin = loaded as Skin

	if mi.mesh != null:
		for i in range(mi.mesh.get_surface_count()):
			var mat: Material = mi.get_surface_override_material(i)
			if mat != null:
				var saved := _externalise_material(mat)
				if saved != null and saved != mat:
					mi.set_surface_override_material(i, saved)


# ─── Material ─────────────────────────────────────────────────────────────────

func _externalise_material(mat: Material) -> Material:
	if mat == null:
		return null
	if mat.resource_path != "" and not _is_inline_path(mat.resource_path):
		return mat

	if mat is StandardMaterial3D:
		_externalise_standard_textures(mat as StandardMaterial3D)
	elif mat is ShaderMaterial:
		_externalise_shader_textures(mat as ShaderMaterial)

	var mat_path := _out_dir + "%s_mat_%d.tres" % [_model_name, _mat_idx]
	_mat_idx += 1
	var loaded := _save_res(mat, mat_path)
	if loaded is Material:
		return loaded as Material
	return mat


func _externalise_standard_textures(mat: StandardMaterial3D) -> void:
	var props := [
		"albedo_texture", "metallic_texture", "roughness_texture",
		"emission_texture", "normal_texture", "rim_texture",
		"clearcoat_texture", "anisotropy_flowmap", "ambient_occlusion_texture",
		"heightmap_texture", "subsurf_scatter_texture",
		"subsurf_scatter_transmittance_texture", "backlight_texture",
		"refraction_texture", "detail_mask", "detail_albedo", "detail_normal",
	]
	for prop in props:
		var tex: Variant = mat.get(prop)
		if tex is Texture2D:
			var saved := _externalise_texture(tex as Texture2D)
			mat.set(prop, saved)
	_externalise_next_pass(mat.next_pass)


func _externalise_shader_textures(mat: ShaderMaterial) -> void:
	if mat.shader == null:
		return
	for param in mat.shader.get_shader_uniform_list():
		var val: Variant = mat.get_shader_parameter(param["name"])
		if val is Texture2D:
			var saved := _externalise_texture(val as Texture2D)
			mat.set_shader_parameter(param["name"], saved)
	_externalise_next_pass(mat.next_pass)


func _externalise_next_pass(next: Variant) -> void:
	if next == null:
		return
	if next is ShaderMaterial:
		_externalise_shader_textures(next as ShaderMaterial)
	elif next is StandardMaterial3D:
		_externalise_standard_textures(next as StandardMaterial3D)


# ─── Textura ──────────────────────────────────────────────────────────────────

func _externalise_texture(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null

	var cache_key: int = tex.get_instance_id()
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key]

	var rpath := tex.resource_path
	if rpath != "" and not _is_inline_path(rpath):
		if tex is CompressedTexture2D:
			var img := _get_image(tex)
			if img != null and not img.is_empty():
				var fname := rpath.get_file().get_basename()
				var tex_path := _out_dir + "%s_%s.tres" % [_model_name, fname]
				if _tex_cache.has(rpath):
					_tex_cache[cache_key] = _tex_cache[rpath]
					return _tex_cache[cache_key]
				if img.get_format() != Image.FORMAT_RGBA8 and img.get_format() != Image.FORMAT_RGB8:
					img.convert(Image.FORMAT_RGBA8)
				var pct := PortableCompressedTexture2D.new()
				pct.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_BASIS_UNIVERSAL)
				pct.resource_name = fname
				var loaded := _save_res(pct, tex_path)
				if loaded is Texture2D:
					_tex_cache[cache_key] = loaded as Texture2D
					_tex_cache[rpath] = loaded as Texture2D
					return loaded as Texture2D
		_ensure_uid(rpath)
		_tex_cache[cache_key] = tex
		return tex

	var img: Image = _get_image(tex)

	if img == null or img.is_empty():
		push_error("[VRM Converter] No se pudo extraer imagen de: %s (%s)" % [rpath, tex.get_class()])
		_tex_cache[cache_key] = null
		return null

	if SAVE_WEBP_DEBUG:
		var webp_path := _out_dir + "%s_tex_%d_debug.webp" % [_model_name, _tex_idx]
		img.save_webp(ProjectSettings.globalize_path(webp_path), false)

	if img.get_format() != Image.FORMAT_RGBA8 and img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGBA8)

	var pct := PortableCompressedTexture2D.new()
	pct.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_BASIS_UNIVERSAL)
	pct.resource_name = tex.resource_name if tex.resource_name != "" else ("tex_%d" % _tex_idx)

	var tex_path := _out_dir + "%s_tex_%d.tres" % [_model_name, _tex_idx]
	_tex_idx += 1

	var loaded := _save_res(pct, tex_path)
	if loaded is Texture2D:
		_tex_cache[cache_key] = loaded as Texture2D
		return loaded as Texture2D

	push_error("[VRM Converter] No se pudo guardar textura en: %s" % tex_path)
	_tex_cache[cache_key] = null
	return null


func _get_image(tex: Texture2D) -> Image:
	if tex == null:
		return null
	if tex is ImageTexture:
		var img = (tex as ImageTexture).get_image()
		return img if img != null else null
	if tex is PortableCompressedTexture2D:
		var img = (tex as PortableCompressedTexture2D).get_image()
		return img if img != null else null
	if tex is CompressedTexture2D:
		if tex.has_method("get_image"):
			var result = tex.call("get_image")
			return result if result is Image else null
		return null
	if tex.has_method("get_image"):
		var result = tex.call("get_image")
		return result if result is Image else null
	return null


func _ensure_uid(res_path: String) -> void:
	var uid_db := ResourceUID
	var existing_uid: int = uid_db.text_to_id(res_path) if uid_db.has_method("text_to_id") else ResourceUID.INVALID_ID
	if existing_uid != ResourceUID.INVALID_ID:
		return
	var new_uid: int = uid_db.create_id()
	uid_db.add_id(new_uid, res_path)


# ─── AnimationPlayer ──────────────────────────────────────────────────────────

func _process_animation_player(ap: AnimationPlayer) -> void:
	for lib_name in ap.get_animation_library_list():
		var lib: AnimationLibrary = ap.get_animation_library(lib_name)
		if lib == null:
			continue
		var lib_copy := AnimationLibrary.new()
		for anim_name in lib.get_animation_list():
			var anim: Animation = lib.get_animation(anim_name)
			if anim:
				var anim_copy: Animation = anim.duplicate(true)
				anim_copy.take_over_path("")
				lib_copy.add_animation(anim_name, anim_copy)
		var safe_name := lib_name.replace("/", "_").replace(":", "_")
		if safe_name == "":
			safe_name = str(_lib_idx)
		var lib_path := _out_dir + "%s_anims_%s.tres" % [_model_name, safe_name]
		_lib_idx += 1
		var loaded := _save_res(lib_copy, lib_path)
		if loaded is AnimationLibrary:
			ap.remove_animation_library(lib_name)
			ap.add_animation_library(lib_name, loaded as AnimationLibrary)


# ─── Helper ───────────────────────────────────────────────────────────────────

func _is_inline_path(path: String) -> bool:
	return ".godot/imported" in path or "::" in path or path == ""

func _register_uid_and_force_external(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	var uid: int = ResourceUID.text_to_id("uid://" + path)
	if uid == ResourceUID.INVALID_ID:
		uid = ResourceUID.create_id()
		ResourceUID.add_id(uid, path)
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().update_file(path)
