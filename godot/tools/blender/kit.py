# Blender (bpy) yardımcıları: tek tek taşlardan örülmüş, elle boyanmış görünümlü düşük poligonlu modeller.
# Renkler köşe rengine (COLOR_0) yazılır; doku dosyası yoktur. Ortam gölgesi (AO) Cycles ile köşe rengine pişirilir.
# Eksenler: Blender Z yukarı, -Y ön. glTF dışa aktarımında Godot'ta Y yukarı, +Z ön olur.

import math
import random

import bpy  # bmesh'ten önce yüklenmeli
import bmesh
from mathutils import Matrix, Vector

# Malzeme sırası: 0 boya (mat), 1 metal (altın, bronz, kurşun), 2 parlak boya (çini, kumaş değil)
MAT_NAMES = ["Painted", "Metal", "Glaze"]


def srgb(h):
	h = h.lstrip("#")
	return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def to_lin(c):
	return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


def mix(a, b, t):
	return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def mul(a, k):
	return tuple(min(1.0, v * k) for v in a)


def jitter(c, amt, rng):
	k = 1.0 + rng.uniform(-amt, amt)
	w = rng.uniform(-amt, amt) * 0.4
	return (min(1, c[0] * k * (1 + w)), min(1, c[1] * k), min(1, c[2] * k * (1 - w)))


# Palet (sRGB): görseldeki sıcak kum taşı, kurşun kubbe, Osmanlı kırmızısı
P = {
	"stone": srgb("#e6d6b4"),
	"stone_light": srgb("#f3ead2"),
	"stone_dark": srgb("#cdb894"),
	"stone_grey": srgb("#d2cbbb"),
	"mortar": srgb("#a08d72"),
	"wood": srgb("#8a5a32"),
	"wood_dark": srgb("#5e3a1e"),
	"wood_light": srgb("#b07a46"),
	"lead": srgb("#8ea2c2"),
	"lead_light": srgb("#bccbe0"),
	"gold": srgb("#e2b54e"),
	"bronze": srgb("#b5823a"),
	"copper": srgb("#b8673a"),
	"iron": srgb("#3c3d44"),
	"red": srgb("#b52a2a"),
	"red_dark": srgb("#7e1a1c"),
	"cream": srgb("#f1e6cc"),
	"white": srgb("#f4efe2"),
	"iznik": srgb("#2c67a8"),
	"turq": srgb("#3aa3a0"),
	"green": srgb("#4f7d3a"),
	"roof": srgb("#c45a3c"),
	"roof_dark": srgb("#94402c"),
	"dark": srgb("#2a1d14"),
	"canvas": srgb("#eadbb5"),
	"rock": srgb("#9a948a"),
	"grass": srgb("#7a9a4a"),
	"soil": srgb("#9a7a52"),
	"black": srgb("#1c1a1c"),
	"fire": srgb("#ffb040"),
}


