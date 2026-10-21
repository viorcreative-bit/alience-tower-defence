import * as THREE from 'three';
import { createBackground, createGrassTile } from './background.js';
import { PALETTE, toon, toonShared, noOutline, ottomanFlagTexture, nationFlagTexture } from './palette.js';
import { NATIONS } from '../data/nations.js';

// Zemin, süsler, düşman ordugâhı ve surlar. Dünya birimi = 1 kare;
// mantıktaki (x, y) → dünyada (x - cols/2, y - rows/2). Zemin düz, y = 0.
export const GROUND_H = 0;
const TEX_TILE = 64;

function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

// Çevre çimi tahtadaki çimle aynı çizimden gelir; UV 10 birimde 1, doku 6 karede bir tekrar eder.
function groundTexture(seed) {
  const t = new THREE.CanvasTexture(createGrassTile(6, TEX_TILE / 2, seed));
  t.colorSpace = THREE.SRGBColorSpace;
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.repeat.set(10 / 6, 10 / 6);
  return t;
}

function buildGround(map, path, rand) {
  const group = new THREE.Group();
  const tex = new THREE.CanvasTexture(createBackground(map, path, TEX_TILE, 1));
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 4;
  const board = new THREE.Mesh(new THREE.PlaneGeometry(map.cols, map.rows), noOutline(new THREE.MeshLambertMaterial({ map: tex })));
  board.rotation.x = -Math.PI / 2;
  board.receiveShadow = true;
  group.add(board);

  // tahtanın dışı: aynı renkte geniş çimen
  const shape = new THREE.Shape();
  shape.moveTo(-40, -40);
  shape.lineTo(40, -40);
  shape.lineTo(40, 40);
  shape.lineTo(-40, 40);
  shape.closePath();
  const hole = new THREE.Path();
  hole.moveTo(-map.cols / 2, -map.rows / 2);
  hole.lineTo(-map.cols / 2, map.rows / 2);
  hole.lineTo(map.cols / 2, map.rows / 2);
  hole.lineTo(map.cols / 2, -map.rows / 2);
  hole.closePath();
  shape.holes.push(hole);
  const geo = new THREE.ShapeGeometry(shape);
  const uv = geo.attributes.uv;
  for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) / 10, uv.getY(i) / 10);
  const plain = new THREE.Mesh(geo, noOutline(new THREE.MeshLambertMaterial({ map: groundTexture(map.seed + 1) })));
  plain.rotation.x = -Math.PI / 2;
  plain.position.y = -0.002;
  plain.receiveShadow = true;
  group.add(plain);
  return group;
}

// Çizgi film çalısı: birkaç top bir arada
const bushGeo = new THREE.IcosahedronGeometry(1, 1);
const bushMats = [toon(PALETTE.bushA), toon(PALETTE.bushB), toon(PALETTE.bushDark)];
function bush(rand, size) {
  const g = new THREE.Group();
  const n = 3 + Math.floor(rand() * 3);
  for (let i = 0; i < n; i++) {
    const s = size * (0.45 + rand() * 0.4);
    const m = new THREE.Mesh(bushGeo, bushMats[Math.floor(rand() * 3)]);
    const a = rand() * Math.PI * 2;
    m.position.set(Math.cos(a) * size * 0.45, s * 0.75, Math.sin(a) * size * 0.45);
    m.scale.set(s, s * 0.9, s);
    m.castShadow = true;
    g.add(m);
  }
  return g;
}

const rockGeo = new THREE.DodecahedronGeometry(1, 1);
const rockMats = [toon(PALETTE.rock), toon(PALETTE.rockDark)];
function rocks(rand, size) {
  const g = new THREE.Group();
  const n = 2 + Math.floor(rand() * 4);
  for (let i = 0; i < n; i++) {
    const s = size * (0.3 + rand() * 0.5);
    const m = new THREE.Mesh(rockGeo, rockMats[Math.floor(rand() * 2)]);
    m.position.set((rand() - 0.5) * size * 1.6, s * 0.35, (rand() - 0.5) * size * 1.2);
    m.scale.set(s, s * 0.6, s * 0.85);
    m.rotation.y = rand() * 3;
    m.castShadow = true;
    g.add(m);
  }
  return g;
}

