import * as THREE from 'three';
import { createBackground, createGrassTile } from './background.js';
import { PALETTE, toon, noOutline } from './palette.js';

// Zemin, süsler, portal ve kale. Dünya birimi = 1 kare;
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

// Ahşap çit
const woodMat = toon(0x9a6436);
const postGeo = new THREE.CylinderGeometry(0.05, 0.06, 0.4, 6);
const railGeo = new THREE.BoxGeometry(1, 0.06, 0.05);
function fence(length) {
  const g = new THREE.Group();
  const posts = Math.max(2, Math.round(length / 0.6) + 1);
  for (let i = 0; i < posts; i++) {
    const p = new THREE.Mesh(postGeo, woodMat);
    p.position.set(-length / 2 + (i * length) / (posts - 1), 0.2, 0);
    p.castShadow = true;
    g.add(p);
  }
  for (const y of [0.15, 0.3]) {
    const r = new THREE.Mesh(railGeo, woodMat);
    r.scale.x = length;
    r.position.y = y;
    r.castShadow = true;
    g.add(r);
  }
  return g;
}

function buildDecor(map, path, rand) {
  const group = new THREE.Group();
  const W = map.cols / 2;
  const D = map.rows / 2;
  // tahtanın kenarı boyunca çalılar ve kayalar
  for (let i = 0; i < 46; i++) {
    const side = rand() < 0.5 ? -1 : 1;
    const x = side * (W + 0.35 + rand() * 3);
    const z = -D - 2 + rand() * (2 * D + 4);
    const d = rand() < 0.7 ? bush(rand, 0.25 + rand() * 0.25) : rocks(rand, 0.2 + rand() * 0.2);
    d.position.set(x, 0, z);
    group.add(d);
  }
  for (let i = 0; i < 14; i++) {
    const x = -W + rand() * 2 * W;
    const z = -D - 0.6 - rand() * 2.5;
    const d = rand() < 0.6 ? bush(rand, 0.3 + rand() * 0.2) : rocks(rand, 0.25);
    d.position.set(x, 0, z);
    group.add(d);
  }
  // tahta üstünde, kare köşelerinde küçük taş öbekleri (kulelere değmez)
  for (let i = 0; i < 18; i++) {
    const c = Math.floor(rand() * map.cols);
    const r = Math.floor(rand() * map.rows);
    const key = r * map.cols + c;
    if (path.tiles.has(key) || path.blocked.has(key)) continue;
    const d = rocks(rand, 0.07);
    d.position.set(c + (rand() < 0.5 ? 0.1 : 0.9) - W, 0, r + (rand() < 0.5 ? 0.1 : 0.9) - D);
    group.add(d);
  }
  // alt kenarda çitler
  for (const [x, len] of [[-3.1, 2.4], [3.1, 2.4]]) {
    const f = fence(len);
    f.position.set(x, 0, D + 0.35);
    group.add(f);
  }
  return group;
}

