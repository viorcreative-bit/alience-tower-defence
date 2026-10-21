# Osmanlı Kale Savunması

Bu dosya, projeyi geliştiren Claude Code için ana rehberdir. Oyunun ne olduğunu, nasıl oynandığını, sayısal dengesini, teknik yapısını ve yol haritasını anlatır. Her yeni görevde önce bu dosyayı oku; bir karar burada yazanla çelişiyorsa önce bana sor.

Oyun önceden "Alien Wars Tower Defence" adlı uzaylı temalı bir kule savunmasıydı. Konsept değişti: artık **Osmanlı Devleti'nin kalesini ve şehrini**, sırayla saldıran dünya devletlerinin ordularına karşı savunuyoruz. Kule savunma çekirdeği (yol, dalga, kule kurma/yükseltme, Three.js 3D çizgi film görünümü) korunur; üstüne **şehir kurma** katmanı eklenir. Uzaylı temasından ekranda hiçbir iz kalmamalı. `reference/kale-savunmasi.html` ilk prototiptir, sadece referanstır.

---

## 1. Oyunun özeti

- **Ad:** Osmanlı Kale Savunması (çalışma adı; değişebilir)
- **Tür:** Kule savunma + şehir kurma, tek oyunculu, uzun soluklu
- **Platform:** Önce telefon tarayıcısı (dikey ekran), sonra Android ve iOS (Capacitor)
- **Kontrol:** Dokunma öncelikli; klavye ve fare de çalışır
- **Dil:** Tüm arayüz Türkçe

### Hikâye

Devlet-i Aliyye'nin sınır kalesi. Surların içinde **Padişah** sarayında, halk evlerinde yaşar. Dünyanın dört bir yanından devletler sırayla sefere çıkar; her dalgada farklı bir devletin ordusu ordugâhından çıkıp yoldan kale kapısına yürür. Oyuncu yolun kenarına savunma kuleleri kurar, surların içinde şehri seviye seviye geliştirir (okul, kışla, okçu ocağı, hastane, sipahi ocağı, bilimhane, din işleri, mahkeme, cami), Kışla, Okçu Ocağı ve Sipahi Ocağı'nda asker yetiştirir; askerler kapıdan çıkıp surların önünde düşmanı karşılar. Kapıya ulaşan her düşman **Sur**'u yıpratır; Sur yıkılırsa kale düşer.

### Ton ve saygı kuralları

- Tüm devletler **saygılı, stilize ordular** olarak çizilir: renkli üniforma, sancak rengi ve tarihî adla. Aşağılayıcı tasvir, karikatür yüz, dinî ya da etnik hakaret yok.
- Düşman ölünce kan yok; asker "dağılır" (renkli toz bulutu, düşen miğfer). Çocuklara uygun.
- Gerçek bayraklar yerine devletin tarihî renklerinden yapılmış sade sancaklar kullanılır. Osmanlı tarafında hilal ve yıldızlı kırmızı sancak kullanılır.
- Dinî öğeler (cami, tekbir) saygıyla kullanılır: cami bir yapı ve moral kaynağıdır; dövüş animasyonu ya da şaka konusu yapılmaz.

---

## 2. Oynanış

### Temel döngü

1. **Hazırlık evresi:** Yolun dışındaki boş kareye dokunup kule kurarsın. Surların içindeki arsalara dokunup şehir binası kurar ya da yükseltirsin.
2. **Dalga evresi:** "Dalgayı Başlat" ile sıradaki devletin ordusu gelir. Ekranda "Bizans Ordusu geliyor!" gibi şerit çıkar, mehter vurur, askerler "Allah Allah!" diye karşılık verir. Dalga sürerken de kurma ve yükseltme yapılır.
3. **Dalga sonu:** Bonus akçe, şehrin gelirleri (vergi, vakıf) ve hastanenin Sur onarımı verilir.
4. **Ani baskın:** Hazırlık evresinde uzun beklersen (2. dalgadan sonra) sıradaki devletin akıncıları habersiz baskın yapar. Baskın dalga sayılmaz, kısa ve hızlıdır.
5. **Bitiş:** Tüm seferler püskürtülürse zafer, Sur sıfırlanırsa yenilgi.

