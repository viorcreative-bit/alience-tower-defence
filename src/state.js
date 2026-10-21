import { RULES } from './data/rules.js';
import { MAPS, DEFAULT_MAP } from './data/maps.js';
import { WAVES } from './data/waves.js';
import { BUILDINGS } from './data/buildings.js';
import { buildPath } from './systems/movement.js';
import { resetRaidTimer } from './systems/raid.js';

// Tek, paylaşılan oyun durumu. Konumlar kare biriminde.
export const state = {};

export function resetState(mapId = DEFAULT_MAP) {
  const map = MAPS[mapId];
  const buildings = {};
  for (const id in BUILDINGS) buildings[id] = BUILDINGS[id].startLevel || 0;
  Object.assign(state, {
    map,
    path: buildPath(map),
    gold: RULES.startGold,
    wall: RULES.startWall,
    maxWall: RULES.startWall,
    wave: 0,
    totalWaves: WAVES.length,
    phase: 'build', // build | wave | won | lost
    raid: false, // dalga evresi bir ani baskın mı
    raidTimer: 0,
    nation: WAVES[0].nation, // ordugâhtaki devlet
    speed: RULES.speeds[0],
    buildings,
    towers: [],
    enemies: [],
    units: [], // yetiştirilen askerler (surların önünde)
    training: {}, // asker türü → { queue, time }
    projectiles: [],
    effects: [],
    sounds: [], // ses sistemine giden olay kuyruğu
    spawnQueue: [],
    spawnTimer: 0,
    charge: { active: 0, cooldown: 0, level: 0 },
    selected: null, // { c, r } ya da { c, r, building }
    shake: 0,
    time: 0,
    nextId: 1,
  });
  resetRaidTimer(state);
}

export function playSound(s, id, opts) {
  s.sounds.push({ id, ...opts });
}

export function towerAt(c, r) {
  return state.towers.find((t) => t.c === c && t.r === r) || null;
}

export function buildingAt(c, r) {
  for (const id in BUILDINGS) {
    const [sc, sr] = BUILDINGS[id].slot;
    if (sc === c && sr === r) return id;
  }
  return null;
}

export function isPathTile(c, r) {
  return state.path.tiles.has(r * state.map.cols + c);
}

// Surlar ve şehir: kule kurulamaz
export function isCityTile(c, r) {
  return r >= state.map.wallRow;
}

export function inGrid(c, r) {
  return c >= 0 && r >= 0 && c < state.map.cols && r < state.map.rows;
}
