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
        let config = environment["OPENSPOT_CONFIG"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
            ?? home.appendingPathComponent(".config/openspot", isDirectory: true)
        return PluginFolder(url: config.appendingPathComponent("plugins", isDirectory: true))
    }

    /// Reads each executable and widget file, at the top of the folder or one folder down, after the shipped commands.
    /// When two commands share a key, the first keeps it.
    public func scan(shipped: [PluginCommand] = []) throws -> ScanResult {
        var result = ScanResult(plugins: shipped.isEmpty ? [] : [Plugin(id: "openspot", commands: shipped)], refused: [])
        var taken = Set(shipped.compactMap(\.key?.name))
        for entry in try Self.sorted(in: url) {
            var isFolder: ObjCBool = false
            FileManager.default.fileExists(atPath: entry.path, isDirectory: &isFolder)
            let files = isFolder.boolValue ? (try? Self.sorted(in: entry)) ?? [] : [entry]
            for file in files {
                let stem = file.deletingPathExtension().lastPathComponent
                let id = isFolder.boolValue ? "\(entry.lastPathComponent)/\(stem)" : stem
                do {
                    guard let plugin = try Plugin(file: file, id: id) else { continue }
                    let commands = plugin.commands.map { command -> PluginCommand in
                        guard let key = command.key, !taken.insert(key.name).inserted else { return command }
                        result.refused.append(Refusal(file: id, reason: "\(command.name) cannot use key \(key.name), because another command has it"))
                        return command.withoutKey()
                    }
                    result.plugins.append(Plugin(id: id, commands: commands, metrics: plugin.metrics))
                } catch {
                    let reason = (error as? PluginError)?.reason ?? String(describing: error)
                    result.refused.append(Refusal(file: id, reason: reason))
                }
            }
        }
        result.removeWidgetsWithLostParts()
        return result
    }

    private static func sorted(in folder: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
