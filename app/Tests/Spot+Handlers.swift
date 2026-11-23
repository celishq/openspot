import Foundation
@testable import OpenspotCore

@MainActor
extension Spot {
    func handle(_ handler: String, _ values: [String] = [], timeout: TimeInterval) async throws {
        let message = switch handler {
        case ScriptEntry.drop.name: ScriptEntry.drop.message(values)
        case ScriptEntry.drag.name: ScriptEntry.drag.message(values)
        case ScriptEntry.press.name: ScriptEntry.press.message(values)
        default: Message(handler, inputs: values.prefix(1).map { .init(key: "item", value: $0) })
        }
        try await perform(message.handler, input: message.text, timeout: timeout)
    }

    func handle(_ item: SpotItem, timeout: TimeInterval) async throws {
        let message = item.isToggle
            ? Message(item.run, inputs: [.init(key: "value", value: item.isOn ? "false" : "true")] + item.carried)
            : ScriptEntry.press.message([item.run], then: item.carried)
        try await perform(message.handler, input: message.text, timeout: timeout)
    }
}
