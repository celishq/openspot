import Foundation

/// A spot as a person sends it: the files of its spot folders, and of each spot folder that it needs, by their paths in
/// the plugins folder. It travels as a zip of those folders. Each value of this type passed its checks, so it holds no path
/// that leaves a spot folder and no text that hides its order.
public struct SharedSpot: Equatable, Sendable {
    public struct File: Equatable, Sendable {
        public let path: String
        public let isExecutable: Bool
        public let contents: Data

        public init(path: String, isExecutable: Bool, contents: Data) {
            self.path = path
            self.isExecutable = isExecutable
            self.contents = contents
        }

        /// Its words, or nil when its bytes are not text that comes back the same.
        public var text: String? {
            guard let text = String(data: contents, encoding: .utf8), !contents.contains(0), Data(text.utf8) == contents else { return nil }
            return text
        }
    }

    public static let fileExtension = SpotFolder.spotExtension
    static let sizeLimit = 64_000_000
    private static let hiddenOrder: ClosedRange<UInt32> = 0x202A...0x202E
    private static let hiddenIsolate: ClosedRange<UInt32> = 0x2066...0x2069

    public let files: [File]

    /// Checks files that came from anywhere, and throws a fault that says what is wrong.
    public init(files: [File]) throws {
        guard !files.isEmpty else { throw SpotError.fault("This file holds no files.") }
        var total = 0
        var taken = Set<String>()
        for file in files {
            guard Self.isSafe(path: file.path) else { throw SpotError.fault("Openspot cannot use the path \(file.path).") }
            guard Self.root(of: file.path) != nil else { throw SpotError.fault("\(file.path) is not in a .spot folder.") }
            if let text = file.text, Self.hidesOrder(text) { throw SpotError.fault("\(file.path) has hidden characters that change what the text shows.") }
            guard taken.insert(Self.folded(file.path)).inserted else { throw SpotError.fault("This file holds \(file.path) twice.") }
            total += file.contents.count
        }
        guard total <= Self.sizeLimit else { throw Self.tooLarge }
        for file in files where Self.parents(of: file.path).contains(where: { taken.contains(Self.folded($0)) }) {
            throw SpotError.fault("This file holds \(file.path) twice.")
        }
        self.files = files
    }

