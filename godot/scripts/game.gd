class_name Game
extends RefCounted

# Oyun mantığı: tarayıcı sürümündeki src/systems ile aynı kurallar. Görüntüden bağımsızdır;
# konumlar kare biriminde 2D (x sütun, y satır). Ses ve efektler `events` kuyruğuna yazılır,
# çizim katmanı her karede okuyup boşaltır.

const D := preload("res://scripts/data.gd")

var cols: int = D.MAP.cols
var rows: int = D.MAP.rows
var wall_row: int = D.MAP.wall_row

var path_points: Array[Vector2] = []
var path_segs: Array = []  # {a, dir, len, start}
var path_length := 0.0
var path_tiles := {}

var gold: int
var res := {}  # odun, demir, yemek
var wall: int
var max_wall: int
var wave := 0
var total_waves: int = D.WAVES.size()
var phase := "build"  # build | wave | won | lost
var raid := false
var raid_timer := 0.0
var nation := "byzantium"
# oyuncunun devleti ve hükümdarının seviyesi (menüde seçilir, reset'ten önce atanır)
var country := "ottoman"
var king_level := 1
var speed := 1
# sefer haritasındaki kuşatma ("" = serbest savaş: klasik yol ve 12 dalga)
var stage_id := ""
var stage := {}
# kahraman komutan ("" = yok): ölürse hero_timer sonra yeniden çıkar; yeteneği hero_cd bekler
var hero_id := ""
var hero_timer := 0.0
var hero_cd := 0.0
var fortify := 0.0  # Sur Onarımı: surlar hasar almaz
var morale := 0.0  # Moral: hasar artar, askerler iyileşir
var strikes: Array = []  # Top Yağmuru: düşmekte olan gülleler {x, y, t}
# mevsim ve hava: sıradaki dalganın havası dalga bitince seçilir, oyuncu önceden görür
var season := "spring"
var weather := "clear"
# Medrese araştırmaları: biten araştırmalar ve sürmekte olan {id, time}
var research := {}
var researching := {}
var buildings := {}
var towers: Array = []
var enemies: Array = []
var units: Array = []
var training := {}
var projectiles: Array = []
var spawn_queue: Array = []
var spawn_timer := 0.0
var charge := {"active": 0.0, "cooldown": 0.0, "level": 0}
var selected = null  # {c, r} ya da {c, r, building}
var time := 0.0
var market_timer := 0.0
var next_id := 1
var events: Array = []


func _init() -> void:
	_build_path(D.MAP.path)
	reset()


# Kuşatmayı seçer: yolu ve dalga sayısını değiştirir. reset'ten önce çağrılır.
func set_stage(id: String) -> void:
	stage_id = id if D.STAGES.has(id) else ""
	stage = D.STAGES[stage_id] if stage_id != "" else {}
	_build_path(stage.get("path", D.MAP.path))
	total_waves = stage.picks.size() if stage_id != "" else D.WAVES.size()


# Zeminin nasıl kurulacağı: yol ve kuşatmanın zemin renkleri (değişirse dünya yeniden kurulur)
func map_key() -> String:
	return str(path_points) + str(stage.get("ground", {}))


# i. dalgayı (0'dan) gönderen devlet; oyuncunun kendi devleti çıkarsa o seferi Osmanlı yapar
func wave_nation(i: int) -> String:
	if stage_id == "":
		return D.wave_nation(i, country)
	var n: String = stage.nations[mini(i, stage.nations.size() - 1)]
	return "ottoman" if n == country else n


func wave_groups(i: int) -> Array:
	return D.WAVES[stage.picks[i] if stage_id != "" else i].groups


# n. dalgada (1'den) düşman canı çarpanı
func difficulty(n: int) -> float:
	return D.difficulty(n) * stage.get("hp", 1.0)


func describe_wave(i: int) -> String:
	if i >= total_waves:
		return ""
	var items := []
	for g in wave_groups(i):
		items.append("%d %s" % [D.group_count(g[1], i + 1), D.ENEMY_NAMES[g[0]]])
	var k := difficulty(i + 1)
	var hard := " Düşman canı ×%s." % D.num(k) if absf(k - 1.0) > 0.01 else ""
	return "Sıradaki sefer: %s — %s.%s" % [D.NATION_NAMES[wave_nation(i)], D.join_list(items), hard]


func reset() -> void:
	gold = D.RULES.start_gold + stage.get("gold", 0) + (D.KING.start_gold * king_level if king_bonus_kind() == "gold" else 0)
	res = D.RULES.start_res.duplicate()
	wall = D.RULES.start_wall + int(king_bonus("wall"))
	max_wall = wall
	wave = 0
	phase = "build"
	raid = false
	nation = wave_nation(0)
	speed = 1
	buildings = {}
	for id in D.BUILDINGS:
		buildings[id] = D.BUILDINGS[id].get("start", 0)
	towers = []
	enemies = []
	units = []
	training = {}
	projectiles = []
	spawn_queue = []
	spawn_timer = 0.0
	charge = {"active": 0.0, "cooldown": 0.0, "level": 0}
	hero_timer = 0.5
	hero_cd = 0.0
	fortify = 0.0
	morale = 0.0
	strikes = []
	_roll_weather(0)
	research = {}
	researching = {}
	selected = null
	time = 0.0
	market_timer = 0.0
	events = []
	_reset_raid_timer()


# ---------------------------------------------------------------- yol

