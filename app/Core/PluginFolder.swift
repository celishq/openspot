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
        return PluginFolder(url: config(environment: environment, home: home).appendingPathComponent("plugins", isDirectory: true))
    }

    /// The folder that holds the plugins folder and the data of plugins.
    /// A Debug build names its own folder, so that its plugins and config stay out of the real ones.
    static func config(
        environment: [String: String],
        home: URL,
        devState: String? = Bundle.main.object(forInfoDictionaryKey: "OpenspotDevState") as? String
    ) -> URL {
        for path in [environment["OPENSPOT_CONFIG"], devState] {
            if let path, !path.isEmpty { return URL(fileURLWithPath: path, isDirectory: true).standardized }
        }
        return home.appendingPathComponent(".config/openspot", isDirectory: true)
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
                    result.plugins.append(Plugin(id: id, commands: commands))
                } catch {
                    let reason = (error as? PluginError)?.reason ?? String(describing: error)
                    result.refused.append(Refusal(file: id, reason: reason))
                }
            }
        }
        result.removeWidgetsWithLostParts()
        return result
    }

    /// Takes the file of a spot and its program out of the folder. They go to the Trash, and the other files of its folder stay.
    public func remove(_ command: PluginCommand, discard: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }) throws {
        guard command.shipped == nil else { throw PluginError.fault("\(command.name) comes with Openspot, so it cannot be removed.") }
        try discard(command.url)
        if let program = SwiftProgram.file(beside: command.url) { try discard(program) }
    }

    private static func sorted(in folder: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
