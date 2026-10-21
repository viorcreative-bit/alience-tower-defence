import * as THREE from 'three';
import { BUILDINGS, CITY } from '../data/buildings.js';
import { canUpgradeBuilding } from '../systems/city.js';
import { paintShared, PALETTE, ottomanFlagTexture } from './palette.js';
import { G, mesh } from './figures.js';
import { prop, bakeStatic } from './models.js';
import { buildSoldier } from './soldiers.js';
import { flagMesh } from './flags.js';
import { TR } from '../i18n/tr.js';

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
  arch: paintShared(0x2c3a4a), // kemerli pencere ve kapı boşluğu
  iznik: paintShared(0x2f78b8), // İznik çinisi mavisi
  iznikLight: paintShared(0x7fc0e0),
  marble: paintShared(0xfbf7ee),
  hay: paintShared(0xd9b45a),
  water: paintShared(0x6cc4d6),
  dome: paintShared(0x8ea2b8), // kurşun kubbe, gökyüzünü yansıtan açık ton
  flower: paintShared(0xd8455a),
};
const ringMat = new THREE.MeshBasicMaterial({
  color: 0xf2c94c, transparent: true, opacity: 0.32, depthWrite: false, blending: THREE.AdditiveBlending,
});
const ringGeo = new THREE.RingGeometry(0.36, 0.46, 32);
const dome = new THREE.SphereGeometry(1, 20, 10, 0, Math.PI * 2, 0, Math.PI / 2);
const oct = new THREE.CylinderGeometry(1, 1, 1, 8);
// geniş saçaklı köşk çatısı: alçak dört yüzlü piramit
const hipRoof = new THREE.ConeGeometry(1, 1, 4, 1).rotateY(Math.PI / 4);

// Sivri Osmanlı kemeri (düz şekil, +z'ye bakar); genişlik 1, omuz yüksekliği 1
const archGeo = (() => {
  const sh = new THREE.Shape();
  sh.moveTo(-0.5, 0);
  sh.lineTo(-0.5, 1);
  sh.quadraticCurveTo(-0.5, 1.45, 0, 1.65);
  sh.quadraticCurveTo(0.5, 1.45, 0.5, 1);
  sh.lineTo(0.5, 0);
  sh.lineTo(-0.5, 0);
  return new THREE.ShapeGeometry(sh, 4);
})();

// Beşik çatı: üçgen prizma, mahyası x yönünde; iki yüzü farklı aydınlanır
const gable = new THREE.CylinderGeometry(1, 1, 1, 3);
function roof(mat, x, y, z, w, h, d) {
  const sz = h / 1.5;
  const r = mesh(gable, mat, x, y + sz * 0.5, z, d / 1.732, w, sz);
  r.rotation.set(-Math.PI / 2, 0, Math.PI / 2);
  return r;
}

// Duvar yüzüne (z) n adet kemerli pencere; ry ile yan yüzlere de döndürülebilir
function arches(g, x, y, z, w, n, h = 0.1, mat = M.arch, ry = 0) {
  const aw = Math.min(h * 0.62, (w / n) * 0.62);
  for (let i = 0; i < n; i++) {
    const t = -w / 2 + ((i + 0.5) * w) / n;
    const a = new THREE.Mesh(archGeo, mat);
    a.position.set(x + Math.cos(ry) * t, y, z - Math.sin(ry) * t);
    a.rotation.y = ry;
    a.scale.set(aw, h / 1.65, 1);
    g.add(a);
  }
}

// Kemer altlarında İznik çinisi şeridi
function tileBand(g, x, y, z, w, d = 0.012) {
  g.add(mesh(G.box, M.iznik, x, y, z, w, 0.025, d));
}

function windows(g, x, y, z, w, n) {
  arches(g, x, y - 0.06, z, w, n, 0.1);
}

function alem(g, x, y, z, s = 1) {
  g.add(mesh(G.cyl, M.gold, x, y + 0.05 * s, z, 0.012 * s, 0.1 * s, 0.012 * s));
  g.add(mesh(G.ball, M.gold, x, y + 0.1 * s, z, 0.025 * s));
}

