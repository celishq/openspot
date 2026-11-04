import Foundation

public struct PluginFolder: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static func standard(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> PluginFolder {
        if let path = environment["OPENSPOT_PLUGINS"], !path.isEmpty {
            return PluginFolder(url: URL(fileURLWithPath: path, isDirectory: true))
        }
        return PluginFolder(url: home.appendingPathComponent(".config/openspot/plugins", isDirectory: true))
    }

    public func scan() throws -> ScanResult {
        let files = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var result = ScanResult(plugins: [], refused: [])
        for file in files {
            guard let text = try? String(contentsOf: file, encoding: .utf8),
                  let header = PluginHeader(text: text) else { continue }
            guard header.api == OpenspotVersion.api else {
                result.refused.append(Refusal(file: file.lastPathComponent, reason: "needs api \(header.api)"))
                continue
            }
            result.plugins.append(Plugin(name: header.name, api: header.api, url: file))
        }
        return result
    }
}
