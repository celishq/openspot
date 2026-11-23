import Foundation

public struct ContextPreview: Hashable, Sendable {
    static let excerptLimit = 280

    public static let loading = ContextPreview(text: "", caption: "Loading", symbol: "ellipsis")

    public let text: String
    public let caption: String
    public let symbol: String

    public init(_ value: ContextValue) {
        let first = value.values.first ?? ""
        symbol = Self.symbol(of: value.kind)
        switch value.kind {
        case .url:
            text = value.title ?? first
            caption = URL(string: first)?.host() ?? first
        case .text:
            text = String(first.prefix(Self.excerptLimit)).split(whereSeparator: \.isWhitespace).joined(separator: " ")
            caption = value.title ?? "Text"
        case .file:
            let names = value.values.map { ($0 as NSString).lastPathComponent }
            let folder = ((first as NSString).deletingLastPathComponent as NSString).lastPathComponent
            text = value.title ?? names.joined(separator: ", ")
            caption = names.count == 1 ? folder : "\(names.count) files in \(folder)"
        }
    }

    private init(text: String, caption: String, symbol: String) {
        self.text = text
        self.caption = caption
        self.symbol = symbol
    }

    public static func symbol(of kind: ContextValue.Kind) -> String {
        switch kind {
        case .url: "globe"
        case .text: "textformat"
        case .file: "doc"
        }
    }
}