// Sekizgen kasnak üstünde kubbe ve alem
function domed(g, mat, x, y, z, r, drum = 0.04) {
  g.add(mesh(oct, M.white, x, y + drum / 2, z, r * 1.04, drum, r * 1.04));
  g.add(mesh(G.cyl, M.stoneDark, x, y + drum, z, r * 1.08, 0.015, r * 1.08));
  g.add(mesh(dome, mat === M.lead ? M.dome : mat, x, y + drum, z, r, r * 0.85, r));
  alem(g, x, y + drum + r * 0.85, z, Math.max(0.8, r * 4));
}

function minaret(g, x, z, h, balconies = 1) {
  g.add(mesh(G.cyl, M.stoneDark, x, 0.05, z, 0.065, 0.1, 0.065));
  g.add(mesh(G.cyl, M.white, x, h / 2, z, 0.045, h, 0.045));
  for (let i = 0; i < balconies; i++) {
    const y = h * (0.62 + i * 0.18);
    g.add(mesh(G.cyl, M.stoneDark, x, y, z, 0.07, 0.03, 0.07)); // şerefe
    g.add(mesh(G.cyl, M.iznik, x, y - 0.04, z, 0.047, 0.03, 0.047));
  }
  g.add(mesh(G.cone, M.lead, x, h + 0.09, z, 0.05, 0.2, 0.05));
  alem(g, x, h + 0.18, z, 0.8);
}

function flag(g, x, y, z, s = 1) {
  g.add(mesh(G.cyl, M.woodDark, x, y + 0.2 * s, z, 0.01, 0.4 * s, 0.01));
  g.add(mesh(G.ball, M.gold, x, y + 0.41 * s, z, 0.018 * s));
  const f = flagMesh(ottomanFlagTexture(), 0.22 * s, 0.14 * s);
  f.position.set(x + 0.01, y + 0.34 * s, z);
  g.add(f);
  return f;
}

// Taş kaide: her binanın altında, önünde seviye kadar altın düğme
function plinth(g, w, d, level, h = 0.05) {
  g.add(mesh(G.box, M.stoneDark, 0, h / 2, 0, w, h, d));
  g.add(mesh(G.box, M.stone, 0, h + 0.006, 0, w - 0.04, 0.012, d - 0.04));
  for (let i = 0; i < level; i++) g.add(mesh(G.ball, M.gold, (i - (level - 1) / 2) * 0.07, h * 0.55, d / 2 + 0.004, 0.022));
}

// Köşk: badanalı gövde, kemerli pencereler, çini şerit, geniş saçaklı kurşun çatı
function kosk(g, x, z, w, d, h, level = 1) {
  g.add(mesh(G.box, M.white, x, 0.05 + h / 2, z, w, h, d));
  arches(g, x, 0.09, z + d / 2 + 0.002, w * 0.86, Math.max(2, Math.round(w / 0.13)), h * 0.5);
  if (level >= 2) tileBand(g, x, 0.05 + h * 0.86, z + d / 2 + 0.004, w * 0.96);
  // saçak ve çatı
  g.add(mesh(G.box, M.woodDark, x, 0.05 + h + 0.012, z, w + 0.1, 0.025, d + 0.1));
  g.add(mesh(hipRoof, M.lead, x, 0.05 + h + 0.025 + 0.09, z, (w + 0.12) * 0.72, 0.18, (d + 0.12) * 0.72));
  alem(g, x, 0.05 + h + 0.2, z, 0.9);
}

// Revak: sütunlar ve üstünde kemer sırası, kurşun saçak
function portico(g, x, z, w, n, h) {
  for (let i = 0; i <= n; i++) {
    const cx = x - w / 2 + (i * w) / n;
    g.add(mesh(G.cyl, M.marble, cx, 0.05 + h / 2, z, 0.018, h, 0.018));
    g.add(mesh(G.box, M.gold, cx, 0.05 + h, z, 0.04, 0.015, 0.04));
  }
  g.add(mesh(G.box, M.white, x, 0.05 + h + 0.03, z, w + 0.04, 0.05, 0.05));
  arches(g, x, 0.05 + h * 0.55, z - 0.03, w, n, h * 0.42, M.arch);
  g.add(mesh(G.box, M.leadDark, x, 0.05 + h + 0.065, z - 0.04, w + 0.12, 0.02, 0.16));
}

