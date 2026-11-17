import Foundation

public struct ThemeFolder: Sendable {
    public static let builtInName = "Openspot"
    public static let builtInURL = Bundle.main.url(forResource: "theme", withExtension: "toml", subdirectory: "Themes/openspot.theme")

    public let url: URL
    public let builtIn: URL?
    public let config: ConfigFile

    public init(url: URL, builtIn: URL?, config: ConfigFile) {
        self.url = url
        self.builtIn = builtIn
        self.config = config
    }

    public static func standard(environment: [String: String], builtIn: URL? = builtInURL) -> ThemeFolder {
        let config = ConfigFile.standard(environment: environment)
        return ThemeFolder(url: config.url.deletingLastPathComponent().appendingPathComponent("themes"), builtIn: builtIn, config: config)
    }

    public func isBuiltIn(_ name: String) -> Bool {
        Self.isTaken(name, in: [Self.builtInName] + scanBuiltIns().keys)
    }

    public func file(of name: String) -> URL {
        folder(of: name).appendingPathComponent("theme.toml")
    }

    public func scanBuiltIns() -> [String: URL] {
        guard let builtIn else { return [:] }
        let own = builtIn.deletingLastPathComponent()
        var themes = [Self.builtInName: builtIn]
        guard own.pathExtension == "theme" else { return themes }
        for file in Self.scanFiles(in: own.deletingLastPathComponent()) where file.deletingLastPathComponent().lastPathComponent != own.lastPathComponent {
            let base = file.deletingLastPathComponent().deletingPathExtension().lastPathComponent
            let name = base.prefix(1).uppercased() + base.dropFirst()
            if !Self.isTaken(name, in: Array(themes.keys)) { themes[name] = file }
        }
        return themes
    }

    public func scan() -> [String] {
        let builtIns = [Self.builtInName] + scanBuiltIns().keys.filter { !Self.isTaken($0, in: [Self.builtInName]) }.sorted(by: Self.order)
        return builtIns + scanOwn().filter { !Self.isTaken($0, in: builtIns) }.sorted(by: Self.order)
    }

    private func scanOwn() -> [String] {
        Self.scanFiles(in: url).map { $0.deletingLastPathComponent().deletingPathExtension().lastPathComponent }
    }

    public func readInUse() -> String {
        let names = scan()
        return config.read().theme.flatMap { chosen in names.first { $0.caseInsensitiveCompare(chosen) == .orderedSame } } ?? Self.builtInName
    }

    public func read() -> Theme {
        let name = readInUse()
        let builtIns = [Self.builtInName] + scanBuiltIns().keys
        let clashes = scanOwn().sorted(by: Self.order).compactMap { own in
            builtIns.first { Self.isTaken(own, in: [$0]) }.map { "The folder \(folder(of: own).path) has the name of the built-in theme \($0), so Openspot skips it. Rename the folder." }
        }
        let theme = clashes.reduce(Self.read(builtIn: builtIn, copy: scanBuiltIns()[name] ?? file(of: name))) { Theme(unreadable: $1, over: $0) }
        guard let chosen = config.read().theme, chosen.caseInsensitiveCompare(name) != .orderedSame else { return theme }
        return Theme(unreadable: "config.toml: the theme \(chosen) is not there, so Openspot uses the theme \(Self.builtInName). Run `openspot theme list` to see each one.", over: theme)
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
        let faults = Self.read(builtIn: builtIn, copy: scanBuiltIns()[found] ?? file(of: found)).faults
        guard faults.isEmpty else {
            throw SpotError.failed(1, (["The theme \(found) has faults, so Openspot keeps the theme \(readInUse()). Fix each line below, then run `openspot theme use \(found)` again."] + faults).joined(separator: "\n"))
        }
        try config.change { $0.set(theme: found) }
        return found
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
        let builtIns = scanBuiltIns()
        let source = try name.map(find) ?? readInUse()
        let file = builtIns[source] ?? (isBuiltIn(source) ? nil : file(of: source))
        let text = try file.map { try String(contentsOf: $0, encoding: .utf8) } ?? readBuiltIn()
        let copy = free("\(source) copy", from: nil)
        try write(text, as: copy)
        return try use(copy)
    }

    @discardableResult
    public func rename(_ old: String, to name: String) throws -> String {
        let new = name.trimmingCharacters(in: .whitespaces)
        let source = try find(old)
        guard !isBuiltIn(source) else {
            throw SpotError.failed(1, "The theme \(source) is built in, so it keeps its name. Run `openspot theme duplicate` to make a copy you can change.")
        }
        try check(new)
        if let taken = ([Self.builtInName] + scanBuiltIns().keys).first(where: { Self.isTaken(new, in: [$0]) }) { throw SpotError.failed(1, "\(taken) is the name of a built-in theme. Pick another name.") }
        guard source.caseInsensitiveCompare(new) == .orderedSame || !scan().contains(where: { $0.caseInsensitiveCompare(new) == .orderedSame }) else {
            throw SpotError.failed(1, "A theme named \(new) is already there. Pick another name.")
        }
        let isInUse = readInUse() == source
        try FileManager.default.moveItem(at: folder(of: source), to: folder(of: new))
        if isInUse { try config.change { $0.set(theme: new) } }
        return new
    }

    @discardableResult
    public func delete(_ name: String, trash: (URL) throws -> URL = AppPlaces.systemTrash) throws -> Bool {
        let found = try find(name)
        guard !isBuiltIn(found) else { throw SpotError.failed(1, "The theme \(found) is built in, so it cannot be deleted.") }
        let isInUse = readInUse() == found
        _ = try trash(folder(of: found))
        if isInUse { try config.change { $0.set(theme: Self.builtInName) } }
        return isInUse
    }

    public func edit(_ named: String? = nil) throws -> (file: URL, isCopy: Bool) {
        let name = try named.map(find) ?? readInUse()
        guard isBuiltIn(name) else { return (file(of: name), false) }
        return (file(of: try duplicate(name)), true)
    }

    private func folder(of name: String) -> URL {
        url.appendingPathComponent("\(name).theme")
    }

    private static func isTaken(_ name: String, in names: [String]) -> Bool {
        names.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    private static func order(_ one: String, _ other: String) -> Bool {
        one.localizedStandardCompare(other) == .orderedAscending
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

    public func find(_ name: String) throws -> String {
        try check(name)
        guard let found = scan().first(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else {
            throw SpotError.failed(1, "There is no theme named \(name). Run `openspot theme list` to see each one.")
        }
        return found
    }

    private func free(_ base: String, from first: Int?) -> String {
        let names = scan()
        let taken = { (name: String) in Self.isTaken(name, in: names) }
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
