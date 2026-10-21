// Şehir binaları. slot: surların içindeki arsa [sütun, satır]. costs: seviye 1/2/3 maliyeti.
// requires: { bina: seviye } ön koşulu. Saray seviyesi diğer binaların en yüksek seviyesidir.
export const BUILDINGS = {
  palace: { id: 'palace', slot: [4, 14], costs: [0, 260, 480], startLevel: 1, color: '#e0b24a' },
  school: { id: 'school', slot: [1, 13], costs: [80, 160, 240], color: '#5aa0d8' },
  barracks: { id: 'barracks', slot: [7, 13], costs: [100, 200, 300], color: '#c23b32' },
  archery: { id: 'archery', slot: [0, 14], costs: [70, 150, 240], color: '#e0503c' },
  hospital: { id: 'hospital', slot: [2, 15], costs: [90, 180, 270], color: '#5cc48a' },
  cavalry: { id: 'cavalry', slot: [8, 14], costs: [140, 240, 340], requires: { barracks: 1 }, color: '#b5793a' },
  science: { id: 'science', slot: [1, 15], costs: [120, 220, 320], requires: { school: 1 }, color: '#f2a33a' },
  religion: { id: 'religion', slot: [6, 15], costs: [110, 210, 310], requires: { mosque: 1 }, color: '#e8d48a' },
  court: { id: 'court', slot: [5, 13], costs: [100, 200, 300], color: '#9b7bd1' },
  mosque: { id: 'mosque', slot: [7, 15], costs: [120, 240, 360], color: '#7fc8c0' },
};

export const BUILDING_ORDER = [
  'palace', 'school', 'barracks', 'archery', 'hospital', 'cavalry', 'science', 'religion', 'court', 'mosque',
];

export const MAX_BUILDING_LEVEL = 3;

// Seviye başına etkiler
export const CITY = {
  schoolDiscount: 0.1,
  archeryDamage: 0.2,
  archeryRange: 0.15,
  hospitalRepair: 1,
  scienceCannonDamage: 0.15,
  scienceTarSlow: 0.05,
  courtTax: 12,
  courtRaidDelay: 0.2,
  mosqueEndowment: 10,
  minarets: [0, 1, 2, 4],
};

// "Allah Allah!" hücumu (Meşihat seviyesine göre; indeks = seviye)
export const CHARGE = {
  rateBoost: [0, 0.3, 0.45, 0.6],
  duration: [0, 6, 8, 10],
  cooldown: [0, 60, 50, 40],
};

// Devriyeler. count: bina seviyesi kadar birlik.
export const PATROLS = {
  janissary: { id: 'janissary', building: 'barracks', speed: 0.9, reach: 7, damage: 9, rate: 0.6, range: 0.55, spacing: 0.6 },
  sipahi: { id: 'sipahi', building: 'cavalry', speed: 1.8, reach: 14, damage: 14, rate: 0.7, range: 0.6, spacing: 0.8 },
};
