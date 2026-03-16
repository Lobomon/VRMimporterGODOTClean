@tool
## SkeletonRetargeter: renombra huesos VRM a Godot SkeletonProfileHumanoid.
## Parcheado para VRM 1.0 + tipado explícito para Godot 4.5

extends RefCounted

const GENERAL_SKELETON_NAME := "GeneralSkeleton"

const VRM_TO_GODOT: Dictionary = {
	"hips": "Hips", "spine": "Spine", "chest": "Chest", "upperChest": "UpperChest",
	"neck": "Neck", "head": "Head", "leftEye": "LeftEye", "rightEye": "RightEye", "jaw": "Jaw",
	"leftShoulder": "LeftShoulder", "leftUpperArm": "LeftUpperArm", "leftLowerArm": "LeftLowerArm", "leftHand": "LeftHand",
	"rightShoulder": "RightShoulder", "rightUpperArm": "RightUpperArm", "rightLowerArm": "RightLowerArm", "rightHand": "RightHand",
	"leftUpperLeg": "LeftUpperLeg", "leftLowerLeg": "LeftLowerLeg", "leftFoot": "LeftFoot", "leftToes": "LeftToes",
	"rightUpperLeg": "RightUpperLeg", "rightLowerLeg": "RightLowerLeg", "rightFoot": "RightFoot", "rightToes": "RightToes",
	"leftThumbMetacarpal": "LeftThumbMetacarpal", "leftThumbProximal": "LeftThumbProximal", "leftThumbDistal": "LeftThumbDistal",
	"leftIndexProximal": "LeftIndexProximal", "leftIndexIntermediate": "LeftIndexIntermediate", "leftIndexDistal": "LeftIndexDistal",
	"leftMiddleProximal": "LeftMiddleProximal", "leftMiddleIntermediate": "LeftMiddleIntermediate", "leftMiddleDistal": "LeftMiddleDistal",
	"leftRingProximal": "LeftRingProximal", "leftRingIntermediate": "LeftRingIntermediate", "leftRingDistal": "LeftRingDistal",
	"leftLittleProximal": "LeftLittleProximal", "leftLittleIntermediate": "LeftLittleIntermediate", "leftLittleDistal": "LeftLittleDistal",
	"rightThumbMetacarpal": "RightThumbMetacarpal", "rightThumbProximal": "RightThumbProximal", "rightThumbDistal": "RightThumbDistal",
	"rightIndexProximal": "RightIndexProximal", "rightIndexIntermediate": "RightIndexIntermediate", "rightIndexDistal": "RightIndexDistal",
	"rightMiddleProximal": "RightMiddleProximal", "rightMiddleIntermediate": "RightMiddleIntermediate", "rightMiddleDistal": "RightMiddleDistal",
	"rightRingProximal": "RightRingProximal", "rightRingIntermediate": "RightRingIntermediate", "rightRingDistal": "RightRingDistal",
	"rightLittleProximal": "RightLittleProximal", "rightLittleIntermediate": "RightLittleIntermediate", "rightLittleDistal": "RightLittleDistal",
}

