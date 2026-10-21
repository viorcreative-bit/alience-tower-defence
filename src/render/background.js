// Zemin ve yol bir kez ayrı bir canvas'a çizilir; portal ve kale her karede.

function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

// Işık sol üstten gelir: gölgeler sağ alta düşer.
const LIGHT = { x: -0.6, y: -0.8 };

// Yumuşak lekeler için küçük rastgele dokuyu büyüterek çizer.
function mottle(g, W, H, rand, cells, alpha, dark, light) {
  const n = document.createElement('canvas');
  n.width = cells;
  n.height = Math.ceil((cells * H) / W);
  const ng = n.getContext('2d');
  const img = ng.createImageData(n.width, n.height);
  for (let i = 0; i < img.data.length; i += 4) {
    const v = rand();
    const c = v < 0.5 ? dark : light;
    img.data[i] = c[0];
    img.data[i + 1] = c[1];
    img.data[i + 2] = c[2];
    img.data[i + 3] = Math.abs(v - 0.5) * 2 * alpha * 255;
  }
  ng.putImageData(img, 0, 0);
  g.save();
  g.imageSmoothingEnabled = true;
  g.imageSmoothingQuality = 'high';
  g.drawImage(n, 0, 0, W, H);
  g.restore();
}

function drawCrater(g, x, y, r) {
  // dış sırt: ışık alan taraf açık, karşı taraf koyu
  const rim = g.createLinearGradient(x + LIGHT.x * r, y + LIGHT.y * r, x - LIGHT.x * r, y - LIGHT.y * r);
  rim.addColorStop(0, 'rgba(196,120,82,0.55)');
  rim.addColorStop(1, 'rgba(40,14,8,0.35)');
  g.fillStyle = rim;
  g.beginPath();
  g.ellipse(x, y, r * 1.18, r * 0.92, 0, 0, Math.PI * 2);
  g.fill();
  // çukur: ışık tarafı gölgede
  const pit = g.createLinearGradient(x + LIGHT.x * r, y + LIGHT.y * r, x - LIGHT.x * r, y - LIGHT.y * r);
  pit.addColorStop(0, '#2c120b');
  pit.addColorStop(0.55, '#4a2117');
  pit.addColorStop(1, '#8a4a32');
  g.fillStyle = pit;
  g.beginPath();
  g.ellipse(x, y, r, r * 0.78, 0, 0, Math.PI * 2);
  g.fill();
}

function drawRock(g, x, y, r, rand) {
  const pts = [];
  const n = 6 + Math.floor(rand() * 3);
  for (let k = 0; k < n; k++) {
    const a = (k / n) * Math.PI * 2;
    const rr = r * (0.7 + rand() * 0.45);
    pts.push([x + Math.cos(a) * rr, y + Math.sin(a) * rr * 0.75]);
  }
  const shape = (dx, dy) => {
    g.beginPath();
    pts.forEach(([px, py], i) => g[i ? 'lineTo' : 'moveTo'](px + dx, py + dy));
    g.closePath();
  };
  g.fillStyle = 'rgba(20,6,3,0.45)';
  shape(r * 0.35, r * 0.3);
  g.fill();
  const grad = g.createLinearGradient(x + LIGHT.x * r, y + LIGHT.y * r, x - LIGHT.x * r, y - LIGHT.y * r);
  grad.addColorStop(0, '#b0694a');
  grad.addColorStop(0.5, '#6e3524');
  grad.addColorStop(1, '#3a180f');
  g.fillStyle = grad;
  shape(0, 0);
  g.fill();
}

