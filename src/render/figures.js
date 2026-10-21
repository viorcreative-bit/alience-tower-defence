import * as THREE from 'three';
import { toon, toonShared, noOutline, PALETTE } from './palette.js';

// İnsan ve at figürleri (çizgi film oranları: iri kafa, kısa gövde).
// Düşman askerleri, devriyeler ve Padişah aynı kurucudan çıkar. Yüz +z yönündedir.
// Ölçü: yaklaşık 2.2 birim boy; çağıran taraf ölçekler.

export const G = {
  ball: new THREE.SphereGeometry(1, 16, 12),
  cap: new THREE.CapsuleGeometry(1, 1, 4, 10),
  cyl: new THREE.CylinderGeometry(1, 1, 1, 12),
  cyl6: new THREE.CylinderGeometry(1, 1, 1, 6),
  taper: new THREE.CylinderGeometry(0.75, 1, 1, 12),
  box: new THREE.BoxGeometry(1, 1, 1),
  cone: new THREE.ConeGeometry(1, 1, 12),
  cone4: new THREE.ConeGeometry(1, 1, 4),
  half: new THREE.SphereGeometry(1, 16, 8, 0, Math.PI * 2, 0, Math.PI / 2),
  disc: new THREE.CylinderGeometry(1, 1, 0.12, 16),
  torus: new THREE.TorusGeometry(1, 0.12, 6, 20),
  plane: new THREE.PlaneGeometry(1, 1),
};

const M = {
  eye: noOutline(new THREE.MeshBasicMaterial({ color: 0x1a120c })),
  white: toonShared(0xf4f1e8),
  metal: toonShared(0xb7bcc6),
  dark: toonShared(0x3a2c22),
  wood: toonShared(PALETTE.wood),
  woodDark: toonShared(PALETTE.woodDark),
  gold: toonShared(PALETTE.gold),
  boot: toonShared(0x4a3324),
};

export function mesh(geo, mat, x, y, z, sx, sy, sz) {
  const m = new THREE.Mesh(geo, mat);
  m.position.set(x, y, z);
  if (sx !== undefined) m.scale.set(sx, sy ?? sx, sz ?? sx);
  m.castShadow = true;
  return m;
}

// Vuruşta beyaz parlayan, figüre özel malzeme
export function flashMat(color) {
  return toon(color, { emissive: 0xffffff, emissiveIntensity: 0 });
}

// Şapka / miğfer çeşitleri; kafa grubuna eklenir (kafa yarıçapı r)
function addHat(head, kind, r, o) {
  const metal = o.metalMat || M.metal;
  switch (kind) {
    case 'kettle': // geniş kenarlı demir başlık
      head.add(mesh(G.half, metal, 0, r * 0.25, 0, r * 1.05, r * 0.8, r * 1.05));
      head.add(mesh(G.disc, metal, 0, r * 0.3, 0, r * 1.45, 1, r * 1.45));
      break;
    case 'greatHelm': // kapalı şövalye miğferi, göz yarığı
      head.add(mesh(G.cyl, metal, 0, r * 0.05, 0, r * 1.08, r * 1.9, r * 1.08));
      head.add(mesh(G.box, M.dark, 0, r * 0.15, r * 1.02, r * 1.3, r * 0.14, r * 0.1));
      head.add(mesh(G.half, metal, 0, r * 0.98, 0, r * 1.08, r * 0.45, r * 1.08));
      break;
    case 'plume': // tüylü komutan miğferi
      head.add(mesh(G.half, metal, 0, r * 0.2, 0, r * 1.08, r * 0.95, r * 1.08));
      head.add(mesh(G.cap, o.trimMat, 0, r * 1.25, -r * 0.2, r * 0.18, r * 0.45, r * 0.18));
      break;
    case 'cap': // bez başlık
      head.add(mesh(G.half, o.trimMat, 0, r * 0.3, 0, r * 1.02, r * 0.7, r * 1.02));
      break;
    case 'bork': { // Yeniçeri börkü: uzun beyaz keçe, arkaya sarkan yatırma, alnında kaşıklık
      head.add(mesh(G.cyl, M.white, 0, r * 0.45, 0, r * 0.95, r * 0.5, r * 0.95));
      const top = mesh(G.taper, M.white, 0, r * 1.25, -r * 0.15, r * 0.7, r * 1.3, r * 0.7);
      top.rotation.x = -0.25;
      head.add(top);
      const flap = mesh(G.box, M.white, 0, r * 1.2, -r * 1.0, r * 0.9, r * 0.25, r * 1.2);
      flap.rotation.x = -0.9;
      head.add(flap);
      head.add(mesh(G.box, M.gold, 0, r * 0.75, r * 0.85, r * 0.25, r * 0.55, r * 0.1));
      break;
    }
    case 'turban': // sarık + sivri miğfer (Sipahi)
      head.add(mesh(G.torus, M.white, 0, r * 0.35, 0, r * 0.95, r * 0.95, r * 1.6));
      head.children[head.children.length - 1].rotation.x = Math.PI / 2;
      head.add(mesh(G.cone, metal, 0, r * 1.05, 0, r * 0.8, r * 1.1, r * 0.8));
      break;
    case 'sultan': { // büyük beyaz kavuk, sorguç
      head.add(mesh(G.ball, M.white, 0, r * 0.85, 0, r * 1.3, r * 1.1, r * 1.3));
      head.add(mesh(G.box, M.gold, 0, r * 1.25, r * 1.15, r * 0.25, r * 0.3, r * 0.1));
      head.add(mesh(G.cap, o.trimMat, 0, r * 1.9, r * 0.9, r * 0.08, r * 0.35, r * 0.08));
      break;
    }
    default:
  }
}

