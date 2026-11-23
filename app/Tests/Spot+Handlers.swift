import Foundation
@testable import OpenspotCore

@MainActor
extension Spot {
    func handle(_ handler: String, _ values: [String] = [], timeout: TimeInterval) async throws {
        let message = switch handler {
        case Handler.drop.name: Handler.drop.message(values)
        case Handler.drag.name: Handler.drag.message(values)
        case Handler.press.name: Handler.press.message(values)
        default: Message(handler, inputs: values.prefix(1).map { .init(key: "item", value: $0) })
        }
        try await perform(message.handler, input: message.text, timeout: timeout)
    }

    func handle(_ item: SpotItem, timeout: TimeInterval) async throws {
        let message = item.isToggle
            ? Message(item.run, inputs: [.init(key: "value", value: item.isOn ? "false" : "true")] + item.carried)
            : Handler.press.message([item.run], then: item.carried)
        try await perform(message.handler, input: message.text, timeout: timeout)
    }
}
