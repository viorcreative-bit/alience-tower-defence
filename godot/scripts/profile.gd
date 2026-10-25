class_name Profiles
extends RefCounted

# Oyuncu hesapları: cihazda (user://hesaplar.cfg) saklanır, sunucu yoktur. Her hesabın adı, seçtiği devlet,
# şerefi, her devletin hükümdar seviyesi, en iyi dalgası ve sefer haritasındaki yıldızları vardır. Son giriş yapan hesap hatırlanır.

const D := preload("res://scripts/data.gd")
const PATH := "user://hesaplar.cfg"
const MAX_NAME := 16

var cfg := ConfigFile.new()
var current := ""  # giriş yapmış hesabın adı ("" = giriş yok)


func _init() -> void:
	cfg.load(PATH)
	current = cfg.get_value("_", "last", "")
	if current != "" and not cfg.has_section(_sec(current)):
		current = ""


func _sec(name: String) -> String:
	return "hesap:" + name


static func clean_name(raw: String) -> String:
	var s := raw.strip_edges()
	while s.contains("  "):
		s = s.replace("  ", " ")
	return s.substr(0, MAX_NAME)


func names() -> Array:
	var out := []
	for sec in cfg.get_sections():
		if sec.begins_with("hesap:"):
			out.append(sec.substr(6))
	return out


# Ad ile giriş: hesap yoksa açılır. Boş ad kabul edilmez.
func login(raw: String) -> bool:
	var name := clean_name(raw)
	if name == "":
		return false
	current = name
	var sec := _sec(name)
	if not cfg.has_section(sec):
		cfg.set_value(sec, "country", "ottoman")
		cfg.set_value(sec, "honor", 0)
		cfg.set_value(sec, "kings", {})
		cfg.set_value(sec, "best_wave", 0)
	cfg.set_value("_", "last", name)
	_save()
	return true


func logout() -> void:
	current = ""
	cfg.set_value("_", "last", "")
	_save()


func get_v(key: String, def):
	return cfg.get_value(_sec(current), key, def)


func set_v(key: String, v) -> void:
	cfg.set_value(_sec(current), key, v)
	_save()


func country() -> String:
	var c: String = get_v("country", "ottoman")
	return c if D.COUNTRIES.has(c) else "ottoman"


func hero() -> String:
	var h: String = get_v("hero", D.HERO_ORDER[0])
	return h if D.HEROES.has(h) else D.HERO_ORDER[0]


func honor() -> int:
	return get_v("honor", 0)


func king_level(c: String) -> int:
	return get_v("kings", {}).get(c, 1)


func can_upgrade_king(c: String) -> bool:
	var l := king_level(c)
	return l < D.KING.max_level and honor() >= D.king_cost(l)


func upgrade_king(c: String) -> bool:
	if not can_upgrade_king(c):
		return false
	var l := king_level(c)
	var kings: Dictionary = get_v("kings", {}).duplicate()
	kings[c] = l + 1
	cfg.set_value(_sec(current), "honor", honor() - D.king_cost(l))
	set_v("kings", kings)
	return true


# ---------------------------------------------------------------- sefer

# Kuşatmalarda kazanılan yıldızlar {kuşatma: 1..3}; hiç kazanılmamış kuşatma yoktur
func stage_stars(id: String) -> int:
	return get_v("stages", {}).get(id, 0)


# İlk kuşatma hep açıktır; sonrakiler bir öncekinin kazanılmasıyla açılır
func stage_open(id: String) -> bool:
	var i := D.STAGE_ORDER.find(id)
	return i == 0 or (i > 0 and stage_stars(D.STAGE_ORDER[i - 1]) > 0)


# Zaferi kaydeder; ilk zaferse kuşatmanın şerefini verir ve verilen şerefi döndürür
func win_stage(id: String, stars: int) -> int:
	if current == "":
		return 0
	var st: Dictionary = get_v("stages", {}).duplicate()
	var first: bool = not st.has(id)
	st[id] = maxi(st.get(id, 0), stars)
	set_v("stages", st)
	if first:
		add_honor(D.STAGES[id].honor)
		return D.STAGES[id].honor
	return 0


func add_honor(n: int) -> void:
	if current != "" and n > 0:
		cfg.set_value(_sec(current), "honor_total", get_v("honor_total", 0) + n)
		set_v("honor", honor() + n)


