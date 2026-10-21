# Osmanlı Kale Savunması

Osmanlı kalesini ve surların içindeki şehri, sırayla sefere çıkan dünya devletlerinin ordularına karşı savunduğun; şehri seviye seviye geliştirdiğin, telefon için tasarlanmış bir kule savunma oyunu. Tasarım ve yol haritası için `CLAUDE.md` dosyasına bak.

## Çalıştırma

```bash
npm install
npm run dev      # yerel sunucu (telefondan aynı ağdaki IP ile açılabilir)
npm run build    # dist/ klasörüne çevrimdışı çalışan derleme
```

Klavye kısayolları: `1–4` kule kur, `U` kule ya da bina yükselt, `S` sat, `Boşluk` dalgayı başlat, `F` hız, `H` "Allah Allah!" hücumu, `M` ses, `Esc` seçimi kaldır.

Tüm müzik ve sesler (mehter tarzı marş, tekbir, efektler) Web Audio ile kodda üretilir; kayıt dosyası yoktur.

## 3D modeller

Yapı, doğa ve asker modelleri Kay Lousberg'in CC0 lisanslı KayKit paketlerinden gelir (kaynaklar ve lisanslar `CREDITS.md`'de). Sıkıştırılmış hâlleri `public/models/` içinde hazırdır. Model listesini değiştirince paketleri indirip yeniden üret:

```bash
git clone https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0
git clone https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0
npm run models -- KayKit-Medieval-Hexagon-Pack-1.0 KayKit-Character-Pack-Adventures-1.0
```

Alt çubuktaki `HD`/`SD` düğmesi görüntü kalitesini değiştirir (parlama, yumuşak gölge, çözünürlük). Seçim yapılmadıysa oyun yavaş cihazda kendiliğinden `SD`'ye geçer.