func _build_path(pts: Array) -> void:
	path_points = []
	path_segs = []
	path_length = 0.0
	path_tiles = {}
	for p in pts:
		path_points.append(Vector2(p[0] + 0.5, p[1] + 0.5))
	for i in path_points.size() - 1:
		var a := path_points[i]
		var b := path_points[i + 1]
		var l := a.distance_to(b)
		path_segs.append({"a": a, "dir": (b - a) / l, "len": l, "start": path_length})
		path_length += l
	for i in pts.size() - 1:
		var c0: int = pts[i][0]
		var r0: int = pts[i][1]
		var c1: int = pts[i + 1][0]
		var r1: int = pts[i + 1][1]
		var steps: int = max(abs(c1 - c0), abs(r1 - r0))
		for k in steps + 1:
			var c := c0 + signi(c1 - c0) * k
			var r := r0 + signi(r1 - r0) * k
			if c >= 0 and r >= 0 and c < cols and r < rows:
				path_tiles[Vector2i(c, r)] = true


# Yol üzerindeki d mesafesindeki nokta; z bileşeni yön açısı.
func point_at(d: float) -> Vector3:
	var seg: Dictionary = path_segs[-1]
	for s in path_segs:
		if d < s.start + s.len:
			seg = s
			break
	var t := clampf(d - seg.start, 0.0, seg.len)
	var p: Vector2 = seg.a + seg.dir * t
	return Vector3(p.x, p.y, seg.dir.angle())


func is_path_tile(c: int, r: int) -> bool:
	return path_tiles.has(Vector2i(c, r))


# Çarşı oyun sürdükçe akçe getirir
func _update_market(dt: float) -> void:
	var lv: int = buildings.market
	if lv <= 0:
		return
	market_timer += dt
	if market_timer >= D.CITY.market_interval:
		market_timer -= D.CITY.market_interval
		var n: int = roundi(D.CITY.market_gold * lv * (1.0 + (D.TECH_FX.market if has_tech("trade1") else 0.0)))
		gold += n
		var s: Array = D.BUILDINGS.market.slot
		text(s[0] + 0.5, s[1] + 0.1, "+%d akçe" % n, "#f2c94c")


func reward(e: Dictionary) -> int:
	return roundi(e.def.reward * D.RULES.reward_mult * (1.0 + king_bonus("gold") + (D.TECH_FX.reward if has_tech("trade2") else 0.0)))


# ---------------------------------------------------------------- hükümdar

func king_bonus_kind() -> String:
	return D.COUNTRIES[country].bonus


# devletin üstünlüğü bu türdeyse seviyeye göre artış, değilse 0
func king_bonus(kind: String) -> float:
	if king_bonus_kind() != kind:
		return 0.0
	return D.KING.per_level[kind] * king_level


func is_work_site(c: int, r: int) -> bool:
	var a: Array = D.MAP.lumber_site
	var b: Array = D.MAP.mine_site
	return (c == a[0] and r == a[1]) or (c == b[0] and r == b[1])


# İşçinin getirdiği yük (görüntü tarafı çağırır)
func deliver(kind: String, x: float, y: float) -> void:
	if not is_active():
		return
	var n: int = D.CITY.wood_load if kind == "wood" else D.CITY.iron_load
	res[kind] += n
	text(x, y - 0.3, "+%d %s" % [n, D.RES_NAMES[kind]], "#d39a5e" if kind == "wood" else "#b9c3cf")


func in_grid(c: int, r: int) -> bool:
	return c >= 0 and r >= 0 and c < cols and r < rows


func tower_at(c: int, r: int):
	for t in towers:
		if t.c == c and t.r == r:
			return t
	return null


func building_at(c: int, r: int):
	for id in D.BUILDINGS:
		var s: Array = D.BUILDINGS[id].slot
		if s[0] == c and s[1] == r:
			return id
	return null


func is_active() -> bool:
	return phase == "build" or phase == "wave"


# ---------------------------------------------------------------- olaylar

func sound(id: String, extra := {}) -> void:
	var e := {"kind": "sound", "id": id}
	e.merge(extra)
	events.append(e)


func particles(x: float, y: float, color: String, count: int, spd := 2.0, size := 0.06, life := 0.5) -> void:
	events.append({"kind": "particles", "x": x, "y": y, "color": color, "count": count, "speed": spd, "size": size, "life": life})


func ring(x: float, y: float, radius: float, color: String) -> void:
	events.append({"kind": "ring", "x": x, "y": y, "radius": radius, "color": color})


func text(x: float, y: float, s: String, color: String) -> void:
	events.append({"kind": "text", "x": x, "y": y, "text": s, "color": color})


func banner(s: String, color: String, life := 2.2) -> void:
	events.append({"kind": "banner", "text": s, "color": color, "life": life})


# ---------------------------------------------------------------- seçim ve eylemler

func select_tile(c: int, r: int) -> void:
	if selected != null and selected.c == c and selected.r == r:
		selected = null
		return
	if not in_grid(c, r) or is_path_tile(c, r) or is_work_site(c, r):
		selected = null
		return
	if r >= wall_row:
		var b = building_at(c, r)
		selected = {"c": c, "r": r, "building": b} if b != null else null
		return
	selected = {"c": c, "r": r}


func selected_tower():
	if selected == null or selected.has("building"):
		return null
	return tower_at(selected.c, selected.r)


func is_tower_unlocked(type: String) -> bool:
	var req = D.TOWERS[type].get("unlock")
	return req == null or buildings[req] >= 1


func can_build(type: String) -> bool:
	return selected != null and not selected.has("building") and tower_at(selected.c, selected.r) == null \
		and is_tower_unlocked(type) and gold >= D.TOWERS[type].cost and is_active()


func build_tower(type: String) -> void:
	if not can_build(type):
		return
	var cost: int = D.TOWERS[type].cost
	gold -= cost
	towers.append({"id": _id(), "type": type, "c": selected.c, "r": selected.r, "x": selected.c + 0.5, "y": selected.r + 0.5,
		"level": 1, "spent": cost, "cooldown": 0.0, "angle": -PI / 2, "recoil": 0.0})
	sound("build")


