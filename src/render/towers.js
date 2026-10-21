import * as THREE from 'three';
import { TOWERS } from '../data/towers.js';
import { toon, toonShared, noOutline, PALETTE, ottomanFlagTexture } from './palette.js';
import { G as FG, buildPerson } from './figures.js';

// 3D savunma kulesi modelleri (çizgi film tarzı). Her türün modeli kendi fonksiyonunda;
// geometri ve malzemeler paylaşılır. Model kökü kare merkezinde, zeminde.

const G = {
  base: new THREE.CylinderGeometry(0.42, 0.46, 0.18, 10),
  block: new THREE.BoxGeometry(1, 1, 1),
  ball: new THREE.SphereGeometry(1, 16, 12),
  cyl: new THREE.CylinderGeometry(1, 1, 1, 14),
  taper: new THREE.CylinderGeometry(0.82, 1, 1, 10),
  cone: new THREE.ConeGeometry(1, 1, 10),
  dot: new THREE.SphereGeometry(0.045, 8, 6),
  glow: new THREE.CircleGeometry(0.56, 32),
  wheel: new THREE.CylinderGeometry(1, 1, 1, 12),
  flag: new THREE.PlaneGeometry(1, 1),
};

const M = {
  stone: toonShared(PALETTE.stone),
  stoneDark: toonShared(PALETTE.stoneDark),
  red: toonShared(PALETTE.ottomanRed),
  lead: toonShared(PALETTE.lead),
  wood: toonShared(PALETTE.wood),
  woodDark: toonShared(PALETTE.woodDark),
  bronze: toonShared(0xc08a3e),
  copper: toonShared(0xb86b3a),
  iron: toonShared(0x3c3a40),
  tar: toonShared(0x1d1620),
  earth: toonShared(0x9b7a55),
  gold: toonShared(PALETTE.gold),
  fire: noOutline(new THREE.MeshBasicMaterial({ color: 0xffa23a })),
  fireCore: noOutline(new THREE.MeshBasicMaterial({ color: 0xffe38a })),
  smoke: noOutline(new THREE.MeshLambertMaterial({ color: 0x5a5058, transparent: true, opacity: 0.55, depthWrite: false })),
  flag: noOutline(new THREE.MeshLambertMaterial({ map: ottomanFlagTexture(), side: THREE.DoubleSide })),
};
const glowMat = {};
for (const [id, def] of Object.entries(TOWERS)) {
  glowMat[id] = noOutline(new THREE.MeshBasicMaterial({
    color: def.color, transparent: true, opacity: 0.35, depthWrite: false, blending: THREE.AdditiveBlending,
  }));
}

function part(geo, mat, x, y, z, sx, sy, sz) {
  const m = new THREE.Mesh(geo, mat);
  m.position.set(x, y, z);
  if (sx !== undefined) m.scale.set(sx, sy ?? sx, sz ?? sx);
  m.castShadow = true;
  return m;
}

function buildBase(type) {
  const g = new THREE.Group();
  const glow = new THREE.Mesh(G.glow, glowMat[type]);
  glow.rotation.x = -Math.PI / 2;
  glow.position.y = 0.01;
  g.add(glow);
  g.add(part(G.base, M.stoneDark, 0, 0.09, 0));
  return { g, glow };
}

function crenels(g, y, r, n, size) {
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2;
    g.add(part(G.block, M.stone, Math.cos(a) * r, y, Math.sin(a) * r, size, size * 1.1, size));
  }
}

// Okçu Kulesi: mazgallı taş kule, kırmızı külah çatı, dönen okçu
function buildArcher(g) {
  g.add(part(G.taper, M.stone, 0, 0.45, 0, 0.27, 0.6, 0.27));
  g.add(part(G.cyl, M.stoneDark, 0, 0.78, 0, 0.31, 0.06, 0.31));
  crenels(g, 0.86, 0.26, 6, 0.09);
  const head = new THREE.Group();
  head.position.y = 0.82;
  const archer = buildPerson({ tunic: 0xb3202a, trim: 0xe0b24a, hat: 'turban', weapon: 'bow', mustache: true });
  archer.root.scale.setScalar(0.2);
  archer.root.children.forEach((c) => (c.castShadow = false));
  head.add(archer.root);
  g.add(head);
  // dört direkli külah çatı
  for (const [x, z] of [[-0.2, -0.2], [0.2, -0.2], [-0.2, 0.2], [0.2, 0.2]]) g.add(part(G.cyl, M.wood, x, 1.02, z, 0.02, 0.36, 0.02));
  g.add(part(G.cone, M.red, 0, 1.36, 0, 0.36, 0.38, 0.36));
  g.add(part(G.ball, M.gold, 0, 1.58, 0, 0.035));
  return { head };
}

