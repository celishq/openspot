import Foundation

public struct ValueType: Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case text, number, bool, date, duration, url, file, secret, choice
    }

    public static let names = Kind.allCases.map(\.rawValue).joined(separator: ", ")

    public let kind: Kind
    public let isList: Bool

    public init(_ kind: Kind, isList: Bool = false) {
        self.kind = kind
        self.isList = isList
    }

    public init?(name: String) {
        let isList = name.hasPrefix("[") && name.hasSuffix("]") && name.count > 2
        guard let kind = Kind(rawValue: isList ? String(name.dropFirst().dropLast()) : name) else { return nil }
        self.init(kind, isList: isList)
    }

    public var name: String {
        isList ? "[\(kind.rawValue)]" : kind.rawValue
    }

    public func accepts(_ value: String, options: [String] = []) -> Bool {
        switch kind {
        case .text, .secret: true
        case .number: Double(value)?.isFinite == true
        case .bool: value == "true" || value == "false"
        case .date: Self.date(value) != nil
        case .duration: Double(value).map { $0.isFinite && $0 >= 0 } == true
        case .url: URL(string: value)?.scheme?.isEmpty == false
        case .file: value.hasPrefix("/")
        case .choice: options.contains(value)
        }
    }

    public var article: String {
        switch kind {
        case .text: "a text"
        case .number: "a number"
        case .bool: "true or false"
        case .date: "a date, such as 2026-11-22 or 2026-11-22T09:00:00Z"
        case .duration: "a number of seconds"
        case .url: "a URL, such as https://example.com"
        case .file: "a path that starts with /"
        case .secret: "a secret"
        case .choice: "one of its options"
        }
    }

    private static func date(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: text)
    }
}
