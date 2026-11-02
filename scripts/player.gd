extends CharacterBody3D
## Joueur : personnage Quaternius (Sci-Fi), caméra à la troisième personne,
## sprint illimité (aucune fatigue), roulade d'esquive, points de vie.
## Tout est construit dans le code : aucune configuration dans l'éditeur.

signal health_changed(current: int, maximum: int)
signal damaged
signal died
signal ammo_changed(current: int, maximum: int, reloading: bool)
signal aim_changed(on_target: bool)   # réticule : une cible est sous le viseur / verrouillée
signal hit_confirmed                 # une balle vient de toucher un monstre
signal shield_changed(points: int) # bouclier restant (affiche dans le HUD)
signal weapon_changed(weapon_name: String, detail: String)
signal grenade_changed(count: int)

const CHARACTER_PATH := "res://assets/character/character.glb"

# Armes (modeles 3D Kenney "Blaster Kit", CC0) : statistiques de base.
const WEAPONS := [
	{"id": "pistolet", "name": "Pistolet", "file": "blaster-b.glb", "mag": 12, "interval": 0.22, "reload": 1.1, "damage": 1, "pellets": 1, "spread": 0.0, "pierce": 0, "recoil": 0.5, "zoom": false, "unlock": 1},
	{"id": "fusil", "name": "Fusil d'assaut", "file": "blaster-g.glb", "mag": 30, "interval": 0.095, "reload": 1.6, "damage": 1, "pellets": 1, "spread": 1.4, "pierce": 0, "recoil": 0.35, "zoom": false, "unlock": 2},
	{"id": "pompe", "name": "Fusil à pompe", "file": "blaster-l.glb", "mag": 6, "interval": 0.85, "reload": 2.2, "damage": 1, "pellets": 6, "spread": 7.0, "pierce": 0, "recoil": 1.0, "zoom": false, "unlock": 4},
	{"id": "precision", "name": "Fusil de précision", "file": "blaster-e.glb", "mag": 5, "interval": 1.15, "reload": 2.0, "damage": 5, "pellets": 1, "spread": 0.0, "pierce": 3, "recoil": 1.2, "zoom": true, "unlock": 6},
]
const WEAPON_DIR := "res://assets/weapons/"
const GrenadeScript = preload("res://scripts/grenade.gd")
const GRAVITY := 24.0

@export_group("Déplacement")
@export var walk_speed := 4.8
@export var sprint_speed := 8.2
@export var acceleration := 14.0
@export var turn_speed := 12.0


@export_group("Roulade")
@export var roll_speed := 9.5
@export var roll_duration := 0.55

@export_group("Vie")
@export var max_health := 100
@export var hit_invincibility := 0.9

@export_group("Arme")
@export var magazine := 12
@export var fire_interval := 0.22       # secondes entre deux tirs (clic maintenu = tir auto)
@export var reload_time := 1.5
@export var shot_damage := 1
@export var crit_chance := 0.12        # coups critiques : dégâts x2
@export var shot_range := 70.0

@export_group("Caméra")
@export var mouse_sensitivity := 0.0028
@export var camera_distance := 4.4

@export_group("Visée")
@export var aim_turn_speed := 26.0        # rotation du personnage vers le viseur en tirant (rad/s-ish)
@export var assist_cone_mouse := 13.0     # cône d'aide à la visée souris (degrés)
@export var assist_cone_touch := 20.0     # cône plus large au tactile / manette
@export var aim_move_factor := 0.62       # on se déplace plus lentement en visant : tir stable

var health := 100
var current_weapon := 0
var unlocked_weapons: Array = [true, false, false, false]
var damage_bonus := 0
var mag_bonus := 0
var fire_mult := 1.0
var reload_mult := 1.0
var grenades := 2
var shots_fired := 0
var shots_hit := 0
var _weapon_nodes: Array = []
var _weapon_holder: Node3D = null
var dead := false
var invulnerable := false
var controls_enabled := false   # false pendant le menu / après la fin de partie

var pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var model: Node3D
var anim: AnimationPlayer

