import Foundation

extension SpotsModel {
    func give(to entry: Entry) {
        guard let value = context.selectedChip?.value else { return }
        landDrop(value, on: entry.spot.id, leavesContext: true)
    }

    func takeTab(back: Bool) -> Bool? {
        guard openSheetID == nil, !isEditing else { return nil }
        if slash != nil { return completeSlash() }
        guard !context.chips.isEmpty else { return nil }
        turnContext(by: back ? -1 : 1)
        return true
    }

    var contextHint: String? {
        guard openSheetID == nil, !isEditing, !context.chips.isEmpty else { return nil }
        guard context.isOn else { return "⇥ \(context.chips.count == 1 ? "Context" : "\(context.chips.count) Contexts")" }
        let run = selectedEntry.map { "⏎ \($0.state.title)" }
        return [run, "⇥ Next", "Esc Leave"].compactMap { $0 }.joined(separator: "   ")
    }
}
