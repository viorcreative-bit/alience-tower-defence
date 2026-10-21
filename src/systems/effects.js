// Görsel efekt nesneleri. Hepsi kare biriminde, ömürleri saniye.
export function addParticles(state, x, y, color, count, speed = 2, size = 0.06, life = 0.5) {
  for (let i = 0; i < count; i++) {
    const a = Math.random() * Math.PI * 2;
    const v = speed * (0.4 + Math.random() * 0.8);
    state.effects.push({
      kind: 'particle',
      x, y,
      vx: Math.cos(a) * v,
      vy: Math.sin(a) * v,
      size: size * (0.6 + Math.random() * 0.8),
      color,
      life: life * (0.6 + Math.random() * 0.6),
      max: life,
    });
  }
}

export function addRing(state, x, y, radius, color, life = 0.35, from = 0.1) {
  state.effects.push({ kind: 'ring', x, y, radius, from, color, life, max: life });
}

export function addLightning(state, x0, y0, x1, y1, color, life = 0.18) {
  const points = [{ x: x0, y: y0 }];
  const len = Math.hypot(x1 - x0, y1 - y0);
  const n = Math.max(4, Math.round(len * 4));
  const nx = -(y1 - y0) / (len || 1);
  const ny = (x1 - x0) / (len || 1);
  for (let i = 1; i < n; i++) {
    const t = i / n;
    const off = (Math.random() - 0.5) * 0.35;
    points.push({ x: x0 + (x1 - x0) * t + nx * off, y: y0 + (y1 - y0) * t + ny * off });
  }
  points.push({ x: x1, y: y1 });
  state.effects.push({ kind: 'lightning', points, color, life, max: life });
}

export function addText(state, x, y, text, color, life = 0.9) {
  state.effects.push({ kind: 'text', x, y, text, color, life, max: life });
}

export function addBanner(state, text, color, life = 2.2) {
  state.effects = state.effects.filter((e) => e.kind !== 'banner');
  state.effects.push({ kind: 'banner', text, color, life, max: life });
}

export function shakeScreen(state, time) {
  state.shake = Math.max(state.shake, time);
}

export function updateEffects(state, dt) {
  for (const e of state.effects) {
    e.life -= dt;
    if (e.kind === 'particle') {
      e.x += e.vx * dt;
      e.y += e.vy * dt;
      e.vx *= 1 - 3 * dt;
      e.vy *= 1 - 3 * dt;
    } else if (e.kind === 'text') {
      e.y -= 0.8 * dt;
    }
  }
  state.effects = state.effects.filter((e) => e.life > 0);
  if (state.shake > 0) state.shake = Math.max(0, state.shake - dt);
}
