# Kuleler ve surlar. Ölçü birimi 1 oyun karesi.

import math

from kit import P, Builder, empty, jitter, mix, mul


def rock_base(b, r, n=9, h=0.05):
	"""Kule dibinde birkaç kaya ve toprak halkası."""
	b.cyl((0, 0, 0), r * 1.2, r * 1.12, 0.02, P["soil"], seg=16)
	for i in range(n):
		a = i * 2 * math.pi / n + b.rng.uniform(-0.2, 0.2)
		s = b.rng.uniform(0.05, 0.09)
		rr = r * b.rng.uniform(1.0, 1.12)
		b.box((math.cos(a) * rr, math.sin(a) * rr, s * 0.3), (s, s * 0.8, s * 0.7), jitter(P["rock"], 0.1, b.rng), rot=(0.2, 0.1, a), bevel=0.012)


def arrow_slit(b, a, r, z, h=0.1, w=0.035):
	x, y = math.cos(a), math.sin(a)
	b.box((x * (r + 0.004), y * (r + 0.004), z), (0.02, w, h), P["dark"], rot=(0, 0, a))
	# taş çerçeve
	b.box((x * (r + 0.008), y * (r + 0.008), z + h / 2 + 0.01), (0.03, w + 0.03, 0.02), P["stone_light"], rot=(0, 0, a), bevel=0.004)
	b.box((x * (r + 0.008), y * (r + 0.008), z - h / 2 - 0.01), (0.03, w + 0.03, 0.02), P["stone_light"], rot=(0, 0, a), bevel=0.004)


def wooden_door(b, a, r, w=0.12, h=0.18):
	x, y = math.cos(a), math.sin(a)
	b.box((x * (r + 0.006), y * (r + 0.006), h / 2 + 0.02), (0.03, w, h), P["wood_dark"], rot=(0, 0, a), bevel=0.005)
	for k in (-1, 1):
		b.box((x * (r + 0.02), y * (r + 0.02), h / 2 + 0.02 + k * h * 0.25), (0.01, w * 0.9, 0.012), P["iron"], rot=(0, 0, a))
	# kemer taşları
	for i in range(5):
		t = -math.pi / 2 + i * math.pi / 4
		px = math.cos(t) * (w / 2 + 0.02)
		pz = h + 0.02 + math.sin(t + math.pi / 2) * 0.02
		ox, oy = -y * px, x * px
		b.box((x * (r + 0.01) + ox, y * (r + 0.01) + oy, pz - 0.01 + (0.02 if i == 2 else 0)), (0.035, 0.04, 0.035), P["stone_light"], rot=(0, 0, a), bevel=0.006)


def crown(b, r, z, n=None, overhang=0.035, corbels=True, col=None):
	"""Taşan taç: konsollar, kat silmesi, mazgal dişleri. Dönüş: yürüme yolunun yüksekliği."""
	n = n or max(10, int(r * 40))
	if corbels:
		for i in range(n):
			a = (i + 0.5) * 2 * math.pi / n
			b.box((math.cos(a) * (r + 0.01), math.sin(a) * (r + 0.01), z + 0.025), (0.05, 0.035, 0.05), jitter(P["stone_dark"], 0.06, b.rng), rot=(0, 0, a), bevel=0.006)
	ro = r + overhang
	b.stone_ring((0, 0, 0), ro, 0.06, z0=z + 0.05, course=0.06, stone_w=0.1, depth=0.045)
	b.cyl((0, 0, z + 0.11), ro - 0.02, ro - 0.02, 0.012, P["stone_light"], seg=24)
	floor_z = z + 0.112
	b.cyl((0, 0, floor_z - 0.004), ro - 0.045, ro - 0.045, 0.006, P["wood_light"], seg=20, cap_bot=False)
	b.merlons_ring((0, 0, floor_z), ro, 0, n * 2 if n % 2 == 0 else n * 2, mh=0.085, md=0.05)
	return floor_z


