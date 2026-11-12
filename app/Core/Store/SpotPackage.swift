import CryptoKit
import Foundation

/// A published spot in the store: a folder `<id>.spot` with `listing.toml` (its title, description and the hash of its
/// files), `readme.md`, `preview.txt`, and the spot's files under `files`. Finder shows it as one file.
public struct SpotPackage: Equatable, Sendable {
    /// What a person installs from a package, a zip of one, or a `.spot` file of the first format, which has no listing.
    public struct Contents: Equatable, Sendable {
        public let spot: SharedSpot
        public let description: String?
        public let readme: String?
        public let preview: String?

        public init(spot: SharedSpot, description: String? = nil, readme: String? = nil, preview: String? = nil) {
            self.spot = spot
            self.description = description
            self.readme = readme
            self.preview = preview
        }

        /// The files that an install puts in the plugins folder: the spot's, with its readme and its preview beside the file
        /// of its first script, as `<name>.md` and `<name>.preview.txt`. A file of the spot at either path stays as it is.
        public func installed() throws -> SharedSpot {
            guard readme != nil || preview != nil, let primary = try ReviewSpot.primaryPath(of: spot) else { return spot }
            let file = URL(fileURLWithPath: "/").appendingPathComponent(primary)
            let beside = [(SpotListing.readme(of: file), readme), (SpotListing.preview(of: file), preview)].compactMap { url, text in
                text.map { (path: String(url.path.dropFirst()), text: $0) }
            }
            let added = beside.filter { listed in !spot.files.contains { $0.path == listed.path } }
                .map { SharedSpot.File(path: $0.path, isExecutable: false, contents: Data($0.text.utf8)) }
            return try SharedSpot(files: spot.files + added)
        }
    }

    public static let fileExtension = SharedSpot.fileExtension
    private static let listingName = "listing.toml"
    private static let readmeName = "readme.md"
    private static let previewName = "preview.txt"
    private static let filesName = "files"

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// The place of the package of a spot with this ID in a store folder.
    public static func url(for id: String, in store: URL) -> URL {
        store.appendingPathComponent(id.replacingOccurrences(of: "/", with: "-") + "." + fileExtension, isDirectory: true)
    }

