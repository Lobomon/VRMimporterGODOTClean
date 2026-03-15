@tool
## MaterialConverter: convierte ShaderMaterials MToon a StandardMaterial3D en el árbol flat.
## Usa SceneFlattener para externalizar materiales. Con keep_mtoon=true mantiene MToon
## y guarda StandardMaterial3D como metadata (standard_fallback).

extends RefCounted


static func process_scene(scene: Node, keep_mtoon: bool, flattener: RefCounted = null) -> void:
	_walk(scene, keep_mtoon, flattener)


static func _walk(node: Node, keep_mtoon: bool, flattener: RefCounted) -> void:
	if node is MeshInstance3D:
		_process_mesh_instance(node as MeshInstance3D, keep_mtoon, flattener)
	for child in node.get_children():
		_walk(child, keep_mtoon, flattener)


static func _process_mesh_instance(mi: MeshInstance3D, keep_mtoon: bool, flattener: RefCounted) -> void:
	if mi.mesh == null:
		return
	var surf_count: int = mi.mesh.get_surface_count()
	for i in range(surf_count):
		var mat: Material = mi.get_surface_override_material(i)
		if mat == null:
			mat = mi.mesh.surface_get_material(i)
		if mat == null:
			continue
		if mat is ShaderMaterial:
			_handle_shader_material(mi, i, mat as ShaderMaterial, keep_mtoon, flattener)


static func _handle_shader_material(
		mi: MeshInstance3D,
		surf_idx: int,
		shader_mat: ShaderMaterial,
		keep_mtoon: bool,
		flattener: RefCounted) -> void:

	if not _is_mtoon(shader_mat):
		return

	var standard: StandardMaterial3D = _bake_standard(shader_mat)
	if standard == null:
		return

	var ext_standard: Material = standard
	if flattener != null and flattener.has_method("_externalise_material"):
		var result = flattener._externalise_material(standard)
		if result is Material:
			ext_standard = result as Material

	if keep_mtoon:
		var override_mat: ShaderMaterial
		var existing := mi.get_surface_override_material(surf_idx)
		if existing is ShaderMaterial:
			override_mat = existing as ShaderMaterial
		else:
			override_mat = shader_mat.duplicate(false) as ShaderMaterial

		var ext_override: Material = override_mat
		if flattener != null and flattener.has_method("_externalise_material"):
			if override_mat.resource_path == "" or "::" in override_mat.resource_path:
				var result = flattener._externalise_material(override_mat)
				if result is ShaderMaterial:
					ext_override = result as ShaderMaterial

		ext_override.set_meta("standard_fallback", ext_standard)
		mi.set_surface_override_material(surf_idx, ext_override)
	else:
		mi.set_surface_override_material(surf_idx, ext_standard)


# ─── Detección MToon ──────────────────────────────────────────────────────────

static func _is_mtoon(mat: ShaderMaterial) -> bool:
	if mat.shader == null:
		return false
	var path: String = mat.shader.resource_path.get_file().to_lower()
	return "mtoon" in path


# ─── Baker MToon → StandardMaterial3D ────────────────────────────────────────

static func _bake_standard(m: ShaderMaterial) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	if m.resource_name != "":
		s.resource_name = m.resource_name + "_standard"

	# Albedo
	s.albedo_color   = _to_color(m.get_shader_parameter("_Color"), Color.WHITE)
	s.albedo_texture = _tex(m, "_MainTex")

	# Normal map
	var bump: Texture2D = _tex(m, "_BumpMap")
	if bump:
		s.normal_enabled = true
		s.normal_texture = bump
		s.normal_scale   = _float(m, "_BumpScale", 1.0)

	# Emission
	var em_tex: Texture2D = _tex(m, "_EmissionMap")
	var em_col: Color     = _to_color(m.get_shader_parameter("_EmissionColor"), Color.BLACK)
	em_col.a = 1.0
	if em_tex != null or not em_col.is_equal_approx(Color.BLACK):
		s.emission_enabled           = true
		s.emission                   = em_col
		s.emission_texture           = em_tex
		s.emission_energy_multiplier = _float(m, "_EmissionMultiplier", 1.0)

	# Transparencia / Alpha
	var shader_name: String = m.shader.resource_path.get_file().to_lower()
	if "_trans" in shader_name:
		s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	elif "_cutout" in shader_name:
		s.transparency            = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		s.alpha_scissor_threshold = _float(m, "_Cutoff", 0.5)
	else:
		s.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

	# Cull mode
	if "_cull_off" in shader_name:
		s.cull_mode = BaseMaterial3D.CULL_DISABLED

	# UV tiling / offset
	var st: Variant = m.get_shader_parameter("_MainTex_ST")
	if st != null:
		var v4 := _to_vector4(st)
		s.uv1_scale  = Vector3(v4.x, v4.y, 0.0)
		s.uv1_offset = Vector3(v4.z, v4.w, 0.0)

	# MToon no es PBR — defaults mate
	s.metallic          = 0.0
	s.roughness         = 1.0
	s.metallic_specular = 0.0

	return s


# ─── Helpers de parámetros ────────────────────────────────────────────────────

static func _tex(m: ShaderMaterial, param: String) -> Texture2D:
	var v: Variant = m.get_shader_parameter(param)
	return v as Texture2D if v is Texture2D else null


static func _float(m: ShaderMaterial, param: String, default_val: float) -> float:
	var v: Variant = m.get_shader_parameter(param)
	return float(v) if v != null else default_val


static func _to_color(v: Variant, fallback: Color) -> Color:
	if v is Color:   return v
	if v is Vector4: return Color(v.x, v.y, v.z, v.w)
	if v is Plane:   return Color(v.x, v.y, v.z, v.d)
	return fallback


static func _to_vector4(v: Variant) -> Vector4:
	if v is Vector4: return v
	if v is Plane:   return Vector4(v.x, v.y, v.z, v.d)
	return Vector4(1.0, 1.0, 0.0, 0.0)
