extends Node3D
## Le cimetière : sol, enceinte, tombes, arbres, lanternes, décors.
## Généré par le code avec une graine fixe : la carte est identique à chaque partie.

const Props = preload("res://scripts/props.gd")

const ARENA := 34.0                       # demi-côté de l'aire de jeu (en mètres)
const START_POS := Vector3(0.0, 0.1, 22.0)  # position de départ du joueur

var _rng := RandomNumberGenerator.new()
var _taken := PackedVector3Array()        # zones occupées : (x, z, rayon)


func build() -> void:
	_rng.seed = 20261031
	# Zones à garder dégagées : départ du joueur, allée centrale, crypte.
	_reserve(START_POS, 7.0)
	for z in range(-18, 25, 4):
		_reserve(Vector3(0.0, 0.0, float(z)), 2.6)
	_reserve(Vector3(0.0, 0.0, -ARENA + 8.0), 9.0)

	_build_ground()
	_build_walls()
	_build_fence()
	_build_landmarks()
	_build_graves()
	_build_decor()
	_build_forest()


## Point libre (hors des props) pris au hasard dans l'aire de jeu, à au moins min_dist de `avoid`.
func random_open_point(avoid: Vector3, min_dist: float, clear: float = 1.0) -> Vector3:
	for i in range(60):
		var p := Vector3(
			randf_range(-ARENA + 3.0, ARENA - 3.0), 0.0,
			randf_range(-ARENA + 3.0, ARENA - 3.0)
		)
		var d := Vector2(p.x - avoid.x, p.z - avoid.z).length()
		if d >= min_dist and _is_free(p, clear):
			return p
	return Vector3(randf_range(-10.0, 10.0), 0.0, randf_range(-10.0, 10.0))


# --------------------------------------------------------------------------- sol & murs

func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400.0, 2.0, 400.0)
	shape.shape = box
	shape.position = Vector3(0.0, -1.0, 0.0)
	body.add_child(shape)
	add_child(body)

	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	# Terre sombre texturee (bruit procedural, tuile de 4,5 m environ) :
	# fini le grand aplat uni qui faisait "prototype".
	mat.albedo_texture = _ground_texture()
	mat.albedo_color = Color(0.34, 0.30, 0.26)
	mat.roughness = 1.0
	mat.texture_repeat = 1   # TEXTURE_REPEAT_ENABLED : la texture se repete sur les 400 m du sol
	mat.uv1_scale = Vector3(130.0, 130.0, 130.0)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mesh.material_override = mat
	add_child(mesh)


## Texture de sol generee (aucun fichier necessaire) : bruit fractal
## sans couture visible, en gris - la teinte vient de albedo_color.
func _ground_texture() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.07
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	# Version sans raccord, puis contraste réduit : de la terre, pas des nuages.
	var img := noise.get_seamless_image(256, 256, false, false, 0.15, true)
	img.convert(Image.FORMAT_L8)
	for y in img.get_height():
		for x in img.get_width():
			var v := img.get_pixel(x, y).r
			var g := 0.78 + (v - 0.5) * 0.28
			img.set_pixel(x, y, Color(g, g, g))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Murs invisibles : le joueur reste dans le cimetière.
## IMPORTANT : la face intérieure du mur est alignée sur la face intérieure de
## la clôture visuelle (posée à ARENA - 0,3, épaisse d'environ 0,4 m), pour que
## le joueur soit arrêté PAR la clôture, et non 60 cm à l'intérieur.
func _build_walls() -> void:
	var half := ARENA + 0.0
	var length := ARENA * 2.0 + 4.0
	var walls := [
		[Vector3(0.0, 4.0, -half), Vector3(length, 8.0, 1.0)],
		[Vector3(0.0, 4.0, half), Vector3(length, 8.0, 1.0)],
		[Vector3(-half, 4.0, 0.0), Vector3(1.0, 8.0, length)],
		[Vector3(half, 4.0, 0.0), Vector3(1.0, 8.0, length)],
	]
	for w in walls:
		var body := StaticBody3D.new()
		body.name = "MurInvisible"
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = w[1]
		shape.shape = box
		body.add_child(shape)
		body.position = w[0]
		add_child(body)


