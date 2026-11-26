import Foundation

public struct ItemPreview: Equatable, Sendable {
    static let kinds: [BlockKind] = [.text, .number, .series, .picture, .icon]
    public static let variants: Set<Style.Variant> = [.preview]
    static let pictureKinds: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "tiff", "webp", "bmp"]

    public let run: String
    public let isOwn: Bool
    let blocks: [TextBlock]
    public let tree: ViewTree

    static func holds(_ item: SpotItem) -> Bool {
        item.file != nil || item.fields.contains { ["url", "text", "whole"].contains($0.key) && !$0.value.isEmpty }
    }

    public init?(item: SpotItem) {
        guard Self.holds(item) else { return nil }
        let value = { (key: String) in item.fields.first { $0.key == key && !$0.value.isEmpty }?.value }
        var blocks = [Self.block("frame", "", [("class", "flex-col gap-part")])]
        if let url = value("url") {
            blocks.append(Self.block("text", "link", [("title", url), ("class", "font-title")]))
            if let host = URL(string: url)?.host() { blocks.append(Self.block("text", "host", [("title", host), ("class", "text-secondary")])) }
        } else if let file = value("whole") ?? (value("text") == nil ? item.file : nil) {
            let isPicture = value("kind") == "picture" || Self.pictureKinds.contains((file as NSString).pathExtension.lowercased())
            blocks.append(Self.block("picture", "picture", [("icon", file), ("class", isPicture ? "grow rounded-inner" : "size-64 self-center")]))
            if !isPicture { blocks.append(Self.block("text", "name", [("title", (file as NSString).lastPathComponent), ("class", "text-center")])) }
        } else if let text = value("text") {
            blocks.append(Self.block("text", "words", [("title", text)]))
        } else {
            return nil
        }
        if let caption = item.subtitle { blocks.append(Self.block("text", "caption", [("title", caption), ("class", "font-detail text-secondary")])) }
        self.init(run: item.run, blocks: blocks, isOwn: false)
    }

    init(run: String, blocks: [TextBlock], isOwn: Bool) {
        self.run = run
        self.blocks = blocks
        self.isOwn = isOwn
        tree = Frame(grouped: Frame.grouping(blocks), kinds: Self.kinds).tree
    }

    static func own(_ text: String, of run: String) -> ItemPreview? {
        let blocks = TextBlock.blocks(in: text)
        guard !blocks.isEmpty, Frame(grouped: Frame.grouping(blocks), kinds: kinds).errors.isEmpty else { return nil }
        return ItemPreview(run: run, blocks: blocks, isOwn: true)
    }

    public static func == (one: ItemPreview, other: ItemPreview) -> Bool {
        one.run == other.run && one.isOwn == other.isOwn && one.blocks == other.blocks
    }

    private static func block(_ kind: String, _ id: String, _ fields: [(String, String)]) -> TextBlock {
        TextBlock(fields: [.init(key: kind, value: id)] + fields.map { .init(key: $0.0, value: $0.1) }, firstLine: "\(kind)=\(id)")
    }
}
