import Foundation

struct Browser: Equatable, Sendable {
    enum Family: String, CaseIterable, Sendable {
        case chromium, safari

        var tab: String {
            self == .safari ? "current tab" : "active tab"
        }

        var title: String {
            self == .safari ? "name" : "title"
        }

        var active: String {
            self == .safari ? "index of current tab" : "active tab index"
        }
    }

    let bundleID: String
    let name: String?
    let family: Family

    static let builtIn = [
        Browser(bundleID: "com.apple.Safari", name: "Safari", family: .safari),
        Browser(bundleID: "com.apple.SafariTechnologyPreview", name: "Safari Technology Preview", family: .safari),
        Browser(bundleID: "com.google.Chrome", name: "Google Chrome"),
        Browser(bundleID: "com.google.Chrome.canary", name: "Google Chrome Canary"),
        Browser(bundleID: "company.thebrowser.Browser", name: "Arc"),
        Browser(bundleID: "com.brave.Browser", name: "Brave"),
        Browser(bundleID: "com.microsoft.edgemac", name: "Microsoft Edge"),
        Browser(bundleID: "com.vivaldi.Vivaldi", name: "Vivaldi"),
        Browser(bundleID: "com.operasoftware.Opera", name: "Opera")
    ]

    init(bundleID: String, name: String? = nil, family: Family = .chromium) {
        self.bundleID = bundleID
        self.name = name
        self.family = family
    }

    static func unknown(_ bundleID: String, names: [String]) -> String {
        "Openspot can't read the tabs of \(bundleID). It reads " + names.dropLast().joined(separator: ", ") + (names.count > 1 ? " and " : "") + (names.last ?? "") + "."
    }

    static func familyFault(of bundleID: String) -> String {
        "the browser \(bundleID) is " + Family.allCases.map { "\"\($0.rawValue)\"" }.joined(separator: " or ") + "."
    }

    func family(_ family: Family) -> Browser {
        Browser(bundleID: bundleID, name: name, family: family)
    }

    var script: String {
        """
        tell application id "\(bundleID)"
            set front_tab to \(family.tab) of front window
            return {URL of front_tab, \(family.title) of front_tab}
        end tell
        """
    }

    var tabsScript: String {
        """
        tell application id "\(bundleID)"
            set {urls, titles, actives} to {URL of tabs of windows, \(family.title) of tabs of windows, \(family.active) of windows}
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
