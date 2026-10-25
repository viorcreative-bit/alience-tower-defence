class_name GameAudio
extends Node

# Bütün sesler kodda üretilir; hazır kayıt yok. Kısa efektler açılışta hazırlanır. Mehter marşları ve
# şehir/hava döngüleri uzun olduğu için adım adım, her karede birkaç milisaniye ayrılarak hazırlanır
# (web'de iş parçacığı yok). Ses düğmesi üç kipe geçer: hepsi açık, müziksiz, sessiz.

const RATE := 22050
const AMB_RATE := 11025  # arka plan sesleri için yarım örnekleme yeter
const BUDGET_USEC := 5000  # her karede döngü hazırlığına ayrılan süre
const MODE_NAMES := ["Ses", "Müziksiz", "Sessiz"]
# arka plan döngülerinin ses düzeyi (dB); dalga sırasında savaş sesi öne çıksın diye kısılır
const AMB_DB := {"city": -11.0, "harbor": -11.0, "field": -9.0, "rain": -12.0, "wind": -13.0}
const AMB_WAVE_DB := -7.0

var mode := 0
var sfx := {}
var players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var amb := {}  # "base" / "wx" -> {"player", "id", "tween"}
var loops := {}  # hazırlanmış döngüler: build, wave, city, harbor, field, rain, wind
var music_mode := "off"
var amb_want := {"base": "", "wx": ""}
var amb_quiet := false
var boss := false
var jobs := []  # hazırlanacak döngülerin adları
var job := {}  # şu an hazırlanan döngü
var rng := RandomNumberGenerator.new()
var last_play := {}


func _ready() -> void:
	rng.seed = 7
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -7.0
	add_child(music_player)
	for slot in ["base", "wx"]:
		var p := AudioStreamPlayer.new()
		add_child(p)
		amb[slot] = {"player": p, "id": "", "tween": null}
	_make_sfx()
	jobs = ["build", "wave"] + jobs


func effects_on() -> bool:
	return mode < 2


func music_on() -> bool:
	return mode == 0


func mode_name() -> String:
	return MODE_NAMES[mode]


func set_mode(m: int) -> void:
	mode = clampi(m, 0, MODE_NAMES.size() - 1)
	if not effects_on():
		for p in players:
			p.stop()
	_apply_music()
	_apply_ambience()


func cycle_mode() -> int:
	set_mode((mode + 1) % MODE_NAMES.size())
	return mode


func play(id: String, opts := {}) -> void:
	if not effects_on() or not sfx.has(id):
		return
	var now := Time.get_ticks_msec()
	# aynı sesin üst üste binmesini sınırla
	if now - int(last_play.get(id, -1000)) < (40 if id in ["archer", "tar"] else 70):
		return
	last_play[id] = now
	var delay: float = opts.get("delay", 0.0)
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(func(): _start(id, opts))
	else:
		_start(id, opts)


func _start(id: String, opts: Dictionary) -> void:
	if not effects_on():
		return
	for p in players:
		if not p.playing:
			p.stream = sfx[id]
			var loud := opts.get("loud", 0) as float
			p.volume_db = _base_db(id) + (3.0 if loud > 0 else 0.0)
			p.pitch_scale = rng.randf_range(0.94, 1.06) if not id in ["chant", "chime", "research"] else 1.0
			p.play()
			return


func _base_db(id: String) -> float:
	match id:
		"archer", "tar":
			return -14.0
		"clash", "fall":
			return -11.0
		"chime":
			return -9.0
		"cannon", "boom":
			return -7.0
		"chant":
			return -2.0
		"bossHorn", "trumpet":
			return -4.0
	return -6.0


# ---------------------------------------------------------------- müzik

func set_music(m: String) -> void:
	if m == music_mode:
		return
	music_mode = m
	_apply_music()


# Kuşatma devi sahadayken marş biraz hızlanır ve tizleşir
func set_boss(v: bool) -> void:
	if v == boss:
		return
	boss = v
	create_tween().tween_property(music_player, "pitch_scale", 1.07 if v else 1.0, 1.2)


func _apply_music() -> void:
	var s: AudioStreamWAV = loops.get(music_mode) if music_mode in ["build", "wave"] else null
	if s == null or not music_on():
		music_player.stop()
		if music_mode in ["build", "wave"] and not loops.has(music_mode):
			_need(music_mode)
		return
	if music_player.stream == s and music_player.playing:
		return
	var pos := music_player.get_playback_position() if music_player.playing else 0.0
	music_player.stream = s
	music_player.play(fmod(pos, s.data.size() / 2.0 / RATE))


