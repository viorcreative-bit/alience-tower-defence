extends Node3D

# Osmanlı Kale Savunması (Godot). Oyun mantığı Game'de, durağan sahne World'de, modeller Models'da,
# arayüz GameUI'da, sesler GameAudio'da. Bu dosya hepsini bağlar: her karede mantığı ilerletir,
# kule/düşman/asker/mermi düğümlerini durumla eşler ve olayları efekte ve sese çevirir.

const D := preload("res://scripts/data.gd")
const SAVE_PATH := "user://kale.cfg"

var game: Game
var models: Models
var world: World
var ui: GameUI
var audio: GameAudio
var camera: Camera3D
var cam_base := Transform3D()
var shake := 0.0

var tower_nodes := {}  # id → {info, level}
var enemy_nodes := {}
var unit_nodes := {}
var proj_nodes := {}
var building_nodes := {}  # id → {node, level}
var bars := {}  # id → [bg, fill]

var select_tile: MeshInstance3D
var range_ring: MeshInstance3D
var hover_tile: MeshInstance3D
var dust_mat: StandardMaterial3D
var spark_mat: StandardMaterial3D
var sultan: Dictionary
var town: Town
var save := ConfigFile.new()


func _ready() -> void:
	save.load(SAVE_PATH)
	game = Game.new()
	models = Models.new()
	world = World.new()
	add_child(world)
	world.time_of_day = save.get_value("settings", "light", 1)
	world.setup(models, game)
	camera = Camera3D.new()
	camera.fov = 36
	camera.near = 0.2
	camera.far = 140.0
	add_child(camera)
	audio = GameAudio.new()
	add_child(audio)
	audio.set_enabled(save.get_value("settings", "sound", true))
	ui = GameUI.new(game)
	ui.best_wave = save.get_value("game", "best_wave", 0)
	add_child(ui)
	ui.action.connect(_on_action)
	dust_mat = world.fire_mat.duplicate()
	dust_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	spark_mat = world.fire_mat
	_build_markers()
	_sync_buildings()
	sultan = models.sultan()
	sultan.root.position = world.to_world(4.5, 13.55)
	sultan.anim.play("Idle")
	add_child(sultan.root)
	town = Town.new()
	town.setup(models, game, world)
	add_child(town)
	get_viewport().size_changed.connect(_fit_camera)
	await get_tree().process_frame
	_fit_camera()
	_debug_hooks()


# ---------------------------------------------------------------- kamera

# Tahtanın tamamı (ordugâh dahil) üst şerit ile alt panelin arasına sığacak uzaklık ve kaydırma.
func _fit_camera() -> void:
	var pitch := deg_to_rad(54.0)
	var dir := Vector3(0, sin(pitch), cos(pitch))
	var vs := get_viewport().get_visible_rect().size
	var y0 := ui.top_bottom() + 6.0
	var y1 := ui.panel_top() - 6.0
	if y1 - y0 < 100.0:
		y0 = 0.0
		y1 = vs.y
	var corners: Array[Vector3] = []
	for x in [-game.cols / 2.0 - 0.1, game.cols / 2.0 + 0.1]:
		for z in [-game.rows / 2.0 - 1.6, game.rows / 2.0 + 0.3]:
			for y in [0.0, 1.0]:
				corners.append(Vector3(x, y, z))
	var target := Vector3(0, 0, 0.3)
	var lo := 4.0
	var hi := 90.0
	for i in 26:
		var mid := (lo + hi) / 2.0
		var t := _center(target, dir, mid, corners, (y0 + y1) / 2.0)
		camera.look_at_from_position(t + dir * mid, t)
		var ok := true
		for c in corners:
			var s := camera.unproject_position(c)
			if s.x < vs.x * 0.01 or s.x > vs.x * 0.99 or s.y < y0 or s.y > y1:
				ok = false
				break
		if ok:
			hi = mid
		else:
			lo = mid
	var tt := _center(target, dir, hi, corners, (y0 + y1) / 2.0)
	camera.look_at_from_position(tt + dir * hi, tt)
	cam_base = camera.transform


# Görüntü dikey olarak istenen bandın ortasına gelsin diye hedefi z ekseninde kaydırır.
func _center(target: Vector3, dir: Vector3, d: float, corners: Array[Vector3], want: float) -> Vector3:
	var t := target
	for k in 6:
		camera.look_at_from_position(t + dir * d, t)
		var mn := INF
		var mx := -INF
		for c in corners:
			var s := camera.unproject_position(c)
			mn = minf(mn, s.y)
			mx = maxf(mx, s.y)
		var err := (mn + mx) / 2.0 - want
		t.z += err * d * 0.0009
	return t


