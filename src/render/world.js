import * as THREE from 'three';
import { createBackground, createGrassTile } from './background.js';
import { PALETTE, paint, paintShared, ottomanFlagTexture, nationFlagTexture } from './palette.js';
import { prop, bakeStatic } from './models.js';
import { flagMesh, setFlagTexture } from './flags.js';
import { NATIONS } from '../data/nations.js';

// Zemin, süsler (KayKit ağaç, kaya, tepe), düşman ordugâhı ve surlar. Dünya birimi = 1 kare;
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
  const board = new THREE.Mesh(new THREE.PlaneGeometry(map.cols, map.rows), new THREE.MeshStandardMaterial({ map: tex, roughness: 1 }));
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
  const plain = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ map: groundTexture(map.seed + 1), roughness: 1 }));
  plain.rotation.x = -Math.PI / 2;
  plain.position.y = -0.002;
  plain.receiveShadow = true;
  group.add(plain);
  return group;
}

// Kenar süsleri: KayKit ağaçları, kayaları, tepeleri. Hepsi tek dokuyu paylaşır, sonra tek ağa birleşir.
const TREES = ['tree_single_A', 'tree_single_B', 'trees_A_small', 'trees_B_small', 'trees_A_medium', 'trees_B_medium'];
const ROCKS = ['rock_single_A', 'rock_single_B', 'rock_single_C', 'rock_single_D', 'rock_single_E'];
const HILLS = ['hills_A_trees', 'hills_B_trees', 'mountain_A_grass_trees', 'mountain_B_grass_trees', 'mountain_C_grass'];
const pick = (rand, list) => list[Math.floor(rand() * list.length)];

function place(group, name, x, z, scale, rand) {
  const m = prop(name, scale);
  m.position.set(x, 0, z);
  m.rotation.y = rand() * Math.PI * 2;
  group.add(m);
  return m;
}

function buildDecor(map, path, rand) {
  const group = new THREE.Group();
  const W = map.cols / 2;
  const D = map.rows / 2;
  // tahtanın iki yanında orman ve tepeler
  for (const side of [-1, 1]) {
    for (let z = -D - 3; z < D + 3; z += 1.1 + rand() * 0.6) {
      place(group, pick(rand, TREES), side * (W + 0.6 + rand() * 0.6), z, 0.55 + rand() * 0.25, rand);
      if (rand() < 0.5) place(group, pick(rand, TREES), side * (W + 1.6 + rand() * 1.5), z + rand(), 0.6 + rand() * 0.3, rand);
    }
    for (let z = -D - 2; z < D + 3; z += 2.5 + rand()) place(group, pick(rand, HILLS), side * (W + 2.6 + rand() * 1.4), z, 0.9 + rand() * 0.4, rand);
    for (let i = 0; i < 8; i++) place(group, pick(rand, ROCKS), side * (W + 0.25 + rand() * 0.5), -D + rand() * 2 * D, 0.6 + rand() * 0.6, rand);
  }
  // ordugâhın ardında dağlar
  for (let x = -W - 2; x < W + 3; x += 1.8 + rand() * 0.6) {
    if (Math.abs(x + W - 1.5) < 1.6) {
      place(group, pick(rand, TREES), x, -D - 3.2 - rand(), 0.7, rand);
      continue;
    }
    place(group, pick(rand, HILLS), x, -D - 2.6 - rand() * 1.2, 1 + rand() * 0.4, rand);
    if (rand() < 0.7) place(group, pick(rand, TREES), x + 0.6, -D - 1.0 - rand() * 0.6, 0.5 + rand() * 0.2, rand);
  }
  // savaş alanında, kare köşelerinde küçük taşlar ve çalılar (kulelere değmez)
  for (let i = 0; i < 22; i++) {
    const c = Math.floor(rand() * map.cols);
    const r = Math.floor(rand() * (map.wallRow - 1));
    if (path.tiles.has(r * map.cols + c)) continue;
    place(group, pick(rand, ROCKS), c + (rand() < 0.5 ? 0.12 : 0.88) - W, r + (rand() < 0.5 ? 0.12 : 0.88) - D, 0.35 + rand() * 0.25, rand);
  }
  return bakeStatic(group);
}

