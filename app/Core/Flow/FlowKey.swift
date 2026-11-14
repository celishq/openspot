import Foundation

enum FlowKey: Equatable {
    case back, forward, grid

    init?(_ key: ActionKey) {
        switch key {
        case ActionKey(name: "[", isCommand: true): self = .back
        case ActionKey(name: "]", isCommand: true): self = .forward
        case ActionKey(name: "escape", isCommand: true): self = .grid
        default: return nil
        }
    }
}
