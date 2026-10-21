extends Node3D

# Osmanlı Kale Savunması: Godot denemesi.
# Harita, yol, surlar, şehir, Okçu Kulesi ve Piyade ile tek ekranlık oynanabilir sahne.
# Kurallar CLAUDE.md ile aynıdır; mantık kare biriminde çalışır, dünyaya to_world ile çevrilir.

const COLS := 9
const ROWS := 16
const WALL_ROW := 12
const PATH := [
	Vector2(1, -1), Vector2(1, 2), Vector2(6, 2), Vector2(6, 5), Vector2(2, 5),
	Vector2(2, 8), Vector2(7, 8), Vector2(7, 10), Vector2(4, 10), Vector2(4, 12),
]
const CITY := [
	["building_castle", 4, 14, 0.72, 0.0],
	["building_home_A", 1, 13, 0.9, 0.3],
	["building_home_B", 2, 13.1, 0.8, -0.2],
	["building_barracks", 7, 13.2, 0.62, 3.14],
	["building_archeryrange", 0.3, 14.3, 0.55, 1.57],
	["building_market", 6, 14.4, 0.55, 3.14],
	["building_home_A", 2.4, 15, 0.85, 1.2],
	["building_tavern", 1.2, 15, 0.7, 0.4],
	["building_home_B", 5.8, 15.2, 0.8, -0.6],
	["building_blacksmith", 7.2, 15.1, 0.6, 2.6],
	["building_well", 2.6, 14.1, 0.7, 0.0],
	["building_windmill", 8.1, 15.0, 0.6, 2.2],
	["building_home_A", 8.3, 13.2, 0.8, 2.0],
]

const ARCHER := {"cost": 50, "range": 2.6, "damage": 11.0, "rate": 0.55, "speed": 10.0}
const INFANTRY := {"hp": 42.0, "speed": 1.1, "reward": 5, "wall": 1}
const BYZANTIUM := Color("#6b2d8f")
const BYZ_TRIM := Color("#e8c547")
const MAX_WAVES := 5

var lib: Node3D
var lib_nodes := {}
var knight_scene: PackedScene

var path_world: Array[Vector3] = []
var path_cum: Array[float] = []
var path_total := 0.0
var path_tiles := {}
var blocked := {}

var akce := 220
var sur := 20
var wave := 0
var wave_active := false
var spawn_left := 0
var spawn_timer := 0.0
var game_speed := 1.0
var game_over := false

var enemies: Array = []
var towers: Array = []
var arrows: Array = []
var torches: Array = []

var camera: Camera3D
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var ground_mat: ShaderMaterial
var time_of_day := 0
var range_ring: MeshInstance3D
var hover_tile: MeshInstance3D

var ui: CanvasLayer
var bars_layer: Control
var lbl_akce: Label
var lbl_sur: Label
var lbl_wave: Label
var btn_wave: Button
var btn_time: Button
var btn_speed: Button
var banner: Label
var hint: Label

var flag_tex: ImageTexture
var fire_mat: StandardMaterial3D
var dust_mat: StandardMaterial3D
var rng := RandomNumberGenerator.new()
var enemy_mats := {}


func _ready() -> void:
	rng.seed = 1453
	lib = load("res://assets/models/medieval.glb").instantiate()
	for c in lib.get_children():
		var n := String(c.name)
		if n.ends_with("2") and not n.ends_with("_2"):
			n = n.substr(0, n.length() - 1)
		lib_nodes[n] = c
	knight_scene = load("res://assets/models/knight.glb")
	_make_shared_materials()
	_build_path()
	_build_environment()
	_build_ground()
	_build_grass()
	_build_walls()
	_build_city()
	_build_camp()
	_build_decor()
	_build_markers()
	_build_ui()
	_place_tower(Vector2i(3, 3), true)
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()
	_apply_time_of_day(true)
	_show_banner("Kaleyi savun!\nBoş kareye dokun: Okçu Kulesi kur", 4.0)
	_debug_shot()


# ---------------------------------------------------------------- yardımcılar

func to_world(c: float, r: float, y := 0.0) -> Vector3:
	return Vector3(c + 0.5 - COLS / 2.0, y, r + 0.5 - ROWS / 2.0)


func prop(name: String, s: float) -> Node3D:
	var src: Node3D = lib_nodes[name]
	var m: Node3D = src.duplicate()
	m.transform = Transform3D.IDENTITY
	m.scale = Vector3.ONE * s
	return m


func place(name: String, pos: Vector3, s: float, rot := 0.0, parent: Node = null) -> Node3D:
	var m := prop(name, s)
	m.position = pos
	m.rotation.y = rot
	(parent if parent else self).add_child(m)
	return m


