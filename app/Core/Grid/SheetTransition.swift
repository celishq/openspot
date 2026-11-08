import Foundation

/// Where a sheet is in its motion between its card and its open place. A moving open first lies on its card, so that the
/// grow has a start; the end of a motion counts only while the motion it ends is still the current one.
public struct SheetTransition: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case closed
        /// Built and lying on its card, before its grow starts.
        case ready
        case opening
        case open
        case closing
    }

    /// The sheet that is built, from its first frame on its card to the end of its close.
    public private(set) var id: String?
    public private(set) var phase = Phase.closed

    public init() {}

    /// Whether the sheet is open or on its way there.
    public var isOpen: Bool {
        phase == .opening || phase == .open
    }

    /// Shows a sheet: at once when it does not move, and else on its card, ready to grow. A sheet that is open already
    /// stays open with the new one in its place.
    public mutating func show(_ id: String, moves: Bool) {
        self.id = id
        if !moves {
            phase = .open
        } else if !isOpen {
            phase = .ready
        }
    }

    /// Starts the grow of a ready sheet.
    public mutating func start() {
        if phase == .ready { phase = .opening }
    }

    /// Closes the sheet: at once when it does not move, and else back into its card.
    public mutating func hide(moves: Bool) {
        guard id != nil else { return }
        if moves {
            phase = .closing
        } else {
            phase = .closed
            id = nil
        }
    }

    /// Ends the motion that began in `phase`, when it is still the current one.
    public mutating func finish(_ phase: Phase) {
        guard phase == self.phase else { return }
        switch phase {
        case .opening:
            self.phase = .open
        case .closing:
            self.phase = .closed
            id = nil
        case .closed, .ready, .open:
            break
        }
    }
}