var ammo := 12
var reloading := false
var sfx := Callable()           # fournie par game.gd : sfx.call("shoot")

var _flash: OmniLight3D
var _flash_t := 0.0
var _reload_t := 0.0
var _shoot_cd := 0.0
var _aim_t := 0.0               # > 0 : le personnage regarde dans la direction de la caméra
var _aim_target: Node3D = null  # monstre verrouillé par l'aide à la visée (avec hystérésis)
var _aim_scan_t := 0.0          # cadence du balayage de cible pour le réticule
var _on_target := false         # le réticule est sur un monstre (ou un monstre est verrouillé)
var _recoil := 0.0              # recul caméra (1 = juste après le tir, décroît tout seul)
var shield_points := 0          # bouclier : absorbe les dégâts avant la vie
var _shield_t := 0.0
var _power_damage_t := 0.0      # rage : dégâts x2 pendant quelques secondes
var _power_speed_t := 0.0       # rapidité : +25 % de vitesse
var _shake := 0.0               # secousse caméra (dégâts reçus, tir)
var _shoot_anim_t := 0.0
var _anims := {}                # nom court ("Idle") -> nom complet ("CharacterArmature|Idle")
var _current_anim := ""
var _invincible := 0.0
var _hit_anim_t := 0.0
var _rolling := false
var _roll_t := 0.0
var _roll_dir := Vector3.ZERO


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2   # le joueur
	collision_mask = 1    # ne heurte que le décor (traverse les ennemis, qui le blessent au contact)
	# Réglages physiques stricts : accroche au sol nette, glissement propre le
	# long des murs et des props, pas de franchissement en roulade.
	floor_snap_length = 0.30
	floor_max_angle = deg_to_rad(50.0)
	wall_min_slide_angle = deg_to_rad(10.0)
	safe_margin = 0.06
	health = max_health
	_apply_weapon_stats(true)
	_build_ambience()

	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	col.shape = capsule
	col.position = Vector3(0.0, 0.9, 0.0)
	add_child(col)

	_build_model()
	_build_camera()
	_build_light()
	_play("Idle")


func emit_state() -> void:
	health_changed.emit(health, max_health)
	ammo_changed.emit(ammo, magazine, reloading)


func _build_model() -> void:
	model = Node3D.new()
	model.name = "Model"
	add_child(model)

	var visual: Node3D = null
	if ResourceLoader.exists(CHARACTER_PATH):
		var scene = load(CHARACTER_PATH)
		if scene is PackedScene:
			visual = (scene as PackedScene).instantiate() as Node3D
	if visual == null:
		# Modèle de secours : une capsule.
		var mi := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.38
		cm.height = 1.8
		mi.mesh = cm
		mi.position = Vector3(0.0, 0.9, 0.0)
		visual = mi
	model.add_child(visual)

	anim = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null:
		return
	for full in anim.get_animation_list():
		var full_name := String(full)
		var short_name := full_name.get_slice("|", full_name.get_slice_count("|") - 1)
		_anims[short_name] = full_name
	# Les animations importées ne bouclent pas par défaut.
	for key in ["Idle", "Walk", "Run"]:
		if _anims.has(key):
			anim.get_animation(_anims[key]).loop_mode = Animation.LOOP_LINEAR
	_build_weapons(visual)


## Accroche les modeles d'armes a l'attache "Pistol" de la main droite.
func _build_weapons(visual: Node3D) -> void:
	var att: BoneAttachment3D = null
	var stack: Array = [visual]
	while not stack.is_empty() and att == null:
		var n = stack.pop_back()
		if n is BoneAttachment3D:
			att = n
			break
		for c in n.get_children():
			stack.append(c)
	_weapon_holder = Node3D.new()
	_weapon_holder.name = "WeaponHolder"
	if att != null:
		for c in att.get_children():
			if c is MeshInstance3D:
				c.visible = false   # ancien pistolet du personnage
		att.add_child(_weapon_holder)
		var gs := att.get_global_transform().basis.get_scale()
		if gs.x > 0.001:
			_weapon_holder.scale = Vector3.ONE / gs
		_weapon_holder.rotation_degrees.y = 90.0
	else:
		_weapon_holder.position = Vector3(0.25, 1.05, 0.2)
		model.add_child(_weapon_holder)
	for w in WEAPONS:
		var node: Node3D = null
		var path := WEAPON_DIR + String(w["file"])
		if ResourceLoader.exists(path):
			node = (load(path) as PackedScene).instantiate() as Node3D
		if node == null:
			node = Node3D.new()
		node.scale *= 0.85
		node.visible = false
		_weapon_holder.add_child(node)
		_weapon_nodes.append(node)
	if not _weapon_nodes.is_empty():
		_weapon_nodes[0].visible = true


