import AppKit
import ApplicationServices
import OpenspotCore

/// The focused window of the front app, read and moved through Accessibility for the `openspot window` commands. It runs on
/// the thread of its call, and reads the screens on the main thread only when a frame needs the area of one.
/// Frames are in points from the top left of the main screen, as Accessibility gives them.
struct SpotWindow {
    private let element: AXUIElement

    /// The focused window of the front app. It fails without Accessibility, or when that app shows no window.
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

    /// The window, then the usable area of its screen, as one line of eight whole numbers.
    func frameText() async -> String {
        let window = frame
        let area = await Self.area(holding: CGPoint(x: window.midX, y: window.midY))
        return ([window.minX, window.minY, window.width, window.height, area.minX, area.minY, area.width, area.height]
            .map { String(Int($0.rounded())) }.joined(separator: " ")) + "\n"
    }

    /// Moves the window to its target first and sizes it there, so the edge of the screen never cuts the new size.
    func move(_ move: WindowMove) async throws {
        let window = frame
        let centre = CGPoint(x: window.midX, y: window.midY)
        let area = move.needsArea ? await Self.area(holding: centre) : .zero
        let target = move.target(window: window, area: area)
        try set(kAXPositionAttribute, .cgPoint, target.origin)
        try set(kAXSizeAttribute, .cgSize, target.size)
        let size = frame.size
        guard size != target.size else { return }
        let bounds = move.needsArea ? area : await Self.area(holding: CGPoint(x: target.midX, y: target.midY))
        let origin = WindowMove.origin(of: size, target: target, area: bounds)
        if origin != target.origin { try set(kAXPositionAttribute, .cgPoint, origin) }
    }

    /// The usable area of the screen that holds this point, or of the main screen.
    @MainActor
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
            throw SpotError.fault("Openspot cannot move this window.")
        }
    }
}
