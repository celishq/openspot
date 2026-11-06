import Foundation

/// One executable of a plugin, with the look its spot takes. A widget runs nothing, and places metrics in a layout.
public struct PluginCommand: Equatable, Sendable {
    public static let lastRank = Int.max

    public let id: String
    public let name: String
    public let url: URL
    public private(set) var kind: SpotKind
    public let size: SpotSize
    public let symbol: String
    public let subtitle: String?
    public private(set) var key: CommandKey?
    public let read: SpotRead?
    public private(set) var pick: ItemPick
    public let rank: Int
    public let order: Int
    public private(set) var keepsRecent = true
    public private(set) var primary: String?
    public private(set) var actions: [CommandAction]
    public let layout: WidgetLayout?
    public let places: [String]
    public let opens: String?
    public let shipped: ShippedSpot?
    /// Whether the script stays running and takes calls on its standard input.
    public let stays: Bool
    /// The file extensions that its card takes, with `folder` and `*`.
    public let drop: [String]

    public init(
        id: String,
        name: String,
        url: URL,
        kind: SpotKind = .launch,
        size: SpotSize = .wide,
        symbol: String = "app",
        subtitle: String? = nil,
        key: CommandKey? = nil,
        read: SpotRead? = nil,
        pick: ItemPick = .close,
        rank: Int = PluginCommand.lastRank,
        order: Int = 0,
        primary: String? = nil,
        actions: [CommandAction] = [],
        layout: WidgetLayout? = nil,
        places: [String] = [],
        opens: String? = nil,
        shipped: ShippedSpot? = nil,
        stays: Bool = false,
        drop: [String] = []
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.kind = kind
        self.size = size
        self.symbol = symbol
        self.subtitle = subtitle
        self.key = key
        self.read = read
        self.pick = pick
        self.rank = rank
        self.order = order
        self.primary = primary
        self.actions = actions
        self.layout = layout
        self.places = places
        self.opens = opens
        self.shipped = shipped
        self.stays = stays
        self.drop = drop
    }

    /// Whether its rows join the main search.
    public var isGlobal: Bool {
        rank != Self.lastRank
    }

    /// The state the header gives, shown before the command answers or when it cannot.
    public var headerState: SpotState {
        SpotState(title: name, subtitle: subtitle)
    }

    /// Whether the panel asks the command how it looks each time it opens.
    public var readsState: Bool {
        read?.has(.panel) == true && !isGlobal && !stays
    }

    /// The call that a click on its card makes: `run`, or no argument for a file with no `read`.
    public var click: SpotAction {
        read == nil ? SpotAction(arguments: []) : .run
    }

    /// Asks the command for its state. A command with no state to read does not run.
    public func state(timeout: TimeInterval) async throws -> SpotState {
        guard readsState else { return headerState }
        return try Self.state(of: try await output(.read, timeout: timeout), header: headerState)
    }

    /// Asks the command how it looks, and returns it with the kind and the actions that its output gives.
    public func opened(timeout: TimeInterval) async throws -> (command: PluginCommand, state: SpotState) {
        guard readsState else { return (self, headerState) }
        let output = try await output(.read, timeout: timeout)
        var command = taking(output)
        command.kind = output.kind
        return (command, try Self.state(of: output, header: headerState))
    }

    /// This command with the actions, the word for Enter, the pick and the recents that its script printed.
    public func taking(_ output: PluginOutput) -> PluginCommand {
        var command = self
        command.actions = output.actions
        command.primary = output.primary
        command.pick = output.pick
        command.keepsRecent = output.keepsRecent
        return command
    }

    private static func state(of output: PluginOutput, header: SpotState) throws -> SpotState {
        guard output.summary != nil || output.errors.isEmpty else { throw PluginError.badState }
        return SpotState(block: output.summary, header: header)
    }

    private func output(_ action: SpotAction, timeout: TimeInterval) async throws -> PluginOutput {
        PluginOutput(text: try await text(of: action.arguments, input: nil, timeout: timeout))
    }

    /// What a call prints: the answer of a shipped spot, or else the output of the script.
    private func text(of arguments: [String], input: String?, timeout: TimeInterval) async throws -> String {
        if case .plugins(let guide) = shipped { return try await guide.answer(arguments, input: input, timeout: timeout) }
        return try await ScriptProcess.output(url: url, arguments: arguments, input: input, limit: timeout)
    }

    /// Asks the command for the items of its list, with the search when the script searches.
    public func items(query: String = "", input: String? = nil, timeout: TimeInterval) async throws -> PluginOutput {
        if stays { return try await firstLiveFrame(timeout: timeout) }
        return PluginOutput(text: try await text(of: SpotAction.items(query: query).arguments, input: input, timeout: timeout))
    }

    /// Starts a staying script, reads its first sheet and stops it.
    private func firstLiveFrame(timeout: TimeInterval) async throws -> PluginOutput {
        let live = ScriptProcess(url: url, mode: .stays, limit: timeout)
        defer { live.end() }
        let frames = try live.start()
        live.send(.read)
        for try await frame in frames { return PluginOutput(text: frame) }
        return PluginOutput(text: "")
    }

    /// What a call prints, frame by frame, as the script prints it.
    public func frames(_ action: SpotAction, input: String?, timeout: TimeInterval) -> AsyncThrowingStream<String, Error> {
        if case .plugins = shipped {
            return AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        continuation.yield(try await text(of: action.arguments, input: input, timeout: timeout))
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
        let process = ScriptProcess(url: url, arguments: action.arguments, mode: .once(input: input), limit: timeout)
        do {
            return try process.start()
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }
    }

    /// Reports a change in a sheet of parts, with all its values on standard input, and returns what the script prints.
    public func change(_ action: SpotAction, values: String, timeout: TimeInterval) async throws -> PluginOutput {
        PluginOutput(text: try await text(of: action.arguments, input: values, timeout: timeout))
    }

    /// Asks the command for the form of an action: the call of that action, with empty stdin.
    public func form(_ action: CommandAction, item: SpotItem?, timeout: TimeInterval) async throws -> ItemForm {
        guard let form = ItemForm(output: try await output(.action(action, item: item), timeout: timeout)) else { throw PluginError.badForm }
        return form
    }

    /// Gives a filled form to the command, and returns the run value of the item it saved, if it prints one.
    public func submit(_ action: CommandAction, item: SpotItem?, draft: FormDraft, timeout: TimeInterval) async throws -> String {
        let output = try await text(of: SpotAction.action(action, item: item).arguments, input: draft.text, timeout: timeout)
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
        case .widget: return opens == nil ? nil : "Open"
        }
    }

    /// Runs an action, and returns the words of the toast that it prints, if any.
    @discardableResult
    public func perform(_ action: SpotAction, timeout: TimeInterval) async throws -> String? {
        try await output(action, timeout: timeout).summary?.value("toast")
    }

    public func withoutKey() -> PluginCommand {
        var command = self
        command.key = nil
        return command
    }
}
