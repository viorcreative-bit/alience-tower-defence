import { TOWERS, UPGRADE, upgradeCost } from './data/towers.js';
import { sellValue } from './data/rules.js';
import { state, towerAt, isPathTile, isBlockedTile, inGrid } from './state.js';

export function selectTile(c, r) {
  if (!inGrid(c, r) || isPathTile(c, r) || isBlockedTile(c, r)) {
    state.selected = null;
    return;
  }
  const sel = state.selected;
  state.selected = sel && sel.c === c && sel.r === r ? null : { c, r };
}

export function clearSelection() {
  state.selected = null;
}

export function canBuild(type) {
  const sel = state.selected;
  return !!sel && !towerAt(sel.c, sel.r) && state.crystal >= TOWERS[type].cost && isActive();
}

export function buildTower(type) {
  if (!canBuild(type)) return;
  const { c, r } = state.selected;
  const def = TOWERS[type];
  state.crystal -= def.cost;
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
}

export function selectedTower() {
  const sel = state.selected;
  return sel ? towerAt(sel.c, sel.r) : null;
}

export function canUpgrade(tower) {
  return (
    !!tower &&
    isActive() &&
    tower.level < UPGRADE.maxLevel &&
    state.crystal >= upgradeCost(TOWERS[tower.type], tower.level)
  );
}

export function upgradeTower() {
  const t = selectedTower();
  if (!canUpgrade(t)) return;
  const cost = upgradeCost(TOWERS[t.type], t.level);
  state.crystal -= cost;
  t.spent += cost;
  t.level += 1;
}

export function sellTower() {
  const t = selectedTower();
  if (!t || !isActive()) return;
  state.crystal += sellValue(t.spent);
  state.towers = state.towers.filter((x) => x !== t);
  state.selected = null;
}

export function isActive() {
  return state.phase === 'build' || state.phase === 'wave';
}
