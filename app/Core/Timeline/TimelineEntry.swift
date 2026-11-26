import Foundation

public struct TimelineEntry: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case text, url, file, picture
    }

    public struct File: Codable, Equatable, Sendable {
        public let path: String
        public let original: String
        public let isKept: Bool
    }

    public let id: String
    public let spot: String
    public let at: Date
    public let kind: Kind
    public let value: String
    public let textFile: String?
    public let files: [File]
    public let title: String
    public let app: String?
    public let icon: String?
    public let key: String?
    public let bytes: Int64
    public var forgotten: Date?

    var block: String {
        var fields = [TextBlock.Field(key: "item", value: id), .init(key: "title", value: title), .init(key: "spot", value: spot), .init(key: "at", value: Self.format(at))]
        switch kind {
        case .text, .url: fields.append(.init(key: kind.rawValue, value: value))
        case .file, .picture: fields += files.map { .init(key: kind.rawValue, value: $0.isKept ? $0.path : $0.original) }
        }
        if let textFile { fields.append(.init(key: "text.file", value: textFile)) }
        if let app { fields.append(.init(key: "app", value: app)) }
        if let icon { fields.append(.init(key: "icon", value: icon)) }
        if let key { fields.append(.init(key: "key", value: key)) }
        return TextBlock(fields: fields).text
    }

    static func format(_ date: Date) -> String {
        let format = ISO8601DateFormatter()
        format.timeZone = .current
        return format.string(from: date)
    }

    var words: String {
        [title, value, app ?? "", files.map { ($0.original as NSString).lastPathComponent }.joined(separator: " ")].joined(separator: " ")
    }
}
