import Foundation

struct TimelineEntry: Codable, Equatable, Sendable {
    struct File: Codable, Equatable, Sendable {
        let path: String
        let original: String
        let isKept: Bool
    }

    let id: String
    let spot: String
    let at: Date
    let kind: AttachmentValue.Kind
    let value: String
    let textFile: String?
    let files: [File]
    let title: String
    let app: String?
    let icon: String?
    let detail: String?
    let key: String?
    let bytes: Int64
    var forgotten: Date?

    var block: String {
        var fields = [TextBlock.Field(key: "item", value: id), .init(key: "title", value: title), .init(key: "spot", value: spot), .init(key: "at", value: Self.format(at)), .init(key: "kind", value: kind.rawValue)]
        fields += kind.fields(kind == .file ? files.map(\.path) : [value])
        if let textFile { fields.append(.init(key: "text.file", value: textFile)) }
        if let app { fields.append(.init(key: "app", value: app)) }
        if let icon { fields.append(.init(key: "icon", value: icon)) }
        if let detail { fields.append(.init(key: "detail", value: detail)) }
        if let key { fields.append(.init(key: "key", value: key)) }
        return TextBlock(fields: fields).text
    }

    nonisolated(unsafe) private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .autoupdatingCurrent
        return formatter
    }()

    static func format(_ date: Date) -> String {
        formatter.string(from: date)
    }

    var words: String {
        [title, value, app ?? "", files.map { ($0.original as NSString).lastPathComponent }.joined(separator: " ")].joined(separator: " ")
    }
}
