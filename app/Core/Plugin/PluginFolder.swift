import Foundation

public struct PluginFolder: Sendable {
    /// What a scan reads: the identity, mode, size and times of each file through its links, the core spots that are on and
    /// the shipped commands. An equal stamp gives an equal scan, because a write, a change of mode and a move each change
    /// the change time of a file.
    public struct Stamp: Equatable, Sendable {
        fileprivate let files: [String: [Int]]
        fileprivate let enabled: Set<String>
        fileprivate let shipped: [Spot]
    }

    private static let coreName = "spots"
    /// The core spots that start on: each reads only local data, and only at a person's act or when the panel opens.
    private static let startingIDs: Set<String> = ["apps", "caffeinate", "color-picker", "emoji", "files", "links", "paste-screenshot", "settings", "snippets", "translate"]

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
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        enabled: Set<String>? = nil
    ) -> PluginFolder {
        let core = Bundle.main.resourceURL?.appendingPathComponent(coreName, isDirectory: true)
        let enabled = enabled ?? ConfigFile.standard(environment: environment, home: home).read().arrangement.enabled
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
    /// first keeps it. A file in the folder hides a core file with the same ID. With Settings among the shipped commands,
    /// a script that lists commands and has no read opens to their keys.
    public func scan(shipped: [Spot] = []) throws -> ScanResult {
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
                Self.read(file, id: id, into: &result, taken: &taken, isDated: true)
            }
        }
        for (file, id) in wantedCoreFiles(after: result, hiding: ownIDs) {
            Self.read(file, id: id, into: &result, taken: &taken)
        }
        result.removeWidgetsWithLostParts()
        result.keepOpenedOffTheGrid()
        if let settings = shipped.lazy.compactMap({ if case .settings(let settings)? = $0.shipped { settings } else { nil } }).first {
            result.listKeys(with: settings)
        }
        return result
    }

    /// The stamp of all that a scan reads: each entry at the top of the folder and of the core folder, and each entry one
    /// folder down. A hidden file is in it too, so it can only ask for a scan that changes nothing.
    public func stamp(shipped: [Spot] = []) -> Stamp {
        var files: [String: [Int]] = [:]
        for folder in [url.path] + (core.map { [$0.path] } ?? []) {
            for entry in Self.entries(of: folder) {
                let state = Self.state(of: entry)
                files[entry] = state
                guard state.first == Int(S_IFDIR) else { continue }
                for file in Self.entries(of: entry) { files[file] = Self.state(of: file) }
            }
        }
        return Stamp(files: files, enabled: enabled, shipped: shipped)
    }

    /// The core spots that a person can turn on. A part of a widget, such as a metric that it places or a sheet off the grid
    /// that it opens, is not one: it comes with its widget.
    public func coreChoices() -> [Spot] {
        let commands = ScanResult(plugins: coreFiles().compactMap { try? Plugin(file: $0.file, id: $0.id) }, refused: []).commands
        let opened = Set(commands.compactMap(\.opens))
        return commands.filter { !opened.contains($0.id) && ($0.read?.seconds == nil || $0.key != nil) }
    }

    /// The ID that turns a core command on: the name of its file, which a widget shares with the others in that file.
    public static func coreID(of command: Spot) -> String {
        command.url.deletingPathExtension().lastPathComponent
    }

    /// Whether the app runs for the first time here: no config file, and no spot in the folder.
    public func isFirstLaunch(config: ConfigFile) -> Bool {
        guard !FileManager.default.fileExists(atPath: config.url.path) else { return false }
        return ((try? PluginFolder(url: url).scan())?.commands ?? []).isEmpty
    }

    /// The IDs of the core spots that a first launch turns on, in the order of the grid.
    public func startingSpots() -> [String] {
        coreChoices().map(Self.coreID(of:)).filter(Self.startingIDs.contains)
    }

    /// Whether a command runs from the core folder of the app.
    public func isCore(_ command: Spot) -> Bool {
        guard let core, command.shipped == nil else { return false }
        return command.url.standardizedFileURL.path.hasPrefix(core.standardizedFileURL.path + "/")
    }

    /// Takes the file of a spot, its program, and its view with the view's library out of the folder. They go to the Trash,
    /// and the other files of its folder stay.
    public func remove(_ command: Spot, discard: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }) throws {
        guard command.shipped == nil, !isCore(command) else { throw PluginError.fault("\(command.name) comes with Openspot, so it cannot be removed.") }
        try discard(command.url)
        if let program = SwiftProgram.file(beside: command.url) { try discard(program) }
        guard let view = command.view.map(URL.init(fileURLWithPath:)), view.deletingLastPathComponent() == command.url.deletingLastPathComponent() else { return }
        for file in [view, URL(fileURLWithPath: ViewLibrary.path(beside: view.path))] where FileManager.default.fileExists(atPath: file.path) {
            try discard(file)
        }
    }

    /// Adds what one file gives, and reports a fault or a key that is taken. A dated file takes its place in the grid by the
    /// date it was added.
    private static func read(_ file: URL, id: String, into result: inout ScanResult, taken: inout Set<String>, isDated: Bool = false) {
        do {
            guard let plugin = try Plugin(file: file, id: id) else { return }
            let added = isDated ? (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) : nil
            let commands = plugin.commands.map { command -> Spot in
                let command = added.map(command.added(at:)) ?? command
                guard let key = command.key, !taken.insert(key.name).inserted else { return command }
                result.refused.append(ScanResult.Refusal(file: id, reason: "\(command.name) cannot use key \(key.name), because another command has it"))
                return command.withoutKey()
            }
            result.plugins.append(Plugin(id: id, commands: commands))
        } catch {
            let reason = (error as? PluginError)?.reason ?? String(describing: error)
            result.refused.append(ScanResult.Refusal(file: id, reason: reason))
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

    private static func commands(of file: (file: URL, id: String)) -> [Spot] {
        ((try? Plugin(file: file.file, id: file.id)) ?? nil)?.commands ?? []
    }

    private func coreFiles() -> [(file: URL, id: String)] {
        guard let core, let files = try? Self.sorted(in: core) else { return [] }
        return files.map { ($0, $0.deletingPathExtension().lastPathComponent) }
    }

    private static func entries(of folder: String) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []).map { folder + "/" + $0 }
    }

    /// The kind, identity, mode, size, change time and modification time of a file, through its links.
    private static func state(of path: String) -> [Int] {
        var info = stat()
        guard stat(path, &info) == 0 else { return [] }
        return [
            Int(info.st_mode & S_IFMT), Int(info.st_dev), Int(info.st_ino), Int(info.st_mode), Int(info.st_size),
            info.st_ctimespec.tv_sec, info.st_ctimespec.tv_nsec, info.st_mtimespec.tv_sec, info.st_mtimespec.tv_nsec
        ]
    }

    private static func sorted(in folder: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
