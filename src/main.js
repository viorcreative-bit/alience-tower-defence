import '@fontsource/orbitron/latin-600.css';
import '@fontsource/orbitron/latin-800.css';
import '@fontsource/rajdhani/latin-500.css';
import '@fontsource/rajdhani/latin-ext-500.css';
import '@fontsource/rajdhani/latin-700.css';
import '@fontsource/rajdhani/latin-ext-700.css';
import './styles.css';

import { RULES } from './data/rules.js';
import { TOWERS, towerStats } from './data/towers.js';
import { state, resetState, towerAt } from './state.js';
import { startWave, updateSpawner, checkWaveEnd } from './systems/spawner.js';
import { updateMovement } from './systems/movement.js';
import { updateTowers, updateProjectiles, cleanupEnemies } from './systems/combat.js';
import { updateEffects } from './systems/effects.js';
import { createBackground, drawPortal, drawCore } from './render/background.js';
import { drawTower, drawProjectile, drawRange, drawSelection } from './render/towers.js';
import { drawEnemy } from './render/enemies.js';
import { drawEffects, drawBanners } from './render/fx.js';
import { createHud } from './ui/hud.js';
import { createPanel } from './ui/panel.js';
import { createOverlay } from './ui/overlay.js';
import { setupInput } from './input.js';
import { saveBestWave } from './storage.js';
import { TR } from './i18n/tr.js';

document.title = TR.title;

const stage = document.getElementById('stage');
const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');
const view = { tile: 32, dpr: 1, width: 0, height: 0, background: null };

const hooks = {
  primary() {
    if (state.phase === 'build') startWave(state);
  },
  speed() {
    const list = RULES.speeds;
    state.speed = list[(list.indexOf(state.speed) + 1) % list.length];
  },
};

const updateHud = createHud(document.getElementById('hud'));
const updatePanel = createPanel(
  document.getElementById('context'),
  document.getElementById('speed'),
  document.getElementById('primary'),
  hooks,
);
const updateOverlay = createOverlay(document.getElementById('overlay'), restart);

function restart() {
  resetState();
  resize();
}

function resize() {
  const { cols, rows } = state.map;
  const w = stage.clientWidth;
  const h = stage.clientHeight;
  const tile = Math.max(8, Math.floor(Math.min(w / cols, h / rows)));
  const dpr = Math.min(window.devicePixelRatio || 1, RULES.maxDpr);
  view.tile = tile;
  view.dpr = dpr;
  view.width = cols * tile;
  view.height = rows * tile;
  canvas.style.width = `${view.width}px`;
  canvas.style.height = `${view.height}px`;
  canvas.width = Math.round(view.width * dpr);
  canvas.height = Math.round(view.height * dpr);
  view.background = createBackground(state.map, state.path, tile, dpr);
}

function update(dt) {
  state.time += dt;
  updateSpawner(state, dt);
  updateMovement(state, dt);
  updateTowers(state, dt);
  updateProjectiles(state, dt);
  cleanupEnemies(state);
  updateEffects(state, dt);
  if (checkWaveEnd(state) || state.phase === 'lost') saveBestWave(state.wave);
}

function render(realTime) {
  const T = view.tile;
  const { path } = state;
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.setTransform(view.dpr, 0, 0, view.dpr, 0, 0);
  if (state.shake > 0) {
    const k = (state.shake / RULES.shakeTime) * RULES.shakeStrength * T;
    ctx.translate((Math.random() - 0.5) * 2 * k, (Math.random() - 0.5) * 2 * k);
  }
  ctx.drawImage(view.background, 0, 0, view.width, view.height);

  const start = path.points[0];
  const end = path.points[path.points.length - 1];
  drawPortal(ctx, start.x, Math.max(start.y, 0) + 0.3, T, realTime);

  const sel = state.selected;
  if (sel) drawSelection(ctx, sel.c, sel.r, T, realTime);

  for (const t of state.towers) drawTower(ctx, t, T, realTime);
  for (const e of state.enemies) drawEnemy(ctx, e, T, realTime);
  drawCore(ctx, end.x, Math.min(end.y, state.map.rows) - 0.55, T, realTime, state.shield / RULES.startShield);
  for (const p of state.projectiles) drawProjectile(ctx, p, T);
  drawEffects(ctx, state.effects, T);

  const selTower = sel && towerAt(sel.c, sel.r);
  if (selTower) {
    const def = TOWERS[selTower.type];
    drawRange(ctx, selTower.x, selTower.y, towerStats(def, selTower.level).range, T, def.color);
  }
  drawBanners(ctx, state.effects, T, view.width, view.height);
}

let last = performance.now();
function frame(now) {
  const elapsed = Math.min((now - last) / 1000, RULES.maxFrameTime);
  last = now;
  if (state.phase === 'build' || state.phase === 'wave') {
    let remaining = elapsed * state.speed;
    while (remaining > 1e-6 && (state.phase === 'build' || state.phase === 'wave')) {
      const step = Math.min(RULES.maxStep, remaining);
      update(step);
      remaining -= step;
    }
  } else {
    updateEffects(state, elapsed);
  }
  render(now / 1000);
  updateHud(state);
  updatePanel(state);
  updateOverlay(state);
  requestAnimationFrame(frame);
}

resetState();
resize();
setupInput(canvas, view, hooks);
window.addEventListener('resize', resize);
if (document.fonts) document.fonts.ready.then(() => resize());
requestAnimationFrame(frame);

if (import.meta.env.DEV) window.__game = { state, hooks };
