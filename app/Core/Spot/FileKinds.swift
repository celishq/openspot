import Foundation

public struct FileKinds: Equatable, Sendable {
    public enum Kind: Sendable {
        case file
        case folder
    }

    public struct Disk: Sendable {
        public init() {}

        public func read(_ paths: [String]) -> FileKinds {
            var kinds: [String: Kind] = [:]
            for path in paths {
                var isFolder: ObjCBool = false
                if FileManager.default.fileExists(atPath: path, isDirectory: &isFolder) { kinds[path] = isFolder.boolValue ? .folder : .file }
            }
            return FileKinds(paths, kinds: kinds)
        }
    }

    public let paths: [String]
    private let kinds: [String: Kind]

    public init(_ paths: [String] = [], kinds: [String: Kind] = [:]) {
        self.paths = paths
        self.kinds = kinds
    }

    func kind(of path: String) -> Kind? {
        kinds[path]
    }
}
