extends SceneTree

# Oyun mantığını görüntüsüz oynatır: kule kurar, şehri geliştirir, asker yetiştirir, 12 dalgayı koşturur.
# Kullanım: godot --headless --script tests/sim.gd
func _init() -> void:
	var g := Game.new()
	g.gold = 99999
	var spots := [[3, 3], [5, 4], [3, 9], [5, 9], [0, 1], [8, 6], [4, 7], [1, 10], [6, 11], [3, 1]]
	for id in ["school", "barracks", "archery", "hospital", "mosque", "court", "kitchen", "market"]:
		g.select_tile(GameData.BUILDINGS[id].slot[0], GameData.BUILDINGS[id].slot[1])
		assert(g.upgrade_building(id), "kurulamadı: " + id)
	for id in ["cavalry", "science", "religion"]:
		assert(g.upgrade_building(id), "kurulamadı: " + id)
	assert(g.upgrade_building("school"), "2. seviye Saray'sız kurulmalı")
	assert(not g.upgrade_building("school"), "saray sınırı çalışmadı")
	g.res = {"wood": 0, "iron": 0, "food": 0}
	assert(not g.upgrade_building("palace"), "Saray odun ve demirsiz yükseldi")
	assert(not g.train_troop("janissary"), "yemeksiz asker yetişti")
	g.res = {"wood": 9999, "iron": 9999, "food": 9999}
	assert(g.upgrade_building("palace"))
	assert(g.upgrade_building("school"))
	var types := ["archer", "tar", "cannon", "musket"]
	for i in spots.size():
		g.select_tile(spots[i][0], spots[i][1])
		g.build_tower(types[i % 4])
		g.upgrade_tower()
	print("kule: ", g.towers.size())
	print("eğitim ", g.training)
	for k in ["janissary", "archer", "sipahi", "sufi"]:
		while g.can_train(k):
			g.train_troop(k)
	g.gold = 300
	var t := 0.0
	var healed := 0
	while g.is_active() and t < 3000.0:
		if g.phase == "build":
			print("dalga ", g.wave, " bitti t=", int(t), " sur ", g.wall, " akçe ", g.gold, " asker ", g.units.size())
			g.start_wave()
		if g.can_charge():
			g.trigger_charge()
		g.step(0.03)
		for u in g.units:
			if u.healing:
				healed += 1
				break
		t += 0.03
	print("bitti: ", g.phase, " dalga ", g.wave, " sur ", g.wall, " akçe ", g.gold, " asker ", g.units.size(), " süre ", int(t), " hastanede geçen adım ", healed, " kaynak ", g.res)
	_countries()
	_stages()
	_heroes()
	_weather()
	_tech()
	_bosses()
	_progress()
	_duel()
	quit()


# Görevler ve başarımlar: sayım hesaba eklenir, eşik geçilince şeref bir kez verilir
func _progress() -> void:
	var D := GameData
	var p := Profiles.new()
	p.cfg = ConfigFile.new()
	p.login("Deneme")
	var msgs := p.record({"kills": 120, "towers": 3})
	assert(p.has_ach("novice"), "Acemi Komutan")
	assert(p.honor() == D.ACHIEVEMENTS.novice.honor + _quest_honor(p), "şeref: %d" % p.honor())
	assert(p.record({"kills": 1}).is_empty() or not p.has_ach("veteran"))
	var day := p.daily()
	assert(day.ids.size() == D.QUESTS_PER_DAY)
	p.win_stage("istanbul", 3)
	p.record({"wins": 1})
	assert(p.has_ach("conqueror") and p.has_ach("perfect"), "kuşatma başarımları")
	var g := Game.new()
	g.wave = 0
	g.start_wave()
	g.spawn_queue = []
	g.enemies = []
	g.step(0.03)
	assert(g.stats.waves == 1 and g.stats.streak == 1, "dalga sayımı")
	assert(p.leaderboard()[0].name == "Deneme")
	print("görevler tamam ", msgs)


func _quest_honor(p: Profiles) -> int:
	var n := 0
	var day := p.daily()
	for q in day.done:
		n += GameData.QUESTS[q].honor
	return n


