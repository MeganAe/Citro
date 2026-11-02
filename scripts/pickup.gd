extends Node3D
## Objet à ramasser : "heal" (citrouille qui soigne) ou "candle" (bougies qui figent les monstres).
## Créé par game.gd avec setup(kind). La collecte est détectée par game.gd.

const Props = preload("res://scripts/props.gd")

var kind := "heal"
var collected := false

var _model: Node3D
var _t := 0.0


func setup(k: String) -> void:
	kind = k
	if kind == "grenade":
		# Grenade 3D (pack Kenney) : +2 grenades a lancer avec la touche G.
		_model = Node3D.new()
		var inst = (load("res://assets/weapons/grenade-a.glb") as PackedScene).instantiate() as Node3D
		var aabb := Props.local_aabb(inst)
		var s := 0.5 / maxf(aabb.size.y, 0.001)
		inst.scale = Vector3.ONE * s
		inst.position = Vector3(-(aabb.position.x + aabb.size.x * 0.5) * s, -aabb.position.y * s, -(aabb.position.z + aabb.size.z * 0.5) * s)
		_model.add_child(inst)
		Props.make_glow(_model, Color(0.55, 1.0, 0.5), 0.7)
		add_child(_model)
		_add_light_and_beam(Color(0.55, 1.0, 0.5))
		return
	# heal = citrouille orange, candle = bougies de gel, shield = citrouille
	# jaune bleutee, rage = bougie rouge, swift = bougie fine verte.
	var table := {
		"heal": ["pumpkin_orange_small.fbx", 0.55, Color(1.0, 0.55, 0.15)],
		"shield": ["pumpkin_yellow_small.fbx", 0.55, Color(0.35, 0.65, 1.0)],
		"rage": ["candle.fbx", 0.7, Color(1.0, 0.25, 0.15)],
		"swift": ["candle_thin.fbx", 0.7, Color(0.45, 1.0, 0.60)],
	}
	var data: Array = table.get(kind, ["candle_triple.fbx", 0.7, Color(0.55, 0.85, 1.0)])
	var file := String(data[0])
	var height := float(data[1])
	var glow: Color = data[2]

	_model = Props.make_fitted(file, height, false)
	Props.make_glow(_model, glow, 0.9)
	add_child(_model)
	_add_light_and_beam(glow)


func _add_light_and_beam(glow: Color) -> void:
	var light := OmniLight3D.new()
	light.light_color = glow
	light.light_energy = 1.4
	light.omni_range = 6.0
	light.position = Vector3(0.0, 0.9, 0.0)
	add_child(light)

	# Faisceau lumineux : permet de repérer l'objet de loin.
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.12
	cyl.height = 7.0
	cyl.radial_segments = 12
	beam.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(glow.r, glow.g, glow.b, 0.22)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = Vector3(0.0, 3.5, 0.0)
	add_child(beam)


func _process(delta: float) -> void:
	_t += delta
	if _model != null:
		_model.position.y = 0.35 + sin(_t * 2.4) * 0.12
		_model.rotation.y += delta * 1.2


func collect() -> void:
	if collected:
		return
	collected = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.02, 0.25)
	tw.tween_callback(queue_free)
