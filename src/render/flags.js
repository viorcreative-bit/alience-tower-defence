import * as THREE from 'three';

// Rüzgârda dalgalanan sancaklar: dalga köşe gölgelendiricisinde hesaplanır, tüm sancaklar tek zaman değerini paylaşır.
// Sancak direğe sol kenarından bağlıdır (yerel x = 0), sağa doğru uzanır.

const shared = { time: { value: 0 } };
const geo = new THREE.PlaneGeometry(1, 1, 10, 2).translate(0.5, 0, 0);
const mats = new Map();

function waving(tex) {
  let m = mats.get(tex);
  if (m) return m;
  m = new THREE.MeshStandardMaterial({ map: tex, side: THREE.DoubleSide, roughness: 0.9 });
  m.onBeforeCompile = (shader) => {
    shader.uniforms.uFlagTime = shared.time;
    shader.vertexShader = shader.vertexShader
      .replace('#include <common>', '#include <common>\nuniform float uFlagTime;')
      .replace(
        '#include <begin_vertex>',
        `#include <begin_vertex>
        float k = position.x;
        float ph = uFlagTime * 5.0 + position.x * 5.5 + modelMatrix[3].x * 1.7;
        transformed.z += sin(ph) * 0.12 * k;
        transformed.y += sin(ph * 0.7 + 1.3) * 0.04 * k;`,
      );
  };
  mats.set(tex, m);
  return m;
}

// w × h boyutunda sancak; döndürülen ağ direğin tepesine konur
export function flagMesh(tex, w, h) {
  const f = new THREE.Mesh(geo, waving(tex));
  f.scale.set(w, h, w);
  f.userData.dynamic = true;
  return f;
}

// Var olan bir sancağın dokusunu değiştirir (ordugâh sancağı dalgadan dalgaya)
export function setFlagTexture(f, tex) {
  f.material = waving(tex);
}

export function tickFlags(time) {
  shared.time.value = time;
}
