class_name Models
extends RefCounted

# 3D modeller: kuleler, surlar, binalar, askerler ve atlar Blender betikleriyle yapılmıştır
# (tools/blender, assets/models/ottoman). Küçük süsler KayKit (CC0), kuşatma araçları koddaki basit şekillerden.
# Ölçü birimi 1 kare.

const D := preload("res://scripts/data.gd")

const GOLD := Color("#e0b24a")
const LEAD := Color("#7d8a99")
const WOOD := Color("#9a6436")
const WOOD_DARK := Color("#6e4424")
const STONE := Color("#d9cbb0")
const STONE_DARK := Color("#a99877")
const WHITEWASH := Color("#f2ece0")
const IZNIK := Color("#2f6fb0")
const OTTOMAN_RED := Color("#b3202a")
const BRONZE := Color("#b0813a")
const IRON := Color("#3a3c42")

var lib := {}
var mats := {}
var tex_cache := {}
var flag_shader: Shader
# Blender askerlerinin genel boy çarpanı (oyunda okunaklı olsun diye)
const CHAR_SIZE := 1.3
# Blender'da kodla yapılmış Osmanlı modelleri (tools/blender): ad -> PackedScene
var ott := {}


func _init() -> void:
	var medieval: Node3D = load("res://assets/models/medieval.glb").instantiate()
	for c in medieval.get_children():
		var n := String(c.name)
		if n.ends_with("2") and not n.ends_with("_2"):
			n = n.substr(0, n.length() - 1)
		lib[n] = c
	flag_shader = load("res://shaders/flag.gdshader")
	for f in DirAccess.get_files_at("res://assets/models/ottoman"):
		var fn := f.trim_suffix(".remap").trim_suffix(".import")
		if fn.ends_with(".glb") and not ott.has(fn.get_basename()):
			var ps: PackedScene = load("res://assets/models/ottoman/" + fn)
			_paint_mats(ps)
			ott[fn.get_basename()] = ps


# glTF içe aktarımı köşe rengini kullanmaz; renkler köşe renginde olduğu için paylaşılan malzemelerle değiştirilir
func _paint_mats(ps: PackedScene) -> void:
	var n := ps.instantiate()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for i in mesh.get_surface_count():
			var old := mesh.surface_get_material(i)
			var key := "paint|" + (old.resource_name if old else "Painted")
			if not mats.has(key):
				var m := StandardMaterial3D.new()
				m.vertex_color_use_as_albedo = true
				match key:
					"paint|Metal":
						# uyumluluk çiziminde yansıma ortamı zayıf; tam metal kararır
						m.metallic = 0.25
						m.roughness = 0.35
						m.metallic_specular = 0.8
					"paint|Glaze":
						m.roughness = 0.4
					_:
						m.roughness = 0.92
						m.metallic_specular = 0.3
				mats[key] = m
			mesh.surface_set_material(i, mats[key])
	n.free()


func ott_model(name: String) -> Node3D:
	return ott[name].instantiate()


# Modeldeki işaret noktası (Blender'daki boş nesne); yoksa sıfır
func mark(model: Node3D, name: String) -> Vector3:
	var n: Node3D = model.find_child(name, true, false)
	if n == null:
		return Vector3.ZERO
	return model.to_local(n.global_position) if model.is_inside_tree() else _local_pos(model, n)


func _local_pos(root: Node3D, n: Node3D) -> Vector3:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != root:
		t = (c as Node3D).transform * t
		c = c.get_parent()
	return t.origin


# ---------------------------------------------------------------- yardımcılar

func mat(color: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(), rough, metal]
	if not mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		mats[key] = m
	return mats[key]


# Yontma taş (shaders/stone.gdshader); renge göre önbellekte tutulur
func stone_mat(color := Color("#cdbb98"), brick := Vector2(0.16, 0.075)) -> ShaderMaterial:
	var key := "stone|%s|%s" % [color.to_html(), brick]
	if not mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/stone.gdshader")
		m.set_shader_parameter("base", color)
		m.set_shader_parameter("mortar", color.darkened(0.38))
		m.set_shader_parameter("brick", brick)
		mats[key] = m
	return mats[key]


