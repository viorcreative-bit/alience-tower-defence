import { PALETTE } from './palette.js';

// Zemin ve yol dokusu (çizgi film tarzı): bir kez 2D canvas'a çizilir, 3D zemine kaplanır.

function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

// Çim zemini. wrap: kenardan taşan lekeler karşı kenarda da çizilir (döşenebilir doku).
// Yoğunluklar kare başına verilir ki tahta ve çevresindeki çim aynı görünsün.
function drawGround(g, cols, rows, T, rand, { wrap = false, grid = false } = {}) {
  const W = cols * T;
  const H = rows * T;
  const area = cols * rows;
  const offsets = wrap ? [-1, 0, 1] : [0];
  const each = (x, y, draw) => {
    for (const ox of offsets) for (const oy of offsets) draw(x + ox * W, y + oy * H);
  };
  g.fillStyle = PALETTE.ground;
  g.fillRect(0, 0, W, H);
  // açık/koyu çim lekeleri
  g.globalAlpha = 0.25;
  for (let i = 0; i < area * 4; i++) {
    g.fillStyle = rand() < 0.5 ? PALETTE.groundLight : PALETTE.groundDark;
    const r = T * (0.19 + rand() * 0.56);
    each(rand() * W, rand() * H, (x, y) => {
      g.beginPath();
      g.arc(x, y, r, 0, Math.PI * 2);
      g.fill();
    });
  }
  g.globalAlpha = 1;

  // çizgi film tarzı küçük çim tutamları ve benekler
  g.lineCap = 'round';
  g.lineWidth = Math.max(1, T * 0.025);
  for (let i = 0; i < area * 0.7; i++) {
    const s = T * (0.05 + rand() * 0.06);
    g.strokeStyle = rand() < 0.5 ? PALETTE.groundDark : PALETTE.speck;
    each(rand() * W, rand() * H, (x, y) => {
      g.beginPath();
      g.moveTo(x - s, y);
      g.lineTo(x - s * 0.6, y - s);
      g.moveTo(x, y);
      g.lineTo(x, y - s * 1.3);
      g.moveTo(x + s, y);
      g.lineTo(x + s * 0.6, y - s);
      g.stroke();
    });
  }
  for (let i = 0; i < area * 1.3; i++) {
    g.fillStyle = rand() < 0.6 ? 'rgba(40,90,20,0.4)' : 'rgba(210,245,150,0.35)';
    const r = T * (0.012 + rand() * 0.02);
    each(rand() * W, rand() * H, (x, y) => {
      g.beginPath();
      g.arc(x, y, r, 0, Math.PI * 2);
      g.fill();
    });
  }

  if (!grid) return;
  // çok hafif ızgara: kule kurulacak kareleri seçmeyi kolaylaştırır
  g.strokeStyle = 'rgba(20,60,10,0.06)';
  g.lineWidth = 1;
  for (let c = 1; c < cols; c++) {
    g.beginPath();
    g.moveTo(c * T + 0.5, 0);
    g.lineTo(c * T + 0.5, H);
    g.stroke();
  }
  for (let r = 1; r < rows; r++) {
    g.beginPath();
    g.moveTo(0, r * T + 0.5);
    g.lineTo(W, r * T + 0.5);
    g.stroke();
  }
}

function polyline(g, pts, T) {
  g.beginPath();
  pts.forEach((p, i) => g[i ? 'lineTo' : 'moveTo'](p.x * T, p.y * T));
}

// Geniş, yuvarlak köşeli, yumuşak kenarlı kumlu yol.
function drawRoad(g, map, path, T, rand) {
  g.lineJoin = 'round';
  g.lineCap = 'butt';
  g.save();
  g.shadowColor = PALETTE.pathShadow;
  g.shadowBlur = T * 0.25;
  g.strokeStyle = PALETTE.pathEdge;
  g.lineWidth = T * 1.0;
  polyline(g, path.points, T);
  g.stroke();
  g.restore();

  g.strokeStyle = PALETTE.path;
  g.lineWidth = T * 0.86;
  polyline(g, path.points, T);
  g.stroke();
  g.save();
  g.filter = `blur(${Math.round(T * 0.12)}px)`;
  g.strokeStyle = PALETTE.pathLight;
  g.lineWidth = T * 0.45;
  polyline(g, path.points, T);
  g.stroke();
  g.restore();

  // yol üstünde çakıl taşları
  for (let i = 0; i < 120; i++) {
    const d = rand() * path.length;
    const seg = path.segments.find((s) => d >= s.start && d < s.start + s.len) || path.segments[0];
    const t = d - seg.start;
    const off = (rand() - 0.5) * 0.7;
    const x = (seg.x + seg.dx * t - seg.dy * off) * T;
    const y = (seg.y + seg.dy * t + seg.dx * off) * T;
    g.fillStyle = rand() < 0.5 ? PALETTE.pebble : PALETTE.pathEdge;
    g.beginPath();
    g.ellipse(x, y, T * (0.02 + rand() * 0.025), T * (0.015 + rand() * 0.015), rand() * 3, 0, Math.PI * 2);
    g.fill();
  }
}

export function createBackground(map, path, T, dpr) {
  const cv = document.createElement('canvas');
  cv.width = Math.round(map.cols * T * dpr);
  cv.height = Math.round(map.rows * T * dpr);
  const g = cv.getContext('2d');
  g.scale(dpr, dpr);
  const rand = rng(map.seed);
  drawGround(g, map.cols, map.rows, T, rand, { grid: true });
  drawRoad(g, map, path, T, rand);
  return cv;
}

// Tahtanın çevresi için döşenebilir çim dokusu (tiles × tiles kare).
export function createGrassTile(tiles, T, seed) {
  const cv = document.createElement('canvas');
  cv.width = cv.height = tiles * T;
  drawGround(cv.getContext('2d'), tiles, tiles, T, rng(seed), { wrap: true });
  return cv;
}