# Mapeo VRoid → nombre estándar VRM.
const VRoid_TO_VRM: Dictionary = {
	"J_Bip_C_Hips": "hips",
	"J_Bip_C_Spine": "spine",
	"J_Bip_C_Chest": "chest",
	"J_Bip_C_UpperChest": "upperChest",
	"J_Bip_C_Neck": "neck",
	"J_Bip_C_Head": "head",
	"J_Bip_C_LeftEye": "leftEye",
	"J_Bip_C_RightEye": "rightEye",
	"J_Bip_C_Jaw": "jaw",
	"J_Bip_L_Shoulder": "leftShoulder",
	"J_Bip_L_UpperArm": "leftUpperArm",
	"J_Bip_L_LowerArm": "leftLowerArm",
	"J_Bip_L_Hand": "leftHand",
	"J_Bip_R_Shoulder": "rightShoulder",
	"J_Bip_R_UpperArm": "rightUpperArm",
	"J_Bip_R_LowerArm": "rightLowerArm",
    "J_Bip_R_Hand": "rightHand",
	"J_Bip_L_UpperLeg": "leftUpperLeg",
	"J_Bip_L_LowerLeg": "leftLowerLeg",
	"J_Bip_L_Foot": "leftFoot",
	"J_Bip_L_ToeBase": "leftToes",
	"J_Bip_R_UpperLeg": "rightUpperLeg",
	"J_Bip_R_LowerLeg": "rightLowerLeg",
	"J_Bip_R_Foot": "rightFoot",
	"J_Bip_R_ToeBase": "rightToes",
	# Dedos
	"J_Bip_L_Thumb1": "leftThumbMetacarpal",
	"J_Bip_L_Thumb2": "leftThumbProximal",
	"J_Bip_L_Thumb3": "leftThumbDistal",
	"J_Bip_L_Index1": "leftIndexProximal",
	"J_Bip_L_Index2": "leftIndexIntermediate",
	"J_Bip_L_Index3": "leftIndexDistal",
	"J_Bip_L_Middle1": "leftMiddleProximal",
	"J_Bip_L_Middle2": "leftMiddleIntermediate",
	"J_Bip_L_Middle3": "leftMiddleDistal",
	"J_Bip_L_Ring1": "leftRingProximal",
	"J_Bip_L_Ring2": "leftRingIntermediate",
	"J_Bip_L_Ring3": "leftRingDistal",
	"J_Bip_L_Little1": "leftLittleProximal",
	"J_Bip_L_Little2": "leftLittleIntermediate",
	"J_Bip_L_Little3": "leftLittleDistal",
	"J_Bip_R_Thumb1": "rightThumbMetacarpal",
	"J_Bip_R_Thumb2": "rightThumbProximal",
	"J_Bip_R_Thumb3": "rightThumbDistal",
	"J_Bip_R_Index1": "rightIndexProximal",
	"J_Bip_R_Index2": "rightIndexIntermediate",
	"J_Bip_R_Index3": "rightIndexDistal",
	"J_Bip_R_Middle1": "rightMiddleProximal",
	"J_Bip_R_Middle2": "rightMiddleIntermediate",
	"J_Bip_R_Middle3": "rightMiddleDistal",
	"J_Bip_R_Ring1": "rightRingProximal",
	"J_Bip_R_Ring2": "rightRingIntermediate",
	"J_Bip_R_Ring3": "rightRingDistal",
	"J_Bip_R_Little1": "rightLittleProximal",
	"J_Bip_R_Little2": "rightLittleIntermediate",
	"J_Bip_R_Little3": "rightLittleDistal",
}

var _godot_lower_to_canonical: Dictionary = {}


func _init() -> void:
	for vrm_name: String in VRM_TO_GODOT:
		var godot_name: String = VRM_TO_GODOT[vrm_name]
		_godot_lower_to_canonical[godot_name.to_lower()] = godot_name


func process(root: Node, base_path: String, options: Dictionary = {}) -> BoneMap:
	var skeleton: Skeleton3D = _find_skeleton(root)
	if skeleton == null:
		push_error("[VRM Converter] No Skeleton3D found")
		return null
	
	# IMPORTANTE:
	# El renombrado de huesos y la aplicación del SkeletonProfileHumanoid
	# lo hace principalmente el plugin oficial godot-vrm mediante vrm_utils.
	# Aquí solo dejamos la opción de aplicar una corrección de T-Pose
	# a la rest pose, si el usuario la tiene activada.
	var force_t_pose: bool = options.get("vrm_converter/force_t_pose", true)
	if force_t_pose:
		_apply_t_pose_to_rest(skeleton)
	
	# No devolvemos ni generamos BoneMap aquí para no duplicar
	# funcionalidad con godot-vrm en el flujo principal.
	return null


# Helpers públicos que reutiliza el importador para detectar VRM 1.0
# y construir un BoneMap compatible con vrm_utils.skeleton_rename().
func find_skeleton(node: Node) -> Skeleton3D:
	var skel := _find_skeleton(node)
	if skel == null:
		print("[VRM Converter] find_skeleton: no se encontró Skeleton3D.")
	else:
		print("[VRM Converter] find_skeleton: encontrado skeleton '%s' con %d huesos." % [skel.name, skel.get_bone_count()])
	return skel


func is_vrm_1_0(root: Node) -> bool:
	var result := _is_vrm_1_0(root)
	print("[VRM Converter] is_vrm_1_0: %s" % str(result))
	return result


