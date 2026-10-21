import { TR } from '../i18n/tr.js';
import { TOWERS, TOWER_ORDER, UPGRADE, towerStats, upgradeCost } from '../data/towers.js';
import { sellValue } from '../data/rules.js';
import { describeWave } from '../systems/spawner.js';
import { towerAt } from '../state.js';
import { buildTower, upgradeTower, sellTower, canBuild, canUpgrade, selectedTower } from '../actions.js';

// Alt bağlamsal panel ve kontrol düğmeleri.
export function createPanel(contextEl, speedBtn, primaryBtn, hooks) {
  contextEl.addEventListener('click', (ev) => {
    const btn = ev.target.closest('[data-action]');
    if (!btn || btn.disabled) return;
    const a = btn.dataset.action;
    if (a === 'build') buildTower(btn.dataset.type);
    else if (a === 'upgrade') upgradeTower();
    else if (a === 'sell') sellTower();
  });
  speedBtn.addEventListener('click', hooks.speed);
  primaryBtn.addEventListener('click', hooks.primary);

  let lastKey = '';
  let lastControls = '';

  function renderIdle(state) {
    const lines = [];
    if (state.phase === 'wave') lines.push(TR.hintWave);
    else lines.push(TR.hintIdle);
    if (state.phase === 'build' && state.wave < state.totalWaves) {
      lines.push(`<span class="next">${TR.nextWave(describeWave(state.wave))}</span>`);
    }
    return `<div class="hint">${lines.map((l) => `<p>${l}</p>`).join('')}</div>`;
  }

  function renderBuild() {
    return `<div class="cards">${TOWER_ORDER.map((type) => {
      const def = TOWERS[type];
      const ok = canBuild(type);
      return `<button class="card" data-action="build" data-type="${type}" ${ok ? '' : 'disabled'} style="--c:${def.color}">
        <span class="card-swatch"></span>
        <span class="card-name">${TR.towers[type].name}</span>
        <span class="card-cost">${def.cost}</span>
        <span class="card-desc">${TR.towers[type].short}</span>
      </button>`;
    }).join('')}</div>`;
  }

  function renderTower(t) {
    const def = TOWERS[t.type];
    const s = towerStats(def, t.level);
    const maxed = t.level >= UPGRADE.maxLevel;
    const cost = maxed ? 0 : upgradeCost(def, t.level);
    return `<div class="tower-info" style="--c:${def.color}">
      <div class="ti-head"><span class="card-swatch"></span><b>${TR.towers[t.type].name}</b><span class="lvl">${TR.level(t.level, UPGRADE.maxLevel)}</span></div>
      <div class="ti-stats">
        <span>${TR.damage} <b>${TR.num(s.damage)}</b></span>
        <span>${TR.range} <b>${TR.tiles(s.range)}</b></span>
        <span>${TR.rate} <b>${TR.seconds(s.rate)}</b></span>
      </div>
      <div class="ti-feature">${TR.towerFeature[t.type](s)}</div>
      <div class="ti-actions">
        <button class="btn btn-upgrade" data-action="upgrade" ${canUpgrade(t) ? '' : 'disabled'}>${maxed ? TR.maxLevel : TR.upgrade(cost)}</button>
        <button class="btn btn-sell" data-action="sell">${TR.sell(sellValue(t.spent))}</button>
      </div>
    </div>`;
  }

  return function updatePanel(state) {
    const sel = state.selected;
    const tower = sel ? towerAt(sel.c, sel.r) : null;
    let mode = 'idle';
    if (sel) mode = tower ? 'tower' : 'build';
    const key = [mode, state.phase, state.wave, state.crystal, sel && sel.c, sel && sel.r, tower && tower.level].join('|');
    if (key !== lastKey) {
      lastKey = key;
      contextEl.innerHTML =
        mode === 'tower' ? renderTower(selectedTower()) : mode === 'build' ? renderBuild() : renderIdle(state);
    }

    const controls = [state.speed, state.phase, state.wave].join('|');
    if (controls !== lastControls) {
      lastControls = controls;
      speedBtn.textContent = TR.speed(state.speed);
      const running = state.phase === 'wave';
      primaryBtn.disabled = state.phase !== 'build';
      primaryBtn.textContent = running ? TR.waveRunning(state.wave) : TR.startWave(Math.min(state.wave + 1, state.totalWaves));
    }
  };
}
