import Foundation

public struct AttachmentPreview: Hashable, Sendable {
    static let excerptLimit = 280
    static let audioKinds: Set<String> = ["mp3", "m4a", "wav", "aif", "aiff", "flac", "aac", "ogg", "opus", "caf"]
    static let audioSymbol = "waveform"
    static let emptySymbol = "tray"
    static let failedSymbol = "exclamationmark.triangle"
    static let reading = "Reading…"

    public let face: AttachmentFace
    public let lines: Int
    public let label: String

    public init(_ value: AttachmentValue) {
        let text: String
        let caption: String
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
        label = text.isEmpty ? caption : text
        if let face = value.face {
            self.face = face
            lines = SpotTokens.previewLines
        } else {
            let picture = Self.picture(of: value)
            face = Self.face(text: text, caption: caption, symbol: value.kind.captionSymbol, picture: picture)
            lines = SpotTokens.attachmentValueLines(of: text, besidePicture: picture != nil)
        }
    }

    public init?(state chip: AttachmentChip) {
        switch chip.state {
        case .ready: return nil
        case .unread, .loading: self.init(caption: chip.appName.map { "Reading \($0)…" } ?? Self.reading, symbol: AttachmentChip.loadingSymbol)
        case .empty(let words): self.init(caption: words, symbol: Self.emptySymbol)
        case .failed(let line): self.init(caption: line, symbol: Self.failedSymbol)
        }
    }

    private init(caption: String, symbol: String) {
        label = caption
        face = Self.face(text: "", caption: caption, symbol: symbol, picture: nil)
        lines = 0
    }

    private static func picture(of value: AttachmentValue) -> String? {
        if let thumbnail = value.wholeCopy?.thumbnail { return thumbnail.path }
        guard case .files(let files) = value.payload, let path = files.paths.first, value.wholeCopy == nil else { return nil }
        return audioKinds.contains((path as NSString).pathExtension.lowercased()) ? audioSymbol : path
    }

    private static func face(text: String, caption: String, symbol: String, picture: String?) -> AttachmentFace {
        func block(_ kind: String, _ id: String, _ fields: [(String, String)]) -> TextBlock {
            TextBlock(fields: [.init(key: kind, value: id)] + fields.map { .init(key: $0.0, value: $0.1) }, firstLine: "\(kind)=\(id)")
        }
        var blocks = [block("frame", "", [("class", "flex-row items-start gap-2")])]
        if let picture { blocks.append(block("picture", "picture", [("icon", picture), ("class", "size-8 shrink-0 rounded-inner bg-tile")])) }
        blocks.append(block("box", "lines", [("class", "flex-col grow")]))
        blocks.append(block("text", "caption", [("title", caption), ("icon", symbol), ("class", "font-detail text-secondary truncate"), ("parent", "lines")]))
        if !text.isEmpty { blocks.append(block("text", "words", [("title", text), ("class", "line-clamp-2"), ("parent", "lines")])) }
        return AttachmentFace(blocks)
    }
}