func upgrade_discount() -> float:
	return D.CITY.school_discount * buildings.school + (D.TECH_FX.discount if has_tech("arch2") else 0.0)


func tower_upgrade_cost(t: Dictionary) -> int:
	return D.upgrade_cost(t.type, t.level, upgrade_discount())


func can_upgrade_tower(t) -> bool:
	return t != null and is_active() and t.level < D.UPGRADE.max_level and gold >= tower_upgrade_cost(t)


func upgrade_tower() -> void:
	var t = selected_tower()
	if not can_upgrade_tower(t):
		return
	var cost := tower_upgrade_cost(t)
	gold -= cost
	t.spent += cost
	t.level += 1
	sound("build")


func sell_tower() -> void:
	var t = selected_tower()
	if t == null or not is_active():
		return
	gold += D.sell_value(t.spent)
	towers.erase(t)
	selected = null
	sound("sell")


func tower_bonus(type: String) -> Dictionary:
	var b := buildings
	var out := {}
	match type:
		"archer":
			out = {"damage": D.CITY.archery_damage * b.archery, "range": D.CITY.archery_range * b.archery}
		"cannon":
			out = {"damage": D.CITY.science_cannon * b.science}
		"tar":
			out = {"slow": D.CITY.science_tar * b.science}
	out.damage = out.get("damage", 0.0) + king_bonus("tower_damage")
	out.range = out.get("range", 0.0) + king_bonus("range")
	var gun := type == "cannon" or type == "musket"
	if gun and has_tech("powder1"):
		out.damage += D.TECH_FX.powder_damage
	if gun and has_tech("powder3"):
		out.range += D.TECH_FX.powder_range
	if has_tech("arch3"):
		out.damage += D.TECH_FX.arch_damage
	return out


func tower_stats(t: Dictionary) -> Dictionary:
	var s := D.tower_stats(t.type, t.level, tower_bonus(t.type))
	s.rate /= 1.0 + king_bonus("rate")
	s.damage = roundi(s.damage * morale_mult())
	if t.type == "cannon" and has_tech("powder2"):
		s.splash *= 1.0 + D.TECH_FX.powder_splash
	var w := wx()
	s.range *= 1.0 - w.range
	s.rate *= 1.0 + w.rate + (w.musket if t.type == "musket" or t.type == "cannon" else 0.0)
	return s


# ---------------------------------------------------------------- hava

func season_of(i: int) -> String:
	if stage_id != "":
		return stage.get("season", "summer")
	return D.SEASON_ORDER[(i / D.SEASON_WAVES) % D.SEASON_ORDER.size()]


# i. dalganın (0'dan) mevsimini ve havasını seçer; ilk dalga hep açık havada başlar
func _roll_weather(i: int) -> void:
	season = season_of(i)
	if i == 0:
		weather = "snow" if season == "winter" else "clear"
		return
	var w: Dictionary = D.SEASONS[season].weather
	var total := 0
	for k in w:
		total += w[k]
	var r := randi() % total
	for k in w:
		r -= w[k]
		if r < 0:
			weather = k
			return


func wx() -> Dictionary:
	return D.WEATHER[weather]


func morale_mult() -> float:
	return 1.0 + D.HERO.morale if morale > 0.0 else 1.0


# ---------------------------------------------------------------- kahraman

func hero_def() -> Dictionary:
	return D.HEROES.get(hero_id, {})


func hero_unit():
	for u in units:
		if u.kind == "hero":
			return u
	return null


func can_hero() -> bool:
	return hero_id != "" and hero_cd <= 0.0 and phase == "wave" and hero_unit() != null


func use_hero() -> void:
	if not can_hero():
		return
	var h: Dictionary = hero_unit()
	hero_cd = hero_def().cooldown
	banner("%s!" % hero_def().ability, hero_def().ring, 2.0)
	text(h.x, h.y - 0.5, hero_def().name, hero_def().ring)
	match hero_id:
		"barbaros":
			var front := enemies.filter(func(e): return not e.dead and e.y < wall_row)
			front.sort_custom(func(a, b): return a.dist > b.dist)
			var n: int = D.HERO.barrage_count
			for i in n:
				var x: float
				var y: float
				if front.size():
					var e: Dictionary = front[i % front.size()]
					# aynı düşmana düşen ikinci gülle biraz ilerisine
					var ahead := point_at(e.dist + e.speed * (D.HERO.barrage_fall + i * D.HERO.barrage_gap))
					x = ahead.x
					y = ahead.y
				else:
					var p := point_at(path_length * randf_range(0.3, 0.9))
					x = p.x
					y = p.y
				var t: float = D.HERO.barrage_fall + i * D.HERO.barrage_gap
				strikes.append({"x": x, "y": y, "t": t})
				events.append({"kind": "fall", "x": x, "y": y, "time": t})
			sound("horn")
		"sinan":
			var n: int = mini(D.HERO.repair, max_wall - wall)
			wall += n
			fortify = D.HERO.fortify
			var g := point_at(path_length)
			text(g.x, g.y - 0.2, "Sur +%d" % n if n > 0 else "Surlar tahkim edildi", "#e0c070")
			particles(g.x, g.y + 0.3, "#e8d6a8", 24, 1.6, 0.06, 0.8)
			sound("build")
		"evliya":
			morale = D.HERO.morale_time
			for u in units:
				particles(u.x, u.y - 0.2, "#6fc0e0", 5, 0.8, 0.05, 0.6)
			sound("chant", {"voices": 10, "loud": 1})
	ring(h.x, h.y, 1.2, hero_def().ring)


