# FlexBar

[English](README.md) · Türkçe

JBL Tune Flex 2 için macOS menü çubuğu uygulaması. JBL'nin telefon uygulamasını açmadan pili görmeni ve gürültü modunu değiştirmeni sağlar.

## Özellikler

- Sol, sağ ve kutu pili.
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

Apple silicon işlemcili bir Mac, macOS 13 veya üstü ve Xcode Command Line Tools gerekir.

```bash
git clone https://github.com/eensarbas/flexbar.git
```

```bash
cd flexbar && ./build.sh --install
```

Bu komut uygulamayı derler, `/Applications` klasörüne kopyalar ve başlatır. Yalnızca `./build.sh` çalıştırırsan uygulama `build/FlexBar.app` olarak derlenir.

İlk açılışta macOS Bluetooth izni ister, **İzin Ver**'e tıkla. Mac açılınca kendiliğinden başlaması için paneldeki dişli menüsünden **Girişte aç**'ı işaretle. Uygulama ad-hoc imzalı olduğu için her yeniden derlemede bu izin tekrar sorulabilir.

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
- Pil değerinin ilk baytını şarj durumu sayıyorum (⚡︎ işareti). Bu henüz doğrulanmadı.
- FlexBar bağlıyken telefondaki JBL uygulaması kulaklığa bağlanamayabilir.
- EQ, dokunmatik kontroller ve diğer ayarlar henüz yok. Komutlar JBL uygulamasının kodunda duruyor, çıkarılması gerekiyor.

## Sorumluluk reddi

FlexBar bağımsız bir projedir; JBL veya Harman International ile bir bağlantısı yoktur, onlar tarafından onaylanmamış ya da desteklenmemiştir. JBL ve Tune Flex, Harman International Industries'in ticari markalarıdır. Bu depoda JBL veya Harman'a ait kod ya da görsel yoktur; kulaklık ve kutu çizimleri özgündür.

## Katkıda bulunanlar

Ensar Bas tarafından, [Claude](https://claude.com/claude-code) ile birlikte geliştirildi.

## Lisans

[MIT](LICENSE)
