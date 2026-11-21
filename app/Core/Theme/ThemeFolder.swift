import Foundation

public struct ThemeFolder: Sendable {
    public static let builtInName = "Openspot"
    public static let liquidName = "Openspot Liquid"
    public static let builtInURL = Bundle.main.url(forResource: "theme", withExtension: "toml", subdirectory: "Themes/openspot.theme")

    public let url: URL
    public let builtIn: URL?
    public let config: ConfigFile
    public let macOS: Int

    public init(url: URL, builtIn: URL?, config: ConfigFile, macOS: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion) {
        self.url = url
        self.builtIn = builtIn
        self.config = config
        self.macOS = macOS
    }

    public init(config: ConfigFile, builtIn: URL? = builtInURL) {
        self.init(url: config.url.deletingLastPathComponent().appendingPathComponent("themes"), builtIn: builtIn, config: config)
    }

    public static func standard(environment: [String: String], builtIn: URL? = builtInURL) -> ThemeFolder {
        ThemeFolder(config: .standard(environment: environment), builtIn: builtIn)
    }

    public func file(of name: String) -> URL {
        folder(of: name).appendingPathComponent("theme.toml")
    }

    public func scan() -> ThemeScan {
        let own = builtIn?.deletingLastPathComponent()
        let others = own.flatMap { $0.pathExtension == "theme" ? $0 : nil }.map { own in
            Self.scanFiles(in: own.deletingLastPathComponent()).filter { $0.deletingLastPathComponent().lastPathComponent != own.lastPathComponent }
        } ?? []
        let builtIns = [(name: Self.builtInName, file: builtIn)] + others.map { file in
            let base = file.deletingLastPathComponent().deletingPathExtension().lastPathComponent
            return (name: base.prefix(1).uppercased() + base.dropFirst(), file: Optional(file))
        }
        let mine = Self.scanFiles(in: url).map { (name: $0.deletingLastPathComponent().deletingPathExtension().lastPathComponent, file: $0) }
        return ThemeScan(builtIns: builtIns, own: mine)
    }

    public func readInUse() -> String {
        readInUse(in: scan())
    }

    private func readInUse(in scan: ThemeScan) -> String {
        inUse(in: scan, chosen: config.read().theme)
    }

    private func inUse(in scan: ThemeScan, chosen: String?) -> String {
        chosen.flatMap { scan.find($0)?.name } ?? firstName(in: scan)
    }

    private func firstName(in scan: ThemeScan) -> String {
        guard macOS == 26 else { return Self.builtInName }
        return scan.find(Self.liquidName)?.name ?? Self.builtInName
    }

    public func read() -> Theme {
        let scan = scan()
        let chosen = config.read().theme
        let name = inUse(in: scan, chosen: chosen)
        let clashes = scan.clashes.map { "The folder \(folder(of: $0.own).path) has the name of the built-in theme \($0.builtIn), so Openspot skips it. Rename the folder." }
        let theme = clashes.reduce(Self.read(builtIn: builtIn, copy: scan.find(name)?.file)) { Theme(unreadable: $1, over: $0) }
        guard let chosen, chosen.caseInsensitiveCompare(name) != .orderedSame else { return theme }
        return Theme(unreadable: "config.toml: the theme \(chosen) is not there, so Openspot uses the theme \(name). Run `openspot theme list` to see each one.", over: theme)
    }

    public static func read(builtIn: URL?, copy: URL? = nil) -> Theme {
        guard let builtIn, let text = try? String(contentsOf: builtIn, encoding: .utf8) else {
            return Theme(unreadable: "theme.toml cannot be read. Install Openspot again.")
        }
        let theme = Theme(text: text)
        guard let copy, FileManager.default.fileExists(atPath: copy.path) else { return theme }
        guard let own = try? String(contentsOf: copy, encoding: .utf8) else {
            return Theme(unreadable: "theme.toml cannot be read at \(copy.path), so Openspot keeps the look of the app. Save it as text, or delete it.", over: theme)
        }
        return Theme(text: own, over: theme)
    }

    @discardableResult
    public func use(_ name: String) throws -> String {
        let found = try find(name)
        let faults = Self.read(builtIn: builtIn, copy: found.file).faults
        guard faults.isEmpty else {
            throw SpotError.failed(1, (["The theme \(found.name) has faults, so Openspot keeps the theme \(readInUse()). Fix each line below, then run `openspot theme use \(found.name)` again."] + faults).joined(separator: "\n"))
        }
        try config.change { $0.set(theme: found.name) }
        return found.name
    }