func _update_hero(dt: float) -> void:
	if hero_cd > 0.0:
		hero_cd = maxf(0.0, hero_cd - dt)
	if fortify > 0.0:
		fortify = maxf(0.0, fortify - dt)
	if morale > 0.0:
		morale = maxf(0.0, morale - dt)
	if hero_id != "" and hero_unit() == null:
		hero_timer -= dt
		if hero_timer <= 0.0:
			_spawn_unit("hero")
			var g := point_at(path_length)
			text(g.x, g.y + 0.3, hero_def().name, hero_def().ring)
	for s in strikes:
		s.t -= dt
		if s.t <= 0.0:
			var dmg: float = D.HERO.barrage_damage * difficulty(maxi(1, wave))
			for e in enemies:
				if not e.dead and Vector2(e.x - s.x, e.y - s.y).length() <= D.HERO.barrage_splash:
					damage_enemy(e, dmg, true)
			ring(s.x, s.y, D.HERO.barrage_splash, "#ffb347")
			particles(s.x, s.y, "#cbb48a", 16, 2.8, 0.07, 0.5)
			particles(s.x, s.y, "#ffb347", 8, 2.0, 0.05, 0.3)
			events.append({"kind": "shake", "time": 0.12})
			events.append({"kind": "blast", "x": s.x, "y": s.y})
			sound("boom")
	strikes = strikes.filter(func(s): return s.t > 0.0)


# ---------------------------------------------------------------- şehir

func level_cap(id: String) -> int:
	return D.MAX_BUILDING_LEVEL if id == "palace" else mini(D.MAX_BUILDING_LEVEL, buildings.palace + D.FREE_LEVELS)


# ---------------------------------------------------------------- kaynaklar

func has_res(cost: Dictionary) -> bool:
	for k in cost:
		if res.get(k, 0) < cost[k]:
			return false
	return true


func pay_res(cost: Dictionary) -> void:
	for k in cost:
		res[k] -= cost[k]


# Eksik kaynakların adları ("odun, demir"), yeterse boş
func missing_res(cost: Dictionary) -> String:
	var miss := []
	for k in D.RES_ORDER:
		if cost.has(k) and res[k] < cost[k]:
			miss.append(D.RES_NAMES[k])
	return ", ".join(miss)


func building_res(id: String) -> Dictionary:
	if id != "palace":
		return {}
	var next: int = buildings.palace + 1
	return D.PALACE_RES[next] if next < D.PALACE_RES.size() else {}


# Kurulamıyorsa nedeni, kurulabiliyorsa boş sözlük (para ayrıca bakılır)
func building_block(id: String) -> Dictionary:
	var def: Dictionary = D.BUILDINGS[id]
	var level: int = buildings[id]
	if level >= D.MAX_BUILDING_LEVEL:
		return {"kind": "max"}
	var req: Dictionary = def.get("requires", {}).duplicate()
	if level >= 1:
		req.merge(def.get("up_requires", {}))
	for r in req:
		if buildings[r] < req[r]:
			return {"kind": "requires", "building": r, "level": req[r]}
	if level + 1 > level_cap(id):
		return {"kind": "palace", "level": level + 1}
	return {}


func building_cost(id: String) -> int:
	var costs: Array = D.BUILDINGS[id].costs
	var l: int = buildings[id]
	var c: int = costs[l] if l < costs.size() else 0
	return roundi(c * (1.0 - D.TECH_FX.discount)) if has_tech("arch2") else c


# ---------------------------------------------------------------- Medrese

func has_tech(id: String) -> bool:
	return research.has(id)


# Araştırılamıyorsa nedeni, araştırılabiliyorsa "" (para ayrıca bakılır)
func tech_block(id: String) -> String:
	var t: Dictionary = D.TECH[id]
	if has_tech(id):
		return "done"
	if researching.get("id", "") == id:
		return "running"
	if buildings.medrese < t.tier:
		return "medrese"
	if t.tier > 1 and not has_tech(D.tech_of(t.branch, t.tier - 1)):
		return "prev"
	if not researching.is_empty():
		return "busy"
	return ""


func can_research(id: String) -> bool:
	return is_active() and tech_block(id) == "" and gold >= D.TECH[id].cost


func start_research(id: String) -> bool:
	if not can_research(id):
		return false
	gold -= D.TECH[id].cost
	researching = {"id": id, "time": D.TECH[id].time}
	sound("build")
	return true


func _update_research(dt: float) -> void:
	if researching.is_empty():
		return
	researching.time -= dt
	if researching.time > 0.0:
		return
	var id: String = researching.id
	researching = {}
	research[id] = true
	if id == "arch1":
		max_wall += D.TECH_FX.wall
		wall += D.TECH_FX.wall
	var s: Array = D.BUILDINGS.medrese.slot
	text(s[0] + 0.5, s[1], D.TECH[id].name, "#9fd0f0")
	banner("%s tamamlandı" % D.TECH[id].name, "#9fd0f0", 1.8)
	sound("victory")


func can_upgrade_building(id: String) -> bool:
	return is_active() and building_block(id).is_empty() and gold >= building_cost(id) and has_res(building_res(id))


func upgrade_building(id: String) -> bool:
	if not can_upgrade_building(id):
		return false
	var s: Array = D.BUILDINGS[id].slot
	gold -= building_cost(id)
	pay_res(building_res(id))
	buildings[id] += 1
	particles(s[0] + 0.5, s[1] + 0.5, "#e8d6a8", 14, 1.6, 0.05, 0.5)
	text(s[0] + 0.5, s[1], "Seviye %d" % buildings[id], "#f2c94c")
	sound("build")
	if id == "religion":
		charge.level = buildings.religion
	if buildings[id] == 1:
		for t in D.TOWERS:
			if D.TOWERS[t].get("unlock") == id:
				banner("%s açıldı!" % D.TOWER_NAMES[t][0], "#f2c94c")
	return true


