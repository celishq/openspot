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
        isGlobal: Bool = false
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

    /// Asks the command for the items of its list.
    public func items(timeout: TimeInterval) async throws -> ItemLines {
        ItemLines(output: try await PluginRun(command: self, arguments: SpotAction.items.arguments, timeout: timeout).output())
    }

    public func perform(_ action: SpotAction, timeout: TimeInterval) async throws {
        _ = try await PluginRun(command: self, arguments: action.arguments, timeout: timeout).output()
    }

    public func withoutKey() -> PluginCommand {
        PluginCommand(id: id, name: name, url: url, kind: kind, size: size, symbol: symbol, subtitle: subtitle, hasState: hasState, pick: pick, isGlobal: isGlobal)
    }
}
