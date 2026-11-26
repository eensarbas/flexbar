# FlexBar

English · [Türkçe](README.tr.md)

A small macOS menu bar app for the **JBL Tune Flex 2** earbuds. See the battery of each earbud and the case, and switch the noise mode, without picking up your phone.

<p>
  <img src="docs/images/panel.png" width="320" alt="FlexBar panel: both earbuds and the case with battery levels, and four noise mode tiles">
  <img src="docs/images/connect-card.png" width="300" alt="Connect card: battery rings for the left earbud, case and right earbud, and the active noise mode">
</p>

JBL's own app only runs on phones. FlexBar talks to the earbuds directly over Bluetooth Low Energy, using the same commands the JBL Headphones app sends.

## Features

- **Battery** for the left earbud, right earbud and case, refreshed every minute.
- **Noise mode:** Noise Cancelling, Ambient Aware, TalkThru or Off. A mode is only shown as active once the earbuds confirm it. If they don't confirm within 3 seconds, the panel says so.
- **Connect card:** each time the earbuds connect, a card drops down from the menu bar icon for 4 seconds with battery rings and the active mode.
- **Live updates:** changing the mode with the touch controls on the earbuds updates the menu bar icon and the panel right away.
- **Reconnects by itself** when the earbuds come back in range or leave the case.
- **Open at Login**, from the gear menu.
- **Languages:** English, Türkçe, हिन्दी, Deutsch, Français, Português. Follows the system language; you can pick another one from the gear menu.
- **URL actions** for Shortcuts, Raycast or Terminal:

  ```bash
  open flexbar://anc
  ```

  Also: `flexbar://ambient`, `flexbar://talkthru`, `flexbar://off`, `flexbar://cycle` (next mode), `flexbar://refresh`, `flexbar://panel` (opens the panel), `flexbar://card` (shows the connect card).

## Requirements

- macOS 13 Ventura or later, on Apple silicon.
- Xcode Command Line Tools, to build it: `xcode-select --install`.
- JBL Tune Flex 2 earbuds, paired with the Mac.

## Install

There's no prebuilt download yet; build it from source:

```bash
git clone https://github.com/eensarbas/flexbar.git
```

```bash
cd flexbar && ./build.sh --install
```

This builds the app, copies it to `/Applications` and starts it. On first launch macOS asks for Bluetooth access: click **Allow**. To start FlexBar with your Mac, open the panel and turn on **Open at Login** in the gear menu.

The app is ad-hoc signed, so macOS may ask for Bluetooth access again after you rebuild it.

## How it works

The Tune Flex 2 uses a Bestechnic (BES) chip. The JBL app controls it through a GATT service (`65786365-6c70-6f69-6e74-2e636f6d0000`): commands are written to characteristic `…0002` and replies arrive as notifications on `…0001`. There's no encryption.

- Noise mode: `AA 91 …` frames.
- Battery and firmware: `AA 06 …` feature-list frames (`0x1A` left, `0x1B` right, `0x1C` case, `0x05` firmware).

[docs/PROTOCOL.md](docs/PROTOCOL.md) has the frame format, every command FlexBar sends with real replies, and where in the JBL app the rest of the commands live.

To debug, start the app with logging:

```bash
open -n build/FlexBar.app --stdout /tmp/flexbar.log --args --log
```

Add `--snapshot /tmp/panel.png` to save the panel and the connect card as PNGs (dark and light) once battery data arrives.

## Known limits

- Only tested with the JBL Tune Flex 2. Other JBL earbuds built on the same platform (the JBL app lists Vibe Flex 2, Wave Flex 2, Tune Buds 2 and Tune Beam 2 in the same family) may work with small changes, but haven't been tried.
- The first byte of each battery value is assumed to be a charging flag (shown as ⚡︎). This hasn't been confirmed yet.
- While FlexBar is connected, the JBL app on your phone may not be able to connect to the earbuds.
- EQ, touch-control settings and the other options in the JBL app aren't supported yet. Their commands are in the JBL app's code; see [docs/PROTOCOL.md](docs/PROTOCOL.md).

## Contributing

Issues and pull requests are welcome, especially:

- **Translations.** All UI text lives in [Resources/translations.py](Resources/translations.py). Edit it and run `python3 Resources/translations.py` to regenerate the `.strings` files. The non-Turkish translations haven't been reviewed by native speakers yet.
- **Other models.** If you have another JBL earbud and can test, please open an issue.
- **More controls** (EQ, touch controls) from the protocol notes.

## Disclaimer

FlexBar is an independent project. It is not affiliated with, endorsed by or supported by JBL or Harman International. JBL and Tune Flex are trademarks of Harman International Industries. The protocol was worked out for interoperability; this repository contains no code or assets from JBL or Harman. The earbud and case drawings are original.

Use it at your own risk.

## Credits

Made by Ensar Bas, built together with [Claude](https://claude.com/claude-code).

## License

[MIT](LICENSE)
