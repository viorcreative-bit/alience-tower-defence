// Düşman birlikleri (her devlette aynı; renk ve ad devletten gelir).
// hız: kare/sn, boyut: yarıçap (kare). mount: atlı, siege: kuşatma aracı.
export const ENEMIES = {
  infantry: { id: 'infantry', hp: 42, speed: 1.1, armor: 0, reward: 5, damage: 1, radius: 0.22 },
  light: { id: 'light', hp: 28, speed: 2.0, armor: 0, reward: 6, damage: 1, radius: 0.2, mount: true },
  knight: { id: 'knight', hp: 150, speed: 0.7, armor: 4, reward: 12, damage: 2, radius: 0.27 },
  horseArcher: { id: 'horseArcher', hp: 36, speed: 1.8, armor: 1, reward: 7, damage: 1, radius: 0.21, mount: true },
  ram: { id: 'ram', hp: 260, speed: 0.6, armor: 6, reward: 20, damage: 3, radius: 0.32, siege: true },
  siegeTower: { id: 'siegeTower', hp: 1100, speed: 0.5, armor: 3, reward: 70, damage: 6, radius: 0.38, siege: true, warning: true },
  commander: { id: 'commander', hp: 2400, speed: 0.42, armor: 6, reward: 150, damage: 10, radius: 0.42, mount: true, warning: true },
};
