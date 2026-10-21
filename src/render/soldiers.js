import * as THREE from 'three';
import { paintShared, PALETTE } from './palette.js';
import { createSoldier } from './models.js';
import { G, mesh, addHat, buildHorse } from './figures.js';

// KayKit iskeletli askerlerin görünüşleri: hangi gövde, hangi parçalar, hangi renk, hangi başlık.
// Düşmanlar dalganın devlet renklerini alır; Osmanlı tarafı Yeniçeri, Okçu, Sipahi ve Padişah.
// Ölçü: ayakta ~2.15 birim boy, yüz +z; çağıran taraf ölçekler.

export const SOLDIER_HEIGHT = 2.15;
const white = new THREE.Color(0xffffff);
// dokunun gri zırhı renkle çarpılır; çok koyu olmasın diye beyaza doğru açılır
const soft = (c, k = 0.3) => new THREE.Color(c).lerp(white, k);

const HAT_SIZE = { kettle: 0.4, sultan: 0.4, cap: 0.5 };
// Başlık KayKit kafa kemiğine takılır: kafa merkezi kemiğin ~0.5 üstünde, yarıçap ~0.55
function hat(kind, colors = {}) {
  return (head) => {
    const g = new THREE.Group();
    g.position.set(0, 0.6, 0.04);
    addHat(g, kind, HAT_SIZE[kind] ?? 0.47, {
      trimMat: paintShared(colors.trim ?? PALETTE.gold),
      metalMat: paintShared(colors.metal ?? 0xb7bcc6),
    });
    g.traverse((o) => o.isMesh && (o.castShadow = true));
    head.add(g);
  };
}

// Sağ ele tutulan uzun eşyalar (el yuvası kemiğinde, kabza başparmak yönünde)
function lance(trim) {
  return (root) => {
    const slot = root.getObjectByName('handslotr');
    const g = new THREE.Group();
    g.add(mesh(G.cyl6, paintShared(PALETTE.wood), 0, 0.6, 0, 0.045, 2.6, 0.045));
    g.add(mesh(G.cone4, paintShared(0xc9ced6), 0, 1.98, 0, 0.09, 0.32, 0.09));
    if (trim !== undefined) {
      const pen = mesh(G.plane, paintShared(trim), 0.16, 1.62, 0, 0.3, 0.2, 1);
      pen.material.side = THREE.DoubleSide;
      g.add(pen);
    }
    slot.add(g);
  };
}

function musket() {
  return (root) => {
    const slot = root.getObjectByName('handslotr');
    const g = new THREE.Group();
    g.add(mesh(G.cyl6, paintShared(PALETTE.woodDark), 0, 0.35, 0.1, 0.05, 1.5, 0.05));
    g.add(mesh(G.cyl6, paintShared(0x55585f), 0, 0.95, 0.1, 0.035, 0.6, 0.035));
    g.rotation.x = 1.2;
    slot.add(g);
  };
}

// Türk yayı: sol ele tutulan, uçları geriye kıvrık kısa yay ve kiriş
const bowGeo = new THREE.TorusGeometry(0.42, 0.035, 5, 14, Math.PI * 0.9);
function bow() {
  return (root) => {
    const slot = root.getObjectByName('handslotl');
    const g = new THREE.Group();
    const arc = new THREE.Mesh(bowGeo, paintShared(PALETTE.woodDark));
    arc.rotation.z = Math.PI / 2 - Math.PI * 0.45;
    arc.castShadow = true;
    g.add(arc);
    for (const s of [1, -1]) g.add(mesh(G.ball, paintShared(PALETTE.gold), 0, s * 0.41, -0.06, 0.05));
    g.add(mesh(G.cyl6, paintShared(0xf4f1e8), 0, 0, -0.06, 0.008, 0.8, 0.008));
    g.rotation.y = Math.PI / 2;
    slot.add(g);
  };
}

