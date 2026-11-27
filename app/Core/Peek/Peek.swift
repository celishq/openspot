import Foundation

public struct Peek: Equatable, Sendable {
    public enum Look: Equatable, Sendable {
        case picture(String)
        case file(String)
        case text(String)
        case link(String, host: String?)
        case color(String)
        case video(String)
        case blocks(ViewTree)
    }

    static let kinds: [BlockKind] = [.text, .number, .series, .picture, .icon]
    static let words = Set((kinds + [.box]).map(\.word))
    public static let variants: Set<Style.Variant> = [.peek]
    static let textLimit = 2000
    static let pictureKinds: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "tiff", "webp", "bmp"]

    public let run: String
    public let look: Look
    public let title: String
    public let caption: String?

    public init?(item: SpotItem, kept: [TextBlock] = []) {
        let value = { (key: String) in item.fields.first { $0.key == key && !$0.value.isEmpty }?.value }
        let look: Look
        if let tree = Self.tree(of: item.peek.isEmpty ? kept : item.peek) {
            look = .blocks(tree)
        } else if let url = value("url") {
            look = .link(url, host: URL(string: url)?.host())
        } else if let color = item.color {
            look = .color(color)
        } else if let file = value("text") == nil ? item.file : nil {
            let kind = (file as NSString).pathExtension.lowercased()
            look = Self.pictureKinds.contains(kind) ? .picture(file) : Icon.videos.contains(kind) ? .video(file) : .file(file)
        } else if let text = value("text") {
            look = .text(String(text.prefix(Self.textLimit)))
        } else {
            return nil
        }
        run = item.run
        self.look = look
        title = item.title
        caption = item.subtitle
    }

    var isRead: Bool {
        switch look {
        case .picture, .file, .video: true
        default: false
        }
    }

    static func tree(of blocks: [TextBlock]) -> ViewTree? {
        guard let peek = blocks.first, let id = peek.value(BlockKind.peek.word) else { return nil }
        let root = RootKey.block([.init(key: ViewNode.classKey, value: peek.value(ViewNode.classKey) ?? "gap-part")])
        let parts = blocks.dropFirst().filter { Self.words.contains($0.fields.first?.key ?? "") }.map { block in
            block.value(ViewNode.parentKey) == id ? TextBlock(fields: block.fields.filter { $0.key != ViewNode.parentKey }, firstLine: block.firstLine) : block
        }
        guard !parts.isEmpty else { return nil }
        let frame = Frame(grouped: [root] + parts, kinds: kinds)
        return frame.errors.isEmpty && frame.tree.faults.isEmpty ? frame.tree : nil
    }
}
