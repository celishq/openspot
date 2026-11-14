import AppKit
import OpenspotCore
import Synchronization

enum SpotGlyphShelf {
    private static let bookGlyphFloor = 100
    private static let timeLimit: DispatchTimeInterval = .seconds(60)
    private static let keptBooks = 3
    private static let binding = DispatchQueue(label: "openspot.glyph-books", qos: .utility)
    private static let books = Mutex<[String: SpotGlyphBook]>([:])
    private static let binds = Mutex<[String: Int]>([:])
    private static let bound = Mutex<[String: [String]]>([:])
    private static let failures = Mutex<Set<String>>([])
    private static let maker = ProcessInfo.processInfo.operatingSystemVersionString + " "
        + ((Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "") + " "
        + ((Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "")

    static func book(side: CGFloat, fontSize: CGFloat) -> SpotGlyphBook? {
        books.withLock { $0[sizeKey(side: side, fontSize: fontSize)] }
    }

    static func bind(_ glyphs: [String], side: CGFloat, fontSize: CGFloat) {
        let size = sizeKey(side: side, fontSize: fontSize)
        let number = binds.withLock { binds in
            binds[size, default: 0] += 1
            return binds[size] ?? 0
        }
        binding.async {
            guard binds.withLock({ $0[size] }) == number, bound.withLock({ $0[size] }) != glyphs else { return }
            let layout = GlyphBook(glyphs: glyphs.filter(SpotGlyphPicture.isColour), side: Double(side), fontSize: Double(fontSize))
            guard layout.glyphs.count >= bookGlyphFloor, books.withLock({ $0[size]?.layout }) != layout else { return }
            let name = layout.name(system: maker)
            guard !failures.withLock({ $0.contains(name) }) else { return }
            let file = GlyphBook.folder().appendingPathComponent(name)
            guard let book = SpotGlyphBook.open(layout, at: file) ?? draw(layout, at: file) else {
                failures.withLock { _ = $0.insert(name) }
                return
            }
            books.withLock { $0[size] = book }
            bound.withLock { $0[size] = glyphs }
        }
    }

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

    private static func prune(_ folder: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        let books = files.filter { $0.lastPathComponent.hasSuffix(GlyphBook.fileExtension) }.sorted { date(of: $0) > date(of: $1) }
        for file in books.dropFirst(keptBooks) + files.filter({ $0.pathExtension == "part" }) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static func date(of file: URL) -> Date {
        (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    static func sizeKey(side: CGFloat, fontSize: CGFloat) -> String {
        "\(side)|\(fontSize)"
    }
}