    /// Reads a spot folder, or a zip of spot folders, and runs none of it. A zip with a path that leaves its folder, a link,
    /// or more bytes in all than `limit` or the limit of shared spots is refused, the last before it unpacks.
    public init(contentsOf url: URL, limit: Int? = nil) throws {
        let limit = min(limit ?? Self.sizeLimit, Self.sizeLimit)
        if Self.type(of: url) == .typeDirectory {
            var total = 0
            let files = try Self.files(at: url, path: url.lastPathComponent, total: &total)
            guard total <= limit else { throw Self.tooLarge }
            try self.init(files: files)
            return
        }
        let head = (try? FileHandle(forReadingFrom: url)).flatMap { try? $0.read(upToCount: 4) }
        guard head == Data([0x50, 0x4B, 0x03, 0x04]) else { throw SpotError.fault("This file is not a spot.") }
        let names = try Self.run("/usr/bin/zipinfo", ["-1", url.path]).split(separator: "\n").map(String.init)
        guard names.allSatisfy(Self.isSafe(entry:)) else { throw SpotError.fault("This file holds a path that leaves its folder, so Openspot does not open it.") }
        let total = try Self.run("/usr/bin/zipinfo", ["-t", url.path]).components(separatedBy: " bytes uncompressed").first?
            .split(separator: " ").last.flatMap { Int($0) } ?? .max
        guard total <= limit else { throw Self.tooLarge }
        let place = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-open-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: place) }
        _ = try Self.run("/usr/bin/ditto", ["-x", "-k", url.path, place.path])
        for case let file as URL in FileManager.default.enumerator(at: place, includingPropertiesForKeys: [.isSymbolicLinkKey]) ?? FileManager.DirectoryEnumerator() {
            if try file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true {
                throw SpotError.fault("This file holds a link, \(file.lastPathComponent), so Openspot does not open it.")
            }
        }
        let folders = try FileManager.default.contentsOfDirectory(atPath: place.path).filter { !$0.hasPrefix(".") }.sorted()
        guard !folders.isEmpty, folders.allSatisfy({ ($0 as NSString).pathExtension.lowercased() == Self.fileExtension }) else { throw SpotError.fault("This file holds no spot.") }
        try self.init(paths: folders, in: place)
    }

    /// Collects a spot from the plugins folder, with what it needs: the whole folder of a script in a folder, and each
    /// script that a widget places or opens. Hidden files stay behind.
    public init(sharing spot: Spot, from scan: ScanResult) throws {
        guard spot.host == nil, !spot.isBuiltIn else { throw SpotError.fault("\(spot.name) comes with Openspot, so it cannot be shared.") }
        var total = 0
        var files: [File] = []
        for root in Self.roots(of: spot, in: scan) {
            files += try Self.files(at: root.url, path: root.path, total: &total)
        }
        try self.init(files: files)
    }

    /// Reads the files under these paths at the top of a folder, each folder in name order with its hidden files left out.
    init(paths: [String], in folder: URL) throws {
        var total = 0
        try self.init(files: try paths.flatMap { try Self.files(at: folder.appendingPathComponent($0), path: $0, total: &total) })
    }

    /// Whether a Swift script or a view of this spot has no program beside it.
    public var needsCompile: Bool {
        !uncompiled.isEmpty || !unbuiltViews.isEmpty
    }

    /// This spot with the program of each Swift script and the library of each view that has none, so that a Mac with no
    /// Swift tools can run it (protocol: Views).
    public func compiled(by program: SwiftProgram = SwiftProgram(), views: ViewLibrary = .standard()) async throws -> SharedSpot {
        var all = files
        for (file, path) in uncompiled {
            all.append(File(path: path, isExecutable: true, contents: try await program.build(source: file.contents)))
        }
        for (file, path) in unbuiltViews {
            let name = URL(fileURLWithPath: file.path).lastPathComponent
            all.append(File(path: path, isExecutable: false, contents: try await views.build(source: file.contents, named: name, kinds: SwiftProgram.kinds)))
        }
        return try SharedSpot(files: all)
    }

    private var uncompiled: [(file: File, path: String)] {
        files.compactMap { file in
            guard file.isExecutable, let path = SwiftProgram.path(beside: file.path), !files.contains(where: { $0.path == path }) else { return nil }
            return (file, path)
        }
    }

    /// Each view that a script's header names, with the path of the library that it lacks.
    private var unbuiltViews: [(file: File, path: String)] {
        files.compactMap { script in
            guard script.isExecutable, let text = script.text, let name = SpotHeader(text: text).block.value("view"), !name.hasPrefix("/") else { return nil }
            let folder = (script.path as NSString).deletingLastPathComponent
            let source = folder.isEmpty ? name : "\(folder)/\(name)"
            let path = ViewLibrary.path(beside: source)
            guard let file = files.first(where: { $0.path == source }), !files.contains(where: { $0.path == path }) else { return nil }
            return (file, path)
        }
    }

    /// The spot folders that it holds, such as `emoji.spot`, its own first.
    public var roots: [String] {
        files.compactMap { Self.root(of: $0.path) }.reduce(into: []) { roots, root in if !roots.contains(root) { roots.append(root) } }
    }

    /// The files of one of its spot folders.
    public func files(in root: String) -> [File] {
        files.filter { $0.path.hasPrefix(root + "/") }
    }

    /// Writes its spot folders as one zip file, which travels where a folder cannot, such as in a chat.
    public func zip(to file: URL) throws {
        let place = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-zip-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: place) }
        try add(to: place)
        try? FileManager.default.removeItem(at: file)
        _ = try Self.run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", place.path, file.path])
    }

    /// Whether a path in a zip stays inside the folder that it unpacks into.
    static func isSafe(entry: String) -> Bool {
        !entry.hasPrefix("/") && !entry.split(separator: "/").contains("..")
    }

    /// The spot folder at the start of a path, when the path lies in one.
    private static func root(of path: String) -> String? {
        let names = path.split(separator: "/")
        guard names.count > 1, let first = names.first, (first as NSString).pathExtension.lowercased() == fileExtension else { return nil }
        return String(first)
    }

    /// Runs a tool of macOS to its end, and gives its output. A tool that fails throws its words.
    private static func run(_ tool: String, _ arguments: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else { throw SpotError.fault("Openspot cannot read this file. \(text)") }
        return text
    }

    /// The name of a `.spot` file for a spot with this name.
    public static func fileName(for name: String) -> String {
        let words = name.split { $0 == "/" || $0 == ":" || $0.isNewline || $0.unicodeScalars.contains(where: { $0.value < 0x20 }) }
            .map { String($0.drop { $0 == "." }) }
            .filter { !$0.isEmpty }
        return "\(words.isEmpty ? "Spot" : words.joined(separator: "-")).\(fileExtension)"
    }

    /// Whether these dragged files are `.spot` files or folders and nothing else.
    public static func isFile(_ paths: [String]) -> Bool {
        !paths.isEmpty && paths.allSatisfy { URL(fileURLWithPath: $0).pathExtension.lowercased() == fileExtension }
    }

    /// The `.spot` file or folder that a text names, when all of the text is its full path, such as a drag into a text field
    /// writes. It must exist. A file URL, quotes and the backslashes of a terminal also count.
    public static func file(in text: String) -> URL? {
        var path = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.count > 1, let quote = path.first, quote == "'" || quote == "\"", path.last == quote { path = String(path.dropFirst().dropLast()) }
        if path.hasPrefix("file://") {
            path = URL(string: path)?.path ?? path
        } else {
            path = path.replacingOccurrences(of: "\\ ", with: " ")
        }
        guard path.hasPrefix("/"), isFile([path]), FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// What the sender reads after a copy.
    public func notice(name: String) -> String {
        files.count == 1
            ? "\(name) copied. Check it for secrets before you send it."
            : "\(name) copied, with \(files.count) files. Check them for secrets before you send them."
    }

    /// The first thing that stops these files from going into a folder, in words for the person.
    func clash(in folder: URL) -> String? {
        for file in files {
            var place = folder
            let names = file.path.split(separator: "/").map(String.init)
            for name in names.dropLast() {
                place.appendPathComponent(name)
                guard let type = Self.type(of: place) else { break }
                if type != .typeDirectory { return "\(file.path) cannot go into the plugins folder, because \(name) is not a folder." }
            }
            if Self.type(of: folder.appendingPathComponent(file.path)) == .typeDirectory {
                return "\(file.path) cannot replace a folder of the same name."
            }
        }
        return nil
    }

    /// The paths of the files in a folder that this spot would change.
    func replaced(in folder: URL) -> [String] {
        files.filter { file in
            let url = folder.appendingPathComponent(file.path)
            guard FileManager.default.fileExists(atPath: url.path) else { return false }
            return (try? Data(contentsOf: url)) != file.contents || FileManager.default.isExecutableFile(atPath: url.path) != file.isExecutable
        }.map(\.path)
    }

    /// Writes each file into a folder. A file it replaces goes to the Trash, and an equal file stays. It runs nothing.
    public func add(to folder: URL, discard: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }) throws {
        if let clash = clash(in: folder) { throw SpotError.fault(clash) }
        let replaced = replaced(in: folder)
        for file in files {
            let url = folder.appendingPathComponent(file.path)
            let isNew = !FileManager.default.fileExists(atPath: url.path)
            guard isNew || replaced.contains(file.path) else { continue }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !isNew { try discard(url) }
            try file.contents.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: file.isExecutable ? 0o755 : 0o644], ofItemAtPath: url.path)
        }
    }

    private static var tooLarge: SpotError {
        .fault("This spot is over the \(sizeLimit / 1_000_000) MB limit.")
    }

    /// The spot folders that a command needs, with its own first.
    private static func roots(of spot: Spot, in scan: ScanResult) -> [(path: String, url: URL)] {
        var roots: [(path: String, url: URL)] = []
        var waiting = [spot.id]
        while !waiting.isEmpty {
            let id = waiting.removeFirst()
            guard let plugin = scan.files.first(where: { $0.spots.contains { $0.id == id } }),
                  let first = plugin.spots.first, first.host == nil, !first.isBuiltIn
            else { continue }
            let folder = first.url.deletingLastPathComponent()
            guard !roots.contains(where: { $0.url == folder }) else { continue }
            roots.append((folder.lastPathComponent, folder))
            let neighbours = scan.files.flatMap(\.spots).filter { $0.url.deletingLastPathComponent() == folder }
            waiting += neighbours.flatMap { $0.places + ($0.opens.map { [$0] } ?? []) }
        }
        return roots
    }

    /// Reads a file, or each file under a folder in name order. A link to a folder below the top stays behind.
    private static func files(at url: URL, path: String, total: inout Int) throws -> [File] {
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) else { return [] }
        if isFolder.boolValue {
            if path.contains("/"), type(of: url) == .typeSymbolicLink { return [] }
            let names = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                .map(\.lastPathComponent)
                .sorted()
            return try names.flatMap { try files(at: url.appendingPathComponent($0), path: "\(path)/\($0)", total: &total) }
        }
        total += (try FileManager.default.attributesOfItem(atPath: url.resolvingSymlinksInPath().path)[.size] as? Int) ?? 0
        guard total <= sizeLimit else { throw tooLarge }
        return [File(path: path, isExecutable: FileManager.default.isExecutableFile(atPath: url.path), contents: try Data(contentsOf: url))]
    }

    /// The type of what lies at a URL, without a walk through a link.
    private static func type(of url: URL) -> FileAttributeType? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.type] as? FileAttributeType
    }

    private static func isSafe(path: String) -> Bool {
        let names = path.split(separator: "/", omittingEmptySubsequences: false)
        return !path.isEmpty && names.allSatisfy { name in
            !name.isEmpty && !name.hasPrefix(".") && !name.unicodeScalars.contains { $0.value < 0x20 || $0.value == 0x7F } && !hidesOrder(String(name))
        }
    }

    private static func hidesOrder(_ text: String) -> Bool {
        text.unicodeScalars.contains { hiddenOrder.contains($0.value) || hiddenIsolate.contains($0.value) }
    }

    /// A path as a Mac disk compares it, which ignores case and the form of an accent.
    private static func folded(_ path: String) -> String {
        path.precomposedStringWithCanonicalMapping.lowercased()
    }

    private static func parents(of path: String) -> [String] {
        let names = path.split(separator: "/").map(String.init)
        return names.indices.dropLast().map { names[...$0].joined(separator: "/") }
    }
}
