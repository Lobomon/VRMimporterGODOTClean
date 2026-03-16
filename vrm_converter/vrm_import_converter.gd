@tool
extends EditorSceneFormatImporter

const MaterialConverter   = preload("res://addons/vrm_converter/material_converter.gd")
const SceneFlattener      = preload("res://addons/vrm_converter/scene_flattener.gd")
const SkeletonRetargeter  = preload("res://addons/vrm_converter/skeleton_retargeter.gd")
const VRMUtils            = preload("res://addons/vrm/vrm_utils.gd")


func _get_importer_name() -> String:
	return "vrm-converter"

func _get_recognized_extensions() -> Array:
	return ["vrm"]

func _get_extensions() -> PackedStringArray:
	return PackedStringArray(["vrm"])

func _get_import_flags() -> int:
	return IMPORT_SCENE

func _get_option_visibility(_path: String, _for_animation: bool, _option: String) -> Variant:
	return true

func _get_options(_path: String) -> Array[Dictionary]:
	return [
		{ "name": "vrm_converter/export_glb",                 "default_value": true,  "property_hint": PROPERTY_HINT_NONE, "hint_string": "", "usage": PROPERTY_USAGE_DEFAULT },
		{ "name": "vrm_converter/export_tscn",                "default_value": true,  "property_hint": PROPERTY_HINT_NONE, "hint_string": "", "usage": PROPERTY_USAGE_DEFAULT },
		{ "name": "vrm_converter/keep_mtoon_shader",          "default_value": true,  "property_hint": PROPERTY_HINT_NONE, "hint_string": "", "usage": PROPERTY_USAGE_DEFAULT },
		{ "name": "vrm_converter/generate_standard_fallback", "default_value": true,  "property_hint": PROPERTY_HINT_NONE, "hint_string": "", "usage": PROPERTY_USAGE_DEFAULT },
		{ "name": "vrm/head_hiding_method",                   "default_value": 0,     "property_hint": PROPERTY_HINT_ENUM, "hint_string": "ThirdPersonOnly,FirstPersonOnly,FirstWithShadow,Layers,LayersWithShadow,IgnoreHeadHiding", "usage": PROPERTY_USAGE_DEFAULT },
		{ "name": "vrm/only_if_head_hiding_uses_layers/first_person_layers", "default_value": 2, "property_hint": PROPERTY_HINT_LAYERS_3D_RENDER, "hint_string": "", "usage": PROPERTY_USAGE_DEFAULT },
		{ "name": "vrm/only_if_head_hiding_uses_layers/third_person_layers", "default_value": 4, "property_hint": PROPERTY_HINT_LAYERS_3D_RENDER, "hint_string": "", "usage": PROPERTY_USAGE_DEFAULT },
		# NUEVA OPCIÓN: Forzar T-Pose en rest pose (corrige modelos VRoid)
		{ "name": "vrm_converter/force_t_pose", 
		  "default_value": true, 
		  "property_hint": PROPERTY_HINT_NONE, 
		  "hint_string": "Forzar T-Pose en rest pose (arregla brazos desviados VRoid)", 
		  "usage": PROPERTY_USAGE_DEFAULT },
	]


