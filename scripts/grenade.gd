extends Node3D
## Grenade lancée par le joueur (touche G) : trajectoire en cloche, rebond,
## puis grosse explosion de zone après une courte mèche. Créée par player.gd.
## Tous les effets sont faits en code (aucun fichier d'image à ajouter).

const ARENA_LIMIT := 31.0

var vel := Vector3.ZERO
var fuse := 1.4
var radius := 6.5            # rayon des dégâts, en mètres
var damage := 30             # dégâts au centre : tue tout sauf le boss en un coup
var sfx := Callable()        # fournie par le joueur : sfx.call("explode_big")
var _exploded := false

static var _soft: Texture2D


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	vel.y -= 24.0 * delta
	global_position += vel * delta
	if global_position.y < 0.16:
		global_position.y = 0.16
		vel.y = absf(vel.y) * 0.35
		vel.x *= 0.7
		vel.z *= 0.7
	rotate_object_local(Vector3.RIGHT, delta * 9.0)
	fuse -= delta
	if fuse <= 0.0:
		_explode()


func _explode() -> void:
	_exploded = true
	var origin := global_position
	var parent := get_parent()
	var quality: int = Settings.quality
	var calm: bool = Settings.reduce_flashes
	var amount_k: float = [0.45, 0.75, 1.0][clampi(quality, 0, 2)]

	if sfx.is_valid():
		sfx.call("explode_big")
	_damage_and_push(origin)

	# --- Effets visuels ---
	_add_scorch(parent, origin)
	_add_shockwave(parent, origin)
	_add_fireball(parent, origin, calm)
	_add_light(parent, origin, calm)
	_add_fire(parent, origin, amount_k)
	_add_debris(parent, origin, amount_k)
	_add_smoke(parent, origin, amount_k)

	# --- Sensations : secousse de caméra, arrêt sur image très court ---
	var pl = get_tree().get_first_node_in_group("player")
	if pl != null and pl.has_method("add_shake"):
		var dp: float = pl.global_position.distance_to(origin)
		if dp < 20.0:
			pl.add_shake(clampf(1.25 - dp / 16.0, 0.3, 1.2))
	if not calm:
		Engine.time_scale = 0.25
		get_tree().create_timer(0.09, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)

	queue_free()


## Dégâts en zone avec décroissance, et les survivants sont repoussés.
func _damage_and_push(origin: Vector3) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		var to_e: Vector3 = e.global_position - origin
		var d := to_e.length()
		var reach := radius + float(e.get("body_radius"))
		if d > reach:
			continue
		var falloff := smoothstep(0.35, 1.0, d / reach)       # plein dégât au cœur, 30 % au bord
		var dmg := maxi(1, int(round(float(damage) * lerpf(1.0, 0.3, falloff))))
		e.take_hit(dmg, false)
		if is_instance_valid(e) and not e.dying:
			_push(e, to_e, reach)


