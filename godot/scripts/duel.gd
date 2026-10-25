class_name DuelLink
extends RefCounted

# İki oyuncu arasındaki konuşma; iletiyi kimin taşıdığını bilmez (Net ya da sınamada doğrudan bağlantı).
# Odayı kuran (creator) oyunun türünü seçer: mode "duel" (ikisi de savunur) ya da "siege" (biri saldırır,
# öteki savunur; kuran kendi rolünü seçer, katılan ötekini alır). Akış: iki taraf "hello" yollar; kuran
# ev sahibidir ve "start" yollar.
# duel: her saniye "state", birikince "troops", sur düşünce "lost".
# siege: savunan her snap saniyede kalesinin görüntüsünü ("snap") yollar, saldıran birlik gönderir ("send")
# ve her saniye "ping" atar. Sur düşerse savunan "lost", süre dolarsa "held" yollar.

const D := preload("res://scripts/data.gd")
const TICK := 1.0

signal outgoing(msg: Dictionary)
signal started(seed: int)
signal changed

var my_id := ""
var my_name := ""
var my_country := ""
var room := ""
var creator := false
var mode := "duel"
var role := ""  # siege'de defend ya da attack
var state := "idle"  # idle | waiting | playing | over
var opp := {}  # {id, name, country, creator, wall, max_wall, wave, seen}
var seed := 0
var game: Game
var timer := 0.0
var snap_timer := 0.0
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


static func other(r: String) -> String:
	return "attack" if r == "defend" else "defend"


# Odaya gir. Kuran türü ve rolü seçer; katılanınki ev sahibinden gelir.
func begin(code: String, is_creator := true, m := "duel", r := "") -> void:
	room = code
	creator = is_creator
	mode = m if is_creator else "duel"
	role = r if is_creator and m == "siege" else ""
	state = "waiting"
	opp = {}
	seed = 0
	timer = 0.0
	lost_sent = false
	result = ""
	why = ""
	changed.emit()


func host() -> bool:
	if not opp.has("id"):
		return false
	if creator != opp.get("creator", false):
		return creator
	return my_id < opp.id


func _send(m: Dictionary) -> void:
	m.from = my_id
	outgoing.emit(m)


func _setup() -> Dictionary:
	return {"mode": mode, "role": role} if creator else {}


func tick(dt: float) -> void:
	clock += dt
	if state == "idle" or state == "over":
		return
	timer -= dt
	if state == "waiting":
		if timer <= 0.0:
			timer = TICK
			var h := {"t": "hello", "name": my_name, "country": my_country, "creator": creator}
			h.merge(_setup())
			_send(h)
			# ev sahibi, rakip oyuna girdiğini duyurana kadar başlatmayı yineler
			if host() and seed != 0:
				var s := {"t": "start", "seed": seed}
				s.merge(_setup())
				_send(s)
		return
	if game == null:
		return
	if mode == "siege":
		_tick_siege(dt)
	else:
		_tick_duel()
	if state == "playing" and clock - float(opp.get("seen", clock)) > D.DUEL.timeout:
		_send({"t": "bye"})
		_win("Rakip ayrıldı, zafer senin")


func _tick_duel() -> void:
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
		_repeat_start()


func _tick_siege(dt: float) -> void:
	if role == "defend":
		if game.phase == "lost" and not lost_sent:
			lost_sent = true
			_send({"t": "lost"})
			_finish("lose", "Surlar yıkıldı, kaleyi %s aldı" % opp.get("name", "rakip"))
			return
		if game.phase == "won" and not lost_sent:
			lost_sent = true
			_send({"t": "held"})
			_finish("win", "Kale %d dakika dayandı" % roundi(D.PVP.duration / 60.0))
			return
		snap_timer -= dt
		if snap_timer <= 0.0:
			snap_timer = D.PVP.snap
			var s := game.snapshot()
			s.t = "snap"
			_send(s)
	else:
		for o in game.pvp_state.out:
			_send({"t": "send", "type": o.type, "n": o.n, "up": o.up})
		game.pvp_state.out.clear()
		if timer <= 0.0:
			timer = TICK
			_send({"t": "ping"})
	if timer <= 0.0:
		timer = TICK
	_repeat_start()


func _repeat_start() -> void:
	if host() and seed != 0 and not opp.get("playing", false):
		var s := {"t": "start", "seed": seed}
		s.merge(_setup())
		_send(s)


func _adopt(m: Dictionary) -> void:
	if creator or not m.has("mode"):
		return
	mode = "siege" if m.mode == "siege" else "duel"
	role = other(str(m.get("role", ""))) if mode == "siege" else ""


func handle(m: Dictionary) -> void:
	if m.get("from", "") == my_id or state == "idle" or state == "over":
		return
	if opp.has("id") and m.get("from") != opp.id:
		return  # odaya üçüncü biri girdi; yok sayılır
	match m.get("t"):
		"hello":
			if not opp.has("id"):
				opp = {"id": str(m.from), "name": str(m.get("name", "Rakip")).substr(0, 16), "country": str(m.get("country", "")),
					"creator": m.get("creator", false) == true, "wall": 0, "max_wall": 0, "wave": 0, "seen": clock}
				_adopt(m)
				timer = 0.0
				if host():
					seed = randi() % 1000000 + 1
				changed.emit()
		"start":
			if state == "waiting" and not host():
				_adopt(m)
				seed = int(m.get("seed", 1))
				_play()
		"state", "ping":
			opp.wall = int(m.get("wall", opp.get("wall", 0)))
			opp.max_wall = int(m.get("max_wall", opp.get("max_wall", 0)))
			opp.wave = int(m.get("wave", opp.get("wave", 0)))
			_seen_playing()
		"snap":
			if state == "playing" and game and game.pvp == "attack":
				game.apply_snap(m)
			opp.wall = int(m.get("wall", 0))
			opp.max_wall = int(m.get("max_wall", 0))
			_seen_playing()
		"send":
			if state == "playing" and game and game.pvp == "defend" and m.get("up") is Dictionary:
				game.pvp_receive(str(m.get("type", "")), int(m.get("n", 1)), m.up)
		"troops":
			if state == "playing" and m.get("list") is Array:
				var list := []
				for t in m.list.slice(0, 30):
					list.append(str(t))
				game.duel_receive(list)
		"lost":
			if state == "playing":
				_win("Surlar yıkıldı, kale senin!" if mode == "siege" else "Rakibin surları düştü, zafer senin!")
		"held":
			if state == "playing":
				if game:
					game.pvp_end(false, "Kale dayandı, kuşatma başarısız")
				_finish("lose", "Kale %d dakika dayandı" % roundi(D.PVP.duration / 60.0))
		"bye":
			if state == "playing":
				_win("Rakip ayrıldı, zafer senin")
	if opp.has("id"):
		opp.seen = clock


func _seen_playing() -> void:
	opp.playing = true
	if state == "waiting" and host():
		_play()
	changed.emit()


func _win(w: String) -> void:
	if game:
		if mode == "siege":
			game.pvp_end(true, w)
		else:
			game.duel_end(true, w)
	_finish("win", w)


# Ev sahibi rakibin ilk durumunu görünce, misafir "start" gelince oyuna geçer
func _play() -> void:
	if state != "waiting":
		return
	state = "playing"
	timer = 0.0
	snap_timer = 0.0
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
