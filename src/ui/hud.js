import { TR } from '../i18n/tr.js';

// Üst şerit: başlık ve kaynaklar.
export function createHud(root) {
  root.innerHTML = `
    <div class="brand"><span class="brand-main">${TR.titleMain}</span><span class="brand-sub">${TR.titleSub}</span></div>
    <div class="stats">
      <div class="stat stat-crystal"><span class="icon"></span><span class="label">${TR.crystal}</span><b data-k="crystal">0</b></div>
      <div class="stat stat-shield"><span class="icon"></span><span class="label">${TR.shield}</span><b data-k="shield">0</b></div>
      <div class="stat stat-wave"><span class="icon"></span><span class="label">${TR.wave}</span><b data-k="wave">0</b></div>
    </div>`;
  const els = {
    crystal: root.querySelector('[data-k="crystal"]'),
    shield: root.querySelector('[data-k="shield"]'),
    wave: root.querySelector('[data-k="wave"]'),
  };
  const last = {};
  return function updateHud(state) {
    const values = {
      crystal: String(state.crystal),
      shield: String(state.shield),
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