function buildDecor(map, path, rand) {
  const group = new THREE.Group();
  const W = map.cols / 2;
  const D = map.rows / 2;
  // tahtanın kenarı boyunca çalılar ve kayalar
  for (let i = 0; i < 50; i++) {
    const side = rand() < 0.5 ? -1 : 1;
    const x = side * (W + 0.35 + rand() * 3);
    const z = -D - 2 + rand() * (2 * D + 4);
    const d = rand() < 0.7 ? bush(rand, 0.25 + rand() * 0.25) : rocks(rand, 0.2 + rand() * 0.2);
    d.position.set(x, 0, z);
    group.add(d);
  }
  for (let i = 0; i < 10; i++) {
    const x = -W + rand() * 2 * W;
    if (Math.abs(x + W - 1.5) < 1.6) continue; // ordugâhın önü boş
    const z = -D - 0.6 - rand() * 2.5;
    const d = rand() < 0.6 ? bush(rand, 0.3 + rand() * 0.2) : rocks(rand, 0.25);
    d.position.set(x, 0, z);
    group.add(d);
  }
  // savaş alanında, kare köşelerinde küçük taş öbekleri (kulelere değmez)
  for (let i = 0; i < 18; i++) {
    const c = Math.floor(rand() * map.cols);
    const r = Math.floor(rand() * (map.wallRow - 1));
    if (path.tiles.has(r * map.cols + c)) continue;
    const d = rocks(rand, 0.07);
    d.position.set(c + (rand() < 0.5 ? 0.1 : 0.9) - W, 0, r + (rand() < 0.5 ? 0.1 : 0.9) - D);
    group.add(d);
  }
  return group;
}

// Düşman ordugâhı: devlet renginde çadırlar ve sancak. Dalga değişince renk değişir.
const tentGeo = new THREE.ConeGeometry(1, 1, 8);
const poleGeo = new THREE.CylinderGeometry(0.03, 0.03, 1, 6);
const flagGeo = new THREE.PlaneGeometry(1, 1);
function buildCamp() {
  const group = new THREE.Group();
  const tentMat = toon(0xffffff);
  const trimMat = toon(0xffffff);
  const tents = [
    [-1.3, -0.9, 0.55], [1.2, -1.0, 0.5], [0, -1.6, 0.7], [-2.4, -1.5, 0.45], [2.3, -1.6, 0.45],
  ];
  for (const [x, z, s] of tents) {
    const t = new THREE.Mesh(tentGeo, tentMat);
    t.position.set(x, s * 0.5, z);
    t.scale.set(s, s, s);
    t.castShadow = true;
    group.add(t);
    const band = new THREE.Mesh(new THREE.CylinderGeometry(1, 1, 0.12, 8), trimMat);
    band.position.set(x, s * 0.12, z);
    band.scale.set(s * 0.92, s, s * 0.92);
    group.add(band);
    const tip = new THREE.Mesh(new THREE.SphereGeometry(0.05, 8, 6), toonShared(PALETTE.gold));
    tip.position.set(x, s + 0.02, z);
    group.add(tip);
  }
  const pole = new THREE.Mesh(poleGeo, toonShared(PALETTE.woodDark));
  pole.position.set(0.75, 0.9, 0.1);
  pole.scale.y = 1.8;
  pole.castShadow = true;
  group.add(pole);
  const flagMat = noOutline(new THREE.MeshLambertMaterial({ side: THREE.DoubleSide }));
  const flag = new THREE.Mesh(flagGeo, flagMat);
  flag.scale.set(0.7, 0.46, 1);
  flag.position.set(1.1, 1.55, 0.1);
  group.add(flag);
  // ateş
  const fire = new THREE.Mesh(new THREE.ConeGeometry(0.1, 0.25, 8), noOutline(new THREE.MeshBasicMaterial({ color: 0xffa23a })));
  fire.position.set(-0.5, 0.12, -0.2);
  group.add(fire);
  const light = new THREE.PointLight(0xffa040, 1.2, 3, 1.5);
  light.position.set(-0.5, 0.5, -0.2);
  group.add(light);
  group.userData = { tentMat, trimMat, flagMat, flag, fire, light, nation: null, textures: new Map() };
  return group;
}

function setCampNation(camp, nation) {
  const u = camp.userData;
  if (u.nation === nation) return;
  u.nation = nation;
  const n = NATIONS[nation];
  u.tentMat.color.set(n.primary).lerp(new THREE.Color(0xffffff), 0.25);
  u.trimMat.color.set(n.secondary);
  let tex = u.textures.get(nation);
  if (!tex) {
    tex = nationFlagTexture(n.primary, n.secondary);
    u.textures.set(nation, tex);
  }
  u.flagMat.map = tex;
  u.flagMat.needsUpdate = true;
}