class Builder:
	"""Bir nesnenin bmesh'i; her yüzün rengi ve malzemesi tutulur, sonra köşe rengine yazılır."""

	def __init__(self, name, seed=1):
		self.name = name
		self.bm = bmesh.new()
		self.rng = random.Random(seed)
		self.face_col = {}
		self.smooth = set()

	# -- temel parçalar ---------------------------------------------------------

	def _tag(self, faces, col, mat=0, smooth=False, shade=True):
		for f in faces:
			f.material_index = mat
			c = col
			if shade:
				# elle boyanmış ışık: üst yüzler açık ve sıcak, alt yüzler koyu
				nz = f.normal.z
				if nz > 0.6:
					c = mix(mul(c, 1.10), P["cream"], 0.08)
				elif nz < -0.5:
					c = mul(c, 0.7)
			self.face_col[f] = c
			f.smooth = smooth

	def _merge(self, t, col, mat=0, smooth=False, matrix=None, jit=0.0, top_col=None, skip_bottom=False, shade=True):
		"""Geçici bmesh t'yi dönüşümle ana bmesh'e kopyalar ve renklendirir."""
		if matrix is not None:
			bmesh.ops.transform(t, matrix=matrix, verts=t.verts)
		vmap = {}
		for v in t.verts:
			vmap[v] = self.bm.verts.new(v.co)
		c = jitter(col, jit, self.rng) if jit else col
		out = []
		t.normal_update()
		for f in t.faces:
			if skip_bottom and f.normal.z < -0.99:
				continue
			try:
				nf = self.bm.faces.new([vmap[v] for v in f.verts])
			except ValueError:
				continue
			nf.normal_update()
			out.append(nf)
		t.free()
		self._tag(out, c, mat, smooth, shade)
		if top_col:
			for f in out:
				if f.normal.z > 0.7:
					self.face_col[f] = top_col
		return out

	def box(self, center, size, col, rot=(0, 0, 0), bevel=0.0, mat=0, jit=0.0, top_col=None, skip_bottom=False):
		t = bmesh.new()
		bmesh.ops.create_cube(t, size=1.0)
		bmesh.ops.scale(t, vec=Vector(size), verts=t.verts)
		if bevel > 0:
			bmesh.ops.bevel(t, geom=list(t.verts) + list(t.edges), offset=min(bevel, min(size) * 0.45), segments=1, affect="EDGES", profile=0.5)
		m = Matrix.Translation(Vector(center)) @ _rot(rot)
		return self._merge(t, col, mat, matrix=m, jit=jit, top_col=top_col, skip_bottom=skip_bottom)

	def cyl(self, center, r_bot, r_top, h, col, seg=12, mat=0, smooth=False, cap_top=True, cap_bot=True, rot=(0, 0, 0), jit=0.0, scale_xy=(1, 1)):
		t = bmesh.new()
		bmesh.ops.create_cone(t, cap_ends=True, cap_tris=False, segments=seg, radius1=r_bot, radius2=max(r_top, 1e-4), depth=h)
		if scale_xy != (1, 1):
			bmesh.ops.scale(t, vec=Vector((scale_xy[0], scale_xy[1], 1)), verts=t.verts)
		kill = [f for f in t.faces if len(f.verts) == seg and ((f.calc_center_median().z > 0 and not cap_top) or (f.calc_center_median().z < 0 and not cap_bot))]
		if kill:
			bmesh.ops.delete(t, geom=kill, context="FACES_ONLY")
		m = Matrix.Translation(Vector(center)) @ _rot(rot) @ Matrix.Translation((0, 0, h / 2))
		out = self._merge(t, col, mat, smooth=smooth, matrix=m, jit=jit)
		for f in out:
			if len(f.verts) == seg:
				f.smooth = False
		return out

	def sphere(self, center, r, col, seg=12, rings=8, mat=0, smooth=True, hemi=False, scale=(1, 1, 1)):
		t = bmesh.new()
		bmesh.ops.create_uvsphere(t, u_segments=seg, v_segments=rings, radius=r)
		if hemi:
			kill = [v for v in t.verts if v.co.z < -1e-4]
			bmesh.ops.delete(t, geom=kill, context="VERTS")
			edges = [e for e in t.edges if e.is_boundary]
			if edges:
				bmesh.ops.holes_fill(t, edges=edges)
		bmesh.ops.scale(t, vec=Vector(scale), verts=t.verts)
		return self._merge(t, col, mat, smooth=smooth, matrix=Matrix.Translation(Vector(center)))

	def lathe(self, profile, center, col, seg=16, mat=0, smooth=True, ribs=None):
		"""profile: [(r, z), ...] aşağıdan yukarı. ribs: (renk, her kaçıncı dilim) kubbe kaburgaları."""
		ring_vs = []
		cx, cy, cz = center
		for (r, z) in profile:
			ring = []
			for i in range(seg):
				a = i * 2 * math.pi / seg
				ring.append(self.bm.verts.new((cx + math.cos(a) * r, cy + math.sin(a) * r, cz + z)))
			ring_vs.append(ring)
		faces = []
		for k in range(len(ring_vs) - 1):
			a, b = ring_vs[k], ring_vs[k + 1]
			for i in range(seg):
				j = (i + 1) % seg
				if profile[k + 1][0] < 1e-5:
					f = self.bm.faces.new((a[i], a[j], b[i]))
				else:
					f = self.bm.faces.new((a[i], a[j], b[j], b[i]))
				faces.append(f)
		if profile[0][0] > 1e-5:
			faces.append(self.bm.faces.new(list(reversed(ring_vs[0]))))
		bmesh.ops.remove_doubles(self.bm, verts=[v for r in ring_vs for v in r], dist=1e-6)
		faces = [f for f in faces if f.is_valid]
		for f in faces:
			f.normal_update()
		self._tag(faces, col, mat, smooth)
		if ribs:
			rc, every = ribs
			for f in faces:
				c = f.calc_center_median()
				a = math.atan2(c.y - cy, c.x - cx) % (2 * math.pi)
				idx = int(round(a / (2 * math.pi / seg) - 0.5)) % seg
				if idx % every == 0:
					self.face_col[f] = rc
		return faces

	def poly_prism(self, pts2d, z0, z1, col, mat=0):
		"""2B çokgeni (x, y) z0'dan z1'e yükseltir."""
		bot = [self.bm.verts.new((x, y, z0)) for x, y in pts2d]
		top = [self.bm.verts.new((x, y, z1)) for x, y in pts2d]
		faces = [self.bm.faces.new(list(reversed(bot))), self.bm.faces.new(top)]
		n = len(pts2d)
		for i in range(n):
			j = (i + 1) % n
			faces.append(self.bm.faces.new((bot[i], bot[j], top[j], top[i])))
		for f in faces:
			f.normal_update()
		self._tag(faces, col, mat)
		return faces

	def quad(self, pts, col, mat=0, both=False):
		vs = [self.bm.verts.new(p) for p in pts]
		f = self.bm.faces.new(vs)
		f.normal_update()
		self._tag([f], col, mat, shade=False)
		out = [f]
		if both:
			vs2 = [self.bm.verts.new(p) for p in reversed(pts)]
			f2 = self.bm.faces.new(vs2)
			f2.normal_update()
			self._tag([f2], mul(col, 0.8), mat, shade=False)
			out.append(f2)
		return out

	# -- taş işçiliği -------------------------------------------------------------

	def stone_ring(self, center, r, h, col=None, course=0.075, stone_w=0.12, depth=0.05, z0=0.0, taper=0.0, arc=(0, 2 * math.pi), bevel=0.008, gap=0.006, palette=None):
		"""Yuvarlak kule gövdesi: sıra sıra, şaşırtmalı kesme taşlar. İçte boşluğu kapatan bir çekirdek silindir."""
		cx, cy, cz = center
		pal = palette or [P["stone"], P["stone_light"], P["stone_dark"], P["stone"], P["stone_grey"]]
		rows = max(1, int(round(h / course)))
		ch = h / rows
		for k in range(rows):
			z = z0 + k * ch
			rr = r - taper * (k / rows)
			circ = rr * (arc[1] - arc[0])
			n = max(5, int(round(circ / stone_w)))
			step = (arc[1] - arc[0]) / n
			off = (0.5 if k % 2 else 0.0) * step + self.rng.uniform(-0.1, 0.1) * step
			for i in range(n):
				a = arc[0] + off + (i + 0.5) * step
				w = 2 * rr * math.sin(step / 2) - gap
				d = depth * self.rng.uniform(0.85, 1.15)
				c = jitter(self.rng.choice(pal), 0.045, self.rng)
				out = self.rng.uniform(-0.004, 0.006)
				pos = (cx + math.cos(a) * (rr - d / 2 + out), cy + math.sin(a) * (rr - d / 2 + out), cz + z + ch / 2)
				self.box(pos, (d, w, ch - gap), c, rot=(0, 0, a), bevel=bevel)
		# çekirdek (harç rengi)
		self.cyl((cx, cy, cz + z0), r - depth * 0.6, r - depth * 0.6 - taper, h, P["mortar"], seg=16, cap_top=False, cap_bot=False)

	def stone_wall(self, x0, x1, z0, z1, y, normal_y, col_pal=None, course=0.075, stone_w=0.13, depth=0.04, bevel=0.008, gap=0.006, along="x"):
		"""Düz duvar yüzü: x0..x1 boyunca (ya da along='y' ise y boyunca), y düzleminde, normal_y yönüne bakan taşlar."""
		pal = col_pal or [P["stone"], P["stone_light"], P["stone_dark"], P["stone"], P["stone_grey"]]
		rows = max(1, int(round((z1 - z0) / course)))
		ch = (z1 - z0) / rows
		L = x1 - x0
		for k in range(rows):
			z = z0 + k * ch + ch / 2
			n = max(1, int(round(L / stone_w)))
			sw = L / n
			shift = (0.5 if k % 2 else 0.0) * sw
			xs = []
			x = x0 - shift
			while x < x1 - 1e-4:
				a, b = max(x, x0), min(x + sw, x1)
				if b - a > sw * 0.25:
					xs.append((a, b))
				elif xs:
					xs[-1] = (xs[-1][0], b)
				x += sw
			for a, b in xs:
				c = jitter(self.rng.choice(pal), 0.045, self.rng)
				d = depth * self.rng.uniform(0.85, 1.15)
				out = self.rng.uniform(-0.003, 0.005)
				w = b - a - gap
				cy = y + normal_y * (out - d / 2 + depth / 2)
				if along == "x":
					self.box(((a + b) / 2, cy, z), (w, d, ch - gap), c, bevel=bevel)
				else:
					self.box((cy, (a + b) / 2, z), (d, w, ch - gap), c, bevel=bevel)

	def merlons_ring(self, center, r, z, n, mw=None, mh=0.09, md=0.07, col=None, gap_every=2):
		cx, cy, cz = center
		for i in range(n):
			if i % gap_every:
				continue
			a = i * 2 * math.pi / n
			w = mw or (2 * math.pi * r / n) * 1.0
			c = jitter(col or P["stone_light"], 0.06, self.rng)
			self.box((cx + math.cos(a) * (r - md / 2), cy + math.sin(a) * (r - md / 2), cz + z + mh / 2), (md, w, mh), c, rot=(0, 0, a), bevel=0.01)

	# -- bitiş ------------------------------------------------------------------

	def finish(self, coll=None, ao=True):
		me = bpy.data.meshes.new(self.name)
		bm = self.bm
		attr = bm.loops.layers.color.new("Col")
		for f in bm.faces:
			# bayt renk katmanı sRGB saklar; to_lin gerekmez
			c = self.face_col.get(f, (1, 0, 1))
			for l in f.loops:
				l[attr] = (c[0], c[1], c[2], 1.0)
		bm.to_mesh(me)
		bm.free()
		for p in me.polygons:
			pass
		ob = bpy.data.objects.new(self.name, me)
		(coll or bpy.context.scene.collection).objects.link(ob)
		for nm in MAT_NAMES:
			me.materials.append(get_mat(nm))
		ob["bake_ao"] = ao
		return ob


