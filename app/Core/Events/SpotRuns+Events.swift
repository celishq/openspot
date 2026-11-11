import Foundation

/// The one way the core selects spots for a moment: an event raised here reads each spot that lists it.
extension SpotRuns {
    /// Reads each spot that the event selects, or sends a text of the main search to each spot that answers it.
    public func raise(_ event: SpotEvent) {
        switch event {
        case .panel: openPanel()
        case .wake: wake()
        case .query(let text): ask(text)
        case .named(let name, let value): read(name, value)
        }
    }

    /// The panel opened: reads each script that this moment lists or that a widget places, and starts the timers.
    public func panelOpened() {
        raise(.panel)
    }

    /// The Mac woke: each wanted script with a number in its `read` reads at once, and its clock starts again from now. A
    /// staying script that something wants and that ended starts again.
    public func woke() {
        raise(.wake)
    }

    /// Takes the events of the Mac from the source, and looks at its clipboard while a spot lists `clipboard`.
    public func listen(to source: any Mac) {
        self.source = source
        source.listen { [weak self] in self?.raise($0) }
        watchClipboard()
    }

    /// Whether the clipboard is looked at.
    var watchesClipboard: Bool {
        clipboardWatch != nil
    }

    /// Looks at the count of the clipboard after each pause while something wants a spot that lists `clipboard`, and raises
    /// `clipboard` when it changes. Each change of what is wanted calls it, through `updateClock`. After a quit nothing looks.
    func watchClipboard() {
        let isWanted = sheets.values.contains { $0.isWanted && $0.spot.read?.has(.event(SpotEvent.clipboard)) == true }
        guard let source, isWanted, !hasQuit else {
            clipboardWatch?.cancel()
            clipboardWatch = nil
            return
        }
        guard clipboardWatch == nil else { return }
        var count = source.clipboardCount
        clipboardWatch = Task { [weak self, weak source, clipboardPause] in
            while !Task.isCancelled {
                try? await Task.sleep(for: clipboardPause, tolerance: clipboardPause / 2)
                guard !Task.isCancelled, let self, let source else { return }
                let next = source.clipboardCount
                guard next != count else { continue }
                count = next
                raise(.named(SpotEvent.clipboard, value: nil))
            }
        }
    }

    private func openPanel() {
        let wasOpen = isPanelOpen
        isPanelOpen = true
        if !wasOpen { sheets.values.forEach { $0.panelOpened() } }
        tick()
        readPanel()
        for id in placed {
            if let sheet = sheets[id], sheet.spot.read?.seconds == nil { sheet.read() }
        }
        updateClock()
    }

    /// Reads each script with `panel` in its `read`, all at the same time, each of which can use a young answer. A staying
    /// script that something wants and that ended starts again.
    private func readPanel() {
        for sheet in sheets.values where sheet.spot.read?.has(.panel) == true {
            sheet.read(need: .moment, reason: .panel)
        }
        sheets.values.forEach { $0.settleScript() }
    }

    private func wake() {
        let time = now()
        for sheet in sheets.values where sheet.isWanted && sheet.spot.read?.seconds != nil {
            asked[sheet.spot.id] = time
            sheet.read(need: .clock, reason: .timer)
        }
        sheets.values.forEach { $0.settleScript() }
    }

    /// Reads each wanted script that lists the event, at once and with no young answer, as the clock does (B1, B5).
    private func read(_ name: String, _ value: String?) {
        for sheet in sheets.values where sheet.isWanted && sheet.spot.read?.has(.event(name)) == true {
            sheet.read(need: .clock, reason: ReadReason(event: name, value: value))
        }
    }

    /// Sends the text to each spot whose `answers` pattern matches it, and an empty text to the others, which drops their
    /// answers (A2).
    private func ask(_ query: String) {
        let text = query.trimmingCharacters(in: .whitespaces)
        for sheet in sheets.values {
            guard let pattern = sheet.spot.answers else { continue }
            sheet.answer(!text.isEmpty && answerMatches.matches(pattern, text) ? text : "")
        }
    }
}
