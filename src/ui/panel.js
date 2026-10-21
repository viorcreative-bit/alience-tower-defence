import { TR } from '../i18n/tr.js';
import { TOWERS, TOWER_ORDER, UPGRADE, towerStats } from '../data/towers.js';
import { BUILDINGS, MAX_BUILDING_LEVEL } from '../data/buildings.js';
import { sellValue } from '../data/rules.js';
import { describeWave } from '../systems/spawner.js';
import { towerAt } from '../state.js';
import {
  buildTower, upgradeTower, sellTower, canBuild, canUpgrade, selectedTower, towerUpgradeCost, upgradeSelectedBuilding,
} from '../actions.js';
import { isTowerUnlocked, towerBonus, buildingBlock, buildingCost, canUpgradeBuilding, canCharge } from '../systems/city.js';

// Alt bağlamsal panel ve kontrol düğmeleri.
export function createPanel(contextEl, controls, hooks) {
  const { sound: soundBtn, speed: speedBtn, charge: chargeBtn, primary: primaryBtn } = controls;
  contextEl.addEventListener('click', (ev) => {
    const btn = ev.target.closest('[data-action]');
    if (!btn || btn.disabled) return;
    const a = btn.dataset.action;
    if (a === 'build') buildTower(btn.dataset.type);
    else if (a === 'upgrade') upgradeTower();
    else if (a === 'sell') sellTower();
    else if (a === 'building') upgradeSelectedBuilding();
  });
  soundBtn.addEventListener('click', hooks.sound);
  speedBtn.addEventListener('click', hooks.speed);
  chargeBtn.addEventListener('click', hooks.charge);
  primaryBtn.addEventListener('click', hooks.primary);

  let lastKey = '';
  let lastControls = '';

  function renderIdle(state) {
    const lines = [];
    if (state.phase === 'wave') lines.push(state.raid ? TR.hintRaid : TR.hintWave);
    else lines.push(TR.hintIdle);
    if (state.phase === 'build' && state.wave < state.totalWaves) {
      lines.push(`<span class="next">${describeWave(state.wave)}</span>`);
    }
    return `<div class="hint">${lines.map((l) => `<p>${l}</p>`).join('')}</div>`;
  }

  function renderBuild(state) {
    return `<div class="cards">${TOWER_ORDER.map((type) => {
      const def = TOWERS[type];
      const unlocked = isTowerUnlocked(state, type);
      const ok = canBuild(type);
      const desc = unlocked ? TR.towers[type].short : TR.towerLocked(TR.buildings[def.unlock].name);
      return `<button class="card ${unlocked ? '' : 'locked'}" data-action="build" data-type="${type}" ${ok ? '' : 'disabled'} style="--c:${def.color}">
        <span class="card-swatch"></span>
        <span class="card-name">${TR.towers[type].name}</span>
        <span class="card-cost">${def.cost}</span>
        <span class="card-desc">${desc}</span>
      </button>`;
    }).join('')}</div>`;
  }

  function renderTower(state, t) {
    const def = TOWERS[t.type];
    const s = towerStats(def, t.level, towerBonus(state, t.type));
    const maxed = t.level >= UPGRADE.maxLevel;
    const cost = maxed ? 0 : towerUpgradeCost(t);
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

  function renderBuilding(state, id) {
    const def = BUILDINGS[id];
    const level = state.buildings[id];
    const text = TR.buildings[id];
    const block = buildingBlock(state, id);
    const cost = buildingCost(id, level);
    let label;
    if (!block) label = level ? TR.upgrade(cost) : TR.buildAction(cost);
    else if (block.kind === 'max') label = TR.maxLevel;
    else if (block.kind === 'requires') label = TR.requires(TR.buildings[block.building].name, block.level);
    else label = TR.needPalace(block.level);
    const now = level ? TR.buildingEffect[id](level) : TR.buildingNotBuilt;
    const next = level < MAX_BUILDING_LEVEL ? `<div class="ti-next">${TR.buildingNext}: ${TR.buildingEffect[id](level + 1)}</div>` : '';
    return `<div class="tower-info building-info" style="--c:${def.color}">
      <div class="ti-head"><span class="card-swatch"></span><b>${text.name}</b><span class="sub">${text.short}</span><span class="lvl">${TR.level(level, MAX_BUILDING_LEVEL)}</span></div>
      <div class="ti-feature">${now}</div>
      ${next}
      <div class="ti-actions">
        <button class="btn btn-upgrade" data-action="building" ${canUpgradeBuilding(state, id) ? '' : 'disabled'}>${label}</button>
      </div>
    </div>`;
  }

  return function updatePanel(state, soundOn) {
    const sel = state.selected;
    const tower = sel && !sel.building ? towerAt(sel.c, sel.r) : null;
    let mode = 'idle';
    if (sel) mode = sel.building ? 'building' : tower ? 'tower' : 'build';
    const key = [
      mode, state.phase, state.raid, state.wave, state.gold, sel && sel.c, sel && sel.r, tower && tower.level,
      Object.values(state.buildings).join(','),
    ].join('|');
    if (key !== lastKey) {
      lastKey = key;
      contextEl.innerHTML =
        mode === 'tower' ? renderTower(state, selectedTower())
          : mode === 'build' ? renderBuild(state)
            : mode === 'building' ? renderBuilding(state, sel.building)
              : renderIdle(state);
    }

    const ch = state.charge;
    const chargeState = ch.level ? (ch.cooldown > 0 ? Math.ceil(ch.cooldown) : canCharge(state) ? 'ready' : 'idle') : 'none';
    const controlsKey = [state.speed, state.phase, state.raid, state.wave, soundOn, chargeState, ch.active > 0].join('|');
    if (controlsKey !== lastControls) {
      lastControls = controlsKey;
      soundBtn.classList.toggle('off', !soundOn);
      soundBtn.setAttribute('aria-label', soundOn ? TR.soundOn : TR.soundOff);
      speedBtn.textContent = TR.speed(state.speed);
      chargeBtn.hidden = !ch.level;
      chargeBtn.disabled = !canCharge(state);
      chargeBtn.classList.toggle('active', ch.active > 0);
      chargeBtn.textContent = ch.cooldown > 0 && ch.active <= 0 ? TR.chargeWait(ch.cooldown) : TR.charge;
      primaryBtn.disabled = state.phase !== 'build';
      primaryBtn.textContent =
        state.phase === 'wave' ? (state.raid ? TR.raidRunning : TR.waveRunning(state.wave))
          : TR.startWave(Math.min(state.wave + 1, state.totalWaves));
    }
  };
}
