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
var cam_board := Transform3D()
var cam_city := Transform3D()
var city_view := false
var city_pan := 0.0
var drag_from := Vector2.ZERO
var dragged := false
var cam_tween: Tween
var tilt: ShaderMaterial
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
var profiles: Profiles
var menu: MainMenu
var in_menu := true
var honored_wave := 0  # şerefi verilmiş son dalga
var debug_hero := ""  # `--hero=sinan` (geliştirme)
var net: Net  # Supabase: çevrimiçi sıralama ve düello odaları
var link: DuelLink  # süren düello (yoksa null)
var net_state := ""  # odanın bağlantı durumu
var debug_def: Game  # `--siege-demo`: aynı süreçte koşan sahte savunan
var debug_link: DuelLink


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
	# eski kayıtlarda yalnız açık/kapalı vardı
	audio.set_mode(save.get_value("settings", "sound_mode", 0 if save.get_value("settings", "sound", true) else 2))
	_build_tilt()
	ui = GameUI.new(game)
	ui.best_wave = save.get_value("game", "best_wave", 0)
	add_child(ui)
	ui.action.connect(_on_action)
	dust_mat = world.fire_mat.duplicate()
	dust_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	spark_mat = world.fire_mat
	_build_markers()
	_sync_buildings()
	_place_king("ottoman", 1)
	profiles = Profiles.new()
	net = Net.new()
	add_child(net)
	net.message.connect(func(m):
		if link:
			link.handle(m))
	net.status.connect(func(st):
		net_state = st
		_duel_status())
	menu = MainMenu.new(ui, models, profiles, net)
	menu.start.connect(_start_game)
	menu.duel_join.connect(_duel_join)
	menu.duel_cancel.connect(_duel_leave)
	add_child(menu)
	ui.visible = false
	town = Town.new()
	town.setup(models, game, world)
	add_child(town)
	get_viewport().size_changed.connect(_fit_camera)
	await get_tree().process_frame
	_fit_camera()
	_debug_hooks()


# ---------------------------------------------------------------- menü ve hükümdar

# Saray önünde duran hükümdar: seçilen devletin kralı, seviyesine göre süslü
func _place_king(country: String, level: int) -> void:
	if sultan:
		sultan.root.queue_free()
	sultan = models.king(country, level)
	sultan.root.position = world.to_world(4.5, 13.55)
	sultan.anim.play("Idle")
	add_child(sultan.root)


func _start_game(country: String, level: int, stage := "", duel := false, pvp := "") -> void:
	if not duel and pvp == "":
		_duel_leave()
	game.country = country
	game.king_level = level
	game.set_stage(stage)
	game.duel = false
	game.pvp = ""
	if duel:
		game.duel_state.nation = link.opp.get("country", "")
		game.set_duel(true)
	elif pvp != "":
		game.pvp_state.nation = link.opp.get("country", "")
		game.set_pvp(pvp)
	game.hero_id = "" if pvp == "attack" else (debug_hero if debug_hero != "" else profiles.hero())
	if world.path_key != game.map_key():
		_rebuild_world()
	models.set_player_flag(country)
	_place_king(country, level)
	ui.set_country(country)
	ui.best_wave = profiles.get_v("best_wave", 0) if profiles.current != "" else ui.best_wave
	_restart()
	in_menu = false
	ui.visible = true
	set_city_view(false)
	if pvp == "attack":
		game.banner("%s'in kalesine saldır!" % link.opp.get("name", "Rakip"), "#e0b24a", 2.6)
	elif pvp == "defend":
		game.banner("%s saldırıyor, kaleni koru!" % link.opp.get("name", "Rakip"), "#e0b24a", 2.6)
	elif game.duel:
		game.banner("Düello: %s" % link.opp.get("name", "Rakip"), "#e0b24a", 2.4)
	elif game.stage_id != "":
		game.banner("%s Kuşatması" % game.stage.name, "#e0b24a", 2.4)
	else:
		game.banner(D.ruler_name(country), "#e0b24a", 2.4)


# Kuşatmanın yolu farklıysa zemin, çim, süsler ve ordugâh yeni yola göre baştan kurulur
func _rebuild_world() -> void:
	var tod := world.time_of_day
	world.queue_free()
	world = World.new()
	add_child(world)
	world.time_of_day = tod
	world.setup(models, game)
	town.world = world
	spark_mat = world.fire_mat