def archer_tower(level):
	"""Okçu Kulesi: yuvarlak kesme taş kule, taşan mazgallı taç, ahşap kapı, ok mazgalları.
	2. seviye: daha yüksek, sancak askısı. 3. seviye: ahşap çatılı gözcü köşkü ve altın süs."""
	b = Builder("archer_tower_%d" % level, seed=11 + level)
	r = 0.25
	h = [0.0, 0.58, 0.7, 0.8][level]
	rock_base(b, r)
	# kaide: daha geniş, eğimli taş etek
	b.stone_ring((0, 0, 0), r + 0.035, 0.12, z0=0.0, taper=0.03, course=0.06, stone_w=0.12, depth=0.05, palette=[P["stone_dark"], P["stone"], P["stone_grey"]])
	b.stone_ring((0, 0, 0), r, h - 0.12, z0=0.12, course=0.07, stone_w=0.12, depth=0.045)
	# kat silmesi
	b.cyl((0, 0, 0.12), r + 0.012, r + 0.012, 0.018, P["stone_light"], seg=24)
	wooden_door(b, -math.pi / 2, r)
	for a, z in [(0.4, h * 0.55), (2.4, h * 0.7), (4.4, h * 0.5), (-1.2, h * 0.8)]:
		arrow_slit(b, a, r, z)
	floor_z = crown(b, r, h)
	top = floor_z
	if level >= 3:
		# köşk: dört direk, kırmızı kiremit külah, altın alem
		for i in range(4):
			a = math.pi / 4 + i * math.pi / 2
			b.box((math.cos(a) * 0.17, math.sin(a) * 0.17, floor_z + 0.14), (0.025, 0.025, 0.28), P["wood"], bevel=0.004)
		b.lathe([(0.26, 0.0), (0.2, 0.06), (0.1, 0.15), (0.0, 0.22)], (0, 0, floor_z + 0.28), P["roof"], seg=8, smooth=False, ribs=(P["roof_dark"], 2))
		b.cyl((0, 0, floor_z + 0.5), 0.008, 0.008, 0.06, P["gold"], seg=6, mat=1)
		b.sphere((0, 0, floor_z + 0.57), 0.018, P["gold"], seg=8, rings=6, mat=1)
	ob = b.finish()
	e = empty("top", (0, 0, top))
	e.parent = ob
	f = empty("flag", (0.16, 0.16, top + 0.08))
	f.parent = ob
	return ob


def burc(domed=True, r=0.3, h=1.0, name=None):
	"""Sur burcu: yuvarlak taş gövde, mazgallı taç, kaburgalı kurşun kubbe ve altın alem."""
	b = Builder(name or ("burc_dome" if domed else "burc_open"), seed=31 if domed else 37)
	b.stone_ring((0, 0, 0), r + 0.03, 0.14, z0=0.0, taper=0.03, course=0.07, stone_w=0.13, depth=0.05, palette=[P["stone_dark"], P["stone"], P["stone_grey"]])
	b.stone_ring((0, 0, 0), r, h - 0.14, z0=0.14, course=0.075, stone_w=0.13, depth=0.05)
	b.cyl((0, 0, 0.14), r + 0.012, r + 0.012, 0.02, P["stone_light"], seg=28)
	for a, z in [(-math.pi / 2, h * 0.6), (-math.pi / 2 + 1.2, h * 0.45), (-math.pi / 2 - 1.2, h * 0.45), (math.pi / 2, h * 0.6)]:
		arrow_slit(b, a, r, z, h=0.12)
	floor_z = crown(b, r, h)
	top = floor_z
	if domed:
		# kasnak, kubbe, alem
		dr = r * 0.82
		b.stone_ring((0, 0, 0), dr, 0.1, z0=floor_z, course=0.05, stone_w=0.1, depth=0.035, palette=[P["stone_light"], P["stone"]])
		b.cyl((0, 0, floor_z + 0.1), dr + 0.012, dr + 0.012, 0.015, P["stone_light"], seg=24)
		prof = []
		for i in range(9):
			t = i / 8
			ang = t * math.pi / 2
			prof.append((dr * math.cos(ang) * (1.0 + 0.04 * math.sin(t * math.pi)), dr * 1.08 * math.sin(ang)))
		prof[-1] = (0.0, prof[-1][1])
		b.lathe(prof, (0, 0, floor_z + 0.115), P["lead"], seg=24, mat=1, ribs=(P["lead_light"], 3))
		ztop = floor_z + 0.115 + dr * 1.08
		b.cyl((0, 0, ztop - 0.01), 0.025, 0.012, 0.04, P["lead_light"], seg=8, mat=1)
		b.cyl((0, 0, ztop + 0.03), 0.006, 0.006, 0.12, P["gold"], seg=6, mat=1)
		for k, rr in enumerate([0.022, 0.016]):
			b.sphere((0, 0, ztop + 0.06 + k * 0.04), rr, P["gold"], seg=10, rings=6, mat=1)
		top = ztop + 0.15
	ob = b.finish()
	e = empty("top", (0, 0, top))
	e.parent = ob
	return ob