func looks_like_vrm1_vroid_skeleton(skeleton: Skeleton3D) -> bool:
	# Heurística alternativa: detectar VRM 1.0 / VRoid nuevo por nombres de huesos J_Bip_*
	for i in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(i)
		if VRoid_TO_VRM.has(name):
			print("[VRM Converter] looks_like_vrm1_vroid_skeleton: detectado VRoid/VRM1 por hueso '%s'." % name)
			return true
	return false


func build_vrm1_bone_map_from_skeleton(skeleton: Skeleton3D) -> BoneMap:
	print("[VRM Converter] build_vrm1_bone_map_from_skeleton: construyendo BoneMap para skeleton '%s'…" % skeleton.name)
	var profile := SkeletonProfileHumanoid.new()
	var bm := BoneMap.new()
	bm.profile = profile

	print("[VRM Converter] SkeletonProfileHumanoid contiene %d huesos:" % profile.bone_size)
	for i in range(profile.bone_size):
		print("[VRM Converter]   profile[%d]: %s (parent=%s)" % [i, profile.get_bone_name(i), profile.get_bone_parent(i)])

	if not bm.has_method("set_skeleton_bone_name"):
		push_warning("[VRM Converter] BoneMap no tiene el método set_skeleton_bone_name. El BoneMap se guardará sin asignaciones.")
		return bm

	var assigned_count := 0
	for i: int in skeleton.get_bone_count():
		var current_name: String = skeleton.get_bone_name(i)
		# 1) Intentar mapear desde nombres VRoid → VRM → Godot
		if VRoid_TO_VRM.has(current_name):
			var vrm_name: String = VRoid_TO_VRM[current_name]
			var godot_name: String = VRM_TO_GODOT.get(vrm_name, "")
			if godot_name != "":
				bm.set_skeleton_bone_name(godot_name, current_name)
				assigned_count += 1
				continue

		# 2) Si ya viene con nombre VRM estándar (hips, spine, etc.)
		for vrm_name: String in VRM_TO_GODOT:
			if vrm_name == current_name:
				var godot_name: String = VRM_TO_GODOT[vrm_name]
				bm.set_skeleton_bone_name(godot_name, current_name)
				assigned_count += 1
				break

		# 3) Si ya está en formato Godot humanoide
		var low: String = current_name.to_lower()
		if _godot_lower_to_canonical.has(low):
			var can: String = _godot_lower_to_canonical[low]
			bm.set_skeleton_bone_name(can, current_name)
			assigned_count += 1

	print("[VRM Converter] build_vrm1_bone_map_from_skeleton: asignadas %d entradas de BoneMap." % assigned_count)
	bm.resource_local_to_scene = false
	return bm