## Recalcule chargeur/cadence/recharge/degats depuis l'arme + les ameliorations.
func _apply_weapon_stats(refill: bool) -> void:
	var w: Dictionary = WEAPONS[current_weapon]
	magazine = int(w["mag"]) + mag_bonus
	fire_interval = maxf(float(w["interval"]) * fire_mult, 0.05)
	reload_time = maxf(float(w["reload"]) * reload_mult, 0.3)
	shot_damage = int(w["damage"]) + damage_bonus
	if refill:
		ammo = magazine
	else:
		ammo = mini(ammo, magazine)
	ammo_changed.emit(ammo, magazine, reloading)


func refresh_weapon_stats() -> void:
	_apply_weapon_stats(false)


func emit_weapon() -> void:
	var w: Dictionary = WEAPONS[current_weapon]
	weapon_changed.emit(String(w["name"]), "")
	grenade_changed.emit(grenades)


func switch_weapon(idx: int) -> bool:
	if idx < 0 or idx >= WEAPONS.size() or idx == current_weapon:
		return false
	if not bool(unlocked_weapons[idx]):
		_play_sfx("empty")
		return false
	current_weapon = idx
	reloading = false
	_apply_weapon_stats(true)
	for i in range(_weapon_nodes.size()):
		_weapon_nodes[i].visible = i == idx
	_play_sfx("switch")
	var w: Dictionary = WEAPONS[idx]
	weapon_changed.emit(String(w["name"]), "Dégâts %d · chargeur %d" % [shot_damage, magazine])
	return true


func cycle_weapon(dir: int) -> void:
	var idx := current_weapon
	for i in range(WEAPONS.size()):
		idx = wrapi(idx + dir, 0, WEAPONS.size())
		if bool(unlocked_weapons[idx]):
			switch_weapon(idx)
			return


## Debloque une arme (montee de niveau) et l'equipe aussitot.
func unlock_weapon(id: String) -> bool:
	for i in range(WEAPONS.size()):
		if String(WEAPONS[i]["id"]) == id and not bool(unlocked_weapons[i]):
			unlocked_weapons[i] = true
			switch_weapon(i)
			return true
	return false


func throw_grenade() -> void:
	if grenades <= 0:
		_play_sfx("empty")
		return
	grenades -= 1
	grenade_changed.emit(grenades)
	_play_sfx("throw")
	var g = GrenadeScript.new()
	var chest := global_position + Vector3(0.0, 1.45, 0.0)
	var dir := -camera.global_transform.basis.z   # suit la visee : bas = court, haut = loin
	g.vel = dir * 16.0 + Vector3.UP * 2.0
	g.sfx = sfx
	if ResourceLoader.exists(WEAPON_DIR + "grenade-a.glb"):
		var visual = (load(WEAPON_DIR + "grenade-a.glb") as PackedScene).instantiate()
		visual.scale = Vector3.ONE * 1.4
		g.add_child(visual)
	get_parent().add_child(g)
	g.global_position = chest + dir * 0.6


## Petites lucioles chaudes qui flottent autour du joueur (ambiance).
func _build_ambience() -> void:
	if Settings.quality <= 0:
		return
	var p := CPUParticles3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	sphere.radial_segments = 6
	sphere.rings = 3
	p.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.75, 0.4, 0.8)
	sphere.material = mat
	p.amount = 22
	p.lifetime = 7.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(9, 2.5, 9)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.5
	p.gravity = Vector3.ZERO
	p.position = Vector3(0, 1.6, 0)
	add_child(p)