func mat(color: Color, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func _make_shared_materials() -> void:
	fire_mat = StandardMaterial3D.new()
	fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_mat.vertex_color_use_as_albedo = true
	fire_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fire_mat.albedo_texture = _soft_dot_texture()
	dust_mat = fire_mat.duplicate()
	dust_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	flag_tex = _ottoman_flag_texture()


func _soft_dot_texture() -> ImageTexture:
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5 - s / 2.0, y + 0.5 - s / 2.0).length() / (s / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


# Kırmızı zemin üstünde beyaz hilal ve yıldız
func _ottoman_flag_texture() -> ImageTexture:
	var w := 96
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var red := Color("#c41e2a")
	var c1 := Vector2(40, 32)
	var c2 := Vector2(46, 32)
	var star := Vector2(62, 32)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var col := red
			if p.distance_to(c1) < 17 and p.distance_to(c2) > 14:
				col = Color.WHITE
			var q := p - star
			var ang := atan2(q.y, q.x) + PI / 2.0
			var k := cos(5.0 * ang) * 0.5 + 0.5
			if q.length() < lerpf(3.5, 8.0, pow(k, 3.0)):
				col = Color.WHITE
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _nation_flag_texture(a: Color, b: Color) -> ImageTexture:
	var img := Image.create(64, 40, false, Image.FORMAT_RGBA8)
	for y in 40:
		for x in 64:
			var col := a
			if Vector2(x - 26, y - 20).length() < 9.0 or y < 4 or y > 35:
				col = b
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _flag(tex: Texture2D, w: float, h: float) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.orientation = PlaneMesh.FACE_Z
	pm.size = Vector2(w, h)
	pm.subdivide_width = 10
	pm.subdivide_depth = 2
	pm.center_offset = Vector3(w / 2.0, 0, 0)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/flag.gdshader")
	sm.set_shader_parameter("tex", tex)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = sm
	return mi


func _fire(parent: Node3D, pos: Vector3, size := 1.0, light := true) -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14) * size
	q.material = fire_mat
	p.mesh = q
	p.amount = 18
	p.lifetime = 0.55
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.04 * size
	p.direction = Vector3.UP
	p.spread = 12
	p.gravity = Vector3(0, 0.9, 0)
	p.initial_velocity_min = 0.15 * size
	p.initial_velocity_max = 0.35 * size
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.6))
	sc.add_point(Vector2(0.3, 1.0))
	sc.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(1.8, 1.3, 0.6, 0.9))
	g.set_color(1, Color(0.5, 0.08, 0.02, 0.0))
	g.add_point(0.45, Color(1.4, 0.5, 0.1, 0.7))
	p.color_ramp = g
	p.position = pos
	parent.add_child(p)
	if light:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.62, 0.28)
		l.omni_range = 2.4 * size
		l.omni_attenuation = 1.4
		l.light_energy = 0.0
		l.position = pos + Vector3(0, 0.12, 0)
		parent.add_child(l)
		torches.append({"light": l, "phase": rng.randf() * 10.0, "base": 1.6 * size})


func _burst(pos: Vector3, color: Color, count := 16, speed := 1.4, size := 0.1, life := 0.6, grav := -2.0, glow := false) -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = fire_mat if glow else dust_mat
	p.mesh = q
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = count
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 80
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, grav, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	var g := Gradient.new()
	g.set_color(0, color)
	var end := color
	end.a = 0.0
	g.set_color(1, end)
	p.color_ramp = g
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.5))
	sc.add_point(Vector2(0.4, 1.0))
	sc.add_point(Vector2(1, 0.6))
	p.scale_amount_curve = sc
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


# ---------------------------------------------------------------- yol

func _build_path() -> void:
	var pts := PATH.duplicate()
	pts[0] = Vector2(1, -2.2)
	for p in pts:
		path_world.append(to_world(p.x, p.y))
	path_cum.append(0.0)
	for i in range(1, path_world.size()):
		path_total += path_world[i].distance_to(path_world[i - 1])
		path_cum.append(path_total)
	for i in range(PATH.size() - 1):
		var a: Vector2 = PATH[i]
		var b: Vector2 = PATH[i + 1]
		var steps := int(max(abs(b.x - a.x), abs(b.y - a.y)))
		for s in steps + 1:
			var t := a.lerp(b, float(s) / max(steps, 1))
			path_tiles[Vector2i(roundi(t.x), roundi(t.y))] = true


func path_point(d: float) -> Vector3:
	d = clampf(d, 0.0, path_total)
	for i in range(1, path_cum.size()):
		if d <= path_cum[i]:
			var t := (d - path_cum[i - 1]) / (path_cum[i] - path_cum[i - 1])
			return path_world[i - 1].lerp(path_world[i], t)
	return path_world[-1]


# ---------------------------------------------------------------- ışık ve gökyüzü

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 34.0
	env.fog_depth_end = 80.0
	env.fog_depth_curve = 1.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_blur = 1.4
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	add_child(sun)

	camera = Camera3D.new()
	camera.fov = 36
	camera.near = 0.2
	camera.far = 140.0
	add_child(camera)


