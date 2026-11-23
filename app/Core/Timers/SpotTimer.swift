import Foundation

public struct SpotTimer: Codable, Equatable, Sendable {
    public struct Input: Codable, Equatable, Sendable {
        public let name: String
        public let value: String
    }

    struct Call: Equatable, Sendable {
        var action: String
        var inputs: [Input]

        init(_ words: [String], of spot: Spot) throws {
            guard let name = words.first else { throw SpotError.fault("`openspot timer add` needs the action to call after the time, such as `wake`.") }
            let action = try spot.action(name)
            let given = try Manifest.InputCheck.fields(of: Array(words.dropFirst()), as: .input)
            _ = try action.check.checked(given)
            self.action = name
            inputs = given.map { Input(name: $0.key, value: $0.value) }
        }
    }

    static let call = "timer"
    static let someday = "someday"

    public let id: String
    public let spot: String
    public let at: Date?
    public var action: String?
    public var inputs: [Input]?

    init(id: String, spot: String, at: Date?, action: String? = nil, inputs: [Input]? = nil) {
        self.id = id
        self.spot = spot
        self.at = at
        self.action = action
        self.inputs = inputs
    }

    var block: String {
        var fields = [TextBlock.Field(key: "item", value: id)]
        if let title = action { fields.append(.init(key: "title", value: title)) }
        fields.append(.init(key: "at", value: at.map(Self.format) ?? Self.someday))
        fields += (inputs ?? []).map { .init(key: "input.\($0.name)", value: $0.value) }
        return TextBlock(fields: fields).text
    }

    static func format(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    static func time(of text: String) -> Date? {
        ISO8601DateFormatter().date(from: text)
    }
}
