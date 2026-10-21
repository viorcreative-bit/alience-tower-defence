import { RULES } from '../data/rules.js';
import { slowFactor } from '../systems/movement.js';

// Her uzaylının çizimi kendi fonksiyonunda. Hepsi aynı "klasik uzaylı" gövdesini
// (iri kel kafa, parlak siyah badem gözler, ince gövde) kendi rengi ve ekleriyle çizer.
// Koordinatlar: merkez (0,0), ekrana dik duruş; r = uzaylının yarıçapı (piksel).

function headPath(ctx, r, w, h, cy) {
  // geniş kubbe, sivri çene
  ctx.beginPath();
  ctx.moveTo(0, cy + h * 0.55);
  ctx.bezierCurveTo(-w * 0.35, cy + h * 0.5, -w * 0.62, cy + h * 0.12, -w * 0.6, cy - h * 0.12);
  ctx.bezierCurveTo(-w * 0.58, cy - h * 0.6, -w * 0.25, cy - h * 0.72, 0, cy - h * 0.72);
  ctx.bezierCurveTo(w * 0.25, cy - h * 0.72, w * 0.58, cy - h * 0.6, w * 0.6, cy - h * 0.12);
  ctx.bezierCurveTo(w * 0.62, cy + h * 0.12, w * 0.35, cy + h * 0.5, 0, cy + h * 0.55);
  ctx.closePath();
}

