import * as THREE from 'three';
import { RULES } from '../data/rules.js';
import { NATIONS } from '../data/nations.js';
import { paintShared, nationFlagTexture } from './palette.js';
import { G, mesh, flashMat, animateHorse } from './figures.js';
import { buildSoldier, buildMounted, SOLDIER_HEIGHT } from './soldiers.js';

// Düşman birliklerinin 3D modelleri. Renkler o dalganın devletinden gelir.
// Modeller 1 birim yarıçapa göre kurulur, birliğin yarıçapı kadar ölçeklenir.

const VISUAL_SCALE = 1.7;
// Yürüyen askerler kameraya biraz döner ki yüzleri görünsün (0 = hiç, 1 = tam).
const FACE_CAMERA = 0.9;
// Yürüyüş klibinin bir saniyesi kaç kare yola denk (ayaklar kaymasın)
const STRIDE = { infantry: 0.55, knight: 0.42 };
const slowMat = new THREE.MeshBasicMaterial({ color: 0x1d1620, transparent: true, opacity: 0.55, depthWrite: false });
const flagMats = new Map();
// zifte bulananların üstünde titreyen alevler (parlama geçişinde ışır)
const flameMat = new THREE.MeshBasicMaterial({ color: new THREE.Color(3.2, 1.1, 0.2), transparent: true, opacity: 0.85, depthWrite: false });
const flameGeo = new THREE.ConeGeometry(0.5, 1, 6).translate(0, 0.5, 0);

function flagMat(nation) {
  let m = flagMats.get(nation);
  if (!m) {
    const n = NATIONS[nation];
    m = new THREE.MeshLambertMaterial({ map: nationFlagTexture(n.primary, n.secondary), side: THREE.DoubleSide });
    flagMats.set(nation, m);
  }
  return m;
}

function foot(kind, nation, n) {
  const s = buildSoldier(kind, nation, n);
  const body = new THREE.Group();
  body.add(s.root);
  return { body, soldier: s, flashMats: [], height: SOLDIER_HEIGHT, stride: STRIDE[kind] };
}

function rider(kind, nation, n, horseOpts, gait) {
  const r = buildMounted(kind, nation, n, horseOpts, flagMat(nation));
  const body = new THREE.Group();
  body.add(r.horse.root);
  return { body, horse: r.horse, rider: r.rider, flashMats: r.horse.flashMats, height: r.height, gallop: gait, mounted: true };
}

// Koçbaşı: tekerlekli, devlet renginde örtülü çatı, önde demir başlı kütük
function buildRam(n) {
  const body = new THREE.Group();
  const wood = flashMat(0x8a5a32);
  const wheels = [];
  for (const [x, z] of [[-0.7, 0.6], [0.7, 0.6], [-0.7, -0.6], [0.7, -0.6]]) {
    const w = mesh(G.cyl, paintShared(0x5a3a20), x, 0.32, z, 0.32, 0.14, 0.32);
    w.rotation.z = Math.PI / 2;
    body.add(w);
    wheels.push(w);
  }
  body.add(mesh(G.box, wood, 0, 0.6, 0, 1.3, 0.18, 1.7));
  for (const [x, z] of [[-0.55, 0.7], [0.55, 0.7], [-0.55, -0.7], [0.55, -0.7]]) body.add(mesh(G.box, wood, x, 1.0, z, 0.1, 0.8, 0.1));
  const roof = mesh(G.cone4, paintShared(n.primary), 0, 1.55, 0, 1.1, 0.6, 1.3);
  roof.rotation.y = Math.PI / 4;
  roof.scale.set(1.05, 0.6, 1.35);
  body.add(roof);
  body.add(mesh(G.box, paintShared(n.secondary), 0, 1.3, 0, 1.32, 0.08, 1.75));
  const log = mesh(G.cyl, paintShared(0x6e4424), 0, 0.85, 0.4, 0.17, 2.2, 0.17);
  log.rotation.x = Math.PI / 2;
  body.add(log);
  const tip = mesh(G.cone, paintShared(0x8f939e), 0, 0.85, 1.6, 0.24, 0.35, 0.24);
  tip.rotation.x = Math.PI / 2;
  body.add(tip);
  return { body, flashMats: [wood], wheels, logged: log, height: 1.9, rolls: true };
}