# Patronlar: dalgaya eklenir; mancınık kuleyi susturur, fil askeri ezer, dev kule asker çıkarır
func _bosses() -> void:
	var D := GameData
	var g := Game.new()
	g.wave = 3
	g.start_wave()
	assert(g.spawn_queue[-1].type == "trebuchet", "4. dalgada mancınık yok")
	for kind in ["trebuchet", "elephant", "bossTower"]:
		g = Game.new()
		g.gold = 9999
		g.wave = 5
		g.phase = "wave"
		g.select_tile(3, 0)
		g.build_tower("archer")
		g._spawn_enemy(kind, "habsburg")
		var e: Dictionary = g.enemies[0]
		e.dist = 1.5
		g.units.append({"id": 999, "kind": "janissary", "def": D.TROOPS.janissary, "hp": 999.0, "max_hp": 999.0, "x": 1.5, "y": 2.0,
			"tx": 1.5, "ty": 2.0, "post": 3.0, "ready": true, "engaged": 0, "cooldown": 0.0, "swing": 0.0, "angle": 0.0,
			"moving": false, "dead": false, "flash": 0.0, "healing": false})
		var n0 := g.enemies.size()
		for i in 120:
			g.step(0.03)
			g.units[0].x = e.x
			g.units[0].y = e.y
		assert(g.first_boss() == e, "patron bulunamadı")
		match kind:
			"trebuchet":
				assert(g.towers[0].get("stun", 0.0) > 0.0, "kule susmadı")
			"elephant":
				assert(g.units[0].hp < 999.0, "fil ezmedi")
			"bossTower":
				assert(g.enemies.size() > n0, "kuleden asker çıkmadı")
		print("patron %s tamam" % kind)


# Medrese: kademe sırası, tek araştırma, etkiler
func _tech() -> void:
	var D := GameData
	var g := Game.new()
	g.gold = 99999
	assert(not g.can_research("powder1"), "Medrese'siz araştırma")
	assert(not g.upgrade_building("medrese"), "Mektep'siz Medrese")
	g.upgrade_building("school")
	assert(g.upgrade_building("medrese"))
	assert(not g.can_research("powder2"), "1. kademesiz 2. kademe")
	var t := {"type": "cannon", "level": 1}
	var before := g.tower_stats(t)
	assert(g.start_research("powder1"))
	assert(not g.can_research("arch1"), "aynı anda iki araştırma")
	for i in 400:
		g.step(0.03)
	assert(g.has_tech("powder1") and g.tower_stats(t).damage > before.damage, "Kara Barut")
	assert(g.tech_block("powder2") == "medrese", "2. kademe Medrese 2 ister")
	var w := g.max_wall
	g.research["arch1"] = true
	g.researching = {"id": "arch1", "time": 0.0}
	g.research.erase("arch1")
	g.step(0.03)
	assert(g.max_wall == w + D.TECH_FX.wall, "Kesme Taş")
	var c := g.building_cost("barracks")
	g.research["arch2"] = true
	assert(g.building_cost("barracks") < c, "Kemer ve Kubbe")
	print("medrese tamam")


# Hava: yağmur menzili kısar ve tüfeği yavaşlatır, kar düşmanı yavaşlatır; mevsimler dalgayla döner
func _weather() -> void:
	var D := GameData
	var g := Game.new()
	assert(g.season == "spring" and g.weather == "clear")
	assert(g.season_of(3) == "summer" and g.season_of(9) == "winter" and g.season_of(12) == "spring")
	var t := {"type": "musket", "level": 1}
	var clear := g.tower_stats(t)
	g.weather = "rain"
	var wet := g.tower_stats(t)
	assert(wet.range < clear.range and wet.rate > clear.rate, "yağmur etkisi")
	g.weather = "fog"
	assert(g.tower_stats(t).range < wet.range, "sis etkisi")
	var seen := {}
	for i in 200:
		g._roll_weather(10)
		seen[g.weather] = true
	assert(seen.has("snow") and not seen.has("rain"), "kış havaları: %s" % str(seen))
	g.set_stage("viyana")
	g.reset()
	assert(g.season == "winter" and g.weather == "snow")
	print("hava tamam")


