import Foundation

public enum PointerTarget: Sendable {
    case card(String)
    case item(SpotItem)
    case menuRow(Int)
}

extension SpotsModel {
    public func point(at target: PointerTarget) {
        switch target {
        case .menuRow(let row):
            menu?.point(at: row)
        case .card(let id):
            guard !menuOwnsPointer, !isEditing, let index = visible.firstIndex(where: { $0.id == id }) else { return }
            selected = index
        case .item(let item):
            guard !menuOwnsPointer else { return }
            openSheet?.list.select(run: item.run)
        }
    }

    var menuOwnsPointer: Bool {
        menu != nil
    }
}
