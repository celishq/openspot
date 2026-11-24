import AppKit
import OpenspotCore

extension FrontApp {
    init?(_ app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier else { return nil }
        self.init(bundleID: bundleID, path: app.bundleURL?.path, name: app.localizedName)
    }
}
