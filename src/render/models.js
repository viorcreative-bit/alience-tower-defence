import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { clone as cloneSkinned } from 'three/examples/jsm/utils/SkeletonUtils.js';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';

// KayKit (CC0) model kütüphanesi: yapılar, doğa, eşyalar ve iskeletli askerler.
// Dosyalar scripts/build-models.mjs ile public/models/ altına üretilir.
// Yapı modelleri tek dokuyu paylaşır; durağan gruplar bakeStatic ile tek çizime indirilir.

const FILES = ['medieval', 'knight', 'barbarian', 'rogue_hooded', 'mage'];
const lib = { props: new Map(), chars: {}, clips: new Map() };

export async function loadModels(onProgress) {
  const loader = new GLTFLoader();
  let done = 0;
  // Yalnız metin dosyası sunabilen barındırmalarda (ör. önizleme sayfası) modeller base64 metin olarak gelir
  const base64 = document.documentElement.dataset.models === 'base64';
  const fetchModel = async (f) => {
    const url = new URL(`models/${f}.glb${base64 ? '.txt' : ''}`, document.baseURI).href;
    const res = await fetch(url);
    if (!res.ok) throw new Error(`model indirilemedi: ${f}`);
    if (!base64) return res.arrayBuffer();
    return Uint8Array.from(atob(await res.text()), (c) => c.charCodeAt(0)).buffer;
  };
  const results = await Promise.all(
    FILES.map(async (f) => {
      const g = await loader.parseAsync(await fetchModel(f), '');
      done += 1;
      if (onProgress) onProgress(done / FILES.length);
      return g;
    }),
  );
  const [medieval, ...chars] = results;
  for (const node of medieval.scene.children) {
    node.traverse((o) => {
      if (o.isMesh) {
        o.castShadow = true;
        o.receiveShadow = true;
        tuneMaterial(o.material);
      }
    });
    lib.props.set(node.name, node);
  }
  chars.forEach((g, i) => {
    g.scene.traverse((o) => o.isMesh && tuneMaterial(o.material));
    lib.chars[FILES[i + 1]] = g.scene;
  });
  for (const clip of chars[0].animations) lib.clips.set(clip.name, clip);
}

function tuneMaterial(m) {
  m.roughness = 0.85;
  m.metalness = 0;
  if (m.map) m.map.anisotropy = 4;
}

// Yapı / doğa modeli: geometri ve malzeme paylaşılan kopya
export function prop(name, scale = 1) {
  const src = lib.props.get(name);
  if (!src) throw new Error(`model yok: ${name}`);
  const m = src.clone();
  m.scale.multiplyScalar(scale);
  return m;
}

// --- Durağan birleştirme ---

const ATTRS = ['position', 'normal', 'uv'];
// Sıkıştırılmış (normalize tamsayı) öznitelikleri düz Float32'ye çevirir; birleştirme için hepsi aynı türde olmalı.
function plainGeometry(src, matrix) {
  const g = new THREE.BufferGeometry();
  for (const name of ATTRS) {
    const a = src.getAttribute(name);
    if (!a) {
      if (name === 'uv') {
        g.setAttribute('uv', new THREE.Float32BufferAttribute(new Float32Array(src.getAttribute('position').count * 2), 2));
        continue;
      }
      return null;
    }
    const out = new Float32Array(a.count * a.itemSize);
    for (let i = 0; i < a.count; i++) {
      for (let k = 0; k < a.itemSize; k++) out[i * a.itemSize + k] = a.getComponent(i, k);
    }
    g.setAttribute(name, new THREE.BufferAttribute(out, a.itemSize));
  }
  if (src.index) g.setIndex(new THREE.BufferAttribute(Uint32Array.from(src.index.array), 1));
  else g.setIndex([...Array(g.getAttribute('position').count).keys()]);
  g.applyMatrix4(matrix);
  return g;
}

