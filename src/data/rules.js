// Genel oyun kuralları ve denge sabitleri.
export const RULES = {
  startCrystal: 200,
  startShield: 20,
  waveBonusBase: 20,
  waveBonusPerWave: 5,
  sellRatio: 0.7,
  hpGrowthPerWave: 1.13,
  firstSpawnDelay: 0.3,
  maxStep: 0.03,
  maxFrameTime: 0.1,
  speeds: [1, 2, 3],
  maxDpr: 2,
  minTile: 18,
  muzzleOffset: 0.3,
  hitFlashTime: 0.08,
  lowHpRatio: 0.4,
  shakeTime: 0.25,
  shakeStrength: 0.12,
};

export function waveBonus(waveNo) {
  return RULES.waveBonusBase + waveNo * RULES.waveBonusPerWave;
}

export function sellValue(spent) {
  return Math.round(spent * RULES.sellRatio);
}
