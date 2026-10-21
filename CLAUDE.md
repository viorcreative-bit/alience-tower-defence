# Alien Wars Tower Defence

Bu dosya, projeyi geliştiren Claude Code için ana rehberdir. Oyunun ne olduğunu, nasıl oynandığını, sayısal dengesini, teknik yapısını ve yol haritasını anlatır. Her yeni görevde önce bu dosyayı oku; bir karar burada yazanla çelişiyorsa önce bana sor.

Projede `kale-savunmasi.html` adında çalışan bir ilk sürüm (prototip) var. Oyun mantığı, dalga sistemi ve kule/düşman dengesi orada hazır. Bu projede o prototipi **uzaylı temasına** taşıyıp, düzenli bir kod yapısına bölüp geliştireceğiz. Prototipteki ortaçağ teması (kale, okçu, şövalye) tamamen kaldırılacak.

---

## 1. Oyunun özeti

- **Ad:** Alien Wars Tower Defence
- **Tür:** Klasik kule savunma (tower defense), tek oyunculu
- **Platform:** Önce telefon tarayıcısı (dikey ekran), sonra Android ve iOS uygulaması (Capacitor ile paketlenecek)
- **Kontrol:** Sadece dokunma. Klavye ve fare de çalışmalı ama tasarım parmak için yapılır.
- **Oyun süresi:** Bir oyun 10–15 dakika
- **Dil:** Arayüz metinleri Türkçe. Oyunun adı İngilizce kalır: "Alien Wars Tower Defence".

### Hikâye

Yıl 2189. İnsanlığın Mars'taki son kolonisi **Nova Üssü**, gezegenin altından çıkan uzaylı sürüsünün hedefinde. Uzaylılar bir solucan deliğinden (portal) çıkıp kanyon yolundan üssün enerji çekirdeğine doğru ilerliyor. Oyuncu, yolun kenarına savunma kuleleri kurarak her dalgayı durdurmaya çalışır. Çekirdeğe ulaşan her uzaylı üssün kalkanını azaltır. Kalkan sıfırlanırsa üs düşer.

---

## 2. Oynanış

### Temel döngü

1. **Hazırlık evresi:** Oyuncu boş (yol olmayan) bir kareye dokunur, açılan menüden kule seçip kurar. Kurulu kuleye dokunursa yükseltir ya da satar.
2. **Dalga evresi:** "Dalgayı Başlat" düğmesine basınca uzaylılar portaldan çıkar ve yolu takip eder. Dalga sürerken de kule kurulabilir ve yükseltilebilir.
3. **Dalga sonu:** Tüm uzaylılar yok edilince bonus kristal verilir ve hazırlık evresine dönülür.
4. **Bitiş:** 10 dalga temizlenirse zafer, kalkan sıfırlanırsa yenilgi ekranı gösterilir.

### Kaynaklar

| Kaynak | Prototipteki adı | Başlangıç | Açıklama |
|---|---|---|---|
| **Kristal** | Altın | 150 | Kule kurma ve yükseltme parası. Uzaylı öldürünce ve dalga bitince kazanılır. |
| **Kalkan** | Can | 15 | Çekirdeğe ulaşan her uzaylı kendi "hasar" değeri kadar azaltır. |
| **Dalga** | Dalga | 0/10 | Hangi dalgada olunduğunu gösterir. |

- Dalga bitiş bonusu: `15 + dalgaNo × 5` kristal (son dalgada bonus yok)
- Zorluk prototipe göre artırıldı (prototip: 200 kristal, 20 kalkan, bonus `20 + dalgaNo × 5`, can büyümesi 1.13).
- Kule satış değeri: kuleye harcanan toplam kristalin **%70'i**

### Hız ve kontrol

- Oyun hızı düğmesi: 1× → 2× → 3× → 1× döngüsü
- Bir kareye ikinci kez dokunmak seçimi kaldırır
- Yola veya ızgara dışına dokunmak seçimi kaldırır