# ---------------------------------------------------------------- şehir ve hava sesleri

# base: city / harbor / field, wx: "" / rain / wind; quiet dalga sırasında kısar
func set_ambience(base: String, wx: String, quiet: bool) -> void:
	if base == amb_want.base and wx == amb_want.wx and quiet == amb_quiet:
		return
	amb_want = {"base": base, "wx": wx}
	amb_quiet = quiet
	_apply_ambience()


func _apply_ambience() -> void:
	for slot in amb:
		var a: Dictionary = amb[slot]
		var want: String = amb_want[slot] if effects_on() else ""
		if want != "" and not loops.has(want):
			_need(want)
			want = ""
		var p: AudioStreamPlayer = a.player
		if a.tween:
			a.tween.kill()
		if want == "":
			if p.playing:
				a.tween = create_tween()
				a.tween.tween_property(p, "volume_db", -40.0, 1.5)
				a.tween.tween_callback(p.stop)
			a.id = ""
			continue
		var db: float = AMB_DB[want] + (AMB_WAVE_DB if amb_quiet else 0.0)
		if a.id != want or not p.playing:
			a.id = want
			p.stream = loops[want]
			p.volume_db = -40.0
			p.play(rng.randf() * 4.0)
		a.tween = create_tween()
		a.tween.tween_property(p, "volume_db", db, 2.0)


# ---------------------------------------------------------------- döngü hazırlığı

func _need(id: String) -> void:
	if not loops.has(id) and not id in jobs and job.get("id", "") != id:
		jobs.append(id)


func _process(_dt: float) -> void:
	if job.is_empty():
		if jobs.is_empty():
			return
		# şu an istenen döngü önce hazırlanır
		var pick: String = jobs[0]
		for id in jobs:
			if id == music_mode or id == amb_want.base or id == amb_want.wx:
				pick = id
				break
		jobs.erase(pick)
		job = _plan(pick)
	var until := Time.get_ticks_usec() + BUDGET_USEC
	var steps: Array = job.steps
	while job.i < steps.size() and Time.get_ticks_usec() < until:
		var st: Array = steps[job.i]
		callv(st[0], [job.buf] + st[1])
		job.i += 1
	if job.i >= steps.size():
		_finish()


func _finish() -> void:
	var id: String = job.id
	var b: PackedFloat32Array = job.buf
	var n: int = job.n
	var out := b.slice(0, n)
	var f := b.size() - n
	for i in f:
		if job.cross:
			var w := float(i) / f
			out[i] = b[i] * sqrt(w) + b[n + i] * sqrt(1.0 - w)
		else:
			out[i] += b[n + i]
	if job.limit:
		for i in out.size():
			out[i] = tanh(out[i] * 0.9)
	loops[id] = _wav(out, true, job.rate)
	job = {}
	if id in ["build", "wave"]:
		_apply_music()
	else:
		_apply_ambience()


# Bir döngünün adımları. Tampon döngüden biraz uzundur: taşan kuyruk başa eklenir (müzik) ya da
# başla harmanlanır (arka plan), böylece döngü dikişsiz döner.
func _plan(id: String) -> Dictionary:
	var j := {"id": id, "i": 0, "steps": [], "cross": false, "limit": false, "rate": RATE}
	rng.seed = hash(id)
	match id:
		"build", "wave":
			_plan_mehter(j, id == "wave")
		"city", "harbor", "field", "rain", "wind":
			_plan_ambience(j, id)
	return j


func _job_buf(j: Dictionary, sec: float, tail: float, rate: int) -> void:
	j.rate = rate
	j.n = int(sec * rate)
	var b := PackedFloat32Array()
	b.resize(int((sec + tail) * rate))
	j.buf = b


# ---------------------------------------------------------------- dalga yardımcıları

func _wav(samples: PackedFloat32Array, loop := false, rate := RATE) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


