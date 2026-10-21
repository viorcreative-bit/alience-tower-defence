import * as THREE from 'three';
import { TOWERS } from '../data/towers.js';
import { toon, noOutline } from './palette.js';

// 3D kule modelleri (çizgi film tarzı): taş kaide, tıknaz gövde, parlayan taş tepe
// ve altta renkli ışık halkası. Her kule türünün modeli kendi fonksiyonunda;
// geometri ve malzemeler paylaşılır. Model kökü kare merkezinde, zeminde.

const G = {
  base: new THREE.CylinderGeometry(0.4, 0.44, 0.2, 8),
  baseTop: new THREE.CylinderGeometry(0.36, 0.4, 0.06, 8),
  block: new THREE.BoxGeometry(1, 1, 1),
  ball: new THREE.SphereGeometry(1, 16, 12),
  cyl: new THREE.CylinderGeometry(1, 1, 1, 12),
  taper: new THREE.CylinderGeometry(0.7, 1, 1, 8),
  gem: new THREE.OctahedronGeometry(1, 0),
  cone: new THREE.ConeGeometry(1, 1, 8),
  coil: new THREE.TorusGeometry(0.15, 0.04, 8, 20),
  dot: new THREE.SphereGeometry(0.04, 8, 6),
  glow: new THREE.CircleGeometry(0.58, 32),
};

