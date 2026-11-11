import AppKit
import OpenspotCore

/// The overlay over each screen where the person picks a source with no value (S3). It lights the window or the display
/// under the pointer, draws the area of a drag, and ends at a pick or at Escape, which gives the focus back to the app that
/// had it.
@MainActor
final class SpotScreenPick {
    private let pick: ScreenPick
    private let mainHeight: CGFloat
    private var panels: [NSPanel] = []
    private var views: [Surface] = []
    private var start: CGPoint?
    private var answer: CheckedContinuation<ScreenTarget?, Never>?
    private var previous: NSRunningApplication?

    private init(pick: ScreenPick, mainHeight: CGFloat) {
        self.pick = pick
        self.mainHeight = mainHeight
    }

    /// The target that the person picks, or nil after Escape.
    static func target(of source: ScreenSource) async -> ScreenTarget? {
        let mainHeight = NSScreen.screens.first?.frame.maxY ?? 0
        let displays = NSScreen.screens.compactMap { screen -> ScreenPick.Item? in
            guard let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else { return nil }
            return ScreenPick.Item(id: id, frame: CGRect(x: screen.frame.minX, y: mainHeight - screen.frame.maxY, width: screen.frame.width, height: screen.frame.height))
        }
        let windows = SpotScreenTarget.windows().compactMap { window -> ScreenPick.Item? in
            guard let id = window[kCGWindowNumber as String] as? UInt32,
                  let bounds = (window[kCGWindowBounds as String] as? NSDictionary).flatMap({ CGRect(dictionaryRepresentation: $0) }) else { return nil }
            return ScreenPick.Item(id: id, frame: bounds)
        }
        guard let pick = ScreenPick(source: source, displays: displays, windows: windows) else { return nil }
        let overlay = SpotScreenPick(pick: pick, mainHeight: mainHeight)
        return await withCheckedContinuation { overlay.show(answering: $0) }
    }

    private func show(answering answer: CheckedContinuation<ScreenTarget?, Never>) {
        self.answer = answer
        for screen in NSScreen.screens {
            let panel = Panel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            let view = Surface(frame: CGRect(origin: .zero, size: screen.frame.size), overlay: self)
            panel.level = .screenSaver
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.acceptsMouseMovedEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = view
            panel.setFrame(screen.frame, display: false)
            panels.append(panel)
            views.append(view)
        }
        previous = NSWorkspace.shared.frontmostApplication.flatMap { $0.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : $0 }
        NSApp.activate()
        panels.forEach { $0.orderFrontRegardless() }
        let under = panels.first { $0.frame.contains(NSEvent.mouseLocation) } ?? panels.first
        under?.makeKey()
        under?.makeFirstResponder(under?.contentView)
        NSCursor.crosshair.set()
        moved(to: NSEvent.mouseLocation)
    }

    /// A point of the screen, in points from the top left of the main display.
    private func global(_ point: NSPoint) -> CGPoint {
        CGPoint(x: point.x, y: mainHeight - point.y)
    }

    fileprivate func moved(to location: NSPoint) {
        let lit = start.flatMap { pick.area(from: $0, to: global(location)) } ?? (start == nil ? pick.hover(at: global(location)) : nil)
        views.forEach { $0.show(lit.map(local), isArea: start != nil) }
    }

    fileprivate func pressed(at location: NSPoint) {
        start = global(location)
        moved(to: location)
    }

    fileprivate func released(at location: NSPoint) {
        guard let from = start else { return }
        start = nil
        guard let target = pick.target(from: from, to: global(location)) else {
            moved(to: location)
            return
        }
        finish(target)
    }

    fileprivate func finish(_ target: ScreenTarget?) {
        panels.forEach { $0.orderOut(nil) }
        panels = []
        views = []
        previous?.activate()
        previous = nil
        answer?.resume(returning: target)
        answer = nil
    }

    /// A frame from the top left of the main display, as a frame on the screen that AppKit draws.
    private func local(_ frame: CGRect) -> CGRect {
        CGRect(x: frame.minX, y: mainHeight - frame.maxY, width: frame.width, height: frame.height)
    }

    /// A panel of the overlay that takes keys, so that Escape reaches it.
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    /// The view of one screen: a dim over all of it, and a clear frame where the light falls.
    private final class Surface: NSView {
        private let overlay: SpotScreenPick
        private var lit: CGRect?
        private var isArea = false

        init(frame: CGRect, overlay: SpotScreenPick) {
            self.overlay = overlay
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) { nil }

        /// Lights a frame given on the screens, in AppKit points from the bottom left of the main display.
        func show(_ frame: CGRect?, isArea: Bool) {
            lit = frame.map { $0.offsetBy(dx: -(window?.frame.minX ?? 0), dy: -(window?.frame.minY ?? 0)) }
            self.isArea = isArea
            needsDisplay = true
        }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.black.withAlphaComponent(0.25).setFill()
            bounds.fill()
            guard let lit, lit.intersects(bounds) else { return }
            NSColor.clear.setFill()
            lit.fill(using: .copy)
            NSColor.controlAccentColor.withAlphaComponent(isArea ? 0 : 0.15).setFill()
            lit.fill(using: .sourceOver)
            NSColor.controlAccentColor.setStroke()
            let rim = NSBezierPath(rect: lit.insetBy(dx: 1, dy: 1))
            rim.lineWidth = 2
            rim.stroke()
            guard isArea else { return }
            let words = "\(Int(lit.width)) × \(Int(lit.height))" as NSString
            let style: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.white]
            let size = words.size(withAttributes: style)
            let tag = CGRect(x: lit.minX, y: max(lit.minY - size.height - 10, 4), width: size.width + 12, height: size.height + 6)
            NSColor.black.withAlphaComponent(0.7).setFill()
            NSBezierPath(roundedRect: tag, xRadius: 5, yRadius: 5).fill()
            words.draw(at: CGPoint(x: tag.minX + 6, y: tag.minY + 3), withAttributes: style)
        }

        override var acceptsFirstResponder: Bool { true }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .cursorUpdate, .activeAlways, .inVisibleRect], owner: self))
        }

        override func cursorUpdate(with event: NSEvent) { NSCursor.crosshair.set() }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseMoved(with event: NSEvent) { overlay.moved(to: NSEvent.mouseLocation) }
        override func mouseDown(with event: NSEvent) { overlay.pressed(at: NSEvent.mouseLocation) }
        override func mouseDragged(with event: NSEvent) { overlay.moved(to: NSEvent.mouseLocation) }
        override func mouseUp(with event: NSEvent) { overlay.released(at: NSEvent.mouseLocation) }

        override func keyDown(with event: NSEvent) {
            guard event.keyCode == 53 else { return super.keyDown(with: event) }
            overlay.finish(nil)
        }
    }
}