# Kahramanlar: kapıdan çıkar, yeteneği dalgada çalışır, düşünce yeniden gelir
func _heroes() -> void:
	var D := GameData
	for id in D.HERO_ORDER:
		var g := Game.new()
		g.hero_id = id
		g.reset()
		for i in 40:
			g.step(0.03)
		var h = g.hero_unit()
		assert(h != null, "kahraman çıkmadı: " + id)
		assert(not g.can_hero(), "yetenek dalga dışında açık")
		g.wave = 3
		g.start_wave()
		for i in 400:
			g.step(0.03)
		g.wall = 10
		var hp_before := 0.0
		for e in g.enemies:
			hp_before += e.hp
		assert(g.can_hero(), "yetenek kullanılamıyor: " + id)
		g.use_hero()
		assert(g.hero_cd > 0.0)
		match id:
			"barbaros":
				assert(g.strikes.size() == D.HERO.barrage_count)
				for i in 100:
					g.step(0.03)
				assert(g.strikes.is_empty(), "gülleler düşmedi")
			"sinan":
				assert(g.wall == 10 + D.HERO.repair and g.fortify > 0.0)
			"evliya":
				assert(g.morale > 0.0 and g.troop_stats("hero").damage > D.HEROES.evliya.damage)
		h = g.hero_unit()
		g._kill_unit(h)
		g.step(0.03)
		assert(g.hero_unit() == null and g.hero_timer > 0.0, "kahraman düşmedi")
		print("kahraman %s tamam" % id)


# Sefer haritası: her kuşatmanın yolu kapıda biter, işçi alanlarına ve okçu sırasına değmez, kendini kesmez.
# Ardından her kuşatma sabit bir savunmayla oynatılır.
func _stages() -> void:
	var D := GameData
	for id in D.STAGE_ORDER:
		var st: Dictionary = D.STAGES[id]
		assert(st.picks.size() == st.nations.size(), "dalga ve devlet sayısı: " + id)
		assert(st.path.size() <= 12, "yol en fazla 12 nokta (zemin gölgelendiricisi 12 tutar): " + id)
		assert(st.path[-1] == [4, 12] and st.path[0][1] == -1, "yol başı/sonu: " + id)
		var g := Game.new()
		g.set_stage(id)
		g.reset()
		var cells := 0
		for i in st.path.size() - 1:
			var a: Array = st.path[i]
			var b: Array = st.path[i + 1]
			assert(a[0] == b[0] or a[1] == b[1], "yol köşegen: " + id)
			cells += maxi(absi(b[0] - a[0]), absi(b[1] - a[1]))
		# başlangıçtaki -1. satır tahtanın dışında
		assert(g.path_tiles.size() == cells, "yol kendini kesiyor: %s %d/%d" % [id, g.path_tiles.size(), cells])
		for c in g.cols:
			if c != 4:
				assert(not g.is_path_tile(c, 11), "yol okçu sırasına giriyor: " + id)
		assert(g.total_waves == st.picks.size())
		assert(g.wave_nation(0) == st.nations[0] or st.nations[0] == g.country)
		g.gold = 99999
		g.res = {"wood": 9999, "iron": 9999, "food": 9999}
		for b in ["school", "barracks", "archery", "science", "hospital", "mosque"]:
			g.upgrade_building(b)
		var n := 0
		for r in range(0, 11):
			for c in g.cols:
				if n < 12 and not g.is_path_tile(c, r) and not g.is_work_site(c, r) and (g.is_path_tile(c, r - 1) or g.is_path_tile(c, r + 1)):
					g.select_tile(c, r)
					g.build_tower(["archer", "cannon", "musket", "tar"][n % 4])
					g.upgrade_tower()
					n += 1
		for k in ["janissary", "archer", "sufi"]:
			while g.can_train(k):
				g.train_troop(k)
		var t := 0.0
		while g.is_active() and t < 3000.0:
			if g.phase == "build":
				g.start_wave()
			g.step(0.03)
			t += 0.03
		print("kuşatma %s: %s dalga %d/%d sur %d/%d yıldız %d" % [id, g.phase, g.wave, g.total_waves, g.wall, g.max_wall, D.stage_stars(g.wall, g.max_wall)])
	print("sefer tamam")


