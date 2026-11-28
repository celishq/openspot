import Foundation

extension SpotsModel {
    func openAttachment() {
        guard !isAttachmentOpen else { return runs.panelOpened() }
        isAttachmentOpen = !isWarming
        heldArrivals = []
        let wasOn = attachments.isOn
        let front = isWarming ? nil : host.frontApp
        let feeds = !isWarming && entries.contains { !$0.spot.chipActions.isEmpty }
        let unread = feeds ? entries.filter { $0.spot.isAttachmentSource && !$0.spot.isAttachmentHidden && $0.spot.triggers.picks(over: front?.bundleID, browsers: config.browsers) } : []
        endSpread()
        var next = attachments
        next.open(over: front, unread: unread.map { ($0.id, $0.spot.attachmentLook) })
        if next != attachments { attachments = next }
        hideAttachments()
        if wasOn { updateVisible() }
        runs.panelOpened(showsToEnd: isWarming, over: front?.bundleID, feedsAttachment: feeds)
    }

    func takeAttachment(_ value: AttachmentValue, of id: String) {
        guard showMotion == nil else {
            heldArrivals.removeAll { $0.id == id }
            return heldArrivals.append((value, id))
        }
        settle(filled(attachments, with: value, of: id), motion: .fade)
    }

    func startShowMotion() {
        showMotion?.cancel()
        let length = showLength ?? MotionTokens.fadeIn
        showMotion = Task { [weak self] in
            try? await Task.sleep(for: .seconds(length), tolerance: .seconds(length / 10))
            guard !Task.isCancelled else { return }
            self?.endShowMotion()
        }
    }

    func endShowMotion() {
        showMotion?.cancel()
        showMotion = nil
        let held = heldArrivals
        heldArrivals = []
        guard !held.isEmpty else { return }
        settle(held.reduce(attachments) { filled($0, with: $1.value, of: $1.id) }, motion: .fade)
    }

    func failAttachment(_ text: String, of id: String) {
        guard entry(id)?.spot.isAttachmentHidden != true else { return }
        var next = attachments
        next.fail(id, text, look: entry(id)?.spot.attachmentLook)
        settle(next, motion: .fade)
    }

    private func filled(_ stack: AttachmentStack, with value: AttachmentValue, of id: String) -> AttachmentStack {
        var next = stack
        if entry(id)?.spot.isAttachmentHidden != true, cards.contains(where: { $0.spot.offers(value) }) { next.fill(id, with: value, look: entry(id)?.spot.attachmentLook) } else { next.remove(id) }
        return next
    }

    func endAttachment(of id: String, _ end: ScriptCall.End) {
        guard let chip = attachments.chips.first(where: { $0.source == id }), chip.isLoading else { return }
        switch end {
        case .failed(SpotError.timedOut): failAttachment(chip.appName.map { "\($0) didn't answer" } ?? "No answer", of: id)
        case .failed: failAttachment(sheets[id]?.failure ?? "", of: id)
        case .ended: mark(id, .empty(chip.appName.map { "Nothing to attach from \($0)" } ?? "Nothing to attach"))
        case .stopped: break
        }
    }