function banner(flagMat) {
  return (root) => {
    const slot = root.getObjectByName('handslotr');
    const g = new THREE.Group();
    g.add(mesh(G.cyl6, paintShared(PALETTE.wood), 0, 1.0, 0, 0.04, 3.0, 0.04));
    g.add(mesh(G.ball, paintShared(PALETTE.gold), 0, 2.55, 0, 0.08));
    const f = new THREE.Mesh(G.plane, flagMat);
    f.position.set(0.42, 2.15, 0);
    f.scale.set(0.8, 0.55, 1);
    g.add(f);
    slot.add(g);
  };
}

const LOOKS = {
  infantry: (n) => ({
    base: 'barbarian',
    show: ['1H_Axe', 'Barbarian_Round_Shield'],
    dye: { Barbarian_Body: n.primary, Barbarian_Round_Shield: n.secondary },
    hats: [hat('kettle', { metal: n.metal })],
  }),
  knight: (n) => ({
    base: 'knight',
    show: ['Knight_Helmet', '1H_Sword', 'Round_Shield', 'Knight_Cape'],
    tint: { Knight_Body: soft(n.metal, 0.45) },
    dye: { Knight_Cape: n.primary, Round_Shield: n.primary },
  }),
  light: (n) => ({
    base: 'barbarian',
    show: [],
    dye: { Barbarian_Body: n.primary },
    hats: [hat('cap', { trim: n.secondary })],
    items: [lance(n.secondary)],
  }),
  horseArcher: (n) => ({
    base: 'rogue_hooded',
    show: ['1H_Crossbow', 'Rogue_Cape'],
    dye: { Rogue_Body: n.primary, Rogue_Cape: n.secondary },
  }),
  commander: (n, flagMat) => ({
    base: 'knight',
    show: ['Knight_Helmet', 'Knight_Cape'],
    tint: { Knight_Body: soft(n.secondary, 0.4) },
    dye: { Knight_Cape: n.primary },
    hats: [hat('plume', { trim: n.secondary, metal: n.metal })],
    items: [banner(flagMat)],
  }),
  janissary: () => ({
    base: 'knight',
    show: ['1H_Sword'],
    dye: { Knight_Body: 0x3566b0 },
    hats: [hat('bork')],
  }),
  musketeer: () => ({
    base: 'knight',
    show: [],
    dye: { Knight_Body: 0x3566b0 },
    hats: [hat('bork')],
    items: [musket()],
  }),
  archer: () => ({
    base: 'knight',
    show: [],
    dye: { Knight_Body: 0x2f7a4a },
    hats: [hat('turban', { metal: 0xe0b24a })],
    items: [bow()],
  }),
  sipahi: () => ({
    base: 'knight',
    show: ['Round_Shield'],
    dye: { Knight_Body: PALETTE.ottomanRed, Round_Shield: PALETTE.gold },
    hats: [hat('turban')],
    items: [lance(PALETTE.gold)],
  }),
  sultan: () => ({
    base: 'mage',
    show: ['Mage_Cape'],
    dye: { Mage_Body: PALETTE.ottomanRed, Mage_Cape: PALETTE.gold },
    hats: [hat('sultan', { trim: 0xf4f1e8 })],
  }),
};

// kind: LOOKS anahtarı; nation ve n (renkler) düşmanlar için
export function buildSoldier(kind, nation, n, flagMat) {
  const spec = LOOKS[kind](n, flagMat);
  spec.key = `${kind}:${nation || 'ottoman'}`;
  return createSoldier(spec);
}

// Atlı asker: elle kurulan at + oturan KayKit binici. +z ileri.
export function buildMounted(kind, nation, n, horseOpts, flagMat) {
  const horse = buildHorse(horseOpts);
  const rider = buildSoldier(kind, nation, n, flagMat);
  rider.root.position.set(0, 0.8, 0.26);
  rider.root.scale.setScalar(0.72);
  rider.pose('Sit_Chair_Idle', 0.4);
  // sandalye oturuşundan ata biniş: bacakları iki yana aç
  for (const [bone, s] of [['upperlegl', 1], ['upperlegr', -1]]) {
    const b = rider.bone(bone);
    if (b) b.rotation.z += s * 0.55;
  }
  horse.root.add(rider.root);
  return { horse, rider, height: 0.8 + SOLDIER_HEIGHT * 0.66 };
}
