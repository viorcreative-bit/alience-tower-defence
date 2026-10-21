import { RULES } from './data/rules.js';
import { MAPS, DEFAULT_MAP } from './data/maps.js';
import { WAVES } from './data/waves.js';
import { buildPath } from './systems/movement.js';

// Tek, paylaşılan oyun durumu. Konumlar kare biriminde.
export const state = {};

export function resetState(mapId = DEFAULT_MAP) {
  const map = MAPS[mapId];
  Object.assign(state, {
    map,
    path: buildPath(map),
    crystal: RULES.startCrystal,
    shield: RULES.startShield,
    wave: 0,
    totalWaves: WAVES.length,
    phase: 'build', // build | wave | won | lost
    speed: RULES.speeds[0],
    towers: [],
    enemies: [],
    projectiles: [],
    effects: [],
    spawnQueue: [],
    spawnTimer: 0,
    selected: null, // { c, r }
    shake: 0,
    time: 0,
    nextId: 1,
  });
}

export function towerAt(c, r) {
  return state.towers.find((t) => t.c === c && t.r === r) || null;
}

export function isPathTile(c, r) {
  return state.path.tiles.has(r * state.map.cols + c);
}

export function inGrid(c, r) {
  return c >= 0 && r >= 0 && c < state.map.cols && r < state.map.rows;
}
