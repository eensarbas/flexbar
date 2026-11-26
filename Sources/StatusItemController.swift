import AppKit
import Combine
import SwiftUI

/// Menu bar icon plus the panel. The panel is an NSPopover anchored to the icon, so it opens
/// centred under the icon with an arrow pointing at it.
@MainActor
final class StatusItemController: NSObject {
    private let client: FlexClient
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let cardPopover = NSPopover()
    private var cardCloseTask: DispatchWorkItem?
    /// Set when a connection is made; cleared once the card for it has been shown.
    private var awaitingCard = false
    private var subscriptions: Set<AnyCancellable> = []
    static let cardDuration: TimeInterval = 4

    init(client: FlexClient) {
        self.client = client
        super.init()

        let hosting = NSHostingController(rootView: PanelView(client: client))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.behavior = .transient  // closes on a click outside, like a menu
        popover.animates = true

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePanel)
            button.setAccessibilityLabel("FlexBar")
        }

        cardPopover.behavior = .applicationDefined  // stays put without taking focus; closed by a timer
        cardPopover.animates = true

        // Show the card once per connection, as soon as both earbuds and the case have reported.
        client.$state.removeDuplicates()
            .sink { [weak self] state in
                guard let self else { return }
                if state == .connected { self.awaitingCard = true } else { self.awaitingCard = false; self.closeCard() }
            }
            .store(in: &subscriptions)
        client.$left.combineLatest(client.$right, client.$caseLevel)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] left, right, caseLevel in
                guard let self, self.awaitingCard, left != nil, right != nil, caseLevel != nil else { return }
                self.awaitingCard = false
                self.showCard()
            }
            .store(in: &subscriptions)

        client.$state.combineLatest(client.$mode, client.$pendingMode)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state, mode, pending in
                self?.updateIcon(connected: state == .connected, mode: pending ?? mode)
            }
            .store(in: &subscriptions)
    }

    @objc func togglePanel() {
        popover.isShown ? popover.performClose(nil) : showPanel()
    }

    func showPanel() {
        guard let button = statusItem.button else { return }
        closeCard()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    /// The connect card: centred under the icon like the panel, closes itself after a few seconds.
    func showCard() {
        guard let button = statusItem.button, !popover.isShown else { return }
        // A fresh hosting controller each time replays the ring animation.
        let hosting = NSHostingController(rootView: ConnectCardView(client: client) { [weak self] in self?.showPanel() })
        hosting.sizingOptions = .preferredContentSize
        cardPopover.contentViewController = hosting
        if !cardPopover.isShown {
            cardPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        cardCloseTask?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.closeCard() }
        cardCloseTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.cardDuration, execute: task)
    }

    private func closeCard() {
        cardCloseTask?.cancel()
        if cardPopover.isShown { cardPopover.performClose(nil) }
    }

    private func updateIcon(connected: Bool, mode: NoiseMode?) {
        guard let button = statusItem.button else { return }
        let name = connected ? (mode ?? .off).symbol : "headphones"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        button.image = image
        button.appearsDisabled = !connected
    }
}
