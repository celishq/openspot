import Foundation

public struct SpotTimer: Codable, Equatable, Sendable {
    static let call = "due"
    static let event = "timer.due"
    static let someday = "someday"

    public let id: String
    public let spot: String
    public let at: Date?
    public let value: String?

    var block: String {
        var fields = [TextBlock.Field(key: "item", value: id)]
        if let value { fields.append(.init(key: "title", value: value)) }
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
