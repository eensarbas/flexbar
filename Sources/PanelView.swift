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
            } else {
                DisconnectedView(state: client.state)
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
            item(CaseDrawing(level: client.caseLevel?.percent).frame(width: 86), client.caseLevel, String(localized: "Case"))
            item(EarbudDrawing(level: client.right?.percent, mirrored: true).frame(width: 58), client.right, String(localized: "Right"))
        }
        .padding(.top, 4)
    }

    private func item(_ drawing: some View, _ level: BatteryLevel?, _ name: String) -> some View {
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
            Text(name).font(.caption2).foregroundStyle(.secondary)
        }
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
        switch state {
        case .bluetoothOff: return String(localized: "Bluetooth is off")
        case .unauthorized: return String(localized: "No Bluetooth permission")
        case .connecting: return String(localized: "Connecting…")
        default: return String(localized: "Looking for headphones…")
        }
    }

    private var hint: String {
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

    var body: some View {
        HStack {
            Text(client.firmware.map { String(localized: "Firmware \($0)") } ?? client.deviceName)
            Spacer()
            Menu {
                Button("Refresh") { client.refresh() }
                    .disabled(client.state != .connected)
                Toggle("Open at Login", isOn: $launchAtLogin)
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
    }
}
