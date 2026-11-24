import Foundation

public struct AttachmentPreview: Hashable, Sendable {
    public enum Picture: Hashable, Sendable {
        case thumbnail(String)
        case icon(String)
        case data(Data)
        case symbol(String)
    }

    static let excerptLimit = 280
    static let thumbnailKinds: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "heif", "tif", "tiff", "webp", "bmp", "mov", "mp4", "m4v", "avi", "mkv", "webm", "pdf"]
    static let audioKinds: Set<String> = ["mp3", "m4a", "wav", "aif", "aiff", "flac", "aac", "ogg", "opus", "caf"]
    static let audioSymbol = "waveform"

    public static let loading = AttachmentPreview(text: "", caption: "Reading…", symbol: AttachmentChip.loadingSymbol)
    static let emptySymbol = "tray"
    static let failedSymbol = "exclamationmark.triangle"

    public let text: String
    public let caption: String
    public let symbol: String
    public let lines: Int
    public let picture: Picture?

    public init(_ value: AttachmentValue) {
        symbol = value.kind.captionSymbol
        switch value.payload {
        case .url(let url):
            text = value.title ?? url
            caption = URL(string: url)?.host() ?? url
        case .text(let words):
            text = String(words.prefix(Self.excerptLimit)).split(whereSeparator: \.isWhitespace).joined(separator: " ")
            caption = value.title ?? "Text"
        case .files(let files):
            let names = files.paths.map { ($0 as NSString).lastPathComponent }
            let folder = (((files.paths.first ?? "") as NSString).deletingLastPathComponent as NSString).lastPathComponent
            text = value.title ?? names.joined(separator: ", ")
            caption = names.count == 1 ? folder : "\(names.count) files in \(folder)"
        }
        picture = Self.picture(of: value)
        lines = SpotTokens.attachmentValueLines(of: text, besidePicture: picture != nil)
    }

    private static func picture(of value: AttachmentValue) -> Picture? {
        if let thumbnail = value.copy?.thumbnail { return .data(thumbnail) }
        guard case .files(let files) = value.payload, let path = files.paths.first, value.copy == nil else { return nil }
        let kind = (path as NSString).pathExtension.lowercased()
        if thumbnailKinds.contains(kind) { return .thumbnail(path) }
        return audioKinds.contains(kind) ? .symbol(audioSymbol) : .icon(path)
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
        picture = nil
        lines = SpotTokens.attachmentValueLines(of: text)
    }
}
