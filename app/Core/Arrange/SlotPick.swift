import Foundation

public struct SlotPick: Equatable, Sendable {
    public static let limit = 6

    public let cell: GridCell
    public internal(set) var query = ""
    public internal(set) var ids: [String] = []
    public internal(set) var selected = 0

    init(cell: GridCell) {
        self.cell = cell
    }

    public var chosen: String? {
        ids.indices.contains(selected) ? ids[selected] : nil
    }

    mutating func move(by step: Int) {
        guard !ids.isEmpty else { return }
        selected = min(max(selected + step, 0), ids.count - 1)
    }
}
