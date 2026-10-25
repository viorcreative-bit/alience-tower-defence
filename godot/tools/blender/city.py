# Kale içi süsleri: şadırvan köşkü, çarşı çadırları, cumbalı evler, bahçeler, servi kümeleri, fener,
# sandık-fıçı yığınları, top ve sehpa. Her biri bir kareye (1x1) sığar; ön -Y (Godot +Z).
# Su yüzeyleri "Water" adlı ayrı örgüdür (oyunda parlak su malzemesi verilir).

import math

import arch
from kit import P, Builder, empty, jitter, mix, mul, srgb

GRASS = srgb("#6f9a45")
GRASS_D = srgb("#4f7d36")
CYP = srgb("#2f5e30")
CYP_L = srgb("#3f7a3c")
WATER = srgb("#3f86b8")
FLOWERS = [srgb("#d6455a"), srgb("#f2c94c"), srgb("#f0e8f4"), srgb("#c25ab8"), srgb("#f08a3c")]


def round_paving(b, r, rings=3, col=None):
	"""Dairesel taş döşeme: halka halka kesme taş."""
	for k in range(rings):
		r0 = r * k / rings
		r1 = r * (k + 1) / rings
		n = max(6, int((r0 + r1) * math.pi / 0.09))
		for i in range(n):
			a = (i + 0.5 * (k % 2)) * 2 * math.pi / n
			rm = (r0 + r1) / 2
			w = 2 * math.pi * rm / n - 0.006
			c = jitter(col or mix(P["stone_light"], P["stone_grey"], 0.5 if k % 2 else 0.2), 0.05, b.rng)
			b.box((math.cos(a) * rm, math.sin(a) * rm, 0.006), (r1 - r0 - 0.006, max(0.02, w), 0.012), c, rot=(0, 0, a), bevel=0.003)


def cypress(b, x, y, h, r=0.055):
	b.cyl((x, y, 0), 0.012, 0.016, 0.06, P["wood_dark"], seg=5)
	b.lathe([(r * 0.6, 0.0), (r, h * 0.2), (r * 0.95, h * 0.5), (r * 0.6, h * 0.8), (0.0, h)], (x, y, 0.05), jitter(CYP, 0.08, b.rng), seg=8, smooth=False, ribs=(CYP_L, 2))


def lantern(b, x, y, h=0.42):
	b.box((x, y, 0.015), (0.05, 0.05, 0.03), P["stone_dark"])
	b.cyl((x, y, 0.03), 0.01, 0.008, h, P["iron"], seg=6, mat=1)
	b.cyl((x, y, h + 0.01), 0.028, 0.024, 0.06, P["fire"], seg=6, mat=2)
	for i in range(4):
		a = i * math.pi / 2 + math.pi / 4
		b.box((x + math.cos(a) * 0.026, y + math.sin(a) * 0.026, h + 0.04), (0.006, 0.006, 0.065), P["iron"], mat=1)
	b.lathe([(0.04, 0.0), (0.0, 0.05)], (x, y, h + 0.07), P["iron"], seg=6, mat=1, smooth=False)


