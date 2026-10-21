import * as THREE from 'three';

// Çizgi film görünümü: renk paleti, toon malzeme ve kenar çizgisi yardımcıları.
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
  cobble: '#cdbf9f',
  cobbleDark: '#a89878',
  cobbleLight: '#e4d8bc',
  bushA: 0x4fae32,
  bushB: 0x7cc840,
  bushDark: 0x2f7a22,
  rock: 0xa9a49a,
  rockDark: 0x77736c,
  stone: 0xe2d4b6, // sur taşı
  stoneDark: 0xb9a783,
  lead: 0x7d8a99, // kurşun kaplı kubbe/külah
  leadDark: 0x5c6876,
  whitewash: 0xf4efe4,
  roofTile: 0xc4553a,
  wood: 0x9a6436,
  woodDark: 0x6e4424,
  gold: 0xe0b24a,
  ottomanRed: 0xb3202a,
  skin: 0xf0c9a0,
  sky: 0x1e2a18,
  outline: [0.08, 0.07, 0.05],
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

// Paylaşılan toon malzemeleri (renk başına bir tane)
const cache = new Map();
export function toonShared(color) {
  const key = typeof color === 'string' ? color : `#${color.toString(16).padStart(6, '0')}`;
  let m = cache.get(key);
  if (!m) {
    m = toon(color);
    cache.set(key, m);
  }
  return m;
}

// Kenar çizgisi istemeyen malzemeler (efektler, şeffaf yüzeyler, zemin)
export function noOutline(mat) {
  mat.userData.outlineParameters = { visible: false };
  return mat;
}

// Kırmızı zemin üstünde beyaz hilal ve yıldız (Osmanlı sancağı) dokusu
let ottomanFlagTex = null;
export function ottomanFlagTexture() {
  if (ottomanFlagTex) return ottomanFlagTex;
  const cv = document.createElement('canvas');
  cv.width = 128;
  cv.height = 84;
  const g = cv.getContext('2d');
  g.fillStyle = '#c8202c';
  g.fillRect(0, 0, 128, 84);
  g.fillStyle = '#ffffff';
  g.beginPath();
  g.arc(52, 42, 22, 0, Math.PI * 2);
  g.fill();
  g.fillStyle = '#c8202c';
  g.beginPath();
  g.arc(58, 42, 18, 0, Math.PI * 2);
  g.fill();
  g.fillStyle = '#ffffff';
  star(g, 80, 42, 10, 4.2);
  ottomanFlagTex = new THREE.CanvasTexture(cv);
  ottomanFlagTex.colorSpace = THREE.SRGBColorSpace;
  return ottomanFlagTex;
}

function star(g, cx, cy, R, r) {
  g.beginPath();
  for (let i = 0; i < 10; i++) {
    const a = -Math.PI / 2 + (i * Math.PI) / 5 + Math.PI / 2;
    const rad = i % 2 ? r : R;
    const x = cx + Math.cos(a) * rad;
    const y = cy + Math.sin(a) * rad;
    i ? g.lineTo(x, y) : g.moveTo(x, y);
  }
  g.closePath();
  g.fill();
}

// Devlet sancağı: iki renkli sade çizgili bez (gerçek bayrak değil)
export function nationFlagTexture(primary, secondary) {
  const cv = document.createElement('canvas');
  cv.width = 96;
  cv.height = 64;
  const g = cv.getContext('2d');
  g.fillStyle = primary;
  g.fillRect(0, 0, 96, 64);
  g.fillStyle = secondary;
  g.fillRect(0, 26, 96, 12);
  g.fillRect(40, 0, 12, 64);
  const t = new THREE.CanvasTexture(cv);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}
