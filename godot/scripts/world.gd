class_name World
extends Node3D

# Durağan sahne: gökyüzü ve ışık, zemin, çim, surlar, ordugâh, şehir süsleri, ağaçlar.

const D := preload("res://scripts/data.gd")

var models: Models
var game: Game
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var torches: Array = []
var torch_level := 0.0
var time_of_day := 1
var camp: Node3D
var camp_flags: Array = []
var camp_nation := ""
var fire_mat: StandardMaterial3D
var rng := RandomNumberGenerator.new()
var blocked := {}

const LIGHTS := [
	{"sun_rot": Vector3(-58, -150, 0), "sun_col": Color(1.0, 0.95, 0.86), "sun_e": 2.4,
		"top": Color(0.32, 0.55, 0.88), "hor": Color(0.74, 0.84, 0.92), "gnd": Color(0.45, 0.5, 0.42),
		"amb": 0.75, "amb_col": Color(0.78, 0.8, 0.85), "fog": Color(0.74, 0.82, 0.88), "torch": 0.0, "exp": 1.1, "name": "Öğle"},
	{"sun_rot": Vector3(-30, -125, 0), "sun_col": Color(1.0, 0.76, 0.5), "sun_e": 2.5,
		"top": Color(0.28, 0.42, 0.72), "hor": Color(1.0, 0.72, 0.48), "gnd": Color(0.38, 0.32, 0.26),
		"amb": 0.62, "amb_col": Color(0.78, 0.66, 0.62), "fog": Color(0.95, 0.74, 0.55), "torch": 0.6, "exp": 1.1, "name": "İkindi"},
	{"sun_rot": Vector3(-50, -200, 0), "sun_col": Color(0.55, 0.65, 1.0), "sun_e": 0.45,
		"top": Color(0.02, 0.04, 0.12), "hor": Color(0.1, 0.14, 0.28), "gnd": Color(0.04, 0.05, 0.08),
		"amb": 0.42, "amb_col": Color(0.24, 0.3, 0.58), "fog": Color(0.08, 0.1, 0.2), "torch": 1.6, "exp": 1.3, "name": "Gece"},
]


func setup(m: Models, g: Game) -> void:
	models = m
	game = g
	rng.seed = D.MAP.seed
	fire_mat = StandardMaterial3D.new()
	fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_mat.vertex_color_use_as_albedo = true
	fire_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fire_mat.albedo_texture = soft_dot()
	_build_environment()
	_build_ground()
	_build_grass()
	_build_walls()
	_build_city_decor()
	_build_camp()
	_build_decor()
	apply_light(true)


func to_world(x: float, y: float, h := 0.0) -> Vector3:
	return Vector3(x - game.cols / 2.0, h, y - game.rows / 2.0)


