import Foundation

public struct TranslatedText: Equatable, Sendable {
    public enum Status: String, CaseIterable, Sendable {
        case failed
        case unknown
        case missing
        case unsupported
    }

    public let text: String?
    public let status: Status?
    public let from: String?
    public let to: String?

    public init(text: String? = nil, status: Status? = nil, from: String? = nil, to: String? = nil) {
        self.text = text
        self.status = status
        self.from = from
        self.to = to
    }

    public init(block: TextBlock) {
        self.init(text: block.value("text"), status: block.value("status").flatMap(Status.init(rawValue:)), from: block.value("from"), to: block.value("to"))
    }

    public var block: TextBlock {
        let pairs = [("text", text), ("status", status?.rawValue), ("from", from), ("to", to)]
        return TextBlock(fields: pairs.compactMap { key, value in value.map { .init(key: key, value: $0) } })
    }

    static func languages(_ codes: [String], preferred: [String] = Locale.preferredLanguages, locale: Locale = .current) -> String {
        let named = codes.map { (code: $0, name: locale.localizedString(forIdentifier: $0) ?? $0) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        let summary = TextBlock(fields: TranslationTargets(preferred: preferred, source: "").codes.map { .init(key: "preferred", value: $0) })
        let blocks = named.map { TextBlock(fields: [.init(key: "language", value: $0.code), .init(key: "name", value: $0.name)]) }
        return ([summary] + blocks).map(\.text).joined(separator: "\n")
    }
}