# ---------------------------------------------------------------- dokunma

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var t := _tile_under(event.position)
		var ok := t.y >= 0 and t.y < game.wall_row and t.x >= 0 and t.x < game.cols and not game.is_path_tile(t.x, t.y)
		hover_tile.visible = ok and game.tower_at(t.x, t.y) == null
		if ok:
			hover_tile.position = world.to_world(t.x + 0.5, t.y + 0.5, 0.012)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var t := _tile_under(event.position)
		game.select_tile(t.x, t.y)


func _tile_under(screen: Vector2) -> Vector2i:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 1e-4:
		return Vector2i(-99, -99)
	var p := from + dir * (-from.y / dir.y)
	return Vector2i(floori(p.x + game.cols / 2.0), floori(p.z + game.rows / 2.0))


func _on_action(name: String, arg: String) -> void:
	match name:
		"build":
			game.build_tower(arg)
		"upgrade":
			game.upgrade_tower()
		"sell":
			game.sell_tower()
		"building":
			game.upgrade_building(arg)
		"train":
			game.train_troop(arg)
		"primary":
			game.start_wave()
		"speed":
			var list: Array = D.RULES.speeds
			game.speed = list[(list.find(game.speed) + 1) % list.size()]
		"charge":
			game.trigger_charge()
		"sound":
			audio.set_enabled(not audio.enabled)
			save.set_value("settings", "sound", audio.enabled)
			save.save(SAVE_PATH)
		"light":
			world.cycle_light()
			save.set_value("settings", "light", world.time_of_day)
			save.save(SAVE_PATH)
		"restart":
			_restart()


func _restart() -> void:
	for dict in [tower_nodes, enemy_nodes, unit_nodes, proj_nodes]:
		for id in dict:
			dict[id].info.root.queue_free()
		dict.clear()
	for id in bars:
		bars[id][0].queue_free()
	bars.clear()
	game.reset()
	_sync_buildings()


# ---------------------------------------------------------------- ana döngü

func _process(delta: float) -> void:
	if game.advance(delta) or game.phase == "lost":
		_save_best()
	_handle_events()
	_sync_towers(delta)
	_sync_enemies(delta)
	_sync_units(delta)
	_sync_projectiles()
	_sync_buildings()
	town.update(delta)
	_update_markers()
	audio.set_music("wave" if game.phase == "wave" else ("build" if game.phase == "build" else "off"))
	ui.refresh(audio.enabled, world.light_name())
	if shake > 0.0:
		shake = maxf(0.0, shake - delta)
		camera.transform = cam_base
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.35
		if shake <= 0.0:
			camera.transform = cam_base


func _save_best() -> void:
	if game.wave > ui.best_wave:
		ui.best_wave = game.wave
		save.set_value("game", "best_wave", game.wave)
		save.save(SAVE_PATH)


# ---------------------------------------------------------------- eşleme

func _yaw(angle: float) -> float:
	# mantık açısı (x sağa, y aşağı) → modelin +z yönünden y ekseni dönüşü
	return atan2(cos(angle), sin(angle))


func _sync_towers(dt: float) -> void:
	var seen := {}
	for t in game.towers:
		seen[t.id] = true
		var rec = tower_nodes.get(t.id)
		if rec == null or rec.level != t.level:
			if rec != null:
				rec.info.root.queue_free()
			var info := models.tower(t.type, t.level)
			info.root.position = world.to_world(t.x, t.y)
			add_child(info.root)
			_pop(info.root)
			_burst(info.root.position + Vector3(0, 0.05, 0), Color(0.85, 0.75, 0.55, 0.7), 22, 1.2, 0.22, 0.8, 0.3)
			if info.has("fire"):
				world.fire(info.root, info.fire, 0.6, true)
				_smoke(info.root, info.smoke)
			rec = {"info": info, "level": t.level, "recoil": 0.0}
			tower_nodes[t.id] = rec
		var info: Dictionary = rec.info
		if info.has("head"):
			var yaw := _yaw(t.angle)
			info.head.rotation.y = lerp_angle(info.head.rotation.y, yaw, minf(1.0, dt * 12.0))
		if info.has("barrel"):
			info.barrel.position.z = -0.08 * t.recoil
		if t.recoil > 0.9 and rec.recoil <= 0.0 and info.has("muzzle"):
			_muzzle(info)
		rec.recoil = t.recoil
	for id in tower_nodes.keys():
		if not seen.has(id):
			var root: Node3D = tower_nodes[id].info.root
			_burst(root.position + Vector3(0, 0.1, 0), Color(0.85, 0.75, 0.55, 0.7), 18, 1.0, 0.2, 0.7, 0.3)
			root.queue_free()
			tower_nodes.erase(id)