def fountain():
	"""Şadırvan köşkü: basamaklı yuvarlak platform, mermer havuz, sekiz sütun, çini kuşak, kurşun kubbe."""
	b = Builder("city_fountain", 501)
	round_paving(b, 0.48, rings=4)
	b.cyl((0, 0, 0), 0.38, 0.38, 0.04, P["stone_dark"], seg=8)
	b.cyl((0, 0, 0.04), 0.34, 0.34, 0.03, P["stone"], seg=8)
	b.cyl((0, 0, 0.07), 0.27, 0.28, 0.09, P["white"], seg=8)
	for i in range(8):
		a = i * math.pi / 4 + math.pi / 8
		b.box((math.cos(a) * 0.28, math.sin(a) * 0.28, 0.115), (0.012, 0.18, 0.07), P["stone_light"], rot=(0, 0, a))
	b.cyl((0, 0, 0.16), 0.06, 0.07, 0.1, P["white"], seg=8)
	b.cyl((0, 0, 0.26), 0.09, 0.05, 0.03, P["white"], seg=8)
	# musluklar
	for i in range(8):
		a = i * math.pi / 4
		b.box((math.cos(a) * 0.075, math.sin(a) * 0.075, 0.22), (0.02, 0.008, 0.008), P["bronze"], rot=(0, 0, a), mat=1)
	# sütunlar ve kemerler
	for i in range(8):
		a = i * math.pi / 4 + math.pi / 8
		x, y = math.cos(a) * 0.32, math.sin(a) * 0.32
		b.cyl((x, y, 0.07), 0.022, 0.02, 0.34, P["white"], seg=8)
		b.box((x, y, 0.42), (0.05, 0.05, 0.025), P["stone_light"])
	b.cyl((0, 0, 0.43), 0.36, 0.36, 0.07, P["white"], seg=8, cap_bot=True)
	b.cyl((0, 0, 0.45), 0.362, 0.362, 0.03, P["iznik"], seg=8, mat=2, cap_top=False, cap_bot=False)
	b.cyl((0, 0, 0.5), 0.4, 0.4, 0.02, P["stone_light"], seg=8)
	arch.dome(b, 0, 0, 0.52, 0.3, drum=0.05, seg=16)
	water = Builder("Water", 502)
	water.cyl((0, 0, 0.155), 0.25, 0.25, 0.006, WATER, seg=16)
	ob = b.finish()
	water.finish().parent = ob
	empty("spout", (0, 0, 0.29), ob)
	return ob


def big_tent(name="city_tent", col=P["canvas"], trim=P["red"], seed=511):
	"""Çarşı çadırı: dört direkli büyük kanvas, kırmızı saçak, altında tezgâh, halı ve mallar."""
	b = Builder(name, seed)
	W, D, H = 0.62, 0.5, 0.36
	for sx in (-1, 1):
		for sy in (-1, 1):
			b.cyl((sx * W / 2, sy * D / 2, 0), 0.012, 0.011, H, P["wood"], seg=6)
	b.cyl((0, 0, 0), 0.016, 0.014, H + 0.18, P["wood"], seg=6)
	# eğimli tavan (dört yüz) ve saçak
	import bmesh
	from mathutils import Matrix
	t = bmesh.new()
	cs = [t.verts.new(p) for p in [(-W / 2 - 0.04, -D / 2 - 0.04, H), (W / 2 + 0.04, -D / 2 - 0.04, H), (W / 2 + 0.04, D / 2 + 0.04, H), (-W / 2 - 0.04, D / 2 + 0.04, H)]]
	top = t.verts.new((0, 0, H + 0.2))
	for i in range(4):
		t.faces.new((cs[i], cs[(i + 1) % 4], top))
	b._merge(t, col)
	for i in range(10):
		x = -W / 2 + (i + 0.5) * W / 10
		for s in (-1, 1):
			b.box((x, s * (D / 2 + 0.045), H - 0.03), (W / 10 - 0.004, 0.006, 0.06), trim if i % 2 == 0 else col)
	for i in range(8):
		y = -D / 2 + (i + 0.5) * D / 8
		for s in (-1, 1):
			b.box((s * (W / 2 + 0.045), y, H - 0.03), (0.006, D / 8 - 0.004, 0.06), trim if i % 2 == 0 else col)
	b.sphere((0, 0, H + 0.22), 0.02, P["gold"], seg=8, rings=5, mat=1)
	# halı ve tezgâh
	b.box((0, 0.02, 0.004), (0.4, 0.3, 0.006), trim)
	b.box((0, 0.02, 0.006), (0.34, 0.24, 0.006), P["iznik"])
	b.box((0, -0.13, 0.05), (0.42, 0.1, 0.1), P["wood_light"], bevel=0.006)
	goods = [P["red"], P["gold"], P["green"], P["copper"], P["cream"]]
	for i in range(6):
		g = goods[(i + seed) % len(goods)]
		b.sphere((-0.17 + i * 0.068, -0.13, 0.12), 0.024, g, seg=6, rings=4, smooth=False, mat=1 if g in (P["gold"], P["copper"]) else 0)
	# bakır testiler, çuvallar
	for k, x in enumerate((0.2, 0.25)):
		b.lathe([(0.02, 0), (0.035, 0.03), (0.03, 0.06), (0.012, 0.08), (0.016, 0.1)], (x, 0.16, 0), P["copper"], seg=8, mat=1)
	for x in (-0.22, -0.16):
		b.sphere((x, 0.17, 0.04), 0.045, P["canvas"], seg=8, rings=5, scale=(1, 1, 1.1))
	return b.finish()