func _push(e: Node3D, to_e: Vector3, reach: float) -> void:
	var dir := Vector3(to_e.x, 0.0, to_e.z)
	if dir.length() < 0.05:
		dir = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	dir = dir.normalized()
	var strength := 1.0 - clampf(to_e.length() / reach, 0.0, 1.0)
	var target := e.global_position + dir * (2.0 + 5.0 * strength)
	target.x = clampf(target.x, -ARENA_LIMIT, ARENA_LIMIT)
	target.z = clampf(target.z, -ARENA_LIMIT, ARENA_LIMIT)
	e.set("_stun", 0.7)
	var tw := e.create_tween()
	tw.tween_property(e, "global_position", target, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# --------------------------------------------------------------------------- effets

func _soft_texture() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 128
		gt.height = 128
		_soft = gt
	return _soft


func _glow_material(color: Color, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _ramp(offsets: Array, colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g


func _grow_curve(start: float, peak: float, end: float) -> Curve:
	var c := Curve.new()
	c.max_value = 3.0
	c.add_point(Vector2(0.0, start))
	c.add_point(Vector2(0.3, peak))
	c.add_point(Vector2(1.0, end))
	return c


## Lueur d'explosion : de grands halos doux (sans bord dur) qui gonflent très vite puis s'éteignent.
func _add_fireball(parent: Node, origin: Vector3, calm: bool) -> void:
	_halo(parent, origin + Vector3(0, 1.1, 0), Color(1.0, 0.5, 0.12, 0.0 if calm else 0.85), radius * 0.8, radius * 3.4, 0.45)
	if not calm:
		_halo(parent, origin + Vector3(0, 1.0, 0), Color(1.0, 0.97, 0.8, 1.0), radius * 0.5, radius * 2.0, 0.2)


func _halo(parent: Node, at: Vector3, color: Color, from_size: float, to_size: float, time: float) -> void:
	var sprite := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	sprite.mesh = quad
	var mat := _glow_material(color, true)
	mat.albedo_texture = _soft_texture()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.no_depth_test = true      # le halo ne se fait pas couper par le sol
	sprite.material_override = mat
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sprite)
	sprite.global_position = at
	sprite.scale = Vector3.ONE * from_size
	var tw := sprite.create_tween().set_parallel(true)
	tw.tween_property(sprite, "scale", Vector3.ONE * to_size, time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, time * 1.1).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(sprite.queue_free)


func _ring_texture() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.72, 0.88, 0.96, 1.0])
	g.colors = PackedColorArray([
		Color(1, 0.7, 0.3, 0.0), Color(1, 0.7, 0.3, 0.0), Color(1.0, 0.85, 0.55, 0.95),
		Color(1.0, 0.5, 0.2, 0.35), Color(1.0, 0.4, 0.1, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	return gt


## Onde de choc au sol : un anneau fin et lumineux qui s'élargit jusqu'au bord de la zone.
func _add_shockwave(parent: Node, origin: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	ring.mesh = quad
	var mat := _glow_material(Color(1, 1, 1, 1.0), true)
	mat.albedo_texture = _ring_texture()
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.global_position = origin + Vector3(0, 0.12, 0)
	ring.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	ring.scale = Vector3(1.5, 1.5, 1.5)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * radius * 3.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ring.queue_free)


## Trace de brûlure sur le sol, qui s'efface lentement.
func _add_scorch(parent: Node, origin: Vector3) -> void:
	var quad := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * radius * 1.9
	quad.mesh = q
	var mat := _glow_material(Color(0.0, 0.0, 0.0, 0.7), false)
	mat.albedo_texture = _soft_texture()
	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(quad)
	quad.global_position = Vector3(origin.x, 0.04, origin.z)
	quad.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var tw := quad.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(mat, "albedo_color:a", 0.0, 4.0)
	tw.tween_callback(quad.queue_free)


func _add_light(parent: Node, origin: Vector3, calm: bool) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 9.0 if calm else 18.0
	light.omni_range = radius * 2.6
	light.shadow_enabled = false
	parent.add_child(light)
	light.global_position = origin + Vector3(0, 1.2, 0)
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(light.queue_free)


func _billboard_particles(amount: int, life: float, size: float, additive: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	p.mesh = quad
	var m := _glow_material(Color.WHITE, additive)
	m.albedo_texture = _soft_texture()
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	quad.material = m
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.95
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _finish(p: Node, parent: Node, at: Vector3, life: float) -> void:
	parent.add_child(p)
	p.global_position = at
	(p as CPUParticles3D).emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


## Flammes : de gros nuages jaune → orange → rouge sombre qui montent et grossissent.
func _add_fire(parent: Node, origin: Vector3, k: float) -> void:
	var p := _billboard_particles(int(46.0 * k) + 8, 1.0, 2.6, true)
	p.emission_sphere_radius = radius * 0.28
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 8.5
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.gravity = Vector3(0, 2.5, 0)
	p.scale_amount_min = 0.9
	p.scale_amount_max = 1.6
	p.scale_amount_curve = _grow_curve(0.5, 1.0, 1.5)
	p.color_ramp = _ramp([0.0, 0.2, 0.55, 1.0], [
		Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.55, 0.12, 0.95),
		Color(0.55, 0.14, 0.05, 0.55), Color(0.1, 0.05, 0.04, 0.0)])
	_finish(p, parent, origin + Vector3(0, 0.8, 0), p.lifetime)


## Éclats incandescents projetés très loin, qui retombent.
func _add_debris(parent: Node, origin: Vector3, k: float) -> void:
	var p := CPUParticles3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.14, 0.14, 0.14)
	p.mesh = box
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	box.material = m
	p.amount = int(34.0 * k) + 6
	p.lifetime = 1.3
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4
	p.direction = Vector3.UP
	p.spread = 75.0
	p.initial_velocity_min = 9.0
	p.initial_velocity_max = 20.0
	p.gravity = Vector3(0, -24, 0)
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.6
	p.color_ramp = _ramp([0.0, 0.5, 1.0], [
		Color(1.0, 0.9, 0.5, 1.0), Color(1.0, 0.4, 0.08, 1.0), Color(0.25, 0.08, 0.04, 0.0)])
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_finish(p, parent, origin + Vector3(0, 0.5, 0), p.lifetime)


## Fumée sombre qui monte lentement et reste un moment.
func _add_smoke(parent: Node, origin: Vector3, k: float) -> void:
	var p := _billboard_particles(int(22.0 * k) + 4, 2.4, 3.4, false)
	p.emission_sphere_radius = radius * 0.3
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.5
	p.damping_min = 0.8
	p.damping_max = 1.6
	p.gravity = Vector3(0, 0.8, 0)
	p.explosiveness = 0.7
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.8
	p.scale_amount_curve = _grow_curve(0.5, 1.2, 1.9)
	p.color_ramp = _ramp([0.0, 0.25, 1.0], [
		Color(0.12, 0.1, 0.09, 0.0), Color(0.16, 0.14, 0.13, 0.6), Color(0.08, 0.08, 0.09, 0.0)])
	_finish(p, parent, origin + Vector3(0, 1.0, 0), p.lifetime)
