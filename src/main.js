import '@fontsource/cinzel/latin-700.css';
import '@fontsource/cinzel/latin-900.css';
import '@fontsource/cinzel/latin-ext-700.css';
import '@fontsource/cinzel/latin-ext-900.css';
import '@fontsource/barlow-semi-condensed/latin-500.css';
import '@fontsource/barlow-semi-condensed/latin-ext-500.css';
import '@fontsource/barlow-semi-condensed/latin-700.css';
import '@fontsource/barlow-semi-condensed/latin-ext-700.css';
import './styles.css';

import { RULES } from './data/rules.js';
import { state, resetState } from './state.js';
import { startWave, updateSpawner, checkWaveEnd } from './systems/spawner.js';
import { updateMovement } from './systems/movement.js';
import { updateTowers, updateProjectiles, cleanupEnemies } from './systems/combat.js';
import { updateEffects } from './systems/effects.js';
import { updatePatrols, syncPatrols } from './systems/patrol.js';
import { updateRaid } from './systems/raid.js';
import { updateCharge, triggerCharge } from './systems/city.js';
import { createRenderer } from './render/scene.js';
import { loadModels } from './render/models.js';
import { createHud } from './ui/hud.js';
import { createPanel } from './ui/panel.js';
import { createOverlay } from './ui/overlay.js';
import { setupInput } from './input.js';
import { saveBestWave, getSettings, saveSettings } from './storage.js';
import { createAudio } from './audio/index.js';
import { TR } from './i18n/tr.js';

document.title = TR.title;

const stage = document.getElementById('stage');
const canvas = document.getElementById('game');
const overlayCanvas = document.getElementById('labels');
const audio = createAudio(getSettings().sound !== false);

const hooks = {
  primary() {
    if (state.phase === 'build') startWave(state);
  },
  speed() {
    const list = RULES.speeds;
    state.speed = list[(list.indexOf(state.speed) + 1) % list.length];
  },
  charge() {
    triggerCharge(state);
  },
  sound() {
    audio.setEnabled(!audio.enabled);
    saveSettings({ sound: audio.enabled });
  },
  quality() {
    setQuality(renderer.quality === 'high' ? 'low' : 'high', true);
  },
};

// Zayıf cihazda düşük kaliteyle başla; oyuncu seçmediyse yavaş kare hızında kendiliğinden düşür.
function defaultQuality() {
  const mem = navigator.deviceMemory;
  return (mem && mem <= 3) || (navigator.hardwareConcurrency || 8) <= 4 ? 'low' : 'high';
}
const qualityBtn = document.getElementById('quality');
qualityBtn.addEventListener('click', () => hooks.quality());
function setQuality(q, chosen) {
  renderer.setQuality(q);
  if (chosen) saveSettings({ quality: q });
  qualityBtn.textContent = TR.qualityShort(q);
  qualityBtn.classList.toggle('low', q === 'low');
  qualityBtn.setAttribute('aria-label', TR.qualityLabel(q));
  qualityBtn.title = TR.qualityLabel(q);
}
const perf = { time: 0, frames: 0 };
function watchFrameRate(elapsed) {
  if (renderer.quality !== 'high' || getSettings().quality) return;
  perf.time += elapsed;
  perf.frames += 1;
  if (perf.time < 4) return;
  if (perf.time / perf.frames > RULES.slowFrameTime) setQuality('low', false);
  perf.time = 0;
  perf.frames = 0;
}

const updateHud = createHud(document.getElementById('hud'));
const updatePanel = createPanel(
  document.getElementById('context'),
  {
    sound: document.getElementById('sound'),
    speed: document.getElementById('speed'),
    charge: document.getElementById('charge'),
    primary: document.getElementById('primary'),
  },
  hooks,
);
const updateOverlay = createOverlay(document.getElementById('overlay'), restart);

function restart() {
  resetState();
  syncPatrols(state);
  renderer.reset();
}

function resize() {
  renderer.resize(Math.max(1, stage.clientWidth), Math.max(1, stage.clientHeight));
}

function update(dt) {
  state.time += dt;
  updateRaid(state, dt);
  updateSpawner(state, dt);
  updateMovement(state, dt);
  updatePatrols(state, dt);
  updateTowers(state, dt);
  updateProjectiles(state, dt);
  cleanupEnemies(state);
  updateCharge(state, dt);
  updateEffects(state, dt);
  if (checkWaveEnd(state) || state.phase === 'lost') saveBestWave(state.wave);
}

let last = performance.now();
function frame(now) {
  const raw = (now - last) / 1000;
  const elapsed = Math.min(raw, RULES.maxFrameTime);
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
  audio.setMusic(state.phase === 'wave' ? 'wave' : state.phase === 'build' ? 'build' : 'off');
  audio.update(state);
  renderer.render(state, now / 1000);
  if (!document.hidden && raw < 0.5) watchFrameRate(raw);
  updateHud(state);
  updatePanel(state, audio.enabled);
  updateOverlay(state);
  requestAnimationFrame(frame);
}

let renderer = null;

// Modeller yüklenirken sahnede ilerleme yazısı
const loading = document.createElement('div');
loading.className = 'loading';
loading.textContent = TR.loading(0);
stage.append(loading);

async function start() {
  await loadModels((k) => (loading.textContent = TR.loading(k)));
  loading.remove();
  resetState();
  syncPatrols(state);
  renderer = createRenderer(canvas, overlayCanvas, state.map, state.path, getSettings().quality || defaultQuality());
  setQuality(renderer.quality, false);
  resize();
  setupInput(canvas, renderer, hooks);
  window.addEventListener('resize', resize);
  if (document.fonts) document.fonts.ready.then(() => resize());
  last = performance.now();
  requestAnimationFrame(frame);
  if (import.meta.env.DEV) window.__game = { state, hooks, renderer, audio };
}

// tarayıcılar sesi ancak bir kullanıcı hareketinden sonra açar
for (const ev of ['pointerdown', 'keydown']) window.addEventListener(ev, () => audio.unlock(), { capture: true });
start().catch((err) => {
  loading.textContent = TR.loadFailed;
  console.error(err);
});
