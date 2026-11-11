import Foundation

/// What one file in the plugin folder gives: an executable, or a TOML file of widgets.
public struct Plugin: Equatable, Sendable {
    public static let widgetExtension = "toml"

    public let id: String
    public let commands: [Spot]

    public init(id: String, commands: [Spot]) {
        self.id = id
        self.commands = commands
    }

    /// Reads a file with no run of it. Returns nil for a file that is neither. Throws a fault that names what is wrong.
    public init?(file url: URL, id: String) throws {
        if SwiftProgram.isProgram(url) { return nil }
        if url.pathExtension == Self.widgetExtension {
            let document = try TomlDocument(text: try String(contentsOf: url, encoding: .utf8))
            self.init(id: id, commands: try (document.arrays["widgets"] ?? []).map { try Self.widget($0, id: id, url: url) })
        } else if FileManager.default.isExecutableFile(atPath: url.path) {
            try self.init(script: url, header: PluginHeader(url: url).block, id: id)
        } else {
            return nil
        }
    }

    /// A script with a number in its `read` starts off the grid until the person shows it (F7).
    public init(script url: URL, header: TextBlock, id: String) throws {
        let name = header.value("title") ?? Self.name(of: url)
        let icon = Icon(text: header.value("icon"))
        let symbol = icon?.symbol
        var read: SpotRead?
        if let text = header.value("read") {
            guard let parsed = SpotRead(text: text) else {
                throw PluginError.fault("\(name) has an unknown read: \(text). Use sheet, panel or a number of seconds")
            }
            read = parsed
        }
        try Self.refuseOldKeys(header, of: name)
        let stay = header.value("stay")
        guard stay == nil || ["true", "false", "always"].contains(stay) else {
            throw PluginError.fault("\(name) has an unknown stay: \(stay!). Use true or always")
        }
        let stays = stay == "true" || stay == "always"
        let sizeName = header.value("size") ?? "wide"
        guard let size = SpotSize(name: sizeName) else { throw PluginError.fault("\(name) has an unknown size: \(sizeName)") }
        let places = try Self.places(header.value("offers"), of: name)
        let isRowsOnly = places.contains("rows")
        let isGlobal = isRowsOnly || places.contains("search")
        if isGlobal {
            guard read?.has(.panel) == true || read?.seconds != nil else {
                throw PluginError.fault("\(name) needs panel or a number in its read to join the main search")
            }
        }
        let offers = try header.values("command").map { text in
            guard let offer = CommandOffer(text: text) else {
                throw PluginError.fault("\(name) has an unknown command: \(text). Write an ID and a title, such as left:Left side")
            }
            return offer
        }
        let view = header.value("view")
        if let view, URL(fileURLWithPath: view).pathExtension != SwiftProgram.sourceExtension {
            throw PluginError.fault("\(name) needs a Swift file for its view, such as view=\(url.deletingPathExtension().lastPathComponent).swift")
        }
        if let view, !id.contains("/") {
            throw PluginError.fault("\(name) has a view, so it needs a folder of its own. Move \(url.lastPathComponent) and \(view) into a folder such as \(id)/")
        }
        let command = Spot(
            id: id,
            name: name,
            url: url,
            kind: stays || isGlobal || read?.has(.sheet) == true || read?.seconds != nil ? .list : .launch,
            size: size,
            symbol: symbol ?? "app",
            subtitle: header.value("detail"),
            read: read,
            isGlobal: isGlobal,
            isFound: !isRowsOnly,
            stays: stays,
            staysAlways: stay == "always",
            drop: header.value("drop")?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? [],
            offersFloat: places.contains("float"),
            dataName: id.split(separator: "/").first.map(String.init),
            isOnGrid: offers.isEmpty && !isRowsOnly && read?.seconds == nil,
            headerSymbol: symbol,
            offers: offers,
            settings: header.value("settings")?.split(separator: ",").compactMap { CommandOffer(setting: String($0)) } ?? [],
            file: icon?.file.map { Self.path($0, beside: url) },
            image: icon?.image.map { Self.path($0, beside: url) },
            glyph: icon?.glyph,
            view: view.map { Self.path($0, beside: url) }
        )
        self.init(id: id, commands: [command])
    }

    /// The places that `offers` names. An unknown place, or `search` with `rows`, is a fault.
    private static func places(_ text: String?, of name: String) throws -> Set<String> {
        guard let text else { return [] }
        let words = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if let word = words.first(where: { !["search", "rows", "float"].contains($0) }) {
            throw PluginError.fault("\(name) offers an unknown place: \(word). Use search, rows or float")
        }
        if words.contains("search"), words.contains("rows") {
            throw PluginError.fault("\(name) offers both search and rows. Use search for the spot and its rows, or rows for its rows alone")
        }
        return Set(words)
    }