# 0: öğle, 1: ikindi (altın saat), 2: gece
func _apply_time_of_day(instant := false) -> void:
	var presets := [
		{"sun_rot": Vector3(-58, -150, 0), "sun_col": Color(1.0, 0.95, 0.86), "sun_e": 2.4,
			"top": Color(0.32, 0.55, 0.88), "hor": Color(0.74, 0.84, 0.92), "gnd": Color(0.45, 0.5, 0.42),
			"amb": 0.75, "amb_col": Color(0.78, 0.8, 0.85), "fog": Color(0.74, 0.82, 0.88), "torch": 0.0, "exp": 1.1, "name": "Öğle"},
		{"sun_rot": Vector3(-24, -120, 0), "sun_col": Color(1.0, 0.72, 0.45), "sun_e": 2.6,
			"top": Color(0.28, 0.42, 0.72), "hor": Color(1.0, 0.7, 0.45), "gnd": Color(0.38, 0.32, 0.26),
			"amb": 0.6, "amb_col": Color(0.75, 0.62, 0.62), "fog": Color(0.95, 0.72, 0.52), "torch": 0.7, "exp": 1.1, "name": "İkindi"},
		{"sun_rot": Vector3(-50, -200, 0), "sun_col": Color(0.55, 0.65, 1.0), "sun_e": 0.45,
			"top": Color(0.02, 0.04, 0.12), "hor": Color(0.1, 0.14, 0.28), "gnd": Color(0.04, 0.05, 0.08),
			"amb": 0.4, "amb_col": Color(0.22, 0.28, 0.55), "fog": Color(0.08, 0.1, 0.2), "torch": 1.6, "exp": 1.3, "name": "Gece"},
	]
	var p: Dictionary = presets[time_of_day]
	var dur := 0.01 if instant else 1.6
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sun, "rotation_degrees", p.sun_rot, dur)
	tw.tween_property(sun, "light_color", p.sun_col, dur)
	tw.tween_property(sun, "light_energy", p.sun_e, dur)
	tw.tween_property(sky_mat, "sky_top_color", p.top, dur)
	tw.tween_property(sky_mat, "sky_horizon_color", p.hor, dur)
	tw.tween_property(sky_mat, "ground_horizon_color", p.hor, dur)
	tw.tween_property(sky_mat, "ground_bottom_color", p.gnd, dur)
	tw.tween_property(env, "ambient_light_energy", p.amb, dur)
	tw.tween_property(env, "ambient_light_color", p.amb_col, dur)
	tw.tween_property(env, "fog_light_color", p.fog, dur)
	tw.tween_property(env, "tonemap_exposure", p.exp, dur)
	tw.tween_method(func(v): torch_level = v, torch_level, p.torch, dur)
	if btn_time:
		btn_time.text = p["name"]


var torch_level := 0.0


# ---------------------------------------------------------------- zemin, çim

func _build_ground() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(70, 70)
	pm.subdivide_width = 4
	pm.subdivide_depth = 4
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = load("res://shaders/ground.gdshader")
	var pts := PackedVector2Array()
	for p in path_world:
		pts.append(Vector2(p.x, p.z))
	ground_mat.set_shader_parameter("pts", pts)
	ground_mat.set_shader_parameter("count", pts.size())
	ground_mat.set_shader_parameter("wall_z", to_world(0, WALL_ROW).z)
	var g := MeshInstance3D.new()
	g.mesh = pm
	g.material_override = ground_mat
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)


func _grass_tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 7:
		var a := r.randf() * TAU
		var off := Vector3(cos(a), 0, sin(a)) * r.randf_range(0.0, 0.05)
		var side := Vector3(cos(a + PI / 2), 0, sin(a + PI / 2)) * 0.018
		var lean := Vector3(cos(a), 0, sin(a)) * r.randf_range(0.02, 0.06)
		var h := r.randf_range(0.09, 0.17)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(off - side)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(off + side)
		st.set_uv(Vector2(0.5, 1))
		st.add_vertex(off + lean + Vector3(0, h, 0))
	st.generate_normals()
	return st.commit()


func _build_grass() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _grass_tuft_mesh()
	var xforms: Array[Transform3D] = []
	var wall_z := to_world(0, WALL_ROW).z
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var tries := 0
	while xforms.size() < 3600 and tries < 30000:
		tries += 1
		var p := Vector3(r.randf_range(-8.5, 8.5), 0, r.randf_range(-11.5, wall_z - 0.45))
		if _dist_to_path(p) < 0.5:
			continue
		var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * r.randf_range(0.7, 1.5))
		xforms.append(Transform3D(b, p))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		var v := r.randf_range(0.8, 1.15)
		mm.set_instance_color(i, Color(v * r.randf_range(0.95, 1.05), v, v * 0.9))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/grass.gdshader")
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _dist_to_path(p: Vector3) -> float:
	var q := Vector2(p.x, p.z)
	var best := 1e9
	for i in range(1, path_world.size()):
		var a := Vector2(path_world[i - 1].x, path_world[i - 1].z)
		var b := Vector2(path_world[i].x, path_world[i].z)
		var ab := b - a
		var t := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = min(best, q.distance_to(a + ab * t))
	return best


# ---------------------------------------------------------------- surlar, şehir, ordugâh