function addWeapon(arm, kind, o) {
  // kol pivotu omuzda; el yaklaşık y = -0.6
  switch (kind) {
    case 'spear': {
      const s = mesh(G.cyl6, M.wood, 0, -0.35, 0.1, 0.035, 1.9, 0.035);
      arm.add(s);
      arm.add(mesh(G.cone4, M.metal, 0, 0.66, 0.1, 0.07, 0.25, 0.07));
      break;
    }
    case 'lance': {
      const s = mesh(G.cyl6, M.wood, 0, -0.6, 0.55, 0.04, 2.2, 0.04);
      s.rotation.x = 1.2;
      arm.add(s);
      const tip = mesh(G.cone4, M.metal, 0, -0.18, 1.6, 0.07, 0.28, 0.07);
      tip.rotation.x = 1.2 + Math.PI;
      arm.add(tip);
      if (o.trimMat) {
        const pen = mesh(G.plane, o.trimMat, 0, -0.1, 1.25, 0.02, 0.18, 0.3);
        pen.rotation.y = Math.PI / 2;
        arm.add(pen);
      }
      break;
    }
    case 'sword':
    case 'yatagan': {
      const blade = mesh(G.box, M.metal, 0, -0.85, 0.12, 0.05, 0.6, 0.09);
      blade.rotation.x = kind === 'yatagan' ? 0.35 : 0;
      arm.add(blade);
      arm.add(mesh(G.box, M.gold, 0, -0.58, 0.08, 0.16, 0.04, 0.12));
      break;
    }
    case 'bow': {
      const bow = mesh(G.torus, M.woodDark, 0, -0.62, 0.15, 0.45, 0.45, 0.45);
      bow.scale.z = 0.2;
      bow.rotation.y = Math.PI / 2;
      arm.add(bow);
      break;
    }
    case 'musket': {
      const gun = mesh(G.cyl6, M.woodDark, 0, -0.6, 0.4, 0.045, 1.1, 0.045);
      gun.rotation.x = 1.4;
      arm.add(gun);
      break;
    }
    case 'banner': {
      arm.add(mesh(G.cyl6, M.wood, 0, 0.1, 0.1, 0.03, 2.4, 0.03));
      if (o.flagMat) {
        const f = new THREE.Mesh(G.plane, o.flagMat);
        f.position.set(0, 1.05, -0.3);
        f.scale.set(0.6, 0.4, 1);
        f.rotation.y = Math.PI / 2;
        arm.add(f);
      }
      break;
    }
    default:
  }
}

