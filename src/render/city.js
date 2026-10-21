import * as THREE from 'three';
import { BUILDINGS, CITY } from '../data/buildings.js';
import { canUpgradeBuilding } from '../systems/city.js';
import { paintShared, PALETTE, ottomanFlagTexture } from './palette.js';
import { G, mesh } from './figures.js';
import { prop, bakeStatic } from './models.js';
import { buildSoldier } from './soldiers.js';
import { flagMesh } from './flags.js';

// Surların içindeki şehir: saray, Padişah, kurulan binalar, boş arsalar, halk evleri ve servi ağaçları.
// Her binanın modeli kendi fonksiyonunda; seviye değişince model yeniden kurulur.

const M = {
  white: paintShared(PALETTE.whitewash),
  stone: paintShared(PALETTE.stone),
  stoneDark: paintShared(PALETTE.stoneDark),
  tile: paintShared(PALETTE.roofTile),
  lead: paintShared(PALETTE.lead),
  leadDark: paintShared(PALETTE.leadDark),
  wood: paintShared(PALETTE.wood),
  woodDark: paintShared(PALETTE.woodDark),
  gold: paintShared(PALETTE.gold),
  red: paintShared(PALETTE.ottomanRed),
  green: paintShared(0x2f7a4a),
  cypress: paintShared(0x2e6b34),
  window: paintShared(0x3b5f7a),
  hay: paintShared(0xd9b45a),
  target: paintShared(0xf4efe4),
};
const ringMat = new THREE.MeshBasicMaterial({
  color: 0xf2c94c, transparent: true, opacity: 0.32, depthWrite: false, blending: THREE.AdditiveBlending,
});
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
  const f = flagMesh(ottomanFlagTexture(), 0.22 * s, 0.14 * s);
  f.position.set(x + 0.01, y + 0.34 * s, z);
  g.add(f);
  return f;
}

// --- Binalar (yaklaşık 0.8 × 0.8 kare taban) ---

function palace(level) {
  const g = new THREE.Group();
  // KayKit kalesi: seviyeyle büyür; 3. seviyede iki yanında minare, kulelerde Osmanlı sancakları
  g.add(mesh(G.box, M.stone, 0, 0.03, 0, 1.6, 0.06, 0.9));
  const castle = prop('building_castle', 0.36 + level * 0.03);
  castle.rotation.y = Math.PI;
  g.add(castle);
  const top = (0.36 + level * 0.03) * 3.9;
  if (level >= 3) for (const s of [-1, 1]) minaret(g, s * 0.66, -0.25, 1.05);
  const flags = [flag(g, 0, top - 0.05, 0, 1.3)];
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
  // Yeniçeri ocağı: KayKit kışla, önünde silahlık ve ocağın sembolü kazan
  const b = prop('building_barracks', 0.5);
  b.rotation.y = Math.PI;
  b.position.z = -0.06;
  g.add(b);
  const rack = prop('weaponrack', 0.6);
  rack.position.set(-0.3, 0, 0.32);
  g.add(rack);
  g.add(mesh(G.taper, paintShared(0xb86b3a), 0.3, 0.06, 0.32, 0.07, 0.1, 0.07));
  const flags = [flag(g, 0.32, 0.8, -0.2, 1.1)];
  return { g, flags };
}

function archery(level) {
  const g = new THREE.Group();
  // okçu ocağı: KayKit atış meydanı, seviye başına bir nişan tahtası daha
  const b = prop('building_archeryrange', 0.45);
  b.rotation.y = Math.PI;
  g.add(b);
  for (let i = 1; i < level; i++) {
    const t = prop('target', 0.7);
    t.position.set(0.2 + i * 0.12, 0, 0.3);
    g.add(t);
  }
  return { g };
}

