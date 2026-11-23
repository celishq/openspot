import Foundation

public enum AppCache {
    public static func folder(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        devState: String? = Bundle.main.object(forInfoDictionaryKey: "OpenspotDevState") as? String
    ) -> URL {
        SpotsFolder.ownConfig(environment: environment, devState: devState) ?? home.appendingPathComponent("Library/Caches/openspot", isDirectory: true)
    }
}