# Savaşın sayımını hesaba aktarır; tamamlanan görev ve başarımlar ekranın üstünde duyurulur
func _flush_stats() -> void:
	if game.stats.is_empty():
		return
	for msg in profiles.record(game.stats):
		ui.toast(msg)
		audio.play("chime")
	game.stats = {}
	_submit_score()


# Hesabın satırını çevrimiçi sıralamaya yazar (sunucu ayarlı değilse hiçbir şey yapmaz)
func _submit_score() -> void:
	if not Net.configured() or profiles.current == "":
		return
	var p := profiles
	net.submit({"device": _device(), "name": p.current, "honor": p.get_v("honor_total", p.honor()), "stars": p.stars_total(),
		"best_wave": p.get_v("best_wave", 0), "duel_wins": p.stats().get("duel_wins", 0),
		"updated_at": Time.get_datetime_string_from_system(true) + "Z"})


# Bu cihazın kalıcı kimliği (sıralamada aynı adlı başka cihazların satırını ezmemek için)
func _device() -> String:
	var d: String = save.get_value("settings", "device", "")
	if d == "":
		var r := RandomNumberGenerator.new()
		r.randomize()
		d = "%08x%08x" % [r.randi(), r.randi()]
		save.set_value("settings", "device", d)
		save.save(SAVE_PATH)
	return d


# ---------------------------------------------------------------- düello

func _duel_join(code: String, creator := true, mode := "duel", role := "") -> void:
	_duel_leave()
	var r := RandomNumberGenerator.new()
	r.randomize()
	link = DuelLink.new("%s-%06d" % [_device(), r.randi() % 1000000], profiles.current, profiles.country())
	link.outgoing.connect(net.send)
	link.started.connect(_duel_start)
	link.changed.connect(_duel_status)
	link.begin(code, creator, mode, role)
	net_state = ""
	net.join(code)
	_duel_status()


func _duel_leave() -> void:
	if link:
		link.leave()
		link = null
	net.leave()


func _duel_start(sd: int) -> void:
	seed(sd)
	link.game = game
	menu.visible = false
	if link.mode == "siege":
		_start_game(profiles.country(), profiles.king_level(profiles.country()), "", false, link.role)
	else:
		_start_game(profiles.country(), profiles.king_level(profiles.country()), "", true)


# Menüdeki bekleme satırı
func _duel_status() -> void:
	if link == null or link.state != "waiting":
		return
	var t := ""
	if net_state == "error" or net_state == "closed":
		t = "Sunucuya bağlanılamadı. İnternetini kontrol edip yeniden dene."
	elif not net.joined:
		t = "Sunucuya bağlanılıyor…"
	elif link.opp.has("id"):
		var r := {"attack": " Sen saldıransın.", "defend": " Sen savunansın."}.get(link.role, "") as String
		t = "Rakip bulundu: %s.%s Başlıyor…" % [link.opp.name, r]
	else:
		t = "Oda kodu %s. Rakibin bu kodla katılsın; bekleniyor…" % link.room
	menu.duel_status(t)


func _open_menu(map := false) -> void:
	_flush_stats()
	in_menu = true
	ui.visible = false
	ui.overlay.visible = false
	ui.tech.visible = false
	game.selected = null
	menu.open(map)


