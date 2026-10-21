import { ENEMIES } from '../data/enemies.js';
import { WAVES } from '../data/waves.js';
import { RULES, RAID, waveBonus } from '../data/rules.js';
import { pointAt } from './movement.js';
import { addBanner } from './effects.js';
import { cityIncome } from './city.js';
import { resetRaidTimer } from './raid.js';
import { TR } from '../i18n/tr.js';

export function startWave(state) {
  if (state.phase !== 'build' || state.wave >= state.totalWaves) return;
  state.wave += 1;
  state.phase = 'wave';
  state.raid = false;
  const wave = WAVES[state.wave - 1];
  state.nation = wave.nation;
  state.spawnQueue = [];
  for (const [type, count, interval] of wave.groups) {
    for (let i = 0; i < count; i++) state.spawnQueue.push({ type, gap: interval, nation: wave.nation });
  }
  state.spawnTimer = RULES.firstSpawnDelay + 1.2;
  addBanner(state, TR.waveBanner(TR.nations[wave.nation]), '#f3e6c8', 2.4);
  state.sounds.push({ id: 'waveStart' });
  // surların önündeki askerler tekbirle karşılık verir
  state.sounds.push({ id: 'chant', voices: state.units.length ? 12 : 8, delay: 0.9 });
}

export function spawnEnemy(state, type, nation) {
  const def = ENEMIES[type];
  const hp = Math.round(def.hp * Math.pow(RULES.hpGrowthPerWave, Math.max(0, state.wave - 1)));
  const p = pointAt(state.path, 0);
  state.enemies.push({
    id: state.nextId++,
    def,
    type,
    nation,
    hp,
    maxHp: hp,
    speed: def.speed,
    armor: def.armor,
    radius: def.radius,
    dist: 0,
    x: p.x,
    y: p.y,
    angle: p.angle,
    slow: 0,
    slowTime: 0,
    flash: 0,
    dead: false,
    seed: Math.random() * 10,
  });
  if (def.warning) {
    addBanner(state, TR.warnings[type], '#ff5b4d');
    state.sounds.push({ id: 'horn' });
  }
}

export function updateSpawner(state, dt) {
  if (state.phase !== 'wave') return;
  // Sayaç geri sayar; her birlik çıktıktan sonra kendi grubunun aralığı kadar beklenir.
  state.spawnTimer -= dt;
  while (state.spawnQueue.length && state.spawnTimer <= 0) {
    const next = state.spawnQueue.shift();
    spawnEnemy(state, next.type, next.nation);
    state.spawnTimer += next.gap;
  }
}

// Dalga (ya da baskın) bitti mi? Bittiyse gelirleri ver ve evreyi değiştir.
export function checkWaveEnd(state) {
  if (state.phase !== 'wave' || state.spawnQueue.length || state.enemies.length) return false;
  if (state.raid) {
    state.raid = false;
    state.phase = 'build';
    state.gold += RAID.bonus;
    state.nation = WAVES[state.wave].nation;
    resetRaidTimer(state);
    addBanner(state, TR.raidCleared(RAID.bonus), '#f2c94c');
    return false;
  }
  if (state.wave >= state.totalWaves) {
    state.phase = 'won';
    state.sounds.push({ id: 'chant', voices: 16, loud: 1 });
    return true;
  }
  const bonus = waveBonus(state.wave);
  const income = cityIncome(state);
  state.gold += bonus + income.tax + income.endowment;
  state.wall = Math.min(state.maxWall, state.wall + income.repair);
  state.phase = 'build';
  state.nation = WAVES[state.wave].nation;
  state.charge.active = 0;
  resetRaidTimer(state);
  addBanner(state, TR.waveCleared(state.wave, bonus + income.tax + income.endowment), '#f2c94c');
  state.sounds.push({ id: 'victory' });
  return true;
}

export function describeWave(waveIndex) {
  const wave = WAVES[waveIndex];
  if (!wave) return '';
  return TR.nextWave(TR.nations[wave.nation], TR.list(wave.groups.map(([type, count]) => `${count} ${TR.enemies[type]}`)));
}