## Étincelles a l'impact d'une balle.
func _impact_fx(pos: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	sphere.radial_segments = 6
	sphere.rings = 3
	p.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	sphere.material = mat
	p.amount = 7
	p.lifetime = 0.35
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -6, 0)
	p.emitting = true
	get_parent().add_child(p)
	p.global_position = pos
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)


func _build_camera() -> void:
	pivot = Node3D.new()
	pivot.name = "CameraPivot"
	pivot.position = Vector3(0.0, 1.55, 0.0)
	add_child(pivot)

	spring_arm = SpringArm3D.new()
	spring_arm.spring_length = camera_distance
	spring_arm.collision_mask = 1
	spring_arm.margin = 0.25
	spring_arm.rotation.x = deg_to_rad(-16.0)
	pivot.add_child(spring_arm)
	spring_arm.add_excluded_object(get_rid())

	camera = Camera3D.new()
	camera.fov = 70.0
	camera.far = 250.0
	spring_arm.add_child(camera)
	camera.make_current()


func _build_light() -> void:
	# Lueur chaude autour du joueur (sa lanterne).
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.42)
	light.light_energy = 1.6
	light.omni_range = 11.0
	light.position = Vector3(0.0, 2.3, 0.0)
	add_child(light)

	# Flash du tir.
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.85, 0.5)
	_flash.light_energy = 0.0
	_flash.omni_range = 7.0
	_flash.position = Vector3(0.0, 1.4, 0.0)
	add_child(_flash)


func menu_orbit(delta: float) -> void:
	pivot.rotate_y(0.22 * delta)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_delta((event as InputEventMouseMotion).relative)


## Tourne la caméra (souris ou doigt). Le réglage de sensibilité s'applique ici.
func look_delta(relative: Vector2) -> void:
	if not controls_enabled or dead:
		return
	var k := mouse_sensitivity * Settings.sensitivity
	pivot.rotate_y(-relative.x * k)
	spring_arm.rotation.x = clampf(
		spring_arm.rotation.x - relative.y * k,
		deg_to_rad(-60.0),
		deg_to_rad(25.0)
	)


