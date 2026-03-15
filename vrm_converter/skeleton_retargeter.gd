@tool
## SkeletonRetargeter: renombra huesos VRM a Godot SkeletonProfileHumanoid.
## Usa vrm_meta si existe; si no, infiere por nombres. Actualiza AnimationPlayers y guarda BoneMap.

extends RefCounted

const GENERAL_SKELETON_NAME := "GeneralSkeleton"

## VRM bone name → Godot SkeletonProfileHumanoid bone name
const VRM_TO_GODOT: Dictionary = {
	"hips": "Hips", "spine": "Spine", "chest": "Chest",
	"upperChest": "UpperChest", "neck": "Neck", "head": "Head",
	"leftEye": "LeftEye", "rightEye": "RightEye", "jaw": "Jaw",
	"leftShoulder": "LeftShoulder", "leftUpperArm": "LeftUpperArm",
	"leftLowerArm": "LeftLowerArm", "leftHand": "LeftHand",
	"rightShoulder": "RightShoulder", "rightUpperArm": "RightUpperArm",
	"rightLowerArm": "RightLowerArm", "rightHand": "RightHand",
	"leftUpperLeg": "LeftUpperLeg", "leftLowerLeg": "LeftLowerLeg",
	"leftFoot": "LeftFoot", "leftToes": "LeftToes",
	"rightUpperLeg": "RightUpperLeg", "rightLowerLeg": "RightLowerLeg",
	"rightFoot": "RightFoot", "rightToes": "RightToes",
	"leftThumbProximal": "LeftThumbMetacarpal",
	"leftThumbIntermediate": "LeftThumbProximal",
	"leftThumbDistal": "LeftThumbDistal",
	"leftIndexProximal": "LeftIndexProximal",
	"leftIndexIntermediate": "LeftIndexIntermediate",
	"leftIndexDistal": "LeftIndexDistal",
	"leftMiddleProximal": "LeftMiddleProximal",
	"leftMiddleIntermediate": "LeftMiddleIntermediate",
	"leftMiddleDistal": "LeftMiddleDistal",
	"leftRingProximal": "LeftRingProximal",
	"leftRingIntermediate": "LeftRingIntermediate",
	"leftRingDistal": "LeftRingDistal",
	"leftLittleProximal": "LeftLittleProximal",
	"leftLittleIntermediate": "LeftLittleIntermediate",
	"leftLittleDistal": "LeftLittleDistal",
	"rightThumbProximal": "RightThumbMetacarpal",
	"rightThumbIntermediate": "RightThumbProximal",
	"rightThumbDistal": "RightThumbDistal",
	"rightIndexProximal": "RightIndexProximal",
	"rightIndexIntermediate": "RightIndexIntermediate",
	"rightIndexDistal": "RightIndexDistal",
	"rightMiddleProximal": "RightMiddleProximal",
	"rightMiddleIntermediate": "RightMiddleIntermediate",
	"rightMiddleDistal": "RightMiddleDistal",
	"rightRingProximal": "RightRingProximal",
	"rightRingIntermediate": "RightRingIntermediate",
	"rightRingDistal": "RightRingDistal",
	"rightLittleProximal": "RightLittleProximal",
	"rightLittleIntermediate": "RightLittleIntermediate",
	"rightLittleDistal": "RightLittleDistal",
	"leftThumbMetacarpal": "LeftThumbMetacarpal",
	"rightThumbMetacarpal": "RightThumbMetacarpal",
}

## Godot SkeletonProfileHumanoid bone name en minúsculas → nombre canónico
## Para resolver casos donde el hueso ya se llama igual que el destino pero
## con diferente capitalización
var _godot_lower_to_canonical: Dictionary = {}