### Kaynaklar

| Kaynak | Başlangıç | Açıklama | Aşama |
|---|---|---|---|
| **Akçe** | 220 | Kule, bina ve yükseltme parası. Düşman ölünce, dalga bitince, vergi ve vakıftan gelir. | 1 |
| **Sur** | 20 | Kalenin sağlamlığı. Kapıya ulaşan düşman kendi hasarı kadar azaltır. Hastane onarır. | 1 |
| **Dalga** | 0/12 | Hangi seferde olunduğu. | 1 |
| **Nüfus** | — | Evler ve saray seviyesiyle artar; bina kurmak için işçi gerekir. | 3 |
| **Erzak** | — | Çiftlik/değirmenle üretilir; asker beslemek için. | 3 |
| **İlim** | — | Mektep ve bilimhane üretir; araştırma ağacında harcanır. | 3 |

- Dalga bonusu: `20 + dalgaNo × 5` akçe (son dalgada yok)
- Kule satış değeri: harcananın **%70'i**. Binalar satılmaz.

### Hız ve kontrol

- Hız düğmesi 1× → 2× → 3×. Ses düğmesi: müzik ve efektleri aç/kapa.
- Seçili şeye ikinci kez dokunmak seçimi kaldırır.

---

## 3. Harita

- Izgara: **9 sütun × 16 satır**. Satır 0–11 savaş alanı, **satır 12 surlar** (kapı 4. sütunda), **satır 13–15 surların içindeki şehir**.
- Yol (sütun, satır): `[1,-1] → [1,2] → [6,2] → [6,5] → [2,5] → [2,8] → [7,8] → [7,10] → [4,10] → [4,12]`
- `[1,-1]` ekranın üstündeki **düşman ordugâhı** (çadırlar ve o dalganın sancağı), `[4,12]` **kale kapısı**.
- Yola, surlara ve şehre kule kurulamaz. Şehirdeki her binanın sabit bir arsası vardır (bkz. 6. bölüm).
- Yol verisi `src/data/maps.js` içinde; ileride başka kaleler (Belgrad, Kandiye, Viyana önü...) eklenecek.

---

## 4. Savunma kuleleri

Bazı kuleler başta kilitlidir; şehirde ilgili bina kurulunca açılır.

| Kule | Maliyet | Menzil | Hasar | Atış (sn) | Mermi hızı | Özellik | Kilit |
|---|---|---|---|---|---|---|---|
| **Okçu Kulesi** | 50 | 2.6 | 11 | 0.55 | 10 | Hızlı, tek hedef | Açık |
| **Zift Kazanı** | 70 | 2.2 | 5 | 0.9 | 8 | %45 yavaşlatma, 1.6 sn | Açık |
| **Balyemez Topu** | 90 | 2.3 | 28 | 1.5 | 6 | Alan hasarı, yarıçap 0.95 | Bilimhane 1 |
| **Tüfekçi Tabyası** | 120 | 3.2 | 46 | 1.7 | anında | Zırhı tamamen deler | Kışla 1 |

### Yükseltme

- En fazla **3. seviye**; maliyet `round(kuleMaliyeti × 0.75 × mevcutSeviye)`, Mektep indirimi düşülür.
- Her seviyede hasar × 1.6, menzil + 0.35, atış aralığı × 0.9, zift yavaşlatması +%10 (en fazla %70).
- Şehir bonusları (Okçu Ocağı, Bilimhane) bunun üstüne çarpan olarak eklenir.

### Hedef seçimi

Menzildeki düşmanlardan yolda en çok ilerlemiş olanı. (Aşama 3: İlk / En güçlü / En yakın.)

### Görsel tarif

- **Okçu Kulesi:** Kesme taş kule, kırmızı külahlı çatı (KayKit). Arkasında ışıklı iz bırakan ok mermisi.
- **Zift Kazanı:** Taş ocak üstünde bakır kazan, altında ateş, üstünde dumanlı kara zift. Vurduğu düşmanın altında kara leke.
- **Balyemez Topu:** Ahşap kundak üstünde bronz top. Gülle atar, çarpınca toz halkası.
- **Tüfekçi Tabyası:** Toprak-taş tabya üstünde beyaz börklü Yeniçeri tüfekçi. Atışta namlu alevi ve duman.
- Seviye: kaidede 1–3 altın nokta; seviye arttıkça kule biraz büyür, 3. seviyede tepeye küçük sancak.

