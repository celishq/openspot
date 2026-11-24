import Foundation

public enum ToastKind: Sendable {
    case confirm
    case failure
    case work

    public var symbol: String? {
        switch self {
        case .confirm: "checkmark.circle.fill"
        case .failure: "exclamationmark.triangle.fill"
        case .work: nil
        }
    }
}
