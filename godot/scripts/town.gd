class_name Town
extends Node3D

# Surların içindeki hayat: sokaklarda gezen halk ve Cami önünde dönen semazenler.
# Yalnızca görüntüdür, oyun mantığına dokunmaz. Şehir büyüdükçe kalabalık artar.

const D := preload("res://scripts/data.gd")
const ROBES := ["#7a3b2e", "#2f5d7c", "#5b6b2f", "#8a6a48", "#6b2d5f", "#a0522d", "#3d4f6b", "#7c6a3a"]
const SCARVES := ["#e8e0cc", "#c8423a", "#3e6fb5", "#d9b65a", "#6a8f5a"]
const MAX_PEOPLE := 14

var models: Models
var game: Game
var world: World
var rng := RandomNumberGenerator.new()
var people: Array = []
var dervishes: Array = []
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
	return mini(MAX_PEOPLE, 2 + game.buildings.palace * 2 + built)


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


func _add_person() -> void:
	var woman := rng.randf() < 0.45
	var ch: Dictionary
	if woman:
		ch = models.character("rogue_hooded", ["Rogue_Cape"], {"Body": Color(ROBES[rng.randi() % ROBES.size()]),
			"Cape": Color(ROBES[rng.randi() % ROBES.size()]), "Head_Hooded": Color(SCARVES[rng.randi() % SCARVES.size()])}, 0.2)
	else:
		ch = models.character("mage", [], {"Body": Color(ROBES[rng.randi() % ROBES.size()]),
			"Arm": Color(ROBES[rng.randi() % ROBES.size()]), "Leg": Color("#d9cfba")}, 0.21)
		models.add_turban(ch, Color(SCARVES[rng.randi() % SCARVES.size()]))
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
		var ch := models.character("mage", [], {"Body": Color("#f6f2ea"), "Arm": Color("#f6f2ea"), "Leg": Color("#f6f2ea")}, 0.2)
		var h := models.attach(ch, "head")
		h.position = Vector3(0, 0.7, 0)
		models.cyl(h, 0.36, 0.42, 1.05, Vector3(0, 0.45, 0), models.mat(Color("#8a6a48")), 12)
		# açılan tennure eteği
		models.cyl(ch.root, 0.2, 1.1, 1.2, Vector3(0, 0.6, 0), models.mat(Color("#fbf8f0")), 16)
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
