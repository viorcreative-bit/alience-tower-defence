# Bütün modelleri üretir: assets/models/ottoman/*.glb
# Kullanım: python build.py [ad ...]   (bpy kurulu Python ile; pip install bpy)

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit
import bosses
import buildings
import chars
import city
import towers

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "ottoman")

ASSETS = {
	"archer_tower_1": lambda: towers.archer_tower(1),
	"archer_tower_2": lambda: towers.archer_tower(2),
	"archer_tower_3": lambda: towers.archer_tower(3),
	"burc_dome": lambda: towers.burc(True),
	"burc_open": lambda: towers.burc(False, r=0.25, h=0.82),
	"wall_segment": lambda: towers.wall_segment(),
	"tar_tower": towers.tar_tower,
	"cannon_tower": towers.cannon_tower,
	"musket_tower": towers.musket_tower,
	"gate": towers.gate,
	"camp_tent": lambda: towers.camp_tent("red"),
	"camp_tent_b": lambda: towers.camp_tent("iznik", "camp_tent_b"),
}
ASSETS.update(buildings.ALL)
ASSETS.update(city.ALL)


def _char(name):
	f, hold = chars.TYPES[name]
	c = chars.Char(name)
	f(c)
	return chars.build_char(c, hold)


for _n in chars.TYPES:
	ASSETS["ch_" + _n] = (lambda n: lambda: _char(n))(_n)
ASSETS["horse"] = chars.horse
ASSETS["boss_trebuchet"] = bosses.trebuchet
ASSETS["boss_elephant"] = bosses.elephant
ASSETS["boss_tower"] = bosses.siege_ram


def main(names):
	os.makedirs(OUT, exist_ok=True)
	for name in names or ASSETS:
		t0 = time.time()
		kit.reset()
		ASSETS[name]()
		kit.bake_ao(list(kit.bpy.context.scene.objects))
		path = os.path.abspath(os.path.join(OUT, name + ".glb"))
		kit.export(path)
		tris = sum(len(o.data.loop_triangles) if o.data.calc_loop_triangles() is None else 0 for o in kit.bpy.context.scene.objects if o.type == "MESH")
		print("%-20s %6d üçgen  %.1f sn" % (name, tris, time.time() - t0))


if __name__ == "__main__":
	main(sys.argv[1:])
