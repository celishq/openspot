import AppKit
import OpenspotCore
import Synchronization

/// The picture books in use, one for each size, and their files in the cache folder. A big list takes the book of its
/// colour glyphs: a book drawn before is mapped, and else a helper process draws it. The folder keeps the books used last.
enum SpotGlyphShelf {
    /// The fewest colour glyphs that a list needs for a book. A list of fewer draws them in the app.
    private static let bookFloor = 100
    /// The longest wait for a helper to draw a book.
    private static let timeLimit: DispatchTimeInterval = .seconds(60)
    /// How many books the folder keeps, the most recently used first.
    private static let shelf = 3
    private static let binding = DispatchQueue(label: "openspot.glyph-books", qos: .utility)
    /// The book in use for each size, by its side and font size.
    private static let books = Mutex<[String: SpotGlyphBook]>([:])
    /// The number of the newest bind for each size, so that a bind that a newer one follows does nothing.
    private static let binds = Mutex<[String: Int]>([:])
    /// The books that failed in this session, by their file names, so that a list does not run a helper on each read.
    private static let failures = Mutex<Set<String>>([])
    /// What the pictures of a book depend on besides its glyphs and sizes: the system and the app that draws them.
    private static let maker = ProcessInfo.processInfo.operatingSystemVersionString + " "
        + ((Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "") + " "
        + ((Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "")

    /// The book in use at this size, or nil when a list of that size has none yet.
    static func book(side: CGFloat, fontSize: CGFloat) -> SpotGlyphBook? {
        books.withLock { $0[sizeKey(side: side, fontSize: fontSize)] }
    }

    /// Takes the book of a whole list's colour glyphs at this size: maps it when a helper drew it before, else has a helper
    /// draw it. A list with few colour glyphs gets none.
    static func bind(_ glyphs: [String], side: CGFloat, fontSize: CGFloat) {
        let size = sizeKey(side: side, fontSize: fontSize)
        let number = binds.withLock { binds in
            binds[size, default: 0] += 1
            return binds[size] ?? 0
        }
        binding.async {
            guard binds.withLock({ $0[size] }) == number else { return }
            let layout = GlyphBook(glyphs: glyphs.filter(SpotGlyphPicture.isColour), side: Double(side), fontSize: Double(fontSize))
            guard layout.glyphs.count >= bookFloor, books.withLock({ $0[size]?.layout }) != layout else { return }
            let name = layout.name(system: maker)
            guard !failures.withLock({ $0.contains(name) }) else { return }
            let file = GlyphBook.folder().appendingPathComponent(name)
            guard let book = SpotGlyphBook.open(layout, at: file) ?? draw(layout, at: file) else {
                failures.withLock { _ = $0.insert(name) }
                return
            }
            books.withLock { $0[size] = book }
        }
    }

    /// Has a helper process draw the book into its file, waits for it, and maps it. A helper that fails leaves no book.
    private static func draw(_ layout: GlyphBook, at file: URL) -> SpotGlyphBook? {
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
        let text = Data(layout.glyphs.joined(separator: "\n").utf8)
        let writing = input.fileHandleForWriting
        DispatchQueue.global(qos: .utility).async {
            try? writing.write(contentsOf: text)
            try? writing.close()
        }
        if ended.wait(timeout: .now() + timeLimit) == .timedOut {
            process.terminate()
            ended.wait()
        }
        guard process.terminationStatus == 0 else { return nil }
        try? FileManager.default.removeItem(at: file)
        guard (try? FileManager.default.moveItem(at: part, to: file)) != nil else { return nil }
        prune(folder)
        return SpotGlyphBook.open(layout, at: file)
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

    /// The key of a size: its side and its font size.
    static func sizeKey(side: CGFloat, fontSize: CGFloat) -> String {
        "\(side)|\(fontSize)"
    }
}
