import Foundation

public enum SearchPath {
    static let system = ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]
    static let installs = ["/opt/homebrew/bin", "/usr/local/bin"]

    public static func adding(_ folders: [String], to path: String?) -> String {
        var paths = (path ?? "").split(separator: ":").map(String.init)
        for folder in folders where !paths.contains(folder) { paths.append(folder) }
        return paths.joined(separator: ":")
    }

    public static func addInstalls() {
        setenv("PATH", adding(installs, to: ProcessInfo.processInfo.environment["PATH"]), 1)
    }
}
