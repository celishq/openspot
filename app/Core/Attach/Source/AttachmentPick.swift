import Foundation

public enum AttachmentPick: Equatable, Sendable {
    case pattern(AnswerPattern)
    case browsers

    static let browsersWord = "browsers"

    init?(_ text: String) {
        guard text != Self.browsersWord else {
            self = .browsers
            return
        }
        guard let pattern = AnswerPattern(text) else { return nil }
        self = .pattern(pattern)
    }

    func matches(_ front: String, browsers: [Browser]) -> Bool {
        switch self {
        case .pattern(let pattern): pattern.matches(front)
        case .browsers: browsers.contains { $0.bundleID == front }
        }
    }
}
