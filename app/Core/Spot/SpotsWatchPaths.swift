import Foundation

/// The folders that the watch of the spots folder and the config file listens to, resolved once through their links, and
/// the changed paths it reports: those that a scan reads and the config file itself.
public struct SpotsWatchPaths: Sendable {
    /// The spots folder, and the folder that holds the config file when it is another one.
    public let roots: [String]
    private let folder: SpotsFolder
    private let config: String

    public init(folder: URL, config: URL) {
        let spots = Self.real(folder.path)
        self.folder = SpotsFolder(url: URL(fileURLWithPath: spots, isDirectory: true))
        self.config = Self.real(config.path)
        let configFolder = (self.config as NSString).deletingLastPathComponent
        roots = configFolder == spots ? [spots] : [spots, configFolder]
    }

    /// Whether a change of this path, as the watch reports it, changes what a reload reads.
    public func reports(_ path: String) -> Bool {
        path == config || folder.reads(path)
    }

    /// The path with each link resolved, as the watch reports it. A file that is not there yet resolves through its folder.
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