def wall_segment(length=1.0, h=0.62, t=0.34, name="wall_segment"):
	"""Sur parçası (x boyunca): iki yüzü kesme taş, iki yanda mazgal dişleri, üstte taş döşeli yürüme yolu."""
	b = Builder(name, seed=53)
	L = length
	# eğimli kaide
	b.box((0, 0, 0.04), (L, t + 0.1, 0.08), P["stone_dark"], bevel=0.01)
	for s in (-1, 1):
		b.stone_wall(-L / 2, L / 2, 0.08, h, s * t / 2, s, course=0.078, stone_w=0.15, depth=0.04)
	b.box((0, 0, h / 2), (L, t - 0.06, h), P["mortar"])
	# yürüme yolu döşemesi
	b.box((0, 0, h + 0.005), (L, t - 0.02, 0.012), P["stone_light"], top_col=mix(P["stone_light"], P["stone"], 0.4))
	for i in range(int(L / 0.12)):
		x = -L / 2 + (i + 0.5) * L / int(L / 0.12)
		b.box((x, 0, h + 0.012), (0.004, t - 0.06, 0.004), P["mortar"])
	# silme
	for s in (-1, 1):
		b.box((0, s * (t / 2 + 0.008), h - 0.02), (L, 0.02, 0.025), P["stone_light"], bevel=0.005)
	# mazgal dişleri: dışta (+y: Godot -z, düşman tarafı) daha yüksek, içte alçak korkuluk
	n = max(2, int(round(L / 0.18)))
	for i in range(n):
		x = -L / 2 + (i + 0.5) * L / n
		b.box((x, (t / 2 - 0.035), h + 0.06), (L / n * 0.62, 0.07, 0.11), jitter(P["stone_light"], 0.06, b.rng), bevel=0.01)
	b.box((0, (t / 2 - 0.035), h + 0.012), (L, 0.07, 0.025), P["stone"])
	b.box((0, -(t / 2 - 0.03), h + 0.03), (L, 0.06, 0.06), P["stone"], bevel=0.008)
	return b.finish()


