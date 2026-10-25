class_name DuelLink
extends RefCounted

# Düellonun iki oyuncu arasındaki konuşması; iletiyi kimin taşıdığını bilmez (Net ya da sınamada
# doğrudan bağlantı). Akış: iki taraf "hello" yollar; kimliği küçük olan ev sahibidir ve "start"
# yollar; sonra her saniye "state" (sur, dalga), birikince "troops" (rakibe asker), sur düşünce "lost".

const D := preload("res://scripts/data.gd")
const TICK := 1.0

signal outgoing(msg: Dictionary)
signal started(seed: int)
signal changed

var my_id := ""
var my_name := ""
var my_country := ""
var room := ""
var state := "idle"  # idle | waiting | playing | over
var opp := {}  # {id, name, country, wall, max_wall, wave, seen}
var seed := 0
var game: Game
var timer := 0.0
var clock := 0.0
var lost_sent := false
var result := ""  # win | lose
var why := ""


func _init(id: String, name: String, country: String) -> void:
	my_id = id
	my_name = name
	my_country = country


static func make_code(rng: RandomNumberGenerator) -> String:
	var abc := "ABCDEFGHJKLMNPRSTUVYZ"  # karışan harfler (I, O, Q...) yok
	var s := ""
	for i in D.DUEL.code_len:
		s += abc[rng.randi() % abc.length()]
	return s


func begin(code: String) -> void:
	room = code
	state = "waiting"
	opp = {}
	seed = 0
	timer = 0.0
	lost_sent = false
	result = ""
	why = ""
	changed.emit()


func host() -> bool:
	return opp.has("id") and my_id < opp.id


func _send(m: Dictionary) -> void:
	m.from = my_id
	outgoing.emit(m)


func tick(dt: float) -> void:
	clock += dt
	if state == "idle" or state == "over":
		return
	timer -= dt
	if state == "waiting":
		if timer <= 0.0:
			timer = TICK
			_send({"t": "hello", "name": my_name, "country": my_country})
			# ev sahibi, rakip oyuna girdiğini duyurana kadar başlatmayı yineler
			if host() and seed != 0:
				_send({"t": "start", "seed": seed})
		return
	# oyunda
	if game == null:
		return
	if game.duel_state.out.size():
		_send({"t": "troops", "list": game.duel_state.out.duplicate()})
		game.duel_state.out.clear()
	if game.phase == "lost" and not lost_sent:
		lost_sent = true
		_send({"t": "lost"})
		_finish("lose", "Surlar düştü, düelloyu %s kazandı" % opp.get("name", "rakip"))
		return
	if timer <= 0.0:
		timer = TICK
		_send({"t": "state", "wall": game.wall, "max_wall": game.max_wall, "wave": game.wave, "phase": game.phase})
		if host() and seed != 0 and not opp.get("playing", false):
			_send({"t": "start", "seed": seed})
	if clock - float(opp.get("seen", clock)) > D.DUEL.timeout:
		_send({"t": "bye"})
		game.duel_end(true, "Rakip ayrıldı, düello senin")
		_finish("win", "Rakip ayrıldı")


func handle(m: Dictionary) -> void:
	if m.get("from", "") == my_id or state == "idle" or state == "over":
		return
	if opp.has("id") and m.get("from") != opp.id:
		return  # odaya üçüncü biri girdi; yok sayılır
	match m.get("t"):
		"hello":
			if not opp.has("id"):
				opp = {"id": str(m.from), "name": str(m.get("name", "Rakip")).substr(0, 16), "country": str(m.get("country", "")),
					"wall": 0, "max_wall": 0, "wave": 0, "seen": clock}
				timer = 0.0
				if host():
					seed = randi() % 1000000 + 1
				changed.emit()
		"start":
			if state == "waiting" and not host():
				seed = int(m.get("seed", 1))
				_play()
		"state":
			opp.wall = int(m.get("wall", 0))
			opp.max_wall = int(m.get("max_wall", 0))
			opp.wave = int(m.get("wave", 0))
			opp.playing = true
			if state == "waiting" and host():
				_play()
			changed.emit()
		"troops":
			if state == "playing" and m.get("list") is Array:
				var list := []
				for t in m.list.slice(0, 30):
					list.append(str(t))
				game.duel_receive(list)
		"lost":
			if state == "playing":
				game.duel_end(true, "Rakibin surları düştü, zafer senin!")
				_finish("win", "Rakip yenildi")
		"bye":
			if state == "playing":
				game.duel_end(true, "Rakip ayrıldı, düello senin")
				_finish("win", "Rakip ayrıldı")
	if opp.has("id"):
		opp.seen = clock


# Ev sahibi rakibin ilk durumunu (ya da kendi başlatma iletisini) görünce, misafir "start" gelince oyuna geçer
func _play() -> void:
	if state != "waiting":
		return
	state = "playing"
	timer = 0.0
	opp.seen = clock
	started.emit(seed)
	changed.emit()


func _finish(r: String, w: String) -> void:
	state = "over"
	result = r
	why = w
	changed.emit()


func leave() -> void:
	if state == "playing" or state == "waiting":
		_send({"t": "bye"})
	state = "idle"
	changed.emit()
