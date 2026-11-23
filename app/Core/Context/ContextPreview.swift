import Foundation

public struct ContextPreview: Equatable, Sendable {
    static let excerptLimit = 280

    public let text: String
    public let caption: String
    public let picture: Icon

    public init(_ value: ContextValue) {
        let first = value.values.first ?? ""
        switch value.kind {
        case .url:
            text = value.title ?? first
            caption = URL(string: first)?.host() ?? first
            picture = .symbol(Self.symbol(of: .url))
        case .text:
            text = String(first.prefix(Self.excerptLimit)).split(whereSeparator: \.isWhitespace).joined(separator: " ")
            caption = value.title ?? "Text"
            picture = .symbol(Self.symbol(of: .text))
        case .file:
            let names = value.values.map { ($0 as NSString).lastPathComponent }
            let folder = ((first as NSString).deletingLastPathComponent as NSString).lastPathComponent
            text = value.title ?? names.joined(separator: ", ")
            caption = names.count == 1 ? folder : "\(names.count) files in \(folder)"
            picture = .file(first)
        }
    }

    public static func symbol(of kind: ContextValue.Kind) -> String {
        switch kind {
        case .url: "link"
        case .text: "textformat"
        case .file: "doc"
        }
    }
}