---

## 5. Düşman birlikleri

Birlik türleri her devlette aynıdır; rengi, sancağı ve adı o dalganın devletinden gelir.

| Birlik | Can | Hız | Zırh | Ödül | Sur hasarı | Yarıçap | Not |
|---|---|---|---|---|---|---|---|
| **Piyade** | 42 | 1.1 | 0 | 5 | 1 | 0.22 | Mızrak ve kalkan |
| **Hafif Süvari** | 28 | 2.0 | 0 | 6 | 1 | 0.20 | Atlı, hızlı |
| **Zırhlı Şövalye** | 150 | 0.7 | 4 | 12 | 2 | 0.27 | Ağır zırh, miğfer |
| **Atlı Okçu** | 36 | 1.8 | 1 | 7 | 1 | 0.21 | Atlı |
| **Koçbaşı** | 260 | 0.6 | 6 | 20 | 3 | 0.32 | Tekerlekli çatılı ahşap koç |
| **Kuşatma Kulesi** | 1100 | 0.5 | 3 | 70 | 6 | 0.38 | Uyarı: "Kuşatma kulesi geliyor!" |
| **Başkomutan** | 2400 | 0.42 | 6 | 150 | 10 | 0.42 | Atlı komutan; uyarı şeridi |

- Can büyümesi: `round(temelCan × 1.2^(dalgaNo − 1))`
- Zırh: her vuruştan zırh kadar düşülür, en az 1 geçer. Tüfekçi zırhı deler.

---

## 6. Şehir (surların içi)

Şehir surların içindeki 3 satırdır. **Saray** ortadadır, Padişah orada yaşar. Diğer binaların her biri kendi arsasına kurulur; arsaya dokununca alt panelde bina kartı açılır. Kurulan bina 3D olarak arsada belirir, seviyesiyle büyür.

**Saray seviyesi diğer binaların en yüksek seviyesini belirler** (Saray 1 → binalar en fazla 1. seviye). Böylece oyun uzun soluklu, adım adım ilerler.

| Bina | Arsa (sütun,satır) | Maliyet (1/2/3) | Ön koşul | Etkisi (seviye başına) | Aşama |
|---|---|---|---|---|---|
| **Saray** (Padişah) | (4,14) | başta 1 / 260 / 480 | — | Diğer binaların seviye sınırı = Saray seviyesi | 1 |
| **Mektep** (okul) | (1,13) | 80 / 160 / 240 | — | Kule yükseltmeleri %10 ucuz | 1 |
| **Kışla** (asker geliştirme) | (7,13) | 100 / 200 / 300 | — | 1: Tüfekçi Tabyası açılır. Seviye başına 2 Yeniçeri yetiştirilebilir | 1 |
| **Okçu Ocağı** (okçu geliştirme) | (0,14) | 70 / 150 / 240 | — | Okçu Kulesi hasarı +%20, menzil +0.15. Seviye başına 2 okçu yetiştirilebilir | 1 |
| **Darüşşifa** (hastane) | (2,15) | 90 / 180 / 270 | — | Dalga sonunda Sur +1 onarım; dalga sırasında askerler saniyede +2 can | 1 |
| **Sipahi Ocağı** (atlı birlik geliştirme) | (8,14) | 140 / 240 / 340 | Kışla 1 | Seviye başına 1 Sipahi yetiştirilebilir (ikişer düşman durdurur) | 1 |
| **Bilimhane** (bilim) | (1,15) | 120 / 220 / 320 | Mektep 1 | 1: Balyemez Topu açılır. Top hasarı +%15, zift yavaşlatma +%5 | 1 |
| **Meşihat** (din işleri) | (6,15) | 110 / 210 / 310 | Cami 1 | 1: "Allah Allah!" hücum düğmesi açılır; seviye süreyi ve gücü artırır | 1 |
| **Kadı Mahkemesi** | (5,13) | 100 / 200 / 300 | — | Dalga sonu +12 akçe vergi; ani baskınlar %20 seyrek | 1 |
| **Cami** | (7,15) | 120 / 240 / 360 | — | Dalga sonu +10 akçe vakıf geliri; minare sayısı 1 / 2 / 4 | 1 |
| Evler, Çarşı, Değirmen, Tophane, Tersane | — | — | — | Nüfus, ticaret, erzak, ağır top, deniz | 3–4 |

