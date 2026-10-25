# Osmanlı mimarisi parçaları: almaşık duvarlı gövde, kemerli pencere, kubbe, minare, kiremit çatı, revak, çadır.
# Ön yüz -Y (Godot'ta +Z, kameraya bakan taraf).

import math

import bmesh
from mathutils import Matrix, Vector

from kit import P, jitter, mix, mul

ALMASIK = "almasik"  # taş sıraları arasında ince tuğla şeritler
STONE = "stone"
PLASTER = "plaster"


def body(b, cx, cy, w, d, h, style=ALMASIK, z0=0.0, plinth=True, cornice=True):
	"""Dikdörtgen gövde: dört yüzü taş (ya da badanalı) duvar, kaide ve saçak silmesi. Dönüş: üst kot."""
	if plinth:
		b.box((cx, cy, z0 + 0.02), (w + 0.04, d + 0.04, 0.04), P["stone_dark"], bevel=0.008)
		z0 += 0.04
	if style == PLASTER:
		b.box((cx, cy, z0 + h / 2), (w, d, h), P["white"], bevel=0.006)
		# köşe taşları
		for sx in (-1, 1):
			for sy in (-1, 1):
				for k in range(int(h / 0.06)):
					s = 0.045 if k % 2 else 0.03
					b.box((cx + sx * (w / 2 - s / 2 + 0.004), cy + sy * (d / 2 - 0.03 / 2 + 0.004), z0 + 0.03 + k * 0.06), (s, 0.03, 0.055), jitter(P["stone"], 0.05, b.rng), bevel=0.004)
	else:
		pal = [P["stone"], P["stone_light"], P["stone_grey"]]
		course = 0.06
		b.box((cx, cy, z0 + h / 2), (w - 0.03, d - 0.03, h), P["mortar"])
		for (x0, x1, y, n, along) in [
			(cx - w / 2, cx + w / 2, cy - d / 2 + 0.02, -1, "x"),
			(cx - w / 2, cx + w / 2, cy + d / 2 - 0.02, 1, "x"),
			(cy - d / 2 + 0.02, cy + d / 2 - 0.02, cx - w / 2 + 0.02, -1, "y"),
			(cy - d / 2 + 0.02, cy + d / 2 - 0.02, cx + w / 2 - 0.02, 1, "y"),
		]:
			if style == ALMASIK:
				z = z0
				k = 0
				while z < z0 + h - 0.01:
					hh = min(0.075, z0 + h - z)
					b.stone_wall(x0, x1, z, z + hh, y, n, col_pal=pal, course=hh, stone_w=0.11, depth=0.022, bevel=0.005, gap=0.005, along=along)
					z += hh
					if z < z0 + h - 0.03:
						# tuğla şeridi
						if along == "x":
							b.box(((x0 + x1) / 2, y + n * 0.004, z + 0.009), (x1 - x0, 0.03, 0.018), jitter(P["roof"], 0.05, b.rng))
						else:
							b.box((y + n * 0.004, (x0 + x1) / 2, z + 0.009), (0.03, x1 - x0, 0.018), jitter(P["roof"], 0.05, b.rng))
						z += 0.018
					k += 1
			else:
				b.stone_wall(x0, x1, z0, z0 + h, y, n, col_pal=pal, course=course, stone_w=0.11, depth=0.022, bevel=0.005, gap=0.005, along=along)
	top = z0 + h
	if cornice:
		b.box((cx, cy, top + 0.012), (w + 0.03, d + 0.03, 0.024), P["stone_light"], bevel=0.006)
		top += 0.024
	return top


