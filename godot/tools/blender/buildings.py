# Şehir binaları. Her bina bir glb: temel gövde, "L2" ve "L3" parçaları (seviye yükselince görünür).
# Cami minareleri "M1".."M4" ayrı nesnelerdir. Arsa yaklaşık 0.7 x 0.7; ön yüz -Y.

import math

import arch
from arch import ALMASIK, PLASTER, STONE
from kit import P, Builder, empty, jitter, mix


def _parts(name, seed):
	return Builder("b_%s" % name, seed), Builder("L2", seed + 1), Builder("L3", seed + 2)


def _done(*bs):
	obs = [b.finish() for b in bs]
	for o in obs[1:]:
		o.parent = obs[0]
	return obs[0]


def paving(b, w, d, col=None):
	"""Arsanın taş döşemesi: düzensiz kare taşlar."""
	n = 5
	for i in range(n):
		for j in range(n):
			x = -w / 2 + (i + 0.5) * w / n
			y = -d / 2 + (j + 0.5) * d / n
			b.box((x, y, 0.006), (w / n - 0.008, d / n - 0.008, 0.012), jitter(col or P["stone_grey"], 0.05, b.rng), bevel=0.003)


def tile_band(b, cx, cy, w, d, z, h=0.024):
	"""Gövdeyi saran çini kuşak: lacivert zemin üstünde turkuaz baklavalar."""
	for s in (-1, 1):
		b.box((cx, cy + s * d / 2, z), (w + 0.006, 0.02, h), P["iznik"], mat=2)
		b.box((cx + s * w / 2, cy, z), (0.02, d + 0.006, h), P["iznik"], mat=2)
	n = max(3, int(w / 0.045))
	for i in range(n):
		x = cx - w / 2 + (i + 0.5) * w / n
		b.box((x, cy - d / 2 - 0.011, z), (0.011, 0.004, 0.011), P["turq"], mat=2, rot=(0, math.pi / 4, 0))
	n = max(3, int(d / 0.045))
	for i in range(n):
		y = cy - d / 2 + (i + 0.5) * d / n
		for s in (-1, 1):
			b.box((cx + s * (w / 2 + 0.011), y, z), (0.004, 0.011, 0.011), P["turq"], mat=2, rot=(math.pi / 4, 0, 0))


def parapet(b, cx, cy, w, d, z, step=0.05):
	"""Damın kenarında sivri uçlu taş dişler (Osmanlı mazgalı)."""
	pts = []
	for sy in (-1, 1):
		n = max(2, int(w / step))
		pts += [(cx - w / 2 + (i + 0.5) * w / n, cy + sy * d / 2) for i in range(n)]
	for sx in (-1, 1):
		n = max(2, int(d / step))
		pts += [(cx + sx * w / 2, cy - d / 2 + (i + 0.5) * d / n) for i in range(1, n - 1)]
	for (x, y) in pts:
		b.box((x, y, z + 0.016), (0.02, 0.02, 0.032), P["stone_light"], bevel=0.003)
		b.cyl((x, y, z + 0.032), 0.014, 0.0, 0.022, P["stone_light"], seg=4, rot=(0, 0, math.pi / 4))


def portal(b, x, y, w, h, z0=0.04, face=-1):
	"""Taç kapı: öne çıkan yüksek taş kütle, çini çerçeve, mukarnaslı kavsara, altın yazı kuşağı, kemerli kapı."""
	f = face
	b.box((x, y + f * 0.03, z0 + h / 2), (w, 0.06, h), P["stone_light"], bevel=0.006)
	b.box((x, y + f * 0.061, z0 + h * 0.47), (w * 0.82, 0.006, h * 0.86), P["iznik"], mat=2)
	b.box((x, y + f * 0.064, z0 + h * 0.43), (w * 0.64, 0.006, h * 0.76), P["stone"])
	# mukarnas: aşağı doğru daralan basamaklar
	for k in range(4):
		b.box((x, y + f * (0.066 - k * 0.006), z0 + h * 0.8 - k * h * 0.06), (w * (0.6 - k * 0.1), 0.012 + k * 0.012, h * 0.05), P["white"])
	dw, dh = w * 0.42, h * 0.46
	b.box((x, y + f * 0.068, z0 + dh / 2), (dw, 0.008, dh), P["wood_dark"])
	b.box((x, y + f * 0.068, z0 + dh + 0.008), (dw * 0.7, 0.008, 0.016), P["wood_dark"])
	b.box((x, y + f * 0.068, z0 + dh + 0.02), (dw * 0.35, 0.008, 0.012), P["wood_dark"])
	for k in (-1, 1):
		b.sphere((x + k * dw * 0.22, y + f * 0.073, z0 + dh * 0.5), 0.006, P["gold"], seg=6, rings=4, mat=1)
	b.box((x, y + f * 0.067, z0 + h * 0.9), (w * 0.72, 0.008, 0.022), P["gold"], mat=1)
	# tepe dişleri
	n = max(3, int(w / 0.035))
	for i in range(n):
		px = x - w / 2 + (i + 0.5) * w / n
		b.cyl((px, y + f * 0.03, z0 + h), 0.012, 0.0, 0.03, P["stone_light"], seg=4, rot=(0, 0, math.pi / 4))


