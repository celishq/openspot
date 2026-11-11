import Foundation

/// The one way the core selects spots for a moment: an event raised here reads each spot that lists it.
extension SpotRuns {
    /// Reads each spot that the event selects, or sends a text of the main search to each spot that answers it.
    public func raise(_ event: SpotEvent) {
        switch event {
        case .panel: openPanel()
        case .wake: wake()
        case .query(let text): ask(text)
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

    private func openPanel() {
        let wasOpen = isPanelOpen
        isPanelOpen = true
        if !wasOpen { sheets.values.forEach { $0.panelOpened() } }
        tick()
        readPanel()
        for id in placed {
            if let sheet = sheets[id], sheet.command.read?.seconds == nil { sheet.read() }
        }
        updateClock()
    }

    /// Reads each script with `panel` in its `read`, all at the same time, each of which can use a young answer. A staying
    /// script that something wants and that ended starts again.
    private func readPanel() {
        for sheet in sheets.values where sheet.command.read?.has(.panel) == true {
            sheet.read(need: .moment, reason: .panel)
        }
        sheets.values.forEach { $0.settleScript() }
    }

    private func wake() {
        let time = now()
        for sheet in sheets.values where sheet.isWanted && sheet.command.read?.seconds != nil {
            asked[sheet.command.id] = time
            sheet.read(need: .clock, reason: .timer)
        }
        sheets.values.forEach { $0.settleScript() }
    }

    /// Sends the text to each spot whose `answers` pattern matches it, and an empty text to the others, which drops their
    /// answers (A2).
    private func ask(_ query: String) {
        let text = query.trimmingCharacters(in: .whitespaces)
        for sheet in sheets.values {
            guard let pattern = sheet.command.answers else { continue }
            sheet.answer(!text.isEmpty && answerMatches.matches(pattern, text) ? text : "")
        }
    }
}