func _physics_process(delta: float) -> void:
	if dead:
		return

	_invincible = maxf(_invincible - delta, 0.0)
	_hit_anim_t = maxf(_hit_anim_t - delta, 0.0)
	_power_damage_t = maxf(_power_damage_t - delta, 0.0)
	_power_speed_t = maxf(_power_speed_t - delta, 0.0)
	if _shield_t > 0.0:
		_shield_t -= delta
		if _shield_t <= 0.0 and shield_points > 0:
			shield_points = 0
			shield_changed.emit(0)
	# Secousse caméra : aléatoire décroissante, coupée si "réduire les flashs".
	if camera != null:
		if _shake > 0.001:
			_shake = maxf(_shake - delta * 1.9, 0.0)
			var a := 0.055 * _shake * (0.3 if Settings.reduce_flashes else 1.0)
			camera.position = Vector3(randf_range(-a, a), randf_range(-a, a), 0.0)
		elif camera.position != Vector3.ZERO:
			camera.position = Vector3.ZERO
	velocity.y = maxf(velocity.y - GRAVITY * delta, -40.0)

	var input_dir := Vector2.ZERO
	if controls_enabled:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		# Camera a la manette : stick droit (meme sensibilite que la souris).
		var look_vec := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if look_vec.length() > 0.15:
			look_delta(look_vec * 900.0 * delta)
	var direction := pivot.global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	direction.y = 0.0
	direction = direction.normalized()
	var moving := input_dir.length() > 0.1

	var sprinting := false
	if _rolling:
		_roll_t -= delta
		_invincible = maxf(_invincible, 0.1)
		velocity.x = _roll_dir.x * roll_speed
		velocity.z = _roll_dir.z * roll_speed
		if _roll_t <= 0.0:
			_rolling = false
			if anim != null:
				anim.speed_scale = 1.0
	else:
		# Course AUTOMATIQUE : le personnage court toujours a pleine vitesse
		# dans la direction demandee (fleches, ZQSD, joystick) — aucune touche
		# "courir" a maintenir. Pousser doucement le joystick fait marcher.
		sprinting = controls_enabled and moving
		var target_speed := sprint_speed
		target_speed *= clampf(input_dir.length(), 0.6, 1.0)   # joystick : on peut marcher doucement
		if _aim_t > 0.0:
			target_speed *= aim_move_factor   # en visant, on avance lentement mais le tir est stable
		if _power_speed_t > 0.0:
			target_speed *= 1.25   # pouvoir rapidité
		var t := clampf(acceleration * delta, 0.0, 1.0)
		velocity.x = lerpf(velocity.x, direction.x * target_speed, t)
		velocity.z = lerpf(velocity.z, direction.z * target_speed, t)
		if controls_enabled and Input.is_action_just_pressed("roll"):
			_start_roll(direction)

	# Visée : le minuteur _aim_t ne doit JAMAIS s'auto-entretenir (avant, une
	# fois un tir parti, le personnage restait bloqué face à la caméra et
	# "courait de côté"). Il ne se relance que pendant un vrai tir.
	var auto_aim_fire := Settings.auto_shoot and Settings.aim_assist and _on_target
	var aiming := controls_enabled and not _rolling and (Input.is_action_pressed("shoot") or auto_aim_fire)
	if aiming:
		_aim_t = maxf(_aim_t, 0.25)
		if not moving:
			_face(-pivot.global_transform.basis.z, delta, aim_turn_speed)
	_update_weapon(delta)
	_update_aim_state(delta)

	# Le modèle se tourne TOUJOURS vers sa direction de course quand il bouge
	# (flèches, ZQSD, joystick) : appuyer sur ">" le fait courir vers la droite
	# en regardant à droite. La visée ne prend le dessus qu'à l'arrêt.
	if _rolling:
		_face(_roll_dir, delta)
	elif moving:
		_face(direction, delta, 16.0)
	elif _aim_t > 0.0:
		_face(-pivot.global_transform.basis.z, delta)

	if _rolling:
		_play("Roll")
	elif _hit_anim_t > 0.0:
		_play("HitRecieve")
	elif _shoot_anim_t > 0.0:
		_play("Run_Shoot" if moving else "Idle_Gun_Shoot")
	elif sprinting and Vector2(velocity.x, velocity.z).length() > 5.2:
		_play("Run")
	elif moving:
		_play("Walk")
	elif _aim_t > 0.0:
		_play("Idle_Gun_Pointing")
	else:
		_play("Idle")

	move_and_slide()


# --------------------------------------------------------------------------- arme

func _update_weapon(delta: float) -> void:
	# Changement d'arme : lecture directe (clavier, manette, molette, tactile).
	if controls_enabled and not _rolling:
		if Input.is_action_just_pressed("weapon_next") or Input.is_action_just_pressed("weapon_next_wheel"):
			cycle_weapon(1)
		elif Input.is_action_just_pressed("weapon_prev") or Input.is_action_just_pressed("weapon_prev_wheel"):
			cycle_weapon(-1)
		elif Input.is_action_just_pressed("weapon_1"):
			switch_weapon(0)
		elif Input.is_action_just_pressed("weapon_2"):
			switch_weapon(1)
		elif Input.is_action_just_pressed("weapon_3"):
			switch_weapon(2)
		elif Input.is_action_just_pressed("weapon_4"):
			switch_weapon(3)
	_recoil = maxf(_recoil - delta * 5.0, 0.0)
	if camera != null:
		camera.rotation.x = _recoil * 0.02   # petit coup vers le haut, qui s'estompe
	_shoot_cd = maxf(_shoot_cd - delta, 0.0)
	_aim_t = maxf(_aim_t - delta, 0.0)
	_shoot_anim_t = maxf(_shoot_anim_t - delta, 0.0)
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash.light_energy = 0.0

	if reloading:
		_reload_t -= delta
		if _reload_t <= 0.0:
			reloading = false
			ammo = magazine
			ammo_changed.emit(ammo, magazine, reloading)
		return

	if not controls_enabled or _rolling:
		return
	if Input.is_action_just_pressed("grenade"):
		throw_grenade()
	# Zoom du fusil de precision quand on vise.
	if camera != null:
		var w: Dictionary = WEAPONS[current_weapon]
		var want_zoom := bool(w["zoom"]) and (Input.is_action_pressed("shoot") or _aim_t > 0.0)
		camera.fov = lerpf(camera.fov, 46.0 if want_zoom else 70.0, clampf(delta * 8.0, 0.0, 1.0))
	var want_fire := Input.is_action_pressed("shoot")
	if Settings.auto_shoot and Settings.aim_assist and _on_target:
		want_fire = true   # accessibilite : le tir part tout seul sur cible verrouillee
	if Input.is_action_just_pressed("reload") and ammo < magazine:
		_start_reload()
	elif want_fire and _shoot_cd <= 0.0:
		_fire()


