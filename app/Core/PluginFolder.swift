import Foundation

public struct PluginFolder: Sendable {
    private static let coreName = "spots"

    public let url: URL
    /// The folder of the core spots in the app. A scan skips it when it does not exist.
    public let core: URL?
    /// The IDs of the core spots that the person turned on.
    public let enabled: Set<String>

    public init(url: URL, core: URL? = nil, enabled: Set<String> = []) {
        self.url = url
        self.core = core
        self.enabled = enabled
    }

    public static func standard(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> PluginFolder {
        let core = Bundle.main.resourceURL?.appendingPathComponent(coreName, isDirectory: true)
        let enabled = ConfigFile.standard(environment: environment, home: home).read().arrangement.enabled
        if let path = environment["OPENSPOT_PLUGINS"], !path.isEmpty {
            return PluginFolder(url: URL(fileURLWithPath: path, isDirectory: true), core: core, enabled: enabled)
        }
        let url = config(environment: environment, home: home).appendingPathComponent("plugins", isDirectory: true)
        return PluginFolder(url: url, core: core, enabled: enabled)
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
    /// Then it reads each core spot that is on, and each core file that a spot needs. When two commands share a key, the
    /// first keeps it. A file in the folder hides a core file with the same ID.
    public func scan(shipped: [PluginCommand] = []) throws -> ScanResult {
        var result = ScanResult(plugins: shipped.isEmpty ? [] : [Plugin(id: "openspot", commands: shipped)], refused: [])
        var taken = Set(shipped.compactMap(\.key?.name))
        let entries = core == nil ? try Self.sorted(in: url) : (try? Self.sorted(in: url)) ?? []
        var ownIDs = Set<String>()
        for entry in entries {
            var isFolder: ObjCBool = false
            FileManager.default.fileExists(atPath: entry.path, isDirectory: &isFolder)
            let files = isFolder.boolValue ? (try? Self.sorted(in: entry)) ?? [] : [entry]
            for file in files {
                let stem = file.deletingPathExtension().lastPathComponent
                let id = isFolder.boolValue ? "\(entry.lastPathComponent)/\(stem)" : stem
                ownIDs.insert(id)
                Self.read(file, id: id, into: &result, taken: &taken)
            }
        }
        for (file, id) in wantedCoreFiles(after: result, hiding: ownIDs) {
            Self.read(file, id: id, into: &result, taken: &taken)
        }
        result.removeWidgetsWithLostParts()
        return result
    }

    /// The core spots that a person can turn on. A core file with no card, such as a metric that a widget places, is not one.
    public func coreChoices() -> [PluginCommand] {
        ScanResult(plugins: coreFiles().compactMap { try? Plugin(file: $0.file, id: $0.id) }, refused: []).commands
    }

    /// The ID that turns a core command on: the name of its file, which a widget shares with the others in that file.
    public static func coreID(of command: PluginCommand) -> String {
        command.url.deletingPathExtension().lastPathComponent
    }

    /// Whether the app runs for the first time here: no config file, and no spot in the folder.
    public func isFirstLaunch(config: ConfigFile) -> Bool {
        guard !FileManager.default.fileExists(atPath: config.url.path) else { return false }
        return ((try? PluginFolder(url: url).scan())?.commands ?? []).isEmpty
    }

    /// Whether a command runs from the core folder of the app.
    public func isCore(_ command: PluginCommand) -> Bool {
        guard let core, command.shipped == nil else { return false }
        return command.url.standardizedFileURL.path.hasPrefix(core.standardizedFileURL.path + "/")
    }

    /// Takes the file of a spot out of the folder. It goes to the Trash, and the other files of its folder stay.
    public func remove(_ command: PluginCommand, discard: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }) throws {
        guard command.shipped == nil, !isCore(command) else { throw PluginError.fault("\(command.name) comes with Openspot, so it cannot be removed.") }
        try discard(command.url)
    }

    /// Adds what one file gives, and reports a fault or a key that is taken.
    private static func read(_ file: URL, id: String, into result: inout ScanResult, taken: inout Set<String>) {
        do {
            guard let plugin = try Plugin(file: file, id: id) else { return }
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

    /// The core files to load: each one that is on, and each one that a loaded spot places or opens.
    private func wantedCoreFiles(after result: ScanResult, hiding ownIDs: Set<String>) -> [(file: URL, id: String)] {
        let files = coreFiles().filter { !ownIDs.contains($0.id) }
        var wanted = Set(files.map(\.id).filter(enabled.contains))
        var waiting = result.plugins.flatMap(\.commands) + files.filter { wanted.contains($0.id) }.flatMap { Self.commands(of: $0) }
        while let command = waiting.popLast() {
            for id in command.places + (command.opens.map { [$0] } ?? []) where !wanted.contains(id) {
                guard let file = files.first(where: { $0.id == id }) else { continue }
                wanted.insert(id)
                waiting += Self.commands(of: file)
            }
        }
        return files.filter { wanted.contains($0.id) }
    }

    private static func commands(of file: (file: URL, id: String)) -> [PluginCommand] {
        ((try? Plugin(file: file.file, id: file.id)) ?? nil)?.commands ?? []
    }

    private func coreFiles() -> [(file: URL, id: String)] {
        guard let core, let files = try? Self.sorted(in: core) else { return [] }
        return files.map { ($0, $0.deletingPathExtension().lastPathComponent) }
    }

    private static func sorted(in folder: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
