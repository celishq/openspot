import CryptoKit
import Foundation

/// A published spot in the store: a copy of its `<name>.spot` folder, with the program of each Swift script.
public struct SpotPackage: Equatable, Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// The place of the package of a spot with this ID in a store folder: the spot folder of its first name.
    public static func url(for id: String, in store: URL) -> URL {
        store.appendingPathComponent(SpotID(id).folderName, isDirectory: true)
    }

    /// The hash of the paths, the modes and the bytes of the files of one spot folder that a person writes, which says
    /// whether they changed. Programs and view libraries, which a publish builds, and the release log are not in it.
    public static func hash(of spot: SpotFolder, in root: String) -> String {
        var hasher = SHA256()
        let written = spot.released(in: root).filter { !SwiftProgram.isProgram(URL(fileURLWithPath: $0.path)) && !ViewLibrary.isLibrary($0.path) }
        for file in written.sorted(by: { $0.path < $1.path }) {
            hasher.update(data: Data("\(file.path)\n\(file.isExecutable)\n\(file.contents.count)\n".utf8))
            hasher.update(data: file.contents)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Writes each spot folder of a spot into the store folder, in place of the one there.
    public static func write(_ spot: SpotFolder, to store: URL) throws {
        let manager = FileManager.default
        let draft = store.appendingPathComponent(".draft-\(UUID().uuidString)", isDirectory: true)
        defer { try? manager.removeItem(at: draft) }
        try spot.add(to: draft)
        for root in spot.roots {
            let url = store.appendingPathComponent(root, isDirectory: true)
            if manager.fileExists(atPath: url.path) { try manager.removeItem(at: url) }
            try manager.moveItem(at: draft.appendingPathComponent(root), to: url)
        }
    }

    /// The hash of the files that the package holds, or nil when the store has no package.
    public var hash: String? {
        (try? spot()).map { Self.hash(of: $0, in: url.lastPathComponent) }
    }

    /// The spot's files, with the checks of every shared spot.
    public func spot() throws -> SpotFolder {
        try SpotFolder(contentsOf: url)
    }
}