// Düşman ordugâhı: devlet renginde çadırlar, sancak, erzak ve ateş. Dalga değişince renk değişir.
const tentGeo = new THREE.ConeGeometry(1, 1, 10);
const bandGeo = new THREE.CylinderGeometry(1, 1, 0.12, 10);
const poleGeo = new THREE.CylinderGeometry(0.025, 0.03, 1, 6);
function buildCamp(rand) {
  const group = new THREE.Group();
  const tentMat = paint(0xffffff);
  const trimMat = paint(0xffffff);
  const tents = [
    [-1.3, -0.9, 0.55], [1.2, -1.0, 0.5], [0, -1.6, 0.7], [-2.4, -1.5, 0.45], [2.3, -1.6, 0.45],
  ];
  for (const [x, z, s] of tents) {
    const t = new THREE.Mesh(tentGeo, tentMat);
    t.position.set(x, s * 0.5, z);
    t.scale.set(s, s, s);
    t.castShadow = true;
    t.receiveShadow = true;
    group.add(t);
    const band = new THREE.Mesh(bandGeo, trimMat);
    band.position.set(x, s * 0.12, z);
    band.scale.set(s * 0.92, s, s * 0.92);
    group.add(band);
    const tip = new THREE.Mesh(new THREE.SphereGeometry(0.05, 8, 6), paintShared(PALETTE.gold));
    tip.position.set(x, s + 0.02, z);
    group.add(tip);
  }
  // erzak, silahlık, el arabası
  const stuff = [
    ['barrel', -0.7, -0.55, 1.6], ['barrel', -0.5, -0.7, 1.6], ['crate_A_big', 0.5, -0.6, 1.5], ['crate_B_small', 0.7, -0.45, 1.6],
    ['weaponrack', -1.8, -0.7, 1.8], ['wheelbarrow', 1.8, -0.55, 1.6], ['sack', 0.35, -0.35, 1.8], ['resource_lumber', -2.9, -0.8, 1],
    ['fence_wood_straight', -3.4, -0.4, 1.2], ['fence_wood_straight', 3.3, -0.4, 1.2],
  ];
  for (const [name, x, z, sc] of stuff) place(group, name, x, z, sc * 0.5, rand);
  const stat = bakeStatic(group);

  const pole = new THREE.Mesh(poleGeo, paintShared(PALETTE.woodDark));
  pole.position.set(0.75, 0.9, 0.1);
  pole.scale.y = 1.8;
  pole.castShadow = true;
  stat.add(pole);
  const flag = flagMesh(nationFlagTexture('#ffffff', '#ffffff'), 0.7, 0.46);
  flag.position.set(0.77, 1.55, 0.1);
  stat.add(flag);
  // kamp ateşi: taş halka, parlayan alev
  for (let i = 0; i < 7; i++) {
    const a = (i / 7) * Math.PI * 2;
    const st = prop('rock_single_E', 0.18);
    st.position.set(-0.5 + Math.cos(a) * 0.13, 0, -0.2 + Math.sin(a) * 0.13);
    stat.add(st);
  }
  const fireMat = new THREE.MeshBasicMaterial({ color: new THREE.Color(4, 1.5, 0.25), transparent: true, opacity: 0.95, depthWrite: false });
  const fire = new THREE.Mesh(new THREE.ConeGeometry(0.09, 0.28, 8), fireMat);
  fire.position.set(-0.5, 0.14, -0.2);
  stat.add(fire);
  const light = new THREE.PointLight(0xff9a40, 1.6, 3, 1.5);
  light.position.set(-0.5, 0.5, -0.2);
  stat.add(light);
  stat.userData = { tentMat, trimMat, flag, fire, light, nation: null, textures: new Map() };
  return stat;
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
  setFlagTexture(u.flag, tex);
}

// Surlar: KayKit taş sur parçaları, ortada kapı, iki yanında burçlar; köşelerde kuleler.
// Burçlarda kurşun külah, altın alem ve dalgalanan Osmanlı sancakları.
const WALL_SCALE = 0.75;
const leadCone = new THREE.ConeGeometry(1, 1, 12);
function buildWalls(map, rand) {
  const g = new THREE.Group();
  const W = map.cols / 2;
  const gate = prop('wall_straight_gate', WALL_SCALE);
  g.add(gate);
  const step = 2 * WALL_SCALE;
  for (let x = step; x < W + step / 2; x += step) {
    for (const s of [-1, 1]) {
      const w = prop('wall_straight', WALL_SCALE);
      w.position.x = s * x;
      g.add(w);
    }
  }
  const flagTex = ottomanFlagTexture();
  const flags = [];
  const tower = (x, sc) => {
    const t = prop('building_tower_base', sc);
    t.position.x = x;
    t.rotation.y = Math.PI;
    g.add(t);
    const top = 1.5 * sc;
    const roof = new THREE.Mesh(leadCone, paintShared(PALETTE.lead));
    roof.position.set(x, top + 0.26, 0);
    roof.scale.set(0.47 * sc, 0.52, 0.47 * sc);
    roof.castShadow = true;
    g.add(roof);
    const ball = new THREE.Mesh(new THREE.SphereGeometry(0.045, 10, 8), paintShared(PALETTE.gold));
    ball.position.set(x, top + 0.54, 0);
    g.add(ball);
    const pole = new THREE.Mesh(poleGeo, paintShared(PALETTE.woodDark));
    pole.position.set(x, top + 0.78, 0);
    pole.scale.y = 0.5;
    g.add(pole);
    const f = flagMesh(flagTex, 0.44, 0.28);
    f.position.set(x + 0.02, top + 0.9, 0);
    g.add(f);
    flags.push(f);
  };
  tower(-0.95, 0.72);
  tower(0.95, 0.72);
  tower(-W + 0.15, 0.62);
  tower(W - 0.15, 0.62);
  // kapının üstünde altın hilal levha
  const crescent = new THREE.Mesh(new THREE.TorusGeometry(0.075, 0.02, 6, 16, Math.PI * 1.5), paintShared(PALETTE.gold));
  crescent.position.set(0, 0.98, 0.34);
  crescent.rotation.z = 0.8;
  g.add(crescent);
  bakeStatic(g);
  g.userData = { flags };
  return g;
}

export function buildWorld(scene, map, path) {
  const rand = rng(map.seed);
  const root = new THREE.Group();
  root.add(buildGround(map, path, rand));
  root.add(buildDecor(map, path, rand));

  const start = path.points[0];
  const camp = buildCamp(rand);
  camp.position.set(start.x - map.cols / 2, 0, -map.rows / 2 - 0.2);
  root.add(camp);

  const walls = buildWalls(map, rand);
  walls.position.set(0, 0, map.wallRow + 0.5 - map.rows / 2);
  root.add(walls);

  scene.add(root);
  return { root, camp, walls };
}

export function updateWorld(world, time, state) {
  setCampNation(world.camp, state.nation);
  const c = world.camp.userData;
  c.fire.scale.set(1 + 0.15 * Math.sin(time * 13), 0.8 + 0.3 * Math.sin(time * 17), 1);
  c.light.intensity = 1.4 + 0.4 * Math.sin(time * 11);
}
