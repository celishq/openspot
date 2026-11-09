import Foundation

/// Where a sheet is in its motion between its card and its open place. A moving open first lies on its card, so that the
/// grow has a start. Each change starts a new motion with its own number, and the end of a motion counts only by that number.
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
    /// The number of the current motion.
    public private(set) var motion = 0
    /// The sheet that the current one took the place of, until that change has settled.
    public private(set) var replaced: String?

    public init() {}

    /// The sheet that shows: from its first frame on its card until its close starts.
    public var shown: String? {
        phase == .closing || phase == .closed ? nil : id
    }

    /// Whether the sheet is open or on its way there.
    public var isOpen: Bool {
        phase == .opening || phase == .open
    }

    /// Shows a sheet: at once when it does not move, and else on its card, ready to grow. A sheet that is open already
    /// stays open with the new one in its place.
    public mutating func show(_ id: String, moves: Bool) {
        replaced = moves && isOpen && self.id != id ? self.id : nil
        self.id = id
        if !moves {
            motion += 1
            phase = .open
        } else if !isOpen {
            motion += 1
            phase = .ready
        }
    }

    /// Starts the grow of a ready sheet.
    public mutating func start() {
        guard phase == .ready else { return }
        motion += 1
        phase = .opening
    }

    /// Closes the sheet: at once when it does not move, and else back into its card.
    public mutating func hide(moves: Bool) {
        guard id != nil else { return }
        motion += 1
        replaced = nil
        if moves {
            phase = .closing
        } else {
            phase = .closed
            id = nil
        }
    }

    /// Ends the change of place to this sheet, when it is still the current one.
    public mutating func settle(_ id: String) {
        if self.id == id { replaced = nil }
    }

    /// Ends the motion with this number, when it is still the current one.
    public mutating func finish(_ motion: Int) {
        guard motion == self.motion else { return }
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