func build_vrm1_bone_map_from_gltf_state(gstate: GLTFState, skeleton: Skeleton3D) -> BoneMap:
	print("[VRM Converter] build_vrm1_bone_map_from_gltf_state: analizando gstate.json para VRMC_vrm/humanoid…")
	var json: Dictionary = gstate.json
	if not json.has("extensions") or not (json["extensions"] is Dictionary):
		print("[VRM Converter] build_vrm1_bone_map_from_gltf_state: no hay 'extensions' en json.")
		return build_vrm1_bone_map_from_skeleton(skeleton)

	var exts: Dictionary = json["extensions"]
	if not exts.has("VRMC_vrm") or not (exts["VRMC_vrm"] is Dictionary):
		print("[VRM Converter] build_vrm1_bone_map_from_gltf_state: no hay extensión 'VRMC_vrm'.")
		return build_vrm1_bone_map_from_skeleton(skeleton)

	var vrm1: Dictionary = exts["VRMC_vrm"]
	if not vrm1.has("humanoid") or not (vrm1["humanoid"] is Dictionary):
		print("[VRM Converter] build_vrm1_bone_map_from_gltf_state: no hay 'humanoid' en VRMC_vrm.")
		return build_vrm1_bone_map_from_skeleton(skeleton)

	var humanoid: Dictionary = vrm1["humanoid"]
	if not humanoid.has("humanBones"):
		print("[VRM Converter] build_vrm1_bone_map_from_gltf_state: no hay 'humanBones' en humanoid.")
		return build_vrm1_bone_map_from_skeleton(skeleton)

	var hb = humanoid["humanBones"]
	var vrm_to_actual: Dictionary = {}

	# VRM 1.0: humanBones suele ser un array de objetos { bone, node, ... }
	if hb is Array:
		for e in hb:
			if e is Dictionary and e.has("bone") and e.has("node"):
				var vrm_name: String = str(e["bone"])
				var node_idx: int = int(e["node"])
				if node_idx >= 0 and node_idx < json.get("nodes", []).size():
					var node_json: Dictionary = json["nodes"][node_idx]
					var actual_name: String = str(node_json.get("name", ""))
					if actual_name != "":
						vrm_to_actual[vrm_name] = actual_name
	else:
		# Por si VRoid usa un diccionario { boneName: { node: idx, ... } }
		if hb is Dictionary:
			for vrm_name in hb.keys():
				var e = hb[vrm_name]
				if e is Dictionary and e.has("node"):
					var node_idx: int = int(e["node"])
					if node_idx >= 0 and node_idx < json.get("nodes", []).size():
						var node_json: Dictionary = json["nodes"][node_idx]
						var actual_name: String = str(node_json.get("name", ""))
						if actual_name != "":
							vrm_to_actual[str(vrm_name)] = actual_name

	print("[VRM Converter] build_vrm1_bone_map_from_gltf_state: encontrados %d humanBones mapeados desde json." % vrm_to_actual.size())

	var profile := SkeletonProfileHumanoid.new()
	var bm := BoneMap.new()
	bm.profile = profile
	if not bm.has_method("set_skeleton_bone_name"):
		push_warning("[VRM Converter] BoneMap no tiene el método set_skeleton_bone_name. El BoneMap se guardará sin asignaciones.")
		return bm

	var assigned_count := 0
	for vrm_name in vrm_to_actual.keys():
		var actual: String = vrm_to_actual[vrm_name]
		var godot_name: String = VRM_TO_GODOT.get(vrm_name, "")
		if godot_name == "":
			continue
		# API correcta: asignar el nombre del hueso del Skeleton al hueso humanoide del perfil
		bm.set_skeleton_bone_name(godot_name, actual)
		assigned_count += 1

	print("[VRM Converter] build_vrm1_bone_map_from_gltf_state: asignadas %d entradas de BoneMap desde json." % assigned_count)
	bm.resource_local_to_scene = false
	return bm


func _is_vrm_1_0(root: Node) -> bool:
	var meta: Dictionary = _search_meta_recursive(root)
	if meta.is_empty():
		return false
	if meta.get("specVersion", "") == "1.0":
		return true
	if meta.has("humanBones") and meta["humanBones"] is Dictionary and not meta["humanBones"].is_empty():
		var sample = meta["humanBones"].values()[0]
		if sample is Dictionary and sample.has("node"):
			return true
	var skel: Skeleton3D = _find_skeleton(root)
	return skel != null and skel.find_bone("upperChest") >= 0

func _build_actual_to_godot(root: Node, skeleton: Skeleton3D) -> Dictionary:
	var result: Dictionary = {}
	var is_v1: bool = _is_vrm_1_0(root)
	
	# Estrategia 1: vrm_meta (si godot-vrm lo usó correctamente)
	var vrm_to_actual := _read_vrm_meta(root)
	if not vrm_to_actual.is_empty():
		for vrm_name: String in vrm_to_actual:
			var actual: String = str(vrm_to_actual[vrm_name])
			var godot_name: String = VRM_TO_GODOT.get(vrm_name, "")
			if godot_name != "" and actual != "":
				result[actual] = godot_name
		if not result.is_empty():
			print("[VRM Converter] Usando mapeo directo de vrm_meta (VRM %s)" % ("1.0" if is_v1 else "0.0"))
			return result

	# Estrategia 2 + VRoid mapping
	for i: int in range(skeleton.get_bone_count()):
		var bone_name: String = skeleton.get_bone_name(i)
		var bone_lower: String = bone_name.to_lower()
		
		# 1. Chequeo directo VRoid → VRM name
		if VRoid_TO_VRM.has(bone_name):
			var vrm_name: String = VRoid_TO_VRM[bone_name]
			var godot_name: String = VRM_TO_GODOT.get(vrm_name, "")
			if godot_name != "":
				result[bone_name] = godot_name
				continue
		
		# 2. Fallback genérico (por si algún nombre ya está en formato VRM)
		for vrm_name: String in VRM_TO_GODOT:
			if vrm_name.to_lower() == bone_lower:
				result[bone_name] = VRM_TO_GODOT[vrm_name]
				break
		
		# 3. Si ya es nombre Godot (raro)
		if _godot_lower_to_canonical.has(bone_lower):
			result[bone_name] = _godot_lower_to_canonical[bone_lower]

	if result.is_empty():
		push_warning("[VRM Converter] No se encontró NINGÚN mapeo válido")
	else:
		print("[VRM Converter] Encontrados %d mapeos de huesos (VRM %s)" % [result.size(), "1.0" if is_v1 else "0.0"])

	return result

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child: Node in node.get_children():
		var skel = _find_skeleton(child)
		if skel: return skel
	return null


