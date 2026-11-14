import Foundation

public enum SpotKind: String, CaseIterable, Sendable {
    case launch
    case toggle
    case list
    case slider
    case widget

    public var opensSheet: Bool {
        self == .list
    }
}