function swirlTexture() {
  const cv = document.createElement('canvas');
  cv.width = cv.height = 128;
  const g = cv.getContext('2d');
  const grad = g.createRadialGradient(64, 64, 4, 64, 64, 64);
  grad.addColorStop(0, '#f6e6ff');
  grad.addColorStop(0.3, '#a64dff');
  grad.addColorStop(0.75, '#3a1266');
  grad.addColorStop(1, '#1a0833');
  g.fillStyle = grad;
  g.fillRect(0, 0, 128, 128);
  g.lineCap = 'round';
  for (let i = 0; i < 5; i++) {
    g.strokeStyle = i % 2 ? 'rgba(124,255,107,0.85)' : 'rgba(220,170,255,0.85)';
    g.lineWidth = 5 - i * 0.6;
    g.beginPath();
    for (let a = 0; a < Math.PI * 3; a += 0.1) {
      const rr = 6 + a * 5.5;
      const x = 64 + Math.cos(a + (i * Math.PI * 2) / 5) * rr;
      const y = 64 + Math.sin(a + (i * Math.PI * 2) / 5) * rr;
      a ? g.lineTo(x, y) : g.moveTo(x, y);
    }
    g.stroke();
  }
  const t = new THREE.CanvasTexture(cv);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

// Portal: taş çerçeveli, dönen mor-yeşil solucan deliği.
function buildPortal() {
  const group = new THREE.Group();
  const disc = new THREE.Mesh(new THREE.CircleGeometry(0.52, 32), noOutline(new THREE.MeshBasicMaterial({ map: swirlTexture() })));
  group.add(disc);
  const ringA = new THREE.Mesh(new THREE.TorusGeometry(0.57, 0.09, 10, 40), toon(0x6b3fa0, { emissive: 0x8a3cff, emissiveIntensity: 0.6 }));
  group.add(ringA);
  const ringB = new THREE.Mesh(
    new THREE.TorusGeometry(0.7, 0.03, 6, 40, Math.PI * 1.3),
    noOutline(new THREE.MeshBasicMaterial({ color: 0x7cff6b })),
  );
  group.add(ringB);
  const stone = toon(0x8d8a96);
  for (const s of [-1, 1]) {
    const pillar = new THREE.Mesh(new THREE.BoxGeometry(0.22, 1.4, 0.3), stone);
    pillar.position.set(s * 0.78, -0.05, 0);
    pillar.castShadow = true;
    group.add(pillar);
    const cap = new THREE.Mesh(new THREE.OctahedronGeometry(0.12, 0), toon(0x7cff6b, { emissive: 0x3dbf2f, emissiveIntensity: 0.8 }));
    cap.position.set(s * 0.78, 0.75, 0);
    group.add(cap);
  }
  const light = new THREE.PointLight(0xb45aff, 2.5, 4, 1.5);
  light.position.set(0, 0, 0.5);
  group.add(light);
  group.userData = { disc, ringB, light };
  return group;
}

// Nova Üssü kalesi: surlar, iki yan kule, enerji kubbesi ve kalkan balonu.
function buildFortress() {
  const g = new THREE.Group();
  const wall = toon(0xc9ced9);
  const trim = toon(0x4a5578);
  const roof = toon(0x3d7bd9);
  const add = (geo, mat, x, y, z) => {
    const m = new THREE.Mesh(geo, mat);
    m.position.set(x, y, z);
    m.castShadow = true;
    m.receiveShadow = true;
    g.add(m);
    return m;
  };
  add(new THREE.BoxGeometry(3.0, 0.75, 0.5), wall, 0, 0.375, 0);
  add(new THREE.BoxGeometry(3.08, 0.08, 0.56), trim, 0, 0.76, 0);
  for (let i = -5; i <= 5; i++) {
    if (Math.abs(i) < 2) continue;
    add(new THREE.BoxGeometry(0.17, 0.16, 0.5), wall, i * 0.26, 0.88, 0);
  }
  const winMat = noOutline(new THREE.MeshBasicMaterial({ color: 0x8ee6ff }));
  for (const i of [-4, -3, 3, 4]) {
    const w = new THREE.Mesh(new THREE.PlaneGeometry(0.1, 0.12), winMat);
    w.position.set(i * 0.26, 0.5, 0.252);
    g.add(w);
  }
  add(new THREE.BoxGeometry(0.66, 0.62, 0.54), trim, 0, 0.31, 0.01);
  const field = new THREE.Mesh(
    new THREE.PlaneGeometry(0.5, 0.5),
    noOutline(new THREE.MeshBasicMaterial({ color: 0x4da3ff, transparent: true, opacity: 0.8 })),
  );
  field.position.set(0, 0.27, 0.285);
  g.add(field);

  const blinkers = [];
  for (const s of [-1, 1]) {
    add(new THREE.CylinderGeometry(0.28, 0.31, 1.3, 12), wall, s * 1.28, 0.65, 0);
    add(new THREE.CylinderGeometry(0.34, 0.34, 0.1, 12), trim, s * 1.28, 1.33, 0);
    add(new THREE.ConeGeometry(0.36, 0.5, 12), roof, s * 1.28, 1.63, 0);
    for (const y of [0.55, 0.9]) {
      const w = new THREE.Mesh(new THREE.PlaneGeometry(0.09, 0.12), winMat);
      w.position.set(s * 1.28, y, 0.3);
      g.add(w);
    }
    const blink = new THREE.Mesh(new THREE.SphereGeometry(0.06, 10, 8), noOutline(new THREE.MeshBasicMaterial({ color: 0xff4d5e })));
    blink.position.set(s * 1.28, 1.93, 0);
    g.add(blink);
    blinkers.push(blink);
  }

  add(new THREE.CylinderGeometry(0.64, 0.68, 0.12, 20), trim, 0, 0.84, 0);
  const domeMat = noOutline(toon(0x5ab8ff, { emissive: 0x2a7fff, emissiveIntensity: 0.8, transparent: true, opacity: 0.85 }));
  const dome = new THREE.Mesh(new THREE.SphereGeometry(0.56, 24, 12, 0, Math.PI * 2, 0, Math.PI / 2), domeMat);
  dome.position.set(0, 0.9, 0);
  g.add(dome);
  const core = new THREE.Mesh(new THREE.SphereGeometry(0.15, 16, 12), noOutline(new THREE.MeshBasicMaterial({ color: 0xe0f6ff })));
  core.position.set(0, 1.12, 0);
  g.add(core);
  const shieldMat = noOutline(new THREE.MeshBasicMaterial({
    color: 0x6ec1ff, transparent: true, opacity: 0.12, side: THREE.DoubleSide, depthWrite: false,
  }));
  const shield = new THREE.Mesh(new THREE.SphereGeometry(1.85, 32, 12, 0, Math.PI * 2, 0, Math.PI / 2), shieldMat);
  g.add(shield);
  const light = new THREE.PointLight(0x4da3ff, 2, 4, 1.5);
  light.position.set(0, 1.3, 0.6);
  g.add(light);

  g.userData = { domeMat, core, shieldMat, shield, light, blinkers, field };
  return g;
}

export function buildWorld(scene, map, path) {
  const rand = rng(map.seed);
  const root = new THREE.Group();
  root.add(buildGround(map, path, rand));
  root.add(buildDecor(map, path, rand));

  const start = path.points[0];
  const end = path.points[path.points.length - 1];
  const portal = buildPortal();
  portal.position.set(start.x - map.cols / 2, 0.7, Math.max(start.y, 0) - map.rows / 2 - 0.15);
  root.add(portal);

  const fortress = buildFortress();
  fortress.position.set(end.x - map.cols / 2, 0, map.rows / 2 - 0.45);
  root.add(fortress);

  scene.add(root);
  return { root, portal, fortress };
}

export function updateWorld(world, time, shieldRatio) {
  const p = world.portal.userData;
  p.disc.rotation.z = -time * 1.5;
  p.ringB.rotation.z = time * 2.2;
  p.light.intensity = 2.2 + Math.sin(time * 4) * 0.5;

  const f = world.fortress.userData;
  const power = Math.max(0.1, shieldRatio) * (0.85 + 0.15 * Math.sin(time * 3));
  f.domeMat.emissiveIntensity = 0.2 + power * 0.9;
  f.light.intensity = 0.4 + power * 2;
  f.core.scale.setScalar(0.6 + power * 0.5);
  f.shield.visible = shieldRatio > 0;
  f.shieldMat.opacity = 0.05 + 0.12 * shieldRatio;
  f.field.material.opacity = 0.35 + 0.5 * power;
  f.blinkers.forEach((b, i) => (b.visible = Math.sin(time * 4 + i) > 0.2));
}
