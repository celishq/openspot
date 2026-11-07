import Foundation

/// What one file in the plugin folder gives: an executable, or a TOML file of widgets.
public struct Plugin: Equatable, Sendable {
    public static let widgetExtension = "toml"

    public let id: String
    public let commands: [PluginCommand]

    public init(id: String, commands: [PluginCommand]) {
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
        let name = header.value("name") ?? Self.name(of: url)
        let symbol = header.value("symbol")
        var read: SpotRead?
        if let text = header.value("read") {
            guard let parsed = SpotRead(text: text) else {
                throw PluginError.fault("\(name) has an unknown read: \(text). Use panel, sheet, launch, wake or a number of seconds")
            }
            read = parsed
        }
        let isTray = header.flag("tray") ?? false
        let stays = header.flag("stay") ?? false
        let hasKey = header.value("key") != nil
        if read?.seconds == nil, isTray, !stays {
            throw PluginError.fault("\(name) needs a number in its read, or stay=true, to show in the menu bar")
        }
        let sizeName = header.value("size") ?? "wide"
        guard let size = SpotSize(name: sizeName) else { throw PluginError.fault("\(name) has an unknown size: \(sizeName)") }
        var rank = PluginCommand.lastRank
        if let text = header.value("rank") {
            guard let number = Int(text) else { throw PluginError.fault("\(name) needs a number as its rank") }
            guard read?.has(.panel) == true || read?.has(.launch) == true || read?.seconds != nil else {
                throw PluginError.fault("\(name) needs panel, launch or a number in its read to join the main search")
            }
            guard read?.seconds == nil || hasKey else {
                throw PluginError.fault("\(name) needs a key to join the main search, because a number in its read and no key gives it no spot")
            }
            rank = number
        }
        var order = 0
        if let text = header.value("order") {
            guard let number = Int(text) else { throw PluginError.fault("\(name) needs a number as its order") }
            order = number
        }
        let offers = try header.values("command").map { text in
            guard let offer = CommandOffer(text: text) else {
                throw PluginError.fault("\(name) has an unknown command: \(text). Write an ID and a title, such as left:Left side")
            }
            return offer
        }
        let command = PluginCommand(
            id: id,
            name: name,
            url: url,
            kind: stays || rank != PluginCommand.lastRank || read?.has(.sheet) == true || read?.seconds != nil ? .list : .launch,
            size: size,
            symbol: symbol ?? "app",
            subtitle: header.value("subtitle"),
            key: try Self.key(header.value("key"), of: name),
            read: read,
            rank: rank,
            order: order,
            stays: stays,
            drop: header.value("drop")?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? [],
            isTray: isTray,
            dataName: header.value("data") ?? id.split(separator: "/").first.map(String.init),
            hasSpot: read?.seconds == nil || hasKey,
            isOnGrid: header.flag("grid") ?? true,
            headerSymbol: symbol,
            offers: offers
        )
        self.init(id: id, commands: [command])
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
        guard let key = CommandKey(name: text) else { throw PluginError.fault("\(name) has an unknown key: \(text)") }
        return key
    }

    private static func widget(_ table: [String: TomlDocument.Value], id: String, url: URL) throws -> PluginCommand {
        func text(_ key: String) -> String? {
            if case .string(let value)? = table[key] { return value }
            return nil
        }
        guard let name = text("name") else { throw PluginError.fault("a widget needs a name") }
        if case .strings(let drawing)? = table["grid"] {
            return try drawn(drawing, table, name: name, id: id, url: url)
        }
        guard let layoutName = text("layout") else { throw PluginError.fault("\(name) needs a layout or a grid") }
        guard let layout = WidgetLayout(name: layoutName) else {
            throw PluginError.fault("\(name) has an unknown layout: \(layoutName). Use single, hero, pair or row")
        }
        guard case .strings(let places)? = table["places"], places.count == layout.slots.count else {
            throw PluginError.fault("\(name) needs \(layout.slots.count) places for the \(layoutName) layout")
        }
        var size = layout.size
        if let sizeName = text("size") {
            guard layout == .single else {
                throw PluginError.fault("\(name) cannot take a size, because the \(layoutName) layout sets its own")
            }
            guard let asked = SpotSize(name: sizeName) else {
                throw PluginError.fault("\(name) has an unknown size: \(sizeName)")
            }
            size = asked
        }
        return PluginCommand(
            id: "\(id)/\(name)",
            name: name,
            url: url,
            kind: .widget,
            size: size,
            subtitle: text("subtitle"),
            key: try key(text("key"), of: name),
            layout: layout,
            places: places,
            opens: text("opens")
        )
    }

    /// A widget with a drawing of its own, whose `places` names a metric for each letter.
    private static func drawn(_ drawing: [String], _ table: [String: TomlDocument.Value], name: String, id: String, url: URL) throws -> PluginCommand {
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
        return PluginCommand(
            id: "\(id)/\(name)",
            name: name,
            url: url,
            kind: .widget,
            size: layout.size,
            key: try key(text("key"), of: name),
            layout: layout,
            places: layout.letters.compactMap { places[$0] },
            opens: text("opens")
        )
    }
}
