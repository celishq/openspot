import Foundation

extension SpotRun {
    public func afterAnswer(_ work: @escaping () -> Void) {
        waiter = work
        read()
    }

    public func read(selecting run: String? = nil, need: ReadNeed = .moment, reason: ReadReason? = nil) {
        let reason = reason ?? (need == .change ? .change : showsSheet ? .sheet : .panel)
        let wantsSheetAnswer = reason == .sheet && spot.read?.has(.sheet) == true && readReason != .sheet
        if let run { selecting = run }
        if link.isAsking {
            if need == .change { readsAgain = true }
            if wantsSheetAnswer { sheetAgain = true }
            if reason.isEvent { eventAgain = reason }
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
            key: Self.readKey,
            limit: runs.readLimit,
            reason: reason,
            purpose: .ask(.read(generation: panel?.generation, reports: need != .clock, query: query, tells: reason != .panel))
        ))
        self.typed = nil
        if isSent {
            readReason = reason
            if !list.holdsItems || list.hasFailed { list.beginLoading() }
        }
    }

    public func search(_ text: String) {
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
            limit: runs.readLimit,
            reason: .text(query, inSheet: true),
            purpose: .ask(.search(query))
        ))
    }

    public func answer(_ text: String) {
        guard text != answerQuery else { return }
        answerQuery = text
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
            limit: runs.readLimit,
            reason: .text(text, inSheet: false),
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

    var isReading: Bool {
        link.isAsking
    }

    private func selectKept() {
        guard let run = selecting else { return }
        selecting = nil
        list.select(run: run)
    }

    func readToEnd(reason: ReadReason? = nil) {
        finishesRead = true
        read(need: .change, reason: reason)
    }

    func answerArrived() {
        hasAsked = true
        finishesRead = false
        let work = waiter
        waiter = nil
        work?()
        runs.opening.startMotion(of: spot.id)
    }

    func readAgainIfAsked() {
        guard !link.isAsking else { return }
        if sheetAgain {
            sheetAgain = false
            readsAgain = false
            read(need: .change, reason: .sheet)
            guard !link.isAsking else { return }
        }
        guard readsAgain || eventAgain != nil else { return }
        let need: ReadNeed = readsAgain ? .change : .clock
        let reason = eventAgain
        readsAgain = false
        eventAgain = nil
        read(need: need, reason: reason)
    }

    func readOnce() {
        if spot.read != nil { read(need: .change) }
    }
}