func _build_walls() -> void:
	var z := to_world(0, WALL_ROW).z
	var ws := 0.75
	place("wall_straight_gate", Vector3(0, 0, z), ws)
	var step := 2.0 * ws
	var x := step
	while x < COLS / 2.0 + step:
		for s in [-1, 1]:
			place("wall_straight", Vector3(s * x, 0, z), ws)
		x += step
	var lead := mat(Color("#7d8a99"), 0.55)
	var gold := mat(Color("#e0b24a"), 0.35)
	gold.metallic = 0.8
	for t in [[-0.95, 0.72], [0.95, 0.72], [-COLS / 2.0 + 0.15, 0.62], [COLS / 2.0 - 0.15, 0.62]]:
		var tx: float = t[0]
		var sc: float = t[1]
		place("building_tower_base", Vector3(tx, 0, z), sc, PI)
		var top := 1.5 * sc
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.47 * sc
		cone.height = 0.52
		cone.radial_segments = 16
		var roof := MeshInstance3D.new()
		roof.mesh = cone
		roof.material_override = lead
		roof.position = Vector3(tx, top + 0.26, z)
		add_child(roof)
		var ball := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.045
		sp.height = 0.09
		ball.mesh = sp
		ball.material_override = gold
		ball.position = Vector3(tx, top + 0.54, z)
		add_child(ball)
		_pole(Vector3(tx, top + 0.5, z), 0.55)
		var f := _flag(flag_tex, 0.44, 0.29)
		f.position = Vector3(tx + 0.01, top + 0.9, z)
		add_child(f)
	# şehrin arka ve yan surları
	var zb := ROWS / 2.0 + 0.15
	x = -COLS / 2.0 + ws
	while x < COLS / 2.0:
		place("wall_straight", Vector3(x, 0, zb), ws)
		x += step
	for s in [-1, 1]:
		var zz := z + ws
		while zz < zb:
			place("wall_straight", Vector3(s * (COLS / 2.0 + 0.1), 0, zz), ws, PI / 2)
			zz += step
		place("building_tower_base", Vector3(s * (COLS / 2.0 + 0.1), 0, zb), 0.62, PI)
	# kapının iki yanında meşaleler
	for s in [-1, 1]:
		var pos := Vector3(s * 0.42, 0, z + 0.5)
		_pole(pos, 0.7)
		_fire(self, pos + Vector3(0, 0.74, 0), 1.0)
	# burçların üstünde nöbet ateşi
	_fire(self, Vector3(-0.95, 1.5 * 0.72 + 0.05, z + 0.32), 0.8)
	_fire(self, Vector3(0.95, 1.5 * 0.72 + 0.05, z + 0.32), 0.8)


func _pole(base: Vector3, h: float) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.015
	cm.bottom_radius = 0.02
	cm.height = h
	cm.radial_segments = 6
	var m := MeshInstance3D.new()
	m.mesh = cm
	m.material_override = mat(Color("#6e4424"))
	m.position = base + Vector3(0, h / 2.0, 0)
	add_child(m)


func _build_city() -> void:
	for b in CITY:
		var p := to_world(b[1], b[2])
		place(b[0], p, b[3], b[4])
	# saray sancağı
	var cp := to_world(4, 14)
	_pole(cp + Vector3(0, 1.95, 0), 0.6)
	var f := _flag(flag_tex, 0.5, 0.33)
	f.position = cp + Vector3(0.01, 2.4, 0)
	add_child(f)
	# şehrin içinde fener ışıkları
	for t in [Vector2(3, 13), Vector2(5, 15), Vector2(5, 13), Vector2(2, 14)]:
		var pos := to_world(t.x, t.y) + Vector3(0.3, 0, 0.3)
		_pole(pos, 0.45)
		_fire(self, pos + Vector3(0, 0.48, 0), 0.6)


func _build_camp() -> void:
	var c := to_world(1, -1.6)
	var camp := Node3D.new()
	camp.position = c
	add_child(camp)
	for t in [[-1.1, -0.5, 0.4], [1.1, -0.3, -0.5], [-0.6, -1.4, 0.9], [0.9, -1.4, -0.2], [2.1, -0.9, 0.2]]:
		place("tent", Vector3(t[0], 0, t[1]), 1.5, t[2], camp)
	for t in [[-0.6, 0.5], [0.7, 0.4], [1.6, 0.1]]:
		place(["barrel", "crate_A_big", "sack"][rng.randi() % 3], Vector3(t[0], 0, t[1]), 1.6, rng.randf() * TAU, camp)
	place("weaponrack", Vector3(-1.5, 0, 0.2), 1.6, 0.3, camp)
	_fire(camp, Vector3(0.1, 0.06, -0.5), 1.0)
	# düşman sancakları (Bizans: mor ve altın)
	var ntex := _nation_flag_texture(BYZANTIUM, BYZ_TRIM)
	for s in [-1, 1]:
		var base := c + Vector3(s * 0.55, 0, 0.55)
		_pole(base, 1.0)
		var f := _flag(ntex, 0.45, 0.3)
		f.position = base + Vector3(0.01, 0.84, 0)
		add_child(f)


