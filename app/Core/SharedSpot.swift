import Foundation

/// A spot as one file that a person can send: the files it needs, with a format number. Each value of this type passed
/// its checks, so it holds no path that leaves the plugins folder and no text that hides its order.
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

    private struct Head: Decodable {
        let format: Int
    }

    private struct Document: Codable {
        let format: Int
        let files: [Entry]
    }

    private struct Entry: Codable {
        let path: String
        var executable: Bool?
        var text: String?
        var data: Data?
    }

    public static let fileExtension = "spot"
    static let sizeLimit = 64_000_000
    private static let format = 1
    private static let hiddenOrder: ClosedRange<UInt32> = 0x202A...0x202E
    private static let hiddenIsolate: ClosedRange<UInt32> = 0x2066...0x2069

    public let files: [File]

    /// Checks files that came from anywhere, and throws a fault that says what is wrong.
    public init(files: [File]) throws {
        guard !files.isEmpty else { throw PluginError.fault("This file holds no files.") }
        var total = 0
        var taken = Set<String>()
        for file in files {
            guard Self.isSafe(path: file.path) else { throw PluginError.fault("Openspot cannot use the path \(file.path).") }
            if let text = file.text, Self.hidesOrder(text) { throw PluginError.fault("\(file.path) has hidden characters that change what the text shows.") }
            guard taken.insert(Self.folded(file.path)).inserted else { throw PluginError.fault("This file holds \(file.path) twice.") }
            total += file.contents.count
        }
        guard total <= Self.sizeLimit else { throw Self.tooLarge }
        for file in files where Self.parents(of: file.path).contains(where: { taken.contains(Self.folded($0)) }) {
            throw PluginError.fault("This file holds \(file.path) twice.")
        }
        self.files = files
    }

    /// Reads what a `.spot` file holds.
    public init(data: Data) throws {
        guard let head = try? JSONDecoder().decode(Head.self, from: data) else { throw PluginError.fault("This file is not a spot.") }
        guard head.format <= Self.format else { throw PluginError.fault("This spot needs a newer Openspot.") }
        guard let document = try? JSONDecoder().decode(Document.self, from: data) else { throw PluginError.fault("This file is not a spot.") }
        try self.init(files: try document.files.map { entry in
            let contents: Data
            switch (entry.text, entry.data) {
            case (let text?, nil): contents = Data(text.utf8)
            case (nil, let data?): contents = data
            default: throw PluginError.fault("This file is not a spot.")
            }
            return File(path: entry.path, isExecutable: entry.executable ?? false, contents: contents)
        })
    }

    /// Reads a `.spot` file on the disk. A file far over the limit is refused before it is read.
    public init(contentsOf url: URL) throws {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        guard size <= 2 * Self.sizeLimit else { throw Self.tooLarge }
        do {
            try self.init(data: try Data(contentsOf: url))
        } catch let error as PluginError {
            throw error
        } catch {
            throw PluginError.fault("Openspot cannot read this file.")
        }
    }

    /// Collects a spot from the plugins folder, with what it needs: the whole folder of a script in a folder, and each
    /// script that a widget places or opens. Hidden files stay behind.
    public init(sharing command: PluginCommand, from scan: ScanResult) throws {
        guard command.shipped == nil else { throw PluginError.fault("\(command.name) comes with Openspot, so it cannot be shared.") }
        var total = 0
        var files: [File] = []
        for root in Self.roots(of: command, in: scan) {
            files += try Self.files(at: root.url, path: root.path, total: &total)
        }
        try self.init(files: files)
    }

    /// Whether a Swift script of this spot has no program beside it.
    public var needsCompile: Bool {
        !uncompiled.isEmpty
    }

    /// This spot with the program of each Swift script that has none, so that a Mac with no Swift tools can run it.
    public func compiled(by program: SwiftProgram = SwiftProgram()) async throws -> SharedSpot {
        var all = files
        for (file, path) in uncompiled {
            all.append(File(path: path, isExecutable: true, contents: try await program.build(source: file.contents)))
        }
        return try SharedSpot(files: all)
    }

    private var uncompiled: [(file: File, path: String)] {
        files.compactMap { file in
            guard file.isExecutable, let path = SwiftProgram.path(beside: file.path), !files.contains(where: { $0.path == path }) else { return nil }
            return (file, path)
        }
    }

    /// The whole text of the `.spot` file.
    public var data: Data {
        let entries = files.map { file -> Entry in
            let text = file.text
            return Entry(path: file.path, executable: file.isExecutable ? true : nil, text: text, data: text == nil ? file.contents : nil)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(Document(format: Self.format, files: entries))) ?? Data()
    }

    /// The name of a `.spot` file for a spot with this name.
    public static func fileName(for name: String) -> String {
        let words = name.split { $0 == "/" || $0 == ":" || $0.isNewline || $0.unicodeScalars.contains(where: { $0.value < 0x20 }) }
            .map { String($0.drop { $0 == "." }) }
            .filter { !$0.isEmpty }
        return "\(words.isEmpty ? "Spot" : words.joined(separator: "-")).\(fileExtension)"
    }

    /// Whether these dragged files are `.spot` files and nothing else.
    public static func isFile(_ paths: [String]) -> Bool {
        !paths.isEmpty && paths.allSatisfy { URL(fileURLWithPath: $0).pathExtension.lowercased() == fileExtension }
    }

    /// The `.spot` file that a text names, when all of the text is its full path, such as a drag into a text field writes. The
    /// file must exist. A file URL, quotes and the backslashes of a terminal also count.
    public static func file(in text: String) -> URL? {
        var path = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.count > 1, let quote = path.first, quote == "'" || quote == "\"", path.last == quote { path = String(path.dropFirst().dropLast()) }
        if path.hasPrefix("file://") {
            path = URL(string: path)?.path ?? path
        } else {
            path = path.replacingOccurrences(of: "\\ ", with: " ")
        }
        guard path.hasPrefix("/"), isFile([path]) else { return nil }
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isFolder), !isFolder.boolValue else { return nil }
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
        if let clash = clash(in: folder) { throw PluginError.fault(clash) }
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

    private static var tooLarge: PluginError {
        .fault("This spot is over the \(sizeLimit / 1_000_000) MB limit.")
    }

    /// The files and folders at the top of the plugins folder that a command needs, with its own first.
    private static func roots(of command: PluginCommand, in scan: ScanResult) -> [(path: String, url: URL)] {
        var roots: [(path: String, url: URL)] = []
        var waiting = [command.id]
        while !waiting.isEmpty {
            let id = waiting.removeFirst()
            guard let plugin = scan.plugins.first(where: { $0.commands.contains { $0.id == id } }),
                  let first = plugin.commands.first, first.shipped == nil
            else { continue }
            let folder = plugin.id.split(separator: "/", maxSplits: 1).count > 1 ? plugin.id.split(separator: "/")[0] : nil
            let root = folder.map(String.init) ?? first.url.lastPathComponent
            guard !roots.contains(where: { $0.path == root }) else { continue }
            roots.append((root, folder == nil ? first.url : first.url.deletingLastPathComponent()))
            if folder == nil, let program = SwiftProgram.file(beside: first.url) { roots.append((program.lastPathComponent, program)) }
            let neighbours = folder == nil ? [plugin] : scan.plugins.filter { $0.id.hasPrefix("\(root)/") }
            waiting += neighbours.flatMap(\.commands).flatMap { $0.places + ($0.opens.map { [$0] } ?? []) }
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
