import AppKit
import Foundation

/// Languages FlexBar ships translations for. Translations live in Resources/<code>.lproj.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = ""
    case english = "en"
    case turkish = "tr"
    case hindi = "hi"
    case german = "de"
    case french = "fr"
    case portuguese = "pt"

    var id: String { rawValue }

    /// Each language is listed in its own name, so people can find theirs.
    var displayName: String {
        switch self {
        case .system: return String(localized: "System Language")
        case .english: return "English"
        case .turkish: return "Türkçe"
        case .hindi: return "हिन्दी"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .portuguese: return "Português"
        }
    }

    /// The choice stored for this app only (AppleLanguages in FlexBar's own defaults domain).
    static var current: AppLanguage {
        guard let id = Bundle.main.bundleIdentifier,
              let langs = UserDefaults.standard.persistentDomain(forName: id)?["AppleLanguages"] as? [String],
              let first = langs.first else { return .system }
        return AppLanguage(rawValue: first) ?? .system
    }

    /// Stores the choice and relaunches, since bundle localizations are picked at launch.
    func apply() {
        guard self != AppLanguage.current else { return }
        if self == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()

        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}

/// Locale of the language the UI is actually shown in (not the system region), so numbers match the text.
let uiLocale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")

/// Battery percentage written the way the UI language does: "%97" (tr), "97%" (en), "97 %" (de, fr).
func percentText(_ value: Int) -> String {
    value.formatted(.percent.locale(uiLocale))
}
