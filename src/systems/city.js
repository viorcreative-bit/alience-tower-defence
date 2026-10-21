import { BUILDINGS, MAX_BUILDING_LEVEL, CITY, CHARGE } from '../data/buildings.js';
import { TOWERS } from '../data/towers.js';
import { addBanner, addParticles, addText } from './effects.js';
import { syncPatrols } from './patrol.js';
import { TR } from '../i18n/tr.js';

// Şehir binaları: kurma/yükseltme kuralları ve oyuna etkileri.

export function levelCap(state, id) {
  return id === 'palace' ? MAX_BUILDING_LEVEL : state.buildings.palace;
}

// Kurulamıyorsa nedeni ({ kind, ... }), kurulabiliyorsa null. Para ayrıca kontrol edilir.
export function buildingBlock(state, id) {
  const def = BUILDINGS[id];
  const level = state.buildings[id];
  if (level >= MAX_BUILDING_LEVEL) return { kind: 'max' };
  for (const req in def.requires || {}) {
    if (state.buildings[req] < def.requires[req]) return { kind: 'requires', building: req, level: def.requires[req] };
  }
  if (level + 1 > levelCap(state, id)) return { kind: 'palace', level: level + 1 };
  return null;
}

export function buildingCost(id, level) {
  return BUILDINGS[id].costs[level] || 0;
}

export function canUpgradeBuilding(state, id) {
  const active = state.phase === 'build' || state.phase === 'wave';
  return active && !buildingBlock(state, id) && state.gold >= buildingCost(id, state.buildings[id]);
}

export function upgradeBuilding(state, id) {
  if (!canUpgradeBuilding(state, id)) return false;
  const [c, r] = BUILDINGS[id].slot;
  state.gold -= buildingCost(id, state.buildings[id]);
  state.buildings[id] += 1;
  addParticles(state, c + 0.5, r + 0.5, '#e8d6a8', 14, 1.6, 0.05, 0.5);
  addText(state, c + 0.5, r, TR.levelShort(state.buildings[id]), '#f2c94c');
  state.sounds.push({ id: 'build' });
  if (id === 'religion') state.charge.level = state.buildings.religion;
  if (state.buildings[id] === 1) {
    for (const t in TOWERS) {
      if (TOWERS[t].unlock === id) addBanner(state, TR.towerUnlocked(TR.towers[t].name), '#f2c94c');
    }
  }
  syncPatrols(state);
  return true;
}

export function isTowerUnlocked(state, type) {
  const req = TOWERS[type].unlock;
  return !req || state.buildings[req] >= 1;
}

export function upgradeDiscount(state) {
  return CITY.schoolDiscount * state.buildings.school;
}

// Kule türüne göre şehir çarpanları
export function towerBonus(state, type) {
  const b = state.buildings;
  if (type === 'archer') return { damage: CITY.archeryDamage * b.archery, range: CITY.archeryRange * b.archery };
  if (type === 'cannon') return { damage: CITY.scienceCannonDamage * b.science };
  if (type === 'tar') return { slow: CITY.scienceTarSlow * b.science };
  return {};
}

// Hücum aktifse atış hızı çarpanı (>1 daha hızlı)
export function rateBoost(state) {
  return state.charge.active > 0 ? 1 + CHARGE.rateBoost[state.charge.level] : 1;
}

export function canCharge(state) {
  return state.charge.level > 0 && state.charge.cooldown <= 0 && state.phase === 'wave';
}

export function triggerCharge(state) {
  if (!canCharge(state)) return;
  const lv = state.charge.level;
  state.charge.active = CHARGE.duration[lv];
  state.charge.cooldown = CHARGE.cooldown[lv];
  addBanner(state, TR.chargeBanner, '#f2c94c', 2.2);
  state.sounds.push({ id: 'chant', voices: 14, loud: 1 });
}

export function updateCharge(state, dt) {
  const ch = state.charge;
  if (ch.active > 0) ch.active = Math.max(0, ch.active - dt);
  if (ch.cooldown > 0) ch.cooldown = Math.max(0, ch.cooldown - dt);
}

// Dalga sonunda şehir gelirleri ve onarım
export function cityIncome(state) {
  const b = state.buildings;
  return {
    tax: CITY.courtTax * b.court,
    endowment: CITY.mosqueEndowment * b.mosque,
    repair: CITY.hospitalRepair * b.hospital,
  };
}
