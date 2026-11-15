import Foundation

public struct SpotsFolder: Sendable {
    private static let coreName = "spots"
    static let appName = "openspot.spot"
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
        }
        return SpotsFolder(url: url, core: core, enabled: enabled, disabled: disabled)
    }

    static let folderName = "spots"

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
        try KeptScan.shared.load(self).result(enabled: enabled, disabled: disabled, hosted: hosted)
    }

    static func looseReason(_ file: URL, in url: URL) -> String {
        let target = SpotID(stem(of: file.lastPathComponent)).folderName
        return FileManager.default.fileExists(atPath: url.appendingPathComponent(target).appendingPathComponent(file.lastPathComponent).path)
            ? "\(file.lastPathComponent) is outside a spot folder, and \(target) has a file of that name. Move it into a spot folder of its own, such as \(stem(of: file.lastPathComponent))-2.\(SpotPackage.fileExtension)."
            : "\(file.lastPathComponent) is outside a spot folder. Move it into \(target)."
    }

    public func reads(_ path: String) -> Bool {
        let roots = [url.path, url.resolvingSymlinksInPath().path].map { $0.hasSuffix("/") ? String($0.dropLast()) : $0 }
        guard let root = roots.first(where: { path == $0 || path.hasPrefix($0 + "/") }) else { return false }
        let parts = path.dropFirst(root.count).split(separator: "/")
        return parts.count <= 2 && !parts.contains { $0.hasPrefix(".") }
    }

    public func coreChoices() -> [Spot] {
        core == nil ? [] : KeptScan.shared.load(self).coreChoices
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
        let files = SpotFiles(folder: folder)
        let own = files.own(of: spot.url.path)
        guard files.scripts.allSatisfy(own.contains), folder.pathExtension == SpotPackage.fileExtension else {
            return try own.map(URL.init(fileURLWithPath:)).forEach(discard)
        }
        try discard(folder)
    }

    static func wrap(_ url: URL) throws {
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
            if let view = SpotHeader(url: script).block.value(HeaderKey.view), !view.contains("/") {
                group += loose.filter { ($0.lastPathComponent == view || ViewLibrary.isLibrary($0.lastPathComponent, of: view)) && !group.contains($0) }
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

    private static func wrapped(_ file: String, into name: String) -> String {
        SpotID(name).folderName + "/" + (file == name + "." + SpotReadme.fileExtension ? SpotReadme.name : file)
    }

    private static func stem(of name: String) -> String {
        String(name.prefix { $0 != "." })
    }

    static func isScript(_ url: URL) -> Bool {
        !isFolder(url) && SpotFile.runs(url)
    }

    private static func isFolder(_ url: URL) -> Bool {
        var isFolder: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) && isFolder.boolValue
    }

    private static func sorted(in folder: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { !$0.hasPrefix(".") }.sorted()
            .map { folder.appendingPathComponent($0) }
    }
}
