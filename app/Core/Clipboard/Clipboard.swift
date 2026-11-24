import Foundation
import ImageIO

struct Clipboard {
    static let heldLength = 1_000_000
    static let changed = "The clipboard changed since the panel opened. Copy it again, then hand it on."
    static let unwritten = "Openspot could not save the copied image. Copy it again."

    static var thumbnailPixels: Int { Int((SpotTokens.attachmentPicture * 2).rounded(.up)) }

    let board: any MacClipboard

    func value(count: Int, images: URL) -> AttachmentValue? {
        let value = read(count: count, images: images)
        return board.count() == count ? value : nil
    }

    func whole(of value: AttachmentValue, copy: ClipboardCopy) throws -> AttachmentValue? {
        guard board.count() == copy.count else { return nil }
        guard let image = copy.image else { return autoreleasepool { AttachmentValue(.text(board.text()), title: value.title, app: value.app, icon: value.icon) } }
        let folder = image.deletingLastPathComponent()
        for old in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [] where old.lastPathComponent != image.lastPathComponent {
            try? FileManager.default.removeItem(at: old)
        }
        guard let data = autoreleasepool(invoking: { board.image() }) else { throw SpotError.fault("Openspot cannot find the copied image. Copy it again.") }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: image, options: .atomic)
        return value
    }

    static func thumbnail(of data: Data) -> Data? {
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: thumbnailPixels] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        let png = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(png, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? png as Data : nil
    }

    private func read(count: Int, images: URL) -> AttachmentValue? {
        switch ClipboardContents(of: board) {
        case .none:
            return nil
        case .files(let urls):
            return AttachmentValue(files: FileKinds.Disk().read(urls.map(\.path)))
        case .image(let kind):
            let file = images.appendingPathComponent("Copied image \(count).\(kind)")
            let thumbnail = autoreleasepool { board.image().flatMap(Self.thumbnail) }
            return AttachmentValue(.files(FileKinds([file.path], kinds: [file.path: .file])), title: "Copied image", wholeCopy: ClipboardCopy(count: count, image: file, thumbnail: thumbnail))
        case .text:
            return autoreleasepool { Self.held(board.text(), count: count) }
        }
    }

    private static func held(_ text: String, count: Int) -> AttachmentValue? {
        guard text.contains(where: { !$0.isWhitespace }) else { return nil }
        guard text.utf8.count > heldLength else {
            let line = text.trimmingCharacters(in: .newlines)
            let isLink = (line.hasPrefix("https://") || line.hasPrefix("http://")) && !line.contains(where: \.isWhitespace)
            return isLink ? AttachmentValue(url: line) : AttachmentValue(text: text, title: "Copied text")
        }
        return AttachmentValue(.text(String(text.prefix(heldLength))), title: "Copied text", wholeCopy: ClipboardCopy(count: count, image: nil))
    }
}
