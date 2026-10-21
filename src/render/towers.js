import * as THREE from 'three';
import { TOWERS } from '../data/towers.js';
import { paint, paintShared, PALETTE, ottomanFlagTexture } from './palette.js';
import { G as FG } from './figures.js';
import { prop, bakeStatic } from './models.js';
import { buildSoldier } from './soldiers.js';
import { flagMesh } from './flags.js';

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
  stone: paintShared(PALETTE.stone),
  stoneDark: paintShared(PALETTE.stoneDark),
  red: paintShared(PALETTE.ottomanRed),
  lead: paintShared(PALETTE.lead),
  wood: paintShared(PALETTE.wood),
  woodDark: paintShared(PALETTE.woodDark),
  bronze: paintShared(0xc08a3e),
  copper: paintShared(0xb86b3a),
  iron: paintShared(0x3c3a40),
  tar: paintShared(0x1d1620),
  earth: paintShared(0x9b7a55),
  gold: paintShared(PALETTE.gold),
  // 1'in üstündeki renkler parlama (bloom) geçişinde ışır
  fire: new THREE.MeshBasicMaterial({ color: new THREE.Color(3.2, 1.1, 0.15) }),
  fireCore: new THREE.MeshBasicMaterial({ color: new THREE.Color(4, 3, 1.2) }),
};
const glowMat = {};
for (const [id, def] of Object.entries(TOWERS)) {
  glowMat[id] = new THREE.MeshBasicMaterial({
    color: def.color, transparent: true, opacity: 0.35, depthWrite: false, blending: THREE.AdditiveBlending,
  });
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

// Okçu Kulesi: KayKit taş kule, kırmızı külah çatı; oklar tepeden çıkar
function buildArcher(g) {
  const t = prop('building_tower_A', 0.4);
  t.position.y = 0.16;
  g.add(t);
  const head = new THREE.Group();
  head.position.y = 0.9;
  g.add(head);
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
  // kazanı devirmek için ahşap kol
  const head = new THREE.Group();
  head.position.y = 0.95;
  head.add(part(G.block, M.wood, 0.2, 0, 0, 0.4, 0.04, 0.04));
  g.add(head);
  // duman ve kıvılcım ambient.js parçacıklarıyla çıkar
  return { head, fire, bubbles, smokeY: 0.85 };
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
  // yanında gülle yığını ve barut fıçısı
  for (const [x, z, y] of [[-0.25, 0.25, 0.42], [-0.17, 0.3, 0.42], [-0.21, 0.27, 0.49]]) g.add(part(G.ball, M.iron, x, y, z, 0.05));
  const keg = prop('barrel', 0.5);
  keg.position.set(0.26, 0.37, -0.22);
  g.add(keg);
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
  for (const [x, z] of [[0.26, 0.2], [0.3, -0.12]]) {
    const b = prop('barrel', 0.55);
    b.position.set(x, 0.43, z);
    g.add(b);
  }
  const head = new THREE.Group();
  head.position.y = 0.43;
  const jan = buildSoldier('musketeer');
  jan.pose('Idle', 0.3);
  jan.root.scale.setScalar(0.21);
  head.add(jan.root);
  g.add(head);
  g.add(part(G.cyl, M.wood, -0.3, 0.8, -0.2, 0.015, 0.9, 0.015));
  const flag = flagMesh(ottomanFlagTexture(), 0.34, 0.22);
  flag.position.set(-0.3, 1.12, -0.2);
  g.add(flag);
  return { head, soldier: jan };
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
  const pf = flagMesh(ottomanFlagTexture(), 0.22, 0.14);
  pf.position.set(0.31, 0.8, 0.3);
  pennant.add(pf);
  g.add(pennant);
  // hareket eden ve görünürlüğü değişen parçalar ayrı kalır, gerisi tek çizime iner
  for (const o of [parts.head, parts.fire, ...(parts.bubbles || []), pennant, ...dots]) if (o) o.userData.dynamic = true;
  bakeStatic(g);
  g.userData = { ...parts, dots, glow, pennant };
  return g;
}

export function updateTowerModel(model, tower, time, boosted) {
  const u = model.userData;
  for (let i = 0; i < 3; i++) u.dots[i].visible = i < tower.level;
  u.pennant.visible = tower.level >= 3;
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
  } else if (tower.type === 'tar') {
    u.head.rotation.y = yaw;
    const f = 0.85 + 0.3 * Math.sin(time * 18 + tower.id);
    u.fire.scale.set(1, f, 1);
    u.bubbles.forEach((b, i) => {
      const k = (time * 1.4 + i * 0.33 + tower.id * 0.1) % 1;
      b.scale.setScalar(0.02 + 0.05 * Math.sin(k * Math.PI));
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
  archer: paintShared(0x6e4424),
  cannon: paintShared(0x2b2a30),
  tar: paintShared(0x1d1620),
};

// Ok izi: okun arkasında incelen, sönen açık şerit
const trailTex = (() => {
  const c = document.createElement('canvas');
  c.width = 4;
  c.height = 64;
  const g = c.getContext('2d');
  const grad = g.createLinearGradient(0, 0, 0, 64);
  grad.addColorStop(0, 'rgba(255,255,255,0)');
  grad.addColorStop(1, 'rgba(255,255,255,1)');
  g.fillStyle = grad;
  g.fillRect(0, 0, 4, 64);
  return new THREE.CanvasTexture(c);
})();
const trailMat = new THREE.MeshBasicMaterial({
  map: trailTex, color: 0xfff2c8, transparent: true, opacity: 0.7, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
});
const trailGeo = new THREE.PlaneGeometry(0.035, 0.6).translate(0, -0.42, 0);
// Gülle ve zift izi: arkada kalan koyu duman
const smokeTrailMat = new THREE.MeshBasicMaterial({
  map: trailTex, color: 0x3a3438, transparent: true, opacity: 0.45, depthWrite: false, side: THREE.DoubleSide,
});
const smokeTrailGeo = new THREE.PlaneGeometry(0.09, 0.5).translate(0, -0.3, 0);

export function createProjectileModel(p) {
  const m = new THREE.Mesh(projGeo[p.type], projMat[p.type]);
  m.rotation.order = 'YXZ';
  if (p.type === 'archer') {
    const tip = new THREE.Mesh(FG.cone, paintShared(0xb7bcc6));
    tip.scale.set(0.025, 0.06, 0.025);
    tip.position.y = 0.18;
    m.add(tip);
    // iz yatay düzlemde, kameradan görünsün diye iki çapraz şerit
    for (const r of [0, Math.PI / 2]) {
      const t = new THREE.Mesh(trailGeo, trailMat);
      t.rotation.y = r;
      m.add(t);
    }
  } else {
    const holder = new THREE.Group();
    holder.rotation.order = 'YXZ';
    for (const r of [0, Math.PI / 2]) {
      const t = new THREE.Mesh(smokeTrailGeo, smokeTrailMat);
      t.rotation.y = r;
      holder.add(t);
    }
    m.add(holder);
    m.userData.trail = holder;
  }
  return m;
}

export function updateProjectileModel(m, p) {
  if (p.type === 'archer') {
    m.rotation.y = -p.angle;
    m.rotation.z = -Math.PI / 2;
  } else {
    if (p.type === 'tar') m.scale.set(1, 0.8, 1);
    // iz uçuş yönünün tersine yatar (okla aynı döndürme)
    m.userData.trail.rotation.set(0, -(p.angle ?? 0), -Math.PI / 2);
  }
}