// Grubun içindeki durağan ağları malzemeye göre birleştirir (çizim sayısını düşürür).
// userData.dynamic işaretli düğümler ve altları olduğu gibi kalır.
export function bakeStatic(group) {
  group.updateMatrixWorld(true);
  const inv = new THREE.Matrix4().copy(group.matrixWorld).invert();
  const byMat = new Map();
  const remove = [];
  const visit = (o) => {
    if (o.userData.dynamic) return;
    if (o.isMesh && !o.isSkinnedMesh && !Array.isArray(o.material) && !o.material.transparent) {
      const g = plainGeometry(o.geometry, new THREE.Matrix4().multiplyMatrices(inv, o.matrixWorld));
      if (g) {
        const key = o.material;
        if (!byMat.has(key)) byMat.set(key, { list: [], cast: false });
        const e = byMat.get(key);
        e.list.push(g);
        e.cast ||= o.castShadow;
        remove.push(o);
      }
    }
    for (const c of o.children) visit(c);
  };
  visit(group);
  for (const o of remove) {
    o.parent.remove(o);
    // boşalan ara grupları da bırak (dönüşüm korunur, içleri boş kalır)
  }
  for (const [mat, e] of byMat) {
    const merged = mergeGeometries(e.list, false);
    e.list.forEach((g) => g.dispose());
    const m = new THREE.Mesh(merged, mat);
    m.castShadow = e.cast;
    m.receiveShadow = true;
    m.userData.baked = true; // birleşik geometri bu gruba ait; atılırken serbest bırakılabilir
    group.add(m);
  }
  return group;
}

// --- Askerler ---

// Her karakterin iskeletli parçaları; kalan sabit parçalar (silah, kalkan, başlık) isteğe göre açılır.
const BODY = {
  knight: ['Knight_Body', 'Knight_Head', 'Knight_ArmLeft', 'Knight_ArmRight', 'Knight_LegLeft', 'Knight_LegRight'],
  barbarian: ['Barbarian_Body', 'Barbarian_Head', 'Barbarian_ArmLeft', 'Barbarian_ArmRight', 'Barbarian_LegLeft', 'Barbarian_LegRight'],
  rogue_hooded: ['Rogue_Body', 'Rogue_Head_Hooded', 'Rogue_ArmLeft', 'Rogue_ArmRight', 'Rogue_LegLeft', 'Rogue_LegRight'],
  mage: ['Mage_Body', 'Mage_Head', 'Mage_ArmLeft', 'Mage_ArmRight', 'Mage_LegLeft', 'Mage_LegRight'],
};

const templates = new Map();
const white = new THREE.Color(1, 1, 1);

// Boya için dokunun gri tonlu kopyası: renkle çarpılınca kumaş tam o devletin rengini alır, gölgeler kalır.
const grayMats = new Map();
function grayMaterial(src) {
  let m = grayMats.get(src);
  if (m) return m;
  const img = src.map.image;
  const c = document.createElement('canvas');
  c.width = img.width;
  c.height = img.height;
  const g = c.getContext('2d');
  g.drawImage(img, 0, 0);
  const data = g.getImageData(0, 0, c.width, c.height);
  const d = data.data;
  for (let i = 0; i < d.length; i += 4) {
    const l = (d[i] * 0.299 + d[i + 1] * 0.587 + d[i + 2] * 0.114) / 255;
    const v = Math.round(255 * Math.min(1, 0.32 + l * 0.9));
    d[i] = d[i + 1] = d[i + 2] = v;
  }
  g.putImageData(data, 0, 0);
  const tex = new THREE.CanvasTexture(c);
  tex.flipY = src.map.flipY;
  tex.colorSpace = THREE.SRGBColorSpace;
  m = src.clone();
  m.map = tex;
  grayMats.set(src, m);
  return m;
}

// İskeletli parçaları tek ağda birleştirir; her parçanın rengi köşe rengiyle verilir.
function mergeSkinned(parts, colors, mat, name) {
  const first = parts[0];
  const bones = first.skeleton.bones;
  const index = new Map(bones.map((b, i) => [b, i]));
  const geos = parts.map((p) => {
    const src = p.geometry;
    const g = new THREE.BufferGeometry();
    for (const attr of [...ATTRS, 'skinWeight']) {
      const a = src.getAttribute(attr);
      const out = new Float32Array(a.count * a.itemSize);
      for (let i = 0; i < a.count; i++) for (let k = 0; k < a.itemSize; k++) out[i * a.itemSize + k] = a.getComponent(i, k);
      g.setAttribute(attr, new THREE.BufferAttribute(out, a.itemSize));
    }
    // parça kendi iskelet sırasını kullanabilir: ilk parçanın sırasına çevir
    const si = src.getAttribute('skinIndex');
    const idx = new Uint16Array(si.count * 4);
    for (let i = 0; i < si.count; i++) {
      for (let k = 0; k < 4; k++) idx[i * 4 + k] = index.get(p.skeleton.bones[si.getComponent(i, k)]) ?? 0;
    }
    g.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(idx, 4));
    const c = new THREE.Color(colors[p.name] ?? white);
    const col = new Float32Array(si.count * 3);
    for (let i = 0; i < si.count; i++) c.toArray(col, i * 3);
    g.setAttribute('color', new THREE.BufferAttribute(col, 3));
    g.setIndex(new THREE.BufferAttribute(Uint32Array.from(src.index.array), 1));
    // sıkıştırılmış parçaların bağlama matrisleri farklıdır: köşeleri ilk parçanın uzayına taşı
    const bone = p.skeleton.bones[0];
    const own = new THREE.Matrix4().multiplyMatrices(p.skeleton.boneInverses[0], p.bindMatrix);
    const ref = new THREE.Matrix4().multiplyMatrices(first.skeleton.boneInverses[index.get(bone)], first.bindMatrix);
    g.applyMatrix4(ref.invert().multiply(own));
    return g;
  });
  const m = mat.clone();
  m.vertexColors = true;
  const mesh = new THREE.SkinnedMesh(mergeGeometries(geos, false), m);
  mesh.name = name;
  mesh.castShadow = true;
  first.parent.add(mesh);
  mesh.bind(first.skeleton, first.bindMatrix);
  return mesh;
}

