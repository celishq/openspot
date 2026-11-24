import Foundation

extension SpotsModel {
    func openAttachment() {
        guard !isAttachmentOpen else { return runs.panelOpened() }
        isAttachmentOpen = !isWarming
        let wasOn = attachments.isOn
        let front = isWarming ? nil : host.frontApp
        let feeds = !isWarming && entries.contains { !$0.spot.chipActions.isEmpty }
        let unread = feeds ? entries.filter { $0.spot.isSource && $0.spot.triggers.picks(over: front?.bundleID, browsers: config.browsers) } : []
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
        if cards.contains(where: { $0.spot.offers(value) }) { next.fill(id, with: value, look: entry(id).flatMap { Self.look(of: $0.spot) }) } else { next.remove(id) }
        settle(next, motion: .fade)
    }

    func endAttachment(of id: String, _ end: ScriptCall.End) {
        guard let chip = attachments.chips.first(where: { $0.source == id }), chip.isLoading else { return }
        switch end {
        case .failed(SpotError.timedOut): mark(id, .failed(chip.appName.map { "\($0) didn't answer" } ?? "No answer"))
        case .failed:
            let line = sheets[id]?.failure ?? ""
            mark(id, .failed(ReadRefusal.field(of: line) ?? line))
        case .ended: mark(id, .empty(chip.appName.map { "Nothing to attach from \($0)" } ?? "Nothing to attach"))
        case .stopped: break
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
        guard let read else { return }
        runs.pickAttachment(read.source, over: read.app) { [weak self] end in self?.endAttachment(of: read.source, end) }
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
        guard case .failed = attachments.selectedChip?.state, let id = entries.first(where: { $0.spot.edits == .attachments && $0.spot.isBuiltIn })?.id else { return }
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
        guard let value = attachments.selectedChip?.value, let key = confirmKey(of: entry), let id = entry.item?.run else { return }
        guard let offer = entry.spot.chipActions.first(where: { $0.name == id && $0.fits(value) }) else { return }
        if offer.confirm != nil, confirming != key { return confirming = key }
        confirming = nil
        leaveAttachment()
        sheets[entry.spot.id]?.run(offer, with: value)
        settleGive(on: entry.spot.id)
    }

    func confirmKey(of entry: Entry) -> GlobalKey? {
        guard entry.role == .action, let run = entry.item?.run else { return nil }
        return GlobalKey(spot: entry.spot.id, act: .command(run), trigger: .shake)
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
        let run = waitingWords.map { "⏎ \($0)" } ?? selectedEntry.map { "⏎ \($0.state.title)" }
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
        let search = text.isEmpty ? nil : runs.search(of: text)
        return commands.chipActions(of: value, matching: search, limit: Self.chipActionLimit).compactMap { row in
            entry(row.spot).map { Entry(spot: $0.spot, item: SpotItem(title: row.action.title, run: row.action.name, picture: Icon(text: row.action.icon)), role: .action, detail: row.action.detail) }
        }
    }

    func hold(_ preview: AttachmentPreview?, motion: PanelMotion?) {
        guard preview != fieldValue.preview else { return }
        change(isShown ? motion : nil) { fieldValue = FieldValue(preview) }
    }

    static let chipActionLimit = 5

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
