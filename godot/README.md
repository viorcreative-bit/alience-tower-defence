# Osmanlı Kale Savunması · Godot sürümü

Tarayıcı sürümünün (Vite + Three.js) Godot 4'e taşınmış hâli. Temel kurallar ve sayılar ana `CLAUDE.md` ve `src/data`'dan gelir. Godot sürümüne ayrıca kaynaklar (odun, demir, yemek), Yemekhane, Sofiler, yaralıların hastaneye dönmesi ve dalga dalga artan zorluk eklendi.

## İçinde ne var

- **Kuleler (4):** Okçu Kulesi, Zift Kazanı (yavaşlatır), Balyemez Topu (alan hasarı, Bilimhane gerekir), Tüfekçi Tabyası (Kışla gerekir). Her biri 3 seviyeye yükseltilir, satılınca harcamanın bir kısmı geri gelir.
- **Düşmanlar (7):** piyade, şövalye, hafif süvari, atlı okçu, komutan, koçbaşı, kuşatma kulesi. 12 dalga, her dalga başka bir milletin sancağıyla gelir; her dalgada düşmanın canı, sayısı ve hızı artar. Dalga aralarında ani baskınlar olur.
- **Şehir:** surların içinde Saray ve 10 bina (Mektep, Kışla, Okçu Ocağı, Darüşşifa, Sipahi Ocağı, Bilimhane, Meşihat, Kadı Mahkemesi, Cami, Yemekhane, Odun-Demir Ocağı, Çarşı). Her binanın 3 seviyesi ve kendi etkisi vardır; binalar 2. seviyeye serbestçe çıkar, 3. seviye için Saray'ın yükseltilmesi gerekir.
- **Akçe:** düşman ödülleri tarayıcı sürümünün 1,5 katı, dalga ödülü ve başlangıç akçesi daha bol. Çarşı birkaç saniyede bir akçe getirir, Saray dalga sonunda vergi verir.
- **Kaynaklar:** akçenin yanında odun, demir ve yemek. Saray her dalga sonunda odun ve demir, Yemekhane yemek verir. Odun-Demir Ocağı'nın işçileri surların önündeki kesim alanından odun, madenden demir taşır. Askerler ve Saray yükseltmesi bunlarla ödenir.
- **Şehir görünüşü:** "Şehre Bak" düğmesi kamerayı surların içine yaklaştırır (parmakla sağa sola kaydırılır). Sokaklarda halk gezer; şadırvan, çarşı, bahçeler, cumbalı evler, fenerler ve Cami önünde semazenler vardır.
- **Askerler:** Kışla Yeniçeri (en güçlü asker, en önde durur), Okçu Ocağı okçu, Sipahi Ocağı süvari, Cami Sofi yetiştirir. Sofiler arka sırada savaşır ve yanındaki askerlere can verir. Askerler surların önünde nöbet tutar; canı azalan asker Darüşşifa'ya yürür, iyileşince yerine döner.
- **"Allah Allah!" hücumu:** Meşihat kurulunca açılır, bir süre bütün kulelerin atış hızını artırır.
- Mehter müziği ve savaş sesleri koddan üretilir (dosya yok). Ses, ışık (Öğle · İkindi · Gece) ve en iyi dalga cihazda saklanır.

## Çalıştırma

1. [Godot 4.5](https://godotengine.org/download) kurun (standart sürüm, .NET gerekmez).
2. Godot'da **Import** → bu klasördeki `project.godot`.
3. F5 ile çalıştırın.

Web çıktısı: `GODOT=/yol/godot tools/export_web.sh` → `build/web/`. Motor tek iş parçacıklı derlendiği için özel sunucu başlığı (COOP/COEP) gerekmez; herhangi bir statik barındırma yeter.

Oyun mantığı testi: `godot --headless --script tests/sim.gd` (12 dalgayı kendi kendine oynar, hata olursa söyler).

Geliştirme için ekran görüntüsü: `godot --write-movie /tmp/kare.png --fixed-fps 10 --quit-after 80 -- --demo --wave=3 --light=1 --select=3,9`

## Dosyalar

- `scripts/data.gd`: bütün denge sayıları ve Türkçe metinler
- `scripts/game.gd`: oyun mantığı (görüntüden bağımsız, sabit adımlı)
- `scripts/world.gd`: zemin, surlar, şehir süsleri, ordugâh, ışık ve ateşler
- `scripts/models.gd`: kule, düşman, asker, at ve bina modelleri
- `scripts/ui.gd`: üst şerit, alt panel, sancak yazıları, oyun sonu ekranı
- `scripts/audio.gd`: ses efektleri ve mehter
- `scripts/main.gd`: hepsini birbirine bağlar, efektleri ve kamerayı yönetir
- `tools/blender/`: kuleleri, surları, kapıyı, binaları, çadırları, askerleri ve atı kodla kuran Blender betikleri (`assets/models/ottoman/*.glb`)
- `shaders/`: zemin (çim, yol, kaldırım), rüzgârda çim, dalgalanan sancak

## 3B modeller (Blender)

Kuleler, burçlar, surlar, kapı, 13 şehir binası, ordugâh çadırları, askerler, düşmanlar, şehir halkı ve at `tools/blender/` betikleriyle üretilir. Askerlerin iskeleti ve canlandırmaları (Idle, Walking_A, Running_A, Sit_Chair_Idle, Cheer, 1H_Melee_Attack_Chop) de betikte kurulur. Taşlar tek tek örülür, renkler köşe rengine yazılır, ortam gölgesi Cycles ile pişirilir; doku dosyası yoktur. Binaların "L2" ve "L3" parçaları seviye yükselince görünür, Cami'nin minareleri "M1".."M4".

```
pip install bpy            # Blender'ın Python modülü (ayrı Blender kurulumu gerekmez)
python tools/blender/build.py            # hepsi
python tools/blender/build.py gate       # tek model
```

Sonra `godot --headless --import` ve küçük resimler için `tools/render_thumbs.gd`.

## Kaynaklar

- Osmanlı yapıları ve kuleler: bu depodaki Blender betikleri.
- Bazı küçük süsler: [KayKit Medieval Hexagon Pack ve Adventurers](https://kaylousberg.itch.io/) — Kay Lousberg, CC0. Godot `KHR_mesh_quantization` desteklemediği için `gltf-transform dequantize` ile açılmış kopyalardır.
- Yazı tipleri: Cinzel ve Barlow Semi Condensed, SIL Open Font License 1.1 (`assets/fonts/OFL-*.txt`).
