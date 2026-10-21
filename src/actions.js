import { TOWERS, UPGRADE, upgradeCost } from './data/towers.js';
import { sellValue } from './data/rules.js';
import { state, towerAt, buildingAt, isPathTile, isCityTile, inGrid } from './state.js';
import { isTowerUnlocked, upgradeDiscount, upgradeBuilding } from './systems/city.js';
import { trainTroop } from './systems/army.js';

// Dokunulan kare: savaş alanında boş kare / kule, şehirde bina arsası.
export function selectTile(c, r) {
  const sel = state.selected;
  if (sel && sel.c === c && sel.r === r) {
    state.selected = null;
    return;
  }
  if (!inGrid(c, r) || isPathTile(c, r)) {
    state.selected = null;
    return;
  }
  if (isCityTile(c, r)) {
    const building = buildingAt(c, r);
    state.selected = building ? { c, r, building } : null;
    return;
  }
  state.selected = { c, r };
}

export function clearSelection() {
  state.selected = null;
}

export function canBuild(type) {
  const sel = state.selected;
  return (
    !!sel && !sel.building && !towerAt(sel.c, sel.r) && isTowerUnlocked(state, type) &&
    state.gold >= TOWERS[type].cost && isActive()
  );
}

export function buildTower(type) {
  if (!canBuild(type)) return;
  const { c, r } = state.selected;
  const def = TOWERS[type];
  state.gold -= def.cost;
  state.towers.push({
    id: state.nextId++,
    type,
    c,
    r,
    x: c + 0.5,
    y: r + 0.5,
    level: 1,
    spent: def.cost,
    cooldown: 0,
    angle: -Math.PI / 2,
    recoil: 0,
  });
  state.sounds.push({ id: 'build' });
}

export function selectedTower() {
  const sel = state.selected;
  return sel && !sel.building ? towerAt(sel.c, sel.r) : null;
}

export function towerUpgradeCost(tower) {
  return upgradeCost(TOWERS[tower.type], tower.level, upgradeDiscount(state));
}

export function canUpgrade(tower) {
  return !!tower && isActive() && tower.level < UPGRADE.maxLevel && state.gold >= towerUpgradeCost(tower);
}

export function upgradeTower() {
  const t = selectedTower();
  if (!canUpgrade(t)) return;
  const cost = towerUpgradeCost(t);
  state.gold -= cost;
  t.spent += cost;
  t.level += 1;
  state.sounds.push({ id: 'build' });
}

export function sellTower() {
  const t = selectedTower();
  if (!t || !isActive()) return;
  state.gold += sellValue(t.spent);
  state.towers = state.towers.filter((x) => x !== t);
  state.selected = null;
  state.sounds.push({ id: 'sell' });
}

export function upgradeSelectedBuilding() {
  const sel = state.selected;
  if (sel && sel.building) upgradeBuilding(state, sel.building);
}

export function trainSelected(kind) {
  trainTroop(state, kind);
}

export function isActive() {
  return state.phase === 'build' || state.phase === 'wave';
}