func rate_boost() -> float:
	return 1.0 + D.CHARGE.boost[charge.level] if charge.active > 0.0 else 1.0


func can_charge() -> bool:
	return charge.level > 0 and charge.cooldown <= 0.0 and phase == "wave"


func trigger_charge() -> void:
	if not can_charge():
		return
	var lv: int = charge.level
	charge.active = float(D.CHARGE.duration[lv])
	charge.cooldown = float(D.CHARGE.cooldown[lv])
	banner("Allah Allah! Hücum!", "#f2c94c", 2.2)
	sound("chant", {"voices": 14, "loud": 1})


# ---------------------------------------------------------------- dalgalar

func start_wave() -> void:
	if phase != "build" or wave >= total_waves:
		return
	wave += 1
	phase = "wave"
	raid = false
	nation = wave_nation(wave - 1)
	spawn_queue = []
	for g in wave_groups(wave - 1):
		for i in D.group_count(g[1], wave):
			spawn_queue.append({"type": g[0], "gap": g[2], "nation": nation})
	spawn_timer = D.RULES.first_spawn_delay + 1.2
	banner("%s seferde!" % D.NATION_NAMES[nation], "#f3e6c8", 2.4)
	sound("waveStart")
	sound("chant", {"voices": 12 if units.size() else 8, "delay": 0.9})


func _spawn_enemy(type: String, nat: String) -> void:
	var def: Dictionary = D.ENEMIES[type]
	var hp := roundi(def.hp * difficulty(wave))
	var spd: float = def.speed * (1.0 + D.RULES.speed_growth * max(0, wave - 1))
	var p := point_at(0.0)
	enemies.append({"id": _id(), "def": def, "type": type, "nation": nat, "hp": float(hp), "max_hp": float(hp),
		"speed": spd, "armor": def.armor, "radius": def.radius, "dist": 0.0, "x": p.x, "y": p.y, "angle": p.z,
		"slow": 0.0, "slow_time": 0.0, "flash": 0.0, "dead": false, "blocker": null, "attack_cd": 0.3, "swing": 0.0})
	if def.get("warning", false):
		banner(D.WARNINGS[type], "#ff5b4d")
		sound("horn")


func _update_spawner(dt: float) -> void:
	if phase != "wave":
		return
	spawn_timer -= dt
	while spawn_queue.size() and spawn_timer <= 0.0:
		var n: Dictionary = spawn_queue.pop_front()
		_spawn_enemy(n.type, n.nation)
		spawn_timer += n.gap


func _check_wave_end() -> bool:
	if phase != "wave" or spawn_queue.size() or enemies.size():
		return false
	if raid:
		raid = false
		phase = "build"
		gold += D.RAID.bonus
		nation = wave_nation(wave)
		_reset_raid_timer()
		banner("Baskın püskürtüldü  +%d" % D.RAID.bonus, "#f2c94c")
		return false
	if wave >= total_waves:
		phase = "won"
		sound("chant", {"voices": 16, "loud": 1})
		return true
	var bonus := roundi(D.wave_bonus(wave) * (1.0 + (D.TECH_FX.wave_bonus if has_tech("trade3") else 0.0)))
	var income := city_income()
	gold += bonus + income.tax + income.endowment + income.palace_tax
	wall = mini(max_wall, wall + income.repair)
	for k in D.RES_ORDER:
		res[k] += income[k]
	phase = "build"
	nation = wave_nation(wave)
	charge.active = 0.0
	_roll_weather(wave)
	_reset_raid_timer()
	banner("%d. sefer püskürtüldü  +%d" % [wave, bonus + income.tax + income.endowment + income.palace_tax], "#f2c94c")
	sound("victory")
	return true


func city_income() -> Dictionary:
	var out := {"tax": D.CITY.court_tax * buildings.court, "endowment": D.CITY.mosque_endowment * buildings.mosque,
		"repair": D.CITY.hospital_repair * buildings.hospital + (ceili(king_level / 2.0) if king_bonus_kind() == "wall" else 0), "palace_tax": D.CITY.palace_tax * buildings.palace,
		"wood": D.CITY.palace_wood * buildings.palace, "iron": D.CITY.palace_iron * buildings.palace,
		"food": D.CITY.kitchen_food * buildings.kitchen}
	if has_tech("arch3"):
		out.repair += D.TECH_FX.arch_repair
	if has_tech("trade3"):
		out.wood += D.TECH_FX.wood
		out.iron += D.TECH_FX.iron
	return out


func _reset_raid_timer() -> void:
	var court: int = buildings.get("court", 0)
	var base := randf_range(D.RAID.min_delay, D.RAID.max_delay)
	raid_timer = base * (1.0 + D.CITY.court_raid_delay * court)


func _update_raid(dt: float) -> void:
	if phase != "build" or wave < D.RAID.first_wave or wave >= total_waves:
		return
	raid_timer -= dt
	if raid_timer > 0.0:
		return
	var nat := wave_nation(wave)
	var count := roundi(D.RAID.base_count + wave * D.RAID.count_per_wave)
	phase = "wave"
	raid = true
	nation = nat
	spawn_queue = []
	for i in count:
		spawn_queue.append({"type": D.RAID.unit, "gap": D.RAID.gap, "nation": nat})
	spawn_timer = 0.6
	banner("Ani baskın! %s akıncıları" % D.NATION_NAMES[nat], "#ff5b4d", 2.6)
	sound("horn")


# ---------------------------------------------------------------- hareket

