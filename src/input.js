import { state } from './state.js';
import { selectTile, clearSelection, buildTower, upgradeTower, sellTower } from './actions.js';
import { TOWER_ORDER } from './data/towers.js';

// Dokunma / fare → 3D sahnede ışınla ızgara karesi. Klavye kısayolları da burada.
export function setupInput(canvas, renderer, hooks) {
  canvas.addEventListener('pointerdown', (ev) => {
    if (state.phase !== 'build' && state.phase !== 'wave') return;
    const tile = renderer.pickTile(ev.clientX, ev.clientY);
    if (tile) selectTile(tile.c, tile.r);
    else clearSelection();
    ev.preventDefault();
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
