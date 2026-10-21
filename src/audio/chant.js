import { panner } from './core.js';

// "Allah Allah!" kalabalık tekbiri: formant sentezi.
// Her ses: testere dişi kaynak → üç bant geçiren formant filtresi (ünlü/ünsüz rengine göre kayar).
// Heceler: "Al" (a + l) – "lah" (l + a + h nefesi). Vurgu ikinci hecede, perde orada yükselir.

const VOWEL_A = [760, 1250, 2550];
const CONS_L = [360, 1050, 2700];
const BREATH = 1500;

function voice(core, out, t0, f0, gainScale, pan) {
  const { ctx } = core;
  const src = ctx.createOscillator();
  src.type = 'sawtooth';
  const vib = ctx.createOscillator();
  vib.frequency.value = 5 + Math.random() * 2;
  const vibGain = ctx.createGain();
  vibGain.gain.value = f0 * 0.015;
  vib.connect(vibGain).connect(src.frequency);

  const amp = ctx.createGain();
  amp.gain.value = 0;
  const pn = panner(ctx, pan);
  amp.connect(pn).connect(out);
  pn.connect(core.reverb);

  const formants = VOWEL_A.map((f, i) => {
    const bp = ctx.createBiquadFilter();
    bp.type = 'bandpass';
    bp.frequency.value = f;
    bp.Q.value = [6, 9, 12][i];
    const g = ctx.createGain();
    g.gain.value = [1, 0.55, 0.25][i];
    src.connect(bp).connect(g).connect(amp);
    return bp;
  });

  // "h" nefesi
  const breath = ctx.createBufferSource();
  breath.buffer = core.noise;
  breath.loop = true;
  const bf = ctx.createBiquadFilter();
  bf.type = 'bandpass';
  bf.frequency.value = BREATH;
  bf.Q.value = 0.8;
  const bg = ctx.createGain();
  bg.gain.value = 0;
  breath.connect(bf).connect(bg).connect(pn);

  const g = gainScale;
  const word = 0.68; // bir "Allah" süresi
  let end = t0;
  for (let w = 0; w < 2; w++) {
    const t = t0 + w * (word + 0.1);
    const p = src.frequency;
    // perde: "Al" düşük, "lah" yüksek ve uzun, sonda düşüş
    p.setValueAtTime(f0 * 0.92, t);
    p.linearRampToValueAtTime(f0 * 0.98, t + 0.16);
    p.linearRampToValueAtTime(f0 * 1.22, t + 0.3);
    p.linearRampToValueAtTime(f0 * 1.18, t + 0.5);
    p.linearRampToValueAtTime(f0 * 0.9, t + word);

    // genlik: a – l (çukur) – a – h (sönüş)
    amp.gain.setValueAtTime(0.0001, t);
    amp.gain.linearRampToValueAtTime(g, t + 0.04);
    amp.gain.linearRampToValueAtTime(g * 0.95, t + 0.13);
    amp.gain.linearRampToValueAtTime(g * 0.45, t + 0.2);
    amp.gain.linearRampToValueAtTime(g * 1.1, t + 0.3);
    amp.gain.linearRampToValueAtTime(g * 0.9, t + 0.52);
    amp.gain.linearRampToValueAtTime(0.0001, t + word);

    // formantlar: a → l → a
    formants.forEach((bp, i) => {
      bp.frequency.setValueAtTime(VOWEL_A[i], t);
      bp.frequency.linearRampToValueAtTime(VOWEL_A[i], t + 0.12);
      bp.frequency.linearRampToValueAtTime(CONS_L[i], t + 0.19);
      bp.frequency.linearRampToValueAtTime(CONS_L[i], t + 0.23);
      bp.frequency.linearRampToValueAtTime(VOWEL_A[i], t + 0.3);
    });

    bg.gain.setValueAtTime(0.0001, t + 0.5);
    bg.gain.linearRampToValueAtTime(g * 0.5, t + 0.56);
    bg.gain.linearRampToValueAtTime(0.0001, t + word + 0.08);
    end = t + word + 0.15;
  }

  src.start(t0);
  vib.start(t0);
  breath.start(t0, Math.random());
  src.stop(end);
  vib.stop(end);
  breath.stop(end);
}

// voices: kaç asker; loud: 0–1
export function playChant(core, out, t, voices = 10, loud = 0.7) {
  const n = Math.max(3, Math.min(18, voices));
  const each = (0.75 * (0.6 + loud * 0.6)) / Math.sqrt(n);
  for (let i = 0; i < n; i++) {
    // erkek sesleri, farklı perdeler; herkes biraz farklı anda başlar
    const f0 = 98 + Math.random() * 85;
    const start = t + Math.random() * 0.09;
    voice(core, out, start, f0, each * (0.7 + Math.random() * 0.6), (Math.random() - 0.5) * 1.4);
  }
}
