import { RULES } from '../data/rules.js';
import { shakeScreen } from './effects.js';

// Yol verisini köşe noktalarından kare merkezli çizgilere çevirir.
export function buildPath(map) {
  const points = map.path.map(([c, r]) => ({ x: c + 0.5, y: r + 0.5 }));
  const segments = [];
  let length = 0;
  for (let i = 0; i < points.length - 1; i++) {
    const a = points[i];
    const b = points[i + 1];
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const len = Math.hypot(dx, dy);
    segments.push({ x: a.x, y: a.y, dx: dx / len, dy: dy / len, len, start: length });
    length += len;
  }

  const tiles = new Set();
  for (let i = 0; i < map.path.length - 1; i++) {
    const [c0, r0] = map.path[i];
    const [c1, r1] = map.path[i + 1];
    const steps = Math.max(Math.abs(c1 - c0), Math.abs(r1 - r0));
    for (let k = 0; k <= steps; k++) {
      const c = c0 + Math.sign(c1 - c0) * k;
      const r = r0 + Math.sign(r1 - r0) * k;
      if (c >= 0 && r >= 0 && c < map.cols && r < map.rows) tiles.add(r * map.cols + c);
    }
  }

  return { points, segments, length, tiles };
}

// Yol üzerindeki d mesafesindeki nokta ve yön.
export function pointAt(path, d) {
  const segs = path.segments;
  let seg = segs[segs.length - 1];
  for (let i = 0; i < segs.length; i++) {
    if (d < segs[i].start + segs[i].len) {
      seg = segs[i];
      break;
    }
  }
  const t = Math.min(Math.max(d - seg.start, 0), seg.len);
  return { x: seg.x + seg.dx * t, y: seg.y + seg.dy * t, angle: Math.atan2(seg.dy, seg.dx) };
}

export function slowFactor(enemy) {
  let strongest = 0;
  for (const s of enemy.slows) if (s.amount > strongest) strongest = s.amount;
  return strongest;
}

export function applySlow(enemy, amount, duration) {
  enemy.slows.push({ amount, time: duration });
}

export function updateMovement(state, dt) {
  for (const e of state.enemies) {
    if (e.dead) continue;
    const slow = slowFactor(e);
    e.dist += e.speed * (1 - slow) * dt;
    for (const s of e.slows) s.time -= dt;
    if (e.slows.length) e.slows = e.slows.filter((s) => s.time > 0);
    if (e.flash > 0) e.flash -= dt;

    const p = pointAt(state.path, e.dist);
    e.x = p.x;
    e.y = p.y;
    e.angle = p.angle;

    if (e.dist >= state.path.length) {
      e.dead = true;
      state.shield = Math.max(0, state.shield - e.def.damage);
      shakeScreen(state, RULES.shakeTime);
      if (state.shield <= 0) state.phase = 'lost';
    }
  }
}
