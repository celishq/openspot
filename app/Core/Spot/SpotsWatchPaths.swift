import Foundation

public struct SpotsWatchPaths: Sendable {
    public let roots: [String]
    private let folder: SpotsFolder
    private let config: String
    private let lock: String

    public init(folder: URL, config: URL) {
        let spots = Self.real(folder.path)
        self.folder = SpotsFolder(url: URL(fileURLWithPath: spots, isDirectory: true))
        self.config = Self.real(config.path)
        let configFolder = (self.config as NSString).deletingLastPathComponent
        lock = (configFolder as NSString).appendingPathComponent(SpotLock.fileName)
        roots = configFolder == spots ? [spots] : [spots, configFolder]
    }

    public func reports(_ path: String) -> Bool {
        path == config || path == lock || folder.reads(path)
    }

    private static func real(_ path: String) -> String {
        if let resolved = realpath(path, nil) {
            defer { free(resolved) }
            return String(cString: resolved)
        }
        let parent = (path as NSString).deletingLastPathComponent
        guard parent != path else { return path }
        return (real(parent) as NSString).appendingPathComponent((path as NSString).lastPathComponent)
    }
}
