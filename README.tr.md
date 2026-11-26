# FlexBar

[English](README.md) · Türkçe

JBL Tune Flex 2 için macOS menü çubuğu uygulaması. JBL'nin telefon uygulamasını açmadan pili görmeni ve gürültü modunu değiştirmeni sağlar.

## Özellikler

- Sol, sağ ve kutu pili.
- Mod ayrıntıları: uyarlanabilir gürültü engellemeyi açıp kapatma, Ambient Aware seviyesi (7 kademe).
- Ses efekti: Doğal, Tiz veya Bas.
- Smart Audio & Video: Normal, Müzik (daha yüksek kalite) veya Video (görüntü ve görüşmeler için daha az gecikme).
- Kulaklığı bul: sol ya da sağ kulaklığı öttürme.
- Düşük pil bildirimi: bir kulaklık %20'ye ve sonra %10'a inince bildirim. Dişli menüsünden kapatılabilir.
- Bağlantı kartı: kulaklık her bağlandığında menü çubuğu ikonunun altında 4 saniyeliğine açılır. Sol, kutu ve sağ pil halkalarında görünür, altta etkin gürültü modu yazar. Karta tıklamak paneli açar. `flexbar://card` kartı elle gösterir.
- Gürültü modu: Gürültü Engelleme, Ambient Aware, TalkThru, Kapalı. Seçilen mod, kulaklık onaylayınca işaretlenir. Onay 3 saniye içinde gelmezse menüde uyarı görünür.
- Menü çubuğu ikonu etkin modu gösterir. Kulaklık bağlı değilken soluk kulaklık ikonu görünür.
- Kendiliğinden bağlanma: kulaklık kapanıp açılınca ya da menzilden çıkıp dönünce yeniden bağlanır.
- Pil ve mod her 60 saniyede bir yenilenir. Kulaklıktaki dokunmatik kontrolle mod değişirse menü anında güncellenir.
- Girişte açılma seçeneği.
- Diller: English, Türkçe, हिन्दी, Deutsch, Français, Português. Sistem dilini izler; dişli menüsünden başka bir dil seçilebilir.
- URL ile kontrol (Shortcuts, Raycast, Terminal):

```bash
open flexbar://anc
```

  Diğer adresler: `flexbar://ambient`, `flexbar://talkthru`, `flexbar://off`, `flexbar://cycle` (sıradaki mod), `flexbar://refresh`, `flexbar://panel` (paneli açar), `flexbar://card` (bağlantı kartını gösterir).

## Kurulum

macOS 13 veya üstü gerekir. Uygulama hem Apple silicon hem Intel için derleniyor; Apple silicon'da test edildi.

1. [Son sürümden](https://github.com/eensarbas/flexbar/releases/latest) **FlexBar.zip** dosyasını indir.
2. Zip'i aç, **FlexBar**'ı **Uygulamalar** klasörüne sürükle.
3. FlexBar'ı aç. Uygulama henüz Apple tarafından imzalanmadığı için macOS ilk açılışı engeller:
   - **macOS 15 Sequoia ve sonrası:** macOS, FlexBar'ın açılmadığını söyler. **Bitti**'ye tıkla, sonra **Sistem Ayarları › Gizlilik ve Güvenlik**'i aç, aşağıdaki **Güvenlik** bölümünde FlexBar'ın yanındaki **Yine de Aç**'a tıkla. Parolanı gir ve tekrar **Yine de Aç**'a tıkla.
   - **macOS 13 ve 14:** Uygulamalar klasöründe FlexBar'a sağ tıkla, **Aç**'ı seç, sonra yine **Aç**'a tıkla.

   Bunu yalnızca bir kez yapman gerekir.
4. macOS Bluetooth izni isteyince **İzin Ver**'e tıkla.
5. Mac açılınca kendiliğinden başlaması için menü çubuğundaki ikona tıkla, dişli menüsünden **Girişte aç**'ı işaretle.

Terminal'i tercih edersen 3. adım yerine bu komut indirme işaretini kaldırır:

```bash
xattr -dr com.apple.quarantine /Applications/FlexBar.app
```

### Kaynak koddan derleme

Xcode Command Line Tools gerekir (`xcode-select --install`).

```bash
git clone https://github.com/eensarbas/flexbar.git
```

```bash
cd flexbar && ./build.sh --install
```

Bu komut uygulamayı derler, `/Applications` klasörüne kopyalar ve başlatır. `./build.sh --release`, sürümlerde kullanılan evrensel `build/FlexBar.zip` dosyasını üretir. Uygulama ad-hoc imzalı olduğu için her yeniden derlemede Bluetooth izni tekrar sorulabilir.

## Nasıl çalışır

Kulaklıkla BLE üzerinden JBL uygulamasının kullandığı GATT servisiyle konuşur. Ayrıntılar için [docs/PROTOCOL.md](docs/PROTOCOL.md) dosyasına bak (İngilizce).

- Servis `65786365-6c70-6f69-6e74-2e636f6d0000`: yazma `…0002`, bildirimler `…0001`.
- Gürültü modu: `AA 91 …`. Pil ve firmware: `AA 06 …` özellik listesi (`0x1A` sol, `0x1B` sağ, `0x1C` kutu, `0x05` firmware).

Hata ayıklamak için uygulamayı log moduyla başlat:

```bash
open -n build/FlexBar.app --stdout /tmp/flexbar.log --args --log
```

Paneli PNG olarak kaydetmek için `--snapshot /tmp/panel.png` ekle. Kulaklıktan pil verisi gelince koyu ve açık temada panel ve bağlantı kartı için dosyalar yazılır: `panel-dark.png`, `panel-light.png`, `panel-card-dark.png`, `panel-card-light.png`.

## Bilinen sınırlar

- Yalnızca JBL Tune Flex 2 ile denendi. Uygulama, adı `JBL Tune Flex 2` ile başlayan BLE cihazına bağlanır.
- FlexBar bağlıyken telefondaki JBL uygulaması kulaklığa bağlanamayabilir.
- Kendi EQ eğrin, dokunmatik kontroller ve diğer ayarlar henüz yok. Komutlar JBL uygulamasının kodunda duruyor, çıkarılması gerekiyor.

## Sorumluluk reddi

FlexBar bağımsız bir projedir; JBL veya Harman International ile bir bağlantısı yoktur, onlar tarafından onaylanmamış ya da desteklenmemiştir. JBL ve Tune Flex, Harman International Industries'in ticari markalarıdır. Bu depoda JBL veya Harman'a ait kod ya da görsel yoktur; kulaklık ve kutu çizimleri özgündür.

## Katkıda bulunanlar

Ensar Bas tarafından, [Claude](https://claude.com/claude-code) ile birlikte geliştirildi.

## Lisans

[MIT](LICENSE)