function drawGround(g, map, T, rand, blocked) {
  const W = map.cols * T;
  const H = map.rows * T;
  const base = g.createLinearGradient(0, 0, W * 0.4, H);
  base.addColorStop(0, '#74402c');
  base.addColorStop(0.5, '#64331f');
  base.addColorStop(1, '#552a1d');
  g.fillStyle = base;
  g.fillRect(0, 0, W, H);

  mottle(g, W, H, rand, 10, 0.35, [40, 14, 8], [160, 90, 58]);
  mottle(g, W, H, rand, 36, 0.22, [50, 20, 12], [170, 100, 66]);

  // rüzgâr çizgileri
  g.strokeStyle = 'rgba(190,120,80,0.08)';
  g.lineWidth = Math.max(1, T * 0.03);
  for (let i = 0; i < 26; i++) {
    const x = rand() * W;
    const y = rand() * H;
    const l = T * (0.6 + rand() * 1.6);
    g.beginPath();
    g.moveTo(x, y);
    g.quadraticCurveTo(x + l * 0.5, y - T * 0.08, x + l, y + T * 0.03);
    g.stroke();
  }

  for (let i = 0; i < 10; i++) drawCrater(g, rand() * W, rand() * H, T * (0.12 + rand() * 0.38));
  for (let i = 0; i < 26; i++) drawRock(g, rand() * W, rand() * H, T * (0.05 + rand() * 0.11), rand);
  // çakıl
  for (let i = 0; i < 260; i++) {
    g.fillStyle = rand() < 0.5 ? 'rgba(30,10,5,0.4)' : 'rgba(200,130,90,0.35)';
    const r = Math.max(0.6, T * (0.008 + rand() * 0.02));
    g.beginPath();
    g.arc(rand() * W, rand() * H, r, 0, Math.PI * 2);
    g.fill();
  }

  // ince ızgara (kurulabilir kareler)
  g.strokeStyle = 'rgba(0,0,0,0.09)';
  g.lineWidth = 1;
  for (let c = 1; c < map.cols; c++) {
    g.beginPath();
    g.moveTo(c * T + 0.5, 0);
    g.lineTo(c * T + 0.5, H);
    g.stroke();
  }
  for (let r = 1; r < map.rows; r++) {
    g.beginPath();
    g.moveTo(0, r * T + 0.5);
    g.lineTo(W, r * T + 0.5);
    g.stroke();
  }

  // kale temeli
  for (const key of blocked) {
    const c = key % map.cols;
    const r = Math.floor(key / map.cols);
    g.fillStyle = '#2a2c36';
    g.fillRect(c * T, r * T, T, T);
    g.strokeStyle = 'rgba(255,255,255,0.06)';
    g.strokeRect(c * T + 2, r * T + 2, T - 4, T - 4);
  }
}

function polyline(g, pts, T) {
  g.beginPath();
  pts.forEach((p, i) => g[i ? 'lineTo' : 'moveTo'](p.x * T, p.y * T));
}

// Dik açılı yolu yana kaydırır (köşelerde gönye birleşimi).
function offsetPath(points, d) {
  const out = [];
  for (let i = 0; i < points.length; i++) {
    const prev = points[i - 1];
    const next = points[i + 1];
    let nx = 0;
    let ny = 0;
    for (const [a, b] of [[prev, points[i]], [points[i], next]]) {
      if (!a || !b) continue;
      const len = Math.hypot(b.x - a.x, b.y - a.y);
      const tx = (b.x - a.x) / len;
      const ty = (b.y - a.y) / len;
      if (nx === 0 && ny === 0) {
        nx = -ty;
        ny = tx;
      } else if (Math.abs(nx + ty) > 1e-6 || Math.abs(ny - tx) > 1e-6) {
        nx += -ty;
        ny += tx;
      }
    }
    out.push({ x: points[i].x + nx * d, y: points[i].y + ny * d });
  }
  return out;
}

