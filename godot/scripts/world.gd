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
var path_key := ""  # kurulduğu yol (main, kuşatma değişince yeniden kurar)
var ground_mat: ShaderMaterial
var grass_mat: ShaderMaterial
var weather_key := ""  # gösterilen mevsim|hava
var weather_dim := 1.0  # yağmurda ve siste güneş kısılır
var fog_near := false
var rain: CPUParticles3D
var snowfall: CPUParticles3D

const LIGHTS := [
	{"sun_rot": Vector3(-58, -150, 0), "sun_col": Color(1.0, 0.95, 0.86), "sun_e": 2.4,
		"top": Color(0.32, 0.55, 0.88), "hor": Color(0.74, 0.84, 0.92), "gnd": Color(0.45, 0.5, 0.42),
		"amb": 0.75, "amb_col": Color(0.78, 0.8, 0.85), "fog": Color(0.74, 0.82, 0.88), "torch": 0.0, "exp": 1.1, "name": "Öğle"},
	{"sun_rot": Vector3(-28, -118, 0), "sun_col": Color(1.0, 0.7, 0.42), "sun_e": 2.9,
		"top": Color(0.3, 0.38, 0.62), "hor": Color(1.0, 0.68, 0.42), "gnd": Color(0.38, 0.3, 0.22),
		"amb": 0.6, "amb_col": Color(0.86, 0.68, 0.56), "fog": Color(0.95, 0.72, 0.5), "torch": 0.7, "exp": 1.12, "name": "İkindi"},
	{"sun_rot": Vector3(-50, -200, 0), "sun_col": Color(0.55, 0.65, 1.0), "sun_e": 0.45,
		"top": Color(0.02, 0.04, 0.12), "hor": Color(0.1, 0.14, 0.28), "gnd": Color(0.04, 0.05, 0.08),
		"amb": 0.42, "amb_col": Color(0.24, 0.3, 0.58), "fog": Color(0.08, 0.1, 0.2), "torch": 1.6, "exp": 1.3, "name": "Gece"},
]


func setup(m: Models, g: Game) -> void:
	models = m
	game = g
	rng.seed = D.MAP.seed
	path_key = game.map_key()
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
	_build_work_sites()
	_build_camp()
	_build_decor()
	_build_weather()
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
	tw.tween_property(sun, "light_energy", p.sun_e * weather_dim, dur)
	tw.tween_property(sky_mat, "sky_top_color", p.top, dur)
	tw.tween_property(sky_mat, "sky_horizon_color", p.hor, dur)
	tw.tween_property(sky_mat, "ground_horizon_color", p.hor, dur)
	tw.tween_property(sky_mat, "ground_bottom_color", p.gnd, dur)
	tw.tween_property(env, "ambient_light_energy", p.amb, dur)
	tw.tween_property(env, "ambient_light_color", p.amb_col, dur)
	tw.tween_property(env, "fog_light_color", p.fog, dur)
	tw.tween_property(env, "tonemap_exposure", p.exp, dur)
	tw.tween_property(env, "fog_depth_begin", 20.0 if fog_near else 34.0, dur)
	tw.tween_property(env, "fog_depth_end", 58.0 if fog_near else 80.0, dur)
	tw.tween_method(func(v): torch_level = v, torch_level, p.torch, dur)


# ---------------------------------------------------------------- hava ve mevsim

