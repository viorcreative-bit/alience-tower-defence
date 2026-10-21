import * as THREE from 'three';
import { TOWERS } from '../data/towers.js';

// 3D kule modelleri. Her kule türünün modeli kendi fonksiyonunda; geometri ve
// malzemeler paylaşılır. Model kökü kare merkezinde, kaide tabanı y=0'da.

const G = {
  base: new THREE.CylinderGeometry(0.36, 0.4, 0.16, 8),
  plate: new THREE.CylinderGeometry(0.29, 0.29, 0.03, 8),
  ring: new THREE.TorusGeometry(0.24, 0.018, 6, 24),
  dot: new THREE.SphereGeometry(0.035, 8, 6),
  ball: new THREE.SphereGeometry(1, 16, 12),
  cyl: new THREE.CylinderGeometry(1, 1, 1, 12),
  box: new THREE.BoxGeometry(1, 1, 1),
  crystal: new THREE.OctahedronGeometry(1, 0),
  coil: new THREE.TorusGeometry(0.13, 0.035, 8, 20),
};

const M = {
  metal: new THREE.MeshStandardMaterial({ color: 0x737c99, metalness: 0.75, roughness: 0.35 }),
  dark: new THREE.MeshStandardMaterial({ color: 0x2b3047, metalness: 0.6, roughness: 0.5 }),
  light: new THREE.MeshStandardMaterial({ color: 0xc5cce0, metalness: 0.8, roughness: 0.25 }),
  copper: new THREE.MeshStandardMaterial({ color: 0xc27a40, metalness: 0.85, roughness: 0.3 }),
};
const glow = {};
for (const [id, def] of Object.entries(TOWERS)) {
  glow[id] = new THREE.MeshStandardMaterial({ color: def.color, emissive: def.color, emissiveIntensity: 1.4 });
}
const iceMat = new THREE.MeshStandardMaterial({
  color: 0xbfefff, emissive: 0x3fa9e0, emissiveIntensity: 0.6, metalness: 0.1, roughness: 0.05,
  transparent: true, opacity: 0.9,
});

function part(geo, mat, x, y, z, sx, sy, sz) {
  const m = new THREE.Mesh(geo, mat);
  m.position.set(x, y, z);
  if (sx !== undefined) m.scale.set(sx, sy ?? sx, sz ?? sx);
  m.castShadow = true;
  return m;
}

function buildBase(type) {
  const g = new THREE.Group();
  const base = part(G.base, M.metal, 0, 0.08, 0);
  base.receiveShadow = true;
  g.add(base);
  g.add(part(G.plate, M.dark, 0, 0.175, 0));
  const ring = part(G.ring, glow[type], 0, 0.19, 0);
  ring.rotation.x = Math.PI / 2;
  ring.castShadow = false;
  g.add(ring);
  return g;
}

function buildLaser(g) {
  const head = new THREE.Group();
  head.position.y = 0.3;
  head.add(part(G.ball, M.metal, 0, 0, 0, 0.14));
  const barrel = new THREE.Group();
  barrel.add(part(G.cyl, M.light, 0.22, 0, 0, 0.03, 0.4, 0.03));
  barrel.children[0].rotation.z = Math.PI / 2;
  barrel.add(part(G.box, glow.laser, 0.42, 0, 0, 0.05, 0.07, 0.07));
  head.add(barrel);
  head.add(part(G.cyl, M.dark, 0, -0.08, 0, 0.08, 0.12, 0.08));
  g.add(head);
  return { head, barrel };
}

function buildPlasma(g) {
  const head = new THREE.Group();
  head.position.y = 0.32;
  head.add(part(G.ball, M.metal, 0, 0, 0, 0.19));
  const barrel = new THREE.Group();
  const b = part(G.cyl, M.light, 0.2, 0, 0, 0.09, 0.3, 0.09);
  b.rotation.z = Math.PI / 2;
  barrel.add(b);
  const muzzle = part(G.cyl, M.dark, 0.36, 0, 0, 0.11, 0.06, 0.11);
  muzzle.rotation.z = Math.PI / 2;
  barrel.add(muzzle);
  head.add(barrel);
  const core = part(G.ball, glow.plasma, 0, 0.12, 0, 0.08);
  core.castShadow = false;
  head.add(core);
  g.add(head);
  return { head, barrel, core };
}

