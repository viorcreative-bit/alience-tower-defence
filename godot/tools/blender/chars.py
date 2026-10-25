# İskeletli, canlandırılmış askerler ve düşmanlar; at. Boy ~1 birim (oyunda ölçeklenir), yüz -Y (Godot +Z).
# İskelet "Rig", kemikler: hips, spine, head, upperarm_l/r, forearm_l/r, handslot_l/r, thigh_l/r, shin_l/r.
# Örgüler: "Primary" ve "Secondary" (açık renk; düşmanlarda millet rengiyle boyanır), "Gear" (sabit renkli).
# Canlandırmalar: Idle, Walking_A, Running_A, Sit_Chair_Idle (at üstü), Cheer, 1H_Melee_Attack_Chop (KayKit adlarıyla aynı).

import math

import bpy
from mathutils import Euler, Matrix, Vector

from kit import P, Builder, mix, mul, srgb

SKIN = srgb("#e3b48c")
FPS = 24

# kemik: (baş, kuyruk, ebeveyn)
BONES = {
	"hips": ((0, 0, 0.44), (0, 0, 0.54), None),
	"spine": ((0, 0, 0.54), (0, 0, 0.74), "hips"),
	"head": ((0, 0, 0.74), (0, 0, 0.98), "spine"),
	"upperarm_l": ((0.13, 0, 0.7), (0.15, 0, 0.53), "spine"),
	"forearm_l": ((0.15, 0, 0.53), (0.155, 0, 0.38), "upperarm_l"),
	"handslot_l": ((0.155, 0, 0.38), (0.155, 0, 0.33), "forearm_l"),
	"upperarm_r": ((-0.13, 0, 0.7), (-0.15, 0, 0.53), "spine"),
	"forearm_r": ((-0.15, 0, 0.53), (-0.155, 0, 0.38), "upperarm_r"),
	"handslot_r": ((-0.155, 0, 0.38), (-0.155, 0, 0.33), "forearm_r"),
	"thigh_l": ((0.06, 0, 0.44), (0.065, 0, 0.24), "hips"),
	"shin_l": ((0.065, 0, 0.24), (0.065, 0, 0.04), "thigh_l"),
	"thigh_r": ((-0.06, 0, 0.44), (-0.065, 0, 0.24), "hips"),
	"shin_r": ((-0.065, 0, 0.24), (-0.065, 0, 0.04), "thigh_r"),
}


class Char:
	"""Parçaları kemiklere ve renk gruplarına göre toplar."""

	def __init__(self, name, seed=1):
		self.name = name
		self.seed = seed
		self.parts = {}  # (grup, kemik) -> Builder

	def b(self, bone, group="Gear"):
		key = (group, bone)
		if key not in self.parts:
			self.parts[key] = Builder("%s_%s" % (group, bone), self.seed + len(self.parts))
		return self.parts[key]


# ---------------------------------------------------------------- gövde parçaları

def base_body(c, coat, pants, boots=P["wood_dark"], coat_group="Primary", skirt=0.0, sash=None, belly=1.0):
	"""Tıknaz, büyük kafalı gövde: kaftan/gövde, kollar, bacaklar, kafa."""
	g = c.b("spine", coat_group)
	g.cyl((0, 0, 0.5), 0.12 * belly, 0.11, 0.24, coat, seg=10)
	g.cyl((0, 0, 0.74), 0.11, 0.06, 0.03, coat, seg=10)
	if sash:
		c.b("hips").cyl((0, 0, 0.5), 0.125 * belly, 0.125 * belly, 0.04, sash, seg=10)
	h = c.b("hips", coat_group)
	h.cyl((0, 0, 0.38), 0.12 + skirt, 0.12, 0.13, coat, seg=10)
	if skirt > 0:
		h.cyl((0, 0, 0.2), 0.12 + skirt * 1.6, 0.12 + skirt, 0.18, coat, seg=10, cap_bot=True)
	# bacaklar
	for s, side in ((1, "l"), (-1, "r")):
		t = c.b("thigh_" + side)
		t.cyl((s * 0.063, 0, 0.24), 0.048, 0.055, 0.2, pants, seg=8)
		sh = c.b("shin_" + side)
		sh.cyl((s * 0.065, 0, 0.06), 0.042, 0.047, 0.18, pants, seg=8)
		sh.box((s * 0.065, -0.02, 0.03), (0.075, 0.12, 0.06), boots, bevel=0.015)
		# kollar
		u = c.b("upperarm_" + side, coat_group)
		u.cyl((s * 0.15, 0, 0.52), 0.04, 0.045, 0.18, coat, seg=8)
		u.sphere((s * 0.135, 0, 0.69), 0.05, coat, seg=8, rings=5)
		f = c.b("forearm_" + side, coat_group)
		f.cyl((s * 0.155, 0, 0.38), 0.038, 0.04, 0.16, coat, seg=8)
		f.cyl((s * 0.155, 0, 0.4), 0.045, 0.045, 0.03, mul(coat, 0.8), seg=8)
		hs = c.b("handslot_" + side)
		hs.sphere((s * 0.155, -0.005, 0.355), 0.035, SKIN, seg=8, rings=5)