---

## 3. Harita

- Izgara: **9 sütun × 14 satır**, kareler her zaman kare
- Kare boyutu ekrana göre hesaplanır: `min(alanGenişliği / 9, alanYüksekliği / 14)`
- Yol, köşe noktalarıyla tanımlanır (sütun, satır). Prototipteki yol:

```
[1,-1] → [1,2] → [6,2] → [6,5] → [2,5] → [2,8] → [7,8] → [7,11] → [4,11] → [4,14]
```

- `[1,-1]` ekranın üstündeki **portal** (uzaylıların çıktığı yer), `[4,14]` ekranın altındaki **enerji çekirdeği**.
- Düşmanlar kare merkezlerinden (`sütun + 0.5`, `satır + 0.5`) geçen çizgiyi takip eder.
- Yol üstündeki karelere kule kurulamaz.

İleride birden çok harita olacağı için yol verisi koddan ayrı bir dosyada (`src/data/maps.js`) tutulmalı.

---

## 4. Kuleler

Prototipteki dört kule uzaylı temasına şöyle çevrilecek. Sayılar prototipten birebir alınmıştır, değiştirmeden başla.

| Kule | Prototipte | Maliyet | Menzil (kare) | Hasar | Atış aralığı (sn) | Mermi hızı | Özellik |
|---|---|---|---|---|---|---|---|
| **Lazer Tareti** | Okçu | 50 | 2.6 | 11 | 0.55 | 10 | Hızlı, tek hedef |
| **Plazma Topu** | Top | 90 | 2.2 | 26 | 1.5 | 6 | Alan hasarı, yarıçap 0.95 kare |
| **Kriyo Kulesi** | Buz | 70 | 2.2 | 5 | 0.9 | 8 | %45 yavaşlatma, 1.6 sn |
| **Tesla Bobini** | Büyücü | 120 | 3.2 | 46 | 1.7 | anında | Zırhı tamamen deler, şimşek efekti |

### Yükseltme

- En fazla **3. seviye**
- Yükseltme maliyeti: `round(kuleMaliyeti × 0.75 × mevcutSeviye)`
- Her seviyede:
  - Hasar × 1.6
  - Menzil + 0.35 kare
  - Atış aralığı × 0.9 (daha hızlı)
  - Kriyo yavaşlatması +%10 (en fazla %70)

### Hedef seçimi

Kule, menzilindeki uzaylılardan **yolda en çok ilerlemiş olanı** hedefler. (İleride oyuncunun seçebileceği hedef modları eklenecek: ilk, en güçlü, en yakın.)

### Görsel tarif

- **Lazer Tareti:** Metal kaide üstünde dönen ince namlu. Kırmızı lazer ışını ya da kısa lazer mermisi.
- **Plazma Topu:** Kalın, kısa namlu. Yeşil-mavi parlayan plazma topu atar, çarpınca halka şeklinde patlama.
- **Kriyo Kulesi:** Buz mavisi kristal ya da antenli soğutma kulesi. Vurduğu uzaylının etrafında mavi halka çıkar.
- **Tesla Bobini:** Bobin şeklinde kule, tepesinde nabız gibi atan mor-beyaz enerji küresi. Hedefe zikzaklı şimşek çakar.
- Kulelerin seviyesi kaidenin altında küçük ışıklı noktalarla gösterilir (1, 2 veya 3 nokta).

---

## 5. Uzaylılar

| Uzaylı | Prototipte | Can | Hız (kare/sn) | Zırh | Ödül | Kalkan hasarı | Boyut (yarıçap) |
|---|---|---|---|---|---|---|---|
| **Sürüngen** | Piyade | 42 | 1.1 | 0 | 5 | 1 | 0.22 |
| **Akrep** (hızlı) | Akıncı | 28 | 2.0 | 0 | 6 | 1 | 0.18 |
| **Kabuklu** (zırhlı) | Şövalye | 150 | 0.7 | 4 | 12 | 2 | 0.27 |
| **Uçan Daire** (uzay aracı) | — | 36 | 1.8 | 1 | 7 | 1 | 0.20 |
| **Savaş Gemisi** (uzay aracı) | — | 260 | 0.6 | 6 | 20 | 3 | 0.32 |
| **Dev** (ara boss) | — | 1100 | 0.5 | 3 | 70 | 6 | 0.38 |
| **Ana Beyin** (boss) | Dev | 2400 | 0.42 | 6 | 150 | 10 | 0.42 |

