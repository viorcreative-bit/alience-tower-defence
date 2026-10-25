# Patron düşmanlar: dev mancınık, savaş fili, zırhlı kuşatma kulesi. Ölçü oyun karesi, ön -Y (Godot +Z, gidiş yönü).
# "Primary" örgüleri açık renktir (millet rengiyle boyanır). Hareketli parçalar ayrı düğüm:
#  tekerlekler "wheel0".."wheel3" (eksen merkezinde, yerel X çevresinde döner), mancınık kolu "arm" (X çevresinde),
#  filin bacakları "leg0".."leg3" (kalçadan X çevresinde, animate_horse ile uyumlu), hortum "trunk".

import math

from kit import P, Builder, empty, jitter, mix, mul, srgb

HIDE = srgb("#8f8a86")
TUSK = srgb("#f1ead8")


def _wheel(name, x, y, r, w=0.06, parent=None, seed=0):
	b = Builder(name, 400 + seed)
	b.cyl((0, 0, 0), r, r, w, P["wood_dark"], seg=14, rot=(0, math.pi / 2, 0), jit=0.0)
	b.cyl((w / 2 + 0.003, 0, 0), r * 0.25, r * 0.25, 0.012, P["iron"], seg=8, rot=(0, math.pi / 2, 0), mat=1)
	for k in range(6):
		b.box((0, 0, 0), (w * 0.6, 0.025, r * 1.85), P["wood"], rot=(k * math.pi / 6, 0, 0))
	b.cyl((-w / 2 - 0.002, 0, 0), r * 1.02, r * 1.02, w + 0.004, P["iron"], seg=14, rot=(0, math.pi / 2, 0), mat=1, cap_top=False, cap_bot=False)
	o = b.finish()
	o.location = (x, y, r)
	if parent:
		o.parent = parent
	return o