def head(c, mustache=P["dark"], beard=False, skin=SKIN, eyes=True):
	h = c.b("head")
	h.cyl((0, 0, 0.74), 0.04, 0.045, 0.05, skin, seg=8)
	h.sphere((0, 0, 0.88), 0.13, skin, seg=14, rings=9, scale=(1, 0.95, 1.02))
	h.sphere((0, -0.125, 0.86), 0.022, mul(skin, 0.93), seg=6, rings=4)
	if eyes:
		for s in (-1, 1):
			h.box((s * 0.045, -0.122, 0.9), (0.022, 0.012, 0.03), P["black"], rot=(0.1, 0, 0))
			h.box((s * 0.045, -0.125, 0.93), (0.04, 0.01, 0.01), mul(P["dark"], 1.2))
	if mustache:
		for s in (-1, 1):
			h.box((s * 0.03, -0.122, 0.835), (0.05, 0.02, 0.018), mustache, rot=(0, s * 0.35, 0), bevel=0.006)
	if beard:
		h.sphere((0, -0.07, 0.79), 0.085, mustache or P["dark"], seg=10, rings=6, scale=(1, 0.7, 0.9))
	for s in (-1, 1):
		h.sphere((s * 0.128, 0, 0.88), 0.025, skin, seg=6, rings=4)


def bork(c):
	"""Yeniçeri börkü: beyaz keçe, arkaya düşen yatırtma, önde altın kaşıklık."""
	h = c.b("head")
	h.cyl((0, 0, 0.93), 0.135, 0.12, 0.17, P["white"], seg=12)
	h.cyl((0, 0.07, 1.05), 0.11, 0.1, 0.22, P["white"], seg=10, rot=(-1.15, 0, 0))
	h.cyl((0, 0, 0.93), 0.138, 0.138, 0.035, P["gold"], seg=12, mat=1)
	h.box((0, -0.13, 1.02), (0.035, 0.03, 0.12), P["gold"], mat=1, bevel=0.01)


def turban(c, col=P["white"], big=False, cap=P["red"]):
	h = c.b("head")
	k = 1.25 if big else 1.0
	for i in range(3):
		h.cyl((0, 0, 0.93 + i * 0.035 * k), (0.15 - i * 0.012) * k, (0.15 - i * 0.012) * k, 0.04 * k, col, seg=12, smooth=True)
	h.sphere((0, 0, 0.93 + 0.11 * k), 0.12 * k, col, seg=12, rings=7, scale=(1, 1, 0.75))
	h.cyl((0, 0, 0.98 + 0.1 * k), 0.06, 0.05, 0.05 * k, cap, seg=8)
	if big:
		h.box((0, -0.16, 1.03), (0.03, 0.03, 0.08), P["gold"], mat=1)
		h.sphere((0, -0.17, 1.08), 0.02, P["red"], seg=6, rings=4)


def helmet(c, metal=P["iron"], plume=None, nasal=True, group="Gear"):
	h = c.b("head", group)
	h.sphere((0, 0, 0.9), 0.14, metal, seg=12, rings=7, hemi=True, scale=(1, 1, 1.15), mat=1)
	h.cyl((0, 0, 0.89), 0.145, 0.145, 0.03, mul(metal, 0.85), seg=12, mat=1)
	h.cyl((0, 0, 1.05), 0.012, 0.02, 0.04, metal, seg=6, mat=1)
	if nasal:
		h.box((0, -0.142, 0.87), (0.02, 0.012, 0.07), metal, mat=1)
	if plume:
		h.sphere((0, 0.02, 1.12), 0.05, plume, seg=8, rings=5, scale=(0.6, 1.4, 1.0))


