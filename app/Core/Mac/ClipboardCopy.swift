import Foundation

public struct ClipboardCopy: Equatable, Sendable {
    static let heldLength = 1_000_000
    static let changed = "The clipboard changed since the panel opened. Copy it again, then hand it on."
    static let unwritten = "Openspot could not save the copied image. Copy it again."

    let count: Int
    let image: URL?

    static func value(of board: any MacClipboard, count: Int, images: URL) -> AttachmentValue? {
        let value = read(board, count: count, images: images)
        return board.count() == count ? value : nil
    }

    private static func read(_ board: any MacClipboard, count: Int, images: URL) -> AttachmentValue? {
        switch board.contents() {
        case .none:
            return nil
        case .files(let urls):
            return AttachmentValue(files: FileKinds.Disk().read(urls.map(\.path)))
        case .image(let kind):
            let file = images.appendingPathComponent("Copied image \(count).\(kind)")
            return AttachmentValue(.files(FileKinds([file.path], kinds: [file.path: .file])), title: "Copied image", copy: ClipboardCopy(count: count, image: file))
        case .text:
            return autoreleasepool { held(board.text(), count: count) }
        }
    }

    private static func held(_ text: String, count: Int) -> AttachmentValue? {
        guard text.contains(where: { !$0.isWhitespace }) else { return nil }
        guard text.utf8.count > heldLength else {
            let line = text.trimmingCharacters(in: .newlines)
            let isLink = (line.hasPrefix("https://") || line.hasPrefix("http://")) && !line.contains(where: \.isWhitespace)
            return isLink ? AttachmentValue(url: line) : AttachmentValue(text: text, title: "Copied text")
        }
        return AttachmentValue(.text(String(text.prefix(heldLength))), title: "Copied text", copy: ClipboardCopy(count: count, image: nil))
    }

    func whole(of value: AttachmentValue, from board: any MacClipboard) throws -> AttachmentValue? {
        guard board.count() == count else { return nil }
        guard let image else { return autoreleasepool { AttachmentValue(.text(board.text()), title: value.title, app: value.app, icon: value.icon) } }
        let folder = image.deletingLastPathComponent()
        for old in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [] where old.lastPathComponent != image.lastPathComponent {
            try? FileManager.default.removeItem(at: old)
        }
        try board.writeImage(to: image)
        return value
    }
}