function buildCryo(g) {
  const head = new THREE.Group();
  head.position.y = 0.2;
  const crystal = part(G.crystal, iceMat, 0, 0.25, 0, 0.13, 0.26, 0.13);
  head.add(crystal);
  for (const s of [-1, 1]) {
    const ant = part(G.cyl, M.light, s * 0.15, 0.17, 0, 0.012, 0.32, 0.012);
    ant.rotation.z = -s * 0.35;
    head.add(ant);
    head.add(part(G.ball, glow.cryo, s * 0.21, 0.33, 0, 0.03));
  }
  g.add(head);
  return { head, crystal };
}

function buildTesla(g) {
  const head = new THREE.Group();
  head.position.y = 0.19;
  head.add(part(G.cyl, M.dark, 0, 0.2, 0, 0.06, 0.42, 0.06));
  for (let i = 0; i < 4; i++) {
    const c = part(G.coil, M.copper, 0, 0.06 + i * 0.09, 0, 1 - i * 0.12);
    c.rotation.x = Math.PI / 2;
    head.add(c);
  }
  const orb = part(G.ball, glow.tesla, 0, 0.48, 0, 0.09);
  orb.castShadow = false;
  head.add(orb);
  g.add(head);
  return { head, orb };
}

const BUILD = { laser: buildLaser, plasma: buildPlasma, cryo: buildCryo, tesla: buildTesla };

export function createTowerModel(tower) {
  const g = buildBase(tower.type);
  const parts = BUILD[tower.type](g);
  const dots = [];
  for (let i = 0; i < 3; i++) {
    const d = part(G.dot, glow[tower.type], (i - 1) * 0.11, 0.06, 0.39);
    d.castShadow = false;
    g.add(d);
    dots.push(d);
  }
  g.userData = { ...parts, dots };
  return g;
}

export function updateTowerModel(model, tower, time) {
  const u = model.userData;
  for (let i = 0; i < 3; i++) u.dots[i].visible = i < tower.level;
  // seviye arttıkça kule biraz büyür
  const s = 1.15 * (1 + (tower.level - 1) * 0.08);
  model.scale.set(s, s, s);
  const yaw = -tower.angle;
  if (tower.type === 'laser' || tower.type === 'plasma') {
    u.head.rotation.y = yaw;
    u.barrel.position.x = -tower.recoil * (tower.type === 'plasma' ? 0.08 : 0.05);
    if (u.core) u.core.scale.setScalar(0.08 * (0.85 + 0.15 * Math.sin(time * 4 + tower.id)));
  } else if (tower.type === 'cryo') {
    u.crystal.rotation.y = time * 0.8 + tower.id;
    u.crystal.position.y = 0.25 + Math.sin(time * 2 + tower.id) * 0.02;
  } else {
    const pulse = 0.5 + 0.5 * Math.sin(time * 6 + tower.id);
    u.orb.scale.setScalar(0.08 + 0.025 * pulse + 0.04 * tower.recoil);
  }
}

// Mermiler
const projGeo = {
  laser: new THREE.CapsuleGeometry(0.025, 0.2, 4, 6),
  plasma: new THREE.SphereGeometry(0.09, 12, 8),
  cryo: new THREE.OctahedronGeometry(0.07, 0),
};
const projMat = {
  laser: new THREE.MeshBasicMaterial({ color: 0xff6b78 }),
  plasma: new THREE.MeshBasicMaterial({ color: 0x9dffe0 }),
  cryo: new THREE.MeshBasicMaterial({ color: 0xd9f6ff }),
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