# Her püskürtülen dalga için dalga × honor_per_wave şeref, zaferde ayrıca honor_win
func _award_honor() -> void:
	var n := 0
	var cleared: int = game.wave if game.phase == "build" or game.phase == "won" else game.wave - 1
	while honored_wave < cleared:
		honored_wave += 1
		n += honored_wave * D.KING.honor_per_wave
	var stage_note := ""
	if game.pvp != "" and (game.phase == "won" or game.phase == "lost") and honored_wave <= game.total_waves:
		honored_wave = game.total_waves + 1
		n += D.PVP.honor_win if game.phase == "won" else D.PVP.honor_lose
	elif game.duel and (game.phase == "won" or game.phase == "lost") and honored_wave <= game.total_waves:
		honored_wave = game.total_waves + 1
		n += D.DUEL.honor_win if game.phase == "won" else D.DUEL.honor_lose
	elif game.phase == "won" and honored_wave <= game.total_waves:
		honored_wave = game.total_waves + 1
		if game.stage_id != "":
			var stars := D.stage_stars(game.wall, game.max_wall)
			var first := profiles.win_stage(game.stage_id, stars)
			game.stat("wins")
			stage_note = "%d/3 yıldız" % stars + (" · ilk zafer +%d şeref" % first if first > 0 else "")
			var i := D.STAGE_ORDER.find(game.stage_id)
			if first > 0 and i + 1 < D.STAGE_ORDER.size():
				stage_note += "\nSıradaki kuşatma açıldı: %s" % D.STAGES[D.STAGE_ORDER[i + 1]].name
		else:
			n += D.KING.honor_win
			game.stat("free_wins")
	if n > 0:
		profiles.add_honor(n)
	_flush_stats()
	if n > 0 or stage_note != "":
		ui.honor_note = (stage_note + "\n" if stage_note != "" else "") + "Toplam şeref: %d (hükümdarını menüden geliştir)" % profiles.honor()
		game.text(4.5, 12.6, "+%d şeref" % n, "#e0b24a")


# ---------------------------------------------------------------- kamera

# İki görünüş: savaş (tahtanın tamamı, ordugâh dahil) ve şehir (surların içi yakından).
func _fit_camera() -> void:
	var board: Array[Vector3] = []
	for x in [-game.cols / 2.0 - 0.1, game.cols / 2.0 + 0.1]:
		for z in [-game.rows / 2.0 - 1.6, game.rows / 2.0 + 0.3]:
			for y in [0.0, 1.0]:
				board.append(Vector3(x, y, z))
	var city: Array[Vector3] = []
	var wz: float = game.wall_row - game.rows / 2.0
	# şehir görünüşü dar tutulur (yaklaşık 5,5 kare); kalanı parmakla sağa sola kaydırılır
	for x in [-2.8, 2.8]:
		for z in [wz - 0.1, game.rows / 2.0 + 0.2]:
			for y in [0.0, 0.5]:
				city.append(Vector3(x, y, z))
	cam_city = _fit(city, 60.0, Vector3(0, 0, wz + 2.0))
	cam_board = _fit(board, 54.0, Vector3(0, 0, 0.3))
	camera.transform = _city_cam() if city_view else cam_board
	cam_base = camera.transform
	_update_tilt()


func set_city_view(on: bool) -> void:
	if on == city_view:
		return
	city_view = on
	ui.set_view_label(on)
	shake = 0.0
	city_pan = 0.0
	cam_base = _city_cam() if on else cam_board
	_update_tilt()
	if cam_tween:
		cam_tween.kill()
	cam_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	cam_tween.tween_property(camera, "transform", cam_base, 0.8)


# Minyatür etkisi katmanı (arayüzün altında): üst ve alt kenarı bulanıklaştırır
func _build_tilt() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tilt = ShaderMaterial.new()
	tilt.shader = preload("res://shaders/tiltshift.gdshader")
	r.material = tilt
	layer.add_child(r)


func _update_tilt() -> void:
	var hgt := get_viewport().get_visible_rect().size.y
	var y0 := ui.top_bottom() / hgt
	var y1 := ui.panel_top() / hgt
	var band := y1 - y0
	if city_view:
		tilt.set_shader_parameter("focus_top", y0 + band * 0.3)
		tilt.set_shader_parameter("focus_bottom", y0 + band * 0.78)
	else:
		tilt.set_shader_parameter("focus_top", y0 + band * 0.16)
		tilt.set_shader_parameter("focus_bottom", y1 + 0.2)


func _city_cam() -> Transform3D:
	var t := cam_city
	t.origin.x += city_pan
	return t


