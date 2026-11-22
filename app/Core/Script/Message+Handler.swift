import Foundation

extension Message {
    static let showHandler = "show"
    static let everyHandler = "every"
    static let pressHandler = "press"
    private static let shows: Set<String> = [SpotEvent.panelOpen, SpotEvent.sheetOpen, SpotEvent.spotWant, ShowEvent.change.rawValue]

    func handled() -> Message {
        var message = self
        let arguments = action.arguments
        switch arguments.first {
        case SpotAction.show.arguments.first:
            let name = event?.rawValue ?? Self.showHandler
            if Self.shows.contains(name) {
                message.action = .press(Self.showHandler)
            } else if name.hasPrefix(SpotEvent.clockPrefix) {
                message.action = .press(Self.everyHandler)
            } else if name == SpotEvent.searchText {
                message.action = .press(Manifest.Triggers.search)
                message.inputs.append(.init(key: "text", value: event?.value ?? ""))
            } else {
                message.action = .press(name)
                if let value = event?.value { message.inputs.append(.init(key: "value", value: value)) }
            }
        case SpotAction.open.arguments.first where arguments.count > 1:
            message.action = .press(Self.pressHandler)
            message.inputs.append(.init(key: "item", value: arguments[1]))
        case SpotAction.drop(paths: []).arguments.first:
            message.action = .press(Manifest.Triggers.drop)
            message.inputs += arguments.dropFirst().map { .init(key: "file", value: $0) }
        case SpotAction.drag(runs: []).arguments.first:
            message.action = .press(SpotAction.drag(runs: []).arguments[0])
            message.inputs += arguments.dropFirst().map { .init(key: "item", value: $0) }
        default:
            return self
        }
        message.event = nil
        message.item = []
        message.search = nil
        message.searchForms = []
        return message
    }
}
