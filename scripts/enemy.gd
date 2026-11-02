extends CharacterBody3D
## Ennemi : poursuit le joueur et le blesse au contact.
## Créé par game.gd avec setup(config, game, player). Tout est construit dans le code.

const Props = preload("res://scripts/props.gd")

# Si le visage d'un modèle ne regarde pas le joueur, change cet angle (en radians, ex. PI).
const FACING_OFFSET := 0.0
const GRAVITY := 24.0

var speed := 3.0
var damage := 8
var attack_range := 1.25
var attack_cooldown := 1.0
var hop := false
var flying := false
var hover := 0.0
var dying := false
var hp := 2
var glow_color := Color(1.0, 0.5, 0.1)

var game = null     # Node de partie (lit game.frozen)
var target = null   # le joueur
var kind_name := ""       # type (pumpkin, skull, bomber, ghost, boss...)
var xp_value := 10        # XP rapportee au joueur quand il meurt
var max_hp := 1           # PV de depart (pour la barre de vie)
var is_boss := false
var explode_radius := 0.0 # > 0 : explose au contact (citrouille explosive)
var explode_damage := 0
var ranged := false       # tire des projectiles a distance (fantome)
var stationary := false   # totem : ne bouge pas, tire de loin
var elite := false        # monstre dore, plus gros et plus resistant
var preferred_range := 9.0
var _shoot_t := 2.0
var _projectiles: Array = []
var _bar_back: Sprite3D
var _bar_front: Sprite3D
static var _white_tex: Texture2D = null
var body_height := 1.0    # hauteur du corps (pour le point de visée)
var body_radius := 0.45

var _pivot: Node3D
var _cd := 0.0
var _t := 0.0
var _phase := 0.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _avoid_t := 0.0
var _side := 1.0
var _stun := 0.0


func setup(config: Dictionary, game_node: Node, player_node: Node) -> void:
	game = game_node
	target = player_node
	speed = float(config["speed"]) * randf_range(0.9, 1.1)
	damage = int(config["damage"])
	hop = bool(config["hop"])
	hover = float(config["hover"])
	hp = int(config["hp"])
	max_hp = hp
	glow_color = config["glow"]
	flying = hover > 0.0
	_phase = randf() * TAU
	add_to_group("enemy")
	collision_layer = 4          # ennemis
	collision_mask = 1 | 4       # décor + autres ennemis (ils ne s'empilent pas)

	var height := float(config["height"])
	var radius := float(config["radius"])
	body_height = height
	body_radius = radius
	kind_name = String(config.get("kind", ""))
	xp_value = int(config.get("xp", 10))
	is_boss = bool(config.get("boss", false))
	explode_radius = float(config.get("explode_radius", 0.0))
	explode_damage = int(config.get("explode_damage", 0))
	ranged = bool(config.get("ranged", false))
	stationary = bool(config.get("stationary", false))
	elite = bool(config.get("elite", false))
	if elite:
		xp_value = int(xp_value * 3)
	preferred_range = float(config.get("preferred_range", 9.0))
	attack_range = maxf(attack_range, radius * 2.2)

	_pivot = Props.make_fitted(String(config["model"]), height, flying)
	Props.make_glow(_pivot, config["glow"], float(config["glow_energy"]))
	add_child(_pivot)

	_build_health_bar(height)

	var col := CollisionShape3D.new()
	if flying:
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		col.shape = sphere
	else:
		var capsule := CapsuleShape3D.new()
		capsule.radius = radius
		capsule.height = maxf(height, radius * 2.0 + 0.01)
		col.shape = capsule
		col.position = Vector3(0.0, capsule.height * 0.5, 0.0)
	add_child(col)


## Centre de masse à viser : poitrine pour les ennemis au sol, centre du
## modèle pour les volants. Utilisé par la visée et l'aide à la visée du joueur.
func aim_point() -> Vector3:
	if flying:
		return global_position
	return global_position + Vector3(0.0, body_height * 0.55, 0.0)


static func white_texture() -> Texture2D:
	if _white_tex == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white_tex = ImageTexture.create_from_image(img)
	return _white_tex


