class_name Town
extends Node3D

# Surların içindeki hayat: sokaklarda gezen halk, Cami önünde dönen semazenler ve
# Odun-Demir Ocağı'nın işçileri. Halk ve semazenler yalnızca görüntüdür; işçilerin getirdiği
# her yük game.deliver ile kaynaklara eklenir. Şehir büyüdükçe kalabalık artar.

const D := preload("res://scripts/data.gd")
const ROBES := ["#7a3b2e", "#2f5d7c", "#5b6b2f", "#8a6a48", "#6b2d5f", "#a0522d", "#3d4f6b", "#7c6a3a"]
const SCARVES := ["#e8e0cc", "#c8423a", "#3e6fb5", "#d9b65a", "#6a8f5a"]
const MAX_PEOPLE := 18

var models: Models
var game: Game
var world: World
var rng := RandomNumberGenerator.new()
var people: Array = []
var dervishes: Array = []
var workers: Array = []
var king := {}
# sokaklar binaların arasındaki çizgilerdir: x tam sayılar, y üç sıra
var xs := [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
var ys := []


func setup(m: Models, g: Game, w: World) -> void:
	models = m
	game = g
	world = w
	rng.seed = 1299
	ys = [g.wall_row + 1.1, g.wall_row + 2.0, g.wall_row + 3.0]


func wanted() -> int:
	var built := 0
	for id in game.buildings:
		if game.buildings[id] > 0:
			built += 1
	return mini(MAX_PEOPLE, 5 + game.buildings.palace * 2 + built)


func update(dt: float) -> void:
	while people.size() < wanted():
		_add_person()
	while people.size() > wanted():
		people.pop_back().ch.root.queue_free()
	while dervishes.size() > game.buildings.mosque:
		dervishes.pop_back().ch.root.queue_free()
	for p in people:
		_step(p, dt)
	_update_dervishes(dt)
	_update_workers(dt)
	_update_king(dt)


func _add_person() -> void:
	var woman := rng.randf() < 0.45
	var ch: Dictionary
	var tint := {"Primary": Color(ROBES[rng.randi() % ROBES.size()]), "Secondary": Color(SCARVES[rng.randi() % SCARVES.size()])}
	ch = models.ott_char("townswoman" if woman else "townsman", tint, 0.34 if woman else 0.36)
	add_child(ch.root)
	var n := Vector2i(rng.randi() % xs.size(), rng.randi() % ys.size())
	var p := {"ch": ch, "node": n, "pos": _node_pos(n), "target": n, "wait": rng.randf_range(0.0, 2.0),
		"speed": rng.randf_range(0.35, 0.55), "anim": ""}
	ch.root.position = world.to_world(p.pos.x, p.pos.y)
	ch.root.rotation.y = rng.randf() * TAU
	people.append(p)


func _node_pos(n: Vector2i) -> Vector2:
	return Vector2(xs[n.x], ys[n.y]) + Vector2(rng.randf_range(-0.07, 0.07), rng.randf_range(-0.05, 0.05))


func _step(p: Dictionary, dt: float) -> void:
	var ch: Dictionary = p.ch
	var want := "Idle"
	if p.wait > 0.0:
		p.wait -= dt
	else:
		var goal: Vector2 = p.get("goal", p.pos)
		var d: Vector2 = goal - p.pos
		if d.length() < 0.02:
			# kavşağa vardı: biraz dur ya da komşu bir kavşağa yürü
			if rng.randf() < 0.3:
				p.wait = rng.randf_range(1.0, 3.5)
			var n: Vector2i = p.node
			var opts := []
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var m: Vector2i = n + o
				if m.x >= 0 and m.x < xs.size() and m.y >= 0 and m.y < ys.size():
					opts.append(m)
			p.node = opts[rng.randi() % opts.size()]
			p.goal = _node_pos(p.node)
		else:
			var step: float = minf(d.length(), p.speed * dt)
			p.pos += d.normalized() * step
			ch.root.rotation.y = lerp_angle(ch.root.rotation.y, atan2(d.x, d.y), minf(1.0, dt * 8.0))
			want = "Walking_A"
	ch.root.position = world.to_world(p.pos.x, p.pos.y)
	if p.anim != want:
		p.anim = want
		ch.anim.play(want, 0.2)
		ch.anim.speed_scale = 0.7 if want == "Walking_A" else 1.0


# Cami kurulunca önünde semazenler döner; her seviyede bir semazen daha
func _update_dervishes(dt: float) -> void:
	var lv: int = game.buildings.mosque
	while dervishes.size() < lv:
		var ch := models.ott_char("semazen", {}, 0.32)
		add_child(ch.root)
		var s: Array = D.BUILDINGS.mosque.slot
		var i := dervishes.size()
		var base := Vector2(s[0] + 0.5 + [-0.22, 0.22, 0.0][i % 3], s[1] - 0.02 + [0.0, 0.0, -0.18][i % 3])
		ch.root.position = world.to_world(base.x, base.y)
		ch.anim.play("Idle")
		dervishes.append({"ch": ch, "spin": rng.randf() * TAU})
	for dv in dervishes:
		dv.spin += dt * 5.0
		dv.ch.root.rotation.y = dv.spin


# ---------------------------------------------------------------- atlı hükümdar

# Saray önünden çıkar, sokaklarda sekiz çizerek tur atar, yine saray önünde durup bekler.
const KING_ROUTE := [Vector2(4.5, 13.55), Vector2(5.0, 13.1), Vector2(8.0, 13.1), Vector2(8.0, 15.0), Vector2(5.0, 15.0),
	Vector2(5.0, 14.0), Vector2(4.0, 13.1), Vector2(1.0, 13.1), Vector2(1.0, 15.0), Vector2(4.0, 15.0), Vector2(4.0, 14.0)]


func set_king(country: String, level: int) -> void:
	if king:
		king.root.queue_free()
	king = models.king_rider(country, level)
	add_child(king.root)
	king.merge({"i": 0, "pos": KING_ROUTE[0], "wait": 3.0, "t": 0.0, "gait": 0.0})
	king.root.position = world.to_world(king.pos.x, king.pos.y)


func _update_king(dt: float) -> void:
	if not king:
		return
	king.t += dt
	var moving := false
	if king.wait > 0.0:
		king.wait -= dt
		king.root.rotation.y = lerp_angle(king.root.rotation.y, 0.0, minf(1.0, dt * 3.0))
	else:
		var goal: Vector2 = KING_ROUTE[(king.i + 1) % KING_ROUTE.size()]
		var d: Vector2 = goal - king.pos
		if d.length() < 0.02:
			king.i = (king.i + 1) % KING_ROUTE.size()
			if king.i == 0:
				king.wait = 6.0
		else:
			king.pos += d.normalized() * minf(d.length(), 0.32 * dt)
			king.root.rotation.y = lerp_angle(king.root.rotation.y, atan2(d.x, d.y), minf(1.0, dt * 5.0))
			moving = true
	king.gait = move_toward(king.gait, 1.0 if moving else 0.0, dt * 3.0)
	models.animate_horse(king.horse, king.t * 0.6, king.gait)
	king.root.position = world.to_world(king.pos.x, king.pos.y, absf(sin(king.t * 5.4)) * 0.012 * king.gait)
	# sancak direği elle gider ama hep dik durur; yürürken hafifçe sallanır
	var yaw: float = king.root.rotation.y
	king.pole.global_basis = Basis.from_euler(Vector3(sin(king.t * 2.7) * 0.04 * king.gait, yaw, 0))


# ---------------------------------------------------------------- işçiler

# Ocaktan kapıya, kapıdan çalışma yerine yürür; keser ya da kazar, yükü sırtında geri getirir.
func _update_workers(dt: float) -> void:
	var want: int = D.CITY.workers_per_level * game.buildings.workshop
	while workers.size() < want:
		_add_worker("wood" if workers.size() % 2 == 0 else "iron")
	while workers.size() > want:
		workers.pop_back().ch.root.queue_free()
	for w in workers:
		_step_worker(w, dt)


func _home() -> Vector2:
	var s: Array = D.BUILDINGS.workshop.slot
	return Vector2(s[0] + 0.5, game.wall_row + 1.1)


func _route_out(kind: String) -> Array:
	var gate_x: float = game.point_at(game.path_length).x
	var site: Array = D.MAP.lumber_site if kind == "wood" else D.MAP.mine_site
	var spot := Vector2(site[0] + 0.5, site[1] + 0.5) + Vector2(rng.randf_range(-0.15, 0.15), rng.randf_range(0.1, 0.3))
	return [Vector2(gate_x + rng.randf_range(-0.08, 0.08), game.wall_row + 1.1), Vector2(gate_x, game.wall_row - 0.35), spot]


func _add_worker(kind: String) -> void:
	var vest := Color("#7a5232") if kind == "wood" else Color("#4a4c52")
	var ch := models.ott_char("woodcutter" if kind == "wood" else "miner", {"Primary": vest.lightened(0.15)}, 0.36)
	# sırttaki yük (dönüşte görünür)
	var load := Node3D.new()
	# yük KayKit ölçüsünde çizilir; Blender askerinin ölçüsüne indirilir
	load.position = Vector3(0, 0.62, -0.2)
	load.scale = Vector3.ONE * 0.4
	ch.root.add_child(load)
	if kind == "wood":
		for k in 3:
			var log := models.cyl(load, 0.13, 0.13, 1.5, Vector3(-0.15 + k * 0.15, (k % 2) * 0.18, 0), models.mat(Models.WOOD), 8)
			log.rotation.z = PI / 2
	else:
		models.box(load, Vector3(0.7, 0.45, 0.5), Vector3(0, 0, 0), models.mat(Models.WOOD_DARK))
		for k in 3:
			models.sphere(load, 0.17, Vector3(-0.2 + k * 0.2, 0.28, 0), models.mat(Color("#5a4e48"), 0.55, 0.6), false, 6)
	load.visible = false
	add_child(ch.root)
	var w := {"ch": ch, "kind": kind, "pos": _home() + Vector2(rng.randf_range(-0.2, 0.2), 0.0), "route": [],
		"state": "home", "wait": rng.randf_range(0.2, 3.0), "load": load, "anim": ""}
	ch.root.position = world.to_world(w.pos.x, w.pos.y)
	workers.append(w)


func _step_worker(w: Dictionary, dt: float) -> void:
	var ch: Dictionary = w.ch
	var want := "Idle"
	if w.wait > 0.0:
		w.wait -= dt
		if w.state == "work":
			want = "1H_Melee_Attack_Chop"
		if w.wait <= 0.0:
			match w.state:
				"home":
					w.state = "out"
					w.route = _route_out(w.kind)
				"work":
					w.state = "back"
					w.load.visible = true
					var r: Array = _route_out(w.kind)
					w.route = [r[1], r[0], _home() + Vector2(rng.randf_range(-0.2, 0.2), 0.0)]
	elif w.route.size():
		var goal: Vector2 = w.route[0]
		var d: Vector2 = goal - w.pos
		var step: float = 0.5 * dt * (0.85 if w.load.visible else 1.0)
		if d.length() <= step:
			w.pos = goal
			w.route.pop_front()
		else:
			w.pos += d.normalized() * step
			ch.root.rotation.y = lerp_angle(ch.root.rotation.y, atan2(d.x, d.y), minf(1.0, dt * 8.0))
		want = "Walking_A"
	else:
		match w.state:
			"out":
				w.state = "work"
				w.wait = rng.randf_range(3.0, 4.5)
				# ağaca ya da kayaya dön
				var site: Array = D.MAP.lumber_site if w.kind == "wood" else D.MAP.mine_site
				var c: Vector2 = Vector2(site[0] + 0.5, site[1] + 0.2) - w.pos
				ch.root.rotation.y = atan2(c.x, c.y)
			"back":
				w.state = "home"
				w.wait = rng.randf_range(0.8, 1.6)
				w.load.visible = false
				game.deliver(w.kind, w.pos.x, w.pos.y)
	ch.root.position = world.to_world(w.pos.x, w.pos.y)
	if w.anim != want or (want == "1H_Melee_Attack_Chop" and not ch.anim.is_playing()):
		w.anim = want
		ch.anim.play(want, 0.2)