### "Allah Allah!" hücumu (Meşihat)

- Düğmeye basınca askerler tekbir getirir (sentezlenmiş kalabalık sesi), ekranda altın şerit çıkar.
- Süresince tüm kulelerin ve askerlerin atış hızı artar: seviye 1/2/3 için +%30 / +%45 / +%60, süre 6 / 8 / 10 sn, bekleme 60 / 50 / 40 sn.

### Asker yetiştirme ve sur önü savunması

- Kışla, Okçu Ocağı ve Sipahi Ocağı'nın bina kartında "Yetiştir · akçe" düğmesi vardır. Basınca akçe ödenir, asker sıraya girer, süresi dolunca kale kapısından "Allah Allah!" diye çıkıp surların önündeki yerine yürür. Askerler hem hazırlıkta hem dalga sırasında yetiştirilir.
- Binanın her seviyesi asker sınırını artırır (Yeniçeri ve Okçu seviye başına 2, Sipahi 1). Seviye arttıkça askerlerin canı ve hasarı +%25 artar (var olanlar dahil).
- **Yeniçeri:** 40 akçe, 4 sn; can 120, kılıç 10 / 0.7 sn, menzil 0.6; 1 düşmanı durdurur.
- **Okçu:** 35 akçe, 3.5 sn; can 60, ok 8 / 0.9 sn, menzil 2.4; düşman durdurmaz, kapının iki yanında, surların önünde durur.
- **Sipahi:** 70 akçe, 6 sn; can 200, mızrak 16 / 0.8 sn, menzil 0.65; aynı anda 2 düşmanı durdurur, sıranın önünde durur.
- Yakın dövüşçüler kapıdan dışarıya doğru yolun üstünde ikişerli sıralanır. Önünü kestikleri düşman durur ve onlarla dövüşür. Koçbaşı ve kuşatma kulesi durdurulamaz.
- Durdurulan düşman askere saniyede bir vurur (Piyade 6, Hafif Süvari 5, Şövalye 12, Atlı Okçu 5, Başkomutan 30; dalga başına +%8).
- Askerler hazırlıkta saniyede 10 can, dalga sırasında Darüşşifa seviyesi × 2 can iyileşir (dövüşmüyorken). Ölen asker dağılır ("Şehit düştü"), yeniden yetiştirilmelidir.
- Sayılar `src/data/buildings.js` (TROOPS, ARMY) ve `src/data/enemies.js` (melee, ENEMY_MELEE) içinde; mantık `src/systems/army.js`.

---

## 7. Seferler (dalgalar)

Her dalga farklı bir devletin ordusudur. Gruplar `[birlik, adet, aralık (sn)]`.

