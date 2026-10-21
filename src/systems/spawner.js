import { ENEMIES } from '../data/enemies.js';
import { WAVES } from '../data/waves.js';
import { RULES, waveBonus } from '../data/rules.js';
import { pointAt } from './movement.js';
import { addBanner } from './effects.js';
import { TR } from '../i18n/tr.js';

export function startWave(state) {
  if (state.phase !== 'build' || state.wave >= state.totalWaves) return;
  state.wave += 1;
  state.phase = 'wave';
  state.spawnQueue = [];
  for (const [type, count, interval] of WAVES[state.wave - 1]) {
    for (let i = 0; i < count; i++) state.spawnQueue.push({ type, delay: interval });
  }
  state.spawnQueue[0].delay = 0;
  state.spawnTimer = 0;
}

export function spawnEnemy(state, type) {
  const def = ENEMIES[type];
  const hp = Math.round(def.hp * Math.pow(RULES.hpGrowthPerWave, state.wave - 1));
  const p = pointAt(state.path, 0);
  state.enemies.push({
    id: state.nextId++,
    def,
    type,
    hp,
    maxHp: hp,
    speed: def.speed,
    armor: def.armor,
    radius: def.radius,
    dist: 0,
    x: p.x,
    y: p.y,
    angle: p.angle,
    slows: [],
    flash: 0,
    dead: false,
    seed: Math.random() * 10,
  });
  if (def.boss) addBanner(state, TR.bossWarning, '#ff4d5e');
}

export function updateSpawner(state, dt) {
  if (!state.spawnQueue.length) return;
  state.spawnTimer += dt;
  while (state.spawnQueue.length && state.spawnTimer >= state.spawnQueue[0].delay) {
    const next = state.spawnQueue.shift();
    state.spawnTimer -= next.delay;
    spawnEnemy(state, next.type);
  }
}

// Dalga bitti mi? Bittiyse bonusu ver ve evreyi değiştir.
export function checkWaveEnd(state) {
  if (state.phase !== 'wave' || state.spawnQueue.length || state.enemies.length) return false;
  const bonus = waveBonus(state.wave);
  state.crystal += bonus;
  if (state.wave >= state.totalWaves) {
    state.phase = 'won';
  } else {
    state.phase = 'build';
    addBanner(state, TR.waveCleared(state.wave, bonus), '#5ee6d0');
  }
  return true;
}

export function describeWave(waveIndex) {
  const groups = WAVES[waveIndex];
  if (!groups) return '';
  return TR.list(groups.map(([type, count]) => `${count} ${TR.enemies[type]}`));
}
