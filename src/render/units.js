import * as THREE from 'three';
import { buildPerson, buildRider, animatePerson, animateHorse } from './figures.js';

// Devriye birlikleri: Yeniçeri (yaya) ve Sipahi (atlı). +z ileri.
const SCALE = { janissary: 0.36, sipahi: 0.34 };

export function createPatrolModel(p) {
  const g = new THREE.Group();
  const holder = new THREE.Group();
  let u;
  if (p.kind === 'janissary') {
    const person = buildPerson({
      tunic: 0x2f5c9e, trim: 0xb3202a, pants: 0x8a1c22, hat: 'bork', weapon: 'yatagan', shield: null, mustache: true,
    });
    holder.add(person.root);
    u = { person, height: person.height };
  } else {
    const r = buildRider(
      { tunic: 0xb3202a, trim: 0xe0b24a, hat: 'turban', weapon: 'lance', mustache: true, shield: 0xe0b24a },
      { coat: 0x3a2a20, cloth: 0xb3202a, clothTrim: 0xe0b24a },
    );
    holder.add(r.horse.root);
    u = { horse: r.horse, rider: r.rider, height: r.height };
  }
  holder.scale.setScalar(SCALE[p.kind]);
  g.add(holder);
  u.holder = holder;
  u.topY = u.height * SCALE[p.kind];
  g.userData = u;
  return g;
}

export function updatePatrolModel(model, p, time) {
  const u = model.userData;
  const yaw = Math.PI / 2 - p.angle;
  model.rotation.y = Math.atan2(Math.sin(yaw), Math.cos(yaw) + (u.person ? 0.6 : 0.2));
  const arm = u.person ? u.person.arms[1] : u.rider.arms[1];
  if (u.person) {
    if (p.moving) animatePerson(u.person, time, 10, p.seed);
    else u.person.root.position.y = 0;
  } else if (p.moving) {
    animateHorse(u.horse, time, 15, p.seed);
  }
  // kılıç / mızrak darbesi
  arm.rotation.x = -p.swing * 1.6;
}
