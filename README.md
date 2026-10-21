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