def great_helm(c, metal=P["stone_grey"], plume=None):
	h = c.b("head", "Secondary")
	h.cyl((0, 0, 0.77), 0.14, 0.14, 0.22, metal, seg=12)
	h.sphere((0, 0, 0.99), 0.14, metal, seg=12, rings=6, hemi=True, scale=(1, 1, 0.5))
	g = c.b("head")
	g.box((0, -0.14, 0.9), (0.18, 0.012, 0.02), P["black"])
	g.box((0, -0.14, 0.84), (0.012, 0.012, 0.08), P["black"])
	if plume:
		g.sphere((0, 0.03, 1.1), 0.06, plume, seg=8, rings=5, scale=(0.5, 1.6, 1.2))


def hood(c, col):
	h = c.b("head", "Secondary")
	h.sphere((0, 0.01, 0.9), 0.15, col, seg=12, rings=7, scale=(1, 1.05, 1.1))
	h.cyl((0, 0.06, 0.66), 0.16, 0.12, 0.12, col, seg=10)
	g = c.b("head")
	g.box((0, -0.14, 0.88), (0.2, 0.02, 0.16), mul(SKIN, 1.0))
	for s in (-1, 1):
		g.box((s * 0.045, -0.15, 0.9), (0.022, 0.012, 0.03), P["black"])


def cape(c, col, group="Primary", length=0.42):
	g = c.b("spine", group)
	g.box((0, 0.11, 0.74 - length / 2), (0.24, 0.02, length), col, rot=(-0.12, 0, 0), bevel=0.008)


# ---------------------------------------------------------------- eldekiler

def sword(c, side="r", curved=True):
	b = c.b("handslot_" + side)
	s = -1 if side == "r" else 1
	x = s * 0.155
	b.box((x, -0.02, 0.36), (0.02, 0.06, 0.02), P["gold"], mat=1)
	b.box((x, -0.02, 0.33), (0.016, 0.016, 0.05), P["wood_dark"])
	for k in range(4):
		b.box((x, -0.025 - k * 0.012 * (1 if curved else 0), 0.42 + k * 0.06), (0.012, 0.035, 0.065), P["stone_grey"], mat=1, rot=(-0.12 * k if curved else 0, 0, 0))


def axe(c):
	b = c.b("handslot_r")
	b.cyl((-0.155, -0.01, 0.3), 0.012, 0.012, 0.34, P["wood"], seg=6)
	b.box((-0.155, -0.06, 0.6), (0.015, 0.09, 0.1), P["stone_grey"], mat=1, bevel=0.01)


def round_shield(c, col_group="Secondary", col=P["white"], boss=P["iron"]):
	b = c.b("forearm_l", col_group)
	b.cyl((0.21, -0.02, 0.45), 0.12, 0.12, 0.025, col, seg=14, rot=(0, math.pi / 2, 0))
	g = c.b("forearm_l")
	g.cyl((0.235, -0.02, 0.45), 0.123, 0.123, 0.004, mul(boss, 1.3), seg=14, rot=(0, math.pi / 2, 0), cap_top=False, cap_bot=False)
	g.sphere((0.237, -0.02, 0.45), 0.03, boss, seg=8, rings=4, mat=1)


def kite_shield(c, col=P["white"]):
	b = c.b("forearm_l", "Secondary")
	b.box((0.21, -0.03, 0.45), (0.025, 0.18, 0.24), col, bevel=0.01)
	b.box((0.21, -0.03, 0.31), (0.025, 0.1, 0.06), col, bevel=0.01)
	g = c.b("forearm_l")
	g.box((0.225, -0.03, 0.45), (0.008, 0.03, 0.2), P["gold"], mat=1)
	g.box((0.225, -0.03, 0.49), (0.008, 0.14, 0.03), P["gold"], mat=1)