## Clôture continue autour du cimetière, avec une ouverture au sud (l'entrée).
func _build_fence() -> void:
	var probe := Props.spawn("fence.fbx")
	var aabb := Props.local_aabb(probe)
	probe.free()
	var s := Props.prop_scale()
	var along_x := aabb.size.x >= aabb.size.z
	var seg_len := (aabb.size.x if along_x else aabb.size.z) * s
	if seg_len < 0.8 or seg_len > 10.0:
		return   # dimensions inattendues : on ne construit pas la clôture
	var step := seg_len * 0.97
	var edge := ARENA - 0.3
	var count := int(ceil((ARENA * 2.0) / step))
	var yaw_ns := 0.0 if along_x else PI * 0.5
	var yaw_ew := PI * 0.5 if along_x else 0.0
	for i in range(count):
		var t := -ARENA + step * (float(i) + 0.5)
		_place("fence.fbx", Vector3(t, 0.0, -edge), yaw_ns, 1.0, "none", true)
		if absf(t) > 4.0:
			_place("fence.fbx", Vector3(t, 0.0, edge), yaw_ns, 1.0, "none", true)
		_place("fence.fbx", Vector3(-edge, 0.0, t), yaw_ew, 1.0, "none", true)
		_place("fence.fbx", Vector3(edge, 0.0, t), yaw_ew, 1.0, "none", true)


# --------------------------------------------------------------------------- éléments clés

func _build_landmarks() -> void:
	# Crypte au fond du cimetière.
	_place("crypt.fbx", Vector3(0.0, 0.0, -ARENA + 8.0), 0.0, 1.0, "box")
	# Portail d'entrée : on peut passer dessous, mais ses deux piliers
	# (modèle large de 3,30 m, piliers à environ x = -1,45 et +1,45) sont solides.
	_place("arch_gate.fbx", Vector3(0.0, 0.0, ARENA - 0.3), 0.0, 1.0, "none", true)
	_add_solid_box(Vector3(-1.45, 1.7, ARENA - 0.3), Vector3(0.55, 3.4, 0.7))
	_add_solid_box(Vector3(1.45, 1.7, ARENA - 0.3), Vector3(0.55, 3.4, 0.7))
	# Lanternes le long de l'allée centrale.
	for z in [16.0, 4.0, -8.0]:
		for side in [-1.0, 1.0]:
			var lamp := _place("post_lantern.fbx", Vector3(side * 3.6, 0.0, z), 0.0, 1.0, "box")
			_add_light_on(lamp, Color(1.0, 0.62, 0.28), 1.5, 10.0)
	# Deux sanctuaires avec bougies.
	for p in [Vector3(-16.0, 0.0, -6.0), Vector3(17.0, 0.0, 8.0)]:
		var shrine := _place("shrine_candles.fbx", p, _rng.randf_range(-0.3, 0.3), 1.0, "box")
		_add_light_on(shrine, Color(1.0, 0.7, 0.35), 1.1, 7.0)
		_reserve(p, 2.5)


func _build_graves() -> void:
	var types := [
		"grave_A.fbx", "grave_B.fbx", "gravestone.fbx", "gravemarker_A.fbx",
		"gravemarker_B.fbx", "grave_A_destroyed.fbx", "gravestone.fbx", "grave_A.fbx",
	]
	var x := -ARENA + 6.0
	while x <= ARENA - 5.0:
		var z := -ARENA + 14.0
		while z <= ARENA - 12.0:
			var p := Vector3(
				x + _rng.randf_range(-1.1, 1.1), 0.0,
				z + _rng.randf_range(-1.1, 1.1)
			)
			if _rng.randf() < 0.82 and _is_free(p, 1.6):
				var f := String(types[_rng.randi() % types.size()])
				var yaw := _rng.randf_range(-0.15, 0.15)
				_place(f, p, yaw, 1.0, "box")
				if f == "grave_A.fbx":
					# +3 cm : la plaque de terre ne doit pas etre dans le meme
					# plan que le sol, sinon elle clignote (z-fighting).
					_place("floor_dirt_grave.fbx", p, yaw, 1.0, "none", false, 0.03)
				_reserve(p, 1.6)
			z += 5.5
		x += 6.0
	# Quelques cercueils sortis de terre.
	_scatter(["coffin.fbx", "coffin_decorated.fbx"], 4, 2.2, "box", 1.0, 1.0, 5.0)


