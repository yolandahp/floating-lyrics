import AppKit

/// The menu bar icon: the only sign the app is running, and the way back when the pill is lost.
@MainActor
final class StatusBarController {
    private let item: NSStatusItem
    private let onToggle: () -> Void
    private let onReset: () -> Void

    init(onToggle: @escaping () -> Void, onReset: @escaping () -> Void) {
        self.onToggle = onToggle
        self.onReset = onReset
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "Floating Lyrics")

        let menu = NSMenu()
        menu.addItem(withTitle: "Show / Hide Lyrics", action: #selector(toggle), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Reset Position", action: #selector(reset), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Floating Lyrics", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
    }

    @objc private func toggle() { onToggle() }
    @objc private func reset() { onReset() }
}
