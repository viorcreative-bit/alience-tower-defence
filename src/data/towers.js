// Kule tanımları ve yükseltme formülleri. Mesafeler kare, süreler saniye.
export const TOWERS = {
  laser: {
    id: 'laser',
    cost: 50,
    range: 2.6,
    damage: 11,
    rate: 0.55,
    projectileSpeed: 10,
    color: '#ff4d5e',
  },
  plasma: {
    id: 'plasma',
    cost: 90,
    range: 2.2,
    damage: 26,
    rate: 1.5,
    projectileSpeed: 6,
    splash: 0.95,
    color: '#3dffc0',
  },
  cryo: {
    id: 'cryo',
    cost: 70,
    range: 2.2,
    damage: 5,
    rate: 0.9,
    projectileSpeed: 8,
    slow: 0.45,
    slowDuration: 1.6,
    color: '#7fd8ff',
  },
  tesla: {
    id: 'tesla',
    cost: 120,
    range: 3.2,
    damage: 46,
    rate: 1.7,
    projectileSpeed: 0, // 0 = anında vuruş
    piercesArmor: true,
    color: '#c58bff',
  },
};

export const TOWER_ORDER = ['laser', 'plasma', 'cryo', 'tesla'];

export const UPGRADE = {
  maxLevel: 3,
  costFactor: 0.75,
  damageMult: 1.6,
  rangeAdd: 0.35,
  rateMult: 0.9,
  slowAdd: 0.1,
  slowMax: 0.7,
};

export function upgradeCost(def, level) {
  return Math.round(def.cost * UPGRADE.costFactor * level);
}

export function towerStats(def, level) {
  const n = level - 1;
  return {
    damage: def.damage * Math.pow(UPGRADE.damageMult, n),
    range: def.range + UPGRADE.rangeAdd * n,
    rate: def.rate * Math.pow(UPGRADE.rateMult, n),
    slow: def.slow ? Math.min(UPGRADE.slowMax, def.slow + UPGRADE.slowAdd * n) : 0,
    slowDuration: def.slowDuration || 0,
    splash: def.splash || 0,
    piercesArmor: !!def.piercesArmor,
    projectileSpeed: def.projectileSpeed,
  };
}
