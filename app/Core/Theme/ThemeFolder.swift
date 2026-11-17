import Foundation

public struct ThemeFolder: Sendable {
    public static let builtInName = "Openspot"

    public let url: URL
    public let builtIn: URL?
    public let config: ConfigFile

    public init(url: URL, builtIn: URL?, config: ConfigFile) {
        self.url = url
        self.builtIn = builtIn
        self.config = config
    }

    public static func standard(environment: [String: String], builtIn: URL? = ThemeFile.builtInURL) -> ThemeFolder {
        let config = ConfigFile.standard(environment: environment)
        return ThemeFolder(url: config.url.deletingLastPathComponent().appendingPathComponent("themes"), builtIn: builtIn, config: config)
    }

    public static func isBuiltIn(_ name: String) -> Bool {
        name.caseInsensitiveCompare(builtInName) == .orderedSame
    }

    public func file(of name: String) -> URL? {
        Self.isBuiltIn(name) ? nil : folder(of: name).appendingPathComponent("theme.toml")
    }

    public func scan() -> [String] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        let names = folders.filter { $0.pathExtension == "theme" }.map { $0.deletingPathExtension().lastPathComponent }
            .filter { name in !Self.isBuiltIn(name) && file(of: name).map { FileManager.default.fileExists(atPath: $0.path) } == true }
        return [Self.builtInName] + names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    public func readInUse() -> String {
        let names = scan()
        return config.read().theme.flatMap { chosen in names.first { $0.caseInsensitiveCompare(chosen) == .orderedSame } } ?? Self.builtInName
    }

    public func read() -> Theme {
        let name = readInUse()
        let theme = ThemeFile(builtIn: builtIn, copy: file(of: name)).read()
        guard let chosen = config.read().theme, chosen.caseInsensitiveCompare(name) != .orderedSame else { return theme }
        return Theme(unreadable: "config.toml: the theme \(chosen) is not there, so Openspot uses the theme \(Self.builtInName). Run `openspot theme list` to see each one.", over: theme)
    }

    @discardableResult
    public func use(_ name: String) throws -> String {
        let found = try find(name)
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
        let source = try name.map(find) ?? readInUse()
        let text = if let file = file(of: source) { try String(contentsOf: file, encoding: .utf8) } else { try readBuiltIn() }
        let copy = free("\(source) copy", from: nil)
        try write(text, as: copy)
        return try use(copy)
    }

    @discardableResult
    public func rename(_ old: String, to name: String) throws -> String {
        let new = name.trimmingCharacters(in: .whitespaces)
        let source = try find(old)
        guard !Self.isBuiltIn(source) else {
            throw SpotError.failed(1, "The theme \(Self.builtInName) is built in, so it keeps its name. Run `openspot theme duplicate` to make a copy you can change.")
        }
        try check(new)
        guard !Self.isBuiltIn(new) else { throw SpotError.failed(1, "\(Self.builtInName) is the name of the built-in theme. Pick another name.") }
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
        guard !Self.isBuiltIn(found) else { throw SpotError.failed(1, "The theme \(Self.builtInName) is built in, so it cannot be deleted.") }
        let isInUse = readInUse() == found
        _ = try trash(folder(of: found))
        if isInUse { try config.change { $0.set(theme: Self.builtInName) } }
        return isInUse
    }

    public func readRows(of name: String) throws -> [ThemeRow] {
        let found = try find(name)
        let own = file(of: found).flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        return ThemeRow.rows(builtIn: try readBuiltIn(), own: own)
    }

    public func write(_ key: String, in section: String, to value: ConfigDocument.Value?, of name: String) throws {
        let found = try find(name)
        guard let file = file(of: found) else {
            throw SpotError.failed(1, "The theme \(Self.builtInName) is built in, so it can't change. Run `openspot theme duplicate` to make a copy you can change.")
        }
        let text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        try ConfigDocument.text(text, setting: key, in: section, to: value).write(to: file, atomically: true, encoding: .utf8)
    }

    public func edit() throws -> URL {
        let name = readInUse()
        return folder(of: Self.isBuiltIn(name) ? try duplicate(name) : name).appendingPathComponent("theme.toml")
    }

    private func folder(of name: String) -> URL {
        url.appendingPathComponent("\(name).theme")
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

    private func find(_ name: String) throws -> String {
        try check(name)
        guard let found = scan().first(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else {
            throw SpotError.failed(1, "There is no theme named \(name). Run `openspot theme list` to see each one.")
        }
        return found
    }

    private func free(_ base: String, from first: Int?) -> String {
        let names = scan()
        let taken = { (name: String) in names.contains { $0.caseInsensitiveCompare(name) == .orderedSame } }
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
