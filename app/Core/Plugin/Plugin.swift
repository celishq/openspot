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

    /// A script with a number in its `read` has a spot, a list, only when it has a key.
    public init(script url: URL, header: TextBlock, id: String) throws {
        let name = header.value("title") ?? Self.name(of: url)
        let icon = Icon(text: header.value("icon"))
        let symbol = icon?.symbol
        var read: SpotRead?
        if let text = header.value("read") {
            guard let parsed = SpotRead(text: text) else {
                throw PluginError.fault("\(name) has an unknown read: \(text). Use panel, sheet, launch, wake or a number of seconds")
            }
            read = parsed
        }
        let isTray = header.flag("tray") ?? false
        let stays = header.flag("stay") ?? false
        let hasKey = header.value("shortcut") != nil
        if read?.seconds == nil, isTray, !stays {
            throw PluginError.fault("\(name) needs a number in its read, or stay=true, to show in the menu bar")
        }
        let sizeName = header.value("size") ?? "wide"
        guard let size = SpotSize(name: sizeName) else { throw PluginError.fault("\(name) has an unknown size: \(sizeName)") }
        let isGlobal = header.flag("global") ?? false
        if isGlobal {
            guard read?.has(.panel) == true || read?.has(.launch) == true || read?.seconds != nil else {
                throw PluginError.fault("\(name) needs panel, launch or a number in its read to join the main search")
            }
            guard read?.seconds == nil || hasKey else {
                throw PluginError.fault("\(name) needs a shortcut to join the main search, because a number in its read and no shortcut gives it no spot")
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
            key: try Self.key(header.value("shortcut"), of: name),
            read: read,
            isGlobal: isGlobal,
            stays: stays,
            drop: header.value("drop")?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? [],
            isTray: isTray,
            dataName: header.value("data") ?? id.split(separator: "/").first.map(String.init),
            hasSpot: read?.seconds == nil || hasKey,
            isOnGrid: offers.isEmpty && (hasKey || !isGlobal),
            headerSymbol: symbol,
            offers: offers,
            settings: header.value("settings")?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? [],
            file: icon?.file.map { Self.path($0, beside: url) },
            image: icon?.image.map { Self.path($0, beside: url) },
            glyph: icon?.glyph,
            view: view.map { Self.path($0, beside: url) }
        )
        self.init(id: id, commands: [command])
    }

    /// A path that the header names: a full path stays, and any other starts at the folder of the script.
    private static func path(_ text: String, beside url: URL) -> String {
        text.hasPrefix("/") ? text : url.deletingLastPathComponent().appendingPathComponent(text).path
    }

    /// The name a file gives when it has no `name` line: its words with a capital first letter.
    private static func name(of url: URL) -> String {
        let words = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    private static func key(_ text: String?, of name: String) throws -> CommandKey? {
        guard let text else { return nil }
        guard let key = CommandKey(name: text) else { throw PluginError.fault("\(name) has an unknown shortcut: \(text)") }
        return key
    }

    private static func widget(_ table: [String: TomlDocument.Value], id: String, url: URL) throws -> Spot {
        func text(_ key: String) -> String? {
            if case .string(let value)? = table[key] { return value }
            return nil
        }
        guard let name = text("title") else { throw PluginError.fault("a widget needs a title") }
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
            key: try key(text("shortcut"), of: name),
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
