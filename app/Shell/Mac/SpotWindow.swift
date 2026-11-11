import AppKit
import ApplicationServices
import OpenspotCore

/// The number of the window server for the window of an Accessibility element.
@_silgen_name("_AXUIElementGetWindow")
private func windowNumber(_ element: AXUIElement, _ number: UnsafeMutablePointer<CGWindowID>) -> AXError

/// The focused window of the front app, read and moved through Accessibility for the `openspot window` commands.
/// Frames are in points from the top left of the main screen, as Accessibility gives them.
@MainActor
struct SpotWindow {
    private let element: AXUIElement

    /// The focused window of the front app. It fails without Accessibility, or when that app shows no window.
    static func front() throws -> SpotWindow {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.executableURL?.resolvingSymlinksInPath() != Bundle.main.executableURL?.resolvingSymlinksInPath() else {
            throw PluginError.fault("Openspot cannot find a window in front.")
        }
        let owner = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = attribute(owner, kAXFocusedWindowAttribute) ?? attribute(owner, kAXMainWindowAttribute) else {
            guard AXIsProcessTrusted() else {
                print("link=\(SpotClipboard.accessibility)")
                throw PluginError.fault("Openspot cannot move the window. Allow it in Accessibility, then press the key again.")
            }
            throw PluginError.fault("Openspot cannot find a window of \(app.localizedName ?? "the front app").")
        }
        return SpotWindow(element: window as! AXUIElement)
    }

    var frame: CGRect {
        CGRect(origin: value(kAXPositionAttribute, .cgPoint, CGPoint.zero), size: value(kAXSizeAttribute, .cgSize, CGSize.zero))
    }

    /// The window, then the usable area of its screen, as one line of eight whole numbers.
    var frameText: String {
        let window = frame
        let area = Self.area(holding: CGPoint(x: window.midX, y: window.midY))
        return ([window.minX, window.minY, window.width, window.height, area.minX, area.minY, area.width, area.height]
            .map { String(Int($0.rounded())) }.joined(separator: " ")) + "\n"
    }

    /// Glides the window from its frame to its target over a fifth of a second, so it flies there and takes its shape
    /// on the way. An app that draws a web page shows a new size only once it has drawn it, so the last size is read
    /// back only after the screen shows it. A last move then holds each edge the target touches when the app keeps
    /// another size.
    func move(_ move: WindowMove) throws {
        let window = frame
        let centre = CGPoint(x: window.midX, y: window.midY)
        let area = move.needsArea ? Self.area(holding: centre) : .zero
        let target = move.target(window: window, area: area)
        glide(from: window, to: target)
        try set(kAXPositionAttribute, .cgPoint, target.origin)
        try set(kAXSizeAttribute, .cgSize, target.size)
        settle(at: target.size)
        let size = frame.size
        guard size != target.size else { return }
        let bounds = move.needsArea ? area : Self.area(holding: CGPoint(x: target.midX, y: target.midY))
        let origin = WindowMove.origin(of: size, target: target, area: bounds)
        if origin != target.origin { try set(kAXPositionAttribute, .cgPoint, origin) }
    }

    /// Sets the frames between two frames, eased out, as fast as the app takes them, until the time is up.
    private func glide(from start: CGRect, to end: CGRect) {
        guard start != end else { return }
        let duration = 0.2
        let begin = Date()
        while true {
            let time = Date().timeIntervalSince(begin) / duration
            guard time < 1 else { return }
            let step = 1 - pow(1 - time, 3)
            let x = start.minX + (end.minX - start.minX) * step
            let y = start.minY + (end.minY - start.minY) * step
            let width = start.width + (end.width - start.width) * step
            let height = start.height + (end.height - start.height) * step
            try? set(kAXSizeAttribute, .cgSize, CGSize(width: width.rounded(), height: height.rounded()))
            try? set(kAXPositionAttribute, .cgPoint, CGPoint(x: x.rounded(), y: y.rounded()))
            usleep(4_000)
        }
    }

    /// Waits, for a second at most, until the window server shows the window at this size.
    private func settle(at size: CGSize) {
        var id: CGWindowID = 0
        guard windowNumber(element, &id) == .success else { return }
        let end = Date().addingTimeInterval(1)
        while Date() < end {
            let rows = CGWindowListCopyWindowInfo(.optionIncludingWindow, id) as? [[String: Any]]
            if let bounds = rows?.first?[kCGWindowBounds as String] as! CFDictionary?,
               let shown = CGRect(dictionaryRepresentation: bounds),
               abs(shown.width - size.width) < 1, abs(shown.height - size.height) < 1 {
                return
            }
            usleep(4_000)
        }
    }

    /// The usable area of the screen that holds this point, or of the main screen.
    private static func area(holding point: CGPoint) -> CGRect {
        let screens = NSScreen.screens
        let top = screens.first?.frame.height ?? 0
        let areas = screens.map { CGRect(x: $0.visibleFrame.minX, y: top - $0.visibleFrame.maxY, width: $0.visibleFrame.width, height: $0.visibleFrame.height) }
        return areas.first { $0.contains(point) } ?? areas.first ?? .zero
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    private func value<T>(_ name: String, _ type: AXValueType, _ empty: T) -> T {
        var result = empty
        guard let raw = Self.attribute(element, name), CFGetTypeID(raw) == AXValueGetTypeID() else { return empty }
        AXValueGetValue(raw as! AXValue, type, &result)
        return result
    }

    private func set<T>(_ name: String, _ type: AXValueType, _ value: T) throws {
        var value = value
        guard let raw = AXValueCreate(type, &value), AXUIElementSetAttributeValue(element, name as CFString, raw) == .success else {
            throw PluginError.fault("Openspot cannot move this window.")
        }
    }
}
