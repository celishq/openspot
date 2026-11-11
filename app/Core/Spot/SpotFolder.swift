import Foundation
import Synchronization

public struct SpotFolder: Sendable {
    /// What a scan reads: the identity, mode, size and times of each file through its links, the spots that are on or off
    /// and the sheets of the app. An equal stamp gives an equal scan, because a write, a change of mode and a move each change
    /// the change time of a file.
    public struct Stamp: Equatable, Sendable {
        fileprivate let files: [String: [Int]]
        fileprivate let enabled: Set<String>
        fileprivate let disabled: Set<String>
        fileprivate let hosted: [Spot]
    }

    private static let coreName = "spots"
    /// The folder of the core that holds the spots of the app itself, which are always on.
    private static let appName = "openspot"
    /// The core spots that start on: each reads only local data, and only at a person's act or when the panel opens.
    private static let startingIDs: Set<String> = ["apps", "caffeinate", "color-picker", "emoji", "files", "links", "paste-screenshot", "settings", "snippets", "translate"]

    public let url: URL
    /// The folder of the core spots in the app. A scan skips it when it does not exist.
    public let core: URL?
    /// The IDs of the core spots that the person turned on.
    public let enabled: Set<String>
    /// The IDs of the spots of the folder that the person turned off. Their files stay, and a scan does not load them.
    public let disabled: Set<String>

    public init(url: URL, core: URL? = nil, enabled: Set<String> = [], disabled: Set<String> = []) {
        self.url = url
        self.core = core
        self.enabled = enabled
        self.disabled = disabled
    }