def _rot(r):
	return (Matrix.Rotation(r[2], 4, "Z") @ Matrix.Rotation(r[1], 4, "Y") @ Matrix.Rotation(r[0], 4, "X"))


def get_mat(name):
	m = bpy.data.materials.get(name)
	if m:
		return m
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	nt = m.node_tree
	bsdf = nt.nodes.get("Principled BSDF")
	vc = nt.nodes.new("ShaderNodeVertexColor")
	vc.layer_name = "Col"
	nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
	bsdf.inputs["Roughness"].default_value = {"Painted": 0.9, "Metal": 0.35, "Glaze": 0.45}[name]
	bsdf.inputs["Metallic"].default_value = {"Painted": 0.0, "Metal": 0.75, "Glaze": 0.0}[name]
	return m


# ---------------------------------------------------------------------- sahne

def reset():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	for nm in MAT_NAMES:
		get_mat(nm)


def empty(name, loc, parent=None):
	e = bpy.data.objects.new(name, None)
	e.location = loc
	bpy.context.scene.collection.objects.link(e)
	if parent:
		e.parent = parent
	return e


def bake_ao(objs, samples=24, dist=0.25):
	"""Cycles ile ortam gölgesini köşe rengine pişirip boya rengiyle çarpar."""
	sc = bpy.context.scene
	sc.render.engine = "CYCLES"
	sc.cycles.device = "CPU"
	sc.cycles.samples = samples
	if sc.world is None:
		sc.world = bpy.data.worlds.new("W")
	sc.world.light_settings.distance = dist
	meshes = [o for o in objs if o.type == "MESH" and o.get("bake_ao", True)]
	if not meshes:
		return
	for o in meshes:
		me = o.data
		if "AO" not in me.color_attributes:
			me.color_attributes.new("AO", "BYTE_COLOR", "CORNER")
		me.color_attributes.active_color = me.color_attributes["AO"]
	bpy.ops.object.select_all(action="DESELECT")
	for o in meshes:
		o.select_set(True)
	bpy.context.view_layer.objects.active = meshes[0]
	sc.render.bake.target = "VERTEX_COLORS"
	bpy.ops.object.bake(type="AO")
	for o in meshes:
		me = o.data
		col = me.color_attributes["Col"].data
		ao = me.color_attributes["AO"].data
		for i in range(len(col)):
			a = ao[i].color[0]
			# yumuşak AO: tamamen karartmaz, gölgede hafif sıcaklık bırakır
			k = 0.62 + 0.38 * a
			c = col[i].color
			col[i].color = (c[0] * k, c[1] * (0.03 + k * 0.97), c[2] * (0.08 + k * 0.92), 1.0)
		me.color_attributes.remove(me.color_attributes["AO"])
		me.color_attributes.active_color = me.color_attributes["Col"]


