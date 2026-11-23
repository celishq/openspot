import Foundation

enum RunEnd: Equatable, Sendable {
    case values([TextBlock.Field])
    case failed(String)
    case refused(String)
    case unanswered(String)
    case cancelled

    var code: Int32 {
        switch self {
        case .values: 0
        case .failed: 1
        case .refused: 2
        case .unanswered: 3
        case .cancelled: 4
        }
    }
}