func _start_reload() -> void:
	reloading = true
	_reload_t = reload_time
	_play_sfx("reload")
	ammo_changed.emit(ammo, magazine, reloading)


func _play_sfx(sfx_name: String) -> void:
	if sfx.is_valid():
		sfx.call(sfx_name)


func _fire() -> void:
	_shoot_cd = fire_interval
	if ammo <= 0:
		_play_sfx("empty")
		_start_reload()
		return
	ammo -= 1
	ammo_changed.emit(ammo, magazine, reloading)
	_aim_t = 0.5
	_shoot_anim_t = 0.25
	_play(("Run_Shoot" if Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.1 else "Idle_Gun_Shoot"), true)
	_play_sfx("shoot")
	_recoil = minf(_recoil + 0.5, 1.0)
	_shake = maxf(_shake, 0.10)
	_flash.light_energy = 0.8 if Settings.reduce_flashes else 3.0
	_flash_t = 0.06

	# 1) Où vise le réticule ? Rayon depuis la caméra, en partant à hauteur du joueur
	#    pour ne pas toucher ce qui se trouve derrière lui.
	var space := get_world_3d().direct_space_state
	var screen_center := get_viewport().get_visible_rect().size * 0.5
	var cam_origin := camera.project_ray_origin(screen_center)
	var cam_dir := camera.project_ray_normal(screen_center)
	var chest := global_position + Vector3(0.0, 1.35, 0.0)
	var start := cam_origin + cam_dir * cam_origin.distance_to(chest)
	var aim_point := start + cam_dir * shot_range
	# Aide à la visée douce : pour tout le monde (souris comprise), dès
	# qu'elle est activée dans les Options. Elle ne fait que caler le point
	# visé sur le centre du monstre le plus proche du réticule.
	if Settings.aim_assist:
		var assisted := _assist_target(cam_origin, cam_dir)
		if assisted != Vector3.INF:
			aim_point = assisted
	var q1 := PhysicsRayQueryParameters3D.create(start, aim_point, 1 | 4)
	q1.hit_from_inside = true
	var r1 := space.intersect_ray(q1)
	if not r1.is_empty():
		aim_point = r1["position"]

	# 2) Le tir part de la poitrine du joueur vers ce point.
	var shot_dir := (aim_point - chest).normalized()
	var end := chest + shot_dir * shot_range
	var w: Dictionary = WEAPONS[current_weapon]
	shots_fired += 1
	var hit_any := false
	var muzzle := chest + shot_dir * 0.55 + model.global_transform.basis.x * 0.22 + Vector3(0.0, -0.05, 0.0)
	for pellet in range(int(w["pellets"])):
		var dir := shot_dir
		var spread := deg_to_rad(float(w["spread"]))
		if spread > 0.0:
			dir = (shot_dir + Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)) * spread).normalized()
		var pend := chest + dir * shot_range
		var q2 := PhysicsRayQueryParameters3D.create(chest, pend, 1 if int(w["pierce"]) > 0 else 1 | 4)
		q2.hit_from_inside = true
		var r2 := space.intersect_ray(q2)
		if not r2.is_empty():
			pend = r2["position"]
		var dmg := shot_damage
		var crit := randf() < crit_chance
		if crit:
			dmg *= 2
		if _power_damage_t > 0.0:
			dmg *= 2   # pouvoir rage
		if int(w["pierce"]) > 0:
			var max_d := chest.distance_to(pend)
			var targets: Array = []
			for e in get_tree().get_nodes_in_group("enemy"):
				if e.dying:
					continue
				var c: Vector3 = e.aim_point() if e.has_method("aim_point") else e.global_position
				var rel := c - chest
				var along := rel.dot(dir)
				if along < 1.0 or along > max_d:
					continue
				if (chest + dir * along).distance_to(c) <= float(e.get("body_radius")) + 0.4:
					targets.append([along, e])
			targets.sort_custom(func(a, b): return a[0] < b[0])
			for i in range(mini(int(w["pierce"]), targets.size())):
				targets[i][1].take_hit(dmg, crit)
				hit_any = true
			if hit_any:
				_impact_fx(pend, Color(1.0, 0.85, 0.5))
		elif not r2.is_empty():
			var hit = r2["collider"]
			if hit != null and hit.has_method("take_hit"):
				hit.take_hit(dmg, crit)
				hit_any = true
				_impact_fx(pend, Color(1.0, 0.85, 0.5))
		if pellet < 3:
			_spawn_tracer(muzzle, pend)
	if hit_any:
		shots_hit += 1
		hit_confirmed.emit()   # le réticule clignote (voir hud.gd)
	_recoil = minf(_recoil + float(w["recoil"]) - 0.5, 1.4)