// Yuvarlak/sekizgen kule, sivri kurşun külah (Bâbüsselâm ve Adalet Kulesi gibi)
function spire(g, x, z, r, h, cone = r * 3) {
  g.add(mesh(oct, M.stone, x, h / 2, z, r, h, r));
  g.add(mesh(oct, M.white, x, h - 0.05, z, r * 1.02, 0.1, r * 1.02));
  arches(g, x, h - 0.09, z + r * 0.93, r * 1.1, 2, 0.07);
  g.add(mesh(G.cyl, M.woodDark, x, h + 0.005, z, r * 1.25, 0.02, r * 1.25));
  g.add(mesh(G.cone, M.lead, x, h + cone / 2, z, r * 1.15, cone, r * 1.15));
  alem(g, x, h + cone, z, 1.1);
}

// --- Binalar (yaklaşık 0.8 × 0.8 kare taban; saray üç kare geniş) ---

function palace(level) {
  const g = new THREE.Group();
  const flags = [];
  // Topkapı esinli saray: mermer avlu, Divan kubbesi, revak; seviyeyle köşkler, Bâbüsselâm kuleleri ve Adalet Kulesi
  plinth(g, 2.3, 0.95, level, 0.06);
  g.add(mesh(G.box, M.marble, 0, 0.07, 0.25, 0.8, 0.01, 0.36)); // avlu
  g.add(mesh(G.cyl, M.water, 0, 0.08, 0.28, 0.09, 0.02, 0.09)); // havuz
  g.add(mesh(G.cyl, M.marble, 0, 0.11, 0.28, 0.02, 0.06, 0.02));
  // Divan-ı Hümayun: kubbeli ana salon
  g.add(mesh(G.box, M.white, 0, 0.06 + 0.25, -0.17, 0.84, 0.5, 0.44));
  arches(g, 0, 0.1, 0.052, 0.7, 5, 0.22);
  tileBand(g, 0, 0.5, 0.054, 0.82);
  g.add(mesh(G.box, M.gold, 0, 0.555, 0.054, 0.84, 0.018, 0.014));
  domed(g, M.lead, 0, 0.56, -0.17, 0.26, 0.1);
  for (const s of [-1, 1]) domed(g, M.lead, s * 0.31, 0.56, -0.17, 0.1, 0.04);
  portico(g, 0, 0.1, 0.84, 5, 0.26);
  // bahçeler: çiçek tarhları ve servi ağaçları, yanlarda alçak revaklı duvar
  for (const sx of [-1, 1]) {
    g.add(mesh(G.box, M.green, sx * 0.62, 0.075, 0.27, 0.36, 0.02, 0.3));
    for (let i = 0; i < 3; i++) g.add(mesh(G.ball, M.flower, sx * (0.5 + i * 0.12), 0.095, 0.36, 0.03));
    for (const dz of [0.17, 0.32]) {
      g.add(mesh(G.ball, M.green, sx * 0.98, 0.25, dz, 0.05, 0.18, 0.05));
    }
    if (level < 2) {
      g.add(mesh(G.box, M.white, sx * 0.72, 0.06 + 0.1, -0.2, 0.56, 0.2, 0.16));
      arches(g, sx * 0.72, 0.08, -0.118, 0.5, 4, 0.1);
      g.add(mesh(G.box, M.leadDark, sx * 0.72, 0.27, -0.2, 0.6, 0.02, 0.22));
    }
  }
  // altın kapı
  const door = new THREE.Mesh(archGeo, M.gold);
  door.position.set(0, 0.06, 0.06);
  door.scale.set(0.12, 0.1, 1);
  g.add(door);
  flags.push(flag(g, 0, 0.78, -0.17, 1.3));
  if (level >= 2) {
    // yan köşkler ve onları bağlayan revaklı galeriler
    for (const s of [-1, 1]) {
      kosk(g, s * 0.82, -0.12, 0.52, 0.5, 0.42, level);
      g.add(mesh(G.box, M.white, s * 0.48, 0.06 + 0.11, -0.2, 0.2, 0.22, 0.3));
      arches(g, s * 0.48, 0.08, -0.048, 0.16, 2, 0.1);
      g.add(mesh(G.box, M.leadDark, s * 0.48, 0.29, -0.2, 0.24, 0.02, 0.34));
    }
  }
  if (level >= 3) {
    // Adalet Kulesi ve Bâbüsselâm'ın ikiz külahlı kuleleri, altın süslü sancaklar
    spire(g, 0.4, -0.36, 0.1, 1.2, 0.36);
    flags.push(flag(g, 0.4, 1.58, -0.36, 1.2));
    for (const s of [-1, 1]) {
      spire(g, s * 1.02, 0.32, 0.08, 0.5, 0.28);
      flags.push(flag(g, s * 0.82, 0.72, -0.12, 1));
    }
    for (const s of [-1, 1]) g.add(mesh(G.box, M.gold, s * 0.82, 0.49, 0.135, 0.52, 0.015, 0.012));
  }
  return { g, flags };
}

