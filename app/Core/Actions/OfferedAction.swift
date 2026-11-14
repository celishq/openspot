import Foundation

public struct OfferedAction: Equatable, Sendable {
    public let action: CommandAction
    public let owner: String
    public private(set) var group: String?
    public let origins: Set<SpotOrigin>
    public let when: String?

    static let words: [String: SpotOrigin] = ["mine": .mine, "core": .core, "builtin": .builtIn]

    public init(action: CommandAction, owner: String = "", group: String? = nil, origins: Set<SpotOrigin> = [], when: String? = nil) {
        self.action = action
        self.owner = owner
        self.group = group
        self.origins = origins
        self.when = when
    }

    static func read(_ buttons: [TextBlock], owner: String, of name: String, isInline: Bool) throws -> [OfferedAction] {
        if let block = buttons.first(where: { $0.values("offers").contains { $0.split(separator: " ").first != "actions" } }) {
            let word = block.values("offers").first { $0.split(separator: " ").first != "actions" } ?? ""
            throw SpotError.fault("\(name) has offers=\(word) on the button \(block.value("button") ?? ""). A button offers only offers=actions")
        }
        var offered: [OfferedAction] = []
        for block in buttons {
            let button = block.value("button") ?? ""
            let parent = button.lastIndex(of: ".").flatMap { dot in offered.first { $0.action.id == String(button[..<dot]) } }
            let line = block.values("offers").first
            guard line != nil || parent != nil else { continue }
            guard let action = CommandAction(id: button, block: block) else {
                throw SpotError.fault("\(name) cannot read the button \(button). Give it an ID with no space and a title, such as button=change with title=Change Icon")
            }
            if let parent, line != nil {
                throw SpotError.fault("\(name) offers the button \(button), which shows in the submenu of \(parent.action.id) and takes its place. Remove its offers line")
            }
            let when = block.value("when")
            if let when, !isInline {
                throw SpotError.fault("\(name) has when=\(when) on the button \(button), which only a JavaScript spot can answer. Remove it, or write the spot as a .js file")
            }
            if let when, when.range(of: "^[A-Za-z_$][A-Za-z0-9_$]*$", options: .regularExpression) == nil {
                throw SpotError.fault("\(name) has when=\(when) on the button \(button). Name a function of the spot, such as when=hasIcon")
            }
            let menuAction = CommandAction(id: action.id, title: action.title, key: action.key, scope: .spot, after: action.after, isForm: action.isForm, confirm: action.confirm)
            let origins = try parent?.origins ?? Self.origins(String((line ?? "actions").dropFirst("actions".count)), of: name)
            offered.append(OfferedAction(action: menuAction, owner: owner, group: name, origins: origins, when: when))
        }
        return offered
    }

    private static func origins(_ filter: String, of name: String) throws -> Set<SpotOrigin> {
        try Set(filter.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.map { word in
            guard let origin = words[word] else {
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

    public func fits(_ origin: SpotOrigin) -> Bool {
        origins.isEmpty || origins.contains(origin)
    }
}
