import * as THREE from 'three';
import { animateHorse } from './figures.js';
import { buildSoldier, buildMounted, SOLDIER_HEIGHT } from './soldiers.js';

// Devriye birlikleri: Yeniçeri (yaya) ve Sipahi (atlı). +z ileri.
const SCALE = { janissary: 0.36 * (2.2 / SOLDIER_HEIGHT), sipahi: 0.34 };

export function createPatrolModel(p) {
  const g = new THREE.Group();
  const holder = new THREE.Group();
  let u;
  if (p.kind === 'janissary') {
    const soldier = buildSoldier('janissary');
    soldier.play('Idle');
    holder.add(soldier.root);
    u = { soldier, height: SOLDIER_HEIGHT };
  } else {
    const r = buildMounted('sipahi', null, null, { coat: 0x3a2a20, cloth: 0xb3202a, clothTrim: 0xe0b24a });
    holder.add(r.horse.root);
    u = { horse: r.horse, rider: r.rider, height: r.height };
  }
  holder.scale.setScalar(SCALE[p.kind]);
  g.add(holder);
  u.holder = holder;
  u.topY = u.height * SCALE[p.kind];
  u.last = null;
  g.userData = u;
  return g;
}

export function updatePatrolModel(model, p, time) {
  const u = model.userData;
  const dt = u.last === null ? 0 : Math.min(0.1, time - u.last);
  u.last = time;
  const yaw = Math.PI / 2 - p.angle;
  model.rotation.y = Math.atan2(Math.sin(yaw), Math.cos(yaw) + (u.soldier ? 0.6 : 0.2));
  if (u.soldier) {
    // kılıç darbesi, koşu ya da bekleyiş
    if (p.swing > 0) u.soldier.play('1H_Melee_Attack_Chop', 1.6, 0.08);
    else if (p.moving) u.soldier.play('Running_A', 1.2);
    else u.soldier.play('Idle');
    u.soldier.mixer.update(dt);
  } else {
    if (p.moving) animateHorse(u.horse, time, 15, p.seed);
    // mızrak darbesi: binici öne eğilir
    u.rider.root.rotation.x = p.swing * 0.5;
  }
}

export function disposePatrolModel(model) {
  const u = model.userData;
  (u.soldier || u.rider).dispose();
}
