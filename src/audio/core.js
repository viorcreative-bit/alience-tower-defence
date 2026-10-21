// Ortak Web Audio yardımcıları. Hiçbir kayıt dosyası yok; tüm sesler burada üretilir.

export function createCore() {
  const Ctx = window.AudioContext || window.webkitAudioContext;
  if (!Ctx) return null;
  const ctx = new Ctx();

  const comp = ctx.createDynamicsCompressor();
  comp.threshold.value = -14;
  comp.knee.value = 12;
  comp.ratio.value = 4;
  comp.attack.value = 0.004;
  comp.release.value = 0.2;
  comp.connect(ctx.destination);

  const master = ctx.createGain();
  master.gain.value = 0.9;
  master.connect(comp);

  const music = ctx.createGain();
  music.gain.value = 0;
  music.connect(master);
  const sfx = ctx.createGain();
  sfx.gain.value = 0.75;
  sfx.connect(master);

  // Yapay yankı: sönümlenen gürültüden üretilmiş dürtü yanıtı (açık alan / kale avlusu hissi)
  const reverb = ctx.createConvolver();
  reverb.buffer = impulse(ctx, 1.8, 2.6);
  const reverbOut = ctx.createGain();
  reverbOut.gain.value = 0.35;
  reverb.connect(reverbOut);
  reverbOut.connect(master);

  const noise = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
  const d = noise.getChannelData(0);
  for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;

  return { ctx, master, music, sfx, reverb, noise };
}

function impulse(ctx, seconds, decay) {
  const len = Math.round(ctx.sampleRate * seconds);
  const buf = ctx.createBuffer(2, len, ctx.sampleRate);
  for (let ch = 0; ch < 2; ch++) {
    const data = buf.getChannelData(ch);
    for (let i = 0; i < len; i++) data[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, decay);
  }
  return buf;
}

// Kısa zarf: 0 → peak (attack) → 0 (decay), üstel sönüm.
export function envelope(param, t, peak, attack, decay) {
  param.setValueAtTime(0.0001, t);
  param.linearRampToValueAtTime(peak, t + attack);
  param.exponentialRampToValueAtTime(0.0001, t + attack + decay);
}

export function noiseSource(core, t, duration) {
  const src = core.ctx.createBufferSource();
  src.buffer = core.noise;
  src.loop = true;
  src.loopStart = Math.random();
  src.start(t, Math.random() * 1.5);
  src.stop(t + duration + 0.05);
  return src;
}

export function filter(ctx, type, freq, q = 1) {
  const f = ctx.createBiquadFilter();
  f.type = type;
  f.frequency.value = freq;
  f.Q.value = q;
  return f;
}

// Filtrelenmiş gürültü vuruşu
export function noiseHit(core, out, t, { type = 'bandpass', freq = 1000, q = 1, peak = 0.5, attack = 0.002, decay = 0.1, sweepTo } = {}) {
  const { ctx } = core;
  const src = noiseSource(core, t, attack + decay);
  const f = filter(ctx, type, freq, q);
  if (sweepTo) f.frequency.exponentialRampToValueAtTime(sweepTo, t + attack + decay);
  const g = ctx.createGain();
  envelope(g.gain, t, peak, attack, decay);
  src.connect(f).connect(g).connect(out);
  return g;
}

// Perdesi kayan tek osilatör vuruşu
export function tone(core, out, t, { type = 'sine', from = 440, to, peak = 0.4, attack = 0.003, decay = 0.2, detune = 0 } = {}) {
  const { ctx } = core;
  const o = ctx.createOscillator();
  o.type = type;
  o.frequency.setValueAtTime(from, t);
  if (to) o.frequency.exponentialRampToValueAtTime(to, t + attack + decay);
  o.detune.value = detune;
  const g = ctx.createGain();
  envelope(g.gain, t, peak, attack, decay);
  o.connect(g).connect(out);
  o.start(t);
  o.stop(t + attack + decay + 0.05);
  return g;
}

export function panner(ctx, pan) {
  if (!ctx.createStereoPanner) return ctx.createGain();
  const p = ctx.createStereoPanner();
  p.pan.value = pan;
  return p;
}