# Devlet ve hükümdar üstünlükleri: her devlet kendi bonusunu alır, kendi adı dalgalarda düşman olarak çıkmaz
func _countries() -> void:
	var D := GameData
	for c in D.COUNTRY_ORDER:
		var g := Game.new()
		g.country = c
		g.king_level = 3
		g.reset()
		for i in D.WAVES.size():
			assert(D.wave_nation(i, c) != c, "kendi devletine saldırıyor: " + c)
		var t := {"type": "archer", "level": 1}
		var base := D.tower_stats("archer", 1, g.tower_bonus("archer"))
		match D.COUNTRIES[c].bonus:
			"wall":
				assert(g.wall == D.RULES.start_wall + 9, "sur bonusu")
			"gold":
				assert(g.gold == D.RULES.start_gold + D.KING.start_gold * 3, "akçe bonusu")
			"rate":
				assert(g.tower_stats(t).rate < base.rate, "atış hızı bonusu")
			"tower_damage":
				assert(base.damage > D.TOWERS.archer.damage, "hasar bonusu")
			"range":
				assert(base.range > D.TOWERS.archer.range, "menzil bonusu")
			"troops":
				assert(g.troop_stats("janissary").hp > D.TROOPS.janissary.hp, "asker bonusu")
		assert(D.king_text(c, 3) != "", "kral metni")
	print("devletler tamam")


# Düello: iki oyun doğrudan bağlanır. Güçlü taraf yendiği düşmanlarla zayıfa asker yollar; zayıfın
# surları düşünce iki taraf da sonucu bilir. 12. dalgadan sonra dalgalar dönerek sürer.
func _duel() -> void:
	var D := GameData
	assert(D.ACHIEVEMENTS.size() == D.ACHIEVEMENT_ORDER.size())
	var ga := Game.new()
	var gb := Game.new()
	var la := DuelLink.new("a1", "Ali", "ottoman")
	var lb := DuelLink.new("b2", "Veli", "hungary")
	var inbox_a := []
	var inbox_b := []
	la.outgoing.connect(func(m): inbox_b.append(m.duplicate(true)))
	lb.outgoing.connect(func(m): inbox_a.append(m.duplicate(true)))
	var seeds := []
	for pair in [[la, ga, 12, "hungary"], [lb, gb, 2, "ottoman"]]:
		var l: DuelLink = pair[0]
		var g: Game = pair[1]
		l.started.connect(func(sd):
			seeds.append(sd)
			g.duel_state.nation = pair[3]
			g.set_duel(true)
			g.reset()
			g.gold = 99999
			g.res = {"wood": 9999, "iron": 9999, "food": 9999}
			for b in ["school", "barracks", "archery", "hospital"]:
				g.upgrade_building(b)
			var n := 0
			for r in range(0, 11):
				for c in g.cols:
					if n < pair[2] and not g.is_path_tile(c, r) and not g.is_work_site(c, r) and (g.is_path_tile(c, r - 1) or g.is_path_tile(c, r + 1)):
						g.select_tile(c, r)
						g.build_tower(["archer", "cannon", "musket", "tar"][n % 4])
						g.upgrade_tower()
						n += 1
			g.gold = 200
			l.game = g)
		l.begin("ABCD")
	var t := 0.0
	var max_b_queue := 0
	while t < 4000.0 and not (la.state == "over" and lb.state == "over"):
		for l in [la, lb]:
			l.tick(0.05)
		for m in inbox_a:
			la.handle(m)
		for m in inbox_b:
			lb.handle(m)
		inbox_a.clear()
		inbox_b.clear()
		for l in [la, lb]:
			if l.state == "playing" or (l.state == "over" and l.game.is_active()):
				l.game.step(0.05)
		t += 0.05
	assert(seeds.size() == 2 and seeds[0] == seeds[1], "iki taraf aynı tohumla başlamalı: %s" % str(seeds))
	assert(la.host() and not lb.host())
	assert(gb.duel_state.got > 0, "güçlü taraf asker yollamadı")
	assert(ga.duel_state.sent + gb.duel_state.got > 0)
	assert(lb.result == "lose" and la.result == "win", "sonuç: %s / %s" % [la.result, lb.result])
	assert(ga.phase == "won" and gb.phase == "lost")
	assert(ga.stats.get("duel_wins", 0) == 1 and gb.stats.get("duel_wins", 0) == 0)
	print("düello: %.0f sn, A %d. dalga sur %d, B %d. dalga; B'ye %d asker gitti, A'ya %d" % [t, ga.wave, ga.wall, gb.wave, gb.duel_state.got, ga.duel_state.got])
	# dalgalar 12'den sonra da sürer
	var g := Game.new()
	g.set_duel(true)
	g.reset()
	for i in 30:
		assert(g.wave_groups(i).size() > 0)
	assert(g.wave_bosses(15).size() == 1)
	# oda kodu
	var rng := RandomNumberGenerator.new()
	assert(DuelLink.make_code(rng).length() == D.DUEL.code_len)
	print("düello tamam")
