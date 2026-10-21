import { TROOPS, ARMY } from '../data/buildings.js';
import { ENEMY_MELEE } from '../data/enemies.js';
import { pointAt } from './movement.js';
import { damageEnemy } from './combat.js';
import { rateBoost } from './city.js';
import { addParticles, addText } from './effects.js';
import { TR } from '../i18n/tr.js';

// Şehirde yetiştirilen askerler: kale kapısından çıkar, surların önünde yerini alır.
// Yakın dövüşçüler (Yeniçeri, Sipahi) yolun üstünde durup düşmanı keser; okçular yolun iki yanından atar.
// Ölen asker dağılır, yeniden yetiştirilmesi gerekir.

const GATE_Y_OUT = 0.35; // kapıdan çıkarken önce yol üstüne yürür

export function troopCap(state, kind) {
  return TROOPS[kind].perLevel * (state.buildings[TROOPS[kind].building] || 0);
}

export function troopCount(state, kind) {
  return state.units.filter((u) => u.kind === kind).length;
}

export function training(state, kind) {
  return state.training[kind] || (state.training[kind] = { queue: 0, time: 0 });
}

// Bina seviyesine göre güncel can ve hasar
export function troopStats(state, kind) {
  const def = TROOPS[kind];
  const lv = Math.max(1, state.buildings[def.building] || 0);
  const k = 1 + ARMY.levelBonus * (lv - 1);
  return { hp: Math.round(def.hp * k), damage: def.damage * k };
}

export function canTrain(state, kind) {
  const active = state.phase === 'build' || state.phase === 'wave';
  const t = training(state, kind);
  return active && troopCount(state, kind) + t.queue < troopCap(state, kind) && state.gold >= TROOPS[kind].cost;
}

export function trainTroop(state, kind) {
  if (!canTrain(state, kind)) return false;
  state.gold -= TROOPS[kind].cost;
  training(state, kind).queue += 1;
  state.sounds.push({ id: 'build' });
  return true;
}

function spawnUnit(state, kind) {
  const def = TROOPS[kind];
  const L = state.path.length;
  const gate = pointAt(state.path, L);
  const hp = troopStats(state, kind).hp;
  state.units.push({
    id: state.nextId++,
    kind,
    def,
    hp,
    maxHp: hp,
    x: gate.x,
    y: gate.y,
    tx: gate.x,
    ty: gate.y,
    post: L,
    ready: false,
    engaged: 0,
    cooldown: 0,
    swing: 0,
    angle: -Math.PI / 2,
    moving: false,
    dead: false,
    seed: Math.random() * 10,
  });
  state.sounds.push({ id: 'chant', voices: 4 });
}

// Yerler: yakın dövüşçüler kapıdan dışarı doğru ikişerli sıralar, önde Sipahiler; okçular haritadaki yerlerde.
function assignPosts(state) {
  const L = state.path.length;
  const melee = state.units.filter((u) => u.def.role === 'melee');
  melee.sort((a, b) => (a.kind === b.kind ? a.id - b.id : a.kind === 'janissary' ? -1 : 1));
  melee.forEach((u, i) => {
    const row = Math.floor(i / 2);
    const side = i % 2 ? 1 : -1;
    const post = L - ARMY.firstPost - row * ARMY.postSpacing;
    // dövüşen asker yerinden ayrılmaz
    if (u.engaged && u.ready) return;
    const p = pointAt(state.path, post);
    // yolun soluna/sağına hafif sapma (yol yönüne dik)
    setTarget(u, p.x - Math.sin(p.angle) * ARMY.postSide * side, p.y + Math.cos(p.angle) * ARMY.postSide * side);
    u.post = post;
  });
  const spots = state.map.archerPosts;
  state.units.filter((u) => u.def.role === 'ranged').forEach((u, i) => {
    const [x, y] = spots[i % spots.length];
    setTarget(u, x, y);
  });
}

// yeri değişen asker yeniden yürür
function setTarget(u, x, y) {
  if (Math.abs(u.tx - x) > 1e-3 || Math.abs(u.ty - y) > 1e-3) u.ready = false;
  u.tx = x;
  u.ty = y;
}

function walk(state, u, dt) {
  const gateX = pointAt(state.path, state.path.length).x;
  // önce kapıdan surların önüne çık, sonra yerine yürü
  let tx = u.tx;
  let ty = u.ty;
  if (u.y > state.map.wallRow - GATE_Y_OUT + 0.05 && Math.abs(u.x - gateX) < 0.3 && Math.abs(tx - gateX) > 0.3) {
    tx = gateX;
    ty = state.map.wallRow - GATE_Y_OUT;
  }
  const dx = tx - u.x;
  const dy = ty - u.y;
  const d = Math.hypot(dx, dy);
  const step = u.def.speed * dt;
  if (d <= step) {
    u.x = tx;
    u.y = ty;
    if (tx === u.tx && ty === u.ty) {
      u.ready = true;
      u.moving = false;
      return;
    }
  } else {
    u.x += (dx / d) * step;
    u.y += (dy / d) * step;
  }
  u.moving = true;
  u.angle = Math.atan2(dy, dx);
}

