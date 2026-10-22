import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = LyricsViewModel()
    private let ui = PillUIState()
    private var panel: FloatingPanel!
    private var statusBar: StatusBarController!
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = FloatingPanel(content: PillView(model: model, ui: ui))
        panel.restoreOrCentreBottom()
        panel.orderFrontRegardless()

        statusBar = StatusBarController(
            onToggle: { [weak self] in self?.togglePanel() },
            onReset: { [weak self] in
                self?.ui.minimized = false
                self?.panel.centreBottom()
                self?.panel.orderFrontRegardless()
            }
        )

        ui.$minimized
            .removeDuplicates()
            .sink { [weak self] in self?.panel.setMinimized($0) }
            .store(in: &subscriptions)

        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            NotificationCenter.default.addObserver(forName: name, object: panel, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.panel.saveFrame()
                    self?.panel.invalidateShadow() // the shape changed, so the system shadow must too
                }
            }
        }

        model.start()
    }

    private func togglePanel() {
        if panel.isVisible { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // no Dock icon; the menu bar item is the app's presence
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
