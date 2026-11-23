import Foundation

extension SpotRuns {
    public func raise(_ event: AppSignal) {
        switch event {
        case .panel: openPanel()
        case .wake: wake()
        case .sleep: usage.flush()
        case .clock: updateClock()
        case .query(let text): ask(text)
        case .named(let name, let value, let showsEachSpot): show(name, value, showsEachSpot: showsEachSpot)
        }
    }

    public func panelOpened(showsToEnd: Bool = false, over front: String? = nil, feedsContext: Bool = false) {
        guard !hasQuit else { return }
        openPanel(showsToEnd: showsToEnd, over: front, feedsContext: feedsContext)
    }

    public func launched() {
        readTimers()
        for sheet in sheets.values where sheet.spot.showsAtLaunch {
            sheet.showToEnd(event: .event(EventName.appLaunch, value: nil))
        }
    }

    public func showOfferedItems() {
        for sheet in sheets.values where sheet.spot.showsOfferedItems {
            sheet.showToEnd()
        }
    }

    public func woke() {
        raise(.wake)
    }

    public func listen(to source: any MacEvents) {
        self.source = source
        source.listen { [weak self] in self?.raise($0) }
        watchClipboard()
        watchLoad()
    }

    var watchesLoad: Bool {
        loadWatch != nil
    }

    func watchLoad() {
        let isWanted = sheets.values.contains { $0.isWanted && $0.spot.triggers.events.contains(EventName.systemLoad) }
        guard let source, isWanted, !hasQuit else {
            loadWatch?.cancel()
            loadWatch = nil
            return
        }
        guard loadWatch == nil else { return }
        let first = source.measureLoad()
        let seen = now()
        let value = loadSeen.flatMap { seen.timeIntervalSince($0.at) < Self.loadFreshness ? first.value(since: $0.sample) : nil }
        loadSeen = (first, seen)
        loadWatch = Task { [weak self, weak source, sleep = clock.sleep, pause = loadPause] in
            if let value { self?.raise(.named(EventName.systemLoad, value: value)) }
            var last = first
            while !Task.isCancelled {
                try? await sleep(pause, pause / 5)
                guard !Task.isCancelled, let self, let source else { return }
                let next = source.measureLoad()
                let value = next.value(since: last)
                last = next
                loadSeen = (next, now())
                raise(.named(EventName.systemLoad, value: value))
            }
        }
    }

    private static let loadFreshness: TimeInterval = 10

    var clipboardWait: Duration {
        isPanelOpen ? clipboardPause : clipboardPause * 2
    }

    var watchesClipboard: Bool {
        clipboardWatch != nil
    }

    func watchClipboard(looksNow: Bool = false) {
        let isWanted = sheets.values.contains { $0.isWanted && $0.spot.triggers.events.contains(EventName.clipboard) }
        guard let source, isWanted, !hasQuit else {
            clipboardWatch?.cancel()
            clipboardWatch = nil
            clipboardSeen = nil
            return
        }
        guard clipboardWatch == nil else { return }
        if clipboardSeen == nil { clipboardSeen = source.clipboardCount }
        clipboardWatch = Task { [weak self, weak source, sleep = clock.sleep] in
            var looks = looksNow
            while !Task.isCancelled {
                if !looks, let self {
                    let wait = clipboardWait
                    try? await sleep(wait, isPanelOpen ? wait / 2 : wait)
                }
                looks = false
                guard !Task.isCancelled, let self, let source else { return }
                let next = source.clipboardCount
                guard next != clipboardSeen else { continue }
                clipboardSeen = next
                raise(.named(EventName.clipboard, value: nil))
            }
        }
    }

    func want(_ id: String) {
        guard let sheet = sheets[id], sheet.spot.triggers.events.contains(EventName.spotWant), wanted.insert(id).inserted else { return }
        sheet.show(need: .change, event: .event(EventName.spotWant, value: nil))
    }

    private func openPanel(showsToEnd: Bool = false, over front: String? = nil, feedsContext: Bool = false) {
        let wasOpen = isPanelOpen
        isPanelOpen = true
        if !wasOpen { wanted = [] }
        if !wasOpen { sheets.values.forEach { $0.panelOpened() } }
        if !wasOpen, clipboardWatch != nil {
            clipboardWatch?.cancel()
            clipboardWatch = nil
            watchClipboard(looksNow: true)
        }
        updateClock()
        showPanel(toEnd: showsToEnd, over: front, feedsContext: feedsContext)
    }

    private func showPanel(toEnd: Bool = false, over front: String? = nil, feedsContext: Bool = false) {
        for sheet in sheets.values where sheet.spot.runsOnOpen(over: front, feedsContext: feedsContext) {
            if sheet.spot.isSource {
                sheet.show(need: .change, event: .panel)
            } else if toEnd {
                sheet.showToEnd(event: .panel)
            } else {
                sheet.show(need: .moment, event: .panel)
            }
        }
        sheets.keys.filter(isOnGrid).forEach(want)
        sheets.values.forEach { $0.settleScript() }
    }

    private func wake() {
        let time = now()
        for sheet in sheets.values where sheet.isWanted && sheet.spot.triggers.every != nil {
            sheet.clockShown = time
            sheet.show(need: .clock, event: .clock)
        }
        sheets.values.forEach { $0.settleScript() }
        updateClock()
        scheduleTimers()
        runSchedule()
    }

    private func show(_ name: String, _ value: String?, showsEachSpot: Bool) {
        for sheet in sheets.values where (showsEachSpot || sheet.isWanted) && sheet.spot.triggers.admits(name, value: value) {
            sheet.show(need: showsEachSpot ? .change : .clock, event: .event(name, value: value))
        }
    }
}
