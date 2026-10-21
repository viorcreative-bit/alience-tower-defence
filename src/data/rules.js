// Genel oyun kuralları ve denge sabitleri.
export const RULES = {
  startGold: 220,
  startWall: 20,
  waveBonusBase: 20,
  waveBonusPerWave: 5,
  sellRatio: 0.7,
  hpGrowthPerWave: 1.2,
  firstSpawnDelay: 0.3,
  maxStep: 0.03,
  maxFrameTime: 0.1,
  speeds: [1, 2, 3],
  maxDpr: 2,
  muzzleOffset: 0.3,
  hitFlashTime: 0.08,
  lowHpRatio: 0.4,
  shakeTime: 0.25,
  shakeStrength: 0.12,
};

// Ani baskın: hazırlıkta uzun beklenirse sıradaki devletin akıncıları gelir.
export const RAID = {
  firstWave: 2, // bu kadar dalga bittikten sonra başlar
  minDelay: 45,
  maxDelay: 70,
  baseCount: 4,
  countPerWave: 0.5,
  unit: 'light',
  gap: 0.45,
  bonus: 10,
};

export function waveBonus(waveNo) {
  return RULES.waveBonusBase + waveNo * RULES.waveBonusPerWave;
}

export function sellValue(spent) {
  return Math.round(spent * RULES.sellRatio);
}
