import Foundation

public struct Config: Equatable, Sendable {
    public enum Section: Hashable, Sendable {
        case keys
        case spots
        case settings
        case careful
        case panels
        case rest
    }

    public private(set) var panelKey: Shortcut? = .standard
    public private(set) var fixKey: Shortcut? = .fix
    public private(set) var faults: [String] = []
    public var arrangement = SpotArrangement()
    public var keys: [GlobalKey] = []
    public private(set) var settings: [SpotSetting] = []
    public private(set) var stores: [Store] = []
    public private(set) var isCareful = false
    public private(set) var panels = GridPanels()
    public private(set) var isReadable = true
    private var kept = ConfigDocument()

    public init() {}

    public init(text: String) {
        do {
            self.init(document: try ConfigDocument(text: text))
        } catch {
            self.init(unreadable: (error as? SpotError)?.reason ?? String(describing: error))
        }
    }

    public init(unreadable reason: String) {
        isReadable = false
        panelKey = nil
        faults = ["config.toml: \(reason)"]
    }

    public init(document: ConfigDocument) {
        kept = document
        kept.tables = []
        let known = ["spots", "keys", "settings", "stores"]
        let names = Array(document.values.keys) + Set(document.tables.map(\.name))
        for key in names.sorted() where !(["panel-key", "fix-key", "careful"] + known + GridPanel.allCases.compactMap(\.configKey)).contains(key) {
            faults.append("config.toml: \(key) is not a setting.")
        }
        arrangement = SpotArrangement(choices: document.tables(named: "spots").compactMap { choice(of: $0) })
        keys = document.tables(named: "keys").compactMap { key(of: $0) }
        settings = document.tables(named: "settings").compactMap { setting(of: $0) }
        stores = document.tables(named: "stores").compactMap { store(of: $0) }
        kept.tables += document.tables.filter { !known.contains($0.name) }
        panelKey = shortcut(document.values["panel-key"], named: "panel-key", or: .standard)
        fixKey = shortcut(document.values["fix-key"], named: "fix-key", or: .fix)
        switch document.values["careful"] {
        case .boolean(let isOn)?: isCareful = isOn
        case nil: break
        default: faults.append("config.toml: careful is true or false.")
        }
        for panel in GridPanel.allCases {
            guard let key = panel.configKey else { continue }
            switch document.values[key] {
            case .boolean(let isOn)?: panels[panel] = isOn
            case nil: break
            default: faults.append("config.toml: \(key) is true or false.")
            }
        }
    }

    public var text: String {
        var document = kept
        document.tables = arrangement.tables + keys.map(\.table) + settings.map(\.table) + stores.map(\.table) + kept.tables
        return document.text
    }

    public func sections(differingFrom other: Config) -> Set<Section> {
        var sections = Set<Section>()
        var same = other
        if panelKey != other.panelKey || fixKey != other.fixKey || keys != other.keys { sections.insert(.keys) }
        if arrangement != other.arrangement { sections.insert(.spots) }
        if settings != other.settings { sections.insert(.settings) }
        if isCareful != other.isCareful { sections.insert(.careful) }
        if panels != other.panels { sections.insert(.panels) }
        same.panelKey = panelKey
        same.fixKey = fixKey
        same.keys = keys
        same.arrangement = arrangement
        same.settings = settings
        same.isCareful = isCareful
        same.panels = panels
        same.kept = kept
        same.kept.tables = other.kept.tables
        if same != self { sections.insert(.rest) }
        return sections
    }

    public mutating func set(_ shortcut: Shortcut, for name: String) {
        switch name {
        case "panel-key": panelKey = shortcut
        case "fix-key": fixKey = shortcut
        default: return
        }
        kept.set(name, to: .string(shortcut.text))
    }

    public mutating func set(isCareful: Bool) {
        self.isCareful = isCareful
        kept.set("careful", to: .boolean(isCareful))
    }

    public mutating func show(_ panel: GridPanel, _ isShown: Bool) {
        guard let key = panel.configKey else { return }
        panels[panel] = isShown
        kept.set(key, to: .boolean(isShown))
    }

    public mutating func set(setting key: String, of spot: String, to value: String?) {
        let new = value.map { SpotSetting(spot: spot, key: key, value: $0) }
        if let place = settings.firstIndex(where: { $0.spot == spot && $0.key == key }) {
            settings.removeAll { $0.spot == spot && $0.key == key }
            if let new { settings.insert(new, at: place) }
        } else if let new {
            settings.append(new)
        }
    }

    public mutating func add(store: Store) {
        if !stores.contains(store) { stores.append(store) }
    }