func _build_decor() -> void:
	var half := COLS / 2.0
	var wall_z := to_world(0, WALL_ROW).z
	# tahtanın iki yanı: ağaçlar ve tepeler
	for side in [-1, 1]:
		var z := -11.0
		while z < wall_z + 4.0:
			var x: float = side * rng.randf_range(half + 0.6, half + 2.6)
			var kind: String = ["trees_A_medium", "trees_B_medium", "trees_A_small", "hills_A_trees", "tree_single_A", "tree_single_B"][rng.randi() % 6]
			place(kind, Vector3(x, 0, z), rng.randf_range(0.55, 0.85), rng.randf() * TAU)
			z += rng.randf_range(0.9, 1.6)
		var z2 := -11.0
		while z2 < wall_z + 5.0:
			var x: float = side * rng.randf_range(half + 2.8, half + 5.0)
			place(["trees_A_medium", "trees_B_medium", "hills_B_trees"][rng.randi() % 3], Vector3(x, 0, z2), rng.randf_range(0.9, 1.3), rng.randf() * TAU)
			z2 += rng.randf_range(1.2, 2.0)
	# kuzeyde dağlar
	for i in 9:
		var x := -9.0 + i * 2.3 + rng.randf_range(-0.5, 0.5)
		place(["trees_A_medium", "trees_B_medium", "trees_A_medium"][i % 3], Vector3(x, 0, -11.5 - rng.randf_range(0, 2.5)), rng.randf_range(1.1, 1.5), rng.randf() * TAU)
	# tahtanın içinde yola uzak birkaç kaya ve ağaç (bu karelere kule kurulamaz)
	for r in range(0, WALL_ROW):
		for col in COLS:
			var key := Vector2i(col, r)
			if path_tiles.has(key) or rng.randf() > 0.1:
				continue
			if key == Vector2i(3, 3):
				continue
			var p := to_world(col, r) + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
			var kind: String = ["rock_single_C", "rock_single_E", "tree_single_A", "tree_single_B", "rock_single_B"][rng.randi() % 5]
			place(kind, p, rng.randf_range(0.6, 1.0) if kind.begins_with("rock") else rng.randf_range(0.6, 0.8), rng.randf() * TAU)
			blocked[key] = true
	# yol kenarında çakıl
	for i in 60:
		var d := rng.randf() * path_total
		var p := path_point(d)
		var off := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.36, 0.48)
		place("rock_single_A", p + off, rng.randf_range(0.25, 0.45), rng.randf() * TAU)


func _build_markers() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.97
	ring.outer_radius = 1.0
	ring.rings = 64
	ring.ring_segments = 4
	range_ring = MeshInstance3D.new()
	range_ring.mesh = ring
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1.4, 1.2, 0.6)
	range_ring.material_override = rm
	range_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	range_ring.visible = false
	add_child(range_ring)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.01
	disc.radial_segments = 48
	var dm := MeshInstance3D.new()
	dm.mesh = disc
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.albedo_color = Color(1, 0.9, 0.5, 0.12)
	dm.material_override = dmat
	dm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	range_ring.add_child(dm)

	var bm := BoxMesh.new()
	bm.size = Vector3(0.96, 0.02, 0.96)
	hover_tile = MeshInstance3D.new()
	hover_tile.mesh = bm
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.albedo_color = Color(1, 1, 0.8, 0.22)
	hover_tile.material_override = hm
	hover_tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hover_tile.visible = false
	add_child(hover_tile)


# ---------------------------------------------------------------- kamera

func _fit_camera() -> void:
	var pitch := deg_to_rad(54.0)
	var dir := Vector3(0, sin(pitch), cos(pitch))
	var target := Vector3(0, 0, 0.35)
	var corners: Array[Vector3] = []
	for x in [-COLS / 2.0, COLS / 2.0]:
		for z in [-ROWS / 2.0 - 0.6, ROWS / 2.0 + 0.05]:
			for y in [0.0, 1.6]:
				corners.append(Vector3(x, y, z))
	var vs := get_viewport().get_visible_rect().size
	var lo := 4.0
	var hi := 90.0
	for i in 30:
		var mid := (lo + hi) / 2.0
		camera.look_at_from_position(target + dir * mid, target)
		var ok := true
		for c in corners:
			var s := camera.unproject_position(c)
			if s.x < vs.x * 0.02 or s.x > vs.x * 0.98 or s.y < vs.y * 0.09 or s.y > vs.y * 0.93:
				ok = false
				break
		if ok:
			hi = mid
		else:
			lo = mid
	camera.look_at_from_position(target + dir * hi, target)