def window(b, x, y, z, w=0.05, h=0.08, face=-1, axis="x", frame=P["stone_light"], tile=False):
	"""Kemerli pencere: koyu boşluk, taş çerçeve, sivri kemer; isteğe bağlı çini alınlık."""
	off = face * 0.012
	def put(dx, dz, size, col, mat=0):
		if axis == "x":
			b.box((x + dx, y + off + face * 0.002, z + dz), (size[0], 0.02, size[1]), col, mat=mat)
		else:
			b.box((y + off + face * 0.002, x + dx, z + dz), (0.02, size[0], size[1]), col, mat=mat)
	put(0, 0, (w + 0.022, h + 0.02), frame)
	off += face * 0.004
	put(0, -0.002, (w, h - 0.008), P["dark"])
	# kemer: üstte daralan basamaklar
	put(0, h / 2 + 0.008, (w * 0.75, 0.014), P["dark"])
	put(0, h / 2 + 0.018, (w * 0.4, 0.01), P["dark"])
	if tile:
		put(0, h / 2 + 0.036, (w + 0.02, 0.018), P["iznik"], 2)
	# demir parmaklık
	put(0, -0.01, (0.006, h - 0.02), P["iron"])
	# denizlik
	off -= face * 0.008
	put(0, -h / 2 - 0.006, (w + 0.03, 0.012), P["stone_light"])


def door(b, x, y, w=0.09, h=0.13, face=-1, col=None):
	b.box((x, y + face * 0.012, h / 2 + 0.04), (w + 0.04, 0.024, h + 0.04), P["stone_light"], bevel=0.004)
	b.box((x, y + face * 0.022, h / 2 + 0.035), (w, 0.012, h), col or P["wood_dark"])
	b.box((x, y + face * 0.026, h * 0.55 + 0.035), (0.004, 0.008, h * 0.9), P["dark"])
	for k in (-1, 1):
		b.box((x + k * w * 0.25, y + face * 0.03, h * 0.5 + 0.035), (0.012, 0.006, 0.012), P["gold"], mat=1)
	b.box((x, y + face * 0.026, h + 0.06), (w + 0.03, 0.016, 0.02), P["iznik"], mat=2)


def dome(b, cx, cy, z, r, drum=0.05, col=None, ribs=True, alem=True, drum_style="stone", seg=20):
	"""Kasnaklı kurşun kubbe ve altın alem. Dönüş: alem dahil tepe kotu."""
	if drum > 0:
		if drum_style == "stone":
			b.stone_ring((cx, cy, z), r + 0.01, drum, course=min(0.05, drum), stone_w=0.08, depth=0.025, bevel=0.004, palette=[P["stone_light"], P["stone"]])
		else:
			b.cyl((cx, cy, z), r + 0.01, r + 0.01, drum, P["white"], seg=seg)
		# kasnak pencereleri
		n = max(6, int(r * 50))
		for i in range(n):
			if i % 2:
				continue
			a = i * 2 * math.pi / n
			b.box((cx + math.cos(a) * (r + 0.012), cy + math.sin(a) * (r + 0.012), z + drum * 0.5), (0.01, r * 0.18, drum * 0.55), P["dark"], rot=(0, 0, a))
		b.cyl((cx, cy, z + drum), r + 0.02, r + 0.02, 0.012, P["stone_light"], seg=seg)
		z += drum + 0.012
	prof = []
	for i in range(9):
		t = i / 8
		ang = t * math.pi / 2
		prof.append((r * math.cos(ang) * (1.0 + 0.05 * math.sin(t * math.pi)), r * 1.02 * math.sin(ang)))
	prof[-1] = (0.0, prof[-1][1])
	b.lathe(prof, (cx, cy, z), col or P["lead"], seg=seg, mat=1, ribs=(P["lead_light"], 3) if ribs else None)
	top = z + r * 1.02
	if alem:
		hh = max(0.04, r * 0.5)
		b.cyl((cx, cy, top - 0.005), 0.004 + r * 0.03, 0.003, hh, P["gold"], seg=6, mat=1)
		b.sphere((cx, cy, top + hh * 0.4), 0.006 + r * 0.06, P["gold"], seg=8, rings=5, mat=1)
		b.sphere((cx, cy, top + hh * 0.7), 0.004 + r * 0.045, P["gold"], seg=8, rings=5, mat=1)
		top += hh
	return top