func _search_meta_recursive(node: Node) -> Dictionary:
	if node.has_meta("vrm_meta"):
		var m = node.get_meta("vrm_meta")
		return m if m is Dictionary else {}
	for child: Node in node.get_children():
		var meta = _search_meta_recursive(child)
		if not meta.is_empty(): return meta
	return {}


func _read_vrm_meta(root: Node) -> Dictionary:
	var meta: Dictionary = _search_meta_recursive(root)
	if meta.is_empty(): return {}
	
	var bone_map: Dictionary = {}
	
	# VRM 0.x
	if meta.has("humanoid") and meta["humanoid"] is Dictionary and meta["humanoid"].has("humanBones"):
		var hb = meta["humanoid"]["humanBones"]
		for key: String in hb:
			var e = hb[key]
			if e is Dictionary and e.has("node"):
				bone_map[key] = e["node"]   # ← CORREGIDO
	
	# VRM 1.0
	elif meta.has("humanBones") and meta["humanBones"] is Dictionary:
		for key: String in meta["humanBones"]:
			var e = meta["humanBones"][key]
			if e is Dictionary and e.has("node"):
				bone_map[key] = e["node"]   # ← CORREGIDO
	
	return bone_map


func _update_animation_players(root: Node, old_path: String, new_path: String, renamed: Dictionary) -> void:
	for child: Node in root.get_children():
		if child is AnimationPlayer:
			var player: AnimationPlayer = child
			for anim_name: String in player.get_animation_list():
				var anim: Animation = player.get_animation(anim_name)
				if not anim: continue
				for t: int in anim.get_track_count():
					var p: NodePath = anim.track_get_path(t)
					var ps: String = str(p)
					if ps.begins_with(old_path):
						anim.track_set_path(t, NodePath(ps.replace(old_path, new_path)))
					if renamed.is_empty(): continue
					var bone_part: String = ps.get_slice(":", -1) if ":" in ps else ""
					if bone_part in renamed:
						var nb: String = renamed[bone_part]
						anim.track_set_path(t, NodePath(ps.replace(bone_part, nb)))
		
		_update_animation_players(child, old_path, new_path, renamed)


func _build_bone_map(skeleton: Skeleton3D) -> BoneMap:
	var profile := SkeletonProfileHumanoid.new()
	var bm := BoneMap.new()
	bm.profile = profile

	# Verificar si el método set_bone_name existe (evita error en versiones antiguas)
	if not bm.has_method("set_bone_name"):
		push_warning("[VRM Converter] BoneMap no tiene el método set_bone_name. El BoneMap se guardará sin asignaciones.")
		return bm

	for i: int in skeleton.get_bone_count():
		var bn: String = skeleton.get_bone_name(i)
		var low: String = bn.to_lower()
		if _godot_lower_to_canonical.has(low):
			var can: String = _godot_lower_to_canonical[low]
			var idx: int = profile.find_bone(can)
			if idx >= 0:
				bm.set_bone_name(idx, bn)

	# ← NUEVO: evitar que quede atado a la escena localmente
	bm.resource_local_to_scene = false

	return bm

