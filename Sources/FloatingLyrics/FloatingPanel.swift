import AppKit
import SwiftUI

/// Borderless, transparent, always-on-top panel that never steals focus from the app you work in.
/// The user moves it by dragging and resizes it from the right edge; the pill fills the window.
final class FloatingPanel: NSPanel {
    static let defaultSize = NSSize(width: 560, height: 52)
    static let dotSize = NSSize(width: 18, height: 18)
    private static let frameKey = "pillFrame"

    private let handle: ResizeHandleView
    /// Frame to go back to when the pill is expanded again.
    private var expandedFrame: NSRect?

    init(content: some View) {
        handle = ResizeHandleView(frame: .zero)
        super.init(contentRect: NSRect(origin: .zero, size: Self.defaultSize),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true // follows the pill's rounded alpha shape
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        minSize = NSSize(width: 200, height: 44)
        maxSize = NSSize(width: 2400, height: 120)

        let container = NSView(frame: NSRect(origin: .zero, size: Self.defaultSize))
        let host = NSHostingView(rootView: content)
        host.sizingOptions = [] // the window owns its size, not the view
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)

        handle.frame = NSRect(x: container.bounds.width - ResizeHandleView.width, y: 0,
                              width: ResizeHandleView.width, height: container.bounds.height)
        handle.autoresizingMask = [.minXMargin, .height]
        container.addSubview(handle)
        contentView = container
    }

    // MARK: Placement

    func restoreOrCentreBottom() {
        if let saved = UserDefaults.standard.string(forKey: Self.frameKey) {
            let f = NSRectFromString(saved)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(f) }) {
                setFrame(f, display: true)
                return
            }
        }
        centreBottom()
    }

    func centreBottom() {
        guard let screen = NSScreen.main else { return }
        let v = screen.visibleFrame
        setFrame(NSRect(x: v.midX - Self.defaultSize.width / 2, y: v.minY + 24,
                        width: Self.defaultSize.width, height: Self.defaultSize.height), display: true)
    }

    func saveFrame() {
        guard expandedFrame == nil else { return } // never persist the dot-sized frame
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: Self.frameKey)
    }

    // MARK: Minimize

    /// Shrinks the window to the dot (anchored at its left edge) or restores it.
    /// Keeping the window dot-sized means hover and resize can't trigger over empty space.
    func setMinimized(_ minimized: Bool) {
        if minimized, expandedFrame == nil {
            expandedFrame = frame
            handle.isHidden = true
            let origin = NSPoint(x: frame.minX, y: frame.midY - Self.dotSize.height / 2)
            setFrame(NSRect(origin: origin, size: Self.dotSize), display: true)
        } else if !minimized, let restored = expandedFrame {
            expandedFrame = nil
            handle.isHidden = false
            setFrame(NSRect(x: frame.minX, y: frame.midY - restored.height / 2,
                            width: restored.width, height: restored.height), display: true)
        }
        invalidateShadow()
    }
}

/// macOS moves a background-draggable window in the window server as soon as the press lands,
/// so a resize zone must be a view that opts out of that (`mouseDownCanMoveWindow`) and
/// resizes the window itself.
final class ResizeHandleView: NSView {
    static let width: CGFloat = 28
    private var dragStart: (mouseX: CGFloat, width: CGFloat)?

    override var mouseDownCanMoveWindow: Bool { false }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        dragStart = (NSEvent.mouseLocation.x, window.frame.width)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let dragStart else { return }
        var f = window.frame
        let wanted = dragStart.width + (NSEvent.mouseLocation.x - dragStart.mouseX)
        f.size.width = min(max(wanted, window.minSize.width), window.maxSize.width)
        window.setFrame(f, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
    }
}
