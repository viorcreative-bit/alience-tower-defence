import * as THREE from 'three';
import { RULES } from '../data/rules.js';
import { NATIONS } from '../data/nations.js';
import { toonShared, noOutline, nationFlagTexture } from './palette.js';
import { G, mesh, flashMat, buildPerson, buildRider, animatePerson, animateHorse } from './figures.js';

// Düşman birliklerinin 3D modelleri. Renkler o dalganın devletinden gelir.
// Modeller 1 birim yarıçapa göre kurulur, birliğin yarıçapı kadar ölçeklenir.

const VISUAL_SCALE = 1.7;
// Yürüyen askerler kameraya biraz döner ki yüzleri görünsün (0 = hiç, 1 = tam).
const FACE_CAMERA = 0.9;
const slowMat = noOutline(new THREE.MeshBasicMaterial({ color: 0x1d1620, transparent: true, opacity: 0.55, depthWrite: false }));
const flagMats = new Map();

function flagMat(nation) {
  let m = flagMats.get(nation);
  if (!m) {
    const n = NATIONS[nation];
    m = noOutline(new THREE.MeshLambertMaterial({ map: nationFlagTexture(n.primary, n.secondary), side: THREE.DoubleSide }));
    flagMats.set(nation, m);
  }
  return m;
}

function soldier(n, extra) {
  const p = buildPerson({ tunic: n.primary, trim: n.secondary, metal: n.metal, ...extra });
  const body = new THREE.Group();
  body.add(p.root);
  return { body, person: p, flashMats: p.flashMats, height: p.height, walk: extra.walk || 9 };
}

function rider(n, nation, personExtra, horseExtra, gait) {
  const r = buildRider(
    { tunic: n.primary, trim: n.secondary, metal: n.metal, ...personExtra, flagMat: flagMat(nation) },
    { cloth: n.primary, clothTrim: n.secondary, ...horseExtra },
  );
  const body = new THREE.Group();
  body.add(r.horse.root);
  return { body, horse: r.horse, flashMats: r.flashMats, height: r.height, gallop: gait, mounted: true };
}

// Koçbaşı: tekerlekli, devlet renginde örtülü çatı, önde demir başlı kütük
function buildRam(n) {
  const body = new THREE.Group();
  const wood = flashMat(0x8a5a32);
  const wheels = [];
  for (const [x, z] of [[-0.7, 0.6], [0.7, 0.6], [-0.7, -0.6], [0.7, -0.6]]) {
    const w = mesh(G.cyl, toonShared(0x5a3a20), x, 0.32, z, 0.32, 0.14, 0.32);
    w.rotation.z = Math.PI / 2;
    body.add(w);
    wheels.push(w);
  }
  body.add(mesh(G.box, wood, 0, 0.6, 0, 1.3, 0.18, 1.7));
  for (const [x, z] of [[-0.55, 0.7], [0.55, 0.7], [-0.55, -0.7], [0.55, -0.7]]) body.add(mesh(G.box, wood, x, 1.0, z, 0.1, 0.8, 0.1));
  const roof = mesh(G.cone4, toonShared(n.primary), 0, 1.55, 0, 1.1, 0.6, 1.3);
  roof.rotation.y = Math.PI / 4;
  roof.scale.set(1.05, 0.6, 1.35);
  body.add(roof);
  body.add(mesh(G.box, toonShared(n.secondary), 0, 1.3, 0, 1.32, 0.08, 1.75));
  const log = mesh(G.cyl, toonShared(0x6e4424), 0, 0.85, 0.4, 0.17, 2.2, 0.17);
  log.rotation.x = Math.PI / 2;
  body.add(log);
  const tip = mesh(G.cone, toonShared(0x8f939e), 0, 0.85, 1.6, 0.24, 0.35, 0.24);
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
    const w = mesh(G.cyl, toonShared(0x5a3a20), x, 0.28, z, 0.28, 0.14, 0.28);
    w.rotation.z = Math.PI / 2;
    body.add(w);
    wheels.push(w);
  }
  body.add(mesh(G.taper, wood, 0, 1.6, 0, 0.75, 2.6, 0.75));
  for (let i = 0; i < 4; i++) body.add(mesh(G.box, toonShared(0x6e4424), 0, 0.7 + i * 0.65, 0.01, 1.3 - i * 0.08, 0.07, 1.3 - i * 0.08));
  body.add(mesh(G.box, toonShared(n.primary), 0, 1.9, 0.62, 0.8, 1.0, 0.04));
  body.add(mesh(G.box, toonShared(n.secondary), 0, 1.9, 0.645, 0.16, 1.0, 0.02));
  // mazgallı üst platform
  body.add(mesh(G.box, wood, 0, 2.95, 0, 1.25, 0.12, 1.25));
  for (const [x, z] of [[-0.5, -0.5], [0.5, -0.5], [-0.5, 0.5], [0.5, 0.5]]) body.add(mesh(G.box, wood, x, 3.15, z, 0.22, 0.3, 0.22));
  body.add(mesh(G.cyl, toonShared(0x6e4424), 0, 3.6, 0, 0.04, 1.2, 0.04));
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
      return soldier(n, { hat: 'kettle', weapon: 'spear', shield: n.secondary, walk: 10 });
    case 'knight':
      return soldier(n, { hat: 'greatHelm', armor: true, weapon: 'sword', shield: n.primary, bulk: 1.15, walk: 6 });
    case 'light':
      return rider(n, e.nation, { hat: 'cap', weapon: 'lance', mustache: true }, { coat: 0x9a6a3a }, 16);
    case 'horseArcher':
      return rider(n, e.nation, { hat: 'kettle', weapon: 'bow' }, { coat: 0x6b4a2e }, 14);
    case 'commander':
      return rider(n, e.nation, { hat: 'plume', armor: true, weapon: 'banner', cape: n.primary, beard: 0x6b4a2e, bulk: 1.15 }, { coat: 0xe8e2d4, mane: 0xb0a890 }, 6);
    case 'ram':
      return buildRam(n);
    case 'siegeTower':
      return buildSiegeTower(e.nation, n);
    default:
      return soldier(n, { hat: 'kettle', weapon: 'spear' });
  }
}

export function createEnemyModel(e) {
  const u = build(e);
  const g = new THREE.Group();
  const holder = new THREE.Group();
  holder.add(u.body);
  holder.scale.setScalar(e.radius * VISUAL_SCALE * (u.mounted ? 0.8 : 1) * (u.rolls ? 0.75 : 1));
  g.add(holder);
  // zifte bulanmış: altta kara leke
  const slowSpot = new THREE.Mesh(G.disc, slowMat);
  slowSpot.scale.set(e.radius * 1.5, 0.1, e.radius * 1.5);
  slowSpot.position.y = 0.01;
  g.add(slowSpot);
  u.holder = holder;
  u.slowSpot = slowSpot;
  u.topY = u.height * holder.scale.x;
  g.userData = u;
  return g;
}

export function updateEnemyModel(model, e, time) {
  const u = model.userData;
  const yaw = Math.PI / 2 - e.angle;
  if (u.person) {
    model.rotation.y = Math.atan2(Math.sin(yaw), Math.cos(yaw) + FACE_CAMERA);
    animatePerson(u.person, time, u.walk * (1 - e.slow * 0.6), e.seed);
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
  u.slowSpot.visible = e.slow > 0;
}

export function disposeEnemyModel(model) {
  for (const m of model.userData.flashMats) m.dispose();
}