static func soft_dot() -> ImageTexture:
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5 - s / 2.0, y + 0.5 - s / 2.0).length() / (s / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- ışık

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
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 34.0
	env.fog_depth_end = 80.0
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


func light_name() -> String:
	return LIGHTS[time_of_day].name


func cycle_light() -> void:
	time_of_day = (time_of_day + 1) % LIGHTS.size()
	apply_light()


func apply_light(instant := false) -> void:
	var p: Dictionary = LIGHTS[time_of_day]
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


func fire(parent: Node3D, pos: Vector3, size := 1.0, light := true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14) * size
	q.material = fire_mat
	p.mesh = q
	p.amount = 16
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
	return p


func _process(_dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for tc in torches:
		var f: float = 0.85 + 0.15 * sin(t * 13.0 + tc.phase) + 0.08 * sin(t * 29.0 + tc.phase * 2.0)
		tc.light.light_energy = tc.base * f * torch_level
		tc.light.visible = torch_level > 0.01
	if game.nation != camp_nation:
		camp_nation = game.nation
		for f in camp_flags:
			(f.material_override as ShaderMaterial).set_shader_parameter("tex", models.nation_flag(camp_nation))


# ---------------------------------------------------------------- zemin, çim

func _build_ground() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(70, 70)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ground.gdshader")
	var pts := PackedVector2Array()
	for p in _path_world():
		pts.append(Vector2(p.x, p.z))
	mat.set_shader_parameter("pts", pts)
	mat.set_shader_parameter("count", pts.size())
	mat.set_shader_parameter("wall_z", to_world(0, game.wall_row + 0.5).z)
	var g := MeshInstance3D.new()
	g.mesh = pm
	g.material_override = mat
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)


func _path_world() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in game.path_points.size():
		var p: Vector2 = game.path_points[i]
		if i == 0:
			p.y -= 1.2
		out.append(to_world(p.x, p.y))
	return out


func _dist_to_path(p: Vector3) -> float:
	var q := Vector2(p.x, p.z)
	var pw := _path_world()
	var best := 1e9
	for i in range(1, pw.size()):
		var a := Vector2(pw[i - 1].x, pw[i - 1].z)
		var b := Vector2(pw[i].x, pw[i].z)
		var ab := b - a
		var t := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = min(best, q.distance_to(a + ab * t))
	return best


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
	var wall_z := to_world(0, game.wall_row).z
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var tries := 0
	while xforms.size() < 3600 and tries < 30000:
		tries += 1
		var p := Vector3(r.randf_range(-8.5, 8.5), 0, r.randf_range(-11.5, wall_z - 0.1))
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


# ---------------------------------------------------------------- surlar

func _build_walls() -> void:
	var z := to_world(0, game.wall_row + 0.5).z
	var half := game.cols / 2.0
	var ws := 0.75
	var step := 2.0 * ws
	models.add_prop(self, "wall_straight_gate", Vector3(0, 0, z), ws)
	var x := step
	while x < half + step:
		for s in [-1, 1]:
			models.add_prop(self, "wall_straight", Vector3(s * x, 0, z), ws)
		x += step
	var zb := game.rows / 2.0 + 0.15
	x = -half + ws
	while x < half:
		models.add_prop(self, "wall_straight", Vector3(x, 0, zb), ws)
		x += step
	for s in [-1, 1]:
		var zz := z + ws
		while zz < zb:
			models.add_prop(self, "wall_straight", Vector3(s * (half + 0.1), 0, zz), ws, PI / 2)
			zz += step
		models.add_prop(self, "building_tower_base", Vector3(s * (half + 0.1), 0, zb), 0.62, PI)
	var flag := models.ottoman_flag()
	for t in [[-0.95, 0.72], [0.95, 0.72], [-half + 0.15, 0.62], [half - 0.15, 0.62]]:
		var tx: float = t[0]
		var sc: float = t[1]
		models.add_prop(self, "building_tower_base", Vector3(tx, 0, z), sc, PI)
		var top := 1.5 * sc
		models.cyl(self, 0.0, 0.47 * sc, 0.52, Vector3(tx, top + 0.26, z), models.mat(Models.LEAD, 0.55), 16)
		models.sphere(self, 0.045, Vector3(tx, top + 0.54, z), models.mat(Models.GOLD, 0.35, 0.8), false, 10)
		models.pole_flag(self, Vector3(tx, top + 0.5, z), 0.55, flag, 0.44)
	# kapının üstünde altın hilal
	var cr := TorusMesh.new()
	cr.inner_radius = 0.06
	cr.outer_radius = 0.085
	var m := MeshInstance3D.new()
	m.mesh = cr
	m.material_override = models.mat(Models.GOLD, 0.3, 0.8)
	m.position = Vector3(0, 0.98, z + 0.34)
	m.rotation = Vector3(PI / 2, 0, 0.8)
	add_child(m)
	for s in [-1, 1]:
		var pos := Vector3(s * 0.42, 0, z + 0.5)
		models.cyl(self, 0.015, 0.02, 0.7, pos + Vector3(0, 0.35, 0), models.mat(Models.WOOD_DARK), 6)
		fire(self, pos + Vector3(0, 0.74, 0), 1.0)
	fire(self, Vector3(-0.95, 1.5 * 0.72 + 0.05, z + 0.32), 0.8)
	fire(self, Vector3(0.95, 1.5 * 0.72 + 0.05, z + 0.32), 0.8)


# Şehrin boş karelerine evler ve fenerler (bina arsaları ve kapının önü boş kalır)
func _build_city_decor() -> void:
	var slots := {}
	for id in D.BUILDINGS:
		var s: Array = D.BUILDINGS[id].slot
		slots[Vector2i(s[0], s[1])] = true
	var homes := ["building_home_A", "building_home_B", "building_well", "building_market"]
	for r in range(game.wall_row + 1, game.rows):
		for c in game.cols:
			var k := Vector2i(c, r)
			if slots.has(k) or (c >= 3 and c <= 5 and r <= game.wall_row + 1) or (c == 4):
				continue
			# Kenarlarda seyrek evler; ortalar meydan olarak boş kalır ki binalar seçilebilsin
			var edge := c == 0 or c == game.cols - 1 or r == game.rows - 1
			if rng.randf() > (0.55 if edge else 0.18):
				continue
			var name: String = homes[rng.randi() % 2] if rng.randf() < 0.75 else homes[2 + rng.randi() % 2]
			var sc := 0.42 if name == "building_market" else (0.62 if name == "building_well" else rng.randf_range(0.62, 0.75))
			models.add_prop(self, name, to_world(c + 0.5, r + 0.5) + Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08)), sc, rng.randi() % 4 * PI / 2)
	for t in [Vector2(3.2, 13.2), Vector2(5.8, 13.2), Vector2(3.5, 15.6), Vector2(5.5, 15.6)]:
		var pos := to_world(t.x, t.y)
		models.cyl(self, 0.015, 0.02, 0.45, pos + Vector3(0, 0.22, 0), models.mat(Models.WOOD_DARK), 6)
		fire(self, pos + Vector3(0, 0.48, 0), 0.6)


