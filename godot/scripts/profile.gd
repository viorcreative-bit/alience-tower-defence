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
		set_v("honor", honor() + n)


func _save() -> void:
	cfg.save(PATH)
