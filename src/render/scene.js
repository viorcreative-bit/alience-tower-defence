import * as THREE from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import { PALETTE } from './palette.js';
import { createPost } from './post.js';
import { RULES } from '../data/rules.js';
import { TOWERS, towerStats } from '../data/towers.js';
import { towerBonus } from '../systems/city.js';
import { buildWorld, updateWorld, GROUND_H } from './world.js';
import { createTowerModel, updateTowerModel, createProjectileModel, updateProjectileModel } from './towers.js';
import { createEnemyModel, updateEnemyModel, disposeEnemyModel } from './enemies.js';
import { createFx, updateFx, clearFx, drawOverlay } from './fx.js';
import { buildCity, updateCity } from './city.js';
import { createAmbient } from './ambient.js';
import { createPatrolModel, updatePatrolModel, disposePatrolModel } from './units.js';

// 3D çizim katmanı. Oyun mantığı kare biriminde 2D çalışır; burada dünyaya çevrilir:
// mantık (x, y) → dünya (x - cols/2, yükseklik, y - rows/2). Kamera güneyden eğik bakar.

const CAMERA_PITCH = (54 * Math.PI) / 180;
const CAMERA_FOV = 36;
const HEIGHTS = { tower: GROUND_H, shot: GROUND_H + 0.65, hit: 0.3, ring: 0.04, tesla: GROUND_H + 0.62 };

