import Foundation

/// The cache folder of the app: the folder of a Debug build or of `OPENSPOT_CONFIG`, else in the person's Caches.
public enum AppCache {
    public static func folder(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        devState: String? = Bundle.main.object(forInfoDictionaryKey: "OpenspotDevState") as? String
    ) -> URL {
        let own = [environment["OPENSPOT_CONFIG"], devState].compactMap { $0 }.first { !$0.isEmpty }
        return own.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? home.appendingPathComponent("Library/Caches/openspot", isDirectory: true)
    }
}
