import Foundation

/// The moment another app takes the focus from the panel (D7). A press in that app can start a drag of files toward a card,
/// so the panel waits while the press lasts. A new drag of files keeps it open for the drag, and a press that ends with no
/// such drag closes it. The change count of the drag pasteboard tells a new drag from the files of an earlier one.
public struct FocusLoss: Equatable, Sendable {
    /// What the panel does after one look at the press.
    public enum Step: Equatable, Sendable {
        case wait
        case close
        case followDrag
    }

    private let dragCount: Int

    /// A loss of the focus, with the change count of the drag pasteboard at that moment.
    public init(dragCount: Int) {
        self.dragCount = dragCount
    }

    /// What the panel does, from whether a mouse button is down, the change count of the drag pasteboard, and whether it
    /// holds files. It reads the files only for a new drag.
    public func step(isPressed: Bool, dragCount: Int, holdsFiles: @autoclosure () -> Bool) -> Step {
        guard isPressed else { return .close }
        return dragCount != self.dragCount && holdsFiles() ? .followDrag : .wait
    }
}
