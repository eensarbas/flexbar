import Combine
import Foundation
import UserNotifications

/// User preferences for Mac-only features, stored in UserDefaults.
enum Preference {
    static let lowBatteryAlerts = "lowBatteryAlerts"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [lowBatteryAlerts: true])
    }
}

/// Posts a notification when an earbud drops to 20% and again at 10%.
/// Each threshold fires once per discharge; it re-arms after charging or going back above 25%.
@MainActor
final class LowBatteryAlerts {
    static let thresholds = [20, 10]
    private static let rearmAbove = 25

    private let client: FlexClient
    private var subscriptions: Set<AnyCancellable> = []
    /// Lowest threshold already notified, per side.
    private var notified: [String: Int] = [:]

    init(client: FlexClient) {
        self.client = client
        if UserDefaults.standard.bool(forKey: Preference.lowBatteryAlerts) { Self.requestPermission() }

        client.$left.receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.check(side: "left", level: $0) }
            .store(in: &subscriptions)
        client.$right.receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.check(side: "right", level: $0) }
            .store(in: &subscriptions)
    }

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func check(side: String, level: BatteryLevel?) {
        guard let level else { return }
        if level.charging || level.percent > Self.rearmAbove {
            notified[side] = nil
            return
        }
        guard UserDefaults.standard.bool(forKey: Preference.lowBatteryAlerts),
              let threshold = Self.thresholds.last(where: { level.percent <= $0 }),
              threshold < (notified[side] ?? Int.max) else { return }
        notified[side] = threshold
        post(side: side, percent: level.percent)
    }

    private func post(side: String, percent: Int) {
        let content = UNMutableNotificationContent()
        content.title = client.deviceName
        let value = percentText(percent)
        content.body = side == "left"
            ? String(localized: "Left earbud battery is at \(value).")
            : String(localized: "Right earbud battery is at \(value).")
        content.sound = .default
        let request = UNNotificationRequest(identifier: "low-battery-\(side)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
