VRM Converter for Godot Engine

Author: Jorge Guillermo Flores

A powerful Godot 4.x plugin that automatically converts imported VRM files into optimized GLB + TSCN formats, drastically reducing file sizes (e.g., from 100 MB to 10–20 MB) while preserving full functionality. It also provides a runtime material switcher to toggle between MToon (toon) and StandardPBR materials.
Features

    Automatic VRM conversion – Replaces the default VRM importer and processes every VRM file as soon as it is imported.

    Size optimization – Externalizes meshes, skins, materials, and textures into separate .tres/.res files, registers UIDs, and compresses textures using Basis Universal. This avoids inline embedding and reduces final scene size.

    Skeleton retargeting – Renames VRM bones to match Godot's SkeletonProfileHumanoid naming convention. Updates all animation tracks accordingly and saves a BoneMap resource.

    Material conversion – Converts MToon shader materials to StandardMaterial3D. Optionally keeps the original MToon material and stores the Standard fallback as metadata for runtime switching.

    Metadata cleaning – Strips unnecessary VRM metadata (thumbnails, etc.) but preserves essential bone mapping data.

    GLB export – Copies the original VRM file as a plain GLB (binary glTF) for compatibility with other tools.

    Runtime material switcher – Includes a VRMaterialSwitcher node script that lets you switch between MToon and Standard materials at runtime (e.g., for performance or visual style toggling).

Requirements

    Godot Engine 4.2+ (tested with 4.2.1 and later)

    godot-vrm addon – must be enabled before installing this plugin.

Installation

    Install godot-vrm

        Download or clone godot-vrm into your project’s addons/ folder.

        Enable it in Project → Project Settings → Plugins.

    Install VRM Converter

        Copy the addons/vrm_converter folder from this repository into your project’s addons/ folder.

        Enable VRM Converter in the plugin list (it will automatically replace the default VRM importer).

    Restart the editor to ensure everything loads correctly.

Usage

Once installed, simply place any .vrm file inside your project folder. The editor will automatically import it using the converter.
Import Options

You can adjust conversion settings in the Import dock after selecting a VRM file:

    vrm_converter/export_glb – Whether to also save a plain .glb copy of the VRM (enabled by default).

    vrm_converter/export_tscn – Whether to generate an optimized .tscn scene (enabled by default).

    vrm_converter/keep_mtoon_shader – Keep the original MToon shader materials and attach the Standard version as metadata.

    vrm_converter/generate_standard_fallback – Generate StandardMaterial3D fallbacks even if keep_mtoon is true.

    vrm/head_hiding_method – Controls how first‑person head hiding is handled (same as in godot-vrm).

    vrm/only_if_head_hiding_uses_layers/… – Layer settings for head hiding.

Output Structure

For a VRM file at res://models/avatar.vrm, the converter creates:
text

res://models/
├── avatar.glb                    # Plain GLB copy (if export_glb enabled)
├── avatar/                        # Folder with externalized resources
│   ├── avatar_converted.tscn      # Main optimized scene
│   ├── avatar_mesh_0.tres         # External meshes
│   ├── avatar_skin_0.tres         # External skins
│   ├── avatar_mat_0.tres          # External materials
│   ├── avatar_tex_0.tres          # Basis Universal textures
│   ├── avatar_anims_...tres       # External animation libraries
│   └── avatar_bone_map.tres       # BoneMap for retargeting

Runtime Material Switching

Attach the VRMaterialSwitcher script to any node that is an ancestor of your VRM model (e.g., the root node of the VRM). Then you can call:
gdscript

var switcher = VRMaterialSwitcher.new()
add_child(switcher)
switcher.target_root = $YourVRMRoot   # optional, defaults to parent

# Switch to Standard materials
switcher.use_standard()

# Switch back to MToon
switcher.use_mtoon()

# Toggle between them
switcher.toggle()

The switcher automatically scans for MeshInstance3D children and caches materials that have a standard_fallback metadata (written by the converter during import).
How It Works

    Import interception – vrm_import_converter.gd extends EditorSceneFormatImporter and replaces the standard VRM importer.

    GLB copy – The original VRM (which is a valid GLB) is copied as-is.

    Scene generation – The VRM is loaded via godot-vrm, and the resulting scene is processed:

        Skeleton retargeting – Bones are renamed to Godot’s humanoid profile, animation tracks updated.

        Resource externalization – All meshes, skins, materials, and textures are saved as separate files with UIDs.

        Material conversion – MToon shaders are baked into StandardMaterial3D (optional).

        Metadata cleanup – Unnecessary VRM metadata is stripped.

    PackedScene creation – The flattened node tree is packed and saved as a .tscn file with relative paths.

Why Use This Plugin?

    Massive file size reduction – Externalizing resources and compressing textures can shrink VRM imports by 80–90%.

    Godot‑friendly skeleton – Bones are renamed to match Godot’s humanoid profile, making retargeting and animation easier.

    Material flexibility – Keep the original MToon look or use a Standard fallback; switch at runtime.

    Clean project structure – No more huge inline resources inside the scene file.

License

This plugin is provided under the MIT License. See the LICENSE file for details.
Acknowledgements

    godot-vrm – The core VRM importer for Godot.

    The Godot community for continuous support.

Enjoy! If you encounter any issues or have suggestions, feel free to open an issue or contribute.