static func _midi(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


# Kös / davul vuruşu: alçalan sinüs ve biraz gürültü
func _drum(b: PackedFloat32Array, at: float, freq: float, dur: float, amp: float, noise := 0.3) -> void:
	var s := int(at * RATE)
	var n := int(dur * RATE)
	var ph := 0.0
	for i in n:
		if s + i >= b.size():
			break
		var t := float(i) / RATE
		var env := exp(-t / (dur * 0.28))
		var f := freq * (1.0 + 1.5 * exp(-t * 40.0))
		ph += TAU * f / RATE
		b[s + i] += (sin(ph) + noise * (rng.randf() * 2.0 - 1.0) * exp(-t * 60.0)) * env * amp


# Zil: süzülmüş gürültü
func _cymbal(b: PackedFloat32Array, at: float, dur: float, amp: float) -> void:
	var s := int(at * RATE)
	var prev := 0.0
	for i in int(dur * RATE):
		if s + i >= b.size():
			break
		var t := float(i) / RATE
		var x := rng.randf() * 2.0 - 1.0
		var hp := x - prev
		prev = x
		b[s + i] += hp * exp(-t / (dur * 0.3)) * amp


# Zurna: testere dişi dalga, titreşim, basit alçak geçiren süzgeç
func _zurna(b: PackedFloat32Array, at: float, midi: float, dur: float, amp: float) -> void:
	var s := int(at * RATE)
	var n := int(dur * RATE)
	var ph := 0.0
	var lp := 0.0
	var f0 := _midi(midi)
	for i in n:
		if s + i >= b.size():
			break
		var t := float(i) / RATE
		var vib := 1.0 + 0.012 * sin(TAU * 5.5 * t) * minf(1.0, t * 4.0)
		ph = fmod(ph + f0 * vib / RATE, 1.0)
		var saw := ph * 2.0 - 1.0
		lp += (saw - lp) * 0.35
		var env := minf(1.0, t * 30.0) * minf(1.0, (dur - t) * 20.0)
		b[s + i] += lp * env * amp


# Boru (doğal borazan): parlaklığı açılışta artan, aşağıdan kayarak oturan pirinç tını
func _boru(b: PackedFloat32Array, at: float, midi: float, dur: float, amp: float) -> void:
	var s := int(at * RATE)
	var f0 := _midi(midi)
	var ph := 0.0
	for i in int(dur * RATE):
		if s + i >= b.size():
			break
		var t := float(i) / RATE
		ph += TAU * f0 * (1.0 - 0.03 * exp(-t * 18.0)) / RATE
		var bright := minf(1.0, t * 6.0)
		var v := 0.0
		for k in range(1, 7):
			v += sin(ph * k) / k * (1.0 if k < 3 else bright)
		var env := minf(1.0, t * 16.0) * minf(1.0, (dur - t) * 6.0)
		b[s + i] += v * env * amp


# Ney: yumuşak sinüs, biraz üfleme gürültüsü, geç başlayan titreşim
func _ney(b: PackedFloat32Array, at: float, midi: float, dur: float, amp: float) -> void:
	var s := int(at * RATE)
	var f0 := _midi(midi)
	var ph := 0.0
	var lp := 0.0
	for i in int(dur * RATE):
		if s + i >= b.size():
			break
		var t := float(i) / RATE
		ph += TAU * f0 * (1.0 + 0.008 * sin(TAU * 4.5 * t) * clampf(t * 2.0 - 0.4, 0.0, 1.0)) / RATE
		lp += ((rng.randf() * 2.0 - 1.0) - lp) * 0.12
		var env := minf(1.0, t * 5.0) * minf(1.0, (dur - t) * 5.0)
		b[s + i] += (sin(ph) + 0.18 * sin(ph * 2.0) + 0.35 * lp) * env * amp


# Çan: uyumsuz kısmi tınılarla uzun sönüm
func _bell(b: PackedFloat32Array, at: float, f: float, dur: float, amp: float, rate := RATE) -> void:
	var s := int(at * rate)
	for i in int(dur * rate):
		if s + i >= b.size():
			break
		var t := float(i) / rate
		var v := 0.0
		for p in [[1.0, 1.0], [2.0, 0.6], [2.4, 0.45], [3.0, 0.3], [4.5, 0.2]]:
			v += sin(TAU * f * p[0] * t) * p[1] * exp(-t * (1.2 + p[0] * 0.8) / dur * 2.0)
		b[s + i] += v * minf(1.0, t * 400.0) * amp


# Kayan perdeli kısa ses (kuş cıvıltısı, martı çığlığı)
func _chirp(b: PackedFloat32Array, at: float, f0: float, f1: float, dur: float, amp: float, rate := RATE, harm := 0.0) -> void:
	var s := int(at * rate)
	var ph := 0.0
	var n := int(dur * rate)
	for i in n:
		if s + i >= b.size():
			break
		var t := float(i) / rate
		ph += TAU * lerpf(f0, f1, pow(t / dur, 0.7)) / rate
		var env := sin(PI * t / dur)
		b[s + i] += (sin(ph) + harm * sin(ph * 2.0) + harm * 0.5 * sin(ph * 3.0)) * env * env * amp


# Örs ya da taş keskisi: kısa metal çınlaması
func _tink(b: PackedFloat32Array, at: float, f: float, amp: float, rate := RATE) -> void:
	var s := int(at * rate)
	for i in int(0.25 * rate):
		if s + i >= b.size():
			break
		var t := float(i) / rate
		b[s + i] += (sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.76 * t)) * exp(-t * 22.0) * amp


