import * as THREE from 'three';
import { BUILDINGS, CITY } from '../data/buildings.js';
import { canUpgradeBuilding } from '../systems/city.js';
import { toonShared, noOutline, PALETTE, ottomanFlagTexture } from './palette.js';
import { G, mesh, buildPerson } from './figures.js';

// Surların içindeki şehir: saray, Padişah, kurulan binalar, boş arsalar, halk evleri ve servi ağaçları.
// Her binanın modeli kendi fonksiyonunda; seviye değişince model yeniden kurulur.

const M = {
  white: toonShared(PALETTE.whitewash),
  stone: toonShared(PALETTE.stone),
  stoneDark: toonShared(PALETTE.stoneDark),
  tile: toonShared(PALETTE.roofTile),
  lead: toonShared(PALETTE.lead),
  leadDark: toonShared(PALETTE.leadDark),
  wood: toonShared(PALETTE.wood),
  woodDark: toonShared(PALETTE.woodDark),
  gold: toonShared(PALETTE.gold),
  red: toonShared(PALETTE.ottomanRed),
  green: toonShared(0x2f7a4a),
  cypress: toonShared(0x2e6b34),
  window: toonShared(0x3b5f7a),
  hay: toonShared(0xd9b45a),
  target: toonShared(0xf4efe4),
  flag: noOutline(new THREE.MeshLambertMaterial({ map: ottomanFlagTexture(), side: THREE.DoubleSide })),
};
const ringMat = noOutline(new THREE.MeshBasicMaterial({
  color: 0xf2c94c, transparent: true, opacity: 0.32, depthWrite: false, blending: THREE.AdditiveBlending,
}));
const ringGeo = new THREE.RingGeometry(0.36, 0.46, 32);
const dome = new THREE.SphereGeometry(1, 20, 10, 0, Math.PI * 2, 0, Math.PI / 2);

// Beşik çatı: üçgen prizma, mahyası x yönünde; iki yüzü farklı aydınlanır
const gable = new THREE.CylinderGeometry(1, 1, 1, 3);
function roof(mat, x, y, z, w, h, d) {
  const sz = h / 1.5;
  const r = mesh(gable, mat, x, y + sz * 0.5, z, d / 1.732, w, sz);
  r.rotation.set(-Math.PI / 2, 0, Math.PI / 2);
  return r;
}

function windows(g, x, y, z, w, n) {
  for (let i = 0; i < n; i++) {
    const wx = x - w / 2 + ((i + 0.5) * w) / n;
    const win = mesh(G.box, M.window, wx, y, z, 0.07, 0.11, 0.01);
    win.castShadow = false;
    g.add(win);
  }
}

function alem(g, x, y, z, s = 1) {
  g.add(mesh(G.cyl, M.gold, x, y + 0.05 * s, z, 0.012 * s, 0.1 * s, 0.012 * s));
  g.add(mesh(G.ball, M.gold, x, y + 0.1 * s, z, 0.025 * s));
}

function domed(g, mat, x, y, z, r) {
  g.add(mesh(G.cyl, M.white, x, y + 0.03, z, r * 1.02, 0.06, r * 1.02));
  g.add(mesh(dome, mat, x, y + 0.06, z, r, r * 0.85, r));
  alem(g, x, y + 0.06 + r * 0.85, z, 1);
}

function minaret(g, x, z, h) {
  g.add(mesh(G.cyl, M.white, x, h / 2, z, 0.045, h, 0.045));
  g.add(mesh(G.cyl, M.stoneDark, x, h * 0.72, z, 0.07, 0.03, 0.07)); // şerefe
  g.add(mesh(G.cone, M.lead, x, h + 0.09, z, 0.05, 0.2, 0.05));
  alem(g, x, h + 0.18, z, 0.8);
}

function flag(g, x, y, z, s = 1) {
  g.add(mesh(G.cyl, M.woodDark, x, y + 0.2 * s, z, 0.01, 0.4 * s, 0.01));
  const f = new THREE.Mesh(G.plane, M.flag);
  f.position.set(x + 0.11 * s, y + 0.34 * s, z);
  f.scale.set(0.22 * s, 0.14 * s, 1);
  g.add(f);
  return f;
}

