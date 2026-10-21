import * as THREE from 'three';
import { createBackground } from './background.js';

// Arazi, portal ve kale. Dünya birimi = 1 kare; mantıktaki (x, y) → dünyada (x - cols/2, y - rows/2).
export const GROUND_H = 0.3;
const TEX_TILE = 64;

function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

// Kanyon: yol olmayan kareler GROUND_H yüksekliğinde blok, yol kareleri tabanda.
function buildTerrain(map, path, texture) {
  const { cols, rows } = map;
  const ox = -cols / 2;
  const oz = -rows / 2;
  const isLow = (c, r) => c >= 0 && r >= 0 && c < cols && r < rows && path.tiles.has(r * cols + c);
  const top = { pos: [], uv: [], norm: [] };
  const wall = { pos: [], norm: [], col: [] };

  const quad = (buf, a, b, c, d, n, uvs, cols4) => {
    for (const i of [0, 1, 2, 0, 2, 3]) {
      const v = [a, b, c, d][i];
      buf.pos.push(v[0], v[1], v[2]);
      buf.norm.push(n[0], n[1], n[2]);
      if (uvs) buf.uv.push(uvs[i][0], uvs[i][1]);
      if (cols4) buf.col.push(...cols4[i]);
    }
  };
  const u = (c) => c / cols;
  const v = (r) => 1 - r / rows;
  const H = GROUND_H;
  const lightC = [1, 1, 1];
  const darkC = [0.45, 0.4, 0.4];

  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      if (isLow(c, r)) continue;
      const x0 = ox + c;
      const x1 = x0 + 1;
      const z0 = oz + r;
      const z1 = z0 + 1;
      quad(top, [x0, H, z0], [x0, H, z1], [x1, H, z1], [x1, H, z0], [0, 1, 0],
        [[u(c), v(r)], [u(c), v(r + 1)], [u(c + 1), v(r + 1)], [u(c + 1), v(r)]]);
      const cw = [lightC, darkC, darkC, lightC];
      if (isLow(c, r + 1)) quad(wall, [x0, H, z1], [x0, 0, z1], [x1, 0, z1], [x1, H, z1], [0, 0, 1], null, cw);
      if (isLow(c, r - 1)) quad(wall, [x1, H, z0], [x1, 0, z0], [x0, 0, z0], [x0, H, z0], [0, 0, -1], null, cw);
      if (isLow(c + 1, r)) quad(wall, [x1, H, z1], [x1, 0, z1], [x1, 0, z0], [x1, H, z0], [1, 0, 0], null, cw);
      if (isLow(c - 1, r)) quad(wall, [x0, H, z0], [x0, 0, z0], [x0, 0, z1], [x0, H, z1], [-1, 0, 0], null, cw);
    }
  }

  const group = new THREE.Group();
  const topGeo = new THREE.BufferGeometry();
  topGeo.setAttribute('position', new THREE.Float32BufferAttribute(top.pos, 3));
  topGeo.setAttribute('normal', new THREE.Float32BufferAttribute(top.norm, 3));
  topGeo.setAttribute('uv', new THREE.Float32BufferAttribute(top.uv, 2));
  const topMesh = new THREE.Mesh(topGeo, new THREE.MeshLambertMaterial({ map: texture }));
  topMesh.receiveShadow = true;
  group.add(topMesh);

  const wallGeo = new THREE.BufferGeometry();
  wallGeo.setAttribute('position', new THREE.Float32BufferAttribute(wall.pos, 3));
  wallGeo.setAttribute('normal', new THREE.Float32BufferAttribute(wall.norm, 3));
  wallGeo.setAttribute('color', new THREE.Float32BufferAttribute(wall.col, 3));
  const wallMesh = new THREE.Mesh(wallGeo, new THREE.MeshLambertMaterial({ color: 0x7a3f28, vertexColors: true }));
  wallMesh.receiveShadow = true;
  wallMesh.castShadow = true;
  group.add(wallMesh);

  // yol tabanı: aynı doku, tüm tahtanın altında
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(cols, rows), new THREE.MeshLambertMaterial({ map: texture }));
  floor.rotation.x = -Math.PI / 2;
  floor.receiveShadow = true;
  group.add(floor);
  return group;
}