# ---------------------------------------------------------------- efektler

func _make_sfx() -> void:
	var b: PackedFloat32Array
	# ok vınlaması: yükselip alçalan süzülmüş gürültü
	b = _buf(0.22)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var k := 0.15 + 0.5 * sin(PI * t / 0.22)
		lp += ((rng.randf() * 2.0 - 1.0) - lp) * k
		b[i] = lp * sin(PI * t / 0.22) * 0.8
	sfx.archer = _wav(b)
	# zift fokurtusu
	b = _buf(0.35)
	for k in 4:
		var at := 0.02 + k * 0.075
		var ph := 0.0
		for i in int(0.06 * RATE):
			var t := float(i) / RATE
			ph += TAU * (180.0 + 600.0 * t * 10.0) / RATE
			var idx := int(at * RATE) + i
			if idx < b.size():
				b[idx] += sin(ph) * exp(-t * 50.0) * 0.6
	sfx.tar = _wav(b)
	# gülle düşüşü: tok gümleme
	b = _buf(0.9)
	_drum(b, 0.0, 55.0, 0.9, 1.0, 1.0)
	sfx.boom = _wav(b)
	# top atışı: keskin patlama, ardından uzayan gürleme ve yankı
	b = _buf(1.6)
	lp = 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += ((rng.randf() * 2.0 - 1.0) - lp) * (0.9 * exp(-t * 6.0) + 0.04)
		b[i] = lp * (exp(-t * 40.0) * 0.8 + exp(-t * 2.6) * 0.4)
	_drum(b, 0.0, 42.0, 1.2, 0.7, 0.2)
	_drum(b, 0.32, 40.0, 0.8, 0.25, 0.4)
	sfx.cannon = _wav(b)
	# tüfek patlaması
	b = _buf(0.4)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (rng.randf() * 2.0 - 1.0) * exp(-t * 28.0) * 0.9
	_drum(b, 0.0, 90.0, 0.25, 0.5, 0.0)
	sfx.musket = _wav(b)
	# dağılma: yumuşak tok ses
	b = _buf(0.3)
	_drum(b, 0.0, 120.0, 0.3, 0.5, 0.8)
	sfx.fall = _wav(b)
	# kuşatma aracı kırılması
	b = _buf(0.7)
	for k in 5:
		_drum(b, k * 0.07, 160.0 + k * 40.0, 0.25, 0.4, 1.2)
	sfx.crash = _wav(b)
	# kurma: üç çekiç vuruşu
	b = _buf(0.45)
	for k in 3:
		_drum(b, k * 0.13, 420.0, 0.1, 0.5, 0.8)
	sfx.build = _wav(b)
	# satış: iki altın tınısı
	b = _buf(0.5)
	for k in 2:
		var f := 1320.0 if k == 0 else 1760.0
		for i in int(0.35 * RATE):
			var t := float(i) / RATE
			var idx := int(k * 0.09 * RATE) + i
			if idx < b.size():
				b[idx] += sin(TAU * f * t) * exp(-t * 9.0) * 0.4
	sfx.sell = _wav(b)
	# sura çarpma
	b = _buf(0.5)
	_drum(b, 0.0, 70.0, 0.5, 0.9, 0.9)
	sfx.wallHit = _wav(b)
	# kılıç şakırtısı: uyumsuz tınılar
	b = _buf(0.3)
	for f in [2350.0, 3170.0, 4110.0]:
		for i in b.size():
			var t := float(i) / RATE
			b[i] += sin(TAU * f * t) * exp(-t * 18.0) * 0.18
	sfx.clash = _wav(b)
	# borazan (baskın ve uyarı)
	b = _buf(1.3)
	_zurna(b, 0.0, 55.0, 0.45, 0.5)
	_zurna(b, 0.45, 60.0, 0.8, 0.5)
	sfx.horn = _wav(b)
	# kuşatma devi geliyor: kös gürlemesi ve alçak boru
	b = _buf(2.4)
	for k in 10:
		_drum(b, k * 0.09, 48.0, 0.5, 0.25 + k * 0.05, 0.3)
	_boru(b, 0.9, 43.0, 1.3, 0.22)
	_boru(b, 0.9, 50.0, 1.3, 0.14)
	sfx.bossHorn = _wav(b)
	# mancınık: kol gıcırtısı, vınlama ve uzaktan tok düşüş
	b = _buf(1.0)
	lp = 0.0
	for i in int(0.18 * RATE):
		var t := float(i) / RATE
		b[i] += sin(TAU * (140.0 + 60.0 * sin(TAU * 30.0 * t)) * t) * 0.25 * sin(PI * t / 0.18)
	for i in range(int(0.15 * RATE), int(0.6 * RATE)):
		var t := float(i) / RATE - 0.15
		lp += ((rng.randf() * 2.0 - 1.0) - lp) * (0.05 + 0.25 * sin(PI * t / 0.45))
		b[i] += lp * sin(PI * t / 0.45) * 0.7
	sfx.throw = _wav(b)
	# fil: genizden gelen, titreşimli, yükselen boru sesi
	b = _buf(1.1)
	var ph := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := lerpf(330.0, 620.0, minf(1.0, t / 0.35)) * (1.0 + 0.04 * sin(TAU * 22.0 * t)) * (1.0 - 0.15 * maxf(0.0, t - 0.7))
		ph = fmod(ph + f / RATE, 1.0)
		var saw := ph * 2.0 - 1.0
		var c := 2.0 * 0.96 * cos(TAU * 1400.0 / RATE)
		var o := saw + c * y1 - 0.9216 * y2
		y2 = y1
		y1 = o
		var env := minf(1.0, t * 12.0) * minf(1.0, (1.1 - t) * 5.0)
		b[i] = (saw * 0.4 + o * 0.06) * env * 0.6
	sfx.trumpet = _wav(b)
	# kuşatma kulesinin kapağı: zincir şakırtısı ve ahşap gümlemesi
	b = _buf(0.8)
	for k in 7:
		_tink(b, k * 0.05, 1800.0 + rng.randf() * 900.0, 0.12)
	_drum(b, 0.42, 95.0, 0.35, 0.6, 1.0)
	sfx.gate = _wav(b)
	# görev ve başarım: iki küçük zil
	b = _buf(1.2)
	_bell(b, 0.0, 1046.0, 0.9, 0.18)
	_bell(b, 0.14, 1568.0, 1.0, 0.16)
	sfx.chime = _wav(b)
	# medresede araştırma bitti: derin çan
	b = _buf(2.2)
	_bell(b, 0.0, 392.0, 2.0, 0.28)
	_bell(b, 0.5, 587.0, 1.6, 0.18)
	sfx.research = _wav(b)
	# Barbaros: gemi çanı, boru ve uzaktan top yaylımı
	b = _buf(2.4)
	_bell(b, 0.0, 880.0, 0.8, 0.2)
	_bell(b, 0.3, 880.0, 0.8, 0.2)
	_boru(b, 0.5, 57.0, 0.7, 0.18)
	for k in 3:
		_drum(b, 1.1 + k * 0.28, 46.0, 0.7, 0.55, 0.9)
	sfx.hero_barbaros = _wav(b)
	# Mimar Sinan: taş keskisi ve çekiç vuruşları
	b = _buf(1.2)
	for k in 5:
		_tink(b, k * 0.17, 2100.0 + (k % 2) * 400.0, 0.3)
		_drum(b, k * 0.17, 260.0, 0.12, 0.35, 0.9)
	sfx.hero_sinan = _wav(b)
	# Evliya Çelebi: neyden yükselen bir ezgi
	b = _buf(1.8)
	var up := [62, 66, 67, 69]
	for k in up.size():
		_ney(b, k * 0.3, up[k] + 12, 0.42 if k < up.size() - 1 else 0.85, 0.22)
	sfx.hero_evliya = _wav(b)
	# dalga başı: davul gümbürtüsü
	b = _buf(1.4)
	for k in 8:
		_drum(b, k * 0.11, 70.0, 0.35, 0.35 + k * 0.06, 0.4)
	_cymbal(b, 0.9, 0.5, 0.35)
	sfx.waveStart = _wav(b)
	# zafer: yükselen ezgi
	b = _buf(1.6)
	var notes := [62, 63, 66, 67, 69, 74]
	for k in notes.size():
		_zurna(b, k * 0.18, notes[k], 0.3 if k < notes.size() - 1 else 0.6, 0.35)
	_drum(b, 0.9, 70.0, 0.5, 0.6)
	sfx.victory = _wav(b)
	# yenilgi: inen ezgi
	b = _buf(1.8)
	var down := [69, 67, 66, 63, 62]
	for k in down.size():
		_zurna(b, k * 0.3, down[k], 0.32, 0.3)
	sfx.defeat = _wav(b)
	sfx.chant = _wav(_chant(10))