func process(root: Node, base_path: String) -> BoneMap:
	for vrm_name in VRM_TO_GODOT:
		var godot_name: String = VRM_TO_GODOT[vrm_name]
		_godot_lower_to_canonical[godot_name.to_lower()] = godot_name

	var skeleton := _find_skeleton(root)
	if skeleton == null:
		push_error("[VRM Converter] SkeletonRetargeter: no se encontró Skeleton3D")
		return null

	# 1. Construir mapa: nombre_actual_en_skeleton → nombre_godot
	var actual_to_godot := _build_actual_to_godot(root, skeleton)

	if actual_to_godot.is_empty():
		push_error("[VRM Converter] No se pudo construir bone mapping")
		return null

	# 2. Renombrar huesos
	var renamed: Dictionary = {}
	for i in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(i)
		if actual_to_godot.has(bone_name):
			var new_name: String = actual_to_godot[bone_name]
			if bone_name != new_name:
				if skeleton.find_bone(new_name) >= 0:
					continue
				skeleton.set_bone_name(i, new_name)
				renamed[bone_name] = new_name

	# 3. Renombrar nodo Skeleton3D → GeneralSkeleton
	var old_skel_node_name := skeleton.name
	skeleton.name = GENERAL_SKELETON_NAME
	var new_skel_path_str := String(root.get_path_to(skeleton))
	var old_skel_path_str := new_skel_path_str.replace(GENERAL_SKELETON_NAME, old_skel_node_name)

	# ── 4. Actualizar AnimationPlayers ────────────────────────────────────────
	if not renamed.is_empty() or old_skel_node_name != GENERAL_SKELETON_NAME:
		_update_animation_players(root, old_skel_path_str, new_skel_path_str, renamed)

	# ── 5. Crear carpeta si no existe y guardar BoneMap ───────────────────────
	var model_name := base_path.get_file()
	var out_dir    := base_path.get_base_dir().path_join(model_name) + "/"
	var abs_dir    := ProjectSettings.globalize_path(out_dir)
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)

	var bone_map := _build_bone_map(skeleton)
	var bmap_path := out_dir + model_name + "_bone_map.tres"
	bone_map.take_over_path(bmap_path)
	var err := ResourceSaver.save(bone_map, bmap_path)
	if err == OK:
		if Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().update_file(bmap_path)
		bone_map = ResourceLoader.load(bmap_path, "", ResourceLoader.CACHE_MODE_REPLACE) as BoneMap
	else:
		push_error("[VRM Converter] No se pudo guardar BoneMap: %s (err=%d)" % [bmap_path, err])

	return bone_map


# ─── Construir actual_to_godot ────────────────────────────────────────────────
## Combina tres estrategias en orden de prioridad:
## 1. vrm_meta humanoid_bone_mapping (mapeo exacto del VRM)
## 2. Nombre del hueso es ya un nombre VRM conocido (hips, spine, leftUpperArm…)
## 3. Nombre del hueso es ya el nombre Godot pero con diferente capitalización

func _build_actual_to_godot(root: Node, skeleton: Skeleton3D) -> Dictionary:
	var result: Dictionary = {}

	# Estrategia 1: leer vrm_meta
	var vrm_to_actual := _read_vrm_meta(root)
	if not vrm_to_actual.is_empty():
		for vrm_name in vrm_to_actual:
			var actual: String = str(vrm_to_actual[vrm_name])
			var godot_name: String = VRM_TO_GODOT.get(vrm_name, "")
			if godot_name != "" and actual != "":
				result[actual] = godot_name
		if not result.is_empty():
			return result

	# Estrategia 2 y 3: analizar nombres de huesos del skeleton directamente
	for i in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(i)
		var bone_lower := bone_name.to_lower()

		for vrm_name in VRM_TO_GODOT:
			if vrm_name.to_lower() == bone_lower:
				result[bone_name] = VRM_TO_GODOT[vrm_name]
				break

		if not result.has(bone_name) and _godot_lower_to_canonical.has(bone_lower):
			var canonical: String = _godot_lower_to_canonical[bone_lower]
			if bone_name != canonical:
				result[bone_name] = canonical

	return result


# ─── Leer vrm_meta ────────────────────────────────────────────────────────────

