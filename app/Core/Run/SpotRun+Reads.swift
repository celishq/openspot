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
            if need == .change || wantsSheetAnswer { readsAgain = true }
            if reason.isEvent { eventAgain = reason }
            return
        }
        if need == .moment, !wantsSheetAnswer, let answered, runs.now().timeIntervalSince(answered) < Self.answerAge {
            selectKept()
            return
        }
        let query = list.search == .script && !link.keepsState ? list.query : ""
        let read = SpotAction.read
        let action = spot.read == nil ? spot.click : read
        let values = [showsSheet ? panel?.values : nil, query.isEmpty ? nil : SearchQuery(text: query).input].compactMap { $0 }
        let isSent = link.send(Call(
            action: action,
            key: Self.readKey,
            input: values.isEmpty ? nil : values.joined(),
            limit: action == read ? runs.readLimit : nil,
            reason: reason,
            variables: action == read ? reason.variables : [:],
            purpose: .ask(.read(generation: panel?.generation, reports: need != .clock, query: query, tells: reason != .panel))
        ))
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
        Task { [weak self] in
            let found = await Task.detached(priority: .userInitiated) { asked.found() }.value
            self?.list.take(found)
        }
    }

    func ask() {
        let query = list.query
        if let older = running(Self.searchKey) { stop(older) }
        pauses[Self.searchKey]?.cancel()
        pauses[Self.searchKey] = nil
        link.send(Call(
            action: .read,
            key: Self.searchKey,
            input: (showsSheet ? panel?.values ?? "" : "") + SearchQuery(text: query).input,
            limit: runs.readLimit,
            reason: .text(query, inSheet: true),
            variables: ReadReason.text(query, inSheet: true).variables,
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
        link.send(Call(
            action: .read,
            key: Self.answerKey,
            input: runs.search(of: text).input,
            limit: runs.readLimit,
            reason: .text(text, inSheet: false),
            variables: ReadReason.text(text, inSheet: false).variables,
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
        guard readsAgain || eventAgain != nil, !link.isAsking else { return }
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