def bow(c):
	b = c.b("handslot_l")
	for k in range(7):
		t = (k - 3) / 3
		z = 0.36 + t * 0.26
		y = -0.03 - (1 - t * t) * 0.06
		b.box((0.16, y, z), (0.018, 0.02, 0.085), P["wood_dark"] if abs(k - 3) < 3 else P["gold"], rot=(t * 0.5, 0, 0))
	b.box((0.16, -0.025, 0.36), (0.003, 0.003, 0.52), P["cream"])
	q = c.b("spine")
	q.cyl((0.06, 0.12, 0.5), 0.035, 0.035, 0.22, P["red_dark"], seg=8, rot=(0.3, -0.2, 0))
	for k in range(4):
		q.box((0.05 + k * 0.01, 0.17, 0.76), (0.006, 0.006, 0.07), P["white"], rot=(0.3, -0.2, 0))


def crossbow(c):
	b = c.b("handslot_r")
	b.box((-0.155, -0.08, 0.37), (0.03, 0.22, 0.03), P["wood"])
	b.box((-0.155, -0.17, 0.37), (0.2, 0.02, 0.02), P["wood_dark"])


def musket(c):
	b = c.b("handslot_r")
	b.box((-0.155, -0.02, 0.36), (0.03, 0.05, 0.12), P["wood"], rot=(0.3, 0, 0))
	b.cyl((-0.155, -0.05, 0.4), 0.012, 0.01, 0.55, P["iron"], seg=6, mat=1, rot=(0.3, 0, 0))
	b.box((-0.155, -0.08, 0.5), (0.03, 0.03, 0.25), P["wood"], rot=(0.3, 0, 0))


def lance(c, pennant=P["red"]):
	b = c.b("handslot_r")
	b.cyl((-0.155, 0, 0.1), 0.012, 0.01, 1.1, P["wood"], seg=6)
	b.cyl((-0.155, 0, 1.2), 0.02, 0.0, 0.1, P["stone_grey"], seg=6, mat=1)
	b.box((-0.155, 0.06, 1.12), (0.006, 0.11, 0.06), pennant)


def staff(c):
	b = c.b("handslot_r")
	b.cyl((-0.155, -0.02, 0.0), 0.012, 0.012, 0.8, P["wood"], seg=6)


# ---------------------------------------------------------------- iskelet, deri, canlandırma

def make_rig(name="Rig"):
	arm = bpy.data.armatures.new(name)
	ob = bpy.data.objects.new(name, arm)
	bpy.context.scene.collection.objects.link(ob)
	bpy.context.view_layer.objects.active = ob
	ob.select_set(True)
	bpy.ops.object.mode_set(mode="EDIT")
	for bn, (h, t, par) in BONES.items():
		eb = arm.edit_bones.new(bn)
		eb.head = h
		eb.tail = t
		eb.roll = 0
	for bn, (h, t, par) in BONES.items():
		if par:
			arm.edit_bones[bn].parent = arm.edit_bones[par]
			arm.edit_bones[bn].use_connect = False
	bpy.ops.object.mode_set(mode="OBJECT")
	return ob


def skin(c, rig):
	"""Parçaları renk grubuna göre birleştirir; her parça kendi kemiğine tam ağırlıkla bağlanır."""
	groups = {}
	for (grp, bone), b in c.parts.items():
		ob = b.finish(ao=True)
		vg = ob.vertex_groups.new(name=bone)
		vg.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
		groups.setdefault(grp, []).append(ob)
	out = []
	for grp, obs in groups.items():
		bpy.ops.object.select_all(action="DESELECT")
		for o in obs:
			o.select_set(True)
		bpy.context.view_layer.objects.active = obs[0]
		if len(obs) > 1:
			bpy.ops.object.join()
		o = bpy.context.view_layer.objects.active
		o.name = grp
		o.data.name = c.name + "_" + grp
		o.parent = rig
		m = o.modifiers.new("Armature", "ARMATURE")
		m.object = rig
		out.append(o)
	return out


def _pose(rig, frame, rots, loc=None):
	"""rots: kemik -> (x, y, z) dünya eksenli dönüş (radyan). Rest yönüne göre yerel dönüşe çevrilir."""
	for bn in BONES:
		pb = rig.pose.bones[bn]
		r = rots.get(bn, (0, 0, 0))
		rest = rig.data.bones[bn].matrix_local.to_3x3()
		wq = Euler(r, "XYZ").to_matrix()
		local = rest.inverted() @ wq @ rest
		pb.rotation_mode = "QUATERNION"
		pb.rotation_quaternion = local.to_quaternion()
		pb.keyframe_insert("rotation_quaternion", frame=frame)
		if bn == "hips":
			pb.location = rest.inverted() @ Vector(loc or (0, 0, 0))
			pb.keyframe_insert("location", frame=frame)