function hospital(level) {
  const g = new THREE.Group();
  // avlulu darüşşifa: U plan, ortada şadırvan
  g.add(mesh(G.box, M.white, 0, 0.15, -0.22, 0.7, 0.3, 0.22));
  for (const s of [-1, 1]) g.add(mesh(G.box, M.white, s * 0.26, 0.13, 0.05, 0.18, 0.26, 0.36));
  domed(g, M.green, 0, 0.3, -0.22, 0.13 + level * 0.02);
  g.add(mesh(G.cyl, paintShared(0x7fc8c0), 0, 0.04, 0.08, 0.1, 0.06, 0.1));
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

// Boş arsa: taş temel, köşe kazıkları, kereste ve taş yığını
function emptyLot() {
  const g = new THREE.Group();
  g.add(mesh(G.box, M.stoneDark, 0, 0.02, 0, 0.66, 0.04, 0.66));
  for (const [x, z] of [[-0.3, -0.3], [0.3, -0.3], [-0.3, 0.3], [0.3, 0.3]]) g.add(mesh(G.box, M.wood, x, 0.08, z, 0.03, 0.12, 0.03));
  const lumber = prop('resource_lumber', 0.45);
  lumber.position.set(-0.08, 0.04, -0.12);
  g.add(lumber);
  const stone = prop('resource_stone', 0.45);
  stone.position.set(0.14, 0.04, 0.14);
  g.add(stone);
  return { g };
}

// Halk evleri: KayKit evleri (beyaz badana, kırmızı kiremit, ahşap çatkı)
function house(rand) {
  const h = prop(rand() < 0.55 ? 'building_home_A' : 'building_home_B', 0.4 + rand() * 0.06);
  h.rotation.y = Math.PI + (rand() < 0.5 ? 0 : Math.PI / 2);
  return h;
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

  // halk evleri, çarşı, kuyu, demirci ve servi ağaçları sabit karelerde (tek ağa birleşir)
  const town = new THREE.Group();
  const chimneys = [];
  const homes = [[0, 13], [2, 13], [6, 13], [8, 13], [1, 14], [7, 14], [0, 15], [8, 15]];
  for (const [c, r] of homes) {
    const p = toWorld(c, r);
    const n = 1 + Math.floor(rand() * 2);
    for (let i = 0; i < n; i++) {
      const h = house(rand);
      h.position.set(p.x + (n > 1 ? (i - 0.5) * 0.44 : (rand() - 0.5) * 0.2), 0, p.z + (rand() - 0.5) * 0.25);
      h.rotation.y += (rand() - 0.5) * 0.3;
      h.scale.multiplyScalar(n > 1 ? 0.85 : 1.1);
      town.add(h);
      if (chimneys.length < 5 && rand() < 0.5) chimneys.push({ x: h.position.x, y: 0.5, z: h.position.z });
    }
  }
  for (const [name, c, r, sc, ry] of [
    ['building_well', 3, 13, 0.42, 0], ['building_market', 6, 14, 0.46, Math.PI], ['building_blacksmith', 2, 14, 0.42, Math.PI],
  ]) {
    const p = toWorld(c, r);
    const m = prop(name, sc);
    m.position.set(p.x, 0, p.z);
    m.rotation.y = ry;
    town.add(m);
  }
  for (const [c, r] of [[3, 15], [4, 15], [5, 15]]) {
    const p = toWorld(c, r);
    for (let i = 0; i < 2; i++) {
      const t = cypress(rand);
      t.position.set(p.x + (i ? 0.25 : -0.25), 0, p.z + 0.1 + (rand() - 0.5) * 0.3);
      town.add(t);
    }
  }
  root.add(bakeStatic(town));

  // Padişah: sarayın önünde
  const sultan = buildSoldier('sultan');
  sultan.root.scale.setScalar(0.2);
  const sp = toWorld(...BUILDINGS.palace.slot);
  sultan.root.position.set(sp.x, 0.06, sp.z + 0.5);
  sultan.play('Idle');
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
  return { root, slots, sultan, chimneys, last: null };
}

export function updateCity(city, state, time) {
  for (const id in city.slots) {
    const s = city.slots[id];
    const level = state.buildings[id];
    if (level !== s.level) {
      if (s.model) s.holder.remove(s.model);
      const built = level > 0 ? BUILD[id](level) : emptyLot();
      s.model = bakeStatic(built.g);
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
    const can = canUpgradeBuilding(state, id);
    s.ring.visible = can;
    if (can) s.ring.scale.setScalar(1 + 0.06 * Math.sin(time * 4));
  }
  // Padişah sarayın önünde bekler; hücumda askerlerini selamlar
  const dt = city.last === null ? 0 : Math.min(0.1, time - city.last);
  city.last = time;
  city.sultan.play(state.charge.active > 0 ? 'Cheer' : 'Idle', 1, 0.3);
  city.sultan.mixer.update(dt);
}
