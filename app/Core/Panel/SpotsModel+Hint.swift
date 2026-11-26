import Foundation
import Observation

extension SpotsModel {
    public var hint: String {
        if recording != nil { return KeyRow.hint(of: keyRows(of: .recording)) }
        if isArranging { return arrangeHint }
        if isEditing { return [offGridCount, KeyRow.hint(of: keyRows(of: .edit))].compactMap { $0 }.joined(separator: "   ") }
        if spotDrop != nil { return "Nothing runs until you press ⌘⏎" }
        let escape = KeyRow.hint(of: [escapeRow])
        if let parts = openParts, !parts.showsRows || parts.drawsKeys {
            let hasActions = target.flatMap(actionMenu(on:)) != nil
            return parts.hint(escape: escapeWords, stopping: { act(of: $0) != nil }, actions: hasActions)
        }
        if content != .attachment, let confirm = confirmRow.hint { return [confirm, settingsRow.hint, "⌘K Actions"].compactMap { $0 }.joined(separator: "   ") }
        if let slashHint { return slashHint }
        if content == .attachment, let attachmentHint { return attachmentHint }
        if let soleHint { return soleHint }
        let keys = target.flatMap { target in
            actionMenu(on: target)?.hint(
                stopping: { sheets[target.entry.id]?.act(of: $0, item: target.item) != nil },
                second: [settingsRow.hint].compactMap { $0 }
            )
        } ?? escape
        let shown = selectedGlyphTitle.map { "\($0)  \(keys)" } ?? keys
        return attachmentHint.map { "\($0)   \(shown)" } ?? shown
    }

    var arrangeHint: String {
        if offGrid.isEmpty { return "All your spots are on the grid." }
        if freeCells.isEmpty { return "The grid is full. Drop a spot on a card to swap them." }
        return offGrid.count == 1 ? "1 spot is off the grid. Drag it in to pin it." : "\(offGrid.count) spots are off the grid. Drag one in to pin it."
    }

    private var offGridCount: String? {
        guard !offGrid.isEmpty else { return nil }
        return offGrid.count == 1 ? "1 of your spots is off the grid" : "\(offGrid.count) of your spots are off the grid"
    }

    public func followHint() {
        guard !followsHint else { return }
        followsHint = true
        takeHint()
    }

    func takeHint() {
        hintIsStale = false
        place(HintWords(withObservationTracking { hint } onChange: { [weak self] in
            MainActor.assumeIsolated { self?.staleHint() }
        }))
    }

    private func staleHint() {
        hintIsStale = true
        guard pressDepth == 0 else { return }
        Task { @MainActor [weak self] in
            guard let self, hintIsStale else { return }
            takeHint()
        }
    }

    private func place(_ words: HintWords) {
        hintTakes += 1
        let onSheet = openSheetID != nil || spotDrop != nil
        guard words != (onSheet ? sheetHint : gridHint) else { return }
        let motion: PanelMotion? = isEditing || hintIsForEdit || fieldDrop != nil ? .fade : nil
        hintIsForEdit = isEditing
        let write = { [self] in if onSheet { sheetHint = words } else { gridHint = words } }
        if let motion { change(motion, write) } else { write() }
    }

    var selectedGlyphTitle: String? {
        guard openSheetID == nil, let entry = selectedEntry,
              placements.first(where: { $0.index == selected })?.size == .small
        else { return nil }
        return entry.state.title
    }
}
