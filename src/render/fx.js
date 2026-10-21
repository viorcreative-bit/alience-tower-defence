import * as THREE from 'three';
import { noOutline } from './palette.js';

// Efektler: parçacık, halka ve şimşek 3D sahnede; yükselen yazılar, can çubukları
// ve uyarı şeridi sahnenin üstündeki 2D katmanda çizilir.

const MAX_PARTICLES = 600;
const ringGeo = new THREE.RingGeometry(0.9, 1, 40);

export function createFx(scene) {
  const particles = new THREE.InstancedMesh(
    new THREE.IcosahedronGeometry(1, 0),
    noOutline(new THREE.MeshBasicMaterial({ color: 0xffffff })),
    MAX_PARTICLES,
  );
  particles.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
  particles.frustumCulled = false;
  particles.count = 0;
  // renk tamponunu oluştur
  particles.setColorAt(0, new THREE.Color(1, 1, 1));
  scene.add(particles);
  return { scene, particles, meshes: new Map(), tmp: new THREE.Object3D(), color: new THREE.Color() };
}

function makeRing(e) {
  const m = new THREE.Mesh(
    ringGeo,
    noOutline(new THREE.MeshBasicMaterial({ color: e.color, transparent: true, depthWrite: false, side: THREE.DoubleSide })),
  );
  m.rotation.x = -Math.PI / 2;
  return m;
}

function makeLightning(e, toWorld, fromY, toY) {
  const pts = e.points.map((p, i) => {
    const t = i / (e.points.length - 1);
    const w = toWorld(p.x, p.y);
    return new THREE.Vector3(w.x, fromY + (toY - fromY) * t + (i % 2 ? 0.08 : -0.05), w.z);
  });
  const curve = new THREE.CatmullRomCurve3(pts, false, 'catmullrom', 0.1);
  const g = new THREE.Group();
  g.add(new THREE.Mesh(
    new THREE.TubeGeometry(curve, pts.length * 3, 0.035, 5, false),
    noOutline(new THREE.MeshBasicMaterial({ color: e.color, transparent: true, depthWrite: false })),
  ));
  g.add(new THREE.Mesh(
    new THREE.TubeGeometry(curve, pts.length * 3, 0.012, 4, false),
    noOutline(new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true })),
  ));
  return g;
}

function disposeObject(obj) {
  obj.traverse((o) => {
    if (o.isMesh) {
      if (o.geometry !== ringGeo) o.geometry.dispose();
      o.material.dispose();
    }
  });
}

// Her karede mantıktaki efekt listesini 3D sahneyle eşler.
export function updateFx(fx, effects, toWorld, heights) {
  const seen = new Set();
  let n = 0;
  for (const e of effects) {
    if (e.kind === 'particle') {
      if (n >= MAX_PARTICLES) continue;
      const t = 1 - e.life / e.max;
      const w = toWorld(e.x, e.y);
      fx.tmp.position.set(w.x, heights.hit + Math.sin(t * Math.PI) * 0.35 - t * 0.2, w.z);
      fx.tmp.scale.setScalar(Math.max(0.015, e.size * (1 - t * 0.5)));
      fx.tmp.updateMatrix();
      fx.particles.setMatrixAt(n, fx.tmp.matrix);
      fx.particles.setColorAt(n, fx.color.set(e.color));
      n++;
    } else if (e.kind === 'ring' || e.kind === 'lightning') {
      seen.add(e);
      let m = fx.meshes.get(e);
      if (!m) {
        m = e.kind === 'ring' ? makeRing(e) : makeLightning(e, toWorld, heights.tesla, heights.hit);
        fx.meshes.set(e, m);
        fx.scene.add(m);
      }
      const t = 1 - e.life / e.max;
      if (e.kind === 'ring') {
        const w = toWorld(e.x, e.y);
        const r = e.from + (e.radius - e.from) * t;
        m.position.set(w.x, heights.ring, w.z);
        m.scale.setScalar(Math.max(0.01, r));
        m.material.opacity = 1 - t;
      } else {
        m.children.forEach((c) => (c.material.opacity = 1 - t));
      }
    }
  }
  fx.particles.count = n;
  fx.particles.instanceMatrix.needsUpdate = true;
  if (fx.particles.instanceColor) fx.particles.instanceColor.needsUpdate = true;
  for (const [e, m] of fx.meshes) {
    if (!seen.has(e)) {
      fx.scene.remove(m);
      disposeObject(m);
      fx.meshes.delete(e);
    }
  }
}

export function clearFx(fx) {
  for (const m of fx.meshes.values()) {
    fx.scene.remove(m);
    disposeObject(m);
  }
  fx.meshes.clear();
  fx.particles.count = 0;
}

// 2D katman: project(x, y, h) → ekran pikseli ya da null.
export function drawOverlay(ctx, state, project, W, H, unit, enemyTops, lowHpRatio) {
  ctx.clearRect(0, 0, W, H);

  for (const e of state.enemies) {
    if (e.hp >= e.maxHp) continue;
    const p = project(e.x, e.y, enemyTops.get(e) ?? 0.6);
    if (!p) continue;
    const ratio = Math.max(0, e.hp / e.maxHp);
    const w = Math.max(unit * 0.5, e.radius * unit * 2.2);
    const h = Math.max(3, unit * 0.07);
    const x = p.x - w / 2;
    const y = p.y - h - 6;
    ctx.fillStyle = 'rgba(0,0,0,0.6)';
    ctx.fillRect(x - 1, y - 1, w + 2, h + 2);
    ctx.fillStyle = ratio <= lowHpRatio ? '#ff4d5e' : '#7cff6b';
    ctx.fillRect(x, y, w * ratio, h);
  }

  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  for (const e of state.effects) {
    if (e.kind !== 'text') continue;
    const t = 1 - e.life / e.max;
    const p = project(e.x, e.y, 0.7 + t * 0.6);
    if (!p) continue;
    ctx.globalAlpha = Math.max(0, Math.min(1, (e.life / e.max) * 1.5));
    ctx.font = `700 ${Math.round(unit * 0.4)}px Rajdhani, sans-serif`;
    ctx.lineWidth = 3;
    ctx.strokeStyle = 'rgba(0,0,0,0.7)';
    ctx.strokeText(e.text, p.x, p.y);
    ctx.fillStyle = e.color;
    ctx.fillText(e.text, p.x, p.y);
  }
  ctx.globalAlpha = 1;

  for (const e of state.effects) {
    if (e.kind !== 'banner') continue;
    const t = e.life / e.max;
    ctx.globalAlpha = Math.min(1, t * 4, (1 - t) * 8);
    const y = H * 0.4;
    const bh = Math.max(36, unit * 0.9);
    ctx.fillStyle = 'rgba(13,15,26,0.72)';
    ctx.fillRect(0, y - bh / 2, W, bh);
    ctx.font = `700 ${Math.round(Math.min(bh * 0.45, W / 18))}px Orbitron, sans-serif`;
    ctx.fillStyle = e.color;
    ctx.shadowColor = e.color;
    ctx.shadowBlur = 12;
    ctx.fillText(e.text, W / 2, y, W - 24);
    ctx.shadowBlur = 0;
    ctx.globalAlpha = 1;
  }
}