def stall_pair():
	"""İki küçük tenteli tezgâh ve sandıklar."""
	b = Builder("city_stalls", 521)
	arch.awning_stall(b, -0.18, 0.0, w=0.26, d=0.18, col=P["red"])
	arch.awning_stall(b, 0.18, 0.04, w=0.26, d=0.18, col=P["iznik"], goods=[P["copper"], P["gold"], P["white"]])
	crates(b, 0.0, 0.26)
	return b.finish()


def crates(b, x, y):
	for i, (dx, dy, s) in enumerate([(0, 0, 0.08), (0.09, 0.01, 0.07), (0.04, 0.0, 0.06)]):
		z = 0.0 if i < 2 else 0.08
		b.box((x + dx, y + dy, z + s / 2), (s, s, s), jitter(P["wood_light"], 0.08, b.rng), bevel=0.006)
		b.box((x + dx, y + dy - s / 2 - 0.001, z + s / 2), (s * 0.9, 0.002, 0.008), P["wood_dark"])
	for k in range(2):
		bx = x - 0.11 + k * 0.0
		by = y + 0.06 * k
		b.lathe([(0.032, 0), (0.04, 0.04), (0.032, 0.08)], (bx, by, 0), P["wood"], seg=10)
		b.cyl((bx, by, 0.02), 0.037, 0.037, 0.008, P["iron"], seg=10, mat=1, cap_top=False, cap_bot=False)
		b.cyl((bx, by, 0.06), 0.037, 0.037, 0.008, P["iron"], seg=10, mat=1, cap_top=False, cap_bot=False)


def supplies():
	"""Cephane köşesi: tunç top, gülle yığını, sandıklar, fıçılar, ahşap silah sehpası."""
	b = Builder("city_supplies", 531)
	# top
	for s in (-1, 1):
		b.cyl((s * 0.07, -0.05, 0.06), 0.06, 0.06, 0.02, P["wood_dark"], seg=12, rot=(0, math.pi / 2, 0))
	b.box((0, 0.0, 0.07), (0.1, 0.22, 0.05), P["wood"], rot=(0.15, 0, 0), bevel=0.006)
	b.cyl((0, -0.02, 0.11), 0.04, 0.03, 0.3, P["bronze"], seg=12, mat=1, rot=(math.pi / 2 - 0.15, 0, 0))
	for i, (x, y, z) in enumerate([(0.16, 0.0, 0), (0.2, 0.0, 0), (0.18, 0.035, 0), (0.18, 0.017, 0.03)]):
		b.sphere((x, y, 0.02 + z), 0.02, P["iron"], seg=8, rings=5, mat=1)
	crates(b, -0.2, 0.2)
	# silah sehpası
	b.box((0.2, 0.25, 0.1), (0.2, 0.02, 0.012), P["wood"])
	for s in (-1, 1):
		b.box((0.2 + s * 0.09, 0.25, 0.06), (0.015, 0.03, 0.12), P["wood_dark"])
	for i in range(5):
		x = 0.13 + i * 0.035
		b.cyl((x, 0.24, 0.0), 0.005, 0.005, 0.2, P["wood"], seg=5)
		b.cyl((x, 0.24, 0.2), 0.008, 0.0, 0.04, P["stone_grey"], seg=5, mat=1)
	return b.finish()


