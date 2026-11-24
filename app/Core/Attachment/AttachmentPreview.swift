import Foundation

public struct AttachmentPreview: Hashable, Sendable {
    static let excerptLimit = 280

    public static let loading = AttachmentPreview(text: "", caption: "Reading…", symbol: AttachmentChip.loadingSymbol)
    static let emptySymbol = "tray"
    static let failedSymbol = "exclamationmark.triangle"

    public let text: String
    public let caption: String
    public let symbol: String

    public init(_ value: AttachmentValue) {
        let first = value.values.first ?? ""
        symbol = value.kind.captionSymbol
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

    public init?(state chip: AttachmentChip) {
        switch chip.state {
        case .ready: return nil
        case .unread, .loading: self.init(text: "", caption: chip.appName.map { "Reading \($0)…" } ?? Self.loading.caption, symbol: AttachmentChip.loadingSymbol)
        case .empty(let words): self.init(text: "", caption: words, symbol: Self.emptySymbol)
        case .failed(let line): self.init(text: "", caption: line, symbol: Self.failedSymbol)
        }
    }

    private init(text: String, caption: String, symbol: String) {
        self.text = text
        self.caption = caption
        self.symbol = symbol
    }
}