// --- Binalar (yaklaşık 0.8 × 0.8 kare taban) ---

function palace(level) {
  const g = new THREE.Group();
  // ana köşk ve iki yan kanat; seviye arttıkça kat ve kubbe büyür
  const h = 0.42 + level * 0.06;
  g.add(mesh(G.box, M.stone, 0, 0.04, 0, 1.9, 0.08, 0.9));
  g.add(mesh(G.box, M.white, 0, h / 2 + 0.08, -0.05, 0.9, h, 0.6));
  windows(g, 0, 0.08 + h * 0.6, 0.255, 0.8, 4);
  domed(g, M.lead, 0, h + 0.08, -0.05, 0.28 + level * 0.03);
  for (const s of [-1, 1]) {
    const wh = 0.3 + (level >= 2 ? 0.08 : 0);
    g.add(mesh(G.box, M.white, s * 0.68, wh / 2 + 0.08, 0, 0.5, wh, 0.5));
    g.add(roof(M.tile, s * 0.68, wh + 0.08, 0, 0.62, 0.22, 0.62));
    windows(g, s * 0.68, 0.08 + wh * 0.6, 0.255, 0.36, 2);
    if (level >= 3) minaret(g, s * 0.92, -0.32, 0.95);
  }
  // revak sütunları ve altın kapı
  for (let i = -2; i <= 2; i++) g.add(mesh(G.cyl, M.white, i * 0.16, 0.2, 0.32, 0.025, 0.26, 0.025));
  g.add(mesh(G.box, M.red, 0, 0.35, 0.33, 0.78, 0.05, 0.08));
  g.add(mesh(G.box, M.gold, 0, 0.18, 0.26, 0.16, 0.2, 0.02));
  const flags = [flag(g, -0.3, h + 0.08, -0.25, 1.2), flag(g, 0.3, h + 0.08, -0.25, 1.2)];
  return { g, flags };
}

function school(level) {
  const g = new THREE.Group();
  g.add(mesh(G.box, M.white, 0, 0.18, -0.05, 0.62, 0.36, 0.5));
  domed(g, M.lead, 0, 0.36, -0.05, 0.2);
  windows(g, 0, 0.22, 0.205, 0.5, 3);
  // revaklı avlu
  for (let i = 0; i < level + 1; i++) g.add(mesh(G.cyl, M.white, -0.24 + i * 0.16, 0.1, 0.28, 0.02, 0.2, 0.02));
  g.add(mesh(G.box, M.tile, -0.24 + (level * 0.16) / 2, 0.21, 0.28, 0.12 + level * 0.16, 0.03, 0.14));
  return { g };
}

function barracks(level) {
  const g = new THREE.Group();
  const len = 0.6 + level * 0.06;
  g.add(mesh(G.box, M.stone, 0, 0.16, -0.08, len, 0.32, 0.42));
  g.add(roof(M.tile, 0, 0.32, -0.08, len + 0.08, 0.2, 0.5));
  windows(g, 0, 0.18, 0.135, len - 0.1, 3);
  // talim meydanı: silah sehpası ve kazan (Yeniçeri ocağının sembolü)
  g.add(mesh(G.box, M.woodDark, -0.2, 0.08, 0.27, 0.22, 0.03, 0.05));
  for (let i = 0; i < 3; i++) g.add(mesh(G.cyl, M.wood, -0.28 + i * 0.08, 0.14, 0.27, 0.01, 0.26, 0.01));
  g.add(mesh(G.taper, toonShared(0xb86b3a), 0.18, 0.07, 0.25, 0.08, 0.12, 0.08));
  const flags = [flag(g, len / 2 - 0.05, 0.4, -0.2, 1.1)];
  return { g, flags };
}

function archery(level) {
  const g = new THREE.Group();
  g.add(mesh(G.cyl, M.stone, -0.18, 0.3, -0.12, 0.17, 0.6, 0.17));
  g.add(mesh(G.cone, M.red, -0.18, 0.72, -0.12, 0.22, 0.26, 0.22));
  // nişan tahtaları
  for (let i = 0; i < level; i++) {
    const x = 0.12 + i * 0.12;
    const t = mesh(G.cyl, M.target, x, 0.18, 0.18, 0.08, 0.02, 0.08);
    t.rotation.x = Math.PI / 2;
    g.add(t);
    const bull = mesh(G.cyl, M.red, x, 0.18, 0.191, 0.035, 0.01, 0.035);
    bull.rotation.x = Math.PI / 2;
    g.add(bull);
    g.add(mesh(G.box, M.wood, x, 0.07, 0.17, 0.015, 0.14, 0.015));
  }
  return { g };
}