# Verilen noktalar üst şerit ile alt panelin arasına sığacak uzaklık ve kaydırma.
func _fit(corners: Array[Vector3], pitch_deg: float, target: Vector3) -> Transform3D:
	var pitch := deg_to_rad(pitch_deg)
	var dir := Vector3(0, sin(pitch), cos(pitch))
	var vs := get_viewport().get_visible_rect().size
	var y0 := ui.top_bottom() + 6.0
	var y1 := ui.panel_top() - 6.0
	if y1 - y0 < 100.0:
		y0 = 0.0
		y1 = vs.y
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
	return camera.transform


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
	if in_menu or game.pvp == "attack":
		hover_tile.visible = false
		return
	if event is InputEventMouseMotion:
		var t := _tile_under(event.position)
		var ok := t.y >= 0 and t.y < game.wall_row and t.x >= 0 and t.x < game.cols and not game.is_path_tile(t.x, t.y) and not game.is_work_site(t.x, t.y)
		hover_tile.visible = ok and game.tower_at(t.x, t.y) == null
		if ok:
			hover_tile.position = world.to_world(t.x + 0.5, t.y + 0.5, 0.012)
		# şehir görünüşünde basılı sürükleme kamerayı kaydırır
		if city_view and event.button_mask & MOUSE_BUTTON_MASK_LEFT and not (cam_tween and cam_tween.is_running()):
			if event.position.distance_to(drag_from) > 12.0:
				dragged = true
			if dragged:
				var k: float = cam_city.origin.y / get_viewport().get_visible_rect().size.x * 1.4
				city_pan = clampf(city_pan - event.relative.x * k, -1.9, 1.9)
				camera.transform = _city_cam()
				cam_base = camera.transform
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_from = event.position
			dragged = false
		elif not dragged:
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
			set_city_view(false)
		"view":
			set_city_view(not city_view)
		"pick_building":
			var s: Array = D.BUILDINGS[arg].slot
			game.select_tile(s[0], s[1])
		"speed":
			if game.pvp != "":
				return
			var list: Array = D.RULES.speeds
			game.speed = list[(list.find(game.speed) + 1) % list.size()]
		"charge":
			game.trigger_charge()
		"hero":
			game.use_hero()
		"tech":
			ui.toggle_tech()
		"research":
			game.start_research(arg)
		"sound":
			save.set_value("settings", "sound_mode", audio.cycle_mode())
			save.save(SAVE_PATH)
		"light":
			world.cycle_light()
			save.set_value("settings", "light", world.time_of_day)
			save.save(SAVE_PATH)
		"send":
			game.atk_send(arg, GameUI.atk_batch(arg))
		"army_up":
			game.upgrade_army(arg)
		"restart":
			if game.duel or game.pvp != "":
				_duel_leave()
				_open_menu()
				menu.show_duel()
			else:
				_restart()
		"menu":
			# süren düellodan çıkmak yenilgi sayılır; rakibe "bye" gider
			if game.duel and game.is_active():
				game.duel_end(false, "Düellodan çekildin")
				_award_honor()
			elif game.pvp != "" and game.is_active():
				game.pvp_end(false, "Savaştan çekildin")
				_award_honor()
			_duel_leave()
			_open_menu()
		"map":
			var was_duel := game.duel or game.pvp != ""
			_duel_leave()
			_open_menu(not was_duel)


func _restart() -> void:
	_flush_stats()
	for dict in [tower_nodes, enemy_nodes, unit_nodes, proj_nodes]:
		for id in dict:
			dict[id].info.root.queue_free()
		dict.clear()
	for id in bars:
		bars[id][0].queue_free()
	bars.clear()
	game.reset()
	honored_wave = 0
	ui.honor_note = ""
	_sync_buildings()


# ---------------------------------------------------------------- ana döngü