# ---------------------------------------------------------------- ordugâh

func _build_camp() -> void:
	camp = Node3D.new()
	camp.position = to_world(game.path_points[0].x, -1.1)
	add_child(camp)
	for t in [[-1.1, -0.5, 0.4], [1.1, -0.3, -0.5], [-0.6, -1.4, 0.9], [0.9, -1.4, -0.2], [2.1, -0.9, 0.2]]:
		models.add_prop(camp, "tent", Vector3(t[0], 0, t[1]), 1.5, t[2])
	for t in [[-0.6, 0.5], [0.7, 0.4], [1.6, 0.1]]:
		models.add_prop(camp, ["barrel", "crate_A_big", "sack"][rng.randi() % 3], Vector3(t[0], 0, t[1]), 1.6, rng.randf() * TAU)
	models.add_prop(camp, "weaponrack", Vector3(-1.5, 0, 0.2), 1.6, 0.3)
	fire(camp, Vector3(0.1, 0.06, -0.5), 1.0)
	for s in [-1, 1]:
		var f := models.pole_flag(camp, Vector3(s * 0.55, 0, 0.55), 1.0, models.nation_flag(game.nation), 0.45)
		camp_flags.append(f)


func _build_decor() -> void:
	var half := game.cols / 2.0
	var wall_z := to_world(0, game.wall_row).z
	for side in [-1, 1]:
		var z := -11.0
		while z < wall_z + 4.0:
			var x: float = side * rng.randf_range(half + 0.7, half + 2.6)
			var kind: String = ["trees_A_medium", "trees_B_medium", "trees_A_small", "hills_A_trees", "tree_single_A", "tree_single_B"][rng.randi() % 6]
			models.add_prop(self, kind, Vector3(x, 0, z), rng.randf_range(0.55, 0.85), rng.randf() * TAU)
			z += rng.randf_range(0.9, 1.6)
		var z2 := -11.0
		while z2 < wall_z + 5.0:
			var x: float = side * rng.randf_range(half + 2.8, half + 5.0)
			models.add_prop(self, ["trees_A_medium", "trees_B_medium", "hills_B_trees"][rng.randi() % 3], Vector3(x, 0, z2), rng.randf_range(0.9, 1.3), rng.randf() * TAU)
			z2 += rng.randf_range(1.2, 2.0)
	for i in 9:
		var x := -9.0 + i * 2.3 + rng.randf_range(-0.5, 0.5)
		models.add_prop(self, ["trees_A_medium", "trees_B_medium"][i % 2], Vector3(x, 0, -11.5 - rng.randf_range(0, 2.5)), rng.randf_range(1.1, 1.5), rng.randf() * TAU)
	# tahtanın içinde, yola değmeyen birkaç küçük kaya (kule kurmayı engellemez)
	for r in range(0, game.wall_row):
		for c in game.cols:
			if game.is_path_tile(c, r) or rng.randf() > 0.12:
				continue
			var p := to_world(c + rng.randf_range(0.15, 0.85), r + rng.randf_range(0.15, 0.85))
			models.add_prop(self, ["rock_single_A", "rock_single_B", "rock_single_D"][rng.randi() % 3], p, rng.randf_range(0.35, 0.55), rng.randf() * TAU)
	var pw := _path_world()
	var total := 0.0
	for i in range(1, pw.size()):
		total += pw[i].distance_to(pw[i - 1])
	for i in 60:
		var d := rng.randf() * total
		var acc := 0.0
		var p := pw[-1]
		for j in range(1, pw.size()):
			var l := pw[j].distance_to(pw[j - 1])
			if d <= acc + l:
				p = pw[j - 1].lerp(pw[j], (d - acc) / l)
				break
			acc += l
		var off := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.36, 0.48)
		models.add_prop(self, "rock_single_A", p + off, rng.randf_range(0.25, 0.45), rng.randf() * TAU)
