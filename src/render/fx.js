// Parçacık, halka, şimşek ve yazı efektlerinin çizimi.

function drawParticle(ctx, e, T) {
  ctx.globalAlpha = Math.max(0, e.life / e.max);
  ctx.fillStyle = e.color;
  ctx.beginPath();
  ctx.arc(e.x * T, e.y * T, Math.max(1, e.size * T), 0, Math.PI * 2);
  ctx.fill();
}

function drawRingFx(ctx, e, T) {
  const t = 1 - e.life / e.max;
  ctx.globalAlpha = Math.max(0, 1 - t);
  ctx.strokeStyle = e.color;
  ctx.lineWidth = Math.max(1, T * 0.06 * (1 - t) + 1);
  ctx.beginPath();
  ctx.arc(e.x * T, e.y * T, (e.from + (e.radius - e.from) * t) * T, 0, Math.PI * 2);
  ctx.stroke();
}

function drawLightningFx(ctx, e, T) {
  ctx.globalAlpha = Math.max(0, e.life / e.max);
  ctx.lineJoin = 'round';
  ctx.beginPath();
  e.points.forEach((p, i) => ctx[i ? 'lineTo' : 'moveTo'](p.x * T, p.y * T));
  ctx.strokeStyle = e.color;
  ctx.shadowColor = e.color;
  ctx.shadowBlur = T * 0.3;
  ctx.lineWidth = Math.max(2, T * 0.08);
  ctx.stroke();
  ctx.shadowBlur = 0;
  ctx.strokeStyle = '#ffffff';
  ctx.lineWidth = Math.max(1, T * 0.03);
  ctx.stroke();
}

function drawTextFx(ctx, e, T) {
  ctx.globalAlpha = Math.max(0, Math.min(1, e.life / e.max * 1.5));
  ctx.font = `700 ${Math.round(T * 0.38)}px Rajdhani, sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.lineWidth = 3;
  ctx.strokeStyle = 'rgba(0,0,0,0.7)';
  ctx.strokeText(e.text, e.x * T, e.y * T);
  ctx.fillStyle = e.color;
  ctx.fillText(e.text, e.x * T, e.y * T);
}

function drawBanner(ctx, e, T, W, H) {
  const t = e.life / e.max;
  ctx.globalAlpha = Math.min(1, t * 4, (1 - t) * 8);
  const y = H * 0.42;
  ctx.fillStyle = 'rgba(13,15,26,0.72)';
  ctx.fillRect(0, y - T * 0.5, W, T);
  ctx.font = `700 ${Math.round(T * 0.42)}px Orbitron, sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = e.color;
  ctx.shadowColor = e.color;
  ctx.shadowBlur = T * 0.3;
  ctx.fillText(e.text, W / 2, y, W - T * 0.4);
  ctx.shadowBlur = 0;
}

const DRAW = { particle: drawParticle, ring: drawRingFx, lightning: drawLightningFx, text: drawTextFx };

export function drawEffects(ctx, effects, T) {
  for (const e of effects) {
    if (e.kind === 'banner') continue;
    ctx.save();
    DRAW[e.kind](ctx, e, T);
    ctx.restore();
  }
}

export function drawBanners(ctx, effects, T, W, H) {
  for (const e of effects) {
    if (e.kind !== 'banner') continue;
    ctx.save();
    drawBanner(ctx, e, T, W, H);
    ctx.restore();
  }
}
