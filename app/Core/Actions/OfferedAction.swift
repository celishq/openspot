import Foundation

public struct OfferedAction: Equatable, Sendable {
    public let action: CommandAction
    public let owner: String
    public private(set) var group: String?
    public let origins: Set<SpotOrigin>
    public let hooks: [ActionHook: String]
    public private(set) var keyLabel: String?

    static let place = "actions"

    static let originWords: [String: SpotOrigin] = ["mine": .mine, "core": .core, "builtin": .builtIn]

    public init(action: CommandAction, owner: String = "", group: String? = nil, origins: Set<SpotOrigin> = [], hooks: [ActionHook: String] = [:]) {
        self.action = action
        self.owner = owner
        self.group = group
        self.origins = origins
        self.hooks = hooks
    }

    static func read(_ commands: [Manifest.Command], owner: String, of name: String, isInline: Bool) throws -> [OfferedAction] {
        let isOther = { (line: String) in line.split(separator: " ").first.map(String.init) != place }
        if let command = commands.first(where: { $0.offers.contains(where: isOther) }) {
            let word = command.offers.first(where: isOther) ?? ""
            throw SpotError.fault("\(name) has offers = [\"\(word)\"] in \(command.section). A command offers only offers = [\"actions\"]")
        }
        var offered: [OfferedAction] = []
        for command in commands {
            let parent = command.id.lastIndex(of: ".").flatMap { dot in offered.first { $0.action.id == String(command.id[..<dot]) } }
            let line = command.offers.first
            guard line != nil || parent != nil else { continue }
            let key = command.shortcut.map { ActionKey(text: $0) }
            guard !command.title.isEmpty, key != .some(nil) else {
                throw SpotError.fault("\(name) cannot read \(command.section). Give it an ID with no space and a title, such as [actions.change] with title = \"Change Icon\"")
            }
            if let parent, line != nil {
                throw SpotError.fault("\(name) offers \(command.section), which shows in the submenu of \(parent.action.id) and takes its place. Remove its offers")
            }
            var hooks: [ActionHook: String] = [:]
            for hook in ActionHook.allCases { hooks[hook] = try function(hook, of: command, name: name, isInline: isInline) }
            let menuAction = CommandAction(
                id: command.id, title: command.title, key: key ?? nil, scope: .spot, after: command.closes ? .close : .stay,
                confirm: command.confirm
            )
            let origins = try parent?.origins ?? Self.origins(String((line ?? place).dropFirst(place.count)), of: name)
            offered.append(OfferedAction(action: menuAction, owner: owner, group: name, origins: origins, hooks: hooks))
        }
        return offered
    }

    private static func function(_ hook: ActionHook, of command: Manifest.Command, name: String, isInline: Bool) throws -> String? {
        let word = hook.rawValue
        guard let function = command.hooks[hook] else { return nil }
        guard isInline else {
            throw SpotError.fault("\(name) has \(word) = \"\(function)\" in \(command.section), which only a JavaScript spot can answer. Remove it, or write the spot as a .js file")
        }
        guard function.range(of: "^[A-Za-z_$][A-Za-z0-9_$]*$", options: .regularExpression) != nil else {
            throw SpotError.fault("\(name) has \(word) = \"\(function)\" in \(command.section). Name a function of the spot, such as \(word) = \"\(hook.example)\"")
        }
        return function
    }

    private static func origins(_ filter: String, of name: String) throws -> Set<SpotOrigin> {
        try Set(filter.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.map { word in
            guard let origin = originWords[word] else {
                throw SpotError.fault("\(name) offers actions to an unknown card: \(word). Use mine, core or builtin")
            }
            return origin
        })
    }

    func ofTheApp() -> OfferedAction {
        var offered = self
        offered.group = nil
        return offered
    }

    func labeled(_ text: String) -> OfferedAction {
        var offered = self
        offered.keyLabel = Trigger(text: text)?.label ?? ""
        return offered
    }

    public func fits(_ origin: SpotOrigin) -> Bool {
        origins.isEmpty || origins.contains(origin)
    }
}