def trebuchet():
	"""Dev mancınık: tekerlekli ahşap şasi, iki A ayak, uzun atış kolu ve ağırlık sandığı, sapan."""
	b = Builder("boss_trebuchet", 411)
	L, W = 1.1, 0.55
	for s in (-1, 1):
		b.box((s * W / 2, 0, 0.16), (0.07, L, 0.07), P["wood"], bevel=0.008)
	for y in (-L / 2 + 0.06, 0, L / 2 - 0.06):
		b.box((0, y, 0.16), (W + 0.07, 0.06, 0.06), P["wood"], bevel=0.008)
	# A ayaklar
	for s in (-1, 1):
		for d in (-1, 1):
			b.box((s * W / 2, d * 0.17, 0.48), (0.06, 0.06, 0.68), P["wood"], rot=(d * 0.42, 0, 0), bevel=0.008)
		b.box((s * W / 2, 0, 0.4), (0.05, 0.34, 0.04), P["wood_dark"])
	b.cyl((-W / 2 - 0.05, 0, 0.78), 0.035, 0.035, W + 0.1, P["iron"], seg=10, rot=(0, math.pi / 2, 0), mat=1)
	# atış oluğu ve taş yığını
	b.box((0, 0.25, 0.2), (0.12, 0.5, 0.02), P["wood_light"])
	for i in range(4):
		b.sphere((0.16 + (i % 2) * 0.07, 0.38 + (i // 2) * 0.07, 0.24), 0.04, P["rock"], seg=8, rings=5, smooth=False)
	# millet örtüsü
	pr = Builder("Primary", 412)
	for s in (-1, 1):
		pr.box((s * (W / 2 + 0.04), 0.0, 0.26), (0.01, 0.5, 0.14), P["white"])
	ob = b.finish()
	pr.finish().parent = ob
	for i, (x, y) in enumerate([(-W / 2 - 0.06, -0.38), (W / 2 + 0.06, -0.38), (-W / 2 - 0.06, 0.38), (W / 2 + 0.06, 0.38)]):
		_wheel("wheel%d" % i, x, y, 0.13, parent=ob, seed=i)
	# kol: dönme noktası aksta; uzun ucu arkaya (+y) ve aşağı, ağırlık sandığı öne
	a = Builder("arm", 413)
	a.box((0, 0.25, 0), (0.06, 1.0, 0.06), P["wood_light"], bevel=0.01)
	for k in range(4):
		a.box((0, -0.1 + k * 0.22, 0), (0.07, 0.02, 0.07), P["iron"], mat=1)
	a.box((0, -0.32, -0.12), (0.26, 0.2, 0.22), P["wood_dark"], bevel=0.015)
	for k in range(3):
		a.box((0, -0.32, -0.21 + k * 0.08), (0.27, 0.21, 0.015), P["iron"], mat=1)
	a.cyl((0, 0.75, 0), 0.006, 0.006, 0.3, P["cream"], seg=4, rot=(0, 0, 0))
	a.sphere((0, 0.75, -0.05), 0.04, P["rock"], seg=8, rings=5, smooth=False)
	ao = a.finish()
	ao.parent = ob
	ao.location = (0, 0, 0.78)
	ao.rotation_euler = (-0.45, 0, 0)
	empty("muzzle", (0, 0.4, 1.1), ob)
	return ob


def elephant():
	"""Savaş fili: iri gri gövde, kulaklar, dişler, hortum ("trunk"), sırtında örtülü ahşap kule ("Primary" örtü)."""
	body = Builder("boss_elephant", 421)
	body.box((0, 0.02, 0.95), (0.62, 1.05, 0.62), HIDE, bevel=0.22)
	body.box((0, -0.62, 1.08), (0.46, 0.38, 0.46), HIDE, bevel=0.16)
	for s in (-1, 1):
		body.box((s * 0.27, -0.55, 1.08), (0.04, 0.3, 0.38), mul(HIDE, 0.92), rot=(0, 0, s * 0.35), bevel=0.04)
		body.box((s * 0.15, -0.8, 1.15), (0.03, 0.02, 0.03), P["black"])
		body.cyl((s * 0.12, -0.8, 0.9), 0.03, 0.006, 0.28, TUSK, seg=8, rot=(-1.9, 0, s * 0.2))
	body.box((0, 0.58, 0.95), (0.03, 0.04, 0.3), mul(HIDE, 0.8), rot=(0.3, 0, 0))
	ob = body.finish()
	tr = Builder("trunk", 422)
	for k in range(6):
		r = 0.075 - k * 0.008
		tr.cyl((0, -0.02 * k, -0.1 * k), r, r * 0.92, 0.11, HIDE, seg=10, rot=(0.15 * k, 0, 0))
	to = tr.finish()
	to.parent = ob
	to.location = (0, -0.82, 0.98)
	# örtü ve kule
	pr = Builder("Primary", 423)
	pr.box((0, 0.05, 1.28), (0.66, 0.6, 0.06), P["white"], bevel=0.02)
	for s in (-1, 1):
		pr.box((s * 0.33, 0.05, 1.08), (0.02, 0.6, 0.38), P["white"])
	pr.finish().parent = ob
	g = Builder("Gear", 424)
	for s in (-1, 1):
		g.box((s * 0.345, 0.05, 0.9), (0.02, 0.62, 0.04), P["gold"], mat=1)
	g.box((0, 0.05, 1.35), (0.5, 0.5, 0.08), P["wood"], bevel=0.01)
	for sx in (-1, 1):
		for sy in (-1, 1):
			g.box((sx * 0.22, 0.05 + sy * 0.22, 1.58), (0.04, 0.04, 0.4), P["wood_dark"])
	for sx in (-1, 1):
		g.box((sx * 0.24, 0.05, 1.5), (0.02, 0.48, 0.18), P["wood_light"])
		g.box((0, 0.05 + sx * 0.24, 1.5), (0.48, 0.02, 0.18), P["wood_light"])
	g.lathe([(0.36, 0.0), (0.25, 0.08), (0.0, 0.22)], (0, 0.05, 1.78), P["red"], seg=4, smooth=False, ribs=(P["red_dark"], 2))
	g.box((0, -0.36, 1.32), (0.12, 0.06, 0.12), P["gold"], mat=1, bevel=0.01)
	g.finish().parent = ob
	for i, (x, y) in enumerate([(-0.2, -0.32), (0.2, -0.32), (-0.2, 0.36), (0.2, 0.36)]):
		lb = Builder("leg%d" % i, 430 + i)
		lb.cyl((0, 0, -0.78), 0.12, 0.13, 0.8, HIDE, seg=10)
		lb.cyl((0, 0, -0.8), 0.135, 0.135, 0.06, mul(HIDE, 0.85), seg=10)
		for k in range(3):
			a = -math.pi / 2 + (k - 1) * 0.5
			lb.sphere((math.cos(a) * 0.12, math.sin(a) * 0.12, -0.78), 0.025, TUSK, seg=6, rings=4)
		lo = lb.finish()
		lo.parent = ob
		lo.location = (x, y, 0.8)
	empty("rider", (0, 0.05, 1.4), ob)
	return ob


def siege_ram():
	"""Zırhlı kuşatma kulesi: tekerlekli, demir levha kaplı üç katlı kule, önde iniş köprüsü ("bridge"),
	altında demir başlı koçbaşı, tepede mazgallar ve sancak yeri."""
	b = Builder("boss_tower", 441)
	W, D, H = 0.62, 0.7, 1.35
	b.box((0, 0, 0.14), (W + 0.12, D + 0.1, 0.08), P["wood_dark"], bevel=0.01)
	for k in range(3):
		z0 = 0.18 + k * H / 3
		b.box((0, 0, z0 + H / 6), (W - k * 0.04, D - k * 0.04, H / 3), P["wood"], bevel=0.01)
		# demir levhalar ve perçinler
		for s in (-1, 1):
			for j in range(3):
				x = (j - 1) * (W - k * 0.04) / 3
				b.box((x, s * ((D - k * 0.04) / 2 + 0.006), z0 + H / 6), ((W - k * 0.04) / 3 - 0.01, 0.012, H / 3 - 0.03), srgb("#7a7f8a"), mat=1)
				b.box((x, s * ((D - k * 0.04) / 2 + 0.014), z0 + H / 3 - 0.04), (0.02, 0.008, 0.02), P["stone_grey"], mat=1)
		b.box((0, 0, z0 + H / 3), (W - k * 0.04 + 0.04, D - k * 0.04 + 0.04, 0.03), P["wood_dark"])
	zt = 0.18 + H
	for i in range(5):
		for s in (-1, 1):
			b.box((-0.22 + i * 0.11, s * 0.26, zt + 0.06), (0.06, 0.04, 0.1), P["wood_dark"], bevel=0.005)
	# koçbaşı
	b.cyl((0, -0.1, 0.32), 0.07, 0.07, 0.75, P["wood_dark"], seg=10, rot=(math.pi / 2, 0, 0))
	b.cyl((0, -0.85, 0.32), 0.09, 0.07, 0.12, P["iron"], seg=10, rot=(math.pi / 2, 0, 0), mat=1)
	b.sphere((0, -0.88, 0.32), 0.07, P["iron"], seg=10, rings=6, mat=1, scale=(1, 1.3, 1))
	pr = Builder("Primary", 442)
	for s in (-1, 1):
		pr.box((s * (W / 2 + 0.01), 0, 0.78), (0.012, 0.36, 0.5), P["white"])
	ob = b.finish()
	pr.finish().parent = ob
	br = Builder("bridge", 443)
	br.box((0, -0.25, 0), (0.44, 0.5, 0.03), P["wood_light"], bevel=0.005)
	for k in range(5):
		br.box((0, -0.05 - k * 0.1, 0.018), (0.44, 0.012, 0.008), P["wood_dark"])
	bo = br.finish()
	bo.parent = ob
	bo.location = (0, -D / 2 + 0.02, zt - 0.05)
	bo.rotation_euler = (-1.45, 0, 0)
	for i, (x, y) in enumerate([(-W / 2 - 0.08, -0.25), (W / 2 + 0.08, -0.25), (-W / 2 - 0.08, 0.25), (W / 2 + 0.08, 0.25)]):
		_wheel("wheel%d" % i, x, y, 0.14, w=0.07, parent=ob, seed=10 + i)
	empty("flag", (0.22, 0.25, zt + 0.1), ob)
	return ob
