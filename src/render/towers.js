import { TOWERS } from '../data/towers.js';

// Her kulenin çizimi kendi fonksiyonunda; ileride sprite ile değiştirilebilir.

function drawBase(ctx, T, color) {
  const R = T * 0.36;
  const oct = (r) => {
    ctx.beginPath();
    for (let k = 0; k < 8; k++) {
      const a = (k / 8) * Math.PI * 2 + Math.PI / 8;
      ctx[k ? 'lineTo' : 'moveTo'](Math.cos(a) * r, Math.sin(a) * r);
    }
    ctx.closePath();
  };
  // sağ alta düşen gölge
  ctx.fillStyle = 'rgba(10,3,2,0.45)';
  ctx.save();
  ctx.translate(R * 0.22, R * 0.28);
  oct(R * 1.02);
  ctx.fill();
  ctx.restore();
  // metal kaide: sol üstten ışık
  const g = ctx.createLinearGradient(-R, -R, R, R);
  g.addColorStop(0, '#9aa3bd');
  g.addColorStop(0.45, '#4f5772');
  g.addColorStop(1, '#22263a');
  ctx.fillStyle = g;
  oct(R);
  ctx.fill();
  ctx.strokeStyle = 'rgba(0,0,0,0.5)';
  ctx.lineWidth = Math.max(1, T * 0.02);
  ctx.stroke();
  // iç plaka
  const g2 = ctx.createLinearGradient(-R, -R, R, R);
  g2.addColorStop(0, '#3a4058');
  g2.addColorStop(1, '#2a2f44');
  ctx.fillStyle = g2;
  oct(R * 0.78);
  ctx.fill();
  // perçinler
  ctx.fillStyle = 'rgba(220,228,255,0.55)';
  for (let k = 0; k < 4; k++) {
    const a = (k / 4) * Math.PI * 2 + Math.PI / 4;
    ctx.beginPath();
    ctx.arc(Math.cos(a) * R * 0.88, Math.sin(a) * R * 0.88, Math.max(0.8, T * 0.018), 0, Math.PI * 2);
    ctx.fill();
  }
  // renkli ışık halkası
  ctx.strokeStyle = color;
  ctx.globalAlpha = 0.55;
  ctx.lineWidth = Math.max(1, T * 0.025);
  ctx.beginPath();
  ctx.arc(0, 0, R * 0.66, 0, Math.PI * 2);
  ctx.stroke();
  ctx.globalAlpha = 1;
}

