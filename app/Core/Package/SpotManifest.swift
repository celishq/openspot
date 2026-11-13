import CryptoKit
import Foundation

/// What a set of spot files holds: the path, the SHA-256, the size and the mode of each one. Two equal manifests mean equal
/// files. A release names one, the lock keeps its hash, and the store compares the files a person writes.
public struct SpotManifest: Hashable, Sendable {
    /// One file as a manifest names it.
    public struct File: Hashable, Sendable {
        public let path: String
        public let sha256: String
        public let size: Int
        public let isExecutable: Bool
    }

    public let files: Set<File>

    public init(_ files: [File]) {
        self.files = Set(files)
    }

    public init(_ files: [SpotPackage.File]) {
        self.init(files.map { File(path: $0.path, sha256: Data(CryptoKit.SHA256.hash(data: $0.contents)).hex, size: $0.contents.count, isExecutable: $0.isExecutable) })
    }

    /// The manifest of each file under these paths in a folder, read as they are, with none of the checks of a spot that
    /// travels. Hidden files are left out.
    public init(walking paths: [String], in folder: URL) throws {
        var files: [File] = []
        for path in paths {
            let top = folder.appendingPathComponent(path)
            let inner = FileManager.default.enumerator(atPath: top.path).map { $0.compactMap { $0 as? String } } ?? []
            for relative in [""] + inner {
                let url = relative.isEmpty ? top : top.appendingPathComponent(relative)
                let name = relative.isEmpty ? path : "\(path)/\(relative)"
                var isFolder: ObjCBool = false
                guard !name.split(separator: "/").contains(where: { $0.hasPrefix(".") }),
                      FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder), !isFolder.boolValue else { continue }
                let data = try Data(contentsOf: url)
                files.append(File(path: name, sha256: Data(CryptoKit.SHA256.hash(data: data)).hex, size: data.count, isExecutable: FileManager.default.isExecutableFile(atPath: url.path)))
            }
        }
        self.init(files)
    }

    /// The files in path order.
    public var sorted: [File] {
        files.sorted { $0.path < $1.path }
    }

    /// Only the files a person writes: no program of a Swift script and no view library, which a share or a publish builds.
    public var written: SpotManifest {
        SpotManifest(Array(files).filter { !Self.isBuilt($0.path) })
    }

    /// Whether a path is a program of a Swift script or a view library.
    static func isBuilt(_ path: String) -> Bool {
        SwiftProgram.isProgram(URL(fileURLWithPath: path)) || ViewLibrary.isLibrary(path)
    }

    /// One SHA-256 of the whole manifest, as `spots.lock` keeps it.
    public var hash: String {
        let lines = sorted.map { "\($0.path)\n\($0.sha256)\n\($0.size)\n\($0.isExecutable)\n" }.joined()
        return Data(CryptoKit.SHA256.hash(data: Data(lines.utf8))).hex
    }
}
