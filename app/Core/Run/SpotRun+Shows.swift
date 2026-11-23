import Foundation

extension SpotRun {
    public func afterAnswer(_ work: @escaping () -> Void) {
        waiter = work
        show()
    }

    public func show(selecting run: String? = nil, need: ShowNeed = .moment, event: ShowEvent? = nil) {
        guard !isHeld || route != heldRoute else { return }
        let event = event ?? (need == .change ? .change : showsSheet ? .sheet : .panel)
        let wantsSheetAnswer = event == .sheet && spot.triggers.has(.sheet) && shownEvent != .sheet
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
        let isSent = send(Call(
            message: Message(.show, inputs: showsSheet ? panel?.inputs ?? [] : [], search: search?.text, searchForms: search?.forms ?? []),
            key: Self.showKey,
            limit: runs.showLimit,
            event: event,
            purpose: .ask(.show(generation: partsGeneration, reports: need != .clock, query: query, tells: event != .panel))
        ))
        self.typed = nil
        if isSent {
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
        guard list.beginFinding(text) else { return }
        let asked = rows
        finding?.cancel()
        finding = Task { [weak self] in
            guard let found = await Self.found(asked), !Task.isCancelled else { return }
            self?.list.take(found)
        }
    }

    @concurrent
    private nonisolated static func found(_ list: ItemList) async -> ItemList.Found? {
        Task.isCancelled ? nil : list.found()
    }

    func ask() {
        let query = list.query
        if let older = running(Self.searchKey) { stop(older) }
        pauses[Self.searchKey]?.cancel()
        pauses[Self.searchKey] = nil
        let search = SearchQuery(text: query)
        send(Call(
            message: Message(.show, inputs: showsSheet ? panel?.inputs ?? [] : [], search: search.text, searchForms: search.forms),
            key: Self.searchKey,
            limit: runs.showLimit,
            event: .text(query, inSheet: true),
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
        let search = runs.search(of: text)
        send(Call(
            message: Message(.show, search: search.text, searchForms: search.forms),
            key: Self.answerKey,
            limit: runs.showLimit,
            event: .text(text, inSheet: false),
            purpose: .ask(.answer(text))
        ))
    }

    public func afterAnswers(_ work: @escaping () -> Void) {
        if isAnswering { answerWaiters.append(work) } else { work() }
    }

    func takeAnswers(_ rows: [SpotItem], to query: String? = nil) {
        if let query {
            guard query == answerQuery else { return }
            answeredQuery = query
        }
        if rows != answers {
            answers = rows
            onReport(.listChange)
        }
        guard !isAnswering else { return }
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