// Zift Kazanı: taş ocak, altta ateş, üstte bakır kazanda kaynayan zift
function buildTar(g) {
  g.add(part(G.cyl, M.stone, 0, 0.32, 0, 0.32, 0.3, 0.32));
  const fire = new THREE.Group();
  fire.position.set(0, 0.32, 0.3);
  fire.add(part(G.cone, M.fire, 0, 0, 0, 0.09, 0.2, 0.09));
  fire.add(part(G.cone, M.fireCore, 0.02, -0.02, 0.02, 0.05, 0.12, 0.05));
  fire.children.forEach((c) => (c.castShadow = false));
  g.add(fire);
  g.add(part(G.taper, M.copper, 0, 0.62, 0, 0.3, 0.3, 0.3));
  g.add(part(G.cyl, M.iron, 0, 0.78, 0, 0.3, 0.05, 0.3));
  const tar = part(G.cyl, M.tar, 0, 0.8, 0, 0.25, 0.03, 0.25);
  g.add(tar);
  const bubbles = [];
  for (const [x, z] of [[0.1, 0.06], [-0.06, -0.1]]) {
    const b = part(G.ball, M.tar, x, 0.81, z, 0.05);
    b.castShadow = false;
    g.add(b);
    bubbles.push(b);
  }
  const smoke = [];
  for (let i = 0; i < 2; i++) {
    const s = part(G.ball, M.smoke, 0, 1.0, 0, 0.09);
    s.castShadow = false;
    g.add(s);
    smoke.push(s);
  }
  // kazanı devirmek için ahşap kol
  const head = new THREE.Group();
  head.position.y = 0.95;
  head.add(part(G.block, M.wood, 0.2, 0, 0, 0.4, 0.04, 0.04));
  g.add(head);
  return { head, fire, bubbles, smoke };
}

// Balyemez Topu: ahşap kundak üstünde bronz top, dönen başlık
function buildCannon(g) {
  g.add(part(G.cyl, M.earth, 0, 0.27, 0, 0.36, 0.2, 0.36));
  const head = new THREE.Group();
  head.position.y = 0.4;
  head.add(part(G.block, M.wood, 0, 0.06, 0, 0.42, 0.12, 0.3));
  for (const s of [-1, 1]) {
    const w = part(G.wheel, M.woodDark, -0.05, 0.08, s * 0.19, 0.12, 0.05, 0.12);
    w.rotation.x = Math.PI / 2;
    head.add(w);
  }
  const barrel = new THREE.Group();
  barrel.position.y = 0.2;
  const tube = part(G.taper, M.bronze, 0.12, 0, 0, 0.09, 0.56, 0.09);
  tube.rotation.z = -Math.PI / 2;
  barrel.add(tube);
  const muzzle = part(G.cyl, M.bronze, 0.42, 0, 0, 0.11, 0.06, 0.11);
  muzzle.rotation.z = Math.PI / 2;
  barrel.add(muzzle);
  barrel.add(part(G.ball, M.bronze, -0.17, 0, 0, 0.1));
  for (const x of [0, 0.22]) {
    const band = part(G.cyl, M.gold, x, 0, 0, 0.1, 0.03, 0.1);
    band.rotation.z = Math.PI / 2;
    barrel.add(band);
  }
  head.add(barrel);
  g.add(head);
  // yanında gülle yığını
  for (const [x, z, y] of [[-0.25, 0.25, 0.22], [-0.17, 0.3, 0.22], [-0.21, 0.27, 0.29]]) g.add(part(G.ball, M.iron, x, y, z, 0.05));
  return { head, barrel };
}

// Tüfekçi Tabyası: toprak-taş tabya, sancak, beyaz börklü Yeniçeri tüfekçi
function buildMusket(g) {
  g.add(part(G.cyl, M.earth, 0, 0.3, 0, 0.38, 0.26, 0.38));
  for (let i = 0; i < 5; i++) {
    const a = Math.PI * 0.15 + (i / 4) * Math.PI * 0.7;
    // gabionlar (sepet siper) arka yarıda
    g.add(part(G.cyl, M.woodDark, Math.cos(a + Math.PI) * 0.3, 0.5, Math.sin(a + Math.PI) * 0.3, 0.08, 0.18, 0.08));
  }
  const head = new THREE.Group();
  head.position.y = 0.43;
  const jan = buildPerson({ tunic: 0x2f5c9e, trim: 0xb3202a, pants: 0x8a1c22, hat: 'bork', weapon: 'musket', mustache: true });
  jan.root.scale.setScalar(0.22);
  jan.arms[1].rotation.x = -1.2;
  head.add(jan.root);
  g.add(head);
  g.add(part(G.cyl, M.wood, -0.3, 0.8, -0.2, 0.015, 0.9, 0.015));
  const flag = new THREE.Mesh(G.flag, M.flag);
  flag.position.set(-0.3 + 0.17, 1.12, -0.2);
  flag.scale.set(0.34, 0.22, 1);
  g.add(flag);
  return { head, flag };
}

