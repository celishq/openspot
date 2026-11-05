import Foundation

/// What one file in the plugin folder gives: an executable, or a file of widgets.
public struct Plugin: Equatable, Sendable {
    public static let widgetExtension = "widget"

    public let id: String
    public let commands: [PluginCommand]
    public let metrics: [PluginMetric]

    public init(id: String, commands: [PluginCommand], metrics: [PluginMetric] = []) {
        self.id = id
        self.commands = commands
        self.metrics = metrics
    }

    /// Reads a file with no run of it. Returns nil for a file that is neither. Throws a fault that names what is wrong.
    public init?(file url: URL, id: String) throws {
        if url.pathExtension == Self.widgetExtension {
            let text = try String(contentsOf: url, encoding: .utf8)
            self.init(id: id, commands: try TextBlock.blocks(in: text).map { try Self.widget($0, id: id, url: url) })
        } else if FileManager.default.isExecutableFile(atPath: url.path) {
            try self.init(script: url, header: PluginHeader(url: url).block, id: id)
        } else {
            return nil
        }
    }

    /// A script with a number of seconds as its `read` is a metric, and it is also a list when it has a key.
    public init(script url: URL, header: TextBlock, id: String) throws {
        let name = header.value("name") ?? Self.name(of: url)
        let symbol = header.value("symbol")
        var read: SpotRead?
        if let text = header.value("read") {
            guard let parsed = SpotRead(name: text) else {
                throw PluginError.header("\(name) has an unknown read: \(text). Use click, open or a number of seconds")
            }
            read = parsed
        }
        var metrics: [PluginMetric] = []
        if case .every(let seconds) = read {
            metrics.append(PluginMetric(id: id, url: url, label: name, symbol: symbol, refresh: seconds))
            guard header.value("key") != nil else {
                self.init(id: id, commands: [], metrics: metrics)
                return
            }
        }
        let sizeName = header.value("size") ?? "wide"
        guard let size = SpotSize(name: sizeName) else { throw PluginError.header("\(name) has an unknown size: \(sizeName)") }
        let searchName = header.value("search") ?? ItemSearch.local.rawValue
        guard let search = ItemSearch(rawValue: searchName) else { throw PluginError.header("\(name) has an unknown search: \(searchName)") }
        guard search == .local || read == .click else { throw PluginError.header("\(name) needs read=click to search live") }
        var rank = PluginCommand.lastRank
        if let text = header.value("rank") {
            guard let number = Int(text) else { throw PluginError.header("\(name) needs a number as its rank") }
            guard read == .open else { throw PluginError.header("\(name) needs read=open to join the main search") }
            rank = number
        }
        let command = PluginCommand(
            id: id,
            name: name,
            url: url,
            kind: read == nil || (read == .open && rank == PluginCommand.lastRank) ? .launch : .list,
            size: size,
            symbol: symbol ?? "app",
            subtitle: header.value("subtitle"),
            key: try Self.key(in: header, of: name),
            read: read,
            rank: rank,
            search: search,
            keepsRecent: header.flag("recents") != false
        )
        self.init(id: id, commands: [command], metrics: metrics)
    }

    /// The name a file gives when it has no `name` line: its words with a capital first letter.
    private static func name(of url: URL) -> String {
        let words = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    private static func key(in block: TextBlock, of name: String) throws -> CommandKey? {
        guard let text = block.value("key") else { return nil }
        guard let key = CommandKey(name: text) else { throw PluginError.header("\(name) has an unknown key: \(text)") }
        return key
    }

    private static func widget(_ block: TextBlock, id: String, url: URL) throws -> PluginCommand {
        guard let name = block.value("name") else { throw PluginError.header("a widget needs a name") }
        guard let layoutName = block.value("layout") else { throw PluginError.header("\(name) needs a layout") }
        guard let layout = WidgetLayout(name: layoutName) else {
            throw PluginError.header("\(name) has an unknown layout: \(layoutName). Use single, hero, pair or row")
        }
        let places = block.values("place")
        guard places.count == layout.slots.count else {
            throw PluginError.header("\(name) needs \(layout.slots.count) places for the \(layoutName) layout")
        }
        var size = layout.size
        if let sizeName = block.value("size") {
            guard layout == .single else {
                throw PluginError.header("\(name) cannot take a size, because the \(layoutName) layout sets its own")
            }
            guard let asked = SpotSize(name: sizeName) else {
                throw PluginError.header("\(name) has an unknown size: \(sizeName)")
            }
            size = asked
        }
        let tray = block.value("tray")
        if let tray, !places.contains(tray) {
            throw PluginError.header("\(name) cannot show \(tray) in the menu bar, because it does not place it")
        }
        return PluginCommand(
            id: "\(id)/\(name)",
            name: name,
            url: url,
            kind: .widget,
            size: size,
            key: try key(in: block, of: name),
            layout: layout,
            places: places,
            opens: block.value("opens"),
            tray: tray
        )
    }
}