function school(level) {
  const g = new THREE.Group();
  // Mektep: kubbeli sınıf, revaklı avlu (seviye başına bir göz), çini şerit
  plinth(g, 0.78, 0.78, level);
  g.add(mesh(G.box, M.white, 0, 0.05 + 0.16, -0.08, 0.6, 0.32, 0.44));
  arches(g, 0, 0.1, 0.143, 0.48, 3, 0.13);
  if (level >= 2) tileBand(g, 0, 0.32, 0.145, 0.58);
  domed(g, M.lead, 0, 0.37, -0.08, 0.18, 0.05);
  if (level >= 3) for (const s of [-1, 1]) domed(g, M.lead, s * 0.2, 0.37, -0.08, 0.07, 0.02);
  portico(g, -0.3 + (level + 1) * 0.08, 0.26, (level + 1) * 0.16, level + 1, 0.16);
  // yazı tahtası ve kitaplar (altın ciltler)
  g.add(mesh(G.box, M.woodDark, 0.27, 0.12, 0.27, 0.12, 0.12, 0.02));
  return { g };
}

function barracks(level) {
  const g = new THREE.Group();
  // Yeniçeri ocağı: KayKit kışla, önünde silahlık ve ocağın sembolü kazan; seviyeyle çadır ve ikinci silahlık
  plinth(g, 0.86, 0.86, level);
  const b = prop('building_barracks', 0.5);
  b.rotation.y = Math.PI;
  b.position.set(0, 0.05, -0.06);
  g.add(b);
  const rack = prop('weaponrack', 0.6);
  rack.position.set(-0.3, 0.05, 0.32);
  g.add(rack);
  // kazan: Yeniçerinin sembolü
  g.add(mesh(G.taper, paintShared(0xb86b3a), 0.3, 0.11, 0.32, 0.07, 0.1, 0.07));
  const rim = mesh(G.torus, M.gold, 0.3, 0.16, 0.32, 0.07, 0.07, 0.07);
  rim.rotation.x = Math.PI / 2;
  g.add(rim);
  if (level >= 2) {
    const r2 = prop('weaponrack', 0.6);
    r2.position.set(-0.12, 0.05, 0.34);
    g.add(r2);
  }
  if (level >= 3) spire(g, -0.34, -0.3, 0.06, 0.5, 0.18);
  const flags = [flag(g, 0.32, 0.85, -0.2, 1.1)];
  return { g, flags };
}

function archery(level) {
  const g = new THREE.Group();
  // okçu ocağı: KayKit atış meydanı, seviye başına bir nişan tahtası daha; 3. seviyede gözetleme köşkü
  plinth(g, 0.86, 0.86, level);
  const b = prop('building_archeryrange', 0.45);
  b.rotation.y = Math.PI;
  b.position.y = 0.05;
  g.add(b);
  for (let i = 1; i < level; i++) {
    const t = prop('target', 0.7);
    t.position.set(0.2 + i * 0.12, 0.05, 0.3);
    g.add(t);
  }
  const arrows = prop('bucket_arrows', 0.7);
  arrows.position.set(-0.3, 0.05, 0.32);
  g.add(arrows);
  const flags = level >= 3 ? [flag(g, -0.32, 0.4, -0.3, 1)] : [];
  return { g, flags };
}

