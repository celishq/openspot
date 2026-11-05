import Foundation

/// One executable of a plugin, with the look its spot takes.
public struct PluginCommand: Equatable, Sendable {
    public let id: String
    public let name: String
    public let url: URL
    public let kind: SpotKind
    public let size: SpotSize
    public let symbol: String
    public let subtitle: String?
    public let key: CommandKey?
    public let hasState: Bool
    public let pick: ItemPick
    public let isGlobal: Bool
    public let search: ItemSearch
    public let keepsRecent: Bool
    public let primary: String?
    public let actions: [CommandAction]

    public init(
        id: String,
        name: String,
        url: URL,
        kind: SpotKind = .launch,
        size: SpotSize = .wide,
        symbol: String = "app",
        subtitle: String? = nil,
        key: CommandKey? = nil,
        hasState: Bool = false,
        pick: ItemPick = .close,
        isGlobal: Bool = false,
        search: ItemSearch = .local,
        keepsRecent: Bool = true,
        primary: String? = nil,
        actions: [CommandAction] = []
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.kind = kind
        self.size = size
        self.symbol = symbol
        self.subtitle = subtitle
        self.key = key
        self.hasState = hasState
        self.pick = pick
        self.isGlobal = isGlobal
        self.search = search
        self.keepsRecent = keepsRecent
        self.primary = primary
        self.actions = actions
    }

    /// The state the manifest gives, shown before the command answers or when it cannot.
    public var manifestState: SpotState {
        SpotState(title: name, subtitle: subtitle)
    }

    /// Whether the command prints a state. Toggles and sliders do, a launch spot does not, and a list says so.
    public var readsState: Bool {
        switch kind {
        case .launch: false
        case .toggle, .slider: true
        case .list: hasState
        }
    }

    /// Asks the command for its state. A command with no state to read does not run.
    public func state(timeout: TimeInterval) async throws -> SpotState {
        guard readsState else { return manifestState }
        let output = try await PluginRun(command: self, arguments: SpotAction.read.arguments, timeout: timeout).output()
        guard let state = try? JSONDecoder().decode(SpotState.self, from: Data(output.utf8)) else {
            throw PluginError.badState
        }
        return state
    }

    /// Asks the command for the items of its list, with the search when it searches live.
    public func items(query: String = "", timeout: TimeInterval) async throws -> ItemLines {
        ItemLines(output: try await PluginRun(command: self, arguments: SpotAction.items(query: query).arguments, timeout: timeout).output())
    }

    /// Asks the command for the form of an action.
    public func form(_ action: CommandAction, item: SpotItem?, timeout: TimeInterval) async throws -> ItemForm {
        let output = try await PluginRun(command: self, arguments: SpotAction.form(action, item: item).arguments, timeout: timeout).output()
        guard let form = try? JSONDecoder().decode(ItemForm.self, from: Data(output.utf8)) else { throw PluginError.badForm }
        return form
    }

    /// Gives a filled form to the command, and returns the run value of the item it saved, if it prints one.
    public func submit(_ action: CommandAction, item: SpotItem?, draft: FormDraft, timeout: TimeInterval) async throws -> String {
        let output = try await PluginRun(command: self, arguments: SpotAction.action(action, item: item).arguments, timeout: timeout, input: draft.json).output()
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The actions that fit: those an item does not hide, and only the command's own with no item.
    public func actions(for item: SpotItem?) -> [CommandAction] {
        actions.filter { ($0.scope == .command || item != nil) && item?.hides?.contains($0.id) != true }
    }

    /// What Enter does, in words. A slider has no Enter.
    public func primaryTitle(hasItem: Bool) -> String? {
        if hasItem { return primary ?? "Open" }
        switch kind {
        case .launch: return "Run"
        case .toggle: return "Toggle"
        case .list: return "Open"
        case .slider: return nil
        }
    }

    public func perform(_ action: SpotAction, timeout: TimeInterval) async throws {
        _ = try await PluginRun(command: self, arguments: action.arguments, timeout: timeout).output()
    }

    public func withoutKey() -> PluginCommand {
        PluginCommand(id: id, name: name, url: url, kind: kind, size: size, symbol: symbol, subtitle: subtitle, hasState: hasState, pick: pick, isGlobal: isGlobal, search: search, keepsRecent: keepsRecent, primary: primary, actions: actions)
    }
}