# "Allah Allah!": her biri farklı perdede ve hafif gecikmeli seslerden oluşan kalabalık.
# Ünlüler iki biçimlendirici (formant) süzgeçle "a" sesine yaklaştırılır.
func _chant(voices: int) -> PackedFloat32Array:
	var b := _buf(2.0)
	var syll := [[0.0, 0.22], [0.26, 0.36], [0.82, 0.22], [1.08, 0.5]]  # Al-lah Al-lah
	for v in voices:
		var f0 := rng.randf_range(105.0, 190.0)
		var lag := rng.randf_range(0.0, 0.06)
		var ph := 0.0
		var y1 := 0.0
		var y2 := 0.0
		var z1 := 0.0
		var z2 := 0.0
		for sy in syll:
			var start := int((sy[0] + lag) * RATE)
			var n := int(sy[1] * RATE)
			var rise: float = 1.0 if sy == syll[1] or sy == syll[3] else 0.97
			for i in n:
				if start + i >= b.size():
					break
				var t := float(i) / RATE
				var f := f0 * lerpf(1.0, rise * 1.08, t / sy[1])
				ph += f / RATE
				var pulse := 1.0 if fmod(ph, 1.0) < 0.08 else 0.0
				# iki rezonans (800 Hz ve 1150 Hz civarı)
				var r1 := 0.97
				var c1 := 2.0 * r1 * cos(TAU * 780.0 / RATE)
				var o1 := pulse + c1 * y1 - r1 * r1 * y2
				y2 = y1
				y1 = o1
				var c2 := 2.0 * r1 * cos(TAU * 1180.0 / RATE)
				var o2 := pulse + c2 * z1 - r1 * r1 * z2
				z2 = z1
				z1 = o2
				var env := minf(1.0, t * 25.0) * minf(1.0, (sy[1] - t) * 12.0)
				b[start + i] += (o1 * 0.6 + o2 * 0.4) * env * 0.02
	return b


