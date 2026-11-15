import AppKit
import OpenspotCore
import ScreenCaptureKit

struct SpotScreenTarget {
    let filter: SCContentFilter
    let area: CGRect?
    let frame: CGRect

    var scale: CGFloat { CGFloat(filter.pointPixelScale) }

    func configuration(cursor: Bool) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        let size = area?.size ?? filter.contentRect.size
        configuration.width = Int((size.width * scale).rounded())
        configuration.height = Int((size.height * scale).rounded())
        if let area { configuration.sourceRect = area }
        configuration.showsCursor = cursor
        return configuration
    }

    static func target(of source: ScreenSource) async throws -> ScreenTarget? {
        switch source {
        case .display(let id?): return .display(id)
        case .window(.id(let id)): return .window(id)
        case .window(.front):
            guard let id = windows().first.flatMap({ $0[kCGWindowNumber as String] as? UInt32 }) else {
                throw SpotError.fault("Openspot cannot find a window in front. Open one, then try again.")
            }
            return .window(id)
        case .area(let frame?):
            return .area(frame.target(window: .zero, area: CGDisplayBounds(CGMainDisplayID())))
        case .any, .display(nil), .window(nil), .area(nil):
            return await SpotScreenPick.target(of: source)
        }
    }

    static func find(_ target: ScreenTarget) async throws -> SpotScreenTarget {
        let content = try await SpotScreen.allowed { try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) }
        let own = content.applications.filter { isOwn($0.processID) }
        switch target {
        case .display(let id):
            guard let display = content.displays.first(where: { $0.displayID == id }) else {
                throw SpotError.fault("Openspot cannot find display \(id). Run `openspot screen sources` to see each display.")
            }
            return SpotScreenTarget(filter: SCContentFilter(display: display, excludingApplications: own, exceptingWindows: []), area: nil, frame: display.frame)
        case .window(let id):
            guard let window = content.windows.first(where: { $0.windowID == id }) else {
                throw SpotError.fault("Openspot cannot find window \(id). Run `openspot screen sources` to see each window.")
            }
            return SpotScreenTarget(filter: SCContentFilter(desktopIndependentWindow: window), area: nil, frame: window.frame)
        case .area(let frame):
            guard let display = content.displays.first(where: { $0.frame.contains(frame) }) else {
                throw SpotError.fault("The area does not lie on one display. Pick an area inside one display.")
            }
            let filter = SCContentFilter(display: display, excludingApplications: own, exceptingWindows: [])
            return SpotScreenTarget(filter: filter, area: frame.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY), frame: frame)
        }
    }

    static func windows() -> [[String: Any]] {
        let all = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return all.filter {
            ($0[kCGWindowLayer as String] as? Int) == 0 && ($0[kCGWindowAlpha as String] as? Double ?? 1) > 0
                && !isOwn($0[kCGWindowOwnerPID as String] as? pid_t ?? 0)
        }
    }

    static func isOwn(_ id: pid_t) -> Bool {
        var path = [UInt8](repeating: 0, count: Int(MAXPATHLEN))
        let length = proc_pidpath(id, &path, UInt32(path.count))
        guard length > 0 else { return false }
        let program = URL(fileURLWithPath: String(decoding: path[..<Int(length)], as: UTF8.self))
        return program.resolvingSymlinksInPath() == Bundle.main.executableURL?.resolvingSymlinksInPath()
    }
}
