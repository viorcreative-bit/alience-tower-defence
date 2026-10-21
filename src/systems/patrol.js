import { PATROLS } from '../data/buildings.js';
import { pointAt } from './movement.js';
import { damageEnemy } from './combat.js';
import { rateBoost } from './city.js';

// Devriyeler: kale kapısından yolu geriye doğru yürür, menzildeki düşmana vurur,
// devriye mesafesine varınca kapıya döner. Hazırlık evresinde kaleye çekilir.

// Bina seviyelerine göre devriye sayısını eşitler.
export function syncPatrols(state) {
  for (const kind in PATROLS) {
    const def = PATROLS[kind];
    const want = state.buildings[def.building] || 0;
    const have = state.patrols.filter((p) => p.kind === kind);
    for (let i = have.length; i < want; i++) {
      state.patrols.push({
        id: state.nextId++,
        kind,
        def,
        index: i,
        dist: state.path.length,
        dir: -1,
        wait: i * def.spacing,
        cooldown: 0,
        swing: 0,
        x: 0,
        y: 0,
        angle: -Math.PI / 2,
        seed: Math.random() * 10,
        moving: false,
      });
    }
    if (have.length > want) {
      const drop = new Set(have.slice(want));
      state.patrols = state.patrols.filter((p) => !drop.has(p));
    }
  }
  for (const p of state.patrols) placeUnit(state, p);
}

// Dalga başında devriyeler sırayla kapıdan çıkar.
export function deployPatrols(state) {
  for (const p of state.patrols) {
    p.dir = -1;
    p.wait = p.index * p.def.spacing + (p.kind === 'sipahi' ? 0.8 : 0);
  }
  return state.patrols.length > 0;
}

function placeUnit(state, p) {
  const pt = pointAt(state.path, p.dist);
  p.x = pt.x;
  p.y = pt.y;
}

function nearestEnemy(state, p, range) {
  let best = null;
  let bestD = range * range;
  for (const e of state.enemies) {
    if (e.dead || e.y >= state.map.wallRow) continue;
    const dx = e.x - p.x;
    const dy = e.y - p.y;
    const d = dx * dx + dy * dy;
    if (d <= bestD) {
      best = e;
      bestD = d;
    }
  }
  return best;
}

export function updatePatrols(state, dt) {
  const L = state.path.length;
  const fighting = state.phase === 'wave';
  for (const p of state.patrols) {
    const def = p.def;
    p.cooldown -= dt;
    if (p.swing > 0) p.swing = Math.max(0, p.swing - dt * 4);
    p.moving = false;
    if (!fighting) {
      // kaleye dön
      if (p.dist < L) {
        p.dist = Math.min(L, p.dist + def.speed * dt);
        p.moving = true;
        p.angle = pointAt(state.path, p.dist).angle;
      }
      placeUnit(state, p);
      continue;
    }
    if (p.wait > 0) {
      p.wait -= dt;
      continue;
    }
    const target = nearestEnemy(state, p, def.range);
    if (target) {
      p.angle = Math.atan2(target.y - p.y, target.x - p.x);
      if (p.cooldown <= 0) {
        damageEnemy(state, target, def.damage, false);
        p.cooldown = def.rate / rateBoost(state);
        p.swing = 1;
        if (Math.random() < 0.5) state.sounds.push({ id: 'clash' });
      }
      continue;
    }
    const limit = Math.max(0.5, L - def.reach);
    p.dist += p.dir * def.speed * dt;
    if (p.dir < 0 && p.dist <= limit) {
      p.dist = limit;
      p.dir = 1;
    } else if (p.dir > 0 && p.dist >= L) {
      p.dist = L;
      p.dir = -1;
    }
    p.moving = true;
    const pt = pointAt(state.path, p.dist);
    // yol yönü ileri; dışarı çıkarken ters yöne bakar
    p.angle = p.dir < 0 ? pt.angle + Math.PI : pt.angle;
    placeUnit(state, p);
  }
}