def house(variant=0):
	"""Cumbalı Osmanlı evi: taş alt kat, badanalı ahşap çıkmalı üst kat, cumba, kafesli pencereler, kiremit çatı, baca."""
	cols = [P["cream"], srgb("#e9c99a"), srgb("#e7b8a8"), srgb("#d8e0e8")]
	wall = cols[variant % len(cols)]
	b = Builder("city_house_%d" % variant, 541 + variant)
	W, D = 0.46, 0.38
	arch.body(b, 0, 0, W, D, 0.18, style="stone", plinth=False, cornice=False)
	arch.door(b, -0.1, -D / 2, w=0.07, h=0.12)
	arch.window(b, 0.1, -D / 2, 0.1, w=0.045, h=0.06)
	# çıkma kirişleri
	for i in range(5):
		x = -W / 2 + 0.03 + i * (W - 0.06) / 4
		b.box((x, -D / 2 - 0.025, 0.17), (0.02, 0.06, 0.02), P["wood_dark"])
	# üst kat
	W2, D2, H2 = W + 0.04, D + 0.07, 0.17
	b.box((0, -0.03, 0.18 + H2 / 2), (W2, D2, H2), wall, bevel=0.004)
	for z in (0.185, 0.18 + H2):
		b.box((0, -0.03, z), (W2 + 0.01, D2 + 0.01, 0.014), P["wood_dark"])
	for x in (-W2 / 2, W2 / 2):
		for y in (-0.03 - D2 / 2, -0.03 + D2 / 2):
			b.box((x, y, 0.18 + H2 / 2), (0.016, 0.016, H2), P["wood_dark"])
	# kafesli pencereler
	for x in (-0.15, 0.15):
		b.box((x, -0.03 - D2 / 2 - 0.004, 0.27), (0.07, 0.008, 0.08), P["wood"])
		for k in range(3):
			b.box((x - 0.022 + k * 0.022, -0.03 - D2 / 2 - 0.009, 0.27), (0.004, 0.004, 0.08), P["wood_dark"])
	# cumba (ortada öne çıkan pencereli kutu)
	cy = -0.03 - D2 / 2 - 0.045
	b.box((0, cy, 0.27), (0.16, 0.09, 0.15), wall, bevel=0.004)
	b.box((0, cy - 0.046, 0.28), (0.12, 0.006, 0.07), P["dark"])
	for k in range(3):
		b.box((-0.04 + k * 0.04, cy - 0.05, 0.28), (0.006, 0.004, 0.07), P["wood_dark"])
	b.box((0, cy, 0.19), (0.17, 0.1, 0.016), P["wood_dark"])
	arch.tile_roof(b, 0, -0.04, 0.18 + H2 + 0.006, W2 + 0.04, D2 + 0.14, 0.14, steps=4)
	b.box((0.12, 0.08, 0.5), (0.05, 0.05, 0.14), P["stone"], bevel=0.005)
	b.box((0.12, 0.08, 0.575), (0.065, 0.065, 0.015), P["stone_dark"])
	# saksı ve kapı önü
	b.cyl((-0.17, -D / 2 - 0.05, 0), 0.025, 0.02, 0.04, P["roof"], seg=8)
	b.sphere((-0.17, -D / 2 - 0.05, 0.06), 0.03, P["green"], seg=6, rings=4, smooth=False)
	return b.finish()