## Aide à la visée : renvoie le point à viser sur le monstre le mieux placé
## dans le cône du réticule, ou Vector3.INF s'il n'y en a pas.
func _assist_target(cam_origin: Vector3, cam_dir: Vector3) -> Vector3:
	var e := _find_assist_enemy(cam_origin, cam_dir)
	if e == null:
		return Vector3.INF
	return e.aim_point() if e.has_method("aim_point") else e.global_position + Vector3(0.0, 0.6, 0.0)


## Monstre à verrouiller : le plus proche du centre du réticule, dans le cône
## (plus large au tactile), à portée, et VISIBLE (pas derrière un mur, une
## tombe...). La cible précédente bénéficie d'un petit bonus (hystérésis) pour
## éviter que le verrouillage saute d'un monstre à l'autre à chaque image.
func _find_assist_enemy(cam_origin: Vector3, cam_dir: Vector3) -> Node3D:
	var cone := assist_cone_touch if Settings.is_touch() else assist_cone_mouse
	var chest := global_position + Vector3(0.0, 1.35, 0.0)
	var best: Node3D = null
	var best_score := cone
	if _aim_target != null and (not is_instance_valid(_aim_target) or bool(_aim_target.get("dying"))):
		_aim_target = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.dying:
			continue
		var centre: Vector3 = e.aim_point() if e.has_method("aim_point") else e.global_position + Vector3(0.0, 0.6, 0.0)
		var to_e := centre - cam_origin
		var dist := to_e.length()
		if dist > shot_range or dist < 1.2:
			continue
		var angle := rad_to_deg(acos(clampf(cam_dir.dot(to_e.normalized()), -1.0, 1.0)))
		if angle > cone:
			continue
		if not _has_line_of_sight(chest, centre, e):
			continue
		var score := angle - (2.5 if e == _aim_target else 0.0)   # on garde sa cible
		if score < best_score:
			best_score = score
			best = e
	_aim_target = best
	return best


## Vrai si rien de solide (décor) ne se trouve entre le joueur et le point visé.
func _has_line_of_sight(from: Vector3, to: Vector3, target: Node) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	q.hit_from_inside = true
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return true
	return hit["collider"] == target