def _action(rig, name, frames, fn):
	"""fn(t) -> (rots, loc); t 0..1 döngü. NLA izine konur (glTF'te ayrı canlandırma)."""
	act = bpy.data.actions.new(name)
	rig.animation_data_create()
	rig.animation_data.action = act
	for i in range(frames + 1):
		t = i / frames
		rots, loc = fn(t)
		_pose(rig, i + 1, rots, loc)
	tr = rig.animation_data.nla_tracks.new()
	tr.name = name
	tr.strips.new(name, 1, act)
	rig.animation_data.action = None
	# sonraki işlem için kemikleri sıfırla
	for pb in rig.pose.bones:
		pb.rotation_quaternion = (1, 0, 0, 0)
		pb.location = (0, 0, 0)


def S(t, ph=0.0):
	return math.sin((t + ph) * 2 * math.pi)


def animate(rig, hold="none"):
	"""hold: 'bow' yay tutar, 'musket' tüfek tutar, 'lance' mızrak dik, 'none'."""
	arm_hold = {
		"bow": {"upperarm_l": (-1.2, 0, 0.2), "forearm_l": (-1.3, 0, 0.1), "upperarm_r": (-1.0, 0, -0.4), "forearm_r": (-1.8, 0, -0.4)},
		"musket": {"upperarm_r": (-0.5, 0, 0), "forearm_r": (-1.2, 0, 0.3), "upperarm_l": (-0.6, 0, -0.3), "forearm_l": (-1.3, 0, -0.5)},
		"lance": {"upperarm_r": (-0.3, 0, 0), "forearm_r": (-0.9, 0, 0)},
		"sword": {"upperarm_r": (-0.2, 0, 0), "forearm_r": (-0.5, 0, 0)},
		"none": {},
	}[hold]

	def merged(base):
		r = dict(base)
		for k, v in arm_hold.items():
			if k in r:
				r[k] = tuple(a + b * 0.3 for a, b in zip(v, r[k]))
			else:
				r[k] = v
		return r

	def idle(t):
		b = S(t) * 0.03
		return merged({"spine": (b, 0, 0), "head": (-b, 0, S(t, 0.25) * 0.05), "upperarm_l": (0, -0.08 - b, 0), "upperarm_r": (0, 0.08 + b, 0)}), (0, 0, abs(S(t)) * -0.005)

	def walk(t):
		s = S(t)
		return merged({
			"thigh_l": (-0.55 * s, 0, 0), "thigh_r": (0.55 * s, 0, 0),
			"shin_l": (max(0, S(t, 0.25)) * 0.7 - 0.55 * s, 0, 0), "shin_r": (max(0, S(t, 0.75)) * 0.7 + 0.55 * s, 0, 0),
			"upperarm_l": (0.45 * s, -0.08, 0), "upperarm_r": (-0.45 * s, 0.08, 0),
			"forearm_l": (0.45 * s - 0.25, -0.08, 0), "forearm_r": (-0.45 * s - 0.25, 0.08, 0),
			"spine": (-0.05, 0, S(t) * 0.06), "head": (0.03, 0, -S(t) * 0.05),
		}), (0, 0, abs(math.cos(t * 2 * math.pi)) * 0.025)

	def run(t):
		s = S(t)
		return merged({
			"thigh_l": (-0.9 * s - 0.2, 0, 0), "thigh_r": (0.9 * s - 0.2, 0, 0),
			"shin_l": (max(0, S(t, 0.25)) * 1.3 - 0.9 * s - 0.2, 0, 0), "shin_r": (max(0, S(t, 0.75)) * 1.3 + 0.9 * s - 0.2, 0, 0),
			"upperarm_l": (0.8 * s, -0.1, 0), "upperarm_r": (-0.8 * s, 0.1, 0),
			"forearm_l": (0.8 * s - 1.1, -0.1, 0), "forearm_r": (-0.8 * s - 1.1, 0.1, 0),
			"spine": (-0.25, 0, S(t) * 0.08), "head": (0.2, 0, 0),
		}), (0, -0.02, abs(math.cos(t * 2 * math.pi)) * 0.05)

	def sit(t):
		b = S(t) * 0.03
		return merged({
			"thigh_l": (-1.45, 0, 0.35), "thigh_r": (-1.45, 0, -0.35), "shin_l": (0.0, 0, 0.3), "shin_r": (0.0, 0, -0.3),
			"upperarm_l": (-0.5, -0.1, 0), "upperarm_r": (-0.5, 0.1, 0), "forearm_l": (-1.2, 0, 0), "forearm_r": (-1.2, 0, 0),
			"spine": (b, 0, 0),
		}), (0, 0, -0.02 + b * 0.3)

	def cheer(t):
		s = S(t)
		return {
			"upperarm_l": (0, -2.6 - 0.2 * s, 0), "upperarm_r": (0, 2.6 + 0.2 * s, 0),
			"forearm_l": (0, -2.7, 0), "forearm_r": (0, 2.7, 0), "spine": (0.05 * s, 0, 0), "head": (-0.2, 0, 0),
		}, (0, 0, max(0, s) * 0.05)

	def attack(t):
		s = math.sin(t * math.pi)
		return merged({
			"upperarm_r": (-2.4 + 2.0 * s, 0, -0.2), "forearm_r": (-2.6 + 2.2 * s, 0, -0.2),
			"spine": (-0.15 * s, 0, 0.3 - 0.6 * s), "thigh_l": (-0.4, 0, 0), "thigh_r": (0.3, 0, 0),
		}), (0, 0, -0.02)

	_action(rig, "Idle", 32, idle)
	_action(rig, "Walking_A", 20, walk)
	_action(rig, "Running_A", 14, run)
	_action(rig, "Sit_Chair_Idle", 32, sit)
	_action(rig, "Cheer", 20, cheer)
	_action(rig, "1H_Melee_Attack_Chop", 14, attack)


