import Foundation

public struct ItemPreview: Equatable, Sendable {
    public enum Look: Equatable, Sendable {
        case picture(String)
        case file(String)
        case text(String)
        case link(String, host: String?)
        case color(String)
        case blocks
    }

    static let kinds: [BlockKind] = [.text, .number, .series, .picture, .icon]
    public static let variants: Set<Style.Variant> = [.preview]
    static let pictureKinds: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "tiff", "webp", "bmp"]

    public let run: String
    public let look: Look
    public let title: String
    public let caption: String?
    let blocks: [TextBlock]
    public let tree: ViewTree

    static func holds(_ item: SpotItem) -> Bool {
        !item.preview.isEmpty || item.file != nil || item.fields.contains { ["url", "text", "whole"].contains($0.key) && !$0.value.isEmpty }
    }

    public init?(item: SpotItem) {
        guard Self.holds(item) else { return nil }
        if !item.preview.isEmpty, let own = Self.own(item.preview, of: item) {
            self = own
            return
        }
        let value = { (key: String) in item.fields.first { $0.key == key && !$0.value.isEmpty }?.value }
        let look: Look
        if let url = value("url") {
            look = .link(url, host: URL(string: url)?.host())
        } else if let swatch = item.swatch {
            look = .color(swatch)
        } else if let file = value("whole") ?? (value("text") == nil ? item.file : nil) {
            let isPicture = Self.pictureKinds.contains((file as NSString).pathExtension.lowercased())
            look = isPicture ? .picture(file) : .file(file)
        } else {
            look = .text(value("text") ?? "")
        }
        self.init(run: item.run, look: look, title: item.title, caption: item.subtitle, blocks: [])
    }

    private init(run: String, look: Look, title: String, caption: String?, blocks: [TextBlock]) {
        self.run = run
        self.look = look
        self.title = title
        self.caption = caption
        self.blocks = blocks
        tree = blocks.isEmpty ? .empty : Frame(grouped: Frame.grouping(blocks), kinds: Self.kinds).tree
    }

    public var isOwn: Bool {
        look == .blocks
    }

    static func own(_ text: String, of item: SpotItem) -> ItemPreview? {
        own(TextBlock.blocks(in: text), of: item)
    }

    static func own(_ blocks: [TextBlock], of item: SpotItem) -> ItemPreview? {
        guard !blocks.isEmpty, Frame(grouped: Frame.grouping(blocks), kinds: kinds).errors.isEmpty else { return nil }
        return ItemPreview(run: item.run, look: .blocks, title: item.title, caption: item.subtitle, blocks: blocks)
    }

    public static func == (one: ItemPreview, other: ItemPreview) -> Bool {
        one.run == other.run && one.look == other.look && one.title == other.title && one.caption == other.caption && one.blocks == other.blocks
    }
}