function noiseTexture(rand) {
  const cv = document.createElement('canvas');
  cv.width = cv.height = 128;
  const g = cv.getContext('2d');
  g.fillStyle = '#6b3626';
  g.fillRect(0, 0, 128, 128);
  for (let i = 0; i < 900; i++) {
    g.fillStyle = rand() < 0.5 ? 'rgba(40,14,8,0.12)' : 'rgba(170,100,66,0.1)';
    const r = 2 + rand() * 9;
    g.beginPath();
    g.arc(rand() * 128, rand() * 128, r, 0, Math.PI * 2);
    g.fill();
  }
  const t = new THREE.CanvasTexture(cv);
  t.colorSpace = THREE.SRGBColorSpace;
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.repeat.set(4, 4);
  return t;
}

// Tahtanın dışındaki Mars düzlüğü ve uzaktaki tepeler.
function buildSurroundings(map, rand) {
  const group = new THREE.Group();
  const W = map.cols;
  const D = map.rows;
  const shape = new THREE.Shape();
  shape.moveTo(-40, -40);
  shape.lineTo(40, -40);
  shape.lineTo(40, 40);
  shape.lineTo(-40, 40);
  shape.closePath();
  const hole = new THREE.Path();
  hole.moveTo(-W / 2, -D / 2);
  hole.lineTo(-W / 2, D / 2);
  hole.lineTo(W / 2, D / 2);
  hole.lineTo(W / 2, -D / 2);
  hole.closePath();
  shape.holes.push(hole);
  const geo = new THREE.ShapeGeometry(shape);
  const uv = geo.attributes.uv;
  for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) / 8, uv.getY(i) / 8);
  const plain = new THREE.Mesh(geo, new THREE.MeshLambertMaterial({ map: noiseTexture(rand) }));
  plain.rotation.x = -Math.PI / 2;
  plain.position.y = GROUND_H;
  plain.receiveShadow = true;
  group.add(plain);

  // tahta çevresinde kaya ve uzakta masa tepeler
  const rockMat = new THREE.MeshLambertMaterial({ color: 0x7c4129, flatShading: true });
  const rockGeo = new THREE.DodecahedronGeometry(1, 0);
  for (let i = 0; i < 40; i++) {
    const side = rand() < 0.5 ? -1 : 1;
    const x = side * (W / 2 + 0.4 + rand() * 6);
    const z = -D / 2 - 4 + rand() * (D + 8);
    const s = 0.15 + rand() * 0.5;
    const m = new THREE.Mesh(rockGeo, rockMat);
    m.position.set(x, GROUND_H + s * 0.3, z);
    m.scale.set(s, s * (0.5 + rand() * 0.6), s);
    m.rotation.set(rand() * 3, rand() * 3, rand() * 3);
    m.castShadow = true;
    group.add(m);
  }
  const mesaMat = new THREE.MeshLambertMaterial({ color: 0x5e2e1e, flatShading: true });
  for (let i = 0; i < 9; i++) {
    const r = 1.5 + rand() * 3;
    const h = 1 + rand() * 3;
    const m = new THREE.Mesh(new THREE.CylinderGeometry(r * 0.7, r, h, 7), mesaMat);
    const a = -Math.PI * 0.95 + rand() * Math.PI * 0.9;
    const dist = 16 + rand() * 12;
    m.position.set(Math.cos(a) * dist, GROUND_H + h / 2, Math.sin(a) * dist - 4);
    group.add(m);
  }
  return group;
}

// Tahta üzerindeki küçük kayalar (kare köşelerine yakın, kulelere değmesin diye).
function buildBoardRocks(map, path, rand) {
  const group = new THREE.Group();
  const mat = new THREE.MeshStandardMaterial({ color: 0x8a4a30, roughness: 0.95, flatShading: true });
  const geo = new THREE.DodecahedronGeometry(1, 0);
  for (let i = 0; i < 30; i++) {
    const c = Math.floor(rand() * map.cols);
    const r = Math.floor(rand() * map.rows);
    if (path.tiles.has(r * map.cols + c) || path.blocked.has(r * map.cols + c)) continue;
    const corner = [0.12, 0.88];
    const x = c + corner[Math.floor(rand() * 2)] - map.cols / 2;
    const z = r + corner[Math.floor(rand() * 2)] - map.rows / 2;
    const s = 0.04 + rand() * 0.07;
    const m = new THREE.Mesh(geo, mat);
    m.position.set(x, GROUND_H + s * 0.4, z);
    m.scale.set(s, s * 0.7, s);
    m.rotation.set(rand() * 3, rand() * 3, rand() * 3);
    m.castShadow = true;
    group.add(m);
  }
  return group;
}

