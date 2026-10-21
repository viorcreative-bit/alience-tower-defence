// Genel oyun kuralları ve denge sabitleri.
export const RULES = {
  startCrystal: 200,
  startShield: 20,
  waveBonusBase: 20,
  waveBonusPerWave: 5,
  sellRatio: 0.7,
  hpGrowthPerWave: 1.13,
  maxStep: 0.03,
  maxFrameTime: 0.1,
  speeds: [1, 2, 3],
  maxDpr: 2,
  hitFlashTime: 0.1,
  lowHpRatio: 0.4,
  shakeTime: 0.3,
  shakeStrength: 0.12,
};

export function waveBonus(waveNo) {
  return RULES.waveBonusBase + waveNo * RULES.waveBonusPerWave;
}

export function sellValue(spent) {
  return Math.round(spent * RULES.sellRatio);
}
