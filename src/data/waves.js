// Her dalga bir devletin seferidir. Gruplar sırayla çıkar: [birlik, adet, aralık (sn)].
export const WAVES = [
  { nation: 'byzantium', groups: [['infantry', 10, 0.9]] },
  { nation: 'serbia', groups: [['infantry', 14, 0.75]] },
  { nation: 'hungary', groups: [['infantry', 8, 0.8], ['light', 8, 0.5]] },
  { nation: 'venice', groups: [['knight', 5, 1.2], ['infantry', 10, 0.6], ['horseArcher', 6, 0.6]] },
  { nation: 'mamluk', groups: [['light', 20, 0.4], ['siegeTower', 1, 2.0]] },
  { nation: 'safavid', groups: [['knight', 10, 1.0], ['horseArcher', 8, 0.5], ['infantry', 12, 0.5]] },
  { nation: 'poland', groups: [['light', 14, 0.4], ['knight', 10, 0.9], ['ram', 3, 1.5]] },
  { nation: 'habsburg', groups: [['knight', 18, 0.8], ['siegeTower', 1, 2.0], ['ram', 4, 1.4]] },
  { nation: 'spain', groups: [['light', 22, 0.35], ['horseArcher', 10, 0.4], ['knight', 12, 0.7]] },
  { nation: 'russia', groups: [['knight', 16, 0.8], ['horseArcher', 8, 0.4], ['ram', 5, 1.2], ['siegeTower', 1, 2.0]] },
  { nation: 'france', groups: [['infantry', 24, 0.3], ['knight', 14, 0.7], ['siegeTower', 2, 2.5]] },
  {
    nation: 'holyLeague',
    groups: [['knight', 10, 0.9], ['siegeTower', 2, 2.5], ['commander', 1, 2.0], ['light', 16, 0.35], ['ram', 5, 1.2]],
  },
];