func _muzzle(info: Dictionary) -> void:
	var head: Node3D = info.head
	var p := head.to_global(info.muzzle)
	_burst(p, Color(2.2, 1.6, 0.8, 1.0), 10, 1.4, 0.07, 0.18, 0.0, true)
	_burst(p, Color(0.85, 0.82, 0.78, 0.7), 10, 0.6, 0.2, 0.9, 0.5)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.4)
	l.omni_range = 1.8
	l.light_energy = 3.0
	l.position = p
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.15)
	tw.tween_callback(l.queue_free)


func _sync_enemies(dt: float) -> void:
	var seen := {}
	var t := Time.get_ticks_msec() / 1000.0
	for e in game.enemies:
		seen[e.id] = true
		var rec = enemy_nodes.get(e.id)
		if rec == null:
			var info := models.enemy(e.type, e.nation)
			add_child(info.root)
			rec = {"info": info, "anim": "", "tar": null}
			enemy_nodes[e.id] = rec
			if info.root.has_meta("wheels"):
				info.wheels = info.root.get_meta("wheels")
		var info: Dictionary = rec.info
		var root: Node3D = info.root
		root.position = world.to_world(e.x, e.y)
		var moving: bool = e.blocker == null
		var yaw := _yaw(e.angle)
		if not moving and e.blocker != null:
			yaw = _yaw(atan2(e.blocker.y - e.y, e.blocker.x - e.x))
		root.rotation.y = lerp_angle(root.rotation.y, yaw, minf(1.0, dt * 10.0))
		var spd: float = e.speed * (1.0 - e.slow) * game.speed
		if info.has("char"):
			var ch: Dictionary = info.char
			var want := "Sit_Chair_Idle" if info.has("horse") else ("Walking_A" if moving else ("1H_Melee_Attack_Chop" if e.swing > 0.6 else "Idle"))
			if rec.anim != want:
				rec.anim = want
				ch.anim.play(want, 0.15)
			ch.anim.speed_scale = (spd * 1.4 if want == "Walking_A" else 1.0) if not info.has("horse") else 1.0
		if info.has("horse"):
			models.animate_horse(info.horse, t * spd * 0.8, 1.0 if moving else 0.15)
		if info.has("wheels") and moving:
			for w in info.wheels:
				w.rotation.x += dt * spd * 6.0
		# ziftli düşmanın altında kara leke
		if e.slow > 0.0:
			if rec.tar == null:
				rec.tar = _tar_spot(root, e.radius)
		elif rec.tar != null:
			rec.tar.queue_free()
			rec.tar = null
		# vurulunca kısa parlama: hafif büyüyüp küçülür
		var k: float = 1.0 + 0.12 * clampf(e.flash / D.RULES.hit_flash, 0.0, 1.0)
		root.scale = Vector3.ONE * k
		_bar(e.id, root.position + Vector3(0, 0.62 + e.radius, 0), e.hp / e.max_hp, Color("#ff5b4d") if e.hp / e.max_hp < 0.4 else Color("#7fe05a"), e.hp < e.max_hp)
	for id in enemy_nodes.keys():
		if not seen.has(id):
			enemy_nodes[id].info.root.queue_free()
			enemy_nodes.erase(id)
			_drop_bar(id)


