import { RAID } from '../data/rules.js';
import { CITY } from '../data/buildings.js';
import { WAVES } from '../data/waves.js';
import { addBanner } from './effects.js';
import { TR } from '../i18n/tr.js';

export function resetRaidTimer(state) {
  const court = state.buildings ? state.buildings.court : 0;
  const base = RAID.minDelay + Math.random() * (RAID.maxDelay - RAID.minDelay);
  state.raidTimer = base * (1 + CITY.courtRaidDelay * court);
}

// Hazırlık evresinde sayaç biter ise sıradaki devletin akıncıları baskın yapar.
export function updateRaid(state, dt) {
  if (state.phase !== 'build' || state.wave < RAID.firstWave || state.wave >= state.totalWaves) return;
  state.raidTimer -= dt;
  if (state.raidTimer > 0) return;
  const nation = WAVES[state.wave].nation;
  const count = Math.round(RAID.baseCount + state.wave * RAID.countPerWave);
  state.phase = 'wave';
  state.raid = true;
  state.nation = nation;
  state.spawnQueue = [];
  for (let i = 0; i < count; i++) state.spawnQueue.push({ type: RAID.unit, gap: RAID.gap, nation });
  state.spawnTimer = 0.6;
  addBanner(state, TR.raidBanner(TR.nations[nation]), '#ff5b4d', 2.6);
  state.sounds.push({ id: 'horn' });
}