// spec: { base, show: [sabit parça adları], dye: {parça: renk} (gri dokuyla tam boya),
//         tint: {parça: renk} (dokuyla çarpım), hats: [(kafaKemiği) => void], items: [(kök) => void], key }
function template(spec) {
  let t = templates.get(spec.key);
  if (t) return t;
  const root = cloneSkinned(lib.chars[spec.base]);
  const dye = spec.dye || {};
  const tint = spec.tint || {};
  const parts = BODY[spec.base].map((n) => root.getObjectByName(n)).filter(Boolean);
  const base = parts[0].material;
  const dyed = parts.filter((p) => dye[p.name] !== undefined);
  const plain = parts.filter((p) => dye[p.name] === undefined);
  const made = [];
  if (plain.length) made.push(mergeSkinned(plain, tint, base, 'body'));
  if (dyed.length) made.push(mergeSkinned(dyed, dye, grayMaterial(base), 'uniform'));
  parts.forEach((p) => p.parent.remove(p));
  const drop = [];
  root.traverse((o) => {
    if (!o.isMesh || made.includes(o)) return;
    if (!spec.show.includes(o.name)) {
      drop.push(o);
      return;
    }
    o.castShadow = true;
    if (dye[o.name] !== undefined) {
      o.material = grayMaterial(o.material).clone();
      o.material.color.set(dye[o.name]);
    } else if (tint[o.name] !== undefined) {
      o.material = o.material.clone();
      o.material.color.set(tint[o.name]);
    }
  });
  drop.forEach((o) => o.parent.remove(o));
  const head = root.getObjectByName('head');
  for (const hat of spec.hats || []) hat(head);
  for (const item of spec.items || []) item(root);
  t = root;
  templates.set(spec.key, t);
  return t;
}

// Yeni asker: { root, mixer, play(ad, hız), flash(0..1), head }
export function createSoldier(spec) {
  const root = cloneSkinned(template(spec));
  const mats = new Map();
  // vuruşta parlama için her askerin kendi malzeme kopyası
  root.traverse((o) => {
    if (!o.isMesh) return;
    let m = mats.get(o.material);
    if (!m && o.material.emissive) {
      m = o.material.clone();
      m.emissive.set(0xffffff);
      m.emissiveIntensity = 0;
      mats.set(o.material, m);
    }
    if (m) o.material = m;
    o.castShadow = true;
    o.frustumCulled = false;
  });
  const mixer = new THREE.AnimationMixer(root);
  let current = null;
  const actions = new Map();
  const play = (name, timeScale = 1, fade = 0.2) => {
    let a = actions.get(name);
    if (!a) {
      a = mixer.clipAction(lib.clips.get(name));
      actions.set(name, a);
    }
    a.timeScale = timeScale;
    if (current === a) return a;
    a.reset().play();
    if (current && fade > 0) current.crossFadeTo(a, fade, false);
    else if (current) current.stop();
    current = a;
    return a;
  };
  // Tek bir klibi verilen saniyede dondurur (yürüyüşü kat edilen yola bağlamak için)
  const pose = (name, t) => {
    const a = play(name, 0, 0);
    a.time = t % a.getClip().duration;
    for (const other of actions.values()) if (other !== a) other.stop();
    mixer.update(0);
  };
  const materials = [...mats.values()];
  return {
    root,
    mixer,
    play,
    pose,
    materials,
    head: root.getObjectByName('head'),
    bone: (n) => root.getObjectByName(n),
    flash(k) {
      for (const m of materials) m.emissiveIntensity = k;
    },
    dispose() {
      for (const m of materials) m.dispose();
      mixer.stopAllAction();
    },
  };
}

export function hasClip(name) {
  return lib.clips.has(name);
}