function swirlTexture() {
  const cv = document.createElement('canvas');
  cv.width = cv.height = 128;
  const g = cv.getContext('2d');
  const grad = g.createRadialGradient(64, 64, 4, 64, 64, 64);
  grad.addColorStop(0, '#f2dcff');
  grad.addColorStop(0.25, '#9b45ff');
  grad.addColorStop(0.7, '#2a0b4a');
  grad.addColorStop(1, '#0c0418');
  g.fillStyle = grad;
  g.fillRect(0, 0, 128, 128);
  g.lineCap = 'round';
  for (let i = 0; i < 5; i++) {
    g.strokeStyle = i % 2 ? 'rgba(124,255,107,0.8)' : 'rgba(210,150,255,0.8)';
    g.lineWidth = 4 - i * 0.5;
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

// Portal: dikey duran, dönen mor-yeşil solucan deliği.
function buildPortal() {
  const group = new THREE.Group();
  const disc = new THREE.Mesh(
    new THREE.CircleGeometry(0.5, 32),
    new THREE.MeshBasicMaterial({ map: swirlTexture(), transparent: true }),
  );
  group.add(disc);
  const ringA = new THREE.Mesh(
    new THREE.TorusGeometry(0.55, 0.07, 10, 40),
    new THREE.MeshStandardMaterial({ color: 0x40205e, emissive: 0xb45aff, emissiveIntensity: 1.2, metalness: 0.5, roughness: 0.4 }),
  );
  group.add(ringA);
  const ringB = new THREE.Mesh(
    new THREE.TorusGeometry(0.65, 0.025, 6, 40, Math.PI * 1.3),
    new THREE.MeshBasicMaterial({ color: 0x7cff6b }),
  );
  group.add(ringB);
  // taş çerçeve
  const frameMat = new THREE.MeshStandardMaterial({ color: 0x3a3048, roughness: 0.8, metalness: 0.3 });
  for (const s of [-1, 1]) {
    const pillar = new THREE.Mesh(new THREE.BoxGeometry(0.16, 1.3, 0.22), frameMat);
    pillar.position.set(s * 0.72, 0, 0);
    pillar.castShadow = true;
    group.add(pillar);
  }
  const light = new THREE.PointLight(0xb45aff, 2.5, 4, 1.5);
  light.position.set(0, 0, 0.4);
  group.add(light);
  group.userData = { disc, ringA, ringB, light };
  return group;
}

const metalMat = () => new THREE.MeshStandardMaterial({ color: 0x6b7390, metalness: 0.7, roughness: 0.35 });

// Nova Üssü kalesi: surlar, iki yan kule, enerji kubbesi ve kalkan balonu.
function buildFortress() {
  const g = new THREE.Group();
  const metal = metalMat();
  const dark = new THREE.MeshStandardMaterial({ color: 0x2b3047, metalness: 0.6, roughness: 0.5 });
  const add = (mesh, x, y, z) => {
    mesh.position.set(x, y, z);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    g.add(mesh);
    return mesh;
  };
  add(new THREE.Mesh(new THREE.BoxGeometry(3.0, 0.8, 0.45), metal), 0, 0.4, 0);
  add(new THREE.Mesh(new THREE.BoxGeometry(3.06, 0.06, 0.5), dark), 0, 0.8, 0);
  for (let i = -5; i <= 5; i++) {
    if (Math.abs(i) < 2) continue;
    add(new THREE.Mesh(new THREE.BoxGeometry(0.16, 0.14, 0.45), metal), i * 0.26, 0.9, 0);
  }
  const winMat = new THREE.MeshBasicMaterial({ color: 0x78dcff });
  for (const i of [-4, -3, 3, 4]) {
    const w = new THREE.Mesh(new THREE.PlaneGeometry(0.1, 0.07), winMat);
    w.position.set(i * 0.26, 0.55, 0.226);
    g.add(w);
  }
  // kapı
  const gate = new THREE.Mesh(new THREE.BoxGeometry(0.62, 0.6, 0.5), dark);
  add(gate, 0, 0.3, 0.01);
  const field = new THREE.Mesh(
    new THREE.PlaneGeometry(0.5, 0.5),
    new THREE.MeshBasicMaterial({ color: 0x4da3ff, transparent: true, opacity: 0.7 }),
  );
  field.position.set(0, 0.27, 0.262);
  g.add(field);

  // yan kuleler
  const blinkers = [];
  for (const s of [-1, 1]) {
    const tower = add(new THREE.Mesh(new THREE.CylinderGeometry(0.24, 0.27, 1.35, 16), metal), s * 1.28, 0.675, 0);
    tower.userData.side = s;
    add(new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.3, 0.08, 16), dark), s * 1.28, 1.39, 0);
    add(new THREE.Mesh(new THREE.CylinderGeometry(0.31, 0.31, 0.06, 16), dark), s * 1.28, 0.95, 0);
    for (const y of [0.55, 0.75, 1.15]) {
      const w = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.06, 0.02), winMat);
      w.position.set(s * 1.28, y, 0.26);
      g.add(w);
    }
    const ant = new THREE.Mesh(new THREE.CylinderGeometry(0.012, 0.012, 0.35, 5), metal);
    ant.position.set(s * 1.28, 1.6, 0);
    g.add(ant);
    const blink = new THREE.Mesh(new THREE.SphereGeometry(0.045, 10, 8), new THREE.MeshBasicMaterial({ color: 0xff4d5e }));
    blink.position.set(s * 1.28, 1.8, 0);
    g.add(blink);
    blinkers.push(blink);
  }

  // enerji kubbesi
  add(new THREE.Mesh(new THREE.CylinderGeometry(0.62, 0.66, 0.1, 24), dark), 0, 0.85, 0);
  const domeMat = new THREE.MeshStandardMaterial({
    color: 0x4da3ff, emissive: 0x2a7fff, emissiveIntensity: 1, transparent: true, opacity: 0.75,
    metalness: 0.2, roughness: 0.1,
  });
  const dome = add(new THREE.Mesh(new THREE.SphereGeometry(0.55, 24, 12, 0, Math.PI * 2, 0, Math.PI / 2), domeMat), 0, 0.9, 0);
  dome.castShadow = false;
  const core = new THREE.Mesh(new THREE.SphereGeometry(0.15, 16, 12), new THREE.MeshBasicMaterial({ color: 0xd2f0ff }));
  core.position.set(0, 1.12, 0);
  g.add(core);
  const shieldMat = new THREE.MeshBasicMaterial({
    color: 0x4da3ff, transparent: true, opacity: 0.12, side: THREE.DoubleSide, depthWrite: false,
  });
  const shield = new THREE.Mesh(new THREE.SphereGeometry(1.85, 32, 12, 0, Math.PI * 2, 0, Math.PI / 2), shieldMat);
  g.add(shield);
  const light = new THREE.PointLight(0x4da3ff, 3, 5, 1.5);
  light.position.set(0, 1.3, 0.6);
  g.add(light);

  g.userData = { domeMat, core, shield, shieldMat, light, blinkers, field };
  return g;
}

