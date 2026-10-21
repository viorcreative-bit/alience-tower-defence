import { state } from './state.js';
import { selectTile, clearSelection, buildTower, upgradeTower, sellTower } from './actions.js';
import { TOWER_ORDER } from './data/towers.js';

// Dokunma / fare → ızgara karesi. Klavye kısayolları da burada.
export function setupInput(canvas, view, hooks) {
  canvas.addEventListener('pointerdown', (ev) => {
    if (state.phase !== 'build' && state.phase !== 'wave') return;
    const rect = canvas.getBoundingClientRect();
    const c = Math.floor((ev.clientX - rect.left) / view.tile);
    const r = Math.floor((ev.clientY - rect.top) / view.tile);
    selectTile(c, r);
    ev.preventDefault();
  });

  // Oyun alanının boş kenarına dokunmak da seçimi kaldırır.
  canvas.parentElement.addEventListener('pointerdown', (ev) => {
    if (ev.target === canvas.parentElement) clearSelection();
  });

  window.addEventListener('keydown', (ev) => {
    if (ev.repeat) return;
    const k = ev.key.toLowerCase();
    const idx = ['1', '2', '3', '4'].indexOf(k);
    if (idx >= 0) buildTower(TOWER_ORDER[idx]);
    else if (k === 'u') upgradeTower();
    else if (k === 's') sellTower();
    else if (k === 'escape') clearSelection();
    else if (k === ' ' || k === 'enter') {
      hooks.primary();
      ev.preventDefault();
    } else if (k === 'f') hooks.speed();
  });
}