def tar_tower():
	"""Zift Kazanı: kesme taş kaide, demir ayaklar üstünde bakır kazan, altında ateş deliği ve odunlar."""
	b = Builder("tar_tower", seed=61)
	rock_base(b, 0.33, n=10)
	b.stone_ring((0, 0, 0), 0.34, 0.22, taper=0.03, course=0.055, stone_w=0.12, depth=0.045)
	b.cyl((0, 0, 0.22), 0.33, 0.33, 0.02, P["stone_light"], seg=24)
	# ateş ağzı (Godot +z = Blender -y)
	b.box((0, -0.31, 0.08), (0.12, 0.06, 0.1), P["dark"])
	for i in range(5):
		t = math.pi * i / 4
		b.box((math.cos(t) * 0.075, -0.33, 0.13 + math.sin(t) * 0.04), (0.04, 0.03, 0.03), P["stone_light"], bevel=0.005)
	for k in range(3):
		b.cyl((-0.04 + k * 0.04, -0.33, 0.04), 0.014, 0.014, 0.1, P["wood"], seg=6, rot=(math.pi / 2, 0, 0.2 * (k - 1)))
	# demir ayaklar
	for i in range(3):
		a = i * 2 * math.pi / 3 + 0.5
		b.box((math.cos(a) * 0.24, math.sin(a) * 0.24, 0.32), (0.035, 0.035, 0.22), P["iron"], rot=(0, -0.25, a), mat=1)
	# kazan: yuvarlak gövdeli bakır, kalın dudak, iki kulp
	prof = [(0.1, 0.0), (0.2, 0.04), (0.25, 0.12), (0.26, 0.2), (0.27, 0.22), (0.28, 0.24), (0.24, 0.24)]
	b.lathe(prof, (0, 0, 0.22), P["copper"], seg=20, mat=1)
	b.cyl((0, 0, 0.44), 0.24, 0.24, 0.012, P["black"], seg=20)
	for s in (-1, 1):
		b.cyl((s * 0.28, 0, 0.42), 0.035, 0.035, 0.012, P["iron"], seg=10, rot=(0, math.pi / 2, 0), mat=1)
	# kepçe
	b.cyl((0.12, 0.08, 0.4), 0.008, 0.008, 0.32, P["wood_dark"], seg=5, rot=(0.6, 0.4, 0))
	ob = b.finish()
	empty("smoke", (0, 0, 0.5), ob)
	empty("fire", (0, -0.2, 0.18), ob)
	return ob


def cannon_tower():
	"""Balyemez Topu: taş tabya, sepet siperler ve gülleler; dönen ahşap kundak ("head") ve tunç namlu ("barrel")."""
	b = Builder("cannon_tower", seed=71)
	b.box((0, 0, 0.06), (0.64, 0.64, 0.12), P["stone"], bevel=0.01)
	b.stone_wall(-0.32, 0.32, 0.0, 0.12, -0.32, -1, course=0.06, stone_w=0.13, depth=0.03)
	b.stone_wall(-0.32, 0.32, 0.0, 0.12, 0.32, 1, course=0.06, stone_w=0.13, depth=0.03)
	b.stone_wall(-0.32, 0.32, 0.0, 0.12, -0.32, -1, course=0.06, stone_w=0.13, depth=0.03, along="y")
	b.stone_wall(-0.32, 0.32, 0.0, 0.12, 0.32, 1, course=0.06, stone_w=0.13, depth=0.03, along="y")
	# döşeme tahtaları
	for i in range(6):
		b.box((-0.25 + i * 0.1, 0, 0.125), (0.095, 0.58, 0.01), jitter(P["stone_grey"], 0.06, b.rng))
	# sepet siperler (gabion) arkada ve yanlarda
	for (x, y) in [(-0.26, 0.26), (0.26, 0.26), (-0.26, -0.05), (0.26, -0.05), (0, 0.27)]:
		b.cyl((x, y, 0.12), 0.055, 0.05, 0.1, P["wood_light"], seg=10, jit=0.06)
		b.cyl((x, y, 0.215), 0.048, 0.048, 0.008, P["soil"], seg=10)
	# gülle yığını
	for i, (x, y, z) in enumerate([(-0.18, 0.12, 0), (-0.13, 0.12, 0), (-0.155, 0.16, 0), (-0.155, 0.135, 0.035)]):
		b.sphere((x, y, 0.15 + z), 0.024, P["iron"], seg=8, rings=5, mat=1)
	ob = b.finish()
	# kundak
	h = Builder("head", seed=72)
	h.box((0, 0.04, 0.1), (0.24, 0.42, 0.06), P["wood"], bevel=0.008)
	for s in (-1, 1):
		h.box((s * 0.1, 0.0, 0.17), (0.04, 0.34, 0.1), P["wood"], rot=(0.18, 0, 0), bevel=0.006)
		h.cyl((s * 0.15, -0.02, 0.12), 0.11, 0.11, 0.035, P["wood_dark"], seg=14, rot=(0, math.pi / 2, 0))
		h.cyl((s * 0.17, -0.02, 0.12), 0.025, 0.025, 0.012, P["iron"], seg=8, rot=(0, math.pi / 2, 0), mat=1)
		for k in range(4):
			h.box((s * 0.155, -0.02, 0.12), (0.01, 0.2, 0.012), P["wood_dark"], rot=(k * math.pi / 4, 0, 0))
	ho = h.finish()
	ho.parent = ob
	ho.location = (0, 0, 0.12)
	# namlu: ön (-y) tarafa, hafif yukarı
	n = Builder("barrel", seed=73)
	prof = [(0.0, -0.22), (0.07, -0.21), (0.09, -0.17), (0.085, -0.1), (0.08, 0.1), (0.075, 0.12), (0.07, 0.3), (0.085, 0.33), (0.085, 0.38), (0.05, 0.38)]
	n.lathe([(r, z) for r, z in prof], (0, 0, 0), P["bronze"], seg=16, mat=1)
	for z in (-0.12, 0.0, 0.2):
		n.cyl((0, 0, z), 0.092, 0.092, 0.02, P["gold"], seg=16, mat=1)
	n.cyl((0, 0, 0.378), 0.045, 0.045, 0.004, P["black"], seg=12)
	for s in (-1, 1):
		n.cyl((s * 0.09, 0, 0.0), 0.02, 0.02, 0.05, P["bronze"], seg=8, rot=(0, math.pi / 2, 0), mat=1)
	no = n.finish()
	no.parent = ho
	no.location = (0, 0, 0.12)
	no.rotation_euler = (math.pi / 2 - 0.12, 0, 0)
	empty("muzzle_hint", (0, -0.45, 0.38), ob)
	return ob


