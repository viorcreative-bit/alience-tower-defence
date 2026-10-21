import * as THREE from 'three';
import { animateHorse } from './figures.js';
import { buildSoldier, buildMounted, SOLDIER_HEIGHT } from './soldiers.js';

// Şehirde yetiştirilen askerler: Yeniçeri ve Okçu (yaya), Sipahi (atlı). +z ileri.
const SCALE = { janissary: 0.36 * (2.2 / SOLDIER_HEIGHT), archer: 0.34 * (2.2 / SOLDIER_HEIGHT), sipahi: 0.34 };

export function createUnitModel(unit) {
  const g = new THREE.Group();
  const holder = new THREE.Group();
  let u;
  if (unit.kind === 'sipahi') {
    const r = buildMounted('sipahi', null, null, { coat: 0x3a2a20, cloth: 0xb3202a, clothTrim: 0xe0b24a });
    holder.add(r.horse.root);
    u = { horse: r.horse, rider: r.rider, height: r.height };
  } else {
    const soldier = buildSoldier(unit.kind);
    soldier.play('Idle');
    holder.add(soldier.root);
    u = { soldier, height: SOLDIER_HEIGHT };
  }
  holder.scale.setScalar(SCALE[unit.kind]);
  g.add(holder);
  u.holder = holder;
  u.topY = u.height * SCALE[unit.kind];
  u.last = null;
  g.userData = u;
  return g;
}

export function updateUnitModel(model, unit, time) {
  const u = model.userData;
  const dt = u.last === null ? 0 : Math.min(0.1, time - u.last);
  u.last = time;
  const yaw = Math.PI / 2 - unit.angle;
  model.rotation.y = Math.atan2(Math.sin(yaw), Math.cos(yaw) + (u.soldier ? 0.6 : 0.2));
  const flash = unit.flash > 0 ? 0.7 : 0;
  if (u.soldier) {
    // kılıç darbesi / yay çekişi, yürüyüş ya da bekleyiş
    if (unit.swing > 0) u.soldier.play('1H_Melee_Attack_Chop', unit.kind === 'archer' ? 1.1 : 1.6, 0.08);
    else if (unit.moving) u.soldier.play('Running_A', 1.2);
    else u.soldier.play('Idle');
    u.soldier.mixer.update(dt);
    u.soldier.flash(flash);
  } else {
    if (unit.moving) animateHorse(u.horse, time, 15, unit.seed);
    // mızrak darbesi: binici öne eğilir
    u.rider.root.rotation.x = unit.swing * 0.5;
    u.rider.flash(flash);
  }
}

export function disposeUnitModel(model) {
  const u = model.userData;
  (u.soldier || u.rider).dispose();
}