// Surlar: kesme taş, mazgallı; ortada kapı ve iki burç, köşelerde yuvarlak kuleler,
// kurşun külahlar, burçlarda Osmanlı sancakları.
const box = new THREE.BoxGeometry(1, 1, 1);
const cyl = new THREE.CylinderGeometry(1, 1, 1, 16);
const cone = new THREE.ConeGeometry(1, 1, 16);
function buildWalls(map) {
  const g = new THREE.Group();
  const stone = toonShared(PALETTE.stone);
  const stoneDark = toonShared(PALETTE.stoneDark);
  const lead = toonShared(PALETTE.lead);
  const add = (geo, mat, x, y, z, sx, sy, sz) => {
    const m = new THREE.Mesh(geo, mat);
    m.position.set(x, y, z);
    m.scale.set(sx, sy, sz);
    m.castShadow = true;
    m.receiveShadow = true;
    g.add(m);
    return m;
  };
  const W = map.cols / 2;
  const H = 0.85;
  const T = 0.5;
  const gateHalf = 0.5;
  // iki sur parçası
  for (const s of [-1, 1]) {
    const len = W - gateHalf;
    const cx = s * (gateHalf + len / 2);
    add(box, stone, cx, H / 2, 0, len, H, T);
    add(box, stoneDark, cx, H + 0.03, 0, len, 0.06, T + 0.06);
    // mazgallar
    for (let x = gateHalf + 0.15; x < W - 0.1; x += 0.3) add(box, stone, s * x, H + 0.13, T * 0.36, 0.16, 0.16, 0.12);
    // taş sıraları
    for (const y of [0.25, 0.55]) add(box, stoneDark, cx, y, T / 2 + 0.005, len, 0.025, 0.01);
  }
  // kapı burçları
  const flags = [];
  const flagMat = noOutline(new THREE.MeshLambertMaterial({ map: ottomanFlagTexture(), side: THREE.DoubleSide }));
  const tower = (x, r, h) => {
    add(cyl, stone, x, h / 2, 0, r, h, r);
    add(cyl, stoneDark, x, h + 0.03, 0, r + 0.05, 0.06, r + 0.05);
    for (let i = 0; i < 8; i++) {
      const a = (i / 8) * Math.PI * 2;
      add(box, stone, x + Math.cos(a) * r * 0.9, h + 0.14, Math.sin(a) * r * 0.9, 0.12, 0.16, 0.12);
    }
    add(cone, lead, x, h + 0.55, 0, r * 0.95, 0.8, r * 0.95);
    add(new THREE.SphereGeometry(0.04, 8, 6), toonShared(PALETTE.gold), x, h + 1.0, 0, 1, 1, 1);
    add(new THREE.CylinderGeometry(0.015, 0.015, 1, 6), toonShared(PALETTE.woodDark), x, h + 1.25, 0, 1, 0.5, 1);
    const f = new THREE.Mesh(flagGeo, flagMat);
    f.scale.set(0.42, 0.27, 1);
    f.position.set(x + 0.21, h + 1.35, 0);
    g.add(f);
    flags.push(f);
  };
  tower(-0.68, 0.3, 1.3);
  tower(0.68, 0.3, 1.3);
  tower(-W + 0.1, 0.36, 1.1);
  tower(W - 0.1, 0.36, 1.1);
  // kapı kemeri ve ahşap kanatlar
  add(box, stone, 0, H + 0.12, 0, gateHalf * 2 + 0.2, 0.34, T);
  add(box, stoneDark, 0, H - 0.08, T / 2 + 0.01, gateHalf * 2, 0.06, 0.02);
  const doorMat = toonShared(PALETTE.woodDark);
  const doors = [];
  for (const s of [-1, 1]) {
    const pivot = new THREE.Group();
    pivot.position.set(s * 0.42, 0, -0.18);
    const d = new THREE.Mesh(box, doorMat);
    d.scale.set(0.42, 0.72, 0.05);
    d.position.set(-s * 0.21, 0.36, 0);
    d.castShadow = true;
    pivot.add(d);
    g.add(pivot);
    doors.push({ pivot, side: s });
  }
  // kapının üstünde tuğra yerine altın hilal levha
  add(new THREE.TorusGeometry(0.08, 0.02, 6, 16, Math.PI * 1.5), toonShared(PALETTE.gold), 0, H + 0.15, T / 2 + 0.01, 1, 1, 1).rotation.z = 0.8;
  g.userData = { flags, doors };
  return g;
}

export function buildWorld(scene, map, path) {
  const rand = rng(map.seed);
  const root = new THREE.Group();
  root.add(buildGround(map, path, rand));
  root.add(buildDecor(map, path, rand));

  const start = path.points[0];
  const camp = buildCamp();
  camp.position.set(start.x - map.cols / 2, 0, -map.rows / 2 - 0.2);
  root.add(camp);

  const walls = buildWalls(map);
  walls.position.set(0, 0, map.wallRow + 0.5 - map.rows / 2);
  root.add(walls);

  scene.add(root);
  return { root, camp, walls };
}

export function updateWorld(world, time, state) {
  setCampNation(world.camp, state.nation);
  const c = world.camp.userData;
  c.flag.rotation.y = Math.sin(time * 2.5) * 0.25;
  c.fire.scale.y = 0.8 + 0.3 * Math.sin(time * 17);
  c.light.intensity = 1 + 0.3 * Math.sin(time * 11);

  const w = world.walls.userData;
  w.flags.forEach((f, i) => (f.rotation.y = Math.sin(time * 2.4 + i) * 0.3));
  // dalga sırasında kapı açılır (devriyeler çıkar), hazırlıkta kapanır
  const open = state.phase === 'wave' && state.patrols.length > 0;
  for (const d of w.doors) {
    const target = open ? d.side * 1.4 : 0;
    d.pivot.rotation.y += (target - d.pivot.rotation.y) * 0.08;
  }
}