function drawEyes(ctx, r, w, h, cy, look) {
  for (const s of [-1, 1]) {
    ctx.save();
    ctx.translate(s * w * 0.24 + look * w * 0.04, cy + h * 0.02);
    ctx.rotate(s * 0.45);
    ctx.fillStyle = '#07080c';
    ctx.beginPath();
    ctx.ellipse(0, 0, w * 0.2, h * 0.13, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,0.85)';
    ctx.beginPath();
    ctx.ellipse(-w * 0.06, -h * 0.04, w * 0.06, h * 0.035, -0.3, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }
}

// Ortak gövde. p: { skin, light, shade, head, body, walk, lean, look }
function drawAlienBody(ctx, e, r, time, p) {
  const swing = Math.sin(time * p.walk + e.seed);
  const w = r * 2 * p.head;
  const h = r * 2.1 * p.head;
  const headCy = -r * 0.55;
  const bodyTop = headCy + h * 0.5;
  const bodyLen = r * 1.1 * p.body;
  const bulk = p.bulk || 1;
  const lw = Math.max(1.2, r * 0.16 * bulk);

  ctx.save();
  ctx.rotate(p.lean);
  ctx.lineCap = 'round';

  // bacaklar
  ctx.strokeStyle = p.shade;
  ctx.lineWidth = lw;
  for (const s of [-1, 1]) {
    ctx.beginPath();
    ctx.moveTo(s * r * 0.12, bodyTop + bodyLen * 0.8);
    ctx.lineTo(s * r * 0.2 + swing * s * r * 0.25, bodyTop + bodyLen * 1.35);
    ctx.stroke();
  }
  // gövde
  ctx.fillStyle = p.skin;
  ctx.beginPath();
  ctx.moveTo(-r * 0.12 * bulk, bodyTop);
  ctx.quadraticCurveTo(-r * 0.36 * bulk, bodyTop + bodyLen * 0.25, -r * 0.2 * bulk, bodyTop + bodyLen * 0.9);
  ctx.lineTo(r * 0.2 * bulk, bodyTop + bodyLen * 0.9);
  ctx.quadraticCurveTo(r * 0.36 * bulk, bodyTop + bodyLen * 0.25, r * 0.12 * bulk, bodyTop);
  ctx.closePath();
  ctx.fill();
  // kollar
  ctx.strokeStyle = p.skin;
  for (const s of [-1, 1]) {
    ctx.beginPath();
    ctx.moveTo(s * r * 0.26 * bulk, bodyTop + bodyLen * 0.2);
    ctx.lineTo(s * r * 0.42 * bulk - swing * s * r * 0.15, bodyTop + bodyLen * 0.85);
    ctx.stroke();
  }

  // kafa
  const g = ctx.createRadialGradient(-w * 0.15, headCy - h * 0.35, r * 0.05, 0, headCy, w * 0.7);
  g.addColorStop(0, p.light);
  g.addColorStop(0.6, p.skin);
  g.addColorStop(1, p.shade);
  ctx.fillStyle = g;
  headPath(ctx, r, w, h, headCy);
  ctx.fill();
  ctx.strokeStyle = 'rgba(0,0,0,0.35)';
  ctx.lineWidth = Math.max(1, r * 0.05);
  ctx.stroke();

  if (p.dome) p.dome(ctx, w, h, headCy);
  drawEyes(ctx, r, w, h, headCy, p.look);

  // burun ve gülümseme
  ctx.fillStyle = 'rgba(0,0,0,0.45)';
  for (const s of [-1, 1]) {
    ctx.beginPath();
    ctx.arc(s * w * 0.03, headCy + h * 0.22, Math.max(0.6, r * 0.025), 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.strokeStyle = 'rgba(0,0,0,0.55)';
  ctx.lineWidth = Math.max(0.8, r * 0.04);
  ctx.beginPath();
  ctx.arc(0, headCy + h * 0.24, w * 0.09, 0.25 * Math.PI, 0.75 * Math.PI);
  ctx.stroke();
  ctx.restore();
}

// Sürüngen: klasik yeşil uzaylı.
function drawReptile(ctx, e, T, time, look) {
  drawAlienBody(ctx, e, e.radius * T, time, {
    skin: '#7ccf4a', light: '#c9f59a', shade: '#3f7f25',
    head: 1, body: 1, walk: 10, lean: 0, look,
  });
}

// Akrep: turuncu, ince ve öne eğik koşan hızlı uzaylı, arkasında hız izleri.
function drawScorpion(ctx, e, T, time, look) {
  const r = e.radius * T;
  ctx.strokeStyle = 'rgba(255,170,80,0.45)';
  ctx.lineWidth = Math.max(1, r * 0.12);
  ctx.lineCap = 'round';
  for (let i = -1; i <= 1; i++) {
    ctx.beginPath();
    ctx.moveTo(-look * r * 0.9, i * r * 0.45 - r * 0.2);
    ctx.lineTo(-look * r * 1.6, i * r * 0.45 - r * 0.2);
    ctx.stroke();
  }
  drawAlienBody(ctx, e, r, time, {
    skin: '#ff9b3d', light: '#ffd9a0', shade: '#b4561a',
    head: 0.95, body: 1.1, walk: 24, lean: look * 0.3, look,
  });
}

// Kabuklu: gri-mor zırhlı uzaylı; omuz plakaları ve kafada zırh bandı.
function drawShell(ctx, e, T, time, look) {
  const r = e.radius * T;
  drawAlienBody(ctx, e, r, time, {
    skin: '#8e82a8', light: '#cfc6e0', shade: '#4e4566',
    head: 1, body: 1.05, walk: 5, lean: 0, look,
    dome(ctx, w, h, cy) {
      ctx.fillStyle = '#4a4060';
      ctx.beginPath();
      ctx.ellipse(0, cy - h * 0.42, w * 0.5, h * 0.2, 0, Math.PI, 0);
      ctx.fill();
      ctx.fillStyle = '#ffcf5a';
      ctx.beginPath();
      ctx.arc(0, cy - h * 0.5, Math.max(1, w * 0.04), 0, Math.PI * 2);
      ctx.fill();
    },
  });
  // göğüs ve omuz zırhı
  const top = -r * 0.55 + r * 2.1 * 0.5;
  ctx.fillStyle = '#5d5276';
  ctx.strokeStyle = '#2f2742';
  ctx.lineWidth = Math.max(1, r * 0.06);
  ctx.beginPath();
  ctx.moveTo(-r * 0.55, top + r * 0.05);
  ctx.lineTo(r * 0.55, top + r * 0.05);
  ctx.lineTo(r * 0.3, top + r * 0.75);
  ctx.lineTo(-r * 0.3, top + r * 0.75);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();
}

// Uçan Daire: metal disk, cam kubbede küçük bir uzaylı, yanıp sönen kenar ışıkları.
function drawSaucer(ctx, e, T, time) {
  const r = e.radius * T * 1.5;
  const bob = Math.sin(time * 5 + e.seed) * r * 0.12;
  ctx.save();
  ctx.translate(0, -r * 0.5 + bob);
  // çekim ışını
  const beam = ctx.createLinearGradient(0, 0, 0, r * 1.5);
  beam.addColorStop(0, 'rgba(124,255,107,0.35)');
  beam.addColorStop(1, 'rgba(124,255,107,0)');
  ctx.fillStyle = beam;
  ctx.beginPath();
  ctx.moveTo(-r * 0.35, r * 0.1);
  ctx.lineTo(r * 0.35, r * 0.1);
  ctx.lineTo(r * 0.7, r * 1.5);
  ctx.lineTo(-r * 0.7, r * 1.5);
  ctx.closePath();
  ctx.fill();
  // kubbe ve pilot
  const dome = ctx.createRadialGradient(-r * 0.2, -r * 0.55, r * 0.05, 0, -r * 0.3, r * 0.6);
  dome.addColorStop(0, 'rgba(230,250,255,0.9)');
  dome.addColorStop(1, 'rgba(90,160,200,0.55)');
  ctx.fillStyle = '#7ccf4a';
  ctx.beginPath();
  ctx.ellipse(0, -r * 0.32, r * 0.2, r * 0.24, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#07080c';
  for (const s of [-1, 1]) {
    ctx.beginPath();
    ctx.ellipse(s * r * 0.08, -r * 0.33, r * 0.065, r * 0.04, s * 0.45, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.fillStyle = dome;
  ctx.beginPath();
  ctx.arc(0, -r * 0.15, r * 0.48, Math.PI, 0);
  ctx.closePath();
  ctx.fill();
  // disk
  const disk = ctx.createLinearGradient(0, -r * 0.3, 0, r * 0.3);
  disk.addColorStop(0, '#e2e7f2');
  disk.addColorStop(0.45, '#8f98b0');
  disk.addColorStop(1, '#3a4058');
  ctx.fillStyle = disk;
  ctx.beginPath();
  ctx.ellipse(0, 0, r * 1.15, r * 0.36, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = 'rgba(0,0,0,0.4)';
  ctx.lineWidth = Math.max(1, r * 0.05);
  ctx.stroke();
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * Math.PI + 0.25;
    const on = Math.sin(time * 8 - i) > 0;
    ctx.fillStyle = on ? '#ffe066' : '#6b5a20';
    ctx.beginPath();
    ctx.arc(Math.cos(a) * r * 0.85, Math.sin(a) * r * 0.2, Math.max(0.8, r * 0.07), 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}

// Savaş Gemisi: zırh plakalı uzun gövde, yön değiştirince döner, arkada motor alevi.
function drawCruiser(ctx, e, T, time) {
  const r = e.radius * T * 1.25;
  ctx.save();
  ctx.translate(0, -r * 0.35);
  ctx.rotate(e.angle);
  // motor alevi
  const flame = r * (0.45 + 0.15 * Math.sin(time * 30 + e.seed));
  const fg = ctx.createLinearGradient(-r * 0.9, 0, -r * 0.9 - flame, 0);
  fg.addColorStop(0, 'rgba(120,220,255,0.95)');
  fg.addColorStop(1, 'rgba(120,120,255,0)');
  ctx.fillStyle = fg;
  for (const s of [-1, 1]) {
    ctx.beginPath();
    ctx.moveTo(-r * 0.85, s * r * 0.28 - r * 0.1);
    ctx.lineTo(-r * 0.9 - flame, s * r * 0.28);
    ctx.lineTo(-r * 0.85, s * r * 0.28 + r * 0.1);
    ctx.closePath();
    ctx.fill();
  }
  // kanatlar
  ctx.fillStyle = '#3e3550';
  ctx.beginPath();
  ctx.moveTo(-r * 0.2, 0);
  ctx.lineTo(-r * 0.8, -r * 0.85);
  ctx.lineTo(-r * 0.55, -r * 0.85);
  ctx.lineTo(r * 0.3, 0);
  ctx.lineTo(-r * 0.55, r * 0.85);
  ctx.lineTo(-r * 0.8, r * 0.85);
  ctx.closePath();
  ctx.fill();
  // gövde
  const hull = ctx.createLinearGradient(0, -r * 0.4, 0, r * 0.4);
  hull.addColorStop(0, '#b3a9c9');
  hull.addColorStop(0.5, '#6a5f86');
  hull.addColorStop(1, '#2c253d');
  ctx.fillStyle = hull;
  ctx.beginPath();
  ctx.moveTo(r * 1.15, 0);
  ctx.lineTo(r * 0.5, -r * 0.38);
  ctx.lineTo(-r * 0.9, -r * 0.42);
  ctx.lineTo(-r * 0.9, r * 0.42);
  ctx.lineTo(r * 0.5, r * 0.38);
  ctx.closePath();
  ctx.fill();
  ctx.strokeStyle = 'rgba(0,0,0,0.5)';
  ctx.lineWidth = Math.max(1, r * 0.05);
  ctx.stroke();
  // plaka çizgileri
  ctx.strokeStyle = 'rgba(20,14,30,0.6)';
  ctx.lineWidth = Math.max(1, r * 0.03);
  for (const x of [-0.5, -0.1, 0.3]) {
    ctx.beginPath();
    ctx.moveTo(r * x, -r * 0.38);
    ctx.lineTo(r * x, r * 0.38);
    ctx.stroke();
  }
  // kokpit
  ctx.fillStyle = '#7cff6b';
  ctx.shadowColor = '#7cff6b';
  ctx.shadowBlur = r * 0.4;
  ctx.beginPath();
  ctx.ellipse(r * 0.62, 0, r * 0.22, r * 0.12, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

// Dev: iri yapılı, geniş omuzlu koyu yeşil uzaylı; yavaş ve ağır adımlı.
function drawGiant(ctx, e, T, time, look) {
  drawAlienBody(ctx, e, e.radius * T, time, {
    skin: '#4f9a3a', light: '#a6e07e', shade: '#24521a',
    head: 0.8, body: 1.45, bulk: 2.1, walk: 3.5, lean: 0, look,
    dome(ctx, w, h, cy) {
      // alındaki yara izi
      ctx.strokeStyle = 'rgba(30,60,20,0.7)';
      ctx.lineWidth = Math.max(1, w * 0.03);
      ctx.beginPath();
      ctx.moveTo(-w * 0.2, cy - h * 0.5);
      ctx.lineTo(w * 0.05, cy - h * 0.3);
      ctx.stroke();
    },
  });
}

// Ana Beyin: dev uzaylı, şişkin pembe kafasında parlayan damarlı beyin.
function drawBrain(ctx, e, T, time, look) {
  const r = e.radius * T;
  const glow = 0.5 + 0.5 * Math.sin(time * 3 + e.seed);
  drawAlienBody(ctx, e, r, time, {
    skin: '#e0566f', light: '#ffc2cf', shade: '#8f2440',
    head: 1.15, body: 0.85, walk: 3, lean: 0, look,
    dome(ctx, w, h, cy) {
      ctx.save();
      ctx.strokeStyle = 'rgba(150,30,60,0.7)';
      ctx.lineWidth = Math.max(1, w * 0.025);
      ctx.beginPath();
      ctx.moveTo(0, cy - h * 0.7);
      ctx.lineTo(0, cy - h * 0.2);
      for (const s of [-1, 1]) {
        ctx.moveTo(s * w * 0.1, cy - h * 0.62);
        ctx.quadraticCurveTo(s * w * 0.4, cy - h * 0.55, s * w * 0.2, cy - h * 0.38);
        ctx.quadraticCurveTo(s * w * 0.45, cy - h * 0.32, s * w * 0.5, cy - h * 0.15);
      }
      ctx.stroke();
      ctx.strokeStyle = `rgba(255,240,120,${0.35 + 0.55 * glow})`;
      ctx.shadowColor = '#ffe066';
      ctx.shadowBlur = w * 0.15;
      ctx.lineWidth = Math.max(1, w * 0.018);
      ctx.beginPath();
      for (const s of [-1, 1]) {
        ctx.moveTo(s * w * 0.05, cy - h * 0.5);
        ctx.bezierCurveTo(s * w * 0.3, cy - h * 0.48, s * w * 0.15, cy - h * 0.3, s * w * 0.42, cy - h * 0.25);
      }
      ctx.stroke();
      ctx.restore();
    },
  });
}

const DRAW = {
  reptile: drawReptile,
  scorpion: drawScorpion,
  shell: drawShell,
  saucer: drawSaucer,
  cruiser: drawCruiser,
  giant: drawGiant,
  brain: drawBrain,
};

function drawHealthBar(ctx, e, T) {
  if (e.hp >= e.maxHp) return;
  const ratio = Math.max(0, e.hp / e.maxHp);
  const w = Math.max(T * 0.5, e.radius * T * 2);
  const h = Math.max(3, T * 0.07);
  const x = e.x * T - w / 2;
  const y = (e.y - e.radius * 1.75) * T - h - T * 0.04;
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
  ctx.ellipse(0, r * 1.05, r * 0.75, r * 0.28, 0, 0, Math.PI * 2);
  ctx.fill();
  // Uzaylılar ekrana dik durur; yürüdükleri yöne göre sağa/sola bakar.
  const look = Math.abs(Math.cos(e.angle)) > 0.5 ? Math.sign(Math.cos(e.angle)) : 0;
  DRAW[e.type](ctx, e, T, time, look);
  if (slowFactor(e) > 0) {
    ctx.strokeStyle = 'rgba(127,216,255,0.75)';
    ctx.lineWidth = Math.max(1, T * 0.03);
    ctx.beginPath();
    ctx.ellipse(0, -r * 0.3, r * 1.15, r * 1.6, 0, 0, Math.PI * 2);
    ctx.stroke();
  }
  if (e.flash > 0) {
    ctx.globalAlpha = Math.min(1, e.flash / RULES.hitFlashTime) * 0.75;
    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.ellipse(0, -r * 0.55, r * 1.05, r * 1.1, 0, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
  drawHealthBar(ctx, e, T);
}