def export(path, objs=None):
	# canlandırmalar NLA izlerinden: her iz ayrı glTF canlandırması
	bpy.ops.object.select_all(action="DESELECT")
	objs = objs or list(bpy.context.scene.objects)
	for o in objs:
		o.select_set(True)
	bpy.ops.export_scene.gltf(
		filepath=path,
		export_format="GLB",
		use_selection=True,
		export_yup=True,
		export_apply=True,
		export_vertex_color="NAME",
		export_vertex_color_name="Col",
		export_all_vertex_colors=False,
		export_normals=True,
		export_texcoords=False,
		export_materials="EXPORT",
		export_extras=False,
		export_animations=True,
		export_animation_mode="NLA_TRACKS",
		export_force_sampling=True,
		export_optimize_animation_size=True,
	)


def render_preview(path, target=(0, 0, 0.4), dist=2.2, res=480, elev=0.55, azim=-0.9):
	sc = bpy.context.scene
	sc.render.engine = "CYCLES"
	sc.cycles.samples = 32
	sc.render.resolution_x = res
	sc.render.resolution_y = res
	sc.render.film_transparent = False
	w = sc.world or bpy.data.worlds.new("W")
	sc.world = w
	w.use_nodes = True
	w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.62, 0.7, 1)
	w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
	cam = bpy.data.objects.get("PrevCam")
	if not cam:
		cam = bpy.data.objects.new("PrevCam", bpy.data.cameras.new("PrevCam"))
		sc.collection.objects.link(cam)
		sun = bpy.data.objects.new("PrevSun", bpy.data.lights.new("PrevSun", "SUN"))
		sun.data.energy = 3.5
		sun.data.color = (1.0, 0.9, 0.75)
		sun.rotation_euler = (0.9, 0.2, -0.8)
		sc.collection.objects.link(sun)
	t = Vector(target)
	cam.location = t + Vector((math.cos(azim) * math.cos(elev), math.sin(azim) * math.cos(elev), math.sin(elev))) * dist
	cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
	cam.data.lens = 50
	sc.camera = cam
	sc.render.filepath = path
	bpy.ops.render.render(write_still=True)