    public mutating func remove(store: Store) {
        stores.removeAll { $0 == store }
    }

    public mutating func assign(_ trigger: Trigger?, to spot: String, act: GlobalKey.Act) {
        if trigger == .shake { keys.removeAll { $0.trigger == .shake && ($0.spot != spot || $0.act != act) } }
        let place = keys.firstIndex { $0.spot == spot && $0.act == act }
        let key = trigger.map { GlobalKey(spot: spot, act: act, trigger: $0) }
        switch (place, key) {
        case (let place?, let key?): keys[place] = key
        case (let place?, nil): keys.remove(at: place)
        case (nil, let key?): keys.append(key)
        case (nil, nil): break
        }
    }

    private mutating func unread<Value>(_ table: ConfigDocument.Table, _ fault: String) -> Value? {
        faults.append(fault)
        kept.tables.append(table)
        return nil
    }

    public func setting(_ key: String, of spot: String) -> String? {
        settings.first { $0.spot == spot && $0.key == key }?.value
    }

    private mutating func setting(of table: ConfigDocument.Table) -> SpotSetting? {
        guard case .string(let spot)? = table["spot"], case .string(let key)? = table["key"], case .string(let value)? = table["value"] else {
            return unread(table, "config.toml: a setting needs a spot, a key and a value.")
        }
        return SpotSetting(spot: spot, key: key, value: value)
    }

    private mutating func store(of table: ConfigDocument.Table) -> Store? {
        guard case .string(let path)? = table["path"], path.hasPrefix("/") else {
            return unread(table, "config.toml: a store needs the full path of its folder.")
        }
        return Store(url: URL(fileURLWithPath: path))
    }

    private mutating func shortcut(_ value: ConfigDocument.Value?, named name: String, or standard: Shortcut) -> Shortcut? {
        guard let value else { return standard }
        if case .string(let text) = value, let shortcut = Shortcut(text: text) { return shortcut }
        let word = if case .string(let text) = value { text } else { "this value" }
        faults.append("config.toml: \(name) cannot use \(word). Hold cmd, ctrl or option with a letter, a digit, a sign, an arrow, space, return or tab.")
        return nil
    }

    private mutating func key(of table: ConfigDocument.Table) -> GlobalKey? {
        guard case .string(let spot)? = table["spot"], case .string(let text)? = table["key"] else {
            return unread(table, "config.toml: a key needs a spot and a key.")
        }
        if let open = table["open"], open != .boolean(true) {
            return unread(table, "config.toml: the key of \(spot) takes open = true, or no open line.")
        }
        let act: GlobalKey.Act = if case .string(let command)? = table["command"] { .command(command) } else if table["open"] != nil { .open } else { .float }
        guard let trigger = Trigger(text: text) else {
            let name = if case .command(let command) = act { "\(spot) \(command)" } else { spot }
            return unread(table, "config.toml: \(name) cannot use \(text).")
        }
        return GlobalKey(spot: spot, act: act, trigger: trigger)
    }

    private mutating func choice(of table: ConfigDocument.Table) -> SpotArrangement.Choice? {
        guard case .string(let id)? = table["id"] else {
            return unread(table, "config.toml: a spot needs an id.")
        }
        var choice = SpotArrangement.Choice(id: id)
        if case .string(let name)? = table["size"] {
            choice.size = SpotSize(name: name)
            if choice.size == nil { faults.append("config.toml: \(id) cannot use the size \(name).") }
        }
        if case .boolean(let isOnGrid)? = table["grid"] { choice.isOnGrid = isOnGrid }
        if case .boolean(let isEnabled)? = table["enabled"] { choice.isEnabled = isEnabled }
        if case .boolean(let isGlobal)? = table["global"] { choice.isGlobal = isGlobal }
        if case .boolean(let isInMenuBar)? = table["tray"] { choice.isInMenuBar = isInMenuBar }
        if case .string(let text)? = table["key"] {
            choice.key = ActionKey(text: text)
            if choice.key == nil { faults.append("config.toml: \(id) cannot use the key \(text).") }
        }
        if case .string(let name)? = table["side"] {
            choice.panel = GridPanel(rawValue: name).flatMap { $0 == .center ? nil : $0 }
            if choice.panel == nil { faults.append("config.toml: \(id) cannot use the side \(name).") }
        }
        for key in table.keys.sorted() where !["id", "size", "grid", "enabled", "global", "tray", "letter", "key", "side"].contains(key) {
            faults.append("config.toml: \(key) is not a setting of a spot.")
        }
        return choice
    }
}
