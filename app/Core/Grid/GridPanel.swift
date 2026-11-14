import Foundation

public enum GridPanel: String, CaseIterable, Equatable, Hashable, Sendable {
    case left, center, right

    public var configKey: String? {
        switch self {
        case .left: "left_panel"
        case .center: nil
        case .right: "right_panel"
        }
    }
}