function drawLevelDots(ctx, T, level, color) {
  const gap = T * 0.13;
  const y = T * 0.4;
  ctx.fillStyle = color;
  ctx.shadowColor = color;
  ctx.shadowBlur = T * 0.15;
  for (let i = 0; i < level; i++) {
    ctx.beginPath();
    ctx.arc((i - (level - 1) / 2) * gap, y, T * 0.04, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.shadowBlur = 0;
}

function drawLaser(ctx, t, T) {
  const c = TOWERS.laser.color;
  drawBase(ctx, T, c);
  ctx.save();
  ctx.rotate(t.angle);
  const back = t.recoil * T * 0.05;
  const bar = ctx.createLinearGradient(0, -T * 0.035, 0, T * 0.035);
  bar.addColorStop(0, '#c5cce0');
  bar.addColorStop(1, '#4f5772');
  ctx.fillStyle = bar;
  ctx.fillRect(-back, -T * 0.035, T * 0.42, T * 0.07);
  ctx.fillStyle = c;
  ctx.fillRect(T * 0.38 - back, -T * 0.045, T * 0.06, T * 0.09);
  ctx.fillStyle = '#6b7491';
  ctx.beginPath();
  ctx.arc(0, 0, T * 0.15, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = c;
  ctx.beginPath();
  ctx.arc(0, 0, T * 0.05, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

function drawPlasma(ctx, t, T, time) {
  const c = TOWERS.plasma.color;
  drawBase(ctx, T, c);
  ctx.save();
  ctx.rotate(t.angle);
  const back = t.recoil * T * 0.08;
  const bar = ctx.createLinearGradient(0, -T * 0.1, 0, T * 0.1);
  bar.addColorStop(0, '#9aa3bd');
  bar.addColorStop(1, '#2f3448');
  ctx.fillStyle = bar;
  ctx.fillRect(-back, -T * 0.1, T * 0.34, T * 0.2);
  ctx.fillStyle = '#2b3147';
  ctx.fillRect(T * 0.28 - back, -T * 0.12, T * 0.07, T * 0.24);
  ctx.fillStyle = '#4b5470';
  ctx.beginPath();
  ctx.arc(0, 0, T * 0.2, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = c;
  ctx.globalAlpha = 0.7 + 0.3 * Math.sin(time * 4 + t.id);
  ctx.shadowColor = c;
  ctx.shadowBlur = T * 0.25;
  ctx.beginPath();
  ctx.arc(0, 0, T * 0.09, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

function drawCryo(ctx, t, T, time) {
  const c = TOWERS.cryo.color;
  drawBase(ctx, T, c);
  ctx.save();
  // antenler
  ctx.strokeStyle = '#a9b6d6';
  ctx.lineWidth = Math.max(1, T * 0.025);
  for (const s of [-1, 1]) {
    ctx.beginPath();
    ctx.moveTo(s * T * 0.12, -T * 0.05);
    ctx.lineTo(s * T * 0.2, -T * 0.32);
    ctx.stroke();
    ctx.fillStyle = c;
    ctx.beginPath();
    ctx.arc(s * T * 0.2, -T * 0.32, T * 0.03, 0, Math.PI * 2);
    ctx.fill();
  }
  // kristal
  const h = T * (0.28 + 0.02 * Math.sin(time * 2 + t.id));
  const grad = ctx.createLinearGradient(0, -h, 0, h * 0.5);
  grad.addColorStop(0, '#e8fbff');
  grad.addColorStop(1, '#3fa9e0');
  ctx.fillStyle = grad;
  ctx.shadowColor = c;
  ctx.shadowBlur = T * 0.2;
  ctx.beginPath();
  ctx.moveTo(0, -h);
  ctx.lineTo(T * 0.13, -h * 0.2);
  ctx.lineTo(T * 0.08, h * 0.45);
  ctx.lineTo(-T * 0.08, h * 0.45);
  ctx.lineTo(-T * 0.13, -h * 0.2);
  ctx.closePath();
  ctx.fill();
  ctx.shadowBlur = 0;
  ctx.strokeStyle = 'rgba(255,255,255,0.6)';
  ctx.lineWidth = Math.max(1, T * 0.015);
  ctx.beginPath();
  ctx.moveTo(0, -h);
  ctx.lineTo(0, h * 0.45);
  ctx.stroke();
  ctx.restore();
}

function drawTesla(ctx, t, T, time) {
  const c = TOWERS.tesla.color;
  drawBase(ctx, T, c);
  ctx.save();
  // bobin
  ctx.fillStyle = '#2b3147';
  ctx.fillRect(-T * 0.07, -T * 0.3, T * 0.14, T * 0.42);
  for (let i = 0; i < 4; i++) {
    const y = T * 0.08 - i * T * 0.1;
    ctx.fillStyle = i % 2 ? '#b8743c' : '#d48a4a';
    ctx.beginPath();
    ctx.ellipse(0, y, T * (0.17 - i * 0.02), T * 0.04, 0, 0, Math.PI * 2);
    ctx.fill();
  }
  // enerji küresi
  const pulse = 0.5 + 0.5 * Math.sin(time * 6 + t.id);
  const r = T * (0.1 + 0.025 * pulse + 0.03 * t.recoil);
  const g = ctx.createRadialGradient(0, -T * 0.34, 0, 0, -T * 0.34, r * 2.2);
  g.addColorStop(0, '#ffffff');
  g.addColorStop(0.35, c);
  g.addColorStop(1, 'rgba(197,139,255,0)');
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.arc(0, -T * 0.34, r * 2.2, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

const DRAW = { laser: drawLaser, plasma: drawPlasma, cryo: drawCryo, tesla: drawTesla };

export function drawTower(ctx, t, T, time) {
  ctx.save();
  ctx.translate(t.x * T, t.y * T);
  DRAW[t.type](ctx, t, T, time);
  drawLevelDots(ctx, T, t.level, TOWERS[t.type].color);
  ctx.restore();
}

// Mermiler
function drawLaserBolt(ctx, p, T) {
  ctx.rotate(p.angle);
  ctx.strokeStyle = TOWERS.laser.color;
  ctx.shadowColor = TOWERS.laser.color;
  ctx.shadowBlur = T * 0.2;
  ctx.lineWidth = Math.max(1.5, T * 0.05);
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(-T * 0.18, 0);
  ctx.lineTo(T * 0.05, 0);
  ctx.stroke();
  ctx.strokeStyle = '#ffd6da';
  ctx.lineWidth = Math.max(1, T * 0.02);
  ctx.stroke();
}

function drawPlasmaBall(ctx, p, T) {
  const c = TOWERS.plasma.color;
  const g = ctx.createRadialGradient(0, 0, 0, 0, 0, T * 0.16);
  g.addColorStop(0, '#eafff8');
  g.addColorStop(0.4, c);
  g.addColorStop(1, 'rgba(61,255,192,0)');
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.arc(0, 0, T * 0.16, 0, Math.PI * 2);
  ctx.fill();
}

function drawCryoShard(ctx, p, T) {
  ctx.rotate(p.angle);
  ctx.fillStyle = '#d9f6ff';
  ctx.shadowColor = TOWERS.cryo.color;
  ctx.shadowBlur = T * 0.15;
  ctx.beginPath();
  ctx.moveTo(T * 0.09, 0);
  ctx.lineTo(0, T * 0.045);
  ctx.lineTo(-T * 0.09, 0);
  ctx.lineTo(0, -T * 0.045);
  ctx.closePath();
  ctx.fill();
}

const DRAW_PROJECTILE = { laser: drawLaserBolt, plasma: drawPlasmaBall, cryo: drawCryoShard };

export function drawProjectile(ctx, p, T) {
  ctx.save();
  ctx.translate(p.x * T, p.y * T);
  DRAW_PROJECTILE[p.type](ctx, p, T);
  ctx.restore();
}

export function drawRange(ctx, x, y, range, T, color) {
  ctx.save();
  ctx.fillStyle = color + '1a';
  ctx.strokeStyle = color;
  ctx.globalAlpha = 0.85;
  ctx.lineWidth = Math.max(1, T * 0.03);
  ctx.setLineDash([T * 0.15, T * 0.1]);
  ctx.beginPath();
  ctx.arc(x * T, y * T, range * T, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();
  ctx.restore();
}

export function drawSelection(ctx, c, r, T, time) {
  ctx.save();
  ctx.strokeStyle = '#5ee6d0';
  ctx.globalAlpha = 0.6 + 0.4 * Math.sin(time * 6);
  ctx.lineWidth = Math.max(1.5, T * 0.05);
  const m = T * 0.06;
  ctx.strokeRect(c * T + m, r * T + m, T - 2 * m, T - 2 * m);
  ctx.restore();
}
