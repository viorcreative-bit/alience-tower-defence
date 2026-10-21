// localStorage sarmalayıcısı; her erişim try/catch içinde.
const KEY = 'osmanli-kale.save.v1';

function read() {
  try {
    const raw = localStorage.getItem(KEY);
    return raw ? JSON.parse(raw) : {};
  } catch {
    return {};
  }
}

function write(data) {
  try {
    localStorage.setItem(KEY, JSON.stringify(data));
  } catch {
    // depolama kapalı olabilir; oyun kayıtsız devam eder
  }
}

export function getBestWave() {
  return read().bestWave || 0;
}

export function saveBestWave(wave) {
  const data = read();
  if (wave > (data.bestWave || 0)) {
    data.bestWave = wave;
    write(data);
  }
}

export function getSettings() {
  return read().settings || {};
}

export function saveSettings(settings) {
  const data = read();
  data.settings = { ...data.settings, ...settings };
  write(data);
}
