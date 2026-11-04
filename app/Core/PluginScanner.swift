import Foundation

public struct Plugin: Equatable, Sendable {
    public let name: String
    public let api: Int
    public let url: URL

    public init(name: String, api: Int, url: URL) {
        self.name = name
        self.api = api
        self.url = url
    }
}

public struct Refusal: Equatable {
    public let file: String
    public let reason: String

    public init(file: String, reason: String) {
        self.file = file
        self.reason = reason
    }
}

public struct ScanResult: Equatable {
    public var plugins: [Plugin]
    public var refused: [Refusal]

    public init(plugins: [Plugin], refused: [Refusal]) {
        self.plugins = plugins
        self.refused = refused
    }
}

public enum PluginScanner {
    public static func scan(_ folder: URL) throws -> ScanResult {
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var result = ScanResult(plugins: [], refused: [])
        for url in files {
            guard let text = try? String(contentsOf: url, encoding: .utf8),
                  let header = PluginHeader.read(text) else { continue }
            guard header.api == OpenspotVersion.api else {
                result.refused.append(Refusal(file: url.lastPathComponent, reason: "needs api \(header.api)"))
                continue
            }
            result.plugins.append(Plugin(name: header.name, api: header.api, url: url))
        }
        return result
    }
}