function enemyInRange(state, u, range) {
  let best = null;
  let bestScore = -Infinity;
  for (const e of state.enemies) {
    if (e.dead || e.y >= state.map.wallRow) continue;
    const d = Math.hypot(e.x - u.x, e.y - u.y);
    if (d > range + e.radius) continue;
    // önünü kestiği düşman önce; sonra en çok ilerlemiş
    const score = (e.blocker === u ? 1000 : 0) + e.dist;
    if (score > bestScore) {
      best = e;
      bestScore = score;
    }
  }
  return best;
}

function attack(state, u, dt) {
  u.cooldown -= dt;
  const target = enemyInRange(state, u, u.def.range);
  if (!target) return;
  u.angle = Math.atan2(target.y - u.y, target.x - u.x);
  if (u.cooldown > 0) return;
  const dmg = troopStats(state, u.kind).damage;
  u.cooldown = u.def.rate / rateBoost(state);
  u.swing = 1;
  if (u.def.role === 'ranged') {
    state.sounds.push({ id: 'archer' });
    state.projectiles.push({
      type: 'archer', x: u.x, y: u.y, tx: target.x, ty: target.y, target,
      speed: u.def.projectileSpeed, damage: dmg, angle: 0, done: false,
    });
  } else {
    damageEnemy(state, target, dmg, false);
    if (Math.random() < 0.5) state.sounds.push({ id: 'clash' });
  }
}

function killUnit(state, u) {
  u.dead = true;
  addParticles(state, u.x, u.y, '#b3202a', 10, 2, 0.06, 0.6);
  addParticles(state, u.x, u.y, '#e8dcc0', 6, 1.4, 0.08, 0.7);
  addText(state, u.x, u.y - 0.3, TR.troopFell, '#ff5b4d');
  state.sounds.push({ id: 'fall' });
}

export function updateArmy(state, dt) {
  // yetiştirme sırası
  for (const kind in TROOPS) {
    const t = training(state, kind);
    if (!t.queue) {
      t.time = 0;
      continue;
    }
    t.time += dt;
    if (t.time >= TROOPS[kind].train) {
      t.time = 0;
      t.queue -= 1;
      spawnUnit(state, kind);
    }
  }

  // önü kesilen düşman sayısı ve düşmanların askere saldırısı
  for (const u of state.units) u.engaged = 0;
  const growth = 1 + ENEMY_MELEE.growth * Math.max(0, state.wave - 1);
  for (const e of state.enemies) {
    const b = e.blocker;
    if (!b) continue;
    if (b.dead || e.dead) {
      e.blocker = null;
      continue;
    }
    b.engaged += 1;
    e.attackCd = (e.attackCd ?? 0.3) - dt;
    if (e.swing > 0) e.swing = Math.max(0, e.swing - dt * 2);
    if (e.attackCd <= 0) {
      e.attackCd = ENEMY_MELEE.rate;
      e.swing = 1;
      b.hp -= e.def.melee * growth;
      b.flash = 0.12;
      if (b.hp <= 0) killUnit(state, b);
    }
  }
  for (const e of state.enemies) if (e.blocker && e.blocker.dead) e.blocker = null;
  state.units = state.units.filter((u) => !u.dead);

  assignPosts(state);
  const regen = state.phase === 'wave' ? ARMY.hospitalRegen * state.buildings.hospital : ARMY.regenBuild;
  for (const u of state.units) {
    // bina yükseltilince can da artar
    const maxHp = troopStats(state, u.kind).hp;
    if (maxHp !== u.maxHp) {
      u.hp += maxHp - u.maxHp;
      u.maxHp = maxHp;
    }
    if (regen && !u.engaged) u.hp = Math.min(u.maxHp, u.hp + regen * dt);
    if (u.flash > 0) u.flash -= dt;
    if (u.swing > 0) u.swing = Math.max(0, u.swing - dt * 4);
    if (!u.ready) walk(state, u, dt);
    else u.moving = false;
    if (u.ready) attack(state, u, dt);
  }
}

// Yoldaki düşmanın önünü kesecek asker: yerinde duran, boş yakın dövüşçü (ilk karşılaşılan).
export function findBlocker(state, e, nextDist) {
  if (e.def.siege) return null;
  let best = null;
  for (const u of state.units) {
    if (!u.ready || u.def.block <= u.engaged || u.def.role !== 'melee') continue;
    if (e.dist > u.post || nextDist < u.post - ARMY.blockGap) continue;
    if (!best || u.post < best.post) best = u;
  }
  return best;
}
