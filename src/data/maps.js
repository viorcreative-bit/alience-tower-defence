// Haritalar. Yol köşe noktaları [sütun, satır]; düşmanlar kare merkezlerinden geçer.
// wallRow: surların satırı (kapı yolun bittiği sütunda). Altındaki satırlar şehirdir.
export const MAPS = {
  frontier: {
    id: 'frontier',
    cols: 9,
    rows: 16,
    wallRow: 12,
    path: [[1, -1], [1, 2], [6, 2], [6, 5], [2, 5], [2, 8], [7, 8], [7, 10], [4, 10], [4, 12]],
    seed: 1453,
  },
};

export const DEFAULT_MAP = 'frontier';