- Canlar her dalgada büyür: `can = round(temelCan × 1.2^(dalgaNo − 1))` (prototipte 1.13)
- **Zırh:** Her vuruştan zırh kadar hasar düşülür, en az 1 hasar geçer. Tesla Bobini zırhı yok sayar.
- **Yavaşlama:** Hız `× (1 − yavaşlamaOranı)` olur. Birden çok yavaşlamada en güçlüsü geçerlidir.

### Görsel tarif

- **Sürüngen:** Yeşil, yuvarlak gövdeli, tek gözlü küçük uzaylı.
- **Akrep:** Turuncu, küçük ve sivri, kuyruklu. Hızlı yürüdüğü belli olmalı.
- **Kabuklu:** Gri-mor sert kabuklu, yavaş, iri.
- **Uçan Daire:** Metal disk, cam kubbede küçük yeşil pilot, yanıp sönen kenar ışıkları, altında yeşil çekim ışını. Yolu takip eder.
- **Savaş Gemisi:** Zırh plakalı, kanatlı uzun gövde, yeşil kokpit, arkasında mavi motor alevi. Gittiği yöne döner, yolu takip eder.
- **Dev:** İri yapılı, geniş omuzlu koyu yeşil uzaylı, alnında yara izi. Ekrana girince "Dev geliyor!" uyarısı çıkar.
- **Ana Beyin:** Büyük, kırmızı-pembe, dokunaçlı, damarları parlayan bir beyin. Ekrana girince kısa bir uyarı yazısı çıksın: "Ana Beyin yaklaşıyor!"
- Hasar alan uzaylı bir an beyaz parlar. Canı azalmışsa üstünde can çubuğu görünür (%40'ın altında kırmızı).
- Ölen uzaylı yeşil sıvı damlacıklarına dağılır, yerinde "+5" gibi kristal yazısı yükselir.

---

## 6. Dalgalar

Her dalga, sırayla çıkan gruplardan oluşur: `[uzaylı türü, adet, aralık (sn)]`.

| Dalga | İçerik |
|---|---|
| 1 | 10 Sürüngen (0.9 sn) |
| 2 | 14 Sürüngen (0.75 sn) |
| 3 | 8 Sürüngen (0.8) + 8 Akrep (0.5) |
| 4 | 5 Kabuklu (1.2) + 10 Sürüngen (0.6) + 6 Uçan Daire (0.6) |
| 5 | 20 Akrep (0.4) + 1 Dev (2.0) |
| 6 | 10 Kabuklu (1.0) + 8 Uçan Daire (0.5) + 12 Sürüngen (0.5) |
| 7 | 14 Akrep (0.4) + 10 Kabuklu (0.9) + 3 Savaş Gemisi (1.5) |
| 8 | 18 Kabuklu (0.8) + 1 Dev (2.0) + 4 Savaş Gemisi (1.4) |
| 9 | 22 Akrep (0.35) + 10 Uçan Daire (0.4) + 12 Kabuklu (0.7) |
| 10 | 10 Kabuklu (0.9) + 2 Dev (2.5) + 1 Ana Beyin (2.0) + 16 Akrep (0.35) + 5 Savaş Gemisi (1.2) |

Hazırlık evresinde alt panelde sıradaki dalganın içeriği yazmalı: "Sıradaki dalga: 10 Sürüngen."

---

## 7. Görsel kimlik

- **Ortam (kullanıcı isteği, referans görsele göre):** Çizgi film tarzı mobil kule savunma görünümü. Zemin **yeşil çimen**, üstünde açık/koyu çim lekeleri ve tutamlar; geniş, yuvarlak köşeli, yumuşak kenarlı **kumlu yol**. Kenarlarda yuvarlak çalılar, gri kayalar, kalenin yanında tahta çitler. Kuleler tıknaz taş gövdeli, tepesi parlayan renkli taşlı, altında kendi renginde ışık halkası.
- **Portal (giriş):** Ekranın üstünde dönen mor-yeşil bir solucan deliği.
- **Nova Üssü kalesi (çıkış):** Ekranın altında surları, iki yan kulesi ve ortada mavi parlayan enerji kubbesi olan bilim kurgu kalesi. Kalkan azaldıkça ışığı zayıflasın. Kalenin oturduğu iki kareye (3,13 ve 5,13) kule kurulamaz.
- **Renk paleti önerisi:**
  - Arka plan / gece gökyüzü: `#0d0f1a`
  - Çim zemini: `#6fb33a` (açık `#8fcf4a`, koyu `#4f8f2c`)
  - Yol: `#efd9a6`, kenar `#c9a46e`
  - 3D renk paleti `src/render/palette.js` içindedir.
  - Arayüz paneli: `#161a2b`, kenar `#2c3352`
  - Kristal (para): `#5ee6d0`
  - Kalkan: `#4da3ff`
  - Uyarı / tehlike: `#ff4d5e`
  - Uzaylı yeşili: `#7cff6b`
- **Yazı tipleri:** Başlık için bilim kurgu hissi veren bir font (ör. Google Fonts'tan "Orbitron" ya da "Audiowide"), arayüz metinleri için okunaklı dar bir font (ör. "Barlow Semi Condensed" ya da "Rajdhani").
- **Efektler:** Ekran sarsıntısı (çekirdek hasar alınca), patlama halkaları, parçacıklar, Tesla şimşeği, Kriyo halkası. Abartmadan, telefonda akıcı çalışacak kadar.
- **Görünüm 3D'dir** (kullanıcı isteği): harita, yol, uzaylılar, uzay araçları, kale ve kuleler Three.js ile 3D çizilir. Kamera tahtaya güneyden yüksek açıyla eğik (yaklaşık 64°) bakar, tam üstten görünüm yok. Çizgi film görünümü için `MeshToonMaterial` (3 basamaklı ışık) ve `OutlineEffect` ile koyu kenar çizgisi kullanılır; parçacık, saydam efekt ve zemin malzemelerinde kenar çizgisi `noOutline` ile kapatılır. Modeller koddaki basit 3D şekillerden kurulur (dışarıdan model dosyası yok); her varlığın modeli kendi fonksiyonunda olsun ki ileride gerçek modellerle değiştirilebilsin.

---

## 8. Arayüz düzeni (dikey telefon ekranı)

```
┌─────────────────────────────┐
│ ALIEN WARS   Kristal Kalkan Dalga │  ← üst şerit
├─────────────────────────────┤
│                             │
│      9 × 14 oyun alanı      │  ← canvas, ortalanmış
│                             │
├─────────────────────────────┤
│  bağlamsal panel            │  ← kule menüsü / kule bilgisi / ipucu
│  [1×]  [ 3. Dalgayı Başlat ]│  ← hız düğmesi + ana düğme
└─────────────────────────────┘
```

- **Bağlamsal panel üç durumda:**
  1. Hiçbir şey seçili değilse: ipucu ve sıradaki dalganın içeriği
  2. Boş kare seçiliyse: 4 kule kartı (renk, ad, maliyet, kısa açıklama). Kristal yetmiyorsa kart soluk ve tıklanamaz.
  3. Kule seçiliyse: kule adı, seviye, hasar, menzil, özellik; "Yükselt · maliyet" ve "Sat +değer" düğmeleri. Seçili kulenin menzili haritada kesikli daire ile gösterilir.
- Panelin yüksekliği sabit olmalı ki seçim değişince oyun alanı zıplamasın.
- Yenilgi ve zafer ekranı oyun alanının üstünde yarı saydam kutu olarak çıkar, "Yeniden Oyna" düğmesi içerir.
  - Yenilgi: "Üs Düştü" — "X. dalgada Nova Üssü'nün kalkanı çöktü."
  - Zafer: "Mars Kurtarıldı!" — "10 dalgayı da püskürttün. Kalkanda X birim kaldı."
- Telefonun çentik ve alt çubuğu için `env(safe-area-inset-*)` boşlukları kullanılmalı.

---

## 9. Teknik yapı

### Teknoloji

- Saf **HTML + CSS + JavaScript** (ES modülleri), **Three.js** (WebGL) ile 3D çizim; can çubukları ve yazılar için üstte şeffaf bir 2D canvas katmanı
- Arayüz framework'ü yok. Paketleme ve yerel sunucu için **Vite** kullanılır; Three.js pakete gömülür (çevrimdışı çalışır).
- Daha sonra **Capacitor** ile Android/iOS uygulamasına çevrilecek, o yüzden sunucuya bağımlı hiçbir şey olmasın; oyun tamamen çevrimdışı çalışsın.

### Önerilen klasör yapısı

```
alien-wars-td/
├── CLAUDE.md               ← bu dosya
├── index.html
├── package.json
├── reference/
│   └── kale-savunmasi.html ← ilk prototip (sadece referans, değiştirilmez)
└── src/
    ├── main.js             ← başlatma, oyun döngüsü (requestAnimationFrame)
    ├── state.js            ← oyun durumu: kristal, kalkan, dalga, listeler
    ├── data/
    │   ├── towers.js       ← kule tanımları ve yükseltme formülleri
    │   ├── enemies.js      ← uzaylı tanımları
    │   ├── waves.js        ← dalga listesi
    │   └── maps.js         ← yol ve harita verisi
    ├── systems/
    │   ├── spawner.js      ← dalga başlatma, düşman çıkarma
    │   ├── movement.js     ← yol takibi, yavaşlama
    │   ├── combat.js       ← hedef seçimi, ateş, mermi, hasar, zırh
    │   └── effects.js      ← parçacık, halka, şimşek, yazı efektleri
    ├── render/
    │   ├── scene.js        ← Three.js sahnesi, kamera, ışık, mantık → 3D eşleme, dokunma ışını
    │   ├── world.js        ← 3D zemin (çimen), süsler, portal, kale
    │   ├── background.js   ← zemin ve yol dokusu (2D canvas'ta çizilip araziye kaplanır)
    │   ├── towers.js       ← 3D kule ve mermi modelleri
    │   ├── enemies.js      ← 3D uzaylı ve uzay aracı modelleri
    │   └── fx.js           ← 3D efektler + 2D katman (can çubuğu, yazılar, uyarı şeridi)
    ├── ui/
    │   ├── hud.js          ← üst şerit
    │   ├── panel.js        ← alt bağlamsal panel
    │   └── overlay.js      ← zafer / yenilgi ekranı
    ├── input.js            ← dokunma → ızgara karesi
    └── styles.css
```

### Kurallar

- **Veri ve mantık ayrı:** Tüm denge sayıları `src/data/` içinde. Mantık kodunda sabit sayı olmasın.
- **Sabit zaman adımı:** Güncelleme, en fazla 0.03 sn'lik adımlarla yapılsın (prototipteki gibi). Hız 2× ve 3× olunca adım sayısı artar, adım boyu artmaz.
- **Birimler:** Oyun mantığında tüm konumlar ve mesafeler **kare** biriminde ve 2D'dir. 3D dünyaya çeviri (`x - sütun/2`, yükseklik, `y - satır/2`) sadece çizim katmanında yapılır.
- **Ekran boyutu:** 3D canvas oyun alanını doldurur; WebGL çözünürlüğü `devicePixelRatio` en fazla 1.5, 2D katman en fazla 2 ile çizilir. Pencere boyutu değişince kamera tahtanın tamamı sığacak şekilde yeniden konumlanır.
- **Performans:** Arazi bir kez kurulur; geometri ve malzemeler paylaşılır, parçacıklar tek bir InstancedMesh ile çizilir, tek gölge ışığı (1024 gölge haritası). Ölü düşman, biten mermi ve efektlerin 3D nesneleri her karede sahneden kaldırılır. Hedef: orta seviye bir Android telefonda 60 FPS.
- **Kayıt:** En yüksek dalga ve ayarlar `localStorage`'da tutulur; her okuma ve yazma `try/catch` içinde olsun.
- **Kod dili:** Değişken ve fonksiyon adları İngilizce, oyuncuya görünen tüm metinler Türkçe. Metinler ileride çeviri eklenebilsin diye tek bir dosyada (`src/i18n/tr.js`) toplanırsa iyi olur.

---

## 10. Yol haritası

Her aşamanın sonunda oyun çalışır durumda olmalı. Bir aşama bitmeden diğerine geçme; her aşama bittiğinde bana kısaca ne yaptığını söyle.

**Aşama 1 — Taşıma ve tema (ilk görev)**
- Projeyi kur (Vite + yukarıdaki klasör yapısı)
- Prototipteki mantığı modüllere böl, davranışı birebir koru
- Tüm ortaçağ temasını uzaylı temasına çevir (adlar, renkler, çizimler, metinler)
- Başlık "Alien Wars Tower Defence" olsun

**Aşama 2 — His ve cila**
- Basit ses efektleri (Web Audio ile kodla üretilmiş: lazer, patlama, şimşek, uzaylı ölümü, dalga başlangıcı) ve ses aç/kapa düğmesi
- Başlangıç ekranı: oyun adı, "Oyna" düğmesi, en yüksek dalga
- Duraklat düğmesi
- Ana Beyin için özel giriş uyarısı

**Aşama 3 — İçerik**
- 2 yeni harita (farklı yollar, biri iki girişli olabilir) ve harita seçme ekranı
- Zorluk seçimi: Kolay / Normal / Zor (can çarpanı ve başlangıç kristali değişir)
- 2 yeni uzaylı: **Uçan Göz** (yolu takip etmez, düz uçar; sadece Lazer ve Tesla vurabilir) ve **Bölünen** (ölünce 2 küçük Sürüngen'e ayrılır)
- Kule hedef modları: İlk / En güçlü / En yakın

**Aşama 4 — Uygulama**
- Capacitor ile Android ve iOS projesi oluştur
- Uygulama ikonu ve açılış ekranı (uzaylı temalı)
- Ekranın dikey kilitlenmesi, ekran uyku modunun oyun sırasında engellenmesi

---

## 11. Kabul kriterleri (Aşama 1 için)

- [ ] Telefon genişliğinde (360–430 px) yatay kaydırma olmadan tam ekran oynanıyor
- [ ] 4 kule kurulabiliyor, 3. seviyeye kadar yükseltilebiliyor ve satılabiliyor
- [ ] Kristal yetmediğinde kule kartları ve yükseltme düğmesi pasif
- [ ] 10 dalga yukarıdaki tabloya göre geliyor, canlar her dalgada büyüyor
- [ ] Zırh, alan hasarı, yavaşlatma ve zırh delme doğru çalışıyor
- [ ] Çekirdeğe ulaşan uzaylı kalkanı azaltıyor, ekran sarsılıyor
- [ ] Zafer ve yenilgi ekranları çalışıyor, "Yeniden Oyna" her şeyi sıfırlıyor
- [ ] 1×, 2×, 3× hız çalışıyor
- [ ] Ekranda ortaçağ temasından hiçbir iz kalmadı
- [ ] Konsolda hata yok
