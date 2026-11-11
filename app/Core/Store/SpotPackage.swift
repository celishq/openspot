import CryptoKit
import Foundation

/// A published spot in the store: a folder `<id>.spot` with `listing.toml` (its title, description and the hash of its
/// files), `readme.md`, `preview.txt`, and the spot's files under `files`. Finder shows it as one file.
public struct SpotPackage: Equatable, Sendable {
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
        return SpotListing(description: value("description"), readme: readme?.trimmingCharacters(in: .whitespacesAndNewlines), preview: preview.map { PluginOutput(text: $0).items } ?? [])
    }

    /// The readme and the preview as their text, for the files beside an installed spot.
    public var texts: (readme: String?, preview: String?) {
        (try? String(contentsOf: url.appendingPathComponent(Self.readmeName), encoding: .utf8), try? String(contentsOf: url.appendingPathComponent(Self.previewName), encoding: .utf8))
    }

    /// The spot's files, with the checks of every shared spot.
    public func spot() throws -> SharedSpot {
        let root = url.appendingPathComponent(Self.filesName, isDirectory: true).resolvingSymlinksInPath()
        guard let walk = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
            throw PluginError.fault("The package \(url.lastPathComponent) has no files.")
        }
        var files: [SharedSpot.File] = []
        for case let file as URL in walk {
            let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw PluginError.fault("The package \(url.lastPathComponent) holds a link, \(file.lastPathComponent).") }
            guard values.isRegularFile == true else { continue }
            let path = String(file.resolvingSymlinksInPath().path.dropFirst(root.path.count + 1))
            files.append(SharedSpot.File(path: path, isExecutable: FileManager.default.isExecutableFile(atPath: file.path), contents: try Data(contentsOf: file)))
        }
        return try SharedSpot(files: files.sorted { $0.path < $1.path })
    }

    private func value(_ key: String) -> String? {
        guard let text = try? String(contentsOf: url.appendingPathComponent(Self.listingName), encoding: .utf8),
              case .string(let value)? = (try? TomlDocument(text: text))?.values[key] else { return nil }
        return value
    }
}
