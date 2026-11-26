import AppKit
import Combine
import SwiftUI

@main
struct FlexBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // The menu bar icon and panel live in StatusItemController; SwiftUI needs at least one scene.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

/// Owns the client and handles flexbar:// URLs (Shortcuts, Raycast, Terminal).
final class AppDelegate: NSObject, NSApplicationDelegate {
    let client = FlexClient()
    private var statusItem: StatusItemController?
    private var logSubscriptions: Set<AnyCancellable> = []

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(handleURL(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    /// `--log` prints state changes to stdout (open -n FlexBar.app --stdout log.txt --args --log).
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = MainActor.assumeIsolated { StatusItemController(client: client) }
        if CommandLine.arguments.contains("--show-panel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                MainActor.assumeIsolated { self?.statusItem?.showPanel() }
            }
        }
        startSnapshotIfRequested()
        guard CommandLine.arguments.contains("--log") else { return }
        setvbuf(stdout, nil, _IOLBF, 0)
        client.$state.sink { print("state:", $0) }.store(in: &logSubscriptions)
        client.$mode.sink { print("mode:", $0?.urlName ?? "-") }.store(in: &logSubscriptions)
        client.$pendingMode.sink { print("pending:", $0?.urlName ?? "-") }.store(in: &logSubscriptions)
        client.$left.combineLatest(client.$right, client.$caseLevel)
            .sink { l, r, c in print("battery: L \(l?.percent ?? -1) R \(r?.percent ?? -1) case \(c?.percent ?? -1)") }
            .store(in: &logSubscriptions)
        client.$firmware.sink { print("firmware:", $0 ?? "-") }.store(in: &logSubscriptions)
        client.$lastError.sink { if let e = $0 { print("error:", e) } }.store(in: &logSubscriptions)
    }

    /// Debug: `--snapshot <file.png>` renders the panel (dark and light) once battery data has arrived.
    private func startSnapshotIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return }
        let path = args[i + 1]
        client.$caseLevel.compactMap { $0 }.first()
            .delay(for: .seconds(1.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in MainActor.assumeIsolated {
                guard let self else { return }
                let views: [(String, AnyView)] = [
                    ("", AnyView(PanelView(client: self.client))),
                    ("card-", AnyView(ConnectCardView(client: self.client, animated: false)))
                ]
                for (prefix, content) in views {
                for (scheme, suffix) in [(ColorScheme.dark, "dark"), (.light, "light")] {
                    let view = content
                        .background(scheme == .dark ? Color(white: 0.16) : Color(white: 0.95))
                        .environment(\.colorScheme, scheme)
                    let renderer = ImageRenderer(content: view)
                    renderer.scale = 2
                    guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                          let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { continue }
                    try? png.write(to: URL(fileURLWithPath: path.replacingOccurrences(of: ".png", with: "-\(prefix)\(suffix).png")))
                }
                }
                print("snapshot written")
            } }
            .store(in: &logSubscriptions)
    }

    /// flexbar://anc | ambient | talkthru | off | cycle | refresh | panel | card
    @objc private func handleURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let text = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: text), url.scheme == "flexbar",
              let action = url.host?.lowercased() else { return }
        switch action {
        case "panel": MainActor.assumeIsolated { statusItem?.showPanel() }
        case "card": MainActor.assumeIsolated { statusItem?.showCard() }
        case "cycle": client.cycleMode()
        case "refresh": client.refresh()
        default:
            if let mode = NoiseMode.allCases.first(where: { $0.urlName == action }) { client.setMode(mode) }
        }
    }
}
