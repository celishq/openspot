import Foundation

struct Browser: Equatable, Sendable {
    let bundleID: String
    let name: String
    let tab: String
    let title: String
    let active: String

    static let all = [
        Browser(bundleID: "com.apple.Safari", name: "Safari", tab: "current tab", title: "name", active: "index of current tab"),
        Browser(bundleID: "com.apple.SafariTechnologyPreview", name: "Safari Technology Preview", tab: "current tab", title: "name", active: "index of current tab"),
        Browser(bundleID: "com.google.Chrome", name: "Google Chrome"),
        Browser(bundleID: "com.google.Chrome.canary", name: "Google Chrome Canary"),
        Browser(bundleID: "company.thebrowser.Browser", name: "Arc"),
        Browser(bundleID: "com.brave.Browser", name: "Brave"),
        Browser(bundleID: "com.microsoft.edgemac", name: "Microsoft Edge"),
        Browser(bundleID: "com.vivaldi.Vivaldi", name: "Vivaldi"),
        Browser(bundleID: "com.operasoftware.Opera", name: "Opera")
    ]

    init(bundleID: String, name: String, tab: String = "active tab", title: String = "title", active: String = "active tab index") {
        self.bundleID = bundleID
        self.name = name
        self.tab = tab
        self.title = title
        self.active = active
    }

    static func named(_ bundleID: String) -> Browser? {
        all.first { $0.bundleID == bundleID }
    }

    static func unknown(_ bundleID: String) -> String {
        let names = all.map(\.name)
        return "Openspot can't read the tabs of \(bundleID). It reads " + names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1] + "."
    }

    var script: String {
        """
        tell application id "\(bundleID)"
            set front_tab to \(tab) of front window
            return {URL of front_tab, \(title) of front_tab}
        end tell
        """
    }

    var tabsScript: String {
        """
        tell application id "\(bundleID)"
            set {urls, titles, actives} to {URL of tabs of windows, \(title) of tabs of windows, \(active) of windows}
        end tell
        set found to {}
        repeat with w from 1 to count of urls
            set window_urls to item w of urls
            repeat with t from 1 to count of window_urls
                set tab_url to item t of window_urls
                if tab_url is missing value then set tab_url to ""
                set tab_title to item t of item w of titles
                if tab_title is missing value then set tab_title to ""
                set end of found to tab_url as text
                set end of found to tab_title as text
                set end of found to w as text
                set end of found to t as text
                set end of found to (t = (item w of actives)) as text
            end repeat
        end repeat
        return found
        """
    }
}