function hospital(level) {
  const g = new THREE.Group();
  // avlulu darüşşifa: U plan, revaklı kanatlar, ortada şadırvan, yeşil kubbe
  plinth(g, 0.84, 0.84, level);
  g.add(mesh(G.box, M.white, 0, 0.05 + 0.15, -0.22, 0.72, 0.3, 0.24));
  arches(g, 0, 0.09, -0.098, 0.6, 4, 0.14);
  for (const s of [-1, 1]) {
    g.add(mesh(G.box, M.white, s * 0.27, 0.05 + 0.12, 0.07, 0.18, 0.24, 0.36));
    arches(g, s * 0.18 - s * 0.002, 0.08, 0.07, 0.3, 3, 0.1, M.arch, s * Math.PI / 2 * -1);
  }
  if (level >= 2) tileBand(g, 0, 0.3, -0.097, 0.7);
  domed(g, M.green, 0, 0.35, -0.22, 0.13 + level * 0.02, 0.04);
  // şadırvan
  g.add(mesh(oct, M.marble, 0, 0.08, 0.1, 0.11, 0.05, 0.11));
  g.add(mesh(G.cyl, M.water, 0, 0.105, 0.1, 0.09, 0.01, 0.09));
  g.add(mesh(G.cyl, M.marble, 0, 0.14, 0.1, 0.02, 0.07, 0.02));
  if (level >= 2) for (const s of [-1, 1]) domed(g, M.lead, s * 0.27, 0.29, 0.07, 0.07, 0.02);
  if (level >= 3) g.add(mesh(G.box, M.gold, 0, 0.36, -0.096, 0.72, 0.012, 0.01));
  return { g };
}

function cavalry(level) {
  const g = new THREE.Group();
  // Sipahi ahırı: taş alt kat, ahşap üst, kiremit çatı, kemerli ahır kapıları, saman ve çit
  plinth(g, 0.84, 0.84, level);
  g.add(mesh(G.box, M.stone, 0, 0.05 + 0.08, -0.12, 0.62, 0.16, 0.42));
  g.add(mesh(G.box, M.wood, 0, 0.05 + 0.23, -0.12, 0.62, 0.14, 0.42));
  g.add(roof(M.tile, 0, 0.35, -0.12, 0.7, 0.2, 0.5));
  arches(g, 0, 0.06, 0.092, 0.54, 3, 0.1, M.woodDark);
  for (let i = 0; i < level; i++) g.add(mesh(G.cyl, M.hay, -0.26 + i * 0.13, 0.1, 0.26, 0.05, 0.08, 0.05));
  g.add(mesh(G.box, M.woodDark, 0.12, 0.12, 0.3, 0.4, 0.02, 0.02));
  for (let i = 0; i < 4; i++) g.add(mesh(G.box, M.woodDark, -0.06 + i * 0.12, 0.1, 0.3, 0.02, 0.1, 0.02));
  const flags = level >= 2 ? [flag(g, 0.3, 0.38, -0.12, 0.9)] : [];
  return { g, flags };
}

