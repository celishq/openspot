import AppKit
import OpenspotCore

enum SpotFrontWindow {
    static func frame(of app: NSRunningApplication?) -> CGRect? {
        guard let app else { return nil }
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let front = windows.first {
            ($0[kCGWindowOwnerPID as String] as? pid_t) == app.processIdentifier && ($0[kCGWindowLayer as String] as? Int) == 0
        }
        let bounds = (front?[kCGWindowBounds as String] as? NSDictionary).flatMap { CGRect(dictionaryRepresentation: $0) }
        return bounds.map { ScreenPlace.frame(ofBounds: $0, mainHeight: NSScreen.screens.first?.frame.maxY ?? 0) }
    }
}
