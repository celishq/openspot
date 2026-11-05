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

    public init(
        id: String,
        name: String,
        url: URL,
        kind: SpotKind = .launch,
        size: SpotSize = .wide,
        symbol: String = "app",
        subtitle: String? = nil,
        key: CommandKey? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.kind = kind
        self.size = size
        self.symbol = symbol
        self.subtitle = subtitle
        self.key = key
    }

    /// The state the manifest gives, shown before the command answers or when it cannot.
    public var manifestState: SpotState {
        SpotState(title: name, subtitle: subtitle)
    }

    /// Asks the command for its state. A launch spot has no state to read, so it does not run.
    public func state(timeout: TimeInterval) async throws -> SpotState {
        guard kind != .launch else { return manifestState }
        let output = try await PluginRun(command: self, arguments: SpotAction.read.arguments, timeout: timeout).output()
        guard let state = try? JSONDecoder().decode(SpotState.self, from: Data(output.utf8)) else {
            throw PluginError.badState
        }
        return state
    }

    public func perform(_ action: SpotAction, timeout: TimeInterval) async throws {
        _ = try await PluginRun(command: self, arguments: action.arguments, timeout: timeout).output()
    }

    public func withoutKey() -> PluginCommand {
        PluginCommand(id: id, name: name, url: url, kind: kind, size: size, symbol: symbol, subtitle: subtitle)
    }
}