function science(level) {
  const g = new THREE.Group();
  // rasathane: sekizgen kule, kubbe, dürbün; yanında kütüphane
  plinth(g, 0.8, 0.8, level);
  const h = 0.4 + level * 0.06;
  g.add(mesh(oct, M.white, 0, 0.05 + h / 2, -0.05, 0.22, h, 0.22));
  arches(g, 0, 0.05 + h * 0.45, 0.155, 0.16, 2, 0.1);
  if (level >= 2) tileBand(g, 0, 0.05 + h * 0.85, 0.16, 0.2);
  g.add(mesh(oct, M.stoneDark, 0, 0.05 + h, -0.05, 0.25, 0.04, 0.25));
  g.add(mesh(dome, M.lead, 0, 0.05 + h + 0.02, -0.05, 0.2, 0.18, 0.2));
  const scope = mesh(G.cyl, M.gold, 0.1, 0.05 + h + 0.18, 0.02, 0.025, 0.26, 0.025);
  scope.rotation.z = -0.8;
  g.add(scope);
  kosk(g, 0.26, 0.17, 0.24, 0.24, 0.18, level);
  // gök küresi
  if (level >= 2) g.add(mesh(G.torus, M.gold, -0.26, 0.17, 0.22, 0.07, 0.07, 0.07));
  if (level >= 3) g.add(mesh(G.ball, M.iznikLight, -0.26, 0.17, 0.22, 0.04));
  return { g };
}

function religion(level) {
  const g = new THREE.Group();
  // Meşihat: yeşil kubbeli ilim ve fetva binası, revaklı giriş
  plinth(g, 0.8, 0.8, level);
  g.add(mesh(G.box, M.white, 0, 0.05 + 0.17, -0.08, 0.6, 0.34, 0.44));
  windows(g, 0, 0.26, 0.143, 0.48, 3);
  tileBand(g, 0, 0.33, 0.145, 0.58);
  domed(g, M.green, 0, 0.39, -0.08, 0.17 + level * 0.02, 0.05);
  portico(g, 0, 0.24, 0.5, 3, 0.16);
  if (level >= 2) for (const s of [-1, 1]) domed(g, M.green, s * 0.22, 0.39, -0.08, 0.07, 0.02);
  if (level >= 3) g.add(mesh(G.box, M.gold, 0, 0.36, 0.146, 0.6, 0.012, 0.01));
  return { g };
}

function court(level) {
  const g = new THREE.Group();
  // Kadı mahkemesi: sütunlu giriş, koyu çatı, altın terazi
  plinth(g, 0.78, 0.7, level);
  g.add(mesh(G.box, M.white, 0, 0.05 + 0.16, -0.1, 0.62, 0.32, 0.38));
  arches(g, 0, 0.1, 0.092, 0.5, level + 2, 0.12);
  if (level >= 2) tileBand(g, 0, 0.32, 0.094, 0.6);
  g.add(roof(M.tile, 0, 0.37, -0.06, 0.76, 0.2, 0.6));
  for (let i = 0; i < 4; i++) g.add(mesh(G.cyl, M.marble, -0.24 + i * 0.16, 0.2, 0.17, 0.025, 0.3, 0.025));
  g.add(mesh(G.box, M.gold, 0, 0.47, 0.18, 0.18, 0.015, 0.015));
  g.add(mesh(G.cyl, M.gold, 0, 0.43, 0.18, 0.01, 0.08, 0.01));
  for (const s of [-1, 1]) g.add(mesh(G.cyl, M.gold, s * 0.09, 0.44, 0.18, 0.03, 0.01, 0.03));
  return { g };
}

function mosque(level) {
  const g = new THREE.Group();
  // selatin camisi: kasnaklı ana kubbe, dört yarım kubbe, son cemaat yeri, minareler (seviye 1/2/3 → 1/2/4)
  plinth(g, 0.88, 0.88, level);
  g.add(mesh(G.box, M.white, 0, 0.05 + 0.14, -0.02, 0.5, 0.28, 0.5));
  arches(g, 0, 0.1, 0.232, 0.4, 3, 0.12);
  for (const s of [-1, 1]) arches(g, s * 0.252, 0.1, -0.02, 0.4, 3, 0.12, M.arch, s * Math.PI / 2);
  tileBand(g, 0, 0.3, 0.234, 0.48);
  domed(g, M.lead, 0, 0.33, -0.02, 0.24, 0.07);
  for (const [x, z] of [[0, 0.24], [0, -0.28], [0.26, -0.02], [-0.26, -0.02]]) {
    g.add(mesh(dome, M.lead, x, 0.33, z, 0.12, 0.1, 0.12));
  }
  // son cemaat yeri: revak ve küçük kubbeler
  portico(g, 0, 0.36, 0.42, 3, 0.13);
  for (let i = -1; i <= 1; i++) g.add(mesh(dome, M.leadDark, i * 0.14, 0.25, 0.32, 0.06, 0.05, 0.06));
  const spots = [[0.37, 0.36], [-0.37, 0.36], [0.37, -0.37], [-0.37, -0.37]];
  for (let i = 0; i < CITY.minarets[level]; i++) minaret(g, spots[i][0], spots[i][1], 0.85 + level * 0.05, level >= 3 && i < 2 ? 2 : 1);
  return { g };
}