func _tar_spot(parent: Node3D, r: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r + 0.12
	c.bottom_radius = r + 0.12
	c.height = 0.01
	c.radial_segments = 16
	m.mesh = c
	m.material_override = models.mat(Color("#1d1620"), 0.2)
	m.position.y = 0.015
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


func _sync_units(dt: float) -> void:
	var seen := {}
	var t := Time.get_ticks_msec() / 1000.0
	for u in game.units:
		seen[u.id] = true
		var rec = unit_nodes.get(u.id)
		if rec == null:
			var info := models.troop(u.kind)
			add_child(info.root)
			rec = {"info": info, "anim": ""}
			unit_nodes[u.id] = rec
		var info: Dictionary = rec.info
		var root: Node3D = info.root
		root.position = world.to_world(u.x, u.y)
		var yaw := _yaw(u.angle) if (u.moving or u.engaged or u.swing > 0.0) else 0.0
		if u.ready and not u.engaged and u.swing <= 0.0:
			yaw = PI  # düşmana (kuzeye) bak
		root.rotation.y = lerp_angle(root.rotation.y, yaw, minf(1.0, dt * 8.0))
		var ch: Dictionary = info.char
		var want := "Idle"
		if info.has("horse"):
			want = "Sit_Chair_Idle"
			models.animate_horse(info.horse, t * 2.0, 1.0 if u.moving else 0.1)
		elif u.moving:
			want = "Running_A" if u.kind == "janissary" else "Walking_A"
		elif u.swing > 0.5:
			want = "1H_Melee_Attack_Chop"
		if rec.anim != want:
			rec.anim = want
			ch.anim.play(want, 0.12)
		_bar(u.id, root.position + Vector3(0, 0.72, 0), u.hp / u.max_hp, Color("#f2c94c"), u.hp < u.max_hp)
	for id in unit_nodes.keys():
		if not seen.has(id):
			unit_nodes[id].info.root.queue_free()
			unit_nodes.erase(id)
			_drop_bar(id)


func _sync_projectiles() -> void:
	var seen := {}
	for p in game.projectiles:
		seen[p.id] = true
		var rec = proj_nodes.get(p.id)
		if rec == null:
			rec = {"info": {"root": _projectile_node(p.type)}, "start": Vector2(p.x, p.y)}
			add_child(rec.info.root)
			proj_nodes[p.id] = rec
		var root: Node3D = rec.info.root
		var total: float = rec.start.distance_to(Vector2(p.tx, p.ty)) + rec.start.distance_to(Vector2(p.x, p.y))
		var k: float = rec.start.distance_to(Vector2(p.x, p.y)) / maxf(total, 0.01)
		var arc := {"archer": 0.35, "tar": 0.5, "cannon": 0.8}.get(p.type, 0.3) as float
		var base_h := 0.9 if p.from == "tower" and p.type == "archer" else 0.4
		var h := lerpf(base_h, 0.25, k) + sin(k * PI) * arc
		var pos := world.to_world(p.x, p.y, h)
		if pos.distance_squared_to(root.position) > 1e-6 and root.position != Vector3.ZERO:
			root.look_at(pos + (pos - root.position), Vector3.UP)
		root.position = pos
	for id in proj_nodes.keys():
		if not seen.has(id):
			proj_nodes[id].info.root.queue_free()
			proj_nodes.erase(id)


func _projectile_node(type: String) -> Node3D:
	var a := Node3D.new()
	var trail := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	q.material = spark_mat
	trail.mesh = q
	trail.amount = 16
	trail.lifetime = 0.25
	trail.local_coords = false
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_max = 0.05
	var g := Gradient.new()
	match type:
		"archer":
			models.box(a, Vector3(0.018, 0.018, 0.26), Vector3.ZERO, models.mat(Color("#7a4e2a")))
			models.box(a, Vector3(0.03, 0.03, 0.05), Vector3(0, 0, -0.14), models.glow_mat(Color(2.4, 1.9, 1.1)))
			g.set_color(0, Color(2.0, 1.6, 0.9, 0.9))
			g.set_color(1, Color(1.0, 0.5, 0.2, 0.0))
		"tar":
			models.sphere(a, 0.07, Vector3.ZERO, models.mat(Color("#1a1418"), 0.15), false, 10)
			q.material = dust_mat
			q.size = Vector2(0.12, 0.12)
			g.set_color(0, Color(0.15, 0.12, 0.14, 0.7))
			g.set_color(1, Color(0.3, 0.28, 0.3, 0.0))
		_:
			models.sphere(a, 0.07, Vector3.ZERO, models.mat(Color("#2a2a2e"), 0.4, 0.6), false, 10)
			q.material = dust_mat
			q.size = Vector2(0.14, 0.14)
			g.set_color(0, Color(0.8, 0.78, 0.72, 0.6))
			g.set_color(1, Color(0.8, 0.78, 0.72, 0.0))
	trail.color_ramp = g
	a.add_child(trail)
	return a


func _sync_buildings() -> void:
	for id in D.BUILDINGS:
		var lv: int = game.buildings[id]
		var rec = building_nodes.get(id)
		if rec != null and rec.level == lv:
			continue
		if rec != null:
			rec.node.queue_free()
		var s: Array = D.BUILDINGS[id].slot
		var node := models.building(id, lv)
		node.position = world.to_world(s[0] + 0.5, s[1] + 0.5)
		if lv == 0:
			var l := Label3D.new()
			l.text = "+ " + String(D.BUILDING_NAMES[id][0]).replace(" ", "\n")
			l.font = ui.font_bold
			l.font_size = 40
			l.pixel_size = 0.0058
			l.line_spacing = -8
			l.outline_size = 10
			l.modulate = Color("#f3e6c8")
			l.outline_modulate = Color(0.15, 0.08, 0.04)
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.position = Vector3(0, 0.32, 0)
			l.no_depth_test = true
			l.name = "Sign"
			node.add_child(l)
		else:
			# kurulu binanın adı önünde küçükçe yazar
			var l := Label3D.new()
			l.text = String(D.BUILDING_NAMES[id][0])
			l.font = ui.font_bold
			l.font_size = 32
			l.pixel_size = 0.0045
			l.outline_size = 8
			l.modulate = Color(1.0, 0.93, 0.78, 0.92)
			l.outline_modulate = Color(0.15, 0.08, 0.04)
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.position = Vector3(0, 0.08, 0.44)
			l.no_depth_test = true
			node.add_child(l)
		add_child(node)
		if rec != null:
			_pop(node)
		building_nodes[id] = {"node": node, "level": lv}
	# kurulabilir arsaların yazısı parlak, kurulamayanlar soluk
	for id in building_nodes:
		var sign: Label3D = building_nodes[id].node.get_node_or_null("Sign")
		if sign:
			sign.modulate = Color("#ffe39a") if game.can_upgrade_building(id) else Color(0.75, 0.7, 0.62, 0.75)


func _pop(n: Node3D) -> void:
	n.scale = Vector3(1, 0.05, 1)
	create_tween().tween_property(n, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- can çubukları

func _bar(id: int, pos: Vector3, frac: float, col: Color, show: bool) -> void:
	if not show:
		if bars.has(id):
			bars[id][0].visible = false
		return
	if not bars.has(id):
		var bg := ColorRect.new()
		bg.color = Color(0.1, 0.05, 0.02, 0.8)
		bg.size = Vector2(36, 6)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := ColorRect.new()
		fill.position = Vector2(1, 1)
		fill.size = Vector2(34, 4)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(fill)
		ui.bars.add_child(bg)
		bars[id] = [bg, fill]
	var b: Array = bars[id]
	b[0].visible = not camera.is_position_behind(pos)
	b[0].position = camera.unproject_position(pos) - Vector2(18, 0)
	b[1].size.x = 34.0 * clampf(frac, 0.0, 1.0)
	b[1].color = col


func _drop_bar(id: int) -> void:
	if bars.has(id):
		bars[id][0].queue_free()
		bars.erase(id)


# ---------------------------------------------------------------- seçim işaretleri

func _build_markers() -> void:
	var bm := BoxMesh.new()
	bm.size = Vector3(0.96, 0.02, 0.96)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(1.0, 0.85, 0.4, 0.32)
	select_tile = MeshInstance3D.new()
	select_tile.mesh = bm
	select_tile.material_override = sm
	select_tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(select_tile)
	hover_tile = select_tile.duplicate()
	var hm := sm.duplicate()
	hm.albedo_color = Color(1, 1, 0.85, 0.16)
	hover_tile.material_override = hm
	add_child(hover_tile)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.97
	ring.outer_radius = 1.0
	ring.rings = 64
	ring.ring_segments = 4
	range_ring = MeshInstance3D.new()
	range_ring.mesh = ring
	range_ring.material_override = models.glow_mat(Color(1.4, 1.2, 0.6))
	range_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


func _update_markers() -> void:
	var sel = game.selected
	select_tile.visible = sel != null
	range_ring.visible = false
	if sel == null:
		return
	select_tile.position = world.to_world(sel.c + 0.5, sel.r + 0.5, 0.015)
	var t = game.selected_tower()
	if t != null:
		var s := game.tower_stats(t)
		range_ring.visible = true
		range_ring.position = world.to_world(t.x, t.y, 0.03)
		range_ring.scale = Vector3(s.range, 1, s.range)


# ---------------------------------------------------------------- olaylar ve efektler

func _handle_events() -> void:
	for ev in game.events:
		match ev.kind:
			"sound":
				audio.play(ev.id, ev)
			"particles":
				var c := Color(ev.color)
				c.a = 0.9
				_burst(world.to_world(ev.x, ev.y, 0.25), c, ev.count, ev.speed * 0.7, maxf(0.06, ev.size * 2.2), ev.life, -1.5)
			"ring":
				_ring(world.to_world(ev.x, ev.y, 0.05), ev.radius, Color(ev.color))
			"musket":
				_shot_line(world.to_world(ev.x0, ev.y0, 0.75), world.to_world(ev.x1, ev.y1, 0.3))
			"text":
				_float_text(world.to_world(ev.x, ev.y, 0.6), ev.text, Color(ev.color))
			"banner":
				ui.show_banner(ev.text, Color(ev.color), ev.life)
			"shake":
				if shake <= 0.0:
					cam_base = camera.transform
				shake = maxf(shake, ev.time)
	game.events.clear()


func _burst(pos: Vector3, color: Color, count := 16, speed := 1.4, size := 0.1, life := 0.6, grav := -2.0, glow := false) -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = spark_mat if glow else dust_mat
	p.mesh = q
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = maxi(1, count)
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
	get_tree().create_timer(life + 0.4).timeout.connect(p.queue_free)


func _smoke(parent: Node3D, pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	q.material = dust_mat
	p.mesh = q
	p.amount = 8
	p.lifetime = 1.6
	p.direction = Vector3.UP
	p.spread = 15
	p.gravity = Vector3(0.05, 0.25, 0)
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.18
	var g := Gradient.new()
	g.set_color(0, Color(0.25, 0.22, 0.24, 0.5))
	g.set_color(1, Color(0.5, 0.48, 0.5, 0.0))
	p.color_ramp = g
	p.position = pos
	parent.add_child(p)


func _ring(pos: Vector3, radius: float, color: Color) -> void:
	var t := TorusMesh.new()
	t.inner_radius = 0.85
	t.outer_radius = 1.0
	t.rings = 32
	t.ring_segments = 4
	var m := MeshInstance3D.new()
	m.mesh = t
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = pos
	m.scale = Vector3(0.1, 0.3, 0.1)
	add_child(m)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3(radius, 0.3, radius), 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(m.queue_free)


func _shot_line(a: Vector3, b: Vector3) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, a.distance_to(b))
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(2.5, 2.2, 1.5, 0.9)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.look_at_from_position((a + b) / 2.0, b, Vector3.UP)
	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.14)
	tw.tween_callback(m.queue_free)


func _float_text(pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = ui.font_bold
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 56
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_modulate = Color(0.25, 0.1, 0.0)
	l.outline_size = 12
	l.no_depth_test = true
	l.position = pos
	add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 0.6, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


# ---------------------------------------------------------------- geliştirme

# `-- --demo` ile birkaç kule, bina ve asker kurulu, dalga başlamış hâlde açılır (ekran görüntüsü için).
# `--light=0|1|2` ışığı seçer, `--select=c,r` bir kareyi seçer.
func _debug_hooks() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--light="):
			world.time_of_day = int(a.substr(8))
			world.apply_light(true)
	if "--demo" in args:
		game.gold = 5000
		game.res = {"wood": 500, "iron": 500, "food": 500}
		for id in ["school", "barracks", "archery", "hospital", "mosque", "court", "cavalry", "science", "religion", "kitchen"]:
			game.upgrade_building(id)
		game.upgrade_building("palace")
		game.upgrade_building("mosque")
		game.upgrade_building("barracks")
		var spots := [[3, 3, "archer"], [5, 4, "tar"], [3, 9, "cannon"], [5, 9, "musket"], [0, 4, "archer"], [8, 6, "cannon"]]
		for s in spots:
			game.selected = {"c": s[0], "r": s[1]}
			game.build_tower(s[2])
			game.upgrade_tower()
		for k in D.TROOP_ORDER:
			while game.can_train(k):
				game.train_troop(k)
		for k in game.training:
			game.training[k].time = 99.0
		game.selected = null
		game.gold = 400
		if _arg(args, "--wave=", "") != "":
			game.wave = int(_arg(args, "--wave=", "0"))
			game.start_wave()
	var sel := _arg(args, "--select=", "")
	if sel != "":
		var p := sel.split(",")
		game.select_tile(int(p[0]), int(p[1]))


func _arg(args: PackedStringArray, key: String, def: String) -> String:
	for a in args:
		if a.begins_with(key):
			return a.substr(key.length())
	return def