func _build_weather() -> void:
	# tween başlangıç değeri okuyabilsin diye gölgelendirici değerleri baştan yazılır
	for m in [ground_mat, grass_mat]:
		m.set_shader_parameter("snow", 0.0)
	ground_mat.set_shader_parameter("season_tint", Vector3.ONE)
	grass_mat.set_shader_parameter("tint", Vector3.ONE)
	rain = CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.45)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(0.82, 0.88, 1.0, 0.7)
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = rm
	rain.mesh = q
	rain.amount = 900
	rain.lifetime = 0.7
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(7.0, 0.1, 10.5)
	rain.direction = Vector3(0.1, -1, 0)
	rain.spread = 3
	rain.gravity = Vector3(0, -6, 0)
	rain.initial_velocity_min = 9.0
	rain.initial_velocity_max = 11.0
	rain.position = Vector3(0, 7.5, 0)
	rain.emitting = false
	rain.visibility_aabb = AABB(Vector3(-9, -9, -12), Vector3(18, 10, 24))
	add_child(rain)
	snowfall = CPUParticles3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(0.1, 0.1)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_texture = soft_dot()
	smat.albedo_color = Color(1, 1, 1, 0.9)
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sq.material = smat
	snowfall.mesh = sq
	snowfall.amount = 700
	snowfall.lifetime = 5.0
	snowfall.preprocess = 5.0
	snowfall.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snowfall.emission_box_extents = Vector3(7.0, 0.1, 10.5)
	snowfall.direction = Vector3(0, -1, 0)
	snowfall.spread = 25
	snowfall.gravity = Vector3(0.25, -0.35, 0)
	snowfall.initial_velocity_min = 0.8
	snowfall.initial_velocity_max = 1.3
	snowfall.scale_amount_min = 0.5
	snowfall.scale_amount_max = 1.4
	snowfall.position = Vector3(0, 6.0, 0)
	snowfall.emitting = false
	snowfall.visibility_aabb = AABB(Vector3(-9, -9, -12), Vector3(18, 10, 24))
	add_child(snowfall)


# Mevsim zemini ve çimi boyar, havaya göre yağmur, kar ve sis açar
func set_weather(season: String, weather: String, instant := false) -> void:
	weather_key = season + "|" + weather
	var s: Dictionary = D.SEASONS[season]
	var dur := 0.01 if instant else 2.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ground_mat, "shader_parameter/season_tint", Vector3(s.tint.r, s.tint.g, s.tint.b), dur)
	tw.tween_property(ground_mat, "shader_parameter/snow", s.snow if weather == "snow" or season == "winter" else 0.0, dur)
	tw.tween_property(grass_mat, "shader_parameter/tint", Vector3(s.tint.r, s.tint.g, s.tint.b), dur)
	tw.tween_property(grass_mat, "shader_parameter/snow", s.snow if weather == "snow" or season == "winter" else 0.0, dur)
	grass_mat.set_shader_parameter("wind", 2.2 if weather == "rain" else 1.0)
	rain.emitting = weather == "rain"
	snowfall.emitting = weather == "snow"
	weather_dim = {"rain": 0.55, "fog": 0.7, "snow": 0.8}.get(weather, 1.0)
	fog_near = weather == "fog"
	apply_light(instant)


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
	ground_mat = mat
	var ground: Dictionary = game.stage.get("ground", {})
	for k in ground:
		mat.set_shader_parameter(k, ground[k])
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
	grass_mat = sm
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------------------------------------------------------------- surlar

