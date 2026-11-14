import CryptoKit
import Foundation

public struct SpotManifest: Hashable, Sendable {
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

    public var sorted: [File] {
        files.sorted { $0.path < $1.path }
    }

    public var written: SpotManifest {
        SpotManifest(Array(files).filter { !Self.isBuilt($0.path) })
    }

    static func isBuilt(_ path: String) -> Bool {
        SwiftProgram.isProgram(URL(fileURLWithPath: path)) || ViewLibrary.isLibrary(path)
    }

    public var hash: String {
        let lines = sorted.map { "\($0.path)\n\($0.sha256)\n\($0.size)\n\($0.isExecutable)\n" }.joined()
        return Data(CryptoKit.SHA256.hash(data: Data(lines.utf8))).hex
    }
}
