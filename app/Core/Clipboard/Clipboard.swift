import Foundation
import ImageIO

struct Clipboard {
    static let heldLength = 1_000_000
    static let changed = "The clipboard changed since the panel opened. Copy it again, then hand it on."

    static var thumbnailPixels: Int { Int((SpotTokens.detailsPicture * 2).rounded(.up)) }

    let board: any MacClipboard

    func value(count: Int, images: URL) -> AttachmentValue? {
        let value = read(count: count, images: images)
        return board.count() == count ? value : nil
    }

    func whole(of value: AttachmentValue, copy: ClipboardCopy) throws -> AttachmentValue? {
        guard board.count() == copy.count else { return nil }
        guard let image = copy.image else { return autoreleasepool { AttachmentValue(.text(board.text()), title: value.title, app: value.app, icon: value.icon) } }
        let folder = image.deletingLastPathComponent()
        for old in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [] where old.lastPathComponent != image.lastPathComponent && old != copy.thumbnail {
            try? FileManager.default.removeItem(at: old)
        }
        guard let data = autoreleasepool(invoking: { board.image() }) else { throw SpotError.fault("Openspot cannot find the copied image. Copy it again.") }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: image, options: .atomic)
        } catch {
            throw SpotError.fault("Openspot could not save the copied image. Copy it again.")
        }
        return value
    }

    private static func save(_ thumbnail: Data, as file: URL) -> URL? {
        let folder = file.deletingLastPathComponent()
        for old in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [] where old.lastPathComponent.hasSuffix(" preview.png") {
            try? FileManager.default.removeItem(at: old)
        }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try thumbnail.write(to: file, options: .atomic)
            return file
        } catch {
            return nil
        }
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
            let thumbnail = autoreleasepool { board.image().flatMap(Self.thumbnail) }.flatMap { Self.save($0, as: images.appendingPathComponent("Copied image \(count) preview.png")) }
            return AttachmentValue(.files(FileKinds([file.path], kinds: [file.path: .file])), title: "Copied image", wholeCopy: ClipboardCopy(count: count, image: file, thumbnail: thumbnail))
        case .text:
            return autoreleasepool { Self.held(board.text(), count: count) }
        }
    }

    static func link(in text: String) -> String? {
        let line = text.trimmingCharacters(in: .newlines)
        return (line.hasPrefix("https://") || line.hasPrefix("http://")) && !line.contains(where: \.isWhitespace) ? line : nil
    }

    private static func held(_ text: String, count: Int) -> AttachmentValue? {
        guard text.contains(where: { !$0.isWhitespace }) else { return nil }
        guard text.utf8.count > heldLength else {
            return link(in: text).map { AttachmentValue(url: $0) } ?? AttachmentValue(text: text, title: "Copied text")
        }
        return AttachmentValue(.text(String(text.prefix(heldLength))), title: "Copied text", wholeCopy: ClipboardCopy(count: count, image: nil))
    }
}
