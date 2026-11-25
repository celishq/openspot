import Foundation

extension SpotRun {
    private static let destinationInput = "at"

    public func afterAnswer(_ work: @escaping () -> Void) {
        waiter = work
        show()
    }

    public func show(selecting run: String? = nil, need: ShowNeed = .moment, event: ShowEvent? = nil) {
        guard !isHeld || route != heldRoute else { return }
        let event = event ?? (need == .change ? .change : showsSheet ? .sheet : .panel)
        let wantsSheetAnswer = event == .sheet && spot.showsInSheet && shownEvent != .sheet
        if let run { selecting = run }
        if link.isAsking {
            if need == .change { showsAgain = true }
            if wantsSheetAnswer { sheetAgain = true }
            if event.isEvent { eventAgain = event }
            return
        }
        if need == .moment, !wantsSheetAnswer, let answered, runs.now().timeIntervalSince(answered) < Self.answerAge {
            selectKept()
            return
        }
        let query = list.search == .script && !script.keepsState ? list.query : ""
        let typed = query.isEmpty ? typed ?? "" : query
        let search = typed.isEmpty ? nil : SearchQuery(text: typed)
        var message = event.message(after: showsSheet ? panel?.inputs ?? [] : [], search: search)
        let lands = showsSheet ? destination : nil
        if let lands { message.inputs.append(.init(key: Self.destinationInput, value: lands)) }
        let isSent = send(Call(
            message: message,
            key: Self.showKey,
            limit: runs.showLimit,
            event: event,
            purpose: .ask(.show(generation: partsGeneration, reports: need != .clock, query: query, tells: event != .panel))
        ))
        self.typed = nil
        if isSent {
            if lands != nil { destination = nil }
            shownEvent = event
            if !list.holdsItems || list.hasFailed { list.beginLoading() }
        }
    }

    public func search(_ text: String) {
        if panel?.isSelectionMoved == true { panel?.clearSelection() }
        if list.search == .local { return find(text) }
        guard list.search(text), list.search == .script else { return }
        if let older = running(Self.searchKey) { stop(older) }
        after(Self.textPause, key: Self.searchKey) { [weak self] in self?.ask() }
    }

    private func find(_ text: String) {
        var next = list
        guard next.beginFinding(text) else { return }
        next.take(next.found())
        list = next
    }

    func ask() {
        let query = list.query
        if let older = running(Self.searchKey) { stop(older) }
        pauses[Self.searchKey]?.cancel()
        pauses[Self.searchKey] = nil
        let event = ShowEvent.typed(query, inSheet: true)
        send(Call(
            message: event.message(after: showsSheet ? panel?.inputs ?? [] : [], search: SearchQuery(text: query)),
            key: Self.searchKey,
            limit: runs.showLimit,
            event: event,
            purpose: .ask(.search(query))
        ))
    }

    public func answer(_ text: String) {
        guard text != answerQuery else { return }
        answerQuery = text
        askAnswer()
    }

    func askAnswer() {
        let text = answerQuery
        if let older = running(Self.answerKey) { stop(older) }
        guard !text.isEmpty else {
            answeredQuery = ""
            answerWaiters = []
            takeAnswers([])
            return
        }
        let event = ShowEvent.typed(text, inSheet: false)
        send(Call(
            message: event.message(search: runs.search(of: text)),
            key: Self.answerKey,
            limit: runs.showLimit,
            event: event,
            purpose: .ask(.answer(text))
        ))
    }

    public func afterAnswers(_ work: @escaping () -> Void) {
        if isAnswering { answerWaiters.append(work) } else { work() }
    }

    func takeAnswers(_ rows: [SpotItem], to query: String? = nil, isStopped: Bool = false) {
        if isStopped, rows.isEmpty, query == answeredQuery { return }
        if let query {
            guard query == answerQuery else { return }
            answeredQuery = query
        }
        if rows != answers {
            answers = rows
            onReport(.listChange)
        }
        guard !isAnswering else { return }
        if query != nil { onReport(.answered) }
        let waiting = answerWaiters
        answerWaiters = []
        waiting.forEach { $0() }
    }

    var isShowing: Bool {
        link.isAsking
    }

    private func selectKept() {
        guard let run = selecting else { return }
        selecting = nil
        list.select(run: run)
    }

    func showToEnd(event: ShowEvent? = nil) {
        finishesShow = true
        show(need: .change, event: event)
    }

    func answerArrived() {
        hasAsked = true
        finishesShow = false
        let work = waiter
        waiter = nil
        work?()
        runs.opening.startMotion(of: spot.id)
    }

    func showAgainIfAsked() {
        guard !link.isAsking else { return }
        if sheetAgain {
            sheetAgain = false
            showsAgain = false
            show(need: .change, event: .sheet)
            guard !link.isAsking else { return }
        }
        guard showsAgain || eventAgain != nil else { return }
        let need: ShowNeed = showsAgain ? .change : .clock
        let event = eventAgain
        showsAgain = false
        eventAgain = nil
        show(need: need, event: event)
    }

    func hold(_ frame: Frame) async {
        isHeld = true
        heldRoute = route
        await takeAnswer(frame, frame: "", to: .show(generation: nil, reports: false, query: ""))
    }

    func release() {
        isHeld = false
    }

    func showOnce() {
        if spot.hasSheet { show(need: .change) }
    }
}