def build_char(c, hold="none"):
	rig = make_rig()
	meshes = skin(c, rig)
	animate(rig, hold)
	return rig, meshes


# ---------------------------------------------------------------- tipler

def janissary(c, weapon="sword"):
	base_body(c, P["iznik"], P["white"], boots=P["gold"], coat_group="Gear", skirt=0.03, sash=P["red"])
	# kırmızı iç entari şeridi önde
	c.b("spine").box((0, -0.115, 0.6), (0.06, 0.02, 0.24), P["red"])
	head(c)
	bork(c)
	if weapon == "sword":
		sword(c)
	else:
		musket(c)


TYPES = {}


def ctype(name, hold="none"):
	def deco(f):
		TYPES[name] = (f, hold)
		return f
	return deco


@ctype("janissary", "sword")
def _janissary(c):
	janissary(c)


@ctype("janissary_musket", "musket")
def _janissary_m(c):
	janissary(c, "musket")


@ctype("archer", "bow")
def _archer(c):
	base_body(c, P["green"], P["cream"], boots=P["red_dark"], coat_group="Gear", skirt=0.025, sash=P["gold"])
	head(c)
	turban(c, P["white"], cap=P["red"])
	bow(c)


@ctype("tower_archer", "bow")
def _tower_archer(c):
	base_body(c, P["red"], P["cream"], boots=P["wood_dark"], coat_group="Gear", skirt=0.025, sash=P["gold"])
	head(c)
	turban(c, P["white"], cap=P["green"])
	bow(c)


@ctype("sipahi", "lance")
def _sipahi(c):
	base_body(c, P["red"], P["white"], boots=P["gold"], coat_group="Gear", skirt=0.03, sash=P["gold"])
	head(c, beard=True)
	turban(c, P["white"], cap=P["red"])
	lance(c, P["red"])
	round_shield(c, "Gear", P["gold"], P["red"])


@ctype("sufi", "none")
def _sufi(c):
	base_body(c, P["white"], P["white"], boots=P["wood"], coat_group="Gear", skirt=0.06, sash=P["cream"])
	head(c, beard=True, mustache=srgb("#6a5a4a"))
	h = c.b("head")
	h.cyl((0, 0, 0.93), 0.11, 0.12, 0.3, srgb("#8a6a48"), seg=12)
	staff(c)