function hospital(level) {
  const g = new THREE.Group();
  // avlulu darüşşifa: U plan, ortada şadırvan
  g.add(mesh(G.box, M.white, 0, 0.15, -0.22, 0.7, 0.3, 0.22));
  for (const s of [-1, 1]) g.add(mesh(G.box, M.white, s * 0.26, 0.13, 0.05, 0.18, 0.26, 0.36));
  domed(g, M.green, 0, 0.3, -0.22, 0.13 + level * 0.02);
  g.add(mesh(G.cyl, toonShared(0x7fc8c0), 0, 0.04, 0.08, 0.1, 0.06, 0.1));
  g.add(mesh(G.cyl, M.white, 0, 0.1, 0.08, 0.02, 0.1, 0.02));
  if (level >= 2) for (const s of [-1, 1]) domed(g, M.lead, s * 0.26, 0.26, 0.05, 0.08);
  return { g };
}

function cavalry(level) {
  const g = new THREE.Group();
  // ahır: ahşap duvar, kiremit çatı, saman balyası ve çit
  g.add(mesh(G.box, M.wood, 0, 0.15, -0.12, 0.6, 0.3, 0.4));
  g.add(roof(M.tile, 0, 0.3, -0.12, 0.68, 0.18, 0.48));
  for (let i = 0; i < 3; i++) g.add(mesh(G.box, M.woodDark, -0.18 + i * 0.18, 0.12, 0.085, 0.1, 0.18, 0.01));
  for (let i = 0; i < level; i++) g.add(mesh(G.cyl, M.hay, -0.26 + i * 0.13, 0.05, 0.26, 0.05, 0.08, 0.05));
  g.add(mesh(G.box, M.woodDark, 0.12, 0.07, 0.3, 0.4, 0.02, 0.02));
  for (let i = 0; i < 4; i++) g.add(mesh(G.box, M.woodDark, -0.06 + i * 0.12, 0.05, 0.3, 0.02, 0.1, 0.02));
  return { g };
}

function science(level) {
  const g = new THREE.Group();
  // rasathane: yuvarlak kule, kubbe, dürbün
  const h = 0.4 + level * 0.06;
  g.add(mesh(G.cyl, M.white, 0, h / 2, -0.05, 0.22, h, 0.22));
  g.add(mesh(G.cyl, M.stoneDark, 0, h, -0.05, 0.25, 0.04, 0.25));
  g.add(mesh(dome, M.lead, 0, h + 0.02, -0.05, 0.2, 0.18, 0.2));
  const scope = mesh(G.cyl, M.gold, 0.1, h + 0.18, 0.02, 0.025, 0.26, 0.025);
  scope.rotation.z = -0.8;
  g.add(scope);
  g.add(mesh(G.box, M.white, 0.25, 0.1, 0.15, 0.24, 0.2, 0.24));
  g.add(roof(M.tile, 0.25, 0.2, 0.15, 0.3, 0.12, 0.3));
  // küre (gök küresi)
  if (level >= 2) g.add(mesh(G.torus, M.gold, -0.26, 0.12, 0.22, 0.07, 0.07, 0.07));
  return { g };
}

function religion(level) {
  const g = new THREE.Group();
  // Meşihat: yeşil kubbeli ilim ve fetva binası
  g.add(mesh(G.box, M.white, 0, 0.17, -0.05, 0.6, 0.34, 0.5));
  domed(g, M.green, 0, 0.34, -0.05, 0.18 + level * 0.02);
  windows(g, 0, 0.2, 0.205, 0.46, 3);
  g.add(mesh(G.box, M.green, 0, 0.36, 0.2, 0.62, 0.03, 0.04));
  if (level >= 2) for (const s of [-1, 1]) domed(g, M.green, s * 0.22, 0.34, -0.05, 0.08);
  return { g };
}