    public static func standard(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        enabled: Set<String>? = nil,
        disabled: Set<String>? = nil
    ) -> SpotFolder {
        let core = environment["OPENSPOT_CORE"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
            ?? Bundle.main.resourceURL?.appendingPathComponent(coreName, isDirectory: true)
        let arrangement = enabled == nil || disabled == nil ? ConfigFile.standard(environment: environment, home: home).read().arrangement : nil
        let enabled = enabled ?? arrangement?.enabled ?? []
        let disabled = disabled ?? arrangement?.disabled ?? []
        if let path = environment["OPENSPOT_PLUGINS"], !path.isEmpty {
            return SpotFolder(url: URL(fileURLWithPath: path, isDirectory: true), core: core, enabled: enabled, disabled: disabled)
        }
        let url = config(environment: environment, home: home).appendingPathComponent("plugins", isDirectory: true)
        return SpotFolder(url: url, core: core, enabled: enabled, disabled: disabled)
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

    /// Reads each executable and widget file that is not off, at the top of the folder or one folder down, after the sheets
    /// of the app. Then it reads each core spot that is on, each core file that a spot needs, and the spots of the app, a
    /// source that a person cannot change. A file in the folder hides a core file or a spot of the app with the same ID.
    public func scan(hosted: [Spot] = []) throws -> ScanResult {
        var result = ScanResult(files: hosted.isEmpty ? [] : [SpotFile(id: "openspot", spots: hosted)], refused: [])
        let own = Self.files(in: core == nil ? try Self.sorted(in: url) : (try? Self.sorted(in: url)) ?? [])
        let ownIDs = Set(own.map(\.id))
        for (file, id) in own where !disabled.contains(id) {
            Self.read(file, id: id, into: &result, isDated: true)
        }
        for (file, id) in wantedCoreFiles(after: result, hiding: ownIDs) {
            Self.read(file, id: id, into: &result)
        }
        for (file, id) in appFiles() where !ownIDs.contains(id) {
            Self.read(file, id: id, into: &result, isReadOnly: true)
        }
        result.removeWidgetsWithLostParts()
        result.keepOpenedOffTheGrid()
        return result
    }

    /// The stamp of all that a scan reads: each entry at the top of the folder and of the core folder, and each entry one
    /// folder down. A hidden file is in it too, so it can only ask for a scan that changes nothing.
    public func stamp(hosted: [Spot] = []) -> Stamp {
        var files: [String: [Int]] = [:]
        for folder in [url.path] + (core.map { [$0.path] } ?? []) {
            for entry in Self.entries(of: folder) {
                let state = Self.state(of: entry)
                files[entry] = state
                guard state.first == Int(S_IFDIR) else { continue }
                for file in Self.entries(of: entry) { files[file] = Self.state(of: file) }
            }
        }
        return Stamp(files: files, enabled: enabled, disabled: disabled, hosted: hosted)
    }

    /// Whether a scan reads this path: the folder, or an entry at its top or one folder down that is not hidden.
    public func reads(_ path: String) -> Bool {
        let roots = [url.path, url.resolvingSymlinksInPath().path].map { $0.hasSuffix("/") ? String($0.dropLast()) : $0 }
        guard let root = roots.first(where: { path == $0 || path.hasPrefix($0 + "/") }) else { return false }
        let parts = path.dropFirst(root.count).split(separator: "/")
        return parts.count <= 2 && !parts.contains { $0.hasPrefix(".") }
    }

    /// The last scan of each folder and the stamp that it came from, by the paths of the folder and its core folder.
    private static let scans = Mutex<[String: (stamp: Stamp, result: ScanResult)]>([:])
    /// The last core choices of each core folder and the stamp of that folder.
    private static let choices = Mutex<[String: (stamp: Stamp, result: [Spot])]>([:])

    /// The scan of the folder, kept from the last one while its stamp holds, so that a look at a folder that did not change
    /// reads no file.
    public func keptScan() throws -> ScanResult {
        let key = "\(url.path)\n\(core?.path ?? "")"
        let stamp = stamp()
        if let kept = Self.scans.withLock({ $0[key] }), kept.stamp == stamp { return kept.result }
        let result = try scan()
        Self.scans.withLock { $0[key] = (stamp, result) }
        return result
    }

    /// The core choices, kept from the last look while no file of the core folder changed.
    public func keptCoreChoices() -> [Spot] {
        guard let core else { return [] }
        let stamp = SpotFolder(url: core).stamp()
        if let kept = Self.choices.withLock({ $0[core.path] }), kept.stamp == stamp { return kept.result }
        let result = coreChoices()
        Self.choices.withLock { $0[core.path] = (stamp, result) }
        return result
    }

    /// The core spots that a person can turn on. A part of a widget, such as a metric that it places or a sheet off the grid
    /// that it opens, is not one: it comes with its widget.
    public func coreChoices() -> [Spot] {
        let commands = ScanResult(files: coreFiles().compactMap { try? SpotFile(file: $0.file, id: $0.id) }, refused: []).spots
        let opened = Set(commands.compactMap(\.opens))
        return commands.filter { !opened.contains($0.id) && $0.read?.seconds == nil }
    }

    /// The ID that turns a core command on: the name of its file, which a widget shares with the others in that file.
    public static func coreID(of spot: Spot) -> String {
        spot.url.deletingPathExtension().lastPathComponent
    }

    /// The ID that turns a spot on or off: the core ID of a core spot, or the place of its file in the folder, with no
    /// extension.
    public func fileID(of spot: Spot) -> String {
        guard !isCore(spot) else { return Self.coreID(of: spot) }
        let parent = spot.url.deletingLastPathComponent().standardizedFileURL
        let stem = spot.url.deletingPathExtension().lastPathComponent
        return parent.path == url.standardizedFileURL.path ? stem : "\(parent.lastPathComponent)/\(stem)"
    }

    /// Whether the app runs for the first time here: no config file, and no spot in the folder.
    public func isFirstLaunch(config: ConfigFile) -> Bool {
        guard !FileManager.default.fileExists(atPath: config.url.path) else { return false }
        return ((try? SpotFolder(url: url).scan())?.spots ?? []).isEmpty
    }

    /// The IDs of the core spots that a first launch turns on, in the order of the grid.
    public func startingSpots() -> [String] {
        coreChoices().map(Self.coreID(of:)).filter(Self.startingIDs.contains)
    }

    /// Whether a command runs from the core folder of the app.
    public func isCore(_ spot: Spot) -> Bool {
        guard let core, spot.host == nil, !spot.isBuiltIn else { return false }
        return spot.url.standardizedFileURL.path.hasPrefix(core.standardizedFileURL.path + "/")
    }

    /// Takes the file of a spot, its program, and its view with the view's library out of the folder. They go to the Trash,
    /// and the other files of its folder stay.
    public func remove(_ spot: Spot, discard: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }) throws {
        guard spot.host == nil, !spot.isBuiltIn, !isCore(spot) else { throw SpotError.fault("\(spot.name) comes with Openspot, so it cannot be removed.") }
        try discard(spot.url)
        if let program = SwiftProgram.file(beside: spot.url) { try discard(program) }
        guard let view = spot.view.map(URL.init(fileURLWithPath:)), view.deletingLastPathComponent() == spot.url.deletingLastPathComponent() else { return }
        for file in [view, URL(fileURLWithPath: ViewLibrary.path(beside: view.path))] where FileManager.default.fileExists(atPath: file.path) {
            try discard(file)
        }
    }

    /// Adds what one file gives, and reports its fault. A dated file takes its place in the grid by the date it was added,
    /// and a read-only one comes with the app.
    private static func read(_ file: URL, id: String, into result: inout ScanResult, isDated: Bool = false, isReadOnly: Bool = false) {
        do {
            guard let plugin = try SpotFile(file: file, id: id) else { return }
            let added = isDated ? (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) : nil
            let spots = plugin.spots.map { command in
                let dated = added.map(command.added(at:)) ?? command
                return isReadOnly ? dated.builtIn() : dated
            }
            result.files.append(SpotFile(id: id, spots: spots))
        } catch {
            let reason = (error as? SpotError)?.reason ?? String(describing: error)
            result.refused.append(ScanResult.Refusal(file: id, reason: reason))
        }
    }

    /// The core files to load: each one that is on, and each one that a loaded spot places or opens.
    private func wantedCoreFiles(after result: ScanResult, hiding ownIDs: Set<String>) -> [(file: URL, id: String)] {
        let files = coreFiles().filter { !ownIDs.contains($0.id) }
        var wanted = Set(files.map(\.id).filter(enabled.contains))
        var waiting = result.files.flatMap(\.spots) + files.filter { wanted.contains($0.id) }.flatMap { Self.spots(of: $0) }
        while let command = waiting.popLast() {
            for id in command.places + (command.opens.map { [$0] } ?? []) where !wanted.contains(id) {
                guard let file = files.first(where: { $0.id == id }) else { continue }
                wanted.insert(id)
                waiting += Self.spots(of: file)
            }
        }
        return files.filter { wanted.contains($0.id) }
    }

    private static func spots(of file: (file: URL, id: String)) -> [Spot] {
        ((try? SpotFile(file: file.file, id: file.id)) ?? nil)?.spots ?? []
    }

    /// The files at the top of the core folder, each a spot that the person turns on or off.
    private func coreFiles() -> [(file: URL, id: String)] {
        guard let core, let files = try? Self.sorted(in: core) else { return [] }
        return files.filter { !$0.hasDirectoryPath && (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true }
            .map { ($0, $0.deletingPathExtension().lastPathComponent) }
    }

    /// The files of the spots of the app, in the `openspot` folder of the core, by their IDs as the folder of a person gives
    /// them.
    private func appFiles() -> [(file: URL, id: String)] {
        var isFolder: ObjCBool = false
        guard let folder = core?.appendingPathComponent(Self.appName, isDirectory: true),
              FileManager.default.fileExists(atPath: folder.path, isDirectory: &isFolder), isFolder.boolValue else { return [] }
        return Self.files(in: [folder])
    }

    /// The files of these entries of a folder, each at the top or one folder down, by their IDs: the name with no extension,
    /// after the name of its folder one down.
    private static func files(in entries: [URL]) -> [(file: URL, id: String)] {
        entries.flatMap { entry in
            var isFolder: ObjCBool = false
            FileManager.default.fileExists(atPath: entry.path, isDirectory: &isFolder)
            let files = isFolder.boolValue ? (try? sorted(in: entry)) ?? [] : [entry]
            return files.map { file in
                let stem = file.deletingPathExtension().lastPathComponent
                return (file, isFolder.boolValue ? "\(entry.lastPathComponent)/\(stem)" : stem)
            }
        }
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