export function buildWorld(scene, map, path) {
  const rand = rng(map.seed);
  const texCanvas = createBackground(map, path, TEX_TILE, 1, false);
  const texture = new THREE.CanvasTexture(texCanvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.anisotropy = 4;

  const root = new THREE.Group();
  root.add(buildTerrain(map, path, texture));
  root.add(buildSurroundings(map, rand));
  root.add(buildBoardRocks(map, path, rand));

  const start = path.points[0];
  const end = path.points[path.points.length - 1];
  const portal = buildPortal();
  portal.position.set(start.x - map.cols / 2, 0.62, Math.max(start.y, 0) - map.rows / 2 - 0.2);
  root.add(portal);

  const fortress = buildFortress();
  fortress.position.set(end.x - map.cols / 2, 0, map.rows / 2 - 0.45);
  root.add(fortress);

  scene.add(root);
  return { root, portal, fortress, texture };
}

export function updateWorld(world, time, shieldRatio) {
  const p = world.portal.userData;
  p.disc.rotation.z = -time * 1.5;
  p.ringB.rotation.z = time * 2.2;
  p.light.intensity = 2.2 + Math.sin(time * 4) * 0.5;

  const f = world.fortress.userData;
  const power = Math.max(0.1, shieldRatio) * (0.85 + 0.15 * Math.sin(time * 3));
  f.domeMat.emissiveIntensity = 0.3 + power * 1.2;
  f.light.intensity = 0.5 + power * 3;
  f.core.scale.setScalar(0.6 + power * 0.5);
  f.shield.visible = shieldRatio > 0;
  f.shieldMat.opacity = 0.05 + 0.12 * shieldRatio;
  f.field.material.opacity = 0.3 + 0.5 * power;
  f.blinkers.forEach((b, i) => (b.visible = Math.sin(time * 4 + i) > 0.2));
}