const BUILD = { archer: buildArcher, tar: buildTar, cannon: buildCannon, musket: buildMusket };

export function createTowerModel(tower) {
  const { g, glow } = buildBase(tower.type);
  const parts = BUILD[tower.type](g);
  const dots = [];
  for (let i = 0; i < 3; i++) {
    const d = part(G.dot, M.gold, (i - 1) * 0.13, 0.12, 0.44);
    d.castShadow = false;
    g.add(d);
    dots.push(d);
  }
  // 3. seviye: tepede küçük sancak
  const pennant = new THREE.Group();
  pennant.add(part(G.cyl, M.wood, 0.3, 0.55, 0.3, 0.012, 0.7, 0.012));
  const pf = new THREE.Mesh(G.flag, M.flag);
  pf.position.set(0.42, 0.8, 0.3);
  pf.scale.set(0.22, 0.14, 1);
  pennant.add(pf);
  g.add(pennant);
  g.userData = { ...parts, dots, glow, pennant, pf };
  return g;
}

export function updateTowerModel(model, tower, time, boosted) {
  const u = model.userData;
  for (let i = 0; i < 3; i++) u.dots[i].visible = i < tower.level;
  u.pennant.visible = tower.level >= 3;
  u.pf.rotation.y = Math.sin(time * 3 + tower.id) * 0.4;
  const s = 1 + (tower.level - 1) * 0.08;
  model.scale.set(s, s, s);
  u.glow.scale.setScalar((boosted ? 1.15 : 0.92) + 0.08 * Math.sin(time * (boosted ? 10 : 3) + tower.id));
  // +x ileri bakan parçalar hedefe döner
  const yaw = -tower.angle;
  if (tower.type === 'archer') {
    u.head.rotation.y = yaw + Math.PI / 2;
  } else if (tower.type === 'cannon') {
    u.head.rotation.y = yaw;
    u.barrel.position.x = -tower.recoil * 0.08;
  } else if (tower.type === 'musket') {
    u.head.rotation.y = yaw + Math.PI / 2;
    u.flag.rotation.y = Math.sin(time * 3 + tower.id) * 0.4;
  } else if (tower.type === 'tar') {
    u.head.rotation.y = yaw;
    const f = 0.85 + 0.3 * Math.sin(time * 18 + tower.id);
    u.fire.scale.set(1, f, 1);
    u.bubbles.forEach((b, i) => {
      const k = (time * 1.4 + i * 0.33 + tower.id * 0.1) % 1;
      b.scale.setScalar(0.02 + 0.05 * Math.sin(k * Math.PI));
    });
    u.smoke.forEach((sm, i) => {
      const k = (time * 0.5 + i * 0.5 + tower.id * 0.2) % 1;
      sm.position.y = 0.9 + k * 0.6;
      sm.scale.setScalar(0.06 + k * 0.12);
      sm.material.opacity = 0.5;
    });
  }
}

// Mermiler
const projGeo = {
  archer: new THREE.CylinderGeometry(0.012, 0.012, 0.32, 4),
  cannon: new THREE.SphereGeometry(0.07, 10, 8),
  tar: new THREE.SphereGeometry(0.07, 8, 6),
};
const projMat = {
  archer: toonShared(0x6e4424),
  cannon: toonShared(0x2b2a30),
  tar: toonShared(0x1d1620),
};

export function createProjectileModel(p) {
  const m = new THREE.Mesh(projGeo[p.type], projMat[p.type]);
  m.rotation.order = 'YXZ';
  if (p.type === 'archer') {
    const tip = new THREE.Mesh(FG.cone, toonShared(0xb7bcc6));
    tip.scale.set(0.025, 0.06, 0.025);
    tip.position.y = 0.18;
    m.add(tip);
  }
  return m;
}

export function updateProjectileModel(m, p) {
  if (p.type === 'archer') {
    m.rotation.y = -p.angle;
    m.rotation.z = -Math.PI / 2;
  } else if (p.type === 'tar') {
    m.scale.set(1, 0.8, 1);
  }
}
