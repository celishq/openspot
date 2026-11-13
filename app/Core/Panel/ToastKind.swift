import Foundation

/// What a toast tells: that an act is done, that it failed, or that work runs with no known end.
public enum ToastKind: Sendable {
    case confirm
    case failure
    case work

    /// The symbol of the toast, which the menu bar icon shows too. Work shows the spinner, which has none.
    public var symbol: String? {
        switch self {
        case .confirm: "checkmark.circle.fill"
        case .failure: "exclamationmark.triangle.fill"
        case .work: nil
        }
    }
}
