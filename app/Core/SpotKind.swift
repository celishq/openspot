import Foundation

public enum SpotKind: String, CaseIterable, Sendable {
    case launch
    case toggle
    case list
    case slider
    case widget
    case view

    /// Whether the spot opens a sheet in the panel.
    public var opensSheet: Bool {
        self == .list || self == .view
    }
}
