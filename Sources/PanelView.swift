import ServiceManagement
import SwiftUI

extension NoiseMode {
    var summary: String {
        switch self {
        case .anc: return String(localized: "Blocks outside sound.")
        case .ambient: return String(localized: "Lets you keep hearing your surroundings.")
        case .talkThru: return String(localized: "Lowers music and brings voices forward.")
        case .off: return String(localized: "No processing.")
        }
    }
}

/// The menu bar panel: earbuds and case on top, noise-mode tiles below, a small footer.
struct PanelView: View {
    @ObservedObject var client: FlexClient

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if client.state == .connected {
                BatteryStage(client: client)
                ModeTiles(client: client)
                ModeDetail(client: client)
                SoundSettings(client: client)
            } else {
                DisconnectedView(state: client.state, applyingSmartAV: client.isApplyingSmartAV)
            }
            if let error = client.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Footer(client: client)
        }
        .padding(14)
        .frame(width: 320)
    }
}

private struct BatteryStage: View {
    @ObservedObject var client: FlexClient

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            item(EarbudDrawing(level: client.left?.percent).frame(width: 58), client.left, String(localized: "Left"))
            item(CaseDrawing(level: client.caseLevel?.percent).frame(width: 86), client.caseLevel, String(localized: "Case"),
                 stale: client.caseLevelIsStale)
            item(EarbudDrawing(level: client.right?.percent, mirrored: true).frame(width: 58), client.right, String(localized: "Right"))
        }
        .padding(.top, 4)
    }

    private func item(_ drawing: some View, _ level: BatteryLevel?, _ name: String, stale: Bool = false) -> some View {
        VStack(spacing: 2) {
            drawing.frame(height: 86)
            HStack(spacing: 2) {
                Text(level.map { percentText($0.percent) } ?? "–")
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
                if level?.charging == true {
                    Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(Color.flexOrange)
                }
            }
            Text(stale ? String(localized: "\(name) · last known") : name).font(.caption2).foregroundStyle(.secondary)
        }
        .opacity(stale ? 0.55 : 1)
        .help(stale ? String(localized: "The case battery updates while the earbuds are in the case.") : "")
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(name) battery: \(level.map { percentText($0.percent) } ?? String(localized: "unknown"))"))
    }
}

private struct ModeTiles: View {
    @ObservedObject var client: FlexClient

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(NoiseMode.allCases) { mode in
                ModeTile(mode: mode,
                         selected: (client.pendingMode ?? client.mode) == mode,
                         pending: client.pendingMode == mode) {
                    client.setMode(mode)
                }
            }
        }
    }
}

private struct ModeTile: View {
    let mode: NoiseMode
    let selected: Bool
    let pending: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: mode.symbol)
                    Spacer()
                    if pending { ProgressView().controlSize(.mini) }
                }
                Text(mode.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)  // long single words (e.g. German) shrink instead of breaking mid-word
                Text(mode.summary)
                    .font(.system(size: 11.5))
                    .foregroundStyle(selected ? Color.white.opacity(0.85) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .padding(11)
            .foregroundStyle(selected ? Color.white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Color.flexOrange : Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Color.flexOrange : Color.primary.opacity(0.08))
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct DisconnectedView: View {
    let state: FlexClient.State
    var applyingSmartAV = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "headphones")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text(message).font(.system(size: 13, weight: .medium))
            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if state == .unauthorized {
                Button("Open Bluetooth Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")!)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private var message: String {
        if applyingSmartAV && (state == .searching || state == .connecting) {
            return String(localized: "Applying Smart Audio & Video…")
        }
        switch state {
        case .bluetoothOff: return String(localized: "Bluetooth is off")
        case .unauthorized: return String(localized: "No Bluetooth permission")
        case .connecting: return String(localized: "Connecting…")
        default: return String(localized: "Looking for headphones…")
        }
    }

    private var hint: String {
        if applyingSmartAV && (state == .searching || state == .connecting) {
            return String(localized: "The earbuds reconnect for a few seconds to switch profiles.")
        }
        switch state {
        case .bluetoothOff: return String(localized: "Turn on Bluetooth in Control Center.")
        case .unauthorized: return String(localized: "Allow FlexBar under Privacy & Security › Bluetooth.")
        default: return String(localized: "Open the case lid or put the earbuds in.")
        }
    }
}

private struct Footer: View {
    @ObservedObject var client: FlexClient
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var language = AppLanguage.current
    @AppStorage(Preference.lowBatteryAlerts) private var lowBatteryAlerts = true

