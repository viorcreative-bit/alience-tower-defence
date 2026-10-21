class_name GameAudio
extends Node

# Bütün sesler kodda üretilir; hazır kayıt yok. Efektler açılışta, mehter marşı ise
# birkaç kareye bölünerek arka planda hazırlanır.

const RATE := 22050
const HICAZ := [0, 1, 4, 5, 7, 8, 10, 12]  # Hicaz dizisi (yarım ses adımları)

var enabled := true
var sfx := {}
var players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var music_build: AudioStreamWAV
var music_wave: AudioStreamWAV
var music_mode := "off"
var music_job := []  # sırayla hazırlanacak parçalar
var rng := RandomNumberGenerator.new()
var last_play := {}


func _ready() -> void:
	rng.seed = 7
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -7.0
	add_child(music_player)
	_make_sfx()
	music_job = ["build", "wave"]


func set_enabled(v: bool) -> void:
	enabled = v
	if not v:
		music_player.stop()
		for p in players:
			p.stop()
	else:
		var m := music_mode
		music_mode = ""
		set_music(m)


func play(id: String, opts := {}) -> void:
	if not enabled or not sfx.has(id):
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
	for p in players:
		if not p.playing:
			p.stream = sfx[id]
			var loud := opts.get("loud", 0) as float
			p.volume_db = _base_db(id) + (3.0 if loud > 0 else 0.0)
			p.pitch_scale = rng.randf_range(0.94, 1.06) if id != "chant" else 1.0
			p.play()
			return


func _base_db(id: String) -> float:
	match id:
		"archer", "tar":
			return -14.0
		"clash", "fall":
			return -11.0
		"chant":
			return -4.0
	return -6.0


func set_music(mode: String) -> void:
	if mode == music_mode:
		return
	music_mode = mode
	if not enabled:
		return
	var s: AudioStreamWAV = music_wave if mode == "wave" else (music_build if mode == "build" else null)
	if s == null:
		music_player.stop()
		return
	var pos := music_player.get_playback_position() if music_player.playing else 0.0
	music_player.stream = s
	music_player.play(fmod(pos, s.data.size() / 2.0 / RATE))


func _process(_dt: float) -> void:
	# marşları teker teker hazırla (web'de iş parçacığı yok)
	if music_job.size():
		var which: String = music_job.pop_front()
		var w := _wav(_mehter(which == "wave"), true)
		if which == "wave":
			music_wave = w
		else:
			music_build = w
		var m := music_mode
		music_mode = ""
		set_music(m)


# ---------------------------------------------------------------- dalga yardımcıları

func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
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


# Zil: filtrelenmiş gürültü
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
	var f0 := 440.0 * pow(2.0, (midi - 69.0) / 12.0)
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
	# top gümlemesi
	b = _buf(0.9)
	_drum(b, 0.0, 55.0, 0.9, 1.0, 1.0)
	sfx.boom = _wav(b)
	sfx.cannon = sfx.boom
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
				b[start + i] += (o1 * 0.6 + o2 * 0.4) * env * 0.028
	return b


# ---------------------------------------------------------------- mehter marşı

# 8 ölçülük döngü, 100 vuruş/dk. Hazırlıkta yalnız davul ve kısık zurna, dalgada tam takım.
func _mehter(full: bool) -> PackedFloat32Array:
	var bpm := 100.0
	var beat := 60.0 / bpm
	var bars := 8
	var b := _buf(bars * 4 * beat)
	for bar in bars:
		var t0 := bar * 4 * beat
		# kös: DÜM . tek DÜM . tek
		_drum(b, t0, 60.0, 0.6, 0.9 if full else 0.6, 0.3)
		_drum(b, t0 + 2 * beat, 60.0, 0.6, 0.8 if full else 0.5, 0.3)
		_drum(b, t0 + 1.5 * beat, 220.0, 0.12, 0.35, 0.6)
		_drum(b, t0 + 3.5 * beat, 220.0, 0.12, 0.35, 0.6)
		if full:
			for k in 8:
				_drum(b, t0 + k * beat * 0.5, 330.0, 0.07, 0.18, 0.9)  # nakkare
			if bar % 2 == 1:
				_cymbal(b, t0 + 3 * beat, 0.7, 0.3)
	var melody := [
		[0, 1, 1], [4, 1, 1], [5, 1, 1], [7, 1, 1], [8, 2, 1], [7, 1, 1], [5, 1, 1],
		[4, 1, 1], [5, 1, 1], [4, 1, 1], [1, 1, 1], [0, 4, 1],
		[7, 1, 1], [8, 1, 1], [10, 1, 1], [12, 2, 1], [10, 1, 1], [8, 1, 1],
		[7, 1, 1], [5, 1, 1], [4, 1, 1], [5, 1, 1], [4, 2, 1], [1, 1, 1], [0, 1, 1],
	]
	var t := 0.0
	var base := 62.0
	var amp := 0.32 if full else 0.12
	var total := bars * 4 * beat
	while t < total - 0.01:
		for n in melody:
			if t >= total - 0.01:
				break
			var dur: float = n[1] * beat * 0.5
			_zurna(b, t, base + n[0], dur * 0.95, amp)
			t += dur
	# yumuşak sınırlama
	for i in b.size():
		b[i] = tanh(b[i] * 0.9)
	return b
