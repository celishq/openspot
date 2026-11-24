import Foundation

struct Browser: Equatable, Sendable {
    let bundleID: String
    let name: String
    let tab: String
    let title: String

    static let all = [
        Browser(bundleID: "com.apple.Safari", name: "Safari", tab: "current tab", title: "name"),
        Browser(bundleID: "com.apple.SafariTechnologyPreview", name: "Safari Technology Preview", tab: "current tab", title: "name"),
        Browser(bundleID: "com.google.Chrome", name: "Google Chrome"),
        Browser(bundleID: "com.google.Chrome.canary", name: "Google Chrome Canary"),
        Browser(bundleID: "company.thebrowser.Browser", name: "Arc"),
        Browser(bundleID: "com.brave.Browser", name: "Brave"),
        Browser(bundleID: "com.microsoft.edgemac", name: "Microsoft Edge"),
        Browser(bundleID: "com.vivaldi.Vivaldi", name: "Vivaldi"),
        Browser(bundleID: "com.operasoftware.Opera", name: "Opera")
    ]

    init(bundleID: String, name: String, tab: String = "active tab", title: String = "title") {
        self.bundleID = bundleID
        self.name = name
        self.tab = tab
        self.title = title
    }

    var script: String {
        """
        tell application id "\(bundleID)"
            set front_tab to \(tab) of front window
            return {URL of front_tab, \(title) of front_tab}
        end tell
        """
    }
}