def minaret(b, x, y, h=0.95, r=0.035, z0=0.0):
	"""Kalem minare: kare kaide, ince gövde, şerefe, kurşun külah, alem."""
	b.box((x, y, z0 + 0.06), (r * 2.8, r * 2.8, 0.12), P["stone"], bevel=0.005)
	b.cyl((x, y, z0 + 0.12), r * 1.5, r * 1.2, 0.04, P["stone_light"], seg=10)
	b.cyl((x, y, z0 + 0.16), r * 1.12, r, h * 0.62, P["stone_light"], seg=10)
	for k in range(5):
		b.cyl((x, y, z0 + 0.2 + k * h * 0.12), r * 1.13, r * 1.13, 0.008, P["stone_dark"], seg=10)
	zs = z0 + 0.16 + h * 0.62
	b.cyl((x, y, zs - 0.02), r * 1.05, r * 1.9, 0.03, P["stone_light"], seg=10)
	b.cyl((x, y, zs + 0.01), r * 1.95, r * 1.95, 0.012, P["stone"], seg=10)
	b.cyl((x, y, zs + 0.022), r * 1.9, r * 1.9, 0.025, P["stone_light"], seg=10, cap_top=False)
	b.cyl((x, y, zs + 0.02), r * 0.92, r * 0.85, h * 0.15, P["stone_light"], seg=10)
	zc = zs + 0.02 + h * 0.15
	b.cyl((x, y, zc), r * 1.15, r * 1.15, 0.01, P["stone_light"], seg=10)
	b.cyl((x, y, zc + 0.01), r * 1.05, 0.002, h * 0.2, P["lead"], seg=10, mat=1)
	zt = zc + 0.01 + h * 0.2
	b.cyl((x, y, zt - 0.005), 0.003, 0.003, 0.05, P["gold"], seg=5, mat=1)
	b.sphere((x, y, zt + 0.025), 0.008, P["gold"], seg=6, rings=4, mat=1)
	return zt + 0.05


def tile_roof(b, cx, cy, z, w, d, h, steps=5, col=None, eave=0.03):
	"""Basamaklı kiremit çatı: her sıra biraz içe çekilmiş, dikdörtgen tabanlı kesik piramit; sıralar açık-koyu."""
	col = col or P["roof"]
	W, D = w / 2 + eave, d / 2 + eave
	m = min(W, D)
	out = []
	for k in range(steps):
		t0, t1 = k / steps, (k + 1) / steps
		def rect(t, zz):
			sh = m * t * 0.97
			return [(-W + sh, -D + sh, zz), (W - sh, -D + sh, zz), (W - sh, D - sh, zz), (-W + sh, D - sh, zz)]
		lo = rect(t0, z + t0 * h)
		hi = rect(t1, z + t1 * h)
		# sırayı biraz aşağı sarkıt: kiremit kenarı
		lo = [(x * 1.015, y * 1.015, zz - 0.01) for x, y, zz in lo]
		tb = bmesh.new()
		vl = [tb.verts.new(p) for p in lo]
		vh = [tb.verts.new(p) for p in hi]
		for i in range(4):
			j = (i + 1) % 4
			tb.faces.new((vl[i], vl[j], vh[j], vh[i]))
		tb.faces.new(list(reversed(vl)))
		if k == steps - 1:
			tb.faces.new(vh)
		c = jitter(mix(col, P["roof_dark"], 0.3 if k % 2 else 0.0), 0.03, b.rng)
		out += b._merge(tb, c, matrix=Matrix.Translation(Vector((cx, cy, 0))))
	# mahya
	if abs(W - D) > 0.01:
		L = abs(W - D) * 2
		if W > D:
			b.box((cx, cy, z + h + 0.005), (L + 0.02, 0.025, 0.02), P["roof_dark"])
		else:
			b.box((cx, cy, z + h + 0.005), (0.025, L + 0.02, 0.02), P["roof_dark"])
	return z + h