## Barre de vie flottante (visible seulement quand le monstre est blesse).
func _build_health_bar(height: float) -> void:
	var y := height + (0.55 if is_boss else 0.38)
	var wide := is_boss or elite
	_bar_back = _bar_sprite(Color(0.05, 0.05, 0.08, 0.75), y, 1.24 if wide else 0.84)
	_bar_front = _bar_sprite(Color(0.55, 0.95, 0.45, 0.95), y, 1.16 if wide else 0.76)
	_bar_back.visible = false
	_bar_front.visible = false
	add_child(_bar_back)
	add_child(_bar_front)


func _bar_sprite(color: Color, y: float, width: float) -> Sprite3D:
	var sp := Sprite3D.new()
	sp.texture = white_texture()
	sp.pixel_size = 0.01
	sp.modulate = color
	sp.scale = Vector3(width / 0.08, 0.75, 1.0)  # texture 8 px a 0,01 m/px = 0,08 m de base
	sp.position = Vector3(0.0, y, 0.0)
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.no_depth_test = true
	sp.render_priority = 10
	return sp


func _refresh_bar() -> void:
	if _bar_front == null or max_hp <= 0:
		return
	var frac := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	var show := hp < max_hp and not dying
	_bar_back.visible = show
	_bar_front.visible = show
	if show:
		var full := 1.16 if (is_boss or elite) else 0.76
		_bar_front.scale.x = (full * frac) / 0.08
		_bar_front.modulate = Color(0.95, 0.35, 0.25, 0.95) if frac < 0.33 else (Color(0.98, 0.80, 0.30, 0.95) if frac < 0.66 else Color(0.55, 0.95, 0.45, 0.95))


## Chiffre de degats qui monte et s'efface au-dessus du monstre.
func _damage_number(amount: int, crit: bool) -> void:
	var label := Label3D.new()
	label.text = str(amount)
	label.font_size = 96 if crit else 64
	label.modulate = Color(1.0, 0.45, 0.15) if crit else Color(1.0, 0.95, 0.75)
	label.outline_size = 12
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(randf_range(-0.2, 0.2), body_height + 0.5, 0.0)
	add_child(label)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y + 0.9, 0.7)
	tw.tween_property(label, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(label.queue_free)


## Projectiles du fantome : petites spheres lumineuses qui blessent au contact.
func _update_projectiles(delta: float) -> void:
	for pr in _projectiles.duplicate():
		if not is_instance_valid(pr["node"]):
			_projectiles.erase(pr)
			continue
		var node: Node3D = pr["node"]
		pr["life"] = float(pr["life"]) - delta
		node.global_position += (pr["vel"] as Vector3) * delta
		var hit := false
		if target != null and is_instance_valid(target) and not target.dead:
			hit = node.global_position.distance_to(target.global_position + Vector3(0, 1.0, 0)) < 0.75
			if hit:
				target.take_damage(int(pr["damage"]))
		if hit or float(pr["life"]) <= 0.0 or node.global_position.y < 0.05:
			node.queue_free()
			_projectiles.erase(pr)


func _shoot_projectile() -> void:
	if target == null or not is_instance_valid(target):
		return
	var from := global_position + Vector3(0.0, body_height * 0.7, 0.0)
	var to: Vector3 = target.global_position + Vector3(0.0, 1.1, 0.0)
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	sphere.radial_segments = 10
	sphere.rings = 6
	node.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = glow_color
	sphere.material = mat
	var light := OmniLight3D.new()
	light.light_color = glow_color
	light.light_energy = 1.2
	light.omni_range = 4.0
	node.add_child(light)
	get_parent().add_child(node)
	node.global_position = from
	_projectiles.append({"node": node, "vel": (to - from).normalized() * 11.0, "life": 4.0, "damage": damage})


func _explode() -> void:
	if dying:
		return
	if target != null and is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= explode_radius:
			target.take_damage(explode_damage)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 6.0
	light.omni_range = 9.0
	get_parent().add_child(light)
	light.global_position = global_position + Vector3(0, 0.6, 0)
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.4)
	tw.tween_callback(light.queue_free)
	_burst()
	_die()


