// Oyuncuya görünen tüm metinler.
const num = (v, digits = 1) =>
  Number(v).toLocaleString('tr-TR', { maximumFractionDigits: digits, minimumFractionDigits: 0 });

export const TR = {
  num,
  title: 'Alien Wars Tower Defence',
  titleMain: 'ALIEN WARS',
  titleSub: 'TOWER DEFENCE',
  crystal: 'Kristal',
  shield: 'Kalkan',
  wave: 'Dalga',

  towers: {
    laser: { name: 'Lazer Tareti', short: 'Hızlı, tek hedef' },
    plasma: { name: 'Plazma Topu', short: 'Alan hasarı' },
    cryo: { name: 'Kriyo Kulesi', short: 'Yavaşlatır' },
    tesla: { name: 'Tesla Bobini', short: 'Zırhı deler' },
  },
  towerFeature: {
    laser: () => 'Hızlı atış, tek hedef',
    plasma: (s) => `Alan hasarı, yarıçap ${num(s.splash, 2)} kare`,
    cryo: (s) => `%${Math.round(s.slow * 100)} yavaşlatma, ${num(s.slowDuration)} sn`,
    tesla: () => 'Zırhı tamamen deler',
  },

  enemies: {
    reptile: 'Sürüngen',
    scorpion: 'Akrep',
    shell: 'Kabuklu',
    brain: 'Ana Beyin',
  },

  level: (l, max) => `Seviye ${l}/${max}`,
  damage: 'Hasar',
  range: 'Menzil',
  rate: 'Atış',
  seconds: (v) => `${num(v, 2)} sn`,
  tiles: (v) => `${num(v, 2)} kare`,
  upgrade: (cost) => `Yükselt · ${cost}`,
  maxLevel: 'En yüksek seviye',
  sell: (value) => `Sat +${value}`,

  hintIdle: 'Kule kurmak için yolun dışındaki boş bir kareye dokun.',
  hintWave: 'Dalga sürerken de kule kurup yükseltebilirsin.',
  hintBuild: 'Kurmak istediğin kuleyi seç.',
  nextWave: (list) => `Sıradaki dalga: ${list}.`,
  list: (items) =>
    items.length < 2 ? items.join('') : `${items.slice(0, -1).join(', ')} ve ${items[items.length - 1]}`,

  startWave: (n) => `${n}. Dalgayı Başlat`,
  waveRunning: (n) => `${n}. dalga sürüyor`,
  speed: (s) => `${s}×`,

  bossWarning: 'Ana Beyin yaklaşıyor!',
  waveCleared: (n, bonus) => `${n}. dalga temizlendi  +${bonus}`,

  lostTitle: 'Üs Düştü',
  lostText: (wave) => `${wave}. dalgada Nova Üssü'nün kalkanı çöktü.`,
  wonTitle: 'Mars Kurtarıldı!',
  wonText: (total, shield) => `${total} dalgayı da püskürttün. Kalkanda ${shield} birim kaldı.`,
  bestWave: (n) => `En yüksek dalga: ${n}`,
  playAgain: 'Yeniden Oyna',
};
