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
    /// on the way. Each step places the size that the app really gave, by the edges the target holds, so a window
    /// that keeps a larger or smaller size ends where it stays, with no jump. The last place waits until the screen
    /// shows the last size, as an app that draws a web page shows a new size late.
    func move(_ move: WindowMove) throws {
        let window = frame
        let centre = CGPoint(x: window.midX, y: window.midY)
        let area = move.needsArea ? Self.area(holding: centre) : .zero
        let target = move.target(window: window, area: area)
        let bounds = move.needsArea ? area : Self.area(holding: CGPoint(x: target.midX, y: target.midY))
        let duration = 0.2
        let begin = Date()
        var time = 0.0
        while time < 1 {
            let step = 1 - pow(1 - time, 3)
            let frame = CGRect(
                x: window.minX + (target.minX - window.minX) * step,
                y: window.minY + (target.minY - window.minY) * step,
                width: window.width + (target.width - window.width) * step,
                height: window.height + (target.height - window.height) * step
            )
            try? place(frame, holding: target, area: bounds)
            usleep(4_000)
            time = Date().timeIntervalSince(begin) / duration
        }
        let size = try place(target, holding: target, area: bounds)
        settle(at: size)
        let origin = WindowMove.origin(of: frame.size, target: target, area: bounds)
        if origin != frame.origin { try set(kAXPositionAttribute, .cgPoint, origin) }
    }

    /// Asks for the size of this frame, then places the size that the app gave by the edges the target holds.
    /// Returns that size.
    @discardableResult
    private func place(_ step: CGRect, holding target: CGRect, area: CGRect) throws -> CGSize {
        try set(kAXSizeAttribute, .cgSize, CGSize(width: step.width.rounded(), height: step.height.rounded()))
        let size = frame.size
        let origin = WindowMove.origin(of: size, target: step, holding: target, area: area, inside: step == target)
        try set(kAXPositionAttribute, .cgPoint, CGPoint(x: origin.x.rounded(), y: origin.y.rounded()))
        return size
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
