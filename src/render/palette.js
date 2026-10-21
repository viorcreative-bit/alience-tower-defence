import * as THREE from 'three';

// Çizgi film görünümü: renk paleti, toon malzeme ve kenar çizgisi yardımcıları.
// Zemin renkleri tek yerde; yeşil çimen gibi başka bir zemin buradan değiştirilir.
export const PALETTE = {
  ground: '#6fb33a',
  groundLight: '#8fcf4a',
  groundDark: '#4f8f2c',
  speck: '#3d7524',
  path: '#efd9a6',
  pathLight: '#fbecc6',
  pathEdge: '#c9a46e',
  pathShadow: 'rgba(40,70,20,0.6)',
  pebble: '#d8bd8a',
  bushA: 0x4fae32,
  bushB: 0x7cc840,
  bushDark: 0x2f7a22,
  rock: 0xa9a49a,
  rockDark: 0x77736c,
  sky: 0x1e2a18,
  outline: [0.08, 0.1, 0.05],
};

// 3 kademeli ışık: düz, çizgi film tarzı gölgelendirme
const gradientMap = (() => {
  const t = new THREE.DataTexture(new Uint8Array([90, 170, 255]), 3, 1, THREE.RedFormat);
  t.minFilter = THREE.NearestFilter;
  t.magFilter = THREE.NearestFilter;
  t.needsUpdate = true;
  return t;
})();

export function toon(color, opts = {}) {
  return new THREE.MeshToonMaterial({ color, gradientMap, ...opts });
}

// Kenar çizgisi istemeyen malzemeler (efektler, şeffaf yüzeyler, zemin)
export function noOutline(mat) {
  mat.userData.outlineParameters = { visible: false };
  return mat;
}
