import { noiseHit, tone, filter } from './core.js';

// Özgün, mehter tarzı marş (telifli bir esere dayanmaz).
// Çalgılar: kös (büyük davul), davul, nakkare (küçük çifte davul), zil, zurna (iki ses, oktav).
// Dizi: Re üzerinde Hicaz (Re Mi♭ Fa♯ Sol La Si♭ Do Re).

const BPM = 96;
const EIGHTH = 60 / BPM / 2;
const D4 = 293.66;
const HICAZ = [0, 1, 4, 5, 7, 8, 10, 12, 13, 16, 17]; // yarım ses adımları
const R = -1; // es

// [derece, sekizlik sayısı]; her ölçü 8 sekizlik
const PHRASE_A = [
  [4, 2], [4, 1], [5, 1], [4, 2], [3, 2],
  [2, 2], [3, 1], [4, 1], [3, 2], [2, 1], [1, 1],
  [0, 2], [2, 2], [3, 2], [4, 2],
  [5, 2], [4, 2], [3, 2], [4, 2],
];
const PHRASE_B = [
  [7, 2], [7, 1], [6, 1], [5, 2], [4, 2],
  [6, 2], [5, 1], [4, 1], [3, 2], [4, 2],
  [5, 2], [4, 1], [3, 1], [2, 2], [3, 1], [2, 1],
  [1, 2], [2, 1], [1, 1], [0, 3], [R, 1],
];
const PHRASE_C = [
  [7, 1], [8, 1], [9, 2], [8, 1], [7, 1], [6, 2],
  [7, 2], [6, 1], [5, 1], [4, 4],
  [4, 1], [5, 1], [6, 2], [5, 1], [4, 1], [3, 2],
  [4, 2], [3, 1], [2, 1], [3, 3], [R, 1],
];
const SONG = [...PHRASE_A, ...PHRASE_B, ...PHRASE_A, ...PHRASE_C, ...PHRASE_A, ...PHRASE_B];
const SONG_EIGHTHS = SONG.reduce((s, n) => s + n[1], 0);

// Ölçü içi vurmalı kalıbı (8 sekizlik): "DÜM . tek DÜM DÜM . tek tek"
const KOS = [1, 0, 0, 0, 1, 0, 0, 0];
const DAVUL = [1, 0, 0, 1, 1, 0, 0, 0];
const NAKKARE = [0, 0, 1, 0, 0, 0, 1, 1];
const ZIL = [1, 0, 0, 0, 1, 0, 0, 0];

function freq(degree, octave = 0) {
  return D4 * Math.pow(2, (HICAZ[degree] + octave * 12) / 12);
}

function kos(core, out, t, strength) {
  tone(core, out, t, { from: 85, to: 42, peak: 0.75 * strength, attack: 0.004, decay: 0.55 });
  noiseHit(core, out, t, { type: 'lowpass', freq: 180, peak: 0.35 * strength, decay: 0.25 });
}

function davul(core, out, t, strength) {
  tone(core, out, t, { from: 140, to: 75, peak: 0.45 * strength, attack: 0.002, decay: 0.18 });
  noiseHit(core, out, t, { type: 'bandpass', freq: 260, q: 1.2, peak: 0.3 * strength, decay: 0.09 });
}

function nakkare(core, out, t, strength) {
  noiseHit(core, out, t, { type: 'bandpass', freq: 1900, q: 2.2, peak: 0.28 * strength, decay: 0.05 });
  tone(core, out, t, { from: 520, to: 380, peak: 0.12 * strength, decay: 0.05 });
}

function zil(core, out, t, strength) {
  noiseHit(core, out, t, { type: 'highpass', freq: 5200, q: 0.7, peak: 0.13 * strength, attack: 0.002, decay: 0.38 });
}