function drawRoad(g, map, path, T, rand) {
  const W = map.cols * T;
  const H = map.rows * T;
  g.lineJoin = 'miter';
  g.lineCap = 'square';

  // kanyon gölgesi: ışığın tersine kaydırılmış koyu iz
  g.save();
  g.translate(T * 0.08, T * 0.1);
  g.strokeStyle = 'rgba(20,6,2,0.55)';
  g.lineWidth = T * 1.12;
  polyline(g, path.points, T);
  g.stroke();
  g.restore();

  // kanyon duvarları
  g.strokeStyle = '#4a2416';
  g.lineWidth = T * 1.04;
  polyline(g, path.points, T);
  g.stroke();
  g.strokeStyle = '#6d3c26';
  g.lineWidth = T * 0.94;
  polyline(g, path.points, T);
  g.stroke();

  // zemin: kumlu kanyon tabanı, ayrı katmanda dokulanır
  const floor = document.createElement('canvas');
  floor.width = Math.ceil(W);
  floor.height = Math.ceil(H);
  const f = floor.getContext('2d');
  f.lineJoin = 'miter';
  f.lineCap = 'square';
  f.strokeStyle = '#000';
  f.lineWidth = T * 0.82;
  polyline(f, path.points, T);
  f.stroke();
  f.globalCompositeOperation = 'source-in';
  const sand = f.createLinearGradient(0, 0, W, H);
  sand.addColorStop(0, '#b07c55');
  sand.addColorStop(1, '#93613f');
  f.fillStyle = sand;
  f.fillRect(0, 0, W, H);
  f.globalCompositeOperation = 'source-atop';
  mottle(f, W, H, rand, 30, 0.3, [90, 55, 32], [215, 170, 125]);
  for (let i = 0; i < 500; i++) {
    f.fillStyle = rand() < 0.5 ? 'rgba(70,40,22,0.35)' : 'rgba(235,200,160,0.35)';
    f.fillRect(rand() * W, rand() * H, Math.max(1, T * 0.025), Math.max(1, T * 0.025));
  }
  // tekerlek izleri
  f.lineCap = 'butt';
  for (const d of [-0.2, 0.2]) {
    f.strokeStyle = 'rgba(70,40,24,0.35)';
    f.lineWidth = Math.max(1.5, T * 0.09);
    polyline(f, offsetPath(path.points, d), T);
    f.stroke();
    f.strokeStyle = 'rgba(60,34,20,0.35)';
    f.lineWidth = Math.max(1, T * 0.012);
    f.setLineDash([T * 0.03, T * 0.05]);
    polyline(f, offsetPath(path.points, d), T);
    f.stroke();
    f.setLineDash([]);
  }
  // kenar gölgesi: duvarın tabana düşen gölgesi
  f.strokeStyle = 'rgba(40,18,8,0.35)';
  f.lineWidth = T * 0.12;
  polyline(f, offsetPath(path.points, -0.38), T);
  f.stroke();
  g.drawImage(floor, 0, 0, W, H);

  // ışık alan duvar kenarı
  g.strokeStyle = 'rgba(230,160,110,0.35)';
  g.lineWidth = Math.max(1, T * 0.03);
  polyline(g, offsetPath(path.points, 0.47), T);
  g.stroke();
}

function vignette(g, W, H) {
  const v = g.createRadialGradient(W / 2, H / 2, Math.min(W, H) * 0.35, W / 2, H / 2, Math.max(W, H) * 0.75);
  v.addColorStop(0, 'rgba(0,0,0,0)');
  v.addColorStop(1, 'rgba(8,4,10,0.45)');
  g.fillStyle = v;
  g.fillRect(0, 0, W, H);
}

export function createBackground(map, path, T, dpr) {
  const cv = document.createElement('canvas');
  cv.width = Math.round(map.cols * T * dpr);
  cv.height = Math.round(map.rows * T * dpr);
  const g = cv.getContext('2d');
  g.scale(dpr, dpr);
  const rand = rng(map.seed);
  drawGround(g, map, T, rand, path.blocked);
  drawRoad(g, map, path, T, rand);
  vignette(g, map.cols * T, map.rows * T);
  return cv;
}