// Kuşatma kulesi: yüksek ahşap kule, tekerlekler, tepede sancak
function buildSiegeTower(nation, n) {
  const body = new THREE.Group();
  const wood = flashMat(0x9a6436);
  const wheels = [];
  for (const [x, z] of [[-0.6, 0.55], [0.6, 0.55], [-0.6, -0.55], [0.6, -0.55]]) {
    const w = mesh(G.cyl, paintShared(0x5a3a20), x, 0.28, z, 0.28, 0.14, 0.28);
    w.rotation.z = Math.PI / 2;
    body.add(w);
    wheels.push(w);
  }
  body.add(mesh(G.taper, wood, 0, 1.6, 0, 0.75, 2.6, 0.75));
  for (let i = 0; i < 4; i++) body.add(mesh(G.box, paintShared(0x6e4424), 0, 0.7 + i * 0.65, 0.01, 1.3 - i * 0.08, 0.07, 1.3 - i * 0.08));
  body.add(mesh(G.box, paintShared(n.primary), 0, 1.9, 0.62, 0.8, 1.0, 0.04));
  body.add(mesh(G.box, paintShared(n.secondary), 0, 1.9, 0.645, 0.16, 1.0, 0.02));
  // mazgallı üst platform
  body.add(mesh(G.box, wood, 0, 2.95, 0, 1.25, 0.12, 1.25));
  for (const [x, z] of [[-0.5, -0.5], [0.5, -0.5], [-0.5, 0.5], [0.5, 0.5]]) body.add(mesh(G.box, wood, x, 3.15, z, 0.22, 0.3, 0.22));
  body.add(mesh(G.cyl, paintShared(0x6e4424), 0, 3.6, 0, 0.04, 1.2, 0.04));
  const flag = new THREE.Mesh(G.plane, flagMat(nation));
  flag.position.set(0.32, 3.95, 0);
  flag.scale.set(0.6, 0.4, 1);
  body.add(flag);
  return { body, flashMats: [wood], wheels, flag, height: 4.2, rolls: true };
}

function build(e) {
  const n = NATIONS[e.nation];
  switch (e.type) {
    case 'infantry':
      return foot('infantry', e.nation, n);
    case 'knight':
      return foot('knight', e.nation, n);
    case 'light':
      return rider('light', e.nation, n, { coat: 0x9a6a3a, cloth: n.primary, clothTrim: n.secondary }, 16);
    case 'horseArcher':
      return rider('horseArcher', e.nation, n, { coat: 0x6b4a2e, cloth: n.secondary }, 14);
    case 'commander':
      return rider('commander', e.nation, n, { coat: 0xe8e2d4, mane: 0xb0a890, cloth: n.primary, clothTrim: n.secondary }, 6);
    case 'ram':
      return buildRam(n);
    case 'siegeTower':
      return buildSiegeTower(e.nation, n);
    default:
      return foot('infantry', e.nation, n);
  }
}

export function createEnemyModel(e) {
  const u = build(e);
  const g = new THREE.Group();
  const holder = new THREE.Group();
  holder.add(u.body);
  holder.scale.setScalar(e.radius * VISUAL_SCALE * (u.soldier ? 2.2 / SOLDIER_HEIGHT : 1) * (u.mounted ? 0.8 : 1) * (u.rolls ? 0.75 : 1));
  g.add(holder);
  // zifte bulanmış: altta kara leke
  const slowSpot = new THREE.Mesh(G.disc, slowMat);
  slowSpot.scale.set(e.radius * 1.5, 0.1, e.radius * 1.5);
  slowSpot.position.y = 0.01;
  g.add(slowSpot);
  const flames = new THREE.Group();
  for (let i = 0; i < 3; i++) {
    const f = new THREE.Mesh(flameGeo, flameMat);
    const a = (i / 3) * Math.PI * 2;
    f.position.set(Math.cos(a) * e.radius * 0.6, 0, Math.sin(a) * e.radius * 0.6);
    flames.add(f);
  }
  g.add(flames);
  u.flames = flames;
  u.holder = holder;
  u.slowSpot = slowSpot;
  u.topY = u.height * holder.scale.x;
  g.userData = u;
  return g;
}

export function updateEnemyModel(model, e, time) {
  const u = model.userData;
  const yaw = Math.PI / 2 - e.angle;
  if (u.soldier) {
    model.rotation.y = Math.atan2(Math.sin(yaw), Math.cos(yaw) + FACE_CAMERA);
    // adım, kat edilen yola bağlı: yavaşlayınca ve hızlandırınca doğru görünür
    u.soldier.pose('Walking_A', e.dist / u.stride + e.seed);
  } else {
    // atlılar ve kuşatma araçları gittikleri yöne bakar (biraz kameraya)
    model.rotation.y = Math.atan2(Math.sin(yaw), Math.cos(yaw) + 0.25);
    if (u.horse) animateHorse(u.horse, time, u.gallop * (1 - e.slow * 0.6), e.seed);
    if (u.wheels) u.wheels.forEach((w) => (w.rotation.x = -e.dist * 3));
    if (u.flag) u.flag.rotation.y = Math.sin(time * 3 + e.seed) * 0.3;
    if (u.rolls) u.body.rotation.z = Math.sin(time * 6 + e.seed) * 0.02;
  }
  const flash = e.flash > 0 ? Math.min(1, e.flash / RULES.hitFlashTime) * 0.8 : 0;
  for (const m of u.flashMats) m.emissiveIntensity = flash;
  if (u.soldier) u.soldier.flash(flash);
  if (u.rider) u.rider.flash(flash);
  u.slowSpot.visible = e.slow > 0;
  u.flames.visible = e.slow > 0;
  if (e.slow > 0) {
    u.flames.children.forEach((f, i) => {
      const k = 0.7 + 0.3 * Math.sin(time * 19 + i * 2.1 + e.seed);
      f.scale.set(e.radius * 0.5, e.radius * 1.3 * k, e.radius * 0.5);
    });
  }
}

export function disposeEnemyModel(model) {
  const u = model.userData;
  for (const m of u.flashMats) m.dispose();
  if (u.soldier) u.soldier.dispose();
  if (u.rider) u.rider.dispose();
}
