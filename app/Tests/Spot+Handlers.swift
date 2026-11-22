import Foundation
@testable import OpenspotCore

@MainActor
extension Spot {
    func handle(_ action: SpotAction, timeout: TimeInterval) async throws {
        let message = Message(action).handled()
        try await perform(message.action, input: message.text, timeout: timeout)
    }
}