    var body: some View {
        HStack {
            Text(client.firmware.map { String(localized: "Firmware \($0)") } ?? client.deviceName)
            Spacer()
            Menu {
                Button("Refresh") { client.refresh() }
                    .disabled(client.state != .connected)
                Toggle("Open at Login", isOn: $launchAtLogin)
                Toggle("Low Battery Alerts", isOn: $lowBatteryAlerts)
                Picker("Language", selection: $language) {
                    ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                }
                Divider()
                Button("Quit FlexBar") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(String(localized: "Settings"))
        }
        .font(.system(size: 11.5))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 2)
        .onChange(of: launchAtLogin) { enabled in
            do {
                if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
        .onChange(of: language) { $0.apply() }
        .onChange(of: lowBatteryAlerts) { if $0 { LowBatteryAlerts.requestPermission() } }
    }
}

// MARK: - Settings below the mode tiles

/// Adaptive ANC switch in Noise Cancelling, strength slider in Ambient Aware; nothing in the other modes.
private struct ModeDetail: View {
    @ObservedObject var client: FlexClient
    @State private var draftLevel: Double?

    var body: some View {
        switch client.mode {
        case .anc?:
            if let adaptive = client.adaptiveANC {
                SettingRow {
                    Toggle(isOn: Binding(get: { adaptive }, set: { client.setAdaptiveANC($0) })) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Adaptive Noise Cancelling")
                            Text("Adjusts to the noise around you.").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            }
        case .ambient?:
            if let level = client.ambientLevel {
                SettingRow {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Ambient Aware level")
                            Spacer()
                            Text("\(Int(draftLevel ?? Double(level)) + 1)/\(ambientLevelRange.count)")
                                .monospacedDigit().foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(get: { draftLevel ?? Double(level) }, set: { draftLevel = $0 }),
                               in: Double(ambientLevelRange.lowerBound)...Double(ambientLevelRange.upperBound),
                               step: 1) { editing in
                            // Send once on release, not on every step while dragging.
                            if !editing, let draft = draftLevel {
                                client.setAmbientLevel(Int(draft))
                                draftLevel = nil
                            }
                        }
                        .tint(Color.flexOrange)
                        .controlSize(.small)
                    }
                }
            }
        default:
            EmptyView()
        }
    }
}

/// EQ, Smart Audio & Video and Find My Buds.
private struct SoundSettings: View {
    @ObservedObject var client: FlexClient

    var body: some View {
        VStack(spacing: 6) {
            if let category = client.eqCategory {
                SettingRow {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EQ")
                        Segmented(options: EQPreset.allCases, selection: EQPreset(rawValue: category), title: \.title) {
                            client.setEQ($0)
                        }
                        if EQPreset(rawValue: category) == nil {
                            Text("A custom EQ from the JBL app is active.").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if let smartAV = client.smartAV {
                SettingRow {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Smart Audio & Video")
                        Segmented(options: SmartAVMode.allCases, selection: smartAV, title: \.title) {
                            client.setSmartAV($0)
                        }
                        Text("\(smartAV.summary) \(String(localized: "Changing it reconnects the earbuds for a few seconds."))")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            SettingRow {
                HStack {
                    Label("Find My Buds", systemImage: "speaker.wave.2")
                        .help(String(localized: "Take the earbuds out first: the beep is loud."))
                    Spacer()
                    BeepButton(title: String(localized: "Left"), on: client.beeping.left) {
                        client.beep(left: !client.beeping.left, right: nil)
                    }
                    BeepButton(title: String(localized: "Right"), on: client.beeping.right) {
                        client.beep(left: nil, right: !client.beeping.right)
                    }
                }
            }
        }
        .font(.system(size: 12.5))
    }
}

private struct BeepButton: View {
    let title: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(on ? String(localized: "Stop") : title)
                .frame(minWidth: 44)
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .foregroundStyle(on ? Color.white : .primary)
                .background(Capsule().fill(on ? Color.flexOrange : Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(on ? String(localized: "Stop beeping \(title)") : String(localized: "Beep \(title)"))
    }
}

/// Segmented control drawn like the mode tiles: the selected option is filled orange.
/// (The system segmented control doesn't match the panel and doesn't render in snapshots.)
private struct Segmented<Option: Hashable>: View {
    let options: [Option]
    let selection: Option?
    let title: KeyPath<Option, String>
    let onSelect: (Option) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button { if !selected { onSelect(option) } } label: {
                    Text(option[keyPath: title])
                        .font(.system(size: 12, weight: selected ? .semibold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .foregroundStyle(selected ? Color.white : .primary)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(selected ? Color.flexOrange : Color.clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.primary.opacity(0.07)))
    }
}

/// A quiet grouped row, styled like the mode tiles' background.
private struct SettingRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.06)))
    }
}
