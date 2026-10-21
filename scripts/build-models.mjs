// KayKit (CC0) paketlerinden oyunun kullandığı modelleri seçip sıkıştırır.
// Kullanım: node scripts/build-models.mjs <KayKit-Medieval-Hexagon-Pack klasörü> <KayKit-Character-Pack-Adventures klasörü>
// Sıkıştırma: KHR_mesh_quantization (tarayıcıda çözücü/WebAssembly gerekmez).
// Çıktı: public/models/medieval.glb (tüm yapı ve doğa modelleri, her biri adıyla bir kök düğüm)
//        public/models/<karakter>.glb (iskeletli askerler; animasyonlar sadece knight.glb içinde)
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { mergeDocuments, dedup, prune, weld, resample, unpartition, textureCompress, quantize } from '@gltf-transform/functions';
import sharp from 'sharp';
import { readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';

const [hexRoot, charRoot] = process.argv.slice(2).map((p) => resolve(p));
if (!hexRoot || !charRoot) {
  console.error('usage: node scripts/build-models.mjs <hexagon-pack> <character-pack>');
  process.exit(1);
}
const HEX = join(hexRoot, 'addons/kaykit_medieval_hexagon_pack/Assets/gltf');
const CHAR = join(charRoot, 'addons/kaykit_character_pack_adventures/Characters/gltf');
const OUT = resolve('public/models');

const MODELS = {
  'buildings/neutral': [
    'wall_straight', 'wall_straight_gate', 'wall_corner_A_outside', 'wall_corner_B_outside',
    'fence_stone_straight', 'fence_wood_straight', 'building_grain',
  ],
  'buildings/red': [
    'building_castle_red', 'building_barracks_red', 'building_archeryrange_red', 'building_home_A_red',
    'building_home_B_red', 'building_tower_A_red', 'building_tower_B_red', 'building_tower_base_red',
    'building_tower_catapult_red', 'building_market_red', 'building_well_red', 'building_windmill_red',
    'building_blacksmith_red', 'building_tavern_red', 'building_watermill_red', 'building_lumbermill_red',
  ],
  'decoration/nature': [
    'tree_single_A', 'tree_single_B', 'trees_A_small', 'trees_A_medium', 'trees_B_small', 'trees_B_medium',
    'hill_single_A', 'hill_single_B', 'hill_single_C', 'hills_A_trees', 'hills_B_trees',
    'mountain_A_grass_trees', 'mountain_B_grass_trees', 'mountain_C_grass', 'rock_single_A', 'rock_single_B',
    'rock_single_C', 'rock_single_D', 'rock_single_E', 'cloud_big', 'cloud_small',
  ],
  'decoration/props': [
    'tent', 'flag_red', 'barrel', 'crate_A_big', 'crate_B_small', 'sack', 'bucket_arrows', 'weaponrack',
    'target', 'wheelbarrow', 'resource_lumber', 'resource_stone',
  ],
};

// Asker animasyonları: iskelet tüm karakterlerde aynı, bu yüzden bir kez saklanır.
const CHARACTERS = ['Knight', 'Barbarian', 'Rogue_Hooded', 'Mage'];
const CLIPS = ['Idle', 'Walking_A', 'Running_A', '1H_Melee_Attack_Chop', 'Cheer', 'Sit_Chair_Idle'];

const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);

async function buildMedieval() {
  const doc = await io.read(join(HEX, 'buildings/neutral/wall_straight.gltf'));
  const root = doc.getRoot();
  const scene = root.listScenes()[0];
  // ilk dosyanın kök düğümlerini kendi adlı düğüme topla
  const wrap = (name, nodes) => {
    const holder = doc.createNode(name);
    for (const n of nodes) holder.addChild(n);
    return holder;
  };
  const first = scene.listChildren();
  first.forEach((n) => scene.removeChild(n));
  scene.addChild(wrap('wall_straight', first));

  for (const [dir, names] of Object.entries(MODELS)) {
    for (const name of names) {
      if (name === 'wall_straight') continue;
      const src = await io.read(join(HEX, dir, `${name}.gltf`));
      const map = mergeDocuments(doc, src);
      const added = map.get(src.getRoot().listScenes()[0]);
      const kids = added.listChildren();
      kids.forEach((n) => added.removeChild(n));
      scene.addChild(wrap(name.replace(/_red$/, ''), kids));
      added.dispose();
    }
  }
  await doc.transform(unpartition(), dedup(), weld(), prune(), quantize());
  await io.write(join(OUT, 'medieval.glb'), doc);
}

async function buildCharacter(name) {
  const doc = await io.read(join(CHAR, `${name}.glb`));
  const root = doc.getRoot();
  for (const a of root.listAnimations()) {
    if (name === 'Knight' && CLIPS.includes(a.getName())) continue;
    // örnekleyiciler de silinmezse verileri prune ile atılmaz
    a.listChannels().forEach((c) => c.dispose());
    a.listSamplers().forEach((s) => s.dispose());
    a.dispose();
  }
  // renk paleti dokusu: 512² kayıpsız WebP yeterli
  await doc.transform(
    resample(), dedup(), prune(),
    textureCompress({ encoder: sharp, targetFormat: 'webp', resize: [512, 512], lossless: true }),
    quantize(),
  );
  await io.write(join(OUT, `${name.toLowerCase()}.glb`), doc);
}

await buildMedieval();
for (const c of CHARACTERS) await buildCharacter(c);
for (const f of readdirSync(OUT)) console.log(f);