def musket_tower():
	"""Tüfekçi Tabyası: alçak yuvarlak kesme taş tabya, mazgal dişleri, kum torbaları, cephane sandıkları."""
	b = Builder("musket_tower", seed=81)
	rock_base(b, 0.4, n=11)
	b.stone_ring((0, 0, 0), 0.4, 0.26, taper=0.04, course=0.065, stone_w=0.13, depth=0.05)
	b.cyl((0, 0, 0.26), 0.365, 0.365, 0.015, P["stone_light"], seg=28)
	b.cyl((0, 0, 0.27), 0.33, 0.33, 0.008, P["stone_grey"], seg=24)
	b.merlons_ring((0, 0, 0), 0.38, 0.275, 20, mh=0.08, md=0.06)
	# kum torbaları ön tarafta
	for i in range(7):
		a = -math.pi / 2 + (i - 3) * 0.22
		b.box((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.3), (0.05, 0.08, 0.035), jitter(P["canvas"], 0.06, b.rng), rot=(0, 0, a), bevel=0.012)
	for (x, y) in [(0.2, 0.18), (-0.2, 0.2)]:
		b.box((x, y, 0.31), (0.08, 0.06, 0.06), P["wood"], bevel=0.006)
		b.box((x, y - 0.031, 0.31), (0.07, 0.004, 0.01), P["iron"])
	wooden_door(b, -math.pi / 2, 0.38, w=0.1, h=0.14)
	ob = b.finish()
	empty("top", (0, 0, 0.28), ob)
	return ob


