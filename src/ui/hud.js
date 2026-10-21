import { TR } from '../i18n/tr.js';

// Üst şerit: başlık ve kaynaklar.
export function createHud(root) {
  root.innerHTML = `
    <div class="brand"><span class="brand-main">${TR.titleMain}</span><span class="brand-sub">${TR.titleSub}</span></div>
    <div class="stats">
      <div class="stat stat-gold"><span class="icon"></span><span class="label">${TR.gold}</span><b data-k="gold">0</b></div>
      <div class="stat stat-wall"><span class="icon"></span><span class="label">${TR.wall}</span><b data-k="wall">0</b></div>
      <div class="stat stat-wave"><span class="icon"></span><span class="label">${TR.wave}</span><b data-k="wave">0</b></div>
    </div>`;
  const els = {
    gold: root.querySelector('[data-k="gold"]'),
    wall: root.querySelector('[data-k="wall"]'),
    wave: root.querySelector('[data-k="wave"]'),
  };
  const last = {};
  return function updateHud(state) {
    const values = {
      gold: String(state.gold),
      wall: String(state.wall),
      wave: `${state.wave}/${state.totalWaves}`,
    };
    for (const k in values) {
      if (last[k] !== values[k]) {
        els[k].textContent = values[k];
        last[k] = values[k];
      }
    }
  };
}