func _process(delta: float) -> void:
	if link:
		link.tick(delta)
	if debug_link:
		debug_link.tick(delta)
		if debug_link.state == "playing":
			if debug_def.pvp == "attack":
				debug_def.mirror_step(delta)
			else:
				debug_def.advance(delta)
	if in_menu:
		town.update(delta)
		# menüde şehir sesi ve ağır ney ezgisi
		audio.set_music("build")
		audio.set_boss(false)
		audio.set_ambience("city", "", false)
		return
	if game.pvp == "attack":
		game.mirror_step(delta)
		if not game.is_active():
			_award_honor()
	elif game.advance(delta) or game.phase == "lost" or (game.pvp != "" and game.phase == "won"):
		_save_best()
		_award_honor()
	_handle_events()
	_sync_towers(delta)
	_sync_enemies(delta)
	_sync_units(delta)
	_sync_projectiles()
	_sync_buildings()
	town.update(delta)
	_update_markers()
	if world.weather_key != game.season + "|" + game.weather:
		world.set_weather(game.season, game.weather, world.weather_key == "")
	audio.set_music("wave" if game.phase == "wave" else ("build" if game.phase == "build" else "off"))
	audio.set_boss(game.first_boss() != null)
	var wx := {"rain": "rain", "snow": "wind", "fog": "wind"}
	audio.set_ambience(game.stage.get("ambience", "city"), wx.get(game.weather, ""), game.phase == "wave")
	ui.duel_text = ""
	if link and link.opp.has("id"):
		var o: Dictionary = link.opp
		if game.pvp == "attack":
			ui.duel_text = "Savunan: %s · Sur %d/%d" % [o.name, game.wall, game.max_wall]
		elif game.pvp == "defend":
			ui.duel_text = "Saldıran: %s" % o.name
		elif game.duel:
			ui.duel_text = "Rakip: %s · Sur %d/%d · %d. dalga" % [o.name, o.wall, o.max_wall, o.wave]
		ui.duel_note = link.why
	ui.refresh(audio.mode_name(), world.light_name())
	if shake > 0.0 and not (cam_tween and cam_tween.is_running()):
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
		if profiles.current != "":
			profiles.set_v("best_wave", game.wave)


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
		# taşla susturulan kule hafifçe yana yatar
		info.root.rotation.z = lerpf(info.root.rotation.z, 0.12 if t.get("stun", 0.0) > 0.0 else 0.0, minf(1.0, dt * 8.0))
		if t.recoil > 0.9 and rec.recoil <= 0.0 and info.has("muzzle"):
			_muzzle(info)
		rec.recoil = t.recoil
		# Saldıran ve Savunan'da kulelerin canı azalır
		var frac: float = t.get("hp", 1.0) / t.get("max_hp", 1.0)
		_bar(t.id, info.root.position + Vector3(0, 1.25, 0), frac, Color("#e0b24a") if frac > 0.4 else Color("#ff5b4d"), frac < 0.999)
	for id in tower_nodes.keys():
		if not seen.has(id):
			var root: Node3D = tower_nodes[id].info.root
			_burst(root.position + Vector3(0, 0.1, 0), Color(0.85, 0.75, 0.55, 0.7), 18, 1.0, 0.2, 0.7, 0.3)
			if game.pvp == "attack":
				# saldıranın ekranında yıkılan kule
				_burst(root.position + Vector3(0, 0.3, 0), Color(0.55, 0.48, 0.4, 0.8), 30, 2.0, 0.25, 0.9, -1.0)
				audio.play("crash")
				shake = 0.15
			root.queue_free()
			tower_nodes.erase(id)
			_drop_bar(id)


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
		if not moving and e.blocker is Dictionary:
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
		# patron canlandırmaları: mancınık kolu savrulur, fil hortumunu kaldırır, dev kule köprüsünü indirir
		if info.has("arm") and info.arm:
			info.arm.rotation.x = lerpf(-0.45, 1.6, sin(clampf(e.act, 0.0, 1.0) * PI))
		if info.has("trunk") and info.trunk:
			info.trunk.rotation.x = -0.9 * e.act + sin(t * 2.0) * 0.08
		if info.has("bridge") and info.bridge:
			var near: bool = e.dist > game.path_length - 1.6
			info.bridge.rotation.x = lerpf(info.bridge.rotation.x, 0.0 if near else -1.45, minf(1.0, dt * 2.0))
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
			var info := models.hero(game.hero_id) if u.kind == "hero" else models.troop(u.kind)
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
		_bar(u.id, root.position + Vector3(0, 0.72, 0), u.hp / u.max_hp, Color("#f2c94c"), u.hp < u.max_hp or u.kind == "hero")
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
			"fall":
				_cannonball(world.to_world(ev.x, ev.y), ev.time)
			"boulder":
				_boulder(world.to_world(ev.x0, ev.y0, 1.0), world.to_world(ev.x1, ev.y1, 0.5), ev.time)
			"blast":
				var bp := world.to_world(ev.x, ev.y, 0.2)
				_burst(bp, Color(2.4, 1.5, 0.6, 1.0), 26, 2.6, 0.14, 0.35, 0.0, true)
				_burst(bp, Color(0.5, 0.45, 0.4, 0.8), 14, 1.2, 0.35, 1.1, 0.6)
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.7, 0.35)
				l.omni_range = 2.6
				l.light_energy = 5.0
				l.position = bp + Vector3(0, 0.3, 0)
				add_child(l)
				var tw := create_tween()
				tw.tween_property(l, "light_energy", 0.0, 0.3)
				tw.tween_callback(l.queue_free)
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


