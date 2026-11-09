import AppKit
import OpenspotCore

/// A picture book mapped from disk: each glyph's bitmap is read in place, with no copy, so its pages stay the file's and
/// the system can drop them. A helper process draws the book, so the glyph caches of Core Text end with that process.
final class SpotGlyphBook: @unchecked Sendable {
    /// The longest wait for a helper to draw a book.
    private static let timeLimit: DispatchTimeInterval = .seconds(60)
    /// How many books the folder keeps, the most recently used first.
    private static let shelf = 2

    let layout: GlyphBook
    private let bytes: NSData

    private init(layout: GlyphBook, bytes: NSData) {
        self.layout = layout
        self.bytes = bytes
    }

    /// The bitmap of a glyph, read from its tile, or nil for a glyph that the book does not hold.
    func image(of glyph: String) -> CGImage? {
        guard let offset = layout.offset(of: glyph), let space = CGColorSpace(name: CGColorSpace.displayP3) else { return nil }
        let info = Unmanaged.passRetained(self).toOpaque()
        guard let provider = CGDataProvider(dataInfo: info, data: bytes.bytes + offset, size: layout.tileBytes, releaseData: { info, _, _ in
            info.map { Unmanaged<SpotGlyphBook>.fromOpaque($0).release() }
        }) else {
            Unmanaged<SpotGlyphBook>.fromOpaque(info).release()
            return nil
        }
        return CGImage(
            width: layout.pixels, height: layout.pixels, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: layout.pixels * 4,
            space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
            decode: nil, shouldInterpolate: true, intent: .defaultIntent
        )
    }

    /// Maps the book from its file, or nil when the file is missing or holds other than the book's bytes.
    static func open(_ layout: GlyphBook, at file: URL) -> SpotGlyphBook? {
        guard let bytes = try? NSData(contentsOf: file, options: .alwaysMapped), bytes.length == layout.fileBytes else { return nil }
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
        return SpotGlyphBook(layout: layout, bytes: bytes)
    }

    /// Has a helper process draw the book into its file, waits for it, and maps it. A helper that fails leaves no book.
    static func draw(_ layout: GlyphBook, at file: URL) -> SpotGlyphBook? {
        let folder = file.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let part = folder.appendingPathComponent(UUID().uuidString + ".part")
        defer { try? FileManager.default.removeItem(at: part) }
        let process = Process()
        let input = Pipe()
        let ended = DispatchSemaphore(value: 0)
        process.executableURL = Bundle.main.executableURL
        process.arguments = ["helper", "glyphs", "\(layout.side)", "\(layout.fontSize)", part.path]
        process.standardInput = input
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { _ in ended.signal() }
        do {
            try process.run()
        } catch {
            return nil
        }
        try? input.fileHandleForWriting.write(contentsOf: Data(layout.glyphs.joined(separator: "\n").utf8))
        try? input.fileHandleForWriting.close()
        if ended.wait(timeout: .now() + timeLimit) == .timedOut {
            process.terminate()
            ended.wait()
        }
        guard process.terminationStatus == 0, (try? FileManager.default.moveItem(at: part, to: file)) != nil else { return nil }
        prune(folder)
        return open(layout, at: file)
    }

    /// Draws each glyph of the book into its tile, and writes the tiles in order to a file. The helper process runs it.
    static func write(_ layout: GlyphBook, to path: String) -> Bool {
        guard FileManager.default.createFile(atPath: path, contents: nil), let file = FileHandle(forWritingAtPath: path) else { return false }
        defer { try? file.close() }
        let tile = UnsafeMutableRawPointer.allocate(byteCount: layout.tileBytes, alignment: 16)
        defer { tile.deallocate() }
        for glyph in layout.glyphs {
            let written: Bool = autoreleasepool {
                tile.initializeMemory(as: UInt8.self, repeating: 0, count: layout.tileBytes)
                guard let context = SpotGlyphPicture.context(side: CGFloat(layout.side), data: tile) else { return false }
                SpotGlyphPicture.render(glyph, side: CGFloat(layout.side), fontSize: CGFloat(layout.fontSize), in: context)
                return (try? file.write(contentsOf: Data(bytesNoCopy: tile, count: layout.tileBytes, deallocator: .none))) != nil
            }
            guard written else { return false }
        }
        return true
    }

    /// Removes each book past the shelf, the least recently used first, and each part that a stopped helper left.
    private static func prune(_ folder: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        let books = files.filter { $0.lastPathComponent.hasSuffix(GlyphBook.fileExtension) }.sorted { date(of: $0) > date(of: $1) }
        for file in books.dropFirst(shelf) + files.filter({ $0.pathExtension == "part" }) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static func date(of file: URL) -> Date {
        (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}