func _physics_process(delta: float) -> void:
	_update_projectiles(delta)
	if dying:
		return
	if target == null or not is_instance_valid(target) or target.dead:
		_stop(delta)
		return
	if game != null and game.frozen:
		_stop(delta)
		return

	_t += delta
	_cd = maxf(_cd - delta, 0.0)
	_stun = maxf(_stun - delta, 0.0)
	if _stun > 0.0:
		_stop(delta)
		return

	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	var dir := to_target.normalized()

	# Anti-blocage : si l'ennemi n'avance plus, il contourne l'obstacle pendant un instant.
	_avoid_t = maxf(_avoid_t - delta, 0.0)
	var move_dir := dir
	if _avoid_t > 0.0:
		move_dir = (dir + dir.rotated(Vector3.UP, _side * PI * 0.5) * 1.3).normalized()
	_stuck_t += delta
	if _stuck_t >= 0.5:
		var moved := Vector2(global_position.x - _last_pos.x, global_position.z - _last_pos.z).length()
		if moved < speed * 0.175 and dist > attack_range * 1.5:
			_avoid_t = 0.9
			_side = 1.0 if randf() < 0.5 else -1.0
		_last_pos = global_position
		_stuck_t = 0.0

	if explode_radius > 0.0 and dist < 1.5:
		_explode()
		return
	if stationary:
		velocity.x = 0.0
		velocity.z = 0.0
		_shoot_t -= delta
		if _shoot_t <= 0.0 and dist < preferred_range + 8.0:
			_shoot_t = 2.6
			_shoot_projectile()
	elif ranged:
		# Le fantome garde ses distances : trop loin il avance, trop pres il recule.
		if dist > preferred_range + 1.0:
			velocity.x = move_dir.x * speed
			velocity.z = move_dir.z * speed
		elif dist < preferred_range - 1.5:
			velocity.x = -move_dir.x * speed * 0.7
			velocity.z = -move_dir.z * speed * 0.7
		else:
			var side_dir := dir.rotated(Vector3.UP, PI * 0.5) * _side
			velocity.x = side_dir.x * speed * 0.45
			velocity.z = side_dir.z * speed * 0.45
		_shoot_t -= delta
		if _shoot_t <= 0.0 and dist < preferred_range + 7.0:
			_shoot_t = 2.3
			_shoot_projectile()
	elif dist > attack_range * 0.8:
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	if flying:
		var want_y := hover + sin(_t * 2.0 + _phase) * 0.18
		velocity.y = (want_y - global_position.y) * 6.0
		_pivot.rotation.z = sin(_t * 3.0 + _phase) * 0.25
	else:
		velocity.y = maxf(velocity.y - GRAVITY * delta, -40.0)
		if hop:
			_pivot.position.y = absf(sin(_t * 6.0 + _phase)) * 0.28

	if dist > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z) + FACING_OFFSET, 8.0 * delta)

	if dist <= attack_range and _cd <= 0.0:
		target.take_damage(damage)
		_cd = attack_cooldown

	move_and_slide()


func _stop(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if flying:
		velocity.y = 0.0
	else:
		velocity.y = maxf(velocity.y - GRAVITY * delta, -40.0)
	move_and_slide()


## Appelé quand une balle touche l'ennemi.
func take_hit(amount: int, crit: bool = false) -> void:
	if dying:
		return
	hp -= amount
	_damage_number(amount, crit)
	_refresh_bar()
	if hp <= 0:
		_die()
		return
	_stun = 0.12
	if game != null:
		game.play_sfx("enemy_hit")
	var tw := create_tween()
	tw.tween_property(_pivot, "scale", Vector3.ONE * 1.3, 0.05)
	tw.tween_property(_pivot, "scale", Vector3.ONE, 0.1)


func _die() -> void:
	dying = true
	remove_from_group("enemy")
	collision_layer = 0
	collision_mask = 0
	if game != null:
		game.play_sfx("enemy_die")
		game.register_kill(self)
	_burst()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.02, 0.18)
	tw.tween_callback(queue_free)


## Petite explosion d'étincelles à la couleur de l'ennemi.
func _burst() -> void:
	var p := CPUParticles3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	sphere.radial_segments = 6
	sphere.rings = 3
	p.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = glow_color
	sphere.material = mat
	p.amount = 16
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0.0, -9.0, 0.0)
	p.emitting = true
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0.0, 0.6, 0.0)
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


## Disparition en fondu (à l'aube).
func vanish() -> void:
	if dying:
		return
	dying = true
	collision_layer = 0
	collision_mask = 0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.02, 0.5)
	tw.tween_callback(queue_free)