# ---------------------------------------------------------------- mehter marşı

# Dalgada tam takım (100 vuruş/dk): kös, davul, nakkare, zil, iki oktav zurna ve boru; son ölçüde kös
# gürlemesi. Hazırlıkta daha ağır (84 vuruş/dk): yumuşak davul ve ney ezgisi. Her ikisi 8 ölçü.
func _plan_mehter(j: Dictionary, full: bool) -> void:
	var beat := 60.0 / (100.0 if full else 84.0)
	var bars := 8
	_job_buf(j, bars * 4 * beat, 1.5, RATE)
	j.limit = true
	var s: Array = j.steps
	for bar in bars:
		var t0 := bar * 4 * beat
		if full:
			# kös: DÜM . tek DÜM . tek
			s.append([&"_drum", [t0, 58.0, 0.7, 0.9, 0.3]])
			s.append([&"_drum", [t0 + 2 * beat, 58.0, 0.6, 0.75, 0.3]])
			s.append([&"_drum", [t0 + 1.5 * beat, 220.0, 0.12, 0.35, 0.6]])
			s.append([&"_drum", [t0 + 3.5 * beat, 220.0, 0.12, 0.35, 0.6]])
			for k in 8:
				s.append([&"_drum", [t0 + k * beat * 0.5, 330.0, 0.07, 0.16 if k % 2 else 0.22, 0.9]])  # nakkare
			s.append([&"_cymbal", [t0 + 3 * beat, 0.7 if bar % 2 else 0.3, 0.3 if bar % 2 else 0.15]])
			if bar % 2 == 0:
				s.append([&"_boru", [t0, 50.0 if bar % 4 == 0 else 57.0, 3.0 * beat, 0.13]])
			if bar == bars - 1:
				for k in 8:
					s.append([&"_drum", [t0 + 2 * beat + k * beat * 0.25, 62.0, 0.3, 0.25 + k * 0.06, 0.4]])
		else:
			s.append([&"_drum", [t0, 62.0, 0.6, 0.5, 0.25]])
			s.append([&"_drum", [t0 + 2.5 * beat, 230.0, 0.1, 0.22, 0.5]])
			s.append([&"_drum", [t0 + 3 * beat, 62.0, 0.4, 0.3, 0.25]])
			if bar % 4 == 3:
				s.append([&"_cymbal", [t0 + 3 * beat, 0.9, 0.12]])
	var total := bars * 4 * beat
	if full:
		# [Hicaz basamağı, yarım vuruş sayısı]; 16 vuruşluk ezgi iki kez çalar, ikincisinde alt oktav eşlik eder
		var melody := [
			[0, 1], [4, 1], [5, 1], [7, 1], [8, 2], [7, 1], [5, 1],
			[4, 1], [5, 1], [4, 1], [1, 1], [0, 4],
			[7, 1], [8, 1], [10, 1], [12, 2], [10, 1], [8, 2],
			[7, 1], [5, 1], [4, 1], [5, 1], [4, 2], [1, 1], [0, 1],
		]
		var t := 0.0
		var round := 0
		while t < total - 0.01:
			for n in melody:
				if t >= total - 0.01:
					break
				var dur: float = n[1] * beat * 0.5
				s.append([&"_zurna", [t, 62.0 + n[0], dur * 0.95, 0.3]])
				if round % 2 == 1:
					s.append([&"_zurna", [t + 0.012, 49.95 + n[0], dur * 0.95, 0.15]])
				t += dur
			round += 1
	else:
		# ney: ağır, iki cümlelik ezgi (vuruş sayısıyla)
		var melody := [
			[7, 2], [8, 1], [7, 1], [5, 2], [4, 2], [5, 1], [4, 1], [1, 2], [0, 4],
			[0, 1], [1, 1], [4, 2], [5, 2], [7, 2], [8, 1], [10, 1], [8, 2], [7, 4],
		]
		var t := 0.0
		for n in melody:
			var dur: float = n[1] * beat
			s.append([&"_ney", [t, 74.0 + n[0], dur * 0.97, 0.14]])
			t += dur


