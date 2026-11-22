import Foundation
@testable import OpenspotCore

@MainActor
extension Spot {
    func handle(_ action: SpotAction, timeout: TimeInterval) async throws {
        var message = Message(action).handled()
        if message.action == action, action.arguments.count > 1 {
            message = Message(.press(action.arguments[0]), inputs: [.init(key: "item", value: action.arguments[1])])
        }
        try await perform(message.action, input: message.text, timeout: timeout)
    }
}