func _build_walls() -> void:
	var z := to_world(0, game.wall_row + 0.5).z
	var half := game.cols / 2.0
	var zb := game.rows / 2.0 + 0.15
	var flag := models.ottoman_flag()
	var st := models.stone_mat()
	var h := 0.62
	var t := 0.34
	# ön sur kapının iki yanında, arka ve yan surlar
	for s in [-1, 1]:
		_wall_run(Vector3(s * 0.62, 0, z), Vector3(s * (half - 0.1), 0, z), h, t, st)
		_wall_run(Vector3(s * (half + 0.1), 0, z + 0.1), Vector3(s * (half + 0.1), 0, zb - 0.1), h * 0.9, t, st)
	_wall_run(Vector3(-half, 0, zb), Vector3(half, 0, zb), h * 0.9, t, st)
	# kapı (Blender modeli): kemer taşlı geçit, açık ahşap kanatlar, altın kitabe
	var gate := models.ott_model("gate")
	gate.position = Vector3(0, 0, z)
	add_child(gate)
	# kapı burçları ve köşe burçları: kubbeli, sancaklı
	for s in [-1, 1]:
		models.round_tower(self, Vector3(s * 0.95, 0, z), 0.3, 1.05, true, flag)
		models.round_tower(self, Vector3(s * (half + 0.05), 0, z), 0.34, 0.95, true, flag)
		models.round_tower(self, Vector3(s * (half + 0.05), 0, zb), 0.3, 0.85, true, null)
		models.round_tower(self, Vector3(s * 2.2, 0, z), 0.24, 0.82, false, null)
		# asılı sancaklar: kapı ayaklarında ve burçlarda
		for f in [-1, 1]:
			models.hang_banner(self, Vector3(s * 0.45, 0.62, z + f * 0.26), 0.5)
			models.hang_banner(self, Vector3(s * 0.95, 0.68, z + f * 0.335), 0.46)
			models.hang_banner(self, Vector3(s * (half + 0.05), 0.6, z + f * 0.375), 0.42)
			models.hang_banner(self, Vector3(s * 3.2, 0.42, z + f * 0.18), 0.34)
	for s in [-1, 1]:
		var pos := Vector3(s * 0.42, 0, z - 0.5)
		models.cyl(self, 0.015, 0.02, 0.7, pos + Vector3(0, 0.35, 0), models.mat(Models.WOOD_DARK), 6)
		fire(self, pos + Vector3(0, 0.74, 0), 1.0)
	fire(self, Vector3(-0.95, 1.12, z - 0.3), 0.8)
	fire(self, Vector3(0.95, 1.12, z - 0.3), 0.8)


# a'dan b'ye düz sur: Blender'daki 1 karelik sur parçası (kesme taş, mazgal dişleri dışa bakar) dizilir.
# Parçanın dış yüzü -z'dir; dış yön şehrin merkezinden uzağa doğru seçilir.
func _wall_run(a: Vector3, b: Vector3, h: float, t: float, _st: Material) -> void:
	var d := b - a
	var len := d.length()
	var along_x := absf(d.x) > absf(d.z)
	var n := maxi(1, int(round(len)))
	var city_z := (to_world(0, game.wall_row).z + game.rows / 2.0) / 2.0
	var rot := 0.0
	if along_x:
		rot = 0.0 if a.z < city_z else PI
	else:
		rot = -PI / 2 if a.x > 0 else PI / 2
	for i in n:
		var seg := models.ott_model("wall_segment")
		seg.position = a + d * ((i + 0.5) / n)
		seg.rotation.y = rot
		seg.scale = Vector3(len / n, h / 0.62, t / 0.34)
		add_child(seg)


# Şehrin boş kareleri: şadırvan, çarşı, bahçeler, servi ağaçları ve cumbalı Osmanlı evleri.
# Bina arsaları ve kapıdan Saray'a giden yol boş kalır; halk kare kenarlarındaki sokaklarda yürür.
const CITY_DECOR := {
	Vector2i(6, 13): "fountain",
	Vector2i(2, 13): "bazaar", Vector2i(3, 13): "bazaar",
	Vector2i(2, 14): "garden", Vector2i(3, 14): "garden", Vector2i(5, 14): "pool", Vector2i(7, 14): "cypress",
	Vector2i(4, 15): "palace_garden",
	Vector2i(0, 13): "house", Vector2i(8, 13): "house", Vector2i(0, 15): "house", Vector2i(8, 15): "house",
	Vector2i(3, 15): "house", Vector2i(5, 15): "house",
}
const AWNINGS := [["#b3202a", "#f2ece0"], ["#2f6fb0", "#f2ece0"], ["#3d7a3a", "#e8d48a"], ["#c47a1e", "#f2ece0"]]


