import Foundation

/// What the pointer moves onto, which takes the selection: a card of the grid, a row of the open sheet, or a row of the
/// open menu.
public enum PointerTarget: Sendable {
    case card(String)
    case item(SpotItem)
    case menuRow(Int)
}

/// The pointer. While the actions menu is open it owns the pointer, so that only its rows take a move or a click.
extension SpotsModel {
    /// Moves the selection to what the pointer moved onto. Edit Spots keeps its selection.
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
