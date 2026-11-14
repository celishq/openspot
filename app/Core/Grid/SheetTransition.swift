import Foundation

public struct SheetTransition: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case closed
        case ready
        case opening
        case open
        case closing
    }

    public private(set) var id: String?
    public private(set) var phase = Phase.closed
    public private(set) var motion = 0
    public private(set) var replaced: String?

    public init() {}

    public var shown: String? {
        phase == .closing || phase == .closed ? nil : id
    }

    public var isOpen: Bool {
        phase == .opening || phase == .open
    }

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

    public mutating func start() {
        guard phase == .ready else { return }
        motion += 1
        phase = .opening
    }

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

    public mutating func settle(_ id: String) {
        if self.id == id { replaced = nil }
    }

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