func _import_scene(path: String, flags: int, options: Dictionary) -> Object:
	var vrm_ext_path := "res://addons/vrm/vrm_extension.gd"
	if not ResourceLoader.exists(vrm_ext_path):
		push_error("[VRM Converter] godot-vrm not found.")
		return null
	var vrm_ext_class = load(vrm_ext_path)

	var gltf  := GLTFDocument.new()
	var state := GLTFState.new()
	flags |= EditorSceneFormatImporter.IMPORT_USE_NAMED_SKIN_BINDS
	var vrm_ext: GLTFDocumentExtension = vrm_ext_class.new()
	gltf.register_gltf_document_extension(vrm_ext, true)
	state.handle_binary_image = GLTFState.HANDLE_BINARY_EMBED_AS_UNCOMPRESSED

	if options.has("vrm/head_hiding_method"):
		state.set_additional_data(&"vrm/head_hiding_method", options["vrm/head_hiding_method"])
	if options.has("vrm/only_if_head_hiding_uses_layers/first_person_layers"):
		state.set_additional_data(&"vrm/first_person_layers", options["vrm/only_if_head_hiding_uses_layers/first_person_layers"])
	if options.has("vrm/only_if_head_hiding_uses_layers/third_person_layers"):
		state.set_additional_data(&"vrm/third_person_layers", options["vrm/only_if_head_hiding_uses_layers/third_person_layers"])

	var err := gltf.append_from_file(path, state, flags)
	if err != OK:
		gltf.unregister_gltf_document_extension(vrm_ext)
		push_error("[VRM Converter] append_from_file failed (err=%d): %s" % [err, path])
		return null

	var scene: Node = gltf.generate_scene(state)
	gltf.unregister_gltf_document_extension(vrm_ext)

	if scene == null:
		push_error("[VRM Converter] generate_scene() returned null")
		return null

	# Si el plugin oficial no ha renombrado a GeneralSkeleton (caso VRM 1.0 / VRoid nuevo),
	# forzamos el mismo flujo de skeleton_rename construyendo un BoneMap compatible.
	print("[VRM Converter] Escena VRM generada, comprobando esqueleto para VRM 1.0…")
	var retargeter := SkeletonRetargeter.new()
	var imported_skeleton: Skeleton3D = retargeter.find_skeleton(scene)
	if imported_skeleton == null:
		print("[VRM Converter] No se encontró Skeleton3D en la escena importada.")
	else:
		print("[VRM Converter] Skeleton encontrado: %s (bones=%d)" % [imported_skeleton.name, imported_skeleton.get_bone_count()])
		var is_v1_meta: bool = retargeter.is_vrm_1_0(scene)
		var is_v1_heuristic: bool = retargeter.looks_like_vrm1_vroid_skeleton(imported_skeleton)
		print("[VRM Converter] ¿VRM 1.0 por meta?: %s, ¿por huesos VRoid?: %s" % [str(is_v1_meta), str(is_v1_heuristic)])
		if imported_skeleton.name != SkeletonRetargeter.GENERAL_SKELETON_NAME and (is_v1_meta or is_v1_heuristic):
			print("[VRM Converter] Intentando forzar retarget completo VRM 1.0 (meta/heurística)…")
			var bone_map: BoneMap = retargeter.build_vrm1_bone_map_from_gltf_state(state, imported_skeleton)
			if bone_map:
				print("[VRM Converter] BoneMap generado, llamando a VRMUtils.perform_retarget…")
				VRMUtils.perform_retarget(state, scene, imported_skeleton, bone_map)
				print("[VRM Converter] perform_retarget terminado. Nombre de esqueleto: %s" % imported_skeleton.name)
				# Loguear algunos huesos para verificar el renombrado real.
				var max_log_bones := min(20, imported_skeleton.get_bone_count())
				for i in range(max_log_bones):
					print("[VRM Converter] Bone[%d]: %s" % [i, imported_skeleton.get_bone_name(i)])
				# Loguear dónde están los AnimationPlayer en la escena resultante.
				print("[VRM Converter] Buscando AnimationPlayer en la escena importada…")
				var stack: Array[Node] = [scene]
				while not stack.is_empty():
					var n: Node = stack.pop_back()
					if n is AnimationPlayer:
						print("[VRM Converter] AnimationPlayer encontrado en ruta: %s" % str(n.get_path()))
					for child in n.get_children():
						if child is Node:
							stack.append(child)
			else:
				push_warning("[VRM Converter] No se pudo generar un BoneMap VRM 1.0 válido.")

	var do_glb:  bool = options.get("vrm_converter/export_glb", true)
	var do_tscn: bool = options.get("vrm_converter/export_tscn", true)

	if do_glb or do_tscn:
		var helper                   := _DeferredExporter.new()
		helper.vrm_path              = path
		helper.do_glb                = do_glb
		helper.do_tscn               = do_tscn
		helper.keep_mtoon            = options.get("vrm_converter/keep_mtoon_shader", true)
		helper.gen_standard_fallback = options.get("vrm_converter/generate_standard_fallback", true)
		helper.source_scene          = scene
		# Pasar todas las opciones para que el retargeter pueda usarlas
		helper.options               = options
		EditorInterface.get_base_control().add_child(helper)
		helper.call_deferred("run")

	return scene


class _DeferredExporter extends Node:
	var vrm_path:              String
	var do_glb:                bool
	var do_tscn:               bool
	var keep_mtoon:            bool
	var gen_standard_fallback: bool
	var source_scene:          Node
	var options:               Dictionary        # NUEVO: guardar opciones


	func run() -> void:
		await get_tree().process_frame

		if do_glb:
			_copy_vrm_as_glb()

		if do_tscn and source_scene != null:
			await _export_tscn_from_scene(source_scene)

		queue_free()


	func _copy_vrm_as_glb() -> void:
		var glb_path := vrm_path.get_basename() + ".glb"
		var abs_vrm  := ProjectSettings.globalize_path(vrm_path)
		var abs_glb  := ProjectSettings.globalize_path(glb_path)

		var bytes := FileAccess.get_file_as_bytes(abs_vrm)
		if bytes.is_empty():
			push_error("[VRM Converter] Cannot read VRM bytes: " + abs_vrm)
			return
		if bytes.size() < 12 \
		or bytes[0] != 0x67 or bytes[1] != 0x6C \
		or bytes[2] != 0x54 or bytes[3] != 0x46:
			push_error("[VRM Converter] Not a valid GLB binary (bad magic bytes)")
			return

		var f := FileAccess.open(abs_glb, FileAccess.WRITE)
		if f == null:
			push_error("[VRM Converter] Cannot write GLB: " + abs_glb)
			return
		f.store_buffer(bytes)
		f.close()
		_notify_filesystem(glb_path)


	func _export_tscn_from_scene(scene: Node) -> void:
		var base_path  := vrm_path.get_basename()
		var model_name := base_path.get_file()
		var tscn_path  := base_path.get_base_dir().path_join(model_name).path_join(model_name + "_converted.tscn")

		# NUEVO: pasar options al retargeter
		var retargeter := SkeletonRetargeter.new()

		var flattener       := SceneFlattener.new()
		flattener.base_path = base_path
		var flat: Node      = flattener.flatten(scene)
		if flat == null:
			push_error("[VRM Converter] SceneFlattener.flatten() returned null")
			return

		if gen_standard_fallback:
			MaterialConverter.process_scene(flat, keep_mtoon, flattener)
		flat.scene_file_path = tscn_path
		var packed   := PackedScene.new()
		var pack_err := packed.pack(flat)
		flat.free()

		if pack_err != OK:
			push_error("[VRM Converter] PackedScene.pack() failed (err=%d)" % pack_err)
			return

		var save_flags := ResourceSaver.FLAG_RELATIVE_PATHS | ResourceSaver.FLAG_COMPRESS
		var save_err := ResourceSaver.save(packed, tscn_path, save_flags)
		if save_err != OK:
			push_error("[VRM Converter] ResourceSaver.save() failed (err=%d): %s" % [save_err, tscn_path])
			return

		if Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().scan()

		_notify_filesystem(tscn_path)

	func _notify_filesystem(path: String) -> void:
		if Engine.is_editor_hint():
			var loc := ProjectSettings.localize_path(path)
			if loc != "":
				EditorInterface.get_resource_filesystem().update_file(loc)