func _build_decor() -> void:
	# Lanternes et bougies : sources de lumière réparties dans le cimetière.
	for lamp in _scatter(["lantern_standing.fbx", "post_lantern.fbx"], 7, 6.0, "box", 1.0, 1.0, 4.0):
		_add_light_on(lamp, Color(1.0, 0.62, 0.28), 1.4, 9.0)
	for c in _scatter(["candle_triple.fbx", "skull_candle.fbx", "plaque_candles.fbx"], 6, 5.0, "cylinder", 1.0, 1.0, 4.0):
		_add_light_on(c, Color(1.0, 0.8, 0.45), 0.9, 5.5)
	# Citrouilles décoratives (les ennemis sont les citrouilles qui brillent et qui bougent !).
	_scatter(
		["pumpkin_orange.fbx", "pumpkin_orange_small.fbx", "pumpkin_yellow.fbx", "pumpkin_yellow_small.fbx"],
		26, 1.4, "cylinder", 0.9, 1.2, 3.0
	)
	# Os, poteaux macabres, bancs, arbres morts.
	# Os plats au sol : "none" volontaire, on marche dessus comme sur le sol.
	_scatter(["bone_A.fbx", "bone_B.fbx", "bone_C.fbx"], 12, 1.0, "none", 1.0, 1.0, 3.0)
	_scatter(["post_skull.fbx", "post.fbx"], 5, 2.0, "box", 1.0, 1.0, 4.0)
	_scatter(["bench.fbx", "bench_decorated.fbx"], 3, 3.0, "box", 1.0, 1.0, 5.0)
	_scatter(["fence_broken.fbx", "fence_pillar_broken.fbx", "fence_seperate_broken.fbx"], 5, 2.0, "box", 1.0, 1.0, 4.0)
	_scatter(["tree_dead_large.fbx", "tree_dead_medium.fbx", "tree_dead_small.fbx", "tree_dead_large_decorated.fbx"], 9, 5.0, "trunk", 0.85, 1.1, 5.0)


## Forêt d'arbres morts et de pins d'automne derrière la clôture.
func _build_forest() -> void:
	var files := [
		"tree_dead_large.fbx", "tree_dead_medium.fbx", "tree_pine_orange_large.fbx",
		"tree_pine_yellow_large.fbx", "tree_pine_orange_medium.fbx", "tree_dead_large_decorated.fbx",
		"tree_dead_small.fbx", "tree_pine_yellow_medium.fbx", "tree_pine_orange_small.fbx",
	]
	for i in range(110):
		var ring := _rng.randf_range(ARENA + 2.5, ARENA + 24.0)
		var along := _rng.randf_range(-ARENA - 24.0, ARENA + 24.0)
		var side := _rng.randi() % 4
		var p := Vector3.ZERO
		match side:
			0:
				p = Vector3(along, 0.0, -ring)
			1:
				p = Vector3(along, 0.0, ring)
			2:
				p = Vector3(-ring, 0.0, along)
			_:
				p = Vector3(ring, 0.0, along)
		if side == 1 and absf(p.x) < 6.0 and ring < ARENA + 12.0:
			continue   # on garde l'entrée dégagée
		var f := String(files[_rng.randi() % files.size()])
		_place(f, p, _rng.randf() * TAU, _rng.randf_range(0.9, 1.4), "none")