function court(level) {
  const g = new THREE.Group();
  // Kadı mahkemesi: sütunlu giriş, koyu çatı
  g.add(mesh(G.box, M.stone, 0, 0.03, 0, 0.72, 0.06, 0.64));
  g.add(mesh(G.box, M.white, 0, 0.2, -0.1, 0.62, 0.32, 0.38));
  g.add(roof(M.leadDark, 0, 0.36, -0.06, 0.74, 0.2, 0.58));
  for (let i = 0; i < 4; i++) g.add(mesh(G.cyl, M.white, -0.24 + i * 0.16, 0.2, 0.17, 0.025, 0.3, 0.025));
  // terazi: altın
  g.add(mesh(G.box, M.gold, 0, 0.46, 0.18, 0.18, 0.015, 0.015));
  g.add(mesh(G.cyl, M.gold, 0, 0.42, 0.18, 0.01, 0.08, 0.01));
  for (const s of [-1, 1]) g.add(mesh(G.cyl, M.gold, s * 0.09, 0.43, 0.18, 0.03, 0.01, 0.03));
  if (level >= 2) windows(g, 0, 0.28, 0.085, 0.5, level + 1);
  return { g };
}

function mosque(level) {
  const g = new THREE.Group();
  // ana kubbe, yarım kubbeler, minareler (seviye 1/2/3 → 1/2/4)
  g.add(mesh(G.box, M.stone, 0, 0.03, 0, 0.84, 0.06, 0.84));
  g.add(mesh(G.box, M.white, 0, 0.17, -0.02, 0.5, 0.28, 0.5));
  domed(g, M.lead, 0, 0.31, -0.02, 0.24);
  for (const [x, z] of [[0, 0.25], [0, -0.29], [0.27, -0.02], [-0.27, -0.02]]) {
    g.add(mesh(dome, M.lead, x, 0.24, z, 0.12, 0.1, 0.12));
  }
  // son cemaat yeri: küçük kubbeler
  for (let i = -1; i <= 1; i++) g.add(mesh(dome, M.leadDark, i * 0.14, 0.18, 0.32, 0.06, 0.05, 0.06));
  const spots = [[0.36, 0.34], [-0.36, 0.34], [0.36, -0.36], [-0.36, -0.36]];
  for (let i = 0; i < CITY.minarets[level]; i++) minaret(g, spots[i][0], spots[i][1], 0.85);
  return { g };
}

const BUILD = { palace, school, barracks, archery, hospital, cavalry, science, religion, court, mosque };

// Boş arsa: taş temel, köşe kazıkları, tabela
function emptyLot() {
  const g = new THREE.Group();
  g.add(mesh(G.box, M.stoneDark, 0, 0.02, 0, 0.66, 0.04, 0.66));
  for (const [x, z] of [[-0.3, -0.3], [0.3, -0.3], [-0.3, 0.3], [0.3, 0.3]]) g.add(mesh(G.box, M.wood, x, 0.08, z, 0.03, 0.12, 0.03));
  g.add(mesh(G.box, M.wood, 0, 0.12, 0.18, 0.02, 0.22, 0.02));
  g.add(mesh(G.box, toonShared(0xd8b98a), 0, 0.22, 0.19, 0.2, 0.1, 0.02));
  return { g };
}

// Halk evleri: beyaz badana, kırmızı kiremit, çıkmalı üst kat
function house(rand) {
  const g = new THREE.Group();
  const w = 0.32 + rand() * 0.1;
  const d = 0.3 + rand() * 0.08;
  const h = 0.2 + rand() * 0.12;
  g.add(mesh(G.box, M.white, 0, h / 2, 0, w, h, d));
  g.add(mesh(G.box, rand() < 0.5 ? M.white : toonShared(0xf1dfc2), 0, h + 0.06, 0.03, w + 0.06, 0.12, d + 0.06));
  g.add(roof(M.tile, 0, h + 0.12, 0.03, w + 0.1, 0.26, d + 0.1));
  g.add(mesh(G.box, M.woodDark, 0, 0.07, d / 2 + 0.005, 0.07, 0.13, 0.01));
  return g;
}

