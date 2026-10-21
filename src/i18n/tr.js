// Oyuncuya görünen tüm metinler.
import { CITY, CHARGE } from '../data/buildings.js';

const num = (v, digits = 1) =>
  Number(v).toLocaleString('tr-TR', { maximumFractionDigits: digits, minimumFractionDigits: 0 });
const pct = (v) => `%${Math.round(v * 100)}`;

export const TR = {
  num,
  pct,
  title: 'Osmanlı Kale Savunması',
  titleMain: 'OSMANLI',
  titleSub: 'KALE SAVUNMASI',
  gold: 'Akçe',
  wall: 'Sur',
  wave: 'Dalga',

  towers: {
    archer: { name: 'Okçu Kulesi', short: 'Hızlı, tek hedef' },
    tar: { name: 'Zift Kazanı', short: 'Yavaşlatır' },
    cannon: { name: 'Balyemez Topu', short: 'Alan hasarı' },
    musket: { name: 'Tüfekçi Tabyası', short: 'Zırhı deler' },
  },
  towerFeature: {
    archer: () => 'Hızlı atış, tek hedef',
    tar: (s) => `${pct(s.slow)} yavaşlatma, ${num(s.slowDuration)} sn`,
    cannon: (s) => `Alan hasarı, yarıçap ${num(s.splash, 2)} kare`,
    musket: () => 'Zırhı tamamen deler',
  },
  towerLocked: (building) => `${building} gerekli`,
  towerUnlocked: (name) => `${name} açıldı!`,

  enemies: {
    infantry: 'Piyade',
    light: 'Hafif Süvari',
    knight: 'Zırhlı Şövalye',
    horseArcher: 'Atlı Okçu',
    ram: 'Koçbaşı',
    siegeTower: 'Kuşatma Kulesi',
    commander: 'Başkomutan',
  },

  nations: {
    byzantium: 'Bizans İmparatorluğu',
    serbia: 'Sırp Despotluğu',
    hungary: 'Macar Krallığı',
    venice: 'Venedik Cumhuriyeti',
    mamluk: 'Memlük Sultanlığı',
    safavid: 'Safevî Devleti',
    poland: 'Lehistan Krallığı',
    habsburg: 'Habsburg Monarşisi',
    spain: 'İspanya Krallığı',
    russia: 'Rus Çarlığı',
    france: 'Fransa Krallığı',
    holyLeague: 'Kutsal İttifak',
  },

  buildings: {
    palace: { name: 'Saray', short: 'Padişahın sarayı' },
    school: { name: 'Mektep', short: 'Okul' },
    barracks: { name: 'Kışla', short: 'Yeniçeri Ocağı' },
    archery: { name: 'Okçu Ocağı', short: 'Okçu geliştirme' },
    hospital: { name: 'Darüşşifa', short: 'Hastane' },
    cavalry: { name: 'Sipahi Ocağı', short: 'Atlı birlik' },
    science: { name: 'Bilimhane', short: 'Bilim' },
    religion: { name: 'Meşihat', short: 'Din işleri' },
    court: { name: 'Kadı Mahkemesi', short: 'Adalet' },
    mosque: { name: 'Cami', short: 'İbadet ve vakıf' },
  },
  // Binanın verilen seviyedeki etkisi (seviye ≥ 1)
  buildingEffect: {
    palace: (l) => `Binalar en fazla ${l}. seviyeye çıkabilir`,
    school: (l) => `Kule yükseltmeleri ${pct(CITY.schoolDiscount * l)} ucuz`,
    barracks: (l) => `Tüfekçi Tabyası açık · ${l} Yeniçeri devriyesi`,
    archery: (l) => `Okçu hasarı +${pct(CITY.archeryDamage * l)}, menzil +${num(CITY.archeryRange * l, 2)}`,
    hospital: (l) => `Her dalga sonunda Sur +${CITY.hospitalRepair * l}`,
    cavalry: (l) => `${l} Sipahi devriyesi`,
    science: (l) => `Balyemez açık · top hasarı +${pct(CITY.scienceCannonDamage * l)}, zift +${pct(CITY.scienceTarSlow * l)}`,
    religion: (l) => `"Allah Allah!" hücumu: atış hızı +${pct(CHARGE.rateBoost[l])}, ${CHARGE.duration[l]} sn`,
    court: (l) => `Dalga sonu +${CITY.courtTax * l} akçe vergi, baskınlar seyrek`,
    mosque: (l) => `Dalga sonu +${CITY.mosqueEndowment * l} akçe vakıf geliri`,
  },
  buildingNotBuilt: 'Henüz kurulmadı',
  buildingNext: 'Sonraki',
  buildAction: (cost) => `Kur · ${cost}`,
  requires: (name, level) => `Önce ${name} ${level}. seviye`,
  needPalace: (level) => `Saray ${level}. seviye gerekli`,
  levelShort: (l) => `Seviye ${l}`,

  level: (l, max) => `Seviye ${l}/${max}`,
  damage: 'Hasar',
  range: 'Menzil',
  rate: 'Atış',
  seconds: (v) => `${num(v, 2)} sn`,
  tiles: (v) => `${num(v, 2)} kare`,
  upgrade: (cost) => `Yükselt · ${cost}`,
  maxLevel: 'En yüksek seviye',
  sell: (value) => `Sat +${value}`,

  hintIdle: 'Yolun dışındaki boş kareye dokunup kule kur. Surların içindeki arsalara dokunup şehri geliştir.',
  hintWave: 'Dalga sürerken de kule ve bina kurabilirsin.',
  hintRaid: 'Ani baskın! Akıncıları kapıya varmadan durdur.',
  nextWave: (nation, list) => `Sıradaki sefer: ${nation} — ${list}.`,
  list: (items) =>
    items.length < 2 ? items.join('') : `${items.slice(0, -1).join(', ')} ve ${items[items.length - 1]}`,

  startWave: (n) => `${n}. Dalgayı Başlat`,
  waveRunning: (n) => `${n}. dalga sürüyor`,
  raidRunning: 'Ani baskın!',
  speed: (s) => `${s}×`,
  charge: 'Allah Allah!',
  chargeWait: (s) => `${Math.ceil(s)} sn`,
  chargeBanner: 'Allah Allah! Hücum!',
  loading: (k) => `Ordu toplanıyor… %${Math.round(k * 100)}`,
  loadFailed: 'Modeller yüklenemedi. Sayfayı yenile.',
  qualityShort: (q) => (q === 'high' ? 'HD' : 'SD'),
  qualityLabel: (q) => `Görüntü kalitesi: ${q === 'high' ? 'Yüksek' : 'Düşük'}`,
  soundOn: 'Ses açık',
  soundOff: 'Ses kapalı',

  warnings: {
    siegeTower: 'Kuşatma kulesi geliyor!',
    commander: 'Düşman başkomutanı sahada!',
  },
  waveBanner: (nation) => `${nation} seferde!`,
  waveCleared: (n, bonus) => `${n}. sefer püskürtüldü  +${bonus}`,
  raidBanner: (nation) => `Ani baskın! ${nation} akıncıları`,
  raidCleared: (bonus) => `Baskın püskürtüldü  +${bonus}`,

  lostTitle: 'Kale Düştü',
  lostText: (wave) => `${wave}. dalgada surlar yıkıldı.`,
  wonTitle: 'Devlet-i Aliyye Muzaffer!',
  wonText: (total, wall) => `${total} seferin hepsini püskürttün. Surda ${wall} sağlamlık kaldı.`,
  bestWave: (n) => `En yüksek dalga: ${n}`,
  playAgain: 'Yeniden Oyna',
};