func _build_city_decor() -> void:
	var slots := {}
	for id in D.BUILDINGS:
		var s: Array = D.BUILDINGS[id].slot
		slots[Vector2i(s[0], s[1])] = true
	for k in CITY_DECOR:
		if slots.has(k):
			continue
		var g := Node3D.new()
		g.position = to_world(k.x + 0.5, k.y + 0.5)
		add_child(g)
		match CITY_DECOR[k]:
			"fountain":
				_fountain(g)
			"bazaar":
				_stall(g, Vector3(-0.17, 0, 0), k.x * 2)
				_stall(g, Vector3(0.17, 0, 0.05), k.x * 2 + 1)
			"garden":
				_garden(g, false)
			"pool":
				_garden(g, true)
			"cypress":
				for c in [Vector3(-0.22, 0, -0.2), Vector3(0.22, 0, -0.2), Vector3(-0.22, 0, 0.22), Vector3(0.22, 0, 0.22)]:
					_cypress(g, c, rng.randf_range(0.55, 0.7))
				_lantern(g, Vector3(0, 0, 0), true)
			"palace_garden":
				for x in [-0.3, -0.1, 0.1, 0.3]:
					_cypress(g, Vector3(x, 0, 0.25), 0.6)
			"house":
				_house(g, rng.randi() % 4 * PI / 2)
	# güney surunun ardında tarlalar, bağlar ve bir yel değirmeni
	var zb: float = to_world(0, game.rows).z
	var wheat := models.mat(Color("#d8b44a"))
	var green := models.mat(Color("#6f9a3e"))
	for i in 5:
		var fx := -3.6 + i * 1.8
		var f := models.box(self, Vector3(1.5, 0.04, 0.9), Vector3(fx, 0.02, zb + 1.0), wheat if i % 2 == 0 else green)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for k in 5:
			var row := models.box(self, Vector3(1.4, 0.05, 0.05), Vector3(fx, 0.045, zb + 0.66 + k * 0.17), models.mat(Color("#b8962e") if i % 2 == 0 else Color("#567d2e")))
			row.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	models.add_prop(self, "building_windmill", Vector3(2.6, 0, zb + 2.0), 0.55, PI)
	for i in 8:
		models.add_prop(self, ["tree_single_A", "tree_single_B"][i % 2], Vector3(-4.2 + i * 1.2 + rng.randf_range(-0.2, 0.2), 0, zb + 1.75 + rng.randf_range(0, 0.4)), rng.randf_range(0.5, 0.7), rng.randf() * TAU)
	# sokak fenerleri (ışıklı olan az; web'de ucuz kalsın)
	var lit := 0
	for t in [Vector2(3.0, 14.0), Vector2(6.0, 14.0), Vector2(2.0, 15.0), Vector2(7.0, 15.0), Vector2(1.0, 14.0), Vector2(8.0, 14.0)]:
		var lg := Node3D.new()
		lg.position = to_world(t.x, t.y)
		add_child(lg)
		_lantern(lg, Vector3.ZERO, lit < 3)
		lit += 1