def garden(pool=False):
	b = Builder("city_pool" if pool else "city_garden", 561 if pool else 562)
	b.box((0, 0, 0.015), (0.72, 0.72, 0.03), GRASS)
	for s in (-1, 1):
		b.box((0, s * 0.37, 0.03), (0.78, 0.04, 0.06), P["stone"], bevel=0.006)
		b.box((s * 0.37, 0, 0.03), (0.04, 0.7, 0.06), P["stone"], bevel=0.006)
	ob_water = None
	if pool:
		b.box((0, 0, 0.04), (0.48, 0.34, 0.05), P["white"], bevel=0.006)
		for s in (-1, 1):
			b.box((0, s * 0.155, 0.08), (0.48, 0.03, 0.03), P["white"], bevel=0.004)
			b.box((s * 0.225, 0, 0.08), (0.03, 0.34, 0.03), P["white"], bevel=0.004)
		b.cyl((0, 0, 0.065), 0.025, 0.03, 0.05, P["white"], seg=8)
		w = Builder("Water", 563)
		w.box((0, 0, 0.074), (0.42, 0.28, 0.004), WATER)
		ob_water = w
		for x in (-0.28, 0.28):
			for y in (-0.25, 0.25):
				cypress(b, x, y, 0.5)
	else:
		# çiçek tarhları
		for (x, y) in [(-0.18, -0.18), (0.18, -0.18), (-0.18, 0.18), (0.18, 0.18)]:
			b.box((x, y, 0.035), (0.2, 0.2, 0.02), GRASS_D)
			for k in range(7):
				b.sphere((x + b.rng.uniform(-0.08, 0.08), y + b.rng.uniform(-0.08, 0.08), 0.055), 0.016, b.rng.choice(FLOWERS), seg=6, rings=4, smooth=False)
		b.box((0, 0, 0.032), (0.08, 0.7, 0.006), P["stone_light"])
		b.box((0, 0, 0.032), (0.7, 0.08, 0.006), P["stone_light"])
		cypress(b, -0.3, 0.3, 0.55)
		cypress(b, 0.3, -0.3, 0.5)
		# bank
		b.box((0.05, 0.3, 0.07), (0.2, 0.05, 0.015), P["wood"])
		for x in (-0.03, 0.13):
			b.box((x, 0.3, 0.04), (0.02, 0.04, 0.05), P["wood_dark"])
	ob = b.finish()
	if ob_water:
		ob_water.finish().parent = ob
	return ob


def cypress_court():
	b = Builder("city_cypress", 571)
	round_paving(b, 0.4, rings=3)
	for (x, y) in [(-0.24, -0.22), (0.24, -0.22), (-0.24, 0.24), (0.24, 0.24)]:
		b.cyl((x, y, 0), 0.06, 0.06, 0.04, P["stone"], seg=10)
		cypress(b, x, y, 0.6)
	lantern(b, 0, 0)
	ob = b.finish()
	empty("light", (0, 0, 0.45), ob)
	return ob


def palace_garden():
	b = Builder("city_palace_garden", 581)
	b.box((0, 0.05, 0.015), (0.8, 0.5, 0.03), GRASS)
	for x in (-0.3, -0.1, 0.1, 0.3):
		cypress(b, x, 0.2, 0.55)
	for x in (-0.25, 0.0, 0.25):
		b.box((x, -0.02, 0.035), (0.16, 0.12, 0.02), GRASS_D)
		for k in range(5):
			b.sphere((x + b.rng.uniform(-0.06, 0.06), -0.02 + b.rng.uniform(-0.04, 0.04), 0.055), 0.016, b.rng.choice(FLOWERS), seg=6, rings=4, smooth=False)
	return b.finish()


def street_lantern():
	b = Builder("city_lantern", 591)
	lantern(b, 0, 0)
	ob = b.finish()
	empty("light", (0, 0, 0.45), ob)
	return ob


def banner_pole():
	"""Uzun direk, tepede altın alem; sancak oyunda kodla asılır ("flag" noktası)."""
	b = Builder("city_banner_pole", 595)
	b.box((0, 0, 0.03), (0.08, 0.08, 0.06), P["stone"], bevel=0.008)
	b.cyl((0, 0, 0.06), 0.012, 0.01, 0.9, P["wood_dark"], seg=6)
	b.sphere((0, 0, 0.97), 0.02, P["gold"], seg=8, rings=5, mat=1)
	ob = b.finish()
	empty("flag", (0, 0, 0.92), ob)
	return ob


ALL = {
	"city_fountain": fountain,
	"city_tent": lambda: big_tent(),
	"city_tent_red": lambda: big_tent("city_tent_red", P["red"], P["gold"], 512),
	"city_stalls": stall_pair,
	"city_supplies": supplies,
	"city_house_0": lambda: house(0),
	"city_house_1": lambda: house(1),
	"city_house_2": lambda: house(2),
	"city_house_3": lambda: house(3),
	"city_garden": lambda: garden(False),
	"city_pool": lambda: garden(True),
	"city_cypress": cypress_court,
	"city_palace_garden": palace_garden,
	"city_lantern": street_lantern,
	"city_banner_pole": banner_pole,
}