def turret(b, x, y, z, r, h, cap=None, cap_h=None, mat=1):
	"""Sekizgen küçük kule: taş gövde, ince pencereler, külah ve alem."""
	b.cyl((x, y, z), r, r, h, P["stone_light"], seg=8)
	for i in range(0, 8, 2):
		a = i * math.pi / 4 + math.pi / 8
		b.box((x + math.cos(a) * r * 0.93, y + math.sin(a) * r * 0.93, z + h * 0.55), (0.006, r * 0.45, h * 0.4), P["dark"], rot=(0, 0, a))
	b.cyl((x, y, z + h), r * 1.15, r * 1.15, 0.008, P["stone"], seg=8)
	ch = cap_h or r * 2.2
	b.cyl((x, y, z + h + 0.008), r * 1.08, 0.0, ch, cap or P["lead"], seg=8, mat=mat)
	b.sphere((x, y, z + h + ch + 0.01), 0.006 + r * 0.08, P["gold"], seg=6, rings=4, mat=1)


def palace():
	"""Saray: mermer kaide üstünde iki katlı taş köşk, çini kuşak, sivri dişli dam, yüksek kasnaklı büyük kubbe,
	öne çıkan taç kapı ve merdiven, köşelerde balkonlu kırmızı külahlı kuleler.
	2: badanalı yan kanatlar, kubbeler, mutfak bacaları. 3: arkada Adalet Kulesi, altın süsler."""
	b, l2, l3 = _parts("palace", 101)
	paving(b, 0.74, 0.74)
	b.box((0, 0.02, 0.02), (0.56, 0.48, 0.04), P["stone_light"], bevel=0.006)
	cy, w, d = 0.04, 0.42, 0.32
	top = arch.body(b, 0, cy, w, d, 0.34, z0=0.04)
	fy = cy - d / 2
	for x in (-0.15, -0.09, 0.09, 0.15):
		arch.window(b, x, fy, 0.18, w=0.04, h=0.07, tile=True)
		arch.window(b, x, fy, 0.33, w=0.035, h=0.055)
	for y in (cy - 0.07, cy + 0.07):
		for s in (-1, 1):
			arch.window(b, y, s * w / 2, 0.18, w=0.04, h=0.07, axis="y", face=s, tile=True)
			arch.window(b, y, s * w / 2, 0.33, w=0.035, h=0.055, axis="y", face=s)
	tile_band(b, 0, cy, w, d, 0.255)
	parapet(b, 0, cy, w, d, top)
	b.box((0, cy, top + 0.006), (w - 0.02, d - 0.02, 0.012), P["lead"], mat=1)
	for sx in (-1, 1):
		for sy in (-1, 1):
			arch.dome(b, sx * 0.13, cy + sy * 0.1, top + 0.012, 0.04, drum=0.02, seg=12)
	arch.dome(b, 0, cy, top + 0.012, 0.13, drum=0.08, seg=24)
	# taç kapı ve merdiven
	portal(b, 0, fy, 0.15, 0.42, z0=0.04)
	for k in range(3):
		b.box((0, fy - 0.075 - k * 0.022, 0.03 - k * 0.01), (0.15 + k * 0.03, 0.024, 0.02), P["stone_light"], bevel=0.003)
	for sx in (-1, 1):
		b.cyl((sx * 0.11, fy - 0.09, 0.0), 0.006, 0.006, 0.12, P["iron"], seg=6, mat=1)
		b.cyl((sx * 0.11, fy - 0.09, 0.12), 0.014, 0.01, 0.025, P["gold"], seg=6, mat=1)
	# köşe kuleleri
	for sx in (-1, 1):
		x, y = sx * 0.235, fy + 0.02
		b.stone_ring((x, y, 0), 0.065, 0.56, z0=0.0, course=0.05, stone_w=0.07, depth=0.025, bevel=0.004)
		b.cyl((x, y, 0.4), 0.085, 0.085, 0.014, P["stone_light"], seg=14)
		b.merlons_ring((x, y, 0), 0.08, 0.414, 10, mw=0.018, mh=0.025, md=0.012, col=P["stone_light"], gap_every=1)
		b.cyl((x, y, 0.5), 0.068, 0.068, 0.03, P["iznik"], seg=14, mat=2)
		b.cyl((x, y, 0.56), 0.078, 0.078, 0.016, P["stone_light"], seg=14)
		b.lathe([(0.085, 0), (0.055, 0.07), (0.0, 0.2)], (x, y, 0.576), P["roof"], seg=14, smooth=False, ribs=(P["roof_dark"], 2))
		b.cyl((x, y, 0.77), 0.003, 0.003, 0.05, P["gold"], seg=5, mat=1)
		b.sphere((x, y, 0.8), 0.012, P["gold"], seg=6, rings=4, mat=1)
		for z in (0.22, 0.33, 0.47):
			arch.window(b, x, y - 0.065, z, w=0.025, h=0.045)
	# 2: yan kanatlar
	for sx in (-1, 1):
		x = sx * 0.3
		t = arch.body(l2, x, 0.17, 0.13, 0.3, 0.26, style=PLASTER)
		for y in (0.08, 0.24):
			arch.window(l2, y, x + sx * 0.065, 0.2, w=0.035, h=0.06, axis="y", face=sx, tile=True)
		arch.window(l2, x, 0.02, 0.2, w=0.035, h=0.06)
		tile_band(l2, x, 0.17, 0.13, 0.3, 0.27, h=0.018)
		arch.dome(l2, x, 0.12, t, 0.05, drum=0.025, seg=14)
		for y in (0.23, 0.28):
			l2.cyl((x, y, t), 0.016, 0.013, 0.09, P["stone_light"], seg=8)
			l2.cyl((x, y, t + 0.09), 0.02, 0.0, 0.03, P["lead"], seg=8, mat=1)
	# 3: Adalet Kulesi ve altın süsler
	t = arch.body(l3, 0, 0.28, 0.12, 0.12, 0.62, style=STONE, plinth=False)
	l3.box((0, 0.28, t + 0.04), (0.11, 0.11, 0.08), P["white"])
	for s in (-1, 1):
		l3.box((0, 0.28 + s * 0.056, t + 0.04), (0.05, 0.004, 0.05), P["dark"])
		l3.box((s * 0.056, 0.28, t + 0.04), (0.004, 0.05, 0.05), P["dark"])
	l3.box((0, 0.28, t + 0.085), (0.13, 0.13, 0.012), P["gold"], mat=1)
	l3.lathe([(0.075, 0), (0.05, 0.08), (0.0, 0.24)], (0, 0.28, t + 0.09), P["lead"], seg=12, mat=1, ribs=(P["lead_light"], 2))
	l3.cyl((0, 0.28, t + 0.33), 0.004, 0.004, 0.06, P["gold"], seg=5, mat=1)
	l3.sphere((0, 0.28, t + 0.37), 0.014, P["gold"], seg=6, rings=4, mat=1)
	for sx in (-1, 1):
		l3.cyl((sx * 0.235, fy + 0.02, 0.45), 0.067, 0.067, 0.012, P["gold"], seg=14, mat=1)
		l3.box((sx * 0.06, fy - 0.068, 0.3), (0.012, 0.006, 0.36), P["gold"], mat=1)
	ob = _done(b, l2, l3)
	empty("flag", (0, 0.28, t + 0.43), ob)
	return ob