# Top Yağmuru güllesi: denizden (sağ üstten) yay çizerek düşer
func _cannonball(target: Vector3, time: float) -> void:
	var n := _projectile_node("cannon")
	n.scale = Vector3.ONE * 2.2
	add_child(n)
	var from := target + Vector3(2.5, 6.0, -3.0)
	n.position = from
	var tw := create_tween()
	tw.tween_method(func(k: float):
		n.position = from.lerp(target, k) + Vector3(0, sin(k * PI) * 1.2, 0), 0.0, 1.0, time)
	tw.tween_callback(n.queue_free)


# Mancınık taşı: yüksek bir yayla kuleye düşer
func _boulder(from: Vector3, to: Vector3, time: float) -> void:
	var n := Node3D.new()
	var rock := models.sphere(n, 0.11, Vector3.ZERO, models.mat(Color("#7a6e62"), 0.9), false, 8)
	rock.scale = Vector3(1.0, 0.85, 1.1)
	add_child(n)
	n.position = from
	var tw := create_tween()
	tw.tween_method(func(k: float):
		n.position = from.lerp(to, k) + Vector3(0, sin(k * PI) * 2.2, 0)
		n.rotation.x = k * 8.0, 0.0, 1.0, time)
	tw.tween_callback(n.queue_free)


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
	# `--country=venice --king=3` ya da `--demo`/`--city` menüyü atlayıp doğrudan oyunu açar
	debug_hero = _arg(args, "--hero=", "")
	var cn := _arg(args, "--country=", "")
	# `--siege-demo` saldıranın ekranını açar; savunan aynı süreçte koşan ikinci bir oyundur
	# `--siege-defend`: savunanın ekranı; saldıran aynı süreçte koşan ve birlik yollayan bir görüntüdür
	if "--siege-defend" in args:
		if profiles.current == "":
			profiles.login("Ali")
		debug_def = Game.new()
		debug_link = DuelLink.new("b", "Veli", "hungary")
		link = DuelLink.new("a", profiles.current, "ottoman")
		link.outgoing.connect(func(m): debug_link.handle(JSON.parse_string(JSON.stringify(m))))
		debug_link.outgoing.connect(func(m):
			if link:
				link.handle(JSON.parse_string(JSON.stringify(m))))
		debug_link.started.connect(func(_s):
			debug_def.set_pvp("attack")
			debug_def.reset()
			debug_link.game = debug_def)
		link.started.connect(func(sd):
			_duel_start(sd)
			game.time = D.PVP.prep
			game.gold = 9999
			for spot in [[3, 3], [5, 4], [3, 9], [5, 9], [0, 1], [8, 6], [6, 2]]:
				game.select_tile(spot[0], spot[1])
				game.build_tower(["archer", "cannon", "musket", "tar"][randi() % 4])
			game.selected = null)
		link.begin("TEST", true, "siege", "defend")
		debug_link.begin("TEST", false)
		get_tree().create_timer(2.0).timeout.connect(func():
			debug_def.pvp_state.loot = 2000
			for k in ["trebuchet", "ram", "knight", "knight", "infantry", "light", "horseArcher"]:
				debug_def.atk_send(k, GameUI.atk_batch(k)))
		return
	if "--siege-demo" in args:
		if profiles.current == "":
			profiles.login("Ali")
		debug_def = Game.new()
		debug_link = DuelLink.new("b", "Veli", "hungary")
		link = DuelLink.new("a", profiles.current, "ottoman")
		link.outgoing.connect(func(m): debug_link.handle(JSON.parse_string(JSON.stringify(m))))
		debug_link.outgoing.connect(func(m):
			if link:
				link.handle(JSON.parse_string(JSON.stringify(m))))
		debug_link.started.connect(func(_s):
			var g := debug_def
			g.pvp_state.nation = "ottoman"
			g.set_pvp("defend")
			g.reset()
			g.time = D.PVP.prep + 1.0
			g.gold = 9999
			for spot in [[3, 3], [5, 4], [3, 9], [5, 9], [0, 1], [8, 6]]:
				g.select_tile(spot[0], spot[1])
				g.build_tower(["archer", "cannon", "musket", "tar"][randi() % 4])
			g.selected = null
			debug_link.game = g)
		link.started.connect(_duel_start)
		link.begin("TEST", true, "siege", "attack")
		debug_link.begin("TEST", false)
		get_tree().create_timer(2.5).timeout.connect(func():
			for k in ["knight", "infantry", "ram", "light"]:
				game.atk_send(k, GameUI.atk_batch(k)))
		return
	# `--duel` sahte bir rakiple düelloyu açar (yalnız görünüş; ileti gitmez)
	if "--duel" in args:
		link = DuelLink.new("a", profiles.current if profiles.current != "" else "Ali", "ottoman")
		link.begin("TEST")
		link.opp = {"id": "b", "name": "Veli", "country": "hungary", "wall": 14, "max_wall": 20, "wave": 3, "seen": 0.0, "playing": true}
		link.started.connect(_duel_start)
		link._play()
		return
	if cn != "" or "--demo" in args or "--city" in args or "--play" in args or _arg(args, "--stage=", "") != "":
		menu.visible = false
		_start_game(cn if cn != "" else "ottoman", int(_arg(args, "--king=", "1")), _arg(args, "--stage=", ""))
	elif "--login" in args:
		profiles.logout()
		menu.open()
	elif _arg(args, "--user=", "") != "":
		profiles.login(_arg(args, "--user=", ""))
		if _arg(args, "--honor=", "") != "":
			profiles.set_v("honor", int(_arg(args, "--honor=", "0")))
		if _arg(args, "--kings=", "") != "":
			var k := {}
			for c in D.COUNTRY_ORDER:
				k[c] = int(_arg(args, "--kings=", "1"))
			profiles.set_v("kings", k)
		menu.selected = _arg(args, "--pick=", profiles.country())
		if _arg(args, "--stars=", "") != "":
			var st := {}
			for id in D.STAGE_ORDER.slice(0, int(_arg(args, "--stars=", "0"))):
				st[id] = 1 + st.size() % 3
			profiles.set_v("stages", st)
		if "--fake-stats" in args:
			profiles.record({"kills": 260, "towers": 14, "boss_kills": 1, "waves": 7, "hero": 2})
			for n in ["Hasan", "Ayşe", "Kemal"]:
				profiles.cfg.set_value("hesap:" + n, "honor_total", n.length() * 137)
				profiles.cfg.set_value("hesap:" + n, "best_wave", n.length() * 2)
		if "--progress" in args:
			menu._show_progress()
		elif "--duel-menu" in args:
			menu.show_duel()
		elif "--map" in args:
			menu._show_campaign()
		else:
			menu._show_countries()
	for a in args:
		if a.begins_with("--light="):
			world.time_of_day = int(a.substr(8))
			world.apply_light(true)
	if "--city" in args:
		set_city_view(true)
		city_pan = float(_arg(args, "--pan=", "0"))
		cam_base = _city_cam()
		cam_tween.kill()
		camera.transform = cam_base
	if "--demo" in args:
		game.gold = 5000
		game.res = {"wood": 500, "iron": 500, "food": 500}
		for id in ["school", "medrese", "barracks", "archery", "hospital", "mosque", "court", "cavalry", "science", "religion", "kitchen", "workshop", "market"]:
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
	if _arg(args, "--weather=", "") != "":
		game.weather = _arg(args, "--weather=", "")
		game.season = _arg(args, "--season=", game.season)
	# `--bosses` üç patronu yolun üzerine dizer
	if "--bosses" in args:
		var k := 0
		for b in ["bossTower", "elephant", "trebuchet"]:
			game._spawn_enemy(b, game.nation)
			game.enemies[-1].dist = 4.0 + k * 5.0
			k += 1
	if "--tech" in args:
		game.upgrade_building("medrese")
		game.research = {"powder1": true, "arch1": true}
		game.gold = 400
		game.start_research("powder2")
		ui.toggle_tech()
	if "--use-hero" in args:
		get_tree().create_timer(float(_arg(args, "--hero-at=", "3"))).timeout.connect(game.use_hero)
	var sel := _arg(args, "--select=", "")
	if sel != "":
		var p := sel.split(",")
		game.select_tile(int(p[0]), int(p[1]))


func _arg(args: PackedStringArray, key: String, def: String) -> String:
	for a in args:
		if a.begins_with(key):
			return a.substr(key.length())
	return def
