# Kovan Nöbeti (v1.1 — Sonsuz Nöbet Fork'u)

Godot 4.7 ile yapılmış üçüncü şahıs hayatta kalma oyunu [yusufipk/kovan-nobeti](https://github.com/yusufipk/kovan-nobeti) projesinin **sonsuz döngü**, **dengeleme** ve **hikaye** güncellemelerini içeren fork sürümüdür.

## v1.1 Yenilikleri

* **Sonsuz Döngü Modu:** Kraliçe devrildiğinde oyun bitmez; bal ödülü, sandık ve şifa ile doğrudan bir sonraki döngüye (`Döngü 2, 3...`) geçer. Her döngüde gün-gece ışığı, müzik ve haritadaki sunak/kavanozlar yenilenir.
* **Sabit Döngü ve Dakika Ölçeklemesi:** Yapay adaptif DPS/XP ölçeklemesi kaldırıldı; gelen slotların hasarı ve saldırı sıklığı her dakika sabit ve öngörülebilir bir eğriyle artar.
* **Boss Dengelemesi:** Makas, Akrep ve Kraliçe bosslarına hasar direnci, tek vuruş koruması ve artırılmış DPS eklendi; toplam can havuzları dengeli dövüş süresine göre ayarlandı.
* **Rastgele 4 Sunak Özelliği:** Uyanan sunaklar artık rastgele olarak Güç (`+%15 hasar`), Hız (`+%10 saldırı hızı`), Can (`+30 maks. can ve tam şifa`) veya Rüzgar (`+%10 hız, +%15 etki alanı`) lütfu verir.
* **Hikaye Ekranı ve Arayüz:** İlk açılışta otomatik açılan ve ana menüdeki **Hikaye** sekmesinden tekrar okunabilen *Kovanın Hikayesi* eklendi; sürüm bilgisi (`v1.1`) Ayarlar ve Duraklatıldı ekranlarına işlendi; tüm **Arılık** metinleri **Arıcılık** olarak güncellendi.
* **Kod ve Performans Temizliği:** Spatial hash tabanlı `nearest()`, önbellekli boss/şampiyon indeksleri, sandık/kavanoz bellek temizliği, değişken gölgeleme ve HUD taşma düzeltmeleri yapıldı.

## İndir

[Releases](https://github.com/beratcan42/kovan-nobeti/releases/tag/v1.1) sayfasından Windows için `KovanNobeti_v1.1.exe` , Linux için `KovanNobeti_v1.1.x86_64` dosyasını indir. Linux'ta önce `chmod +x KovanNobeti_v1.1.x86_64` .

Kaynaktan çalıştırmak için klasörü **Godot 4.7** ile aç ve `F5`'e bas.

*(İlk açılış hikaye ekranını tekrar görmek için `user://kovan_nobeti.json` dosyasındaki `"hikaye_goruldu"` alanını `false` yapabilirsin.)*

## Lisans ve Kaynak

Orijinal proje: [yusufipk/kovan-nobeti](https://github.com/yusufipk/kovan-nobeti)

MIT Lisansı (`LICENSE`). Baloo 2 yazı tipi SIL OFL lisanslıdır (`assets/font/OFL.txt`).
