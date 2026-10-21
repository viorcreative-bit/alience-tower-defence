extends SceneTree

# Oyun mantığını görüntüsüz oynatır: kule kurar, şehri geliştirir, asker yetiştirir, 12 dalgayı koşturur.
# Kullanım: godot --headless --script tests/sim.gd
func _init() -> void:
	var g := Game.new()
	g.gold = 99999
	var spots := [[3, 3], [5, 4], [3, 9], [5, 9], [0, 1], [8, 6], [4, 7], [1, 10], [6, 11], [3, 1]]
	for id in ["school", "barracks", "archery", "hospital", "mosque", "court", "kitchen"]:
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
	quit()