# ---------------------------------------------------------------- arayüz

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	bars_layer = Control.new()
	bars_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	bars_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bars_layer)

	var theme := Theme.new()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.13, 0.08, 0.05, 0.82)
	panel.border_color = Color("#e0b24a")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(12)
	panel.content_margin_left = 14
	panel.content_margin_right = 14
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	theme.set_stylebox("panel", "PanelContainer", panel)
	var btn := panel.duplicate()
	btn.bg_color = Color("#9e1b25")
	var btn_h := btn.duplicate()
	btn_h.bg_color = Color("#bf2a33")
	var btn_d := btn.duplicate()
	btn_d.bg_color = Color(0.3, 0.2, 0.15, 0.8)
	theme.set_stylebox("normal", "Button", btn)
	theme.set_stylebox("hover", "Button", btn_h)
	theme.set_stylebox("pressed", "Button", btn_h)
	theme.set_stylebox("disabled", "Button", btn_d)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_font_size("font_size", "Button", 24)
	theme.set_font_size("font_size", "Label", 24)
	theme.set_color("font_color", "Label", Color("#f6ead0"))
	theme.set_color("font_color", "Button", Color("#fff6e0"))

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	ui.add_child(root)

	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.position.y = 12
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(top)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 26)
	top.add_child(hb)
	lbl_akce = Label.new()
	lbl_sur = Label.new()
	lbl_wave = Label.new()
	for l in [lbl_akce, lbl_sur, lbl_wave]:
		hb.add_child(l)

	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.position.y -= 16
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.add_theme_constant_override("separation", 12)
	root.add_child(bottom)
	btn_speed = Button.new()
	btn_speed.text = "1×"
	btn_speed.custom_minimum_size = Vector2(70, 56)
	btn_speed.pressed.connect(_on_speed)
	btn_wave = Button.new()
	btn_wave.text = "Dalgayı Başlat"
	btn_wave.custom_minimum_size = Vector2(230, 56)
	btn_wave.pressed.connect(_on_start_wave)
	btn_time = Button.new()
	btn_time.custom_minimum_size = Vector2(150, 56)
	btn_time.pressed.connect(_on_time)
	for b in [btn_speed, btn_wave, btn_time]:
		bottom.add_child(b)

	banner = Label.new()
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 34)
	banner.add_theme_color_override("font_color", Color("#ffe9a8"))
	banner.add_theme_color_override("font_outline_color", Color(0.25, 0.05, 0.02))
	banner.add_theme_constant_override("outline_size", 10)
	banner.position.y -= 160
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner)
	_update_hud()


func _update_hud() -> void:
	lbl_akce.text = "Akçe %d" % akce
	lbl_sur.text = "Sur %d" % sur
	lbl_wave.text = "Dalga %d/%d" % [wave, MAX_WAVES]
	btn_wave.disabled = wave_active or game_over
	btn_wave.text = "Dalga sürüyor" if wave_active else "Dalgayı Başlat"
	if game_over:
		btn_wave.text = "Yeniden başlat için dokun" if sur <= 0 else "Zafer!"


func _show_banner(text: String, dur := 2.4) -> void:
	banner.text = text
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(dur)
	tw.tween_property(banner, "modulate:a", 0.0, 0.5)


func _on_speed() -> void:
	game_speed = 1.0 if game_speed >= 3.0 else game_speed + 1.0
	btn_speed.text = "%d×" % int(game_speed)


func _on_time() -> void:
	time_of_day = (time_of_day + 1) % 3
	_apply_time_of_day()


func _on_start_wave() -> void:
	if wave_active or game_over:
		return
	wave += 1
	wave_active = true
	spawn_left = 6 + wave * 3
	spawn_timer = 0.0
	_show_banner("Bizans Ordusu geliyor!")
	_update_hud()


# ---------------------------------------------------------------- dokunma

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var t := _tile_under(event.position)
		if _can_build(t):
			hover_tile.position = to_world(t.x, t.y, 0.01)
			hover_tile.visible = true
		else:
			hover_tile.visible = false
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if game_over and sur <= 0:
			get_tree().reload_current_scene()
			return
		var t := _tile_under(event.position)
		for tw in towers:
			if tw.tile == t:
				_show_range(tw)
				return
		range_ring.visible = false
		if _can_build(t):
			if akce >= ARCHER.cost:
				_place_tower(t)
			else:
				_show_banner("Yeterli akçe yok", 1.0)


func _tile_under(screen: Vector2) -> Vector2i:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if abs(dir.y) < 1e-4:
		return Vector2i(-99, -99)
	var t := -from.y / dir.y
	var p := from + dir * t
	return Vector2i(floori(p.x + COLS / 2.0), floori(p.z + ROWS / 2.0))


func _can_build(t: Vector2i) -> bool:
	if t.x < 0 or t.x >= COLS or t.y < 0 or t.y >= WALL_ROW:
		return false
	if path_tiles.has(t) or blocked.has(t):
		return false
	for tw in towers:
		if tw.tile == t:
			return false
	return true


func _show_range(tw: Dictionary) -> void:
	range_ring.visible = true
	range_ring.position = tw.node.position + Vector3(0, 0.03, 0)
	range_ring.scale = Vector3(ARCHER.range, 1, ARCHER.range)


# ---------------------------------------------------------------- kuleler