def school():
	b, l2, l3 = _parts("school", 111)
	paving(b, 0.66, 0.66)
	top = arch.body(b, 0, 0.06, 0.46, 0.32, 0.22)
	arch.door(b, 0, -0.1, w=0.08, h=0.12)
	for x in (-0.15, 0.15):
		arch.window(b, x, -0.1, 0.15)
	arch.dome(b, 0, 0.06, top, 0.12, drum=0.04)
	arch.arcade(b, -0.2, 0.2, -0.17, 0.04, 0.1, 4)
	b.box((0, -0.165, 0.155), (0.44, 0.07, 0.012), P["lead"], mat=1)
	# 2: talebe hücreleri, küçük kubbeler
	for sx in (-1, 1):
		t = arch.body(l2, sx * 0.25, 0.2, 0.14, 0.14, 0.14, plinth=False)
		arch.dome(l2, sx * 0.25, 0.2, t, 0.05, drum=0.0)
	# 3: ön çini alınlık ve iki küçük kubbe
	for x in (-0.14, 0.14):
		arch.dome(l3, x, -0.165, 0.16, 0.035, drum=0.0)
	l3.box((0, -0.11, top - 0.04), (0.3, 0.012, 0.03), P["iznik"], mat=2)
	return _done(b, l2, l3)


def barracks():
	b, l2, l3 = _parts("barracks", 121)
	paving(b, 0.7, 0.66, P["stone_dark"])
	top = arch.body(b, 0, 0.04, 0.5, 0.3, 0.2, style=STONE)
	for x in (-0.16, 0.0, 0.16):
		arch.window(b, x, -0.11, 0.15, w=0.04, h=0.06)
	arch.door(b, -0.08, -0.11, w=0.08, h=0.11)
	arch.tile_roof(b, 0, 0.04, top, 0.5, 0.3, 0.14)
	# silah sehpası ve kalkanlar
	b.box((0.18, -0.2, 0.08), (0.14, 0.02, 0.012), P["wood"])
	for i in range(5):
		x = 0.12 + i * 0.03
		b.box((x, -0.2, 0.07), (0.006, 0.006, 0.14), P["wood_dark"])
		b.box((x, -0.2, 0.15), (0.012, 0.004, 0.02), P["iron"], mat=1)
	# 2: yan koğuş
	t = arch.body(l2, -0.24, 0.24, 0.2, 0.18, 0.16, style=STONE)
	arch.tile_roof(l2, -0.24, 0.24, t, 0.2, 0.18, 0.1)
	for i in range(2):
		l2.sphere((0.27 - i * 0.06, -0.24, 0.03), 0.025, P["red"], seg=8, rings=4)
	# 3: gözcü kulesi
	l3.stone_ring((0.26, 0.2, 0), 0.07, 0.42, course=0.05, stone_w=0.07, depth=0.025, bevel=0.004)
	l3.merlons_ring((0.26, 0.2, 0), 0.075, 0.42, 12, mh=0.04, md=0.025, gap_every=2)
	l3.cyl((0.26, 0.2, 0.41), 0.07, 0.07, 0.01, P["wood_light"], seg=12)
	ob = _done(b, l2, l3)
	empty("flag", (0.26, 0.2, 0.43), ob)
	return ob


