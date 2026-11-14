import Foundation

/// A key that moves the flow while a sheet shows (H1): ⌘[ back, ⌘] forward, and ⌘Esc to the grid. Esc steps back
/// through the search first, so `SpotsModel.stepBack` takes it.
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