func _place_tower(t: Vector2i, free := false) -> void:
	if not free:
		akce -= ARCHER.cost
	var root := Node3D.new()
	root.position = to_world(t.x, t.y)
	add_child(root)
	var body := place("building_tower_A", Vector3.ZERO, 0.42, PI * 0.25, root)
	var f := _flag(flag_tex, 0.22, 0.15)
	_pole_local(root, Vector3(0, 0.88, 0), 0.32)
	f.position = Vector3(0.01, 1.1, 0)
	root.add_child(f)
	var tw := {"tile": t, "node": root, "cool": 0.0}
	towers.append(tw)
	root.scale = Vector3(1, 0.01, 1)
	var tween := create_tween()
	tween.tween_property(root, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_burst(root.position + Vector3(0, 0.05, 0), Color(0.85, 0.75, 0.55, 0.7), 22, 1.2, 0.22, 0.8, 0.3)
	hover_tile.visible = false
	_update_hud()


func _pole_local(parent: Node3D, base: Vector3, h: float) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.015
	cm.height = h
	var m := MeshInstance3D.new()
	m.mesh = cm
	m.material_override = mat(Color("#6e4424"))
	m.position = base + Vector3(0, h / 2.0, 0)
	parent.add_child(m)


func _update_towers(dt: float) -> void:
	for tw in towers:
		tw.cool -= dt
		if tw.cool > 0.0:
			continue
		var pos: Vector3 = tw.node.position
		var best = null
		var best_d := -1.0
		for e in enemies:
			if e.dead:
				continue
			var d := Vector2(e.node.position.x - pos.x, e.node.position.z - pos.z).length()
			if d <= ARCHER.range and e.dist > best_d:
				best = e
				best_d = e.dist
		if best != null:
			tw.cool = ARCHER.rate
			_fire_arrow(pos + Vector3(0, 0.92, 0), best)


func _fire_arrow(from: Vector3, target: Dictionary) -> void:
	var a := Node3D.new()
	var shaft := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.018, 0.018, 0.26)
	shaft.mesh = bm
	shaft.material_override = mat(Color("#7a4e2a"))
	a.add_child(shaft)
	var tip := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.03, 0.03, 0.05)
	tip.mesh = tm
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(2.4, 1.9, 1.1)
	tip.material_override = glow
	tip.position.z = -0.14
	a.add_child(tip)
	# ışıklı iz
	var trail := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	q.material = fire_mat
	trail.mesh = q
	trail.amount = 20
	trail.lifetime = 0.22
	trail.local_coords = false
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.05
	var g := Gradient.new()
	g.set_color(0, Color(2.0, 1.6, 0.9, 0.9))
	g.set_color(1, Color(1.0, 0.5, 0.2, 0.0))
	trail.color_ramp = g
	a.add_child(trail)
	a.position = from
	add_child(a)
	var dist := from.distance_to(target.node.position)
	arrows.append({"node": a, "from": from, "target": target, "t": 0.0, "dur": max(dist / ARCHER.speed, 0.12), "last": target.node.position})


func _update_arrows(dt: float) -> void:
	for i in range(arrows.size() - 1, -1, -1):
		var ar: Dictionary = arrows[i]
		var tgt: Dictionary = ar.target
		if not tgt.dead:
			ar.last = tgt.node.position + Vector3(0, 0.22, 0)
		ar.t += dt / ar.dur
		var t: float = min(ar.t, 1.0)
		var p: Vector3 = ar.from.lerp(ar.last, t) + Vector3(0, sin(t * PI) * 0.35, 0)
		var n: Node3D = ar.node
		if p.distance_squared_to(n.position) > 1e-6:
			n.look_at_from_position(n.position, p, Vector3.UP)
		n.position = p
		if ar.t >= 1.0:
			if not tgt.dead:
				_damage(tgt, ARCHER.damage)
			_burst(p, Color(2.0, 1.5, 0.8, 1.0), 8, 1.6, 0.05, 0.25, -4.0, true)
			n.queue_free()
			arrows.remove_at(i)


# ---------------------------------------------------------------- düşmanlar

func _spawn_enemy() -> void:
	var k: Node3D = knight_scene.instantiate()
	k.scale = Vector3.ONE * 0.3
	for m in k.find_children("*", "MeshInstance3D", true, false):
		var n := String(m.name)
		if n in ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Spike_Shield", "2H_Sword"]:
			m.visible = false
		elif n in ["Knight_Cape", "Round_Shield", "Knight_Body", "Knight_Helmet"]:
			if not enemy_mats.has(n):
				var sm: StandardMaterial3D = m.get_active_material(0).duplicate()
				sm.albedo_color = BYZ_TRIM.lightened(0.3) if n == "Knight_Helmet" else BYZANTIUM.lightened(0.35)
				enemy_mats[n] = sm
			m.material_override = enemy_mats[n]
	add_child(k)
	var ap: AnimationPlayer = k.find_children("*", "AnimationPlayer", true, false)[0]
	var anim := ap.get_animation("Walking_A")
	anim.loop_mode = Animation.LOOP_LINEAR
	ap.play("Walking_A")
	var hp: float = round(INFANTRY.hp * pow(1.2, wave - 1))
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.1, 0.05, 0.02, 0.8)
	bar_bg.size = Vector2(40, 7)
	var bar := ColorRect.new()
	bar.color = Color("#7fe05a")
	bar.size = Vector2(38, 5)
	bar.position = Vector2(1, 1)
	bar_bg.add_child(bar)
	bar_bg.visible = false
	bars_layer.add_child(bar_bg)
	var e := {"node": k, "anim": ap, "dist": -rng.randf_range(0.0, 0.3), "hp": hp, "max": hp,
		"speed": INFANTRY.speed * rng.randf_range(0.92, 1.08), "dead": false, "bar": bar_bg, "fill": bar,
		"lane": rng.randf_range(-0.12, 0.12), "flash": 0.0}
	k.position = path_point(0)
	enemies.append(e)


