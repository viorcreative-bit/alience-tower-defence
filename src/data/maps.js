// Haritalar. Yol köşe noktaları [sütun, satır]; düşmanlar kare merkezlerinden geçer.
export const MAPS = {
  canyon: {
    id: 'canyon',
    cols: 9,
    rows: 14,
    path: [[1, -1], [1, 2], [6, 2], [6, 5], [2, 5], [2, 8], [7, 8], [7, 11], [4, 11], [4, 14]],
    // Kalenin kapladığı, kule kurulamayan kareler
    blocked: [[3, 13], [5, 13]],
    seed: 2189,
  },
};

export const DEFAULT_MAP = 'canyon';
