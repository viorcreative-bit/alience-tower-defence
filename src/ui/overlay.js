import { TR } from '../i18n/tr.js';
import { getBestWave } from '../storage.js';

// Zafer / yenilgi kutusu.
export function createOverlay(root, onRestart) {
  root.addEventListener('click', (ev) => {
    if (ev.target.closest('[data-action="restart"]')) onRestart();
  });
  let shown = null;
  return function updateOverlay(state) {
    const phase = state.phase === 'won' || state.phase === 'lost' ? state.phase : null;
    if (phase === shown) return;
    shown = phase;
    if (!phase) {
      root.hidden = true;
      root.innerHTML = '';
      return;
    }
    const won = phase === 'won';
    root.innerHTML = `
      <div class="overlay-box ${won ? 'won' : 'lost'}">
        <div class="crest"></div>
        <h2>${won ? TR.wonTitle : TR.lostTitle}</h2>
        <p>${won ? TR.wonText(state.totalWaves, state.wall) : TR.lostText(state.wave)}</p>
        <p class="best">${TR.bestWave(getBestWave())}</p>
        <button class="btn btn-primary" data-action="restart">${TR.playAgain}</button>
      </div>`;
    root.hidden = false;
  };
}