# --------------------------------------------------------------------------- outils

## Place un modèle. collide : "box" (boîte), "cylinder" (props ronds : citrouilles,
## bougies), "trunk" (cylindre du tronc d'arbre) ou "none" (plat au sol / hors aire).
## center = true : le modèle est centré horizontalement sur le point donné.
func _place(file: String, pos: Vector3, yaw: float, mult: float, collide: String, center: bool = false, y_off: float = 0.0) -> Node3D:
	var model := Props.spawn(file)
	var s := Props.prop_scale() * mult
	var aabb := Props.local_aabb(model)
	model.scale = Vector3.ONE * s

	var size := aabb.size * s
	var c := (aabb.position + aabb.size * 0.5) * s
	var off := Vector3.ZERO
	if center:
		off = Vector3(-c.x, 0.0, -c.z)
	model.position = off

	var body: Node3D
	if collide == "none":
		body = Node3D.new()
	else:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		var shape := CollisionShape3D.new()
		if collide == "trunk":
			var cyl := CylinderShape3D.new()
			cyl.radius = clampf(minf(size.x, size.z) * 0.28, 0.32, 0.60)
			cyl.height = maxf(size.y, 0.5)
			shape.shape = cyl
		elif collide == "cylinder":
			var cyl2 := CylinderShape3D.new()
			cyl2.radius = clampf(maxf(size.x, size.z) * 0.42, 0.20, 0.90)
			cyl2.height = maxf(size.y, 0.2)
			shape.shape = cyl2
		else:
			# 0,97 (et non 0,85) : la boîte épouse le modèle, le joueur ne
			# s'enfonce plus visuellement dans les pierres, cercueils, bancs...
			var box := BoxShape3D.new()
			box.size = Vector3(maxf(size.x * 0.97, 0.2), maxf(size.y, 0.2), maxf(size.z * 0.97, 0.2))
			shape.shape = box
		shape.position = c + off
		sb.add_child(shape)
		body = sb
	body.add_child(model)
	body.position = pos + Vector3(0.0, y_off, 0.0)
	body.rotation.y = yaw
	body.set_meta("height", size.y)
	add_child(body)
	return body


## Boîte de collision invisible, aux dimensions exactes voulues (piliers, etc.).
func _add_solid_box(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "CollisionInvisible"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	add_child(body)


## Place `count` props au hasard dans des zones libres. Renvoie les nœuds créés.
func _scatter(files: Array, count: int, clear: float, collide: String, mult_min: float, mult_max: float, margin: float) -> Array:
	var placed: Array = []
	var tries := 0
	while placed.size() < count and tries < count * 40:
		tries += 1
		var p := Vector3(
			_rng.randf_range(-ARENA + margin, ARENA - margin), 0.0,
			_rng.randf_range(-ARENA + margin, ARENA - margin)
		)
		if not _is_free(p, clear):
			continue
		var f := String(files[_rng.randi() % files.size()])
		var node := _place(f, p, _rng.randf() * TAU, _rng.randf_range(mult_min, mult_max), collide)
		_reserve(p, clear)
		placed.append(node)
	return placed


func _add_light_on(prop: Node3D, color: Color, energy: float, light_range: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	# Les lanternes eclairent aussi la brume volumetrique (qualite haute).
	light.set_param(Light3D.PARAM_VOLUMETRIC_FOG_ENERGY, 1.6)
	var h := float(prop.get_meta("height", 1.0))
	light.position = prop.position + Vector3(0.0, h * 0.85, 0.0)
	add_child(light)


func _reserve(p: Vector3, radius: float) -> void:
	_taken.append(Vector3(p.x, p.z, radius))


func _is_free(p: Vector3, radius: float) -> bool:
	var flat := Vector2(p.x, p.z)
	for t in _taken:
		if flat.distance_to(Vector2(t.x, t.y)) < radius + t.z:
			return false
	return true
