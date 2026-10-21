// Uzaylı tanımları. hız: kare/sn, boyut: yarıçap (kare).
export const ENEMIES = {
  reptile: { id: 'reptile', hp: 42, speed: 1.1, armor: 0, reward: 5, damage: 1, radius: 0.22 },
  scorpion: { id: 'scorpion', hp: 28, speed: 2.0, armor: 0, reward: 6, damage: 1, radius: 0.18 },
  shell: { id: 'shell', hp: 150, speed: 0.7, armor: 4, reward: 12, damage: 2, radius: 0.27 },
  saucer: { id: 'saucer', hp: 36, speed: 1.8, armor: 1, reward: 7, damage: 1, radius: 0.2, mech: true },
  cruiser: { id: 'cruiser', hp: 260, speed: 0.6, armor: 6, reward: 20, damage: 3, radius: 0.32, mech: true },
  giant: { id: 'giant', hp: 1100, speed: 0.5, armor: 3, reward: 70, damage: 6, radius: 0.38, warning: true },
  brain: { id: 'brain', hp: 2400, speed: 0.42, armor: 6, reward: 150, damage: 10, radius: 0.42, warning: true },
};
