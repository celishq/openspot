import Foundation

enum FlowKey: Equatable {
    case back, forward, previousSession, nextSession, grid

    init?(_ key: ActionKey) {
        switch key {
        case ActionKey(name: "[", isCommand: true): self = .back
        case ActionKey(name: "]", isCommand: true): self = .forward
        case ActionKey(name: "{", isCommand: true, isShift: true), ActionKey(name: "[", isCommand: true, isShift: true): self = .previousSession
        case ActionKey(name: "}", isCommand: true, isShift: true), ActionKey(name: "]", isCommand: true, isShift: true): self = .nextSession
        case ActionKey(name: "escape", isCommand: true): self = .grid
        default: return nil
        }
    }
}