const BUILD = { palace, school, barracks, archery, hospital, cavalry, science, religion, court, mosque };

// Boş arsa: belirgin taş temel, altın çerçeve, köşe kazıkları, kereste ve taş yığını
function emptyLot() {
  const g = new THREE.Group();
  g.add(mesh(G.box, M.stoneDark, 0, 0.02, 0, 0.74, 0.04, 0.74));
  g.add(mesh(G.box, M.stone, 0, 0.045, 0, 0.66, 0.01, 0.66));
  for (const [x, z] of [[-0.33, -0.33], [0.33, -0.33], [-0.33, 0.33], [0.33, 0.33]]) {
    g.add(mesh(G.box, M.wood, x, 0.1, z, 0.03, 0.16, 0.03));
    g.add(mesh(G.box, M.red, x, 0.17, z, 0.035, 0.03, 0.035));
  }
  // kazıklar arası ip
  for (const [x, z, w, d] of [[0, -0.33, 0.66, 0.008], [0, 0.33, 0.66, 0.008], [-0.33, 0, 0.008, 0.66], [0.33, 0, 0.008, 0.66]]) {
    g.add(mesh(G.box, M.hay, x, 0.14, z, w, 0.008, d));
  }
  const lumber = prop('resource_lumber', 0.4);
  lumber.position.set(-0.16, 0.05, -0.16);
  g.add(lumber);
  const stone = prop('resource_stone', 0.4);
  stone.position.set(0.18, 0.05, -0.14);
  g.add(stone);
  return { g };
}

// Arsa işareti: boş arsada "+" ve bina adı, kurulu binada yükseltilebiliyorsa "▲"
const markerCache = new Map();
function markerTexture(kind, label, on) {
  const key = `${kind}|${label}|${on}`;
  if (markerCache.has(key)) return markerCache.get(key);
  const cv = document.createElement('canvas');
  cv.width = 256;
  cv.height = 192;
  const c = cv.getContext('2d');
  const cx = 128;
  const cy = 64;
  c.beginPath();
  c.arc(cx, cy, 50, 0, Math.PI * 2);
  c.fillStyle = on ? 'rgba(179,32,42,0.95)' : 'rgba(60,48,40,0.9)';
  c.fill();
  c.lineWidth = 8;
  c.strokeStyle = on ? '#f2c94c' : '#9c8b73';
  c.stroke();
  c.fillStyle = on ? '#fff4d6' : '#cbbca2';
  if (kind === 'plus') {
    c.fillRect(cx - 26, cy - 7, 52, 14);
    c.fillRect(cx - 7, cy - 26, 14, 52);
  } else {
    c.beginPath();
    c.moveTo(cx, cy - 28);
    c.lineTo(cx + 26, cy + 14);
    c.lineTo(cx - 26, cy + 14);
    c.closePath();
    c.fill();
  }
  if (label) {
    c.font = "700 46px 'Barlow Semi Condensed', sans-serif";
    c.textAlign = 'center';
    c.textBaseline = 'middle';
    c.lineWidth = 8;
    c.strokeStyle = 'rgba(20,12,8,0.85)';
    c.strokeText(label, cx, 154);
    c.fillStyle = on ? '#f3e6c8' : '#b9a383';
    c.fillText(label, cx, 154);
  }
  const t = new THREE.CanvasTexture(cv);
  t.colorSpace = THREE.SRGBColorSpace;
  markerCache.set(key, t);
  return t;
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
  const names = Object.fromEntries(Object.keys(BUILDINGS).map((id) => [id, TR.buildings[id].name]));
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
    const marker = new THREE.Sprite(new THREE.SpriteMaterial({ depthTest: false, transparent: true }));
    marker.renderOrder = 10;
    marker.center.set(0.5, 0.25);
    holder.add(marker);
    root.add(holder);
    slots[id] = { holder, ring, marker, markerKey: '', level: -1, model: null };
  }
  scene.add(root);
  return { root, slots, sultan, chimneys, names, merged: null, dirty: false, last: null };
}

