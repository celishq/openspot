import Foundation

/// One change of a board, kept so that it can be undone: the figures that the change touched, as they were and as they
/// became, and the order of all figures when it added, removed or moved one. It holds no title, so undo keeps a rename.
struct Step: Equatable {
    /// The figures that the change touched or removed, as they were.
    let before: [Figure]
    /// The figures that the change touched or added, as they became.
    let after: [Figure]
    private let orderBefore: [UUID]?
    private let orderAfter: [UUID]?

    /// The step from one board to the next, or nil when their figures are the same.
    init?(from old: Board, to new: Board) {
        let was = old.figures.map(\.id)
        let now = new.figures.map(\.id)
        before = old.figures.filter { new[$0.id] != $0 }
        after = new.figures.filter { old[$0.id] != $0 }
        orderBefore = was == now ? nil : was
        orderAfter = was == now ? nil : now
        if before.isEmpty, after.isEmpty, was == now { return nil }
    }

    fileprivate func applied(to board: Board, back: Bool) -> [Figure] {
        var kept = Dictionary(board.figures.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for figure in back ? after : before { kept[figure.id] = nil }
        for figure in back ? before : after { kept[figure.id] = figure }
        return ((back ? orderBefore : orderAfter) ?? board.figures.map(\.id)).compactMap { kept[$0] }
    }
}

extension Board {
    /// Puts the figures of a step back as they were before it.
    mutating func undo(_ step: Step) {
        replace(step.applied(to: self, back: true))
    }

    /// Makes the change of a step again.
    mutating func redo(_ step: Step) {
        replace(step.applied(to: self, back: false))
    }
}