function cypress(rand) {
  const g = new THREE.Group();
  const h = 0.45 + rand() * 0.2;
  g.add(mesh(G.cyl, M.woodDark, 0, 0.04, 0, 0.02, 0.08, 0.02));
  g.add(mesh(G.ball, M.cypress, 0, 0.08 + h / 2, 0, 0.07, h / 2, 0.07));
  return g;
}

function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

export function buildCity(scene, map) {
  const root = new THREE.Group();
  const toWorld = (c, r) => ({ x: c + 0.5 - map.cols / 2, z: r + 0.5 - map.rows / 2 });
  const rand = rng(map.seed + 7);

  // halk evleri ve servi ağaçları sabit karelerde
  const homes = [[0, 13], [2, 13], [3, 13], [6, 13], [8, 13], [1, 14], [2, 14], [6, 14], [7, 14], [0, 15], [8, 15]];
  for (const [c, r] of homes) {
    const p = toWorld(c, r);
    const n = 1 + Math.floor(rand() * 2);
    for (let i = 0; i < n; i++) {
      const h = house(rand);
      h.position.set(p.x + (n > 1 ? (i - 0.5) * 0.42 : (rand() - 0.5) * 0.2), 0, p.z + (rand() - 0.5) * 0.25);
      h.rotation.y = (rand() - 0.5) * 0.3;
      h.scale.setScalar(n > 1 ? 0.8 : 1);
      root.add(h);
    }
  }
  for (const [c, r] of [[3, 15], [4, 15], [5, 15]]) {
    const p = toWorld(c, r);
    for (let i = 0; i < 2; i++) {
      const t = cypress(rand);
      t.position.set(p.x + (i ? 0.25 : -0.25), 0, p.z + 0.1 + (rand() - 0.5) * 0.3);
      root.add(t);
    }
  }

  // Padişah: sarayın önünde
  const sultan = buildPerson({ tunic: 0xb3202a, trim: 0xe0b24a, pants: 0x7d141b, hat: 'sultan', beard: 0x3a2a1c, cape: 0xe0b24a });
  sultan.root.scale.setScalar(0.22);
  const sp = toWorld(...BUILDINGS.palace.slot);
  sultan.root.position.set(sp.x, 0.08, sp.z + 0.5);
  root.add(sultan.root);

  const slots = {};
  for (const id in BUILDINGS) {
    const p = toWorld(...BUILDINGS[id].slot);
    const holder = new THREE.Group();
    holder.position.set(p.x, 0, p.z);
    const ring = new THREE.Mesh(ringGeo, ringMat);
    ring.rotation.x = -Math.PI / 2;
    ring.position.y = 0.012;
    holder.add(ring);
    root.add(holder);
    slots[id] = { holder, ring, level: -1, model: null, flags: [] };
  }
  scene.add(root);
  return { root, slots, sultan };
}

export function updateCity(city, state, time) {
  for (const id in city.slots) {
    const s = city.slots[id];
    const level = state.buildings[id];
    if (level !== s.level) {
      if (s.model) s.holder.remove(s.model);
      const built = level > 0 ? BUILD[id](level) : emptyLot();
      s.model = built.g;
      s.flags = built.flags || [];
      // binalar seviyeyle biraz büyür (saray zaten geniş)
      if (level > 0 && id !== 'palace') s.model.scale.setScalar(0.88 + level * 0.07);
      s.holder.add(s.model);
      if (s.level >= 0 && level > s.level) s.pop = 1;
      s.level = level;
    }
    if (s.pop > 0) {
      s.pop = Math.max(0, s.pop - 0.04);
      s.model.position.y = Math.sin(s.pop * Math.PI) * 0.12;
    }
    s.flags.forEach((f, i) => (f.rotation.y = Math.sin(time * 2.6 + i + s.holder.position.x) * 0.35));
    const can = canUpgradeBuilding(state, id);
    s.ring.visible = can;
    if (can) s.ring.scale.setScalar(1 + 0.06 * Math.sin(time * 4));
  }
  // Padişah ağır ağır sağa sola bakar
  city.sultan.head.rotation.y = Math.sin(time * 0.7) * 0.5;
  city.sultan.arms[1].rotation.x = state.charge.active > 0 ? -2.6 : -0.2 + Math.sin(time * 0.9) * 0.1;
}