def gate():
	"""Sur kapısı: iki kalın taş ayak, kemer taşlı büyük kemer, açık ahşap kanatlar, üstte mazgallı taç, altın hilalli kitabe.
	Dış yüz +y (Godot -z)."""
	b = Builder("gate", seed=91)
	W, D, H = 1.2, 0.52, 0.95
	pal = [P["stone"], P["stone_light"], P["stone_grey"]]
	for s in (-1, 1):
		x0, x1 = (0.3, 0.6) if s > 0 else (-0.6, -0.3)
		b.box(((x0 + x1) / 2, 0, H / 2), (0.28, D - 0.06, H), P["mortar"])
		for yy, n in ((D / 2, 1), (-D / 2, -1)):
			b.stone_wall(x0, x1, 0.0, H, yy, n, col_pal=pal, course=0.08, stone_w=0.14, depth=0.04)
		b.stone_wall(-D / 2, D / 2, 0.0, H, x0 if s < 0 else x1, s, col_pal=pal, course=0.08, stone_w=0.14, depth=0.04, along="y")
		# iç yüz (geçide bakan)
		b.stone_wall(-D / 2, D / 2, 0.0, 0.62, x1 if s < 0 else x0, -s, col_pal=pal, course=0.08, stone_w=0.14, depth=0.03, along="y")
	# kemerin üstündeki gövde
	b.box((0, 0, 0.82), (0.62, D - 0.06, 0.26), P["mortar"])
	for yy, n in ((D / 2, 1), (-D / 2, -1)):
		b.stone_wall(-0.3, 0.3, 0.7, H, yy, n, col_pal=pal, course=0.08, stone_w=0.14, depth=0.04)
	# kemer taşları (dış ve iç yüz)
	for yy in (D / 2 + 0.01, -D / 2 - 0.01):
		for i in range(11):
			t = math.pi * (i + 0.5) / 11
			r = 0.3
			b.box((math.cos(t) * r, yy, 0.4 + math.sin(t) * r * 1.0), (0.06, 0.05, 0.1), P["stone_light"] if i % 2 else P["red"], rot=(0, -(t - math.pi / 2), 0), bevel=0.006)
	# geçidin tavanı ve koyu iç
	b.box((0, 0, 0.42), (0.6, D - 0.02, 0.84), P["dark"])
	b.box((0, 0, 0.004), (0.6, D + 0.1, 0.008), P["stone_grey"])
	# açık kanatlar
	for s in (-1, 1):
		px = s * 0.28
		b.box((px - s * 0.0, D / 2 + 0.14, 0.3), (0.03, 0.28, 0.56), P["wood_dark"], rot=(0, 0, s * 0.15), bevel=0.006)
		for z in (0.12, 0.3, 0.48):
			b.box((px + s * 0.017, D / 2 + 0.14, z), (0.008, 0.28, 0.025), P["iron"], rot=(0, 0, s * 0.15), mat=1)
	# kitabe ve hilal
	b.box((0, D / 2 + 0.02, 0.8), (0.34, 0.025, 0.12), P["iznik"], mat=2, bevel=0.005)
	b.box((0, D / 2 + 0.03, 0.8), (0.3, 0.012, 0.08), P["gold"], mat=1)
	b.box((0, D / 2 + 0.02, 0.86), (0.38, 0.03, 0.02), P["stone_light"])
	# taç: silme ve mazgallar iki yüzde
	b.box((0, 0, H + 0.015), (W + 0.04, D + 0.06, 0.03), P["stone_light"], bevel=0.006)
	for yy in (D / 2, -D / 2):
		for i in range(7):
			x = -W / 2 + (i + 0.5) * W / 7
			b.box((x, yy - 0.03 * (1 if yy > 0 else -1), H + 0.09), (0.1, 0.07, 0.12), jitter(P["stone_light"], 0.05, b.rng), bevel=0.01)
	return b.finish()


def camp_tent(stripe="red", name="camp_tent"):
	b = Builder(name, seed=97 if stripe == "red" else 98)
	import arch
	arch.tent(b, 0, 0, 0.2, 0.26, stripe=P[stripe], seg=8)
	# ip kazıkları
	for i in range(4):
		a = i * math.pi / 2 + math.pi / 4
		b.box((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.01), (0.012, 0.012, 0.03), P["wood_dark"])
	return b.finish()
