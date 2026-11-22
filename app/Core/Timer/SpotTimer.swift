import Foundation

public struct SpotTimer: Codable, Equatable, Sendable {
    public struct Input: Codable, Equatable, Sendable {
        public let name: String
        public let value: String
    }

    struct Call: Equatable, Sendable {
        var value: String?
        var action: String?
        var inputs: [Input]?

        init(_ words: [String], of spot: Spot) throws {
            guard !spot.typedActions.isEmpty else {
                guard words.count <= 1 else { throw SpotError.fault("`openspot timer add` takes one value after the time, and got \(words.count).") }
                value = words.first
                return
            }
            guard let name = words.first else { throw SpotError.fault("`openspot timer add` needs the action to call after the time, such as `wake`.") }
            guard let action = spot.typedActions.first(where: { $0.id == name }) else {
                throw SpotError.fault("\(spot.name) has no action \(name). Name one of its [actions]: \(spot.typedActions.map(\.id).joined(separator: ", ")).")
            }
            var given: [TextBlock.Field] = []
            for word in words.dropFirst() {
                guard let equals = word.firstIndex(of: "="), equals != word.startIndex else {
                    throw SpotError.fault("\(word) is not an input. Write <name>=<value>, such as url=https://example.com.")
                }
                let key = String(word[..<equals])
                guard action.inputs.contains(where: { $0.name == key }) else {
                    throw SpotError.fault("\(name) has no input \(key). Its inputs are: \(action.inputs.map(\.name).joined(separator: ", ")).")
                }
                given.append(.init(key: key, value: String(word[word.index(after: equals)...])))
            }
            _ = try action.inputs(given)
            self.action = name
            inputs = given.map { Input(name: $0.key, value: $0.value) }
        }
    }

    static let call = "due"
    static let event = "timer.due"
    static let someday = "someday"

    public let id: String
    public let spot: String
    public let at: Date?
    public let value: String?
    public var action: String?
    public var inputs: [Input]?

    init(id: String, spot: String, at: Date?, value: String?, action: String? = nil, inputs: [Input]? = nil) {
        self.id = id
        self.spot = spot
        self.at = at
        self.value = value
        self.action = action
        self.inputs = inputs
    }

    var block: String {
        var fields = [TextBlock.Field(key: "item", value: id)]
        if let title = value ?? action { fields.append(.init(key: "title", value: title)) }
        fields.append(.init(key: "at", value: at.map(Self.format) ?? Self.someday))
        return TextBlock(fields: fields).text
    }

    static func format(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    static func time(of text: String) -> Date? {
        ISO8601DateFormatter().date(from: text)
    }
}
