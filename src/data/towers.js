// Kule tanımları ve yükseltme formülleri. Mesafeler kare, süreler saniye.
// unlock: kuleyi açan şehir binası (seviye 1).
export const TOWERS = {
  archer: {
    id: 'archer',
    cost: 50,
    range: 2.6,
    damage: 11,
    rate: 0.55,
    projectileSpeed: 10,
    color: '#e0503c',
  },
  tar: {
    id: 'tar',
    cost: 70,
    range: 2.2,
    damage: 5,
    rate: 0.9,
    projectileSpeed: 8,
    slow: 0.45,
    slowDuration: 1.6,
    color: '#8a6cff',
  },
  cannon: {
    id: 'cannon',
    cost: 90,
    range: 2.3,
    damage: 28,
    rate: 1.5,
    projectileSpeed: 6,
    splash: 0.95,
    color: '#f2a33a',
    unlock: 'science',
  },
  musket: {
    id: 'musket',
    cost: 120,
    range: 3.2,
    damage: 46,
    rate: 1.7,
    projectileSpeed: 0, // 0 = anında vuruş
    piercesArmor: true,
    color: '#3fb6d9',
    unlock: 'barracks',
  },
};

export const TOWER_ORDER = ['archer', 'tar', 'cannon', 'musket'];

export const UPGRADE = {
  maxLevel: 3,
  costFactor: 0.75,
  damageMult: 1.6,
  rangeAdd: 0.35,
  rateMult: 0.9,
  slowAdd: 0.1,
  slowMax: 0.7,
};

// discount: Mektep indirimi (0–1)
export function upgradeCost(def, level, discount = 0) {
  return Math.round(def.cost * UPGRADE.costFactor * level * (1 - discount));
}

// bonus: şehirden gelen çarpanlar { damage, range, slow } (kule türüne göre)
export function towerStats(def, level, bonus = {}) {
  const n = level - 1;
  const slow = def.slow ? Math.min(UPGRADE.slowMax, def.slow + UPGRADE.slowAdd * n + (bonus.slow || 0)) : 0;
  return {
    damage: Math.round(def.damage * Math.pow(UPGRADE.damageMult, n) * (1 + (bonus.damage || 0))),
    range: def.range + UPGRADE.rangeAdd * n + (bonus.range || 0),
    rate: def.rate * Math.pow(UPGRADE.rateMult, n),
    slow,
    slowDuration: def.slowDuration || 0,
    splash: def.splash || 0,
    piercesArmor: !!def.piercesArmor,
    projectileSpeed: def.projectileSpeed,
  };
}
