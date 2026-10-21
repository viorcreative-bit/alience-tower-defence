import * as THREE from 'three';

// Sadece görüntüye ait canlılık: duman, kıvılcım ve kuşlar. Oyun mantığına girmez,
// gerçek zamanla akar. Parçacıklar iki nokta bulutunda çizilir (duman ve kıvılcım, toplam 2 çizim).

function softDot() {
  const c = document.createElement('canvas');
  c.width = c.height = 64;
  const g = c.getContext('2d');
  const grad = g.createRadialGradient(32, 32, 0, 32, 32, 32);
  grad.addColorStop(0, 'rgba(255,255,255,1)');
  grad.addColorStop(0.45, 'rgba(255,255,255,0.65)');
  grad.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = grad;
  g.fillRect(0, 0, 64, 64);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

const vertexShader = /* glsl */ `
  attribute float aSize;
  attribute float aAlpha;
  attribute vec3 aColor;
  uniform float uScale;
  varying float vAlpha;
  varying vec3 vColor;
  void main() {
    vec4 mv = modelViewMatrix * vec4(position, 1.0);
    gl_Position = projectionMatrix * mv;
    gl_PointSize = aSize * uScale / -mv.z;
    vAlpha = aAlpha;
    vColor = aColor;
  }`;
const fragmentShader = /* glsl */ `
  uniform sampler2D uMap;
  varying float vAlpha;
  varying vec3 vColor;
  void main() {
    vec4 t = texture2D(uMap, gl_PointCoord);
    gl_FragColor = vec4(vColor, t.a * vAlpha);
    if (gl_FragColor.a < 0.01) discard;
  }`;

function layer(max, blending, map) {
  const geo = new THREE.BufferGeometry();
  const pos = new Float32Array(max * 3);
  const col = new Float32Array(max * 3);
  const size = new Float32Array(max);
  const alpha = new Float32Array(max);
  geo.setAttribute('position', new THREE.BufferAttribute(pos, 3).setUsage(THREE.DynamicDrawUsage));
  geo.setAttribute('aColor', new THREE.BufferAttribute(col, 3).setUsage(THREE.DynamicDrawUsage));
  geo.setAttribute('aSize', new THREE.BufferAttribute(size, 1).setUsage(THREE.DynamicDrawUsage));
  geo.setAttribute('aAlpha', new THREE.BufferAttribute(alpha, 1).setUsage(THREE.DynamicDrawUsage));
  const uniforms = { uMap: { value: map }, uScale: { value: 400 } };
  const mat = new THREE.ShaderMaterial({
    uniforms, vertexShader, fragmentShader, transparent: true, depthWrite: false, blending,
  });
  const points = new THREE.Points(geo, mat);
  points.frustumCulled = false;
  return { points, geo, pos, col, size, alpha, uniforms, list: [], max };
}

// Parçacık türleri: başlangıç rengi, büyüme, yükselme, ömür
const KINDS = {
  smoke: { layer: 'smoke', life: 2.8, size: [0.35, 1.3], rise: 0.45, drift: 0.12, alpha: 0.75, color: [0.5, 0.48, 0.47] },
  chimney: { layer: 'smoke', life: 3.4, size: [0.18, 0.7], rise: 0.3, drift: 0.1, alpha: 0.45, color: [0.92, 0.92, 0.92] },
  puff: { layer: 'smoke', life: 1.2, size: [0.3, 1.0], rise: 0.25, drift: 0.5, alpha: 0.75, color: [0.9, 0.88, 0.84] },
  tarSmoke: { layer: 'smoke', life: 2.2, size: [0.25, 0.9], rise: 0.5, drift: 0.08, alpha: 0.7, color: [0.2, 0.17, 0.19] },
  ember: { layer: 'glow', life: 1.2, size: [0.1, 0.03], rise: 0.8, drift: 0.25, alpha: 1, color: [3.5, 1.3, 0.25] },
  spark: { layer: 'glow', life: 0.45, size: [0.12, 0.03], rise: 0.2, drift: 1.6, alpha: 1, color: [4, 2.4, 0.6] },
};

// Kuşlar: iki kanatlı küçük siluetler, savaş alanının üstünde geniş daireler çizer
function buildBirds(scene) {
  const mat = new THREE.MeshStandardMaterial({ color: 0x2d2622, side: THREE.DoubleSide, roughness: 1 });
  const wing = new THREE.BufferGeometry();
  wing.setAttribute('position', new THREE.Float32BufferAttribute([0, 0, -0.06, 0, 0, 0.06, 0.32, 0, 0.02], 3));
  wing.computeVertexNormals();
  const body = new THREE.SphereGeometry(0.05, 6, 4).scale(1, 0.8, 2.4);
  const birds = [];
  for (let i = 0; i < 7; i++) {
    const g = new THREE.Group();
    g.add(new THREE.Mesh(body, mat));
    const wings = [-1, 1].map((s) => {
      const w = new THREE.Mesh(wing, mat);
      w.scale.x = s;
      g.add(w);
      return w;
    });
    g.scale.setScalar(0.55 + (i % 3) * 0.1);
    scene.add(g);
    birds.push({ g, wings, phase: i * 0.9, radius: 2.2 + (i % 4) * 0.5, speed: 0.22 + (i % 3) * 0.03, height: 3.6 + (i % 2) * 0.5 });
  }
  return birds;
}

export function createAmbient(scene) {
  const map = softDot();
  const layers = {
    smoke: layer(420, THREE.NormalBlending, map),
    glow: layer(260, THREE.AdditiveBlending, map),
  };
  scene.add(layers.smoke.points, layers.glow.points);
  const birds = buildBirds(scene);
  const emitters = [];
  const v = new THREE.Vector3();

  function emit(kind, x, y, z, count = 1, spread = 0.05) {
    const k = KINDS[kind];
    const L = layers[k.layer];
    for (let i = 0; i < count; i++) {
      if (L.list.length >= L.max) return;
      const a = Math.random() * Math.PI * 2;
      const d = k.drift * (0.4 + Math.random() * 0.8);
      L.list.push({
        k,
        x: x + (Math.random() - 0.5) * spread,
        y,
        z: z + (Math.random() - 0.5) * spread,
        vx: Math.cos(a) * d,
        vz: Math.sin(a) * d,
        vy: k.rise * (0.7 + Math.random() * 0.6),
        age: 0,
        life: k.life * (0.7 + Math.random() * 0.5),
      });
    }
  }

  // Sürekli kaynaklar: { x, y, z, kind, rate (sn başına), acc }
  function addEmitter(x, y, z, kind, rate) {
    const e = { x, y, z, kind, rate, acc: Math.random() };
    emitters.push(e);
    return e;
  }

  function removeEmitter(e) {
    const i = emitters.indexOf(e);
    if (i >= 0) emitters.splice(i, 1);
  }

  let last = null;
  function update(time, camera, viewHeight) {
    const dt = last === null ? 0 : Math.min(0.1, time - last);
    last = time;
    for (const e of emitters) {
      e.acc += e.rate * dt;
      while (e.acc >= 1) {
        e.acc -= 1;
        emit(e.kind, e.x, e.y, e.z);
      }
    }
    // nokta boyu: ekran yüksekliğine göre dünya biriminden piksele
    const scale = viewHeight / (2 * Math.tan((camera.fov * Math.PI) / 360));
    for (const L of Object.values(layers)) {
      L.uniforms.uScale.value = scale;
      let n = 0;
      L.list = L.list.filter((p) => (p.age += dt) < p.life);
      for (const p of L.list) {
        const t = p.age / p.life;
        p.x += p.vx * dt;
        p.z += p.vz * dt;
        p.y += p.vy * dt;
        p.vx *= 1 - 1.2 * dt;
        p.vz *= 1 - 1.2 * dt;
        const k = p.k;
        L.pos[n * 3] = p.x;
        L.pos[n * 3 + 1] = p.y;
        L.pos[n * 3 + 2] = p.z;
        L.col.set(k.color, n * 3);
        L.size[n] = k.size[0] + (k.size[1] - k.size[0]) * t;
        // belirip sönme
        L.alpha[n] = k.alpha * Math.min(1, t * 6) * (1 - t);
        n++;
      }
      L.geo.setDrawRange(0, n);
      for (const name of ['position', 'aColor', 'aSize', 'aAlpha']) L.geo.getAttribute(name).needsUpdate = true;
    }
    for (const b of birds) {
      const a = time * b.speed + b.phase;
      b.g.position.set(Math.cos(a) * b.radius, b.height + Math.sin(time * 0.7 + b.phase) * 0.15, Math.sin(a) * b.radius * 1.7 - 1.5);
      v.set(-Math.sin(a) * b.radius, 0, Math.cos(a) * b.radius * 1.7);
      b.g.rotation.y = Math.atan2(v.x, v.z);
      const flap = Math.sin(time * 9 + b.phase * 3) * 0.6;
      b.wings[0].rotation.z = flap;
      b.wings[1].rotation.z = -flap;
    }
  }

  function clear() {
    for (const L of Object.values(layers)) L.list.length = 0;
  }

  return { emit, addEmitter, removeEmitter, update, clear, layers };
}