    public func make() throws -> String {
        let text = try readBuiltIn().components(separatedBy: "\n").map { line in
            let words = line.trimmingCharacters(in: .whitespaces)
            return words.isEmpty || words.hasPrefix("#") || words.hasPrefix("[") ? line : "# " + line
        }.joined(separator: "\n")
        let name = free("Theme", from: 2)
        try write(text, as: name)
        return try use(name)
    }

    public func duplicate(_ name: String?) throws -> String {
        let scan = scan()
        let source = try find(name ?? readInUse(), in: scan)
        let text = try source.file.map { try String(contentsOf: $0, encoding: .utf8) } ?? readBuiltIn()
        let copy = free("\(source.name) copy", from: nil)
        try write(text, as: copy)
        return try use(copy)
    }

    @discardableResult
    public func rename(_ old: String, to name: String) throws -> String {
        let new = name.trimmingCharacters(in: .whitespaces)
        let scan = scan()
        let found = try find(old, in: scan)
        let source = found.name
        guard !found.isBuiltIn else {
            throw SpotError.failed(1, "The theme \(source) is built in, so it keeps its name. Run `openspot theme duplicate` to make a copy you can change.")
        }
        try check(new)
        if let taken = scan.find(new), taken.isBuiltIn { throw SpotError.failed(1, "\(taken.name) is the name of a built-in theme. Pick another name.") }
        guard source.caseInsensitiveCompare(new) == .orderedSame || scan.find(new) == nil else {
            throw SpotError.failed(1, "A theme named \(new) is already there. Pick another name.")
        }
        let isInUse = readInUse(in: scan) == source
        try FileManager.default.moveItem(at: folder(of: source), to: folder(of: new))
        if isInUse { try config.change { $0.set(theme: new) } }
        return new
    }

    @discardableResult
    public func delete(_ name: String, trash: (URL) throws -> URL = AppPlaces.systemTrash) throws -> Bool {
        let scan = scan()
        let found = try find(name, in: scan)
        guard !found.isBuiltIn else { throw SpotError.failed(1, "The theme \(found.name) is built in, so it cannot be deleted.") }
        let isInUse = readInUse(in: scan) == found.name
        _ = try trash(folder(of: found.name))
        if isInUse { try config.change { $0.set(theme: Self.builtInName) } }
        return isInUse
    }

    public func edit(_ named: String? = nil) throws -> (file: URL, isCopy: Bool) {
        let theme = try find(named ?? readInUse(), in: scan())
        guard theme.isBuiltIn else { return (file(of: theme.name), false) }
        return (file(of: try duplicate(theme.name)), true)
    }

    private func folder(of name: String) -> URL {
        url.appendingPathComponent("\(name).theme")
    }

    private static func scanFiles(in folder: URL) -> [URL] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        return folders.filter { $0.pathExtension == "theme" }.map { $0.appendingPathComponent("theme.toml") }.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func readBuiltIn() throws -> String {
        guard let builtIn, let text = try? String(contentsOf: builtIn, encoding: .utf8) else {
            throw SpotError.failed(1, "theme.toml cannot be read. Install Openspot again.")
        }
        return text
    }

    private func check(_ name: String) throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { throw SpotError.failed(1, "A theme needs a name, such as `Dusk`.") }
        guard !name.contains("/") else { throw SpotError.failed(1, "A theme's name cannot hold `/`. Pick a name such as `Dusk`.") }
        guard !name.hasPrefix(".") else { throw SpotError.failed(1, "A theme's name cannot start with `.`. Pick a name such as `Dusk`.") }
        guard name.rangeOfCharacter(from: .newlines) == nil else { throw SpotError.failed(1, "A theme's name cannot hold a new line. Pick a name such as `Dusk`.") }
    }

    public func find(_ name: String) throws -> ThemeScan.Item {
        try find(name, in: scan())
    }

    private func find(_ name: String, in scan: ThemeScan) throws -> ThemeScan.Item {
        try check(name)
        guard let found = scan.find(name) else {
            throw SpotError.failed(1, "There is no theme named \(name). Run `openspot theme list` to see each one.")
        }
        return found
    }

    private func free(_ base: String, from first: Int?) -> String {
        let scan = scan()
        let taken = { (name: String) in scan.find(name) != nil }
        if first == nil, !taken(base) { return base }
        var number = first ?? 2
        while taken("\(base) \(number)") { number += 1 }
        return "\(base) \(number)"
    }

    private func write(_ text: String, as name: String) throws {
        let folder = folder(of: name)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try text.write(to: folder.appendingPathComponent("theme.toml"), atomically: true, encoding: .utf8)
    }
}