# Odun-Demir Ocağı işçilerinin gittiği yerler: surların önünde solda kesim alanı, sağda demir madeni
func _build_work_sites() -> void:
	var a: Array = D.MAP.lumber_site
	var g := Node3D.new()
	g.position = to_world(a[0] + 0.5, a[1] + 0.5)
	add_child(g)
	for t in [[-0.3, -0.28, "tree_single_A"], [0.05, -0.36, "tree_single_B"], [-0.36, 0.08, "tree_single_B"], [0.3, -0.2, "tree_single_A"]]:
		models.add_prop(g, t[2], Vector3(t[0], 0, t[1]), rng.randf_range(0.6, 0.75), rng.randf() * TAU)
	for st in [Vector3(0.1, 0, 0.05), Vector3(-0.12, 0, 0.3)]:
		models.cyl(g, 0.05, 0.06, 0.07, st + Vector3(0, 0.035, 0), models.mat(Models.WOOD), 8)
		models.cyl(g, 0.045, 0.045, 0.005, st + Vector3(0, 0.072, 0), models.mat(Color("#d8b98a")), 8)
	models.add_prop(g, "resource_lumber", Vector3(0.3, 0, 0.3), 0.45, 0.4)
	var b: Array = D.MAP.mine_site
	var m := Node3D.new()
	m.position = to_world(b[0] + 0.5, b[1] + 0.5)
	add_child(m)
	models.add_prop(m, "rock_single_C", Vector3(0.18, 0, -0.2), 1.6, 0.5)
	models.add_prop(m, "rock_single_E", Vector3(-0.22, 0, -0.18), 1.4, 1.9)
	models.add_prop(m, "rock_single_D", Vector3(0.36, 0, 0.05), 0.9, 0.7)
	# maden ağzı: ahşap destekli karanlık giriş
	models.box(m, Vector3(0.24, 0.26, 0.04), Vector3(0.0, 0.13, 0.02), models.mat(Color("#15110e")))
	for x in [-0.13, 0.13]:
		models.box(m, Vector3(0.035, 0.3, 0.035), Vector3(x, 0.15, 0.05), models.mat(Models.WOOD_DARK))
	models.box(m, Vector3(0.32, 0.035, 0.045), Vector3(0.0, 0.31, 0.05), models.mat(Models.WOOD_DARK))
	var ore := models.mat(Color("#5a4e48"), 0.55, 0.6)
	var rust := models.mat(Color("#9a5a3a"), 0.7, 0.3)
	for k in 7:
		var op := Vector3(rng.randf_range(-0.35, 0.35), 0.03, rng.randf_range(0.1, 0.38))
		models.sphere(m, rng.randf_range(0.04, 0.065), op, ore if k % 3 else rust, false, 6)
	models.add_prop(m, "wheelbarrow", Vector3(-0.28, 0, 0.25), 0.3, 2.2)


func _fountain(g: Node3D) -> void:
	var stone := models.mat(Models.STONE)
	var marble := models.mat(Models.WHITEWASH, 0.4)
	models.cyl(g, 0.34, 0.36, 0.05, Vector3(0, 0.025, 0), models.mat(Models.STONE_DARK), 8)
	models.cyl(g, 0.27, 0.27, 0.12, Vector3(0, 0.08, 0), marble, 8)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.25, 0.55, 0.75, 0.85)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.05
	water.metallic = 0.3
	models.cyl(g, 0.24, 0.24, 0.02, Vector3(0, 0.14, 0), water, 8)
	# sekiz sütunlu, kurşun kubbeli çatı
	for i in 8:
		var a := i * TAU / 8.0 + PI / 8.0
		models.cyl(g, 0.018, 0.018, 0.42, Vector3(cos(a) * 0.3, 0.26, sin(a) * 0.3), stone, 6)
	models.cyl(g, 0.38, 0.38, 0.04, Vector3(0, 0.49, 0), models.mat(Models.IZNIK, 0.4), 8)
	models.cyl(g, 0.02, 0.4, 0.2, Vector3(0, 0.6, 0), models.mat(Models.LEAD, 0.5, 0.3), 8)
	models.sphere(g, 0.03, Vector3(0, 0.72, 0), models.mat(Models.GOLD, 0.3, 0.8), false, 8)
	models.cyl(g, 0.04, 0.05, 0.14, Vector3(0, 0.2, 0), marble, 8)
	# fıskiye
	var p := CPUParticles3D.new()
	var q := SphereMesh.new()
	q.radius = 0.012
	q.height = 0.024
	q.material = water
	p.mesh = q
	p.amount = 40
	p.lifetime = 0.7
	p.direction = Vector3.UP
	p.spread = 25
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.7
	p.gravity = Vector3(0, -2.4, 0)
	p.position = Vector3(0, 0.27, 0)
	g.add_child(p)


