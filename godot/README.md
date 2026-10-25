# Osmanlı Kale Savunması · Godot sürümü

Tarayıcı sürümünün (Vite + Three.js) Godot 4'e taşınmış hâli. Temel kurallar ve sayılar ana `CLAUDE.md` ve `src/data`'dan gelir. Godot sürümüne ayrıca kaynaklar (odun, demir, yemek), Yemekhane, Sofiler, yaralıların hastaneye dönmesi ve dalga dalga artan zorluk eklendi.

## İçinde ne var

- **Ana menü ve giriş:** oyun açılınca komutan adıyla giriş yapılır (hesap cihazda, `user://hesaplar.cfg`; sunucu yok). Aynı adla girince şeref ve hükümdar seviyeleri geri gelir. Oyun içindeki "Menü" düğmesi ana menüye döner.
- **Devletler (6):** Osmanlı (Fatih Sultan Mehmed, kule hasarı), Bizans (XI. Konstantinos, sur), Venedik (Doç Francesco Foscari, akçe), Safevî (Şah İsmail, asker gücü), Habsburg (V. Karl, kule menzili), Memlük (Sultan Kayıtbay, atış hızı). Seçilen devletin sancakları surlarda dalgalanır, hükümdarı Saray'ın önünde durur; o devletin seferi sırası gelince Osmanlı ordusu saldırır.
- **Hükümdar geliştirme:** her hükümdar 1'den 5'e kadar yükselir. Bedeli şereftir; şeref her püskürtülen dalgada (dalga × 10) ve zaferde (+250) kazanılır. Her seviye devletin üstünlüğünü artırır ve kral modelinde yeni bir süs (mücevher, pelerin, kılıç/asa, altın süsler) açar. Sayılar `data.gd` içinde `COUNTRIES` ve `KING`.
- **Sefer haritası:** "Sefere Çık" parşömen haritayı açar. Beş kuşatma sırayla açılır: İstanbul 1453 (6 dalga), Belgrad 1521 (8), Rodos 1522 (9), Mohaç 1526 (10), Viyana 1529 (12). Her kalenin kendi yolu, düşman devletleri, can çarpanı ve zemin rengi vardır. Zaferde surda kalan sağlamlığa göre 1–3 yıldız, ilk zaferde kuşatmanın şerefi verilir. "Serbest Savaş" klasik yol ve 12 dalgadır. Sayılar `data.gd` içinde `STAGES`.
- **Kahraman komutanlar:** haritada savaştan önce biri seçilir. Surların önünde en ön sırada savaşır, düşerse 20 sn sonra kapıdan döner. Yeteneği sol alttaki düğmeyle dalga sırasında kullanılır: Barbaros Hayreddin "Top Yağmuru" (en öndeki düşmanlara 8 gülle), Mimar Sinan "Sur Onarımı" (sur +5, 12 sn surlar hasar almaz), Evliya Çelebi "Moral" (12 sn kuleler ve askerler %40 sert vurur, askerler iyileşir). Sayılar `HEROES` ve `HERO`.
- **Hava ve mevsimler:** her dalganın havası mevsime göre seçilir ve bir önceki dalga bitince görünür (sol üstte ve alt panelde). Yağmur menzili %10 kısar, tüfek ve topları yavaşlatır (ıslak barut), düşmanı ve askerleri yavaşlatır; kar düşmanı %22 yavaşlatır, kuleler yavaş atar; sis menzili %25 kısar. Kuşatmaların mevsimi sabittir (Viyana kış), serbest savaşta mevsim her 3 dalgada değişir. Zemin ve çim mevsime göre boyanır, kışın kar örter. Sayılar `WEATHER` ve `SEASONS`.
- **Medrese ve teknoloji ağacı:** Mektep kurulunca surların içinde Medrese kurulur. "Teknoloji Ağacı" düğmesi üç dalı açar: Barut (Kara Barut, Dökme Top, Şahi Topu), Mimari (Kesme Taş, Kemer ve Kubbe, Selimiye Usulü), Ticaret (Kervansaray, Lonca, İpek ve Baharat Yolu). Araştırmalar akçeyle ödenir, birkaç saniye sürer, aynı anda bir tane yapılır; kademe Medrese seviyesi kadar açılır. Sayılar `TECH` ve `TECH_FX`.
- **Patron dalgaları:** üç büyük düşman, üst ortada büyük can çubuğuyla gelir ve askerlerce durdurulamaz. Dev Mancınık en yakın kuleye taş atıp 4 sn susturur, Savaş Fili yanından geçtiği askerleri ezer, Dev Kuşatma Kulesi içinden piyade çıkarır ve kapıya varınca köprüsünü indirir. Serbest savaşta 4., 8. ve 12. dalgada, kuşatmalarda `STAGES[...].bosses` dalgalarında çıkarlar.
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

Kuşatma ve kahraman: `-- --stage=rodos --hero=sinan`; haritayı görmek için `-- --user=Ad --stars=2 --map`; yeteneği denemek için `-- --demo --wave=5 --use-hero --hero-at=5`; hava için `--weather=rain --season=autumn`; patronlar için `-- --demo --wave=6 --bosses`; Medrese için `-- --demo --tech`.

Menüyü atlamak için `-- --country=venice --king=3`; menüyü denemek için `-- --user=Ad --honor=500 --kings=2 --pick=mamluk` ya da `-- --login`.

Geliştirme için ekran görüntüsü: `godot --write-movie /tmp/kare.png --fixed-fps 10 --quit-after 80 -- --demo --wave=3 --light=1 --select=3,9`

## Dosyalar

- `scripts/data.gd`: bütün denge sayıları ve Türkçe metinler
- `scripts/game.gd`: oyun mantığı (görüntüden bağımsız, sabit adımlı)
- `scripts/world.gd`: zemin, surlar, şehir süsleri, ordugâh, ışık ve ateşler
- `scripts/models.gd`: kule, düşman, asker, at ve bina modelleri
- `scripts/ui.gd`: üst şerit, alt panel, sancak yazıları, oyun sonu ekranı
- `scripts/audio.gd`: ses efektleri ve mehter
- `scripts/menu.gd`: giriş, devlet seçimi, hükümdar geliştirme, sefer haritası ve kahraman seçimi
- `scripts/campaign.gd`: sefer haritasının çizimi (kıyılar, Tuna, kaleler, yıldızlar)
- `scripts/profile.gd`: cihazda saklanan hesaplar (şeref, hükümdar seviyeleri, en iyi dalga)
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