// o: { skin, tunic, trim, pants, hat, armor, weapon, shield, bulk, seated, cape, flagMat }
export function buildPerson(o) {
  const root = new THREE.Group();
  const bulk = o.bulk || 1;
  const tunicMat = flashMat(o.tunic);
  const skinMat = flashMat(o.skin ?? PALETTE.skin);
  const trimMat = toonShared(o.trim ?? 0xe0b24a);
  const pantsMat = toonShared(o.pants ?? 0x5a4632);
  const metalMat = o.metal ? toonShared(o.metal) : M.metal;
  const flashMats = [tunicMat, skinMat];
  const hip = 0.62;
  const legs = [];
  if (!o.seated) {
    for (const s of [-1, 1]) {
      const pivot = new THREE.Group();
      pivot.position.set(s * 0.14 * bulk, hip, 0);
      pivot.add(mesh(G.cap, pantsMat, 0, -0.26, 0, 0.11 * bulk, 0.3, 0.11 * bulk));
      pivot.add(mesh(G.box, M.boot, 0, -0.55, 0.05, 0.16 * bulk, 0.12, 0.26));
      root.add(pivot);
      legs.push(pivot);
    }
  } else {
    // ata binmiş: bacaklar yanlara açık
    for (const s of [-1, 1]) {
      const l = mesh(G.cap, pantsMat, s * 0.28, hip - 0.15, 0.1, 0.1, 0.25, 0.1);
      l.rotation.z = s * 0.5;
      l.rotation.x = -0.4;
      root.add(l);
    }
  }
  // gövde: kaftan/tunik (eteği hafif geniş)
  const torsoMat = o.armor ? metalMat : tunicMat;
  root.add(mesh(G.taper, torsoMat, 0, hip + 0.3, 0, 0.34 * bulk, 0.62, 0.26 * bulk));
  if (!o.seated) root.add(mesh(G.taper, tunicMat, 0, hip - 0.02, 0, 0.32 * bulk, 0.3, 0.27 * bulk));
  if (o.armor) {
    // zırhın üstünde devlet renginde cüppe
    root.add(mesh(G.box, tunicMat, 0, hip + 0.22, 0.2 * bulk, 0.4 * bulk, 0.55, 0.05));
  }
  root.add(mesh(G.box, trimMat, 0, hip + 0.06, 0, 0.66 * bulk, 0.07, 0.54 * bulk)); // kuşak
  if (o.cape) {
    const cape = mesh(G.box, toonShared(o.cape), 0, hip + 0.15, -0.28 * bulk, 0.6 * bulk, 0.9, 0.05);
    cape.rotation.x = 0.15;
    root.add(cape);
  }

  const shoulder = hip + 0.58;
  const arms = [];
  for (const s of [-1, 1]) {
    const pivot = new THREE.Group();
    pivot.position.set(s * 0.4 * bulk, shoulder, 0);
    pivot.rotation.z = s * 0.12;
    pivot.add(mesh(G.cap, torsoMat === metalMat ? metalMat : tunicMat, 0, -0.25, 0, 0.09 * bulk, 0.26, 0.09 * bulk));
    pivot.add(mesh(G.ball, skinMat, 0, -0.55, 0.02, 0.09));
    root.add(pivot);
    arms.push(pivot);
  }
  if (o.weapon) addWeapon(arms[1], o.weapon, { trimMat, flagMat: o.flagMat });
  if (o.shield) {
    const sh = mesh(G.disc, toonShared(o.shield), -0.08, -0.35, 0.2, 0.3, 2.2, 0.3);
    sh.rotation.x = Math.PI / 2;
    sh.rotation.z = 0.1;
    arms[0].add(sh);
    arms[0].add(mesh(G.ball, trimMat, -0.08, -0.35, 0.33, 0.07, 0.07, 0.04));
  }

  // kafa
  const r = 0.36;
  const head = new THREE.Group();
  head.position.y = shoulder + 0.12 + r;
  head.add(mesh(G.ball, skinMat, 0, 0, 0, r, r * 1.05, r));
  for (const s of [-1, 1]) {
    const eye = mesh(G.ball, M.eye, s * r * 0.36, r * 0.05, r * 0.88, r * 0.11, r * 0.16, r * 0.08);
    eye.castShadow = false;
    head.add(eye);
  }
  if (o.beard) head.add(mesh(G.ball, toonShared(o.beard), 0, -r * 0.55, r * 0.45, r * 0.55, r * 0.45, r * 0.45));
  else if (o.mustache) head.add(mesh(G.box, toonShared(0x3a2a1c), 0, -r * 0.28, r * 0.92, r * 0.7, r * 0.12, r * 0.1));
  addHat(head, o.hat, r, { trimMat, metalMat });
  head.rotation.x = -0.35; // eğik kamerada yüz görünsün
  root.add(head);

  return { root, legs, arms, head, flashMats, height: head.position.y + r * 2.2 };
}

