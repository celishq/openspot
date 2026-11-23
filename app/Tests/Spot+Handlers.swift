import Foundation
@testable import OpenspotCore

@MainActor
extension Spot {
    func handle(_ action: SpotWords, timeout: TimeInterval) async throws {
        var message = Message(action).handled()
        if message.words == action, action.arguments.count > 1 {
            message = Message(.press(action.arguments[0]), inputs: [.init(key: "item", value: action.arguments[1])])
        }
        try await perform(message.words, input: message.text, timeout: timeout)
    }
}