@ctype("sultan", "none")
def _sultan(c):
	base_body(c, P["red"], P["gold"], boots=P["gold"], coat_group="Gear", skirt=0.07, sash=P["gold"], belly=1.1)
	c.b("spine").box((0, -0.12, 0.6), (0.04, 0.02, 0.26), P["gold"], mat=1)
	head(c, beard=True)
	turban(c, P["white"], big=True, cap=P["red"])
	cape(c, srgb("#e8d7a8"), "Gear", 0.6)


@ctype("enemy_infantry", "sword")
def _inf(c):
	base_body(c, P["white"], srgb("#8a7a64"), boots=P["wood_dark"], coat_group="Primary", skirt=0.02)
	head(c, mustache=srgb("#7a5a3a"), beard=True)
	helmet(c, P["iron"])
	axe(c)
	round_shield(c, "Secondary")


@ctype("enemy_knight", "sword")
def _knight(c):
	base_body(c, P["stone_grey"], P["stone_grey"], boots=P["iron"], coat_group="Gear")
	# tabard: millet rengi
	c.b("spine", "Primary").box((0, -0.005, 0.56), (0.25, 0.25, 0.22), P["white"])
	c.b("hips", "Primary").box((0, -0.005, 0.36), (0.25, 0.25, 0.14), P["white"])
	head(c, mustache=None, eyes=False)
	great_helm(c, P["white"])
	sword(c, curved=False)
	kite_shield(c)


@ctype("enemy_rider", "lance")
def _rider(c):
	base_body(c, P["white"], srgb("#7a6a54"), coat_group="Primary")
	head(c, mustache=None, eyes=False)
	hood(c, P["white"])
	lance(c, P["white"])


@ctype("enemy_horse_archer", "musket")
def _harcher(c):
	base_body(c, P["white"], srgb("#7a6a54"), coat_group="Primary")
	head(c, mustache=None, eyes=False)
	hood(c, P["white"])
	crossbow(c)


@ctype("enemy_commander", "sword")
def _commander(c):
	base_body(c, P["stone_grey"], P["stone_grey"], boots=P["iron"], coat_group="Gear")
	c.b("spine", "Primary").box((0, -0.005, 0.56), (0.25, 0.25, 0.22), P["white"])
	head(c, mustache=None, eyes=False)
	great_helm(c, P["white"], plume=P["red"])
	cape(c, P["white"], "Primary", 0.55)
	sword(c, curved=False)


# ---------------------------------------------------------------- at

def horse():
	"""At: gövde ve baş tek parça; dört bacak "leg0".."leg3" kalça noktasından döner. Eğer üstünde "saddle".
	Örtü "Primary" (millet ya da Osmanlı rengiyle boyanır). Boy ~1 birim (sırt ~0.95)."""
	from kit import empty
	body = Builder("Horse", 301)
	coat = srgb("#f0ece4")
	body.box((0, 0, 0.95), (0.42, 1.0, 0.4), coat, bevel=0.12)
	body.box((0, -0.55, 1.25), (0.22, 0.32, 0.5), coat, rot=(-0.6, 0, 0), bevel=0.08)
	body.box((0, -0.78, 1.45), (0.2, 0.42, 0.22), coat, rot=(0.35, 0, 0), bevel=0.07)
	for s in (-1, 1):
		body.box((s * 0.06, -0.62, 1.62), (0.04, 0.06, 0.1), coat, bevel=0.015)
		body.box((s * 0.1, -0.92, 1.43), (0.015, 0.04, 0.04), P["black"])
	mane = srgb("#e9e3d6")
	body.box((0, -0.5, 1.4), (0.08, 0.42, 0.14), mul(mane, 0.8), rot=(-0.6, 0, 0), bevel=0.03)
	body.box((0, 0.55, 0.92), (0.1, 0.12, 0.42), mul(mane, 0.8), rot=(0.4, 0, 0), bevel=0.04)
	body.box((0, -0.97, 1.36), (0.16, 0.1, 0.12), mul(coat, 0.75), bevel=0.03)
	hb = body.finish()
	cap = Builder("Primary", 302)
	cap.box((0, 0.02, 0.98), (0.46, 0.6, 0.38), P["white"], bevel=0.06)
	cap.box((0, 0.02, 1.17), (0.3, 0.36, 0.06), P["white"], bevel=0.02)
	co = cap.finish()
	gear = Builder("Gear", 303)
	gear.box((0, 0.02, 0.79), (0.48, 0.62, 0.05), P["gold"], mat=1)
	gear.box((0, -0.03, 1.21), (0.22, 0.3, 0.06), P["wood_dark"], bevel=0.02)
	gear.box((0, -0.85, 1.42), (0.22, 0.03, 0.03), P["wood_dark"])
	go = gear.finish()
	co.parent = hb
	go.parent = hb
	for i, (x, y) in enumerate([(-0.13, -0.35), (0.13, -0.35), (-0.13, 0.35), (0.13, 0.35)]):
		lb = Builder("leg%d" % i, 310 + i)
		lb.box((0, 0, -0.32), (0.11, 0.13, 0.55), coat, bevel=0.04)
		lb.box((0, -0.01, -0.68), (0.08, 0.09, 0.2), coat, bevel=0.03)
		lb.box((0, -0.02, -0.8), (0.1, 0.12, 0.07), P["dark"], bevel=0.02)
		lo = lb.finish()
		lo.parent = hb
		lo.location = (x, y, 0.85)
	empty("saddle", (0, -0.03, 1.24), hb)
	return hb


