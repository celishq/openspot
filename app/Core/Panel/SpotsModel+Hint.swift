import Foundation
import Observation

extension SpotsModel {
    private var editHint: String? {
        if let id = openSheetID { return id == teachesEdit ? "⌘E Edit" : nil }
        guard let target, target.item == nil, arrangement.mark(of: target.entry.id) == .new else { return nil }
        return "⌘E Edit"
    }

    public var hint: String {
        if recording != nil { return KeyRow.hint(of: keyRows(of: .recording)) }
        if isEditing { return KeyRow.hint(of: keyRows(of: .edit)) }
        if spotDrop != nil { return "Nothing runs until you press ⌘⏎" }
        let escape = KeyRow.hint(of: [escapeRow])
        if let parts = openParts, !parts.showsRows || parts.drawsKeys {
            let hasActions = target.flatMap(actionMenu(on:)) != nil
            let keys = parts.hint(escape: escapeWords, stopping: { act(of: $0) != nil }, actions: hasActions)
            return editHint.map { "\($0)   \(keys)" } ?? keys
        }
        if content != .attachment, let confirm = confirmRow.hint { return [confirm, settingsRow.hint, "⌘K Actions"].compactMap { $0 }.joined(separator: "   ") }
        if let slashHint { return slashHint }
        if content == .attachment, let attachmentHint { return attachmentHint }
        if let soleHint { return soleHint }
        let keys = target.flatMap { target in
            actionMenu(on: target)?.hint(
                stopping: { sheets[target.entry.id]?.act(of: $0, item: target.item) != nil },
                second: [settingsRow.hint, editHint].compactMap { $0 }
            )
        } ?? escape
        let shown = selectedGlyphTitle.map { "\($0)  \(keys)" } ?? keys
        return attachmentHint.map { "\($0)   \(shown)" } ?? shown
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