    /// Refuses a header that still has `global`, `float`, `tray`, `data` or `shortcut`, and names the new way.
    private static func refuseOldKeys(_ header: TextBlock, of name: String) throws {
        if let global = header.value("global") {
            let place = global == "rows" ? "rows" : "search"
            throw PluginError.fault("\(name) has global=\(global), which Openspot no longer reads. Use offers=\(place)")
        }
        if header.value("float") != nil {
            throw PluginError.fault("\(name) has float, which Openspot no longer reads. Use offers=float")
        }
        if header.value("tray") != nil {
            throw PluginError.fault("\(name) has tray, which Openspot no longer reads. The person puts a spot in the menu bar in Settings")
        }
        if header.value("data") != nil {
            throw PluginError.fault("\(name) has data, which Openspot no longer reads. The scripts of one folder share OPENSPOT_DATA, so move them into one folder")
        }
        try refuseLetter(header.value("shortcut"), of: name)
    }

    /// Refuses a letter that a file names, because the person gives each spot its letter.
    private static func refuseLetter(_ text: String?, of name: String) throws {
        guard text != nil else { return }
        throw PluginError.fault("\(name) has shortcut, which Openspot no longer reads. The person gives each spot its letter in Edit Spots")
    }

    /// A path that the header names: a full path stays, and any other starts at the folder of the script.
    private static func path(_ text: String, beside url: URL) -> String {
        text.hasPrefix("/") ? text : url.deletingLastPathComponent().appendingPathComponent(text).path
    }

    /// The name a file gives when it has no `name` line: its words with a capital first letter.
    static func name(of url: URL) -> String {
        let words = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }


    private static func widget(_ table: [String: TomlDocument.Value], id: String, url: URL) throws -> Spot {
        func text(_ key: String) -> String? {
            if case .string(let value)? = table[key] { return value }
            return nil
        }
        guard let name = text("title") else { throw PluginError.fault("a widget needs a title") }
        try refuseLetter(text("shortcut"), of: name)
        if case .strings(let drawing)? = table["grid"] {
            return try drawn(drawing, table, name: name, id: id, url: url)
        }
        throw PluginError.fault("\(name) needs a grid, such as grid = [\"a a b b\"]")
    }

    /// A widget with a drawing of its own, whose `places` names a metric for each letter.
    private static func drawn(_ drawing: [String], _ table: [String: TomlDocument.Value], name: String, id: String, url: URL) throws -> Spot {
        func text(_ key: String) -> String? {
            if case .string(let value)? = table[key] { return value }
            return nil
        }
        if let fault = WidgetLayout.faults(in: drawing).first { throw PluginError.fault("\(name): \(fault)") }
        var size: SpotSize?
        if let sizeName = text("size") {
            guard let asked = SpotSize(name: sizeName) else { throw PluginError.fault("\(name) has an unknown size: \(sizeName)") }
            size = asked
        }
        let layout = WidgetLayout(drawing: drawing, size: size)
        guard case .table(let places)? = table["places"] else {
            throw PluginError.fault("\(name) needs places, with a metric for each letter of its grid")
        }
        if let letter = layout.letters.first(where: { places[$0] == nil }) {
            throw PluginError.fault("\(name) needs a metric for the letter \(letter)")
        }
        if let letter = places.keys.sorted().first(where: { !layout.letters.contains($0) }) {
            throw PluginError.fault("\(name) names the letter \(letter), which its grid does not have")
        }
        return Spot(
            id: "\(id)/\(name)",
            name: name,
            url: url,
            kind: .widget,
            size: layout.size,
            subtitle: text("detail"),
            layout: layout,
            places: layout.letters.compactMap { places[$0] }.map { tool($0, beside: url, id: id) },
            opens: text("opens").map { tool($0, beside: url, id: id) }
        )
    }

    /// The ID of a tool that a widget names: a script of the widget's own folder by its file name first, else the name as an
    /// ID (F10).
    private static func tool(_ name: String, beside url: URL, id: String) -> String {
        guard !name.contains("/"), let folder = id.split(separator: "/").first, id.contains("/") else { return name }
        let files = (try? FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)) ?? []
        let isOwn = files.contains { $0.deletingPathExtension().lastPathComponent == name && FileManager.default.isExecutableFile(atPath: $0.path) }
        return isOwn ? "\(folder)/\(name)" : name
    }
}