func _update_movement(dt: float) -> void:
	for e in enemies:
		if e.dead:
			continue
		if e.flash > 0.0:
			e.flash -= dt
		if e.slow_time > 0.0:
			e.slow_time -= dt
			if e.slow_time <= 0.0:
				e.slow = 0.0
		if e.blocker == null:
			var nxt: float = e.dist + e.speed * (1.0 - e.slow) * (1.0 - wx().slow) * dt
			var b = _find_blocker(e, nxt)
			if b != null:
				e.blocker = b
				b.engaged += 1
				e.dist = maxf(e.dist, b.post - D.ARMY.block_gap)
			else:
				e.dist = nxt
		var p := point_at(e.dist)
		e.x = p.x
		e.y = p.y
		e.angle = p.z
		if e.dist >= path_length:
			e.dead = true
			e.breached = true
			if fortify > 0.0:
				text(e.x, e.y - 0.4, "Sur sağlam!", "#e0c070")
			else:
				wall = maxi(0, wall - e.def.damage)
			events.append({"kind": "shake", "time": D.RULES.shake_time})
			sound("wallHit")
			if wall <= 0:
				phase = "lost"
				sound("defeat")


# ---------------------------------------------------------------- savaş

func _find_target(t: Dictionary, rng: float):
	var best = null
	for e in enemies:
		if e.dead or e.y >= wall_row:
			continue
		var dx: float = e.x - t.x
		var dy: float = e.y - t.y
		if dx * dx + dy * dy <= rng * rng and (best == null or e.dist > best.dist):
			best = e
	return best


func damage_enemy(e: Dictionary, amount: float, pierce: bool) -> void:
	if e.dead:
		return
	var dmg := amount if pierce else maxf(1.0, amount - e.armor)
	e.hp -= dmg
	e.flash = D.RULES.hit_flash
	if e.hp <= 0.0:
		e.dead = true
		gold += reward(e)
		var color: String = "#a0703c" if e.def.get("siege", false) else D.NATIONS[e.nation].primary
		var big: bool = e.def.get("warning", false)
		particles(e.x, e.y, color, 36 if big else 10, 2.2, e.radius * 0.28, 0.6)
		particles(e.x, e.y, "#e8dcc0", 20 if big else 6, 1.4, e.radius * 0.35, 0.7)
		text(e.x, e.y - e.radius, "+%d" % reward(e), "#f2c94c")
		sound("crash" if e.def.get("siege", false) else "fall")


func _fire(t: Dictionary, target: Dictionary, s: Dictionary) -> void:
	if s.speed <= 0.0:
		damage_enemy(target, s.damage, s.pierce)
		events.append({"kind": "musket", "x0": t.x, "y0": t.y, "x1": target.x, "y1": target.y})
		particles(target.x, target.y, "#e8dcc0", 4, 1.2, 0.04, 0.25)
		sound("musket")
		return
	sound(t.type)
	projectiles.append({"id": _id(), "type": t.type, "x": t.x + cos(t.angle) * D.RULES.muzzle_offset,
		"y": t.y + sin(t.angle) * D.RULES.muzzle_offset, "tx": target.x, "ty": target.y, "target": target,
		"speed": s.speed, "damage": float(s.damage), "splash": s.splash, "slow": s.slow, "slow_time": s.slow_time,
		"pierce": s.pierce, "done": false, "from": "tower"})


func _hit(p: Dictionary) -> void:
	if p.get("splash", 0.0) > 0.0:
		for e in enemies:
			if not e.dead and Vector2(e.x - p.x, e.y - p.y).length() <= p.splash:
				damage_enemy(e, p.damage, p.pierce)
		ring(p.x, p.y, p.splash, "#e8cf9a")
		particles(p.x, p.y, "#cbb48a", 12, 2.5, 0.06, 0.45)
		particles(p.x, p.y, "#ffb347", 5, 1.8, 0.04, 0.25)
		sound("boom")
		return
	var e: Dictionary = p.target
	if e.dead:
		return
	damage_enemy(e, p.damage, p.get("pierce", false))
	if p.get("slow", 0.0) > 0.0:
		e.slow = maxf(e.slow, p.slow)
		e.slow_time = p.slow_time
		e.tarred = 1.2
		particles(e.x, e.y, "#2a2230", 4, 0.9, 0.05, 0.4)
	else:
		particles(p.x, p.y, "#d9c79c", 3, 1.2, 0.035, 0.2)


func _update_towers(dt: float) -> void:
	for t in towers:
		var s := tower_stats(t)
		t.cooldown -= dt
		var target = _find_target(t, s.range)
		if target != null:
			t.angle = atan2(target.y - t.y, target.x - t.x)
		if t.cooldown <= 0.0:
			if target != null:
				_fire(t, target, s)
				t.cooldown = s.rate / rate_boost()
				t.recoil = 1.0
			else:
				t.cooldown = 0.0
		if t.recoil > 0.0:
			t.recoil = maxf(0.0, t.recoil - dt * 8.0)


func _update_projectiles(dt: float) -> void:
	for p in projectiles:
		var tgt: Dictionary = p.target
		if not tgt.dead:
			p.tx = tgt.x
			p.ty = tgt.y
		var dx: float = p.tx - p.x
		var dy: float = p.ty - p.y
		var dist := sqrt(dx * dx + dy * dy)
		var step: float = p.speed * dt
		if dist <= step:
			p.x = p.tx
			p.y = p.ty
			p.done = true
			_hit(p)
		else:
			p.x += dx / dist * step
			p.y += dy / dist * step
	projectiles = projectiles.filter(func(p): return not p.done)


# ---------------------------------------------------------------- askerler

func troop_cap(kind: String) -> int:
	var d: Dictionary = D.TROOPS[kind]
	return d.per_level * buildings.get(d.building, 0)


func troop_count(kind: String) -> int:
	var n := 0
	for u in units:
		if u.kind == kind:
			n += 1
	return n


func training_of(kind: String) -> Dictionary:
	if not training.has(kind):
		training[kind] = {"queue": 0, "time": 0.0}
	return training[kind]


