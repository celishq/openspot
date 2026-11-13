import Foundation

/// The panel of the grid that a spot lies in: the center one, which holds the search, or a side panel left or right of it.
public enum GridPanel: String, CaseIterable, Equatable, Hashable, Sendable {
    case left, center, right

    /// The key of the config file that shows this side panel. Nil for the center, which always shows.
    public var configKey: String? {
        switch self {
        case .left: "left_panel"
        case .center: nil
        case .right: "right_panel"
        }
    }
}
