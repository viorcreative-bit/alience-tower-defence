// Zemin ve yol bir kez ayrı bir canvas'a çizilir; portal ve çekirdek her karede.

function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

function drawGround(g, map, T, rand) {
  const W = map.cols * T;
  const H = map.rows * T;
  const grad = g.createLinearGradient(0, 0, W, H);
  grad.addColorStop(0, '#6b3626');
  grad.addColorStop(1, '#5a2e22');
  g.fillStyle = grad;
  g.fillRect(0, 0, W, H);

  // ton lekeleri
  for (let i = 0; i < 40; i++) {
    g.fillStyle = rand() < 0.5 ? 'rgba(40,14,8,0.10)' : 'rgba(150,80,50,0.08)';
    g.beginPath();
    g.ellipse(rand() * W, rand() * H, T * (0.5 + rand() * 1.5), T * (0.3 + rand()), rand() * 3, 0, Math.PI * 2);
    g.fill();
  }

  // kraterler
  for (let i = 0; i < 9; i++) {
    const x = rand() * W;
    const y = rand() * H;
    const r = T * (0.15 + rand() * 0.35);
    g.fillStyle = 'rgba(30,10,6,0.35)';
    g.beginPath();
    g.ellipse(x, y, r, r * 0.75, 0, 0, Math.PI * 2);
    g.fill();
    g.strokeStyle = 'rgba(170,95,60,0.35)';
    g.lineWidth = Math.max(1, T * 0.04);
    g.beginPath();
    g.ellipse(x, y + r * 0.08, r, r * 0.75, 0, Math.PI * 0.1, Math.PI * 0.9);
    g.stroke();
  }

  // küçük kayalar
  for (let i = 0; i < 70; i++) {
    const x = rand() * W;
    const y = rand() * H;
    const r = T * (0.03 + rand() * 0.07);
    g.fillStyle = rand() < 0.5 ? '#4a2419' : '#7d4430';
    g.beginPath();
    for (let k = 0; k < 6; k++) {
      const a = (k / 6) * Math.PI * 2;
      const rr = r * (0.7 + rand() * 0.5);
      g[k ? 'lineTo' : 'moveTo'](x + Math.cos(a) * rr, y + Math.sin(a) * rr * 0.8);
    }
    g.closePath();
    g.fill();
  }

  // ince ızgara
  g.strokeStyle = 'rgba(0,0,0,0.10)';
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
}

function strokePath(g, path, T) {
  g.beginPath();
  path.points.forEach((p, i) => g[i ? 'lineTo' : 'moveTo'](p.x * T, p.y * T));
  g.stroke();
}

function drawRoad(g, map, path, T, rand) {
  g.lineJoin = 'miter';
  g.lineCap = 'square';
  g.strokeStyle = 'rgba(25,8,4,0.55)';
  g.lineWidth = T * 1.08;
  strokePath(g, path, T);
  g.strokeStyle = '#7d5238';
  g.lineWidth = T * 0.96;
  strokePath(g, path, T);
  g.strokeStyle = '#9a6a4a';
  g.lineWidth = T * 0.82;
  strokePath(g, path, T);

  // metal levhalar: her yol karesinde perçinli plaka
  for (const key of path.tiles) {
    const c = key % map.cols;
    const r = Math.floor(key / map.cols);
    const x = c * T;
    const y = r * T;
    const m = T * 0.18;
    g.strokeStyle = 'rgba(60,35,22,0.35)';
    g.lineWidth = Math.max(1, T * 0.025);
    g.strokeRect(x + m, y + m, T - 2 * m, T - 2 * m);
    g.fillStyle = 'rgba(210,170,130,0.35)';
    const rv = Math.max(1, T * 0.03);
    for (const [px, py] of [[x + m, y + m], [x + T - m, y + m], [x + m, y + T - m], [x + T - m, y + T - m]]) {
      g.beginPath();
      g.arc(px, py, rv, 0, Math.PI * 2);
      g.fill();
    }
    if (rand() < 0.4) {
      g.fillStyle = 'rgba(60,35,22,0.25)';
      g.beginPath();
      g.arc(x + T * (0.3 + rand() * 0.4), y + T * (0.3 + rand() * 0.4), T * 0.05, 0, Math.PI * 2);
      g.fill();
    }
  }

  // tekerlek izi
  g.setLineDash([T * 0.22, T * 0.16]);
  g.strokeStyle = 'rgba(70,40,25,0.45)';
  g.lineWidth = Math.max(1, T * 0.05);
  strokePath(g, path, T);
  g.setLineDash([]);
}

export function createBackground(map, path, T, dpr) {
  const cv = document.createElement('canvas');
  cv.width = Math.round(map.cols * T * dpr);
  cv.height = Math.round(map.rows * T * dpr);
  const g = cv.getContext('2d');
  g.scale(dpr, dpr);
  const rand = rng(map.seed);
  drawGround(g, map, T, rand);
  drawRoad(g, map, path, T, rand);
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

// Enerji çekirdeği: kubbeli üs, kalkan oranına göre parlar.
export function drawCore(ctx, x, y, T, time, ratio) {
  const R = T * 0.62;
  const pulse = 0.85 + 0.15 * Math.sin(time * 3);
  const power = Math.max(0.08, ratio) * pulse;
  ctx.save();
  ctx.translate(x * T, y * T);

  const glow = ctx.createRadialGradient(0, -R * 0.2, 0, 0, -R * 0.2, R * 1.8);
  glow.addColorStop(0, `rgba(77,163,255,${0.6 * power})`);
  glow.addColorStop(1, 'rgba(77,163,255,0)');
  ctx.fillStyle = glow;
  ctx.beginPath();
  ctx.arc(0, -R * 0.2, R * 1.8, 0, Math.PI * 2);
  ctx.fill();

  // taban
  ctx.fillStyle = '#2a3048';
  ctx.beginPath();
  ctx.moveTo(-R * 1.15, R * 0.45);
  ctx.lineTo(-R * 0.95, R * 0.05);
  ctx.lineTo(R * 0.95, R * 0.05);
  ctx.lineTo(R * 1.15, R * 0.45);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = '#4b5578';
  ctx.fillRect(-R * 0.95, R * 0.02, R * 1.9, R * 0.08);

  // kubbe
  const dome = ctx.createRadialGradient(-R * 0.25, -R * 0.4, R * 0.05, 0, 0, R);
  dome.addColorStop(0, `rgba(220,240,255,${0.5 + 0.5 * power})`);
  dome.addColorStop(0.5, `rgba(77,163,255,${0.35 + 0.6 * power})`);
  dome.addColorStop(1, 'rgba(20,40,90,0.95)');
  ctx.fillStyle = dome;
  ctx.beginPath();
  ctx.arc(0, R * 0.05, R * 0.85, Math.PI, 0);
  ctx.closePath();
  ctx.fill();
  ctx.strokeStyle = `rgba(150,210,255,${0.3 + 0.6 * power})`;
  ctx.lineWidth = Math.max(1, T * 0.03);
  ctx.stroke();

  // çekirdek
  ctx.fillStyle = `rgba(200,235,255,${power})`;
  ctx.beginPath();
  ctx.arc(0, -R * 0.25, R * 0.18, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}