def archery():
	b, l2, l3 = _parts("archery", 131)
	b.box((0, 0, 0.006), (0.7, 0.66, 0.012), P["soil"])
	# ahşap köşk
	for sx in (-1, 1):
		for sy in (-1, 1):
			b.box((sx * 0.13 - 0.12, 0.12 + sy * 0.1, 0.1), (0.022, 0.022, 0.2), P["wood"], bevel=0.003)
	b.box((-0.12, 0.12, 0.02), (0.32, 0.26, 0.04), P["stone"], bevel=0.005)
	b.box((-0.12, 0.12, 0.08), (0.3, 0.012, 0.06), P["wood_light"])
	arch.tile_roof(b, -0.12, 0.12, 0.2, 0.3, 0.24, 0.12)
	# hedefler
	def target(bb, x, y):
		bb.box((x, y + 0.01, 0.06), (0.012, 0.012, 0.12), P["wood_dark"])
		for k, (rr, c) in enumerate([(0.06, P["canvas"]), (0.045, P["red"]), (0.03, P["canvas"]), (0.015, P["gold"])]):
			bb.cyl((x, y - 0.002 * k, 0.11), rr, rr, 0.012, c, seg=14, rot=(math.pi / 2, 0, 0))
	target(b, 0.2, -0.22)
	# ok fıçısı
	b.cyl((0.08, 0.05, 0), 0.03, 0.03, 0.06, P["wood"], seg=10)
	for i in range(6):
		b.box((0.08 + (i % 3 - 1) * 0.012, 0.05 + (i // 3 - 0.5) * 0.015, 0.08), (0.003, 0.003, 0.06), P["wood_light"])
	# 2: ikinci hedef, hasır yığını
	target(l2, 0.05, -0.24)
	l2.cyl((0.24, 0.12, 0), 0.05, 0.045, 0.05, P["gold"], seg=10, rot=(0, 0, 0))
	# 3: üçüncü hedef, sancaklı okçu kulesi
	target(l3, -0.1, -0.24)
	l3.stone_ring((0.24, 0.2, 0), 0.06, 0.36, course=0.05, stone_w=0.07, depth=0.025, bevel=0.004)
	l3.merlons_ring((0.24, 0.2, 0), 0.065, 0.36, 10, mh=0.035, md=0.022)
	ob = _done(b, l2, l3)
	empty("flag", (0.24, 0.2, 0.38), ob)
	return ob


def hospital():
	b, l2, l3 = _parts("hospital", 141)
	paving(b, 0.7, 0.66)
	top = arch.body(b, 0, 0.06, 0.52, 0.34, 0.2)
	arch.door(b, 0, -0.11, w=0.08, h=0.12)
	for x in (-0.18, -0.09, 0.09, 0.18):
		arch.window(b, x, -0.11, 0.14, w=0.04, h=0.06)
	b.box((0, 0.06, top + 0.01), (0.5, 0.32, 0.02), P["lead"], mat=1)
	for x in (-0.15, 0.15):
		arch.dome(b, x, 0.06, top + 0.02, 0.07, drum=0.02)
	# 2: ön revak, kurşun saçak
	arch.arcade(l2, -0.22, 0.22, -0.19, 0.04, 0.1, 5)
	l2.box((0, -0.19, 0.155), (0.48, 0.08, 0.012), P["lead"], mat=1)
	# 3: büyük orta kubbe, şifa bahçesi
	arch.dome(l3, 0, 0.06, top + 0.02, 0.1, drum=0.04)
	for x in (-0.28, 0.28):
		l3.cyl((x, -0.22, 0), 0.03, 0.0, 0.14, P["green"], seg=8)
	return _done(b, l2, l3)


def cavalry():
	b, l2, l3 = _parts("cavalry", 151)
	b.box((0, 0, 0.006), (0.72, 0.68, 0.012), P["soil"])
	# ahır: ahşap gövde, taş kaide, kiremit çatı
	b.box((0, 0.16, 0.03), (0.52, 0.22, 0.06), P["stone"], bevel=0.006)
	b.box((0, 0.16, 0.12), (0.5, 0.2, 0.12), P["wood_light"])
	for i in range(4):
		x = -0.18 + i * 0.12
		b.box((x, 0.055, 0.11), (0.07, 0.01, 0.09), P["wood_dark"])
		b.box((x, 0.05, 0.11), (0.07, 0.004, 0.006), P["wood"])
	arch.tile_roof(b, 0, 0.16, 0.18, 0.52, 0.22, 0.1)
	# çit
	for i in range(8):
		x = -0.32 + i * 0.09
		b.box((x, -0.28, 0.05), (0.014, 0.014, 0.1), P["wood"])
	b.box((0, -0.28, 0.08), (0.66, 0.008, 0.012), P["wood_light"])
	b.box((0, -0.28, 0.045), (0.66, 0.008, 0.012), P["wood_light"])
	# su yalağı, saman
	b.box((0.22, -0.06, 0.025), (0.14, 0.05, 0.05), P["wood"], bevel=0.004)
	b.box((0.22, -0.06, 0.049), (0.12, 0.035, 0.004), P["iznik"])
	b.box((-0.24, -0.08, 0.03), (0.08, 0.06, 0.06), P["gold"], bevel=0.008)
	# 2: ikinci saman, eyer sehpası
	l2.box((-0.24, -0.16, 0.03), (0.08, 0.06, 0.06), P["gold"], bevel=0.008)
	l2.box((-0.1, -0.12, 0.05), (0.08, 0.03, 0.03), P["red"], bevel=0.006)
	# 3: sancak kulesi (ahşap)
	for sx in (-1, 1):
		for sy in (-1, 1):
			l3.box((0.3 + sx * 0.03, -0.18 + sy * 0.03, 0.17), (0.012, 0.012, 0.34), P["wood"])
	l3.box((0.3, -0.18, 0.34), (0.1, 0.1, 0.015), P["wood_light"])
	ob = _done(b, l2, l3)
	empty("flag", (0.3, -0.18, 0.35), ob)
	return ob


def science():
	b, l2, l3 = _parts("science", 161)
	paving(b, 0.66, 0.66)
	b.stone_ring((0, 0.06, 0.0), 0.2, 0.34, course=0.06, stone_w=0.09, depth=0.03, bevel=0.005, palette=[P["stone_light"], P["stone"], P["stone_grey"]])
	b.cyl((0, 0.06, 0.34), 0.215, 0.215, 0.02, P["iznik"], seg=24, mat=2)
	arch.dome(b, 0, 0.06, 0.36, 0.18, drum=0.0)
	for a in (-math.pi / 2 - 0.6, -math.pi / 2 + 0.6):
		arch.window(b, math.cos(a) * 0.2, 0.06 + math.sin(a) * 0.2 + 0.02, 0.22, w=0.04)
	arch.door(b, 0, 0.06 - 0.2, w=0.07, h=0.11)
	# 2: kütüphane kanadı
	t = arch.body(l2, 0.0, -0.22, 0.4, 0.14, 0.13, style=PLASTER, plinth=False)
	arch.tile_roof(l2, 0.0, -0.22, t, 0.4, 0.14, 0.06)
	# 3: altın usturlap halkaları ve dürbün
	for k, rot in enumerate([(0, 0, 0), (math.pi / 2, 0, 0.6), (0.6, math.pi / 2, 0)]):
		import bmesh
		from mathutils import Matrix, Vector
		t = bmesh.new()
		bmesh.ops.create_circle(t, cap_ends=False, segments=16, radius=0.07)
		edges = list(t.edges)
		res = bmesh.ops.extrude_edge_only(t, edges=edges)
		bmesh.ops.translate(t, vec=Vector((0, 0, 0.008)), verts=[v for v in res["geom"] if isinstance(v, bmesh.types.BMVert)])
		l3._merge(t, P["gold"], mat=1, matrix=Matrix.Translation(Vector((0.26, 0.22, 0.12))) @ __import__("kit")._rot(rot))
	l3.cyl((0.26, 0.22, 0), 0.01, 0.008, 0.12, P["bronze"], seg=6, mat=1)
	l3.cyl((-0.1, 0.1, 0.55), 0.015, 0.02, 0.2, P["bronze"], seg=8, mat=1, rot=(0.9, 0, 0.3))
	return _done(b, l2, l3)


def religion():
	b, l2, l3 = _parts("religion", 171)
	paving(b, 0.66, 0.66)
	top = arch.body(b, 0, 0.06, 0.44, 0.32, 0.24)
	arch.door(b, 0, -0.1, w=0.08, h=0.13)
	for x in (-0.14, 0.14):
		arch.window(b, x, -0.1, 0.17, tile=True)
	arch.dome(b, 0, 0.06, top, 0.14, drum=0.05)
	arch.arcade(b, -0.18, 0.18, -0.17, 0.04, 0.11, 3)
	b.box((0, -0.17, 0.165), (0.4, 0.07, 0.012), P["lead"], mat=1)
	for x in (-0.18, 0.18):
		arch.dome(l2, x, 0.06, top, 0.05, drum=0.015)
	arch.minaret(l3, 0.27, 0.24, h=0.6, r=0.026)
	return _done(b, l2, l3)


def court():
	b, l2, l3 = _parts("court", 181)
	paving(b, 0.7, 0.66)
	top = arch.body(b, 0, 0.08, 0.5, 0.32, 0.24, style=PLASTER)
	for x in (-0.16, 0.0, 0.16):
		arch.window(b, x, -0.08, 0.18, w=0.045, h=0.07, tile=True)
	arch.tile_roof(b, 0, 0.08, top, 0.5, 0.32, 0.12)
	# sütunlu sundurma
	arch.arcade(b, -0.22, 0.22, -0.16, 0.04, 0.14, 4)
	b.box((0, -0.15, 0.2), (0.5, 0.1, 0.014), P["roof"], rot=(0.25, 0, 0))
	b.box((0, -0.11, 0.06), (0.1, 0.04, 0.04), P["wood_dark"])
	# 2: orta kubbe
	arch.dome(l2, 0, 0.08, top + 0.07, 0.09, drum=0.04)
	# 3: Adalet Kulesi
	l3.box((-0.26, 0.2, 0.25), (0.11, 0.11, 0.5), P["white"], bevel=0.004)
	for k in range(3):
		arch.window(l3, -0.26, 0.145, 0.15 + k * 0.13, w=0.03, h=0.05)
	l3.box((-0.26, 0.2, 0.51), (0.13, 0.13, 0.02), P["stone_light"])
	l3.lathe([(0.095, 0), (0.06, 0.06), (0.0, 0.18)], (-0.26, 0.2, 0.52), P["lead"], seg=8, mat=1, ribs=(P["lead_light"], 2))
	l3.sphere((-0.26, 0.2, 0.72), 0.012, P["gold"], seg=6, rings=4, mat=1)
	return _done(b, l2, l3)


def market():
	b, l2, l3 = _parts("market", 191)
	paving(b, 0.72, 0.68)
	# bedesten: 2 kubbeli taş han
	top = arch.body(b, 0, 0.16, 0.44, 0.24, 0.18)
	arch.door(b, 0, 0.04, w=0.08, h=0.11)
	for x in (-0.11, 0.11):
		arch.dome(b, x, 0.16, top, 0.09, drum=0.02)
	arch.awning_stall(b, -0.2, -0.18, col=P["red"])
	b.box((0.0, -0.22, 0.03), (0.05, 0.05, 0.06), P["wood"], bevel=0.004)
	b.cyl((0.05, -0.26, 0), 0.025, 0.022, 0.06, P["wood_dark"], seg=8)
	arch.awning_stall(l2, 0.05, -0.2, col=P["iznik"], goods=[P["copper"], P["gold"], P["white"]])
	arch.awning_stall(l3, 0.28, -0.16, col=P["green"], col2=P["gold"], goods=[P["red"], P["green"], P["gold"]])
	# 3: ortada üçüncü küçük kubbe ve kandil
	arch.dome(l3, 0, 0.16, top, 0.05, drum=0.015)
	return _done(b, l2, l3)


def workshop():
	b, l2, l3 = _parts("workshop", 201)
	b.box((0, 0, 0.006), (0.72, 0.68, 0.012), P["soil"])
	top = arch.body(b, 0.06, 0.12, 0.38, 0.26, 0.17, style=STONE)
	arch.tile_roof(b, 0.06, 0.12, top, 0.38, 0.26, 0.09, col=P["roof_dark"])
	# ocak bacası
	b.box((0.18, 0.2, top + 0.08), (0.07, 0.07, 0.2), P["stone_dark"], bevel=0.006)
	b.box((0.18, 0.2, top + 0.185), (0.085, 0.085, 0.02), P["stone_grey"])
	# açık ocak ve örs
	b.box((-0.04, -0.02, 0.1), (0.12, 0.012, 0.09), P["dark"])
	b.box((-0.04, -0.03, 0.06), (0.06, 0.01, 0.03), P["fire"])
	b.box((0.16, -0.16, 0.03), (0.04, 0.04, 0.06), P["wood_dark"])
	b.box((0.16, -0.16, 0.07), (0.07, 0.03, 0.025), P["iron"], mat=1)
	# kütük yığını
	for i in range(3):
		for j in range(3 - i):
			b.cyl((-0.28 + j * 0.05 + i * 0.025, -0.18, 0.025 + i * 0.042), 0.022, 0.022, 0.16, jitter(P["wood"], 0.08, b.rng), seg=8, rot=(math.pi / 2, 0, 0))
	# 2: kereste sundurması
	for sx in (-1, 1):
		l2.box((-0.25 + sx * 0.07, 0.2, 0.08), (0.016, 0.016, 0.16), P["wood"])
	l2.box((-0.25, 0.2, 0.17), (0.2, 0.18, 0.012), P["wood_light"], rot=(0.15, 0, 0))
	for k in range(4):
		l2.box((-0.25, 0.2, 0.02 + k * 0.02), (0.16, 0.12, 0.016), jitter(P["wood_light"], 0.08, l2.rng))
	# 3: maden arabası, demir cevheri
	l3.box((0.05, -0.25, 0.05), (0.12, 0.08, 0.05), P["wood"], bevel=0.004)
	for sx in (-1, 1):
		l3.cyl((0.05 + sx * 0.045, -0.25, 0.025), 0.022, 0.022, 0.01, P["wood_dark"], seg=10, rot=(math.pi / 2, 0, 0))
	for i in range(5):
		l3.sphere((0.03 + (i % 3) * 0.02, -0.25 + (i // 3) * 0.02, 0.085), 0.016, P["iron"], seg=6, rings=4, smooth=False)
	ob = _done(b, l2, l3)
	empty("smoke", (0.18, 0.2, top + 0.2), ob)
	empty("flag", (-0.3, 0.26, 0.0), ob)
	return ob


def kitchen():
	b, l2, l3 = _parts("kitchen", 211)
	paving(b, 0.7, 0.66)
	top = arch.body(b, 0, 0.1, 0.54, 0.28, 0.2, style=ALMASIK)
	arch.door(b, -0.1, -0.04, w=0.08, h=0.12)
	for x in (0.06, 0.18):
		arch.window(b, x, -0.04, 0.14, w=0.04, h=0.06)
	b.box((0, 0.1, top + 0.01), (0.52, 0.26, 0.02), P["lead"], mat=1)
	# Topkapı mutfağı gibi kubbeli bacalar
	def chimney(bb, x):
		bb.box((x, 0.12, top + 0.07), (0.07, 0.07, 0.12), P["stone"], bevel=0.005)
		arch.dome(bb, x, 0.12, top + 0.13, 0.035, drum=0.0, alem=False)
		bb.cyl((x, 0.12, top + 0.16), 0.01, 0.01, 0.04, P["stone_dark"], seg=6)
	chimney(b, -0.15)
	chimney(b, 0.15)
	# kazanlar
	def cauldron(bb, x, y):
		bb.cyl((x, y, 0), 0.045, 0.04, 0.04, P["stone_dark"], seg=10)
		bb.cyl((x, y, 0.04), 0.05, 0.055, 0.045, P["copper"], seg=12, mat=1)
		bb.cyl((x, y, 0.084), 0.045, 0.045, 0.004, P["soil"], seg=12)
	cauldron(b, -0.18, -0.2)
	chimney(l2, 0.0)
	cauldron(l2, 0.02, -0.22)
	cauldron(l3, 0.22, -0.2)
	l3.box((0.3, 0.0, 0.04), (0.06, 0.16, 0.08), P["wood"], bevel=0.005)
	ob = _done(b, l2, l3)
	empty("smoke", (-0.15, 0.12, top + 0.2), ob)
	return ob


def mosque():
	"""Cami: iki sıra pencereli yüksek harim, çini kuşak, köşelerde kubbecikler, önde ve arkada kademeli kubbeler,
	yüksek kasnaklı büyük kubbe ve ağırlık kuleleri, taç kapı, son cemaat revakı, şadırvan; minareler "M1".."M4"."""
	b = Builder("b_mosque", 221)
	paving(b, 0.74, 0.74)
	cy, w, d = 0.06, 0.42, 0.38
	top = arch.body(b, 0, cy, w, d, 0.3)
	fy = cy - d / 2
	for x in (-0.14, 0.14):
		arch.window(b, x, fy, 0.15, w=0.045, h=0.075, tile=True)
		arch.window(b, x, fy, 0.28, w=0.035, h=0.05)
	for y in (cy - 0.1, cy, cy + 0.1):
		for s in (-1, 1):
			arch.window(b, y, s * w / 2, 0.15, w=0.04, h=0.075, axis="y", face=s, tile=True)
			arch.window(b, y, s * w / 2, 0.28, w=0.03, h=0.05, axis="y", face=s)
	tile_band(b, 0, cy, w, d, 0.225)
	parapet(b, 0, cy, w, d, top)
	b.box((0, cy, top + 0.006), (w - 0.02, d - 0.02, 0.012), P["lead"], mat=1)
	for sx in (-1, 1):
		for sy in (-1, 1):
			arch.dome(b, sx * 0.15, cy + sy * 0.13, top + 0.012, 0.045, drum=0.015, seg=12)
	for sy in (-1, 1):
		arch.dome(b, 0, cy + sy * 0.12, top + 0.012, 0.08, drum=0.0, seg=18, alem=False)
	ct = arch.dome(b, 0, cy, top + 0.05, 0.16, drum=0.1, seg=28)
	b.cyl((0, cy, top + 0.012), 0.17, 0.17, 0.04, P["stone_light"], seg=28)
	for sx in (-1, 1):
		for sy in (-1, 1):
			turret(b, sx * 0.125, cy + sy * 0.125, top + 0.05, 0.022, 0.11)
	portal(b, 0, fy, 0.13, 0.32, z0=0.04)
	# son cemaat yeri
	arch.arcade(b, -0.2, 0.2, -0.25, 0.04, 0.15, 3)
	b.box((0, -0.25, 0.205), (0.42, 0.08, 0.012), P["lead"], mat=1)
	for x in (-0.135, 0.0, 0.135):
		arch.dome(b, x, -0.245, 0.21, 0.045, drum=0.0, seg=14)
	# şadırvan
	b.cyl((0, -0.32, 0.0), 0.04, 0.04, 0.03, P["white"], seg=8)
	b.cyl((0, -0.32, 0.03), 0.034, 0.034, 0.004, P["iznik"], seg=8, mat=2)
	b.cyl((0, -0.32, 0.03), 0.006, 0.006, 0.04, P["stone"], seg=6)
	ob = b.finish()
	for i, (x, y) in enumerate([(-0.31, -0.29), (0.31, -0.29), (-0.31, 0.31), (0.31, 0.31)]):
		m = Builder("M%d" % (i + 1), 230 + i)
		arch.minaret(m, x, y, h=1.05, r=0.032)
		mo = m.finish()
		mo.parent = ob
	return ob


def medrese():
	"""Medrese: ortada şadırvanlı avlu, üç yanda revak ve kubbeli, bacalı talebe hücreleri, arkada yüksek kubbeli dershane,
	önde taç kapı. 2: sol kanat ve kütüphane kubbesi. 3: sağ arkada rasathane kulesi."""
	b, l2, l3 = _parts("medrese", 251)
	paving(b, 0.74, 0.74)
	# arka: dershane
	top = arch.body(b, 0, 0.22, 0.34, 0.22, 0.3)
	tile_band(b, 0, 0.22, 0.34, 0.22, 0.24, h=0.02)
	parapet(b, 0, 0.22, 0.34, 0.22, top)
	arch.dome(b, 0, 0.22, top, 0.12, drum=0.06, seg=22)
	for x in (-0.1, 0.1):
		arch.window(b, x, 0.11, 0.16, w=0.045, h=0.075, tile=True)
		arch.window(b, x, 0.11, 0.28, w=0.035, h=0.05)
	arch.door(b, 0, 0.11, w=0.07, h=0.13)
	# sağ kanat: hücre sırası
	t = arch.body(b, 0.27, -0.02, 0.16, 0.38, 0.2, plinth=False)
	tile_band(b, 0.27, -0.02, 0.16, 0.38, 0.15, h=0.016)
	for y in (-0.14, 0.0, 0.12):
		arch.dome(b, 0.27, y, t, 0.048, drum=0.012, seg=14)
		b.cyl((0.33, y + 0.06, t), 0.01, 0.008, 0.06, P["stone_light"], seg=6)
		b.cyl((0.33, y + 0.06, t + 0.06), 0.013, 0.0, 0.02, P["lead"], seg=6, mat=1)
	for i in range(4):
		y = -0.17 + i * 0.1
		b.cyl((0.17, y, 0.04), 0.012, 0.011, 0.14, P["white"], seg=8)
	b.box((0.17, -0.02, 0.19), (0.05, 0.36, 0.02), P["lead"], mat=1)
	# avlu: şadırvan ve servi
	b.cyl((0, -0.05, 0.012), 0.065, 0.07, 0.04, P["white"], seg=12)
	b.cyl((0, -0.05, 0.05), 0.055, 0.055, 0.004, P["iznik"], seg=12, mat=2)
	b.cyl((0, -0.05, 0.05), 0.009, 0.009, 0.06, P["stone"], seg=6)
	b.sphere((0, -0.05, 0.115), 0.014, P["white"], seg=8, rings=5)
	for x in (-0.1, 0.1):
		b.cyl((x, -0.26, 0.012), 0.028, 0.0, 0.17, P["green"], seg=8)
	# ön: alçak duvar ve taç kapı
	b.box((0, -0.32, 0.07), (0.62, 0.04, 0.12), P["stone"], bevel=0.006)
	b.box((0, -0.32, 0.135), (0.62, 0.048, 0.012), P["stone_light"])
	portal(b, 0, -0.3, 0.15, 0.3, z0=0.0)
	# 2: sol kanat ve kütüphane kubbesi
	t2 = arch.body(l2, -0.27, -0.02, 0.16, 0.38, 0.2, plinth=False)
	tile_band(l2, -0.27, -0.02, 0.16, 0.38, 0.15, h=0.016)
	for y in (-0.14, 0.12):
		arch.dome(l2, -0.27, y, t2, 0.048, drum=0.012, seg=14)
	arch.dome(l2, -0.27, 0.0, t2, 0.075, drum=0.035, seg=18)
	for i in range(4):
		l2.cyl((-0.17, -0.17 + i * 0.1, 0.04), 0.012, 0.011, 0.14, P["white"], seg=8)
	l2.box((-0.17, -0.02, 0.19), (0.05, 0.36, 0.02), P["lead"], mat=1)
	# 3: rasathane kulesi
	l3.stone_ring((0.27, 0.27, 0), 0.075, 0.6, course=0.05, stone_w=0.07, depth=0.025, bevel=0.004, palette=[P["stone_light"], P["stone"]])
	l3.cyl((0.27, 0.27, 0.6), 0.09, 0.09, 0.024, P["iznik"], seg=14, mat=2)
	l3.merlons_ring((0.27, 0.27, 0), 0.085, 0.624, 10, mw=0.018, mh=0.025, md=0.012, col=P["stone_light"], gap_every=1)
	arch.dome(l3, 0.27, 0.27, 0.624, 0.075, drum=0.0, seg=16)
	l3.cyl((0.32, 0.23, 0.66), 0.013, 0.018, 0.14, P["bronze"], seg=8, mat=1, rot=(0.7, 0.3, 0))
	ob = _done(b, l2, l3)
	empty("flag", (-0.13, 0.3, top), ob)
	return ob


ALL = {
	"b_palace": palace, "b_school": school, "b_barracks": barracks, "b_archery": archery,
	"b_hospital": hospital, "b_cavalry": cavalry, "b_science": science, "b_religion": religion,
	"b_court": court, "b_market": market, "b_workshop": workshop, "b_kitchen": kitchen, "b_mosque": mosque,
	"b_medrese": medrese,
}
