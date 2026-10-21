import { RULES } from '../data/rules.js';
import { slowFactor } from '../systems/movement.js';

// Her uzaylının çizimi kendi fonksiyonunda. Koordinatlar: merkez (0,0), yön sağa (+x).

function drawReptile(ctx, e, T, time) {
  const r = e.radius * T;
  const step = Math.sin(time * 10 + e.seed) * r * 0.15;
  ctx.fillStyle = '#3e9e35';
  for (const s of [-1, 1]) {
    ctx.beginPath();
    ctx.ellipse(-r * 0.2 + s * step, s * r * 0.85, r * 0.3, r * 0.18, 0, 0, Math.PI * 2);
    ctx.fill();
  }
  const g = ctx.createRadialGradient(-r * 0.3, -r * 0.3, r * 0.1, 0, 0, r);
  g.addColorStop(0, '#b6ff9f');
  g.addColorStop(1, '#4fc43f');
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.arc(0, 0, r, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#ffffff';
  ctx.beginPath();
  ctx.arc(r * 0.35, 0, r * 0.38, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#16130f';
  ctx.beginPath();
  ctx.arc(r * 0.48, 0, r * 0.18, 0, Math.PI * 2);
  ctx.fill();
}

function drawScorpion(ctx, e, T, time) {
  const r = e.radius * T;
  const wig = Math.sin(time * 22 + e.seed);
  // bacaklar
  ctx.strokeStyle = '#b8551c';
  ctx.lineWidth = Math.max(1, r * 0.18);
  for (let i = 0; i < 3; i++) {
    const x = r * (0.3 - i * 0.45);
    const k = (i % 2 ? 1 : -1) * wig * r * 0.25;
    for (const s of [-1, 1]) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x + k, s * r * 1.05);
      ctx.stroke();
    }
  }
  // kuyruk
  ctx.strokeStyle = '#ff8a2b';
  ctx.lineWidth = Math.max(1.5, r * 0.32);
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(-r * 0.6, 0);
  ctx.quadraticCurveTo(-r * 1.6, wig * r * 0.3, -r * 1.3, -r * 0.8);
  ctx.stroke();
  ctx.fillStyle = '#ffd04d';
  ctx.beginPath();
  ctx.arc(-r * 1.3, -r * 0.8, r * 0.2, 0, Math.PI * 2);
  ctx.fill();
  // sivri gövde
  ctx.fillStyle = '#ff8a2b';
  ctx.beginPath();
  ctx.moveTo(r * 1.2, 0);
  ctx.lineTo(-r * 0.2, r * 0.7);
  ctx.lineTo(-r * 0.8, 0);
  ctx.lineTo(-r * 0.2, -r * 0.7);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = '#2a1206';
  ctx.beginPath();
  ctx.arc(r * 0.55, -r * 0.2, r * 0.12, 0, Math.PI * 2);
  ctx.arc(r * 0.55, r * 0.2, r * 0.12, 0, Math.PI * 2);
  ctx.fill();
}