# ---------------------------------------------------------------- arka plan döngüleri

# 8 saniyelik döngüler. Gürültü zemini parça parça (her adım yarım saniye) süzülür; süzgeç durumu
# adımlar arasında st sözlüğünde tutulur. Kuş, martı, damla gibi tekil sesler zeminin üstüne eklenir.
func _plan_ambience(j: Dictionary, id: String) -> void:
	var sec := 8.0
	var fade := 0.7
	_job_buf(j, sec, fade, AMB_RATE)
	j.cross = true
	var s: Array = j.steps
	var beds := []
	match id:
		"city":
			beds = [{"kind": "murmur", "amp": 0.5}, {"kind": "water", "amp": 0.06}]
		"harbor":
			beds = [{"kind": "waves", "amp": 0.45}, {"kind": "murmur", "amp": 0.22}]
		"field":
			beds = [{"kind": "breeze", "amp": 0.2}, {"kind": "murmur", "amp": 0.12}]
		"rain":
			beds = [{"kind": "rain", "amp": 0.3}]
		"wind":
			beds = [{"kind": "wind", "amp": 0.45}]
	for bed in beds:
		bed.merge({"lp": 0.0, "lp2": 0.0, "y1": 0.0, "y2": 0.0, "prev": 0.0, "voices": _voices(6)})
		var t := 0.0
		while t < sec + fade:
			s.append([&"_bed", [t, minf(sec + fade, t + 0.5), bed]])
			t += 0.5
	# tekil sesler dikişe denk gelmesin diye [fade, sec - 0.6] aralığına düşer
	var lo := fade
	var hi := sec - 0.6
	match id:
		"city":
			for k in 4:
				_birds(s, rng.randf_range(lo, hi), 0.08)
			for k in 2:
				var at := rng.randf_range(lo, hi - 0.5)
				s.append([&"_tink", [at, 1650.0, 0.08, AMB_RATE]])
				s.append([&"_tink", [at + 0.32, 1650.0, 0.07, AMB_RATE]])
			s.append([&"_chirp", [rng.randf_range(lo, hi), 1500.0, 1050.0, 0.32, 0.06, AMB_RATE, 0.5]])
		"harbor":
			for k in 3:
				var at := rng.randf_range(lo, hi - 0.8)
				for r in 1 + k % 3:
					s.append([&"_chirp", [at + r * 0.38, 1550.0, 1050.0, 0.3, 0.09, AMB_RATE, 0.5]])
			s.append([&"_bell", [rng.randf_range(lo, hi - 1.5), 660.0, 1.6, 0.07, AMB_RATE]])
		"field":
			for k in 6:
				_birds(s, rng.randf_range(lo, hi), 0.07)
			# uzaktan ordugâh davulu
			for k in 3:
				s.append([&"_drum_amb", [lo + 2.0 + k * 0.45, 0.18]])
		"rain":
			for k in 60:
				s.append([&"_chirp", [rng.randf_range(lo, hi), rng.randf_range(1800.0, 3200.0), rng.randf_range(900.0, 1500.0), 0.018, 0.08, AMB_RATE]])