func _stall(g: Node3D, pos: Vector3, i: int) -> void:
	var col: Array = AWNINGS[i % AWNINGS.size()]
	var wood := models.mat(Models.WOOD)
	for c in [Vector3(-0.11, 0, -0.1), Vector3(0.11, 0, -0.1), Vector3(-0.11, 0, 0.1), Vector3(0.11, 0, 0.1)]:
		models.cyl(g, 0.01, 0.01, 0.3, pos + c + Vector3(0, 0.15, 0), wood, 5)
	models.box(g, Vector3(0.24, 0.07, 0.12), pos + Vector3(0, 0.1, 0.06), models.mat(Models.WOOD_DARK))
	# çizgili tente
	for k in 4:
		var stripe := models.box(g, Vector3(0.065, 0.015, 0.3), pos + Vector3(-0.0975 + k * 0.065, 0.32, 0.01),
			models.mat(Color(col[k % 2])))
		stripe.rotation.x = 0.22
	var goods := [Color("#d9a441"), Color("#b3202a"), Color("#6a8f3a"), Color("#e8dcc0")]
	for k in 3:
		models.sphere(g, 0.03, pos + Vector3(-0.07 + k * 0.07, 0.15, 0.08), models.mat(goods[(i + k) % goods.size()]), false, 8)
	models.add_prop(g, ["sack", "barrel", "crate_B_small"][i % 3], pos + Vector3(0.0, 0, -0.17), 0.35)


func _garden(g: Node3D, pool: bool) -> void:
	var grass := models.box(g, Vector3(0.74, 0.03, 0.74), Vector3(0, 0.015, 0), models.mat(Color("#4f7d36")))
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# taş kenar
	for s in [-1, 1]:
		models.box(g, Vector3(0.78, 0.05, 0.03), Vector3(0, 0.025, s * 0.38), models.mat(Models.STONE))
		models.box(g, Vector3(0.03, 0.05, 0.78), Vector3(s * 0.38, 0.025, 0), models.mat(Models.STONE))
	if pool:
		var water := StandardMaterial3D.new()
		water.albedo_color = Color(0.22, 0.5, 0.7)
		water.roughness = 0.05
		water.metallic = 0.4
		models.box(g, Vector3(0.44, 0.04, 0.3), Vector3(0, 0.03, 0), models.mat(Models.WHITEWASH, 0.4))
		models.box(g, Vector3(0.38, 0.042, 0.24), Vector3(0, 0.032, 0), water)
		for x in [-0.3, 0.3]:
			_cypress(g, Vector3(x, 0, -0.25), 0.6)
			_cypress(g, Vector3(x, 0, 0.25), 0.55)
	else:
		_cypress(g, Vector3(-0.24, 0, -0.24), 0.65)
		_cypress(g, Vector3(0.24, 0, 0.24), 0.6)
		var flowers := [Color("#d6455a"), Color("#f2c94c"), Color("#e8e0f0"), Color("#c25ab8")]
		for k in 14:
			var fp := Vector3(rng.randf_range(-0.3, 0.3), 0.045, rng.randf_range(-0.3, 0.3))
			models.sphere(g, 0.022, fp, models.mat(flowers[k % flowers.size()]), false, 6)
		# bank
		models.box(g, Vector3(0.24, 0.03, 0.07), Vector3(0.05, 0.08, -0.05), models.mat(Models.WOOD))
		for x in [-0.05, 0.15]:
			models.box(g, Vector3(0.03, 0.06, 0.06), Vector3(x, 0.045, -0.05), models.mat(Models.WOOD_DARK))


func _cypress(g: Node3D, pos: Vector3, h: float) -> void:
	models.cyl(g, 0.015, 0.02, 0.08, pos + Vector3(0, 0.04, 0), models.mat(Models.WOOD_DARK), 5)
	var c := models.sphere(g, 0.07, pos + Vector3(0, 0.08 + h * 0.45, 0), models.mat(Color("#2d5a2e")), false, 10)
	c.scale = Vector3(1, h / 0.14 * 0.95, 1)