func _damage(e: Dictionary, amount: float) -> void:
	e.hp -= amount
	e.flash = 0.12
	if e.hp <= 0.0 and not e.dead:
		e.dead = true
		akce += INFANTRY.reward
		var p: Vector3 = e.node.position
		_burst(p + Vector3(0, 0.2, 0), Color(BYZANTIUM.r, BYZANTIUM.g, BYZANTIUM.b, 0.9), 18, 1.3, 0.16, 0.7, 0.4)
		_burst(p + Vector3(0, 0.1, 0), Color(0.9, 0.85, 0.75, 0.6), 14, 0.9, 0.25, 0.9, 0.2)
		_float_text(p + Vector3(0, 0.6, 0), "+%d" % INFANTRY.reward, Color("#ffd75a"))
		e.node.queue_free()
		e.bar.queue_free()
		_update_hud()


func _float_text(pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 64
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_modulate = Color(0.25, 0.1, 0.0)
	l.outline_size = 14
	l.no_depth_test = true
	l.position = pos
	add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 0.6, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _update_enemies(dt: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var e: Dictionary = enemies[i]
		if e.dead:
			enemies.remove_at(i)
			continue
		e.dist += e.speed * dt
		var p := path_point(e.dist)
		var ahead := path_point(e.dist + 0.15)
		var fwd := (ahead - p).normalized()
		var side := Vector3(-fwd.z, 0, fwd.x)
		var n: Node3D = e.node
		n.position = p + side * e.lane
		if fwd.length_squared() > 0.0:
			var yaw := atan2(fwd.x, fwd.z)
			n.rotation.y = lerp_angle(n.rotation.y, yaw, min(1.0, dt * 10.0))
		e.anim.speed_scale = e.speed * 1.4 * game_speed
		# vurulunca kısa beyaz parlama
		e.flash = max(0.0, e.flash - dt)
		var bar: ColorRect = e.bar
		if e.hp < e.max:
			var sp := camera.unproject_position(n.position + Vector3(0, 0.55, 0))
			bar.visible = not camera.is_position_behind(n.position)
			bar.position = sp - Vector2(20, 0)
			e.fill.size.x = 38.0 * clampf(e.hp / e.max, 0.0, 1.0)
		if e.dist >= path_total:
			sur = max(0, sur - INFANTRY.wall)
			_burst(n.position + Vector3(0, 0.3, 0), Color(0.7, 0.6, 0.5, 0.8), 20, 1.0, 0.2, 0.8, 0.2)
			n.queue_free()
			bar.queue_free()
			enemies.remove_at(i)
			_shake(0.12)
			_update_hud()
			if sur <= 0 and not game_over:
				game_over = true
				_show_banner("Kale düştü!\nYeniden denemek için dokun", 999)
				_update_hud()


var shake := 0.0
var cam_base := Transform3D()


func _shake(a: float) -> void:
	if shake <= 0.0:
		cam_base = camera.transform
	shake = max(shake, a)


# ---------------------------------------------------------------- ana döngü

func _process(delta: float) -> void:
	var dt := delta * game_speed
	if not game_over:
		if wave_active and spawn_left > 0:
			spawn_timer -= dt
			if spawn_timer <= 0.0:
				_spawn_enemy()
				spawn_left -= 1
				spawn_timer = rng.randf_range(0.7, 1.1)
		_update_enemies(dt)
		_update_towers(dt)
		if wave_active and spawn_left == 0 and enemies.is_empty():
			wave_active = false
			if wave >= MAX_WAVES:
				game_over = true
				_show_banner("Zafer!\nBizans seferi püskürtüldü", 999)
			else:
				var bonus := 20 + wave * 5
				akce += bonus
				_show_banner("Dalga püskürtüldü! +%d akçe" % bonus)
			_update_hud()
	_update_arrows(dt)

	var t := Time.get_ticks_msec() / 1000.0
	for tc in torches:
		var f: float = 0.85 + 0.15 * sin(t * 13.0 + tc.phase) + 0.08 * sin(t * 29.0 + tc.phase * 2.0)
		tc.light.light_energy = tc.base * f * torch_level
		tc.light.visible = torch_level > 0.01

	if shake > 0.0:
		shake = max(0.0, shake - delta)
		camera.transform = cam_base
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.4
		if shake <= 0.0:
			camera.transform = cam_base


# Geliştirme: `-- --shot=dosya.png [--night] [--wave]` ile birkaç saniye sonra ekran görüntüsü alıp çıkar.
func _debug_shot() -> void:
	var args := OS.get_cmdline_user_args()
	var out := ""
	for a in args:
		if a.begins_with("--shot="):
			out = a.substr(7)
	if out == "":
		return
	if "--dusk" in args:
		time_of_day = 1
		_apply_time_of_day(true)
	if "--night" in args:
		time_of_day = 2
		_apply_time_of_day(true)
	if "--wave" in args:
		_place_tower(Vector2i(5, 4))
		_place_tower(Vector2i(3, 9))
		_on_start_wave()
	await get_tree().create_timer(7.0 if "--wave" in args else 2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
