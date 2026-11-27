import Foundation

public enum SpotPlace: String, CaseIterable, Sendable {
    case searchField = "attachment"
    case menuBar = "menubar"
    case window

    public var key: String {
        rawValue
    }

    public var name: String {
        switch self {
        case .searchField: "Search Field"
        case .menuBar: "Menu Bar"
        case .window: "Window"
        }
    }

    var title: String {
        switch self {
        case .searchField: "Show beside the search field"
        case .menuBar: "Show in the menu bar"
        case .window: "Open in a window"
        }
    }

    var icon: String {
        switch self {
        case .searchField: "paperclip"
        case .menuBar: "menubar.rectangle"
        case .window: "macwindow"
        }
    }

    public var info: String? {
        switch self {
        case .searchField: "When the panel opens, what this spot reads shows on the right of the search field. Press Tab to hand it to a spot."
        case .menuBar, .window: nil
        }
    }
}
