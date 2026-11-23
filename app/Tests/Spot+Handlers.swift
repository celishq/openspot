import Foundation
@testable import OpenspotCore

@MainActor
extension Spot {
    func handle(_ action: SpotWords, timeout: TimeInterval) async throws {
        let words = action.arguments
        let rest = Array(words.dropFirst())
        let message = switch words.first {
        case Handler.drop.name: Handler.drop.message(rest)
        case Handler.drag.name: Handler.drag.message(rest)
        case Handler.press.name: Handler.press.message(rest)
        case let name? where !rest.isEmpty: Message(.press(name), inputs: [.init(key: "item", value: rest[0])])
        default: Message(action)
        }
        try await perform(message.words, input: message.text, timeout: timeout)
    }
}