function drawShell(ctx, e, T, time) {
  const r = e.radius * T;
  const step = Math.sin(time * 5 + e.seed) * r * 0.1;
  ctx.fillStyle = '#3d3550';
  for (const s of [-1, 1]) {
    for (const x of [-0.4, 0.3]) {
      ctx.beginPath();
      ctx.ellipse(r * x + s * step, s * r * 0.9, r * 0.22, r * 0.14, 0, 0, Math.PI * 2);
      ctx.fill();
    }
  }
  ctx.fillStyle = '#4a3f60';
  ctx.beginPath();
  ctx.arc(r * 0.75, 0, r * 0.35, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#ffcf5a';
  ctx.beginPath();
  ctx.arc(r * 0.95, -r * 0.13, r * 0.08, 0, Math.PI * 2);
  ctx.arc(r * 0.95, r * 0.13, r * 0.08, 0, Math.PI * 2);
  ctx.fill();
  const g = ctx.createRadialGradient(-r * 0.2, -r * 0.3, r * 0.1, 0, 0, r);
  g.addColorStop(0, '#a99cc0');
  g.addColorStop(1, '#5d5276');
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.ellipse(0, 0, r, r * 0.88, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = '#3a3150';
  ctx.lineWidth = Math.max(1, r * 0.1);
  for (const x of [-0.35, 0.15]) {
    ctx.beginPath();
    ctx.ellipse(r * x, 0, r * 0.25, r * 0.8, 0, -Math.PI / 2, Math.PI / 2);
    ctx.stroke();
  }
}

function drawBrain(ctx, e, T, time) {
  const r = e.radius * T;
  // dokunaçlar
  ctx.strokeStyle = '#a23050';
  ctx.lineCap = 'round';
  ctx.lineWidth = Math.max(2, r * 0.14);
  for (let i = 0; i < 6; i++) {
    const a = Math.PI * (0.7 + (i / 5) * 0.6);
    const w = Math.sin(time * 4 + i + e.seed) * r * 0.35;
    const x0 = Math.cos(a) * r * 0.7;
    const y0 = Math.sin(a) * r * 0.7;
    ctx.beginPath();
    ctx.moveTo(x0, y0);
    ctx.quadraticCurveTo(x0 * 1.6, y0 * 1.6 + w, x0 * 2, y0 * 1.9 - w);
    ctx.stroke();
  }
  const g = ctx.createRadialGradient(-r * 0.3, -r * 0.3, r * 0.1, 0, 0, r);
  g.addColorStop(0, '#ffb3c4');
  g.addColorStop(1, '#d93a5e');
  ctx.fillStyle = g;
  ctx.beginPath();
  for (let k = 0; k < 10; k++) {
    const a = (k / 10) * Math.PI * 2;
    ctx.arc(Math.cos(a) * r * 0.62, Math.sin(a) * r * 0.62, r * 0.42, 0, Math.PI * 2);
  }
  ctx.fill();
  // parlayan damarlar
  const glow = 0.5 + 0.5 * Math.sin(time * 3 + e.seed);
  ctx.strokeStyle = `rgba(255,240,120,${0.4 + 0.5 * glow})`;
  ctx.shadowColor = '#ffe066';
  ctx.shadowBlur = r * 0.4;
  ctx.lineWidth = Math.max(1, r * 0.06);
  ctx.beginPath();
  ctx.moveTo(-r * 0.9, 0);
  ctx.bezierCurveTo(-r * 0.3, -r * 0.3, r * 0.3, r * 0.3, r * 0.9, 0);
  ctx.moveTo(-r * 0.4, -r * 0.7);
  ctx.quadraticCurveTo(-r * 0.1, -r * 0.2, -r * 0.5, r * 0.3);
  ctx.moveTo(r * 0.3, -r * 0.8);
  ctx.quadraticCurveTo(r * 0.5, -r * 0.3, r * 0.2, r * 0.6);
  ctx.stroke();
  ctx.shadowBlur = 0;
}

const DRAW = { reptile: drawReptile, scorpion: drawScorpion, shell: drawShell, brain: drawBrain };

function drawHealthBar(ctx, e, T) {
  if (e.hp >= e.maxHp) return;
  const ratio = Math.max(0, e.hp / e.maxHp);
  const w = Math.max(T * 0.5, e.radius * T * 2);
  const h = Math.max(3, T * 0.07);
  const x = e.x * T - w / 2;
  const y = (e.y - e.radius) * T - h - T * 0.1;
  ctx.fillStyle = 'rgba(0,0,0,0.6)';
  ctx.fillRect(x - 1, y - 1, w + 2, h + 2);
  ctx.fillStyle = ratio <= RULES.lowHpRatio ? '#ff4d5e' : '#7cff6b';
  ctx.fillRect(x, y, w * ratio, h);
}

export function drawEnemy(ctx, e, T, time) {
  const r = e.radius * T;
  ctx.save();
  ctx.translate(e.x * T, e.y * T);
  ctx.fillStyle = 'rgba(0,0,0,0.3)';
  ctx.beginPath();
  ctx.ellipse(0, r * 0.5, r * 1.05, r * 0.55, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.save();
  ctx.rotate(e.angle);
  DRAW[e.type](ctx, e, T, time);
  ctx.restore();
  if (slowFactor(e) > 0) {
    ctx.strokeStyle = 'rgba(127,216,255,0.75)';
    ctx.lineWidth = Math.max(1, T * 0.03);
    ctx.beginPath();
    ctx.arc(0, 0, r * 1.25, 0, Math.PI * 2);
    ctx.stroke();
  }
  if (e.flash > 0) {
    ctx.globalAlpha = Math.min(1, e.flash / RULES.hitFlashTime) * 0.75;
    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.arc(0, 0, r * 1.05, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
  drawHealthBar(ctx, e, T);
}
