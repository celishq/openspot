@testable import OpenspotCore

extension ViewTree {
    var parts: [SpotPart] {
        order.compactMap { node($0)?.part }
    }

    func look(of id: String) -> SpotPart.Look? {
        node(id).flatMap { SpotPart.Look(style: $0.style.resolved(for: [.sheet])) }
    }
}
