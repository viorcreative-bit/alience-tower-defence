import * as THREE from 'three';
import { RULES } from '../data/rules.js';
import { toon, noOutline } from './palette.js';

// 3D uzaylı ve uzay aracı modelleri. Modeller 1 birim yarıçapa göre kurulur,
// sonra uzaylının yarıçapı kadar ölçeklenir. Her türün modeli kendi fonksiyonunda.

const G = {
  ball: new THREE.SphereGeometry(1, 20, 14),
  cap: new THREE.CapsuleGeometry(1, 1, 4, 10),
  cyl: new THREE.CylinderGeometry(1, 1, 1, 16),
  box: new THREE.BoxGeometry(1, 1, 1),
  torus: new THREE.TorusGeometry(1, 0.08, 6, 24),
  half: new THREE.SphereGeometry(1, 20, 10, 0, Math.PI * 2, 0, Math.PI / 2),
  cone: new THREE.ConeGeometry(1, 1, 16, 1, true),
};
const eyeMat = toon(0x0a0c14);
const eyeShineMat = noOutline(new THREE.MeshBasicMaterial({ color: 0xffffff }));
const mouthMat = noOutline(new THREE.MeshBasicMaterial({ color: 0x1a1a1a }));
const ringMat = noOutline(new THREE.MeshBasicMaterial({ color: 0x7fd8ff, transparent: true, opacity: 0.8 }));
const metal = toon(0x9aa3bd);
const darkMetal = toon(0x4e4566);
const saucerLightMat = noOutline(new THREE.MeshBasicMaterial({ color: 0xffe066 }));
const pilotMat = toon(0x7ccf4a);
const glassMat = noOutline(new THREE.MeshLambertMaterial({ color: 0x9fd8ff, transparent: true, opacity: 0.45 }));
const beamMat = noOutline(new THREE.MeshBasicMaterial({ color: 0x7cff6b, transparent: true, opacity: 0.18, depthWrite: false, side: THREE.DoubleSide }));
const cockpitMat = toon(0x7cff6b, { emissive: 0x3dbf2f, emissiveIntensity: 0.8 });
const flameMat = noOutline(new THREE.MeshBasicMaterial({ color: 0x78dcff, transparent: true, opacity: 0.85 }));
const noseGeo = new THREE.ConeGeometry(1, 1, 4);
const flameGeo = new THREE.ConeGeometry(0.15, 0.6, 10);
const veinMat = toon(0xffe066, { emissive: 0xffd040, emissiveIntensity: 0.8 });

// Modeller mantıktaki yarıçaptan biraz büyük çizilir ki eğik kamerada seçilsin.
const VISUAL_SCALE = 1.7;
// İnsansılar yürüdükleri yöne dönerken yüzlerini kameraya doğru çevirir (0 = hiç, 1 = tam).
const FACE_CAMERA = 0.9;

function mesh(geo, mat, x, y, z, sx, sy, sz) {
  const m = new THREE.Mesh(geo, mat);
  m.position.set(x, y, z);
  m.scale.set(sx, sy ?? sx, sz ?? sx);
  m.castShadow = true;
  return m;
}

function skin(color) {
  return toon(color, { emissive: 0xffffff, emissiveIntensity: 0 });
}

