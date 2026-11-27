import SwiftUI

/// Card shown briefly under the menu bar icon when the headphones connect:
/// left earbud, case and right earbud inside battery rings, plus the active noise mode.
struct ConnectCardView: View {
    @ObservedObject var client: FlexClient
    /// false starts the rings full instead of animating them in (used for snapshots).
    var animated = true
    var onTap: () -> Void = {}

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(client.deviceName).font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("Connected").font(.system(size: 12)).foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                RingItem(level: client.left, name: String(localized: "Left"), progress: progress(client.left)) {
                    EarbudDrawing(level: nil, showsGauge: false).frame(width: 36, height: 55)
                }
                RingItem(level: client.caseLevel,
                         name: client.caseLevelIsStale ? String(localized: "Case · last known") : String(localized: "Case"),
                         progress: progress(client.caseLevel)) {
                    CaseDrawing(level: nil, showsGauge: false).frame(width: 64, height: 64).offset(y: -9)
                }
                .opacity(client.caseLevelIsStale ? 0.55 : 1)
                RingItem(level: client.right, name: String(localized: "Right"), progress: progress(client.right)) {
                    EarbudDrawing(level: nil, mirrored: true, showsGauge: false).frame(width: 36, height: 55)
                }
            }

            if let mode = client.pendingMode ?? client.mode {
                HStack(spacing: 8) {
                    Image(systemName: mode.symbol).foregroundStyle(Color.flexOrange)
                    Text(mode.title)
                    Spacer()
                    Text("Active mode").foregroundStyle(.secondary).font(.system(size: 11.5))
                }
                .font(.system(size: 13))
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.06)))
            }
        }
        .padding(14)
        .frame(width: 300)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onAppear {
            guard animated else { return }
            withAnimation(.easeOut(duration: 0.8).delay(0.15)) { appeared = true }
        }
        .accessibilityElement(children: .combine)
    }

    private func progress(_ level: BatteryLevel?) -> CGFloat {
        guard let level, appeared || !animated else { return 0 }
        return CGFloat(level.percent) / 100
    }
}

private struct RingItem<Art: View>: View {
    let level: BatteryLevel?
    let name: String
    let progress: CGFloat
    @ViewBuilder let art: () -> Art

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().fill(Color.primary.opacity(0.04))
                Circle().stroke(Color.primary.opacity(0.12), lineWidth: 4.5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(LinearGradient(colors: [Color(hex: 0xFF8550), Color(hex: 0xEC4A10)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                art()
            }
            .frame(width: 72, height: 72)
            HStack(spacing: 2) {
                Text(level.map { percentText($0.percent) } ?? "–")
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                if level?.charging == true {
                    Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(Color.flexOrange)
                }
            }
            Text(name).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
