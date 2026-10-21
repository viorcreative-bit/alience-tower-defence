import { TOWERS, towerStats } from '../data/towers.js';
import { RULES } from '../data/rules.js';
import { NATIONS } from '../data/nations.js';
import { applySlow } from './movement.js';
import { addParticles, addRing, addLightning, addText } from './effects.js';
import { towerBonus, rateBoost } from './city.js';

// Menzildeki, yolda en çok ilerlemiş düşman (kapıdan girenler hariç).
function findTarget(state, tower, range) {
  let best = null;
  for (const e of state.enemies) {
    if (e.dead || e.y >= state.map.wallRow) continue;
    const dx = e.x - tower.x;
    const dy = e.y - tower.y;
    if (dx * dx + dy * dy <= range * range && (!best || e.dist > best.dist)) best = e;
  }
  return best;
}

export function damageEnemy(state, enemy, amount, piercesArmor) {
  if (enemy.dead) return;
  const dmg = piercesArmor ? amount : Math.max(1, amount - enemy.armor);
  enemy.hp -= dmg;
  enemy.flash = RULES.hitFlashTime;
  if (enemy.hp <= 0) {
    enemy.dead = true;
    state.gold += enemy.def.reward;
    // kan yok: renkli toz bulutu ve tahta/metal kırıntısı
    const color = enemy.def.siege ? '#a0703c' : NATIONS[enemy.nation].primary;
    addParticles(state, enemy.x, enemy.y, color, enemy.def.warning ? 36 : 10, 2.2, enemy.radius * 0.28, 0.6);
    addParticles(state, enemy.x, enemy.y, '#e8dcc0', enemy.def.warning ? 20 : 6, 1.4, enemy.radius * 0.35, 0.7);
    addText(state, enemy.x, enemy.y - enemy.radius, `+${enemy.def.reward}`, '#f2c94c');
    state.sounds.push({ id: enemy.def.siege ? 'crash' : 'fall' });
  }
}

function fire(state, tower, target, stats) {
  if (!stats.projectileSpeed) {
    // tüfek: anında isabet, düz iz, namlu dumanı
    damageEnemy(state, target, stats.damage, stats.piercesArmor);
    addLightning(state, tower.x, tower.y, target.x, target.y, '#fff1c4', 0.12);
    addParticles(state, tower.x + Math.cos(tower.angle) * 0.3, tower.y + Math.sin(tower.angle) * 0.3, '#d9d4c8', 6, 0.8, 0.07, 0.6);
    addParticles(state, target.x, target.y, '#e8dcc0', 4, 1.2, 0.04, 0.25);
    state.sounds.push({ id: 'musket' });
    return;
  }
  state.sounds.push({ id: tower.type });
  state.projectiles.push({
    type: tower.type,
    x: tower.x + Math.cos(tower.angle) * RULES.muzzleOffset,
    y: tower.y + Math.sin(tower.angle) * RULES.muzzleOffset,
    tx: target.x,
    ty: target.y,
    target,
    speed: stats.projectileSpeed,
    damage: stats.damage,
    splash: stats.splash,
    slow: stats.slow,
    slowDuration: stats.slowDuration,
    piercesArmor: stats.piercesArmor,
    angle: 0,
    done: false,
  });
}

function hit(state, p) {
  if (p.splash) {
    for (const e of state.enemies) {
      if (e.dead) continue;
      if (Math.hypot(e.x - p.x, e.y - p.y) <= p.splash) damageEnemy(state, e, p.damage, p.piercesArmor);
    }
    addRing(state, p.x, p.y, p.splash, '#e8cf9a', 0.35);
    addParticles(state, p.x, p.y, '#cbb48a', 12, 2.5, 0.06, 0.45);
    addParticles(state, p.x, p.y, '#ffb347', 5, 1.8, 0.04, 0.25);
    state.sounds.push({ id: 'boom' });
    return;
  }
  const e = p.target;
  if (e.dead) return;
  damageEnemy(state, e, p.damage, p.piercesArmor);
  if (p.slow) {
    applySlow(e, p.slow, p.slowDuration);
    addRing(state, e.x, e.y, e.radius + 0.12, '#2a2230', 0.35, e.radius);
    addParticles(state, e.x, e.y, '#2a2230', 4, 0.9, 0.05, 0.4);
  } else {
    addParticles(state, p.x, p.y, '#d9c79c', 3, 1.2, 0.035, 0.2);
  }
}

export function updateTowers(state, dt) {
  for (const t of state.towers) {
    const stats = towerStats(TOWERS[t.type], t.level, towerBonus(state, t.type));
    t.cooldown -= dt;
    const target = findTarget(state, t, stats.range);
    if (target) t.angle = Math.atan2(target.y - t.y, target.x - t.x);
    if (t.cooldown <= 0) {
      if (target) {
        fire(state, t, target, stats);
        t.cooldown = stats.rate / rateBoost(state);
        t.recoil = 1;
      } else {
        t.cooldown = 0;
      }
    }
    if (t.recoil > 0) t.recoil = Math.max(0, t.recoil - dt * 8);
  }
}

export function updateProjectiles(state, dt) {
  for (const p of state.projectiles) {
    if (!p.target.dead) {
      p.tx = p.target.x;
      p.ty = p.target.y;
    }
    const dx = p.tx - p.x;
    const dy = p.ty - p.y;
    const dist = Math.hypot(dx, dy);
    const step = p.speed * dt;
    p.angle = Math.atan2(dy, dx);
    if (dist <= step) {
      p.x = p.tx;
      p.y = p.ty;
      p.done = true;
      hit(state, p);
    } else {
      p.x += (dx / dist) * step;
      p.y += (dy / dist) * step;
    }
  }
  state.projectiles = state.projectiles.filter((p) => !p.done);
}

export function cleanupEnemies(state) {
  state.enemies = state.enemies.filter((e) => !e.dead);
}