func _voices(n: int) -> Array:
	var out := []
	for k in n:
		out.append([rng.randf_range(2.6, 4.8), rng.randf() * TAU, rng.randf_range(0.11, 0.3), rng.randf() * TAU])
	return out


func _birds(s: Array, at: float, amp: float) -> void:
	var f := rng.randf_range(2800.0, 3800.0)
	for r in rng.randi_range(2, 4):
		s.append([&"_chirp", [at + r * 0.09, f, f * rng.randf_range(1.1, 1.35), 0.055, amp, AMB_RATE]])


# Uzak davul: alçak geçirgen süzgeçten geçmiş gibi yumuşak bir gümleme
func _drum_amb(b: PackedFloat32Array, at: float, amp: float) -> void:
	var s := int(at * AMB_RATE)
	var ph := 0.0
	for i in int(0.5 * AMB_RATE):
		if s + i >= b.size():
			break
		var t := float(i) / AMB_RATE
		ph += TAU * 66.0 * (1.0 + exp(-t * 30.0)) / AMB_RATE
		b[s + i] += sin(ph) * exp(-t * 7.0) * amp


func _bed(b: PackedFloat32Array, from: float, to: float, st: Dictionary) -> void:
	var r := float(AMB_RATE)
	var amp: float = st.amp
	var lp: float = st.lp
	var lp2: float = st.lp2
	var y1: float = st.y1
	var y2: float = st.y2
	var prev: float = st.prev
	var voices: Array = st.voices
	# çarşı uğultusu için konuşma bölgesinde (~550 Hz) rezonans
	var c := 2.0 * 0.93 * cos(TAU * 550.0 / r)
	for i in range(int(from * r), mini(b.size(), int(to * r))):
		var t := i / r
		var x := rng.randf() * 2.0 - 1.0
		var v := 0.0
		match st.kind:
			"murmur":
				# birkaç kişinin hece hece konuşması: her ses kendi hızında açılıp kapanır
				var env := 0.15
				for vo in voices:
					var syl := maxf(0.0, sin(TAU * vo[0] * t + vo[1]))
					var talk := clampf(sin(TAU * vo[2] * t + vo[3]) * 2.0, 0.0, 1.0)
					env += syl * syl * talk * 0.3
				var o := x + c * y1 - 0.8649 * y2
				y2 = y1
				y1 = o
				lp += (o - lp) * 0.5
				v = lp * env * 0.12
			"water":
				# şadırvan: tiz, titrek akış
				var hp := x - prev
				prev = x
				lp += (rng.randf() - lp) * 0.02
				v = hp * (0.4 + lp)
			"waves":
				# iki dalga: 4 sn'de bir kabaran, kıyıda köpüren gürültü
				var sw := pow(0.5 + 0.5 * sin(TAU * t / 4.0 - PI / 2.0), 2.0)
				lp += (x - lp) * (0.03 + 0.12 * sw)
				v = lp * (0.25 + 1.6 * sw)
			"breeze":
				lp += (x - lp) * 0.04
				v = lp * (0.6 + 0.4 * sin(TAU * t / 8.0))
			"rain":
				lp += (x - lp) * 0.45
				var hp := lp - prev
				prev = lp
				v = (hp * 0.7 + lp * 0.3)
			"wind":
				# uğuldayan rüzgâr: yavaş kabaran gürültü ve üstünde gezinen ıslık
				var g := 0.45 + 0.55 * pow(0.5 + 0.5 * sin(TAU * t / 8.0), 1.5)
				lp += (x - lp) * 0.025
				var cw := 2.0 * 0.985 * cos(TAU * (420.0 + 160.0 * sin(TAU * t / 4.0)) / r)
				var o := x + cw * y1 - 0.970225 * y2
				y2 = y1
				y1 = o
				lp2 += (o - lp2) * 0.3
				v = (lp * 2.2 + lp2 * 0.012) * g
		b[i] += v * amp
	st.lp = lp
	st.lp2 = lp2
	st.y1 = y1
	st.y2 = y2
	st.prev = prev