## État du réticule (balayage léger, 20 fois par seconde) : allumé si un
## monstre est sous le viseur ou verrouillé par l'aide à la visée.
func _update_aim_state(_delta: float) -> void:
	_aim_scan_t -= _delta
	if _aim_scan_t > 0.0:
		return
	_aim_scan_t = 0.05
	if not controls_enabled or dead or camera == null:
		_set_on_target(false)
		return
	if Settings.aim_assist and _find_assist_enemy(camera.global_position, -camera.global_transform.basis.z) != null:
		_set_on_target(true)
		return
	var screen_center := get_viewport().get_visible_rect().size * 0.5
	var cam_origin := camera.project_ray_origin(screen_center)
	var cam_dir := camera.project_ray_normal(screen_center)
	var chest := global_position + Vector3(0.0, 1.35, 0.0)
	var start := cam_origin + cam_dir * cam_origin.distance_to(chest)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(start, start + cam_dir * shot_range, 1 | 4)
	var hit := space.intersect_ray(q)
	_set_on_target(not hit.is_empty() and hit["collider"] != null and hit["collider"].has_method("take_hit"))


func _set_on_target(on: bool) -> void:
	if on == _on_target:
		return
	_on_target = on
	aim_changed.emit(on)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.1:
		return
	var tracer := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.025, 0.025, length)
	tracer.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.5)
	tracer.material_override = mat
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(tracer)
	var look_dir := (to - from).normalized()
	var up := Vector3.UP if absf(look_dir.y) < 0.99 else Vector3.RIGHT
	tracer.global_transform = Transform3D(Basis.looking_at(look_dir, up), (from + to) * 0.5)
	get_tree().create_timer(0.05).timeout.connect(tracer.queue_free)


func _face(dir: Vector3, delta: float, speed: float = -1.0) -> void:
	if dir.length() < 0.01:
		return
	var s := turn_speed if speed < 0.0 else speed
	model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), s * delta)


func _start_roll(direction: Vector3) -> void:
	var dir := direction
	if dir.length() < 0.1:
		dir = Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	_roll_dir = dir.normalized()
	_rolling = true
	_roll_t = roll_duration
	if anim != null and _anims.has("Roll"):
		var a: Animation = anim.get_animation(_anims["Roll"])
		anim.speed_scale = maxf(a.length, 0.1) / roll_duration
	_play("Roll", true)
	_play_sfx("roll")


func _play(key: String, restart: bool = false) -> void:
	if anim == null or not _anims.has(key):
		return
	if _current_anim == key and not restart:
		return
	_current_anim = key
	anim.play(_anims[key], 0.12)


## Secousse camera demandee par le jeu (explosion, boss...).
func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Pouvoirs ramassés (appelés par game.gd).
func grant_shield(points: int, seconds: float) -> void:
	shield_points = points
	_shield_t = seconds
	shield_changed.emit(shield_points)


func grant_power(kind: String, seconds: float) -> void:
	if kind == "rage":
		_power_damage_t = seconds
	elif kind == "swift":
		_power_speed_t = seconds


func take_damage(amount: int) -> void:
	if dead or invulnerable or _invincible > 0.0:
		return
	_shake = maxf(_shake, 0.25 if Settings.reduce_flashes else 0.55)
	if shield_points > 0:
		var absorbed := mini(shield_points, amount)
		shield_points -= absorbed
		amount -= absorbed
		shield_changed.emit(shield_points)
		if amount <= 0:
			damaged.emit()   # retour visuel, mais aucun PV perdu
			return
	health = maxi(health - amount, 0)
	_invincible = hit_invincibility
	_hit_anim_t = 0.35
	health_changed.emit(health, max_health)
	damaged.emit()
	_play_sfx("hurt")
	if Settings.is_touch() and Settings.vibration:
		Input.vibrate_handheld(70)
	if health <= 0:
		_die()
	elif not _rolling:
		_play("HitRecieve", true)


func heal(amount: int) -> void:
	if dead:
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


func _die() -> void:
	dead = true
	velocity = Vector3.ZERO
	controls_enabled = false
	if anim != null:
		anim.speed_scale = 1.0
	_play("Death", true)
	died.emit()
