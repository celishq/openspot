import Foundation

public enum SearchPath {
    static let system = ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]
    private static let installs = ["/opt/homebrew/bin", "/usr/local/bin"]
    private static let homeInstalls = [".local/bin", ".claude/local", ".npm-global/bin", ".bun/bin", ".volta/bin"]

    public static func adding(_ folders: [String], to path: String?) -> String {
        var paths = (path ?? "").split(separator: ":").map(String.init)
        for folder in folders where !paths.contains(folder) { paths.append(folder) }
        return paths.joined(separator: ":")
    }

    public static func readInstalls(home: URL) -> [String] {
        let node = home.appendingPathComponent(".nvm/versions/node")
        let versions = ((try? FileManager.default.contentsOfDirectory(atPath: node.path)) ?? []).sorted()
        return installs + homeInstalls.map { home.appendingPathComponent($0).path } + versions.map { node.appendingPathComponent("\($0)/bin").path }
    }

    public static func addInstalls() {
        let folders = readInstalls(home: FileManager.default.homeDirectoryForCurrentUser)
        setenv("PATH", adding(folders, to: ProcessInfo.processInfo.environment["PATH"]), 1)
    }
}
