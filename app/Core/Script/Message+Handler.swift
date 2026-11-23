import Foundation

extension Message {
    static let showHandler = "show"
    static let everyHandler = "every"
    static let pressHandler = "press"
    private static let itemInput = "item"
    private static let routeInput = "route"
    private static let altInput = "alt"
    private static let eventInput = "event"
    private static let shows: Set<String> = [SpotEvent.panelOpen, SpotEvent.sheetOpen, SpotEvent.spotWant, ShowEvent.change.rawValue]

    func handled() -> Message {
        var message = self
        let arguments = words.arguments
        switch arguments.first {
        case SpotWords.show.arguments.first:
            let name = event?.rawValue ?? Self.showHandler
            if Self.shows.contains(name) {
                message.words = .press(Self.showHandler)
                if let event { message.inputs.append(.init(key: Self.eventInput, value: event.rawValue)) }
            } else if name.hasPrefix(SpotEvent.clockPrefix), let search, !search.isEmpty {
                message.words = .press(SpotEvent.sheetText)
                message.inputs.append(.init(key: "value", value: search))
                message.inputs += searchForms.map { .init(key: Self.altInput, value: $0) }
            } else if name.hasPrefix(SpotEvent.clockPrefix) {
                message.words = .press(Self.everyHandler)
            } else if name == SpotEvent.searchText {
                message.words = .press(Manifest.Triggers.search)
                message.inputs.append(.init(key: "text", value: event?.value ?? ""))
                message.inputs += searchForms.map { .init(key: Self.altInput, value: $0) }
            } else {
                message.words = .press(name)
                if let value = event?.value { message.inputs.append(.init(key: "value", value: value)) }
                if name == SpotEvent.sheetText { message.inputs += searchForms.map { .init(key: Self.altInput, value: $0) } }
            }
        case Self.pressHandler:
            message.words = .press(Self.pressHandler)
            if arguments.count > 1 { message.inputs.append(.init(key: Self.itemInput, value: arguments[1])) }
        case SpotWords.drop(paths: []).arguments.first:
            message.words = .press(Manifest.Triggers.drop)
            message.inputs += arguments.dropFirst().map { .init(key: "file", value: $0) }
        case SpotWords.drag(runs: []).arguments.first:
            message.words = .press(SpotWords.drag(runs: []).arguments[0])
            message.inputs += arguments.dropFirst().map { .init(key: "item", value: $0) }
        default:
            return message.carried()
        }
        message.event = nil
        message.search = nil
        message.searchForms = []
        return message.carried()
    }

    private func carried() -> Message {
        var message = self
        message.inputs += item.map { .init(key: "\(Self.itemInput).\($0.key)", value: $0.value) }
        message.inputs += route.map { [.init(key: Self.routeInput, value: $0)] } ?? []
        message.item = []
        message.route = nil
        return message
    }
}
