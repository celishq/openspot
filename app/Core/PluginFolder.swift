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

    /// Reads each plugin in the folder. When two commands share a key, the first keeps it.
    public func scan() throws -> ScanResult {
        let folders = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var result = ScanResult(plugins: [], refused: [])
        var taken: Set<String> = []
        for folder in folders {
            let manifest = folder.appendingPathComponent("manifest.toml")
            guard let text = try? String(contentsOf: manifest, encoding: .utf8) else { continue }
            do {
                let plugin = try Plugin(manifest: text, url: folder)
                let commands = plugin.commands.map { command -> PluginCommand in
                    guard let key = command.key, !taken.insert(key.name).inserted else { return command }
                    result.refused.append(Refusal(
                        file: folder.lastPathComponent,
                        reason: "\(command.name) cannot use key \(key.name), because another command has it"
                    ))
                    return command.withoutKey()
                }
                result.plugins.append(Plugin(name: plugin.name, api: plugin.api, url: folder, commands: commands))
            } catch {
                let reason = (error as? PluginError)?.reason ?? String(describing: error)
                result.refused.append(Refusal(file: folder.lastPathComponent, reason: reason))
            }
        }
        return result
    }
}