| Dalga | Devlet | Renk | İçerik |
|---|---|---|---|
| 1 | Bizans İmparatorluğu | mor / altın | 10 Piyade (0.9) |
| 2 | Sırp Despotluğu | kırmızı / mavi | 14 Piyade (0.75) |
| 3 | Macar Krallığı | kırmızı / beyaz | 8 Piyade (0.8) + 8 Hafif Süvari (0.5) |
| 4 | Venedik Cumhuriyeti | koyu kırmızı / altın | 5 Şövalye (1.2) + 10 Piyade (0.6) + 6 Atlı Okçu (0.6) |
| 5 | Memlük Sultanlığı | sarı / kahve | 20 Hafif Süvari (0.4) + 1 Kuşatma Kulesi (2.0) |
| 6 | Safevî Devleti | yeşil / kırmızı | 10 Şövalye (1.0) + 8 Atlı Okçu (0.5) + 12 Piyade (0.5) |
| 7 | Lehistan Krallığı | kırmızı / beyaz | 14 Hafif Süvari (0.4) + 10 Şövalye (0.9) + 3 Koçbaşı (1.5) |
| 8 | Habsburg Monarşisi | siyah / altın | 18 Şövalye (0.8) + 1 Kuşatma Kulesi (2.0) + 4 Koçbaşı (1.4) |
| 9 | İspanya Krallığı | kırmızı / sarı | 22 Hafif Süvari (0.35) + 10 Atlı Okçu (0.4) + 12 Şövalye (0.7) |
| 10 | Rus Çarlığı | beyaz / mavi | 16 Şövalye (0.8) + 8 Atlı Okçu (0.4) + 5 Koçbaşı (1.2) + 1 Kuşatma Kulesi (2.0) |
| 11 | Fransa Krallığı | mavi / altın | 24 Piyade (0.3) + 14 Şövalye (0.7) + 2 Kuşatma Kulesi (2.5) |
| 12 | Kutsal İttifak | beyaz / kırmızı | 10 Şövalye (0.9) + 2 Kuşatma Kulesi (2.5) + 1 Başkomutan (2.0) + 16 Hafif Süvari (0.35) + 5 Koçbaşı (1.2) |

- Hazırlık evresinde panelde "Sıradaki sefer: Macar Krallığı — 8 Piyade ve 8 Hafif Süvari."
- **Ani baskın:** 3. dalgadan önce başlamaz. Hazırlık evresinde 45–70 sn beklenirse (Mahkeme seviyesi başına süre %20 uzar) sıradaki devletin 4 + dalgaNo/2 Hafif Süvarisi baskın yapar. Bitince küçük bonus (10 akçe). Baskın sırasında dalga başlatılamaz.
- İleride (Aşama 3–4): Çin, Japonya, Hindistan, Britanya gibi uzak devletlerle "Cihan Seferleri" ikinci bölümü ve sonsuz mod.

---

## 8. Ses ve müzik

Hiçbir hazır kayıt ya da telifli eser kullanılmaz; **tüm sesler Web Audio API ile kodda üretilir** (çevrimdışı çalışır).

- **Mehter müziği:** Mehter tarzında özgün bir marş: kös/davul (alçak sinüs + gürültü vuruşu), nakkare (kısa, tiz davul), zil (filtrelenmiş beyaz gürültü), zurna (testere dişi dalga + bant geçiren filtre + vibrato, Hicaz dizisinde ezgi). Dalga sırasında tam, hazırlıkta sadece davul ve hafif zurna.
- **"Allah Allah!" sesi:** Formant sentezi ile çok sesli kalabalık tekbiri ("Al-lah Al-lah"): her ses farklı perdede, hafif zaman kaymalı. Dalga başında, yetişen asker kapıdan çıkarken ve hücum düğmesinde.
- **Efektler:** ok vınlaması, top gümlemesi, tüfek patlaması, zift fokurtusu, düşman dağılması, ani baskın borusu, bina kurma çekici.
- Ses aç/kapa düğmesi; ayar `localStorage`'da saklanır. Tarayıcı kuralı gereği ses ilk dokunuşta başlar.
- İleride oyuncu kendi kayıt dosyalarını `public/sounds/` içine koyarsa sentez yerine onlar çalınabilir (Aşama 2).

---

## 9. Görsel kimlik

