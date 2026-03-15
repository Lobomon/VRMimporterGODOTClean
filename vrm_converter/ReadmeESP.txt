VRM Converter para Godot Engine

Autor: Jorge Guillermo Flores

Un potente complemento para Godot 4.x que convierte automáticamente archivos VRM importados a formatos GLB + TSCN optimizados, reduciendo drásticamente el tamaño de los archivos (p. ej., de 100 MB a 10–20 MB) mientras conserva toda la funcionalidad. También incluye un conmutador de materiales en tiempo de ejecución para alternar entre materiales MToon (toon) y StandardPBR.
Características

    Conversión automática de VRM – Reemplaza el importador VRM predeterminado y procesa cada archivo VRM tan pronto como se importa.

    Optimización de tamaño – Externaliza mallas, pieles (skins), materiales y texturas en archivos .tres/.res separados, registra UIDs y comprime texturas usando Basis Universal. Esto evita la incrustación en línea y reduce el tamaño final de la escena.

    Reorientación del esqueleto – Renombra los huesos VRM para que coincidan con la nomenclatura de SkeletonProfileHumanoid de Godot. Actualiza todas las pistas de animación correspondientes y guarda un recurso BoneMap.

    Conversión de materiales – Convierte materiales shader MToon a StandardMaterial3D. Opcionalmente conserva el material MToon original y almacena el fallback Standard como metadato para cambiar en tiempo de ejecución.

    Limpieza de metadatos – Elimina metadatos VRM innecesarios (miniaturas, etc.) pero preserva la información esencial de mapeo de huesos.

    Exportación GLB – Copia el archivo VRM original como GLB plano (glTF binario) para compatibilidad con otras herramientas.

    Conmutador de materiales en tiempo de ejecución – Incluye un script VRMaterialSwitcher que permite cambiar entre materiales MToon y Standard en tiempo de ejecución (por ejemplo, para rendimiento o cambio de estilo visual).

Requisitos

    Godot Engine 4.2+ (probado con 4.2.1 y posteriores)

    Complemento godot-vrm – debe estar habilitado antes de instalar este complemento.

Instalación

    Instalar godot-vrm

        Descarga o clona godot-vrm en la carpeta addons/ de tu proyecto.

        Habilítalo en Proyecto → Configuración del proyecto → Complementos.

    Instalar VRM Converter

        Copia la carpeta addons/vrm_converter de este repositorio a la carpeta addons/ de tu proyecto.

        Habilita VRM Converter en la lista de complementos (reemplazará automáticamente al importador VRM predeterminado).

    Reinicia el editor para asegurarte de que todo cargue correctamente.

Uso

Una vez instalado, simplemente coloca cualquier archivo .vrm dentro de la carpeta de tu proyecto. El editor lo importará automáticamente usando el conversor.
Opciones de importación

Puedes ajustar la configuración de conversión en el panel Importar después de seleccionar un archivo VRM:

    vrm_converter/export_glb – Indica si también se debe guardar una copia en .glb plano del VRM (habilitado por defecto).

    vrm_converter/export_tscn – Indica si se debe generar una escena .tscn optimizada (habilitado por defecto).

    vrm_converter/keep_mtoon_shader – Conserva los materiales shader MToon originales y adjunta la versión Standard como metadato.

    vrm_converter/generate_standard_fallback – Genera fallbacks StandardMaterial3D incluso si keep_mtoon está activado.

    vrm/head_hiding_method – Controla cómo se maneja la ocultación de la cabeza en primera persona (igual que en godot-vrm).

    vrm/only_if_head_hiding_uses_layers/… – Configuración de capas para la ocultación de la cabeza.

Estructura de salida

Para un archivo VRM en res://models/avatar.vrm, el conversor crea:
text

res://models/
├── avatar.glb                    # Copia GLB plana (si export_glb está activado)
├── avatar/                        # Carpeta con recursos externalizados
│   ├── avatar_converted.tscn      # Escena principal optimizada
│   ├── avatar_mesh_0.tres         # Mallas externalizadas
│   ├── avatar_skin_0.tres         # Pieles externalizadas
│   ├── avatar_mat_0.tres          # Materiales externalizados
│   ├── avatar_tex_0.tres          # Texturas en formato Basis Universal
│   ├── avatar_anims_...tres       # Librerías de animación externalizadas
│   └── avatar_bone_map.tres       # BoneMap para reorientación

Conmutación de materiales en tiempo de ejecución

Adjunta el script VRMaterialSwitcher a cualquier nodo que sea ancestro de tu modelo VRM (por ejemplo, el nodo raíz del VRM). Luego puedes llamar:
gdscript

var switcher = VRMaterialSwitcher.new()
add_child(switcher)
switcher.target_root = $TuRaizVRM   # opcional, por defecto el padre

# Cambiar a materiales Standard
switcher.use_standard()

# Volver a MToon
switcher.use_mtoon()

# Alternar entre ellos
switcher.toggle()

El conmutador escanea automáticamente los hijos MeshInstance3D y guarda en caché los materiales que tienen metadatos standard_fallback (escritos por el conversor durante la importación).
Cómo funciona

    Intercepción de importación – vrm_import_converter.gd extiende EditorSceneFormatImporter y reemplaza al importador VRM estándar.

    Copia GLB – El VRM original (que es un GLB válido) se copia tal cual.

    Generación de escena – El VRM se carga mediante godot-vrm y la escena resultante se procesa:

        Reorientación del esqueleto – Los huesos se renombran para coincidir con el perfil humanoide de Godot, las pistas de animación se actualizan.

        Externalización de recursos – Todas las mallas, pieles, materiales y texturas se guardan como archivos separados con UIDs.

        Conversión de materiales – Los shaders MToon se convierten a StandardMaterial3D (opcional).

        Limpieza de metadatos – Se eliminan metadatos VRM innecesarios.

    Creación de PackedScene – El árbol de nodos aplanado se empaqueta y guarda como un archivo .tscn con rutas relativas.

¿Por qué usar este complemento?

    Reducción masiva de tamaño – Externalizar recursos y comprimir texturas puede reducir las importaciones VRM en un 80–90%.

    Esqueleto amigable con Godot – Los huesos se renombran para coincidir con el perfil humanoide de Godot, facilitando la reorientación y animación.

    Flexibilidad de materiales – Conserva el aspecto MToon original o usa un fallback Standard; cambia en tiempo de ejecución.

    Estructura de proyecto limpia – No más recursos enormes incrustados dentro del archivo de escena.

Licencia

Este complemento se proporciona bajo la Licencia MIT. Consulta el archivo LICENSE para más detalles.
Agradecimientos

    godot-vrm – El importador VRM principal para Godot.

    La comunidad de Godot por su continuo apoyo.

¡Disfrútalo! Si encuentras algún problema o tienes sugerencias, no dudes en abrir un issue o contribuir.