    /// The hash of the paths, the modes and the bytes of a spot's files, which says whether they changed.
    public static func hash(of spot: SharedSpot) -> String {
        var hasher = SHA256()
        for file in spot.files.sorted(by: { $0.path < $1.path }) {
            hasher.update(data: Data("\(file.path)\n\(file.isExecutable)\n\(file.contents.count)\n".utf8))
            hasher.update(data: file.contents)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Writes a package in place of the one at this URL. `hash` is of `spot` as the plugins folder holds it, before a
    /// compile adds programs.
    @discardableResult
    public static func write(_ spot: SharedSpot, hash: String? = nil, title: String, description: String?, readme: String, preview: String?, to url: URL) throws -> SpotPackage {
        let manager = FileManager.default
        let draft = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: draft.appendingPathComponent(filesName), withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: draft) }
        try spot.add(to: draft.appendingPathComponent(filesName))
        let lines = [("title", title), ("description", description), ("hash", hash ?? Self.hash(of: spot))].compactMap { key, value in
            value.map { "\(key) = \"\($0.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n"))\"" }
        }
        try (lines.joined(separator: "\n") + "\n").write(to: draft.appendingPathComponent(listingName), atomically: true, encoding: .utf8)
        try readme.write(to: draft.appendingPathComponent(readmeName), atomically: true, encoding: .utf8)
        if let preview { try preview.write(to: draft.appendingPathComponent(previewName), atomically: true, encoding: .utf8) }
        if manager.fileExists(atPath: url.path) { try manager.removeItem(at: url) }
        try manager.moveItem(at: draft, to: url)
        return SpotPackage(url: url)
    }

    /// The hash of the files that the package holds, as its last publish wrote it.
    public var hash: String? {
        value("hash")
    }

    public var title: String? {
        value("title")
    }

    /// The description, the readme and the preview that the package holds.
    public var listing: SpotListing {
        let readme = try? String(contentsOf: url.appendingPathComponent(Self.readmeName), encoding: .utf8)
        let preview = try? String(contentsOf: url.appendingPathComponent(Self.previewName), encoding: .utf8)
        return SpotListing(description: value("description"), readme: readme?.trimmingCharacters(in: .whitespacesAndNewlines), preview: preview.map { SpotOutput(text: $0).items } ?? [])
    }

    /// The readme and the preview as their text, for the files beside an installed spot.
    public var texts: (readme: String?, preview: String?) {
        (try? String(contentsOf: url.appendingPathComponent(Self.readmeName), encoding: .utf8), try? String(contentsOf: url.appendingPathComponent(Self.previewName), encoding: .utf8))
    }

    /// The spot's files, with the checks of every shared spot.
    public func spot() throws -> SharedSpot {
        let root = url.appendingPathComponent(Self.filesName, isDirectory: true).resolvingSymlinksInPath()
        guard let walk = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
            throw SpotError.fault("The package \(url.lastPathComponent) has no files.")
        }
        var files: [SharedSpot.File] = []
        for case let file as URL in walk {
            let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw SpotError.fault("The package \(url.lastPathComponent) holds a link, \(file.lastPathComponent).") }
            guard values.isRegularFile == true else { continue }
            let path = String(file.resolvingSymlinksInPath().path.dropFirst(root.path.count + 1))
            files.append(SharedSpot.File(path: path, isExecutable: FileManager.default.isExecutableFile(atPath: file.path), contents: try Data(contentsOf: file)))
        }
        return try SharedSpot(files: files.sorted { $0.path < $1.path })
    }

    /// Writes the package as one zip file, which travels where a folder cannot, such as in a chat.
    public func zip(to file: URL) throws {
        try? FileManager.default.removeItem(at: file)
        _ = try Self.run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", "--keepParent", url.path, file.path])
    }

    /// Reads what a package folder, a zip of one, or a `.spot` file of the first format holds, and runs none of it. A zip
    /// with a path that leaves its folder, a link, or more bytes in all than `limit` or the limit of shared spots is refused, the last before it unpacks.
    public static func open(at url: URL, limit: Int? = nil) throws -> Contents {
        let limit = limit ?? SharedSpot.sizeLimit
        var isFolder: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder), isFolder.boolValue {
            return try SpotPackage(url: url).contents()
        }
        let head = (try? FileHandle(forReadingFrom: url)).flatMap { try? $0.read(upToCount: 4) }
        guard head == Data([0x50, 0x4B, 0x03, 0x04]) else { return Contents(spot: try SharedSpot(contentsOf: url)) }
        let names = try run("/usr/bin/zipinfo", ["-1", url.path]).split(separator: "\n").map(String.init)
        guard names.allSatisfy(isSafe(entry:)) else { throw SpotError.fault("This file holds a path that leaves its folder, so Openspot does not open it.") }
        let total = try run("/usr/bin/zipinfo", ["-t", url.path]).components(separatedBy: " bytes uncompressed").first?
            .split(separator: " ").last.flatMap { Int($0) } ?? .max
        guard total <= limit else { throw SpotError.fault("This spot is over the \(limit / 1_000_000) MB limit.") }
        let place = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-open-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: place) }
        _ = try run("/usr/bin/ditto", ["-x", "-k", url.path, place.path])
        for case let file as URL in FileManager.default.enumerator(at: place, includingPropertiesForKeys: [.isSymbolicLinkKey]) ?? FileManager.DirectoryEnumerator() {
            if try file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true {
                throw SpotError.fault("This file holds a link, \(file.lastPathComponent), so Openspot does not open it.")
            }
        }
        let packages = try FileManager.default.contentsOfDirectory(at: place, includingPropertiesForKeys: nil).filter { $0.pathExtension == fileExtension }
        guard packages.count == 1, let package = packages.first else { throw SpotError.fault("This file holds no spot.") }
        return try SpotPackage(url: package).contents()
    }

    /// Whether a path in a zip stays inside the folder that it unpacks into.
    static func isSafe(entry: String) -> Bool {
        !entry.hasPrefix("/") && !entry.split(separator: "/").contains("..")
    }

    private func contents() throws -> Contents {
        let texts = texts
        return Contents(spot: try spot(), description: value("description"), readme: texts.readme?.trimmingCharacters(in: .whitespacesAndNewlines), preview: texts.preview)
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

    private func value(_ key: String) -> String? {
        guard let text = try? String(contentsOf: url.appendingPathComponent(Self.listingName), encoding: .utf8),
              case .string(let value)? = (try? TomlDocument(text: text))?.values[key] else { return nil }
        return value
    }
}
