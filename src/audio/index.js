import { createCore } from './core.js';
import { createMehter } from './mehter.js';
import { playChant } from './chant.js';
import { SFX, MIN_GAP } from './sfx.js';

// Ses sistemi. Tarayıcı kuralı gereği ilk dokunuşta açılır.
// Oyun mantığı state.sounds kuyruğuna olay atar; burada çalınır.
export function createAudio(enabled) {
  let core = null;
  let mehter = null;
  let on = enabled;
  let musicMode = 'off';
  const lastPlayed = {};
  let lastChant = -10;

  function unlock() {
    if (!core) {
      core = createCore();
      if (!core) return;
      mehter = createMehter(core);
    }
    if (core.ctx.state === 'suspended') core.ctx.resume();
    apply();
  }

  function apply() {
    if (!core) return;
    const t = core.ctx.currentTime;
    core.master.gain.cancelScheduledValues(t);
    core.master.gain.setValueAtTime(core.master.gain.value, t);
    core.master.gain.linearRampToValueAtTime(on ? 0.9 : 0, t + 0.15);
    mehter.setMode(on ? musicMode : 'off');
  }

  function setEnabled(v) {
    on = v;
    apply();
  }

  function setMusic(mode) {
    musicMode = mode;
    if (core && on) mehter.setMode(mode);
  }

  function play(ev) {
    if (!core || !on || core.ctx.state !== 'running') return;
    const now = core.ctx.currentTime;
    if (ev.id === 'chant') {
      if (now - lastChant < 1.6) return;
      lastChant = now;
      playChant(core, core.sfx, now + (ev.delay || 0) + 0.02, ev.voices || 10, ev.loud ?? 0.7);
      return;
    }
    const fn = SFX[ev.id];
    if (!fn) return;
    const gap = MIN_GAP[ev.id] || 0.05;
    if (now - (lastPlayed[ev.id] || -10) < gap) return;
    lastPlayed[ev.id] = now;
    fn(core, core.sfx, now + 0.01, ev);
  }

  function update(state) {
    for (const ev of state.sounds) play(ev);
    state.sounds.length = 0;
    if (core && on) mehter.schedule();
  }

  return { unlock, setEnabled, setMusic, update, get enabled() { return on; } };
}
