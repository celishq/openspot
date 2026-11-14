import Foundation
import Synchronization

public struct SpotsFolder: Sendable {
    public struct Stamp: Equatable, Sendable {
        fileprivate let files: [String: [Int]]
        fileprivate let enabled: Set<String>
        fileprivate let disabled: Set<String>
        fileprivate let hosted: [Spot]
    }

    private static let coreName = "spots"
    private static let appName = "openspot.spot"
    private static let startingIDs: Set<String> = ["apps", "caffeinate", "color-picker", "emoji", "files", "links", "paste-screenshot", "settings", "snippets", "translate"]

    public let url: URL
    public let core: URL?
    public let enabled: Set<String>
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
    ) -> SpotsFolder {
        let core = environment["OPENSPOT_CORE"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
            ?? Bundle.main.resourceURL?.appendingPathComponent(coreName, isDirectory: true)
        let arrangement = enabled == nil || disabled == nil ? ConfigFile.standard(environment: environment, home: home).read().arrangement : nil
        let enabled = enabled ?? arrangement?.enabled ?? []
        let disabled = disabled ?? arrangement?.disabled ?? []
        let url: URL
        if let path = environment["OPENSPOT_SPOTS"], !path.isEmpty {
            url = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            url = config(environment: environment, home: home).appendingPathComponent(folderName, isDirectory: true)
            moveOldFolder(to: url)
        }
        let spots = SpotsFolder(url: url, core: core, enabled: enabled, disabled: disabled)
        try? spots.wrap()
        return spots
    }

    static let folderName = "spots"

    static func moveOldFolder(to url: URL) {
        let old = url.deletingLastPathComponent().appendingPathComponent("plugins", isDirectory: true)
        guard !FileManager.default.fileExists(atPath: url.path), FileManager.default.fileExists(atPath: old.path) else { return }
        try? FileManager.default.moveItem(at: old, to: url)
    }

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

    public func scan(hosted: [Spot] = []) throws -> ScanResult {
        var result = ScanResult(files: hosted.isEmpty ? [] : [SpotFile(id: "openspot", spots: hosted)], refused: [])
        for file in ((try? Self.sorted(in: url)) ?? []).filter(Self.isScript) {
            let target = SpotID(Self.stem(of: file.lastPathComponent)).folderName
            let reason = FileManager.default.fileExists(atPath: url.appendingPathComponent(target).appendingPathComponent(file.lastPathComponent).path)
                ? "\(file.lastPathComponent) is outside a spot folder, and \(target) has a file of that name. Move it into a spot folder of its own, such as \(Self.stem(of: file.lastPathComponent))-2.\(SpotPackage.fileExtension)."
                : "\(file.lastPathComponent) is outside a spot folder. Move it into \(target)."
            result.refused.append(ScanResult.Refusal(file: file.lastPathComponent, reason: reason))
        }
        let own = Self.files(in: core == nil ? try Self.spotFolders(in: url) : (try? Self.spotFolders(in: url)) ?? [])
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

    public func reads(_ path: String) -> Bool {
        let roots = [url.path, url.resolvingSymlinksInPath().path].map { $0.hasSuffix("/") ? String($0.dropLast()) : $0 }
        guard let root = roots.first(where: { path == $0 || path.hasPrefix($0 + "/") }) else { return false }
        let parts = path.dropFirst(root.count).split(separator: "/")
        return parts.count <= 2 && !parts.contains { $0.hasPrefix(".") }
    }

    private static let scans = Mutex<[String: (stamp: Stamp, result: ScanResult)]>([:])
    private static let choices = Mutex<[String: (stamp: Stamp, result: [Spot])]>([:])

    public func keptScan() throws -> ScanResult {
        let key = "\(url.path)\n\(core?.path ?? "")"
        let stamp = stamp()
        if let kept = Self.scans.withLock({ $0[key] }), kept.stamp == stamp { return kept.result }
        let result = try scan()
        Self.scans.withLock { $0[key] = (stamp, result) }
        return result
    }

    public func keptCoreChoices() -> [Spot] {
        guard let core else { return [] }
        let stamp = SpotsFolder(url: core).stamp()
        if let kept = Self.choices.withLock({ $0[core.path] }), kept.stamp == stamp { return kept.result }
        let result = coreChoices()
        Self.choices.withLock { $0[core.path] = (stamp, result) }
        return result
    }

    public func coreChoices() -> [Spot] {
        let commands = ScanResult(files: coreFiles().compactMap { try? SpotFile(file: $0.file, id: $0.id) }, refused: []).spots
        let opened = Set(commands.compactMap(\.opens))
        return commands.filter { !opened.contains($0.id) && $0.read?.seconds == nil }
    }

    public static func coreID(of spot: Spot) -> String {
        SpotID(file: spot.url).name
    }

    public func fileID(of spot: Spot) -> String {
        isCore(spot) ? Self.coreID(of: spot) : SpotID(file: spot.url).description
    }

    public func isFirstLaunch(config: ConfigFile) -> Bool {
        guard !FileManager.default.fileExists(atPath: config.url.path) else { return false }
        return ((try? SpotsFolder(url: url).scan())?.spots ?? []).isEmpty
    }

    public func startingSpots() -> [String] {
        coreChoices().map(Self.coreID(of:)).filter(Self.startingIDs.contains)
    }

    public func isCore(_ spot: Spot) -> Bool {
        guard let core, spot.host == nil, !spot.isBuiltIn else { return false }
        return spot.url.standardizedFileURL.path.hasPrefix(core.standardizedFileURL.path + "/")
    }

    public func remove(_ spot: Spot, discard: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }) throws {
        guard spot.host == nil, !spot.isBuiltIn, !isCore(spot) else { throw SpotError.fault("\(spot.name) comes with Openspot, so it cannot be removed.") }
        let folder = spot.url.deletingLastPathComponent()
        var own = [spot.url] + (SwiftProgram.file(beside: spot.url).map { [$0] } ?? [])
        if let view = spot.view.map(URL.init(fileURLWithPath:)), view.deletingLastPathComponent() == folder {
            own += [view, URL(fileURLWithPath: ViewLibrary.path(beside: view.path))].filter { FileManager.default.fileExists(atPath: $0.path) }
        }
        let names = Set(own.map(\.lastPathComponent))
        let others = ((try? Self.sorted(in: folder)) ?? []).filter { !names.contains($0.lastPathComponent) && Self.isScript($0) }
        guard others.isEmpty, folder.pathExtension == SpotPackage.fileExtension else { return try own.forEach(discard) }
        try discard(folder)
    }

    public func wrap() throws {
        let entries = try Self.sorted(in: url)
        var loose = entries.filter { !Self.isFolder($0) }
        for entry in entries where entry.pathExtension != SpotPackage.fileExtension && Self.isFolder(entry) && ((try? Self.sorted(in: entry)) ?? []).contains(where: Self.isScript) {
            let target = url.appendingPathComponent(entry.lastPathComponent + "." + SpotPackage.fileExtension, isDirectory: true)
            if !FileManager.default.fileExists(atPath: target.path) { try FileManager.default.moveItem(at: entry, to: target) }
        }
        let scripts = loose.filter(Self.isScript)
        for script in scripts where loose.contains(script) {
            let name = Self.stem(of: script.lastPathComponent)
            var group = loose.filter { Self.stem(of: $0.lastPathComponent) == name }
            if let view = SpotHeader(url: script).block.value("view"), !view.contains("/") {
                let names = [view, (ViewLibrary.path(beside: view) as NSString).lastPathComponent]
                group += loose.filter { names.contains($0.lastPathComponent) && !group.contains($0) }
            }
            let target = url.appendingPathComponent(name + "." + SpotPackage.fileExtension, isDirectory: true)
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            for file in group {
                loose.removeAll { $0 == file }
                let place = url.appendingPathComponent(Self.wrapped(file.lastPathComponent, into: name))
                if !FileManager.default.fileExists(atPath: place.path) { try FileManager.default.moveItem(at: file, to: place) }
            }
        }
    }

    static func wrapped(_ path: String, into name: String? = nil) -> String {
        let parts = path.split(separator: "/", maxSplits: 1).map(String.init)
        guard let first = parts.first, (first as NSString).pathExtension != SpotPackage.fileExtension else { return path }
        if parts.count > 1 { return SpotID(first).folderName + "/" + parts[1] }
        guard first.contains(".") || name != nil else { return SpotID(first).folderName }
        let stem = name ?? Self.stem(of: first)
        let file = switch first {
        case stem + "." + SpotListing.readmeExtension: SpotListing.readmeName
        case stem + SpotListing.previewSuffix: SpotListing.previewName
        default: first
        }
        return SpotID(stem).folderName + "/" + file
    }

    private static func stem(of name: String) -> String {
        String(name.prefix { $0 != "." })
    }

    private static func isScript(_ url: URL) -> Bool {
        !isFolder(url) && SpotFile.runs(url)
    }

    private static func isFolder(_ url: URL) -> Bool {
        var isFolder: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) && isFolder.boolValue
    }

    private static func read(_ file: URL, id: String, into result: inout ScanResult, isDated: Bool = false, isReadOnly: Bool = false) {
        do {
            guard let loaded = try SpotFile(file: file, id: id) else { return }
            let added = isDated ? (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) : nil
            let spots = loaded.spots.map { command in
                let dated = added.map(command.added(at:)) ?? command
                return isReadOnly ? dated.builtIn() : dated
            }
            result.files.append(SpotFile(id: id, spots: spots))
        } catch {
            let reason = (error as? SpotError)?.reason ?? String(describing: error)
            result.refused.append(ScanResult.Refusal(file: id, reason: reason))
        }
    }

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

    private func coreFiles() -> [(file: URL, id: String)] {
        guard let core, let folders = try? Self.spotFolders(in: core) else { return [] }
        return Self.files(in: folders.filter { $0.lastPathComponent != Self.appName })
    }

    private func appFiles() -> [(file: URL, id: String)] {
        guard let folder = core?.appendingPathComponent(Self.appName, isDirectory: true), Self.isFolder(folder) else { return [] }
        return Self.files(in: [folder])
    }

    private static func spotFolders(in folder: URL) throws -> [URL] {
        try sorted(in: folder).filter { $0.pathExtension == SpotPackage.fileExtension && isFolder($0) }
    }

    private static func files(in folders: [URL]) -> [(file: URL, id: String)] {
        folders.flatMap { folder in ((try? sorted(in: folder)) ?? []).filter { !isFolder($0) }.map { ($0, SpotID(file: $0).description) } }
    }

    private static func entries(of folder: String) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []).map { folder + "/" + $0 }
    }

    private static func state(of path: String) -> [Int] {
        var info = stat()
        guard stat(path, &info) == 0 else { return [] }
        return [
            Int(info.st_mode & S_IFMT), Int(info.st_dev), Int(info.st_ino), Int(info.st_mode), Int(info.st_size),
            info.st_ctimespec.tv_sec, info.st_ctimespec.tv_nsec, info.st_mtimespec.tv_sec, info.st_mtimespec.tv_nsec
        ]
    }

    private static func sorted(in folder: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { !$0.hasPrefix(".") }.sorted()
            .map { folder.appendingPathComponent($0) }
    }
}