func _lantern(g: Node3D, pos: Vector3, light: bool) -> void:
	models.cyl(g, 0.012, 0.016, 0.42, pos + Vector3(0, 0.21, 0), models.mat(Models.IRON, 0.5, 0.5), 6)
	models.cyl(g, 0.03, 0.025, 0.06, pos + Vector3(0, 0.45, 0), models.glow_mat(Color(1.0, 0.7, 0.35)), 6)
	models.cyl(g, 0.0, 0.04, 0.04, pos + Vector3(0, 0.5, 0), models.mat(Models.IRON, 0.5, 0.5), 6)
	if light:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.4)
		l.light_energy = 0.0
		l.omni_range = 1.3
		l.omni_attenuation = 1.4
		l.position = pos + Vector3(0, 0.46, 0)
		g.add_child(l)
		torches.append({"light": l, "phase": rng.randf() * 10.0, "base": 0.9})


# Cumbalı Osmanlı evi: badanalı alt kat, ahşap çıkmalı üst kat, kiremit çatı
func _house(g: Node3D, rot: float) -> void:
	var h := Node3D.new()
	h.rotation.y = rot
	g.add_child(h)
	var wall := models.mat(Models.WHITEWASH)
	var timber := models.mat(Color("#8a5a34"))
	models.box(h, Vector3(0.5, 0.22, 0.42), Vector3(0, 0.11, 0), wall)
	models.box(h, Vector3(0.58, 0.2, 0.5), Vector3(0, 0.32, 0.03), models.mat(Color("#efe2c8")))
	# ahşap kuşaklar ve pencereler
	models.box(h, Vector3(0.6, 0.025, 0.52), Vector3(0, 0.225, 0.03), timber)
	models.box(h, Vector3(0.6, 0.025, 0.52), Vector3(0, 0.42, 0.03), timber)
	for x in [-0.17, 0.0, 0.17]:
		models.box(h, Vector3(0.07, 0.09, 0.01), Vector3(x, 0.33, 0.285), models.mat(Color("#3a2a1e")))
	models.box(h, Vector3(0.1, 0.15, 0.01), Vector3(0, 0.075, 0.215), timber)
	# kırma çatı
	var roof := models.cyl(h, 0.0, 0.46, 0.2, Vector3(0, 0.53, 0.03), models.mat(Color("#b4472e")), 4)
	roof.rotation.y = PI / 4
	roof.scale = Vector3(1.0, 1.0, 0.85)
	models.box(h, Vector3(0.05, 0.12, 0.05), Vector3(0.16, 0.6, -0.08), models.mat(Models.STONE_DARK))


# ---------------------------------------------------------------- ordugâh

func _build_camp() -> void:
	camp = Node3D.new()
	camp.position = to_world(game.path_points[0].x, -1.1)
	add_child(camp)
	for t in [[-1.1, -0.5, 0.4], [1.1, -0.3, -0.5], [-0.6, -1.4, 0.9], [0.9, -1.4, -0.2], [2.1, -0.9, 0.2]]:
		var tent := models.ott_model("camp_tent" if rng.randf() < 0.6 else "camp_tent_b")
		tent.position = Vector3(t[0], 0, t[1])
		tent.rotation.y = t[2]
		tent.scale = Vector3.ONE * 1.6
		camp.add_child(tent)
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
	# kare köşelerinde çalılar ve çiçekler (kule kurulan kare ortalarına değmez)
	var leaf := [models.mat(Color("#3f6a2a")), models.mat(Color("#4f7d30")), models.mat(Color("#5f8a34"))]
	var petals := [models.mat(Color("#c8323a")), models.mat(Color("#f2c94c")), models.mat(Color("#f4efe4"))]
	for r in range(1, game.wall_row):
		for c in range(1, game.cols):
			var near_path := false
			for k in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
				if game.is_path_tile(c + k.x, r + k.y):
					near_path = true
			if rng.randf() > (0.25 if near_path else 0.5):
				continue
			var p := to_world(c + rng.randf_range(-0.06, 0.06), r + rng.randf_range(-0.06, 0.06))
			var kind := rng.randf()
			if kind < 0.6:
				for b in rng.randi_range(2, 3):
					var off := Vector3(rng.randf_range(-0.09, 0.09), 0, rng.randf_range(-0.09, 0.09))
					var rr := rng.randf_range(0.06, 0.11)
					var sp := models.sphere(self, rr, p + off + Vector3(0, rr * 0.7, 0), leaf[rng.randi() % 3], false, 8)
					sp.scale.y = 0.8
			elif kind < 0.85:
				var pm: Material = petals[rng.randi() % 3]
				for f in 6:
					var off := Vector3(rng.randf_range(-0.12, 0.12), 0.03, rng.randf_range(-0.12, 0.12))
					models.sphere(self, 0.022, p + off, pm if f % 3 else leaf[1], false, 6)
			else:
				models.add_prop(self, ["rock_single_B", "rock_single_C"][rng.randi() % 2], p, rng.randf_range(0.35, 0.5), rng.randf() * TAU)
	_build_river()
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