def arcade(b, x0, x1, y, z0, h, n, face=-1, roof=True):
	"""Revak: sütunlar, sivri kemerler, üstte küçük kubbeler ya da saçak."""
	step = (x1 - x0) / n
	for i in range(n + 1):
		x = x0 + i * step
		b.cyl((x, y, z0), 0.014, 0.012, h * 0.75, P["white"], seg=8)
		b.box((x, y, z0 + h * 0.75 + 0.01), (0.03, 0.03, 0.02), P["stone_light"])
	# kemer bandı
	for i in range(n):
		xm = x0 + (i + 0.5) * step
		for k in range(5):
			t = math.pi * (k + 0.5) / 5
			ax = xm - math.cos(t) * step * 0.45
			az = z0 + h * 0.75 + math.sin(t) * step * 0.35
			b.box((ax, y, az), (step * 0.24, 0.035, 0.03), P["roof"] if k % 2 else P["white"], rot=(0, -(t - math.pi / 2) * 0.9, 0))
	b.box(((x0 + x1) / 2, y, z0 + h + 0.01), (x1 - x0 + 0.04, 0.05, 0.03), P["stone_light"], bevel=0.005)
	return z0 + h + 0.025


def tent(b, cx, cy, r, h, col=P["canvas"], stripe=P["red"], seg=8, wall=0.08, flag=False):
	"""Çadır: kısa duvar, çizgili konik tavan, direk ve tepe topuzu."""
	b.cyl((cx, cy, 0), r, r * 0.98, wall, col, seg=seg)
	b.box((cx, cy - r * 0.93, wall * 0.45), (r * 0.5, 0.02, wall * 0.9), P["dark"], rot=(0, 0, 0))
	prof = [(r * 1.08, 0.0), (r * 0.7, h * 0.35), (r * 0.3, h * 0.75), (0.0, h)]
	b.lathe(prof, (cx, cy, wall), col, seg=seg * 2, smooth=False, ribs=(stripe, 2))
	# saçak dilimleri
	for i in range(seg * 2):
		a = (i + 0.5) * math.pi / seg
		b.box((cx + math.cos(a) * r * 1.07, cy + math.sin(a) * r * 1.07, wall - 0.012), (0.01, r * 0.3, 0.025), stripe if i % 2 else col, rot=(0, 0, a))
	b.cyl((cx, cy, wall + h - 0.01), 0.006, 0.006, 0.07, P["wood"], seg=5)
	b.sphere((cx, cy, wall + h + 0.065), 0.014, P["gold"], seg=8, rings=5, mat=1)


def awning_stall(b, cx, cy, w=0.2, d=0.15, col=P["red"], col2=P["cream"], goods=None):
	"""Tenteli çarşı tezgâhı: dört direk, çizgili eğimli tente, mal dolu tezgâh."""
	for sx in (-1, 1):
		for sy in (-1, 1):
			b.box((cx + sx * w / 2, cy + sy * d / 2, 0.11 if sy < 0 else 0.13), (0.012, 0.012, 0.22 if sy < 0 else 0.26), P["wood"])
	n = 6
	for i in range(n):
		x = cx - w / 2 + (i + 0.5) * w / n
		b.box((x, cy, 0.25), (w / n + 0.002, d + 0.06, 0.012), col if i % 2 else col2, rot=(-0.3, 0, 0))
	b.box((cx, cy - d / 2 - 0.03, 0.225), (w + 0.01, 0.006, 0.03), col)
	b.box((cx, cy - d * 0.15, 0.06), (w * 0.9, d * 0.55, 0.06), P["wood_light"], bevel=0.004)
	goods = goods or [P["red"], P["gold"], P["green"], P["copper"]]
	for i in range(5):
		x = cx - w * 0.36 + i * w * 0.18
		g = goods[i % len(goods)]
		b.sphere((x, cy - d * 0.15, 0.1), 0.018, g, seg=6, rings=4, smooth=False, mat=1 if g == P["gold"] else 0)