func _update_skin_binds(skeleton: Skeleton3D, renamed: Dictionary) -> void:
	if renamed.is_empty():
		return
	
	# Recorremos todas las MeshInstance3D bajo el skeleton
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(skeleton, meshes)
	
	for mesh: MeshInstance3D in meshes:
		var skin: Skin = mesh.skin
		if skin == null:
			continue
		
		var bind_count: int = skin.get_bind_count()
		for i: int in range(bind_count):
			var old_name: String = skin.get_bind_name(i)
			if renamed.has(old_name):
				var new_name: String = renamed[old_name]
				skin.set_bind_name(i, new_name)
				print("[VRM Converter] Actualizado skin bind: %s → %s (mesh: %s)" % [old_name, new_name, mesh.name])

func _collect_meshes(node: Node, out_meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out_meshes.append(node)
	for child: Node in node.get_children():
		_collect_meshes(child, out_meshes)


# ==================== NUEVA FUNCIÓN MEJORADA ====================
func _apply_t_pose_to_rest(skeleton: Skeleton3D) -> void:
	print("[VRM Converter] Aplicando corrección de T-Pose a la rest pose...")

	# Guardar rest poses originales antes de cualquier cambio
	var original_rests: Array[Transform3D] = []
	for i in skeleton.get_bone_count():
		original_rests.append(skeleton.get_bone_rest(i))

	# Definir correcciones (valores típicos para VRoid)
	var corrections = {
	#	"LeftShoulder":  Transform3D(Basis(Vector3(0, 1, 0), deg_to_rad(10)), Vector3.ZERO),
	#	"RightShoulder": Transform3D(Basis(Vector3(0, 1, 0), deg_to_rad(-10)), Vector3.ZERO),
	#	"LeftUpperArm":  Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(-90)), Vector3.ZERO),
	#	"RightUpperArm": Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(90)), Vector3.ZERO),
		# Opcional: si las piernas vienen flexionadas, descomentar y ajustar
		# "LeftUpperLeg":  Transform3D(Basis(), Vector3.ZERO),
		# "RightUpperLeg": Transform3D(Basis(), Vector3.ZERO),
	}

	# 1. Aplicar correcciones como poses solo a huesos existentes
	for bone_name in corrections:
		var bone_idx = skeleton.find_bone(bone_name)
		if bone_idx >= 0:
			skeleton.set_bone_pose(bone_idx, corrections[bone_name])
		else:
			print("[VRM Converter] Hueso no encontrado para corrección T-Pose: ", bone_name)

	# 2. Hornear: la pose actual se convierte en la nueva rest pose
	for i in skeleton.get_bone_count():
		skeleton.set_bone_rest(i, skeleton.get_bone_pose(i))

	# 3. NO resetear poses a IDENTITY (para mantener la pose visual)

	# 4. Actualizar bind poses de los skins para que coincidan con la nueva rest
	_update_skin_bind_poses(skeleton, original_rests)

	skeleton.force_update_all_bone_transforms()
	print("[VRM Converter] ✓ Rest pose actualizada a T-Pose (bind poses recalculadas)")


func _update_skin_bind_poses(skeleton: Skeleton3D, original_rests: Array[Transform3D]) -> void:
	"""Recalcula las bind poses de todos los skins para que la apariencia del mesh no cambie
	   después de modificar la rest pose."""
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(skeleton, meshes)
	for mesh in meshes:
		var skin: Skin = mesh.skin
		if skin == null:
			continue
		var bind_count := skin.get_bind_count()
		for i in range(bind_count):
			var bone_name := skin.get_bind_name(i)
			var bone_idx := skeleton.find_bone(bone_name)
			if bone_idx < 0:
				continue
			# Bind pose original (relativa a la rest original)
			var original_bind: Transform3D = skin.get_bind_pose(i)
			# Rest original de ese hueso
			var original_rest: Transform3D = original_rests[bone_idx]
			# Nueva rest
			var new_rest: Transform3D = skeleton.get_bone_rest(bone_idx)
			# La nueva bind pose debe satisfacer: new_rest * new_bind = original_rest * original_bind
			# Por tanto: new_bind = new_rest.affine_inverse() * original_rest * original_bind
			var new_bind: Transform3D = new_rest.affine_inverse() * original_rest * original_bind
			skin.set_bind_pose(i, new_bind)