# Sağ üstte, ordugâhın yanından akan dere: kayalar, köpüklü çağlayan ve ahşap köprü
func _build_river() -> void:
	var half := game.cols / 2.0
	var top := -game.rows / 2.0
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.22, 0.48, 0.62)
	water.roughness = 0.08
	water.metallic = 0.25
	var pts := [Vector3(half + 1.6, 0, top - 3.0), Vector3(half - 0.2, 0, top - 2.2), Vector3(half - 1.2, 0, top - 1.2),
		Vector3(half + 0.4, 0, top - 0.4), Vector3(half + 1.8, 0, top + 0.2)]
	for k in range(1, pts.size()):
		var a: Vector3 = pts[k - 1]
		var b: Vector3 = pts[k]
		var d := b - a
		var seg := models.box(self, Vector3(0.62, 0.03, d.length() + 0.3), (a + b) / 2.0 + Vector3(0, 0.015, 0), water)
		seg.rotation.y = atan2(d.x, d.z)
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for side in [-1, 1]:
			for q in 3:
				var t: float = (q + 0.5) / 3.0
				var n: Vector3 = Vector3(d.z, 0, -d.x).normalized() * side * rng.randf_range(0.36, 0.46)
				models.add_prop(self, ["rock_single_A", "rock_single_D", "rock_single_E"][rng.randi() % 3], a.lerp(b, t) + n, rng.randf_range(0.35, 0.6), rng.randf() * TAU)
	# çağlayan köpüğü
	var foam := CPUParticles3D.new()
	var fq := SphereMesh.new()
	fq.radius = 0.03
	fq.height = 0.06
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.92, 0.96, 1.0, 0.8)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fq.material = fm
	foam.mesh = fq
	foam.amount = 30
	foam.lifetime = 0.8
	foam.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	foam.emission_box_extents = Vector3(0.25, 0.02, 0.1)
	foam.direction = Vector3(0, 1, 0)
	foam.spread = 40
	foam.initial_velocity_min = 0.2
	foam.initial_velocity_max = 0.5
	foam.gravity = Vector3(0, -1.2, 0)
	foam.position = pts[1] + Vector3(0, 0.05, 0)
	add_child(foam)
	# ahşap köprü
	var mid: Vector3 = (pts[2] + pts[3]) / 2.0
	var dir: Vector3 = (pts[3] - pts[2]).normalized()
	var br := Node3D.new()
	br.position = mid + Vector3(0, 0.06, 0)
	br.rotation.y = atan2(dir.x, dir.z) + PI / 2
	add_child(br)
	for k in 7:
		models.box(br, Vector3(0.1, 0.03, 0.34), Vector3(-0.42 + k * 0.14, 0.02, 0), models.mat(Models.WOOD))
	for side in [-1, 1]:
		models.box(br, Vector3(0.98, 0.03, 0.03), Vector3(0, 0.14, side * 0.17), models.mat(Models.WOOD_DARK))
		for k in 3:
			models.box(br, Vector3(0.03, 0.14, 0.03), Vector3(-0.42 + k * 0.42, 0.07, side * 0.17), models.mat(Models.WOOD_DARK))
