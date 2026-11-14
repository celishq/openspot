import Foundation

public struct GlobalKey: Hashable, Sendable {
    public enum Act: Hashable, Sendable {
        case float
        case command(String)
    }

    public let spot: String
    public let act: Act
    public let trigger: Trigger

    public init(spot: String, act: Act, trigger: Trigger) {
        self.spot = spot
        self.act = act
        self.trigger = trigger
    }

    public init(spot: String, command: String, shortcut: Shortcut) {
        self.init(spot: spot, act: .command(command), trigger: .key(shortcut))
    }

    var text: String {
        let command = if case .command(let id) = act { "command = \"\(id)\"\n" } else { "" }
        return "[[keys]]\nspot = \"\(spot)\"\n\(command)key = \"\(trigger.text)\""
    }
}
