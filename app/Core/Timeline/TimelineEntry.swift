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
    var session: SessionPlace?
    let bytes: Int64
    var peekFile: String?
    var forgotten: Date?

    var block: String {
        var fields = [TextBlock.Field(key: "item", value: id), .init(key: "title", value: title), .init(key: "spot", value: spot), .init(key: "at", value: Self.format(at)), .init(key: "kind", value: kind.rawValue)]
        fields += kind.fields(kind == .file ? files.map(\.path) : [value])
        if let textFile { fields.append(.init(key: "text.file", value: textFile)) }
        if let app { fields.append(.init(key: "app", value: app)) }
        if let icon { fields.append(.init(key: "icon", value: icon)) }
        if let detail { fields.append(.init(key: "detail", value: detail)) }
        if let key { fields.append(.init(key: "key", value: key)) }
        if let session {
            fields.append(.init(key: "session", value: id))
            if let page = session.flow.current { fields.append(.init(key: "session.spot", value: page.spot)) }
            if let route = session.flow.current?.route { fields.append(.init(key: "session.route", value: route)) }
            fields.append(.init(key: "session.steps", value: String(session.flow.pages.count)))
            if !session.query.isEmpty { fields.append(.init(key: "session.text", value: session.query)) }
        }
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
}