// quality: 'high' (son işlem, yumuşak gölge, dpr ≤ 1.5) | 'low' (doğrudan çizim, dpr 1)
export function createRenderer(canvas, overlay, map, path, quality = 'high') {
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
  renderer.shadowMap.enabled = true;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 0.95;

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(PALETTE.haze);
  scene.fog = new THREE.Fog(PALETTE.haze, 26, 60);
  // yumuşak çevre ışığı (bir kez hesaplanır)
  const pmrem = new THREE.PMREMGenerator(renderer);
  scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
  scene.environmentIntensity = 0.35;
  pmrem.dispose();

  const camera = new THREE.PerspectiveCamera(CAMERA_FOV, 1, 0.1, 120);
  const target = new THREE.Vector3(0, 0, 0.35);

  scene.add(new THREE.HemisphereLight(0xfff4e0, 0x5d7a3a, 1.0));
  const sun = new THREE.DirectionalLight(0xffe7c4, 2.3);
  sun.position.set(-5, 11, -4);
  sun.castShadow = true;
  sun.shadow.camera.left = -8;
  sun.shadow.camera.right = 8;
  sun.shadow.camera.top = 10;
  sun.shadow.camera.bottom = -10;
  sun.shadow.camera.near = 2;
  sun.shadow.camera.far = 30;
  sun.shadow.bias = -0.0006;
  sun.shadow.normalBias = 0.02;
  scene.add(sun);

  let post = null;
  function applyQuality(q) {
    quality = q;
    const high = q === 'high';
    renderer.shadowMap.type = high ? THREE.PCFSoftShadowMap : THREE.PCFShadowMap;
    sun.shadow.mapSize.set(high ? 2048 : 1024, high ? 2048 : 1024);
    sun.shadow.radius = high ? 3 : 1;
    if (sun.shadow.map) {
      sun.shadow.map.dispose();
      sun.shadow.map = null;
    }
    renderer.shadowMap.needsUpdate = true;
    scene.traverse((o) => {
      if (o.material && !Array.isArray(o.material)) o.material.needsUpdate = true;
    });
    if (high && !post) post = createPost(renderer, scene, camera);
  }
  applyQuality(quality);

  const ctx2d = overlay.getContext('2d');
  const view = { renderer, scene, camera, target, overlay, ctx2d, width: 1, height: 1, dpr: 1, unit: 32 };
  const cols = map.cols;
  const rows = map.rows;
  const toWorld = (x, y) => ({ x: x - cols / 2, z: y - rows / 2 });

  const world = buildWorld(scene, map, path);
  const city = buildCity(scene, map);
  const patrolModels = new Map();
  const fx = createFx(scene);
  const ambient = createAmbient(scene);
  const bufferSize = new THREE.Vector2();
  // ordugâh ateşi ve şehir bacaları sürekli tüter
  {
    const c = world.camp.position;
    ambient.addEmitter(c.x - 0.5, 0.3, c.z - 0.2, 'smoke', 2.5);
    ambient.addEmitter(c.x - 0.5, 0.2, c.z - 0.2, 'ember', 4);
    for (const p of city.chimneys) ambient.addEmitter(p.x, p.y, p.z, 'chimney', 0.7);
  }
  const towerModels = new Map();
  const seenTracers = new WeakSet();
  const enemyModels = new Map();
  const shotModels = new Map();
  const enemyTops = new Map();

  // seçim çerçevesi ve menzil dairesi
  const selection = new THREE.LineLoop(
    new THREE.BufferGeometry().setFromPoints([
      new THREE.Vector3(-0.46, 0, -0.46), new THREE.Vector3(0.46, 0, -0.46),
      new THREE.Vector3(0.46, 0, 0.46), new THREE.Vector3(-0.46, 0, 0.46),
    ]),
    new THREE.LineBasicMaterial({ color: 0xffffff, transparent: true }),
  );
  const selFill = new THREE.Mesh(
    new THREE.PlaneGeometry(0.92, 0.92),
    new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.3, depthWrite: false }),
  );
  selFill.rotation.x = -Math.PI / 2;
  const selGroup = new THREE.Group();
  selGroup.add(selection, selFill);
  selGroup.visible = false;
  scene.add(selGroup);

  const circlePts = [];
  for (let i = 0; i <= 96; i++) {
    const a = (i / 96) * Math.PI * 2;
    circlePts.push(new THREE.Vector3(Math.cos(a), 0, Math.sin(a)));
  }
  const rangeLine = new THREE.Line(
    new THREE.BufferGeometry().setFromPoints(circlePts),
    new THREE.LineDashedMaterial({ color: 0xffffff, dashSize: 0.06, gapSize: 0.04 }),
  );
  rangeLine.computeLineDistances();
  const rangeDisc = new THREE.Mesh(
    new THREE.CircleGeometry(1, 64),
    new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.16, depthWrite: false }),
  );
  rangeDisc.rotation.x = -Math.PI / 2;
  const rangeGroup = new THREE.Group();
  rangeGroup.add(rangeLine, rangeDisc);
  rangeGroup.visible = false;
  scene.add(rangeGroup);

  // Tahtanın tamamı (ve kale/portal yüksekliği) ekrana sığacak kamera uzaklığı.
  function fitCamera() {
    const dir = new THREE.Vector3(0, Math.sin(CAMERA_PITCH), Math.cos(CAMERA_PITCH));
    const corners = [];
    for (const x of [-cols / 2, cols / 2]) {
      for (const z of [-rows / 2 - 0.5, rows / 2 + 0.05]) {
        for (const y of [0, 1.6]) corners.push(new THREE.Vector3(x, y, z));
      }
    }
    const fits = (d) => {
      camera.position.copy(target).addScaledVector(dir, d);
      camera.lookAt(target);
      camera.updateMatrixWorld();
      return corners.every((c) => {
        const p = c.clone().project(camera);
        return Math.abs(p.x) <= 0.97 && Math.abs(p.y) <= 0.97;
      });
    };
    let lo = 4;
    let hi = 80;
    for (let i = 0; i < 30; i++) {
      const mid = (lo + hi) / 2;
      if (fits(mid)) hi = mid;
      else lo = mid;
    }
    fits(hi);
    view.basePos = camera.position.clone();
    // bir karenin ekrandaki yaklaşık boyu (2D katman yazıları için)
    const a = new THREE.Vector3(0, 0, 0).project(camera);
    const b = new THREE.Vector3(1, 0, 0).project(camera);
    view.unit = Math.abs(b.x - a.x) * 0.5 * view.width;
  }

  function resize(w, h) {
    const dpr = Math.min(window.devicePixelRatio || 1, RULES.maxDpr);
    view.width = w;
    view.height = h;
    view.dpr = dpr;
    const glDpr = quality === 'high' ? Math.min(dpr, 1.25) : 1;
    renderer.setPixelRatio(glDpr);
    renderer.setSize(w, h, false);
    if (post) post.setSize(w, h, glDpr);
    canvas.style.width = `${w}px`;
    canvas.style.height = `${h}px`;
    overlay.width = Math.round(w * dpr);
    overlay.height = Math.round(h * dpr);
    overlay.style.width = `${w}px`;
    overlay.style.height = `${h}px`;
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    fitCamera();
  }

  const v3 = new THREE.Vector3();
  function project(x, y, h) {
    const w = toWorld(x, y);
    v3.set(w.x, h, w.z).project(camera);
    if (v3.z > 1) return null;
    return { x: (v3.x * 0.5 + 0.5) * view.width, y: (-v3.y * 0.5 + 0.5) * view.height };
  }

  // Ekrandaki noktadan zemin karesine (ışın - düzlem kesişimi).
  const raycaster = new THREE.Raycaster();
  const groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), -GROUND_H);
  function pickTile(clientX, clientY) {
    const rect = canvas.getBoundingClientRect();
    const ndc = new THREE.Vector2(((clientX - rect.left) / rect.width) * 2 - 1, -((clientY - rect.top) / rect.height) * 2 + 1);
    raycaster.setFromCamera(ndc, camera);
    const hit = new THREE.Vector3();
    if (!raycaster.ray.intersectPlane(groundPlane, hit)) return null;
    return { c: Math.floor(hit.x + cols / 2), r: Math.floor(hit.z + rows / 2) };
  }

  // Kuleye bağlı parçacıklar: kaynayan ziftin dumanı, top atışında duman ve kıvılcım
  function towerEffects(m, t, w) {
    const u = m.userData;
    if (u.smokeY && !u.emitters) {
      const y = u.smokeY * m.scale.y;
      u.emitters = [ambient.addEmitter(w.x, y, w.z, 'tarSmoke', 2.2), ambient.addEmitter(w.x, y, w.z, 'ember', 2)];
    }
    if (t.type === 'cannon') {
      if (t.recoil > (u.lastRecoil ?? 0) + 0.5) {
        const r = 0.45 * m.scale.x;
        const x = w.x + Math.cos(t.angle) * r;
        const z = w.z + Math.sin(t.angle) * r;
        ambient.emit('puff', x, 0.62, z, 5, 0.12);
        ambient.emit('spark', x, 0.62, z, 8, 0.05);
      }
      u.lastRecoil = t.recoil;
    }
  }

  function disposeTower(m) {
    for (const e of m.userData.emitters || []) ambient.removeEmitter(e);
  }

  function sync(map, list, create, update, dispose, extra) {
    const seen = new Set();
    for (const item of list) {
      seen.add(item);
      let m = map.get(item);
      if (!m) {
        m = create(item);
        map.set(item, m);
        scene.add(m);
      }
      extra(m, item);
      update(m, item);
    }
    for (const [item, m] of map) {
      if (!seen.has(item)) {
        scene.remove(m);
        if (dispose) dispose(m);
        map.delete(item);
      }
    }
  }

  function render(state, time) {
    updateWorld(world, time, state);
    updateCity(city, state, time);
    const boosted = state.charge.active > 0;

    sync(towerModels, state.towers, createTowerModel, (m, t) => updateTowerModel(m, t, time, boosted), disposeTower, (m, t) => {
      const w = toWorld(t.x, t.y);
      m.position.set(w.x, HEIGHTS.tower, w.z);
      towerEffects(m, t, w);
    });

    enemyTops.clear();
    sync(enemyModels, state.enemies, createEnemyModel, (m, e) => updateEnemyModel(m, e, time), disposeEnemyModel, (m, e) => {
      const w = toWorld(e.x, e.y);
      m.position.set(w.x, 0, w.z);
      // kale kapısından girenler gizlenir
      m.visible = e.y < map.wallRow + 0.15;
      enemyTops.set(e, m.userData.topY + 0.05);
    });

    sync(patrolModels, state.patrols, createPatrolModel, (m, p) => updatePatrolModel(m, p, time), disposePatrolModel, (m, p) => {
      const w = toWorld(p.x, p.y);
      m.position.set(w.x, 0, w.z);
      // kapının içindeyken görünmez
      m.visible = p.y < map.wallRow + 0.1;
    });

    sync(shotModels, state.projectiles, createProjectileModel, updateProjectileModel, null, (m, p) => {
      const w = toWorld(p.x, p.y);
      m.position.set(w.x, HEIGHTS.shot, w.z);
    });

    updateFx(fx, state.effects, toWorld, HEIGHTS);
    // tüfek atışında namlu dumanı ve kıvılcım
    for (const e of state.effects) {
      if (e.kind !== 'lightning' || seenTracers.has(e)) continue;
      seenTracers.add(e);
      const w = toWorld(e.points[0].x, e.points[0].y);
      ambient.emit('puff', w.x, HEIGHTS.tesla, w.z, 3, 0.1);
      ambient.emit('spark', w.x, HEIGHTS.tesla, w.z, 4, 0.05);
    }
    renderer.getDrawingBufferSize(bufferSize);
    ambient.update(time, camera, bufferSize.y);

    const sel = state.selected;
    selGroup.visible = !!sel;
    if (sel) {
      const w = toWorld(sel.c + 0.5, sel.r + 0.5);
      selGroup.position.set(w.x, GROUND_H + 0.01, w.z);
      selection.material.opacity = 0.6 + 0.4 * Math.sin(time * 6);
      const t = sel.building ? null : state.towers.find((tw) => tw.c === sel.c && tw.r === sel.r);
      selFill.visible = !t && !sel.building;
      rangeGroup.visible = !!t;
      if (t) {
        const def = TOWERS[t.type];
        const r = towerStats(def, t.level, towerBonus(state, t.type)).range;
        rangeGroup.position.set(w.x, GROUND_H + 0.02, w.z);
        rangeGroup.scale.setScalar(r);
        rangeLine.material.color.set(def.color);
        rangeLine.material.dashSize = 0.06 / r;
        rangeLine.material.gapSize = 0.04 / r;
        rangeDisc.material.color.set(def.color);
      }
    } else {
      rangeGroup.visible = false;
    }

    camera.position.copy(view.basePos);
    if (state.shake > 0) {
      const k = (state.shake / RULES.shakeTime) * RULES.shakeStrength;
      camera.position.x += (Math.random() - 0.5) * 2 * k;
      camera.position.y += (Math.random() - 0.5) * 2 * k;
    }
    if (quality === 'high') post.render();
    else renderer.render(scene, camera);

    ctx2d.setTransform(view.dpr, 0, 0, view.dpr, 0, 0);
    drawOverlay(ctx2d, state, project, view.width, view.height, view.unit, enemyTops, RULES.lowHpRatio);
  }

  // Yeniden oyna: tüm modelleri temizle (arazi aynı kalır).
  function reset() {
    for (const m of towerModels.values()) {
      scene.remove(m);
      disposeTower(m);
    }
    ambient.clear();
    for (const m of enemyModels.values()) {
      scene.remove(m);
      disposeEnemyModel(m);
    }
    for (const m of shotModels.values()) scene.remove(m);
    for (const m of patrolModels.values()) {
      scene.remove(m);
      disposePatrolModel(m);
    }
    patrolModels.clear();
    towerModels.clear();
    enemyModels.clear();
    shotModels.clear();
    clearFx(fx);
  }

  function setQuality(q) {
    applyQuality(q);
    resize(view.width, view.height);
  }

  return { resize, render, pickTile, project, reset, view, ambient, setQuality, get quality() { return quality; } };
}