// Klasik uzaylı gövdesi: iri kel kafa, parlak siyah badem gözler, ince gövde.
// p: { color, head, body, bulk }
function buildHumanoid(p) {
  const root = new THREE.Group();
  const mat = skin(p.color);
  const bulk = p.bulk || 1;
  const legLen = 0.55 * p.body;
  const hip = legLen + 0.15;
  const torsoLen = 0.6 * p.body;
  const shoulder = hip + torsoLen + 0.05;
  const headR = 0.95 * p.head;
  const headY = shoulder + 0.2 + headR * 0.95;

  const legs = [];
  for (const s of [-1, 1]) {
    const pivot = new THREE.Group();
    pivot.position.set(s * 0.13 * bulk, hip, 0);
    pivot.add(mesh(G.cap, mat, 0, -legLen / 2, 0, 0.1 * bulk, legLen / 2, 0.1 * bulk));
    root.add(pivot);
    legs.push(pivot);
  }
  root.add(mesh(G.cap, mat, 0, hip + torsoLen / 2, 0, 0.27 * bulk, torsoLen / 2, 0.2 * bulk));
  const arms = [];
  for (const s of [-1, 1]) {
    const pivot = new THREE.Group();
    pivot.position.set(s * 0.33 * bulk, shoulder, 0);
    pivot.rotation.z = s * 0.15;
    pivot.add(mesh(G.cap, mat, 0, -0.32, 0, 0.075 * bulk, 0.3, 0.075 * bulk));
    root.add(pivot);
    arms.push(pivot);
  }
  root.add(mesh(G.cyl, mat, 0, shoulder + 0.1, 0, 0.08, 0.25, 0.08));

  const head = new THREE.Group();
  head.position.y = headY;
  // geniş kubbe, sivri çene
  head.add(mesh(G.ball, mat, 0, 0, 0, headR, headR * 1.08, headR * 0.92));
  head.add(mesh(G.ball, mat, 0, -headR * 0.55, headR * 0.12, headR * 0.5, headR * 0.5, headR * 0.55));
  for (const s of [-1, 1]) {
    const eye = mesh(G.ball, eyeMat, s * headR * 0.38, -headR * 0.05, headR * 0.72, headR * 0.3, headR * 0.17, headR * 0.16);
    eye.rotation.z = s * 0.45;
    eye.rotation.y = s * 0.35;
    eye.castShadow = false;
    head.add(eye);
    // çizgi film gözü: küçük beyaz parıltı
    const shine = mesh(G.ball, eyeShineMat, s * headR * 0.3, headR * 0.04, headR * 0.86, headR * 0.06);
    shine.castShadow = false;
    head.add(shine);
  }
  const mouth = mesh(G.torus, mouthMat, 0, -headR * 0.6, headR * 0.6, headR * 0.12);
  mouth.rotation.z = Math.PI;
  mouth.scale.z = headR * 0.05;
  mouth.castShadow = false;
  head.add(mouth);
  // dik kamerada yüz görünsün diye kafa hafifçe yukarı bakar
  head.rotation.x = -0.5;
  root.add(head);

  return { root, mat, legs, arms, head, height: headY + headR * 1.08 };
}

function animateWalk(u, e, time, speed, amount = 0.6) {
  const swing = Math.sin(time * speed + e.seed);
  u.legs[0].rotation.x = swing * amount;
  u.legs[1].rotation.x = -swing * amount;
  u.arms[0].rotation.x = -swing * amount * 0.8;
  u.arms[1].rotation.x = swing * amount * 0.8;
  u.body.position.y = Math.abs(swing) * 0.05;
}

function humanoidModel(p, extra) {
  const h = buildHumanoid(p);
  const body = new THREE.Group();
  body.add(h.root);
  if (extra) extra(h);
  return { body, mat: h.mat, legs: h.legs, arms: h.arms, head: h.head, height: h.height, walk: p.walk, lean: p.lean || 0 };
}

const BUILD = {
  // Sürüngen: klasik yeşil uzaylı
  reptile: () => humanoidModel({ color: 0x7ccf4a, head: 1, body: 1, walk: 10 }),
  // Akrep: turuncu, ince, öne eğik koşan
  scorpion: () => humanoidModel({ color: 0xff9b3d, head: 0.95, body: 1.1, walk: 22, lean: 0.35 }),
  // Kabuklu: gri-mor, miğferli ve göğüs zırhlı
  shell: () =>
    humanoidModel({ color: 0x8e82a8, head: 1, body: 1.05, walk: 5 }, (h) => {
      const helm = mesh(G.half, darkMetal, 0, 0.15, -0.05, 1.0, 0.85, 0.98);
      h.head.add(helm);
      h.root.add(mesh(G.box, darkMetal, 0, 1.15, 0.05, 0.7, 0.55, 0.5));
      for (const s of [-1, 1]) h.root.add(mesh(G.ball, darkMetal, s * 0.38, 1.38, 0, 0.17, 0.12, 0.17));
    }),
  // Dev: iri yapılı, geniş omuzlu koyu yeşil uzaylı
  giant: () => humanoidModel({ color: 0x4f9a3a, head: 0.8, body: 1.45, bulk: 2.0, walk: 3.5 }),
  // Ana Beyin: şişkin pembe kafasında parlayan damarlar
  brain: () =>
    humanoidModel({ color: 0xe0566f, head: 1.15, body: 0.85, walk: 3 }, (h) => {
      for (let i = 0; i < 4; i++) {
        const v = mesh(G.torus, veinMat, 0, 0.35, 0, 0.75 - i * 0.08);
        v.rotation.set(Math.PI / 2 + (i - 1.5) * 0.35, 0, i * 0.8);
        v.castShadow = false;
        h.head.add(v);
      }
    }),
};

