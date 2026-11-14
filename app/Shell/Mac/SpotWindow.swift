import AppKit
import ApplicationServices
import OpenspotCore

@_silgen_name("_AXUIElementGetWindow")
private func windowNumber(_ element: AXUIElement, _ number: UnsafeMutablePointer<CGWindowID>) -> AXError

struct SpotWindow {
    private let element: AXUIElement

    static func front() throws -> SpotWindow {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.executableURL?.resolvingSymlinksInPath() != Bundle.main.executableURL?.resolvingSymlinksInPath() else {
            throw SpotError.fault("Openspot cannot find a window in front.")
        }
        let owner = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = attribute(owner, kAXFocusedWindowAttribute) ?? attribute(owner, kAXMainWindowAttribute) else {
            guard AXIsProcessTrusted() else {
                throw SpotError.failedWithFix(1, "Openspot cannot move the window. Allow it in Accessibility, then press the key again.", URL(string: SpotClipboard.accessibility)!)
            }
            throw SpotError.fault("Openspot cannot find a window of \(app.localizedName ?? "the front app").")
        }
        return SpotWindow(element: window as! AXUIElement)
    }

    var frame: CGRect {
        CGRect(origin: value(kAXPositionAttribute, .cgPoint, CGPoint.zero), size: value(kAXSizeAttribute, .cgSize, CGSize.zero))
    }

    var frameText: String {
        let window = frame
        let area = Self.area(holding: CGPoint(x: window.midX, y: window.midY))
        return ([window.minX, window.minY, window.width, window.height, area.minX, area.minY, area.width, area.height]
            .map { String(Int($0.rounded())) }.joined(separator: " ")) + "\n"
    }

    func move(_ move: WindowMove) throws {
        let window = frame
        let home = Self.area(holding: CGPoint(x: window.midX, y: window.midY))
        let target = move.target(window: window, area: move.needsArea ? home : .zero)
        let bounds = move.needsArea ? home : Self.area(holding: CGPoint(x: target.midX, y: target.midY))
        let start = WindowMove.start(of: target.size, from: window.origin, home: home, area: bounds)
        if start != window.origin { try? set(kAXPositionAttribute, .cgPoint, start) }
        resize(to: target.size)
        let size = frame.size
        let end = WindowMove.origin(of: size, target: target, area: bounds)
        let duration = 0.2
        let begin = Date()
        var time = 0.0
        while time < 1 {
            let step = 1 - pow(1 - time, 3)
            let x = start.x + (end.x - start.x) * step
            let y = start.y + (end.y - start.y) * step
            try? set(kAXPositionAttribute, .cgPoint, CGPoint(x: x.rounded(), y: y.rounded()))
            usleep(4_000)
            time = Date().timeIntervalSince(begin) / duration
        }
        try set(kAXPositionAttribute, .cgPoint, end)
        settle(at: size)
        let shown = frame.size
        if shown.width < target.width - 1 || shown.height < target.height - 1 { resize(to: target.size) }
        let last = WindowMove.origin(of: frame.size, target: target, area: bounds)
        if last != end { try set(kAXPositionAttribute, .cgPoint, last) }
    }

    private func resize(to size: CGSize) {
        _ = WindowMove.fit(size, from: frame.size) { wanted in
            try? set(kAXSizeAttribute, .cgSize, wanted)
            return frame.size
        }
    }

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

    private static func area(holding point: CGPoint) -> CGRect {
        Thread.isMainThread ? MainActor.assumeIsolated { area(of: point) } : DispatchQueue.main.sync { MainActor.assumeIsolated { area(of: point) } }
    }

    @MainActor
    private static func area(of point: CGPoint) -> CGRect {
        let screens = NSScreen.screens
        let top = screens.first?.frame.height ?? 0
        let areas = screens.map { CGRect(x: $0.visibleFrame.minX, y: top - $0.visibleFrame.maxY, width: $0.visibleFrame.width, height: $0.visibleFrame.height) }
        return areas.first { $0.contains(point) } ?? areas.first ?? .zero
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    private func value<T: BitwiseCopyable>(_ name: String, _ type: AXValueType, _ empty: T) -> T {
        var result = empty
        guard let raw = Self.attribute(element, name), CFGetTypeID(raw) == AXValueGetTypeID() else { return empty }
        AXValueGetValue(raw as! AXValue, type, &result)
        return result
    }

    private func set<T: BitwiseCopyable>(_ name: String, _ type: AXValueType, _ value: T) throws {
        var value = value
        guard let raw = AXValueCreate(type, &value), AXUIElementSetAttributeValue(element, name as CFString, raw) == .success else {
            throw SpotError.fault("Openspot cannot move this window.")
        }
    }
}
