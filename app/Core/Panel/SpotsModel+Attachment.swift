import Foundation

extension SpotsModel {
    func openAttachment() {
        guard !isAttachmentOpen else { return runs.panelOpened() }
        isAttachmentOpen = !isWarming
        let wasOn = attachments.isOn
        let front = isWarming ? nil : host.frontApp
        let feeds = !isWarming && entries.contains { entry in AttachmentValue.Kind.allCases.contains(where: entry.spot.triggers.drop.takes) }
        let unread = feeds ? entries.filter { $0.spot.isSource && $0.spot.triggers.attaches(over: front?.bundleID) } : []
        endSpread()
        isAttachmentMoving = false
        var next = attachments
        next.open(over: front, unread: unread.map { ($0.id, Self.look(of: $0.spot)) })
        if next != attachments { attachments = next }
        if wasOn { updateVisible() }
        runs.panelOpened(showsToEnd: isWarming, over: front?.bundleID, feedsAttachment: feeds)
    }

    func takeAttachment(_ state: AttachmentChip.State, of id: String) {
        guard case .ready(let value) = state else {
            guard attachments.chips.contains(where: { $0.source == id && $0.isLoading }) else { return }
            return mark(id, state)
        }
        var next = attachments
        if cards.contains(where: { $0.spot.takes(value) }) { next.fill(id, with: value, look: entry(id).flatMap { Self.look(of: $0.spot) }) } else { next.remove(id) }
        settle(next, motion: .fade)
    }

    func endAttachment(of id: String, _ end: ScriptCall.End) {
        guard let chip = attachments.chips.first(where: { $0.source == id }), chip.isLoading else { return }
        switch end {
        case .failed(SpotError.timedOut): mark(id, .failed("\(chip.appName ?? "The app") didn't answer"))
        case .failed: mark(id, .failed(sheets[id]?.failure ?? ""))
        case .ended, .stopped: mark(id, .empty("Nothing to attach from \(chip.appName ?? "the app")"))
        }
    }

    func turnAttachment(by step: Int) {
        let isCycling = attachments.layout.isSpread
        spreadAttachment()
        var next = attachments
        next.turn(by: step)
        let read = next.selectedChip.flatMap { !$0.isRead ? $0 : nil }
        if let read { next.mark(read.source, .loading) }
        settle(next, motion: isCycling ? nil : .edit)
        if let read { runs.attach(read.source, over: read.app) }
    }

    func leaveAttachment() {
        endSpread()
        var next = attachments
        let reading = next.chips.filter(\.isLoading).map(\.source)
        reading.forEach { next.mark($0, .unread) }
        next.leave()
        settle(next, motion: .edit)
        reading.forEach(runs.stopAttach)
    }

    func allowAttachment() {
        guard case .denied = attachments.selectedChip?.state, let id = entries.first(where: { $0.spot.edits == .attachments && $0.spot.isBuiltIn })?.id else { return }
        pushFirst(id, moving: true)
    }

    private func mark(_ id: String, _ state: AttachmentChip.State) {
        var next = attachments
        next.mark(id, state)
        settle(next, motion: .fade)
    }

    public func pressAttachment() {
        guard openSheetID == nil, !isEditing, !attachments.chips.isEmpty else { return }
        turnAttachment(by: 1)
    }

    private static func look(of spot: Spot) -> AttachmentChip.Look? {
        spot.fileIcon.map(AttachmentChip.Look.file) ?? (spot.symbol.isEmpty ? nil : .symbol(spot.symbol))
    }

    private func settle(_ next: AttachmentStack, motion: PanelMotion?) {
        guard next != attachments else { return }
        let before = (isOn: attachments.isOn, chip: attachments.selectedChip)
        change(isShown ? motion : nil, { attachments = next })
        placeAttachment(motion)
        guard before.isOn != next.isOn || before.chip != next.selectedChip else { return }
        selected = 0
        updateVisible(holding: motion)
    }

    func give(to entry: Entry) {
        guard let value = attachments.selectedChip?.value else { return }
        landDrop(value, on: entry.spot.id, leavesAttachment: true)
    }

    func takeTab(back: Bool) -> Bool? {
        guard openSheetID == nil, !isEditing else { return nil }
        if slash != nil { return completeSlash() }
        guard !attachments.chips.isEmpty else { return nil }
        turnAttachment(by: back ? -1 : 1)
        return true
    }

    var attachmentHint: String? {
        guard openSheetID == nil, !isEditing, !attachments.chips.isEmpty else { return nil }
        guard attachments.isOn else { return attachments.layout.showsHint ? "⇥ Attach" : nil }
        let run = selectedEntry.map { "⏎ \($0.state.title)" }
        return [run, "⇥ Next", "Esc Leave"].compactMap { $0 }.joined(separator: "   ")
    }

    func hideAttachments() {
        let isHidden = attachments.layout.isQuiet && !query.isEmpty
        guard isAttachmentHidden != isHidden else { return }
        change(isShown ? .fade : nil) { isAttachmentHidden = isHidden }
    }

    func showAttachment(holding motion: PanelMotion?) -> [Entry] {
        guard let chip = attachments.selectedChip, entry(chip.source) != nil else {
            hold(nil, motion: motion)
            return []
        }
        guard let value = chip.value else {
            hold(AttachmentPreview(state: chip), motion: motion)
            return []
        }
        hold(AttachmentPreview(value), motion: motion)
        let text = query.trimmingCharacters(in: .whitespaces)
        let found = commands.takers(of: value, matching: text.isEmpty ? nil : runs.search(of: text), limit: Self.takerLimit)
        let taken = found.compactMap { row in
            entry(row.spot).map { Entry(spot: $0.spot, item: SpotItem(title: row.title, run: ""), role: .taker, detail: value.kind.takerWords) }
        }
        return taken
    }

    func hold(_ preview: AttachmentPreview?, motion: PanelMotion?) {
        guard preview != fieldValue.preview else { return }
        change(isShown ? motion : nil) { fieldValue = FieldValue(preview) }
    }

    static let takerLimit = 5

    func spreadAttachment() {
        attachmentWatch?.cancel()
        let pause = attachmentPause
        attachmentWatch = Task { [weak self] in
            try? await Task.sleep(for: pause, tolerance: pause / 10)
            guard !Task.isCancelled else { return }
            self?.foldAttachment()
        }
    }

    func endSpread() {
        attachmentWatch?.cancel()
        attachmentWatch = nil
    }

    func placeAttachment(_ motion: PanelMotion?) {
        guard !isAttachmentMoving else { return }
        var next = attachments
        next.place(spreads: attachmentWatch != nil)
        guard next != attachments else { return }
        guard let motion, isShown else {
            attachments = next
            return
        }
        isAttachmentMoving = true
        change(motion, { attachments = next }) { [weak self] in
            self?.isAttachmentMoving = false
            self?.placeAttachment(.edit)
        }
    }

    private func foldAttachment() {
        endSpread()
        placeAttachment(.edit)
    }
}
