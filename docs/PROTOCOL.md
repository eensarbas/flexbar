# JBL Tune Flex 2 control protocol

Notes on how the JBL Headphones app talks to the Tune Flex 2, and what FlexBar uses.

Sources: the decompiled JBL Headphones Android app, version 5.38.2 (package `jbl.stc.com`), and live tests from a Mac over CoreBluetooth in November 2026. Class names below refer to that app version.

## Hardware and transport

- Chip: Bestechnic (BES). The app's product list (`assets/product_list.json`) has `"platform": "Bes"` and `"connectType": "BLE"` for this model.
- Control class in the app: `com.harman.cmdctrl.imp.control.u3.protocol3.TuneFlex2Control` (Harman "protocol3").
- BLE advertising name: `JBL Tune Flex 2-LE`. The BLE address rotates, so scan by name rather than reconnecting to a saved peripheral identifier.
- No encryption: command bytes are written as they are.

### GATT

| UUID | Role | Properties |
|---|---|---|
| `65786365-6c70-6f69-6e74-2e636f6d0000` | Command service (the UUID's bytes spell "excelpoint.com" in ASCII) | |
| `…6f6d0002` | Write to the earbuds (TX) | write, write without response |
| `…6f6d0001` | Notifications from the earbuds (RX) | notify |
| `86868686-…`, `97979797-…` | BES OTA (firmware update). **Don't write to these.** | |

Order: connect → discover services → enable notifications on `…0001` → write to `…0002`.

Optional handshake: for devices with `bleSecurityMode` 3, the app writes a "HostNameCRC" to characteristic `…0003` and waits up to 1 second for a reply, then carries on without it. FlexBar works without the handshake.

### Classic Bluetooth (SDP), for reference

| RFCOMM channel | What it is |
|---|---|
| 17 | Google Fast Pair Message Stream. On connect it pushes model ID, battery and firmware version by itself. |
| 12 | "TOTA" (SPP, UUID 0x1101). The app doesn't use it for this model; `AA` commands get no reply here. |
| 29 | Custom UUID `99999999-…`. Opens, but stays silent. |

## Frame format

There are two kinds of frames.

**Short command** (`CmdBase.combine`):

```
AA <command> <length> <payload…>
```

**Feature list** (`Command3`, command `0x06`):

```
AA 06 <length LE16> <type> <feature ID BE16>…
```

`type` is `01` for a read request and `02` for a reply. In a reply, each feature is `<ID BE16> <length, 1 byte> <value>`. The full status frame the earbuds push on connect parses cleanly with this rule.

Battery values are 2 bytes, `<charging> <percent>`, for example `00 64`. The JBL app stores the first byte as the charging flag (`DeviceUnitBatteryInfo.setCharging`).

## Read commands (tested)

| What | Sent | Example reply | Meaning |
|---|---|---|---|
| Noise mode | `AA 91 01 11` | `AA 91 07 12 01 00 02 01 03 00` | mode/value pairs: ANC = 0, Ambient = 1, TalkThru = 0, so **Ambient Aware is on** |
| Battery (left, right, case) | `AA 06 07 00 01 00 1A 00 1B 00 1C` | `AA 06 10 00 02 00 1A 02 00 64 00 1B 02 00 64 00 1C 02 00 47` | feature `0x1A` left = `00 64` (100%), `0x1B` right = 100%, `0x1C` case = `00 47` (71%) |
| Firmware | `AA 06 03 00 01 00 05` | `AA 06 07 00 02 00 05 03 03 05 00` | feature `0x05`, 3 bytes `03 05 00` = 3.5.0 |

Frames the earbuds push by themselves after connecting: `AA 12` (device name, address and battery), `AA 06 …` (full status), `AA 91 …` (noise mode), `AA 9C`, `AA 80`, `AA 94` (serial number).

Mode numbers (`com.harman.sdk.message.AncMode`): `1` = ANC, `2` = Ambient Aware, `3` = TalkThru.

## Write commands (tested)

From `HmProtocol3DeviceStatusControl.setAncSetting` → `CmdGen.genSetANCModes` / `genSetANCModeOFF`. After each command the earbuds report the new state by themselves (`AA 91 07 12 …`).

| Mode | Sent | Earbuds' reply |
|---|---|---|
| Noise Cancelling | `AA 91 07 10 01 01 02 00 03 00` | `AA 91 07 12 01 01 02 00 03 00` ✓ |
| TalkThru | `AA 91 07 10 01 00 02 00 03 01` | `AA 91 07 12 01 00 02 00 03 01` ✓ |
| Off | `AA 91 01 13` | `AA 91 07 12 01 00 02 00 03 00` ✓ |
| Ambient Aware | `AA 91 07 10 01 00 02 01 03 00` | `AA 91 07 12 01 00 02 01 03 00` ✓ |

Every mode report is followed by the advanced ANC report `AA 91 09 22 …`, described below.

## More settings (tested)

All of these were read, changed and restored on real earbuds. After each write the earbuds report the new value by themselves.

### Advanced ANC: adaptive ANC and Ambient Aware level

`AdvancedAncCmd`. Read with `AA 91 01 21`; the reply is key/value pairs after `22`:

```
AA 91 09 22  01 01  04 07  05 01  A1 06
             │      │      │      └ A1 Ambient Aware level (0–6)
             │      │      └ 05 leakage compensation
             │      └ 04 manual adaptive ANC level
             └ 01 adaptive ANC on (1) / off (0)
```

| Change | Sent |
|---|---|
| Adaptive ANC off / on | `AA 91 03 20 01 00` / `AA 91 03 20 01 01` |
| Ambient Aware level 3 | `AA 91 03 20 A1 03` |

The JBL app shows 7 Ambient Aware steps. The earbuds accepted 3 and 6; they ignored 7, so the range is 0–6.

### Sound effect

Feature `0x14` in the feature-list frames (`SoundEffectInfo`): value `<status> <type>`, type `00` Natural, `01` Treble Boost, `02` Bass Boost.

| Change | Sent |
|---|---|
| Read | `AA 06 03 00 01 00 14` → `AA 06 06 00 02 00 14 02 00 00` |
| Treble Boost | `AA 06 06 00 00 00 14 02 01 01` (status `01`, as the JBL app sends) |

### Smart Audio & Video

`SmartSwitchCmd`, command `0x80`. Values are little-endian 16-bit: AAC bitrate (kbps), SBC bitpool, latency (ms), and a second latency the earbuds report as `FFFF`.

| | AAC | SBC | Latency | Sent |
|---|---|---|---|---|
| Read | | | | `AA 80 01 01` → `AA 80 09 02 00 01 2E 00 18 01 FF FF` |
| Normal | 197 | 46 | 280 | `AA 80 09 00 C5 00 2E 00 18 01 FF FF` |
| Audio | 256 | 46 | 280 | `AA 80 09 00 00 01 2E 00 18 01 FF FF` |
| Video | 197 | 46 | 120 | `AA 80 09 00 C5 00 2E 00 78 00 FF FF` |

The three profiles come from the JBL app's product list for the Tune Flex 2.

### Find My Buds

`BeepingCmd`, command `0x23`. Read with `AA 23 01 01` → `AA 23 03 02 <left> <right>` (1 = beeping). To change: `AA 23 03 00 <left> <right>` with `01` beep, `00` stop, `FF` leave as is. The read was tested; the beep itself hasn't been triggered from the Mac yet.

## Not implemented yet: where to look in the app

- Custom EQ: `TuneFlex2Control.setEQSettings2` → `EQControl` (`QMultiply10EQ`). Gain range ±6 dB.
- Touch controls: `customizedGesture` in `product_list.json`, `CommandHeader.HEADER_FOR_SET_GESTURE_CONTROL` (`AA 71`).
- Other settings, all in `TuneFlex2Control`: `getAudioLimiterStatus`, `getAutoStandbyModeList`, `getLRBalanceStatus`, `getFindMyBuds`, `getInEarStatus`.