    func turnAttachment(by step: Int) {
        let isCycling = attachments.layout.isSpread
        spreadAttachment()
        var next = attachments
        next.spread()
        next.turn(by: step)
        var placed = next
        placed.place()
        let isStill = isCycling && placed.layout.places.map(\.x) == attachments.layout.places.map(\.x)
        let read = next.selectedChip.flatMap { !$0.isRead && entry($0.source)?.spot.triggers.pick != nil ? $0 : nil }
        if let read { next.mark(read.source, .loading) }
        settle(next, motion: isStill ? nil : .edit)
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

    @discardableResult
    func openSourceSettings() -> Bool {
        guard attachments.isOn, openSheetID == nil, let source = attachments.selectedChip?.source else { return false }
        return openSettings(at: .spotOf(source))
    }

    var isChipRefused: Bool {
        if case .failed = attachments.selectedChip?.state { true } else { false }
    }

    private func mark(_ id: String, _ state: AttachmentChip.State) {
        var next = attachments
        next.mark(id, state)
        settle(next, motion: .fade)
    }

    public func pressAttachment() {
        asOnePress {
            guard openSheetID == nil, !isEditing, !attachments.chips.isEmpty else { return }
            turnAttachment(by: 1)
        }
    }

    private func settle(_ stack: AttachmentStack, motion: PanelMotion?) {
        var next = stack
        if !next.isMoving { next.place() }
        guard next != attachments else { return }
        let turns = attachments.isOn != next.isOn || attachments.selectedChip != next.selectedChip
        let shown = turns ? shownDetails(of: query, in: next) : details
        let motion = isShown ? detailsMotion(to: shown, else: motion) : nil
        let moves = !next.isMoving && motion != nil && next.layout != attachments.layout
        if moves { next.isMoving = true }
        change(motion, {
            attachments = next
            guard turns else { return }
            takeDetails(shown)
            selected = 0
            showVisible()
        }) { [weak self] in
            guard moves, var landed = self?.attachments else { return }
            landed.isMoving = false
            self?.placeAttachment(landed, .edit)
        }
        hideAttachments()
    }

    func give(to entry: Entry) {
        guard let chip = attachments.selectedChip, let value = chip.value, let key = confirmKey(of: entry), let id = entry.item?.run else { return }
        guard let offer = entry.spot.chipActions.first(where: { $0.name == id && $0.fits(value) }) else { return }
        if offer.confirm != nil, confirming != key { return confirming = key }
        confirming = nil
        guard !value.isWhole else { return hand(value, to: entry.spot.id, by: offer) }
        let board = runs.api?.mac.clipboard
        Task { [weak self] in
            let whole = await Task.detached { Result { try value.whole(from: board) } }.value
            guard let self else { return }
            asOnePress {
                guard attachments.selectedChip?.source == chip.source else { return }
                switch whole {
                case .success(let whole): hand(whole, to: entry.spot.id, by: offer)
                case .failure(let error): mark(chip.source, .failed((error as? SpotError)?.reason ?? error.localizedDescription))
                }
            }
        }
    }

    private func hand(_ value: AttachmentValue, to id: String, by offer: ChipAction) {
        leaveAttachment()
        sheets[id]?.run(offer, with: value)
        settleGive(on: id)
    }

    func confirmKey(of entry: Entry) -> GlobalKey? {
        guard entry.role == .action, let run = entry.item?.run else { return nil }
        return GlobalKey(spot: entry.spot.id, act: .command(run), trigger: .shake)
    }

    func takeTab(back: Bool) -> Bool? {
        if handRow() { return true }
        guard openSheetID == nil, !isEditing else { return nil }
        if slash != nil { return completeSlash() }
        guard !attachments.chips.isEmpty else { return nil }
        turnAttachment(by: back ? -1 : 1)
        return true
    }

    private func handRow() -> Bool {
        guard let id = openSheetID, !isEditing, let value = openItems?.selectedItem.flatMap(AttachmentValue.init(row:)), cards.contains(where: { $0.spot.offers(value) }) else { return false }
        closeSheet(moving: true)
        var next = attachments
        next.fill(id, with: value, look: entry(id)?.spot.attachmentLook)
        next.select(id)
        next.spread()
        settle(next, motion: .edit)
        return true
    }

    var attachmentHint: String? {
        guard openSheetID == nil, !isEditing, !attachments.chips.isEmpty else { return nil }
        guard attachments.isOn else { return attachments.layout.isQuiet ? "⇥ Attach" : nil }
        let run = waitingWords.map { "⏎ \($0)" } ?? selectedEntry.map { "⏎ \($0.state.title)" } ?? (isChipRefused ? "⏎ Allow" : nil)
        return [run, "⇥ Next", "⌘⏎ Settings", "Esc Leave"].compactMap { $0 }.joined(separator: "   ")
    }

    func hideAttachments() {
        hideAttachments(for: query)
    }

    func hideAttachments(for query: String) {
        let isHidden = attachments.selected == nil && !query.isEmpty
        guard isAttachmentHidden != isHidden else { return }
        guard isShown, !attachments.chips.isEmpty else { return isAttachmentHidden = isHidden }
        change(.fade) { isAttachmentHidden = isHidden }
    }

    func showsAttachment(of query: String, in stack: AttachmentStack? = nil) -> Bool {
        (stack ?? attachments).isOn && !isEditing && !query.trimmingCharacters(in: .whitespaces).hasPrefix("/")
    }

    func attachmentRows() -> [Entry] {
        guard let chip = attachments.selectedChip, entry(chip.source) != nil, let value = chip.value else { return [] }
        let text = query.trimmingCharacters(in: .whitespaces)
        let search = text.isEmpty ? nil : runs.search(of: text)
        return commands.chipActions(of: value, matching: search, limit: Self.chipActionLimit).compactMap { row in
            entry(row.spot).map { Entry(spot: $0.spot, item: SpotItem(title: row.action.title, run: row.action.name, picture: Icon(text: row.action.icon)), role: .action, detail: row.action.detail) }
        }
    }

    static let chipActionLimit = 5

    func spreadAttachment() {
        attachmentWatch?.cancel()
        let pause = attachments.pause
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

    private func placeAttachment(_ stack: AttachmentStack, _ motion: PanelMotion?) {
        var next = stack
        if !next.isMoving { next.place() }
        guard next != attachments else { return }
        guard let motion, isShown, next.layout != attachments.layout else {
            attachments = next
            return hideAttachments()
        }
        next.isMoving = true
        change(motion, { attachments = next }) { [weak self] in
            guard var landed = self?.attachments else { return }
            landed.isMoving = false
            self?.placeAttachment(landed, .edit)
        }
        hideAttachments()
    }

    private func foldAttachment() {
        endSpread()
        var next = attachments
        next.fold()
        placeAttachment(next, .edit)
    }
}