# Yuvarlak taş burç (Blender modeli): kesme taş gövde, mazgallı taç, isteğe bağlı kaburgalı kurşun kubbe ve sancak.
# Dönüş: tepe yüksekliği
func round_tower(parent: Node3D, pos: Vector3, r: float, h: float, domed := true, flag_tex: Texture2D = null) -> float:
	var m := ott_model("burc_dome" if domed else "burc_open")
	var r0 := 0.3 if domed else 0.25
	var h0 := 1.0 if domed else 0.82
	m.scale = Vector3(r / r0, h / h0, r / r0)
	m.position = pos
	m.rotation.y = randf() * TAU
	parent.add_child(m)
	var top := mark(m, "top").y * h / h0
	if flag_tex:
		pole_flag(parent, pos + Vector3(0, top - (0.12 if domed else 0.0), 0), 0.5, flag_tex, 0.4)
	return top


# Duvara asılı kırmızı sancak (hilalli, kırlangıç kuyruklu)
func hang_banner(parent: Node3D, pos: Vector3, h: float, rot_y := 0.0) -> MeshInstance3D:
	var key := "banner_mat"
	if not mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = preload("res://assets/ui/banner.png")
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.4
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.85
		mats[key] = m
	var q := QuadMesh.new()
	q.size = Vector2(h * 0.46, h)
	var mi := _mi(parent, q, pos, mats[key])
	mi.rotation.y = rot_y
	return mi


func glow_mat(color: Color) -> StandardMaterial3D:
	var key := "glow|" + color.to_html()
	if not mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color
		mats[key] = m
	return mats[key]


func prop(name: String, s: float) -> Node3D:
	var m: Node3D = lib[name].duplicate()
	m.transform = Transform3D.IDENTITY
	m.scale = Vector3.ONE * s
	return m


func add_prop(parent: Node3D, name: String, pos: Vector3, s: float, rot := 0.0) -> Node3D:
	var m := prop(name, s)
	m.position = pos
	m.rotation.y = rot
	parent.add_child(m)
	return m


func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _mi(parent, bm, pos, m)


func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, m: Material, seg := 12) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	return _mi(parent, cm, pos, m)


func sphere(parent: Node3D, r: float, pos: Vector3, m: Material, hemi := false, seg := 16) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r if hemi else r * 2.0
	sm.is_hemisphere = hemi
	sm.radial_segments = seg
	sm.rings = 8
	return _mi(parent, sm, pos, m)