// At: gövde, boyun, baş, 4 bacak. +z ileri. Sırt yüksekliği ~1.15.
export function buildHorse(o = {}) {
  const root = new THREE.Group();
  const coat = flashMat(o.coat ?? 0x8b5a2b);
  const mane = toonShared(o.mane ?? 0x3a2416);
  const legs = [];
  for (const [x, z] of [[-0.22, 0.55], [0.22, 0.55], [-0.22, -0.55], [0.22, -0.55]]) {
    const pivot = new THREE.Group();
    pivot.position.set(x, 0.8, z);
    pivot.add(mesh(G.cap, coat, 0, -0.38, 0, 0.09, 0.5, 0.09));
    pivot.add(mesh(G.cyl, M.dark, 0, -0.78, 0, 0.1, 0.08, 0.1));
    root.add(pivot);
    legs.push(pivot);
  }
  const body = mesh(G.cap, coat, 0, 1.0, 0, 0.34, 0.85, 0.34);
  body.rotation.x = Math.PI / 2;
  root.add(body);
  const neck = mesh(G.cap, coat, 0, 1.42, 0.72, 0.18, 0.38, 0.2);
  neck.rotation.x = 0.6;
  root.add(neck);
  const head = mesh(G.box, coat, 0, 1.68, 0.98, 0.2, 0.22, 0.46);
  head.rotation.x = 0.35;
  root.add(head);
  root.add(mesh(G.box, mane, 0, 1.55, 0.62, 0.06, 0.3, 0.42));
  const tail = mesh(G.cap, mane, 0, 1.0, -0.95, 0.07, 0.3, 0.07);
  tail.rotation.x = -0.6;
  root.add(tail);
  if (o.cloth) {
    // eyer örtüsü (devlet ya da Osmanlı rengi)
    root.add(mesh(G.box, toonShared(o.cloth), 0, 1.12, -0.05, 0.75, 0.42, 0.9));
    if (o.clothTrim) root.add(mesh(G.box, toonShared(o.clothTrim), 0, 0.92, -0.05, 0.77, 0.06, 0.92));
  }
  return { root, legs, flashMats: [coat], height: 1.8 };
}

export function animatePerson(p, time, speed, seed, amount = 0.6) {
  const swing = Math.sin(time * speed + seed);
  if (p.legs.length) {
    p.legs[0].rotation.x = swing * amount;
    p.legs[1].rotation.x = -swing * amount;
  }
  p.arms[0].rotation.x = -swing * amount * 0.6;
  p.root.position.y = Math.abs(swing) * 0.05;
}

export function animateHorse(h, time, speed, seed) {
  const t = time * speed + seed;
  // dört nal: çapraz bacaklar birlikte
  h.legs[0].rotation.x = Math.sin(t) * 0.6;
  h.legs[3].rotation.x = Math.sin(t) * 0.6;
  h.legs[1].rotation.x = Math.sin(t + Math.PI) * 0.6;
  h.legs[2].rotation.x = Math.sin(t + Math.PI) * 0.6;
  h.root.position.y = Math.abs(Math.sin(t)) * 0.08;
}

// Binici + at birleşimi
export function buildRider(personOpts, horseOpts) {
  const horse = buildHorse(horseOpts);
  const rider = buildPerson({ ...personOpts, seated: true });
  rider.root.position.set(0, 0.7, -0.05);
  horse.root.add(rider.root);
  return { horse, rider, flashMats: [...horse.flashMats, ...rider.flashMats], height: 0.7 + rider.height };
}