- **Ortam:** Çizgi film tarzı. Yeşil çimen, kumlu yol (önceki görünüm korunur). Surlar kesme taş, mazgallı; iki yanda yuvarlak burç kuleleri, kurşun kaplı sivri külah çatılar, kapının üstünde hilal ve yıldızlı kırmızı sancak.
- **Şehir:** Arnavut kaldırımı zemin, beyaz badanalı kırmızı kiremit çatılı evler, ortada saray (köşkler, altın alem), Padişah sarayın önünde kırmızı kaftan ve beyaz kavuklu figür olarak durur.
- **Saray:** Topkapı esinli, kodla kurulur: mermer avlu ve havuz, kasnaklı Divan kubbesi, revak, çini şerit, altın kapı, bahçeler. 2. seviyede iki yanda geniş saçaklı köşkler ve galeriler, 3. seviyede Adalet Kulesi, Bâbüsselâm'ın sivri külahlı kuleleri ve sancaklar.
- **Binalar:** Hepsi taş kaide üstünde; kaidenin önünde seviye kadar altın düğme. Sivri kemerli pencereler, İznik mavisi çini şerit, kasnaklı kubbeler; her seviyede yeni parça eklenir (revak gözü, yan kubbe, kule, sancak) ve bina biraz büyür.
- **Arsalar:** Boş arsada taş temel, kırmızı başlı kazıklar ve ip, üstünde "+" ve binanın adı yazan işaret (kurulabiliyorsa kırmızı-altın, değilse gri). Kurulu bina yükseltilebiliyorsa üstünde "▲". Seviyeler oturunca tüm şehir malzeme başına tek ağa birleşir (çizim çağrısı az).
- **Cami:** Kurşun gri kubbe, altın alem, ince kalem minareler (seviyeye göre 1/2/4).
- **Ordugâh:** Ekranın üstünde o devletin renginde çadırlar ve sancak; dalga değişince renk değişir.
- **Renk paleti:**
  - Arayüz paneli `#1f1712`, kenar `#4a3524`, metin `#f3e6c8`, soluk metin `#b9a383`
  - Osmanlı kırmızısı `#b3202a`, altın `#e0b24a`, akçe `#f2c94c`, sur `#cfd6e0`, tehlike `#ff5b4d`
  - 3D renkler `src/render/palette.js` içinde.
- **Yazı tipleri:** Başlık "Cinzel" (klasik, oymalı), arayüz "Barlow Semi Condensed" (Türkçe karakterli). İkisi de pakete gömülü.
- **Görünüm 3D:** Three.js, `MeshStandardMaterial` + ACES ton eşleme, kamera güneyden ~54° eğik. Yüksek kalitede son işlem: parlama (bloom), yumuşak gölge, sıcak renk ayarı ve kenar karartması (`src/render/post.js`).
- **Modeller:** Yapılar, doğa ve askerler KayKit (CC0) paketlerinden; `scripts/build-models.mjs` seçer ve sıkıştırır, çıktı `public/models/`. Kaynak ve lisanslar `CREDITS.md`'de. Osmanlı'ya özgü yapılar (cami, mektep, darüşşifa, bilimhane, meşihat, mahkeme), toplar, kazanlar ve atlar koddaki şekillerden kurulur. Askerler iskeletli KayKit gövdeleridir: devlet renkleri gri dokuyla boyanır, başlıklar (börk, sarık, kavuk, miğfer) kafa kemiğine takılır.
- **Canlılık:** Dalgalanan sancaklar (köşe gölgelendiricisi), duman, kıvılcım, namlu dumanı, ok izi, yanan zift ve kuşlar (`src/render/ambient.js`, `flags.js`).
- **Kalite:** Yüksek / Düşük düğmesi (HD/SD). Düşük kalitede son işlem yok, gölge sert, dpr 1. Oyuncu seçmediyse yavaş karede kendiliğinden düşüğe geçer.

---

## 10. Arayüz düzeni (dikey telefon)

```
┌──────────────────────────────────┐
│ OSMANLI  KALE SAVUNMASI  Akçe Sur Dalga │ ← üst şerit
├──────────────────────────────────┤
│  ordugâh (üstte)                 │
│  savaş alanı 9 × 12              │ ← 3D sahne
│  ═══ surlar / kapı ═══           │
│  şehir 9 × 3 (saray, binalar)    │
├──────────────────────────────────┤
│ bağlamsal panel                  │ ← ipucu / kule kartları / kule / bina
│ [🔊] [1×] [Allah Allah!] [Dalgayı Başlat] │
└──────────────────────────────────┘
```

- Panel durumları: ipucu + sıradaki sefer; kule kartları (kilitliyse "Bilimhane gerekli"); seçili kule; seçili bina (ad, seviye, etkisi, sonraki seviyenin etkisi, "Kur · 120" / "Yükselt · 240", kilit nedeni).
- Panel yüksekliği sabit. Zafer: "Devlet-i Aliyye Muzaffer!", yenilgi: "Kale Düştü".

