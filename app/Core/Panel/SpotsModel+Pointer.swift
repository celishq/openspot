import Foundation

public enum PointerTarget: Sendable {
    case grid(CGPoint?)
    case item(SpotItem)
    case menuRow(Int)
}

extension SpotsModel {
    public func point(at target: PointerTarget) {
        asOnePress {
            switch target {
            case .menuRow(let row):
                menu?.point(at: row)
            case .grid(let point):
                let index = point.flatMap { point in placements.first { $0.rect.contains(point) }?.index }
                let id = index.map { visible[$0].id }
                if pointedCard != id { pointedCard = id }
                if point != nil { editByKey() }
                guard let index, !menuOwnsPointer, !isEditing else { return }
                selected = index
            case .item(let item):
                guard !menuOwnsPointer else { return }
                openSheet?.list.select(run: item.run)
            }
        }
    }

    var menuOwnsPointer: Bool {
        menu != nil
    }
}