// Portal: dönen mor-yeşil solucan deliği.
export function drawPortal(ctx, x, y, T, time) {
  const R = T * 0.62;
  ctx.save();
  ctx.translate(x * T, y * T);
  const glow = ctx.createRadialGradient(0, 0, 0, 0, 0, R * 1.5);
  glow.addColorStop(0, 'rgba(180,90,255,0.55)');
  glow.addColorStop(0.6, 'rgba(124,255,107,0.18)');
  glow.addColorStop(1, 'rgba(124,255,107,0)');
  ctx.fillStyle = glow;
  ctx.beginPath();
  ctx.arc(0, 0, R * 1.5, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = '#12061f';
  ctx.beginPath();
  ctx.ellipse(0, 0, R, R * 0.8, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.lineCap = 'round';
  for (let i = 0; i < 3; i++) {
    const a = time * (1.6 + i * 0.5) + (i * Math.PI * 2) / 3;
    ctx.strokeStyle = i % 2 ? '#7cff6b' : '#b45aff';
    ctx.lineWidth = T * (0.07 - i * 0.015);
    ctx.beginPath();
    ctx.ellipse(0, 0, R * (0.85 - i * 0.22), R * 0.8 * (0.85 - i * 0.22), 0, a, a + Math.PI * 1.1);
    ctx.stroke();
  }
  ctx.fillStyle = 'rgba(230,200,255,0.9)';
  ctx.beginPath();
  ctx.arc(0, 0, R * (0.12 + 0.04 * Math.sin(time * 5)), 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

// Nova Üssü kalesi: surlar, iki yan kule, ortada enerji kubbesi.
// (x, bottom) kalenin kapı merkezi ve zemin çizgisi; ratio = kalkan oranı.
export function drawFortress(ctx, x, bottom, T, time, ratio) {
  const power = Math.max(0.1, ratio) * (0.85 + 0.15 * Math.sin(time * 3));
  const X = x * T;
  const B = bottom * T;
  const u = T;
  ctx.save();

  // kalkan balonu
  if (ratio > 0) {
    const sh = ctx.createRadialGradient(X, B, u * 0.6, X, B, u * 1.75);
    sh.addColorStop(0, 'rgba(77,163,255,0)');
    sh.addColorStop(0.85, `rgba(77,163,255,${0.10 * power})`);
    sh.addColorStop(1, `rgba(150,210,255,${0.35 * power})`);
    ctx.fillStyle = sh;
    ctx.beginPath();
    ctx.arc(X, B, u * 1.75, Math.PI, 0);
    ctx.fill();
  }

  // gölge
  ctx.fillStyle = 'rgba(0,0,0,0.4)';
  ctx.beginPath();
  ctx.ellipse(X + u * 0.1, B - u * 0.05, u * 1.6, u * 0.22, 0, 0, Math.PI * 2);
  ctx.fill();

  const metal = (x0, x1) => {
    const g = ctx.createLinearGradient(x0, 0, x1, 0);
    g.addColorStop(0, '#8a93ad');
    g.addColorStop(0.35, '#5b6380');
    g.addColorStop(1, '#262a3a');
    return g;
  };

  // sur duvarı
  const wallTop = B - u * 0.62;
  ctx.fillStyle = metal(X - u * 1.45, X + u * 1.45);
  ctx.beginPath();
  ctx.moveTo(X - u * 1.45, B);
  ctx.lineTo(X - u * 1.38, wallTop);
  ctx.lineTo(X + u * 1.38, wallTop);
  ctx.lineTo(X + u * 1.45, B);
  ctx.closePath();
  ctx.fill();
  // mazgallar
  ctx.fillStyle = '#3a4058';
  for (let i = -5; i <= 5; i++) {
    if (Math.abs(i) < 2) continue;
    ctx.fillRect(X + i * u * 0.24 - u * 0.07, wallTop - u * 0.1, u * 0.14, u * 0.12);
  }
  // panel çizgileri ve pencereler
  ctx.strokeStyle = 'rgba(0,0,0,0.35)';
  ctx.lineWidth = 1;
  for (let i = -5; i <= 5; i++) {
    ctx.beginPath();
    ctx.moveTo(X + i * u * 0.26, wallTop + u * 0.04);
    ctx.lineTo(X + i * u * 0.27, B);
    ctx.stroke();
  }
  ctx.fillStyle = `rgba(120,220,255,${0.35 + 0.5 * power})`;
  for (const i of [-4, -3, 3, 4]) {
    ctx.fillRect(X + i * u * 0.26 - u * 0.05, wallTop + u * 0.2, u * 0.1, u * 0.06);
  }
  ctx.fillStyle = 'rgba(255,255,255,0.18)';
  ctx.fillRect(X - u * 1.38, wallTop, u * 2.76, Math.max(1, u * 0.03));

  // yan kuleler
  for (const s of [-1, 1]) {
    const cx = X + s * u * 1.18;
    const top = B - u * 1.15;
    const w = u * 0.42;
    ctx.fillStyle = metal(cx - w / 2, cx + w / 2);
    ctx.fillRect(cx - w / 2, top, w, B - top);
    ctx.fillStyle = '#9aa3bd';
    ctx.beginPath();
    ctx.ellipse(cx, top, w / 2, w * 0.18, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#2f3448';
    ctx.fillRect(cx - w * 0.55, top + u * 0.1, w * 1.1, u * 0.07);
    // anten ve yanıp sönen ışık
    ctx.strokeStyle = '#aab3cc';
    ctx.lineWidth = Math.max(1, u * 0.025);
    ctx.beginPath();
    ctx.moveTo(cx, top);
    ctx.lineTo(cx, top - u * 0.28);
    ctx.stroke();
    const blink = Math.sin(time * 4 + s) > 0.2;
    ctx.fillStyle = blink ? '#ff4d5e' : '#5a1e26';
    if (blink) {
      ctx.shadowColor = '#ff4d5e';
      ctx.shadowBlur = u * 0.25;
    }
    ctx.beginPath();
    ctx.arc(cx, top - u * 0.3, Math.max(1.2, u * 0.045), 0, Math.PI * 2);
    ctx.fill();
    ctx.shadowBlur = 0;
    ctx.fillStyle = `rgba(120,220,255,${0.3 + 0.5 * power})`;
    ctx.fillRect(cx - w * 0.15, top + u * 0.3, w * 0.3, u * 0.08);
    ctx.fillRect(cx - w * 0.15, top + u * 0.5, w * 0.3, u * 0.08);
  }

  // kapı: enerji alanı
  const gateW = u * 0.5;
  ctx.fillStyle = '#11131d';
  ctx.beginPath();
  ctx.moveTo(X - gateW / 2, B);
  ctx.lineTo(X - gateW / 2, B - u * 0.3);
  ctx.arc(X, B - u * 0.3, gateW / 2, Math.PI, 0);
  ctx.lineTo(X + gateW / 2, B);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = `rgba(77,163,255,${0.25 + 0.45 * power})`;
  ctx.fill();

  // enerji kubbesi
  const domeY = wallTop + u * 0.02;
  const R = u * 0.5;
  const glow = ctx.createRadialGradient(X, domeY - R * 0.3, 0, X, domeY - R * 0.3, R * 2.2);
  glow.addColorStop(0, `rgba(77,163,255,${0.55 * power})`);
  glow.addColorStop(1, 'rgba(77,163,255,0)');
  ctx.fillStyle = glow;
  ctx.beginPath();
  ctx.arc(X, domeY - R * 0.3, R * 2.2, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#3a4058';
  ctx.fillRect(X - R * 1.15, domeY - u * 0.04, R * 2.3, u * 0.1);
  const dome = ctx.createRadialGradient(X - R * 0.35, domeY - R * 0.6, R * 0.05, X, domeY, R);
  dome.addColorStop(0, `rgba(230,245,255,${0.5 + 0.5 * power})`);
  dome.addColorStop(0.5, `rgba(77,163,255,${0.35 + 0.6 * power})`);
  dome.addColorStop(1, 'rgba(16,32,80,0.95)');
  ctx.fillStyle = dome;
  ctx.beginPath();
  ctx.arc(X, domeY - u * 0.04, R, Math.PI, 0);
  ctx.closePath();
  ctx.fill();
  ctx.strokeStyle = `rgba(150,210,255,${0.3 + 0.6 * power})`;
  ctx.lineWidth = Math.max(1, u * 0.025);
  ctx.stroke();
  // kubbe kafesi
  ctx.strokeStyle = 'rgba(200,230,255,0.25)';
  ctx.lineWidth = 1;
  for (const k of [-0.5, 0, 0.5]) {
    ctx.beginPath();
    ctx.ellipse(X, domeY - u * 0.04, R * Math.abs(Math.cos(k * 1.2)) || 1, R, 0, Math.PI, 0);
    ctx.stroke();
  }
  ctx.fillStyle = `rgba(210,240,255,${power})`;
  ctx.shadowColor = '#4da3ff';
  ctx.shadowBlur = u * 0.3 * power;
  ctx.beginPath();
  ctx.arc(X, domeY - R * 0.45, R * 0.18, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}
