import Foundation

extension SpotRuns {
    public func raise(_ event: SpotEvent) {
        switch event {
        case .panel: openPanel()
        case .wake: wake()
        case .sleep: usage.flush()
        case .clock: tick()
        case .query(let text): ask(text)
        case .named(let name, let value, let readsEachSpot): read(name, value, readsEachSpot: readsEachSpot)
        }
    }

    public func panelOpened() {
        raise(.panel)
    }

    public func launched() {
        for sheet in sheets.values where sheet.spot.readsAtLaunch {
            sheet.readToEnd(reason: ReadReason(event: SpotEvent.appLaunch, value: nil))
        }
    }

    public func readOfferedRows() {
        for sheet in sheets.values where sheet.spot.readsOfferedRows {
            sheet.readToEnd()
        }
    }

    public func woke() {
        raise(.wake)
    }

    public func listen(to source: any Mac) {
        self.source = source
        source.listen { [weak self] in self?.raise($0) }
        watchClipboard()
    }

    var clipboardWait: Duration {
        isPanelOpen ? clipboardPause : clipboardPause * 2
    }

    var watchesClipboard: Bool {
        clipboardWatch != nil
    }

    func watchClipboard(looksNow: Bool = false) {
        let isWanted = sheets.values.contains { $0.isWanted && $0.spot.read?.has(.event(SpotEvent.clipboard)) == true }
        guard let source, isWanted, !hasQuit else {
            clipboardWatch?.cancel()
            clipboardWatch = nil
            clipboardSeen = nil
            return
        }
        guard clipboardWatch == nil else { return }
        if clipboardSeen == nil { clipboardSeen = source.clipboardCount }
        clipboardWatch = Task { [weak self, weak source] in
            var looks = looksNow
            while !Task.isCancelled {
                if !looks, let self {
                    let wait = clipboardWait
                    try? await Task.sleep(for: wait, tolerance: isPanelOpen ? wait / 2 : wait)
                }
                looks = false
                guard !Task.isCancelled, let self, let source else { return }
                let next = source.clipboardCount
                guard next != clipboardSeen else { continue }
                clipboardSeen = next
                raise(.named(SpotEvent.clipboard, value: nil))
            }
        }
    }

    private func openPanel() {
        let wasOpen = isPanelOpen
        isPanelOpen = true
        if !wasOpen { sheets.values.forEach { $0.panelOpened() } }
        if !wasOpen, clipboardWatch != nil {
            clipboardWatch?.cancel()
            clipboardWatch = nil
            watchClipboard(looksNow: true)
        }
        raise(.clock)
        readPanel()
        for id in placed {
            guard let sheet = sheets[id], let read = sheet.spot.read, read.seconds == nil, !read.has(.panel) else { continue }
            sheet.read(reason: .want)
        }
        updateClock()
    }

    private func readPanel() {
        for sheet in sheets.values where sheet.spot.read?.has(.panel) == true {
            sheet.read(need: .moment, reason: .panel)
        }
        sheets.values.forEach { $0.settleScript() }
    }

    private func wake() {
        let time = now()
        for sheet in sheets.values where sheet.isWanted && sheet.spot.read?.seconds != nil {
            lastClockRead[sheet.spot.id] = time
            sheet.read(need: .clock, reason: .clock(sheet.spot.read?.seconds))
        }
        sheets.values.forEach { $0.settleScript() }
    }

    private func read(_ name: String, _ value: String?, readsEachSpot: Bool) {
        for sheet in sheets.values where (readsEachSpot || sheet.isWanted) && sheet.spot.read?.admits(name, value: value) == true {
            sheet.read(need: readsEachSpot ? .change : .clock, reason: ReadReason(event: name, value: value))
        }
    }

    private func ask(_ query: String) {
        let text = query.trimmingCharacters(in: .whitespaces)
        answerWaits = []
        for sheet in sheets.values {
            guard let pattern = sheet.spot.answers else { continue }
            sheet.answer(!text.isEmpty && answerMatches.matches(pattern, text) ? text : "")
        }
        let waits = answerWaits ?? []
        answerWaits = nil
        let deadline = DispatchTime.now() + frameWait
        waits.forEach { $0(deadline) }
    }
}