// Uçan Daire: metal disk, cam kubbede pilot, yanıp sönen ışıklar, çekim ışını.
function buildSaucer() {
  const body = new THREE.Group();
  const mat = toon(0xc5cce0, { emissive: 0xffffff, emissiveIntensity: 0 });
  const disk = new THREE.Group();
  disk.position.y = 2.2;
  disk.add(mesh(G.ball, mat, 0, 0, 0, 1.25, 0.3, 1.25));
  disk.add(mesh(G.cyl, darkMetal, 0, -0.2, 0, 0.5, 0.15, 0.5));
  const pilot = mesh(G.ball, pilotMat, 0, 0.35, 0, 0.22, 0.28, 0.22);
  disk.add(pilot);
  const dome = mesh(G.half, glassMat, 0, 0.12, 0, 0.55);
  dome.castShadow = false;
  disk.add(dome);
  const lights = [];
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    const l = mesh(G.ball, saucerLightMat, Math.cos(a) * 1.1, 0, Math.sin(a) * 1.1, 0.09);
    l.castShadow = false;
    disk.add(l);
    lights.push(l);
  }
  const beam = mesh(G.cone, beamMat, 0, 1.0, 0, 0.75, 2.0, 0.75);
  beam.castShadow = false;
  body.add(beam);
  body.add(disk);
  return { body, mat, disk, lights, height: 2.9, hover: true };
}

// Savaş Gemisi: zırhlı uzun gövde, kanatlar, yeşil kokpit, mavi motor alevi.
function buildCruiser() {
  const body = new THREE.Group();
  const mat = toon(0x8d82ab, { emissive: 0xffffff, emissiveIntensity: 0 });
  const ship = new THREE.Group();
  ship.position.y = 1.4;
  ship.add(mesh(G.box, mat, -0.1, 0, 0, 1.8, 0.5, 0.75));
  const nose = mesh(noseGeo, mat, 1.05, 0, 0, 0.42, 0.7, 0.42);
  nose.rotation.z = -Math.PI / 2;
  nose.rotation.x = Math.PI / 4;
  ship.add(nose);
  ship.add(mesh(G.box, darkMetal, -0.4, -0.05, 0, 0.9, 0.1, 2.0));
  ship.add(mesh(G.box, darkMetal, -0.75, 0.3, 0, 0.4, 0.4, 0.08));
  const cockpit = mesh(G.ball, cockpitMat, 0.5, 0.25, 0, 0.32, 0.16, 0.22);
  ship.add(cockpit);
  const flames = [];
  for (const s of [-1, 1]) {
    const f = mesh(flameGeo, flameMat, -1.25, 0, s * 0.22, 1);
    f.rotation.z = Math.PI / 2;
    f.castShadow = false;
    ship.add(f);
    flames.push(f);
  }
  body.add(ship);
  return { body, mat, ship, flames, height: 2.0, hover: true, faceAlong: true };
}

BUILD.saucer = buildSaucer;
BUILD.cruiser = buildCruiser;

export function createEnemyModel(e) {
  const u = BUILD[e.type]();
  const g = new THREE.Group();
  const holder = new THREE.Group();
  holder.add(u.body);
  holder.scale.setScalar(e.radius * VISUAL_SCALE);
  g.add(holder);
  const slowRing = mesh(G.torus, ringMat, 0, 0.03, 0, e.radius * 1.6, e.radius * 1.6, e.radius * 1.6);
  slowRing.rotation.x = Math.PI / 2;
  slowRing.castShadow = false;
  g.add(slowRing);
  u.holder = holder;
  u.slowRing = slowRing;
  u.topY = u.height * e.radius * VISUAL_SCALE;
  g.userData = u;
  return g;
}

export function updateEnemyModel(model, e, time) {
  const u = model.userData;
  // insansılar yürüdükleri yöne bakar (+z yüz), gemi burnu +x
  if (u.faceAlong) {
    model.rotation.y = -e.angle;
  } else {
    const yaw = Math.PI / 2 - e.angle;
    model.rotation.y = Math.atan2(Math.sin(yaw), Math.cos(yaw) + FACE_CAMERA);
  }
  if (u.legs) {
    u.body.rotation.x = u.lean;
    animateWalk(u, e, time, u.walk);
  } else if (u.disk) {
    u.disk.position.y = 2.2 + Math.sin(time * 4 + e.seed) * 0.15;
    u.disk.rotation.y = time * 2;
    u.lights.forEach((l, i) => (l.visible = Math.sin(time * 8 - i) > 0));
  } else if (u.ship) {
    u.ship.position.y = 1.4 + Math.sin(time * 3 + e.seed) * 0.1;
    const f = 0.8 + 0.4 * Math.sin(time * 30 + e.seed);
    u.flames.forEach((fl) => fl.scale.set(1, f, 1));
  }
  u.mat.emissiveIntensity = e.flash > 0 ? Math.min(1, e.flash / RULES.hitFlashTime) * 0.8 : 0;
  u.slowRing.visible = e.slow > 0;
}

export function disposeEnemyModel(model) {
  model.userData.mat.dispose();
}