func unit_def(kind: String) -> Dictionary:
	return hero_def() if kind == "hero" else D.TROOPS[kind]


func troop_stats(kind: String) -> Dictionary:
	var d := unit_def(kind)
	var lv: int = 1 if kind == "hero" else max(1, buildings.get(d.building, 0))
	var k: float = (1.0 + D.ARMY.level_bonus * (lv - 1)) * (1.0 + king_bonus("troops"))
	return {"hp": float(roundi(d.hp * k)), "damage": d.damage * k * morale_mult()}


func can_train(kind: String) -> bool:
	var t := training_of(kind)
	return is_active() and troop_count(kind) + t.queue < troop_cap(kind) and gold >= D.TROOPS[kind].cost and has_res(D.TROOPS[kind].res)


func train_troop(kind: String) -> bool:
	if not can_train(kind):
		return false
	gold -= D.TROOPS[kind].cost
	pay_res(D.TROOPS[kind].res)
	training_of(kind).queue += 1
	sound("build")
	return true


func troop_of(building: String):
	for k in D.TROOP_ORDER:
		if D.TROOPS[k].building == building:
			return k
	return null


func _spawn_unit(kind: String) -> void:
	var gate := point_at(path_length)
	var hp: float = troop_stats(kind).hp
	units.append({"id": _id(), "kind": kind, "def": unit_def(kind), "hp": hp, "max_hp": hp, "x": gate.x, "y": gate.y + 0.6,
		"tx": gate.x, "ty": gate.y, "post": path_length, "ready": false, "engaged": 0, "cooldown": 0.0, "swing": 0.0,
		"angle": -PI / 2, "moving": false, "dead": false, "flash": 0.0, "healing": false})
	sound("chant", {"voices": 4})


func _assign_posts() -> void:
	var melee := units.filter(func(u): return u.def.role == "melee" and not u.healing)
	# kapıya en yakın sırada Sofiler (arkadan can verir), en önde Yeniçeriler
	var order := {"sufi": 0, "sipahi": 1, "janissary": 2, "hero": 3}
	melee.sort_custom(func(a, b):
		if a.kind == b.kind:
			return a.id < b.id
		return order.get(a.kind, 1) < order.get(b.kind, 1))
	for i in melee.size():
		var u: Dictionary = melee[i]
		var row := i / 2
		var side := 1.0 if i % 2 else -1.0
		var post: float = path_length - D.ARMY.first_post - row * D.ARMY.post_spacing
		if u.engaged and u.ready:
			continue
		var p := point_at(post)
		_set_target(u, p.x - sin(p.z) * D.ARMY.post_side * side, p.y + cos(p.z) * D.ARMY.post_side * side)
		u.post = post
	var spots: Array = D.MAP.archer_posts
	var i := 0
	for u in units:
		if u.def.role == "ranged" and not u.healing:
			var s: Array = spots[i % spots.size()]
			_set_target(u, s[0], s[1])
			i += 1


func _set_target(u: Dictionary, x: float, y: float) -> void:
	if absf(u.tx - x) > 1e-3 or absf(u.ty - y) > 1e-3:
		u.ready = false
	u.tx = x
	u.ty = y


func _walk(u: Dictionary, dt: float) -> void:
	var gate_x: float = point_at(path_length).x
	var tx: float = u.tx
	var ty: float = u.ty
	# surların içi ile dışı arasında yalnızca kapıdan geçilir
	var out_y: float = wall_row - 0.35
	var in_y: float = wall_row + 1.1
	var u_in: bool = u.y > wall_row + 0.5
	var t_in: bool = ty > wall_row + 0.5
	if u_in and not t_in:
		tx = gate_x
		ty = in_y if absf(u.x - gate_x) > 0.08 else out_y
	elif t_in and not u_in:
		tx = gate_x
		ty = out_y if absf(u.x - gate_x) > 0.08 or u.y < out_y - 0.05 else in_y
	var dx: float = tx - u.x
	var dy: float = ty - u.y
	var d := sqrt(dx * dx + dy * dy)
	var step: float = u.def.speed * (1.0 - wx().troop_slow) * dt
	if d <= step:
		u.x = tx
		u.y = ty
		if tx == u.tx and ty == u.ty:
			u.ready = true
			u.moving = false
			return
	else:
		u.x += dx / d * step
		u.y += dy / d * step
	u.moving = true
	u.angle = atan2(dy, dx)


func _enemy_in_range(u: Dictionary, rng: float):
	var best = null
	var best_score := -INF
	for e in enemies:
		if e.dead or e.y >= wall_row:
			continue
		var d := Vector2(e.x - u.x, e.y - u.y).length()
		if d > rng + e.radius:
			continue
		var score: float = (1000.0 if e.blocker == u else 0.0) + e.dist
		if score > best_score:
			best = e
			best_score = score
	return best


func _attack(u: Dictionary, dt: float) -> void:
	u.cooldown -= dt
	var target = _enemy_in_range(u, u.def.range)
	if target == null:
		return
	u.angle = atan2(target.y - u.y, target.x - u.x)
	if u.cooldown > 0.0:
		return
	var dmg: float = troop_stats(u.kind).damage
	u.cooldown = u.def.rate / rate_boost()
	u.swing = 1.0
	if u.def.role == "ranged":
		sound("archer")
		projectiles.append({"id": _id(), "type": "archer", "x": u.x, "y": u.y, "tx": target.x, "ty": target.y, "target": target,
			"speed": u.def.projectile, "damage": dmg, "done": false, "from": "unit"})
	else:
		damage_enemy(target, dmg, false)
		if randf() < 0.5:
			sound("clash")


