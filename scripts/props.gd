extends RefCounted
## Chargement, matériaux et mesures des modèles du pack Halloween Bits.
##
## - Si la texture du pack (halloweenbits_texture.png) est présente dans
##   assets/halloween/, elle est appliquée automatiquement.
## - Sinon, chaque modèle reçoit une couleur de secours choisie d'après son nom.
## - Si un modèle est introuvable, un cube de remplacement est utilisé.
## - Toutes les tailles sont mesurées à l'exécution : le jeu fonctionne quelle que
##   soit l'échelle d'import des fichiers FBX.

const HALLOWEEN_DIR := "res://assets/halloween/"
const TEXTURE_PATH := "res://assets/halloween/halloweenbits_texture.png"
const REF_MODEL := "gravestone.fbx"
const REF_HEIGHT := 1.25   # hauteur (en mètres) donnée à la pierre tombale de référence

# L'ordre compte : le premier mot-clé trouvé dans le nom de fichier gagne.
const FALLBACK_COLORS := [
	["jackolantern", Color(1.0, 0.42, 0.06)],
	["yellow", Color(0.88, 0.66, 0.12)],
	["pumpkin", Color(0.95, 0.40, 0.07)],
	["pine", Color(0.72, 0.36, 0.10)],
	["tree", Color(0.20, 0.15, 0.12)],
	["candle", Color(0.93, 0.88, 0.72)],
	["lantern", Color(0.90, 0.62, 0.20)],
	["post", Color(0.35, 0.24, 0.16)],
	["skull", Color(0.90, 0.88, 0.80)],
	["bone", Color(0.90, 0.88, 0.80)],
	["ribcage", Color(0.90, 0.88, 0.80)],
	["coffin", Color(0.30, 0.20, 0.14)],
	["bench", Color(0.35, 0.24, 0.16)],
	["fence", Color(0.20, 0.20, 0.25)],
	["arch", Color(0.22, 0.22, 0.27)],
	["pillar", Color(0.40, 0.40, 0.45)],
	["crypt", Color(0.40, 0.40, 0.46)],
	["floor", Color(0.22, 0.17, 0.12)],
	["grave", Color(0.45, 0.46, 0.50)],
	["plaque", Color(0.45, 0.46, 0.50)],
	["shrine", Color(0.45, 0.46, 0.50)],
	["path", Color(0.40, 0.38, 0.36)],
]

static var _scale_k := -1.0
static var _textured: StandardMaterial3D = null
static var _color_mats := {}


static func texture_available() -> bool:
	return ResourceLoader.exists(TEXTURE_PATH)


## Instancie un modèle du pack (avec matériau). Ne renvoie jamais null.
static func spawn(file_name: String) -> Node3D:
	var root: Node3D = null
	var path := HALLOWEEN_DIR + file_name
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is PackedScene:
			root = (res as PackedScene).instantiate() as Node3D
	if root == null:
		root = _placeholder()
	var mat := _material_for(file_name)
	for mi in find_meshes(root):
		var mesh_inst := mi as MeshInstance3D
		mesh_inst.material_override = mat
	return root


## Facteur d'échelle global : ramène la pierre tombale de référence à REF_HEIGHT.
## Appliqué à tous les décors pour garder leurs proportions d'origine.
static func prop_scale() -> float:
	if _scale_k > 0.0:
		return _scale_k
	var ref := spawn(REF_MODEL)
	var h := local_aabb(ref).size.y
	ref.free()
	_scale_k = (REF_HEIGHT / h) if h > 0.001 else 1.0
	return _scale_k


## Modèle redimensionné à `height` mètres, centré sur son pivot (pas de décalage).
## center_vertical = false : le bas du modèle touche y = 0. true : centré en hauteur aussi.
static func make_fitted(file_name: String, height: float, center_vertical: bool) -> Node3D:
	var model := spawn(file_name)
	var aabb := local_aabb(model)
	var s := height / maxf(aabb.size.y, 0.001)
	model.scale = Vector3.ONE * s
	var cy := -aabb.position.y * s
	if center_vertical:
		cy = -(aabb.position.y + aabb.size.y * 0.5) * s
	model.position = Vector3(
		-(aabb.position.x + aabb.size.x * 0.5) * s,
		cy,
		-(aabb.position.z + aabb.size.z * 0.5) * s
	)
	var pivot := Node3D.new()
	pivot.add_child(model)
	return pivot


## Boîte englobante d'un modèle dans son propre repère (sans tenir compte de l'échelle de `root`).
static func local_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mi in find_meshes(root):
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst.mesh == null:
			continue
		var box: AABB = _relative_transform(mesh_inst, root) * mesh_inst.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	if first:
		return AABB(Vector3(-0.5, 0.0, -0.5), Vector3.ONE)
	return result


static func find_meshes(root: Node) -> Array:
	var out: Array = []
	_collect_meshes(root, out)
	return out


## Rend un modèle lumineux (émission) : utile pour les ennemis et les objets à ramasser.
static func make_glow(root: Node, color: Color, energy: float) -> void:
	for mi in find_meshes(root):
		var mesh_inst := mi as MeshInstance3D
		var m: StandardMaterial3D = null
		if mesh_inst.material_override is StandardMaterial3D:
			m = (mesh_inst.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		else:
			m = StandardMaterial3D.new()
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		mesh_inst.material_override = m


static func _collect_meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_meshes(child, out)


static func _relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


static func _placeholder() -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	mi.mesh = box
	mi.position = Vector3(0.0, 0.5, 0.0)
	root.add_child(mi)
	return root


static func _material_for(file_name: String) -> StandardMaterial3D:
	if texture_available():
		if _textured == null:
			_textured = StandardMaterial3D.new()
			_textured.albedo_texture = load(TEXTURE_PATH) as Texture2D
			_textured.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			_textured.roughness = 0.9
		return _textured
	var color := _fallback_color(file_name)
	var key := color.to_html()
	if not _color_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.9
		_color_mats[key] = m
	return _color_mats[key]


static func _fallback_color(file_name: String) -> Color:
	var n := file_name.to_lower()
	for entry in FALLBACK_COLORS:
		if n.contains(String(entry[0])):
			return entry[1]
	return Color(0.5, 0.5, 0.5)