# ---------------------------------------------------------------- şehir halkı

@ctype("townsman", "none")
def _townsman(c):
	base_body(c, P["white"], srgb("#d9cfba"), boots=P["wood_dark"], coat_group="Primary", skirt=0.05, sash=P["gold"])
	head(c, beard=c.seed % 2 == 0)
	h = c.b("head", "Secondary")
	for i in range(3):
		h.cyl((0, 0, 0.93 + i * 0.035), 0.15 - i * 0.012, 0.15 - i * 0.012, 0.04, P["white"], seg=12, smooth=True)
	h.sphere((0, 0, 1.04), 0.12, P["white"], seg=12, rings=7, scale=(1, 1, 0.75))


@ctype("townswoman", "none")
def _townswoman(c):
	base_body(c, P["white"], P["white"], boots=P["red_dark"], coat_group="Primary", skirt=0.08)
	head(c, mustache=None)
	h = c.b("head", "Secondary")
	h.sphere((0, 0.01, 0.9), 0.15, P["white"], seg=12, rings=7, scale=(1, 1.05, 1.1))
	h.cyl((0, 0.05, 0.6), 0.17, 0.13, 0.2, P["white"], seg=10)
	g = c.b("head")
	g.box((0, -0.14, 0.88), (0.2, 0.02, 0.16), SKIN)
	for s in (-1, 1):
		g.box((s * 0.045, -0.15, 0.9), (0.022, 0.012, 0.03), P["black"])


@ctype("semazen", "none")
def _semazen(c):
	base_body(c, P["white"], P["white"], boots=P["white"], coat_group="Gear", skirt=0.0)
	# açılmış tennure eteği
	c.b("hips").lathe([(0.12, 0.42), (0.2, 0.3), (0.42, 0.06), (0.46, 0.02), (0.0, 0.02)][::-1], (0, 0, 0), P["white"], seg=20)
	head(c, beard=True, mustache=srgb("#6a5a4a"))
	c.b("head").cyl((0, 0, 0.93), 0.1, 0.11, 0.28, srgb("#8a6a48"), seg=12)


def _worker(c, tool):
	base_body(c, P["white"], srgb("#5a4632"), boots=P["wood_dark"], coat_group="Primary")
	head(c, beard=True, mustache=srgb("#5a3a22"))
	c.b("head").cyl((0, 0, 0.93), 0.14, 0.13, 0.08, P["cream"] if tool == "axe" else P["iron"], seg=12)
	b = c.b("handslot_r")
	b.cyl((-0.155, -0.01, 0.28), 0.012, 0.012, 0.36, P["wood"], seg=6)
	if tool == "axe":
		b.box((-0.155, -0.06, 0.6), (0.015, 0.09, 0.1), P["stone_grey"], mat=1, bevel=0.01)
	else:
		b.cyl((-0.155, 0, 0.62), 0.01, 0.018, 0.24, P["iron"], seg=6, mat=1, rot=(math.pi / 2, 0, 0))


@ctype("woodcutter", "none")
def _woodcutter(c):
	_worker(c, "axe")


@ctype("miner", "none")
def _miner(c):
	_worker(c, "pick")
