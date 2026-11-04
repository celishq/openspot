import Foundation

public enum PluginFolder {
    public static func url(environment: [String: String] = ProcessInfo.processInfo.environment,
                           home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        if let path = environment["OPENSPOT_PLUGINS"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return home.appendingPathComponent(".config/openspot/plugins", isDirectory: true)
    }
}
