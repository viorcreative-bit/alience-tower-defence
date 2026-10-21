# Emeği Geçenler ve Lisanslar

## 3D modeller

Oyundaki yapı, doğa, eşya ve asker modelleri **Kay Lousberg**'in (www.kaylousberg.com) KayKit paketlerinden gelir. İki paket de **Creative Commons Zero (CC0 1.0)** lisanslıdır: kişisel, eğitim ve ticari projelerde serbestçe kullanılabilir, atıf zorunlu değildir. Biz yine de teşekkür ederiz.

| Paket | Kaynak | Sürüm | Lisans | Kullandığımız yer |
|---|---|---|---|---|
| KayKit: Medieval Hexagon Pack 1.0 | https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0 (commit `84fa4e9`) | 1.0 (26.04.2024) | CC0 1.0 — http://creativecommons.org/publicdomain/zero/1.0/ | Surlar ve kapı, burç gövdeleri, saray (kale), kışla, okçu ocağı, evler, çarşı, kuyu, demirci, okçu kulesi, ağaçlar, kayalar, tepeler, dağlar, ordugâh eşyaları |
| KayKit: Adventurers Character Pack 1.0 | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 (commit `6720747`) | 1.0 (13.03.2023) | CC0 1.0 — http://creativecommons.org/publicdomain/zero/1.0/ | Düşman askerleri, Yeniçeri, Sipahi, Padişah ve tüfekçi (iskelet, animasyonlar ve gövdeler) |

`public/models/` içindeki dosyalar bu paketlerden `scripts/build-models.mjs` ile seçilip sıkıştırılmıştır (köşe nicemleme, WebP doku). Askerlerin renkleri, başlıkları (börk, sarık, kavuk), mızraklar, sancaklar ve tüfekler oyunun kendi kodunda eklenir.

## Elle kurulan modeller

Cami, Mektep, Darüşşifa, Bilimhane, Meşihat, Kadı Mahkemesi, Sipahi Ocağı, zift kazanı, Balyemez topu, tüfekçi tabyası, atlar, koçbaşı, kuşatma kulesi, çadırlar ve burç külahları bu projenin kodunda basit şekillerden kurulur (`src/render/`).

## Ses ve müzik

Mehter marşı, "Allah Allah!" tekbiri ve tüm efektler Web Audio API ile kodda üretilir (`src/audio/`). Hazır kayıt ya da telifli eser kullanılmaz.

## Yazı tipleri

- Cinzel — Natanael Gama, SIL Open Font License 1.1 (`@fontsource/cinzel`)
- Barlow Semi Condensed — Jeremy Tribby, SIL Open Font License 1.1 (`@fontsource/barlow-semi-condensed`)
