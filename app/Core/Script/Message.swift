import Foundation

public struct Message: Equatable, Sendable {
    static let argumentLimit = 65_536

    public var action: SpotAction
    public var event: ShowEvent?
    public var route: String?
    public var item: [TextBlock.Field]
    public var inputs: [TextBlock.Field]
    public var search: String?
    public var searchForms: [String]
    public var given: String?
    public var settings: [TextBlock.Field]
    public var late: Int?

    public init(_ action: SpotAction, event: ShowEvent? = nil, route: String? = nil, item: [TextBlock.Field] = [], inputs: [TextBlock.Field] = [], search: String? = nil, searchForms: [String] = [], given: String? = nil, settings: [TextBlock.Field] = [], late: Int? = nil) {
        self.action = action
        self.event = event
        self.route = route
        self.item = item
        self.inputs = inputs
        self.search = search
        self.searchForms = searchForms
        self.given = given
        self.settings = settings
        self.late = late
    }

    var keys: [TextBlock.Field] {
        var keys: [TextBlock.Field] = []
        if let event {
            keys.append(.init(key: "event", value: event.rawValue))
            if let value = event.value { keys.append(.init(key: "event.value", value: value)) }
        }
        if let route { keys.append(.init(key: "route", value: route)) }
        keys += item.map { .init(key: "item.\($0.key)", value: $0.value) }
        keys += inputs.map { .init(key: "input.\($0.key)", value: $0.value) }
        if let late { keys.append(.init(key: "timer.late", value: String(late))) }
        if let search { keys.append(.init(key: "search", value: search)) }
        keys += searchForms.map { .init(key: "search.alt", value: $0) }
        return keys
    }

    public var text: String? {
        let settings = settings.map { TextBlock.Field(key: "setting.\($0.key)", value: $0.value) }
        let text = TextBlock(fields: keys).text + (given ?? "") + TextBlock(fields: settings).text
        return text.isEmpty && given == nil ? nil : text
    }

    public func block(id: Int) -> String {
        let call = [TextBlock.Field(key: "call", value: String(id))] + action.arguments.map { TextBlock.Field(key: "arg", value: $0) }
        let fields = text.map { TextBlock.blocks(in: $0).flatMap(\.fields) } ?? []
        return TextBlock(fields: call + fields).text + "\n"
    }

    var sent: (arguments: [String], input: String?) {
        let arguments = action.arguments
        let input = text
        let long = arguments.dropFirst().filter { $0.utf8.count > Self.argumentLimit }
        guard !long.isEmpty else { return (arguments, input) }
        let held = input.flatMap { TextBlock.blocks(in: $0).first }?.fields.map(\.value) ?? []
        let missing = long.filter { !held.contains($0) }.map { TextBlock.Field(key: "input.value", value: $0) }
        return (arguments.prefix(1) + arguments.dropFirst().filter { !long.contains($0) }, (input ?? "") + TextBlock(fields: missing).text)
    }
}