// Arsadaki model; binalar seviyeyle biraz büyür (saray zaten geniş)
function buildSlot(id, level) {
  const g = level > 0 ? BUILD[id](level).g : emptyLot().g;
  if (level > 0 && id !== 'palace') g.scale.setScalar(0.96 + level * 0.08);
  const wrap = new THREE.Group();
  wrap.add(g);
  return wrap;
}

// Seviyeler oturunca tüm şehir binaları malzeme başına tek ağa birleşir (telefonda az çizim çağrısı).
// Bir bina değişince birleşik ağ kalkar, tek tek modeller görünür; zıplama bitince yeniden birleşir.
function merge(city) {
  const g = new THREE.Group();
  for (const id in city.slots) {
    const sl = city.slots[id];
    const m = buildSlot(id, sl.level);
    m.position.copy(sl.holder.position);
    g.add(m);
    sl.model.visible = false;
  }
  city.merged = bakeStatic(g);
  city.root.add(city.merged);
  city.dirty = false;
}

function disposeBaked(g) {
  g.traverse((o) => o.userData.baked && o.geometry.dispose());
}

function unmerge(city) {
  if (city.merged) {
    city.root.remove(city.merged);
    disposeBaked(city.merged);
    city.merged = null;
  }
  for (const id in city.slots) if (city.slots[id].model) city.slots[id].model.visible = true;
  city.dirty = true;
}

export function updateCity(city, state, time) {
  for (const id in city.slots) {
    const s = city.slots[id];
    const level = state.buildings[id];
    if (level !== s.level) {
      if (s.model) {
        s.holder.remove(s.model);
        disposeBaked(s.model);
      }
      s.model = bakeStatic(buildSlot(id, level));
      s.holder.add(s.model);
      if (s.level >= 0 && level > s.level) s.pop = 1;
      s.level = level;
      unmerge(city);
    }
    if (s.pop > 0) {
      s.pop = Math.max(0, s.pop - 0.04);
      s.model.position.y = Math.sin(s.pop * Math.PI) * 0.12;
    }
    const can = canUpgradeBuilding(state, id);
    s.ring.visible = can;
    if (can) s.ring.scale.setScalar(1 + 0.06 * Math.sin(time * 4));
    // boş arsa her zaman işaretli (kurulabiliyorsa parlak); kurulu bina yalnız yükseltilebiliyorsa
    const kind = level === 0 ? 'plus' : can ? 'up' : '';
    const key = `${kind}|${can}`;
    if (key !== s.markerKey) {
      s.markerKey = key;
      s.marker.visible = !!kind;
      if (kind) {
        s.marker.material.map = markerTexture(kind, kind === 'plus' ? city.names[id] : '', can);
        s.marker.material.needsUpdate = true;
        const k = kind === 'plus' ? 0.85 : 0.34;
        s.marker.scale.set(k, k * 0.75, 1);
      }
    }
    if (s.marker.visible) {
      const top = s.level > 0 ? (id === 'palace' ? 1.9 : 1.05) : 0.3;
      s.marker.position.y = top + (can ? 0.04 * Math.sin(time * 3 + s.holder.position.x) : 0);
    }
  }
  if (city.dirty && Object.values(city.slots).every((sl) => !(sl.pop > 0))) merge(city);
  // Padişah sarayın önünde bekler; hücumda askerlerini selamlar
  const dt = city.last === null ? 0 : Math.min(0.1, time - city.last);
  city.last = time;
  city.sultan.play(state.charge.active > 0 ? 'Cheer' : 'Idle', 1, 0.3);
  city.sultan.mixer.update(dt);
}