func _kill_unit(u: Dictionary) -> void:
	u.dead = true
	particles(u.x, u.y, "#b3202a", 10, 2.0, 0.06, 0.6)
	particles(u.x, u.y, "#e8dcc0", 6, 1.4, 0.08, 0.7)
	if u.kind == "hero":
		hero_timer = D.HERO.respawn
		text(u.x, u.y - 0.3, "%s yaralandı, %d sn sonra döner" % [hero_def().name, roundi(D.HERO.respawn)], "#ff5b4d")
	else:
		text(u.x, u.y - 0.3, "Şehit düştü", "#ff5b4d")
	sound("fall")


func _update_army(dt: float) -> void:
	for kind in D.TROOPS:
		var t := training_of(kind)
		if not t.queue:
			t.time = 0.0
			continue
		t.time += dt
		if t.time >= D.TROOPS[kind].train:
			t.time = 0.0
			t.queue -= 1
			_spawn_unit(kind)

	for u in units:
		u.engaged = 0
	var growth: float = 1.0 + D.ENEMY_MELEE.growth * max(0, wave - 1)
	for e in enemies:
		var b = e.blocker
		if b == null:
			continue
		if b.dead or e.dead:
			e.blocker = null
			continue
		b.engaged += 1
		e.attack_cd -= dt
		if e.swing > 0.0:
			e.swing = maxf(0.0, e.swing - dt * 2.0)
		if e.attack_cd <= 0.0:
			e.attack_cd = D.ENEMY_MELEE.rate
			e.swing = 1.0
			b.hp -= e.def.melee * growth
			b.flash = 0.12
			if b.hp <= 0.0:
				_kill_unit(b)
	for e in enemies:
		if e.blocker != null and e.blocker.dead:
			e.blocker = null
	units = units.filter(func(u): return not u.dead)

	_send_wounded()
	_assign_posts()
	if morale > 0.0:
		for u in units:
			u.hp = minf(u.max_hp, u.hp + D.HERO.morale_heal * dt)
	var regen: float = 0.0 if phase == "wave" else D.ARMY.regen_build
	var ward := hospital_pos()
	var ward_heal: float = D.CITY.ward_heal + D.CITY.ward_heal_level * buildings.hospital
	for u in units:
		if u.healing and u.ready:
			u.hp = minf(u.max_hp, u.hp + ward_heal * dt)
			if u.hp >= u.max_hp:
				u.healing = false
				u.ready = false
				text(ward.x, ward.y - 0.4, "İyileşti", "#5cc48a")
		elif u.def.has("heal") and u.ready and not u.healing:
			for o in units:
				if o != u and not o.healing and Vector2(o.x - u.x, o.y - u.y).length() <= u.def.heal_range:
					if o.hp < o.max_hp:
						o.hp = minf(o.max_hp, o.hp + u.def.heal * dt)
						if randf() < dt * 1.5:
							particles(o.x, o.y - 0.2, "#7fe0a0", 3, 0.6, 0.04, 0.6)
	for u in units:
		var max_hp: float = troop_stats(u.kind).hp
		if max_hp != u.max_hp:
			u.hp += max_hp - u.max_hp
			u.max_hp = max_hp
		if regen > 0.0 and not u.engaged:
			u.hp = minf(u.max_hp, u.hp + regen * dt)
		if u.flash > 0.0:
			u.flash -= dt
		if u.swing > 0.0:
			u.swing = maxf(0.0, u.swing - dt * 4.0)
		if not u.ready:
			_walk(u, dt)
		else:
			u.moving = false
		if u.ready and not u.healing:
			_attack(u, dt)


func hospital_pos() -> Vector2:
	var s: Array = D.BUILDINGS.hospital.slot
	return Vector2(s[0] + 0.5, s[1] + 0.5)


# Canı azalan asker, Darüşşifa kuruluysa savaşı bırakıp hastaneye yürür
func _send_wounded() -> void:
	if buildings.hospital <= 0:
		return
	var ward := hospital_pos()
	for u in units:
		if u.healing or u.hp >= u.max_hp * D.CITY.wounded_ratio:
			continue
		u.healing = true
		for e in enemies:
			if e.blocker == u:
				e.blocker = null
		_set_target(u, ward.x + randf_range(-0.3, 0.3), ward.y + randf_range(-0.2, 0.2))
		text(u.x, u.y - 0.3, "Darüşşifa'ya", "#5cc48a")


func _find_blocker(e: Dictionary, next_dist: float):
	if e.def.get("siege", false):
		return null
	var best = null
	for u in units:
		if not u.ready or u.healing or u.def.block <= u.engaged or u.def.role != "melee":
			continue
		if e.dist > u.post or next_dist < u.post - D.ARMY.block_gap:
			continue
		if best == null or u.post < best.post:
			best = u
	return best


# ---------------------------------------------------------------- ana adım

func _id() -> int:
	next_id += 1
	return next_id


# Bir sabit adım. Dalga ya da baskın bittiyse true döner (kayıt için).
func step(dt: float) -> bool:
	time += dt
	_update_raid(dt)
	_update_market(dt)
	_update_research(dt)
	_update_spawner(dt)
	_update_hero(dt)
	_update_army(dt)
	_update_movement(dt)
	_update_towers(dt)
	_update_projectiles(dt)
	enemies = enemies.filter(func(e): return not e.dead)
	if charge.active > 0.0:
		charge.active = maxf(0.0, charge.active - dt)
	if charge.cooldown > 0.0:
		charge.cooldown = maxf(0.0, charge.cooldown - dt)
	return _check_wave_end()


func advance(elapsed: float) -> bool:
	var ended := false
	if not is_active():
		return false
	var remaining := minf(elapsed, D.RULES.max_frame) * speed
	while remaining > 1e-6 and is_active():
		var s := minf(D.RULES.max_step, remaining)
		if step(s):
			ended = true
		remaining -= s
	return ended
