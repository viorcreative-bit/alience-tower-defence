import { TOWERS, towerStats } from '../data/towers.js';
import { RULES } from '../data/rules.js';
import { applySlow } from './movement.js';
import { addParticles, addRing, addLightning, addText } from './effects.js';

// Menzildeki, yolda en çok ilerlemiş uzaylı.
function findTarget(state, tower, range) {
  let best = null;
  for (const e of state.enemies) {
    if (e.dead) continue;
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
    state.crystal += enemy.def.reward;
    addParticles(state, enemy.x, enemy.y, '#7cff6b', enemy.def.boss ? 40 : 12, 2.4, enemy.radius * 0.3, 0.6);
    addText(state, enemy.x, enemy.y - enemy.radius, `+${enemy.def.reward}`, '#5ee6d0');
  }
}

function fire(state, tower, target, stats) {
  const def = TOWERS[tower.type];
  if (!stats.projectileSpeed) {
    damageEnemy(state, target, stats.damage, stats.piercesArmor);
    addLightning(state, tower.x, tower.y - 0.3, target.x, target.y, def.color);
    addParticles(state, target.x, target.y, '#e9d8ff', 5, 1.5, 0.04, 0.25);
    return;
  }
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
  const def = TOWERS[p.type];
  if (p.splash) {
    for (const e of state.enemies) {
      if (e.dead) continue;
      if (Math.hypot(e.x - p.x, e.y - p.y) <= p.splash) damageEnemy(state, e, p.damage, p.piercesArmor);
    }
    addRing(state, p.x, p.y, p.splash, def.color, 0.35);
    addParticles(state, p.x, p.y, def.color, 10, 2.5, 0.05, 0.35);
    return;
  }
  const e = p.target;
  if (e.dead) return;
  damageEnemy(state, e, p.damage, p.piercesArmor);
  if (p.slow) {
    applySlow(e, p.slow, p.slowDuration);
    addRing(state, e.x, e.y, e.radius + 0.12, def.color, 0.3, e.radius);
  } else {
    addParticles(state, p.x, p.y, def.color, 3, 1.2, 0.035, 0.2);
  }
}

export function updateTowers(state, dt) {
  for (const t of state.towers) {
    const stats = towerStats(TOWERS[t.type], t.level);
    t.cooldown -= dt;
    const target = findTarget(state, t, stats.range);
    if (target) t.angle = Math.atan2(target.y - t.y, target.x - t.x);
    if (t.cooldown <= 0) {
      if (target) {
        fire(state, t, target, stats);
        t.cooldown = stats.rate;
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