func _read_vrm_meta(root: Node) -> Dictionary:
	return _search_meta_recursive(root)


func _search_meta_recursive(node: Node) -> Dictionary:
	for key in node.get_meta_list():
		var val = node.get_meta(key)

		if key == &"humanoid_bone_mapping" and val is Dictionary:
			return val

		if key == &"vrm_meta":
			if val is Dictionary:
				var hbm = val.get("humanoid_bone_mapping", {})
				if hbm is Dictionary and not hbm.is_empty():
					return hbm
				var hb = val.get("humanBones", {})
				if hb is Dictionary and not hb.is_empty():
					var mapping: Dictionary = {}
					for bone_key in hb:
						mapping[bone_key] = bone_key
					return mapping
			elif val is Resource:
				for prop in ["humanoid_bone_mapping", "humanBones"]:
					if prop in val:
						var hbm = val.get(prop)
						if hbm is Dictionary and not hbm.is_empty():
							return hbm

		if val is Dictionary and val.has("hips") and val["hips"] is String:
			return val

	for child in node.get_children():
		var r := _search_meta_recursive(child)
		if not r.is_empty():
			return r

	return {}


# ─── Actualizar AnimationPlayers ──────────────────────────────────────────────

func _update_animation_players(root: Node, old_skel_path: String, new_skel_path: String, renamed_bones: Dictionary) -> void:
	var players: Array[AnimationPlayer] = []
	_collect_animation_players(root, players)

	for ap in players:
		var total_updated := 0
		for lib_name in ap.get_animation_library_list():
			var lib := ap.get_animation_library(lib_name)
			if lib == null:
				continue
			var lib_dirty := false
			for anim_name in lib.get_animation_list():
				var anim := lib.get_animation(anim_name)
				if anim == null:
					continue
				for track_idx in range(anim.get_track_count()):
					var old_path_str := String(anim.track_get_path(track_idx))
					var new_path_str := old_path_str

					if old_skel_path != new_skel_path:
						new_path_str = new_path_str.replace(old_skel_path + ":", new_skel_path + ":")
						new_path_str = new_path_str.replace(old_skel_path + "/", new_skel_path + "/")
						var old_node := old_skel_path.get_file()
						if old_node != GENERAL_SKELETON_NAME:
							new_path_str = new_path_str.replace(old_node + ":", GENERAL_SKELETON_NAME + ":")

					for old_bone in renamed_bones:
						new_path_str = new_path_str.replace(":" + old_bone, ":" + renamed_bones[old_bone])

					if new_path_str != old_path_str:
						anim.track_set_path(track_idx, NodePath(new_path_str))
						total_updated += 1
						lib_dirty = true

			if lib_dirty and lib.resource_path != "":
				ResourceSaver.save(lib, lib.resource_path)

		if total_updated > 0:
			print("[VRM Converter]   AnimationPlayer '%s': %d tracks actualizados" % [ap.name, total_updated])


func _collect_animation_players(node: Node, result: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		result.append(node as AnimationPlayer)
	for child in node.get_children():
		_collect_animation_players(child, result)


# ─── BoneMap ──────────────────────────────────────────────────────────────────

func _build_bone_map(skeleton: Skeleton3D) -> BoneMap:
	var profile := SkeletonProfileHumanoid.new()
	var bone_map := BoneMap.new()
	bone_map.profile = profile
	for i in range(profile.bone_size):
		var pname: StringName = profile.get_bone_name(i)
		if skeleton.find_bone(pname) >= 0:
			bone_map.set_skeleton_bone_name(pname, pname)
	return bone_map


func _count_mapped_bones(bone_map: BoneMap) -> int:
	if bone_map == null or bone_map.profile == null:
		return 0
	var count := 0
	for i in range(bone_map.profile.bone_size):
		var pname: StringName = bone_map.profile.get_bone_name(i)
		if bone_map.get_skeleton_bone_name(pname) != &"":
			count += 1
	return count


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var r := _find_skeleton(child)
		if r != null:
			return r
	return null
