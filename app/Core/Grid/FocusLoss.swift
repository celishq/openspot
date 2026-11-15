import Foundation

public struct FocusLoss: Equatable, Sendable {
    public enum Step: Equatable, Sendable {
        case wait
        case close
        case followDrag
    }

    private let dragCount: Int

    public init(dragCount: Int) {
        self.dragCount = dragCount
    }

    public func step(isPressed: Bool, dragCount: Int, holdsFiles: @autoclosure () -> Bool) -> Step {
        guard isPressed else { return .close }
        return dragCount != self.dragCount && holdsFiles() ? .followDrag : .wait
    }
}
