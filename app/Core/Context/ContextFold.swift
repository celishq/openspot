import Foundation

struct ContextFold {
    var pause: Duration = .seconds(1)
    var spreads = false
    var isMoving = false
    var watch: Task<Void, Never>?
}