// Zurna: genzden gelen tiz ses. Testere dişi + kare dalga, bant geçiren renk, vibrato, kısa kayış.
function zurna(core, out, t, f, prevF, dur, gain) {
  const { ctx } = core;
  const end = t + dur;
  const g = ctx.createGain();
  g.gain.setValueAtTime(0.0001, t);
  g.gain.linearRampToValueAtTime(gain, t + 0.025);
  g.gain.setValueAtTime(gain * 0.85, Math.max(t + 0.03, end - 0.04));
  g.gain.linearRampToValueAtTime(0.0001, end);
  const body = filter(ctx, 'bandpass', 1500, 0.9);
  const nasal = filter(ctx, 'peaking', 2900, 3);
  nasal.gain.value = 7;
  body.connect(nasal).connect(g).connect(out);
  g.connect(core.reverb);

  const vib = ctx.createOscillator();
  vib.frequency.value = 5.6;
  const vibG = ctx.createGain();
  vibG.gain.setValueAtTime(0, t);
  vibG.gain.linearRampToValueAtTime(f * 0.012, t + Math.min(0.25, dur));
  vib.connect(vibG);
  for (const [type, det, lvl] of [['sawtooth', 0, 0.6], ['square', 7, 0.35]]) {
    const o = ctx.createOscillator();
    o.type = type;
    o.detune.value = det;
    o.frequency.setValueAtTime(prevF || f, t);
    o.frequency.exponentialRampToValueAtTime(f, t + 0.035);
    vibG.connect(o.frequency);
    const og = ctx.createGain();
    og.gain.value = lvl;
    o.connect(og).connect(body);
    o.start(t);
    o.stop(end + 0.02);
  }
  vib.start(t);
  vib.stop(end + 0.02);
}

// Önden zamanlanan çalar. mode: 'wave' (tam takım) | 'build' (sadece hafif davul) | 'off'
export function createMehter(core) {
  let mode = 'off';
  let nextStep = 0; // sıradaki sekizliğin zamanı
  let step = 0; // şarkı içindeki sekizlik
  let noteIdx = 0;
  let noteLeft = 0;
  let prevF = 0;

  function setMode(m) {
    if (m === mode) return;
    const { ctx, music } = core;
    const t = ctx.currentTime;
    music.gain.cancelScheduledValues(t);
    music.gain.setValueAtTime(music.gain.value, t);
    const target = m === 'wave' ? 0.55 : m === 'build' ? 0.32 : 0;
    music.gain.linearRampToValueAtTime(target, t + (m === 'off' ? 0.6 : 1.2));
    if (mode === 'off' && m !== 'off') {
      nextStep = t + 0.1;
      step = 0;
      noteIdx = 0;
      noteLeft = 0;
    }
    mode = m;
  }

  function schedule() {
    if (mode === 'off') return;
    const { ctx, music } = core;
    const horizon = ctx.currentTime + 0.25;
    if (nextStep < ctx.currentTime - 0.5) nextStep = ctx.currentTime + 0.05; // sekme arka plandaydı
    while (nextStep < horizon) {
      const t = nextStep;
      const s = step % 8;
      const full = mode === 'wave';
      const bar = Math.floor(step / 8);
      const accent = s === 0 ? 1 : 0.8;
      if (KOS[s]) kos(core, music, t, accent);
      if (DAVUL[s]) davul(core, music, t, full ? 0.9 : 0.6);
      if (full && NAKKARE[s]) nakkare(core, music, t, 0.9);
      if (full && ZIL[s] && (s === 0 || bar % 2)) zil(core, music, t, 1);

      if (noteLeft <= 0) {
        const [deg, len] = SONG[noteIdx];
        noteLeft = len;
        const dur = len * EIGHTH * 0.94;
        if (deg !== R && full) {
          const f = freq(deg);
          const g = 0.2;
          zurna(core, music, t, f, prevF, dur, g);
          zurna(core, music, t, f / 2, prevF / 2, dur, g * 0.55); // alt oktav
          prevF = f;
        }
        noteIdx = (noteIdx + 1) % SONG.length;
      }
      noteLeft -= 1;
      step = (step + 1) % SONG_EIGHTHS;
      if (step === 0) noteIdx = 0;
      nextStep += EIGHTH;
    }
  }

  return { setMode, schedule, get mode() { return mode; } };
}

export { kos, zurna, freq };
