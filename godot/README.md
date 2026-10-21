# Osmanlı Kale Savunması · Godot denemesi

Tarayıcı sürümünü (Vite + Three.js) Godot 4'e taşımadan önce görüntü farkını görmek için yapılmış küçük, oynanabilir bir deneme. Kurallar ve sayılar ana `CLAUDE.md` ile aynıdır.

## İçinde ne var

- 9 × 16 ızgara, CLAUDE.md'deki yol, düşman ordugâhı, surlar ve kapı, surların içinde şehir
- Okçu Kulesi (50 akçe, menzil 2.6, hasar 11, atış 0.55 sn): boş kareye dokununca kurulur, kuleye dokununca menzili görünür
- Piyade (can 42, hız 1.1, ödül 5): Bizans renklerinde, yürüme animasyonlu; 5 dalga, can her dalga × 1.2
- Işık: güneş gölgesi, gökyüzü, sis, parlama (glow), meşale ve ocak ateşleri; alttaki düğmeyle Öğle → İkindi → Gece
- Rüzgârda sallanan çimler, dalgalanan sancaklar, ışıklı iz bırakan oklar, vuruş kıvılcımı, dağılma tozu

## Çalıştırma

1. [Godot 4.5](https://godotengine.org/download) kurun (standart sürüm, .NET gerekmez).
2. Godot'da **Import** → bu klasördeki `project.godot`.
3. F5 ile çalıştırın.

Web çıktısı: `GODOT=/yol/godot tools/export_web.sh` → `build/web/`. Motor tek iş parçacıklı derlendiği için özel sunucu başlığı (COOP/COEP) gerekmez; herhangi bir statik barındırma yeter.

Ekran görüntüsü (geliştirme için): `godot --write-movie /tmp/kare.png --fixed-fps 10 --quit-after 80 -- --shot=x --wave --dusk`

## Dosyalar

- `scripts/main.gd`: sahnenin tamamı (dünya, ışık, kule, düşman, arayüz) kodla kurulur
- `shaders/ground.gdshader`: çim, toprak yol ve kaldırım; yol köşe noktalarından hesaplanır
- `shaders/grass.gdshader`, `shaders/flag.gdshader`: rüzgârda çim ve sancak
- `assets/models/`: tarayıcı sürümündeki KayKit (CC0) modelleri. Godot `KHR_mesh_quantization` desteklemediği için `gltf-transform dequantize` ile açılmış kopyalardır. Lisans ve kaynak için kökteki `CREDITS.md`'ye bakın.
- `export_presets.cfg`: Web dışa aktarım ayarı (Android ve iOS sonra eklenecek)