# ---------------------------------------------------------------- görevler, başarımlar, sıralama

func stats() -> Dictionary:
	return get_v("stats", {})


# Savaştan gelen sayımı ekler; tamamlanan günlük görevlerin ve başarımların şerefini verir.
# Gösterilecek duyuruları döndürür.
func record(delta: Dictionary) -> Array:
	if current == "":
		return []
	var st: Dictionary = stats().duplicate()
	for k in delta:
		if k == "streak":
			st.streak = maxi(st.get("streak", 0), delta.streak)
		else:
			st[k] = st.get(k, 0) + delta[k]
	cfg.set_value(_sec(current), "stats", st)
	var out := []
	var day := daily()
	for k in delta:
		if k != "streak":
			day.progress[k] = day.progress.get(k, 0) + delta[k]
	for q in day.ids:
		var qd: Dictionary = D.QUESTS[q]
		if not day.done.has(q) and day.progress.get(qd.stat, 0) >= qd.goal:
			day.done[q] = true
			add_honor(qd.honor)
			out.append("Görev tamam: %s  +%d şeref" % [qd.text, qd.honor])
	cfg.set_value(_sec(current), "daily", day)
	var got: Dictionary = get_v("ach", {}).duplicate()
	for a in D.ACHIEVEMENT_ORDER:
		if not got.has(a) and achieved(a):
			got[a] = true
			cfg.set_value(_sec(current), "ach", got)
			add_honor(D.ACHIEVEMENTS[a].honor)
			out.append("Başarım: %s  +%d şeref" % [D.ACHIEVEMENTS[a].name, D.ACHIEVEMENTS[a].honor])
	_save()
	return out


func has_ach(id: String) -> bool:
	return get_v("ach", {}).has(id)


func achieved(id: String) -> bool:
	var a: Dictionary = D.ACHIEVEMENTS[id]
	var st := stats()
	for k in a.get("need", {}):
		if st.get(k, 0) < a.need[k]:
			return false
	if a.has("stage") and stage_stars(a.stage) <= 0:
		return false
	if a.get("three", false):
		var any := false
		for s in D.STAGE_ORDER:
			any = any or stage_stars(s) >= 3
		if not any:
			return false
	if a.get("all_stages", false):
		for s in D.STAGE_ORDER:
			if stage_stars(s) <= 0:
				return false
	return true


# Başarımın ilerlemesi [şimdi, hedef] (tek sayılık başarımlar için)
func ach_progress(id: String) -> Array:
	var a: Dictionary = D.ACHIEVEMENTS[id]
	var need: Dictionary = a.get("need", {})
	if need.size():
		var k: String = need.keys()[0]
		return [mini(stats().get(k, 0), need[k]), need[k]]
	if a.get("all_stages", false):
		var n := 0
		for s in D.STAGE_ORDER:
			n += 1 if stage_stars(s) > 0 else 0
		return [n, D.STAGE_ORDER.size()]
	return [1 if achieved(id) else 0, 1]


# Bugünün görevleri: tarih değişince tarihe göre yeniden seçilir
func daily() -> Dictionary:
	var today := Time.get_date_string_from_system()
	var d: Dictionary = get_v("daily", {})
	if d.get("date", "") == today:
		return d.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(today)
	var pool: Array = D.QUEST_ORDER.duplicate()
	var ids := []
	while ids.size() < D.QUESTS_PER_DAY and pool.size():
		ids.append(pool.pop_at(rng.randi() % pool.size()))
	return {"date": today, "ids": ids, "progress": {}, "done": {}}


func stars_total(name := "") -> int:
	var st: Dictionary = cfg.get_value(_sec(name if name != "" else current), "stages", {})
	var n := 0
	for k in st:
		n += st[k]
	return n


# Bu cihazdaki hesapların sıralaması: kazanılan toplam şeref, sonra yıldız
func leaderboard() -> Array:
	var rows := []
	for n in names():
		var sec := _sec(n)
		rows.append({"name": n, "honor": cfg.get_value(sec, "honor_total", cfg.get_value(sec, "honor", 0)), "stars": stars_total(n),
			"best": cfg.get_value(sec, "best_wave", 0), "ach": cfg.get_value(sec, "ach", {}).size()})
	rows.sort_custom(func(a, b): return a.honor > b.honor or (a.honor == b.honor and a.stars > b.stars))
	return rows


func _save() -> void:
	cfg.save(PATH)
