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
	quit()


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