func _mi(parent: Node3D, mesh: Mesh, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


# Kubbe: kasnak (silindir), kurşun yarım küre, altın alem
func dome(parent: Node3D, pos: Vector3, r: float, drum := 0.0) -> void:
	if drum > 0.0:
		cyl(parent, r * 1.02, r * 1.02, drum, pos + Vector3(0, drum / 2.0, 0), mat(WHITEWASH))
	sphere(parent, r, pos + Vector3(0, drum, 0), mat(LEAD, 0.5, 0.3), true)
	cyl(parent, 0.008, 0.008, r * 0.5, pos + Vector3(0, drum + r + r * 0.2, 0), mat(GOLD, 0.3, 0.8), 6)
	sphere(parent, r * 0.1, pos + Vector3(0, drum + r + r * 0.1, 0), mat(GOLD, 0.3, 0.8), false, 8)


func minaret(parent: Node3D, pos: Vector3, h: float) -> void:
	cyl(parent, 0.035, 0.045, h, pos + Vector3(0, h / 2.0, 0), mat(WHITEWASH), 10)
	cyl(parent, 0.06, 0.06, 0.02, pos + Vector3(0, h * 0.78, 0), mat(WHITEWASH), 10)
	cyl(parent, 0.0, 0.045, h * 0.22, pos + Vector3(0, h + h * 0.11, 0), mat(LEAD, 0.5, 0.3), 10)
	sphere(parent, 0.012, pos + Vector3(0, h + h * 0.24, 0), mat(GOLD, 0.3, 0.8), false, 6)


# Badanalı, çini şeritli, kubbeli Osmanlı yapısı
func ottoman_block(parent: Node3D, pos: Vector3, size: Vector3, dome_r := 0.0) -> void:
	box(parent, Vector3(size.x + 0.06, 0.06, size.z + 0.06), pos + Vector3(0, 0.03, 0), mat(STONE_DARK))
	box(parent, size, pos + Vector3(0, 0.06 + size.y / 2.0, 0), mat(WHITEWASH))
	box(parent, Vector3(size.x + 0.01, 0.03, size.z + 0.01), pos + Vector3(0, 0.06 + size.y * 0.8, 0), mat(IZNIK, 0.4))
	# kemerli pencereler
	var n := maxi(1, int(size.x / 0.14))
	for i in n:
		var x := -size.x / 2.0 + (i + 0.5) * size.x / n
		box(parent, Vector3(0.05, 0.1, 0.01), pos + Vector3(x, 0.06 + size.y * 0.45, size.z / 2.0 + 0.002), mat(Color("#3b4a5c")))
	if dome_r > 0.0:
		dome(parent, pos + Vector3(0, 0.06 + size.y, 0), dome_r, 0.04)
	else:
		var roof := CylinderMesh.new()
		roof.top_radius = 0.0
		roof.bottom_radius = 0.72
		roof.height = 0.22
		roof.radial_segments = 4
		var r := _mi(parent, roof, pos + Vector3(0, 0.06 + size.y + 0.11, 0), mat(Color("#c4553a")))
		r.rotation.y = PI / 4
		r.scale = Vector3(size.x * 1.05, 1, size.z * 1.05)


func flag(tex: Texture2D, w: float, h: float) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.orientation = PlaneMesh.FACE_Z
	pm.size = Vector2(w, h)
	pm.subdivide_width = 8
	pm.subdivide_depth = 1
	pm.center_offset = Vector3(w / 2.0, 0, 0)
	var sm := ShaderMaterial.new()
	sm.shader = flag_shader
	sm.set_shader_parameter("tex", tex)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func pole_flag(parent: Node3D, pos: Vector3, h: float, tex: Texture2D, w := 0.3) -> MeshInstance3D:
	cyl(parent, 0.012, 0.016, h, pos + Vector3(0, h / 2.0, 0), mat(WOOD_DARK), 6)
	var f := flag(tex, w, w * 0.66)
	f.position = pos + Vector3(0.01, h - w * 0.33, 0)
	parent.add_child(f)
	return f


# Kırmızı zemin üstünde beyaz hilal ve yıldız
func ottoman_flag() -> Texture2D:
	if tex_cache.has("ottoman"):
		return tex_cache.ottoman
	var w := 96
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var red := Color("#c41e2a")
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var col := red
			if p.distance_to(Vector2(40, 32)) < 17 and p.distance_to(Vector2(46, 32)) > 14:
				col = Color.WHITE
			var q := p - Vector2(62, 32)
			var k := cos(5.0 * (atan2(q.y, q.x) + PI / 2.0)) * 0.5 + 0.5
			if q.length() < lerpf(3.5, 8.0, pow(k, 3.0)):
				col = Color.WHITE
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	tex_cache.ottoman = ImageTexture.create_from_image(img)
	return tex_cache.ottoman


# Devlet sancağı: ana renk zemin, ortada süs renginde daire ve kenar şeritleri (gerçek bayrak değil)
func nation_flag(nation: String) -> Texture2D:
	if tex_cache.has(nation):
		return tex_cache[nation]
	var n: Dictionary = D.NATIONS[nation]
	var a := Color(n.primary)
	var b := Color(n.secondary)
	var img := Image.create(64, 40, false, Image.FORMAT_RGBA8)
	for y in 40:
		for x in 64:
			var col := a
			if Vector2(x - 26, y - 20).length() < 9.0 or y < 4 or y > 35:
				col = b
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	tex_cache[nation] = ImageTexture.create_from_image(img)
	return tex_cache[nation]


# ---------------------------------------------------------------- iskeletli askerler

# Gövde: KayKit karakteri, verilen parçalar görünür, renkler çarpılır. Animasyonlar knight.glb'den gelir.
# Blender'da yapılmış iskeletli asker (assets/models/ottoman/ch_*.glb). "Primary" ve "Secondary" örgüleri
# açık renktir; tint ile boyanır. Kemik adları (head, handslot_l/r) attach() ile kullanılabilir.
func ott_char(kind: String, tint := {}, scale := 0.4) -> Dictionary:
	var root: Node3D = ott["ch_" + kind].instantiate()
	root.scale = Vector3.ONE * scale * CHAR_SIZE
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var key := String(m.name)
		if tint.has(key):
			m.material_override = _tinted(m.mesh.surface_get_material(0), tint[key])
	var ap: AnimationPlayer = root.get_node("AnimationPlayer")
	for a in ["Idle", "Walking_A", "Running_A", "Sit_Chair_Idle", "Cheer"]:
		ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	ap.play("Idle")
	ap.seek(randf() * 1.0, true)
	return {"root": root, "anim": ap, "skeleton": root.get_node("Rig/Skeleton3D")}


# Atlı: binicinin kalçası eyere oturur (binici at ölçeğinden bağımsız dünya ölçeğinde rs)
func mount(hr: Dictionary, ch: Dictionary, rs := 0.3) -> void:
	var k: float = rs * CHAR_SIZE / hr.scale
	ch.root.scale = Vector3.ONE * k
	ch.root.position = hr.saddle - Vector3(0, 0.4 * k, 0.05)
	ch.anim.play("Sit_Chair_Idle")
	hr.body.add_child(ch.root)


func _tinted(base: Material, c: Color) -> Material:
	var key := "tint|%d|%s" % [base.get_instance_id(), c.to_html()]
	if not mats.has(key):
		var m: StandardMaterial3D = base.duplicate()
		m.albedo_color = c
		mats[key] = m
	return mats[key]


func attach(ch: Dictionary, slot: String) -> Node3D:
	var n: Node3D = ch.root.get_node_or_null("Rig/Skeleton3D/" + slot)
	if n == null:
		var sk: Skeleton3D = ch.skeleton
		var ba := BoneAttachment3D.new()
		ba.bone_name = slot
		sk.add_child(ba)
		n = ba
	var holder := Node3D.new()
	n.add_child(holder)
	return holder


func soft(c: Color, k := 0.35) -> Color:
	return c.lerp(Color.WHITE, k)


# ---------------------------------------------------------------- at

# At (Blender modeli): gövde, örtü ("Primary"), dört bacak "leg0".."leg3" kalçadan döner. Burnu +z.
func horse(color: Color, caparison: Color, s := 0.3) -> Dictionary:
	var root := Node3D.new()
	var m := ott_model("horse")
	m.scale = Vector3.ONE * s
	root.add_child(m)
	var body: MeshInstance3D = m.get_node("Horse")
	body.material_override = _tinted(body.mesh.surface_get_material(0), color)
	var legs := []
	for i in 4:
		var leg: MeshInstance3D = body.get_node("leg%d" % i)
		leg.material_override = body.material_override
		legs.append(leg)
	var cap: MeshInstance3D = body.get_node("Primary")
	cap.material_override = _tinted(cap.mesh.surface_get_material(0), caparison)
	return {"root": root, "body": body, "legs": legs, "phase": randf() * TAU, "scale": s, "saddle": mark(body, "saddle")}


func animate_horse(h: Dictionary, t: float, gait: float) -> void:
	var legs: Array = h.legs
	var ph: float = h.phase + t * 9.0
	for i in legs.size():
		var off := 0.0 if i == 0 or i == 3 else PI
		legs[i].rotation.x = sin(ph + off) * 0.55 * gait


# ---------------------------------------------------------------- düşmanlar

func enemy(type: String, nation: String) -> Dictionary:
	var n: Dictionary = D.NATIONS[nation]
	var p := Color(n.primary)
	var sec := Color(n.secondary)
	var metal := Color(n.metal)
	var root := Node3D.new()
	var info := {"root": root, "type": type}
	match type:
		"infantry":
			var ch := ott_char("enemy_infantry", {"Primary": soft(p, 0.15), "Secondary": soft(sec, 0.1)}, 0.4)
			root.add_child(ch.root)
			info.char = ch
			info.walk = "Walking_A"
		"knight":
			var ch := ott_char("enemy_knight", {"Primary": soft(p, 0.1), "Secondary": soft(metal, 0.25)}, 0.44)
			root.add_child(ch.root)
			info.char = ch
			info.walk = "Walking_A"
		"light", "horseArcher", "commander":
			var big := type == "commander"
			var hs := 0.3 if not big else 0.38
			var hr := horse(Color("#8a5e3a") if type != "horseArcher" else Color("#6a5444"), p, hs)
			root.add_child(hr.root)
			var kind: String = {"light": "enemy_rider", "horseArcher": "enemy_horse_archer", "commander": "enemy_commander"}[type]
			var ch := ott_char(kind, {"Primary": soft(p, 0.15), "Secondary": soft(sec, 0.15)})
			mount(hr, ch, 0.3 if not big else 0.38)
			if big:
				var f := pole_flag(hr.root, Vector3(-0.1, 0.3, -0.12), 0.65, nation_flag(nation), 0.27)
				f.rotation.y = PI / 2
			info.horse = hr
			info.char = ch
		"ram":
			_build_ram(root, p, sec)
			info.rolls = true
		"siegeTower":
			_build_siege_tower(root, p, nation)
			info.rolls = true
		"trebuchet", "elephant", "bossTower":
			_build_boss(root, info, type, p, nation)
	return info


# Patron modelleri (Blender, boss_*.glb): "Primary" millet rengine boyanır. Mancınıkta "arm" atış kolu,
# filde "leg0".."leg3" ve "trunk", dev kulede "bridge" iniş köprüsü ve "flag" sancak yeri vardır.
func _build_boss(root: Node3D, info: Dictionary, type: String, p: Color, nation: String) -> void:
	var name: String = {"trebuchet": "boss_trebuchet", "elephant": "boss_elephant", "bossTower": "boss_tower"}[type]
	var m := ott_model(name)
	m.scale = Vector3.ONE * {"trebuchet": 0.9, "elephant": 0.85, "bossTower": 0.8}[type]
	root.add_child(m)
	for prim in m.find_children("Primary*", "MeshInstance3D", true, false):
		prim.material_override = _tinted(prim.mesh.surface_get_material(0), soft(p, 0.1))
	var wheels := []
	for i in 4:
		var w := m.find_child("wheel%d" % i, true, false)
		if w:
			wheels.append(w)
	if wheels.size():
		root.set_meta("wheels", wheels)
	match type:
		"trebuchet":
			info.arm = m.find_child("arm", true, false)
		"elephant":
			var legs := []
			for i in 4:
				legs.append(m.find_child("leg%d" % i, true, false))
			info.horse = {"legs": legs, "phase": randf() * TAU}
			info.trunk = m.find_child("trunk", true, false)
		"bossTower":
			info.bridge = m.find_child("bridge", true, false)
			if info.bridge:
				info.bridge.rotation.x = -1.45
			var fl := m.find_child("flag", true, false)
			if fl:
				pole_flag(m, _local_pos(m, fl), 0.5, nation_flag(nation), 0.3)


func _build_ram(root: Node3D, p: Color, sec: Color) -> void:
	var g := Node3D.new()
	g.scale = Vector3.ONE * 0.3
	root.add_child(g)
	var wheels := []
	for w in [[-0.7, 0.6], [0.7, 0.6], [-0.7, -0.6], [0.7, -0.6]]:
		var wh := cyl(g, 0.32, 0.32, 0.14, Vector3(w[0], 0.32, w[1]), mat(Color("#5a3a20")), 12)
		wh.rotation.z = PI / 2
		wheels.append(wh)
	box(g, Vector3(1.3, 0.18, 1.7), Vector3(0, 0.6, 0), mat(Color("#8a5a32")))
	for w in [[-0.55, 0.7], [0.55, 0.7], [-0.55, -0.7], [0.55, -0.7]]:
		box(g, Vector3(0.1, 0.8, 0.1), Vector3(w[0], 1.0, w[1]), mat(Color("#8a5a32")))
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = 1.0
	roof.height = 0.6
	roof.radial_segments = 4
	var r := _mi(g, roof, Vector3(0, 1.6, 0), mat(soft(p, 0.15)))
	r.rotation.y = PI / 4
	r.scale = Vector3(1.0, 1, 1.3)
	box(g, Vector3(1.32, 0.08, 1.75), Vector3(0, 1.3, 0), mat(sec))
	var log := cyl(g, 0.17, 0.17, 2.2, Vector3(0, 0.85, 0.4), mat(WOOD_DARK), 8)
	log.rotation.x = PI / 2
	var tip := cyl(g, 0.0, 0.24, 0.35, Vector3(0, 0.85, 1.6), mat(Color("#8f939e"), 0.4, 0.6), 8)
	tip.rotation.x = PI / 2
	root.set_meta("wheels", wheels)


func _build_siege_tower(root: Node3D, p: Color, nation: String) -> void:
	var g := Node3D.new()
	g.scale = Vector3.ONE * 0.3
	root.add_child(g)
	var wheels := []
	for w in [[-0.6, 0.55], [0.6, 0.55], [-0.6, -0.55], [0.6, -0.55]]:
		var wh := cyl(g, 0.28, 0.28, 0.14, Vector3(w[0], 0.28, w[1]), mat(Color("#5a3a20")), 12)
		wh.rotation.z = PI / 2
		wheels.append(wh)
	var wood := mat(WOOD)
	box(g, Vector3(1.3, 2.8, 1.3), Vector3(0, 1.9, 0), wood)
	for y in [0.9, 1.7, 2.5, 3.2]:
		box(g, Vector3(1.36, 0.08, 1.36), Vector3(0, y, 0), mat(WOOD_DARK))
	box(g, Vector3(1.32, 0.9, 0.05), Vector3(0, 2.0, 0.67), mat(soft(p, 0.1)))
	box(g, Vector3(1.0, 0.1, 0.9), Vector3(0, 3.35, 0.55), mat(WOOD_DARK))
	var f := pole_flag(g, Vector3(0.5, 3.3, -0.5), 1.4, nation_flag(nation), 0.8)
	f.rotation.y = PI / 2
	root.set_meta("wheels", wheels)


# ---------------------------------------------------------------- Osmanlı askerleri

func troop(kind: String) -> Dictionary:
	var root := Node3D.new()
	var info := {"root": root, "kind": kind}
	match kind:
		"janissary", "archer", "sufi":
			var ch := ott_char(kind, {}, 0.4)
			root.add_child(ch.root)
			info.char = ch
		"sipahi":
			var hr := horse(Color("#f2eee6"), OTTOMAN_RED, 0.32)
			root.add_child(hr.root)
			var ch := ott_char("sipahi")
			mount(hr, ch, 0.32)
			info.horse = hr
			info.char = ch
	return info


# Kahraman komutan: kendi modeli (ch_<id>.glb) varsa o, yoksa geçici gövde; ayağının altında renkli halka
func hero(id: String) -> Dictionary:
	var h: Dictionary = D.HEROES[id]
	var root := Node3D.new()
	var own: bool = ott.has("ch_" + id)
	var ch := ott_char(id if own else h.model, {}, 0.44 if own else 0.47)
	root.add_child(ch.root)
	var t := TorusMesh.new()
	t.inner_radius = 0.17
	t.outer_radius = 0.21
	t.rings = 24
	t.ring_segments = 4
	var ring := MeshInstance3D.new()
	ring.mesh = t
	ring.material_override = glow_mat(Color(h.ring) * 1.6)
	ring.position.y = 0.02
	ring.scale.y = 0.2
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	return {"root": root, "kind": "hero", "char": ch}


func sultan() -> Dictionary:
	return ott_char("sultan", {}, 0.42)


# Oyuncunun hükümdarı (assets/models/ottoman/ch_king_*.glb). Seviye parçaları "L2".."L5" iskeletin altındadır:
# L2 başlıkta mücevher, L3 pelerin, L4 kılıç ya da asa, L5 altın süsler. Seviyeyle biraz da büyür.
func king(country: String, level: int) -> Dictionary:
	var ch := ott_char("king_" + country, {}, 0.42 * (1.0 + 0.03 * (level - 1)))
	for n in ch.skeleton.get_children():
		var nm := String(n.name)
		if nm.length() == 2 and nm.begins_with("L") and nm[1].is_valid_int():
			n.visible = int(nm.substr(1)) <= level
	return ch


# Atlı hükümdar: beyaz at, devlet renginde örtü; sağ elinde sancak (oyuncunun sancak dokusu, Osmanlı'da
# al sancak). Sancak direği "flag_holder" ile ele bağlıdır; Town her karede onu dik tutar.
func king_rider(country: String, level: int) -> Dictionary:
	var root := Node3D.new()
	var cap: Color = OTTOMAN_RED if country == "ottoman" else Color(D.NATIONS[country].primary)
	var hr := horse(Color("#f4f0e8"), cap, 0.42)
	root.add_child(hr.root)
	var ch := king(country, level)
	mount(hr, ch, 0.5 * (1.0 + 0.03 * (level - 1)))
	# sağ eldeki kılıç ya da asa sancağa yer açsın
	var l4: Node3D = (ch.skeleton as Node).get_node_or_null("L4")
	if l4:
		l4.visible = false
	var holder := attach(ch, "handslot_r")
	var pole := Node3D.new()
	holder.add_child(pole)
	cyl(pole, 0.01, 0.012, 1.15, Vector3(0, 0.35, 0), mat(WOOD_DARK), 6)
	sphere(pole, 0.025, Vector3(0, 0.94, 0), mat(GOLD, 0.3, 0.8), false, 8)
	var f := flag(ottoman_flag(), 0.48, 0.32)
	f.position = Vector3(0.01, 0.75, 0)
	pole.add_child(f)
	return {"root": root, "horse": hr, "char": ch, "pole": pole, "flag": f}


# Surlardaki ve kulelerdeki sancaklar tek bir dokuyu paylaşır; oyuncu başka devlet seçince o dokunun resmi
# değiştirilir, böylece bütün sancaklar yerinde güncellenir.
func set_player_flag(country: String) -> void:
	var tex: ImageTexture = ottoman_flag()
	if not tex_cache.has("ottoman_img"):
		tex_cache.ottoman_img = tex.get_image()
	var img: Image = tex_cache.ottoman_img if country == "ottoman" else nation_flag(country).get_image()
	tex.set_image(img)
	# surlarda asılı sancaklar (assets/ui/banner*.png)
	if mats.has("banner_mat"):
		mats.banner_mat.albedo_texture = load("res://assets/ui/%s.png" % banner_name(country))


static func banner_name(country: String) -> String:
	return "banner" if country == "ottoman" else "banner_" + country


# ---------------------------------------------------------------- kuleler

# Kule: kaide, gövde, seviye düğmeleri. Döner parça "head" ile döner.
func tower(type: String, level: int) -> Dictionary:
	var root := Node3D.new()
	var info := {"root": root, "type": type, "level": level}
	var s := 1.0 + 0.08 * (level - 1)
	var body := Node3D.new()
	body.scale = Vector3.ONE * s
	root.add_child(body)
	match type:
		"archer":
			# yuvarlak kesme taş kule (Blender modeli), taşan mazgallı taç, tepede okçu
			var m := ott_model("archer_tower_%d" % level)
			body.add_child(m)
			var head := Node3D.new()
			head.position = mark(m, "top")
			body.add_child(head)
			var ch := ott_char("tower_archer", {}, 0.34)
			head.add_child(ch.root)
			info.head = head
			info.char = ch
			info.flag = mark(m, "flag")
			if level >= 2:
				add_prop(body, "bucket_arrows", Vector3(0.3, 0, 0.22), 1.1)
		"tar":
			var m := ott_model("tar_tower")
			body.add_child(m)
			info.smoke = mark(m, "smoke")
			info.fire = mark(m, "fire")
		"cannon":
			# taş tabya; "head" (kundak) döner, "barrel" (tunç namlu) geri teper
			var m := ott_model("cannon_tower")
			body.add_child(m)
			info.head = m.find_child("head", true, false)
			info.barrel = m.find_child("barrel", true, false)
			info.muzzle = Vector3(0, 0.17, 0.42)
		"musket":
			var m := ott_model("musket_tower")
			body.add_child(m)
			var head := Node3D.new()
			head.position = mark(m, "top")
			body.add_child(head)
			var ch := ott_char("janissary_musket", {}, 0.4)
			head.add_child(ch.root)
			info.head = head
			info.char = ch
			info.muzzle = Vector3(0, 0.62, 0.42)
	# seviye düğmeleri ve 3. seviyede sancak
	for i in level:
		sphere(root, 0.03, Vector3(-0.12 + i * 0.12, 0.03, 0.42), mat(GOLD, 0.3, 0.8), false, 8)
	if type == "archer":
		pole_flag(body, info.flag, 0.42 if level >= 3 else 0.38, ottoman_flag(), 0.26 if level >= 3 else 0.22)
	elif level >= 3:
		pole_flag(root, Vector3(0.2, 0.6, -0.1), 0.45, ottoman_flag(), 0.26)
	return info


# ---------------------------------------------------------------- şehir binaları

func building(id: String, level: int) -> Node3D:
	var root := Node3D.new()
	if level <= 0:
		_empty_plot(root)
		return root
	# Blender modelleri arsanın ~%65'ini kaplar; 1.3 ile arsayı doldurur
	var s: float = [0.0, 0.88, 1.0, 1.12][level] * 1.3
	var g := Node3D.new()
	g.scale = Vector3.ONE * s
	root.add_child(g)
	# Blender modeli: gövde + "L2", "L3" parçaları; Cami'de minareler "M1".."M4"
	# kendi modeli henüz yoksa (Medrese) Mektep'in gövdesi
	var m := ott_model("b_" + id if ott.has("b_" + id) else "b_school")
	g.add_child(m)
	for c in m.find_children("*", "Node3D", true, false):
		var n := String(c.name)
		if n == "L2" or n == "L3":
			c.visible = level >= int(n.substr(1))
		elif n.length() == 2 and n.begins_with("M"):
			c.visible = int(n.substr(1)) <= D.CITY.minarets[level]
	if level >= 3 and m.find_child("flag", true, false):
		pole_flag(g, mark(m, "flag"), 0.4, ottoman_flag(), 0.24)
	if id == "cavalry" and level >= 2:
		var hr := horse(Color("#e8e2d6"), OTTOMAN_RED, 0.16)
		hr.root.position = Vector3(0.05, 0, 0.12)
		hr.root.rotation.y = 1.2
		g.add_child(hr.root)
	# seviye düğmeleri
	for i in level:
		sphere(root, 0.028, Vector3(-0.1 + i * 0.1, 0.03, 0.46), mat(GOLD, 0.3, 0.8), false, 8)
	return root


func _empty_plot(root: Node3D) -> void:
	box(root, Vector3(0.7, 0.04, 0.7), Vector3(0, 0.02, 0), mat(STONE_DARK))
	for c in [Vector3(-0.33, 0, -0.33), Vector3(0.33, 0, -0.33), Vector3(-0.33, 0, 0.33), Vector3(0.33, 0, 0.33)]:
		cyl(root, 0.012, 0.012, 0.16, c + Vector3(0, 0.08, 0), mat(WOOD), 6)
		sphere(root, 0.022, c + Vector3(0, 0.17, 0), mat(OTTOMAN_RED), false, 6)
	add_prop(root, "resource_stone", Vector3(-0.15, 0.04, 0.08), 0.6, 0.4)
	add_prop(root, "resource_lumber", Vector3(0.15, 0.04, -0.1), 0.45, 1.2)
