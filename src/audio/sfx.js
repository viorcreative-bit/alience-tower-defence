import { noiseHit, tone, filter } from './core.js';
import { kos, zurna, freq } from './mehter.js';

// Oyun içi efekt sesleri. Her fonksiyon (core, out, t, opts).

function arrow(core, out, t) {
  // yay kirişi + ok vınlaması
  tone(core, out, t, { type: 'triangle', from: 260, to: 120, peak: 0.16, decay: 0.07 });
  noiseHit(core, out, t + 0.01, { type: 'bandpass', freq: 3200, q: 1.5, peak: 0.09, attack: 0.01, decay: 0.12, sweepTo: 1400 });
}

function tar(core, out, t) {
  // zift fokurtusu
  for (let i = 0; i < 3; i++) {
    tone(core, out, t + i * 0.05, { from: 180 + Math.random() * 80, to: 70, peak: 0.12, decay: 0.06 });
  }
  noiseHit(core, out, t, { type: 'lowpass', freq: 600, peak: 0.12, decay: 0.15 });
}

function cannonFire(core, out, t) {
  tone(core, out, t, { from: 110, to: 32, peak: 0.6, attack: 0.002, decay: 0.45 });
  noiseHit(core, out, t, { type: 'lowpass', freq: 1400, peak: 0.45, decay: 0.35, sweepTo: 200 });
}

function boom(core, out, t) {
  noiseHit(core, out, t, { type: 'lowpass', freq: 700, peak: 0.35, decay: 0.3, sweepTo: 120 });
  tone(core, out, t, { from: 70, to: 35, peak: 0.25, decay: 0.25 });
}

function musket(core, out, t) {
  noiseHit(core, out, t, { type: 'highpass', freq: 1200, peak: 0.4, attack: 0.001, decay: 0.05 });
  noiseHit(core, out, t + 0.005, { type: 'lowpass', freq: 900, peak: 0.3, decay: 0.28, sweepTo: 150 });
  tone(core, out, t, { from: 160, to: 60, peak: 0.2, decay: 0.12 });
}

function fall(core, out, t) {
  tone(core, out, t, { from: 200, to: 90, peak: 0.12, decay: 0.09 });
  tone(core, out, t + 0.04, { type: 'square', from: 1300 + Math.random() * 400, peak: 0.025, decay: 0.05 });
}

function crash(core, out, t) {
  noiseHit(core, out, t, { type: 'bandpass', freq: 320, q: 0.8, peak: 0.4, decay: 0.45 });
  for (let i = 0; i < 4; i++) {
    noiseHit(core, out, t + 0.05 + Math.random() * 0.25, { type: 'bandpass', freq: 900 + Math.random() * 900, q: 3, peak: 0.12, decay: 0.05 });
  }
}

function clash(core, out, t) {
  const base = 1900 + Math.random() * 500;
  tone(core, out, t, { from: base, peak: 0.05, decay: 0.16 });
  tone(core, out, t, { from: base * 1.51, peak: 0.035, decay: 0.12 });
  noiseHit(core, out, t, { type: 'highpass', freq: 3000, peak: 0.06, decay: 0.02 });
}

function build(core, out, t) {
  for (const dt of [0, 0.13]) {
    noiseHit(core, out, t + dt, { type: 'bandpass', freq: 1000, q: 2, peak: 0.25, decay: 0.05 });
    tone(core, out, t + dt, { from: 320, to: 200, peak: 0.14, decay: 0.06 });
  }
}

function sell(core, out, t) {
  for (const [dt, f] of [[0, 1760], [0.07, 2350], [0.14, 2090]]) tone(core, out, t + dt, { from: f, peak: 0.06, decay: 0.12 });
}

function wallHit(core, out, t) {
  noiseHit(core, out, t, { type: 'lowpass', freq: 260, peak: 0.5, decay: 0.35 });
  tone(core, out, t, { from: 70, to: 40, peak: 0.35, decay: 0.3 });
}

// Boru: pirinç nefesli; düşman borusu baskın ve uyarılar için
function horn(core, out, t, notes = [[0, 0.32], [7, 0.55]], base = 196) {
  const { ctx } = core;
  let tt = t;
  for (const [semi, dur] of notes) {
    const f = base * Math.pow(2, semi / 12);
    const o = ctx.createOscillator();
    o.type = 'sawtooth';
    o.frequency.setValueAtTime(f * 0.97, tt);
    o.frequency.linearRampToValueAtTime(f, tt + 0.05);
    const lp = filter(ctx, 'lowpass', 400, 1);
    lp.frequency.setValueAtTime(400, tt);
    lp.frequency.linearRampToValueAtTime(2200, tt + 0.08);
    lp.frequency.linearRampToValueAtTime(1300, tt + dur);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, tt);
    g.gain.linearRampToValueAtTime(0.2, tt + 0.05);
    g.gain.setValueAtTime(0.18, tt + dur - 0.06);
    g.gain.linearRampToValueAtTime(0.0001, tt + dur);
    o.connect(lp).connect(g).connect(out);
    g.connect(core.reverb);
    o.start(tt);
    o.stop(tt + dur + 0.05);
    tt += dur;
  }
}

function waveStart(core, out, t) {
  kos(core, out, t, 1);
  kos(core, out, t + 0.42, 0.9);
  kos(core, out, t + 0.84, 1.1);
}

function victory(core, out, t) {
  let prev = 0;
  const notes = [[4, 0.16], [5, 0.16], [7, 0.32], [6, 0.16], [7, 0.5]];
  let tt = t;
  for (const [deg, dur] of notes) {
    const f = freq(deg);
    zurna(core, out, tt, f, prev, dur, 0.16);
    prev = f;
    tt += dur;
  }
  kos(core, out, t, 0.8);
  kos(core, out, tt - 0.5, 1);
}

function defeat(core, out, t) {
  horn(core, out, t, [[0, 0.5], [-2, 0.5], [-5, 1.1]], 165);
  kos(core, out, t + 1.6, 1.2);
}

export const SFX = {
  archer: arrow,
  tar,
  cannon: cannonFire,
  boom,
  musket,
  fall,
  crash,
  clash,
  build,
  sell,
  wallHit,
  horn: (core, out, t) => horn(core, out, t),
  waveStart,
  victory,
  defeat,
};

// Aynı sesin üst üste binmesini sınırlar (3× hızda kakofoni olmasın).
export const MIN_GAP = {
  archer: 0.07, tar: 0.12, cannon: 0.12, boom: 0.1, musket: 0.1, fall: 0.05, crash: 0.2,
  clash: 0.09, build: 0.15, sell: 0.15, wallHit: 0.2, horn: 1.5, waveStart: 1, victory: 1, defeat: 2,
};
