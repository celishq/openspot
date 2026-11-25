import Foundation

extension SpotsModel {
    public func openSlotPick(at cell: GridCell) {
        asOnePress {
            guard isEditing, freeCells.contains(cell) else { return }
            var pick = SlotPick(cell: cell)
            pick.ids = matches(of: "")
            change(.fade) { slotPick = pick }
        }
    }

    public func searchSlotPick(_ text: String) {
        asOnePress {
            guard var pick = slotPick, pick.query != text else { return }
            pick.query = text
            pick.ids = matches(of: text)
            pick.selected = 0
            slotPick = pick
        }
    }

    public func pickSlotSpot(_ id: String) {
        asOnePress {
            guard let pick = slotPick else { return }
            closeSlotPick()
            pin(id, at: pick.cell)
            endKeyEditing()
        }
    }

    public func closeSlotPick() {
        asOnePress {
            guard slotPick != nil else { return }
            change(.fade) { slotPick = nil }
            endKeyEditing()
        }
    }

    func moveSlotPick(by step: Int) {
        slotPick?.move(by: step)
    }

    private func matches(of text: String) -> [String] {
        Array(shelfMatches(of: text).prefix(SlotPick.limit).map(\.id))
    }
}