---

## 11. Teknik yapı

- Saf HTML + CSS + JS (ES modülleri), Three.js, Vite. Arayüz framework'ü yok; tamamen çevrimdışı.
- Klasörler: `src/data` (denge: towers, enemies, waves, nations, buildings, maps, rules), `src/systems` (spawner, movement, combat, effects, city, army, raid), `src/render` (scene, post, models, soldiers, world, city, towers, enemies, units, fx, ambient, flags, background, palette), `src/audio` (sfx, mehter, chant), `src/ui`, `src/i18n/tr.js`.
- **Kurallar:** Denge sayıları sadece `src/data/` içinde. Sabit adım ≤ 0.03 sn. Mantık kare biriminde 2D; 3D çeviri sadece çizimde. WebGL dpr ≤ 1.25 (yüksek) / 1 (düşük). Tek gölge ışığı. Durağan modeller `bakeStatic` ile malzeme başına tek ağa birleştirilir. Kayıt `localStorage` + try/catch. Kod İngilizce, oyuncu metinleri Türkçe ve `tr.js`'de.
- Geliştirme sırasında `window.__game` ile durum incelenebilir.

---

## 12. Yol haritası

Her aşamanın sonunda oyun oynanabilir olmalı.

**Aşama 1 — Osmanlı teması ve şehir çekirdeği (ilk görev)**
- Tüm uzaylı temasını Osmanlı temasına çevir: kuleler, düşman birlikleri, ordugâh, surlar, kapı, renkler, yazılar
- Haritayı 9 × 16 yap; surlar ve şehir alanı
- 12 devletlik sefer listesi, her dalgada devlet adı ve rengi
- Şehir: Saray ve 9 bina, seviye sınırı, arsaya dokunarak kurma/yükseltme, 3D bina modelleri, Padişah figürü
- Kilitli kuleler (Balyemez ← Bilimhane, Tüfekçi ← Kışla)
- Binalarda asker yetiştirme (Yeniçeri, Okçu, Sipahi); askerler surların önünde düşmanı durdurur
- Ani baskın
- "Allah Allah!" hücumu
- Sentezlenmiş mehter müziği, tekbir sesi ve efektler; ses düğmesi

**Aşama 2 — Derinlik ve cila**
- Başlangıç ekranı, duraklatma, kayıtlı oyuna devam (uzun oyun için otomatik kayıt)
- Düşman okçuları kulelere ateş eder, kuleler onarılır
- İsteğe bağlı gerçek ses dosyası desteği

**Aşama 3 — Büyük şehir**
- Nüfus, Erzak, İlim kaynakları; Evler, Çarşı, Değirmen
- Araştırma ağacı (Bilimhane), Saray 4–5
- Yeni kaleler ve "Cihan Seferleri" (uzak devletler), zorluk seçimi, hedef modları

**Aşama 4 — Uygulama**
- Capacitor ile Android/iOS, ikon ve açılış ekranı (Osmanlı temalı), dikey kilit, uyku engelleme

---

## 13. Kabul kriterleri (Aşama 1)

- [ ] 360–430 px genişlikte yatay kaydırma olmadan oynanıyor
- [ ] 4 kule kurulup 3. seviyeye yükseltilebiliyor ve satılabiliyor; kilitli kuleler bina kurulunca açılıyor
- [ ] 12 dalga tabloya göre, her biri kendi devletinin adı ve rengiyle geliyor
- [ ] Saray ve 9 bina kurulup yükseltilebiliyor; Saray seviye sınırı ve ön koşullar çalışıyor; etkiler oyuna yansıyor
- [ ] Binalarda asker yetiştiriliyor; askerler surların önünde düşmanı durdurup dövüşüyor, ölünce yeniden yetiştiriliyor
- [ ] Ani baskın geliyor; "Allah Allah!" hücumu atış hızını artırıyor
- [ ] Mehter müziği ve tekbir sesi çalıyor, ses düğmesiyle kapanıyor
- [ ] Zafer/yenilgi ekranları ve "Yeniden Oyna" çalışıyor
- [ ] Ekranda uzaylı temasından iz yok, konsolda hata yok
