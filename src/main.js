import '@fontsource/orbitron/latin-600.css';
import '@fontsource/orbitron/latin-800.css';
import '@fontsource/rajdhani/latin-500.css';
import '@fontsource/rajdhani/latin-ext-500.css';
import '@fontsource/rajdhani/latin-700.css';
import '@fontsource/rajdhani/latin-ext-700.css';
import './styles.css';

import { RULES } from './data/rules.js';
import { state, resetState } from './state.js';
import { startWave, updateSpawner, checkWaveEnd } from './systems/spawner.js';
import { updateMovement } from './systems/movement.js';
import { updateTowers, updateProjectiles, cleanupEnemies } from './systems/combat.js';
import { updateEffects } from './systems/effects.js';
import { createRenderer } from './render/scene.js';
import { createHud } from './ui/hud.js';
import { createPanel } from './ui/panel.js';
import { createOverlay } from './ui/overlay.js';
import { setupInput } from './input.js';
import { saveBestWave } from './storage.js';
import { TR } from './i18n/tr.js';

document.title = TR.title;

const stage = document.getElementById('stage');
const canvas = document.getElementById('game');
const overlayCanvas = document.getElementById('labels');

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
  renderer.reset();
}

function resize() {
  renderer.resize(Math.max(1, stage.clientWidth), Math.max(1, stage.clientHeight));
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
  renderer.render(state, now / 1000);
  updateHud(state);
  updatePanel(state);
  updateOverlay(state);
  requestAnimationFrame(frame);
}

resetState();
const renderer = createRenderer(canvas, overlayCanvas, state.map, state.path);
resize();
setupInput(canvas, renderer, hooks);
window.addEventListener('resize', resize);
if (document.fonts) document.fonts.ready.then(() => resize());
requestAnimationFrame(frame);

if (import.meta.env.DEV) window.__game = { state, hooks, renderer };