const M = {
  stone: toon(0x9aa0ad),
  stoneDark: toon(0x6a7080),
  metal: toon(0x5b6578),
  metalLight: toon(0xb7bfcf),
  copper: toon(0xd08a48),
  wood: toon(0x8a5a32),
};
const gemMat = {};
const glowMat = {};
for (const [id, def] of Object.entries(TOWERS)) {
  gemMat[id] = toon(def.color, { emissive: def.color, emissiveIntensity: 0.7 });
  glowMat[id] = noOutline(new THREE.MeshBasicMaterial({
    color: def.color, transparent: true, opacity: 0.45, depthWrite: false, blending: THREE.AdditiveBlending,
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
  g.add(part(G.base, M.stoneDark, 0, 0.1, 0));
  g.add(part(G.baseTop, M.stone, 0, 0.23, 0));
  return { g, glow };
}

// Lazer Tareti: taş kule gövdesi, dönen çift namlulu taret, kırmızı taş
function buildLaser(g) {
  g.add(part(G.taper, M.stone, 0, 0.42, 0, 0.27, 0.36, 0.27));
  for (let i = 0; i < 4; i++) {
    const a = (i / 4) * Math.PI * 2 + Math.PI / 4;
    g.add(part(G.block, M.stone, Math.cos(a) * 0.22, 0.65, Math.sin(a) * 0.22, 0.1, 0.1, 0.1));
  }
  const head = new THREE.Group();
  head.position.y = 0.72;
  head.add(part(G.ball, M.metal, 0, 0, 0, 0.15, 0.12, 0.15));
  const barrel = new THREE.Group();
  for (const s of [-1, 1]) {
    const b = part(G.cyl, M.metalLight, 0.2, 0, s * 0.055, 0.035, 0.32, 0.035);
    b.rotation.z = Math.PI / 2;
    barrel.add(b);
  }
  head.add(barrel);
  head.add(part(G.gem, gemMat.laser, -0.05, 0.16, 0, 0.08, 0.12, 0.08));
  g.add(head);
  return { head, barrel, gem: head.children[2] };
}

// Plazma Topu: kalın namlulu tıknaz top, yeşil parlayan çekirdek
function buildPlasma(g) {
  g.add(part(G.cyl, M.stoneDark, 0, 0.36, 0, 0.3, 0.24, 0.3));
  const head = new THREE.Group();
  head.position.y = 0.55;
  head.add(part(G.ball, M.metal, 0, 0, 0, 0.24, 0.2, 0.24));
  const barrel = new THREE.Group();
  const b = part(G.cyl, M.metal, 0.22, 0.02, 0, 0.12, 0.34, 0.12);
  b.rotation.z = Math.PI / 2;
  barrel.add(b);
  const muzzle = part(G.cyl, M.stoneDark, 0.4, 0.02, 0, 0.15, 0.08, 0.15);
  muzzle.rotation.z = Math.PI / 2;
  barrel.add(muzzle);
  const ring = part(G.cyl, gemMat.plasma, 0.3, 0.02, 0, 0.13, 0.04, 0.13);
  ring.rotation.z = Math.PI / 2;
  barrel.add(ring);
  head.add(barrel);
  const core = part(G.gem, gemMat.plasma, 0, 0.22, 0, 0.08);
  head.add(core);
  g.add(head);
  return { head, barrel, core };
}

// Kriyo Kulesi: incelen gövde, tepesinde büyük parlayan buz kristali
function buildCryo(g) {
  g.add(part(G.taper, M.stone, 0, 0.5, 0, 0.24, 0.5, 0.24));
  for (let i = 0; i < 3; i++) {
    const a = (i / 3) * Math.PI * 2;
    const sh = part(G.gem, gemMat.cryo, Math.cos(a) * 0.22, 0.32, Math.sin(a) * 0.22, 0.05, 0.12, 0.05);
    sh.rotation.z = Math.cos(a) * 0.4;
    sh.rotation.x = -Math.sin(a) * 0.4;
    g.add(sh);
  }
  g.add(part(G.cyl, M.metal, 0, 0.78, 0, 0.2, 0.06, 0.2));
  const head = new THREE.Group();
  head.position.y = 0.8;
  const crystal = part(G.gem, gemMat.cryo, 0, 0.28, 0, 0.16, 0.3, 0.16);
  head.add(crystal);
  g.add(head);
  return { head, crystal };
}

// Tesla Bobini: sivri çıkıntılı koyu gövde, bakır bobinler, havada süzülen mor taş
function buildTesla(g) {
  g.add(part(G.taper, M.metal, 0, 0.45, 0, 0.27, 0.42, 0.27));
  for (let i = 0; i < 4; i++) {
    const a = (i / 4) * Math.PI * 2;
    const spike = part(G.cone, M.stoneDark, Math.cos(a) * 0.25, 0.68, Math.sin(a) * 0.25, 0.05, 0.16, 0.05);
    g.add(spike);
  }
  for (let i = 0; i < 2; i++) {
    const c = part(G.coil, M.copper, 0, 0.36 + i * 0.16, 0, 1.25 - i * 0.15);
    c.rotation.x = Math.PI / 2;
    g.add(c);
  }
  const head = new THREE.Group();
  head.position.y = 0.72;
  const orb = part(G.gem, gemMat.tesla, 0, 0.26, 0, 0.13, 0.2, 0.13);
  head.add(orb);
  g.add(head);
  return { head, orb };
}

const BUILD = { laser: buildLaser, plasma: buildPlasma, cryo: buildCryo, tesla: buildTesla };

export function createTowerModel(tower) {
  const { g, glow } = buildBase(tower.type);
  const parts = BUILD[tower.type](g);
  const dots = [];
  for (let i = 0; i < 3; i++) {
    const d = part(G.dot, gemMat[tower.type], (i - 1) * 0.12, 0.12, 0.42);
    d.castShadow = false;
    g.add(d);
    dots.push(d);
  }
  g.userData = { ...parts, dots, glow };
  return g;
}

export function updateTowerModel(model, tower, time) {
  const u = model.userData;
  for (let i = 0; i < 3; i++) u.dots[i].visible = i < tower.level;
  // seviye arttıkça kule biraz büyür
  const s = 1 + (tower.level - 1) * 0.08;
  model.scale.set(s, s, s);
  u.glow.scale.setScalar(0.92 + 0.08 * Math.sin(time * 3 + tower.id));
  const yaw = -tower.angle;
  if (tower.type === 'laser' || tower.type === 'plasma') {
    u.head.rotation.y = yaw;
    u.barrel.position.x = -tower.recoil * (tower.type === 'plasma' ? 0.08 : 0.05);
    if (u.core) u.core.rotation.y = time * 2;
  } else if (tower.type === 'cryo') {
    u.crystal.rotation.y = time * 0.8 + tower.id;
    u.crystal.position.y = 0.28 + Math.sin(time * 2 + tower.id) * 0.03;
  } else {
    const pulse = 0.5 + 0.5 * Math.sin(time * 6 + tower.id);
    u.orb.rotation.y = time * 1.5;
    u.orb.position.y = 0.26 + Math.sin(time * 2 + tower.id) * 0.03;
    u.orb.scale.set(0.13 + 0.02 * pulse + 0.04 * tower.recoil, 0.2 + 0.03 * pulse, 0.13 + 0.02 * pulse);
  }
}

// Mermiler
const projGeo = {
  laser: new THREE.CapsuleGeometry(0.03, 0.22, 4, 6),
  plasma: new THREE.SphereGeometry(0.1, 12, 8),
  cryo: new THREE.OctahedronGeometry(0.08, 0),
};
const projMat = {
  laser: noOutline(new THREE.MeshBasicMaterial({ color: 0xff6b78 })),
  plasma: noOutline(new THREE.MeshBasicMaterial({ color: 0x9dffe0 })),
  cryo: noOutline(new THREE.MeshBasicMaterial({ color: 0xd9f6ff })),
};

export function createProjectileModel(p) {
  const m = new THREE.Mesh(projGeo[p.type], projMat[p.type]);
  if (p.type === 'laser') m.rotation.order = 'YXZ';
  return m;
}

export function updateProjectileModel(m, p) {
  if (p.type === 'laser') {
    m.rotation.y = -p.angle;
    m.rotation.z = Math.PI / 2;
  } else if (p.type === 'cryo') {
    m.rotation.y += 0.3;
  }
}
